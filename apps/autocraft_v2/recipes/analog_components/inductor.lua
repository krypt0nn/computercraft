-- standard craft
-- return {
--     machine = "crafter",
--     inputs = {
--         { name = "modern_industrialization:copper_wire", count = 1 },
--         { name = "modern_industrialization:copper_wire", count = 1 },
--         { name = "modern_industrialization:copper_wire", count = 1 },
--         { name = "modern_industrialization:copper_wire", count = 1 },
--         { name = "modern_industrialization:steel_rod",   count = 1 },
--         { name = "modern_industrialization:copper_wire", count = 1 },
--         { name = "modern_industrialization:copper_wire", count = 1 },
--         { name = "modern_industrialization:copper_wire", count = 1 },
--         { name = "modern_industrialization:copper_wire", count = 1 }
--     },
--     outputs = {
--         { name = "modern_industrialization:inductor", count = 1 }
--     }
-- }

-- assembler craft
return {
    machine = "assembler",
    inputs = {
        { name = "modern_industrialization:copper_wire", count = 8 },
        { name = "modern_industrialization:steel_rod",   count = 1 }
    },
    outputs = {
        { name = "modern_industrialization:inductor", count = 4 }
    }
}
