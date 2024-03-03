# Setup

Run this command in the computer:

```
wget https://raw.githubusercontent.com/krypt0nn/computercraft/main/require.lua
```

# Usage

Add this code to the header of your script:

```lua
local packages = dofile("require.lua")({
    source = "https://raw.githubusercontent.com/krypt0nn/computercraft/main/libs",
    cache = "cache", -- Optional field
    packages = {
        fuel = {
            minimalVersion = 3
        }
    }
})

-- Your script code
-- Example:

packages.fuel.refuel()
```

If `cache` field is given, then packages will be cached to the local folder. Otherwise they will always be loaded dynamically from the internet.
