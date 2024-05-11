local function info()
    return {
        version = 11
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
        error("Failed to identify type of given inventory")
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
        if item.name and item.count then
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
    end

    return items
end

-- Find an item in given inventory with given name
-- If many items have the same name, return the first found
local function findItem(inventory, name)
    local items = listItems(inventory)

    if not items then
        error("Failed to list items in given inventory")
    end

    if items[name] then
        return items[name]
    end

    for _, item in pairs(items) do
        if string.find(item.name, name) or string.find(item.title, name) then
            return item
        end
    end

    return nil
end

return {
    info = info,
    getInventoryType = getInventoryType,
    isInventory = isInventory,
    findItem = findItem,
    listItems = listItems
}
