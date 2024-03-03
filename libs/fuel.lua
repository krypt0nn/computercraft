local function info()
    return {
        version = 4
    }
end

-- Check if given entity name is a fuel
local function isFuel(name)
    local fuel = {
        "minecraft:coal",
        "minecraft:coal_block",
        "minecraft:charcoal",
        "minecraft:dried_kelp_block"
    }

    for _, fuelName in pairs(fuel) do
        if name == fuelName then
            return true
        end
    end

    return false
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

            if detail ~= nil and isFuel(detail.name) then
                turtle.select(slot)
                turtle.refuel()

                hasFuel = true

                break
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
    info   = info,
    isFuel = isFuel,
    refuel = refuel
}
