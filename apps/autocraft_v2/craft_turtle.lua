local REDNET_MODEM_SIDE = "right"

local function recipe_to_turtle_slot(slot)
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

rednet.open(REDNET_MODEM_SIDE)

while true do
    local sender_id, layout, protocol = rednet.receive()

    if layout then
        -- Clear turtle inventory
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)

            if item then
                turtle.select(slot)
                turtle.drop(item.count)
            end
        end

        -- Fill grid from input
        while true do
            -- Take input resource
            turtle.select(16)
            turtle.suckUp()

            local item = turtle.getItemDetail(16)

            if not item then
                break
            end

            local unneeded = true

            -- Try to find it in the recipe
            for slot, input in pairs(layout) do
                if not input.used and input.name == item.name then
                    -- If we took enough resources - mark resource as taken
                    -- and move it to the needed slot
                    if item.count >= input.count then
                        input.used = true
                        unneeded = false

                        item.count = item.count - input.count

                        turtle.transferTo(recipe_to_turtle_slot(slot), input.count)

                        if item.count == 0 then
                            break
                        end
                    end
                end
            end

            -- Return remaining resources to the output storage because we have
            -- used it in every possible slot
            if unneeded or item.count > 0 then
                turtle.drop()
            end

            -- Check if we've finished
            local finished = true

            for _, input in pairs(layout) do
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

        -- Craft loop
        turtle.select(4)

        while turtle.craft() do
            local result = turtle.getItemDetail(4)

            if result then
                turtle.drop(result.count)
            end

            turtle.select(4)
        end

        -- Clear turtle slots
        for slot = 1, 16 do
            local info = turtle.getItemDetail(slot)

            if info then
                turtle.select(slot)
                turtle.drop(info.count)
            end
        end

        rednet.send(sender_id, true, protocol)
    end
end
