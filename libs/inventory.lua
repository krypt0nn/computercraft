local function info()
    return {
        version = 9
    }
end

-- Get type of given inventory
local function getInventoryType(name)
    local inventory = peripheral.wrap(name)

    if not inventory then
        return nil
    end

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
    local inventoryType = getInventoryType(name)

    if not inventoryType then
        return nil
    end

    local itemsRaw = {}
    local items = {}

    if inventoryType == "chest" then
        itemsRaw = peripheral.wrap(name).list()
    elseif inventoryType == "drawer" then
        itemsRaw = peripheral.wrap(name).items()
    else
        error("Unknown inventory type: " .. inventoryType)
    end

    for _, item in pairs(itemsRaw) do
        local title = item.name

        if inventoryType == "drawer" then
            title = item.displayName
        end

        local value = items[item.name] or {
            name  = item.name,
            title = title,
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
