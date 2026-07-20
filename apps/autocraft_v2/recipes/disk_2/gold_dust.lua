return {
    machine = "macerator",
    inputs = {
        { name = "minecraft:raw_gold", count = 1 }
    },
    outputs = {
        -- real chance is 1.5 but we use lower value for guaranteed result
        { name  = "modern_industrialization:gold_dust", count = 1.2 }
    }
}
