-- ================================================================================================
-- GUNFIGHT ARENA LITE - CLIENT MAIN (CORRIGÉ - SYNCHRO RÉSEAU)
-- ================================================================================================

-- ÉTAT
local PlayerState = {
    inArena = false,
    currentZone = nil,
    isDead = false,
    weaponEquipped = false,
    showingUI = false,
    spawnStartTime = 0,
    lastRespawnComplete = 0
}

local lobbyPed = nil
local lobbyBlip = nil

local Cache = {
    ped = 0,
    coords = vector3(0, 0, 0),
    isDead = false,
    lastUpdate = 0,
    nearLobby = false,
    lobbyDistance = 999.0,
}

local Throttle = {
    lastDeathEvent = 0,
    lastExitEvent = 0
}

local CACHE_UPDATE_INTERVAL = 250
local LOBBY_INTERACT_DIST = 2.5
local SPAWN_GRACE_PERIOD = 5000
local THROTTLE_DEATH = 3000

-- ================================================================================================
-- UTILITAIRES
-- ================================================================================================

local function GetTime()
    return GetGameTimer()
end

local function UpdateCache()
    local now = GetTime()
    if now - Cache.lastUpdate < CACHE_UPDATE_INTERVAL then return end
    
    Cache.ped = PlayerPedId()
    Cache.coords = GetEntityCoords(Cache.ped)
    Cache.isDead = IsEntityDead(Cache.ped)
    Cache.lastUpdate = now
    
    if not PlayerState.inArena and lobbyPed and DoesEntityExist(lobbyPed) then
        local lobbyCoords = GetEntityCoords(lobbyPed)
        Cache.lobbyDistance = #(Cache.coords - lobbyCoords)
        Cache.nearLobby = Cache.lobbyDistance < LOBBY_INTERACT_DIST
    else
        Cache.nearLobby = false
    end
end

local function Draw3DText(x, y, z, text)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(screenX, screenY)
end

local function DrawHelpMessage()
    local cfg = Config.UI.helpMessage
    if not cfg.enabled then return end
    
    SetTextFont(cfg.font)
    SetTextScale(cfg.scale, cfg.scale)
    SetTextProportional(true)
    SetTextColour(cfg.color.r, cfg.color.g, cfg.color.b, cfg.color.a)
    SetTextEntry("STRING")
    AddTextComponentSubstringPlayerName(cfg.text)
    DrawText(cfg.position.x, cfg.position.y)
end

-- ================================================================================================
-- ARME - Forcer l'équipement visuel (l'arme est donnée par le serveur)
-- ================================================================================================

local function ForceWeaponInHand(ped, weaponHash)
    if not ped or not DoesEntityExist(ped) then return end
    if not HasPedGotWeapon(ped, weaponHash, false) then return end
    
    -- Forcer l'arme dans les mains
    SetCurrentPedWeapon(ped, weaponHash, true)
    SetPedCurrentWeaponVisible(ped, true, true, true, true)
    SetPedCanSwitchWeapon(ped, false)
end

local function EquipWeaponVisual(weaponName, ammo)
    local ped = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)
    
    if Config.DebugClient then
        print('^3[GF-Client]^0 EquipWeaponVisual: ' .. weaponName)
    end
    
    -- Attendre que l'arme soit disponible (donnée par le serveur)
    local attempts = 0
    while not HasPedGotWeapon(ped, weaponHash, false) and attempts < 20 do
        Wait(100)
        ped = PlayerPedId()
        attempts = attempts + 1
    end
    
    if not HasPedGotWeapon(ped, weaponHash, false) then
        if Config.DebugClient then
            print('^1[GF-Client]^0 Arme non reçue du serveur après ' .. attempts .. ' tentatives')
        end
        return
    end
    
    -- Forcer l'arme en main
    ForceWeaponInHand(ped, weaponHash)
    
    Wait(200)
    
    -- Double vérification
    ped = PlayerPedId()
    ForceWeaponInHand(ped, weaponHash)
    
    PlayerState.weaponEquipped = true
    
    if Config.DebugClient then
        print('^2[GF-Client]^0 Arme équipée et en main!')
    end
end

local function RemoveWeaponVisual()
    local ped = PlayerPedId()
    
    if Config.DebugClient then
        print('^3[GF-Client]^0 RemoveWeaponVisual')
    end
    
    SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
    SetPedCanSwitchWeapon(ped, true)
    
    PlayerState.weaponEquipped = false
end

-- ================================================================================================
-- LOBBY
-- ================================================================================================

local function CreateLobbyPed()
    local pedConfig = Config.Lobby.ped
    if not pedConfig or not pedConfig.enabled then return end
    
    local modelHash = GetHashKey(pedConfig.model)
    RequestModel(modelHash)
    
    local timeout = 50
    while not HasModelLoaded(modelHash) and timeout > 0 do
        Wait(100)
        timeout = timeout - 1
    end
    
    if not HasModelLoaded(modelHash) then return end
    
    local pos = pedConfig.position
    lobbyPed = CreatePed(5, modelHash, pos.x, pos.y, pos.z, pedConfig.heading or 0.0, false, true)
    
    if not lobbyPed or lobbyPed == 0 then return end
    
    SetEntityAsMissionEntity(lobbyPed, true, true)
    SetPedFleeAttributes(lobbyPed, 0, 0)
    SetPedDiesWhenInjured(lobbyPed, false)
    SetPedKeepTask(lobbyPed, true)
    SetBlockingOfNonTemporaryEvents(lobbyPed, true)
    FreezeEntityPosition(lobbyPed, true)
    SetEntityInvincible(lobbyPed, true)
    
    if pedConfig.scenario and pedConfig.scenario ~= "" then
        TaskStartScenarioInPlace(lobbyPed, pedConfig.scenario, 0, true)
    end
    
    SetModelAsNoLongerNeeded(modelHash)
    
    if Config.DebugClient then
        print('^2[GF-Client]^0 Lobby PED créé')
    end
end

local function CreateLobbyBlip()
    local blipConfig = Config.Lobby.blip
    if not blipConfig or not blipConfig.enabled then return end
    
    local pos = Config.Lobby.ped.position
    lobbyBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
    
    SetBlipSprite(lobbyBlip, blipConfig.sprite or 304)
    SetBlipDisplay(lobbyBlip, 4)
    SetBlipScale(lobbyBlip, blipConfig.scale or 0.8)
    SetBlipColour(lobbyBlip, blipConfig.color or 1)
    SetBlipAsShortRange(lobbyBlip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(blipConfig.name or "Gunfight Arena")
    EndTextCommandSetBlipName(lobbyBlip)
end

-- ================================================================================================
-- OUVRIR SÉLECTEUR
-- ================================================================================================

local function OpenZoneSelector()
    if PlayerState.inArena or PlayerState.showingUI then return end
    
    if Config.DebugClient then
        print('^2[GF-Client]^0 OpenZoneSelector')
    end
    
    PlayerState.showingUI = true
    
    TriggerServerEvent('gfarena:requestZoneUpdate')
    
    local zones = {}
    for _, zone in ipairs(Config.Zones) do
        if zone.enabled then
            zones[#zones + 1] = {
                zone = zone.id,
                label = zone.name,
                image = zone.image,
                players = 0,
                maxPlayers = zone.maxPlayers
            }
        end
    end
    
    UIController.ShowMainUI(zones)
end

-- ================================================================================================
-- TÉLÉPORTATION
-- ================================================================================================

local function TeleportToArena(spawnPoint, isRespawn)
    if Config.DebugClient then
        print('^2[GF-Client]^0 TeleportToArena - isRespawn=' .. tostring(isRespawn))
    end
    
    local ped = PlayerPedId()
    local pos = spawnPoint.pos
    local heading = spawnPoint.heading or 0.0
    
    DoScreenFadeOut(250)
    Wait(300)
    
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, true, false)
        ped = PlayerPedId()
        Wait(100)
    end
    
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, heading)
    
    Wait(200)
    
    ClearPedTasksImmediately(ped)
    ClearPlayerWantedLevel(PlayerId())
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    
    -- Protection spawn
    local invincDuration = Config.Gameplay.spawnInvincibility or 3000
    SetPlayerInvincible(PlayerId(), true)
    SetEntityAlpha(ped, Config.Gameplay.spawnAlpha or 128, false)
    
    SetTimeout(Config.Gameplay.spawnAlphaDuration or 2000, function()
        local currentPed = PlayerPedId()
        if DoesEntityExist(currentPed) then
            SetEntityAlpha(currentPed, 255, false)
        end
    end)
    
    SetTimeout(invincDuration, function()
        SetPlayerInvincible(PlayerId(), false)
    end)
    
    DoScreenFadeIn(500)
    
    Wait(300)
    
    if isRespawn then
        PlayerState.lastRespawnComplete = GetTime()
    end
    
    PlayerState.isDead = false
    
    if Config.DebugClient then
        print('^2[GF-Client]^0 Téléportation terminée')
    end
end

-- ================================================================================================
-- QUITTER L'ARÈNE
-- ================================================================================================

local function ExitArena()
    if not PlayerState.inArena then return end
    
    local now = GetTime()
    if (now - Throttle.lastExitEvent) < 2000 then return end
    Throttle.lastExitEvent = now
    
    if Config.DebugClient then
        print('^3[GF-Client]^0 ExitArena - envoi au serveur')
    end
    
    TriggerServerEvent('gfarena:leaveArena')
end

-- ================================================================================================
-- EVENTS
-- ================================================================================================

-- Rejoindre une zone
RegisterNetEvent('gfarena:join')
AddEventHandler('gfarena:join', function(zoneId, isRespawn)
    if Config.DebugClient then
        print('^2[GF-Client]^0 gfarena:join - zone=' .. tostring(zoneId) .. ', isRespawn=' .. tostring(isRespawn))
    end
    
    UIController.CloseMainUI()
    PlayerState.showingUI = false
    
    local zoneData = ZoneManager.GetZone(zoneId)
    if not zoneData then
        print('^1[GF-Client]^0 Zone non trouvée: ' .. tostring(zoneId))
        return
    end
    
    local spawnPoint = ZoneManager.GetRandomSpawnPoint(zoneId)
    if not spawnPoint then
        print('^1[GF-Client]^0 Pas de spawn point')
        return
    end
    
    PlayerState.inArena = true
    PlayerState.currentZone = zoneId
    PlayerState.isDead = false
    PlayerState.spawnStartTime = GetTime()

    ZoneManager.SetCurrentZone(zoneId)
    UIController.ShowExitHud()

    TeleportToArena(spawnPoint, isRespawn)
end)

-- Équiper arme (depuis serveur - arme déjà donnée côté serveur)
RegisterNetEvent('gfarena:equipWeapon')
AddEventHandler('gfarena:equipWeapon', function(weaponName, ammo)
    if Config.DebugClient then
        print('^2[GF-Client]^0 Event: equipWeapon - ' .. tostring(weaponName))
    end
    
    -- Attendre que le joueur soit bien spawné
    Wait(200)
    
    -- Équiper l'arme visuellement (elle est déjà donnée par le serveur)
    EquipWeaponVisual(weaponName, ammo)
    
    -- Sécurité supplémentaire après 500ms
    SetTimeout(500, function()
        if PlayerState.inArena and PlayerState.weaponEquipped then
            local ped = PlayerPedId()
            local weaponHash = GetHashKey(weaponName)
            ForceWeaponInHand(ped, weaponHash)
        end
    end)
end)

-- Retirer arme (depuis serveur)
RegisterNetEvent('gfarena:removeWeapon')
AddEventHandler('gfarena:removeWeapon', function()
    if Config.DebugClient then
        print('^3[GF-Client]^0 Event: removeWeapon')
    end
    
    RemoveWeaponVisual()
end)

-- Quitter la zone (depuis serveur)
RegisterNetEvent('gfarena:exitZone')
AddEventHandler('gfarena:exitZone', function()
    if Config.DebugClient then
        print('^3[GF-Client]^0 Event: exitZone')
    end
    
    PlayerState.inArena = false
    PlayerState.currentZone = nil
    PlayerState.isDead = false
    PlayerState.weaponEquipped = false
    
    ZoneManager.SetCurrentZone(nil)
    UIController.ClearKillFeed()
    UIController.HideExitHud()
    
    -- Téléporter au lobby
    local lobbySpawn = Config.Lobby.spawn
    local ped = PlayerPedId()
    
    DoScreenFadeOut(250)
    Wait(300)
    
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(lobbySpawn.position.x, lobbySpawn.position.y, lobbySpawn.position.z, lobbySpawn.heading, true, false)
        ped = PlayerPedId()
        Wait(100)
    end
    
    SetEntityCoords(ped, lobbySpawn.position.x, lobbySpawn.position.y, lobbySpawn.position.z, false, false, false, false)
    SetEntityHeading(ped, lobbySpawn.heading)
    
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedCanSwitchWeapon(ped, true)
    
    DoScreenFadeIn(500)
end)

-- Heal joueur
RegisterNetEvent('gfarena:healPlayer')
AddEventHandler('gfarena:healPlayer', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end)

-- Kill feed
RegisterNetEvent('gfarena:killFeed')
AddEventHandler('gfarena:killFeed', function(killerName, victimName, headshot, streak, killerId, victimId)
    UIController.AddKillFeedMessage({
        killer = killerName,
        victim = victimName,
        headshot = headshot,
        multiplier = streak,
        killerId = killerId,
        victimId = victimId
    })
end)

-- Update zones
RegisterNetEvent('gfarena:updateZonePlayers')
AddEventHandler('gfarena:updateZonePlayers', function(zonesData)
    if PlayerState.showingUI then
        UIController.UpdateZonePlayers(zonesData)
    end
end)

-- UI fermée
RegisterNetEvent('gfarena:ui:closed')
AddEventHandler('gfarena:ui:closed', function()
    PlayerState.showingUI = false
end)

-- ================================================================================================
-- MORT
-- ================================================================================================

local function HandlePlayerDeath()
    if not PlayerState.inArena or PlayerState.isDead then return end
    
    local now = GetTime()
    if (now - Throttle.lastDeathEvent) < THROTTLE_DEATH then return end
    
    local timeSinceSpawn = now - PlayerState.spawnStartTime
    if timeSinceSpawn < SPAWN_GRACE_PERIOD then return end
    
    if Config.DebugClient then
        print('^1[GF-Client]^0 Mort détectée')
    end
    
    PlayerState.isDead = true
    Throttle.lastDeathEvent = now
    
    local ped = Cache.ped
    local killerId = nil
    local killerEntity = GetPedSourceOfDeath(ped)
    
    if killerEntity and killerEntity ~= 0 and killerEntity ~= ped then
        if IsPedAPlayer(killerEntity) then
            killerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(killerEntity))
        end
    end
    
    TriggerServerEvent('gfarena:playerDied', PlayerState.currentZone, killerId)
end

-- ================================================================================================
-- THREADS
-- ================================================================================================

-- Cache update
CreateThread(function()
    while true do
        UpdateCache()
        Wait(CACHE_UPDATE_INTERVAL)
    end
end)

-- Lobby interaction
CreateThread(function()
    Wait(2000)
    CreateLobbyPed()
    CreateLobbyBlip()
    
    while true do
        local sleepMs = 1000
        
        if not PlayerState.inArena and not PlayerState.showingUI then
            if Cache.lobbyDistance < 15.0 then
                sleepMs = 0

                local pedPos = GetEntityCoords(lobbyPed)
                Draw3DText(pedPos.x, pedPos.y, pedPos.z + 1.5, "~w~[ ZONE DE GUERRE ]")

                if Cache.nearLobby and IsControlJustPressed(0, Config.Keys.interact) then
                    OpenZoneSelector()
                end
            elseif Cache.lobbyDistance < 50.0 then
                sleepMs = 200
            end
        end
        
        Wait(sleepMs)
    end
end)

-- Arena gameplay + sortie zone
CreateThread(function()
    while true do
        local sleepMs = 1000
        
        if PlayerState.inArena and not PlayerState.isDead then
            sleepMs = 0
            
            -- Touche X pour quitter
            if IsControlJustPressed(0, Config.Keys.exit) then
                ExitArena()
            end
            
            -- Vérifier si hors zone (après grace period)
            local timeSinceSpawn = GetTime() - PlayerState.spawnStartTime
            if timeSinceSpawn > SPAWN_GRACE_PERIOD then
                local inBounds = ZoneManager.IsPlayerInCurrentZone(Cache.coords)
                
                if not inBounds then
                    local distToBoundary = ZoneManager.GetDistanceToBoundary(Cache.coords)
                    
                    if Config.DebugClient then
                        print('^3[GF-Client]^0 Hors zone! Distance: ' .. distToBoundary)
                    end
                    
                    if distToBoundary > 5.0 then
                        TriggerServerEvent('gfarena:outOfBounds')
                    end
                end
            end
        end
        
        Wait(sleepMs)
    end
end)

-- Death detection
CreateThread(function()
    while true do
        local sleepMs = 500
        
        if PlayerState.inArena then
            sleepMs = 100
            
            if Cache.isDead and not PlayerState.isDead then
                HandlePlayerDeath()
            end
        end
        
        Wait(sleepMs)
    end
end)

-- Zone marker
CreateThread(function()
    while true do
        local sleepMs = 1000
        
        if PlayerState.inArena and Config.Gameplay.showZoneMarker then
            local zoneData = ZoneManager.GetCurrentZoneData()
            
            if zoneData then
                sleepMs = 0
                
                local color = ZoneManager.GetMarkerColor()
                local center = zoneData.center
                local radius = zoneData.radius
                
                DrawMarker(
                    1,
                    center.x, center.y, center.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    radius * 2, radius * 2, 2.0,
                    color.r, color.g, color.b, color.a,
                    false, false, 2, false, nil, nil, false
                )
            end
        end
        
        Wait(sleepMs)
    end
end)

-- Stamina infinie
CreateThread(function()
    while true do
        if PlayerState.inArena and Config.Gameplay.infiniteStamina then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        Wait(1000)
    end
end)

-- Thread pour maintenir l'arme en main (vérification périodique)
CreateThread(function()
    while true do
        Wait(2000)
        
        if PlayerState.inArena and PlayerState.weaponEquipped and not PlayerState.isDead then
            local ped = PlayerPedId()
            local weaponHash = GetHashKey(Config.Weapon.hash)
            
            if HasPedGotWeapon(ped, weaponHash, false) then
                local currentWeapon = GetSelectedPedWeapon(ped)
                
                if currentWeapon ~= weaponHash then
                    ForceWeaponInHand(ped, weaponHash)
                    
                    if Config.DebugClient then
                        print('^3[GF-Client]^0 Arme remise en main (vérification périodique)')
                    end
                end
            end
        end
    end
end)

-- Commande
RegisterCommand(Config.Commands.exit, function()
    if PlayerState.inArena then
        ExitArena()
    else
        TriggerEvent('esx:showNotification', Config.Messages.notInArena)
    end
end, false)

-- Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if lobbyPed and DoesEntityExist(lobbyPed) then
        DeleteEntity(lobbyPed)
    end
    
    if lobbyBlip and DoesBlipExist(lobbyBlip) then
        RemoveBlip(lobbyBlip)
    end
    
    SetNuiFocus(false, false)
end)

-- Init
CreateThread(function()
    Wait(1000)
    if Config.DebugClient then
        print('^2[GF-Arena Lite]^0 Client initialisé')
    end
end)