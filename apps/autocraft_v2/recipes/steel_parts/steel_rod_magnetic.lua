-- redstone recipe
-- return {
--     machine = "crafter",
--     inputs = {
--         [2] = { name = "minecraft:redstone",                 count = 1 },
--         [3] = { name = "minecraft:redstone",                 count = 1 },
--         [4] = { name = "minecraft:redstone",                 count = 1 },
--         [5] = { name = "modern_industrialization:steel_rod", count = 1 },
--         [6] = { name = "minecraft:redstone",                 count = 1 },
--         [7] = { name = "minecraft:redstone",                 count = 1 },
--         [8] = { name = "minecraft:redstone",                 count = 1 }
--     },
--     outputs = {
--         { name = "modern_industrialization:steel_rod_magnetic", count = 1 }
--     }
-- }

-- polarizer recipe
return {
    machine = "polarizer",
    inputs = {
        { name = "modern_industrialization:steel_rod", count = 1 }
    },
    outputs = {
        { name = "modern_industrialization:steel_rod_magnetic", count = 1 }
    }
}
