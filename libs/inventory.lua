local function info()
    return {
        version = 2
    }
end

-- Check if given peripheral name is an inventory
local function isInventory(side, name)
    local pullItems = false
    local pushItems = false
    local list = false

    local methods = peripheral.wrap(side).getMethodsRemote(name)

    if not methods then
        return false
    end

    for _, name in pairs(methods) do
        if name == "pullItems" then
            pullItems = true
        elseif name == "pushItems" then
            pushItems = true
        elseif name == "list" then
            list = true
        end
    end

    return pullItems and pushItems and list
end

return {
    info = info,
    isInventory = isInventory
}
