return {
    machine = "macerator",
    inputs = {
        { name = "minecraft:diamond", count = 1 }
    },
    outputs = {
        -- real chance is 1.5 but we use lower value for guaranteed result
        { name = "modern_industrialization:diamond_dust", count = 1.2 }
    }
}
