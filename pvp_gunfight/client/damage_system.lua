-- ========================================
-- PVP GUNFIGHT - SYSTÈME DE DÉGÂTS ULTRA-OPTIMISÉ
-- Version 3.1.0 - FIX DÉTECTION MORT
-- ========================================
-- ✅ FIX: Envoi mort immédiat sur headshot
-- ✅ FIX: Protection friendly fire renforcée
-- ✅ FIX: Logs détaillés pour debug
-- ✅ OPTIMISÉ: UN SEUL thread principal
-- ========================================

DebugClient('Module Damage System chargé (v3.1.0 - FIX DÉTECTION MORT)')

-- ========================================
-- CACHE DES NATIVES (LOCALES)
-- ========================================
local _PlayerPedId = PlayerPedId
local _SetWeaponDamageModifier = SetWeaponDamageModifier
local _SetWeaponDamageModifierThisFrame = SetWeaponDamageModifierThisFrame
local _GetHashKey = GetHashKey
local _Wait = Wait
local _NetworkGetPlayerIndexFromPed = NetworkGetPlayerIndexFromPed
local _GetPlayerServerId = GetPlayerServerId
local _GetEntityHealth = GetEntityHealth
local _SetEntityHealth = SetEntityHealth
local _GetGameTimer = GetGameTimer
local _GetPlayerPed = GetPlayerPed
local _GetPlayerFromServerId = GetPlayerFromServerId
local _NetworkIsPlayerActive = NetworkIsPlayerActive
local _DoesEntityExist = DoesEntityExist
local _IsPedAPlayer = IsPedAPlayer
local _GetPedSourceOfDeath = GetPedSourceOfDeath
local _SetPedHelmet = SetPedHelmet
local _SetPedCanLosePropsOnDamage = SetPedCanLosePropsOnDamage
local _SetPedConfigFlag = SetPedConfigFlag
local _GetPedLastDamageBone = GetPedLastDamageBone
local _IsEntityDead = IsEntityDead

-- ========================================
-- CONFIGURATION OPTIMISEE (FIX PERFORMANCE v2)
-- ========================================
local PERF = {
    attackerCacheDuration = 1000,
    teammateCacheRefresh = 1000,
    helmetCheckInterval = 500,
    healthCheckInterval = 50,           -- FIX: 50ms au lieu de 0 (economise ~95% CPU)
    historyCleanupInterval = 3000,
}

local DAMAGE_CONFIG = {
    baseDamageMultiplier = 1.0,
    
    weapons = {
        [_GetHashKey('WEAPON_PISTOL50')] = 1.0,
        [_GetHashKey('WEAPON_COMBATPISTOL')] = 1.0,
        [_GetHashKey('WEAPON_APPISTOL')] = 1.0,
        [_GetHashKey('WEAPON_PISTOL')] = 1.0,
        [_GetHashKey('WEAPON_HEAVYPISTOL')] = 1.0,
    },
    
    headshotEnabled = true,
    headshotInstantKill = true,
    
    headshotBones = {
        31086,
        39317,
        0x796E,
        12844,
    },
}

-- ========================================
-- VARIABLES OPTIMISÉES
-- ========================================
local damageSystemActive = false

local cachedAttacker = {
    ped = nil,
    weapon = nil,
    timestamp = 0
}

local teammateServerIds = {}
local lastTeammateUpdate = 0

local damageHistory = {}
local MAX_HISTORY = 10
local HISTORY_TIMEOUT = 2000

local headshotKillInProgress = false
local lastHeadshotTime = 0
local lastHeadshotNotify = 0
local HEADSHOT_NOTIFY_COOLDOWN = 1000

local lastHealthCheck = {
    health = 200,
    time = 0
}

-- ========================================
-- FONCTION: Vérifier bone headshot
-- ========================================
local function IsHeadshotBone(bone)
    if not bone then return false end
    return bone == 31086 or bone == 39317 or bone == 0x796E or bone == 12844
end

-- ========================================
-- ✅ FIX: Kill instantané avec envoi mort
-- ========================================
local function ForceInstantKill(ped, reason, killerId, weaponHash, isHeadshot)
    headshotKillInProgress = true
    lastHeadshotTime = _GetGameTimer()
    
    DebugClient('[HEADSHOT] 💀 KILL INSTANTANÉ - %s (Killer: %s)', reason, tostring(killerId))
    
    -- Kill instantané
    _SetEntityHealth(ped, 0)
    _Wait(0)
    _SetEntityHealth(ped, 0)
    
    -- ✅ NOUVEAU: Envoyer mort immédiatement
    if killerId and killerId > 0 then
        DebugClient('[HEADSHOT] 📤 Envoi mort au serveur')
        TriggerServerEvent('pvp:playerDiedWithKiller', killerId, weaponHash, isHeadshot)
    end
    
    -- Vérification finale
    CreateThread(function()
        _Wait(50)
        if not _IsEntityDead(ped) then
            _SetEntityHealth(ped, 0)
            DebugClient('[HEADSHOT] 🔄 Force kill final')
        end
        
        _Wait(500)
        headshotKillInProgress = false
    end)
end

-- ========================================
-- FONCTION: Mettre à jour coéquipiers
-- ========================================
local function UpdateTeammateCache()
    local now = _GetGameTimer()
    
    if now - lastTeammateUpdate < PERF.teammateCacheRefresh then
        return
    end
    
    lastTeammateUpdate = now
    teammateServerIds = {}
    
    local teammates = GetTeammates()
    if not teammates or #teammates == 0 then
        return
    end
    
    for i = 1, #teammates do
        teammateServerIds[teammates[i]] = true
    end
    
    DebugClient('[TEAM] Cache mis à jour: %d coéquipiers', #teammates)
end

-- ========================================
-- FONCTION: Vérifier si coéquipier
-- ========================================
local function IsTeammatePed(ped)
    if not ped or not _DoesEntityExist(ped) or not _IsPedAPlayer(ped) then
        return false
    end
    
    local playerIndex = _NetworkGetPlayerIndexFromPed(ped)
    if not playerIndex or playerIndex == -1 then
        return false
    end
    
    local serverId = _GetPlayerServerId(playerIndex)
    if not serverId or serverId <= 0 then
        return false
    end
    
    return teammateServerIds[serverId] == true
end

-- ========================================
-- FONCTION: Enregistrer dégât avec cache
-- ========================================
local function RecordDamage(attacker, weapon)
    if not attacker or attacker == 0 or attacker == -1 then return end
    if not _DoesEntityExist(attacker) then return end
    if not _IsPedAPlayer(attacker) then return end
    
    local now = _GetGameTimer()
    
    cachedAttacker.ped = attacker
    cachedAttacker.weapon = weapon
    cachedAttacker.timestamp = now
    
    if #damageHistory >= MAX_HISTORY then
        table.remove(damageHistory, MAX_HISTORY)
    end
    
    table.insert(damageHistory, 1, {
        attacker = attacker,
        weapon = weapon,
        time = now
    })
end

-- ========================================
-- FONCTION: Cleanup historique
-- ========================================
local function CleanupHistory()
    local now = _GetGameTimer()
    
    for i = #damageHistory, 1, -1 do
        if now - damageHistory[i].time > HISTORY_TIMEOUT then
            table.remove(damageHistory, i)
        end
    end
end

-- ========================================
-- FONCTION: Récupérer meilleur attaquant
-- ========================================
local function GetBestAttacker(eventAttacker, eventWeapon)
    local now = _GetGameTimer()
    
    if eventAttacker and eventAttacker ~= -1 and _DoesEntityExist(eventAttacker) and _IsPedAPlayer(eventAttacker) then
        return eventAttacker, eventWeapon
    end
    
    if cachedAttacker.ped and (now - cachedAttacker.timestamp) < PERF.attackerCacheDuration then
        if _DoesEntityExist(cachedAttacker.ped) and _IsPedAPlayer(cachedAttacker.ped) then
            return cachedAttacker.ped, cachedAttacker.weapon
        end
    end
    
    for i = 1, #damageHistory do
        local record = damageHistory[i]
        if (now - record.time) < HISTORY_TIMEOUT then
            if _DoesEntityExist(record.attacker) and _IsPedAPlayer(record.attacker) then
                return record.attacker, record.weapon
            end
        end
    end
    
    return nil, nil
end

-- ========================================
-- EVENT: gameEventTriggered
-- ========================================
AddEventHandler('gameEventTriggered', function(eventName, eventData)
    if eventName ~= 'CEventNetworkEntityDamage' then return end
    if not IsInMatch() then return end
    
    local victim = eventData[1]
    local attacker = eventData[2]
    local weaponUsed = eventData[7]
    local bone = eventData[3]
    local isDead = eventData[4] == 1
    
    if victim ~= _PlayerPedId() then return end
    
    -- Enregistrer dans cache
    if attacker and attacker ~= -1 then
        RecordDamage(attacker, weaponUsed)
    end
    
    -- HEADSHOT CHECK
    local isHeadshot = IsHeadshotBone(bone)
    
    if not isHeadshot then
        local lastBone = _GetPedLastDamageBone(victim)
        if IsHeadshotBone(lastBone) then
            isHeadshot = true
        end
    end
    
    if isHeadshot and DAMAGE_CONFIG.headshotEnabled then
        local now = _GetGameTimer()
        
        if now - lastHeadshotNotify >= HEADSHOT_NOTIFY_COOLDOWN then
            lastHeadshotNotify = now
            DebugClient('[HEADSHOT] 💀 DÉTECTÉ (Bone: %d)', bone or -1)
        end
        
        local finalAttacker, finalWeapon = GetBestAttacker(attacker, weaponUsed)
        
        if not finalAttacker then
            DebugClient('[HEADSHOT] ⚠️ Pas d\'attaquant trouvé')
            return
        end
        
        -- Vérifier coéquipier
        if IsTeammatePed(finalAttacker) then
            DebugClient('[HEADSHOT] 🛡️ COÉQUIPIER - BLOQUÉ')
            
            local currentHealth = _GetEntityHealth(victim)
            if currentHealth <= 100 or isDead then
                _SetEntityHealth(victim, lastHealthCheck.health or 150)
            end
            return
        end
        
        -- Convertir PED → ServerID
        local attackerPlayerIndex = _NetworkGetPlayerIndexFromPed(finalAttacker)
        local attackerServerId = nil
        
        if attackerPlayerIndex and attackerPlayerIndex ~= -1 then
            attackerServerId = _GetPlayerServerId(attackerPlayerIndex)
        end
        
        -- ✅ FIX: Kill instantané AVEC envoi mort
        if DAMAGE_CONFIG.headshotInstantKill then
            ForceInstantKill(victim, 'HEADSHOT', attackerServerId, finalWeapon, true)
        end
    end
end)

-- ========================================
-- THREAD PRINCIPAL (FIX PERFORMANCE v2)
-- ========================================
CreateThread(function()
    DebugSuccess('Thread principal degats demarre (OPTIMISE v2)')

    local lastHelmetCheck = 0
    local lastHistoryCleanup = 0
    local lastTeammateUpdate = 0
    local cachedPed = _PlayerPedId()
    local lastPedUpdate = 0

    while true do
        if not IsInMatch() or not damageSystemActive then
            _Wait(500)
            cachedPed = _PlayerPedId()  -- Refresh ped quand on sort du match
        else
            local now = _GetGameTimer()

            -- FIX: Mettre a jour le ped cache seulement toutes les 500ms
            if now - lastPedUpdate > 500 then
                cachedPed = _PlayerPedId()
                lastPedUpdate = now
            end

            -- Protection friendly fire (seulement si pas de headshot en cours)
            if not headshotKillInProgress then
                local currentHealth = _GetEntityHealth(cachedPed)
                local healthLost = lastHealthCheck.health - currentHealth

                if healthLost > 0 and cachedAttacker.ped and (now - cachedAttacker.timestamp) < 200 then
                    if IsTeammatePed(cachedAttacker.ped) then
                        _SetEntityHealth(cachedPed, lastHealthCheck.health)
                    end
                end

                -- Mise a jour sante toutes les 200ms
                if now - lastHealthCheck.time > 200 then
                    lastHealthCheck.health = currentHealth
                    lastHealthCheck.time = now
                end
            end

            -- Casque toutes les 500ms
            if now - lastHelmetCheck >= PERF.helmetCheckInterval then
                lastHelmetCheck = now
                _SetPedConfigFlag(cachedPed, 438, true)
                _SetPedHelmet(cachedPed, false)
            end

            -- Cleanup historique toutes les 3 secondes
            if now - lastHistoryCleanup >= PERF.historyCleanupInterval then
                lastHistoryCleanup = now
                CleanupHistory()
            end

            -- Mise a jour coequipiers toutes les 1 seconde
            if now - lastTeammateUpdate >= PERF.teammateCacheRefresh then
                lastTeammateUpdate = now
                UpdateTeammateCache()
            end

            -- FIX: Supprime la boucle des multiplicateurs d'armes (tous a 1.0 = inutile)
            -- Les multiplicateurs a 1.0 sont la valeur par defaut, pas besoin de les appliquer

            _Wait(PERF.healthCheckInterval)  -- 50ms au lieu de 0
        end
    end
end)

-- ========================================
-- ACTIVATION/DÉSACTIVATION
-- ========================================
local function EnableDamageSystem()
    if damageSystemActive then return end
    
    damageSystemActive = true
    headshotKillInProgress = false
    lastHeadshotTime = 0
    lastHeadshotNotify = 0
    
    DebugSuccess('🔫 Système de dégâts ACTIVÉ')
    
    for weaponHash, multiplier in pairs(DAMAGE_CONFIG.weapons) do
        _SetWeaponDamageModifier(weaponHash, multiplier)
    end
    
    local ped = _PlayerPedId()
    _SetPedHelmet(ped, false)
    _SetPedCanLosePropsOnDamage(ped, false, 0)
    _SetPedConfigFlag(ped, 438, true)
    
    lastHealthCheck = {
        health = _GetEntityHealth(ped),
        time = _GetGameTimer()
    }
    
    damageHistory = {}
    cachedAttacker = {ped = nil, weapon = nil, timestamp = 0}
    
    _Wait(200)
    UpdateTeammateCache()
end

local function DisableDamageSystem()
    if not damageSystemActive then return end
    
    damageSystemActive = false
    headshotKillInProgress = false
    
    DebugClient('🔫 Système de dégâts DÉSACTIVÉ')
    
    for weaponHash, _ in pairs(DAMAGE_CONFIG.weapons) do
        _SetWeaponDamageModifier(weaponHash, 1.0)
    end
    
    local ped = _PlayerPedId()
    _SetPedHelmet(ped, true)
    _SetPedCanLosePropsOnDamage(ped, true, 0)
    _SetPedConfigFlag(ped, 438, false)
    
    damageHistory = {}
    teammateServerIds = {}
    cachedAttacker = {ped = nil, weapon = nil, timestamp = 0}
end

-- ========================================
-- THREAD: ACTIVATION AUTOMATIQUE
-- ========================================
CreateThread(function()
    while true do
        if IsInMatch() then
            if not damageSystemActive then
                EnableDamageSystem()
            end
            _Wait(1000)
        else
            if damageSystemActive then
                DisableDamageSystem()
            end
            _Wait(2000)
        end
    end
end)

-- ========================================
-- EVENT: MISE À JOUR COÉQUIPIERS
-- ========================================
RegisterNetEvent('pvp:setTeammates', function(teammateIds)
    DebugClient('[TEAM] 📡 Event setTeammates reçu')
    _Wait(500)
    UpdateTeammateCache()
end)

-- ========================================
-- EVENTS
-- ========================================
RegisterNetEvent('pvp:enableDamageSystem', EnableDamageSystem)
RegisterNetEvent('pvp:disableDamageSystem', DisableDamageSystem)

-- ========================================
-- EXPORTS
-- ========================================
exports('EnableDamageSystem', EnableDamageSystem)
exports('DisableDamageSystem', DisableDamageSystem)

DebugSuccess('Module Damage System initialisé (v3.1.0 - FIX DÉTECTION MORT)')
DebugSuccess('✅ Headshot instantané avec envoi mort automatique')
DebugSuccess('✅ Protection friendly fire renforcée')
DebugSuccess('✅ Logs détaillés activés')