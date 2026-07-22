local REDNET_MODEM_SIDE = "top"
local MASTER_INVENTORY  = "toms_storage:ts.inventory_connector_5"
local WORKING_INVENTORY = "toms_storage:ts.inventory_connector_6"
local BUFFER_INVENTORY  = "ironchests:gold_barrel_0"

local MACHINES_TIMEOUT = 600

local MACHINES = {
    crafter = {
        { input = "minecraft:barrel_4",  output = "minecraft:barrel_3",  id = 1, slot_usage = 64 },
        { input = "minecraft:barrel_17", output = "minecraft:barrel_18", id = 2, slot_usage = 64 },
        { input = "minecraft:barrel_53", output = "minecraft:barrel_52", id = 3, slot_usage = 64 },
        { input = "minecraft:barrel_55", output = "minecraft:barrel_54", id = 4, slot_usage = 64 }
    },
    furnace = {
        { input = "minecraft:barrel_6",  output = "minecraft:barrel_5",  slot_usage = 64 },
        { input = "minecraft:barrel_19", output = "minecraft:barrel_20", slot_usage = 64 },
        { input = "minecraft:barrel_49", output = "minecraft:barrel_48", slot_usage = 64 },
        { input = "minecraft:barrel_51", output = "minecraft:barrel_50", slot_usage = 64 }
    },
    macerator = {
        { input = "minecraft:barrel_8",  output = "minecraft:barrel_7",  slot_usage = 64 },
        { input = "minecraft:barrel_21", output = "minecraft:barrel_22", slot_usage = 64 },
        { input = "minecraft:barrel_45", output = "minecraft:barrel_44", slot_usage = 64 },
        { input = "minecraft:barrel_47", output = "minecraft:barrel_46", slot_usage = 64 }
    },
    compressor = {
        { input = "minecraft:barrel_9",  output = "minecraft:barrel_10", slot_usage = 64 },
        { input = "minecraft:barrel_15", output = "minecraft:barrel_16", slot_usage = 64 },
        { input = "minecraft:barrel_41", output = "minecraft:barrel_40", slot_usage = 64 },
        { input = "minecraft:barrel_43", output = "minecraft:barrel_42", slot_usage = 64 }
    },
    mixer = {
        { input = "minecraft:barrel_11", output = "minecraft:barrel_12", slot_usage = 64 },
        { input = "minecraft:barrel_33", output = "minecraft:barrel_34", slot_usage = 64 },
        { input = "minecraft:barrel_37", output = "minecraft:barrel_36", slot_usage = 64 },
        { input = "minecraft:barrel_39", output = "minecraft:barrel_38", slot_usage = 64 }
    },
    cutter = {
        { input = "minecraft:barrel_13", output = "minecraft:barrel_14", slot_usage = 64 },
        { input = "minecraft:barrel_64", output = "minecraft:barrel_65", slot_usage = 64 }
    },
    wiremill = {
        { input = "minecraft:barrel_56", output = "minecraft:barrel_57", slot_usage = 64 },
        { input = "minecraft:barrel_58", output = "minecraft:barrel_59", slot_usage = 64 }
    },
    polarizer = {
        { input = "minecraft:barrel_60", output = "minecraft:barrel_61", slot_usage = 64 },
        { input = "minecraft:barrel_68", output = "minecraft:barrel_69", slot_usage = 64 }
    },
    assembler = {
        { input = "minecraft:barrel_62", output = "minecraft:barrel_63", slot_usage = 64 },
        { input = "minecraft:barrel_66", output = "minecraft:barrel_67", slot_usage = 64 }
    },
    extractor = {
        { input = "minecraft:barrel_72", output = "minecraft:barrel_73", slot_usage = 64 },
        { input = "minecraft:barrel_74", output = "minecraft:barrel_75", slot_usage = 64 },
        { input = "minecraft:barrel_76", output = "minecraft:barrel_77", slot_usage = 64 },
        { input = "minecraft:barrel_78", output = "minecraft:barrel_79", slot_usage = 64 }
    },
    centrifuge = {
        { input = "minecraft:barrel_80", output = "minecraft:barrel_81", slot_usage = 64 },
        { input = "minecraft:barrel_82", output = "minecraft:barrel_83", slot_usage = 64 }
    },
    electric_blast_furnace = {
        { input = "minecraft:barrel_70", output = "minecraft:barrel_71", slot_usage = 64 },
        { input = "minecraft:barrel_84", output = "minecraft:barrel_85", slot_usage = 64 }
    }
}

rednet.open(REDNET_MODEM_SIDE)

---------- recipes parsing ----------

local function build_recipe(machine, inputs, outputs)
    if type(machine) ~= "string" then
        error("build_recipe: machine name is not a string")
    end

    if type(inputs) ~= "table" then
        error("build_recipe: expected input resources table, got " .. type(inputs))
    end

    if type(outputs) ~= "table" then
        error("build_recipe: expected output resources table, got " .. type(inputs))
    end

    local flat_inputs = {}
    local flat_outputs = {}

    for slot, resource in pairs(inputs) do
        if resource ~= nil then
            if type(resource) ~= "table" then
                error("build_recipe: expected input resource table at slot " .. slot .. ", got " .. type(resource))
            end

            if not resource.name or type(resource.name) ~= "string" then
                error("build_recipe: missing input resource name at slot " .. slot)
            end

            if not resource.count or type(resource.count) ~= "number" then
                error("build_recipe: missing input resource count at slot " .. slot)
            end

            flat_inputs[resource.name] = flat_inputs[resource.name] or {
                name = resource.name,
                count = 0
            }

            flat_inputs[resource.name].count = flat_inputs[resource.name].count + resource.count
        end
    end

    for slot, resource in pairs(outputs) do
        if type(resource) ~= "table" then
            error("build_recipe: expected output resource table at slot " .. slot .. ", got " .. type(resource))
        end

        if not resource.name or type(resource.name) ~= "string" then
            error("build_recipe: missing output resource name at slot " .. slot)
        end

        if not resource.count or type(resource.count) ~= "number" then
            error("build_recipe: missing output resource count at slot " .. slot)
        end

        flat_outputs[resource.name] = flat_outputs[resource.name] or {
            name = resource.name,
            count = 0
        }

        flat_outputs[resource.name].count = flat_outputs[resource.name].count + resource.count
    end

    return {
        machine = machine,
        inputs = {
            layout = inputs,
            flat = flat_inputs
        },
        outputs = {
            layout = outputs,
            flat = flat_outputs
        }
    }
end

local function load_recipes()
    local paths = {}

    for _, drive in ipairs(fs.find("*/recipes")) do
        for _, path in ipairs(fs.find(drive .. "/*.lua")) do
            table.insert(paths, path)
        end

        for _, path in ipairs(fs.find(drive .. "/*/*.lua")) do
            table.insert(paths, path)
        end
    end

    for _, path in ipairs(fs.find("recipes/*.lua")) do
        table.insert(paths, path)
    end

    for _, path in ipairs(fs.find("recipes/*/*.lua")) do
        table.insert(paths, path)
    end

    local recipes = {}

    for _, path in ipairs(paths) do
        local recipe = loadfile(path)()

        -- Load only recipes for which we have machines
        if recipe.machine and MACHINES[recipe.machine] then
            table.insert(recipes, build_recipe(
                recipe.machine,
                recipe.inputs,
                recipe.outputs
            ))
        end
    end

    return recipes
end

---------- auto-craft engine ----------

local function build_recipe_tree(resource, quantity, recipes)
    if not resource or type(resource) ~= "string" then
        error("build_recipe_tree: resource is not a string")
    end

    if not quantity or type(quantity) ~= "number" or quantity < 1 then
        error("build_recipe_tree: quantity is not a positive number")
    end

    if not recipes or type(recipes) ~= "table" then
        error("build_recipe_tree: recipes is not a table")
    end

    for _, recipe in ipairs(recipes) do
        for name, output in pairs(recipe.outputs.flat) do
            if name == resource or name:match(":(.+)$") == resource then
                local leafs = {}
                local executions = math.ceil(quantity / output.count)

                for _, input in pairs(recipe.inputs.flat) do
                    local leaf = build_recipe_tree(
                        input.name,
                        input.count * executions,
                        recipes
                    )

                    if leaf then
                        table.insert(leafs, leaf)
                    end
                end

                return {
                    recipe = recipe,
                    executions = executions,
                    leafs = leafs
                }
            end
        end
    end

    return nil
end

local function truncate_recipe_tree(tree)
    local available_items = {}
    local truncated_items = {}

    for _, item in pairs(peripheral.wrap(MASTER_INVENTORY).items()) do
        if item.name and item.count then
            available_items[item.name] = (available_items[item.name] or 0) + item.count
        end
    end

    local function truncate(node)
        if not node then
            return
        end

        local original_executions = node.executions

        for _, output in pairs(node.recipe.outputs.flat) do
            local available = available_items[output.name]

            if available then
                local covered = math.floor(available / output.count)
                local reduction = math.min(covered, node.executions)

                if reduction > 0 then
                    node.executions = node.executions - reduction

                    local amount = math.floor(reduction * output.count)

                    available_items[output.name] = available - amount
                    truncated_items[output.name] = (truncated_items[output.name] or 0) + amount
                end
            end
        end

        local clean_leafs = {}
        local ratio = original_executions > 0 and (node.executions / original_executions) or 0

        for _, leaf in pairs(node.leafs) do
            if ratio < 1 then
                leaf.executions = math.ceil(leaf.executions * ratio)
            end

            truncate(leaf)

            if leaf.executions > 0 then
                table.insert(clean_leafs, leaf)
            end
        end

        node.leafs = clean_leafs
    end

    truncate(tree)

    return tree, truncated_items
end

local function convert_recipe_tree_into_batches(tree)
    local batches = {}
    local resolved = {}

    while true do
        local batch = {}
        local recipe_map = {}
        local pending = {}

        local function collect(node)
            if not node or resolved[node] or pending[node] then
                return
            end

            local ready = true

            -- A node is ready only if ALL its leafs were resolved in PRIOR
            -- batches, not in the current one. This prevents dependent recipes
            -- from sharing a batch (e.g. plank -> slabs -> barrels in separate
            -- batches).
            for _, child in pairs(node.leafs) do
                if child then
                    if not resolved[child] then
                        if not pending[child] then
                            collect(child)
                        end

                        if not resolved[child] then
                            ready = false
                        end
                    end
                end
            end

            if ready then
                pending[node] = true

                local entry = recipe_map[node.recipe]

                if entry then
                    entry.executions = entry.executions + node.executions
                else
                    entry = {
                        recipe = node.recipe,
                        executions = node.executions,
                    }

                    table.insert(batch, entry)

                    recipe_map[node.recipe] = entry
                end

                return
            end

            for _, child in pairs(node.leafs) do
                collect(child)
            end
        end

        collect(tree)

        if #batch == 0 then
            break
        end

        for node, _ in pairs(pending) do
            resolved[node] = true
        end

        table.insert(batches, batch)
    end

    return batches
end

---------- inventories ----------

local master_inventory  = peripheral.wrap(MASTER_INVENTORY)
local working_inventory = peripheral.wrap(WORKING_INVENTORY)
local buffer_inventory  = peripheral.wrap(BUFFER_INVENTORY)

if not master_inventory then
    error("no master inventory " .. MASTER_INVENTORY)
end

if not working_inventory then
    error("no working inventory " .. WORKING_INVENTORY)
end

if not buffer_inventory then
    error("no buffer inventory " .. BUFFER_INVENTORY)
end

local function move_items_from_working_to_master(name, count)
    -- Push to buffer barrel
    local total = 0

    while total < count do
        local pushed = working_inventory.pushItem(
            BUFFER_INVENTORY,
            name,
            count - total
        )

        if pushed == 0 then
            break
        end

        total = total + pushed
    end

    -- Pull from buffer barrel
    local total_pulled = 0

    while total_pulled < total do
        local pulled = master_inventory.pullItem(
            BUFFER_INVENTORY,
            name,
            total - total_pulled
        )

        if pulled == 0 then
            break
        end

        total_pulled = total_pulled + pulled
    end

    return total_pulled
end

local function move_items_from_master_to_working(name, count)
    -- Push to buffer barrel
    local total = 0

    while total < count do
        local pushed = master_inventory.pushItem(
            BUFFER_INVENTORY,
            name,
            count - total
        )

        if pushed == 0 then
            break
        end

        total = total + pushed
    end

    -- Pull from buffer barrel
    local total_pulled = 0

    while total_pulled < total do
        local pulled = working_inventory.pullItem(
            BUFFER_INVENTORY,
            name,
            total - total_pulled
        )

        if pulled == 0 then
            break
        end

        total_pulled = total_pulled + pulled
    end

    return total_pulled
end

local function move_working_inventory_to_master()
    for _, item in pairs(working_inventory.items()) do
        if item.name and item.count then
            move_items_from_working_to_master(item.name, item.count)
        end
    end
end

local function move_buffer_inventory_to_master()
    for _, item in pairs(buffer_inventory.list()) do
        if item.name and item.count then
            master_inventory.pullItem(BUFFER_INVENTORY, item.name, item.count)
        end
    end
end

local function move_machines_inventories_to_master()
    for _, machines in pairs(MACHINES) do
        for _, machine in ipairs(machines) do
            local input_inventory = peripheral.wrap(machine.input)
            local output_inventory = peripheral.wrap(machine.output)

            if not input_inventory then
                error("no machine input inventory " .. machine.input)
            end

            if not output_inventory then
                error("no machine output inventory " .. machine.output)
            end

            for _, item in pairs(input_inventory.list()) do
                master_inventory.pullItem(machine.input, item.name, item.count)
            end

            for _, item in pairs(output_inventory.list()) do
                master_inventory.pullItem(machine.output, item.name, item.count)
            end
        end
    end
end

---------- user interface ----------

move_working_inventory_to_master()
move_buffer_inventory_to_master()
move_machines_inventories_to_master()

-- User input
local recipe_name, recipe_quantity = ...

if not recipe_name then
    error("no recipe provided")
end

if not recipe_quantity or recipe_quantity == "" then
    recipe_quantity = 1
else
    recipe_quantity = tonumber(recipe_quantity)
end

-- Load recipes
local recipes = load_recipes()

-- Build crafting tree
local recipe_tree = build_recipe_tree(
    recipe_name,
    recipe_quantity,
    recipes
)

if not recipe_tree then
    error("missing crafting recipe")
end

-- Remove already available items from the crafting tree
local recipe_tree, truncated_items = truncate_recipe_tree(recipe_tree)

-- Prepare batches from the crafting tree
local craft_batches = convert_recipe_tree_into_batches(recipe_tree)

for i, batch in ipairs(craft_batches) do
    print("batch #" .. i .. " outputs:")

    for _, entry in ipairs(batch) do
        for _, output in pairs(entry.recipe.outputs.flat) do
            print("- " .. output.name .. " x" .. math.floor(output.count * entry.executions))
        end
    end
end

print()

-- Validate machines presence
for _, batch in ipairs(craft_batches) do
    for _, entry in ipairs(batch) do
        if not MACHINES[entry.recipe.machine] then
            error("missing machine " .. entry.recipe.machine)
        end
    end
end

-- Move crafting ingredients to working inventory
for name, count in pairs(truncated_items) do
    local total_moved = move_items_from_master_to_working(name, count)

    if total_moved < count then
        move_working_inventory_to_master()
        move_buffer_inventory_to_master()

        error("missing resource " .. name .. " x" .. count - total_moved)
    end
end

-- Calculate net raw materials needed across all batches
local total_inputs = {}
local total_outputs = {}

for _, batch in ipairs(craft_batches) do
    for _, entry in ipairs(batch) do
        for name, input in pairs(entry.recipe.inputs.flat) do
            total_inputs[name] = (total_inputs[name] or 0) + input.count * entry.executions
        end

        for name, output in pairs(entry.recipe.outputs.flat) do
            total_outputs[name] = (total_outputs[name] or 0) + output.count * entry.executions
        end
    end
end

for name, count in pairs(total_inputs) do
    local produced = total_outputs[name] or 0
    local deficit = count - produced

    if deficit > 0 then
        for _, item in pairs(working_inventory.items()) do
            if item.name == name then
                deficit = math.max(0, deficit - item.count)
            end
        end

        if deficit > 0 then
            deficit = math.ceil(deficit)

            local moved = move_items_from_master_to_working(name, deficit)

            if moved < deficit then
                move_working_inventory_to_master()
                move_buffer_inventory_to_master()

                error("missing resource " .. name .. " x" .. deficit - moved)
            end
        end
    end
end

-- Execute batches after moving input resources
for i, batch in ipairs(craft_batches) do
    print("% batch #" .. i)

    local pending = {}

    for _, entry in ipairs(batch) do
        pending[entry] = entry.executions
    end

    while true do
        -- Clear all machines in this batch
        for _, entry in ipairs(batch) do
            for _, machine in ipairs(MACHINES[entry.recipe.machine]) do
                -- Loop until barrel is fully cleared
                while true do
                    local input_inventory = peripheral.wrap(machine.input)
                    local found_item = false

                    for _, item in pairs(input_inventory.list()) do
                        working_inventory.pullItem(machine.input, item.name, item.count)

                        found_item = true
                    end

                    local output_inventory = peripheral.wrap(machine.output)

                    for _, item in pairs(output_inventory.list()) do
                        working_inventory.pullItem(machine.output, item.name, item.count)

                        found_item = true
                    end

                    if not found_item then
                        break
                    end
                end
            end
        end

        -- Check if there's any executions pending
        local any_pending = false

        for _, entry in ipairs(batch) do
            if pending[entry] > 0 then
                any_pending = true

                break
            end
        end

        if not any_pending then
            break
        end

        -- Fill machines for all pending entries
        local round_machines = {}
        local round_entry_execs = {}

        -- Group pending entries by machine type
        local machine_type_entries = {}

        for _, entry in ipairs(batch) do
            if pending[entry] > 0 then
                local machine = entry.recipe.machine

                if not machine_type_entries[machine] then
                    machine_type_entries[machine] = {}
                end

                table.insert(machine_type_entries[machine], entry)
            end
        end

        for machine, entries in pairs(machine_type_entries) do
            local machines = MACHINES[machine]
            local remaining = {}

            for _, entry in ipairs(entries) do
                remaining[entry] = pending[entry]
            end

            -- Single recipe: parallelize across all machines
            if #entries == 1 then
                local entry = entries[1]
                local machine_count = #machines

                for idx, machine in ipairs(machines) do
                    if remaining[entry] <= 0 then
                        break
                    end

                    local machines_left = machine_count - idx + 1
                    local curr_executions = math.ceil(remaining[entry] / machines_left)

                    for _, input in pairs(entry.recipe.inputs.flat) do
                        curr_executions = math.min(
                            curr_executions,
                            math.floor(machine.slot_usage / input.count)
                        )
                    end

                    for _, output in pairs(entry.recipe.outputs.flat) do
                        curr_executions = math.min(
                            curr_executions,
                            math.floor(machine.slot_usage / output.count)
                        )
                    end

                    if curr_executions > 0 then
                        for _, output in pairs(entry.recipe.outputs.flat) do
                            print("- " .. output.name .. " x" .. math.floor(output.count * curr_executions))
                        end

                        for name, input in pairs(entry.recipe.inputs.flat) do
                            working_inventory.pushItem(
                                machine.input,
                                name,
                                input.count * curr_executions
                            )
                        end

                        machine.layout = {}

                        for slot, resource in pairs(entry.recipe.inputs.layout) do
                            if resource then
                                machine.layout[slot] = {
                                    name = resource.name,
                                    count = resource.count * curr_executions,
                                }
                            end
                        end

                        table.insert(round_machines, machine)

                        round_entry_execs[entry] = (round_entry_execs[entry] or 0) + curr_executions
                        remaining[entry] = remaining[entry] - curr_executions
                    end
                end

            -- Multiple recipes: one machine per entry round-robin
            else
                for _, machine in ipairs(machines) do
                    local entry = nil

                    for _, curr_entry in ipairs(entries) do
                        if remaining[curr_entry] > 0 then
                            entry = curr_entry

                            break
                        end
                    end

                    if not entry then
                        break
                    end

                    local curr_executions = remaining[entry]

                    for _, input in pairs(entry.recipe.inputs.flat) do
                        curr_executions = math.min(
                            curr_executions,
                            math.floor(machine.slot_usage / input.count)
                        )
                    end

                    for _, output in pairs(entry.recipe.outputs.flat) do
                        curr_executions = math.min(
                            curr_executions,
                            math.floor(machine.slot_usage / output.count)
                        )
                    end

                    if curr_executions > 0 then
                        for _, output in pairs(entry.recipe.outputs.flat) do
                            print("- " .. output.name .. " x" .. math.floor(output.count * curr_executions))
                        end

                        for name, input in pairs(entry.recipe.inputs.flat) do
                            working_inventory.pushItem(
                                machine.input,
                                name,
                                input.count * curr_executions
                            )
                        end

                        machine.layout = {}

                        for slot, resource in pairs(entry.recipe.inputs.layout) do
                            if resource then
                                machine.layout[slot] = {
                                    name = resource.name,
                                    count = resource.count * curr_executions,
                                }
                            end
                        end

                        table.insert(round_machines, machine)

                        round_entry_execs[entry] = (round_entry_execs[entry] or 0) + curr_executions
                        remaining[entry] = remaining[entry] - curr_executions
                    end
                end
            end

            for _, entry in ipairs(entries) do
                pending[entry] = remaining[entry]
            end
        end

        if #round_machines == 0 then
            move_working_inventory_to_master()
            move_buffer_inventory_to_master()
            move_machines_inventories_to_master()

            error("cannot fit any executions in machines")
        end

        -- Process auto (non-crafter) machines: wait for outputs
        local auto_machines = {}
        local auto_expected = {}

        for entry, execs in pairs(round_entry_execs) do
            if entry.recipe.machine ~= "crafter" then
                for name, output in pairs(entry.recipe.outputs.flat) do
                    auto_expected[name] = (auto_expected[name] or 0) + math.floor(output.count * execs)
                end
            end
        end

        for _, machine in ipairs(round_machines) do
            if not machine.id then
                table.insert(auto_machines, machine)
            end
        end

        if next(auto_expected) then
            local waited_seconds = 0
            local outputs_ready = false

            while waited_seconds < MACHINES_TIMEOUT do
                local current = {}

                for _, machine in ipairs(auto_machines) do
                    local inventory = peripheral.wrap(machine.output)

                    for _, item in pairs(inventory.list()) do
                        current[item.name] = (current[item.name] or 0) + item.count
                    end
                end

                outputs_ready = true

                for name, need in pairs(auto_expected) do
                    if (current[name] or 0) < need then
                        outputs_ready = false

                        break
                    end
                end

                if outputs_ready then
                    break
                end

                os.sleep(1)

                waited_seconds = waited_seconds + 1
            end

            if not outputs_ready then
                move_working_inventory_to_master()
                move_buffer_inventory_to_master()
                move_machines_inventories_to_master()

                error("processing timeout")
            end
        end

        -- Process crafter machines (send layout, wait for reply)
        local reply_count = 0

        for _, machine in ipairs(round_machines) do
            if machine.layout and machine.id then
                rednet.send(machine.id, machine.layout)

                machine.layout = nil

                reply_count = reply_count + 1
            end
        end

        while reply_count > 0 do
            rednet.receive(MACHINES_TIMEOUT)

            reply_count = reply_count - 1
        end
    end
end

-- Move crafting results to master inventory
move_working_inventory_to_master()
move_buffer_inventory_to_master()
move_machines_inventories_to_master()
