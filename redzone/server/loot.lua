--[[
    =====================================================
    REDZONE LEAGUE - Systeme de Loot (Serveur)
    =====================================================
    Ce fichier gere la validation et la synchronisation
    du systeme de loot, ainsi que l'ouverture de l'inventaire.

    Logs Discord en temps reel pour chaque item vole.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Framework ESX
local ESX = nil

-- Tracking: Qui loote qui (eviter double loot)
-- {[victimServerId] = looterServerId}
local beingLooted = {}

-- Sessions de loot actives (pour tracker les transferts)
-- {[victimServerId] = {looter = serverId, looterInfo = {}, victimInfo = {}, lastInventory = {}}}
local activeLootSessions = {}

-- Webhook URL (defini dans server.cfg)
-- set redzone_loot_webhook "https://discord.com/api/webhooks/..."
local webhookUrl = nil

-- =====================================================
-- INITIALISATION
-- =====================================================

local function InitLootESX()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX == nil do
        Wait(100)
    end

    -- Recuperer le webhook depuis server.cfg
    webhookUrl = GetConvar('redzone_loot_webhook', '')
    if webhookUrl == '' then
        webhookUrl = nil
        print('[REDZONE/LOOT] ^1Webhook Discord non configure!^0 Ajoutez dans server.cfg:')
        print('[REDZONE/LOOT] set redzone_loot_webhook "VOTRE_WEBHOOK_URL"')
    else
        print('[REDZONE/LOOT] ^2Webhook Discord configure avec succes^0')
    end
end

-- =====================================================
-- FONCTIONS UTILITAIRES - IDENTIFIANTS JOUEUR
-- =====================================================

---Obtient les identifiants d'un joueur
---@param playerId number ID serveur du joueur
---@return table identifiers {license, discord, fivem, steam}
local function GetPlayerIdentifiers(playerId)
    local identifiers = {
        license = nil,
        discord = nil,
        fivem = nil,
        steam = nil,
    }

    for i = 0, GetNumPlayerIdentifiers(playerId) - 1 do
        local identifier = GetPlayerIdentifier(playerId, i)
        if identifier then
            if string.find(identifier, 'license:') then
                identifiers.license = identifier
            elseif string.find(identifier, 'discord:') then
                identifiers.discord = string.gsub(identifier, 'discord:', '')
            elseif string.find(identifier, 'fivem:') then
                identifiers.fivem = identifier
            elseif string.find(identifier, 'steam:') then
                identifiers.steam = identifier
            end
        end
    end

    return identifiers
end

---Obtient les informations completes d'un joueur
---@param playerId number ID serveur du joueur
---@return table playerInfo
local function GetPlayerInfo(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    local playerName = GetPlayerName(playerId) or 'Inconnu'

    return {
        serverId = playerId,
        name = playerName,
        license = identifiers.license or 'N/A',
        discord = identifiers.discord,
        discordMention = identifiers.discord and ('<@' .. identifiers.discord .. '>') or 'N/A',
        fivem = identifiers.fivem or 'N/A',
        steam = identifiers.steam or 'N/A',
    }
end

-- =====================================================
-- FONCTIONS UTILITAIRES - INVENTAIRE
-- =====================================================

---Obtient l'inventaire d'un joueur via qs-inventory (format simplifie)
---@param playerId number ID serveur du joueur
---@return table inventory {[itemName] = count}
local function GetPlayerInventorySnapshot(playerId)
    local inventory = {}

    local success, result = pcall(function()
        return exports['qs-inventory']:GetInventory(playerId)
    end)

    if success and result then
        for _, item in pairs(result) do
            if item and item.name then
                local itemName = item.name
                local count = item.count or item.amount or 1

                if inventory[itemName] then
                    inventory[itemName].count = inventory[itemName].count + count
                else
                    inventory[itemName] = {
                        name = itemName,
                        label = item.label or itemName,
                        count = count,
                    }
                end
            end
        end
    end

    return inventory
end

-- =====================================================
-- FONCTIONS UTILITAIRES - SESSIONS DE LOOT
-- =====================================================

---Trouve une session de loot active pour un looter
---@param looterId number ID serveur du looter
---@return number|nil victimId
local function FindLootSessionByLooter(looterId)
    for victimId, session in pairs(activeLootSessions) do
        if session.looter == looterId then
            return victimId
        end
    end
    return nil
end

-- =====================================================
-- DISCORD WEBHOOK
-- =====================================================

---Envoie un log Discord pour un item vole
---@param looterInfo table Informations du looter
---@param victimInfo table Informations de la victime
---@param itemName string Nom de l'item
---@param itemLabel string Label de l'item
---@param itemCount number Quantite volee
local function SendDiscordItemStolenLog(looterInfo, victimInfo, itemName, itemLabel, itemCount)
    if not webhookUrl then return end

    local timestamp = os.date('%Y-%m-%d %H:%M:%S')

    -- Determiner si c'est une arme
    local isWeapon = string.find(string.upper(itemName or ''), 'WEAPON_')
    local itemIcon = isWeapon and '🔫' or '📦'
    local itemType = isWeapon and 'Arme' or 'Item'

    -- Quantite
    local countStr = itemCount > 1 and (' x' .. itemCount) or ''

    -- Construire l'embed Discord
    local embed = {
        {
            title = itemIcon .. ' ' .. itemType .. ' Volé - Redzone',
            color = isWeapon and 16711680 or 16744448, -- Rouge pour armes, Orange pour items
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            footer = {
                text = 'Redzone League - Loot System',
            },
            fields = {
                {
                    name = '📥 Item Volé',
                    value = '**' .. (itemLabel or itemName) .. '**' .. countStr,
                    inline = false,
                },
                {
                    name = '👤 Voleur',
                    value = string.format(
                        '**Nom:** %s\n**ID:** %d\n**License:** `%s`\n**Discord:** %s',
                        looterInfo.name,
                        looterInfo.serverId,
                        looterInfo.license,
                        looterInfo.discordMention
                    ),
                    inline = true,
                },
                {
                    name = '💀 Victime',
                    value = string.format(
                        '**Nom:** %s\n**ID:** %d\n**License:** `%s`\n**Discord:** %s',
                        victimInfo.name,
                        victimInfo.serverId,
                        victimInfo.license,
                        victimInfo.discordMention
                    ),
                    inline = true,
                },
                {
                    name = '⏰ Heure',
                    value = timestamp,
                    inline = false,
                },
            },
        },
    }

    -- Envoyer le webhook
    PerformHttpRequest(webhookUrl, function(statusCode, response, headers)
        if statusCode == 200 or statusCode == 204 then
            print('[REDZONE/LOOT] ^2Log Discord envoye:^0 ' .. (itemLabel or itemName) .. countStr)
        else
            print('[REDZONE/LOOT] ^1Erreur webhook Discord:^0 ' .. tostring(statusCode))
        end
    end, 'POST', json.encode({
        username = 'Redzone Loot',
        avatar_url = 'https://i.imgur.com/oBQXsRl.png',
        embeds = embed,
    }), {
        ['Content-Type'] = 'application/json',
    })
end

-- =====================================================
-- DETECTION DES TRANSFERTS EN TEMPS REEL
-- =====================================================

---Verifie les changements d'inventaire et log les items voles
---@param victimId number ID de la victime
local function CheckInventoryChanges(victimId)
    local session = activeLootSessions[victimId]
    if not session then return end

    -- Obtenir l'inventaire actuel
    local currentInventory = GetPlayerInventorySnapshot(victimId)
    local lastInventory = session.lastInventory

    -- Comparer avec le dernier inventaire connu
    for itemName, lastData in pairs(lastInventory) do
        local currentData = currentInventory[itemName]
        local lastCount = lastData.count or 0
        local currentCount = currentData and currentData.count or 0

        -- Si la quantite a diminue, l'item a ete vole
        if currentCount < lastCount then
            local stolenCount = lastCount - currentCount
            print('[REDZONE/LOOT] ^3Item vole detecte:^0 ' .. itemName .. ' x' .. stolenCount)

            -- Envoyer le log Discord
            SendDiscordItemStolenLog(
                session.looterInfo,
                session.victimInfo,
                itemName,
                lastData.label,
                stolenCount
            )
        end
    end

    -- Mettre a jour le dernier inventaire connu
    session.lastInventory = currentInventory
end

---Demarre le monitoring d'inventaire pour une session de loot
---@param victimId number ID de la victime
local function StartInventoryMonitoring(victimId)
    CreateThread(function()
        while activeLootSessions[victimId] do
            Wait(500) -- Verifier toutes les 500ms
            CheckInventoryChanges(victimId)
        end
        print('[REDZONE/LOOT] Monitoring termine pour victime: ' .. victimId)
    end)
end

-- =====================================================
-- EVENEMENTS
-- =====================================================

---Evenement: Demande de loot
RegisterNetEvent('redzone:loot:requestStart')
AddEventHandler('redzone:loot:requestStart', function(targetServerId)
    local source = source

    -- Verifier si la cible existe
    local targetPlayer = GetPlayerPed(targetServerId)
    if not targetPlayer or targetPlayer == 0 then
        TriggerClientEvent('redzone:loot:startDenied', source, 'target_invalid')
        return
    end

    -- Verifier si la cible est deja en train d'etre lootee
    if beingLooted[targetServerId] or activeLootSessions[targetServerId] then
        TriggerClientEvent('redzone:loot:startDenied', source, 'already_looted')
        return
    end

    -- Verifier si le joueur n'est pas en train de looter quelqu'un d'autre
    for victim, looter in pairs(beingLooted) do
        if looter == source then
            TriggerClientEvent('redzone:loot:startDenied', source, 'already_looting')
            return
        end
    end

    -- Reserver la victime
    beingLooted[targetServerId] = source

    -- Confirmer au client que le loot peut commencer
    TriggerClientEvent('redzone:loot:startConfirmed', source, targetServerId)

    print('[REDZONE/LOOT] Loot autorise: ' .. source .. ' -> ' .. targetServerId)
end)

---Evenement: Annulation du loot
RegisterNetEvent('redzone:loot:cancel')
AddEventHandler('redzone:loot:cancel', function(targetServerId)
    local source = source

    if beingLooted[targetServerId] == source then
        beingLooted[targetServerId] = nil
        print('[REDZONE/LOOT] Loot annule: ' .. source .. ' -> ' .. targetServerId)
    end
end)

---Evenement: Fin du loot (succes) - Ouvre l'inventaire
RegisterNetEvent('redzone:loot:finish')
AddEventHandler('redzone:loot:finish', function(targetServerId)
    local source = source

    -- Verifier que c'est bien le bon looter qui termine
    if beingLooted[targetServerId] ~= source then
        return
    end

    -- Recuperer les infos des joueurs pour le log
    local looterInfo = GetPlayerInfo(source)
    local victimInfo = GetPlayerInfo(targetServerId)

    -- Prendre un snapshot de l'inventaire AVANT le loot
    local inventoryBefore = GetPlayerInventorySnapshot(targetServerId)

    -- Liberer le lock de base
    beingLooted[targetServerId] = nil

    -- Creer une session de loot active
    activeLootSessions[targetServerId] = {
        looter = source,
        looterInfo = looterInfo,
        victimInfo = victimInfo,
        lastInventory = inventoryBefore,
        startTime = os.time(),
    }

    -- Ouvrir l'inventaire du joueur mort via qs-inventory
    local success, err = pcall(function()
        exports['qs-inventory']:OpenInventory('otherplayer', targetServerId, nil, source)
    end)

    if success then
        print('[REDZONE/LOOT] ^2Inventaire ouvert:^0 ' .. source .. ' -> ' .. targetServerId)
        TriggerClientEvent('redzone:loot:openInventory', source, targetServerId)

        -- Demarrer le monitoring en temps reel
        StartInventoryMonitoring(targetServerId)

        if Redzone.Server.Utils then
            Redzone.Server.Utils.Log('PLAYER_LOOTED', source, 'Looted player: ' .. targetServerId)
        end
    else
        print('[REDZONE/LOOT] ^1Erreur ouverture inventaire:^0 ' .. tostring(err))
        if Redzone.Server.Utils then
            Redzone.Server.Utils.NotifyError(source, 'Erreur lors de l\'ouverture de l\'inventaire')
        end
        activeLootSessions[targetServerId] = nil
    end

    -- Timeout de securite (5 minutes max)
    SetTimeout(300000, function()
        if activeLootSessions[targetServerId] then
            print('[REDZONE/LOOT] Session expiree: ' .. targetServerId)
            activeLootSessions[targetServerId] = nil
        end
    end)
end)

-- =====================================================
-- DETECTION FERMETURE INVENTAIRE
-- =====================================================

-- Quand le joueur ferme l'inventaire (event qs-inventory)
RegisterNetEvent('qs-inventory:server:closeInventory')
AddEventHandler('qs-inventory:server:closeInventory', function()
    local source = source
    local victimId = FindLootSessionByLooter(source)
    if victimId then
        -- Derniere verification avant de fermer
        SetTimeout(500, function()
            CheckInventoryChanges(victimId)
            activeLootSessions[victimId] = nil
            print('[REDZONE/LOOT] Session terminee: ' .. victimId)
        end)
    end
end)

-- Event alternatif depuis le client
RegisterNetEvent('redzone:loot:inventoryClosed')
AddEventHandler('redzone:loot:inventoryClosed', function()
    local source = source
    local victimId = FindLootSessionByLooter(source)
    if victimId then
        SetTimeout(500, function()
            CheckInventoryChanges(victimId)
            activeLootSessions[victimId] = nil
        end)
    end
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Nettoyer si ce joueur etait en train de looter
    for victim, looter in pairs(beingLooted) do
        if looter == source then
            beingLooted[victim] = nil
        end
    end

    -- Nettoyer les sessions actives
    for victimId, session in pairs(activeLootSessions) do
        if session.looter == source then
            -- Derniere verification
            CheckInventoryChanges(victimId)
            activeLootSessions[victimId] = nil
        end
    end

    -- Nettoyer si ce joueur etait victime
    if beingLooted[source] then
        beingLooted[source] = nil
    end
    if activeLootSessions[source] then
        activeLootSessions[source] = nil
    end
end)

-- =====================================================
-- FERMETURE FORCEE (QUAND LA VICTIME RESPAWN)
-- =====================================================

---Ferme la session de loot quand la victime respawn/revive
---@param victimId number ID de la victime
local function ForceCloseLootSession(victimId)
    local session = activeLootSessions[victimId]
    if not session then return end

    local looterId = session.looter

    print('[REDZONE/LOOT] ^3Fermeture forcee du loot:^0 victime ' .. victimId .. ' a respawn')

    -- Derniere verification des items
    CheckInventoryChanges(victimId)

    -- Fermer l'inventaire du looter
    if looterId then
        -- Fermer l'inventaire qs-inventory directement (le prefix est 'inventory' pas 'qs-inventory')
        TriggerClientEvent('inventory:client:forceCloseInventory', looterId)
        TriggerClientEvent('inventory:client:closeinv', looterId)
        -- Aussi notifier notre script
        TriggerClientEvent('redzone:loot:forceClose', looterId)
    end

    -- Nettoyer la session
    activeLootSessions[victimId] = nil
end

-- Evenement: La victime a respawn/revive
RegisterNetEvent('redzone:loot:victimRespawned')
AddEventHandler('redzone:loot:victimRespawned', function()
    local source = source

    -- Verifier si ce joueur etait en train d'etre loote
    if activeLootSessions[source] then
        ForceCloseLootSession(source)
    end

    -- Aussi nettoyer beingLooted
    if beingLooted[source] then
        beingLooted[source] = nil
    end
end)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('IsPlayerBeingLooted', function(playerId)
    return beingLooted[playerId] ~= nil or activeLootSessions[playerId] ~= nil
end)

exports('GetPlayerLooter', function(playerId)
    if beingLooted[playerId] then
        return beingLooted[playerId]
    end
    if activeLootSessions[playerId] then
        return activeLootSessions[playerId].looter
    end
    return nil
end)

-- Fermer le loot si la victime respawn (appele depuis death.lua)
exports('CloseVictimLootSession', function(victimId)
    ForceCloseLootSession(victimId)
end)

-- =====================================================
-- DEMARRAGE
-- =====================================================

CreateThread(function()
    InitLootESX()
    print('[REDZONE/LOOT] ^2Module Loot serveur charge^0')
end)
