return {
    machine = "crafter",
    inputs = {
        [2] = { name = "create:cogwheel",        count = 1 },
        [4] = { name = "create:cogwheel",        count = 1 },
        [5] = { name = "create:andesite_casing", count = 1 },
        [6] = { name = "create:cogwheel",        count = 1 },
        [8] = { name = "create:cogwheel",        count = 1 }
    },
    outputs = {
        { name = "create:gearbox", count = 8 }
    }
}
