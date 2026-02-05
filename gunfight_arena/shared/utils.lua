-- ================================================================================================
-- GUNFIGHT ARENA LITE - UTILS
-- ================================================================================================

local Utils = {}

function Utils.Distance3D(pos1, pos2)
    return #(pos1 - pos2)
end

function Utils.IsValidZoneId(zoneId)
    if type(zoneId) ~= "number" then return false end
    return Config.ZonesIndex[zoneId] ~= nil
end

function Utils.GetZoneById(zoneId)
    return Config.ZonesIndex[zoneId]
end

function Utils.IsValidSource(source)
    if type(source) ~= "number" then return false end
    return source > 0 and source < 65535
end

function Utils.Log(message, level)
    level = level or "info"
    local colors = {error = "^1", success = "^2", warning = "^3", info = "^5", debug = "^6"}
    print((colors[level] or "^7") .. "[GF-Arena]^7 " .. tostring(message))
end

function Utils.TableCount(tbl)
    if type(tbl) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function Utils.RandomElement(tbl)
    if type(tbl) ~= "table" or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

math.randomseed(GetGameTimer())

_G.Utils = Utils
return Utils
