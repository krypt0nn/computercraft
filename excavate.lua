local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        excavation = {
            minimalVersion = 4
        }
    }
})

local length, width, height = ...

packages.excavation.digRectangle(
    tonumber(length),
    tonumber(width),
    tonumber(height)
)
