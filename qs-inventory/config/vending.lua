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
-- Vending Machine Configuration                                                [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Defines vending machine categories, their available items, and prop models.
--        Each category can contain multiple items with prices and stock amounts.
--        Machines link to these categories by model name for contextual interaction.
--──────────────────────────────────────────────────────────────────────────────
Config.VendingMachines = {

    --──────────────────────────────────────────────────────────────────────────
    -- Drinks Category                                                         [EDIT]
    --──────────────────────────────────────────────────────────────────────────
    ['drinks'] = {
        Label = 'Drinks',
        Items = {
            [1] = {
                name   = 'kurkakola', -- [INFO] Drink item name
                price  = 4,            -- [EDIT] Item price
                amount = 50,           -- [EDIT] Stock quantity
                info   = {},           -- [ADV] Metadata
                type   = 'item',       -- [INFO] Type of entry
                slot   = 1,            -- [INFO] Slot index in menu
            },
            [2] = {
                name   = 'water_bottle',
                price  = 4,
                amount = 50,
                info   = {},
                type   = 'item',
                slot   = 2,
            },
        },
    },

    --──────────────────────────────────────────────────────────────────────────
    -- Candy Category                                                          [EDIT]
    --──────────────────────────────────────────────────────────────────────────
    ['candy'] = {
        Label = 'Candy',
        Items = {
            [1] = {
                name   = 'chocolate', -- [INFO] Candy item
                price  = 4,           -- [EDIT] Item price
                amount = 50,          -- [EDIT] Stock
                info   = {},
                type   = 'item',
                slot   = 1,
            },
        },
    },

    --──────────────────────────────────────────────────────────────────────────
    -- Coffee Category                                                         [EDIT]
    --──────────────────────────────────────────────────────────────────────────
    ['coffee'] = {
        Label = 'Coffee',
        Items = {
            [1] = {
                name   = 'coffee',  -- [INFO] Coffee item
                price  = 4,
                amount = 50,
                info   = {},
                type   = 'item',
                slot   = 1,
            },
        },
    },

    --──────────────────────────────────────────────────────────────────────────
    -- Water Category                                                          [EDIT]
    --──────────────────────────────────────────────────────────────────────────
    ['water'] = {
        Label = 'Water',
        Items = {
            [1] = {
                name   = 'water_bottle', -- [INFO] Water bottle item
                price  = 4,
                amount = 50,
                info   = {},
                type   = 'item',
                slot   = 1,
            },
        },
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Vending Machine Models                                                      [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Lists vending machine props and links them to a category defined above.
--        Allows interaction with corresponding items based on prop model type.
--──────────────────────────────────────────────────────────────────────────────
Config.Vendings = {
    [1] = { Model = 'prop_vend_coffe_01',     Category = 'coffee' },
    [2] = { Model = 'prop_vend_water_01',     Category = 'water'  },
    [3] = { Model = 'prop_watercooler',       Category = 'water'  },
    [4] = { Model = 'prop_watercooler_Dark',  Category = 'water'  },
    [5] = { Model = 'prop_vend_snak_01',      Category = 'candy'  },
    [6] = { Model = 'prop_vend_snak_01_tu',   Category = 'candy'  },
    [7] = { Model = 'prop_vend_fridge01',     Category = 'drinks' },
    [8] = { Model = 'prop_vend_soda_01',      Category = 'drinks' },
    [9] = { Model = 'prop_vend_soda_02',      Category = 'drinks' },
}
