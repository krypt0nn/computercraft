-- inventory.lua
-- Copyright (c) 2024-2025 Nikita Podvirnyi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local function info()
    return {
        version = 18
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
        error("Unsupported inventory type: " .. inventoryType)
    end

    for slot, item in pairs(itemsRaw) do
        if item.name and item.count then
            local title = item.name

            if inventoryType == "drawer" then
                -- Sometimes title is nil?
                title = item.displayName or item.name
            end

            local value = items[item.name] or {
                name  = item.name,
                title = title,
                count = 0,
                slots = {}
            }

            value.slots[slot] = {
                slot  = slot,
                count = item.count
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
        if string.find(item.name or "", name) or string.find(item.title or "", name) then
            return item
        end
    end

    return nil
end

-- Move items from one inventory to another
-- Returns number of moved items. Can be lower than "amount"
local function moveItems(from, to, name, amount)
    local fromType = getInventoryType(from)
    local toType = getInventoryType(to)

    if not fromType or not toType then
        error("Failed to identify types of given inventories. Are they valid?")
    end

    local item = findItem(from, name)

    if not item then
        return nil
    end

    if fromType == "chest" and toType == "chest" then
        local moved = 0

        for _, slot in pairs(item.slots) do
            if slot.count >= amount - moved then
                moved = moved + peripheral.wrap(from).pushItems(to, slot.slot, amount - moved)
            else
                moved = moved + peripheral.wrap(from).pushItems(to, slot.slot)
            end

            if moved >= amount then
                return moved
            end
        end

        return moved
    elseif toType == "drawer" then
        return peripheral.wrap(to).pullItem(from, item.name, amount)
    elseif fromType == "drawer" then
        return peripheral.wrap(from).pushItem(to, item.name, amount)
    else
        error("Unsupported inventory type: " .. inventoryType)
    end
end

-- Move all the items from one inventory to another
-- Returns table of moved items
local function migrateItems(from, to, ignoreList)
    local fromItemsList = listItems(from)

    if not fromItemsList then
        error("Can't list items in inventory " .. from)
    end

    if type(ignoreList) ~= "table" then
        ignoreList = {}
    end

    local movedItems = {}

    for _, item in pairs(fromItemsList) do
        if not ignoreList[item.name] then
            local moved = moveItems(from, to, item.name)

            if moved then
                local value = movedItems[item.name] or {
                    name     = item.name,
                    count    = 0,
                    remained = 0
                }

                value.count    = value.count + moved
                value.remained = value.remained + item.count - moved

                movedItems[item.name] = value
            end
        end
    end

    return movedItems
end

return {
    info = info,
    getInventoryType = getInventoryType,
    isInventory = isInventory,
    listItems = listItems,
    findItem = findItem,
    moveItems = moveItems,
    migrateItems = migrateItems
}
