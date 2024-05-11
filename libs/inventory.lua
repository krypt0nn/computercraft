local function info()
    return {
        version = 3
    }
end

-- Check if given peripheral name is an inventory
local function isInventory(name)
    local pullItems = false
    local pushItems = false
    local list = false

    local inventory = peripheral.wrap(name)

    if not inventory then
        return false
    end

    for name, _ in pairs(inventory) do
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

-- Get table of items in given inventory
local function listItems(name)
    if not isInventory(name) then
        return nil
    end

    local itemsRaw = peripheral.wrap(name).list()
    local items = {}

    for _, item in pairs(itemsRaw) do
        local value = items[item.name] or {
            name  = item.name,
            count = 0
        }

        value.count = value.count + item.count

        items[item.name] = value
    end

    return items
end

return {
    info = info,
    isInventory = isInventory,
    listItems = listItems
}
