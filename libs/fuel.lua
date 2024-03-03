local function info()
    return {
        version = 5
    }
end

-- Get amount of movement automaton will get from given fuel,
-- or nil if it's not a fuel
local function getFuelValue(name)
    local fuel = {
        ["minecraft:coal"]       = 80,
        ["minecraft:charcoal"]   = 80,
        ["minecraft:coal_block"] = 720
    }

    for fuelName, fuelValue in pairs(fuel) do
        if name == fuelName then
            return fuelValue
        end
    end

    return nil
end

-- Refuel automaton
-- Returns amount of fuel that is needed additionally
-- If 0, then automaton has enough fuel to continue
local function refuel(neededFuel)
    while turtle.getFuelLevel() < neededFuel do
        local slot = 1
        local hasFuel = false

        while slot < 17 do
            local detail = turtle.getItemDetail(slot)

            if detail ~= nil then
                local fuelValue = getFuelValue(detail.name)

                if fuelValue then
                    local refuelCount = math.ceil(neededFuel / fuelValue)

                    turtle.select(slot)
                    turtle.refuel(math.min(refuelCount, detail.count))

                    hasFuel = true

                    break
                end
            end

            slot = slot + 1
        end

        if not hasFuel then
            return neededFuel - turtle.getFuelLevel()
        end
    end

    return 0
end

return {
    info = info,
    getFuelValue = getFuelValue,
    refuel = refuel
}
