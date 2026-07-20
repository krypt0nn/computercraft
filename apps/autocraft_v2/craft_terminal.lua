local REDNET_MODEM_SIDE = "top"
local MASTER_INVENTORY  = "toms_storage:ts.inventory_connector_0"
local WORKING_INVENTORY = "toms_storage:ts.inventory_connector_2"

local MACHINES = {
    crafter = {
        { input = "minecraft:barrel_1", output = "minecraft:barrel_2" }
    },
    furnace = {
        { input = "minecraft:barrel_1", output = "minecraft:barrel_2" },
        { input = "minecraft:barrel_1", output = "minecraft:barrel_2" }
    }
}

---------- recipes parsing ----------

-- [1] [2] [3]
-- [4] [5] [6]
-- [7] [8] [9]
function build_recipe(machine, inputs, outputs)
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

function build_recipe_tree(resource, quantity, recipes)
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

function truncate_recipe_tree(tree)
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

        for _, output in pairs(node.recipe.outputs.flat) do
            local available = available_items[output.name]

            if available then
                local covered = math.floor(available / output.count)
                local reduction = math.min(covered, node.executions)

                if reduction > 0 then
                    node.executions = node.executions - reduction

                    local amount = reduction * output.count

                    available_items[output.name] = available - amount
                    truncated_items[output.name] = (truncated_items[output.name] or 0) + amount
                end
            end
        end

        local clean_leafs = {}

        for _, leaf in pairs(node.leafs) do
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

function convert_recipe_tree_into_batches(tree)
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

---------- user interface ----------

while true do
    -- Move items from working to master inventory
    local master_inventory = peripheral.wrap(MASTER_INVENTORY)
    local working_inventory = peripheral.wrap(WORKING_INVENTORY)

    for _, item in pairs(working_inventory.items()) do
        master_inventory.pullItem(WORKING_INVENTORY, item.name, item.count)
    end

    -- Prompt crafting recipe and quantity
    print()

    io.write("$ ")

    local recipe_name, recipe_quantity = string.match(io.read(), "^(%S+)%s*(.*)$")

    print()

    -- Read craft name
    if not recipe_name then
        print("invalid name")
    else
        -- Read craft quantity
        if not recipe_quantity or recipe_quantity == "" then
            recipe_quantity = 1
        else
            recipe_quantity = tonumber(recipe_quantity)
        end

        if not recipe_quantity or recipe_quantity < 1 then
            print("invalid quantity")
        else
            -- Load recipes
            local recipes = load_recipes()

            -- Build crafting tree
            local recipe_tree = build_recipe_tree(
                recipe_name,
                recipe_quantity,
                recipes
            )

            if not recipe_tree then
                print("recipe is missing")
            else
                -- Remove already available items from the crafting tree
                local recipe_tree, truncated_items = truncate_recipe_tree(recipe_tree)

                -- Prepare batches from the crafting tree
                local craft_batches = convert_recipe_tree_into_batches(recipe_tree)

                for i, batch in ipairs(craft_batches) do
                    print("batch " .. i .. " outputs:")

                    for _, entry in ipairs(batch) do
                        for _, output in pairs(entry.recipe.outputs.flat) do
                            print(" - " .. output.name .. "  x" .. output.count * entry.executions)
                        end
                    end
                end

                -- Move crafting ingredients to working inventory
                local can_craft = true

                for name, count in pairs(truncated_items) do
                    local moved = working_inventory.pullItem(
                        MASTER_INVENTORY,
                        name,
                        count
                    )

                    if moved < count then
                        print("missing " .. name .. " x" .. count - moved)

                        can_craft = false

                        break
                    end
                end

                if can_craft then
                    for _, batch in ipairs(craft_batches) do
                        if not can_craft then
                            break
                        end

                        local inputs_needed = {}

                        for _, entry in ipairs(batch) do
                            for name, input in pairs(entry.recipe.inputs.flat) do
                                inputs_needed[name] = (inputs_needed[name] or 0) + input.count * entry.executions
                            end
                        end

                        for _, item in pairs(working_inventory.items()) do
                            local needed = inputs_needed[item.name]

                            if needed then
                                inputs_needed[item.name] = math.max(0, needed - item.count)
                            end
                        end

                        for name, deficit in pairs(inputs_needed) do
                            if deficit > 0 then
                                local moved = working_inventory.pullItem(MASTER_INVENTORY, name, deficit)

                                if moved < deficit then
                                    print("missing " .. name .. " x" .. deficit - moved)

                                    can_craft = false

                                    break
                                end
                            end
                        end

                        -- Execute batches
                        if can_craft then
                            return
                        end
                    end
                end
            end
        end
    end
end
