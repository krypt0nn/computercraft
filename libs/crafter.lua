local function info()
    return {
        version = 6,
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

-- Convert normal crafting slots numbers
-- to slots numbers in the crafting turtle
local function recipeSlotToTurtleSlot(slot)
    if slot == 1 then return 1 end
    if slot == 2 then return 2 end
    if slot == 3 then return 3 end

    if slot == 4 then return 5 end
    if slot == 5 then return 6 end
    if slot == 6 then return 7 end

    if slot == 7 then return 9 end
    if slot == 8 then return 10 end
    if slot == 9 then return 11 end

    return nil
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
                -- Input all the crafting resources
                while true do
                    -- Select and suck some input resources there
                    turtle.select(16)
                    turtle.suck()

                    -- Check what did we took from the input inventory
                    local suckedItem = turtle.getItemDetail()

                    local unneededResource = true

                    -- Try to find it in the recipe
                    for slot, input in pairs(command.recipe.params.recipe) do
                        if not input.used and input.name == suckedItem.name then
                            -- If we took too many resources - return unneeded
                            if suckedItem.count > input.count then
                                turtle.drop(suckedItem.count - input.count)
                            end

                            -- If we took enough resources - mark resource as taken
                            -- and move it to the needed slot
                            if suckedItem.count >= input.count then
                                input.used = true
                                unneededResource = false

                                turtle.transferTo(recipeSlotToTurtleSlot(slot), input.count)

                                break
                            end
                        end
                    end

                    -- Return back unneeded resources
                    if unneededResource then
                        turtle.drop()
                    end

                    -- Check if we've finished
                    local finished = true

                    for _, input in pairs(command.recipe.params.recipe) do
                        if not input.used then
                            finished = false

                            break
                        end
                    end

                    -- Stop resources input if everything's done
                    if finished then
                        break
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
