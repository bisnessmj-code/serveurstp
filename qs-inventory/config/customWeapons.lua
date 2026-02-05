--──────────────────────────────────────────────────────────────────────────────
-- Custom Weapons                                                               [EDIT]
-- [INFO] Map weapon names to allowed attachments and durability loss per shot.
-- [INFO] You must also register these in items.lua and weapons.lua.
-- [REF]  Example reference: https://github.com/NoobySloth/Custom-Weapons/tree/main
--──────────────────────────────────────────────────────────────────────────────
Config.CustomWeapons = {
    -- -- Example:
    -- ['WEAPON_AK47'] = {
    --     attachments = {
    --         defaultclip = { component = 'COMPONENT_AK47_CLIP_01', item = 'rifle_defaultclip' }, -- [EDIT]
    --         extendedclip = { component = 'COMPONENT_AK47_CLIP_02', item = 'rifle_extendedclip' }, -- [EDIT]
    --         -- Add more: scope = { component = 'COMPONENT_AK47_SCOPE', item = 'rifle_scope' },
    --     },
    --     durability = 0.15 -- [EDIT] Durability decay per shot (0.0–1.0; higher = wears faster)
    -- },
}