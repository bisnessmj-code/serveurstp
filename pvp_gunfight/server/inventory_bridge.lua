-- ========================================
-- PVP GUNFIGHT - INVENTORY BRIDGE SERVER
-- Version 4.1.0 - QS-Inventory Compatible
-- ========================================

DebugServer('Module Inventory Bridge Server chargé')

-- ========================================
-- CONFIGURATION
-- ========================================
local detectedInventory = "vanilla"

-- Liste des armes du PVP (à synchroniser avec config.lua)
local PVP_WEAPONS = {
    'WEAPON_PISTOL50',
    'WEAPON_COMBATPISTOL',
    'WEAPON_APPISTOL',
    'WEAPON_PISTOL',
    'WEAPON_HEAVYPISTOL'
}

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
-- EVENT: DONNER ARME VIA INVENTAIRE
-- ========================================
RegisterNetEvent('pvp:giveWeaponInventory', function(weaponName, ammo)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then
        DebugError('Joueur ESX introuvable: %d', src)
        return
    end
    
    DebugServer('Attribution arme inventaire: %s -> Joueur %d', weaponName, src)
    
    if detectedInventory == "qs-inventory" then
        -- 🔴 QS-INVENTORY
        DebugServer('Utilisation QS-Inventory (serveur)')
        
        local hasWeapon = exports['qs-inventory']:GetItemTotalAmount(src, weaponName)
        
        if not hasWeapon or hasWeapon == 0 then
            local success = exports['qs-inventory']:AddItem(src, weaponName, 1)
            
            if success then
                DebugSuccess('Arme ajoutée à l\'inventaire QS')
                
                -- Ajouter munitions si configuré
                -- Note: QS-Inventory gère automatiquement les munitions avec l'arme
            else
                DebugError('Échec ajout arme QS-Inventory')
            end
        else
            DebugServer('Arme déjà dans l\'inventaire')
        end
        
    elseif detectedInventory == "ox_inventory" then
        -- 🔴 OX-INVENTORY
        DebugServer('Utilisation OX-Inventory (serveur)')
        
        local success = exports.ox_inventory:AddItem(src, weaponName, 1)
        
        if success then
            DebugSuccess('Arme ajoutée à l\'inventaire OX')
        else
            DebugError('Échec ajout arme OX-Inventory')
        end
        
    elseif detectedInventory == "qb-inventory" then
        -- 🔴 QB-INVENTORY
        DebugServer('Utilisation QB-Inventory (serveur)')
        
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddItem(weaponName, 1)
            DebugSuccess('Arme ajoutée à l\'inventaire QB')
        end
        
    else
        -- 🔴 VANILLA (pas d'action serveur)
        DebugServer('Mode Vanilla - Pas d\'action serveur')
    end
end)

-- ========================================
-- EVENT: RETIRER ARME DE L'INVENTAIRE
-- ========================================
RegisterNetEvent('pvp:removeWeaponInventory', function(weaponName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then
        DebugError('Joueur ESX introuvable: %d', src)
        return
    end
    
    DebugServer('Retrait arme inventaire: %s <- Joueur %d', weaponName, src)
    
    if detectedInventory == "qs-inventory" then
        -- 🔴 QS-INVENTORY
        DebugServer('Utilisation QS-Inventory pour retrait (serveur)')
        
        local hasWeapon = exports['qs-inventory']:GetItemTotalAmount(src, weaponName)
        
        if hasWeapon and hasWeapon > 0 then
            local success = exports['qs-inventory']:RemoveItem(src, weaponName, hasWeapon)
            
            if success then
                DebugSuccess('Arme retirée de l\'inventaire QS')
            else
                DebugError('Échec retrait arme QS-Inventory')
            end
        else
            DebugServer('Arme non trouvée dans l\'inventaire')
        end
        
    elseif detectedInventory == "ox_inventory" then
        -- 🔴 OX-INVENTORY
        DebugServer('Utilisation OX-Inventory pour retrait (serveur)')
        
        local count = exports.ox_inventory:Search(src, 'count', weaponName)
        
        if count > 0 then
            local success = exports.ox_inventory:RemoveItem(src, weaponName, count)
            
            if success then
                DebugSuccess('Arme retirée de l\'inventaire OX')
            else
                DebugError('Échec retrait arme OX-Inventory')
            end
        end
        
    elseif detectedInventory == "qb-inventory" then
        -- 🔴 QB-INVENTORY
        DebugServer('Utilisation QB-Inventory pour retrait (serveur)')
        
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local item = Player.Functions.GetItemByName(weaponName)
            
            if item then
                Player.Functions.RemoveItem(weaponName, item.amount)
                DebugSuccess('Arme retirée de l\'inventaire QB')
            end
        end
        
    else
        -- 🔴 VANILLA
        DebugServer('Mode Vanilla - Pas d\'action serveur')
    end
end)

-- ========================================
-- EVENT: RETIRER TOUTES LES ARMES PVP
-- ========================================
RegisterNetEvent('pvp:removeAllWeaponsInventory', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    DebugServer('Retrait de toutes les armes PVP - Joueur %d', src)
    
    for i = 1, #PVP_WEAPONS do
        local weaponName = PVP_WEAPONS[i]
        
        if detectedInventory == "qs-inventory" then
            local hasWeapon = exports['qs-inventory']:GetItemTotalAmount(src, weaponName)
            if hasWeapon and hasWeapon > 0 then
                exports['qs-inventory']:RemoveItem(src, weaponName, hasWeapon)
            end
            
        elseif detectedInventory == "ox_inventory" then
            local count = exports.ox_inventory:Search(src, 'count', weaponName)
            if count > 0 then
                exports.ox_inventory:RemoveItem(src, weaponName, count)
            end
            
        elseif detectedInventory == "qb-inventory" then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                local item = Player.Functions.GetItemByName(weaponName)
                if item then
                    Player.Functions.RemoveItem(weaponName, item.amount)
                end
            end
        end
    end
    
    DebugSuccess('Toutes les armes PVP retirées')
end)

-- ========================================
-- INITIALISATION
-- ========================================
CreateThread(function()
    Wait(1000)
    
    local inventory = DetectInventory()
    
    DebugSuccess('========================================')
    DebugSuccess('INVENTORY BRIDGE SERVER CHARGÉ (v4.1.0)')
    DebugSuccess('Type détecté: %s', inventory)
    DebugSuccess('Méthode: Attribution via inventaire serveur')
    DebugSuccess('========================================')
end)
