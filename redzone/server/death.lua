--[[
    =====================================================
    REDZONE LEAGUE - Système de Mort/Réanimation (Serveur)
    =====================================================
    Ce fichier gère la synchronisation des états de mort
    et les vérifications côté serveur pour la réanimation.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Framework ESX
local ESX = nil

-- Joueurs morts
local deadPlayers = {}

-- Joueurs en cours de réanimation
local revivingPlayers = {}

-- =====================================================
-- INITIALISATION
-- =====================================================

local function InitDeathESX()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX == nil do
        Wait(100)
    end
end

-- =====================================================
-- SYSTÈME DE RÉCOMPENSE KILL
-- =====================================================

---Donne la récompense au tueur
---@param killerServerId number ID serveur du tueur
---@param victimServerId number ID serveur de la victime
local function GiveKillReward(killerServerId, victimServerId)
    if not Config.KillReward or not Config.KillReward.Enabled then return end

    local amount = Config.KillReward.Amount or 2000
    local moneyType = Config.KillReward.MoneyType or 'black_money'

    -- Donner l'argent via qs-inventory (black_money est un item)
    local success, err = pcall(function()
        exports['qs-inventory']:AddItem(killerServerId, moneyType, amount)
    end)

    if success then
        -- Notification au tueur (désactivée)
        -- local message = string.format(Config.KillReward.Message or '+$%s argent sale!', amount)
        -- Redzone.Server.Utils.NotifySuccess(killerServerId, message)

        Redzone.Shared.Debug('[DEATH/SERVER] Récompense kill: ', killerServerId, ' a reçu ', amount, ' ', moneyType)
        Redzone.Server.Utils.Log('KILL_REWARD', killerServerId, 'Killed player ' .. victimServerId .. ' - Reward: ' .. amount .. ' ' .. moneyType)
    else
        Redzone.Shared.Debug('[DEATH/SERVER] Erreur récompense kill: ', err)
    end
end

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

---Événement: Joueur mort
RegisterNetEvent('redzone:death:playerDied')
AddEventHandler('redzone:death:playerDied', function(killerServerId)
    local source = source
    deadPlayers[source] = {
        time = os.time(),
        beingRevived = false,
        reviver = nil,
    }
    Redzone.Shared.Debug('[DEATH/SERVER] Joueur mort: ', source, ' | Tueur: ', killerServerId or 'N/A')

    -- Système de récompense pour le kill
    if killerServerId and Config.KillReward and Config.KillReward.Enabled then
        -- Vérifier que le tueur existe et n'est pas la victime elle-même
        if killerServerId ~= source and GetPlayerPed(killerServerId) ~= 0 then
            GiveKillReward(killerServerId, source)
        end
    end

    -- Système de leaderboard: enregistrer le kill dans la BDD
    if killerServerId and killerServerId ~= source and GetPlayerPed(killerServerId) ~= 0 then
        if Redzone.Server.Leaderboard and Redzone.Server.Leaderboard.RegisterKill then
            Redzone.Server.Leaderboard.RegisterKill(killerServerId, source)
        end
    end

    -- Diffuser le kill feed à tous les joueurs
    if killerServerId and killerServerId ~= source and GetPlayerPed(killerServerId) ~= 0 then
        local killerName = GetPlayerName(killerServerId) or 'Inconnu'
        local victimName = GetPlayerName(source) or 'Inconnu'

        -- Envoyer à tous les clients
        TriggerClientEvent('redzone:killfeed:add', -1, {
            killerName = killerName,
            killerId = killerServerId,
            victimName = victimName,
            victimId = source,
        })

        Redzone.Shared.Debug('[KILLFEED] ', killerName, ' (', killerServerId, ') a tué ', victimName, ' (', source, ')')
    end
end)

---Événement: Joueur réanimé
RegisterNetEvent('redzone:death:playerRevived')
AddEventHandler('redzone:death:playerRevived', function()
    local source = source
    deadPlayers[source] = nil
    revivingPlayers[source] = nil
    Redzone.Shared.Debug('[DEATH/SERVER] Joueur réanimé: ', source)
end)

---Événement: Début de réanimation
RegisterNetEvent('redzone:death:startRevive')
AddEventHandler('redzone:death:startRevive', function(targetId)
    local source = source

    -- Vérifications
    if not deadPlayers[targetId] then
        Redzone.Server.Utils.NotifyError(source, 'Ce joueur n\'est pas à terre.')
        return
    end

    if deadPlayers[targetId].beingRevived then
        Redzone.Server.Utils.NotifyError(source, 'Ce joueur est déjà en cours de réanimation.')
        return
    end

    -- Marquer comme en cours de réanimation
    deadPlayers[targetId].beingRevived = true
    deadPlayers[targetId].reviver = source
    revivingPlayers[source] = targetId

    -- Notifier le joueur à terre
    TriggerClientEvent('redzone:death:beingRevived', targetId, source)

    Redzone.Shared.Debug('[DEATH/SERVER] Réanimation commencée: ', source, ' -> ', targetId)
end)

---Événement: Annulation de réanimation
RegisterNetEvent('redzone:death:cancelRevive')
AddEventHandler('redzone:death:cancelRevive', function(targetId)
    local source = source

    if deadPlayers[targetId] then
        deadPlayers[targetId].beingRevived = false
        deadPlayers[targetId].reviver = nil
    end

    revivingPlayers[source] = nil

    -- Notifier le joueur à terre
    TriggerClientEvent('redzone:death:reviveCancelled', targetId)

    Redzone.Shared.Debug('[DEATH/SERVER] Réanimation annulée: ', source, ' -> ', targetId)
end)

---Événement: Fin de réanimation
RegisterNetEvent('redzone:death:finishRevive')
AddEventHandler('redzone:death:finishRevive', function(targetId)
    local source = source

    -- Vérifications
    if not deadPlayers[targetId] then
        return
    end

    -- Vérifier si c'est bien le bon réanimateur
    if deadPlayers[targetId].reviver ~= source then
        return
    end

    -- Réanimer le joueur
    deadPlayers[targetId] = nil
    revivingPlayers[source] = nil

    TriggerClientEvent('redzone:death:revived', targetId)

    Redzone.Shared.Debug('[DEATH/SERVER] Joueur réanimé par ', source, ': ', targetId)
    Redzone.Server.Utils.Log('PLAYER_REVIVED', source, 'Revived player: ' .. targetId)
end)

---Événement: Début de transport
RegisterNetEvent('redzone:death:startCarry')
AddEventHandler('redzone:death:startCarry', function(targetId)
    local source = source
    Redzone.Shared.Debug('[DEATH/SERVER] Transport commencé: ', source, ' porte ', targetId)

    -- Notifier le joueur porté
    TriggerClientEvent('redzone:death:beingCarried', targetId, source)
end)

---Événement: Fin de transport
RegisterNetEvent('redzone:death:stopCarry')
AddEventHandler('redzone:death:stopCarry', function(targetId)
    local source = source
    Redzone.Shared.Debug('[DEATH/SERVER] Transport terminé: ', source, ' lâche ', targetId)

    -- Notifier le joueur porté qu'il est lâché
    TriggerClientEvent('redzone:death:droppedCarry', targetId)
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

---Événement: Joueur déconnecté
AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Nettoyer les données
    if deadPlayers[source] then
        deadPlayers[source] = nil
    end

    if revivingPlayers[source] then
        local targetId = revivingPlayers[source]
        if deadPlayers[targetId] then
            deadPlayers[targetId].beingRevived = false
            deadPlayers[targetId].reviver = nil
            TriggerClientEvent('redzone:death:reviveCancelled', targetId)
        end
        revivingPlayers[source] = nil
    end
end)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('IsPlayerDead', function(playerId)
    return deadPlayers[playerId] ~= nil
end)

exports('RevivePlayer', function(playerId)
    if deadPlayers[playerId] then
        deadPlayers[playerId] = nil
        TriggerClientEvent('redzone:death:revived', playerId)
        return true
    end
    return false
end)

-- =====================================================
-- DÉMARRAGE
-- =====================================================

CreateThread(function()
    InitDeathESX()
    Redzone.Shared.Debug('[SERVER/DEATH] Module Death serveur chargé')
end)
