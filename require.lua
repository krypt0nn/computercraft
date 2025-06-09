-- require.lua
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

-- stringify({ a = "b" }) = "{a:b;}"
local function stringify(value)
    if type(value) == "table" then
        local string = ""

        for key, value in pairs(value) do
            string = string .. stringify(key) .. ":" .. stringify(value) .. ";"
        end

        return "{" .. string .. "}"
    else
        return tostring(value)
    end
end

-- hex({ 0, 0, 0, 0 }) = 00000000
local function hex(bytes)
    local alphabet = {
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "a", "b", "c", "d", "e", "f"
    }

    local hex = ""

    for _, byte in pairs(bytes) do
        local lower = byte % 16
        local upper = math.floor(byte / 16) % 16

        hex = hex .. alphabet[upper + 1] .. alphabet[lower + 1]
    end

    return hex
end

-- hash(value1, value2, value3, ...) = cfc62e561ec4c193
local function hash(...)
    -- 3.1415926535897932384626433832795028...
    local bytes = { 31, 41, 59, 26, 53, 58, 97, 93 }
    local n = #bytes

    for _, value in pairs({ ... }) do
        value = stringify(value)

        for i = 1, #value do
            local byte = string.byte(value, i)

            local cos = math.floor((bytes[i % n + 1] - 128) / 256 * 10000) / 10000
            local sin = math.floor((byte - 128) / 256 * 10000) / 10000

            local acos = math.floor(math.acos(cos) * 10000) / 10000
            local asin = math.floor(math.asin(sin) * 10000) / 10000

            local acos_deg = math.floor(math.deg(acos) * 10000) / 10000
            local asin_deg = math.floor(math.deg(asin) * 10000) / 10000

            bytes[i % n + 1] = (bytes[i % n + 1] + math.floor(acos_deg * asin_deg)) % 256
        end
    end

    return hex(bytes)
end

-- require({
--     source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
--     cache = "cache",
--     packages = {
--         excavation = {
--             minimalVersion = 3
--         }
--     }
-- })

return function(params)
    -- Verify source URL
    if not params.source then
        error("Can't require packages: no source URL provided")
    end

    local valid, message = http.checkURL(params.source)

    if not valid then
        error("Can't require packages: source URL is invalid (" .. message .. ")")
    end

    -- Verify cache folder
    if params.cache then
        if not fs.exists(params.cache) then
            fs.makeDir(params.cache)
        end
    end

    -- Require packages
    local packages = {}

    for packageName, packageParams in pairs(params.packages) do
        local packageHash = hash(params.source, packageName, packageParams)
        local package = nil

        -- Try to load cache if available
        if params.cache then
            local path = fs.combine(params.cache, packageName .. "-" .. packageHash .. ".lua")

            if fs.exists(path) then
                local file = fs.open(path, "r")

                package = file.readAll()

                file.close()
            end
        end

        -- Request package if it wasn't loaded from the cache
        if not package then
            package = http.get(params.source .. "/" .. packageName .. ".lua")
            package = package.readAll()

            -- Verify that the package requested correctly
            if not package then
                error("Failed to require package " .. packageName)
            end

            -- Cache package if needed
            if package and params.cache then
                local path = fs.combine(params.cache, packageName .. "-" .. packageHash .. ".lua")
                local file = fs.open(path, "w")

                file.write(package)
                file.close()
            end
        end

        -- Load package from string
        package = loadstring(package)()

        -- Verify requested package
        if not package.info then
            error("Required package " .. packageName .. " has incorrect format")
        end

        if not package.info().version then
            error("Required package " .. packageName .. " doesn't have 'version' field")
        end

        -- Check minimalVersion param
        if packageParams.minimalVersion then
            if package.info().version < packageParams.minimalVersion then
                error("Required package " .. packageName .. " is too outdated")
            end
        end

        packages[packageName] = package
    end

    return packages
end
