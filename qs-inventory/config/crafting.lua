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
-- Crafting System                                                             [EDIT]
-- [INFO] Independent crafting, no DLC required. Supports success chance, and
--        (opcional) reputación en QBCore para bloquear/mostrar recetas.
--──────────────────────────────────────────────────────────────────────────────
Config.Crafting = true -- [EDIT] Toggle the crafting system on/off

--[[ [INFO]
    Noteworthy features:
    - Per-item success chance (1–100%)
    - Reputation-based visibility (QBCore): 'craftingrep' / 'attachmentcraftingrep'
    - Configure 'rep' fields and thresholds per your server design.
]]

--──────────────────────────────────────────────────────────────────────────────
-- Reputation (QBCore only)                                                    [EDIT]
-- [INFO] Gate items behind reputation levels. Only for QBCore frameworks.
--──────────────────────────────────────────────────────────────────────────────
Config.CraftingReputation = false -- [EDIT] Enable reputation gating (QBCore)
Config.ThresholdItems     = false -- [EDIT] Show items only if rep >= threshold (QBCore)

--──────────────────────────────────────────────────────────────────────────────
-- Example Item Entry (Reference)                                              [INFO]
--──────────────────────────────────────────────────────────────────────────────
--[[
    [1] = {
        name = "weapon_pistol",
        amount = 50,
        info = {},
        costs = {
            ["iron"] = 80,
            ["metalscrap"] = 120,
            ["rubber"] = 8,
            ["steel"] = 133,
            ["lockpick"] = 5,
        },
        type = "weapon",       -- "item" | "weapon"
        slot = 1,
        rep = 'attachmentcraftingrep', -- QBCore only
        points = 1,            -- QBCore only (reward on craft)
        threshold = 0,         -- QBCore only (visibility)
        time = 5500,           -- ms
        chance = 100           -- 1..100 success probability
    },
]]

--──────────────────────────────────────────────────────────────────────────────
-- External Crafting Event (Sample)                                            [ADV]
-- [INFO] Example to open a custom crafting menu from another script/event.
--       ⚠ Posible typo: export 'SetUpCrafing' → suele ser 'SetUpCrafting'. Mantengo tu nombre.
--──────────────────────────────────────────────────────────────────────────────
function OpenCrafting()
    local CustomCrafting = {
        [1] = {
            name = 'weapon_pistol',
            amount = 50,
            info = {},
            costs = { ['tosti'] = 1 },
            type = 'weapon',
            slot = 1,
            rep = 'attachmentcraftingrep',
            points = 1,
            threshold = 0,
            time = 5500,
            chance = 100
        },
        [2] = {
            name = 'water_bottle',
            amount = 1,
            info = {},
            costs = { ['tosti'] = 1 },
            type = 'item',
            slot = 2,
            rep = 'attachmentcraftingrep',
            points = 1,
            threshold = 0,
            time = 8500,
            chance = 100
        },
    }

    local items = exports['qs-inventory']:SetUpCrafing(CustomCrafting) -- [INFO] Revisa el nombre del export si fuera necesario.
    local crafting = { label = 'Craft', items = items }

    TriggerServerEvent('inventory:server:SetInventoryItems', items)
    TriggerServerEvent('inventory:server:OpenInventory', 'customcrafting', crafting.label, crafting)
end

--──────────────────────────────────────────────────────────────────────────────
-- Crafting Tables                                                             [EDIT]
-- [INFO] Define mesas de crafteo por job/ubicación, con blip y recetas propias.
--──────────────────────────────────────────────────────────────────────────────
Config.CraftingTables = {
    [1] = {
        name = 'Police Crafting',
        isjob = 'police',
        grades = 'all',
        text = '[E] - Police Craft',
        blip = {
            enabled = true,
            title = 'Police Crafting',
            scale = 1.0,
            display = 4,
            colour = 0,
            id = 365
        },
        location = vec3(459.771423, -989.050537, 24.898926),
        items = {
            [1] = {
                name = 'weapon_pistol',
                amount = 50,
                info = {},
                costs = {
                    ['iron'] = 80,
                    ['metalscrap'] = 70,
                    ['rubber'] = 8,
                    ['steel'] = 60,
                    ['lockpick'] = 5,
                },
                type = 'weapon',
                slot = 1,
                rep = 'attachmentcraftingrep',
                points = 1,
                threshold = 0,
                time = 5500,
                chance = 100
            },
            [2] = {
                name = 'weapon_smg',
                amount = 1,
                info = {},
                costs = {
                    ['iron'] = 80,
                    ['metalscrap'] = 120,
                    ['rubber'] = 10,
                    ['steel'] = 65,
                    ['lockpick'] = 10,
                },
                type = 'weapon',
                slot = 2,
                rep = 'attachmentcraftingrep',
                points = 1,
                threshold = 0,
                time = 8500,
                chance = 100
            },
            [3] = {
                name = 'weapon_carbinerifle',
                amount = 1,
                info = {},
                costs = {
                    ['iron'] = 120,
                    ['metalscrap'] = 120,
                    ['rubber'] = 20,
                    ['steel'] = 90,
                    ['lockpick'] = 14,
                },
                type = 'weapon',
                slot = 3,
                rep = 'craftingrep',
                points = 2,
                threshold = 0,
                time = 12000,
                chance = 100
            }
        }
    },
    [2] = {
        name = 'Attachment Crafting',
        isjob = true,
        grades = 'all',
        text = '[E] - Craft Attachment',
        blip = {
            enabled = true,
            title = 'Attachment Crafting',
            scale = 1.0,
            display = 4,
            colour = 0,
            id = 365
        },
        location = vec3(90.303299, 3745.503418, 39.771484),
        items = {
            [1] = {
                name = 'pistol_extendedclip',
                amount = 50,
                info = {},
                costs = {
                    ['metalscrap'] = 140,
                    ['steel'] = 250,
                    ['rubber'] = 60,
                },
                type = 'item',
                slot = 1,
                rep = 'attachmentcraftingrep',
                points = 1,
                threshold = 0,
                time = 8000,
                chance = 90
            },
            [2] = {
                name = 'pistol_suppressor',
                amount = 50,
                info = {},
                costs = {
                    ['metalscrap'] = 165,
                    ['steel'] = 285,
                    ['rubber'] = 75,
                },
                type = 'item',
                slot = 2,
                rep = 'attachmentcraftingrep',
                points = 1,
                threshold = 0,
                time = 8000,
                chance = 90
            },
        }
    },
    -- Continue with the same structure for the other Crafting Tables...
}
