-- crafter.lua
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
        version = 9,
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
                            -- If we took enough resources - mark resource as taken
                            -- and move it to the needed slot
                            if suckedItem.count >= input.count then
                                input.used = true
                                unneededResource = false

                                suckedItem.count = suckedItem.count - input.count

                                turtle.transferTo(recipeSlotToTurtleSlot(slot), input.count)

                                if suckedItem.count == 0 then
                                    break
                                end
                            end
                        end
                    end

                    -- Return remaining resources to the output storage
                    -- because we have used it in every possible slot
                    if suckedItem.count > 0 then
                        turtle.dropUp()
                    end

                    -- Return back unneeded resources
                    if unneededResource then
                        turtle.dropUp()
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
                turtle.dropUp()

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
