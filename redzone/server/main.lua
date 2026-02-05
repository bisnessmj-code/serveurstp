--[[
    =====================================================
    REDZONE LEAGUE - Script Principal Serveur
    =====================================================
    Ce fichier est le point d'entrée du script côté serveur.
    Il gère les événements, les données des joueurs et la synchronisation.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================

-- Framework ESX
local ESX = nil

-- Joueurs actuellement dans le redzone
local playersInRedzone = {}

-- Armes sauvegardées des joueurs
local savedWeapons = {}

-- Anti-spam pour le farm AFK (cooldown par joueur)
local lastFarmReward = {}

-- Instance/Bucket pour le redzone
local REDZONE_BUCKET = 10
local DEFAULT_BUCKET = 0

-- =====================================================
-- SYNCHRONISATION DES ZONES
-- =====================================================

-- Position actuelle des zones (synchronisée pour tous les joueurs)
local currentCombatZoneIndex = 1
local currentLaunderingZoneIndex = 1
local currentCal50ZoneIndex = 1

-- Timestamps des derniers changements (en secondes depuis le démarrage)
local lastCombatZoneChange = 0
local lastLaunderingZoneChange = 0
local lastCal50ZoneChange = 0

-- Timestamp de démarrage du serveur
local serverStartTime = os.time()

-- =====================================================
-- FONCTIONS DE SYNCHRONISATION DES ZONES
-- =====================================================

---Obtient le temps écoulé depuis le démarrage du serveur en secondes
---@return number seconds Temps écoulé en secondes
local function GetServerUptime()
    return os.time() - serverStartTime
end

---Change la zone de combat et notifie tous les joueurs dans le redzone
local function ChangeCombatZone()
    if not Config.CombatZone.Enabled then return end

    local positions = Config.CombatZone.Positions
    if not positions or #positions == 0 then return end

    -- Passer à la position suivante (boucle)
    currentCombatZoneIndex = currentCombatZoneIndex + 1
    if currentCombatZoneIndex > #positions then
        currentCombatZoneIndex = 1
    end

    lastCombatZoneChange = GetServerUptime()

    local newZone = positions[currentCombatZoneIndex]
    Redzone.Shared.Debug('[SERVER/ZONES] Zone de combat changée vers: ', newZone.name, ' (index: ', currentCombatZoneIndex, ')')

    -- Notifier tous les joueurs dans le redzone
    for playerId, _ in pairs(playersInRedzone) do
        TriggerClientEvent('redzone:syncCombatZone', playerId, currentCombatZoneIndex)
    end
end

---Change la zone de blanchiment et notifie tous les joueurs dans le redzone
local function ChangeLaunderingZone()
    if not Config.MoneyLaundering.Enabled then return end

    local positions = Config.MoneyLaundering.Positions
    if not positions or #positions == 0 then return end

    -- Passer à la position suivante (boucle)
    currentLaunderingZoneIndex = currentLaunderingZoneIndex + 1
    if currentLaunderingZoneIndex > #positions then
        currentLaunderingZoneIndex = 1
    end

    lastLaunderingZoneChange = GetServerUptime()

    local newZone = positions[currentLaunderingZoneIndex]
    Redzone.Shared.Debug('[SERVER/ZONES] Zone de blanchiment changée vers: ', newZone.name, ' (index: ', currentLaunderingZoneIndex, ')')

    -- Notifier tous les joueurs dans le redzone
    for playerId, _ in pairs(playersInRedzone) do
        TriggerClientEvent('redzone:syncLaunderingZone', playerId, currentLaunderingZoneIndex)
    end
end

---Change la zone CAL50 et notifie tous les joueurs dans le redzone
local function ChangeCal50Zone()
    if not Config.Cal50Zone or not Config.Cal50Zone.Enabled then return end

    local positions = Config.Cal50Zone.Positions
    if not positions or #positions == 0 then return end

    -- Passer à la position suivante (boucle)
    currentCal50ZoneIndex = currentCal50ZoneIndex + 1
    if currentCal50ZoneIndex > #positions then
        currentCal50ZoneIndex = 1
    end

    lastCal50ZoneChange = GetServerUptime()

    local newZone = positions[currentCal50ZoneIndex]
    Redzone.Shared.Debug('[SERVER/ZONES] Zone CAL50 changée vers: ', newZone.name, ' (index: ', currentCal50ZoneIndex, ')')

    -- Notifier tous les joueurs dans le redzone
    for playerId, _ in pairs(playersInRedzone) do
        TriggerClientEvent('redzone:syncCal50Zone', playerId, currentCal50ZoneIndex)
    end
end

---Démarre le thread de synchronisation des zones côté serveur
local function StartZoneSyncThread()
    CreateThread(function()
        -- Initialiser les timestamps
        lastCombatZoneChange = GetServerUptime()
        lastLaunderingZoneChange = GetServerUptime()
        lastCal50ZoneChange = GetServerUptime()

        Redzone.Shared.Debug('[SERVER/ZONES] Thread de synchronisation des zones démarré')

        while true do
            Wait(1000) -- Vérifier toutes les secondes

            local currentUptime = GetServerUptime()

            -- Vérifier si la zone de combat doit changer
            if Config.CombatZone.Enabled and Config.CombatZone.ChangeInterval then
                if currentUptime - lastCombatZoneChange >= Config.CombatZone.ChangeInterval then
                    ChangeCombatZone()
                end
            end

            -- Vérifier si la zone de blanchiment doit changer
            if Config.MoneyLaundering.Enabled and Config.MoneyLaundering.ChangeInterval then
                if currentUptime - lastLaunderingZoneChange >= Config.MoneyLaundering.ChangeInterval then
                    ChangeLaunderingZone()
                end
            end

            -- Vérifier si la zone CAL50 doit changer
            if Config.Cal50Zone and Config.Cal50Zone.Enabled and Config.Cal50Zone.ChangeInterval then
                if currentUptime - lastCal50ZoneChange >= Config.Cal50Zone.ChangeInterval then
                    ChangeCal50Zone()
                end
            end
        end
    end)
end

---Envoie l'état actuel des zones à un joueur
---@param playerId number L'ID du joueur
local function SendCurrentZonesToPlayer(playerId)
    -- Envoyer la zone de combat actuelle
    if Config.CombatZone.Enabled then
        TriggerClientEvent('redzone:syncCombatZone', playerId, currentCombatZoneIndex)
    end

    -- Envoyer la zone de blanchiment actuelle
    if Config.MoneyLaundering.Enabled then
        TriggerClientEvent('redzone:syncLaunderingZone', playerId, currentLaunderingZoneIndex)
    end

    -- Envoyer la zone CAL50 actuelle
    if Config.Cal50Zone and Config.Cal50Zone.Enabled then
        TriggerClientEvent('redzone:syncCal50Zone', playerId, currentCal50ZoneIndex)
    end

    Redzone.Shared.Debug('[SERVER/ZONES] Zones synchronisées pour le joueur ', playerId)
end

-- =====================================================
-- INITIALISATION DU FRAMEWORK
-- =====================================================

---Initialise la connexion avec ESX
local function InitializeESX()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

    while ESX == nil do
        Wait(100)
    end

    Redzone.Shared.Debug('[SERVER/MAIN] ESX chargé avec succès')
end

-- =====================================================
-- GESTION DES JOUEURS DANS LE REDZONE
-- =====================================================

---Ajoute un joueur à la liste des joueurs dans le redzone
---@param source number L'ID du joueur
---@param spawnId number L'ID du point de spawn utilisé
local function AddPlayerToRedzone(source, spawnId)
    playersInRedzone[source] = {
        joinTime = os.time(),
        spawnId = spawnId,
        kills = 0,
        deaths = 0,
    }

    -- Mettre le joueur dans l'instance Redzone (bucket 10)
    SetPlayerRoutingBucket(source, REDZONE_BUCKET)
    Redzone.Shared.Debug('[SERVER] Joueur ', source, ' mis dans l\'instance ', REDZONE_BUCKET)

    Redzone.Shared.Debug(Config.DebugMessages.PlayerEntered, source)
    Redzone.Server.Utils.Log('PLAYER_ENTERED', source, 'Spawn ID: ' .. tostring(spawnId) .. ', Bucket: ' .. REDZONE_BUCKET)
end

---Retire un joueur de la liste des joueurs dans le redzone
---@param source number L'ID du joueur
local function RemovePlayerFromRedzone(source)
    if playersInRedzone[source] then
        local sessionTime = os.time() - playersInRedzone[source].joinTime
        Redzone.Server.Utils.Log('PLAYER_LEFT', source, 'Session: ' .. sessionTime .. 's, Bucket: ' .. DEFAULT_BUCKET)
    end

    -- Remettre le joueur dans l'instance par défaut (bucket 0)
    SetPlayerRoutingBucket(source, DEFAULT_BUCKET)
    Redzone.Shared.Debug('[SERVER] Joueur ', source, ' remis dans l\'instance ', DEFAULT_BUCKET)

    playersInRedzone[source] = nil
    Redzone.Shared.Debug(Config.DebugMessages.PlayerLeft, source)
end

---Vérifie si un joueur est dans le redzone
---@param source number L'ID du joueur
---@return boolean inRedzone True si dans le redzone
local function IsPlayerInRedzone(source)
    return playersInRedzone[source] ~= nil
end

---Obtient le nombre de joueurs dans le redzone
---@return number count Le nombre de joueurs
local function GetRedzonePlayerCount()
    local count = 0
    for _ in pairs(playersInRedzone) do
        count = count + 1
    end
    return count
end

---Synchronise le nombre de joueurs avec TOUS les clients connectés
---Utilisé pour afficher le compteur au-dessus du PED menu
local function SyncPlayerCountToAllClients()
    local count = GetRedzonePlayerCount()
    TriggerClientEvent('redzone:syncPlayerCount', -1, count)
    Redzone.Shared.Debug('[SERVER] Nombre de joueurs synchronisé: ', count)
end

-- =====================================================
-- ÉVÉNEMENTS CLIENTS
-- =====================================================

---Événement: Joueur entre dans le redzone
RegisterNetEvent('redzone:playerEntered')
AddEventHandler('redzone:playerEntered', function(spawnId)
    local source = source

    -- Vérification de sécurité
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end

    -- Ajout à la liste
    AddPlayerToRedzone(source, spawnId)

    -- Gestion des armes (si configuré)
    if Config.Inventory.RemoveWeaponsOnEnter then
        savedWeapons[source] = Redzone.Server.Utils.RemoveWeapons(source)
    end

    -- IMPORTANT: Envoyer les positions actuelles des zones au nouveau joueur
    SendCurrentZonesToPlayer(source)

    -- Notification aux autres joueurs dans le redzone (DÉSACTIVÉ)
    -- local playerName = Redzone.Server.Utils.GetPlayerName(source)
    -- for playerId, _ in pairs(playersInRedzone) do
    --     if playerId ~= source then
    --         Redzone.Server.Utils.NotifyInfo(playerId, playerName .. ' a rejoint le REDZONE!')
    --     end
    -- end

    -- Log
    Redzone.Server.Utils.Log('REDZONE_JOIN', source, 'Total players: ' .. GetRedzonePlayerCount())

    -- Synchroniser le nombre de joueurs avec tous les clients
    SyncPlayerCountToAllClients()
end)

---Événement: Joueur quitte le redzone
RegisterNetEvent('redzone:playerLeft')
AddEventHandler('redzone:playerLeft', function()
    local source = source

    -- Vérification de sécurité
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end

    -- Restauration des armes (si configuré)
    if Config.Inventory.RestoreWeaponsOnExit and savedWeapons[source] then
        Redzone.Server.Utils.RestoreWeapons(source, savedWeapons[source])
        savedWeapons[source] = nil
    end

    -- Notification aux autres joueurs dans le redzone (DÉSACTIVÉ)
    -- local playerName = Redzone.Server.Utils.GetPlayerName(source)
    -- for playerId, _ in pairs(playersInRedzone) do
    --     if playerId ~= source then
    --         Redzone.Server.Utils.NotifyInfo(playerId, playerName .. ' a quitté le REDZONE.')
    --     end
    -- end

    -- Retrait de la liste
    RemovePlayerFromRedzone(source)

    -- Log
    Redzone.Server.Utils.Log('REDZONE_LEAVE', source, 'Total players: ' .. GetRedzonePlayerCount())

    -- Synchroniser le nombre de joueurs avec tous les clients
    SyncPlayerCountToAllClients()
end)

-- =====================================================
-- GESTION DE LA DÉCONNEXION
-- =====================================================

---Événement: Joueur déconnecté
AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Vérifier si le joueur était dans le redzone (pour sync après)
    local wasInRedzone = playersInRedzone[source] ~= nil

    -- Nettoyer les données du joueur
    if playersInRedzone[source] then
        RemovePlayerFromRedzone(source)
    end

    if savedWeapons[source] then
        savedWeapons[source] = nil
    end

    -- Nettoyer le cooldown de farm AFK
    if lastFarmReward[source] then
        lastFarmReward[source] = nil
    end

    -- Synchroniser le nombre de joueurs si le joueur était dans le redzone
    if wasInRedzone then
        SyncPlayerCountToAllClients()
    end

    Redzone.Shared.Debug('[SERVER] Joueur déconnecté: ', source, ' - Raison: ', reason)
end)

-- =====================================================
-- COMMANDES ADMIN
-- =====================================================

-- Point de sortie pour les kicks
local KICK_EXIT_POINT = vector4(-5804.584472, -917.947266, 505.320800, 87.874016)

-- Groupes autorisés pour les commandes staff
local STAFF_GROUPS = {'staff', 'organisateur', 'responsable', 'admin', 'superadmin'}

---Vérifie si un joueur a les permissions staff
---@param source number L'ID du joueur (0 = console)
---@return boolean hasPermission True si le joueur a les permissions
local function HasStaffPermission(source)
    -- Console toujours autorisée
    if source == 0 then return true end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local group = xPlayer.getGroup()
    for _, allowedGroup in ipairs(STAFF_GROUPS) do
        if group == allowedGroup then
            return true
        end
    end

    return false
end

---Kick un joueur du redzone (téléportation forcée au point de sortie)
---@param targetId number L'ID du joueur à kick
---@param kickedBy number L'ID du joueur qui kick (0 = console)
local function KickPlayerFromRedzone(targetId, kickedBy)
    if not IsPlayerInRedzone(targetId) then
        return false, 'Le joueur n\'est pas dans le redzone'
    end

    -- Notifier le joueur qu'il est kick
    Redzone.Server.Utils.NotifyWarning(targetId, 'Vous avez été expulsé du REDZONE par un staff.')

    -- Déclencher l'event client pour forcer la sortie
    TriggerClientEvent('redzone:forceKick', targetId, KICK_EXIT_POINT)

    -- Retirer le joueur de la liste côté serveur
    RemovePlayerFromRedzone(targetId)

    -- Log
    local kickedByName = kickedBy == 0 and 'Console' or Redzone.Server.Utils.GetPlayerName(kickedBy)
    local targetName = Redzone.Server.Utils.GetPlayerName(targetId)
    Redzone.Server.Utils.Log('REDZONE_KICK', kickedBy, 'Kicked: ' .. targetName .. ' (ID: ' .. targetId .. ')')

    return true, targetName
end

-- =====================================================
-- COMMANDES STAFF (redkick, redkickall, redstatus)
-- =====================================================

---Commande: /redstatus - Affiche le nombre de joueurs dans le redzone
RegisterCommand('redstatus', function(source, args, rawCommand)
    if not HasStaffPermission(source) then
        if source ~= 0 then
            Redzone.Server.Utils.NotifyError(source, 'Vous n\'avez pas la permission.')
        end
        return
    end

    local count = GetRedzonePlayerCount()
    local message = 'REDZONE STATUS: ' .. count .. ' joueur(s) dans le mode de jeu'

    if source == 0 then
        print('[REDZONE] ' .. message)
        -- Afficher aussi la liste des joueurs
        if count > 0 then
            for playerId, data in pairs(playersInRedzone) do
                local name = Redzone.Server.Utils.GetPlayerName(playerId)
                print('  - ' .. name .. ' (ID: ' .. playerId .. ')')
            end
        end
    else
        Redzone.Server.Utils.NotifyInfo(source, message)
    end
end, false)

---Commande: /redkick [id] - Kick un joueur du redzone
RegisterCommand('redkick', function(source, args, rawCommand)
    if not HasStaffPermission(source) then
        if source ~= 0 then
            Redzone.Server.Utils.NotifyError(source, 'Vous n\'avez pas la permission.')
        end
        return
    end

    local targetId = tonumber(args[1])

    if not targetId then
        local usage = 'Usage: /redkick [id]'
        if source == 0 then
            print('[REDZONE] ' .. usage)
        else
            Redzone.Server.Utils.NotifyError(source, usage)
        end
        return
    end

    if not Redzone.Server.Utils.IsPlayerConnected(targetId) then
        local msg = 'Joueur non connecté: ' .. targetId
        if source == 0 then
            print('[REDZONE] ' .. msg)
        else
            Redzone.Server.Utils.NotifyError(source, msg)
        end
        return
    end

    local success, result = KickPlayerFromRedzone(targetId, source)

    if success then
        local msg = 'Joueur ' .. result .. ' (ID: ' .. targetId .. ') expulsé du REDZONE'
        if source == 0 then
            print('[REDZONE] ' .. msg)
        else
            Redzone.Server.Utils.NotifySuccess(source, msg)
        end
    else
        if source == 0 then
            print('[REDZONE] ' .. result)
        else
            Redzone.Server.Utils.NotifyError(source, result)
        end
    end
end, false)

---Commande: /redkickall - Kick tous les joueurs du redzone
RegisterCommand('redkickall', function(source, args, rawCommand)
    if not HasStaffPermission(source) then
        if source ~= 0 then
            Redzone.Server.Utils.NotifyError(source, 'Vous n\'avez pas la permission.')
        end
        return
    end

    local count = GetRedzonePlayerCount()

    if count == 0 then
        local msg = 'Aucun joueur dans le REDZONE'
        if source == 0 then
            print('[REDZONE] ' .. msg)
        else
            Redzone.Server.Utils.NotifyInfo(source, msg)
        end
        return
    end

    -- Copier la liste des joueurs car on va la modifier pendant l'itération
    local playersToKick = {}
    for playerId, _ in pairs(playersInRedzone) do
        table.insert(playersToKick, playerId)
    end

    -- Kick tous les joueurs
    local kickedCount = 0
    for _, playerId in ipairs(playersToKick) do
        local success, _ = KickPlayerFromRedzone(playerId, source)
        if success then
            kickedCount = kickedCount + 1
        end
    end

    local msg = kickedCount .. ' joueur(s) expulsé(s) du REDZONE'
    if source == 0 then
        print('[REDZONE] ' .. msg)
    else
        Redzone.Server.Utils.NotifySuccess(source, msg)
    end

    -- Log
    local kickedByName = source == 0 and 'Console' or Redzone.Server.Utils.GetPlayerName(source)
    Redzone.Server.Utils.Log('REDZONE_KICKALL', source, 'Kicked ' .. kickedCount .. ' players')
end, false)

-- =====================================================
-- ANCIENNES COMMANDES ADMIN (debug)
-- =====================================================

---Commande: Lister les joueurs dans le redzone (debug)
RegisterCommand('redzone_players', function(source, args, rawCommand)
    -- Vérification des permissions (admin seulement ou console)
    if source ~= 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'superadmin' then
            Redzone.Server.Utils.NotifyError(source, 'Vous n\'avez pas la permission.')
            return
        end
    end

    local count = GetRedzonePlayerCount()
    print('[REDZONE] Joueurs dans le redzone: ' .. count)

    for playerId, data in pairs(playersInRedzone) do
        local name = Redzone.Server.Utils.GetPlayerName(playerId)
        local sessionTime = os.time() - data.joinTime
        print(string.format('  - %s (ID: %d) | Spawn: %d | Temps: %ds | K/D: %d/%d',
            name, playerId, data.spawnId, sessionTime, data.kills, data.deaths))
    end

    if source ~= 0 then
        Redzone.Server.Utils.NotifyInfo(source, 'Voir la console serveur pour la liste.')
    end
end, true)

---Commande: Forcer un joueur à entrer dans le redzone
RegisterCommand('redzone_force_enter', function(source, args, rawCommand)
    -- Vérification des permissions
    if source ~= 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'superadmin' then
            Redzone.Server.Utils.NotifyError(source, 'Vous n\'avez pas la permission.')
            return
        end
    end

    local targetId = tonumber(args[1])
    local spawnId = tonumber(args[2]) or 1

    if not targetId then
        print('[REDZONE] Usage: redzone_force_enter [player_id] [spawn_id]')
        return
    end

    if not Redzone.Server.Utils.IsPlayerConnected(targetId) then
        print('[REDZONE] Joueur non connecté: ' .. targetId)
        return
    end

    TriggerClientEvent('redzone:forceEnter', targetId, spawnId)
    Redzone.Server.Utils.Log('ADMIN_FORCE_ENTER', source, 'Target: ' .. targetId .. ', Spawn: ' .. spawnId)
end, true)

---Commande: Forcer un joueur à quitter le redzone
RegisterCommand('redzone_force_leave', function(source, args, rawCommand)
    -- Vérification des permissions
    if source ~= 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'superadmin' then
            Redzone.Server.Utils.NotifyError(source, 'Vous n\'avez pas la permission.')
            return
        end
    end

    local targetId = tonumber(args[1])

    if not targetId then
        print('[REDZONE] Usage: redzone_force_leave [player_id]')
        return
    end

    if not IsPlayerInRedzone(targetId) then
        print('[REDZONE] Le joueur n\'est pas dans le redzone: ' .. targetId)
        return
    end

    TriggerClientEvent('redzone:forceLeave', targetId)
    Redzone.Server.Utils.Log('ADMIN_FORCE_LEAVE', source, 'Target: ' .. targetId)
end, true)

-- =====================================================
-- SYSTÈME DE FARM AFK EN ZONE SAFE
-- =====================================================

---Événement: Récompense de farm AFK en zone safe
RegisterNetEvent('redzone:safezone:farmReward')
AddEventHandler('redzone:safezone:farmReward', function()
    local source = source

    -- Vérification de sécurité
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end

    -- Vérifier que le joueur est bien dans le redzone
    if not IsPlayerInRedzone(source) then
        Redzone.Shared.Debug('[FARM] Tentative de farm hors redzone par joueur: ', source)
        return
    end

    -- Vérifier la config
    if not Config.SafeZoneFarm or not Config.SafeZoneFarm.Enabled then return end

    -- Anti-spam: vérifier le cooldown (minimum 50 secondes entre les récompenses)
    local currentTime = os.time()
    local lastReward = lastFarmReward[source] or 0
    local minInterval = (Config.SafeZoneFarm.Interval or 60) - 10 -- 10 secondes de marge

    if currentTime - lastReward < minInterval then
        Redzone.Shared.Debug('[FARM] Cooldown actif pour joueur: ', source)
        return
    end

    -- Mettre à jour le timestamp
    lastFarmReward[source] = currentTime

    -- Vérifier si le joueur est VIP
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local isVip = false
    local playerGroup = xPlayer.getGroup()
    if Config.SafeZoneFarm.VipGroups then
        for _, vipGroup in ipairs(Config.SafeZoneFarm.VipGroups) do
            if playerGroup == vipGroup then
                isVip = true
                break
            end
        end
    end

    -- Donner la récompense (montant VIP ou normal)
    local amount = isVip and (Config.SafeZoneFarm.VipAmount or 80) or (Config.SafeZoneFarm.Amount or 60)
    local moneyType = Config.SafeZoneFarm.MoneyType or 'black_money'

    if moneyType == 'black_money' then
        xPlayer.addAccountMoney('black_money', amount)
    else
        xPlayer.addMoney(amount)
    end

    -- Notification au joueur (message VIP ou normal)
    local messageFormat = isVip and (Config.SafeZoneFarm.Messages.RewardVip or '+$%s (VIP)') or (Config.SafeZoneFarm.Messages.Reward or '+$%s')
    local message = string.format(messageFormat, amount)
    Redzone.Server.Utils.NotifySuccess(source, message)

    Redzone.Shared.Debug('[FARM] Récompense donnée - Joueur: ', source, ' | Montant: ', amount, ' | VIP: ', isVip)
    Redzone.Server.Utils.Log('SAFEZONE_FARM', source, 'Amount: ' .. amount .. (isVip and ' (VIP)' or ''))
end)


-- =====================================================
-- CALLBACKS (pour ox_lib ou autres systèmes)
-- =====================================================

-- Callback: Vérifier si un joueur est dans le redzone
-- Peut être utilisé par d'autres scripts

---Export: Vérifier si un joueur est dans le redzone
exports('IsPlayerInRedzone', function(playerId)
    return IsPlayerInRedzone(playerId)
end)

---Export: Obtenir le nombre de joueurs dans le redzone
exports('GetRedzonePlayerCount', function()
    return GetRedzonePlayerCount()
end)

---Export: Obtenir la liste des joueurs dans le redzone
exports('GetRedzonePlayersv', function()
    return Redzone.Shared.DeepCopy(playersInRedzone)
end)

-- =====================================================
-- SYNCHRONISATION DU NOMBRE DE JOUEURS (pour affichage PED)
-- =====================================================

---Événement: Client demande le nombre de joueurs actuel
RegisterNetEvent('redzone:requestPlayerCount')
AddEventHandler('redzone:requestPlayerCount', function()
    local source = source
    local count = GetRedzonePlayerCount()
    TriggerClientEvent('redzone:syncPlayerCount', source, count)
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

-- Thread d'initialisation
CreateThread(function()
    -- Initialiser ESX
    InitializeESX()

    -- Configurer le bucket Redzone
    -- SetRoutingBucketPopulationEnabled: active/désactive la population (PNJ, véhicules)
    -- SetRoutingBucketEntityLockdownMode: 'strict' = seules les entités créées dans ce bucket existent
    SetRoutingBucketPopulationEnabled(REDZONE_BUCKET, true)
    SetRoutingBucketEntityLockdownMode(REDZONE_BUCKET, 'inactive') -- 'inactive' = comportement normal

    Redzone.Shared.Debug('[SERVER] Instance Redzone configurée - Bucket: ', REDZONE_BUCKET)

    -- Démarrer la synchronisation des zones
    StartZoneSyncThread()

    -- Message de démarrage
    print([[

    ██████╗ ███████╗██████╗ ███████╗ ██████╗ ███╗   ██╗███████╗
    ██╔══██╗██╔════╝██╔══██╗╚══███╔╝██╔═══██╗████╗  ██║██╔════╝
    ██████╔╝█████╗  ██║  ██║  ███╔╝ ██║   ██║██╔██╗ ██║█████╗
    ██╔══██╗██╔══╝  ██║  ██║ ███╔╝  ██║   ██║██║╚██╗██║██╔══╝
    ██║  ██║███████╗██████╔╝███████╗╚██████╔╝██║ ╚████║███████╗
    ╚═╝  ╚═╝╚══════╝╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝

    REDZONE LEAGUE v1.0.0 - Serveur démarré
    Mode Debug: ]] .. (Config.Debug and 'ACTIVÉ' or 'DÉSACTIVÉ') .. [[

    Instance Redzone: Bucket ]] .. REDZONE_BUCKET .. [[

    ]])

    Redzone.Shared.Debug(Config.DebugMessages.ScriptLoaded)
end)

Redzone.Shared.Debug('[SERVER/MAIN] Module principal serveur chargé')
