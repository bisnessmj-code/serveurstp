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
-- Storage Containers                                                           [EDIT]
--──────────────────────────────────────────────────────────────────────────────
-- [INFO] Defines items that act as physical containers capable of holding other items.
--        Example: a cigarette box containing multiple cigarettes.
--        Containers have their own weight, slot capacity, and optional default contents.
--
--        How it works:
--        • Define a container item (e.g. 'cigarettebox').
--        • Set its internal storage capacity (slots + weight).
--        • Optionally preload items inside with metadata and amounts.
--
--        This feature enhances immersion and realism, especially for roleplay setups.
--──────────────────────────────────────────────────────────────────────────────
Config.Storage = {

    [1] = {
        name   = "cigarettebox",  -- [EDIT] Unique name of the container item
        label  = "Cigarette Box", -- [EDIT] Display name in inventory
        weight = 50,              -- [EDIT] Max total weight the container can hold
        slots  = 1,               -- [EDIT] Max number of different item types allowed

        items = { -- [EDIT] Default contents of this container
            [1] = {
                name        = "cigarette",         -- [INFO] Item identifier
                label       = "Cigarette",         -- [INFO] Display name
                description = "A single cigarette",-- [INFO] Short description
                useable     = true,                -- [EDIT] Can the item be used
                type        = "item",              -- [INFO] Inventory type
                amount      = 20,                  -- [EDIT] Default quantity
                weight      = 1,                   -- [EDIT] Weight per unit
                unique      = false,               -- [EDIT] Unique (non-stackable)
                slot        = 1,                   -- [INFO] Slot position inside container
                info        = {},                  -- [ADV] Metadata or custom data
            },
            -- [EDIT] Add more default items here if needed.
        },
    },

    -- [EDIT] Add more container definitions below.
}
