local REDNET_MODEM_SIDE     = "right"
local INPUT_INVENTORY_SIDE  = "top"
local OUTPUT_INVENTORY_SIDE = "front"

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
    local sender_id, data, protocol = rednet.receive()

    if data and data.inputs then
        local input_inventory = peripheral.wrap(INPUT_INVENTORY_SIDE)
        local output_inventory = peripheral.wrap(OUTPUT_INVENTORY_SIDE)

        if not input_inventory or not output_inventory then
            rednet.send(sender_id, {
                success = false,
                error = "missing inventory"
            }, protocol)
        else
            local available = {}
            local failed = false

            -- Clear turtle inventory to output
            for slot = 1, 16 do
                local info = turtle.getItemDetail(slot)

                if info then
                    turtle.select(slot)

                    output_inventory.pullItem("turtle", slot, info.count)
                end
            end

            turtle.select(4)

            -- Prepare table of available input resources
            for _, item in pairs(input_inventory.items()) do
                if item.name and item.count then
                    available[item.name] = (available[item.name] or 0) + item.count
                end
            end

            -- Calculate how many times we can craft from available resources
            local max_crafts = math.huge

            for _, resource in pairs(data.inputs.flat) do
                if resource and resource.name and resource.count then
                    local available_resource = available[resource.name] or 0

                    max_crafts = math.min(
                        max_crafts,
                        math.floor(available_resource / resource.count)
                    )
                end
            end

            while max_crafts > 0 do
                -- Clear crafting grid slots
                for slot = 1, 16 do
                    local info = turtle.getItemDetail(slot)

                    if info then
                        turtle.select(slot)

                        output_inventory.pullItem("turtle", slot, info.count)
                    end
                end

                -- Fill crafting grid from input inventory
                for slot = 1, 9 do
                    local resource = data.inputs.layout[slot]

                    if resource then
                        for src_slot, item in pairs(input_inventory.items()) do
                            if item.name == resource.name and item.count >= resource.count then
                                input_inventory.pushItems(
                                    "turtle",
                                    src_slot,
                                    resource.count,
                                    recipe_to_turtle_slot(slot)
                                )

                                break
                            end
                        end
                    end
                end

                -- Craft
                turtle.select(4)

                if not turtle.craft() then
                    failed = true

                    break
                end

                -- Push result to output
                local result = turtle.getItemDetail()

                if result then
                    output_inventory.pullItem("turtle", 4, result.count)
                end

                max_crafts = max_crafts - 1
            end

            -- Push all remaining items to output
            for slot = 1, 16 do
                local info = turtle.getItemDetail(slot)

                if info then
                    turtle.select(slot)

                    output_inventory.pullItem("turtle", slot, info.count)
                end
            end

            rednet.send(sender_id, {
                success = not failed,
                error = failed and "craft failed" or nil
            }, protocol)
        end
    end
end
