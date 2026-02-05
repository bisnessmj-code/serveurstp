--[[
    =====================================================
    REDZONE LEAGUE - Système de Coffre (Stash) - Serveur
    =====================================================
    Ce fichier gère la logique serveur du coffre personnel.

    La persistance est gérée par qs-inventory via:
    - GetOtherInventoryItems() pour le chargement
    - SaveStashItems() pour la sauvegarde (via handleInventoryClosed)

    Chaque joueur a son propre stash identifié par: rzstash_<identifier>
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}
Redzone.Server.Stash = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

local ESX = nil
local openStashes = {} -- Track des stash ouverts: {[source] = stashName}

-- =====================================================
-- INITIALISATION ESX
-- =====================================================

local function InitializeESX()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX == nil do
        Wait(100)
    end
end

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Obtient l'identifier d'un joueur via ESX
---@param source number L'ID du joueur
---@return string|nil identifier L'identifier du joueur
local function GetPlayerIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        return xPlayer.identifier
    end
    return nil
end

---Génère le nom unique du stash pour un joueur
---@param identifier string L'identifier du joueur
---@return string stashName Le nom du stash (format: coffre_xxx)
local function GetStashName(identifier)
    -- Nettoyer l'identifier (garder uniquement alphanumériques)
    local cleanId = identifier:gsub('[^%w]', '')

    -- Limiter la longueur pour éviter les problèmes de BDD
    if #cleanId > 40 then
        cleanId = string.sub(cleanId, 1, 40)
    end

    return 'coffre_' .. cleanId
end

-- =====================================================
-- ÉVÉNEMENT: OUVERTURE DU COFFRE
-- =====================================================

RegisterNetEvent('redzone:stash:open')
AddEventHandler('redzone:stash:open', function()
    local source = source
    local identifier = GetPlayerIdentifier(source)

    if not identifier then
        if Redzone.Server.Utils and Redzone.Server.Utils.NotifyError then
            Redzone.Server.Utils.NotifyError(source, 'Erreur: Impossible d\'identifier le joueur.')
        end
        return
    end

    local stashName = GetStashName(identifier)

    Redzone.Shared.Debug('[STASH] Ouverture coffre - Joueur: ' .. source .. ' | Stash: ' .. stashName)

    -- Tracker le stash ouvert
    openStashes[source] = stashName

    -- Ouvrir l'inventaire via qs-inventory
    -- qs-inventory va automatiquement:
    -- 1. Appeler GetOtherInventoryItems('stash', stashName) pour charger
    -- 2. Appeler SaveStashItems() à la fermeture via handleInventoryClosed
    local stashLabel = Config.StashPeds.Settings.Label or 'Coffre'
    local success, err = pcall(function()
        exports['qs-inventory']:OpenInventory('stash', stashName, {
            maxweight = Config.StashPeds.Settings.MaxWeight or 100000000,
            slots = Config.StashPeds.Settings.MaxSlots or 500,
            label = stashLabel,
        }, source)
    end)

    if not success then
        Redzone.Shared.Debug('[STASH/ERROR] Erreur ouverture: ' .. tostring(err))
        if Redzone.Server.Utils and Redzone.Server.Utils.NotifyError then
            Redzone.Server.Utils.NotifyError(source, 'Erreur lors de l\'ouverture du coffre.')
        end
    else
        Redzone.Shared.Debug('[STASH] Coffre ouvert avec succès: ' .. stashName)
        if Redzone.Server.Utils and Redzone.Server.Utils.Log then
            Redzone.Server.Utils.Log('STASH_OPEN', source, 'Stash: ' .. stashName)
        end
    end
end)

-- =====================================================
-- NETTOYAGE À LA DÉCONNEXION
-- =====================================================

AddEventHandler('playerDropped', function(reason)
    local source = source
    if openStashes[source] then
        Redzone.Shared.Debug('[STASH] Joueur déconnecté, nettoyage: ' .. openStashes[source])
        openStashes[source] = nil
    end
end)

-- =====================================================
-- COMMANDES ADMIN (DEBUG)
-- =====================================================

---Commande: Debug - Affiche les informations du stash d'un joueur
RegisterCommand('redzone_debugstash', function(source, args, rawCommand)
    -- Console ou admin seulement
    if source ~= 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer or (xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'superadmin') then
            return
        end
    end

    local targetId = tonumber(args[1])
    if not targetId then
        print('[REDZONE DEBUG] Usage: redzone_debugstash [player_id]')
        return
    end

    local identifier = GetPlayerIdentifier(targetId)
    if not identifier then
        print('[REDZONE DEBUG] Joueur non trouvé: ' .. targetId)
        return
    end

    local stashName = GetStashName(identifier)

    print('[REDZONE DEBUG] ================================')
    print('[REDZONE DEBUG] Joueur ID: ' .. targetId)
    print('[REDZONE DEBUG] Identifier: ' .. identifier)
    print('[REDZONE DEBUG] Stash Name: ' .. stashName)
    print('[REDZONE DEBUG] ================================')

    -- Vérifier dans la table stash_items
    MySQL.query('SELECT items FROM stash_items WHERE stash = ?', {stashName}, function(result)
        if result and result[1] then
            print('[REDZONE DEBUG] Trouvé dans stash_items!')
            local items = json.decode(result[1].items) or {}

            local count = 0
            for _ in pairs(items) do
                count = count + 1
            end

            print('[REDZONE DEBUG] Nombre d\'items: ' .. count)

            for slot, item in pairs(items) do
                if type(item) == 'table' and item.name then
                    print(string.format('[REDZONE DEBUG]   Slot %s: %s x%d', tostring(slot), item.name or 'unknown', item.count or item.amount or 1))
                end
            end
        else
            print('[REDZONE DEBUG] PAS trouvé dans stash_items')
        end
    end)
end, true)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetPlayerStashName', function(playerId)
    local identifier = GetPlayerIdentifier(playerId)
    if not identifier then return nil end
    return GetStashName(identifier)
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

CreateThread(function()
    InitializeESX()
    Redzone.Shared.Debug('[SERVER/STASH] Module Stash serveur initialisé')
end)
