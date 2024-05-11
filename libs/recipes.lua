local function info()
    return {
        version = 1
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
            table.insert(input, {
                name  = item.name,
                count = item.count
            })
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
    local recipes = {}

    for _, recipe in pairs(recipes()) do
        for _, output in pairs(recipe.output) do
            if string:find(output.name, item) then
                table.insert(recipes, recipe)

                break
            end
        end
    end

    return recipes
end

return {
    info = info,
    craft = craft,
    recipes = recipes,
    findRecipes = findRecipes
}
