local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        inventory = {
            minimalVersion = 18
        },
        recipes = {
            minimalVersion = 48
        },
        recipes_runtime = {
            minimalVersion = 7
        }
    }
})

--------------------- Settings ---------------------

-- Rednet modem interface
local modem = "top"

-- Main storage interface name
local storageInventory = "toms_storage:ts.inventory_connector_0"

-- Register recipes executers pool
local pool = packages.recipes_runtime.pool({
    -- Crafter
    packages.recipes_runtime.crafter(
        1,
        "minecraft:barrel_17",
        "minecraft:barrel_18"
    ),

    -- Furnace
    packages.recipes_runtime.processer(
        "furnace",
        "minecraft:barrel_3",
        "minecraft:barrel_4"
    ),

    -- Macerator
    packages.recipes_runtime.processer(
        "macerator",
        "minecraft:barrel_5",
        "minecraft:barrel_6"
    ),

    -- Compressor
    packages.recipes_runtime.processer(
        "compressor",
        "minecraft:barrel_7",
        "minecraft:barrel_8"
    ),

    -- Wiremill
    packages.recipes_runtime.processer(
        "wiremill",
        "minecraft:barrel_11",
        "minecraft:barrel_12"
    ),

    -- Cutting Machine
    packages.recipes_runtime.processer(
        "cutting_machine",
        "minecraft:barrel_13",
        "minecraft:barrel_14"
    ),

    -- Mixer
    packages.recipes_runtime.processer(
        "mixer",
        "minecraft:barrel_15",
        "minecraft:barrel_16"
    )
})

--------------------- Settings ---------------------

-- Check that main storage inventory is correct
if not packages.inventory.isInventory(storageInventory) then
    error("Wrong main storage inventory name")
end

-- Clear inputs and outputs of all the executers
packages.recipes_runtime.clearStorages(storageInventory, pool)

-- Open modem to send commands
rednet.open(modem)

while true do
    io.write("What should I craft? ")

    local name = io.read()

    io.write("How many? ")

    local count = io.read()

    print()
    print("[*] Building crafting queue...")

    local craftingQueue, hint = packages.recipes.buildItemCraftingQueue(
        name,
        count,
        packages.inventory.listItems(storageInventory)
    )

    if not craftingQueue then
        print("[!] Couldn't build crafting queue")

        if hint then
            print("    Possible solution:")

            local function printHint(hint, prefix)
                print(prefix .. "- Add [" .. hint.name .. "] x" .. hint.count)

                if hint.subhint then
                    printHints(hint.subhint, "  " .. prefix)
                end
            end

            printHint(hint, "    ")
        end
    else
        print("[*] Built queue with " .. #craftingQueue .. " actions")

        if not packages.recipes.craftingQueueIsOptimal(craftingQueue) then
            print("[!] Crafting queue is suboptimal")

            local function askFor(message, default)
                io.write("[?] " .. message)

                if default then
                    io.write(" (Y/n): ")
                else
                    io.write(" (y/N): ")
                end

                local input = string.lower(io.read())

                if default then
                    return input ~= "n" and input ~= "no"
                else
                    return input ~= "y" and input ~= "ye" and input ~= "yes"
                end
            end

            -- Ask for inline optimizer
            if askFor("Run inline optimizer", true) then
                print("[*] Started inline optimizer...")

                craftingQueue = packages.recipes.inlineOptimizer(craftingQueue)

                print("[*] Done")
            end
        end

        print()

        -- Count total number of steps
        local totalSteps  = 0
        local currentStep = 0

        for _, action in pairs(craftingQueue) do
            totalSteps = totalSteps + action.multiplier
        end

        -- Start queue execution
        local craftStartTime = os.epoch("utc")

        -- Iterate over actions
        for i = #craftingQueue, 1, -1 do
            local action = craftingQueue[i]

            -- Iterate over action multiplier
            for j = 1, action.multiplier do
                currentStep = currentStep + 1

                local prefix = "[" .. math.floor(currentStep / totalSteps * 100) .. "%]"

                -- Execute recipe
                local result, reason = packages.recipes_runtime.executeRecipe(storageInventory, action.recipe, pool)

                -- Stop execution if failed
                if not result then
                    print(prefix .. " Couldn't execute recipe: " .. reason)

                    break
                end

                -- Add recipe execution time to the prefix
                local recipeTime = math.ceil(result.time.duration / 10) / 100

                prefix = prefix .. "[" .. recipeTime .. " sec]"

                -- List recipe result
                local recipeResult = ""

                for _, result in pairs(result.result) do
                    if recipeResult == "" then
                        recipeResult = "[" .. result.name .. "] x" .. result.count
                    else
                        recipeResult = recipeResult .. ", [" .. result.name .. "] x" .. result.count
                    end
                end

                -- Calculate total ETA
                local craftingTime = os.epoch("utc") - craftStartTime
                local craftingEta = math.ceil((totalSteps * craftingTime / currentStep - craftingTime) / 10) / 100

                -- Add ETA to the prefix
                prefix = prefix .. "[ETA: " .. craftingEta .. " sec]"

                print(prefix .. " Crafted " .. recipeResult)
                print()
            end
        end

        -- Print crafting time
        local craftingTime = math.ceil((os.epoch("utc") - craftStartTime) / 10) / 100

        print("[*] Craft finished in " .. craftingTime .. " sec")
    end

    print()
end
