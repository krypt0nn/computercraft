local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        fuel = {
            minimalVersion = 5
        }
    }
})

-- Refuel turtle
packages.fuel.refuel()
