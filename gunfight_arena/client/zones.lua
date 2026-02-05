-- ================================================================================================
-- GUNFIGHT ARENA LITE - ZONES CLIENT
-- ================================================================================================

local ZoneManager = {}

local currentZone = nil
local currentZoneData = nil
local isInZone = false
local lastSpawnIndex = 0

local zoneLookup = {}

local function BuildZoneLookup()
    for _, zone in ipairs(Config.Zones) do
        if zone.enabled then
            zoneLookup[zone.id] = zone
        end
    end
end

function ZoneManager.GetZone(zoneId)
    return zoneLookup[zoneId]
end

function ZoneManager.GetZoneCount()
    local count = 0
    for _ in pairs(zoneLookup) do count = count + 1 end
    return count
end

function ZoneManager.GetRandomSpawnPoint(zoneId)
    local zone = zoneLookup[zoneId]
    if not zone or not zone.spawnPoints or #zone.spawnPoints == 0 then
        return nil
    end
    
    local count = #zone.spawnPoints
    local selectedIndex = math.random(1, count)
    lastSpawnIndex = selectedIndex
    
    return zone.spawnPoints[selectedIndex]
end

function ZoneManager.SetCurrentZone(zoneId)
    if zoneId then
        currentZone = zoneId
        currentZoneData = zoneLookup[zoneId]
        isInZone = true
        
        if Config.DebugClient then
            print('^2[GF-Zones]^0 Zone courante: ' .. zoneId)
        end
    else
        currentZone = nil
        currentZoneData = nil
        isInZone = false
    end
end

function ZoneManager.GetCurrentZone()
    return currentZone
end

function ZoneManager.GetCurrentZoneData()
    return currentZoneData
end

function ZoneManager.IsInZone()
    return isInZone
end

function ZoneManager.IsPlayerInCurrentZone(playerCoords)
    if not isInZone or not currentZoneData then
        return false
    end
    
    local dist = #(playerCoords - currentZoneData.center)
    return dist <= currentZoneData.radius
end

function ZoneManager.GetDistanceToBoundary(playerCoords)
    if not currentZoneData then return math.huge end
    local dist = #(playerCoords - currentZoneData.center)
    return dist - currentZoneData.radius
end

function ZoneManager.GetMarkerColor()
    if currentZoneData and currentZoneData.markerColor then
        return currentZoneData.markerColor
    end
    return {r = 255, g = 0, b = 0, a = 50}
end

function ZoneManager.Cleanup()
    currentZone = nil
    currentZoneData = nil
    isInZone = false
    lastSpawnIndex = 0
end

CreateThread(function()
    BuildZoneLookup()
    if Config.DebugClient then
        print('^2[GF-Zones]^0 Initialisé - ' .. ZoneManager.GetZoneCount() .. ' zones')
    end
end)

_G.ZoneManager = ZoneManager
return ZoneManager
