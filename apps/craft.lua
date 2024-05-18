local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        inventory = {
            minimalVersion = 15
        },
        recipes = {
            minimalVersion = 11
        },
        crafter = {
            minimalVersion = 6
        }
    }
})

local inventory = "extended_drawers:access_point_0"

if not packages.inventory.isInventory(inventory) then
    error("Wrong inventory name")
end

io.write("Rednet modem side: ")

local modem = io.read()

io.write("Crafting turtle ID: ")

local crafterId = io.read()

io.write("Crafting turtle input inventory: ")

local crafterInputInventory = io.read()

if not packages.inventory.isInventory(crafterInputInventory) then
    error("Given name is not an actual inventory")
end

print()

rednet.open(modem)

while true do
    io.write("What should I craft? ")

    local name = io.read()

    io.write("How many? ")

    local count = io.read()

    local craftQueue = packages.recipes.findRecipeExecutionQueue(
        packages.inventory.listItems(inventory),
        name,
        count
    )

    if craftQueue then
        print("Found craft with " .. #craftQueue .. " steps")

        local craftStartTime = os.epoch("utc")

        for step, recipe in pairs(craftQueue) do
            local prefix = "[" .. math.floor(step / #craftQueue * 100) .. "%] "

            if recipe.action ~= "craft" then
                print(prefix .. "Not a crafting action. Stopping execution")

                break
            else
                local continueCrafting = true

                for _, input in pairs(recipe.params.recipe) do
                    if packages.inventory.moveItems(inventory, crafterInputInventory, input.name, input.count) < input.count then
                        print(prefix .. "Couldn't transfer enough resources. Stopping execution")

                        continueCrafting = false

                        break
                    end
                end

                if not continueCrafting then
                    break
                end

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

                        if packages.inventory.findItem(crafterInputInventory, output.name) then
                            break
                        end
                    end

                    -- Move it to the storage
                    packages.inventory.moveItems(crafterInputInventory, inventory, output.name)

                    -- Append suffix
                    if craftedSuffix == "" then
                        craftedSuffix = "[" .. output.name .. "] x" .. output.count
                    else
                        craftedSuffix = craftedSuffix .. ", [" .. output.name .. "] x" .. output.count
                    end
                end

                local craftingTime = os.epoch("utc") - craftStartTime
                local craftingEta = math.round(#craftQueue * craftingTime / step / 10) / 100

                print(prefix .. "Crafted " .. craftedSuffix .. ". ETA: " .. craftingEta .. " sec")
            end
        end

        -- Move crafted thing to the storage
        packages.inventory.moveItems(crafterInputInventory, inventory, name)
    else
        print("Couldn't find possible craft")
    end

    print()
end
