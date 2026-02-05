-- ========================================
-- PVP GUNFIGHT - SYSTÈME SPECTATEUR V2.1
-- FIXES: Hauteur + Rotation Souris + Zoom
-- ========================================
-- ✅ FIX: Hauteur caméra ajustée (2m au-dessus)
-- ✅ FIX: Rotation gauche/droite avec souris
-- ✅ FIX: Zoom molette fonctionnel
-- ✅ Caméra suit le joueur specté
-- ========================================

DebugSuccess('Module Spectateur V2.1 chargé (FIXED)')

-- ========================================
-- CACHE DES NATIVES
-- ========================================
local _PlayerPedId = PlayerPedId
local _GetPlayerFromServerId = GetPlayerFromServerId
local _GetPlayerPed = GetPlayerPed
local _NetworkIsPlayerActive = NetworkIsPlayerActive
local _DoesEntityExist = DoesEntityExist
local _IsEntityDead = IsEntityDead
local _GetEntityCoords = GetEntityCoords
local _GetEntityHeading = GetEntityHeading
local _GetEntityRotation = GetEntityRotation
local _SetEntityCoords = SetEntityCoords
local _SetEntityVisible = SetEntityVisible
local _SetEntityAlpha = SetEntityAlpha
local _SetEntityCollision = SetEntityCollision
local _FreezeEntityPosition = FreezeEntityPosition
local _NetworkSetEntityInvisibleToNetwork = NetworkSetEntityInvisibleToNetwork
local _SetEveryoneIgnorePlayer = SetEveryoneIgnorePlayer
local _SetPoliceIgnorePlayer = SetPoliceIgnorePlayer
local _SetEntityInvincible = SetEntityInvincible
local _Wait = Wait
local _IsControlJustPressed = IsControlJustPressed
local _IsDisabledControlJustPressed = IsDisabledControlJustPressed
local _GetDisabledControlNormal = GetDisabledControlNormal
local _DisableControlAction = DisableControlAction
local _SetCamCoord = SetCamCoord
local _SetCamRot = SetCamRot
local _CreateCam = CreateCam
local _SetCamActive = SetCamActive
local _RenderScriptCams = RenderScriptCams
local _DestroyCam = DestroyCam
local _DoesCamExist = DoesCamExist
local _SetCamFov = SetCamFov
local _GetPlayerName = GetPlayerName

-- ========================================
-- CONFIGURATION
-- ========================================
local CONFIG = {
    -- Distance caméra (modifiable avec molette)
    defaultDistance = 4.0,      -- ✅ Distance par défaut
    minDistance = 2.0,          -- ✅ Zoom max
    maxDistance = 15.0,         -- ✅ Dézoom max
    zoomSpeed = 0.8,            -- ✅ Vitesse zoom
    
    -- Offset vertical (hauteur caméra au-dessus du joueur)
    heightOffset = 0,         -- ✅ FIX: 2m au-dessus (au lieu de 0.8)
    
    -- Offset latéral (vue épaule)
    sideOffset = 0.8,           -- Légèrement à droite
    
    -- Rotation souris
    mouseSensitivity = 15.0,     -- ✅ Sensibilité rotation horizontale
    
    -- FOV
    defaultFov = 70.0,
    
    -- Touches
    nextTargetKey = 175,        -- Flèche droite
    prevTargetKey = 174,        -- Flèche gauche
    
    -- Intervals
    updateInterval = 0,
    targetCheckInterval = 500,
    
    -- HUD
    hudEnabled = true,
    hudY = 0.92,
}

-- ========================================
-- VARIABLES D'ÉTAT
-- ========================================
local spectatorActive = false
local spectatorCam = nil
local currentTargetServerId = nil
local currentTargetPed = nil
local availableTargets = {}
local currentTargetIndex = 1

-- Distance caméra + angle rotation
local camDistance = CONFIG.defaultDistance
local camAngleOffset = 0.0      -- ✅ Offset rotation horizontal (souris)

-- ========================================
-- FONCTION: Récupérer coéquipiers vivants
-- ========================================
local function GetAliveTeammates()
    local teammates = GetTeammates()
    local aliveTargets = {}
    
    if not teammates or #teammates == 0 then
        return aliveTargets
    end
    
    for i = 1, #teammates do
        local serverId = teammates[i]
        local playerIndex = _GetPlayerFromServerId(serverId)
        
        if playerIndex and playerIndex ~= -1 and _NetworkIsPlayerActive(playerIndex) then
            local ped = _GetPlayerPed(playerIndex)
            
            if ped and _DoesEntityExist(ped) and not _IsEntityDead(ped) then
                aliveTargets[#aliveTargets + 1] = {
                    serverId = serverId,
                    playerIndex = playerIndex,
                    ped = ped,
                    name = _GetPlayerName(playerIndex) or ('Joueur ' .. serverId)
                }
            end
        end
    end
    
    return aliveTargets
end

-- ========================================
-- FONCTION: Mettre à jour liste cibles
-- ========================================
local function UpdateAvailableTargets()
    local newTargets = GetAliveTeammates()
    availableTargets = newTargets
    
    if currentTargetServerId then
        local stillValid = false
        
        for i = 1, #availableTargets do
            if availableTargets[i].serverId == currentTargetServerId then
                stillValid = true
                currentTargetIndex = i
                currentTargetPed = availableTargets[i].ped
                break
            end
        end
        
        if not stillValid then
            if #availableTargets > 0 then
                currentTargetIndex = 1
                currentTargetServerId = availableTargets[1].serverId
                currentTargetPed = availableTargets[1].ped
                camAngleOffset = 0.0  -- Reset rotation
                
                DebugClient('[SPEC] Cible morte, passage à: %s', availableTargets[1].name)
            else
                DebugClient('[SPEC] Plus de coéquipiers vivants')
                StopSpectating()
            end
        end
    end
    
    return #availableTargets
end

-- ========================================
-- FONCTION: Créer caméra spectateur
-- ========================================
local function CreateSpectatorCamera()
    if spectatorCam and _DoesCamExist(spectatorCam) then
        _DestroyCam(spectatorCam, false)
    end
    
    spectatorCam = _CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    _SetCamFov(spectatorCam, CONFIG.defaultFov)
    
    DebugClient('[SPEC] Caméra créée')
end

-- ========================================
-- FONCTION: Activer caméra
-- ========================================
local function ActivateSpectatorCamera()
    if spectatorCam and _DoesCamExist(spectatorCam) then
        _SetCamActive(spectatorCam, true)
        _RenderScriptCams(true, true, 500, true, true)
        DebugClient('[SPEC] Caméra activée')
    end
end

-- ========================================
-- FONCTION: Détruire caméra
-- ========================================
local function DestroySpectatorCamera()
    if spectatorCam and _DoesCamExist(spectatorCam) then
        _SetCamActive(spectatorCam, false)
        _RenderScriptCams(false, true, 500, true, true)
        _DestroyCam(spectatorCam, false)
        spectatorCam = nil
    end
    
    DebugClient('[SPEC] Caméra détruite')
end

-- ========================================
-- ✅ CALCUL CAMÉRA AVEC ROTATION SOURIS
-- ========================================
-- ========================================
-- ✅ CALCUL CAMÉRA INDÉPENDANT DU JOUEUR (FIXED)
-- ========================================
local function CalculateBehindPlayerCamera(targetPed)
    if not targetPed or not _DoesEntityExist(targetPed) then
        return nil, nil
    end
    
    -- Position du joueur specté
    local targetCoords = _GetEntityCoords(targetPed)
    
    -- ✅ UTILISER UNIQUEMENT camAngleOffset (Indépendant du joueur)
    -- On ne récupère plus le Heading du joueur ici
    local finalHeading = camAngleOffset 
    local headingRad = math.rad(finalHeading)
    
    -- Calculer offset autour du joueur
    local behindX = -math.sin(headingRad) * camDistance
    local behindY = math.cos(headingRad) * camDistance
    
    -- ✅ Position finale caméra (Hauteur ajustable via CONFIG.heightOffset)
    local camX = targetCoords.x + behindX
    local camY = targetCoords.y + behindY
    local camZ = targetCoords.z + CONFIG.heightOffset
    
    local camPos = vector3(camX, camY, camZ)
    
    -- Point de focus (Le joueur lui-même)
    local focusX = targetCoords.x
    local focusY = targetCoords.y
    local focusZ = targetCoords.z + (CONFIG.heightOffset - 0.5)
    
    -- Calculer rotation caméra vers le joueur
    local dx = focusX - camPos.x
    local dy = focusY - camPos.y
    local dz = focusZ - camPos.z
    
    local heading = math.deg(math.atan(dx, dy))
    local distance2D = math.sqrt(dx * dx + dy * dy)
    local pitch = math.deg(math.atan(dz, distance2D))
    
    local camRot = vector3(-pitch, 0.0, -heading)
    
    return camPos, camRot
end

-- ========================================
-- FONCTION: Rendre joueur invisible
-- ========================================
local function SetPlayerInvisible(invisible)
    local ped = _PlayerPedId()
    
    if invisible then
        _SetEntityVisible(ped, false, false)
        _SetEntityAlpha(ped, 0, false)
        _SetEntityCollision(ped, false, false)
        _FreezeEntityPosition(ped, true)
        _NetworkSetEntityInvisibleToNetwork(ped, true)
        _SetEveryoneIgnorePlayer(PlayerId(), true)
        _SetPoliceIgnorePlayer(PlayerId(), true)
        _SetEntityInvincible(ped, true)
    else
        _SetEntityVisible(ped, true, false)
        _SetEntityAlpha(ped, 255, false)
        _SetEntityCollision(ped, true, true)
        _FreezeEntityPosition(ped, false)
        _NetworkSetEntityInvisibleToNetwork(ped, false)
        _SetEveryoneIgnorePlayer(PlayerId(), false)
        _SetPoliceIgnorePlayer(PlayerId(), false)
        _SetEntityInvincible(ped, false)
    end
end

-- ========================================
-- FONCTION: Changer de cible
-- ========================================
local function SwitchTarget(direction)
    if #availableTargets <= 1 then
        return
    end
    
    if direction == 'next' then
        currentTargetIndex = currentTargetIndex + 1
        if currentTargetIndex > #availableTargets then
            currentTargetIndex = 1
        end
    else
        currentTargetIndex = currentTargetIndex - 1
        if currentTargetIndex < 1 then
            currentTargetIndex = #availableTargets
        end
    end
    
    local target = availableTargets[currentTargetIndex]
    if target then
        currentTargetServerId = target.serverId
        currentTargetPed = target.ped
        camAngleOffset = 0.0  -- ✅ Reset rotation souris
        
        exports['brutal_notify']:SendAlert('Spectateur', 'Spectate: ' .. target.name, 2000, 'info')
        DebugClient('[SPEC] Changement cible -> %s', target.name)
    end
end

-- ========================================
-- ✅ DÉMARRER MODE SPECTATEUR
-- ========================================
function StartSpectating()
    if spectatorActive then
        DebugWarn('[SPEC] Déjà en mode spectateur')
        return false
    end
    
    if not IsInMatch() then
        DebugWarn('[SPEC] Pas en match')
        return false
    end
    
    if not IsMatchDead() then
        DebugWarn('[SPEC] Pas mort')
        return false
    end
    
    local targetCount = UpdateAvailableTargets()
    
    if targetCount == 0 then
        DebugWarn('[SPEC] Aucun coéquipier vivant à spectate')
        return false
    end
    
    -- Sélectionner première cible
    currentTargetIndex = 1
    currentTargetServerId = availableTargets[1].serverId
    currentTargetPed = availableTargets[1].ped
    
    if not currentTargetPed or not _DoesEntityExist(currentTargetPed) then
        DebugError('[SPEC] Cible invalide')
        return false
    end
    
    -- Activer mode spectateur
    spectatorActive = true
    
    if SetSpectatingState then
        SetSpectatingState(true)
    end
    
    -- Rendre joueur invisible
    SetPlayerInvisible(true)
    
    -- Téléporter notre ped invisible près de la cible
    local targetCoords = _GetEntityCoords(currentTargetPed)
    _SetEntityCoords(_PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z + 5.0, false, false, false, false)
    
    -- Reset distance zoom et rotation
    camDistance = CONFIG.defaultDistance
    camAngleOffset = 0.0
    
    -- Créer et activer caméra
    CreateSpectatorCamera()
    
    -- Positionner caméra immédiatement
    if spectatorCam and _DoesCamExist(spectatorCam) then
        local camPos, camRot = CalculateBehindPlayerCamera(currentTargetPed)
        if camPos and camRot then
            _SetCamCoord(spectatorCam, camPos.x, camPos.y, camPos.z)
            _SetCamRot(spectatorCam, camRot.x, camRot.y, camRot.z, 2)
        end
    end
    
    _Wait(100)
    ActivateSpectatorCamera()
    
    -- Notification
    exports['brutal_notify']:SendAlert('Mode Spectateur', 
        'Spectate: ' .. availableTargets[1].name .. 
        '\n🖱️ Souris = Tourner | ← → = Changer | Molette = Zoom', 
        5000, 'info')
    
    DebugSuccess('[SPEC] Mode spectateur activé - Cible: %s', availableTargets[1].name)
    
    return true
end

-- ========================================
-- FONCTION: Arrêter mode spectateur
-- ========================================
function StopSpectating()
    if not spectatorActive then
        return
    end
    
    spectatorActive = false
    
    if SetSpectatingState then
        SetSpectatingState(false)
    end
    
    DestroySpectatorCamera()
    SetPlayerInvisible(false)
    
    currentTargetServerId = nil
    currentTargetPed = nil
    availableTargets = {}
    currentTargetIndex = 1
    camAngleOffset = 0.0
    
    DebugSuccess('[SPEC] Mode spectateur désactivé')
end

-- ========================================
-- FONCTION: État spectateur
-- ========================================
function IsSpectating()
    return spectatorActive
end

-- ========================================
-- ✅ THREAD PRINCIPAL: Caméra + Contrôles
-- ========================================
CreateThread(function()
    DebugSuccess('Thread spectateur principal démarré (V2.1 FIXED)')
    
    while true do
        if not spectatorActive then
            _Wait(500)
        else
            _Wait(CONFIG.updateInterval)
            
            -- ═══════════════════════════════════════
            -- ✅ DÉSACTIVER CONTRÔLES (pour souris)
            -- ═══════════════════════════════════════
            _DisableControlAction(0, 1, true)   -- Camera X
            _DisableControlAction(0, 2, true)   -- Camera Y
            _DisableControlAction(0, 24, true)  -- Attack
            _DisableControlAction(0, 25, true)  -- Aim
            
            -- ═══════════════════════════════════════
            -- ✅ ROTATION SOURIS (Gauche/Droite)
            -- ═══════════════════════════════════════
            local mouseX = _GetDisabledControlNormal(0, 1)  -- Mouvement horizontal souris
            
            if mouseX ~= 0 then
                camAngleOffset = camAngleOffset - (mouseX * CONFIG.mouseSensitivity)
                
                -- Limiter l'angle pour éviter désorientation
                if camAngleOffset > 180.0 then
                    camAngleOffset = camAngleOffset - 360.0
                elseif camAngleOffset < -180.0 then
                    camAngleOffset = camAngleOffset + 360.0
                end
            end
            
            -- ═══════════════════════════════════════
            -- ✅ ZOOM MOLETTE (FIXED)
            -- ═══════════════════════════════════════
            if _IsControlJustPressed(0, 241) then  -- Molette haut
                camDistance = math.max(CONFIG.minDistance, camDistance - CONFIG.zoomSpeed)
                DebugClient('[SPEC] Zoom: %.1fm', camDistance)
            end
            
            if _IsControlJustPressed(0, 242) then  -- Molette bas
                camDistance = math.min(CONFIG.maxDistance, camDistance + CONFIG.zoomSpeed)
                DebugClient('[SPEC] Dézoom: %.1fm', camDistance)
            end
            
            -- ═══════════════════════════════════════
            -- CHANGEMENT DE CIBLE (← →)
            -- ═══════════════════════════════════════
            if _IsControlJustPressed(0, CONFIG.nextTargetKey) or _IsDisabledControlJustPressed(0, CONFIG.nextTargetKey) then
                SwitchTarget('next')
            end
            
            if _IsControlJustPressed(0, CONFIG.prevTargetKey) or _IsDisabledControlJustPressed(0, CONFIG.prevTargetKey) then
                SwitchTarget('prev')
            end
            
            -- ═══════════════════════════════════════
            -- ✅ UPDATE CAMÉRA (suit le joueur)
            -- ═══════════════════════════════════════
            if spectatorCam and _DoesCamExist(spectatorCam) and currentTargetPed and _DoesEntityExist(currentTargetPed) then
                local camPos, camRot = CalculateBehindPlayerCamera(currentTargetPed)
                
                if camPos and camRot then
                    _SetCamCoord(spectatorCam, camPos.x, camPos.y, camPos.z)
                    _SetCamRot(spectatorCam, camRot.x, camRot.y, camRot.z, 2)
                end
                
                -- Téléporter notre ped invisible près de la cible (streaming)
                local targetCoords = _GetEntityCoords(currentTargetPed)
                local myPed = _PlayerPedId()
                local myCoords = _GetEntityCoords(myPed)
                local distance = #(myCoords - targetCoords)
                
                if distance > 100.0 then
                    _SetEntityCoords(myPed, targetCoords.x, targetCoords.y, targetCoords.z + 50.0, false, false, false, false)
                end
            end
            
            -- ═══════════════════════════════════════
            -- HUD SPECTATEUR
            -- ═══════════════════════════════════════
            if CONFIG.hudEnabled and currentTargetServerId and #availableTargets > 0 then
                local target = availableTargets[currentTargetIndex]
                if target then
                    local text = string.format('SPECTATEUR | %s (%d/%d) | 🖱️ Souris = Tourner | ← → = Changer | Molette = Zoom (%.1fm)', 
                        target.name, currentTargetIndex, #availableTargets, camDistance)
                    
                    SetTextFont(4)
                    SetTextScale(0.35, 0.35)
                    SetTextColour(255, 255, 255, 200)
                    SetTextCentre(true)
                    SetTextOutline()
                    SetTextEntry('STRING')
                    AddTextComponentString(text)
                    DrawText(0.5, CONFIG.hudY)
                end
            end
        end
    end
end)

-- ========================================
-- THREAD: Vérification cibles
-- ========================================
CreateThread(function()
    DebugSuccess('Thread spectateur cibles démarré')
    
    while true do
        if not spectatorActive then
            _Wait(1000)
        else
            _Wait(CONFIG.targetCheckInterval)
            UpdateAvailableTargets()
        end
    end
end)

-- ========================================
-- EVENTS
-- ========================================

RegisterNetEvent('pvp:onPlayerDeathInMatch', function()
    if not IsInMatch() then return end
    if IsSpectating() then return end
    
    local teammates = GetTeammates()
    if not teammates or #teammates == 0 then
        DebugClient('[SPEC] Mode 1v1 - Pas de spectateur')
        return
    end
    
    _Wait(1500)
    
    if not IsMatchDead() then
        return
    end
    
    StartSpectating()
end)

RegisterNetEvent('pvp:roundStart', function()
    if IsSpectating() then
        StopSpectating()
    end
end)

RegisterNetEvent('pvp:matchEnd', function()
    if IsSpectating() then
        StopSpectating()
    end
end)

RegisterNetEvent('pvp:respawnPlayer', function()
    if IsSpectating() then
        StopSpectating()
    end
end)

RegisterNetEvent('pvp:teleportToSpawn', function()
    if IsSpectating() then
        StopSpectating()
    end
end)

RegisterNetEvent('pvp:teleportToExit', function()
    if IsSpectating() then
        StopSpectating()
    end
end)

RegisterNetEvent('pvp:forceCleanup', function()
    if IsSpectating() then
        StopSpectating()
    end
end)

RegisterNetEvent('pvp:forceReturnToLobby', function()
    if IsSpectating() then
        StopSpectating()
    end
end)

-- FIX: Event explicite pour arrêter le spectate (déconnexion joueur)
RegisterNetEvent('pvp:stopSpectating', function()
    if IsSpectating() then
        DebugClient('[SPEC] Arrêt forcé (event stopSpectating)')
        StopSpectating()
    end
end)

-- ========================================
-- COMMANDES DEBUG
-- ========================================
RegisterCommand('specstatus', function()
    print('^5[SPECTATOR V2.1]^7 === STATUT ===')
    print(string.format('Actif: %s', tostring(spectatorActive)))
    print(string.format('Cible ServerId: %s', tostring(currentTargetServerId)))
    print(string.format('Cible Ped: %s', tostring(currentTargetPed)))
    print(string.format('Cibles disponibles: %d', #availableTargets))
    print(string.format('Distance caméra: %.2f', camDistance))
    print(string.format('Angle offset: %.2f°', camAngleOffset))
    
    if currentTargetPed and _DoesEntityExist(currentTargetPed) then
        local coords = _GetEntityCoords(currentTargetPed)
        print(string.format('Position cible: %.2f, %.2f, %.2f', coords.x, coords.y, coords.z))
    end
end, false)

RegisterCommand('specstop', function()
    if IsSpectating() then
        StopSpectating()
        print('^5[SPECTATOR V2.1]^7 Mode spectateur arrêté')
    else
        print('^5[SPECTATOR V2.1]^7 Pas en mode spectateur')
    end
end, false)

-- ========================================
-- EXPORTS
-- ========================================
exports('StartSpectating', StartSpectating)
exports('StopSpectating', StopSpectating)
exports('IsSpectating', IsSpectating)

-- ========================================
-- CLEANUP
-- ========================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if spectatorActive then
        StopSpectating()
    end
end)

DebugSuccess('Module Spectateur V2.1 initialisé (FIXED)')
DebugSuccess('✅ Hauteur: 2m au-dessus du joueur')
DebugSuccess('✅ Rotation souris gauche/droite')
DebugSuccess('✅ Zoom/Dézoom molette')
DebugSuccess('✅ Changement cible ← →')