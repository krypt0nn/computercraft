local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        crafter = {
            minimalVersion = 9
        }
    }
})

if not packages.crafter.isCrafter() then
    error("Not a crafting turtle")
end

------------------------------- Settings -------------------------------

-- Rednet modem interface
local modem = "left"

-- Crafting server ID
local serverId = 0

------------------------------- Settings -------------------------------

rednet.open(modem)

packages.crafter.start(tonumber(serverId))
