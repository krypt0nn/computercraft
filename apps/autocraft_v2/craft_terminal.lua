local REDNET_MODEM_SIDE = "top"
local MASTER_INVENTORY  = "toms_storage:ts.inventory_connector_3"
local WORKING_INVENTORY = "toms_storage:ts.inventory_connector_4"

local MACHINES_TIMEOUT = 600

local MACHINES = {
    crafter = {
        { input = "minecraft:barrel_4",  output = "minecraft:barrel_3",  id = 1, slot_usage = 64 },
        { input = "minecraft:barrel_17", output = "minecraft:barrel_18", id = 2, slot_usage = 64 }
    },
    furnace = {
        { input = "minecraft:barrel_6", output = "minecraft:barrel_5", slot_usage = 64 }
    },
    macerator = {
        { input = "minecraft:barrel_8", output = "minecraft:barrel_7", slot_usage = 64 }
    },
    compressor = {
        { input = "minecraft:barrel_9",  output = "minecraft:barrel_10", slot_usage = 64 },
        { input = "minecraft:barrel_15", output = "minecraft:barrel_16", slot_usage = 64 }
    },
    mixer = {
        { input = "minecraft:barrel_11", output = "minecraft:barrel_12", slot_usage = 64 }
    },
    cutter = {
        { input = "minecraft:barrel_13", output = "minecraft:barrel_14", slot_usage = 64 }
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
    local recipes = {}

    for _, drive in ipairs(fs.find("*/recipes")) do
        for _, path in ipairs(fs.find(drive .. "/*.lua")) do
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

        local function collect(node)
            if not node or resolved[node] then
                return
            end

            local ready = true

            for _, child in pairs(node.leafs) do
                if child and not resolved[child] then
                    ready = false

                    break
                end
            end

            if ready then
                resolved[node] = true

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

        table.insert(batches, batch)
    end

    return batches
end

---------- inventories ----------

local master_inventory = peripheral.wrap(MASTER_INVENTORY)
local working_inventory = peripheral.wrap(WORKING_INVENTORY)

local function move_working_inventory_to_master()
    for _, item in pairs(working_inventory.items()) do
        if item.name and item.count then
            master_inventory.pullItem(WORKING_INVENTORY, item.name, item.count)
        end
    end
end

local function move_machines_inventories_to_master()
    for _, machines in pairs(MACHINES) do
        for _, machine in ipairs(machines) do
            local input_inventory = peripheral.wrap(machine.input)
            local output_inventory = peripheral.wrap(machine.output)

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
    local moved = working_inventory.pullItem(MASTER_INVENTORY, name, count)

    if moved < count then
        move_working_inventory_to_master()

        error("missing resource " .. name .. " x" .. count - moved)
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

            local moved = working_inventory.pullItem(MASTER_INVENTORY, name, deficit)

            if moved < deficit then
                move_working_inventory_to_master()

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
        local claimed = {}

        for _, entry in ipairs(batch) do
            if pending[entry] > 0 then
                local machines = MACHINES[entry.recipe.machine]
                local remaining = pending[entry]

                for _, machine in ipairs(machines) do
                    if not claimed[machine] then
                        local curr_executions = remaining

                        for _, input in pairs(entry.recipe.inputs.flat) do
                            curr_executions = math.min(
                                curr_executions,
                                math.floor(machine.slot_usage / input.count)
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

                            local layout = {}

                            for slot, resource in pairs(entry.recipe.inputs.layout) do
                                if resource then
                                    layout[slot] = {
                                        name = resource.name,
                                        count = resource.count * curr_executions
                                    }
                                end
                            end

                            machine.layout = layout

                            claimed[machine] = true

                            table.insert(round_machines, machine)

                            remaining = remaining - curr_executions

                            pending[entry] = pending[entry] - curr_executions
                            round_entry_execs[entry] = (round_entry_execs[entry] or 0) + curr_executions
                        end

                        if remaining <= 0 then
                            break
                        end
                    end
                end
            end
        end

        if #round_machines == 0 then
            move_working_inventory_to_master()
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
move_machines_inventories_to_master()
