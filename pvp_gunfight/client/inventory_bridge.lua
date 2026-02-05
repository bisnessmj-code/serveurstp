-- ========================================
-- PVP GUNFIGHT - INVENTORY BRIDGE CLIENT
-- Version 4.1.0 - QS-Inventory Compatible
-- ========================================

DebugSuccess('Module Inventory Bridge chargé')

-- ========================================
-- CONFIGURATION
-- ========================================
local InventoryBridge = {}
local detectedInventory = "vanilla"

-- ========================================
-- CACHE DES NATIVES
-- ========================================
local _PlayerPedId = PlayerPedId
local _GetHashKey = GetHashKey
local _HasPedGotWeapon = HasPedGotWeapon
local _GiveWeaponToPed = GiveWeaponToPed
local _SetCurrentPedWeapon = SetCurrentPedWeapon
local _SetPedAmmo = SetPedAmmo
local _GetAmmoInPedWeapon = GetAmmoInPedWeapon
local _RemoveWeaponFromPed = RemoveWeaponFromPed
local _RemoveAllPedWeapons = RemoveAllPedWeapons
local _Wait = Wait

-- ========================================
-- DÉTECTION AUTOMATIQUE INVENTAIRE
-- ========================================
local function DetectInventory()
    if GetResourceState('qs-inventory') == 'started' then
        detectedInventory = "qs-inventory"
        return "qs-inventory"
    end
    
    if GetResourceState('ox_inventory') == 'started' then
        detectedInventory = "ox_inventory"
        return "ox_inventory"
    end
    
    if GetResourceState('qb-inventory') == 'started' then
        detectedInventory = "qb-inventory"
        return "qb-inventory"
    end
    
    detectedInventory = "vanilla"
    return "vanilla"
end

-- ========================================
-- FONCTION: FORCER RECHARGEMENT ARME
-- ========================================
local function ForceReloadWeapon(weaponHash, maxAmmo)
    local playerPed = _PlayerPedId()
    
    if not _HasPedGotWeapon(playerPed, weaponHash, false) then
        DebugWarn('Arme non équipée pour rechargement')
        return
    end
    
    local currentAmmo = _GetAmmoInPedWeapon(playerPed, weaponHash)
    
    if currentAmmo < maxAmmo then
        _SetPedAmmo(playerPed, weaponHash, maxAmmo)
        DebugClient('Rechargement forcé: %d -> %d munitions', currentAmmo, maxAmmo)
    end
end

-- ========================================
-- FONCTION: DONNER ARME (VIA INVENTAIRE)
-- ========================================
function InventoryBridge.GiveWeapon(weaponName, ammo)
    local playerPed = _PlayerPedId()
    local weaponHash = _GetHashKey(weaponName)
    
    DebugClient('Attribution arme: %s (%s)', weaponName, detectedInventory)
    
    if detectedInventory == "qs-inventory" then
        -- 🔴 MÉTHODE QS-INVENTORY
        DebugClient('Utilisation QS-Inventory')
        
        -- Vérifier si l'arme est déjà dans l'inventaire
        local hasWeapon = exports['qs-inventory']:GetItemTotalAmount(weaponName)
        
        if not hasWeapon or hasWeapon == 0 then
            -- Demander au serveur d'ajouter l'arme à l'inventaire
            TriggerServerEvent('pvp:giveWeaponInventory', weaponName, ammo)
            _Wait(200) -- Attendre que l'inventaire soit mis à jour
        end
        
        -- Forcer l'équipement de l'arme
        _Wait(100)
        
        if not _HasPedGotWeapon(playerPed, weaponHash, false) then
            _GiveWeaponToPed(playerPed, weaponHash, ammo, false, true)
        end
        
        _SetCurrentPedWeapon(playerPed, weaponHash, true)
        _Wait(50)
        _SetPedAmmo(playerPed, weaponHash, ammo)
        ForceReloadWeapon(weaponHash, ammo)
        
        DebugSuccess('Arme donnée via QS-Inventory')
        
    elseif detectedInventory == "ox_inventory" then
        -- 🔴 MÉTHODE OX-INVENTORY
        DebugClient('Utilisation OX-Inventory')
        
        TriggerServerEvent('pvp:giveWeaponInventory', weaponName, ammo)
        _Wait(200)
        
        if not _HasPedGotWeapon(playerPed, weaponHash, false) then
            _GiveWeaponToPed(playerPed, weaponHash, ammo, false, true)
        end
        
        _SetCurrentPedWeapon(playerPed, weaponHash, true)
        _Wait(50)
        _SetPedAmmo(playerPed, weaponHash, ammo)
        ForceReloadWeapon(weaponHash, ammo)
        
        DebugSuccess('Arme donnée via OX-Inventory')
        
    elseif detectedInventory == "qb-inventory" then
        -- 🔴 MÉTHODE QB-INVENTORY
        DebugClient('Utilisation QB-Inventory')
        
        TriggerServerEvent('pvp:giveWeaponInventory', weaponName, ammo)
        _Wait(200)
        
        if not _HasPedGotWeapon(playerPed, weaponHash, false) then
            _GiveWeaponToPed(playerPed, weaponHash, ammo, false, true)
        end
        
        _SetCurrentPedWeapon(playerPed, weaponHash, true)
        _Wait(50)
        _SetPedAmmo(playerPed, weaponHash, ammo)
        ForceReloadWeapon(weaponHash, ammo)
        
        DebugSuccess('Arme donnée via QB-Inventory')
        
    else
        -- 🔴 MÉTHODE VANILLA
        DebugClient('Utilisation Vanilla (Natives)')
        
        _GiveWeaponToPed(playerPed, weaponHash, ammo, false, true)
        _SetCurrentPedWeapon(playerPed, weaponHash, true)
        _Wait(50)
        _SetPedAmmo(playerPed, weaponHash, ammo)
        ForceReloadWeapon(weaponHash, ammo)
        
        DebugSuccess('Arme donnée via Vanilla')
    end
    
    return true
end

-- ========================================
-- FONCTION: RETIRER ARME (VIA INVENTAIRE)
-- ========================================
function InventoryBridge.RemoveWeapon(weaponName)
    local playerPed = _PlayerPedId()
    local weaponHash = _GetHashKey(weaponName)
    
    DebugClient('Retrait arme: %s', weaponName)
    
    -- Retirer l'arme équipée
    _RemoveWeaponFromPed(playerPed, weaponHash)
    
    -- Demander au serveur de retirer de l'inventaire
    if detectedInventory ~= "vanilla" then
        TriggerServerEvent('pvp:removeWeaponInventory', weaponName)
    end
    
    DebugSuccess('Arme retirée')
end

-- ========================================
-- FONCTION: RETIRER TOUTES LES ARMES
-- ========================================
function InventoryBridge.RemoveAllWeapons()
    local playerPed = _PlayerPedId()
    
    DebugClient('Retrait de toutes les armes')
    
    -- Retirer physiquement
    _RemoveAllPedWeapons(playerPed, true)
    
    -- Demander au serveur de nettoyer l'inventaire
    if detectedInventory ~= "vanilla" then
        TriggerServerEvent('pvp:removeAllWeaponsInventory')
    end
    
    DebugSuccess('Toutes les armes retirées')
end

-- ========================================
-- FONCTION: VÉRIFIER POSSESSION ARME
-- ========================================
function InventoryBridge.HasWeapon(weaponName)
    local playerPed = _PlayerPedId()
    local weaponHash = _GetHashKey(weaponName)
    
    if detectedInventory == "qs-inventory" then
        local hasInInventory = exports['qs-inventory']:GetItemTotalAmount(weaponName) > 0
        local hasEquipped = _HasPedGotWeapon(playerPed, weaponHash, false)
        return hasInInventory or hasEquipped
        
    elseif detectedInventory == "ox_inventory" then
        local hasInInventory = exports.ox_inventory:Search('count', weaponName) > 0
        local hasEquipped = _HasPedGotWeapon(playerPed, weaponHash, false)
        return hasInInventory or hasEquipped
        
    else
        return _HasPedGotWeapon(playerPed, weaponHash, false)
    end
end

-- ========================================
-- EXPORTS
-- ========================================
exports('GiveWeapon', InventoryBridge.GiveWeapon)
exports('RemoveWeapon', InventoryBridge.RemoveWeapon)
exports('RemoveAllWeapons', InventoryBridge.RemoveAllWeapons)
exports('HasWeapon', InventoryBridge.HasWeapon)
exports('GetInventoryType', function() return detectedInventory end)

-- Rendre accessible globalement
_G.InventoryBridge = InventoryBridge

-- ========================================
-- INITIALISATION
-- ========================================
CreateThread(function()
    Wait(1000)
    
    local inventory = DetectInventory()
    
    DebugSuccess('========================================')
    DebugSuccess('INVENTORY BRIDGE CHARGÉ (VERSION 4.1.0)')
    DebugSuccess('Type détecté: %s', inventory)
    DebugSuccess('Méthode: Attribution via inventaire')
    DebugSuccess('========================================')
end)
