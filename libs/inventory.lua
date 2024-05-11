local function info()
    return {
        version = 4
    }
end

-- Get type of given inventory
local function getInventoryType(name)
    local inventory = peripheral.wrap(name) or return nil

    for name, _ in pairs(inventory) do
        if name == "pullItems" then
            return "chest"
        elseif name == "pullItem" then
            return "drawer"
        end
    end

    return nil
end

-- Check if given peripheral name is an inventory
local function isInventory(name)
    return getInventoryType(name) ~= nil
end

-- Get table of items in given inventory
local function listItems(name)
    local inventoryType = getInventoryType(name) or return nil

    local itemsRaw = peripheral.wrap(name).list()
    local items = {}

    for _, item in pairs(itemsRaw) do
        local value = items[item.name] or {
            name  = item.name,
            title = if inventoryType == "drawer" then item.displayName else item.name,
            count = 0
        }

        value.count = value.count + item.count

        items[item.name] = value
    end

    return items
end

return {
    info = info,
    getInventoryType = getInventoryType,
    isInventory = isInventory,
    listItems = listItems
}
