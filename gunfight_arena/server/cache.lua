-- ================================================================================================
-- GUNFIGHT ARENA LITE - CACHE SERVEUR
-- ================================================================================================

local Cache = {}

local PlayerCache = {}
local ZoneCache = {}
local ThrottleTimers = {}

function Cache.CreatePlayer(source, name)
    if not Utils.IsValidSource(source) then return nil end
    
    PlayerCache[source] = {
        name = name or "Joueur",
        inArena = false,
        zoneId = nil,
        routingBucket = 0,
        session = { kills = 0, deaths = 0, currentStreak = 0 },
    }
    
    if Config.DebugServer then
        Utils.Log(("Cache créé pour joueur %d (%s)"):format(source, name), "debug")
    end
    
    return PlayerCache[source]
end

function Cache.GetPlayer(source)
    return PlayerCache[source]
end

function Cache.HasPlayer(source)
    return PlayerCache[source] ~= nil
end

function Cache.RemovePlayer(source)
    local player = PlayerCache[source]
    PlayerCache[source] = nil
    ThrottleTimers[source] = nil
    return player
end

function Cache.SetPlayerInArena(source, zoneId, bucket)
    local player = PlayerCache[source]
    if not player then return false end
    
    player.inArena = true
    player.zoneId = zoneId
    player.routingBucket = bucket
    player.session.currentStreak = 0
    
    ZoneCache[zoneId] = (ZoneCache[zoneId] or 0) + 1
    
    if Config.DebugServer then
        Utils.Log(("Joueur %d ajouté à zone %d (total: %d)"):format(source, zoneId, ZoneCache[zoneId]), "debug")
    end
    
    return true
end

function Cache.RemovePlayerFromArena(source)
    local player = PlayerCache[source]
    if not player or not player.inArena then return nil end
    
    local previousZone = player.zoneId
    
    player.inArena = false
    player.zoneId = nil
    player.routingBucket = 0
    player.session.currentStreak = 0
    
    if previousZone and ZoneCache[previousZone] then
        ZoneCache[previousZone] = math.max(0, ZoneCache[previousZone] - 1)
    end
    
    return previousZone
end

function Cache.IsPlayerInArena(source)
    local player = PlayerCache[source]
    return player and player.inArena or false
end

function Cache.GetPlayerZone(source)
    local player = PlayerCache[source]
    return player and player.zoneId or nil
end

function Cache.RecordKill(killerId, victimId)
    local killer = PlayerCache[killerId]
    local victim = PlayerCache[victimId]
    
    if killer then
        killer.session.kills = killer.session.kills + 1
        killer.session.currentStreak = killer.session.currentStreak + 1
    end
    
    if victim then
        victim.session.deaths = victim.session.deaths + 1
        victim.session.currentStreak = 0
    end
    
    return killer and killer.session.currentStreak or 0
end

function Cache.GetZonePlayerCount(zoneId)
    return ZoneCache[zoneId] or 0
end

function Cache.IsZoneFull(zoneId)
    local zone = Utils.GetZoneById(zoneId)
    if not zone then return true end
    return (ZoneCache[zoneId] or 0) >= zone.maxPlayers
end

function Cache.GetAllZonesData()
    local data = {}
    for _, zone in pairs(Config.ZonesIndex) do
        data[#data + 1] = {
            zone = zone.id,
            name = zone.name,
            players = ZoneCache[zone.id] or 0,
            maxPlayers = zone.maxPlayers,
        }
    end
    return data
end

function Cache.GetZonePlayers(zoneId)
    local players = {}
    for source, player in pairs(PlayerCache) do
        if player.zoneId == zoneId then
            players[#players + 1] = source
        end
    end
    return players
end

function Cache.IsThrottled(source, action)
    local key = source .. "_" .. action
    local now = GetGameTimer()
    local cooldown = Config.Performance.throttle[action] or 1000
    
    if ThrottleTimers[key] and (now - ThrottleTimers[key]) < cooldown then
        return true
    end
    
    ThrottleTimers[key] = now
    return false
end

_G.Cache = Cache
return Cache
