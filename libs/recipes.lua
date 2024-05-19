local function info()
    return {
        version = 33
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
    if type(params.recipe) ~= "table" then
        error("Incorrect params format: no recipe provided")
    end

    if type(params.result) ~= "table" then
        error("Incorrect params format: no result provided")
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

-- Prepare processing recipe
-- Mostly needed for mods integration
-- 
-- local iron_plates = process({
--     name = "compressor",
--     input = {
--         { name = "minecraft:iron_ingot", count = 1 }
--     },
--     output = {
--         { name = "modern_industrialization:iron_plate", count = 1 }
--     }
-- })
local function process(params)
    if not params.name then
        error("Incorrect params format: no machine name provided")
    end

    if type(params.input) ~= "table" then
        error("Incorrect params format: no input provided")
    end

    if type(params.output) ~= "table" then
        error("Incorrect params format: no output provided")
    end

    local input  = {}
    local output = {}

    -- Prepare input
    for _, item in pairs(params.input) do
        if item.name and item.count then
            value = input[item.name] or {
                name  = item.name,
                count = 0
            }

            value.count = value.count + item.count

            input[item.name] = value
        end
    end

    -- Prepare output
    for _, item in pairs(params.output) do
        if item.name and item.count then
            value = output[item.name] or {
                name  = item.name,
                count = 0
            }

            value.count = value.count + item.count

            output[item.name] = value
        end
    end

    return {
        action = "process",
        input  = input,
        output = output,
        params = {
            name   = params.name,
            input  = params.input,
            output = params.output
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
            local file_recipes = loadfile(path)()

            if type(file_recipes) == "function" then
                file_recipes = file_recipes({
                    info    = info,
                    craft   = craft,
                    process = process
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
                    count  = output.count
                })

                break
            end
        end
    end

    return foundRecipes
end

-- Try to find the most optimal recipe execution queue
-- to craft an item from available resources
local function findRecipeExecutionQueue(available, item, count, folders)
    local recipeHints = {}

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

                        -- Put required item to the hints
                        table.insert(recipeHints, {
                            name  = input.name,
                            count = craft
                        })

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
    return nil, recipeHints
end

-- Get crafting dependency tree from the queue
local function getQueueDependencyTree(queue)
    local tree = {}

    for _, recipe in pairs(queue) do
        for _, output in pairs(recipe.output) do
            local value = tree[output.name] or {
                name       = output.name,
                count      = output.count,
                input      = recipe.input,
                recipe     = recipe,
                multiplier = 0
            }

            value.multiplier = value.multiplier + 1

            tree[output.name] = value
        end
    end

    return tree
end

-- Convert dependency tree to the dependency queue
-- starting from the [name] item
local function resolveDependencyTree(tree, name)
    local queue = {}

    if tree[name] then
        table.insert(queue, tree[name])
    else
        for key, value in pairs(tree) do
            if string.find(key, name) then
                table.insert(queue, value)

                break
            end
        end
    end

    local i = 1

    while queue[i] do
        -- To prevent recursions
        tree[queue[i].name].used = i

        for _, input in pairs(tree[queue[i].name].input) do
            if tree[input.name] then
                table.insert(queue, tree[input.name])

                if tree[input.name].used then
                    queue[tree[input.name].used] = nil
                end

                tree[input.name].used = #queue
            end
        end

        i = i + 1
    end

    local cleanQueue = {}

    for _, recipe in pairs(queue) do
        if recipe then
            table.insert(cleanQueue, recipe)
        end
    end

    return cleanQueue
end

-- Clone given table
local function cloneTable(original)
	local copy = {}

	for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = cloneTable(value)
        else
            copy[key] = value
        end
	end

	return copy
end

-- Check if we can add original recipe to given
local function canBatchRecipe(recipe, original)
    -- Verify that all the inputs are lower than a full stack
    for _, input in pairs(original.input) do
        if recipe.input[input.name].count + input.count > 64 then
            return false
        end
    end

    for _, output in pairs(original.output) do
        if recipe.output[output.name].count + output.count > 64 then
            return false
        end
    end

    -- Verify that processing machine is the same
    if recipe.action == "process" and recipe.params.name ~= original.params.name then
        return false
    end

    return true
end

-- Add original recipe to given
local function batchRecipe(recipe, original)
    -- Batch standard input and output
    for _, input in pairs(original.input) do
        recipe.input[input.name].count = recipe.input[input.name].count + input.count
    end

    for _, output in pairs(original.output) do
        recipe.output[output.name].count = recipe.output[output.name].count + output.count
    end

    -- Batch crafting recipe
    if recipe.action == "craft" then
        for i, resource in pairs(original.params.recipe) do
            recipe.params.recipe[i].count = recipe.params.recipe[i].count + resource.count
        end

    -- Batch processing inputs and outputs
    elseif recipe.action == "process" then
        for i, resource in pairs(original.params.input) do
            recipe.params.input[i].count = recipe.params.input[i].count + resource.count
        end

        for i, resource in pairs(original.params.output) do
            recipe.params.output[i].count = recipe.params.output[i].count + resource.count
        end

    -- Unsupported action
    else
        error("Can't batch recipe: unsupported recipe action: " .. recipe.action)
    end

    return recipe
end

-- Batch-optimize found crafting queue around given output name
local function batchRecipeExecutionQueue(queue, name)
    local dependencies = getQueueDependencyTree(queue)
    local dependenciesQueue = resolveDependencyTree(dependencies, name)

    local queue = {}

    for _, step in pairs(dependenciesQueue) do
        local repeats = 0

        while repeats < step.multiplier do
            local batchedRecipe = cloneTable(step.recipe)

            repeats = repeats + 1

            while repeats < step.multiplier do
                -- Break current batched recipe if can't continue
                if not canBatchRecipe(batchedRecipe, step.recipe) then
                    break
                end

                -- Batch recipe
                batchedRecipe = batchRecipe(batchedRecipe, step.recipe)

                repeats = repeats + 1
            end

            table.insert(queue, batchedRecipe)
        end
    end

    local revQueue = {}

    for i = 1, #queue do
        table.insert(revQueue, queue[#queue - i + 1])
    end

    return revQueue
end

return {
    info = info,
    craft = craft,
    recipes = recipes,
    findRecipes = findRecipes,
    findRecipeExecutionQueue = findRecipeExecutionQueue,
    getQueueDependencyTree = getQueueDependencyTree,
    resolveDependencyTree = resolveDependencyTree,
    canBatchRecipe = canBatchRecipe,
    batchRecipe = batchRecipe,
    batchRecipeExecutionQueue = batchRecipeExecutionQueue
}
