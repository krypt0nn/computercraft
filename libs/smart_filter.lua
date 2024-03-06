local function info()
    return {
        version = 1
    }
end

-- start({
--     filter = {
--         name    = "kelp smart filter",
--         slave   = "right",
--         master  = "left",
--         save    = "storage.data",
--         timeout = 5
--     },
--     input = {
--         side  = "top",
--         power = 15,
--         update = function()
--             print("Input")
--         end
--     },
--     output = {
--         side = "bottom",
--         power = 15,
--         update = function()
--             print("Output")
--         end
--     },
--     items = {
--         name = "kelp",
--         quantity = 64
--     }
-- })

local function start(params)
    local stored = 0

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

    while true do
        -- If input signal detected
        if redstone.getAnalogInput(params.input.side) == (params.input.power or 15) then
            -- Call input update function if available
            if params.input.update then
                params.input.update({
                    stored = stored,
                    params = params
                })
            end

            -- Enable output signal
            redstone.setAnalogOutput(params.output.side, params.output.power or 15)

            -- Wait until input is available
            while redstone.getAnalogInput(params.input.side) == (params.input.power or 15) do
                sleep(params.filter.timeout or 5)
            end

            -- Disable output signal
            redstone.setAnalogOutput(params.output.side, 15 - (params.output.power or 15))

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
        end

        sleep(params.filter.timeout or 5)
    end
end

return {
    info  = info,
    start = start
}
