local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        inventory = {
            minimalVersion = 16
        },
        crafter = {
            minimalVersion = 8
        }
    }
})

local function info()
    return {
        version = 1
    }
end

-- Convert recipe type to the executer role
local function taskToRole(task)
    return {
        craft   = "crafter",
        process = "processer"
    }[task]
end

-- Convert executer role to the recipe type
local function roleToTask(role)
    return {
        crafter   = "craft",
        processer = "process"
    }[task]
end

-- Create an executer of the "craft" recipe types
local function crafter(turtleId, inputInventory, outputInventory)
    if not packages.inventory.isInventory(inputInventory) then
        error("Can't register crafter with id [" .. turtleId .. "]: wrong input inventory: [" .. inputInventory .. "]")
    end

    if not packages.inventory.isInventory(outputInventory) then
        error("Can't register crafter with id [" .. turtleId .. "]: wrong output inventory: [" .. outputInventory .. "]")
    end

    return {
        role   = "crafter",
        input  = inputInventory,
        output = outputInventory,
        params = {
            turtleId = tonumber(turtleId)
        }
    }
end

-- Create an executer of the "process" recipe types
local function processer(inputInventory, outputInventory)
    if not packages.inventory.isInventory(inputInventory) then
        error("Can't register processer: wrong input inventory: [" .. inputInventory .. "]")
    end

    if not packages.inventory.isInventory(outputInventory) then
        error("Can't register processer: wrong output inventory: [" .. outputInventory .. "]")
    end

    return {
        role   = "processer",
        input  = inputInventory,
        output = outputInventory
    }
end

-- Create pool of tasks executers
local function pool(executers)
    local pool = {}

    if type(executers) ~= "table" then
        error("Can't create executers pool: executers must be a table")
    end

    for _, executer in pairs(executers) do
        local action = roleToTask(executer.role)

        if not action then
            error("Can't create executers pool: wrong executer role")
        end

        if not pool[action] then
            pool[action] = {}
        end

        table.insert(pool[action], executer)
    end

    return pool
end

-- Find recipe executer from the pool
local function getRecipeExecuter(recipe, pool)
    if type(recipe) ~= "table" then
        error("Can't find recipe executer: recipe must be a table")
    end

    if type(pool) ~= "table" then
        error("Can't find recipe executer: pool must be a table")
    end

    if not pool[recipe.action] then
        return nil
    end

    -- Shouldn't be possible but just in case
    if not pool[recipe.action][1] then
        return nil
    end

    -- For now just return the first available executers
    -- Scheduler will be (possibly) added in a future
    return pool[recipe.action][1]
end

-- Execute given recipe using executers pool and input storage inventory
-- Can panic, will return nil and a reason of soft errors
local function executeRecipe(storageInventory, recipe, pool)
    if not packages.inventory.isInventory(storageInventory) then
        error("Can't execute recipe: wrong storage inventory: [" .. storageInventory .. "]")
    end

    if not recipe.action then
        error("Can't execute recipe: no action field provided. Incorrect type?")
    end

    -- Find recipe executer
    local executer = getRecipeExecuter(recipe, pool)

    if not executer then
        return nil, "No recipe executer found"
    end

    local startTime = os.epoch("utc")
    local recipeResult = {}

    -- Process crafting recipe
    if recipe.action == "craft" then
        -- Move all the items to the input storage
        for _, input in pairs(recipe.params.recipe) do
            local moved = packages.inventory.moveItems(storageInventory, executer.input, input.name, input.count)

            if not moved then
                error("Couldn't transfer [" .. input.name .. "]. Expected " .. input.count .. ", got none")
            elseif moved < input.count then
                error("Couldn't transfer [" .. input.name .. "]. Expected " .. input.count .. ", got " .. moved)
            end
        end

        -- Get output inventory state before requesting craft
        local outputInventoryItems = packages.inventory.listItems(executer.output)

        -- Send crafting request to the turtle
        if not packages.crafter.sendRecipe(executer.params.turtleId, recipe) then
            error("Couldn't request recipe crafting")
        end

        -- Go through the expected recipe outputs
        for _, output in pairs(recipe.output) do
            -- Wait until the craft is finished
            while true do
                sleep(1)

                local foundItem = packages.inventory.findItem(executer.output, output.name)

                -- If we have found the item and it either
                -- wasn't presented in the output inventory before crafting
                -- or its value is different now
                -- 
                -- This is needed because we can't move some craft results to the
                -- output (global storage) inventory
                if foundItem ~= nil and (not outputInventoryItems[foundItem.name] or foundItem.count > outputInventoryItems[foundItem.name].count) then
                    break
                end
            end

            -- Move it to the storage
            local moved = packages.inventory.moveItems(executer.output, storageInventory, output.name)

            if not moved then
                error("Couldn't store crafted [" .. output.name .. "]. Expected " .. output.count .. ", got none")
            elseif moved < output.count then
                error("Couldn't store crafted [" .. output.name .. "]. Expected " .. output.count .. ", got " .. moved)
            end

            -- Add crafted item to the function output
            table.insert(recipeResult, {
                name  = output.name,
                count = output.count
            })
        end

    -- Process "process" recipe
    elseif recipe.action == "process" then
        error("Process recipes are not supported yet")
    end

    local finishTime = os.epoch("utc")

    return {
        result = recipeResult,
        time = {
            startedAt  = startTime,
            finishedAt = finishTime,
            duration   = finishTime - startTime
        }
    }
end

return {
    info = info,
    taskToRole = taskToRole,
    roleToTask = roleToTask,
    crafter = crafter,
    processer = processer,
    pool = pool,
    getRecipeExecuter = getRecipeExecuter,
    executeRecipe = executeRecipe
}
