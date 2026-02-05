-- ========================================
-- PVP GUNFIGHT - ZONES ULTRA-OPTIMISÉES
-- Version 5.0.0 - HAUTE CHARGE (160+ JOUEURS)
-- ========================================
-- ✅ Cache distance au bord (évite recalculs)
-- ✅ Dessin partiel intelligent (seulement proche)
-- ✅ Précalculs angles (évite math.rad répétitif)
-- ✅ Thread unique (au lieu de 3)
-- ✅ Skip frames intelligent
-- ========================================

DebugZones('Module zones chargé (ULTRA-OPTIMISÉ v5.0.0)')

-- ========================================
-- CACHE DES NATIVES (LOCALES)
-- ========================================
local _GetGameTimer = GetGameTimer
local _Wait = Wait
local _DrawLine = DrawLine
local _SetEntityHealth = SetEntityHealth
local _GetEntityHealth = GetEntityHealth
local _ShakeGameplayCam = ShakeGameplayCam
local _PlaySoundFrontend = PlaySoundFrontend

-- ========================================
-- CONFIGURATION PERFORMANCE
-- ========================================
local PERF = {
    -- Cache
    distanceCacheDuration = 200,       -- ✅ 200ms cache distance
    
    -- Intervals
    damageCheckInterval = 300,         -- ✅ 300ms vérif dégâts
    damageTickInterval = 2500,         -- ✅ 2.5s entre dégâts
    
    -- Skip frames
    skipFramesFar = 10,                -- ✅ Skip 10 frames si loin
    skipFramesMedium = 3,              -- ✅ Skip 3 frames si moyen
    skipFramesClose = 0,               -- ✅ Pas de skip si proche
}

-- ========================================
-- VARIABLES
-- ========================================
local currentArenaZone = nil
local isZoneActive = false
local zoneUpdateLock = false

-- ✅ Cache distance au bord
local cachedDistanceToBorder = 999
local lastDistanceUpdate = 0

-- ✅ Derniers dégâts
local lastDamageTime = 0

-- ✅ Configuration dégâts
local DAMAGE_CONFIG = {
    damagePerTick = 30,
    warningDistance = 2.0
}

-- ✅ Configuration visibilité zone
local VISIBILITY_CONFIG = {
    showDistance = 1.0,  -- Visible à 1m du bord
    
    normalColor = {r = 0, g = 255, b = 0, a = 100},
    warningColor = {r = 255, g = 165, b = 0, a = 150},
    dangerColor = {r = 255, g = 0, b = 0, a = 200},
}

-- ✅ Configuration dôme (réduite)
local DOME_CONFIG = {
    verticalSegments = 8,      -- ✅ 8 au lieu de 12
    horizontalSegments = 12,   -- ✅ 12 au lieu de 16
    drawPartialOnly = true,    -- ✅ Dessin partiel uniquement
    partialRadius = 5.0,       -- ✅ 5m autour joueur
}

-- ✅ Précalculs angles (calculés UNE SEULE FOIS)
local precalculatedAngles = {}
local precalculatedSphere = {}

-- ========================================
-- ✅ PRÉCALCULS (UNE SEULE FOIS AU DÉMARRAGE)
-- ========================================
local function PrecalculateAngles()
    local angleStep = 360.0 / DOME_CONFIG.horizontalSegments
    
    for i = 0, DOME_CONFIG.horizontalSegments do
        local rad = math.rad(i * angleStep)
        precalculatedAngles[i] = {
            cos = math.cos(rad),
            sin = math.sin(rad)
        }
    end
    
    for v = 0, DOME_CONFIG.verticalSegments do
        local heightRatio = v / DOME_CONFIG.verticalSegments
        local angle = math.rad(heightRatio * 180)
        
        precalculatedSphere[v] = {
            cosAngle = math.cos(angle),
            sinAngle = math.sin(angle)
        }
    end
    
    DebugZones('✅ Angles précalculés: %d horizontal, %d vertical', 
        DOME_CONFIG.horizontalSegments, DOME_CONFIG.verticalSegments)
end

PrecalculateAngles()

-- ========================================
-- ✅ FONCTION OPTIMISÉE: Calculer distance au bord
-- ========================================
local function UpdateDistanceToBorder()
    local now = _GetGameTimer()
    
    -- ✅ Utiliser cache si récent
    if now - lastDistanceUpdate < PERF.distanceCacheDuration then
        return cachedDistanceToBorder
    end
    
    lastDistanceUpdate = now
    
    if not currentArenaZone then
        cachedDistanceToBorder = 999
        return 999
    end
    
    local center = currentArenaZone.center
    local radius = currentArenaZone.radius
    local playerPos = GetCachedCoords()
    
    -- ✅ Calcul 3D optimisé
    local dx = playerPos.x - center.x
    local dy = playerPos.y - center.y
    local dz = playerPos.z - center.z
    local distance3D = math.sqrt(dx*dx + dy*dy + dz*dz)
    
    cachedDistanceToBorder = radius - distance3D
    
    return cachedDistanceToBorder
end

-- ========================================
-- ✅ FONCTION OPTIMISÉE: Couleur selon distance
-- ========================================
local function GetZoneColor(distanceToBorder)
    if distanceToBorder < 0 then
        return VISIBILITY_CONFIG.dangerColor
    elseif distanceToBorder < 0.5 then
        return VISIBILITY_CONFIG.warningColor
    else
        return VISIBILITY_CONFIG.normalColor
    end
end

-- ========================================
-- ✅ FONCTION OPTIMISÉE: Dessin cercle au sol
-- ========================================
local function DrawGroundCircle(center, radius, height, r, g, b, a)
    local segments = DOME_CONFIG.horizontalSegments
    
    for i = 0, segments - 1 do
        local p1 = precalculatedAngles[i]
        local p2 = precalculatedAngles[i + 1]
        
        _DrawLine(
            center.x + p1.cos * radius, center.y + p1.sin * radius, height,
            center.x + p2.cos * radius, center.y + p2.sin * radius, height,
            r, g, b, a
        )
    end
end

-- ========================================
-- ✅ FONCTION ULTRA-OPTIMISÉE: Dessin partiel sphère
-- ========================================
local function DrawPartialSphereNearPlayer(center, radius, playerPos, r, g, b, a)
    local partialRadius = DOME_CONFIG.partialRadius
    
    -- ✅ Ne dessiner que les segments proches du joueur
    for v = 0, DOME_CONFIG.verticalSegments do
        local sphereData = precalculatedSphere[v]
        local currentRadius = sphereData.sinAngle * radius
        local currentHeight = center.z + (sphereData.cosAngle * radius)
        
        -- ✅ Skip si trop loin en hauteur
        local heightDiff = math.abs(playerPos.z - currentHeight)
        if heightDiff < partialRadius then
            
            -- Dessiner cercle horizontal
            for i = 0, DOME_CONFIG.horizontalSegments - 1 do
                local p1 = precalculatedAngles[i]
                local p2 = precalculatedAngles[i + 1]
                
                local point1X = center.x + p1.cos * currentRadius
                local point1Y = center.y + p1.sin * currentRadius
                
                -- ✅ Vérifier proximité joueur (évite sqrt)
                local dx = playerPos.x - point1X
                local dy = playerPos.y - point1Y
                local distSquared = dx*dx + dy*dy
                
                if distSquared < (partialRadius * partialRadius) then
                    local point2X = center.x + p2.cos * currentRadius
                    local point2Y = center.y + p2.sin * currentRadius
                    
                    _DrawLine(point1X, point1Y, currentHeight, 
                             point2X, point2Y, currentHeight, r, g, b, a)
                end
            end
        end
    end
    
    -- ✅ Lignes verticales (réduites)
    for i = 0, DOME_CONFIG.horizontalSegments - 1, 2 do  -- ✅ Skip 1 sur 2
        local baseAngle = precalculatedAngles[i]
        
        local lineX = center.x + baseAngle.cos * radius
        local lineY = center.y + baseAngle.sin * radius
        
        -- ✅ Vérifier proximité
        local dx = playerPos.x - lineX
        local dy = playerPos.y - lineY
        local distSquared = dx*dx + dy*dy
        
        if distSquared < (partialRadius * partialRadius) then
            for v = 0, DOME_CONFIG.verticalSegments - 1 do
                local d1 = precalculatedSphere[v]
                local d2 = precalculatedSphere[v + 1]
                
                local r1 = d1.sinAngle * radius
                local h1 = d1.cosAngle * radius
                local r2 = d2.sinAngle * radius
                local h2 = d2.cosAngle * radius
                
                _DrawLine(
                    center.x + baseAngle.cos * r1, center.y + baseAngle.sin * r1, center.z + h1,
                    center.x + baseAngle.cos * r2, center.y + baseAngle.sin * r2, center.z + h2,
                    r, g, b, a
                )
            end
        end
    end
end

-- ========================================
-- ✅ THREAD UNIQUE: DESSIN + DÉGÂTS + TEXTE (UNIFIÉ)
-- ========================================
CreateThread(function()
    DebugSuccess('Thread zones UNIFIÉ démarré')
    
    local frameSkipCounter = 0
    local lastDamageCheck = 0
    
    while true do
        if not isZoneActive or zoneUpdateLock or not currentArenaZone then
            _Wait(1000)
        else
            local now = _GetGameTimer()
            
            -- ✅ 1. MISE À JOUR CACHE DISTANCE
            local distanceToBorder = UpdateDistanceToBorder()
            
            -- ✅ 2. SKIP FRAMES INTELLIGENT
            local shouldDraw = false
            local waitTime = 0
            
            if distanceToBorder > VISIBILITY_CONFIG.showDistance then
                -- Loin du bord: pas de dessin, vérification lente
                waitTime = 200
                shouldDraw = false
                
            elseif distanceToBorder < -5.0 then
                -- Très loin hors zone: skip frames
                frameSkipCounter = frameSkipCounter + 1
                if frameSkipCounter >= PERF.skipFramesFar then
                    frameSkipCounter = 0
                    shouldDraw = true
                end
                waitTime = 0
                
            elseif distanceToBorder < 0 then
                -- Hors zone: skip quelques frames
                frameSkipCounter = frameSkipCounter + 1
                if frameSkipCounter >= PERF.skipFramesMedium then
                    frameSkipCounter = 0
                    shouldDraw = true
                end
                waitTime = 0
                
            else
                -- Proche du bord: toujours dessiner
                shouldDraw = true
                frameSkipCounter = 0
                waitTime = 0
            end
            
            -- ✅ 3. DESSIN (SI NÉCESSAIRE)
            if shouldDraw then
                local playerPos = GetCachedCoords()
                local color = GetZoneColor(distanceToBorder)
                
                DrawPartialSphereNearPlayer(currentArenaZone.center, currentArenaZone.radius, 
                                           playerPos, color.r, color.g, color.b, color.a)
                
                DrawGroundCircle(currentArenaZone.center, currentArenaZone.radius, 
                                currentArenaZone.center.z + 0.1, color.r, color.g, color.b, color.a)
            end
            
            -- ✅ 4. TEXTE ZONE (SI PROCHE)
            if distanceToBorder <= DAMAGE_CONFIG.warningDistance then
                if distanceToBorder < 0 then
                    SetTextScale(0.5, 0.5)
                    SetTextFont(4)
                    SetTextProportional(1)
                    SetTextColour(255, 0, 0, 255)
                    SetTextEntry("STRING")
                    SetTextCentre(1)
                    AddTextComponentString(string.format("⚠ HORS ZONE! (%.1fm)", math.abs(distanceToBorder)))
                    DrawText(0.5, 0.15)
                elseif distanceToBorder <= DAMAGE_CONFIG.warningDistance then
                    SetTextScale(0.4, 0.4)
                    SetTextFont(4)
                    SetTextProportional(1)
                    SetTextColour(255, 165, 0, 255)
                    SetTextEntry("STRING")
                    SetTextCentre(1)
                    AddTextComponentString(string.format("⚠ Limite à %.1fm", distanceToBorder))
                    DrawText(0.5, 0.15)
                end
            end
            
            -- ✅ 5. VÉRIFICATION DÉGÂTS (300ms)
            if now - lastDamageCheck >= PERF.damageCheckInterval then
                lastDamageCheck = now
                
                if distanceToBorder < 0 then
                    if now - lastDamageTime >= PERF.damageTickInterval then
                        local ped = GetCachedPed()
                        local currentHealth = _GetEntityHealth(ped)
                        local newHealth = currentHealth - DAMAGE_CONFIG.damagePerTick
                        
                        DebugZones('Dégâts: -%d HP (%d -> %d)', DAMAGE_CONFIG.damagePerTick, currentHealth, newHealth)
                        
                        _SetEntityHealth(ped, newHealth)
                        _ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
                        _PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
                        ESX.ShowNotification('~r~⚠ Hors zone! (-' .. DAMAGE_CONFIG.damagePerTick .. ' HP)')
                        
                        lastDamageTime = now
                        
                        if newHealth <= 0 then
                            DebugError('Joueur mort hors zone!')
                            TriggerServerEvent('pvp:playerDiedOutsideZone')
                        end
                    end
                end
            end
            
            _Wait(waitTime)
        end
    end
end)

-- ========================================
-- EVENTS
-- ========================================
RegisterNetEvent('pvp:setArenaZone', function(arenaKey)
    DebugZones('Configuration zone: %s', arenaKey)
    
    zoneUpdateLock = true
    
    local arena = Config.Arenas[arenaKey]
    
    if not arena then
        DebugError('Arène %s introuvable!', arenaKey)
        zoneUpdateLock = false
        return
    end
    
    if not arena.zone or not arena.zone.center or not arena.zone.radius then
        DebugError('Zone invalide pour arène %s!', arenaKey)
        zoneUpdateLock = false
        return
    end
    
    currentArenaZone = {
        center = vector3(arena.zone.center.x, arena.zone.center.y, arena.zone.center.z),
        radius = arena.zone.radius
    }
    
    -- ✅ Reset cache
    cachedDistanceToBorder = 999
    lastDistanceUpdate = 0
    
    zoneUpdateLock = false
    
    DebugZones('Zone sphérique activée - Centre: %.2f, %.2f, %.2f | Rayon: %.2f', 
        currentArenaZone.center.x, currentArenaZone.center.y, currentArenaZone.center.z, currentArenaZone.radius)
end)

RegisterNetEvent('pvp:enableZones', function()
    DebugSuccess('Activation zones (MODE OPTIMISÉ)')
    lastDamageTime = _GetGameTimer()
    isZoneActive = true
    
    -- ✅ Reset cache
    cachedDistanceToBorder = 999
    lastDistanceUpdate = 0
end)

RegisterNetEvent('pvp:disableZones', function()
    DebugSuccess('Désactivation zones')
    
    zoneUpdateLock = true
    isZoneActive = false
    _Wait(0)
    currentArenaZone = nil
    lastDamageTime = 0
    
    -- ✅ Reset cache
    cachedDistanceToBorder = 999
    lastDistanceUpdate = 0
    
    zoneUpdateLock = false
end)

-- ========================================
-- CLEANUP
-- ========================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    DebugZones('Nettoyage module zones')
    zoneUpdateLock = true
    isZoneActive = false
    currentArenaZone = nil
    zoneUpdateLock = false
end)

DebugSuccess('Module zones initialisé (VERSION 5.0.0 - ULTRA-OPTIMISÉ)')
DebugSuccess('✅ Thread unique (au lieu de 3)')
DebugSuccess('✅ Cache distance: 200ms')
DebugSuccess('✅ Dessin partiel: 5m autour joueur')
DebugSuccess('✅ Skip frames: 10 (loin) / 3 (moyen) / 0 (proche)')
DebugSuccess('✅ Segments réduits: 8x12 (au lieu de 12x16)')