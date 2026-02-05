--──────────────────────────────────────────────────────────────────────────────
--  Quasar Store · Configuration Guidelines
--──────────────────────────────────────────────────────────────────────────────
--  This configuration file defines all adjustable parameters for the script.
--  Comments are standardized to help you identify which sections you can safely edit.
--
--  • [EDIT] – Safe for users to modify. Adjust these values as needed.
--  • [INFO] – Informational note describing what the variable or block does.
--  • [ADV]  – Advanced settings. Change only if you understand the logic behind it.
--  • [CORE] – Core functionality. Do not modify unless you are a developer.
--  • [AUTO] – Automatically handled by the system. Never edit manually.
--
--  Always make a backup before editing configuration files.
--  Incorrect changes in [CORE] or [AUTO] sections can break the resource.
--──────────────────────────────────────────────────────────────────────────────

--──────────────────────────────────────────────────────────────────────────────
-- Vehicle Configuration System                                                 [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Defines storage and access rules for vehicles, including trunk and glovebox.
--        Supports ownership checks, police access overrides, and custom vehicle setups.
--──────────────────────────────────────────────────────────────────────────────
Config.IsVehicleOwned           = false -- [EDIT] If true, only owned vehicles retain trunk data.
Config.UseItemInVehicle         = true  -- [EDIT] Disable item usage inside vehicles when false.
Config.WeaponsOnVehicle         = true  -- [EDIT] Disable weapon storage in vehicles when false (may affect performance).

Config.OpenTrunkAll             = true  -- [EDIT] Allow any player to open any trunk.
Config.OpenTrunkPolice          = true  -- [EDIT] Allow police to bypass trunk restrictions.
Config.OpenTrunkPoliceGrade     = 0     -- [EDIT] Minimum police grade to open trunks when restricted.

Config.OpenGloveboxesAll        = true  -- [EDIT] Allow any player to open any glovebox.
Config.OpenGloveboxesPolice     = true  -- [EDIT] Allow police to bypass glovebox restrictions.
Config.OpenGloveboxesPoliceGrade = 0    -- [EDIT] Minimum police grade to open gloveboxes when restricted.

--──────────────────────────────────────────────────────────────────────────────
-- Vehicle Class Storage Capacities                                             [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Defines weight and slot capacity for gloveboxes and trunks by vehicle class.
--        Reference: https://docs.fivem.net/natives/?_0x29439776AAA00A62
--──────────────────────────────────────────────────────────────────────────────
Config.VehicleClass = {
    [0]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 38000,  slots = 30 } },
    [1]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 50000,  slots = 40 } },
    [2]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 75000,  slots = 50 } },
    [3]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 42000,  slots = 35 } },
    [4]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 38000,  slots = 30 } },
    [5]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 30000,  slots = 25 } },
    [6]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 30000,  slots = 25 } },
    [7]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 30000,  slots = 25 } },
    [8]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 15000,  slots = 15 } },
    [9]  = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 60000,  slots = 35 } },
    [10] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 60000,  slots = 35 } },
    [11] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 60000,  slots = 35 } },
    [12] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 120000, slots = 35 } },
    [13] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 0,      slots = 0  } },
    [14] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 120000, slots = 50 } },
    [15] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 120000, slots = 50 } },
    [16] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 120000, slots = 50 } },
    [17] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 120000, slots = 50 } },
    [18] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 120000, slots = 50 } },
    [19] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 120000, slots = 50 } },
    [20] = { glovebox = { maxweight = 100000, slots = 5 }, trunk = { maxweight = 120000, slots = 50 } },
}

--──────────────────────────────────────────────────────────────────────────────
-- Custom Vehicle Storage (Model Overrides)                                    [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Defines specific trunk/glovebox capacities for individual models, overriding class values.
--──────────────────────────────────────────────────────────────────────────────
Config.CustomTrunk = {
    [joaat('adder')] = { slots = 5, maxweight = 100000 },
}

Config.CustomGlovebox = {
    [joaat('adder')] = { slots = 5, maxweight = 100000 },
}

--──────────────────────────────────────────────────────────────────────────────
-- Front Trunk (Rear Engine Vehicles)                                          [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] For vehicles with rear engines, defines models where trunk is accessed from the front.
--──────────────────────────────────────────────────────────────────────────────
Config.BackEngineVehicles = {
    [`ninef`]        = true,
    [`adder`]        = true,
    [`vagner`]       = true,
    [`t20`]          = true,
    [`infernus`]     = true,
    [`zentorno`]     = true,
    [`reaper`]       = true,
    [`comet2`]       = true,
    [`comet3`]       = true,
    [`jester`]       = true,
    [`jester2`]      = true,
    [`cheetah`]      = true,
    [`cheetah2`]     = true,
    [`prototipo`]    = true,
    [`turismor`]     = true,
    [`pfister811`]   = true,
    [`ardent`]       = true,
    [`nero`]         = true,
    [`nero2`]        = true,
    [`tempesta`]     = true,
    [`vacca`]        = true,
    [`bullet`]       = true,
    [`osiris`]       = true,
    [`entityxf`]     = true,
    [`turismo2`]     = true,
    [`fmj`]          = true,
    [`re7b`]         = true,
    [`tyrus`]        = true,
    [`italigtb`]     = true,
    [`penetrator`]   = true,
    [`monroe`]       = true,
    [`ninef2`]       = true,
    [`stingergt`]    = true,
    [`surfer`]       = true,
    [`surfer2`]      = true,
    [`gp1`]          = true,
    [`autarch`]      = true,
    [`tyrant`]       = true,
    -- [EDIT] Add more front-trunk vehicles here if needed.
}
