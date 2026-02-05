-- ================================================================================================
-- GUNFIGHT ARENA LITE - ZONES MANAGER SERVEUR
-- ================================================================================================

local ZonesManager = {}

local lastBroadcast = 0

local function SetPlayerBucketAsync(source, bucketId)
    CreateThread(function()
        if GetPlayerPing(source) == 0 then return end
        
        pcall(function()
            SetPlayerRoutingBucket(source, bucketId)
        end)
        
        Wait(100)
        
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            pcall(function()
                SetEntityRoutingBucket(ped, bucketId)
            end)
        end
        
        if Config.DebugServer then
            Utils.Log(("Joueur %d -> bucket %d"):format(source, bucketId), "debug")
        end
    end)
end

local function ResetPlayerBucket(source)
    CreateThread(function()
        if GetPlayerPing(source) == 0 then return end
        
        pcall(function()
            SetPlayerRoutingBucket(source, 0)
        end)
        
        Wait(50)
        
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            pcall(function()
                SetEntityRoutingBucket(ped, 0)
            end)
        end
    end)
end

function ZonesManager.IsPlayerInArena(source)
    return Cache.IsPlayerInArena(source)
end

function ZonesManager.GetPlayerZone(source)
    return Cache.GetPlayerZone(source)
end

function ZonesManager.IsZoneFull(zoneId)
    return Cache.IsZoneFull(zoneId)
end

function ZonesManager.AddPlayerToZone(source, zoneId)
    if not Utils.IsValidSource(source) or not Utils.IsValidZoneId(zoneId) then
        return false
    end
    
    local zone = Utils.GetZoneById(zoneId)
    if not zone or ZonesManager.IsZoneFull(zoneId) then
        return false
    end
    
    if Cache.IsPlayerInArena(source) then
        ZonesManager.RemovePlayerFromZone(source)
    end
    
    local success = Cache.SetPlayerInArena(source, zoneId, zone.routingBucket)
    if not success then return false end
    
    SetPlayerBucketAsync(source, zone.routingBucket)
    ZonesManager.BroadcastZoneUpdate()
    
    if Config.DebugServer then
        Utils.Log(("Joueur %d ajouté à zone %d (%s)"):format(source, zoneId, zone.name), "success")
    end
    
    return true
end

function ZonesManager.RemovePlayerFromZone(source)
    if not Cache.IsPlayerInArena(source) then return end
    
    Cache.RemovePlayerFromArena(source)
    ResetPlayerBucket(source)
    ZonesManager.BroadcastZoneUpdate()
end

function ZonesManager.GetRandomSpawnPoint(zoneId)
    local zone = Utils.GetZoneById(zoneId)
    if not zone or not zone.spawnPoints or #zone.spawnPoints == 0 then
        return nil
    end
    return Utils.RandomElement(zone.spawnPoints)
end

function ZonesManager.GetZonePlayers(zoneId)
    return Cache.GetZonePlayers(zoneId)
end

function ZonesManager.BroadcastZoneUpdate()
    local now = GetGameTimer()
    if (now - lastBroadcast) < 500 then return end
    lastBroadcast = now
    
    local zonesData = Cache.GetAllZonesData()
    TriggerClientEvent('gfarena:updateZonePlayers', -1, zonesData)
end

CreateThread(function()
    Wait(2000)
    Utils.Log(("Zones Manager initialisé - %d zones"):format(Utils.TableCount(Config.ZonesIndex)), "success")
end)

_G.ZonesManager = ZonesManager
return ZonesManager
