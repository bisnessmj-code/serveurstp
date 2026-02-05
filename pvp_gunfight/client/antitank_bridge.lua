-- ========================================
-- PVP GUNFIGHT - ANTITANK BRIDGE CLIENT
-- Version 2.0.0 - FIX DÉTECTION MORT CRITIQUE
-- ========================================
-- ✅ FIX: Cache killer étendu à 5s (au lieu de 3s)
-- ✅ FIX: Envoi mort avec retry automatique
-- ✅ FIX: Protection double envoi renforcée
-- ✅ FIX: Logs détaillés pour debug
-- ✅ NOUVEAU: Timeout automatique si pas de confirmation serveur
-- ========================================

DebugClient('Module Antitank Bridge chargé (v2.0.0 - FIX DÉTECTION MORT)')

-- ========================================
-- CACHE DES NATIVES (LOCALES)
-- ========================================
local _GetGameTimer = GetGameTimer
local _NetworkGetPlayerIndexFromPed = NetworkGetPlayerIndexFromPed
local _GetPlayerServerId = GetPlayerServerId
local _DoesEntityExist = DoesEntityExist
local _IsPedAPlayer = IsPedAPlayer
local _Wait = Wait

-- ========================================
-- CACHE DU DERNIER KILL DÉTECTÉ PAR ANTITANK
-- ========================================
local LastKillData = {
    killerId = nil,
    killerPed = nil,
    victimId = nil,
    victimPed = nil,
    weaponHash = nil,
    isHeadshot = false,
    isMelee = false,
    timestamp = 0,
    distance = 0
}

-- ✅ FIX: Cache étendu à 5s
local KILL_CACHE_DURATION = 5000

-- ✅ FIX: Protection envoi mort renforcée
local deathSentData = {
    sent = false,
    timestamp = 0,
    killerId = nil,
    confirmed = false
}

local DEATH_SEND_COOLDOWN = 2000
local DEATH_RETRY_INTERVAL = 500
local DEATH_RETRY_MAX = 3

-- ========================================
-- FONCTION: Obtenir le dernier killer détecté
-- ========================================
function GetLastAntitankKiller()
    local now = _GetGameTimer()
    
    if (now - LastKillData.timestamp) > KILL_CACHE_DURATION then
        return nil, nil, nil
    end
    
    return LastKillData.killerId, LastKillData.weaponHash, LastKillData.isHeadshot
end

-- ========================================
-- FONCTION: Obtenir les données complètes du dernier kill
-- ========================================
function GetLastAntitankKillData()
    local now = _GetGameTimer()
    
    if (now - LastKillData.timestamp) > KILL_CACHE_DURATION then
        return nil
    end
    
    return LastKillData
end

-- ========================================
-- FONCTION: Réinitialiser le cache
-- ========================================
function ClearAntitankKillCache()
    LastKillData = {
        killerId = nil,
        killerPed = nil,
        victimId = nil,
        victimPed = nil,
        weaponHash = nil,
        isHeadshot = false,
        isMelee = false,
        timestamp = 0,
        distance = 0
    }
    
    deathSentData = {
        sent = false,
        timestamp = 0,
        killerId = nil,
        confirmed = false
    }
end

-- ========================================
-- ✅ NOUVEAU: FONCTION ENVOI MORT AVEC RETRY
-- ========================================
local function SendDeathToServerWithRetry(killerId, weaponHash, isHeadshot, attemptNumber)
    attemptNumber = attemptNumber or 1
    
    if attemptNumber > DEATH_RETRY_MAX then
        DebugClient('[ANTITANK] ❌ ÉCHEC ENVOI MORT après %d tentatives', DEATH_RETRY_MAX)
        return
    end
    
    -- Vérifications de base
    if not IsInMatch() then 
        DebugClient('[ANTITANK] ⚠️ Pas en match - Annulation envoi')
        return 
    end
    
    if IsMatchDead() and deathSentData.confirmed then
        DebugClient('[ANTITANK] ⚠️ Déjà mort ET confirmé - SKIP')
        return
    end
    
    -- Marquer comme mort localement
    SetMatchDead(true)
    
    DebugClient('[ANTITANK] 📤 ENVOI MORT (Tentative %d/%d) - Killer: %s, Weapon: %s, Headshot: %s',
        attemptNumber, DEATH_RETRY_MAX,
        tostring(killerId), tostring(weaponHash), tostring(isHeadshot))
    
    -- Envoyer au serveur
    TriggerServerEvent('pvp:playerDiedWithKiller', killerId, weaponHash, isHeadshot)
    
    -- Déclencher event local pour spectateur
    TriggerEvent('pvp:onPlayerDeathInMatch')
    
    -- ✅ NOUVEAU: Thread de vérification confirmation
    CreateThread(function()
        _Wait(DEATH_RETRY_INTERVAL)
        
        -- Si toujours pas confirmé, retry
        if not deathSentData.confirmed and IsInMatch() then
            DebugClient('[ANTITANK] ⚠️ Pas de confirmation serveur - RETRY')
            SendDeathToServerWithRetry(killerId, weaponHash, isHeadshot, attemptNumber + 1)
        end
    end)
end

-- ========================================
-- ✅ FONCTION: Envoyer la mort au serveur
-- ========================================
local function SendDeathToServerFromAntitank(killerId, weaponHash, isHeadshot)
    local now = _GetGameTimer()
    
    -- ✅ Protection double envoi renforcée
    if deathSentData.sent then
        local timeSinceLastSend = now - deathSentData.timestamp
        
        -- Si même killer et < 2s, SKIP
        if deathSentData.killerId == killerId and timeSinceLastSend < DEATH_SEND_COOLDOWN then
            DebugClient('[ANTITANK] ⚠️ Mort déjà envoyée il y a %dms - SKIP', timeSinceLastSend)
            return
        end
        
        -- Si confirmé, SKIP absolu
        if deathSentData.confirmed then
            DebugClient('[ANTITANK] ⚠️ Mort déjà confirmée par serveur - SKIP')
            return
        end
    end
    
    -- Marquer l'envoi
    deathSentData.sent = true
    deathSentData.timestamp = now
    deathSentData.killerId = killerId
    deathSentData.confirmed = false
    
    -- Envoyer avec retry
    SendDeathToServerWithRetry(killerId, weaponHash, isHeadshot, 1)
end

-- ========================================
-- ✅ NOUVEAU: EVENT CONFIRMATION SERVEUR
-- ========================================
RegisterNetEvent('pvp:deathConfirmed', function()
    DebugClient('[ANTITANK] ✅ MORT CONFIRMÉE PAR SERVEUR')
    deathSentData.confirmed = true
end)

-- ========================================
-- EVENT CLIENT: fanca_antitank:gotHit
-- Déclenché quand le joueur local prend un hit
-- ========================================
AddEventHandler('fanca_antitank:gotHit', function(attacker, attackerServerId, hitLocation, weaponHash, weaponName, dying, isHeadshot, withMeleeWeapon, damage, enduranceDamage)
    if not IsInMatch() then return end
    
    local now = _GetGameTimer()
    
    DebugClient('[ANTITANK] 🎯 gotHit - Attacker: %s, Weapon: %s, Dying: %s, Headshot: %s, Damage: %s',
        tostring(attackerServerId), tostring(weaponName), tostring(dying), tostring(isHeadshot), tostring(damage))
    
    -- Enregistrer l'attaquant dans le cache
    if attackerServerId and attackerServerId > 0 then
        LastKillData.killerId = attackerServerId
        LastKillData.killerPed = attacker
        LastKillData.weaponHash = weaponHash
        LastKillData.isHeadshot = isHeadshot or false
        LastKillData.isMelee = withMeleeWeapon or false
        LastKillData.timestamp = now
        
        DebugClient('[ANTITANK] ✅ Attaquant enregistré: ID=%d, Arme=%s', attackerServerId, weaponName)
    end
    
    -- ✅ Si on meurt de ce hit, envoyer IMMÉDIATEMENT
    if dying then
        DebugClient('[ANTITANK] 💀 MORT DÉTECTÉE via gotHit (dying=true)')
        SendDeathToServerFromAntitank(attackerServerId, weaponHash, isHeadshot)
    end
end)

-- ========================================
-- EVENT CLIENT: fanca_antitank:hit
-- Déclenché quand le joueur local touche un autre joueur
-- ========================================
AddEventHandler('fanca_antitank:hit', function(victim, victimServerId, bone, isHeadshot, weapon, dying, victimGodmode)
    if not IsInMatch() then return end
    
    DebugClient('[ANTITANK] 🔫 hit - Victime: %s, Bone: %s, Headshot: %s, Dying: %s',
        tostring(victimServerId), tostring(bone), tostring(isHeadshot), tostring(dying))
    
    if victimServerId and victimServerId > 0 and dying then
        local myServerId = GetPlayerServerId(PlayerId())
        local now = _GetGameTimer()
        
        DebugClient('[ANTITANK] ✅ Kill confirmé - Nous (%d) avons tué %d', myServerId, victimServerId)
        
        LastKillData.victimId = victimServerId
        LastKillData.victimPed = victim
        LastKillData.killerId = myServerId
        LastKillData.weaponHash = weapon
        LastKillData.isHeadshot = isHeadshot or false
        LastKillData.timestamp = now
    end
end)

-- ========================================
-- EVENT CLIENT: fanca_antitank:hitExp
-- ========================================
AddEventHandler('fanca_antitank:hitExp', function(victim, victimServerId, bone, isHeadshot, weapon, dying, victimGodmode)
    if not IsInMatch() then return end
    
    if victimServerId and victimServerId > 0 and dying then
        local myServerId = GetPlayerServerId(PlayerId())
        local now = _GetGameTimer()
        
        DebugClient('[ANTITANK] ✅ Kill confirmé (hitExp) - Nous (%d) avons tué %d', myServerId, victimServerId)
        
        LastKillData.victimId = victimServerId
        LastKillData.victimPed = victim
        LastKillData.killerId = myServerId
        LastKillData.weaponHash = weapon
        LastKillData.isHeadshot = isHeadshot or false
        LastKillData.timestamp = now
    end
end)

-- ========================================
-- EVENT CLIENT: fanca_antitank:effect
-- Déclenché après un kill (killer ou victime)
-- ========================================
AddEventHandler('fanca_antitank:effect', function(isVictim, killerOrVictimId, killerData)
    if not IsInMatch() then return end
    
    local now = _GetGameTimer()
    
    DebugClient('[ANTITANK] 💥 effect - isVictim: %s, otherId: %s', 
        tostring(isVictim), tostring(killerOrVictimId))
    
    if killerData then
        DebugClient('[ANTITANK] 💥 killerData - Weapon: %s, Headshot: %s, Melee: %s',
            tostring(killerData.weaponHash), tostring(killerData.isHeadshot), tostring(killerData.isMelee))
    end
    
    local myServerId = GetPlayerServerId(PlayerId())
    
    if isVictim then
        DebugClient('[ANTITANK] 💀 NOUS SOMMES LA VICTIME - Killer: %s', tostring(killerOrVictimId))
        
        -- Mettre à jour le cache
        LastKillData.killerId = killerOrVictimId
        LastKillData.victimId = myServerId
        LastKillData.timestamp = now
        
        if killerData then
            LastKillData.killerPed = killerData.killerPed
            LastKillData.victimPed = killerData.victimPed
            LastKillData.weaponHash = killerData.weaponHash
            LastKillData.isHeadshot = killerData.isHeadshot or false
            LastKillData.isMelee = killerData.isMelee or false
        end
        
        -- ✅ Envoyer la mort immédiatement
        SendDeathToServerFromAntitank(
            killerOrVictimId, 
            killerData and killerData.weaponHash or nil, 
            killerData and killerData.isHeadshot or false
        )
    else
        DebugClient('[ANTITANK] 🏆 Nous avons tué - Victime: %s', tostring(killerOrVictimId))
        
        LastKillData.killerId = myServerId
        LastKillData.victimId = killerOrVictimId
        LastKillData.timestamp = now
        
        if killerData then
            LastKillData.killerPed = killerData.killerPed
            LastKillData.victimPed = killerData.victimPed
            LastKillData.weaponHash = killerData.weaponHash
            LastKillData.isHeadshot = killerData.isHeadshot or false
            LastKillData.isMelee = killerData.isMelee or false
        end
    end
end)

-- ========================================
-- ✅ RESET DU FLAG À CHAQUE NOUVEAU ROUND/MATCH
-- ========================================
RegisterNetEvent('pvp:roundStart', function()
    ClearAntitankKillCache()
    DebugClient('[ANTITANK] 🔄 Reset pour nouveau round')
end)

RegisterNetEvent('pvp:matchFound', function()
    ClearAntitankKillCache()
    DebugClient('[ANTITANK] 🔄 Reset pour nouveau match')
end)

RegisterNetEvent('pvp:respawnPlayer', function()
    ClearAntitankKillCache()
    DebugClient('[ANTITANK] 🔄 Reset après respawn')
end)

RegisterNetEvent('pvp:teleportToSpawn', function()
    ClearAntitankKillCache()
    DebugClient('[ANTITANK] 🔄 Reset après téléportation')
end)

-- ========================================
-- EXPORTS
-- ========================================
exports('GetLastAntitankKiller', GetLastAntitankKiller)
exports('GetLastAntitankKillData', GetLastAntitankKillData)
exports('ClearAntitankKillCache', ClearAntitankKillCache)

DebugSuccess('Module Antitank Bridge initialisé (v2.0.0 - FIX DÉTECTION MORT)')
DebugSuccess('✅ Events écoutés: gotHit, hit, hitExp, effect')
DebugSuccess('✅ Cache kill: 5s (au lieu de 3s)')
DebugSuccess('✅ Envoi mort avec retry automatique (max 3 tentatives)')
DebugSuccess('✅ Confirmation serveur requise')