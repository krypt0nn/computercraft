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

                if continueCrafting then
                    if not packages.crafter.sendRecipe(tonumber(crafterId), recipe) then
                        print(prefix .. "Couldn't request recipe crafting. Stopping execution")

                        break
                    end

                    -- FIXME: wait when shit will actually be crafted

                    sleep(4)

                    print(prefix .. "Crafted")
                end
            end
        end
    else
        print("Couldn't find possible craft")
    end

    print()
end
