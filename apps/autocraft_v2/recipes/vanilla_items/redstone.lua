return {
    machine = "compressor",
    inputs = {
        { name = "modern_industrialization:redstone_crushed_dust", count = 1 }
    },
    outputs = {
        -- real chance is 1.5 but we use lower value for guaranteed result
        { name = "minecraft:redstone", count = 1.5 }
    }
}
