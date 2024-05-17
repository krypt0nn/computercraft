local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        inventory = {
            minimalVersion = 15
        },
        recipes = {
            minimalVersion = 9
        }
    }
})

local inventory = "extended_drawers:access_point_0"

if not packages.inventory.isInventory(inventory) then
    error("Wrong inventory name")
end

while true do
    print("What should I craft?")

    local name = io.read("*l")

    print("How many?")

    local count = io.read("*n")

    local craftQueue = packages.recipes.findRecipeExecutionQueue(
        packages.inventory.listItems(inventory),
        name,
        count
    )

    if craftQueue then
        print("Found craft with " .. #craftQueue .. " steps")
    else
        print("Couldn't find possible craft")
    end
end
