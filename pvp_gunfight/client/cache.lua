-- ========================================
-- PVP GUNFIGHT - SYSTÈME DE CACHE CENTRALISÉ
-- Version 4.2.0 - Cache intelligent avec support spectateur
-- ========================================

-- ========================================
-- CACHE DES NATIVES (LOCALES)
-- ========================================
local _PlayerPedId = PlayerPedId
local _GetEntityCoords = GetEntityCoords
local _GetEntityHealth = GetEntityHealth
local _GetEntityMaxHealth = GetEntityMaxHealth
local _IsEntityDead = IsEntityDead
local _GetGameTimer = GetGameTimer
local _IsPedInAnyVehicle = IsPedInAnyVehicle
local _GetCurrentPedWeapon = GetCurrentPedWeapon
local _Wait = Wait

-- ========================================
-- STRUCTURE DU CACHE
-- ========================================
local Cache = {
    -- Identifiants
    ped = 0,
    playerId = 0,
    
    -- Position
    coords = vector3(0, 0, 0),
    heading = 0.0,
    
    -- États
    isDead = false,
    isInVehicle = false,
    health = 200,
    maxHealth = 200,
    
    -- Arme
    hasWeapon = false,
    currentWeapon = 0,
    
    -- Timestamps
    lastCoordsUpdate = 0,
    lastStateUpdate = 0,
    lastWeaponUpdate = 0,
    
    -- Intervalles configurables
    coordsInterval = 100,
    stateInterval = 500,
    weaponInterval = 500,
}

-- ========================================
-- ÉTAT DU MATCH (partagé entre modules)
-- ========================================
local MatchState = {
    inMatch = false,
    inQueue = false,
    playerTeam = nil,
    canShoot = false,
    isDead = false,
    teammates = {},
    currentArena = nil,
    queueStartTime = 0,
    -- ✅ NOUVEAU: État spectateur
    isSpectating = false,
}

-- ========================================
-- FONCTIONS DE MISE À JOUR DU CACHE
-- ========================================

-- Met à jour le PED (appelé rarement, seulement si nécessaire)
local function UpdatePed()
    Cache.ped = _PlayerPedId()
    Cache.playerId = PlayerId()
end

-- Met à jour les coordonnées (appelé régulièrement)
local function UpdateCoords()
    local now = _GetGameTimer()
    if now - Cache.lastCoordsUpdate < Cache.coordsInterval then
        return Cache.coords
    end
    
    Cache.coords = _GetEntityCoords(Cache.ped)
    Cache.heading = GetEntityHeading(Cache.ped)
    Cache.lastCoordsUpdate = now
    
    return Cache.coords
end

-- Met à jour les états (appelé moins souvent)
local function UpdateState()
    local now = _GetGameTimer()
    if now - Cache.lastStateUpdate < Cache.stateInterval then
        return
    end
    
    Cache.isDead = _IsEntityDead(Cache.ped)
    Cache.isInVehicle = _IsPedInAnyVehicle(Cache.ped, false)
    Cache.health = _GetEntityHealth(Cache.ped)
    Cache.maxHealth = _GetEntityMaxHealth(Cache.ped)
    Cache.lastStateUpdate = now
end

-- Met à jour l'arme actuelle
local function UpdateWeapon()
    local now = _GetGameTimer()
    if now - Cache.lastWeaponUpdate < Cache.weaponInterval then
        return
    end
    
    local hasWeapon, weaponHash = _GetCurrentPedWeapon(Cache.ped, true)
    Cache.hasWeapon = hasWeapon
    Cache.currentWeapon = weaponHash
    Cache.lastWeaponUpdate = now
end

-- ========================================
-- ACCESSEURS PUBLICS (avec mise à jour automatique)
-- ========================================

-- Obtient le PED actuel (avec vérification)
function GetCachedPed()
    if Cache.ped == 0 or not DoesEntityExist(Cache.ped) then
        UpdatePed()
    end
    return Cache.ped
end

-- Obtient les coordonnées (avec cache)
function GetCachedCoords()
    return UpdateCoords()
end

-- Obtient les coordonnées sans mise à jour (lecture seule)
function GetCachedCoordsRaw()
    return Cache.coords
end

-- Force la mise à jour des coordonnées
function ForceUpdateCoords()
    Cache.lastCoordsUpdate = 0
    return UpdateCoords()
end

-- Obtient l'état de mort (avec cache)
function GetCachedIsDead()
    UpdateState()
    return Cache.isDead
end

-- Obtient la santé (avec cache)
function GetCachedHealth()
    UpdateState()
    return Cache.health, Cache.maxHealth
end

-- Obtient l'arme actuelle (avec cache)
function GetCachedWeapon()
    UpdateWeapon()
    return Cache.hasWeapon, Cache.currentWeapon
end

-- ========================================
-- GESTION DE L'ÉTAT DU MATCH
-- ========================================

function SetMatchState(key, value)
    if MatchState[key] ~= nil then
        MatchState[key] = value
    end
end

function GetMatchState(key)
    return MatchState[key]
end

function IsInMatch()
    return MatchState.inMatch
end

function IsInQueue()
    return MatchState.inQueue
end

function SetInMatch(value)
    MatchState.inMatch = value
end

function SetInQueue(value)
    MatchState.inQueue = value
end

function SetCanShoot(value)
    MatchState.canShoot = value
end

function CanShoot()
    return MatchState.canShoot
end

function SetPlayerTeam(team)
    MatchState.playerTeam = team
end

function GetPlayerTeam()
    return MatchState.playerTeam
end

function SetTeammates(teammates)
    MatchState.teammates = teammates or {}
end

function GetTeammates()
    return MatchState.teammates
end

function SetMatchDead(value)
    MatchState.isDead = value
end

function IsMatchDead()
    return MatchState.isDead
end

function SetCurrentArena(arena)
    MatchState.currentArena = arena
end

function GetCurrentArena()
    return MatchState.currentArena
end

function SetQueueStartTime(time)
    MatchState.queueStartTime = time
end

function GetQueueStartTime()
    return MatchState.queueStartTime
end

-- ========================================
-- ✅ NOUVEAU: GESTION ÉTAT SPECTATEUR
-- ========================================

-- Setter pour l'état spectateur (utilisé par spectator.lua)
function SetSpectatingState(value)
    MatchState.isSpectating = value
end

-- Getter pour l'état spectateur
function GetSpectatingState()
    return MatchState.isSpectating
end

-- ========================================
-- Réinitialise tout l'état du match
-- ========================================
function ResetMatchState()
    MatchState.inMatch = false
    MatchState.inQueue = false
    MatchState.playerTeam = nil
    MatchState.canShoot = false
    MatchState.isDead = false
    MatchState.teammates = {}
    MatchState.currentArena = nil
    MatchState.queueStartTime = 0
    MatchState.isSpectating = false
end

-- ========================================
-- THREAD DE MISE À JOUR DU CACHE
-- ========================================
CreateThread(function()
    -- Initialisation
    UpdatePed()
    
    while true do
        -- Mise à jour du PED si nécessaire (très rare)
        local currentPed = _PlayerPedId()
        if currentPed ~= Cache.ped then
            Cache.ped = currentPed
            DebugClient('Cache: PED mis à jour -> %d', currentPed)
        end
        
        -- Mise à jour des coordonnées
        UpdateCoords()
        
        -- Mise à jour des états (moins fréquent)
        UpdateState()
        
        -- Intervalle adaptatif selon l'état
        if MatchState.inMatch then
            -- En match: rafraîchissement plus fréquent
            Cache.coordsInterval = 50
            Cache.stateInterval = 200
            _Wait(50)
        else
            -- Hors match: rafraîchissement lent
            Cache.coordsInterval = 200
            Cache.stateInterval = 1000
            _Wait(200)
        end
    end
end)

function ResetAllMatchState()
    MatchState.inMatch = false
    MatchState.inQueue = false
    MatchState.playerTeam = nil
    MatchState.canShoot = false
    MatchState.isDead = false
    MatchState.teammates = {}
    MatchState.currentArena = nil
    MatchState.queueStartTime = 0
    MatchState.isSpectating = false
    
    DebugClient('🧹 État match complètement réinitialisé')
end

-- ========================================
-- EXPORTS
-- ========================================
exports('GetCachedPed', GetCachedPed)
exports('GetCachedCoords', GetCachedCoords)
exports('GetCachedHealth', GetCachedHealth)
exports('IsInMatch', IsInMatch)
exports('GetMatchState', GetMatchState)
exports('SetMatchState', SetMatchState)
exports('ResetAllMatchState', ResetAllMatchState)
exports('GetSpectatingState', GetSpectatingState)
exports('SetSpectatingState', SetSpectatingState)

DebugSuccess('Module Cache chargé (VERSION 4.2.0 - Support Spectateur)')
