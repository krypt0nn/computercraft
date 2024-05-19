local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        inventory = {
            minimalVersion = 15
        },
        recipes = {
            minimalVersion = 27
        },
        crafter = {
            minimalVersion = 8
        }
    }
})

------------------------------- Settings -------------------------------

-- Rednet modem interface
local modem = "top"

-- Crafting turtle ID
local crafterId = 1

-- Crafting turtle input inventory interface name
local crafterInputInventory = "minecraft:barrel_1"

-- Crafting turtle output inventory interface name
local crafterOutputInventory = "minecraft:barrel_2"

-- Main storage interface name
local storageInventory = "toms_storage:ts.inventory_connector_0"

-- Perform recipes queues optimizations (experimental)
local optimizeRecipes = true

------------------------------- Settings -------------------------------

if not packages.inventory.isInventory(crafterInputInventory) then
    error("Wrong crafter input inventory name")
end

if not packages.inventory.isInventory(crafterOutputInventory) then
    error("Wrong crafter output inventory name")
end

if not packages.inventory.isInventory(storageInventory) then
    error("Wrong main storage inventory name")
end

rednet.open(modem)

while true do
    io.write("What should I craft? ")

    local name = io.read()

    io.write("How many? ")

    local count = io.read()

    local craftQueue, resourcesHint = packages.recipes.findRecipeExecutionQueue(
        packages.inventory.listItems(storageInventory),
        name,
        count
    )

    if craftQueue then
        print("Found craft with " .. #craftQueue .. " steps")

        if optimizeRecipes then
            craftQueue = packages.recipes.batchRecipeExecutionQueue(
                craftQueue,
                name
            )

            print("Optimized to " .. #craftQueue .. " steps")
        end

        print()

        local craftStartTime = os.epoch("utc")

        for step, recipe in pairs(craftQueue) do
            local prefix = "[" .. math.floor(step / #craftQueue * 100) .. "%] "

            if recipe.action ~= "craft" then
                print(prefix .. "Not a crafting action. Stopping execution")

                break
            else
                local continueCrafting = true

                for _, input in pairs(recipe.params.recipe) do
                    local moved = packages.inventory.moveItems(storageInventory, crafterInputInventory, input.name, input.count)

                    if not moved or moved < input.count then
                        print(prefix .. "Couldn't transfer enough resources. Stopping execution")

                        continueCrafting = false

                        break
                    end
                end

                if not continueCrafting then
                    break
                end

                -- Get output inventory state before requesting craft
                local outputInventoryItems = packages.inventory.listItems(crafterOutputInventory)

                -- Send crafting request to the turtle
                if not packages.crafter.sendRecipe(tonumber(crafterId), recipe) then
                    print(prefix .. "Couldn't request recipe crafting. Stopping execution")

                    break
                end

                local craftedSuffix = ""

                -- Go through the expected recipe outputs
                for _, output in pairs(recipe.output) do
                    -- Wait until the craft is finished
                    while true do
                        sleep(1)

                        local foundItem = packages.inventory.findItem(crafterOutputInventory, output.name)

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
                    packages.inventory.moveItems(crafterOutputInventory, storageInventory, output.name)

                    -- Append suffix
                    if craftedSuffix == "" then
                        craftedSuffix = "[" .. output.name .. "] x" .. output.count
                    else
                        craftedSuffix = craftedSuffix .. ", [" .. output.name .. "] x" .. output.count
                    end
                end

                local craftingTime = os.epoch("utc") - craftStartTime
                local craftingEta = math.ceil((#craftQueue * craftingTime / step - craftingTime) / 10) / 100

                print(prefix .. "Crafted " .. craftedSuffix .. ". ETA: " .. craftingEta .. " sec")
            end
        end

        -- Move crafted thing to the storage
        packages.inventory.moveItems(crafterOutputInventory, storageInventory, name)

        -- Print crafting time
        local craftingTime = math.ceil((os.epoch("utc") - craftStartTime) / 10) / 100

        print("Craft finished in " .. craftingTime .. " sec")
    else
        print("Couldn't find possible craft")

        if #resourcesHint > 0 then
            print("Possible solutions:")

            for _, hint in pairs(resourcesHint) do
                print("- Add [" .. hint.name .. "] x" .. hint.count)
            end
        end
    end

    print()
end
