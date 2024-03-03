local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        notifications = {
            minimalVersion = 4
        },
        fuel = {
            minimalVersion = 3
        }
    }
})

local function info()
    return {
        version = 4
    }
end

local function notify(line)
    if line then
        print(line)

        packages.notifications.broadcast(line)
    else
        print()
    end
end

local function digRectangle(length, width, height)
    notify("Mining rectangle")
    notify("  Length: " .. length)
    notify("   Width: " .. width)
    notify("  Height: " .. height)
    notify()

    local movementsPerLine = (length * 2) * (height * 2) + 1
    local totalBlocks = length * width * height
    local minedBlocks = 0

    while true do
        local neededFuel = packages.fuel.refuel(movementsPerLine)

        if neededFuel > 0 then
            notify("Need " .. neededFuel .. " more fuel!")

            sleep(15)
        else
            break
        end
    end

    while width > 0 do
        local i = 0

        while i < length do
            -- Dig forward
            turtle.dig()
            turtle.forward()

            -- Mine blocks from down to up
            local j = 1

            while j < height do
                turtle.digUp()

                j = j + 1

                if j < height then
                    turtle.up()
                end
            end

            -- Return back to the ground
            j = 2 -- some big pp logic

            while j < height do
                turtle.down()

                j = j + 1
            end

            i = i + 1
        end

        -- Return back to the beginning of the line
        turtle.turnLeft()
        turtle.turnLeft()

        i = 0

        while i < length do
            turtle.forward()

            i = i + 1
        end

        -- Go to the new line if needed
        width = width - 1

        if width > 0 then
            turtle.turnLeft()
            turtle.dig()
            turtle.forward()
            turtle.turnLeft()

            while true do
                local neededFuel = packages.fuel.refuel(movementsPerLine)

                if neededFuel > 0 then
                    notify("Need " .. neededFuel .. " more fuel!")

                    sleep(15)
                else
                    break
                end
            end
        end

        -- Print task progress
        minedBlocks = minedBlocks + length * height

        notify("Progress: " .. (math.floor((minedBlocks / totalBlocks * 10000)) / 100) .. "% (" .. minedBlocks .. " / " .. totalBlocks .. " blocks)")
    end

    notify()
    notify("Task is done")
end

return {
    info = info,
    digRectangle = digRectangle
}
