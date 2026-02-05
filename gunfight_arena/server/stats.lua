-- ================================================================================================
-- GUNFIGHT ARENA - SYSTÈME DE STATISTIQUES
-- ================================================================================================

local Stats = {}

-- Message de confirmation au chargement
print("^3[GF-Arena]^0 Chargement du module Stats...")

-- Vérification que MySQL est disponible
if not MySQL then
    print("^1[GF-Arena] ERREUR: MySQL n'est pas disponible! Vérifie que oxmysql est bien installé.^0")
end

-- ================================================================================================
-- RÉCUPÉRER LA LICENSE D'UN JOUEUR
-- ================================================================================================

local function GetPlayerLicense(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, 8) == "license:" then
            return id
        end
    end
    return nil
end

-- ================================================================================================
-- ENREGISTRER UN KILL
-- ================================================================================================

function Stats.RecordKill(source)
    local license = GetPlayerLicense(source)
    if not license then
        if Config.DebugServer then
            Utils.Log(("Stats: Impossible de récupérer la license pour joueur %d"):format(source), "warning")
        end
        return
    end

    -- Insérer ou mettre à jour les stats du joueur
    MySQL.Async.execute([[
        INSERT INTO gunfight_stats (license, kills, deaths)
        VALUES (@license, 1, 0)
        ON DUPLICATE KEY UPDATE kills = kills + 1
    ]], {
        ['@license'] = license
    }, function(rowsChanged)
        if Config.DebugServer then
            Utils.Log(("Stats: Kill enregistré pour %s"):format(license), "debug")
        end
    end)
end

-- ================================================================================================
-- ENREGISTRER UNE MORT
-- ================================================================================================

function Stats.RecordDeath(source)
    local license = GetPlayerLicense(source)
    if not license then return end

    MySQL.Async.execute([[
        INSERT INTO gunfight_stats (license, kills, deaths)
        VALUES (@license, 0, 1)
        ON DUPLICATE KEY UPDATE deaths = deaths + 1
    ]], {
        ['@license'] = license
    })
end

-- ================================================================================================
-- RÉCUPÉRER LES STATS D'UN JOUEUR
-- ================================================================================================

function Stats.GetPlayerStats(source, callback)
    local license = GetPlayerLicense(source)
    if not license then
        callback(nil)
        return
    end

    MySQL.Async.fetchAll([[
        SELECT kills, deaths FROM gunfight_stats WHERE license = @license
    ]], {
        ['@license'] = license
    }, function(result)
        if result and result[1] then
            callback(result[1])
        else
            callback({ kills = 0, deaths = 0 })
        end
    end)
end

-- ================================================================================================
-- RÉCUPÉRER LE CLASSEMENT (TOP KILLERS)
-- ================================================================================================

function Stats.GetLeaderboard(limit, callback)
    limit = limit or 10

    MySQL.Async.fetchAll([[
        SELECT license, kills, deaths
        FROM gunfight_stats
        ORDER BY kills DESC
        LIMIT @limit
    ]], {
        ['@limit'] = limit
    }, function(result)
        callback(result or {})
    end)
end

-- ================================================================================================
-- RÉCUPÉRER LES STATS PAR LICENSE (pour usage externe)
-- ================================================================================================

function Stats.GetStatsByLicense(license, callback)
    MySQL.Async.fetchAll([[
        SELECT kills, deaths FROM gunfight_stats WHERE license = @license
    ]], {
        ['@license'] = license
    }, function(result)
        if result and result[1] then
            callback(result[1])
        else
            callback(nil)
        end
    end)
end

-- ================================================================================================
-- EXPORTS POUR USAGE EXTERNE
-- ================================================================================================

exports('GetPlayerLicense', GetPlayerLicense)
exports('GetPlayerStats', Stats.GetPlayerStats)
exports('GetLeaderboard', Stats.GetLeaderboard)
exports('GetStatsByLicense', Stats.GetStatsByLicense)

_G.Stats = Stats

print("^2[GF-Arena]^0 Module Stats chargé avec succès!")

return Stats
