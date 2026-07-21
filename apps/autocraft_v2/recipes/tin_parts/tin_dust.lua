return {
    machine = "macerator",
    inputs = {
        { name = "modern_industrialization:raw_tin", count = 1 }
    },
    outputs = {
        -- real chance is 1.5 but we use lower value for guaranteed result
        { name = "modern_industrialization:tin_dust", count = 1.2 }
    }
}
