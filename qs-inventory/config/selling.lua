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
-- Seller Configuration                                                         [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Defines in-game stores and seller NPCs, including item lists, prices, 
--        payment accounts, and map blip settings. Each entry represents a store 
--        with its own location, available items, and visual configuration.
--──────────────────────────────────────────────────────────────────────────────
Config.SellItems = {

    --──────────────────────────────────────────────────────────────────────────
    -- Seller NPC Configuration                                                 [EDIT]
    --──────────────────────────────────────────────────────────────────────────
    ['Seller item'] = {
        coords = vec3(2682.7588, 3284.8857, 55.2103), -- [EDIT] Store location on map

        blip = { -- [EDIT] Map blip configuration
            active  = true,       -- [EDIT] Enables or disables visibility
            name    = 'Seller',   -- [EDIT] Blip title displayed on the map
            sprite  = 89,         -- [EDIT] Blip icon ID
            color   = 1,          -- [EDIT] Color of the blip
            scale   = 0.5,        -- [EDIT] Blip icon size
            account = 'money',    -- [EDIT] Payment source ('money', 'bank', etc.)
        },

        items = { -- [EDIT] Items available for sale
            {
                name   = 'sandwich',
                price  = 3,
                amount = 1,
                info   = {},
                type   = 'item',
                slot   = 1,
            },
            {
                name   = 'tosti',
                price  = 2,
                amount = 1,
                info   = {},
                type   = 'item',
                slot   = 2,
            },
            {
                name   = 'water_bottle',
                price  = 2,
                amount = 1,
                info   = {},
                type   = 'item',
                slot   = 3,
            },
        }
    },

    --──────────────────────────────────────────────────────────────────────────
    -- 24/7 Store Configuration                                                 [EDIT]
    --──────────────────────────────────────────────────────────────────────────
    ['24/7'] = {
        coords = vec3(2679.9326, 3276.6897, 54.4058), -- [EDIT] Store location

        blip = { -- [EDIT] Blip settings for 24/7 store
            active  = true,
            name    = '24/7 Store',
            sprite  = 89,
            color   = 1,
            scale   = 0.5,
            account = 'money',
        },

        items = { -- [EDIT] Items sold in this store
            {
                name   = 'tosti',
                price  = 1,
                amount = 1,
                info   = {},
                type   = 'item',
                slot   = 1,
            },
        }
    },
}
