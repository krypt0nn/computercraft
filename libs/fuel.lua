-- fuel.lua
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
