# Auto-crafter Architecture

## Working directory

ALL work is done inside `apps/autocraft_v2/`. The user edits files on in-game
computers remotely via SFTP (the Minecraft world is on a remote server). Files
in this directory are edited in-place — edits auto-sync to the remote via the
gvfs mount. No separate deploy step needed.

Files to edit:
- `craft_terminal.lua` — the terminal computer script (master controller)
- `craft_turtle.lua` — the turtle worker script
- `recipes/{category}/*.lua` — recipe definitions (flat subdirs)
- `AGENTS.md` — this file

## Overview

CC:Tweaked + Tom's Simple Storage auto-crafting system. User requests an item+quantity, the system builds a recipe tree, removes already-owned resources, batches independent operations, stages materials to working inventory, executes across machines/turtles, and returns results.

## Scripts

- `craft_terminal.lua` — master controller (terminal computer)
- `craft_turtle.lua` — worker (turtle, receives 4×4 layouts via rednet)

## Recipe format

Each file under `recipes/{category}/*.lua` returns:

```lua
return {
    machine = "furnace",            -- machine type key in MACHINES table
    inputs = {                      -- layout (nils for empty slots)
        { name = "mod:item", count = 1 },
        nil,
    },
    outputs = {
        { name = "mod:item", count = 1 },
    }
}
```

Namespaced names (`mod:item`) are used throughout. Loaded from `recipes/`
subdirectories. Recipes without a configured machine are skipped. To validate all recipe
files on NixOS: `nix-shell -p lua --run 'for f in recipes/*/*.lua; do lua -e "assert(loadfile(\"$f\"))()"; done'`

## Architecture (5-step pipeline)

### Step 1: Build recipe tree (`build_recipe_tree`)

Recursive DFS: for a resource+quantity, find the first recipe whose output matches the resource name (exact or `:suffix`). Create a node with `recipe`, `executions = ceil(quantity / output.count)`, and `leafs` — one per flat input, recursively built. Inputs with no producing recipe (raw materials) become `nil` and are omitted from leafs.

Tree is nested: root = requested item, leafs = sub-recipes for its inputs, leafs of leafs = sub-recipes for their inputs, etc.

### Step 2: Truncate tree (`truncate_recipe_tree`)

Scan master storage via `.items()` (network-wide). Walk tree top-down: for each node whose output exists in storage, reduce `node.executions` by the available amount. The reduction ratio cascades to leafs: `leaf.executions = ceil(leaf.executions * ratio)`. Items "consumed" from storage are recorded in `truncated_items`. Nodes with `executions == 0` (fully satisfied) are pruned.

Purpose: skip crafting items already in storage.

### Step 3: Convert to batches (`convert_recipe_tree_into_batches`)

Repeatedly collect "ready" nodes. A node is ready when ALL its leafs were
added to batches in PRIOR iterations (tracked by a persistent `resolved` set).
Nodes whose leafs are in the CURRENT iteration's `pending` set are NOT ready
— this prevents dependent recipes (e.g. planks → slabs → barrels) from ending
up in the same batch.

Same-recipe nodes across the tree are merged into one batch entry (summed
`executions`). After each iteration, `pending` is moved into `resolved` for
the next iteration. Stops when no nodes remain.

A batch is a set of entries where no entry's recipe depends on another's
output. Within a batch, operations are parallelizable.

### Step 4: Stage materials

Move `truncated_items` from master to working via buffer barrel (`move_items_from_master_to_working`). Then calculate net deficit across all batches: for every input item, `deficit = total_input - total_output - working_inventory_count`. Pull remaining deficit from master to working via buffer barrel. Error if insufficient.

Connector↔connector transfers (`pushItem`/`pullItem` by item name) are broken
on Tom's Simple Storage. All connector-to-connector transfers are routed
through `BUFFER_INVENTORY` (an Iron Chests gold barrel): push from source
connector to buffer barrel, then pull from buffer barrel to target connector.

This isolates the process: if another user takes items from master during crafting, the pipeline isn't disrupted.

### Step 5: Execute batches (round-based)

For each batch (sequential), repeat rounds:

1. **Clear machines**: empty every machine's input and output barrels into working inventory (retry loop per barrel).
2. **Fill machines**: group pending entries by machine type. If only one entry needs a machine type, parallelize it across ALL machines of that type (fair share: `ceil(remaining / machines_left)` per machine, capped by `slot_usage`). If multiple entries share a machine type, round-robin one machine per entry. Push items from working to machine input barrel. For crafter machines, build a `layout` table (grid slots with multiplied counts).
3. **Auto phase** (non-crafter): wait for expected outputs to appear in machine output barrels. Poll every 1s, timeout after `MACHINES_TIMEOUT` seconds.
4. **Crafter phase**: send layout to turtle via `rednet.send(machine.id, layout)`. Wait for reply per machine (`rednet.receive(MACHINES_TIMEOUT)`).

Repeat until all entries in the batch have zero pending executions.

After all batches, move everything back to master storage (including buffer).

## Machine types

| Type | Behavior |
|------|----------|
| `crafter` | Rednet-controlled turtle. Receives 4×4 layout table, executes `turtle.craft()` loop, sends reply. Has `.id` field. |
| `furnace` | Auto machine (barrel I/O). Waited on via polling. No `.id`. |
| `macerator` | Auto machine. |
| `compressor` | Auto machine. |
| `mixer` | Auto machine. |
| `cutter` | Auto machine. |

All machines define `input`, `output` barrel names and `slot_usage` (max item count per slot). Both input and output counts are capped against `slot_usage` when calculating per-fill executions.

## Turtle internals (`craft_turtle.lua`)

- 4×4 inventory. Slot 16 is the stash/inbox. `suckUp()` pulls items into slot 16.
- `recipe_to_turtle_slot(slot)` maps recipe slots 1–9 to the top-left 3×3 area: `{1,2,3,5,6,7,9,10,11}`. Slot 4 is the result slot.
- Receives a multiplied layout via rednet. For each recipe slot, processes one item type at a time: suck from stash into slot 16, then distribute to all matching grid slots. Leftovers returned to stash.
- Crafts via `turtle.craft()` loop. Terminal caps each fill by output `slot_usage`, so slot 4 (result) never receives more than 64 items — no overflow into grid.
- `turtle.drop()` retries with `os.sleep(0.5)` on failure (both initial inventory clear and final cleanup) to handle transient output barrel contention.

## References

- CC:Tweaked docs: https://tweaked.cc

## Key details

- Lua 5.1 (no `goto`/`continue`). `ipairs` stops at first `nil` — use `pairs` for layout iteration.
- `.list()` on vanilla barrels/machine I/O. `.items()` only on Tom's Simple Storage connectors.
- `math.floor`/`math.ceil` applied consistently for fractional output handling.
- Single `MACHINES_TIMEOUT = 600s` for both auto machine wait and rednet reply wait.
- `slot_usage` caps BOTH input and output counts per fill. Failing to cap output can overflow turtle slot 4 into the crafting grid, forming unintended recipes (e.g. 64 logs → 256 planks → 192 overflow into grid slots 5-7 → slab/button recipes).
- Connector↔connector `pushItem`/`pullItem` by item name is broken on Tom's Simple Storage. Use a buffer barrel as intermediary: push from source to buffer, pull from buffer to target.
- Single-entry machine types in a batch are parallelized across all machines (fair split). Multi-entry types share machines round-robin.
