-- ========================================
-- PVP GUNFIGHT SERVER MAIN - VERSION 5.3.1 PATCHED
-- FIX CRITIQUE: Routing bucket non reset après déconnexion
-- ========================================
-- PATCH NOTES v5.3.1 (15 janvier 2026):
-- ✅ FIX ResetPlayerBucket: Ajout Wait(100) synchronisation
-- ✅ FIX HandlePlayerDisconnect: Verification bucket = 0 avant TP
-- ✅ FIX EndMatch: Verification bucket = 0 avant TP
-- ✅ FIX Délai augmenté après reset bucket (500 -> 1000ms)
-- ✅ RÉSOLU: Joueurs restent dans instance après déconnexion
-- ✅ RÉSOLU: Joueurs invisibles au lobby après fin match
-- ========================================
-- PATCH NOTES v5.3.0 (15 janvier 2026):
-- ✅ FIX HandlePlayerDisconnect: Terminaison match complète
-- ✅ FIX Condition de course: Flag matchBeingTerminated
-- ✅ FIX CheckRoundEnd: Détection proactive déconnexions
-- ✅ FIX Thread mort: Respect flag terminaison
-- ✅ FIX Joueur retiré de team1/team2 immédiatement
-- ✅ FIX Event pvp:stopSpectating ajouté
-- ✅ RÉSOLU: Joueurs bloqués 3v4 après déconnexion
-- ✅ RÉSOLU: Rounds qui ne passent plus
-- ========================================
-- PATCH NOTES v5.2.1 (13 janvier 2026):
-- ✅ FIX Ligne 960: antitankKiller conversion sécurisée
-- ✅ FIX Ligne 318: killerId conversion sécurisée
-- ✅ FIX Ligne 291: killerId dans BroadcastKillfeed
-- ✅ NOUVEAU: Fonction SafeToNumber() globale
-- ✅ RÉSOLU: "attempt to compare number with string"
-- ✅ RÉSOLU: Server thread hitch warnings
-- ========================================

DebugServer('Chargement systeme PVP (VERSION 5.3.1 PATCHED - FIX ROUTING BUCKET)...')

-- ========================================
-- ✅ PATCH CRITIQUE: UTILITAIRE CONVERSION SÉCURISÉE
-- Résout: attempt to compare number with string
-- ========================================
local function SafeToNumber(value, default)
    local num = tonumber(value)
    if not num then
        if value ~= nil then
            DebugServer('[SAFE_CONVERT] ⚠️ Conversion échouée: %s (type: %s) -> défaut: %s', 
                tostring(value), type(value), tostring(default or 0))
        end
        return default or 0
    end
    return num
end

-- ========================================
-- CONFIGURATION PERFORMANCE
-- ========================================
local PERF = {
    heartbeatInterval = 15000,
    heartbeatTimeout = 30000,
    cleanupInterval = 60000,
    maxPlayersPerBatch = 50,
    batchDelay = 100,
    rateLimitWindow = 500,
    statsCacheDuration = 2000,
    matchEndDelay = 3000,
    postMatchDelay = 1000,
    deathCheckInterval = 500,
}

local REWARDS = {
    killReward = 1000,
    winReward = 1000,
    rewardType = 'bank'
}

local EXIT_POINT = {
    x = -5814.118652,
    y = -918.606567,
    z = 506.416016,
    w = 87.874016
}

local MATCH_STATE = {
    CREATING = 'creating',
    STARTING = 'starting',
    PLAYING = 'playing',
    ROUND_END = 'round_end',
    FINISHING = 'finishing',
    CANCELLED = 'cancelled',
    FINISHED = 'finished'
}

-- ========================================
-- VARIABLES GLOBALES
-- ========================================
local queues = {['1v1'] = {}, ['2v2'] = {}, ['3v3'] = {}, ['4v4'] = {}}
local activeMatches = {}
local playersInQueue = {}
local playerCurrentMatch = {}
local playerCurrentBucket = {}
local playerWasSoloBeforeMatch = {}
local nextBucketId = 100
local playerLastHeartbeat = {}
local cachedQueueStats = {['1v1'] = 0, ['2v2'] = 0, ['3v3'] = 0, ['4v4'] = 0, lastUpdate = 0}
local playerEventTimestamps = {}
local matchBeingTerminated = {} -- FIX: Flag pour éviter les terminaisons concurrentes

local WEAPON_NAMES = {
    [GetHashKey('WEAPON_PISTOL')] = 'Pistol',
    [GetHashKey('WEAPON_PISTOL50')] = 'Pistol .50',
    [GetHashKey('WEAPON_COMBATPISTOL')] = 'Combat Pistol',
    [GetHashKey('WEAPON_APPISTOL')] = 'AP Pistol',
    [GetHashKey('WEAPON_HEAVYPISTOL')] = 'Heavy Pistol',
    [GetHashKey('WEAPON_SNSPISTOL')] = 'SNS Pistol',
    [GetHashKey('WEAPON_VINTAGEPISTOL')] = 'Vintage Pistol',
    [GetHashKey('WEAPON_ASSAULTRIFLE')] = 'AK-47',
    [GetHashKey('WEAPON_CARBINERIFLE')] = 'M4A1',
    [GetHashKey('WEAPON_SMG')] = 'SMG',
    [GetHashKey('WEAPON_MICROSMG')] = 'Micro SMG',
    [GetHashKey('WEAPON_PUMPSHOTGUN')] = 'Pump Shotgun',
    [GetHashKey('WEAPON_KNIFE')] = 'Knife',
}

-- ========================================
-- DÉCLARATIONS FORWARD (FIX CRITIQUE)
-- ========================================
local MarkPlayerDead
local CheckRoundEnd
local EndRound
local HandlePlayerDisconnect
local GetTeammatesForPlayer
local SyncAllPlayersInMatch
local ForceCleanupClientState
local TeleportPlayersToArena
local StartRound
local RespawnPlayers
local CreateMatch
local CheckAndCreateMatch
local CancelMatch
local GetMatchSafe
local IsMatchValid
local TeleportToExitPoint
local ResetPlayerBucket
local SetPlayerBucket
local CreateMatchBucket
local BroadcastKillfeed
local GetRandomArena
local BroadcastQueueStatsIfChanged
local RewardWinners
local RewardKill
local GivePlayerMoney
local CancelGroupSearch
local HandlePlayerDisconnectFromQueue
local ShouldSwapSpawns

-- ========================================
-- FONCTIONS UTILITAIRES
-- ========================================
local function IsRateLimited(playerId, eventName)
    local now = GetGameTimer()
    local key = playerId .. '_' .. eventName
    local lastTime = playerEventTimestamps[key] or 0
    if (now - lastTime) < PERF.rateLimitWindow then return true end
    playerEventTimestamps[key] = now
    return false
end

local function GetPlayerFiveMNameWithID(playerId)
    if not playerId or playerId <= 0 then return "Joueur inconnu" end
    if GetPlayerPing(playerId) <= 0 then return "Joueur déconnecté" end
    local playerName = GetPlayerName(playerId)
    if playerName then playerName = playerName:gsub("%^%d", "") else playerName = "Joueur" end
    return string.format("%s [%d]", playerName, playerId)
end

function IsMatchValid(matchId)
    if not matchId then return false end
    local match = activeMatches[matchId]
    if not match then return false end
    if match.status == MATCH_STATE.CANCELLED or match.status == MATCH_STATE.FINISHED then return false end
    return true
end

function GetMatchSafe(matchId)
    if not matchId then DebugError('GetMatchSafe: matchId nil') return nil end
    local match = activeMatches[matchId]
    if not match then DebugError('GetMatchSafe: match introuvable') return nil end
    if match.status == MATCH_STATE.CANCELLED or match.status == MATCH_STATE.FINISHED then return nil end
    return match
end

function GivePlayerMoney(playerId, amount, accountType)
    if not playerId or playerId <= 0 or GetPlayerPing(playerId) <= 0 then return false end
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    xPlayer.addAccountMoney(accountType or 'bank', amount)
    DebugServer('💰 +%d$ pour joueur %d', amount, playerId)
    return true
end

function RewardKill(killerId)
    if not killerId or killerId <= 0 then return end
    GivePlayerMoney(killerId, REWARDS.killReward, REWARDS.rewardType)
end

function RewardWinners(winnerIds)
    if not winnerIds or #winnerIds == 0 then return end
    for i = 1, #winnerIds do
        local playerId = winnerIds[i]
        if playerId > 0 and GetPlayerPing(playerId) > 0 then
            if GivePlayerMoney(playerId, REWARDS.winReward, REWARDS.rewardType) then
                TriggerClientEvent('brutal_notify:SendAlert', playerId, '🏆 Victoire!', '+' .. REWARDS.winReward .. '$', 5000, 'success')
            end
        end
    end
end

local function GetQueueStats()
    local now = GetGameTimer()
    if (now - cachedQueueStats.lastUpdate) < PERF.statsCacheDuration then
        return {['1v1'] = cachedQueueStats['1v1'], ['2v2'] = cachedQueueStats['2v2'], ['3v3'] = cachedQueueStats['3v3'], ['4v4'] = cachedQueueStats['4v4']}
    end
    local stats = {['1v1'] = #queues['1v1'], ['2v2'] = #queues['2v2'], ['3v3'] = #queues['3v3'], ['4v4'] = #queues['4v4']}
    cachedQueueStats = {['1v1'] = stats['1v1'], ['2v2'] = stats['2v2'], ['3v3'] = stats['3v3'], ['4v4'] = stats['4v4'], lastUpdate = now}
    return stats
end

local function HasStatsChanged(newStats)
    for mode, count in pairs(newStats) do
        if mode ~= 'lastUpdate' and cachedQueueStats[mode] ~= count then return true end
    end
    return false
end

function BroadcastQueueStatsIfChanged()
    local newStats = GetQueueStats()
    if not HasStatsChanged(newStats) then return end
    for mode, count in pairs(newStats) do cachedQueueStats[mode] = count end
    cachedQueueStats.lastUpdate = GetGameTimer()
    local players = GetPlayers()
    local totalPlayers = #players
    if totalPlayers == 0 then return end
    for i = 1, totalPlayers, PERF.maxPlayersPerBatch do
        CreateThread(function()
            Wait((i - 1) / PERF.maxPlayersPerBatch * PERF.batchDelay)
            local endIndex = math.min(i + PERF.maxPlayersPerBatch - 1, totalPlayers)
            for j = i, endIndex do
                local playerId = tonumber(players[j])
                if playerId and playerId > 0 and GetPlayerPing(playerId) > 0 then
                    TriggerClientEvent('pvp:updateQueueStats', playerId, newStats)
                end
            end
        end)
    end
end

function CreateMatchBucket()
    local bucketId = nextBucketId
    nextBucketId = nextBucketId + 1
    SetRoutingBucketPopulationEnabled(bucketId, true)
    SetRoutingBucketEntityLockdownMode(bucketId, 'strict')
    DebugBucket('Bucket %d créé', bucketId)
    return bucketId
end

function SetPlayerBucket(playerId, bucketId)
    if playerId <= 0 then return end
    SetPlayerRoutingBucket(playerId, bucketId)
    playerCurrentBucket[playerId] = bucketId
    Wait(100)
end

function ResetPlayerBucket(playerId)
    if playerId <= 0 then return end
    local previousBucket = GetPlayerRoutingBucket(playerId)
    SetPlayerRoutingBucket(playerId, 0)
    playerCurrentBucket[playerId] = nil
    Wait(100) -- FIX: Attendre synchronisation bucket comme SetPlayerBucket
    DebugServer('[BUCKET] Joueur %d: bucket %d -> 0', playerId, previousBucket or -1)
end

function TeleportToExitPoint(playerId)
    if not playerId or playerId <= 0 or GetPlayerPing(playerId) <= 0 then return end
    DebugServer('📍 Téléportation joueur %d au point de sortie', playerId)
    TriggerClientEvent('pvp:teleportToExit', playerId, EXIT_POINT)
end

function ForceCleanupClientState(playerId)
    if not playerId or playerId <= 0 or GetPlayerPing(playerId) <= 0 then return end
    DebugServer('🧹 Nettoyage état client: Joueur %d', playerId)
    TriggerClientEvent('pvp:forceCleanup', playerId)
    Wait(200)
    TriggerClientEvent('pvp:disableZones', playerId)
    TriggerClientEvent('pvp:disableTeammateHUD', playerId)
    TriggerClientEvent('pvp:hideScoreHUD', playerId)
    TriggerClientEvent('pvp:searchCancelled', playerId)
    Wait(100)
    TriggerClientEvent('pvp:forceCloseUI', playerId)
end

-- FIX: Filtrer les arenes par mode (1v1, 2v2, 3v3, 4v4)
function GetRandomArena(mode)
    local arenaKeys = {}

    for key, arena in pairs(Config.Arenas) do
        -- Verifier si l'arene supporte ce mode
        local supportsMode = false

        if arena.modes then
            for i = 1, #arena.modes do
                if arena.modes[i] == mode then
                    supportsMode = true
                    break
                end
            end
        else
            -- Si pas de modes defini, l'arene supporte tous les modes (retrocompatibilite)
            supportsMode = true
        end

        if supportsMode then
            arenaKeys[#arenaKeys + 1] = key
        end
    end

    -- Si aucune arene trouvee pour ce mode, fallback sur toutes les arenes
    if #arenaKeys == 0 then
        DebugServer('[ARENA] ATTENTION: Aucune arene pour le mode %s, utilisation de toutes les arenes', mode)
        for key in pairs(Config.Arenas) do
            arenaKeys[#arenaKeys + 1] = key
        end
    end

    local randomIndex = math.random(1, #arenaKeys)
    local arenaKey = arenaKeys[randomIndex]

    DebugServer('[ARENA] Mode %s -> Arene selectionnee: %s (%d arenes disponibles)', mode, arenaKey, #arenaKeys)

    return arenaKey, Config.Arenas[arenaKey]
end

function GetTeammatesForPlayer(matchId, playerId)
    local match = GetMatchSafe(matchId)
    if not match then return {} end
    local playerTeam = match.playerTeams[playerId]
    if not playerTeam then return {} end
    local teammates = {}
    local teamPlayers = playerTeam == 'team1' and match.team1 or match.team2
    for i = 1, #teamPlayers do
        if teamPlayers[i] ~= playerId and teamPlayers[i] > 0 then
            teammates[#teammates + 1] = teamPlayers[i]
        end
    end
    return teammates
end

function SyncAllPlayersInMatch(matchId)
    local match = GetMatchSafe(matchId)
    if not match then return end
    for i = 1, #match.players do
        local playerId = match.players[i]
        if playerId > 0 and GetPlayerPing(playerId) > 0 then
            local currentBucket = GetPlayerRoutingBucket(playerId)
            if currentBucket ~= match.bucketId then SetPlayerBucket(playerId, match.bucketId) end
        end
    end
end

function BroadcastKillfeed(matchId, killerId, victimId, weaponHash, isHeadshot)
    local match = GetMatchSafe(matchId)
    if not match then return end
    -- ✅ PATCH LIGNE 291: Conversion sécurisée killerId
    local safeKillerId = tonumber(killerId)
    local killerName = nil
    local victimName = "Unknown"
    if safeKillerId and safeKillerId > 0 then killerName = GetPlayerFiveMNameWithID(safeKillerId) end
    victimName = GetPlayerFiveMNameWithID(victimId)
    local weaponName = WEAPON_NAMES[weaponHash] or "Unknown Weapon"
    if not safeKillerId or safeKillerId == victimId then killerName = nil weaponName = "Suicide" end
    for i = 1, #match.players do
        local playerId = match.players[i]
        if playerId > 0 and GetPlayerPing(playerId) > 0 then
            TriggerClientEvent('pvp:showKillfeed', playerId, killerName, victimName, weaponName, isHeadshot)
        end
    end
end

-- ========================================
-- FONCTION CRITIQUE: MARQUER JOUEUR MORT
-- ========================================
function MarkPlayerDead(matchId, match, victimId, killerId, weaponHash, isHeadshot)
    if not match then DebugError('[DEATH] Match nil') return false end
    if match.status ~= MATCH_STATE.PLAYING then DebugServer('[DEATH] Match pas en PLAYING') return false end
    if not match.currentRound or type(match.currentRound) ~= 'number' then match.currentRound = 1 end
    local deathKey = tostring(victimId) .. '_' .. tostring(match.currentRound)
    DebugServer('[DEATH] DeathKey: "%s"', deathKey)
    if match.deathProcessed[deathKey] then DebugServer('[DEATH] Déjà traité') return false end
    match.deathProcessed[deathKey] = true
    match.deadPlayers[victimId] = true
    DebugServer('[DEATH] 💀 Joueur %d MORT - Killer: %s, Round: %d', victimId, tostring(killerId), match.currentRound)
    if victimId > 0 and GetPlayerPing(victimId) > 0 then TriggerEvent('pvp:confirmDeathToClient', victimId) end
    local isFriendlyFire = false
    -- ✅ PATCH LIGNE 318: Conversion sécurisée killerId
    local safeKillerId = tonumber(killerId)
    if safeKillerId and safeKillerId > 0 then
        local killerTeam = match.playerTeams[safeKillerId]
        local victimTeam = match.playerTeams[victimId]
        if killerTeam and victimTeam and killerTeam == victimTeam then isFriendlyFire = true end
    end
    match.roundStats = match.roundStats or {}
    match.roundStats[#match.roundStats + 1] = {victim = victimId, killer = safeKillerId or killerId, weaponHash = weaponHash, isHeadshot = isHeadshot, time = os.time(), friendlyFire = isFriendlyFire}
    if safeKillerId and safeKillerId ~= victimId and not isFriendlyFire then
        exports['pvp_gunfight']:UpdatePlayerKillsByMode(safeKillerId, 1, match.mode)
        RewardKill(safeKillerId)
    end
    exports['pvp_gunfight']:UpdatePlayerDeathsByMode(victimId, 1, match.mode)
    BroadcastKillfeed(matchId, safeKillerId or killerId, victimId, weaponHash, isHeadshot)
    return true
end

-- ========================================
-- FONCTION CRITIQUE: VÉRIFIER FIN ROUND
-- ========================================
function CheckRoundEnd(matchId, match)
    if not match then return end
    -- FIX: Vérifier si le match est en cours de terminaison
    if matchBeingTerminated[matchId] then
        DebugServer('[ROUND-CHECK] Match %d en cours de terminaison, skip', matchId)
        return
    end
    if match.status ~= MATCH_STATE.PLAYING then return end
    if not match.currentRound or type(match.currentRound) ~= 'number' then match.currentRound = 1 end

    local team1Alive = 0
    local team2Alive = 0
    local team1Disconnected = 0
    local team2Disconnected = 0

    -- FIX: Compter aussi les joueurs déconnectés séparément
    for i = 1, #match.team1 do
        local playerId = match.team1[i]
        local ping = GetPlayerPing(playerId)
        if ping <= 0 then
            -- Joueur déconnecté - marquer comme mort et compter
            match.deadPlayers[playerId] = true
            team1Disconnected = team1Disconnected + 1
            DebugServer('[ROUND-CHECK] T1 Joueur %d deconnecte (ping=0)', playerId)
        elseif not match.deadPlayers[playerId] then
            team1Alive = team1Alive + 1
        end
    end

    for i = 1, #match.team2 do
        local playerId = match.team2[i]
        local ping = GetPlayerPing(playerId)
        if ping <= 0 then
            -- Joueur déconnecté - marquer comme mort et compter
            match.deadPlayers[playerId] = true
            team2Disconnected = team2Disconnected + 1
            DebugServer('[ROUND-CHECK] T2 Joueur %d deconnecte (ping=0)', playerId)
        elseif not match.deadPlayers[playerId] then
            team2Alive = team2Alive + 1
        end
    end

    DebugServer('[ROUND-CHECK] Match %d Round %d - T1:%d (dc:%d) T2:%d (dc:%d)',
        matchId, match.currentRound, team1Alive, team1Disconnected, team2Alive, team2Disconnected)

    -- FIX: Si une équipe entière est déconnectée, forcer la terminaison du match
    local team1Size = #match.team1
    local team2Size = #match.team2

    if team1Disconnected > 0 or team2Disconnected > 0 then
        -- Un joueur est déconnecté - appeler HandlePlayerDisconnect pour le premier déconnecté trouvé
        for i = 1, #match.team1 do
            local playerId = match.team1[i]
            if GetPlayerPing(playerId) <= 0 and not matchBeingTerminated[matchId] then
                DebugServer('[ROUND-CHECK] Declenchement HandlePlayerDisconnect pour T1 joueur %d', playerId)
                CreateThread(function() HandlePlayerDisconnect(playerId) end)
                return -- Important: sortir pour éviter les appels multiples
            end
        end
        for i = 1, #match.team2 do
            local playerId = match.team2[i]
            if GetPlayerPing(playerId) <= 0 and not matchBeingTerminated[matchId] then
                DebugServer('[ROUND-CHECK] Declenchement HandlePlayerDisconnect pour T2 joueur %d', playerId)
                CreateThread(function() HandlePlayerDisconnect(playerId) end)
                return -- Important: sortir pour éviter les appels multiples
            end
        end
    end

    local roundWinner = nil
    if team1Alive == 0 and team2Alive > 0 then roundWinner = 'team2'
    elseif team2Alive == 0 and team1Alive > 0 then roundWinner = 'team1'
    elseif team1Alive == 0 and team2Alive == 0 then
        if match.roundStats and #match.roundStats > 0 then
            for i = #match.roundStats, 1, -1 do
                local stat = match.roundStats[i]
                if stat.killer and not stat.friendlyFire then roundWinner = match.playerTeams[stat.killer] break end
            end
        end
        if not roundWinner then roundWinner = 'team1' end
    end
    if roundWinner then
        match.score[roundWinner] = match.score[roundWinner] + 1
        DebugServer('[ROUND-CHECK] Round terminé - %s gagne', roundWinner)
        EndRound(matchId, match, roundWinner)
    end
end

-- ========================================
-- THREADS
-- ========================================
CreateThread(function()
    DebugServer('Thread heartbeat démarré')
    while true do
        Wait(PERF.heartbeatInterval)
        local currentTime = GetGameTimer()
        local crashedPlayers = {}
        for playerId, matchId in pairs(playerCurrentMatch) do
            if activeMatches[matchId] then
                local lastHeartbeat = playerLastHeartbeat[playerId] or 0
                if (currentTime - lastHeartbeat) > PERF.heartbeatTimeout and GetPlayerPing(playerId) <= 0 then
                    crashedPlayers[#crashedPlayers + 1] = playerId
                end
            end
        end
        for i = 1, #crashedPlayers do CreateThread(function() HandlePlayerDisconnect(crashedPlayers[i]) end) end
    end
end)

RegisterNetEvent('pvp:heartbeat', function() playerLastHeartbeat[source] = GetGameTimer() end)

CreateThread(function()
    DebugServer('Thread cleanup démarré')
    while true do
        Wait(PERF.cleanupInterval)
        local now = GetGameTimer()
        for key, timestamp in pairs(playerEventTimestamps) do
            if (now - timestamp) > 60000 then playerEventTimestamps[key] = nil end
        end
        for playerId, _ in pairs(playerLastHeartbeat) do
            if GetPlayerPing(playerId) <= 0 then playerLastHeartbeat[playerId] = nil end
        end
    end
end)

CreateThread(function()
    DebugServer('Thread vérification mort serveur démarré - CORRIGÉ v2')
    while true do
        Wait(PERF.deathCheckInterval)
        for matchId, match in pairs(activeMatches) do
            -- FIX: Skip si le match est en cours de terminaison
            if matchBeingTerminated[matchId] then
                DebugServer('[DEATH-CHECK] Match %d en terminaison, skip', matchId)
                goto continue
            end

            if not match.currentRound or type(match.currentRound) ~= 'number' then match.currentRound = 1 end
            if match.status == MATCH_STATE.PLAYING then
                local team1Alive = 0
                local team2Alive = 0
                local hasDisconnectedPlayer = false
                local disconnectedPlayerId = nil

                for i = 1, #match.team1 do
                    local playerId = match.team1[i]
                    if not match.deadPlayers[playerId] then
                        local ping = GetPlayerPing(playerId)
                        if ping > 0 then
                            local ped = GetPlayerPed(playerId)
                            if ped and ped > 0 then
                                local health = GetEntityHealth(ped)
                                if health <= 0 then
                                    match.deadPlayers[playerId] = true
                                    DebugServer('[DEATH-CHECK] T1 Joueur %d mort (health=0)', playerId)
                                else
                                    team1Alive = team1Alive + 1
                                end
                            else
                                team1Alive = team1Alive + 1
                            end
                        else
                            -- FIX: Joueur déconnecté détecté
                            match.deadPlayers[playerId] = true
                            hasDisconnectedPlayer = true
                            disconnectedPlayerId = playerId
                            DebugServer('[DEATH-CHECK] T1 Joueur %d DECONNECTE (ping=0)', playerId)
                        end
                    end
                end

                for i = 1, #match.team2 do
                    local playerId = match.team2[i]
                    if not match.deadPlayers[playerId] then
                        local ping = GetPlayerPing(playerId)
                        if ping > 0 then
                            local ped = GetPlayerPed(playerId)
                            if ped and ped > 0 then
                                local health = GetEntityHealth(ped)
                                if health <= 0 then
                                    match.deadPlayers[playerId] = true
                                    DebugServer('[DEATH-CHECK] T2 Joueur %d mort (health=0)', playerId)
                                else
                                    team2Alive = team2Alive + 1
                                end
                            else
                                team2Alive = team2Alive + 1
                            end
                        else
                            -- FIX: Joueur déconnecté détecté
                            match.deadPlayers[playerId] = true
                            hasDisconnectedPlayer = true
                            disconnectedPlayerId = playerId
                            DebugServer('[DEATH-CHECK] T2 Joueur %d DECONNECTE (ping=0)', playerId)
                        end
                    end
                end

                -- FIX: Si un joueur est déconnecté, forcer la terminaison du match immédiatement
                if hasDisconnectedPlayer and disconnectedPlayerId and not matchBeingTerminated[matchId] then
                    DebugServer('[DEATH-CHECK] Match %d - Deconnexion detectee, terminaison forcee', matchId)
                    local pid = disconnectedPlayerId
                    CreateThread(function() HandlePlayerDisconnect(pid) end)
                elseif team1Alive == 0 or team2Alive == 0 then
                    DebugServer('[DEATH-CHECK] Match %d Round %d - FIN ROUND', matchId, match.currentRound)
                    CreateThread(function() CheckRoundEnd(matchId, match) end)
                end
            end
            ::continue::
        end
    end
end)

AddEventHandler('pvp:forceProcessDeath', function(victimId, killerId, weaponHash, isHeadshot)
    local matchId = playerCurrentMatch[victimId]
    if not matchId then return end
    local match = activeMatches[matchId]
    if not match then return end
    DebugServer('[FORCE-DEATH] Force mort: Victime=%d, Killer=%s', victimId, tostring(killerId))
    if MarkPlayerDead(matchId, match, victimId, killerId, weaponHash, isHeadshot) then
        CheckRoundEnd(matchId, match)
    end
end)

-- ========================================
-- ANNULER/CANCEL FONCTIONS
-- ========================================
function CancelGroupSearch(groupMembers, mode, reason)
    if not groupMembers or #groupMembers == 0 then return end
    for i = 1, #groupMembers do
        local memberId = groupMembers[i]  -- Capturer AVANT CreateThread pour éviter le problème de closure
        CreateThread(function()
            for j = #queues[mode], 1, -1 do
                if queues[mode][j] == memberId then table.remove(queues[mode], j) break end
            end
            playersInQueue[memberId] = nil
            playerLastHeartbeat[memberId] = nil
            if GetPlayerPing(memberId) > 0 then
                TriggerClientEvent('pvp:searchCancelled', memberId)
                TriggerClientEvent('brutal_notify:SendAlert', memberId, 'Recherche Annulée', reason, 4000, 'error')
            end
        end)
    end
    BroadcastQueueStatsIfChanged()
end

function HandlePlayerDisconnectFromQueue(playerId)
    if not playersInQueue[playerId] then return end
    local queueData = playersInQueue[playerId]
    local mode = queueData.mode
    local groupMembers = queueData.groupMembers or {playerId}
    if #groupMembers > 1 then
        CancelGroupSearch(groupMembers, mode, 'Un membre a quitté')
    else
        for j = #queues[mode], 1, -1 do
            if queues[mode][j] == playerId then table.remove(queues[mode], j) break end
        end
        playersInQueue[playerId] = nil
        playerLastHeartbeat[playerId] = nil
        BroadcastQueueStatsIfChanged()
    end
end

function CancelMatch(matchId, reason)
    local match = activeMatches[matchId]
    if not match then return end
    DebugWarn('ANNULATION MATCH %d - %s', matchId, reason)
    match.status = MATCH_STATE.CANCELLED
    for i = 1, #match.players do
        local playerId = match.players[i]
        if playerId > 0 and GetPlayerPing(playerId) > 0 then
            ForceCleanupClientState(playerId)
            Wait(100)
            TriggerClientEvent('pvp:forceReturnToLobby', playerId)
            TriggerClientEvent('brutal_notify:SendAlert', playerId, 'Match Annulé', reason, 5000, 'error')
            playerCurrentMatch[playerId] = nil
            playerLastHeartbeat[playerId] = nil
            ResetPlayerBucket(playerId)
        end
    end
    Wait(1000)
    activeMatches[matchId] = nil
end

-- ========================================
-- ÉCHANGE SPAWNS
-- ========================================
function ShouldSwapSpawns(roundNumber)
    return (roundNumber % 2) == 0
end

function TeleportPlayersToArena(matchId, match, arena, arenaKey)
    if not match then return end
    local shouldSwap = ShouldSwapSpawns(match.currentRound)
    if shouldSwap then DebugServer('Round %d: ÉCHANGE SPAWNS', match.currentRound) end
    local team1Spawns = shouldSwap and arena.teamB or arena.teamA
    for i = 1, #match.team1 do
        local playerId = match.team1[i]
        if team1Spawns[i] and playerId > 0 and GetPlayerPing(playerId) > 0 then
            TriggerClientEvent('pvp:teleportToSpawn', playerId, team1Spawns[i], 'team1', matchId, arenaKey)
        end
    end
    local team2Spawns = shouldSwap and arena.teamA or arena.teamB
    for i = 1, #match.team2 do
        local playerId = match.team2[i]
        if team2Spawns[i] and playerId > 0 and GetPlayerPing(playerId) > 0 then
            TriggerClientEvent('pvp:teleportToSpawn', playerId, team2Spawns[i], 'team2', matchId, arenaKey)
        end
    end
    Wait(1000)
    for i = 1, #match.players do
        local playerId = match.players[i]
        if playerId > 0 and GetPlayerPing(playerId) > 0 then
            local teammates = GetTeammatesForPlayer(matchId, playerId)
            TriggerClientEvent('pvp:setTeammates', playerId, teammates)
        end
    end
end

function RespawnPlayers(matchId, match, arena)
    if not match or not arena then return end
    local shouldSwap = ShouldSwapSpawns(match.currentRound)
    local team1Spawns = shouldSwap and arena.teamB or arena.teamA
    for i = 1, #match.team1 do
        if team1Spawns[i] and match.team1[i] > 0 and GetPlayerPing(match.team1[i]) > 0 then
            TriggerClientEvent('pvp:respawnPlayer', match.team1[i], team1Spawns[i])
        end
    end
    local team2Spawns = shouldSwap and arena.teamA or arena.teamB
    for i = 1, #match.team2 do
        if team2Spawns[i] and match.team2[i] > 0 and GetPlayerPing(match.team2[i]) > 0 then
            TriggerClientEvent('pvp:respawnPlayer', match.team2[i], team2Spawns[i])
        end
    end
end

function StartRound(matchId, match, arena)
    if not match or not arena then return end
    if match.status == MATCH_STATE.CANCELLED or match.status == MATCH_STATE.FINISHED then return end
    match.status = MATCH_STATE.PLAYING
    match.roundStats = {}
    match.deadPlayers = {}
    match.deathProcessed = {}
    SyncAllPlayersInMatch(matchId)
    for i = 1, #match.players do
        if match.players[i] > 0 and GetPlayerPing(match.players[i]) > 0 then
            TriggerClientEvent('pvp:roundStart', match.players[i], match.currentRound)
            TriggerClientEvent('pvp:updateScore', match.players[i], match.score, match.currentRound)
        end
    end
    DebugServer('[ROUND] Round %d démarré', match.currentRound)
end

function EndRound(matchId, match, roundWinner)
    if not match then return end
    if match.status == MATCH_STATE.ROUND_END or match.status == MATCH_STATE.FINISHING then return end
    match.status = MATCH_STATE.ROUND_END
    local arena = Config.Arenas[match.arena]
    if not arena then CancelMatch(matchId, 'Erreur arène') return end
    SyncAllPlayersInMatch(matchId)
    for i = 1, #match.players do
        local playerId = match.players[i]
        if playerId > 0 and GetPlayerPing(playerId) > 0 then
            local playerTeam = match.playerTeams[playerId]
            local isVictory = (roundWinner == playerTeam)
            TriggerClientEvent('pvp:roundEnd', playerId, roundWinner, match.score, playerTeam, isVictory)
            TriggerClientEvent('pvp:updateScore', playerId, match.score, match.currentRound)
        end
    end
    if match.score.team1 >= Config.MaxRounds or match.score.team2 >= Config.MaxRounds then
        EndMatch(matchId, match)
    else
        Wait(3000)
        if not GetMatchSafe(matchId) then return end
        match.currentRound = match.currentRound + 1
        match.deadPlayers = {}
        match.deathProcessed = {}
        match.roundStats = {}
        SyncAllPlayersInMatch(matchId)
        for i = 1, #match.players do
            if match.players[i] > 0 and GetPlayerPing(match.players[i]) > 0 then
                TriggerClientEvent('pvp:freezePlayer', match.players[i])
            end
        end
        Wait(500)
        RespawnPlayers(matchId, match, arena)
        Wait(2000)
        if not GetMatchSafe(matchId) then return end
        SyncAllPlayersInMatch(matchId)
        StartRound(matchId, match, arena)
    end
end

function EndMatch(matchId, match)
    if not match then return end
    match.status = MATCH_STATE.FINISHING
    local winningTeam = match.score.team1 > match.score.team2 and 'team1' or 'team2'
    local winners = winningTeam == 'team1' and match.team1 or match.team2
    local losers = winningTeam == 'team1' and match.team2 or match.team1
    if match.mode == '1v1' then
        exports['pvp_gunfight']:UpdatePlayerElo1v1ByMode(winners[1], losers[1], match.score, match.mode)
    else
        exports['pvp_gunfight']:UpdateTeamEloByMode(winners, losers, match.score, match.mode)
    end
    for i = 1, #winners do
        if winners[i] > 0 and GetPlayerPing(winners[i]) > 0 then
            TriggerClientEvent('pvp:matchEnd', winners[i], true, match.score, match.playerTeams[winners[i]])
            TriggerClientEvent('pvp:hideScoreHUD', winners[i])
            playerCurrentMatch[winners[i]] = nil
            playerLastHeartbeat[winners[i]] = nil
        end
    end
    for i = 1, #losers do
        if losers[i] > 0 and GetPlayerPing(losers[i]) > 0 then
            TriggerClientEvent('pvp:matchEnd', losers[i], false, match.score, match.playerTeams[losers[i]])
            TriggerClientEvent('pvp:hideScoreHUD', losers[i])
            playerCurrentMatch[losers[i]] = nil
            playerLastHeartbeat[losers[i]] = nil
        end
    end
    Wait(PERF.matchEndDelay)
    for i = 1, #match.players do ResetPlayerBucket(match.players[i]) end
    exports['pvp_gunfight']:RestoreGroupsAfterMatch(match.players, match.wasSoloMatch)
    for i = 1, #match.players do playerWasSoloBeforeMatch[match.players[i]] = nil end
    Wait(PERF.postMatchDelay)
    -- FIX: Verifier que les buckets sont bien a 0 avant teleportation
    for i = 1, #match.players do
        local pid = match.players[i]
        if pid > 0 and GetPlayerPing(pid) > 0 then
            local currentBucket = GetPlayerRoutingBucket(pid)
            if currentBucket ~= 0 then
                DebugWarn('[ENDMATCH] ATTENTION: Joueur %d toujours dans bucket %d, force reset', pid, currentBucket)
                SetPlayerRoutingBucket(pid, 0)
                Wait(200)
            end
        end
    end
    for i = 1, #match.players do
        if match.players[i] > 0 and GetPlayerPing(match.players[i]) > 0 then
            TeleportToExitPoint(match.players[i])
        end
    end
    Wait(500)
    RewardWinners(winners)
    match.status = MATCH_STATE.FINISHED
    activeMatches[matchId] = nil
end

function HandlePlayerDisconnect(playerId)
    DebugServer('[DISCONNECT] Joueur %d deconnecte - Traitement...', playerId)

    -- Nettoyer les donnees du joueur deconnecte
    playerWasSoloBeforeMatch[playerId] = nil
    playerLastHeartbeat[playerId] = nil

    local matchId = playerCurrentMatch[playerId]

    -- FIX: Vérifier si le match existe (même s'il est en ROUND_END)
    if not matchId then
        ResetPlayerBucket(playerId)
        return
    end

    local match = activeMatches[matchId]
    if not match then
        ResetPlayerBucket(playerId)
        playerCurrentMatch[playerId] = nil
        return
    end

    -- FIX: Vérifier si le match est déjà terminé OU en cours de terminaison
    if match.status == MATCH_STATE.CANCELLED or match.status == MATCH_STATE.FINISHED then
        ResetPlayerBucket(playerId)
        playerCurrentMatch[playerId] = nil
        return
    end

    -- FIX: Éviter les terminaisons concurrentes (condition de course)
    if matchBeingTerminated[matchId] then
        DebugServer('[DISCONNECT] Match %d deja en cours de terminaison, skip joueur %d', matchId, playerId)
        ResetPlayerBucket(playerId)
        playerCurrentMatch[playerId] = nil
        return
    end

    -- FIX: Marquer le match comme en cours de terminaison IMMÉDIATEMENT
    matchBeingTerminated[matchId] = true
    match.status = MATCH_STATE.FINISHING -- Empêcher CheckRoundEnd de tourner

    local quitterTeam = match.playerTeams[playerId]
    if not quitterTeam then
        ResetPlayerBucket(playerId)
        playerCurrentMatch[playerId] = nil
        matchBeingTerminated[matchId] = nil
        return
    end

    DebugServer('[DISCONNECT] Joueur %d equipe %s - Terminaison match %d', playerId, quitterTeam, matchId)

    -- FIX: Retirer le joueur de son équipe IMMÉDIATEMENT
    local teamArray = quitterTeam == 'team1' and match.team1 or match.team2
    for i = #teamArray, 1, -1 do
        if teamArray[i] == playerId then
            table.remove(teamArray, i)
            DebugServer('[DISCONNECT] Joueur %d retire de %s', playerId, quitterTeam)
            break
        end
    end

    -- FIX: Retirer de la liste des joueurs aussi
    for i = #match.players, 1, -1 do
        if match.players[i] == playerId then
            table.remove(match.players, i)
            break
        end
    end

    -- Marquer comme mort pour éviter les problèmes
    match.deadPlayers[playerId] = true

    -- Calculer equipe gagnante
    local winningTeam = quitterTeam == 'team1' and 'team2' or 'team1'
    local winners = winningTeam == 'team1' and match.team1 or match.team2
    local losers = winningTeam == 'team1' and match.team2 or match.team1
    local forfeitScore = {team1 = winningTeam == 'team1' and Config.MaxRounds or 0, team2 = winningTeam == 'team2' and Config.MaxRounds or 0}

    -- Mise a jour ELO (utiliser les listes AVANT suppression pour l'ELO)
    if match.mode == '1v1' then
        if #winners > 0 then
            -- En 1v1, le perdant est le joueur qui a quitté
            exports['pvp_gunfight']:UpdatePlayerElo1v1ByMode(winners[1], playerId, forfeitScore, match.mode)
        end
    else
        -- En mode équipe, tous les joueurs de l'équipe perdante perdent (y compris celui qui a quitté)
        local allLosers = {}
        for i = 1, #losers do
            allLosers[#allLosers + 1] = losers[i]
        end
        allLosers[#allLosers + 1] = playerId -- Ajouter le joueur qui a quitté
        exports['pvp_gunfight']:UpdateTeamEloByMode(winners, allLosers, forfeitScore, match.mode)
    end

    -- FIX: Collecter les joueurs restants AVANT de modifier les etats
    local remainingPlayers = {}
    local remainingWinners = {}
    for i = 1, #match.players do
        local pid = match.players[i]
        if pid > 0 and pid ~= playerId then
            local pingOk = GetPlayerPing(pid) > 0
            if pingOk then
                remainingPlayers[#remainingPlayers + 1] = pid
                local playerTeam = match.playerTeams[pid]
                if playerTeam == winningTeam then
                    remainingWinners[#remainingWinners + 1] = pid
                end
            end
        end
    end

    DebugServer('[DISCONNECT] %d joueurs restants a traiter', #remainingPlayers)

    -- FIX: D'abord envoyer les notifications et forcer le nettoyage client
    for i = 1, #remainingPlayers do
        local pid = remainingPlayers[i]
        local playerTeam = match.playerTeams[pid]
        local isWinner = (playerTeam == winningTeam)

        -- FIX 1: Envoyer forceCleanup EN PREMIER pour preparer le client
        TriggerClientEvent('pvp:forceCleanup', pid)

        if isWinner then
            TriggerClientEvent('brutal_notify:SendAlert', pid, 'Victoire', 'VICTOIRE par abandon!', 5000, 'success')
        else
            TriggerClientEvent('brutal_notify:SendAlert', pid, 'Defaite', 'DEFAITE - Coequipier quitte!', 5000, 'error')
        end

        TriggerClientEvent('pvp:matchEnd', pid, isWinner, forfeitScore, playerTeam)
        TriggerClientEvent('pvp:hideScoreHUD', pid)
        TriggerClientEvent('pvp:disableZones', pid)
        TriggerClientEvent('pvp:disableTeammateHUD', pid)
        TriggerClientEvent('pvp:stopSpectating', pid) -- FIX: Arrêter le spectate aussi

        playerCurrentMatch[pid] = nil
        playerLastHeartbeat[pid] = nil
        playerWasSoloBeforeMatch[pid] = nil
    end

    -- FIX 2: Attendre que les clients aient traite le nettoyage
    Wait(1500)

    -- FIX 3: Reset bucket APRES le nettoyage client
    DebugServer('[DISCONNECT] Reset des buckets pour %d joueurs restants', #remainingPlayers)
    for i = 1, #remainingPlayers do
        local pid = remainingPlayers[i]
        if GetPlayerPing(pid) > 0 then
            ResetPlayerBucket(pid)
        end
    end
    ResetPlayerBucket(playerId)

    -- FIX: Attendre plus longtemps pour synchronisation bucket complete
    Wait(1000)

    -- FIX 4: Verifier que les buckets sont bien a 0 avant teleportation
    for i = 1, #remainingPlayers do
        local pid = remainingPlayers[i]
        if GetPlayerPing(pid) > 0 then
            local currentBucket = GetPlayerRoutingBucket(pid)
            if currentBucket ~= 0 then
                DebugWarn('[DISCONNECT] ATTENTION: Joueur %d toujours dans bucket %d, force reset', pid, currentBucket)
                SetPlayerRoutingBucket(pid, 0)
                Wait(200)
            end
        end
    end

    -- FIX 5: Teleporter APRES le reset bucket verifie
    if #remainingPlayers > 0 then
        exports['pvp_gunfight']:RestoreGroupsAfterMatch(remainingPlayers, match.wasSoloMatch)

        for i = 1, #remainingPlayers do
            local pid = remainingPlayers[i]
            if GetPlayerPing(pid) > 0 then
                TeleportToExitPoint(pid)
            end
        end

        Wait(1000)

        if #remainingWinners > 0 then
            RewardWinners(remainingWinners)
        end
    end

    match.status = MATCH_STATE.FINISHED
    activeMatches[matchId] = nil
    matchBeingTerminated[matchId] = nil -- FIX: Nettoyer le flag
    playerCurrentMatch[playerId] = nil

    DebugServer('[DISCONNECT] Traitement termine pour joueur %d - Match %d supprime', playerId, matchId)
end

-- ========================================
-- MATCHMAKING
-- ========================================
RegisterNetEvent('pvp:joinQueue', function(mode)
    local src = source
    if IsRateLimited(src, 'joinQueue') then
        TriggerClientEvent('brutal_notify:SendAlert', src, 'PVP', 'Patientez...', 2000, 'warning')
        return
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if playersInQueue[src] then
        TriggerClientEvent('brutal_notify:SendAlert', src, 'File', 'Déjà en file!', 3000, 'error')
        return
    end
    playerLastHeartbeat[src] = GetGameTimer()
    local group = exports['pvp_gunfight']:GetPlayerGroup(src)
    local playersToQueue = {}
    local isSoloQueue = false
    if group then
        if group.leaderId ~= src then
            TriggerClientEvent('brutal_notify:SendAlert', src, 'Groupe', 'Seul le leader!', 3000, 'error')
            return
        end
        local playersNeededPerTeam = tonumber(mode:sub(1, 1))
        if #group.members ~= playersNeededPerTeam then
            TriggerClientEvent('brutal_notify:SendAlert', src, 'Groupe', string.format('Il faut %d joueur(s)!', playersNeededPerTeam), 4000, 'error')
            return
        end
        local allReady = true
        for memberId, isReady in pairs(group.ready) do
            if not isReady then allReady = false break end
        end
        if not allReady then
            TriggerClientEvent('brutal_notify:SendAlert', src, 'Groupe', 'Tous prêts!', 3000, 'warning')
            return
        end
        for i = 1, #group.members do
            playersToQueue[#playersToQueue + 1] = group.members[i]
            playerLastHeartbeat[group.members[i]] = GetGameTimer()
        end
        isSoloQueue = false
    else
        if mode ~= '1v1' then
            TriggerClientEvent('brutal_notify:SendAlert', src, 'Groupe', 'Créez groupe pour 2v2+!', 4000, 'error')
            return
        end
        playersToQueue[1] = src
        isSoloQueue = true
    end
    for i = 1, #playersToQueue do
        local playerId = playersToQueue[i]
        queues[mode][#queues[mode] + 1] = playerId
        playersInQueue[playerId] = {mode = mode, startTime = os.time(), groupMembers = playersToQueue, isSolo = isSoloQueue}
        TriggerClientEvent('pvp:searchStarted', playerId, mode)
        TriggerClientEvent('brutal_notify:SendAlert', playerId, 'Recherche', 'Recherche ' .. mode, 3000, 'info')
        local stats = GetQueueStats()
        TriggerClientEvent('pvp:updateQueueStats', playerId, stats)
    end
    BroadcastQueueStatsIfChanged()
    CheckAndCreateMatch(mode)
end)

function CheckAndCreateMatch(mode)
    local playersNeeded = tonumber(mode:sub(1, 1)) * 2
    if #queues[mode] >= playersNeeded then
        local matchPlayers = {}
        for i = 1, playersNeeded do matchPlayers[i] = table.remove(queues[mode], 1) end
        BroadcastQueueStatsIfChanged()
        CreateMatch(mode, matchPlayers)
    end
end

function CreateMatch(mode, players)
    for i = 1, #players do
        if GetPlayerPing(players[i]) <= 0 then
            for j = 1, #players do
                if j ~= i and GetPlayerPing(players[j]) > 0 then queues[mode][#queues[mode] + 1] = players[j] end
            end
            BroadcastQueueStatsIfChanged()
            return
        end
    end
    local matchId = #activeMatches + 1
    local bucketId = CreateMatchBucket()
    local arenaKey, arena = GetRandomArena(mode)  -- FIX: Passer le mode pour filtrer les arenes
    if not arena then
        for i = 1, #players do
            if GetPlayerPing(players[i]) > 0 then
                queues[mode][#queues[mode] + 1] = players[i]
                playersInQueue[players[i]] = nil
            end
        end
        BroadcastQueueStatsIfChanged()
        return
    end
    DebugServer('===== MATCH %d =====', matchId)
    DebugServer('Mode: %s | Arène: %s', mode, arena.name)
    local allWereSolo = true
    for i = 1, #players do
        local playerId = players[i]
        if playersInQueue[playerId] and not playersInQueue[playerId].isSolo then allWereSolo = false break end
    end
    activeMatches[matchId] = {
        mode = mode,
        players = players,
        arena = arenaKey,
        bucketId = bucketId,
        team1 = {},
        team2 = {},
        playerTeams = {},
        score = {team1 = 0, team2 = 0},
        currentRound = 1,
        status = MATCH_STATE.CREATING,
        startTime = os.time(),
        deadPlayers = {},
        deathProcessed = {},
        roundStats = {},
        wasSoloMatch = allWereSolo
    }
    local halfSize = #players / 2
    for i = 1, #players do
        local playerId = players[i]
        if GetPlayerPing(playerId) <= 0 then
            CancelMatch(matchId, 'Joueur déconnecté')
            return
        end
        local team = i <= halfSize and 'team1' or 'team2'
        if team == 'team1' then
            activeMatches[matchId].team1[#activeMatches[matchId].team1 + 1] = playerId
        else
            activeMatches[matchId].team2[#activeMatches[matchId].team2 + 1] = playerId
        end
        activeMatches[matchId].playerTeams[playerId] = team
        if playersInQueue[playerId] then playerWasSoloBeforeMatch[playerId] = playersInQueue[playerId].isSolo end
        playersInQueue[playerId] = nil
        playerCurrentMatch[playerId] = matchId
        playerLastHeartbeat[playerId] = GetGameTimer()
    end
    if not GetMatchSafe(matchId) then return end
    for i = 1, #players do SetPlayerBucket(players[i], bucketId) end
    Wait(200)
    if not GetMatchSafe(matchId) then return end
    SyncAllPlayersInMatch(matchId)
    for i = 1, #players do
        if GetPlayerPing(players[i]) > 0 then
            TriggerClientEvent('pvp:matchFound', players[i])
            TriggerClientEvent('brutal_notify:SendAlert', players[i], 'Match', 'Arène: ' .. arena.name, 4000, 'success')
            TriggerClientEvent('pvp:showScoreHUD', players[i], activeMatches[matchId].score, 1)
        end
    end
    TeleportPlayersToArena(matchId, activeMatches[matchId], arena, arenaKey)
    Wait(3000)
    if not GetMatchSafe(matchId) then return end
    SyncAllPlayersInMatch(matchId)
    for i = 1, #players do
        if players[i] > 0 and GetPlayerPing(players[i]) > 0 then TriggerClientEvent('pvp:freezePlayer', players[i]) end
    end
    Wait(1000)
    local match = GetMatchSafe(matchId)
    if match then
        match.status = MATCH_STATE.STARTING
        StartRound(matchId, match, arena)
    end
end

RegisterNetEvent('pvp:cancelSearch', function()
    local src = source
    if IsRateLimited(src, 'cancelSearch') then return end
    if not playersInQueue[src] then return end
    local queueData = playersInQueue[src]
    local mode = queueData.mode
    local groupMembers = queueData.groupMembers or {src}
    local isSolo = queueData.isSolo
    if not isSolo and #groupMembers > 1 then
        local group = exports['pvp_gunfight']:GetPlayerGroup(src)
        if group and group.leaderId == src then
            CancelGroupSearch(groupMembers, mode, 'Annulé par leader')
        else
            TriggerClientEvent('brutal_notify:SendAlert', src, 'Groupe', 'Seul le leader!', 3000, 'error')
        end
    else
        for j = #queues[mode], 1, -1 do
            if queues[mode][j] == src then table.remove(queues[mode], j) break end
        end
        playersInQueue[src] = nil
        playerLastHeartbeat[src] = nil
        TriggerClientEvent('pvp:searchCancelled', src)
        TriggerClientEvent('brutal_notify:SendAlert', src, 'Recherche', 'Annulée', 2000, 'warning')
        BroadcastQueueStatsIfChanged()
    end
end)

-- ========================================
-- EVENTS MORT
-- ========================================
RegisterNetEvent('pvp:playerDiedWithKiller', function(killerId, weaponHash, isHeadshot)
    local victimId = source
    local matchId = playerCurrentMatch[victimId]
    if not IsMatchValid(matchId) then return end
    local match = GetMatchSafe(matchId)
    if not match then return end
    DebugServer('[EVENT] playerDiedWithKiller - V:%d K:%s M:%d R:%d', victimId, tostring(killerId), matchId, match.currentRound or 0)
    local finalKillerId = killerId
    local finalWeaponHash = weaponHash
    local finalIsHeadshot = isHeadshot
    if not finalKillerId or finalKillerId <= 0 then
        local antitankKiller, antitankWeapon, antitankHeadshot = exports['pvp_gunfight']:GetAntitankKiller(victimId)
        if antitankKiller and antitankKiller > 0 then
            -- ✅ PATCH LIGNE 960: Conversion sécurisée
            local safeAntitankKiller = tonumber(antitankKiller)
            if safeAntitankKiller and safeAntitankKiller > 0 then
                finalKillerId = safeAntitankKiller
                finalWeaponHash = antitankWeapon or finalWeaponHash
                finalIsHeadshot = antitankHeadshot or finalIsHeadshot
                DebugServer('[EVENT] Killer via antitank: %d', finalKillerId)
            end
        end
    end
    if MarkPlayerDead(matchId, match, victimId, finalKillerId, finalWeaponHash, finalIsHeadshot) then
        CheckRoundEnd(matchId, match)
    end
end)

RegisterNetEvent('pvp:playerDied', function(killerId)
    local victimId = source
    local matchId = playerCurrentMatch[victimId]
    if not IsMatchValid(matchId) then return end
    local match = GetMatchSafe(matchId)
    if not match then return end
    if not match.currentRound or type(match.currentRound) ~= 'number' then match.currentRound = 1 end
    local deathKey = tostring(victimId) .. '_' .. tostring(match.currentRound)
    if match.deathProcessed[deathKey] then return end
    DebugServer('[EVENT-LEGACY] playerDied - V:%d K:%s', victimId, tostring(killerId))
    local finalKillerId = killerId
    if not finalKillerId or finalKillerId <= 0 then
        local antitankKiller = exports['pvp_gunfight']:GetAntitankKiller(victimId)
        if antitankKiller and antitankKiller > 0 then finalKillerId = antitankKiller end
    end
    if MarkPlayerDead(matchId, match, victimId, finalKillerId, nil, false) then CheckRoundEnd(matchId, match) end
end)

RegisterNetEvent('pvp:playerDiedOutsideZone', function()
    local victimId = source
    if IsRateLimited(victimId, 'playerDiedOutsideZone') then return end
    local matchId = playerCurrentMatch[victimId]
    if not IsMatchValid(matchId) then return end
    local match = GetMatchSafe(matchId)
    if not match then return end
    if not match.currentRound or type(match.currentRound) ~= 'number' then match.currentRound = 1 end
    local deathKey = tostring(victimId) .. '_' .. tostring(match.currentRound)
    if match.deathProcessed[deathKey] then return end
    if MarkPlayerDead(matchId, match, victimId, nil, nil, false) then CheckRoundEnd(matchId, match) end
end)

RegisterNetEvent('pvp:requestTeammateRefresh', function()
    local src = source
    local matchId = playerCurrentMatch[src]
    if not IsMatchValid(matchId) then return end
    local teammates = GetTeammatesForPlayer(matchId, src)
    TriggerClientEvent('pvp:setTeammates', src, teammates)
end)

-- ========================================
-- CALLBACKS
-- ========================================
ESX.RegisterServerCallback('pvp:getPlayerStats', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(nil) return end
    MySQL.single('SELECT * FROM pvp_stats WHERE identifier = ?', {xPlayer.identifier}, function(result)
        if result then
            result.name = result.name or xPlayer.getName()
            result.kills = result.kills or 0
            result.deaths = result.deaths or 0
            if Config.Discord and Config.Discord.enabled then
                exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(source, function(avatarUrl)
                    result.avatar = avatarUrl
                    cb(result)
                end)
            else
                result.avatar = Config.Discord.defaultAvatar
                cb(result)
            end
        else
            MySQL.insert('INSERT INTO pvp_stats (identifier, name, kills, deaths) VALUES (?, ?, 0, 0)', 
                {xPlayer.identifier, xPlayer.getName()}, function()
                exports['pvp_gunfight']:InitPlayerModeStats(xPlayer.identifier, xPlayer.getName())
                if Config.Discord and Config.Discord.enabled then
                    exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(source, function(avatarUrl)
                        cb({identifier = xPlayer.identifier, name = xPlayer.getName(), elo = Config.StartingELO, kills = 0, deaths = 0, matches_played = 0, wins = 0, losses = 0, avatar = avatarUrl})
                    end)
                else
                    cb({identifier = xPlayer.identifier, name = xPlayer.getName(), elo = Config.StartingELO, kills = 0, deaths = 0, matches_played = 0, wins = 0, losses = 0, avatar = Config.Discord.defaultAvatar})
                end
            end)
        end
    end)
end)

ESX.RegisterServerCallback('pvp:getPlayerStatsByMode', function(source, cb, mode)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(nil) return end
    exports['pvp_gunfight']:GetPlayerStatsByMode(xPlayer.identifier, mode, function(stats)
        if stats then
            stats.name = xPlayer.getName()
            if Config.Discord and Config.Discord.enabled then
                exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(source, function(avatarUrl)
                    stats.avatar = avatarUrl
                    cb(stats)
                end)
            else
                stats.avatar = Config.Discord.defaultAvatar
                cb(stats)
            end
        else
            cb(nil)
        end
    end)
end)

ESX.RegisterServerCallback('pvp:getPlayerAllModeStats', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(nil) return end
    exports['pvp_gunfight']:GetPlayerAllModeStats(xPlayer.identifier, function(statsByMode)
        if Config.Discord and Config.Discord.enabled then
            exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(source, function(avatarUrl)
                cb({name = xPlayer.getName(), avatar = avatarUrl, modes = statsByMode})
            end)
        else
            cb({name = xPlayer.getName(), avatar = Config.Discord.defaultAvatar, modes = statsByMode})
        end
    end)
end)

ESX.RegisterServerCallback('pvp:getLeaderboard', function(source, cb)
    MySQL.query('SELECT * FROM pvp_stats ORDER BY elo DESC LIMIT 20', {}, function(results)
        for i = 1, #results do
            results[i].kills = results[i].kills or 0
            results[i].deaths = results[i].deaths or 0
            results[i].name = results[i].name or ('Joueur ' .. i)
            results[i].avatar = results[i].discord_avatar or Config.Discord.defaultAvatar
        end
        cb(results)
    end)
end)

ESX.RegisterServerCallback('pvp:getLeaderboardByMode', function(source, cb, mode)
    exports['pvp_gunfight']:GetLeaderboardByMode(mode, 20, function(results)
        cb(results)
    end)
end)

ESX.RegisterServerCallback('pvp:getQueueStats', function(source, cb)
    cb(GetQueueStats())
end)

-- ========================================
-- COMMANDES ADMIN
-- ========================================
local function ForcePlayerToLobby(playerId)
    if not playerId or playerId <= 0 or GetPlayerPing(playerId) <= 0 then return false end
    ForceCleanupClientState(playerId)
    Wait(300)
    ResetPlayerBucket(playerId)
    playerWasSoloBeforeMatch[playerId] = nil
    playerLastHeartbeat[playerId] = nil
    local matchId = playerCurrentMatch[playerId]
    if matchId then playerCurrentMatch[playerId] = nil end
    if playersInQueue[playerId] then
        local queueData = playersInQueue[playerId]
        for i = #queues[queueData.mode], 1, -1 do
            if queues[queueData.mode][i] == playerId then table.remove(queues[queueData.mode], i) break end
        end
        playersInQueue[playerId] = nil
        TriggerClientEvent('pvp:searchCancelled', playerId)
        BroadcastQueueStatsIfChanged()
    end
    Wait(200)
    TeleportToExitPoint(playerId)
    return true
end

RegisterCommand('pvpforcelobby', function(source, args)
    if not exports['pvp_gunfight']:IsPlayerAdmin(source) then
        if source > 0 then
            TriggerClientEvent('brutal_notify:SendAlert', source, 'Permission', 'Refusée', 3000, 'error')
        end
        return
    end
    local targetId = tonumber(args[1])
    if not targetId then
        if source > 0 then
            TriggerClientEvent('brutal_notify:SendAlert', source, 'Commande', 'Usage: /pvpforcelobby [id]', 4000, 'warning')
        end
        return
    end
    if ForcePlayerToLobby(targetId) then
        local msg = 'Joueur ' .. targetId .. ' forcé au lobby'
        if source > 0 then
            TriggerClientEvent('brutal_notify:SendAlert', source, 'Admin', msg, 3000, 'success')
        else
            print('[PVP] ' .. msg)
        end
    end
end, false)

RegisterCommand('pvpkickall', function(source)
    if not exports['pvp_gunfight']:IsPlayerAdmin(source) then
        if source > 0 then
            TriggerClientEvent('brutal_notify:SendAlert', source, 'Permission', 'Refusée', 3000, 'error')
        end
        return
    end
    local kickedCount = 0
    for _, match in pairs(activeMatches) do
        for i = 1, #match.players do
            if match.players[i] > 0 and GetPlayerPing(match.players[i]) > 0 then
                ForcePlayerToLobby(match.players[i])
                kickedCount = kickedCount + 1
                Wait(100)
            end
        end
    end
    activeMatches = {}
    for mode, queue in pairs(queues) do
        for i = 1, #queue do
            if queue[i] > 0 and GetPlayerPing(queue[i]) > 0 then
                ForceCleanupClientState(queue[i])
                TriggerClientEvent('pvp:searchCancelled', queue[i])
                kickedCount = kickedCount + 1
            end
        end
        queues[mode] = {}
    end
    playersInQueue = {}
    playerCurrentMatch = {}
    playerWasSoloBeforeMatch = {}
    playerLastHeartbeat = {}
    BroadcastQueueStatsIfChanged()
    local msg = kickedCount .. ' joueurs forcés au lobby'
    if source > 0 then
        TriggerClientEvent('brutal_notify:SendAlert', source, 'Admin', msg, 4000, 'success')
    else
        print('[PVP] ' .. msg)
    end
end, false)

RegisterCommand('pvpstatus', function(source)
    if not exports['pvp_gunfight']:IsPlayerAdmin(source) then
        if source > 0 then
            TriggerClientEvent('brutal_notify:SendAlert', source, 'Permission', 'Refusée', 3000, 'error')
        end
        return
    end
    local matchCount = 0
    local playersInMatchCount = 0
    for _, match in pairs(activeMatches) do
        matchCount = matchCount + 1
        playersInMatchCount = playersInMatchCount + #match.players
    end
    local totalInQueue = 0
    for _, queue in pairs(queues) do totalInQueue = totalInQueue + #queue end
    local msg = string.format('Matchs:%d | En jeu:%d | Queue:%d', matchCount, playersInMatchCount, totalInQueue)
    if source > 0 then
        TriggerClientEvent('brutal_notify:SendAlert', source, 'Statut PVP', msg, 5000, 'info')
    else
        print('[PVP] ' .. msg)
    end
end, false)

-- ========================================
-- EVENTS
-- ========================================
AddEventHandler('playerDropped', function()
    local src = source
    HandlePlayerDisconnectFromQueue(src)
    HandlePlayerDisconnect(src)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for matchId, match in pairs(activeMatches) do
        for i = 1, #match.players do
            local playerId = match.players[i]
            if playerId > 0 and GetPlayerPing(playerId) > 0 then
                TriggerClientEvent('pvp:hideScoreHUD', playerId)
                TriggerClientEvent('pvp:disableZones', playerId)
                TriggerClientEvent('pvp:onResourceStop', playerId)
                ResetPlayerBucket(playerId)
                playerWasSoloBeforeMatch[playerId] = nil
                playerLastHeartbeat[playerId] = nil
            end
        end
    end
    for mode, queue in pairs(queues) do
        for i = 1, #queue do
            if queue[i] > 0 and GetPlayerPing(queue[i]) > 0 then
                TriggerClientEvent('pvp:searchCancelled', queue[i])
                playerLastHeartbeat[queue[i]] = nil
            end
        end
        queues[mode] = {}
    end
end)

-- ========================================
-- EXPORTS
-- ========================================
exports('GetPlayerCurrentMatch', function(playerId)
    return playerCurrentMatch[playerId]
end)

exports('GetPlayerTeamInMatch', function(playerId, matchId)
    local match = activeMatches[matchId]
    if not match then return nil end
    return match.playerTeams[playerId]
end)

exports('HandlePlayerDisconnectFromQueue', HandlePlayerDisconnectFromQueue)

DebugSuccess('Systeme PVP chargé (VERSION 5.3.1 - FIX ROUTING BUCKET)')
DebugSuccess('✅ ResetPlayerBucket avec Wait(100) synchronisation')
DebugSuccess('✅ Verification bucket = 0 avant teleportation')
DebugSuccess('✅ HandlePlayerDisconnect corrigé')
DebugSuccess('✅ EndMatch corrigé')
DebugSuccess('✅ Joueurs ne restent plus dans instance après déconnexion')