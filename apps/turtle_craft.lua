local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        crafter = {
            minimalVersion = 1
        }
    }
})

if not packages.crafter.isCrafter() then
    error("Not a crafting turtle")
end

io.write("Rednet modem side: ")

local modem = io.read()

io.write("Crafting server ID: ")

local serverId = io.read()

print()

rednet.open(modem)

packages.crafter.start(serverId)
