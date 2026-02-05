-- ========================================
-- PVP GUNFIGHT - ANTITANK BRIDGE SERVER
-- Version 2.0.1 - FIX CRITIQUE TYPE CONVERSION
-- ========================================
-- ✅ FIX: Conversion sécurisée des IDs (ligne 209 patch)
-- ✅ FIX: Validation stricte avant comparaison
-- ✅ NOUVEAU: Protection against string/number mix
-- ========================================

DebugServer('Module Antitank Bridge Server chargé (v2.0.1 - FIX TYPE CONVERSION)')

-- ========================================
-- CACHE DES KILLS DÉTECTÉS PAR ANTITANK
-- ========================================
local KillCache = {}

-- ✅ FIX: Cache étendu à 10s
local CACHE_DURATION = 10000

-- ✅ NOUVEAU: Tracking des morts en attente
local PendingDeaths = {}
local PENDING_DEATH_TIMEOUT = 3000

-- ========================================
-- ✅ NOUVEAU: UTILITAIRE CONVERSION SÉCURISÉE
-- ========================================
local function SafeToNumber(value, default)
    local num = tonumber(value)
    if not num then
        DebugServer('[ANTITANK-SERVER] ⚠️ SafeToNumber: %s -> défaut: %s', 
            tostring(value), tostring(default or 0))
        return default or 0
    end
    return num
end

-- ========================================
-- FONCTION: Enregistrer un kill dans le cache
-- ========================================
local function RegisterKill(victimId, killerId, weaponHash, isHeadshot, isMelee, distance)
    local now = GetGameTimer()
    
    -- ✅ PATCH: Conversion sécurisée
    local safeVictimId = SafeToNumber(victimId)
    local safeKillerId = SafeToNumber(killerId, -1)
    
    if safeVictimId == 0 then
        DebugServer('[ANTITANK-SERVER] ❌ RegisterKill: VictimId invalide: %s', tostring(victimId))
        return
    end
    
    KillCache[safeVictimId] = {
        killerId = safeKillerId,
        weaponHash = weaponHash,
        isHeadshot = isHeadshot or false,
        isMelee = isMelee or false,
        distance = distance or 0,
        timestamp = now
    }
    
    DebugServer('[ANTITANK-SERVER] ✅ Kill enregistré: Victime=%d, Killer=%d, Weapon=%s, Headshot=%s',
        safeVictimId, safeKillerId, tostring(weaponHash), tostring(isHeadshot))
end

-- ========================================
-- FONCTION: Récupérer le killer d'une victime
-- ========================================
function GetAntitankKiller(victimId)
    local now = GetGameTimer()
    
    -- ✅ PATCH: Conversion sécurisée
    local safeVictimId = SafeToNumber(victimId)
    
    if safeVictimId == 0 then
        DebugServer('[ANTITANK-SERVER] ⚠️ GetAntitankKiller: VictimId invalide: %s', tostring(victimId))
        return nil, nil, false
    end
    
    local cached = KillCache[safeVictimId]
    
    if not cached then
        DebugServer('[ANTITANK-SERVER] ⚠️ Pas de cache pour victime %d', safeVictimId)
        return nil, nil, false
    end
    
    -- Vérifier si le cache est encore valide
    if (now - cached.timestamp) > CACHE_DURATION then
        DebugServer('[ANTITANK-SERVER] ⚠️ Cache expiré pour victime %d (age: %dms)', safeVictimId, now - cached.timestamp)
        KillCache[safeVictimId] = nil
        return nil, nil, false
    end
    
    DebugServer('[ANTITANK-SERVER] ✅ Killer trouvé en cache: Victime=%d, Killer=%d (age: %dms)', 
        safeVictimId, cached.killerId, now - cached.timestamp)
    
    return cached.killerId, cached.weaponHash, cached.isHeadshot
end

-- ========================================
-- FONCTION: Récupérer toutes les données du kill
-- ========================================
function GetAntitankKillData(victimId)
    local now = GetGameTimer()
    
    -- ✅ PATCH: Conversion sécurisée
    local safeVictimId = SafeToNumber(victimId)
    
    if safeVictimId == 0 then
        return nil
    end
    
    local cached = KillCache[safeVictimId]
    
    if not cached then
        return nil
    end
    
    if (now - cached.timestamp) > CACHE_DURATION then
        KillCache[safeVictimId] = nil
        return nil
    end
    
    return cached
end

-- ========================================
-- FONCTION: Nettoyer le cache d'une victime
-- ========================================
function ClearAntitankKillCache(victimId)
    if victimId then
        local safeId = SafeToNumber(victimId)
        if safeId > 0 then
            KillCache[safeId] = nil
            PendingDeaths[safeId] = nil
            DebugServer('[ANTITANK-SERVER] 🧹 Cache nettoyé pour victime %d', safeId)
        end
    else
        KillCache = {}
        PendingDeaths = {}
        DebugServer('[ANTITANK-SERVER] 🧹 Tout le cache nettoyé')
    end
end

-- ========================================
-- ✅ NOUVEAU: Marquer une mort en attente
-- ========================================
local function MarkPendingDeath(victimId, killerId)
    local now = GetGameTimer()
    
    -- ✅ PATCH: Conversion sécurisée
    local safeVictimId = SafeToNumber(victimId)
    local safeKillerId = SafeToNumber(killerId, -1)
    
    if safeVictimId == 0 then
        DebugServer('[ANTITANK-SERVER] ❌ MarkPendingDeath: VictimId invalide: %s', tostring(victimId))
        return
    end
    
    PendingDeaths[safeVictimId] = {
        killerId = safeKillerId,
        timestamp = now
    }
    
    DebugServer('[ANTITANK-SERVER] ⏳ Mort en attente: Victime=%d, Killer=%d', safeVictimId, safeKillerId)
end

-- ========================================
-- EVENT SERVER: fanca_antitank:killed
-- Déclenché APRÈS qu'un joueur a été tué
-- ========================================
AddEventHandler('fanca_antitank:killed', function(targetId, targetPed, playerId, playerPed, killDistance, killerData)
    -- ✅ PATCH: Conversion sécurisée des IDs
    local safeTargetId = SafeToNumber(targetId)
    local safePlayerId = SafeToNumber(playerId, -1)
    
    if safeTargetId == 0 then
        DebugServer('[ANTITANK-SERVER] ❌ fanca_antitank:killed: targetId invalide: %s', tostring(targetId))
        return
    end
    
    -- Vérifier que c'est un kill PVP
    local victimMatchId = exports['pvp_gunfight']:GetPlayerCurrentMatch(safeTargetId)
    local killerMatchId = (safePlayerId > 0) and exports['pvp_gunfight']:GetPlayerCurrentMatch(safePlayerId) or nil
    
    -- Si la victime n'est pas en match PVP, ignorer
    if not victimMatchId then
        return
    end
    
    DebugServer('[ANTITANK-SERVER] 💀 Kill détecté: Victime=%d, Killer=%s, Distance=%.2f, Match=%s',
        safeTargetId, tostring(safePlayerId), killDistance or 0, tostring(victimMatchId))
    
    if killerData then
        DebugServer('[ANTITANK-SERVER] 💀 KillerData: Weapon=%s, Headshot=%s, Melee=%s',
            tostring(killerData.weaponHash), tostring(killerData.isHeadshot), tostring(killerData.isMelee))
    end
    
    -- Enregistrer dans le cache
    RegisterKill(
        safeTargetId,
        safePlayerId,
        killerData and killerData.weaponHash or nil,
        killerData and killerData.isHeadshot or false,
        killerData and killerData.isMelee or false,
        killDistance
    )
    
    -- Marquer comme mort en attente
    MarkPendingDeath(safeTargetId, safePlayerId)
    
    -- Déclencher event interne
    TriggerEvent('pvp:antitankKillConfirmed', safeTargetId, safePlayerId, killerData)
end)

-- ========================================
-- EVENT SERVER: fanca_antitank:kill (avant le kill)
-- ========================================
AddEventHandler('fanca_antitank:kill', function(targetId, playerId)
    -- ✅ PATCH: Conversion sécurisée
    local safeTargetId = SafeToNumber(targetId)
    local safePlayerId = SafeToNumber(playerId, -1)
    
    if safeTargetId == 0 then
        return
    end
    
    local victimMatchId = exports['pvp_gunfight']:GetPlayerCurrentMatch(safeTargetId)
    local killerMatchId = (safePlayerId > 0) and exports['pvp_gunfight']:GetPlayerCurrentMatch(safePlayerId) or nil
    
    if not victimMatchId then
        return
    end
    
    DebugServer('[ANTITANK-SERVER] ⚔️ Kill imminent: Victime=%d, Killer=%s', safeTargetId, tostring(safePlayerId))
    
    if victimMatchId and killerMatchId and victimMatchId == killerMatchId then
        local victimTeam = exports['pvp_gunfight']:GetPlayerTeamInMatch(safeTargetId, victimMatchId)
        local killerTeam = exports['pvp_gunfight']:GetPlayerTeamInMatch(safePlayerId, killerMatchId)
        
        if victimTeam and killerTeam and victimTeam == killerTeam then
            DebugServer('[ANTITANK-SERVER] 🛡️ Friendly fire détecté - Victime=%d, Killer=%d', safeTargetId, safePlayerId)
        end
    end
end)

-- ========================================
-- ✅ NOUVEAU: THREAD VÉRIFICATION MORTS EN ATTENTE
-- ✅ PATCH LIGNE 209 - CONVERSION SÉCURISÉE ICI
-- ========================================
CreateThread(function()
    DebugServer('[ANTITANK-SERVER] Thread vérification morts en attente démarré')
    
    while true do
        Wait(1000)
        
        local now = GetGameTimer()
        local processedDeaths = 0
        
        for victimId, data in pairs(PendingDeaths) do
            local timeSinceDeath = now - data.timestamp
            
            -- Si la mort n'a pas été confirmée après 3s, forcer la notification
            if timeSinceDeath > PENDING_DEATH_TIMEOUT then
                DebugServer('[ANTITANK-SERVER] ⚠️ Mort en timeout (age: %dms) - Force notification: Victime=%d', 
                    timeSinceDeath, victimId)
                
                -- ✅ PATCH CRITIQUE: Conversion sécurisée AVANT GetPlayerCurrentMatch
                local safeVictimId = SafeToNumber(victimId)
                
                if safeVictimId == 0 then
                    DebugServer('[ANTITANK-SERVER] ❌ VictimId invalide dans PendingDeaths: %s', tostring(victimId))
                    PendingDeaths[victimId] = nil
                    goto continue
                end
                
                -- Vérifier si le joueur est toujours en match
                local matchId = exports['pvp_gunfight']:GetPlayerCurrentMatch(safeVictimId)
                if matchId then
                    -- Récupérer le killer depuis le cache
                    local killerId, weaponHash, isHeadshot = GetAntitankKiller(safeVictimId)
                    
                    -- ✅ PATCH CRITIQUE: Conversion sécurisée du killerId
                    local safeKillerId = SafeToNumber(killerId, -1)
                    
                    DebugServer('[ANTITANK-SERVER] 🔄 Force traitement mort: Victime=%d, Killer=%s', 
                        safeVictimId, tostring(safeKillerId))
                    
                    -- Déclencher l'event de mort côté serveur
                    TriggerEvent('pvp:forceProcessDeath', safeVictimId, safeKillerId, weaponHash, isHeadshot)
                end
                
                PendingDeaths[victimId] = nil
                processedDeaths = processedDeaths + 1
                
                ::continue::
            end
        end
        
        if processedDeaths > 0 then
            DebugServer('[ANTITANK-SERVER] 🔄 %d mort(s) forcée(s)', processedDeaths)
        end
    end
end)

-- ========================================
-- THREAD: Nettoyage automatique du cache
-- ========================================
CreateThread(function()
    DebugServer('[ANTITANK-SERVER] Thread cleanup cache démarré')
    
    while true do
        Wait(30000)
        
        local now = GetGameTimer()
        local cleanedCache = 0
        local cleanedPending = 0
        
        for victimId, data in pairs(KillCache) do
            if (now - data.timestamp) > CACHE_DURATION then
                KillCache[victimId] = nil
                cleanedCache = cleanedCache + 1
            end
        end
        
        for victimId, data in pairs(PendingDeaths) do
            if (now - data.timestamp) > (PENDING_DEATH_TIMEOUT * 2) then
                PendingDeaths[victimId] = nil
                cleanedPending = cleanedPending + 1
            end
        end
        
        if cleanedCache > 0 or cleanedPending > 0 then
            DebugServer('[ANTITANK-SERVER] 🧹 Cleanup: %d cache, %d pending', cleanedCache, cleanedPending)
        end
    end
end)

-- ========================================
-- ✅ NOUVEAU: Confirmer la mort auprès du client
-- ========================================
RegisterNetEvent('pvp:confirmDeathToClient', function(victimId)
    local safeId = SafeToNumber(victimId)
    
    if safeId == 0 then
        DebugServer('[ANTITANK-SERVER] ❌ confirmDeathToClient: ID invalide: %s', tostring(victimId))
        return
    end
    
    if GetPlayerPing(safeId) > 0 then
        TriggerClientEvent('pvp:deathConfirmed', safeId)
        DebugServer('[ANTITANK-SERVER] ✅ Confirmation mort envoyée au client: %d', safeId)
    end
    
    -- Nettoyer de la liste des morts en attente
    PendingDeaths[safeId] = nil
end)

-- ========================================
-- EXPORTS
-- ========================================
exports('GetAntitankKiller', GetAntitankKiller)
exports('GetAntitankKillData', GetAntitankKillData)
exports('ClearAntitankKillCache', ClearAntitankKillCache)

DebugSuccess('Module Antitank Bridge Server initialisé (v2.0.1 - FIX TYPE CONVERSION)')
DebugSuccess('✅ Events écoutés: fanca_antitank:kill, fanca_antitank:killed')
DebugSuccess('✅ Cache duration: 10s')
DebugSuccess('✅ Timeout mort: 3s')
DebugSuccess('✅ Conversion sécurisée activée (PATCH CRITIQUE)')