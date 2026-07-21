return {
    machine = "macerator",
    inputs = {
        { name = "modern_industrialization:lignite_coal_crushed_dust", count = 1 }
    },
    outputs = {
        -- real chance is 1.5 but we use lower value for guaranteed result
        { name = "modern_industrialization:lignite_coal_dust", count = 1.2 },

        -- real chance is 0.5 but we use lower value for guaranteed result
        { name = "modern_industrialization:sulfur_dust", count = 0.2 }
    }
}
