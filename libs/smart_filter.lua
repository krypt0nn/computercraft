local function info()
    return {
        version = 3,
        rednet = {
            protocol = "new_moscow/smart_filter"
        }
    }
end

-- start({
--     filter = {
--         name   = "kelp smart filter",
--         save   = "storage.data"
--     },
--     input = {
--         side    = "top",
--         power   = 15,
--         timeout = 3,
--         update  = function()
--             print("Input")
--         end
--     },
--     output = {
--         side    = "bottom",
--         power   = 15,
--         timeout = 0.5,
--         update  = function()
--             print("Output")
--         end
--     },
--     items = {
--         name     = "kelp",
--         quantity = 64
--     },
--     rednet = {
--         side   = "back",
--         master = 12
--     }
-- })

local function start(params)
    local stored = 0

    -- Set default redstone signals
    for _, side in pairs(redstone.getSides()) do
        redstone.setAnalogOutput(side, 0)
    end

    -- Disable output signal
    redstone.setAnalogOutput(params.output.side or "left", 15 - (params.output.power or 15))

    -- Read save file if available
    if params.filter.save then
        local file = fs.open(params.filter.save, "r")

        if file then
            stored = file.readAll()

            file.close()

            -- Set default value if failed to read
            if not stored then
                stored = 0
            end
        end
    end

    -- Enable rednet adapter if param is present
    if params.rednet then
        if not rednet.isOpen(params.rednet.side or "back") then
            rednet.open(params.rednet.side or "back")
        end
    end

    while true do
        -- If input signal detected
        if redstone.getAnalogInput(params.input.side or "right") == (params.input.power or 15) then
            -- Call input update function if available
            if params.input.update then
                params.input.update({
                    stored = stored,
                    params = params
                })
            end

            -- Enable output signal
            redstone.setAnalogOutput(params.output.side or "left", params.output.power or 15)

            -- Wait until input is available
            while redstone.getAnalogInput(params.input.side or "right") == (params.input.power or 15) do
                sleep(params.output.timeout or 0.5)
            end

            -- Disable output signal
            redstone.setAnalogOutput(params.output.side or "left", 15 - (params.output.power or 15))

            -- Update stored items counter
            stored = stored + params.items.quantity or 64

            -- Save stored items counter if option is given
            if params.filter.save then
                local file = fs.open(params.filter.save, "w")

                file.write(stored)
                file.close()
            end

            -- Call output update function if available
            if params.output.update then
                params.output.update({
                    stored = stored,
                    params = params
                })
            end

            -- Send stats to the master
            if params.rednet and params.rednet.master then
                rednet.send(params.rednet.master, {
                    filter = {
                        name = params.filter.name
                    },
                    items = {
                        name = params.items.name,
                        stored = stored
                    }
                }, info().rednet.protocol)
            end
        end

        sleep(params.input.timeout or 5)
    end
end

-- listen({
--     side = "back",
--     update = function(sender, params)
--         print("Filter id: " .. sender)
--         print("Filter name: " .. params.filter.name)
--         print("Filter items name: " .. params.items.name)
--         print("Filter items stored: " .. params.items.stored)
--     end
-- })

local function listen(params)
    -- Enable rednet adapter
    if not rednet.isOpen(params.side or "back") then
        rednet.open(params.side or "back")
    end

    while true do
        local sender, message = rednet.receive(info().rednet.protocol)

        if params.update then
            params.update(sender, message)
        end
    end
end

return {
    info   = info,
    start  = start,
    listen = listen
}
