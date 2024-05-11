local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        inventory = {
            minimalVersion = 2
        }
    }
})

local side = "left"
local inventory = "minecraft:chest_2"

if not packages.inventory.isInventory(side, inventory) then
    error("Wrong inventory")
end
