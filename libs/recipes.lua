local function info()
    return {
        version = 13
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

    output[params.result.name] = {
        name  = params.result.name,
        count = params.result.count
    }

    return {
        action = "craft",
        input  = input,
        output = output,
        params = {
            recipe = params.recipe
        }
    }
end

-- List all recipes from the given folders
-- If none given, searches through the "recipes" and "disk/recipes"
local function recipes(folders)
    local recipes = {}

    if not folders then
        folders = { "recipes", "disk/recipes" }
    end

    if type(folders) ~= "table" then
        folders = { folders }
    end

    for _, folder in pairs(folders) do
        for _, path in pairs(fs.find(folder .. "/*.lua")) do
            local file_recipes = loadfile(path)

            if type(file_recipes) == "function" then
                file_recipes = file_recipes({
                    info  = info,
                    craft = craft
                })
            end

            if type(file_recipes) ~= "table" then
                error("Wrong recipes format in file [" .. path .. "]. Expected table or function, got " .. type(file_recipes))
            end

            for _, recipe in pairs(file_recipes) do
                table.insert(recipes, recipe)
            end
        end
    end

    return recipes
end

-- Find recipes which produce given item
local function findRecipes(item, folders)
    local foundRecipes = {}

    for _, recipe in pairs(recipes(folders)) do
        for _, output in pairs(recipe.output) do
            if string.find(output.name, item) then
                table.insert(foundRecipes, {
                    recipe = recipe,
                    count = output.count
                })

                break
            end
        end
    end

    return foundRecipes
end

-- TODO: add recipes crafting optimization
--       as the last step before returning the final queue
--       (craft stacks of items instead of one-by-one)

-- Try to find the most optimal recipe execution queue
-- to craft an item from available resources
local function findRecipeExecutionQueue(available, item, count, folders)
    -- Try to find known recipes for needed item
    for _, recipe in pairs(findRecipes(item, folders)) do
        local remainingResources = available

        local queue = {}
        local correctQueue = true

        -- Put crafts to the queue to get needed amount of items
        for i = 1, math.ceil(count / recipe.count) do
            local correctRecipe = true

            -- Go through recipe input resources
            for _, input in pairs(recipe.recipe.input) do
                local craft = 0

                -- If none available - craft needed amount
                if not remainingResources[input.name] then
                    craft = input.count

                -- If more than available needed - craft what's absent
                elseif input.count > remainingResources[input.name].count then
                    craft = input.count - remainingResources[input.name].count

                    remainingResources[input.name].count = 0

                -- Otherwise we have just enough resources so only need
                -- to decreese their remaining value
                else
                    remainingResources[input.name].count = remainingResources[input.name].count - input.count
                end

                -- If we need to craft anything
                if craft > 0 then
                    -- Prepare needed resources crafting queue
                    local inputCraftQueue = findRecipeExecutionQueue(remainingResources, input.name, craft)

                    -- Stop search if it's not available
                    if not inputCraftQueue then
                        correctRecipe = false

                        break
                    end

                    -- Otherwise merge the queues
                    for _, inputCraftRecipe in pairs(inputCraftQueue) do
                        table.insert(queue, inputCraftRecipe)
                    end
                end
            end

            -- Stop search if the recipe is incorrect
            if not correctRecipe then
                correctQueue = false

                break
            end

            -- Put the recipe to the queue otherwise
            table.insert(queue, recipe.recipe)
        end

        -- Return prepared craft queue if everything is correct
        if correctQueue then
            return queue
        end
    end

    -- Recipe wasn't found
    return nil
end

return {
    info = info,
    craft = craft,
    recipes = recipes,
    findRecipes = findRecipes,
    findRecipeExecutionQueue = findRecipeExecutionQueue
}
