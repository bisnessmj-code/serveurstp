-- ========================================
-- PVP GUNFIGHT - TEAMMATE HUD
-- Version 4.0.0 - Ultra-Optimisé
-- ========================================

DebugSuccess('Module HUD coéquipiers chargé')

-- ========================================
-- CACHE DES NATIVES (LOCALES)
-- ========================================
local _GetPlayerFromServerId = GetPlayerFromServerId
local _GetPlayerPed = GetPlayerPed
local _GetPlayerName = GetPlayerName
local _NetworkIsPlayerActive = NetworkIsPlayerActive
local _DoesEntityExist = DoesEntityExist
local _IsEntityDead = IsEntityDead
local _GetEntityCoords = GetEntityCoords
local _GetEntityHealth = GetEntityHealth
local _GetEntityMaxHealth = GetEntityMaxHealth
local _GetPedBoneIndex = GetPedBoneIndex
local _GetWorldPositionOfEntityBone = GetWorldPositionOfEntityBone
local _World3dToScreen2d = World3dToScreen2d
local _DrawRect = DrawRect
local _SetTextScale = SetTextScale
local _SetTextFont = SetTextFont
local _SetTextProportional = SetTextProportional
local _SetTextColour = SetTextColour
local _SetTextOutline = SetTextOutline
local _SetTextEntry = SetTextEntry
local _SetTextCentre = SetTextCentre
local _AddTextComponentString = AddTextComponentString
local _DrawText = DrawText
local _Wait = Wait

-- ========================================
-- VARIABLES
-- ========================================
local teammateHudActive = false
local teammatesList = {}

-- Configuration
local HUD_CONFIG = {
    maxDistance = 50.0,
    barWidth = 0.055,
    barHeight = 0.008,
    barOffsetZ = 1.0,
    nameOffsetZ = 1.08,
    textScale = 0.35,
    backgroundColor = {0, 0, 0, 150},
    
    colors = {
        high = {46, 204, 113},
        medium = {241, 196, 15},
        low = {231, 76, 60}
    }
}

-- Index de l'os de la tête (constant)
local HEAD_BONE_INDEX = nil

-- ========================================
-- FONCTIONS DE DESSIN
-- ========================================
local function DrawText3D(coords, text, scale)
    local onScreen, _x, _y = _World3dToScreen2d(coords.x, coords.y, coords.z)
    
    if onScreen then
        _SetTextScale(scale, scale)
        _SetTextFont(4)
        _SetTextProportional(1)
        _SetTextColour(255, 255, 255, 215)
        _SetTextOutline()
        _SetTextEntry("STRING")
        _SetTextCentre(1)
        _AddTextComponentString(text)
        _DrawText(_x, _y)
    end
end

local function DrawRect3D(coords, width, height, r, g, b, a)
    local onScreen, _x, _y = _World3dToScreen2d(coords.x, coords.y, coords.z)
    
    if onScreen then
        _DrawRect(_x, _y, width, height, r, g, b, a)
    end
end

local function GetHealthColor(healthPercent)
    if healthPercent > 66 then
        return HUD_CONFIG.colors.high
    elseif healthPercent > 33 then
        return HUD_CONFIG.colors.medium
    else
        return HUD_CONFIG.colors.low
    end
end

local function DrawTeammateHealthBar(teammate)
    local ped = teammate.ped
    
    if not _DoesEntityExist(ped) or _IsEntityDead(ped) then
        return
    end
    
    -- Position de la tête
    local headBone = HEAD_BONE_INDEX or _GetPedBoneIndex(ped, 0x796E)
    local headCoords = _GetWorldPositionOfEntityBone(ped, headBone)
    
    if headCoords.x == 0.0 and headCoords.y == 0.0 and headCoords.z == 0.0 then
        headCoords = _GetEntityCoords(ped)
    end
    
    local barCoords = vector3(headCoords.x, headCoords.y, headCoords.z + HUD_CONFIG.barOffsetZ)
    local nameCoords = vector3(headCoords.x, headCoords.y, headCoords.z + HUD_CONFIG.nameOffsetZ)
    
    -- Santé
    local health = _GetEntityHealth(ped)
    local maxHealth = _GetEntityMaxHealth(ped)
    local healthPercent = math.max(0, math.min(100, (health / maxHealth) * 100))
    
    local color = GetHealthColor(healthPercent)
    
    -- Fond
    DrawRect3D(barCoords, HUD_CONFIG.barWidth, HUD_CONFIG.barHeight,
        HUD_CONFIG.backgroundColor[1], HUD_CONFIG.backgroundColor[2],
        HUD_CONFIG.backgroundColor[3], HUD_CONFIG.backgroundColor[4])
    
    -- Barre de vie
    local healthBarWidth = HUD_CONFIG.barWidth * (healthPercent / 100)
    DrawRect3D(barCoords, healthBarWidth, HUD_CONFIG.barHeight - 0.001,
        color[1], color[2], color[3], 255)
    
    -- Nom
    DrawText3D(nameCoords, teammate.name, HUD_CONFIG.textScale)
end

-- ========================================
-- FONCTIONS DE GESTION
-- ========================================
local function UpdateTeammatesList(teammateIds)
    teammatesList = {}
    
    if not teammateIds or #teammateIds == 0 then
        return
    end
    
    for _, serverId in ipairs(teammateIds) do
        local playerIndex = _GetPlayerFromServerId(serverId)
        
        if playerIndex and playerIndex ~= -1 and _NetworkIsPlayerActive(playerIndex) then
            local ped = _GetPlayerPed(playerIndex)
            local name = _GetPlayerName(playerIndex)
            
            teammatesList[#teammatesList + 1] = {
                serverId = serverId,
                playerIndex = playerIndex,
                ped = ped,
                name = name
            }
        end
    end
    
    DebugClient('HUD coéquipiers: %d joueurs', #teammatesList)
end

local function EnableTeammateHUD()
    if teammateHudActive then return end
    
    teammateHudActive = true
    DebugClient('HUD coéquipiers activé')
end

local function DisableTeammateHUD()
    if not teammateHudActive then return end
    
    teammateHudActive = false
    teammatesList = {}
    DebugClient('HUD coéquipiers désactivé')
end

-- ========================================
-- THREAD: AFFICHAGE DES BARRES (RENDU)
-- ⚡ OPTIMISÉ: Skip intelligent + cache distance
-- ========================================
CreateThread(function()
    while true do
        if not teammateHudActive or #teammatesList == 0 then
            _Wait(500)
        else
            _Wait(0)
            
            local playerCoords = GetCachedCoords()
            
            for i = 1, #teammatesList do
                local teammate = teammatesList[i]
                
                if _DoesEntityExist(teammate.ped) then
                    local teammateCoords = _GetEntityCoords(teammate.ped)
                    local dx = playerCoords.x - teammateCoords.x
                    local dy = playerCoords.y - teammateCoords.y
                    local distance = dx * dx + dy * dy -- Évite math.sqrt
                    
                    -- Comparaison avec le carré de la distance max
                    if distance <= (HUD_CONFIG.maxDistance * HUD_CONFIG.maxDistance) then
                        DrawTeammateHealthBar(teammate)
                    end
                end
            end
        end
    end
end)

-- ========================================
-- THREAD: MISE À JOUR DES PEDS (LOGIQUE)
-- ⚡ SÉPARÉ du rendu - Intervalle 1s
-- ========================================
CreateThread(function()
    while true do
        if not teammateHudActive or #teammatesList == 0 then
            _Wait(2000)
        else
            _Wait(Config.Performance.intervals.teammateHudUpdate)
            
            for i = 1, #teammatesList do
                local teammate = teammatesList[i]
                local playerIndex = _GetPlayerFromServerId(teammate.serverId)
                
                if playerIndex and playerIndex ~= -1 and _NetworkIsPlayerActive(playerIndex) then
                    teammate.ped = _GetPlayerPed(playerIndex)
                    teammate.name = _GetPlayerName(playerIndex)
                end
            end
        end
    end
end)

-- ========================================
-- EVENTS
-- ========================================
RegisterNetEvent('pvp:enableTeammateHUD', function(teammateIds)
    UpdateTeammatesList(teammateIds)
    EnableTeammateHUD()
end)

RegisterNetEvent('pvp:disableTeammateHUD', function()
    DisableTeammateHUD()
end)

RegisterNetEvent('pvp:updateTeammatesList', function(teammateIds)
    UpdateTeammatesList(teammateIds)
end)

-- ========================================
-- EXPORTS
-- ========================================
exports('EnableTeammateHUD', EnableTeammateHUD)
exports('DisableTeammateHUD', DisableTeammateHUD)
exports('UpdateTeammatesList', UpdateTeammatesList)

DebugSuccess('Module HUD coéquipiers initialisé (VERSION 4.0.0)')
