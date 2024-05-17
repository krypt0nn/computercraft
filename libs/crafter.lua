local function info()
    return {
        version = 3,
        rednet = {
            protocol = "adeptus_mechanicus/crafter"
        }
    }
end

-- Check if currect machine is a crafting turtle
local function isCrafter()
    return turtle ~= nil and turtle["craft"] ~= nil and turtle["suck"] ~= nil
end

-- Send recipe to the turtle
local function sendRecipe(crafterId, recipe)
    return rednet.send(crafterId, {
        version = 1,
        recipe = recipe
    }, info().rednet.protocol)
end

-- Start recipes processing on the turtle
local function start(serverId)
    if not isCrafter() then
        error("Current machine is not a crafting turtle")
    end

    while true do
        local sender, command = rednet.receive(info().rednet.protocol)

        if sender == serverId then
            print("[*] received crafting request")

            if command.recipe.action ~= "craft" then
                print("[!] unsupported recipe action: " .. command.recipe.action)
            else
                -- Input resources for crafting
                for slot, input in pairs(command.recipe.params.recipe) do
                    if input then
                        if slot == 1 then turtle.select(1) end
                        if slot == 2 then turtle.select(2) end
                        if slot == 3 then turtle.select(3) end

                        if slot == 4 then turtle.select(5) end
                        if slot == 5 then turtle.select(6) end
                        if slot == 6 then turtle.select(7) end

                        if slot == 7 then turtle.select(9) end
                        if slot == 8 then turtle.select(10) end
                        if slot == 9 then turtle.select(11) end

                        turtle.suck(input.count)

                        local suckedItem = turtle.getItemDetail()

                        if suckedItem.name ~= input.name then
                            error("Incorrect resources input. Expected [" .. input.name .. "], got [" .. suckedItem.name .. "] at input slot " .. slot)
                        end
                    end
                end

                -- Select output slot
                turtle.select(4)

                -- Execute the craft
                if not turtle.craft() then
                    error("Failed to execute the craft")
                end

                -- Verify craft result
                local craftedItem = turtle.getItemDetail()
                local successfulCraft = false

                for _, output in pairs(command.recipe.output) do
                    if craftedItem.name == output.name then
                        successfulCraft = true
                    end
                end

                if not successfulCraft then
                    error("Incorrect crafting result: [" .. craftedItem.name .. "]")
                end

                -- Put crafter item to the storage
                turtle.drop()

                print("[*] crafted [" .. craftedItem.name .. "] x" .. craftedItem.count)
            end
        end
    end
end

return {
    info = info,
    isCrafter = isCrafter,
    sendRecipe = sendRecipe,
    start = start
}
