local function info()
    return {
        version = 53
    }
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

local recipesCache = {}

-- List all recipes from the given folders
-- If none given, searches through the "recipes" and "disk/recipes"
local function recipes(folders, cache)
    local recipes = {}

    if not folders then
        folders = { "recipes", "disk/recipes" }
    end

    if type(folders) ~= "table" then
        folders = { folders }
    end

    for _, folder in pairs(folders) do
        for _, path in pairs(fs.find(folder .. "/*.lua")) do
            if not recipesCache[path] then
                local fileRecipes = loadfile(path)()

                if type(fileRecipes) == "function" then
                    fileRecipes = fileRecipes({
                        info    = info,
                        craft   = craft,
                        process = process
                    })
                end
    
                if type(fileRecipes) ~= "table" then
                    error("Wrong recipes format in file [" .. path .. "]. Expected table or function, got " .. type(fileRecipes))
                end

                recipesCache[path] = fileRecipes
            end

            for _, recipe in pairs(recipesCache[path]) do
                table.insert(recipes, recipe)
            end
        end
    end

    return recipes
end

-- Find recipes which produce given item
local function findRecipes(item, folders)
    local foundRecipes = {}

    -- If we have a colon in item name - it must be
    -- a full ID string, so we need to compare them directly
    local strict = string.find(item, ":")

    for _, recipe in pairs(recipes(folders)) do
        for _, output in pairs(recipe.output) do
            if (strict and output.name == item) or (not strict and string.match(output.name, item)) then
                table.insert(foundRecipes, {
                    name   = output.name,
                    count  = output.count,
                    recipe = recipe
                })

                break
            end
        end
    end

    return foundRecipes
end

-- Build item crafting queue using list of available resources
-- and paths to search for recipes in
local function buildItemCraftingQueue(item, count, availableResources, recipesFolders)
    local recipes = findRecipes(item, recipesFolders)

    -- If no recipes found for given item
    if not recipes or #recipes == 0 then
        return nil, {
            {
                name     = item,
                count    = count,
                subhints = nil
            }
        }
    end

    local hints = {}

    -- This function will expect its first recipe to be recurrent, but
    -- other recipes will be tried to be executed on a stack
    for _, recipe in pairs(recipes) do
        local remainingResources = cloneTable(availableResources)

        -- Amount of times we need to execute this recipe
        recipe.multiplier = math.ceil(count / recipe.count)

        local craftingQueue = {}
        local recipesQueue = { recipe }

        local correctCraft = true

        local i = 1

        -- Iterate over recipes stack
        while recipesQueue[i] do
            table.insert(craftingQueue, recipesQueue[i])

            for _, input in pairs(recipesQueue[i].recipe.input) do
                -- Real amount of input resources we need to have
                local multipliedInputCount = recipesQueue[i].multiplier * input.count

                -- Calculate amount of input resource needed to craft
                local inputCraftNeeded = 0

                -- If none available - craft needed amount
                if not remainingResources[input.name] then
                    inputCraftNeeded = multipliedInputCount

                -- If more than available needed - craft what's absent
                elseif multipliedInputCount > remainingResources[input.name].count then
                    inputCraftNeeded = multipliedInputCount - remainingResources[input.name].count

                    remainingResources[input.name].count = 0

                -- Otherwise we have just enough resources so only need
                -- to decreese their remaining value
                else
                    remainingResources[input.name].count = remainingResources[input.name].count - multipliedInputCount
                end

                -- If we need to craft anything
                if inputCraftNeeded > 0 then
                    local inputRecipes = findRecipes(input.name, recipesFolders)

                    -- If no recipes found for given item
                    if not inputRecipes or #inputRecipes == 0 then
                        table.insert(hints, {
                            name     = input.name,
                            count    = multipliedInputCount,
                            subhints = nil
                        })

                        correctCraft = false

                        break
                    end

                    -- Put recipe on a stack if there's only one
                    if #inputRecipes == 1 then
                        inputRecipes[1].multiplier = math.ceil(multipliedInputCount / inputRecipes[1].count)

                        table.insert(recipesQueue, inputRecipes[1])

                    -- Otherwise find input's crafting queue recurrently
                    else
                        local inputCraftingQueue, inputRecipeHints = buildItemCraftingQueue(
                            input.name,
                            multipliedInputCount,
                            remainingResources,
                            recipesFolders
                        )

                        -- If couldn't find the queue - panic
                        if not inputCraftingQueue then
                            table.insert(hints, {
                                name     = input.name,
                                count    = multipliedInputCount,
                                subhints = inputRecipeHints
                            })

                            correctCraft = false

                            break
                        end

                        for _, craft in pairs(inputCraftingQueue) do
                            table.insert(craftingQueue, craft)
                        end
                    end
                end
            end

            if not correctCraft then
                break
            end

            i = i + 1
        end

        if correctCraft then
            return craftingQueue
        end
    end

    return nil, hints
end

-- Check if given crafting queue is optimal
local function craftingQueueIsOptimal(queue)
    local usedCrafts = {}

    for _, action in pairs(queue) do
        -- TODO: Not really > 1, better say if it doesn't have
        --       *full stack* inputs/outputs AND has multiplier > 1
        if usedCrafts[action.name] or action.multiplier > 1 then
            return false
        end

        usedCrafts[action.name] = true
    end

    return true
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

-- Run inline optimizer on given crafting queue
local function inlineOptimizer(queue)
    local optimizedQueue = {}

    for _, action in pairs(queue) do
        local repeats = 0

        while repeats < action.multiplier do
            local batchedRecipe = cloneTable(action.recipe)
            local localRepeats  = repeats

            repeats = repeats + 1

            while repeats < action.multiplier do
                -- Break current batched recipe if can't continue
                if not canBatchRecipe(batchedRecipe, action.recipe) then
                    break
                end

                -- Batch recipe
                batchedRecipe = batchRecipe(batchedRecipe, action.recipe)

                repeats = repeats + 1
            end

            table.insert(optimizedQueue, {
                name       = action.name,
                recipe     = batchedRecipe,
                count      = action.count * (repeats - localRepeats),
                multiplier = 1
            })
        end
    end

    return optimizedQueue
end

-- TODO: rewrite to work with buildItemCraftingQueue
-- Get crafting dependency tree from the queue
local function getQueueDependencyTree(queue)
    local tree = {}

    print("[getQueueDependencyTree] DEPRECATED, MUSTN'T BE USED")

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

-- TODO: rewrite to work with buildItemCraftingQueue
-- Convert dependency tree to the dependency queue
-- starting from the [name] item
local function resolveDependencyTree(tree, name)
    local queue = {}

    print("[resolveDependencyTree] DEPRECATED, MUSTN'T BE USED")

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

-- TODO: rewrite to work with buildItemCraftingQueue
-- Batch-optimize found crafting queue around given output name
local function batchRecipeExecutionQueue(queue, name)
    local dependencies = getQueueDependencyTree(queue)
    local dependenciesQueue = resolveDependencyTree(dependencies, name)

    print("[batchRecipeExecutionQueue] DEPRECATED, MUSTN'T BE USED")

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

    -- Crafting queue
    buildItemCraftingQueue = buildItemCraftingQueue,
    craftingQueueIsOptimal = craftingQueueIsOptimal,

    -- Optmizers
    inlineOptimizer = inlineOptimizer,

    -- Service functions
    canBatchRecipe = canBatchRecipe,
    batchRecipe = batchRecipe,

    -- Deprecated functions
    getQueueDependencyTree = getQueueDependencyTree,
    resolveDependencyTree = resolveDependencyTree,
    batchRecipeExecutionQueue = batchRecipeExecutionQueue
}
