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
        -- Copy counts so we can decrement in-place
        local needs = {}

        for slot, resource in pairs(layout) do
            if resource then
                needs[slot] = {
                    name = resource.name,
                    count = resource.count,
                    slot = recipe_to_turtle_slot(slot)
                }
            end
        end

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
            local done = true

            for _, need in pairs(needs) do
                if need.count > 0 then
                    done = false

                    break
                end
            end

            if done then
                break
            end

            turtle.select(16)

            if not turtle.suckUp() then
                break
            end

            local item = turtle.getItemDetail(16)

            if not item then
                break
            end

            for _, need in pairs(needs) do
                if need.count > 0 and need.name == item.name then
                    local give = math.min(item.count, need.count)

                    turtle.transferTo(need.slot, give)

                    need.count = need.count - give
                    item.count = item.count - give

                    if item.count == 0 then
                        break
                    end
                end
            end

            if item.count > 0 then
                turtle.drop(item.count)
            end
        end

        -- Drop anything left in stash
        local leftover = turtle.getItemDetail(16)

        if leftover then
            turtle.select(16)
            turtle.drop(leftover.count)
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
