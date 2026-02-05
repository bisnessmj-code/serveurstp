-- ========================================
-- PVP GUNFIGHT - CLIENT MAIN ULTRA-OPTIMIS�
-- Version 5.4.0 - AJOUT SYST�ME ARMURE (KEVLAR)
-- ========================================
-- ? FIX: D�tection mort multi-sources
-- ? FIX: Synchronisation serveur garantie
-- ? FIX: Fallback d�tection mort robuste
-- ? FIX: Anti-double event am�lior�
-- ? NOUVEAU: Gestion armure (kevlar) optimis�e
-- ========================================

DebugSuccess('Script charg� (Version 5.4.0 - Fix D�tection Mort + Armure)')

-- ========================================
-- CACHE DES NATIVES (LOCALES)
-- ========================================
local _PlayerPedId = PlayerPedId
local _GetEntityCoords = GetEntityCoords
local _IsControlJustReleased = IsControlJustReleased
local _Wait = Wait
local _GetGameTimer = GetGameTimer
local _GetHashKey = GetHashKey
local _IsEntityDead = IsEntityDead
local _RestorePlayerStamina = RestorePlayerStamina
local _FreezeEntityPosition = FreezeEntityPosition
local _SetEntityCoords = SetEntityCoords
local _SetEntityHeading = SetEntityHeading
local _SetEntityHealth = SetEntityHealth
local _DoScreenFadeOut = DoScreenFadeOut
local _DoScreenFadeIn = DoScreenFadeIn
local _PlaySoundFrontend = PlaySoundFrontend
local _SetCanAttackFriendly = SetCanAttackFriendly
local _SetPedRelationshipGroupHash = SetPedRelationshipGroupHash
local _GetPlayerFromServerId = GetPlayerFromServerId
local _NetworkIsPlayerActive = NetworkIsPlayerActive
local _GetPlayerPed = GetPlayerPed
local _GetEntityHealth = GetEntityHealth
local _NetworkGetPlayerIndexFromPed = NetworkGetPlayerIndexFromPed
local _GetPlayerServerId = GetPlayerServerId
local _IsPedAPlayer = IsPedAPlayer
local _GetPedSourceOfDeath = GetPedSourceOfDeath
local _SetPedArmour = SetPedArmour
local _GetPedArmour = GetPedArmour

-- ========================================
-- CONFIGURATION PERFORMANCE
-- ========================================
local PERF = {
    -- Intervals
    heartbeatInterval = 3000,
    positionCheckInterval = 2000,
    weaponCheckInterval = 500,
    pedDistanceCheckIdle = 500,
    pedDistanceCheckClose = 100,
    relationCheckInterval = 1000,
    
    -- ? NOUVEAU: Intervalle d�tection mort
    deathCheckInterval = 100,  -- V�rification toutes les 100ms
    
    -- Distances
    pedInteractDistance = 2.5,
    pedDrawDistance = 50.0,
}

-- ========================================
-- VARIABLES
-- ========================================
local pedSpawned = false
local pedEntity = nil
local pedCoords = nil
local uiOpen = false
local LOBBY_COORDS = nil
local isProtectedFromOtherScripts = false
local isNearRankedPed = false
local isNearPed = false

local cachedPedDistance = 999
local lastPedDistanceUpdate = 0

local WEAPON_CONFIG = {
    hash = _GetHashKey('WEAPON_PISTOL50'),
    ammo = 250,
}

local weaponCheckAttempts = 0
local MAX_WEAPON_CHECK_ATTEMPTS = 5
local lastWeaponCheckTime = 0

-- ? NOUVEAU: Syst�me de d�tection mort am�lior�
local DeathDetection = {
    lastDeathEventTime = 0,
    deathEventCooldown = 1000,  -- 1 seconde entre les events
    lastHealthCheck = 200,
    deathConfirmed = false,
    lastKillerId = nil,
    lastWeaponHash = nil,
    lastIsHeadshot = false,
    deathSentToServer = false,
    lastDeathSentTime = 0,
}

-- ========================================
-- ? FONCTION: R�initialiser l'�tat de mort
-- ========================================
local function ResetDeathState()
    DeathDetection.deathConfirmed = false
    DeathDetection.lastKillerId = nil
    DeathDetection.lastWeaponHash = nil
    DeathDetection.lastIsHeadshot = false
    DeathDetection.deathSentToServer = false
    DeathDetection.lastHealthCheck = 200
end

-- ========================================
-- ? NOUVEAU: GESTION ARMURE (KEVLAR)
-- ========================================

-- Fonction pour donner l'armure au joueur
local function GiveArmor(ped)
    if not Config.Armor.enabled then return end
    
    local currentArmor = _GetPedArmour(ped)
    
    -- Seulement si l'armure actuelle est inf�rieure � celle configur�e
    if currentArmor < Config.Armor.amount then
        _SetPedArmour(ped, Config.Armor.amount)
        DebugClient('??? Armure donn�e: %d', Config.Armor.amount)
    end
end

-- Fonction pour retirer toute l'armure
local function RemoveAllArmor(ped)
    _SetPedArmour(ped, 0)
    DebugClient('??? Armure retir�e')
end

-- ========================================
-- ? FONCTION: Envoyer mort au serveur (UNE SEULE FOIS)
-- ========================================
local function SendDeathToServer(killerId, weaponHash, isHeadshot)
    local now = _GetGameTimer()
    
    -- ? Protection anti-double envoi
    if DeathDetection.deathSentToServer then
        DebugClient('[DEATH] ?? Mort d�j� envoy�e au serveur - IGNOR�')
        return
    end
    
    -- ? Protection cooldown
    if (now - DeathDetection.lastDeathSentTime) < DeathDetection.deathEventCooldown then
        DebugClient('[DEATH] ?? Cooldown actif - IGNOR�')
        return
    end
    
    DeathDetection.deathSentToServer = true
    DeathDetection.lastDeathSentTime = now
    SetMatchDead(true)
    
    DebugClient('[DEATH] ?? ENVOI MORT AU SERVEUR - Killer: %s, Weapon: %s, Headshot: %s',
        tostring(killerId), tostring(weaponHash), tostring(isHeadshot))
    
    -- ? Envoyer avec toutes les infos disponibles
    TriggerServerEvent('pvp:playerDiedWithKiller', killerId, weaponHash, isHeadshot)
    
    -- D�clencher event pour le syst�me spectateur
    TriggerEvent('pvp:onPlayerDeathInMatch')
end

-- ========================================
-- ? FONCTION: R�cup�rer le killer depuis toutes les sources
-- ========================================
local function GetBestKillerInfo()
    local killerId = nil
    local weaponHash = nil
    local isHeadshot = false
    
    -- ? SOURCE 1: Cache DeathDetection (set par les events)
    if DeathDetection.lastKillerId and DeathDetection.lastKillerId > 0 then
        killerId = DeathDetection.lastKillerId
        weaponHash = DeathDetection.lastWeaponHash
        isHeadshot = DeathDetection.lastIsHeadshot
        DebugClient('[DEATH] Source 1 (Cache): Killer=%d', killerId)
    end
    
    -- ? SOURCE 2: fanca_antitank bridge
    if not killerId and GetLastAntitankKiller then
        local antitankKiller, antitankWeapon, antitankHeadshot = GetLastAntitankKiller()
        if antitankKiller and antitankKiller > 0 then
            killerId = antitankKiller
            weaponHash = antitankWeapon or weaponHash
            isHeadshot = antitankHeadshot or isHeadshot
            DebugClient('[DEATH] Source 2 (Antitank): Killer=%d', killerId)
        end
    end
    
    -- ? SOURCE 3: GetPedSourceOfDeath (native GTA)
    if not killerId then
        local ped = _PlayerPedId()
        local sourceOfDeath = _GetPedSourceOfDeath(ped)
        
        if sourceOfDeath and sourceOfDeath ~= 0 and sourceOfDeath ~= ped then
            if _IsPedAPlayer(sourceOfDeath) then
                local killerIndex = _NetworkGetPlayerIndexFromPed(sourceOfDeath)
                if killerIndex and killerIndex ~= -1 then
                    killerId = _GetPlayerServerId(killerIndex)
                    DebugClient('[DEATH] Source 3 (Native): Killer=%d', killerId)
                end
            end
        end
    end
    
    return killerId, weaponHash, isHeadshot
end

-- ========================================
-- FONCTION: DONNER ARMES + ARMURE (OPTIMIS�E)
-- ========================================
local function GiveMatchWeapons(ped)
    RemoveAllPedWeapons(ped, true)
    _Wait(50)
    
    GiveWeaponToPed(ped, WEAPON_CONFIG.hash, WEAPON_CONFIG.ammo, false, true)
    _Wait(100)
    
    SetCurrentPedWeapon(ped, WEAPON_CONFIG.hash, true)
    
    -- ? NOUVEAU: Donner l'armure si activ�e
    if Config.Armor.enabled and Config.Armor.giveOnSpawn then
        GiveArmor(ped)
    end
    
    local hasWeapon, currentWeapon = GetCurrentPedWeapon(ped, true)
    
    if not hasWeapon or currentWeapon ~= WEAPON_CONFIG.hash then
        DebugWarn('?? Arme non �quip�e - Retry...')
        
        _Wait(100)
        RemoveAllPedWeapons(ped, true)
        _Wait(50)
        GiveWeaponToPed(ped, WEAPON_CONFIG.hash, WEAPON_CONFIG.ammo, false, true)
        _Wait(100)
        SetCurrentPedWeapon(ped, WEAPON_CONFIG.hash, true)
        
        -- ? Redonner armure apr�s retry
        if Config.Armor.enabled and Config.Armor.giveOnSpawn then
            GiveArmor(ped)
        end
        
        hasWeapon, currentWeapon = GetCurrentPedWeapon(ped, true)
        
        if not hasWeapon or currentWeapon ~= WEAPON_CONFIG.hash then
            DebugError('? �CHEC attribution arme')
            TriggerServerEvent('pvp:weaponCheckFailed')
        else
            DebugSuccess('? Arme �quip�e apr�s retry')
        end
    else
        DebugClient('? Armes donn�es')
    end
end

-- ========================================
-- FONCTION: FORCER V�RIFICATION ARME
-- ========================================
local function ForceWeaponCheck(ped)
    local hasWeapon, currentWeapon = GetCurrentPedWeapon(ped, true)
    
    if not hasWeapon or currentWeapon ~= WEAPON_CONFIG.hash then
        DebugWarn('?? ARME MANQUANTE - Correction...')
        
        RemoveAllPedWeapons(ped, true)
        _Wait(50)
        GiveWeaponToPed(ped, WEAPON_CONFIG.hash, WEAPON_CONFIG.ammo, false, true)
        _Wait(50)
        SetCurrentPedWeapon(ped, WEAPON_CONFIG.hash, true)
        
        hasWeapon, currentWeapon = GetCurrentPedWeapon(ped, true)
        
        if hasWeapon and currentWeapon == WEAPON_CONFIG.hash then
            DebugSuccess('? Arme forc�e avec succ�s')
            TriggerServerEvent('pvp:weaponForced')
            return true
        else
            DebugError('? �chec for�age arme')
            TriggerServerEvent('pvp:weaponCheckFailed')
            return false
        end
    end
    
    return true
end

-- ========================================
-- FONCTION: V�RIFICATION POST-SPAWN
-- ========================================
local function PostSpawnWeaponCheck()
    CreateThread(function()
        _Wait(1000)
        
        local ped = GetCachedPed()
        
        if IsInMatch() then
            DebugClient('?? V�rification post-spawn arme...')
            
            for attempt = 1, 5 do
                local hasWeapon, currentWeapon = GetCurrentPedWeapon(ped, true)
                
                if not hasWeapon or currentWeapon ~= WEAPON_CONFIG.hash then
                    DebugWarn('?? Tentative %d/5 - Arme manquante', attempt)
                    
                    RemoveAllPedWeapons(ped, true)
                    _Wait(50)
                    GiveWeaponToPed(ped, WEAPON_CONFIG.hash, WEAPON_CONFIG.ammo, false, true)
                    _Wait(100)
                    SetCurrentPedWeapon(ped, WEAPON_CONFIG.hash, true)
                    
                    _Wait(500 * attempt)
                else
                    DebugSuccess('? Arme v�rifi�e OK (tentative %d)', attempt)
                    break
                end
            end
            
            local hasWeapon, currentWeapon = GetCurrentPedWeapon(ped, true)
            
            if not hasWeapon or currentWeapon ~= WEAPON_CONFIG.hash then
                DebugError('? �CHEC FINAL - Arme manquante apr�s 5 tentatives')
                TriggerServerEvent('pvp:weaponCheckFailed')
                exports['brutal_notify']:SendAlert('PVP Gunfight', 'Probléme arme - Contactez un admin', 5000, 'error')
            else
                DebugSuccess('? V�rification post-spawn termin�e')
            end
        end
    end)
end

-- ========================================
-- EXPORTS
-- ========================================
exports('IsPlayerInPVP', function()
    return IsInMatch() or IsInQueue()
end)

exports('IsPlayerSearchingPVP', function()
    return IsInQueue()
end)

exports('IsPlayerInPVPMatch', function()
    return IsInMatch()
end)

exports('CanPlayerInteract', function()
    return not (IsInMatch() or IsInQueue())
end)

exports('IsNearRankedPed', function()
    return isNearRankedPed
end)

-- ========================================
-- FONCTION: PROTECTION SCRIPT
-- ========================================
local function SetScriptProtection(enabled)
    isProtectedFromOtherScripts = enabled
    
    if enabled then
        DebugClient('?? PROTECTION ACTIV�E')
    else
        DebugClient('?? PROTECTION D�SACTIV�E')
        isNearRankedPed = false
    end
end

-- ========================================
-- THREAD 1/7: PROTECTION + CONTROLES (FIX PERFORMANCE v2)
-- ========================================

-- FIX: Tables de controles precalculees (evite les appels repetes)
local _DisableControlAction = DisableControlAction
local CONTROLS_MATCH_BASE = {38, 51, 46, 23, 75, 44, 74, 244, 323, 170, 243}
local CONTROLS_MATCH_NOSHOOT = {24, 25, 257, 140, 141, 142}
local CONTROLS_MATCH_WEAPONS = {14, 15, 16, 17, 37, 157, 158, 159, 160, 161, 162, 163, 164, 165}
local CONTROLS_QUEUE_FAR = {38, 51, 46, 23, 75, 44, 74, 86, 244, 323, 170, 243}
local CONTROLS_QUEUE_NEAR = {44, 74, 75, 86, 244, 323, 170, 243, 23}

CreateThread(function()
    while not pedSpawned do
        _Wait(100)
    end

    DebugSuccess('Thread protection + controles demarre (OPTIMISE v2)')

    -- Cache les tailles des tables
    local nMatchBase = #CONTROLS_MATCH_BASE
    local nMatchNoShoot = #CONTROLS_MATCH_NOSHOOT
    local nMatchWeapons = #CONTROLS_MATCH_WEAPONS
    local nQueueFar = #CONTROLS_QUEUE_FAR
    local nQueueNear = #CONTROLS_QUEUE_NEAR

    while true do
        if not isProtectedFromOtherScripts then
            _Wait(1000)
            isNearRankedPed = false
        else
            _Wait(0)

            local distance = cachedPedDistance
            isNearRankedPed = (distance <= PERF.pedInteractDistance)

            if IsSpectating and IsSpectating() then
                -- En mode spectateur, les controles sont geres par spectator.lua
            elseif IsInMatch() then
                -- FIX: Boucles optimisees au lieu d'appels individuels
                for i = 1, nMatchBase do
                    _DisableControlAction(0, CONTROLS_MATCH_BASE[i], true)
                end

                if not CanShoot() then
                    for i = 1, nMatchNoShoot do
                        _DisableControlAction(0, CONTROLS_MATCH_NOSHOOT[i], true)
                    end
                end

                for i = 1, nMatchWeapons do
                    _DisableControlAction(0, CONTROLS_MATCH_WEAPONS[i], true)
                end

            elseif distance > PERF.pedInteractDistance then
                for i = 1, nQueueFar do
                    _DisableControlAction(0, CONTROLS_QUEUE_FAR[i], true)
                end

                if IsDisabledControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 51) then
                    exports['brutal_notify']:SendAlert('PVP Gunfight', 'Retournez au PED Ranked pour annuler', 3000, 'error')
                end
            else
                for i = 1, nQueueNear do
                    _DisableControlAction(0, CONTROLS_QUEUE_NEAR[i], true)
                end
            end
        end
    end
end)

-- ========================================
-- ? THREAD 2/7: HEARTBEAT + POSITION + STAMINA (UNIFI�)
-- ========================================
CreateThread(function()
    DebugSuccess('Thread heartbeat + position + stamina d�marr� (UNIFI�)')
    
    local lastHeartbeat = 0
    local lastPositionCheck = 0
    
    while true do
        local now = _GetGameTimer()
        local inMatch = IsInMatch()
        local inQueue = IsInQueue()
        
        if (inMatch or inQueue) and (now - lastHeartbeat >= PERF.heartbeatInterval) then
            lastHeartbeat = now
            TriggerServerEvent('pvp:heartbeat')
        end
        
        if inMatch and not (IsSpectating and IsSpectating()) and (now - lastPositionCheck >= PERF.positionCheckInterval) then
            lastPositionCheck = now
            
            local currentArena = GetCurrentArena()
            if currentArena and Config.Arenas[currentArena] then
                local arena = Config.Arenas[currentArena]
                local playerCoords = GetCachedCoords()
                
                if arena.zoneCenter and arena.zoneRadius then
                    local dx = playerCoords.x - arena.zoneCenter.x
                    local dy = playerCoords.y - arena.zoneCenter.y
                    local dz = playerCoords.z - arena.zoneCenter.z
                    local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
                    
                    if distance > arena.zoneRadius then
                        DebugWarn('?? JOUEUR HORS ZONE')
                        TriggerServerEvent('pvp:playerOutOfArena')
                    end
                end
            end
        end
        
        if inMatch and not (IsSpectating and IsSpectating()) then
            _RestorePlayerStamina(PlayerId(), 100.0)
            _Wait(150)
        else
            _Wait(500)
        end
    end
end)

-- ========================================
-- ? THREAD 3/7: V�RIFICATION ARMES (OPTIMIS�)
-- ========================================
CreateThread(function()
    DebugSuccess('Thread v�rification armes d�marr�')
    
    while true do
        if not IsInMatch() then
            _Wait(2000)
            weaponCheckAttempts = 0
        elseif IsMatchDead() then
            _Wait(1000)
        elseif not CanShoot() then
            _Wait(500)
        elseif IsSpectating and IsSpectating() then
            _Wait(1000)
        else
            local now = _GetGameTimer()
            
            if now - lastWeaponCheckTime >= PERF.weaponCheckInterval then
                lastWeaponCheckTime = now
                
                local ped = GetCachedPed()
                local hasWeapon, weaponHash = GetCurrentPedWeapon(ped, true)
                
                if not hasWeapon or weaponHash ~= WEAPON_CONFIG.hash then
                    weaponCheckAttempts = weaponCheckAttempts + 1
                    
                    DebugWarn('?? ARME MANQUANTE (Tentative %d/%d)', weaponCheckAttempts, MAX_WEAPON_CHECK_ATTEMPTS)
                    
                    if weaponCheckAttempts >= MAX_WEAPON_CHECK_ATTEMPTS then
                        DebugError('? �CHEC apr�s %d tentatives', MAX_WEAPON_CHECK_ATTEMPTS)
                        TriggerServerEvent('pvp:weaponCheckFailed')
                        exports['brutal_notify']:SendAlert('PVP Gunfight', 'Probléme arme - Admin contacté', 5000, 'warning')
                        weaponCheckAttempts = 0
                    else
                        ForceWeaponCheck(ped)
                    end
                else
                    weaponCheckAttempts = 0
                end
            end
            
            _Wait(100)
        end
    end
end)

-- ========================================
-- ? THREAD 4/7: DISTANCE PED (LOGIQUE)
-- ========================================
CreateThread(function()
    while not pedSpawned do
        _Wait(1000)
    end
    
    DebugSuccess('Thread distance PED d�marr�')
    
    while true do
        local playerCoords = GetCachedCoords()
        local dx = playerCoords.x - pedCoords.x
        local dy = playerCoords.y - pedCoords.y
        local dz = playerCoords.z - pedCoords.z
        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
        
        cachedPedDistance = distance
        isNearPed = distance <= PERF.pedInteractDistance
        
        if distance > PERF.pedDrawDistance then
            _Wait(PERF.pedDistanceCheckIdle)
        elseif distance > PERF.pedInteractDistance then
            _Wait(200)
        else
            _Wait(PERF.pedDistanceCheckClose)
        end
    end
end)

-- ========================================
-- FONCTION: DESSINER TEXTE 3D
-- ========================================
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = #(vector3(px, py, pz) - vector3(x, y, z))

    if onScreen then
        local scale = (1 / dist) * 2
        local fov = (1 / GetGameplayCamFov()) * 100
        local scaleMultiplier = scale * fov

        SetTextScale(0.0 * scaleMultiplier, 0.85 * scaleMultiplier)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 215, 0, 255) -- Couleur dorée
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- ========================================
-- THREAD 5/7: AFFICHAGE MARKER + HELP TEXT (FIX PERFORMANCE v2)
-- ========================================
CreateThread(function()
    while not pedSpawned do
        _Wait(1000)
    end

    DebugSuccess('Thread marker + help text demarre (OPTIMISE)')

    local markerCoords = vector3(Config.PedLocation.coords.x, Config.PedLocation.coords.y, Config.PedLocation.coords.z)
    local textUIShown = false
    local drawMarkerEnabled = Config.DrawMarker  -- Cache la config

    while true do
        if not isNearPed then
            if textUIShown then
                exports['brutal_textui']:Close()
                textUIShown = false
            end
            _Wait(500)
        elseif drawMarkerEnabled then
            -- FIX: Wait(0) seulement si DrawMarker est active
            _Wait(0)

            if not IsInMatch() and not IsInQueue() then
                if not textUIShown then
                    exports['brutal_textui']:Open('[E] Ouvrir le menu PVP', 'blue', 1, 'right')
                    textUIShown = true
                end
                DrawMarker(2, markerCoords.x, markerCoords.y, markerCoords.z + 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.3, 0.3, 0.3, 255, 0, 0, 200, true, true, 2, false, nil, nil, false)
            else
                if textUIShown then
                    exports['brutal_textui']:Close()
                    textUIShown = false
                end
            end
        else
            -- FIX: Sans DrawMarker, on peut utiliser Wait(100) au lieu de Wait(0)
            _Wait(100)

            if not IsInMatch() and not IsInQueue() then
                if not textUIShown then
                    exports['brutal_textui']:Open('[E] Ouvrir le menu PVP', 'blue', 1, 'right')
                    textUIShown = true
                end
            else
                if textUIShown then
                    exports['brutal_textui']:Close()
                    textUIShown = false
                end
            end
        end
    end
end)

-- ========================================
-- THREAD: TEXTE 3D [ RANKED ] AU-DESSUS DU PED
-- ========================================
CreateThread(function()
    while not pedSpawned do
        _Wait(1000)
    end

    DebugSuccess('Thread texte RANKED demarre')

    local rankedTextHeight = 1.3  -- Hauteur du texte au-dessus du PED
    local rankedTextDistance = 15.0  -- Distance max pour voir le texte

    while true do
        if cachedPedDistance <= rankedTextDistance then
            _Wait(0)
            DrawText3D(pedCoords.x, pedCoords.y, pedCoords.z + rankedTextHeight, "[ RANKED ]")
        else
            _Wait(500)
        end
    end
end)

-- ========================================
-- THREAD 6/7: INTERACTION PED (FIX PERFORMANCE v3)
-- ========================================
CreateThread(function()
    while not pedSpawned do
        _Wait(1000)
    end

    DebugSuccess('Thread interaction PED demarre (OPTIMISE v3)')

    while true do
        local distance = cachedPedDistance

        if distance > PERF.pedDrawDistance then
            -- Loin du PED: attendre longtemps
            _Wait(500)
        elseif distance > PERF.pedInteractDistance then
            -- Proche mais pas interactif: attendre moins
            _Wait(100)
        else
            -- FIX: Wait(0) obligatoire pour detecter IsControlJustReleased
            _Wait(0)

            local ePressed = _IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38)

            if ePressed then
                if IsInMatch() then
                    exports['brutal_notify']:SendAlert('PVP Gunfight', 'Impossible d\'ouvrir l\'interface en match!', 3000, 'error')
                else
                    local canInteract = true

                    if GetResourceState('catmouse_racing') == 'started' then
                        local success, result = pcall(function()
                            return exports['catmouse_racing']:CanPlayerInteract()
                        end)

                        if success and result == false then
                            canInteract = false
                            exports['brutal_notify']:SendAlert('PVP Gunfight', 'Vous etes en recherche CatMouse Racing!', 3000, 'error')
                        end
                    end

                    if canInteract then
                        exports['brutal_textui']:Close()
                        DebugClient('Ouverture UI autorisee')
                        OpenUI()
                        _Wait(200)
                    end
                end
            end
        end
    end
end)

-- ========================================
-- ? THREAD 7/7: RELATIONS �QUIPE
-- ========================================
CreateThread(function()
    
    while true do
        if not IsInMatch() then
            _Wait(2000)
        elseif IsSpectating and IsSpectating() then
            _Wait(1000)
        else
            _Wait(PERF.relationCheckInterval)
            
            local teammates = GetTeammates()
            
            if teammates and #teammates > 0 then
                local myPed = GetCachedPed()
                _SetCanAttackFriendly(myPed, false, false)
                
                local relationshipGroup = _GetHashKey('PLAYER')
                _SetPedRelationshipGroupHash(myPed, relationshipGroup)
                
                for _, teammateServerId in ipairs(teammates) do
                    local teammatePlayerIndex = _GetPlayerFromServerId(teammateServerId)
                    
                    if teammatePlayerIndex and teammatePlayerIndex ~= -1 and _NetworkIsPlayerActive(teammatePlayerIndex) then
                        local teammatePed = _GetPlayerPed(teammatePlayerIndex)
                        
                        if teammatePed and DoesEntityExist(teammatePed) then
                            _SetPedRelationshipGroupHash(teammatePed, relationshipGroup)
                            _SetCanAttackFriendly(teammatePed, false, false)
                            SetRelationshipBetweenGroups(1, relationshipGroup, relationshipGroup)
                        end
                    end
                end
            end
        end
    end
end)

-- ========================================
-- THREAD: TIMER DE RECHERCHE
-- ========================================
CreateThread(function()
    
    while true do
        _Wait(1000)
        
        if IsInQueue() then
            local elapsed = math.floor((_GetGameTimer() - GetQueueStartTime()) / 1000)
            SendNUIMessage({
                action = 'updateSearchTimer',
                elapsed = elapsed
            })
        end
    end
end)

-- ========================================
-- ? NOUVEAU: EVENT FANCA_ANTITANK - CAPTURE KILLER
-- ========================================
AddEventHandler('pvp:antitankDeathDetected', function(killerId, weaponHash, isHeadshot)
    if not IsInMatch() then return end
    if IsMatchDead() then return end
    if IsSpectating and IsSpectating() then return end
    
    DebugClient('[ANTITANK] ?? Mort d�tect�e - Killer: %s, Weapon: %s, Headshot: %s', 
        tostring(killerId), tostring(weaponHash), tostring(isHeadshot))
    
    -- ? Stocker les infos du killer
    DeathDetection.lastKillerId = killerId
    DeathDetection.lastWeaponHash = weaponHash
    DeathDetection.lastIsHeadshot = isHeadshot
    
    -- ? Envoyer imm�diatement au serveur
    SendDeathToServer(killerId, weaponHash, isHeadshot)
end)

-- ========================================
-- ? EVENT: gameEventTriggered - CAPTURE D�G�TS ET MORT
-- ========================================
AddEventHandler('gameEventTriggered', function(eventName, eventData)
    if eventName ~= 'CEventNetworkEntityDamage' then return end
    if not IsInMatch() then return end
    if IsSpectating and IsSpectating() then return end
    
    local victim = eventData[1]
    local attacker = eventData[2]
    local victimDied = eventData[4] == 1
    local weaponHash = eventData[7]
    
    -- ? Seulement si c'est nous la victime
    if victim ~= _PlayerPedId() then return end
    
    -- ? Capturer l'attaquant pour r�f�rence future
    if attacker and attacker ~= 0 and attacker ~= victim then
        if _IsPedAPlayer(attacker) then
            local killerIndex = _NetworkGetPlayerIndexFromPed(attacker)
            if killerIndex and killerIndex ~= -1 then
                local killerId = _GetPlayerServerId(killerIndex)
                if killerId and killerId > 0 then
                    DeathDetection.lastKillerId = killerId
                    DeathDetection.lastWeaponHash = weaponHash
                    DebugClient('[EVENT] ?? Attaquant captur�: %d', killerId)
                end
            end
        end
    end
    
    -- ? Si on est mort
    if victimDied and not IsMatchDead() then
        DebugClient('[EVENT] ?? Mort d�tect�e via gameEventTriggered')
        
        -- R�cup�rer le meilleur killer disponible
        local killerId, finalWeapon, isHeadshot = GetBestKillerInfo()
        
        -- Utiliser le weaponHash de l'event si pas d'autre source
        if not finalWeapon then
            finalWeapon = weaponHash
        end
        
        SendDeathToServer(killerId, finalWeapon, isHeadshot)
    end
end)

-- ========================================
-- ? THREAD CRITIQUE: D�TECTION MORT FIABLE (100ms)
-- ========================================
CreateThread(function()
    DebugSuccess('Thread d�tection mort FIABLE d�marr� (100ms)')
    
    while true do
        if not IsInMatch() then
            _Wait(1000)
            ResetDeathState()
        elseif IsMatchDead() then
            _Wait(500)
        elseif IsSpectating and IsSpectating() then
            _Wait(1000)
        else
            _Wait(PERF.deathCheckInterval)
            
            local ped = _PlayerPedId()
            local currentHealth = _GetEntityHealth(ped)
            local isDead = _IsEntityDead(ped)
            
            -- ? V�rification multi-crit�res
            if isDead or currentHealth <= 0 then
                if not DeathDetection.deathSentToServer then
                    DebugClient('[THREAD] ?? MORT D�TECT�E - Health: %d, IsDead: %s', 
                        currentHealth, tostring(isDead))
                    
                    -- R�cup�rer le meilleur killer disponible
                    local killerId, weaponHash, isHeadshot = GetBestKillerInfo()
                    
                    SendDeathToServer(killerId, weaponHash, isHeadshot)
                end
            else
                -- ? Mise � jour health pour tracking
                DeathDetection.lastHealthCheck = currentHealth
            end
        end
    end
end)

RegisterNetEvent('pvp:updateQueueStats', function(stats)
    SendNUIMessage({
        action = 'updateQueueStats',
        stats = stats
    })
end)

-- ========================================
-- FONCTIONS UI
-- ========================================
function OpenUI()
    if uiOpen then
        DebugClient('UI d�j� ouverte - Fermeture puis r�ouverture')
        CloseUI()
        _Wait(100)
    end
    
    DebugClient('Ouverture UI')
    SetNuiFocus(true, true)
    
    if IsInQueue() then
        SendNUIMessage({ 
            action = 'openUI',
            isSearching = true
        })
        DebugClient('UI ouverte en mode recherche')
    else
        SendNUIMessage({ action = 'openUI' })
    end
    
    uiOpen = true
    
    ESX.TriggerServerCallback('pvp:getQueueStats', function(stats)
        SendNUIMessage({
            action = 'updateQueueStats',
            stats = stats
        })
    end)
end

function CloseUI()
    if not uiOpen then return end
    
    DebugClient('Fermeture UI')
    SendNUIMessage({ action = 'closeUI' })
    _Wait(100)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    uiOpen = false
end

-- ========================================
-- EVENT FORCE CLEANUP (FIX FREEZE v2)
-- ========================================
RegisterNetEvent('pvp:forceCleanup', function()
    DebugClient('[CLEANUP] >> EVENT forceCleanup recu - NETTOYAGE COMPLET')

    -- FIX 1: Arreter spectateur EN PREMIER
    if IsSpectating and IsSpectating() then
        StopSpectating()
        _Wait(100)
    end

    -- FIX 2: UNFREEZE IMMEDIAT - C'EST CRITIQUE!
    local ped = _PlayerPedId()
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    ClearPedTasks(ped)

    -- FIX 3: Reset des exports
    if exports['pvp_gunfight'] and exports['pvp_gunfight'].ResetAllMatchState then
        exports['pvp_gunfight']:ResetAllMatchState()
    end

    if exports['pvp_gunfight'] and exports['pvp_gunfight'].DisableDamageSystem then
        exports['pvp_gunfight']:DisableDamageSystem()
    end

    -- FIX 4: Desactiver zones et HUD
    TriggerEvent('pvp:disableZones')
    TriggerEvent('pvp:disableTeammateHUD')

    -- FIX 5: Fermer UI si ouverte
    if uiOpen then
        CloseUI()
    end

    SendNUIMessage({ action = 'hideScoreHUD' })

    -- FIX 6: Reset complet des etats
    ResetMatchState()
    ResetDeathState()

    -- FIX 7: Double unfreeze pour garantir
    ped = _PlayerPedId()
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    ClearPedTasks(ped)

    -- FIX 8: Thread de securite pour garantir le unfreeze
    CreateThread(function()
        for i = 1, 5 do
            _Wait(100)
            local currentPed = _PlayerPedId()
            _FreezeEntityPosition(currentPed, false)
            SetPlayerControl(PlayerId(), true, 0)
        end
    end)

    DebugClient('[CLEANUP] >> Nettoyage force termine - Joueur debloque')
end)

-- ========================================
-- NUI CALLBACKS
-- ========================================
RegisterNUICallback('closeUI', function(data, cb)
    cb('ok')
    _Wait(50)
    CloseUI()
end)

RegisterNetEvent('pvp:forceCloseUI', function()
    CloseUI()
end)

RegisterNUICallback('joinQueue', function(data, cb)
    cb('ok')
    TriggerServerEvent('pvp:joinQueue', data.mode)
end)

RegisterNUICallback('getStats', function(data, cb)
    ESX.TriggerServerCallback('pvp:getPlayerStats', function(stats)
        cb(stats)
    end)
end)

RegisterNUICallback('getPlayerStatsByMode', function(data, cb)
    ESX.TriggerServerCallback('pvp:getPlayerStatsByMode', function(stats)
        cb(stats)
    end, data.mode or '1v1')
end)

RegisterNUICallback('getPlayerAllModeStats', function(data, cb)
    ESX.TriggerServerCallback('pvp:getPlayerAllModeStats', function(allStats)
        cb(allStats)
    end)
end)

RegisterNUICallback('getLeaderboard', function(data, cb)
    ESX.TriggerServerCallback('pvp:getLeaderboard', function(leaderboard)
        cb(leaderboard)
    end)
end)

RegisterNUICallback('getLeaderboardByMode', function(data, cb)
    ESX.TriggerServerCallback('pvp:getLeaderboardByMode', function(leaderboard)
        cb(leaderboard)
    end, data.mode or '1v1')
end)

RegisterNUICallback('invitePlayer', function(data, cb)
    cb('ok')
    TriggerServerEvent('pvp:inviteToGroup', tonumber(data.targetId))
end)

RegisterNUICallback('leaveGroup', function(data, cb)
    cb('ok')
    TriggerServerEvent('pvp:leaveGroup')
end)

RegisterNUICallback('kickPlayer', function(data, cb)
    cb('ok')
    TriggerServerEvent('pvp:kickFromGroup', tonumber(data.targetId))
end)

RegisterNUICallback('toggleReady', function(data, cb)
    cb('ok')
    TriggerServerEvent('pvp:toggleReady')
end)

RegisterNUICallback('getGroupInfo', function(data, cb)
    ESX.TriggerServerCallback('pvp:getGroupInfo', function(groupInfo)
        cb(groupInfo)
    end)
end)

RegisterNUICallback('acceptInvite', function(data, cb)
    cb('ok')
    TriggerServerEvent('pvp:acceptInvite', tonumber(data.inviterId))
end)

RegisterNUICallback('declineInvite', function(data, cb)
    cb('ok')
end)

RegisterNUICallback('cancelSearch', function(data, cb)
    cb('ok')
    TriggerServerEvent('pvp:cancelSearch')
end)

-- ========================================
-- EVENTS R�SEAU - GROUPE
-- ========================================
RegisterNetEvent('pvp:updateGroupUI', function(groupData)
    SendNUIMessage({
        action = 'updateGroup',
        group = groupData
    })
end)

RegisterNetEvent('pvp:receiveInvite', function(inviterName, inviterId)
    exports['brutal_notify']:SendAlert('Invitation Groupe', inviterName .. ' vous invite!', 5000, 'info')
    SendNUIMessage({
        action = 'showInvite',
        inviterName = inviterName,
        inviterId = inviterId
    })
end)

-- ========================================
-- EVENTS R�SEAU - MATCHMAKING
-- ========================================
RegisterNetEvent('pvp:searchStarted', function(mode)
    SetInQueue(true)
    SetQueueStartTime(_GetGameTimer())
    SetScriptProtection(true)
    
    SendNUIMessage({
        action = 'searchStarted',
        mode = mode
    })
end)

RegisterNetEvent('pvp:matchFound', function()
    SetInQueue(false)
    SetInMatch(true)
    SetMatchDead(false)
    SetScriptProtection(true)
    
    -- ? Reset �tat mort pour nouveau match
    ResetDeathState()
    
    SendNUIMessage({ action = 'closeInvitationsPanel' })
    
    if uiOpen then
        CloseUI()
    end
    
    SendNUIMessage({ action = 'matchFound' })
end)

RegisterNetEvent('pvp:searchCancelled', function()
    SetInQueue(false)
    SetScriptProtection(false)
    
    SendNUIMessage({ action = 'searchCancelled' })
end)

RegisterNetEvent('pvp:setTeammates', function(teammateIds)
    SetTeammates(teammateIds or {})
end)

-- ========================================
-- EVENTS R�SEAU - T�L�PORTATION
-- ========================================
RegisterNetEvent('pvp:teleportToSpawn', function(spawn, team, matchId, arenaKey)
    if IsSpectating and IsSpectating() then
        StopSpectating()
    end
    
    SetPlayerTeam(team)
    SetMatchDead(false)
    SetCurrentArena(arenaKey)
    
    -- ? Reset �tat mort
    ResetDeathState()
    
    local ped = GetCachedPed()
    
    if _IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)
        _Wait(100)
        ped = _PlayerPedId()
    end
    
    _DoScreenFadeOut(500)
    _Wait(500)
    
    _SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    _SetEntityHeading(ped, spawn.w)
    _FreezeEntityPosition(ped, true)
    _SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    
    GiveMatchWeapons(ped)
    
    exports['pvp_gunfight']:EnableDamageSystem()
    
    _Wait(500)
    _DoScreenFadeIn(500)
    
    local teamColor = team == 'team1' and 'info' or 'error'
    local teamName = team == 'team1' and 'Team A (Bleu)' or 'Team B (Rouge)'
    exports['brutal_notify']:SendAlert('PVP Match', 'Vous étes dans la ' .. teamName, 4000, teamColor)
    
    if arenaKey then
        TriggerEvent('pvp:setArenaZone', arenaKey)
        TriggerEvent('pvp:enableZones')
    end
    
    local teammates = GetTeammates()
    if #teammates > 0 then
        TriggerEvent('pvp:enableTeammateHUD', teammates)
    end
    
    PostSpawnWeaponCheck()
end)

RegisterNetEvent('pvp:respawnPlayer', function(spawn)
    if IsSpectating and IsSpectating() then
        StopSpectating()
    end
    
    SetMatchDead(false)
    
    -- ? Reset �tat mort pour nouveau round
    ResetDeathState()
    
    local ped = GetCachedPed()
    
    if _IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)
        _Wait(100)
        ped = _PlayerPedId()
    end
    
    _DoScreenFadeOut(300)
    _Wait(300)
    
    _SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    _SetEntityHeading(ped, spawn.w)
    _SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    
    GiveMatchWeapons(ped)
    
    -- ? NOUVEAU: Redonner armure au respawn si activ�
    if Config.Armor.enabled and Config.Armor.giveOnRespawn then
        GiveArmor(ped)
    end
    
    _Wait(300)
    _DoScreenFadeIn(300)
    
    PostSpawnWeaponCheck()
end)

RegisterNetEvent('pvp:freezePlayer', function()
    _FreezeEntityPosition(GetCachedPed(), true)
end)

RegisterNetEvent('pvp:forceTeleportToArena', function(spawn)
    local ped = GetCachedPed()
    
    _DoScreenFadeOut(300)
    _Wait(300)
    
    _SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    _SetEntityHeading(ped, spawn.w)
    
    _Wait(300)
    _DoScreenFadeIn(300)
    
    exports['brutal_notify']:SendAlert('PVP Gunfight', 'Retéléporté à l\'aréne!', 3000, 'warning')
end)

-- ========================================
-- EVENT: TELEPORTATION AU POINT DE SORTIE (FIX FREEZE v2)
-- ========================================
RegisterNetEvent('pvp:teleportToExit', function(exitPoint)
    DebugClient('[EXIT] >> TELEPORTATION POINT DE SORTIE - DEBUT')

    -- FIX 1: Arreter spectateur EN PREMIER
    if IsSpectating and IsSpectating() then
        DebugClient('[EXIT] Arret mode spectateur')
        StopSpectating()
        _Wait(100)
    end

    -- FIX 2: Reset complet de l'etat match AVANT tout
    ResetMatchState()
    SetCanShoot(false)
    SetMatchDead(false)
    SetTeammates({})

    local ped = _PlayerPedId()

    -- FIX 3: Forcer unfreeze AVANT resurrection
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    _Wait(50)

    -- FIX 4: Sortir du vehicule si necessaire
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        _Wait(500)
        ped = _PlayerPedId()
    end

    -- FIX 5: Resurrection si mort
    if _IsEntityDead(ped) then
        DebugClient('[EXIT] Resurrection joueur mort')
        NetworkResurrectLocalPlayer(exitPoint.x, exitPoint.y, exitPoint.z, exitPoint.w, true, false)
        _Wait(200)
        ped = _PlayerPedId()
        _FreezeEntityPosition(ped, false)
        SetPlayerControl(PlayerId(), true, 0)
        _Wait(100)
    end

    _DoScreenFadeOut(500)
    _Wait(500)

    -- FIX 6: Re-obtenir ped apres fade
    ped = _PlayerPedId()

    -- FIX 7: Forcer unfreeze AVANT teleportation
    _FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    SetPlayerControl(PlayerId(), true, 0)
    _Wait(50)

    -- FIX 8: Teleportation avec Z+0.5 pour eviter de tomber sous la map
    _SetEntityCoords(ped, exitPoint.x, exitPoint.y, exitPoint.z + 0.5, false, false, false, true)
    _Wait(100)
    _SetEntityHeading(ped, exitPoint.w)

    -- FIX 9: Nettoyage complet du personnage
    _SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    RemoveAllPedWeapons(ped, true)
    RemoveAllArmor(ped)

    -- FIX 10: Triple unfreeze avec delais pour garantir
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    _Wait(100)
    _FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    _Wait(100)

    -- FIX 11: Dernier unfreeze et verifications
    ped = _PlayerPedId()
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)

    _DoScreenFadeIn(500)

    exports['brutal_notify']:SendAlert('Match Termine', 'Vous etes au point de sortie', 4000, 'success')

    -- FIX 12: Thread de securite pour garantir le unfreeze (2 secondes)
    CreateThread(function()
        for i = 1, 10 do
            _Wait(200)
            local currentPed = _PlayerPedId()
            _FreezeEntityPosition(currentPed, false)
            SetPlayerControl(PlayerId(), true, 0)
        end
        DebugClient('[EXIT] >> TELEPORTATION TERMINEE - Joueur debloque')
    end)
end)

-- ========================================
-- EVENTS R�SEAU - ROUNDS
-- ========================================
RegisterNetEvent('pvp:roundStart', function(roundNumber)
    if IsSpectating and IsSpectating() then
        StopSpectating()
    end
    
    local ped = GetCachedPed()
    _FreezeEntityPosition(ped, true)
    SetCanShoot(false)
    SetMatchDead(false)
    
    -- ? Reset �tat mort pour nouveau round
    ResetDeathState()
    
    _PlaySoundFrontend(-1, "GO", "HUD_MINI_GAME_SOUNDSET", true)
    
    _Wait(500)
    
    _FreezeEntityPosition(ped, false)
    SetCanShoot(true)
end)

RegisterNetEvent('pvp:roundEnd', function(winningTeam, score, serverPlayerTeam, isVictory)
    SetCanShoot(false)
    
    local actualIsVictory = isVictory
    if actualIsVictory == nil then
        local teamToUse = serverPlayerTeam or GetPlayerTeam()
        actualIsVictory = (winningTeam == teamToUse)
    end
    
    SendNUIMessage({
        action = 'showRoundEnd',
        winner = winningTeam,
        score = score,
        playerTeam = serverPlayerTeam or GetPlayerTeam(),
        isVictory = actualIsVictory
    })
    
    _PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
end)

RegisterNetEvent('pvp:updateScore', function(score, round)
    SendNUIMessage({
        action = 'updateScore',
        score = score,
        round = round
    })
end)

RegisterNetEvent('pvp:showScoreHUD', function(score, round)
    SendNUIMessage({
        action = 'showScoreHUD',
        score = score,
        round = round
    })
end)

RegisterNetEvent('pvp:hideScoreHUD', function()
    SendNUIMessage({ action = 'hideScoreHUD' })
end)

RegisterNetEvent('pvp:showKillfeed', function(killerName, victimName, weapon, isHeadshot)
    SendNUIMessage({
        action = 'showKillfeed',
        killerName = killerName,
        victimName = victimName,
        weapon = weapon,
        isHeadshot = isHeadshot
    })
end)

-- ========================================
-- EVENTS RESEAU - FIN MATCH (FIX FREEZE v2)
-- ========================================
RegisterNetEvent('pvp:matchEnd', function(victory, score, serverPlayerTeam)
    DebugClient('[MATCHEND] >> Fin de match - Debut nettoyage')

    -- FIX 1: Arreter spectateur EN PREMIER
    if IsSpectating and IsSpectating() then
        StopSpectating()
        _Wait(100)
    end

    -- FIX 2: Reset complet des etats
    SetInMatch(false)
    SetCanShoot(false)
    SetMatchDead(false)
    SetTeammates({})
    SetScriptProtection(false)

    -- FIX 3: Desactiver zones et HUD
    TriggerEvent('pvp:disableZones')
    TriggerEvent('pvp:disableTeammateHUD')

    -- FIX 4: UNFREEZE IMMEDIAT pour eviter le blocage
    local ped = _PlayerPedId()
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    ClearPedTasks(ped)

    SendNUIMessage({
        action = 'showMatchEnd',
        victory = victory,
        score = score,
        playerTeam = serverPlayerTeam or GetPlayerTeam()
    })

    if victory then
        _PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS", true)
    else
        _PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
    end

    SetPlayerTeam(nil)
    ResetDeathState()

    -- FIX 5: Thread de securite pour garantir le unfreeze
    CreateThread(function()
        for i = 1, 5 do
            _Wait(200)
            local currentPed = _PlayerPedId()
            _FreezeEntityPosition(currentPed, false)
            SetPlayerControl(PlayerId(), true, 0)
        end
    end)

    DebugClient('[MATCHEND] >> Etat match reinitialise - Teleportation imminente')
end)

RegisterNetEvent('pvp:forceReturnToLobby', function()
    DebugClient('[LOBBY] >> Retour force au lobby - DEBUT')

    -- FIX 1: Arreter spectateur EN PREMIER
    if IsSpectating and IsSpectating() then
        StopSpectating()
        _Wait(100)
    end

    -- FIX 2: Reset complet des etats
    ResetMatchState()
    SetScriptProtection(false)
    ResetDeathState()

    TriggerEvent('pvp:disableZones')
    TriggerEvent('pvp:disableTeammateHUD')

    local ped = _PlayerPedId()

    -- FIX 3: Unfreeze AVANT resurrection
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    _Wait(50)

    -- FIX 4: Sortir du vehicule si necessaire
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        _Wait(500)
        ped = _PlayerPedId()
    end

    -- FIX 5: Resurrection si mort
    if _IsEntityDead(ped) then
        local coords = _GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
        _Wait(200)
        ped = _PlayerPedId()
        _FreezeEntityPosition(ped, false)
        SetPlayerControl(PlayerId(), true, 0)
        _Wait(100)
    end

    _DoScreenFadeOut(500)
    _Wait(500)

    -- FIX 6: Re-obtenir ped apres fade
    ped = _PlayerPedId()

    -- FIX 7: Unfreeze AVANT teleportation
    _FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    SetPlayerControl(PlayerId(), true, 0)
    _Wait(50)

    -- FIX 8: Teleportation avec Z+0.5
    _SetEntityCoords(ped, Config.PedLocation.coords.x, Config.PedLocation.coords.y, Config.PedLocation.coords.z + 0.5, false, false, false, true)
    _Wait(100)
    _SetEntityHeading(ped, Config.PedLocation.coords.w)

    -- FIX 9: Nettoyage complet
    _SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    ResetPedVisibleDamage(ped)
    RemoveAllPedWeapons(ped, true)
    RemoveAllArmor(ped)

    -- FIX 10: Triple unfreeze
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    _Wait(100)
    _FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    _Wait(100)

    -- FIX 11: Dernier unfreeze
    ped = _PlayerPedId()
    _FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)

    _DoScreenFadeIn(500)

    -- FIX 12: Thread de securite (2 secondes)
    CreateThread(function()
        for i = 1, 10 do
            _Wait(200)
            local currentPed = _PlayerPedId()
            _FreezeEntityPosition(currentPed, false)
            SetPlayerControl(PlayerId(), true, 0)
        end
        DebugClient('[LOBBY] >> Retour force termine - Joueur debloque')
    end)
end)

RegisterNetEvent('pvp:updateQueueStats', function(stats)
    SendNUIMessage({
        action = 'updateQueueStats',
        stats = stats
    })
end)

-- ========================================
-- CLEANUP
-- ========================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if IsSpectating and IsSpectating() then
        StopSpectating()
    end
    
    SetScriptProtection(false)
    
    exports['brutal_textui']:Close()
    
    if IsInMatch() or IsInQueue() then
        ResetMatchState()
        TriggerEvent('pvp:disableZones')
        TriggerEvent('pvp:disableTeammateHUD')
        
        local ped = _PlayerPedId()
        
        if _IsEntityDead(ped) then
            local coords = _GetEntityCoords(ped)
            NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, 0.0, true, false)
            ped = _PlayerPedId()
        end
        
        _SetEntityCoords(ped, Config.PedLocation.coords.x, Config.PedLocation.coords.y, Config.PedLocation.coords.z, false, false, false, false)
        _SetEntityHeading(ped, Config.PedLocation.coords.w)
        _SetEntityHealth(ped, 200)
        ClearPedBloodDamage(ped)
        ResetPedVisibleDamage(ped)
        RemoveAllPedWeapons(ped, true)
        RemoveAllArmor(ped)
        _FreezeEntityPosition(ped, false)
        
        if IsScreenFadedOut() then
            _DoScreenFadeIn(0)
        end
    end
    
    if DoesEntityExist(pedEntity) then
        DeleteEntity(pedEntity)
    end
    
    SetNuiFocus(false, false)
end)

-- ========================================
-- SPAWN PED
-- ========================================
local function SpawnPed()
    if pedSpawned then return end
    
    LOBBY_COORDS = {
        x = Config.PedLocation.coords.x,
        y = Config.PedLocation.coords.y,
        z = Config.PedLocation.coords.z,
        w = Config.PedLocation.coords.w
    }
    
    local pedModel = _GetHashKey(Config.PedLocation.model)
    
    RequestModel(pedModel)
    local timeout = 0
    while not HasModelLoaded(pedModel) and timeout < 50 do
        _Wait(100)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(pedModel) then
        DebugError('Impossible charger mod�le PED')
        return
    end
    
    pedEntity = CreatePed(4, pedModel, 
        Config.PedLocation.coords.x, 
        Config.PedLocation.coords.y, 
        Config.PedLocation.coords.z - 1.0, 
        Config.PedLocation.coords.w, false, true)
    
    SetEntityAsMissionEntity(pedEntity, true, true)
    SetPedFleeAttributes(pedEntity, 0, 0)
    SetPedDiesWhenInjured(pedEntity, false)
    SetPedKeepTask(pedEntity, true)
    SetBlockingOfNonTemporaryEvents(pedEntity, true)
    SetEntityInvincible(pedEntity, true)
    _FreezeEntityPosition(pedEntity, true)
    
    if Config.PedLocation.scenario then
        TaskStartScenarioInPlace(pedEntity, Config.PedLocation.scenario, 0, true)
    end
    
    pedSpawned = true
    pedCoords = vector3(Config.PedLocation.coords.x, Config.PedLocation.coords.y, Config.PedLocation.coords.z)
    
    DebugSuccess('PED spawn�')
end

CreateThread(function()
    SpawnPed()
end)

DebugSuccess('Initialisation termin�e (VERSION 5.4.0 - Fix D�tection Mort + Armure)')
DebugSuccess('? D�tection mort: Multi-sources (Antitank + Event + Thread 100ms)')
DebugSuccess('? Protection anti-double envoi')
DebugSuccess('? Reset �tat mort automatique � chaque round/match')
DebugSuccess('? Armure (Kevlar): %s', Config.Armor.enabled and 'ACTIV�E' or 'D�SACTIV�E')
if Config.Armor.enabled then
    DebugSuccess('   � Quantit�: %d', Config.Armor.amount)
    DebugSuccess('   � Au spawn: %s', Config.Armor.giveOnSpawn and 'OUI' or 'NON')
    DebugSuccess('   � Au respawn: %s', Config.Armor.giveOnRespawn and 'OUI' or 'NON')
end