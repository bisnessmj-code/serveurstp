-- ========================================
-- PVP GUNFIGHT - SYSTÈME DE PERMISSIONS
-- Version 1.0.0 - Gestion ACE + ESX
-- ========================================

DebugServer('Chargement système de permissions...')

-- ========================================
-- CONFIGURATION PERMISSIONS
-- ========================================
local PermissionConfig = {
    -- Groupes ESX autorisés (admin, superadmin, etc.)
    allowedGroups = {
        'admin',
        'staff',
        'superadmin',
        'owner'
    },
    
    -- ACE permissions (pour ceux qui utilisent ACE au lieu d'ESX)
    acePermission = 'pvp.admin',
    
    -- Cache des permissions (optimisation)
    cache = {},
    cacheDuration = 300000 -- 5 minutes
}

-- ========================================
-- FONCTION: VÉRIFIER SI JOUEUR EST ADMIN
-- ========================================
function IsPlayerAdmin(source)
    -- Console serveur = toujours admin
    if source == 0 then
        return true
    end
    
    -- Vérifier le cache
    local now = GetGameTimer()
    local cached = PermissionConfig.cache[source]
    
    if cached and (now - cached.time) < PermissionConfig.cacheDuration then
        return cached.isAdmin
    end
    
    local isAdmin = false
    
    -- 1. Vérifier ACE permission (pour ceux qui utilisent ACE)
    if IsPlayerAceAllowed(source, PermissionConfig.acePermission) then
        isAdmin = true
        DebugServer('✅ Joueur %d autorisé (ACE)', source)
    else
        -- 2. Vérifier groupe ESX (pour ceux qui utilisent ESX)
        local xPlayer = ESX.GetPlayerFromId(source)
        
        if xPlayer then
            local playerGroup = xPlayer.getGroup()
            
            -- Vérifier si le groupe est dans la liste autorisée
            for i = 1, #PermissionConfig.allowedGroups do
                if playerGroup == PermissionConfig.allowedGroups[i] then
                    isAdmin = true
                    DebugServer('✅ Joueur %d autorisé (Groupe ESX: %s)', source, playerGroup)
                    break
                end
            end
            
            if not isAdmin then
                DebugWarn('❌ Joueur %d refusé (Groupe ESX: %s)', source, playerGroup)
            end
        else
            DebugWarn('⚠️ xPlayer introuvable pour joueur %d', source)
        end
    end
    
    -- Mettre en cache
    PermissionConfig.cache[source] = {
        isAdmin = isAdmin,
        time = now
    }
    
    return isAdmin
end

-- ========================================
-- FONCTION: NETTOYER LE CACHE
-- ========================================
function ClearPermissionCache(source)
    if source then
        PermissionConfig.cache[source] = nil
    else
        PermissionConfig.cache = {}
    end
end

-- ========================================
-- EVENT: NETTOYER CACHE À LA DÉCONNEXION
-- ========================================
AddEventHandler('playerDropped', function()
    local src = source
    ClearPermissionCache(src)
end)

-- ========================================
-- COMMANDE: AJOUTER/RETIRER GROUPE AUTORISÉ
-- ========================================
RegisterCommand('pvpaddgroup', function(source, args)
    if not IsPlayerAdmin(source) then
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        else
            print('[PVP] Cette commande nécessite les permissions admin')
        end
        return
    end
    
    local groupName = args[1]
    
    if not groupName then
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~r~Usage: /pvpaddgroup [nom_groupe]')
        else
            print('[PVP] Usage: pvpaddgroup [nom_groupe]')
        end
        return
    end
    
    -- Vérifier si déjà présent
    for i = 1, #PermissionConfig.allowedGroups do
        if PermissionConfig.allowedGroups[i] == groupName then
            if source > 0 then
                TriggerClientEvent('esx:showNotification', source, '~y~Groupe déjà autorisé: ' .. groupName)
            else
                print('[PVP] Groupe déjà autorisé: ' .. groupName)
            end
            return
        end
    end
    
    -- Ajouter le groupe
    PermissionConfig.allowedGroups[#PermissionConfig.allowedGroups + 1] = groupName
    
    if source > 0 then
        TriggerClientEvent('esx:showNotification', source, '~g~Groupe ajouté: ' .. groupName)
    else
        print('[PVP] ✅ Groupe ajouté: ' .. groupName)
    end
    
    -- Nettoyer le cache
    ClearPermissionCache()
end, false)

RegisterCommand('pvpremovegroup', function(source, args)
    if not IsPlayerAdmin(source) then
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        else
            print('[PVP] Cette commande nécessite les permissions admin')
        end
        return
    end
    
    local groupName = args[1]
    
    if not groupName then
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~r~Usage: /pvpremovegroup [nom_groupe]')
        else
            print('[PVP] Usage: pvpremovegroup [nom_groupe]')
        end
        return
    end
    
    -- Chercher et retirer
    local found = false
    for i = #PermissionConfig.allowedGroups, 1, -1 do
        if PermissionConfig.allowedGroups[i] == groupName then
            table.remove(PermissionConfig.allowedGroups, i)
            found = true
            break
        end
    end
    
    if found then
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~g~Groupe retiré: ' .. groupName)
        else
            print('[PVP] ✅ Groupe retiré: ' .. groupName)
        end
        
        -- Nettoyer le cache
        ClearPermissionCache()
    else
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~r~Groupe introuvable: ' .. groupName)
        else
            print('[PVP] ❌ Groupe introuvable: ' .. groupName)
        end
    end
end, false)

-- ========================================
-- COMMANDE: LISTER GROUPES AUTORISÉS
-- ========================================
RegisterCommand('pvplistgroups', function(source)
    if not IsPlayerAdmin(source) then
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        else
            print('[PVP] Cette commande nécessite les permissions admin')
        end
        return
    end
    
    if source > 0 then
        TriggerClientEvent('esx:showNotification', source, '~b~Groupes autorisés:')
        for i = 1, #PermissionConfig.allowedGroups do
            TriggerClientEvent('esx:showNotification', source, '~w~- ' .. PermissionConfig.allowedGroups[i])
        end
    else
        print('[PVP] ========== GROUPES AUTORISÉS ==========')
        for i = 1, #PermissionConfig.allowedGroups do
            print('[PVP] - ' .. PermissionConfig.allowedGroups[i])
        end
        print('[PVP] ========================================')
    end
end, false)

-- ========================================
-- COMMANDE: VÉRIFIER PERMISSIONS JOUEUR
-- ========================================
RegisterCommand('pvpcheckperm', function(source, args)
    if source == 0 then
        print('[PVP] Cette commande ne peut être utilisée que par un joueur')
        return
    end
    
    local targetId = tonumber(args[1]) or source
    
    if not IsPlayerAdmin(source) and targetId ~= source then
        TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(targetId)
    
    if not xPlayer then
        TriggerClientEvent('esx:showNotification', source, '~r~Joueur introuvable')
        return
    end
    
    local playerGroup = xPlayer.getGroup()
    local hasAce = IsPlayerAceAllowed(targetId, PermissionConfig.acePermission)
    local isAdmin = IsPlayerAdmin(targetId)
    
    TriggerClientEvent('esx:showNotification', source, '~b~=== PERMISSIONS JOUEUR ' .. targetId .. ' ===')
    TriggerClientEvent('esx:showNotification', source, '~w~Groupe ESX: ' .. playerGroup)
    TriggerClientEvent('esx:showNotification', source, '~w~ACE Permission: ' .. (hasAce and '~g~OUI' or '~r~NON'))
    TriggerClientEvent('esx:showNotification', source, '~w~Est Admin PVP: ' .. (isAdmin and '~g~OUI' or '~r~NON'))
end, false)

-- ========================================
-- EXPORTS
-- ========================================
exports('IsPlayerAdmin', IsPlayerAdmin)
exports('ClearPermissionCache', ClearPermissionCache)

DebugSuccess('✅ Système de permissions chargé (Groupes autorisés: %s)', 
    table.concat(PermissionConfig.allowedGroups, ', '))
