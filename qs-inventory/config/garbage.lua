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
-- Garbage Scavenging                                                           [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Controls the lootable garbage cans system. Players can search bins or dumpsters
--        around the map to find random items with dynamic amounts and rarity.
--        Each prop listed below can be configured individually for slot count and loot pool.
--──────────────────────────────────────────────────────────────────────────────
Config.GarbageItems = {}           -- [INFO] Reserved for future garbage-related flags or logic extensions.
Config.GarbageRefreshTime = 2 * 60 -- 2 hours

--──────────────────────────────────────────────────────────────────────────────
-- Garbage Objects (Registered Props)                                           [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] This list defines the in-world dumpster models that can be looted.
--        If your server does not use targeting, this section can be ignored.
--──────────────────────────────────────────────────────────────────────────────
Config.GarbageObjects = {
    'prop_dumpster_02a', -- Standard dumpster
    'prop_dumpster_4b',  -- Large blue dumpster
    'prop_dumpster_4a',  -- Large green dumpster
    'prop_dumpster_3a',  -- Small gray dumpster
    'prop_dumpster_02b', -- Alternate dumpster model
    'prop_dumpster_01a'  -- Basic dumpster model
}

--──────────────────────────────────────────────────────────────────────────────
-- Loot Tables Per Prop                                                         [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Maps dumpster models (joaat hashes) to their respective loot inventories.
--        Each entry defines:
--        • label → UI label shown when looting
--        • slots → max number of items the container can hold
--        • items → actual loot entries with random quantity ranges
--──────────────────────────────────────────────────────────────────────────────
Config.GarbageItemsForProp = {
    [joaat('prop_dumpster_02a')] = {
        label = 'Garbage', -- [INFO] UI label displayed when interacting
        slots = 30,        -- [EDIT] Total available item slots in dumpster
        items = {
            [1] = {
                [1] = {
                    name = 'aluminum',
                    amount = { min = 1, max = 5 },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'metalscrap',
                    amount = { min = 1, max = 5 },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
            [2] = {
                [1] = {
                    name = 'iron',
                    amount = { min = 1, max = 5 },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'steel',
                    amount = { min = 1, max = 5 },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
        }
    },
    [joaat('prop_dumpster_4b')] = {
        label = 'Garbage',
        slots = 30,
        items = {
            [1] = {
                [1] = {
                    name = 'aluminum',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'plastic',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
            [2] = {
                [1] = {
                    name = 'plastic',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'metalscrap',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
        }
    },
    [joaat('prop_dumpster_4a')] = {
        label = 'Garbage',
        slots = 30,
        items = {
            [1] = {
                [1] = {
                    name = 'aluminum',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'metalscrap',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
            [2] = {
                [1] = {
                    name = 'glass',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'joint',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
        }
    },
    [joaat('prop_dumpster_3a')] = {
        label = 'Garbage',
        slots = 30,
        items = {
            [1] = {
                [1] = {
                    name = 'aluminum',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'lighter',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
            [2] = {
                [1] = {
                    name = 'metalscrap',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'rubber',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
        }
    },
    [joaat('prop_dumpster_02b')] = {
        label = 'Garbage',
        slots = 30,
        items = {
            [1] = {
                [1] = {
                    name = 'metalscrap',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'rubber',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
            [2] = {
                [1] = {
                    name = 'iron',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'steel',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
        }
    },
    [joaat('prop_dumpster_01a')] = {
        label = 'Garbage',
        slots = 30,
        items = {
            [1] = {
                [1] = {
                    name = 'plastic',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'metalscrap',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
            [2] = {
                [1] = {
                    name = 'lighter',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 1,
                },
                [2] = {
                    name = 'metalscrap',
                    amount = {
                        min = 1,
                        max = 5
                    },
                    info = {},
                    type = 'item',
                    slot = 2,
                },
            },
        }
    },
}
