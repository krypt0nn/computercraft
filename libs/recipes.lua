local function info()
    return {
        version = 5
    }
end

-- Prepare crafting recipe
-- 
-- local planks = craft({
--     recipe = {
--         { name = "minecraft:spruce_log", count = 1 }
--     },
--     result = {
--         name  = "minecraft:spruce_planks",
--         count = 4
--     }
-- })
local function craft(params)
    if not params.recipe then
        error("Incorrect params format: no recipe provided")
    end

    local input  = {}
    local output = {}

    for _, item in pairs(params.recipe) do
        if item.name and item.count then
            value = input[item.name] or {
                name  = item.name,
                count = 0
            }

            value.count = value.count + item.count

            input[item.name] = value
        end
    end

    table.insert(output, {
        name  = params.result.name,
        count = params.result.count
    })

    return {
        action = "craft",
        input  = input,
        output = output,
        params = {
            recipe = params.recipe
        }
    }
end

-- List all known recipes
local function recipes()
    return {
        -- Planks
        craft({
            recipe = {
                { name = "minecraft:spruce_log", count = 1 }
            },
            result = {
                name  = "minecraft:spruce_planks",
                count = 4
            }
        }),

        -- Chest
        craft({
            recipe = {
                { name = "minecraft:spruce_planks", count = 1 },
                { name = "minecraft:spruce_planks", count = 1 },
                { name = "minecraft:spruce_planks", count = 1 },
                { name = "minecraft:spruce_planks", count = 1 },
                nil,
                { name = "minecraft:spruce_planks", count = 1 },
                { name = "minecraft:spruce_planks", count = 1 },
                { name = "minecraft:spruce_planks", count = 1 },
                { name = "minecraft:spruce_planks", count = 1 }
            },
            result = {
                name  = "minecraft:chest",
                count = 1
            }
        })
    }
end

-- Find recipes which produce given item
local function findRecipes(item)
    local foundRecipes = {}

    for _, recipe in pairs(recipes()) do
        for _, output in pairs(recipe.output) do
            if string.find(output.name, item) then
                table.insert(foundRecipes, recipe)

                break
            end
        end
    end

    return foundRecipes
end

-- Try to find the most optimal recipe execution queue
-- to craft an item from available resources
local function findRecipeExecutionQueue(available, item) -- TODO: quantity (craft)
    for _, recipe in pairs(findRecipes(item)) do
        local remainingResources = available

        local queue = {
          recipe
        }

        local correctRecipe = true

        for _, input in pairs(recipe.input) do
            local craft = 0

            if not remainingResources[input.name] then
                craft = input.count
            elseif input.count > remainingResources[input.name].count then
                craft = input.count - remainingResources[input.name].count

                remainingResources[input.name].count = 0
            else
                remainingResources[input.name].count = remainingResources[input.name].count - input.count
            end

            -- TODO: respect craft variable
            if craft > 0 then
                local inputCraftQueue = findRecipeExecutionQueue(remainingResources, input.name)

                if not inputCraftQueue then
                    correctRecipe = false

                    break
                end

                for _, oldQueue in pairs(queue) do
                    table.insert(inputCraftQueue, oldQueue)
                end

                queue = inputCraftQueue
            end
        end

        if correctRecipe then
            return queue
        end
    end

    return nil
end

return {
    info = info,
    craft = craft,
    recipes = recipes,
    findRecipes = findRecipes,
    findRecipeExecutionQueue = findRecipeExecutionQueue
}
