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

---@generic T
---@param data {[string]: string}
---@return string | false
local function DependencyCheck(data) -- [CORE] Detects the first started dependency and returns its alias.
    for k, v in pairs(data) do
        if GetResourceState(k):find('started') ~= nil then
            return v
        end
    end
    return false
end

Config          = Config or {}  -- [CORE] Main configuration table.
Locales         = Locales or {} -- [CORE] Language packs container.

--──────────────────────────────────────────────────────────────────────────────
-- Language Selection                                                          [EDIT]
-- [INFO] Choose your preferred language in locales/* or add your own.
-- Available:
-- 'ar','bg','ca','cs','da','de','el','en','es','fa','fr','hi','hu','it','ja',
-- 'ko','nl','no','pl','pt','ro','ru','sl','sv','th','tr','zh-CN','zh-TW'
--──────────────────────────────────────────────────────────────────────────────
Config.Language = 'fr' -- [EDIT]

--[[ [INFO]
    Choose your preferred language!

    In this section, you can select the main language for your asset. We have a wide
    selection of default languages available, located in the locales/* folder.

    If your language is not listed, you can create a new one by adding a file
    in locales and customizing it to your needs.
]]

--──────────────────────────────────────────────────────────────────────────────
-- Framework Detection & Configuration (Inventory)                              [AUTO]
-- [INFO] Auto-detects qb-core / es_extended / qbx_core. If you renamed them,
-- set adapters or assign manually. Avoid edits unless you know the framework.
--──────────────────────────────────────────────────────────────────────────────
local frameworks = { -- [CORE] Resource name → internal alias
    ['es_extended'] = 'esx',
    ['qb-core']     = 'qb',
    ['qbx_core']    = 'qb'
}
Config.Framework = DependencyCheck(frameworks) or 'none'     -- [AUTO]

local qbxHas     = GetResourceState('qbx_core') == 'started' -- [AUTO]
Config.QBX       = qbxHas                                    -- [AUTO]

--[[ [INFO]
    Manual setup (only if necessary):
      1) Clear Config.Framework auto-detection and set your custom alias.
      2) Update framework-specific calls in client/server where required.
    Warning: Wrong edits here can break core functionality.
]]

--──────────────────────────────────────────────────────────────────────────────
-- Security                                                                    [EDIT]
-- [INFO] Disables client-side shop generation via `inventory:server:OpenInventory`.
-- If enabled, you must use the provided server exports/events to create & open shops.
--──────────────────────────────────────────────────────────────────────────────
Config.DisableShopGenerationOnClient = false -- [EDIT] true = client shop-gen disabled

-- [INFO] Safe APIs to use when disabling client shop-gen:
--   Server exports: CreateShop, OpenShop
--   Server event:  inventory:openShop
-- Example (client): TriggerServerEvent('inventory:openShop', 'shop_name')

--──────────────────────────────────────────────────────────────────────────────
-- Backward Compatibility (qs-inventory Migration)                              [EDIT]
-- [INFO] One-time migration from older qs-inventory data. Set true ONCE.
-- After completion (console shows 'Backward compatibility has been completed'),
-- immediately set back to false. Do NOT change other settings during migration.
--──────────────────────────────────────────────────────────────────────────────
Config.FetchOldInventory             = false -- [EDIT] Use true once for migration, then false.

--──────────────────────────────────────────────────────────────────────────────
-- Targeting                                                                   [EDIT]
-- [INFO] Enable qb-target / ox_target. If false, targeting is disabled.
--──────────────────────────────────────────────────────────────────────────────
Config.UseTarget                     = false -- [EDIT]

--──────────────────────────────────────────────────────────────────────────────
-- General Inventory Settings                                                   [EDIT]
-- [INFO] Core behavior for interactions, UI and safety features.
--──────────────────────────────────────────────────────────────────────────────
Config.ThrowKeybind                  = false                     -- [EDIT] Key to throw items; false to disable.
Config.PoliceCanSeeSixthSlot         = true                    -- [EDIT] Police can see protected 6th slot.
Config.PoliceJobs                    = { 'police', 'sheriff' } -- [EDIT] Jobs treated as police.
Config.BlockedSlot                   = true                    -- [EDIT] Lock 6th slot to prevent stealing.
Config.GiveItemHideName              = false                   -- [EDIT] Hide item names on give; show only ID.
Config.OpenProgressBar               = false                   -- [EDIT] Show progress bar on open (dup-prevention).
Config.EnableSounds                  = false                   -- [EDIT] Toggle default inventory sounds.
Config.EnableThrow                   = false                    -- [EDIT] Allow throwing items.
Config.UseJonskaItemThrow            = false                   -- [EDIT] Use custom throw (see custom/misc/jonska.lua).
Config.EnableTrade                   = false                    -- [EDIT] Safe MMORPG-style trade.
Config.EnableChangeLabel             = false                    -- [EDIT] One-click rename items.

Config.Handsup                       = true                    -- [EDIT] Enable hands-up & robbery options.
Config.StealDeadPlayer               = true                    -- [EDIT] Allow looting dead players.
Config.StealWithoutWeapons           = false                   -- [EDIT] Can only rob if target is hands-up w/o weapon.
Config.PlaceableItems                = true                    -- [EDIT] Enable placeable items.

--──────────────────────────────────────────────────────────────────────────────
-- Player Inventory Capacity                                                    [EDIT]
-- [INFO] Changing weight/slots can require wipes to avoid dupes. Be cautious.
--──────────────────────────────────────────────────────────────────────────────
Config.InventoryWeight               = { -- [EDIT]
    weight = 9000000,                     -- [INFO] Max weight (grams).
    slots  = 41,                         -- [INFO] Set 40 to remove protected 6th slot.
}

--──────────────────────────────────────────────────────────────────────────────
-- Drop (Ground) Capacity                                                       [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.DropWeight                    = { -- [EDIT]
    weight = 20000000,                   -- [INFO] Max ground drop capacity (grams).
    slots  = 130,                        -- [INFO] Max slots for a ground drop.
}

--──────────────────────────────────────────────────────────────────────────────
-- Label Change                                                                 [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.LabelChange                   = true  -- [EDIT] Allow item renaming.
Config.LabelChangePrice              = false -- [EDIT] Price or false for free.
Config.BlockedLabelChangeItems       = {     -- [EDIT] Items that cannot be renamed.
    money = true,
    phone = true,
}

--──────────────────────────────────────────────────────────────────────────────
-- Hotbar                                                                      [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.UsableItemsFromHotbar         = true -- [EDIT] Use items from hotbar (1–5).
Config.BlockedItemsHotbar            = {    -- [EDIT] Items blocked from hotbar use.
    'lockpick',
    -- Add more here ...
}

--──────────────────────────────────────────────────────────────────────────────
-- Backpack & Item Rules                                                        [EDIT]
-- [INFO] One-per-item limits, non-stealable and non-storable item lists.
--──────────────────────────────────────────────────────────────────────────────
Config.OnePerItem                    = { -- [EDIT] Max quantity per item type.
    backpack = 1,
    -- Add more items as needed.
}

Config.notStolenItems                = { -- [EDIT] Items that cannot be stolen.
    id_card      = true,
    water_bottle = true,
    tosti        = true,
}

Config.notStoredItems                = { -- [EDIT] Items that cannot be stashed.
    backpack = true,
}

--──────────────────────────────────────────────────────────────────────────────
-- Armor                                                                        [EDIT]
--──────────────────────────────────────────────────────────────────────────────
Config.DrawableArmor                 = 100 -- [EDIT] Armor points granted when wearing an armor vest.

--──────────────────────────────────────────────────────────────────────────────
-- Clothing System Integration                                                 [EDIT]
-- [INFO] Enables or disables clothing system integration. Refer to documentation:
-- ESX Docs: https://docs.quasar-store.com/ Inventory > Functions > Clothing
-- QB Docs:  https://docs.quasar-store.com/
--──────────────────────────────────────────────────────────────────────────────
Config.Clothing                      = true -- [EDIT] Enables clothing options in inventory (adds clothing button).

---@type ClotheSlot[]
Config.ClothingSlots                 = { -- [EDIT] Define which slots are used for clothing pieces.
    {
        name = 'helmet',
        slot = 1,
        type = 'head',
        wearType = 'prop',
        componentId = 0,
        anim = { dict = 'mp_masks@standard_car@ds@', anim = 'put_on_mask', flags = 49 }
    },
    {
        name = 'mask',
        slot = 2,
        type = 'head',
        wearType = 'drawable',
        componentId = 1,
        anim = { dict = 'mp_masks@standard_car@ds@', anim = 'put_on_mask', flags = 49 }
    },
    {
        name = 'glasses',
        slot = 3,
        type = 'head',
        wearType = 'prop',
        componentId = 1,
        anim = { dict = 'clothingspecs', anim = 'take_off', flags = 49 }
    },
    {
        name = 'torso',
        slot = 4,
        type = 'body',
        wearType = 'drawable',
        componentId = 11,
        anim = { dict = 'missmic4', anim = 'michael_tux_fidget', flags = 49 }
    },
    {
        name = 'tshirt',
        slot = 5,
        type = 'body',
        wearType = 'drawable',
        componentId = 8,
        anim = { dict = 'clothingtie', anim = 'try_tie_negative_a', flags = 49 }
    },
    {
        name = 'jeans',
        slot = 6,
        type = 'body',
        wearType = 'drawable',
        componentId = 4,
        anim = { dict = 'missmic4', anim = 'michael_tux_fidget', flags = 49 }
    },
    {
        name = 'arms',
        slot = 7,
        type = 'body',
        wearType = 'drawable',
        componentId = 3,
        anim = { dict = 'nmt_3_rcm-10', anim = 'cs_nigel_dual-10', flags = 49 }
    },
    {
        name = 'shoes',
        slot = 8,
        type = 'body',
        wearType = 'drawable',
        componentId = 6,
        anim = { dict = 'random@domestic', anim = 'pickup_low', flags = 49 }
    },
    {
        name = 'ears',
        slot = 9,
        type = 'body',
        wearType = 'prop',
        componentId = 2,
        anim = { dict = 'mp_cp_stolen_tut', anim = 'b_think', flags = 49 }
    },
    {
        name = 'bag',
        slot = 10,
        type = 'addon',
        wearType = 'drawable',
        componentId = 5,
        anim = { dict = 'anim@heists@ornate_bank@grab_cash', anim = 'intro', flags = 49 }
    },
    {
        name = 'watch',
        slot = 11,
        type = 'addon',
        wearType = 'prop',
        componentId = 6,
        anim = { dict = 'nmt_3_rcm-10', anim = 'cs_nigel_dual-10', flags = 49 }
    },
    {
        name = 'bracelets',
        slot = 12,
        type = 'addon',
        wearType = 'prop',
        componentId = 7,
        anim = { dict = 'nmt_3_rcm-10', anim = 'cs_nigel_dual-10', flags = 49 }
    },
    {
        name = 'chain',
        slot = 13,
        type = 'addon',
        wearType = 'drawable',
        componentId = 7,
        anim = { dict = 'nmt_3_rcm-10', anim = 'cs_nigel_dual-10', flags = 49 }
    },
    {
        name = 'vest',
        slot = 14,
        type = 'addon',
        wearType = 'drawable',
        componentId = 9,
        anim = { dict = 'nmt_3_rcm-10', anim = 'cs_nigel_dual-10', flags = 49 }
    },
}

--──────────────────────────────────────────────────────────────────────────────
-- Appearance System Detection                                                 [AUTO]
-- [INFO] Auto-detects supported appearance/clothing resources.
--──────────────────────────────────────────────────────────────────────────────
local appearances                    = { -- [CORE] Resource name → internal alias
    ['illenium-appearance'] = 'illenium',
    ['qs-appearance']       = 'illenium',
    ['rcore_clothing']      = 'rcore',
    ['esx_skin']            = 'esx',
    ['qb-clothing']         = 'qb'
}
Config.Appearance                    = DependencyCheck(appearances) or 'standalone' -- [AUTO]

Config.TakePreviousClothes           = false                                        -- [EDIT] Adds previous worn clothes back to inventory when changing.

--──────────────────────────────────────────────────────────────────────────────
-- Drop Settings                                                               [EDIT]
-- [INFO] Control dropped items visuals and refresh system.
--──────────────────────────────────────────────────────────────────────────────
Config.ItemDropObject                = `prop_paper_bag_small` -- [EDIT] Model for dropped items (false = no object)
Config.DropRefreshTime               = 15 * 60                -- [EDIT] Refresh time for ground items (seconds)
Config.MaxDropViewDistance           = 2.5                    -- [EDIT] Max view distance for dropped items

--──────────────────────────────────────────────────────────────────────────────
-- Gender System                                                               [EDIT]
-- [INFO] Defines available gender labels for use in UI and logic.
--──────────────────────────────────────────────────────────────────────────────
Config.Genders                       = {
    ['m'] = 'Male',
    ['f'] = 'Female',
    [1]   = 'Male',
    [2]   = 'Female'
}

--──────────────────────────────────────────────────────────────────────────────
-- Visual Configuration                                                        [EDIT]
-- [INFO] Controls animations, UI logo, idle camera and sidebar visibility.
--──────────────────────────────────────────────────────────────────────────────
Config.OpenInventoryAnim             = false                                      -- [EDIT] Play animation when opening inventory
Config.OpenInventoryScene            = false                                     -- [EDIT] Toggle scene animation
Config.Logo                          = 'https://i.ibb.co/Q7ysgpcR/logofond.png' -- [EDIT] Logo (URL or local path)
Config.IdleCamera                    = false                                      -- [EDIT] Enable idle camera while inventory open

--──────────────────────────────────────────────────────────────────────────────
-- Sidebar & Display Options                                                   [EDIT]
-- [INFO] Defines what stats and menus appear in the UI.
--──────────────────────────────────────────────────────────────────────────────
Config.InventoryOptions              = {
    ['clothes']       = Config.Clothing, -- [EDIT] Enable clothing button
    ['configuration'] = true,            -- [EDIT] Show config menu
    ['health']        = false,            -- [EDIT] Show player health
    ['armor']         = false,            -- [EDIT] Show armor level
    ['hunger']        = false,            -- [EDIT] Show hunger
    ['thirst']        = false,            -- [EDIT] Show thirst
    ['id']            = false,            -- [EDIT] Show player ID
    ['money']         = false,            -- [EDIT] Show cash
    ['bank']          = false,            -- [EDIT] Show bank balance
    ['blackmoney']    = false,            -- [EDIT] Show black money
}

--──────────────────────────────────────────────────────────────────────────────
-- Item Mini Icons                                                             [EDIT]
-- [INFO] Assign FontAwesome icons to items in UI. (https://fontawesome.com/)
--──────────────────────────────────────────────────────────────────────────────
Config.ItemMiniIcons                 = {
    ['tosti'] = { icon = 'fa-solid fa-utensils' },
    ['water_bottle'] = { icon = 'fa-solid fa-utensils' },
}

--──────────────────────────────────────────────────────────────────────────────
-- Item Rarities                                                               [EDIT]
-- [INFO] Define rarity gradients for inventory visuals.
--──────────────────────────────────────────────────────────────────────────────
Config.ItemRarities                  = {
    { name = 'common',    css = 'background-image: linear-gradient(to top, rgba(211,211,211,0.5), rgba(211,211,211,0) 60%)' },
    { name = 'epic',      css = 'background-image: linear-gradient(to top, rgba(128,0,128,0.5), rgba(128,0,128,0) 60%)' },
    { name = 'legendary', css = 'background-image: linear-gradient(to top, rgba(255,215,0,0.5), rgba(255,215,0,0) 60%)' },
}

--──────────────────────────────────────────────────────────────────────────────
-- Default Character Appearance                                                [EDIT]
-- [INFO] Base clothing sets per gender. Adjust for custom clothing systems.
--──────────────────────────────────────────────────────────────────────────────
Config.Defaults                      = {
    ['female'] = {
        torso = 18,
        jeans = 19,
        shoes = 34,
        arms = 15,
        helmet = -1,
        glasses = -1,
        mask = 0,
        tshirt = 2,
        ears = -1,
        bag = 0,
        watch = -1,
        chain = 0,
        bracelets = -1,
        vest = 0,
    },
    ['male'] = {
        torso = 15,
        jeans = 14,
        shoes = 34,
        arms = 15,
        helmet = -1,
        glasses = -1,
        mask = 0,
        tshirt = 15,
        ears = -1,
        bag = 0,
        watch = -1,
        chain = 0,
        bracelets = -1,
        vest = 0,
    }
}

--──────────────────────────────────────────────────────────────────────────────
-- Compact Inventory                                                            [EDIT]
-- [INFO] Turns your inventory into a compact, side-mounted interface allowing
--        movement while open — signature Quasar experience.
--──────────────────────────────────────────────────────────────────────────────
Config.CompactInventory              = false -- [EDIT] Enables compact view for a smaller, mobile-friendly layout.

--──────────────────────────────────────────────────────────────────────────────
-- Key Bindings                                                                [EDIT]
-- [INFO] Define shortcut keys for inventory actions. See documentation for keymap setup.
--──────────────────────────────────────────────────────────────────────────────
Config.KeyBinds                      = { -- [EDIT]
    inventory = 'TAB',                   -- [INFO] Open inventory
    hotbar    = 'Z',                     -- [INFO] Show hotbar
    reload    = 'R',                     -- [INFO] Reload action
    handsup   = 'X',                     -- [INFO] Hands-up/robbery gesture
}

--──────────────────────────────────────────────────────────────────────────────
-- Debug & Development Tools                                                   [EDIT]
-- [INFO] Enables development logs and debugging prints. Use only during testing.
--──────────────────────────────────────────────────────────────────────────────
Config.Debug                         = true       -- [EDIT] Detailed console prints
Config.ZoneDebug                     = true       -- [EDIT] Display additional zone debug info
Config.InventoryPrefix               = 'inventory' -- [ADV] Internal prefix; changing requires code adjustments
Config.SaveInventoryInterval         = 12500       -- [EDIT] Autosave interval (ms)
Config.BypassQbInventory             = true        -- [EDIT] Bypass qb-inventory for QS compatibility

--[[ [INFO]
    The system now saves inventories when updates occur instead of on close,
    reducing duplication risks. Avoid frequent restarts, as unsaved data may be lost.

    Command available:
      /save-inventories → Manually saves all inventories before restart.
]]

--──────────────────────────────────────────────────────────────────────────────
-- Free Mode Keys                                                              [EDIT]
-- [INFO] Controls for object manipulation during free placement/edit modes.
--──────────────────────────────────────────────────────────────────────────────
Config.FreeModeKeys = {
    ChangeKey        = Keys['LEFTCTRL'], -- [EDIT] Toggle free mode
    MoreSpeed        = Keys['.'],        -- [EDIT] Increase move speed
    LessSpeed        = Keys[','],        -- [EDIT] Decrease move speed
    MoveToTop        = Keys['TOP'],      -- [EDIT] Move upward
    MoveToDown       = Keys['DOWN'],     -- [EDIT] Move downward
    MoveToForward    = Keys['TOP'],      -- [EDIT] Move forward
    MoveToBack       = Keys['DOWN'],     -- [EDIT] Move backward
    MoveToRight      = Keys['RIGHT'],    -- [EDIT] Move right
    MoveToLeft       = Keys['LEFT'],     -- [EDIT] Move left
    RotateToTop      = Keys['6'],        -- [EDIT] Rotate upward
    RotateToDown     = Keys['7'],        -- [EDIT] Rotate downward
    RotateToLeft     = Keys['8'],        -- [EDIT] Rotate left
    RotateToRight    = Keys['9'],        -- [EDIT] Rotate right
    TiltToTop        = Keys['Z'],        -- [EDIT] Tilt upward
    TiltToDown       = Keys['X'],        -- [EDIT] Tilt downward
    TiltToLeft       = Keys['C'],        -- [EDIT] Tilt left
    TiltToRight      = Keys['V'],        -- [EDIT] Tilt right
    StickToTheGround = Keys['LEFTALT'],  -- [EDIT] Snap object to ground
}

--──────────────────────────────────────────────────────────────────────────────
-- Editor Action Controls                                                      [EDIT]
-- [INFO] Keybinds used in world/zone editing for point and rotation handling.
--──────────────────────────────────────────────────────────────────────────────
ActionControls      = {
    leftClick       = { label = 'Place Object', codes = { 24 } },       -- [EDIT]
    forward         = { label = 'Forward +/-', codes = { 33, 32 } },    -- [EDIT] Move forward/backward
    right           = { label = 'Right +/-', codes = { 35, 34 } },      -- [EDIT] Move left/right
    up              = { label = 'Up +/-', codes = { 52, 51 } },         -- [EDIT] Raise/lower vertically
    add_point       = { label = 'Add Point', codes = { 24 } },          -- [EDIT]
    undo_point      = { label = 'Undo Last', codes = { 25 } },          -- [EDIT]
    rotate_z        = { label = 'RotateZ +/-', codes = { 20, 79 } },    -- [EDIT] Z-axis rotation
    rotate_y        = { label = 'RotateY +/-', codes = { 29, 249 } },   -- [EDIT] Y-axis rotation
    rotate_x        = { label = 'RotateX +/-', codes = { 311, 182 } },  -- [EDIT] X-axis rotation
    rotate_z_scroll = { label = 'RotateZ +/-', codes = { 17, 16 } },    -- [EDIT] Z-axis via scroll modifiers
    offset_z        = { label = 'Offset Z +/-', codes = { 44, 46 } },   -- [EDIT] Vertical offset
    boundary_height = { label = 'Z Boundary +/-', codes = { 20, 73 } }, -- [EDIT] Change Z boundary
    done            = { label = 'Done', codes = { 191 } },              -- [EDIT] Confirm/finish
    cancel          = { label = 'Cancel', codes = { 194 } },            -- [EDIT] Cancel current action
    throw           = { label = 'Throw', codes = { 24, 25 } },          -- [EDIT] Throw current weapon
}
--──────────────────────────────────────────────────────────────────────────────
-- Free Camera Options                                                         [EDIT]
-- [INFO] Camera movement and rotation speed configuration for editors/previews.
--──────────────────────────────────────────────────────────────────────────────
CameraOptions       = {
    lookSpeedX  = 1000.0, -- [EDIT] Horizontal camera movement speed
    lookSpeedY  = 1000.0, -- [EDIT] Vertical camera movement speed
    moveSpeed   = 20.0,   -- [EDIT] Free camera move speed
    climbSpeed  = 10.0,   -- [EDIT] Up/Down movement speed
    rotateSpeed = 20.0,   -- [EDIT] Rotation speed
}
