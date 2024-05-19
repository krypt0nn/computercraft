local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache",
    packages = {
        inventory = {
            minimalVersion = 16
        },
        recipes = {
            minimalVersion = 34
        },
        recipes_runtime = {
            minimalVersion = 5
        }
    }
})

--------------------- Settings ---------------------

-- Rednet modem interface
local modem = "top"

-- Main storage interface name
local storageInventory = "toms_storage:ts.inventory_connector_0"

-- Perform recipes queues optimizations (experimental)
local optimizeRecipes = true

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

if not packages.inventory.isInventory(storageInventory) then
    error("Wrong main storage inventory name")
end

rednet.open(modem)

while true do
    io.write("What should I craft? ")

    local name = io.read()

    io.write("How many? ")

    local count = io.read()

    local craftQueue, resourcesHint = packages.recipes.findRecipeExecutionQueue(
        packages.inventory.listItems(storageInventory),
        name,
        count
    )

    if craftQueue then
        print("Found craft with " .. #craftQueue .. " steps")

        if optimizeRecipes then
            craftQueue = packages.recipes.batchRecipeExecutionQueue(
                craftQueue,
                name
            )

            print("Optimized to " .. #craftQueue .. " steps")
        end

        print()

        local craftStartTime = os.epoch("utc")

        for step, recipe in pairs(craftQueue) do
            local prefix = "[" .. math.floor(step / #craftQueue * 100) .. "%]"

            -- Execute recipe
            local result, reason = packages.recipes_runtime.executeRecipe(storageInventory, recipe, pool)

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
            local craftingEta = math.ceil((#craftQueue * craftingTime / step - craftingTime) / 10) / 100

            -- Add ETA to the prefix
            prefix = prefix .. "[ETA: " .. craftingEta .. " sec]"

            print(prefix .. " Crafted " .. recipeResult)
            print()
        end

        -- Print crafting time
        local craftingTime = math.ceil((os.epoch("utc") - craftStartTime) / 10) / 100

        print("Craft finished in " .. craftingTime .. " sec")
    else
        print("Couldn't find crafting queue")

        if #resourcesHint > 0 then
            print("Required items:")

            local function printHints(hints, prefix)
                if not prefix then
                    prefix = ""
                end

                for _, hint in pairs(hints) do
                    print("- Add [" .. hint.name .. "] x" .. hint.count)

                    if hint.subhint then
                        printHints(hint.subhint, "  " .. prefix)
                    end
                end
            end

            printHints(resourcesHint)
        end
    end

    print()
end
