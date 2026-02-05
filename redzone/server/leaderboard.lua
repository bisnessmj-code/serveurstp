--[[
    =====================================================
    REDZONE LEAGUE - Système de Leaderboard (Classement)
    =====================================================
    Ce fichier gère le tracking des kills et le classement
    des joueurs dans la redzone.

    Table SQL requise: redzone_leaderboard
    - identifier: identifiant unique du joueur (license:xxx)
    - name: nom du joueur
    - kills: nombre total de kills
    - deaths: nombre total de morts
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}
Redzone.Server.Leaderboard = {}

-- =====================================================
-- CONFIGURATION
-- =====================================================

local LeaderboardConfig = {
    -- Activer/désactiver le système
    Enabled = true,
    -- Nombre de joueurs dans le top classement
    TopPlayers = 3,
    -- Cache du leaderboard (rafraîchi toutes les X secondes)
    CacheTime = 30,
    -- Configuration Discord
    Discord = {
        -- Activer l'envoi automatique quotidien
        AutoSend = true,
        -- Heure d'envoi (format 24h)
        SendHour = 20,
        SendMinute = 0,
        -- Nombre de joueurs dans le classement Discord
        TopPlayersDiscord = 15,
        -- Image du logo (thumbnail)
        LogoUrl = 'https://r2.fivemanage.com/65OINTV6xwj2vOK7XWptj/logo.png',
        -- Couleur de l'embed (en décimal, rouge/orange)
        EmbedColor = 16729156,  -- #FF5544
        -- Titre de l'embed
        Title = '🏆 REDZONE LEAGUE - Classement',
    }
}

-- Cache local pour éviter trop de requêtes
local leaderboardCache = {
    data = {},
    lastUpdate = 0
}

-- Framework ESX (pour vérification des permissions admin)
local ESX = nil
CreateThread(function()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
end)

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Récupère l'identifier d'un joueur (format license:xxx)
---@param source number ID serveur du joueur
---@return string|nil identifier
local function GetPlayerIdentifier(source)
    if not source or source <= 0 then return nil end

    local identifiers = GetPlayerIdentifiers(source)
    if not identifiers then return nil end

    -- Chercher l'identifier license (format: license:xxx)
    for _, id in pairs(identifiers) do
        if string.find(id, 'license:') then
            return id
        end
    end

    -- Fallback sur le premier identifier disponible
    return identifiers[1]
end

---Récupère le nom d'un joueur
---@param source number ID serveur du joueur
---@return string name
local function GetPlayerNameSafe(source)
    if not source or source <= 0 then return 'Inconnu' end
    return GetPlayerName(source) or 'Inconnu'
end

-- =====================================================
-- FONCTIONS DE BASE DE DONNÉES (ASYNCHRONES)
-- =====================================================

---Enregistre un kill pour un joueur (INSERT ou UPDATE)
---@param killerSource number ID serveur du tueur
---@param victimSource number ID serveur de la victime
function Redzone.Server.Leaderboard.RegisterKill(killerSource, victimSource)
    if not LeaderboardConfig.Enabled then return end

    local killerIdentifier = GetPlayerIdentifier(killerSource)
    local killerName = GetPlayerNameSafe(killerSource)

    if not killerIdentifier then
        Redzone.Shared.Debug('[LEADERBOARD] Impossible de récupérer l\'identifier du tueur: ', killerSource)
        return
    end

    -- Requête asynchrone: INSERT ou UPDATE si existe déjà
    MySQL.Async.execute([[
        INSERT INTO redzone_leaderboard (identifier, name, kills, last_kill)
        VALUES (?, ?, 1, NOW())
        ON DUPLICATE KEY UPDATE
            kills = kills + 1,
            name = VALUES(name),
            last_kill = NOW()
    ]], {killerIdentifier, killerName}, function(rowsChanged)
        if rowsChanged and rowsChanged > 0 then
            Redzone.Shared.Debug('[LEADERBOARD] Kill enregistré pour: ', killerName, ' (', killerIdentifier, ')')
        else
            Redzone.Shared.Debug('[LEADERBOARD] ERREUR: Impossible d\'enregistrer le kill')
        end
    end)

    -- Enregistrer aussi la mort de la victime
    if victimSource and victimSource > 0 then
        Redzone.Server.Leaderboard.RegisterDeath(victimSource)
    end

    -- Invalider le cache
    leaderboardCache.lastUpdate = 0
end

---Enregistre une mort pour un joueur
---@param victimSource number ID serveur de la victime
function Redzone.Server.Leaderboard.RegisterDeath(victimSource)
    if not LeaderboardConfig.Enabled then return end

    local victimIdentifier = GetPlayerIdentifier(victimSource)
    local victimName = GetPlayerNameSafe(victimSource)

    if not victimIdentifier then return end

    -- Requête asynchrone: INSERT ou UPDATE si existe déjà
    MySQL.Async.execute([[
        INSERT INTO redzone_leaderboard (identifier, name, deaths)
        VALUES (?, ?, 1)
        ON DUPLICATE KEY UPDATE
            deaths = deaths + 1,
            name = VALUES(name)
    ]], {victimIdentifier, victimName}, function(rowsChanged)
        Redzone.Shared.Debug('[LEADERBOARD] Mort enregistrée pour: ', victimName)
    end)
end

---Récupère le classement des meilleurs joueurs (asynchrone)
---@param limit number Nombre de joueurs à récupérer (default: 3)
---@param callback function Fonction appelée avec les résultats
function Redzone.Server.Leaderboard.GetTopPlayers(limit, callback)
    if not LeaderboardConfig.Enabled then
        if callback then callback({}) end
        return
    end

    limit = limit or LeaderboardConfig.TopPlayers
    local now = os.time()

    -- Utiliser le cache si encore valide
    if leaderboardCache.lastUpdate > 0 and (now - leaderboardCache.lastUpdate) < LeaderboardConfig.CacheTime then
        if callback then callback(leaderboardCache.data) end
        return
    end

    -- Requête asynchrone pour récupérer le top
    MySQL.Async.fetchAll([[
        SELECT identifier, name, kills, deaths,
               CASE WHEN deaths > 0 THEN ROUND(kills / deaths, 2) ELSE kills END as kd_ratio
        FROM redzone_leaderboard
        WHERE kills > 0
        ORDER BY kills DESC
        LIMIT ?
    ]], {limit}, function(results)
        if results then
            leaderboardCache.data = results
            leaderboardCache.lastUpdate = now
            Redzone.Shared.Debug('[LEADERBOARD] Cache mis à jour: ', #results, ' joueurs')
        else
            results = {}
        end

        if callback then callback(results) end
    end)
end

---Récupère les stats d'un joueur spécifique (asynchrone)
---@param identifier string L'identifier du joueur
---@param callback function Fonction appelée avec les résultats
function Redzone.Server.Leaderboard.GetPlayerStats(identifier, callback)
    if not LeaderboardConfig.Enabled or not identifier then
        if callback then callback(nil) end
        return
    end

    MySQL.Async.fetchAll([[
        SELECT identifier, name, kills, deaths,
               CASE WHEN deaths > 0 THEN ROUND(kills / deaths, 2) ELSE kills END as kd_ratio,
               (SELECT COUNT(*) + 1 FROM redzone_leaderboard WHERE kills > l.kills) as rank
        FROM redzone_leaderboard l
        WHERE identifier = ?
    ]], {identifier}, function(results)
        if results and results[1] then
            if callback then callback(results[1]) end
        else
            if callback then callback(nil) end
        end
    end)
end

---Récupère les stats d'un joueur par son source ID (asynchrone)
---@param source number ID serveur du joueur
---@param callback function Fonction appelée avec les résultats
function Redzone.Server.Leaderboard.GetPlayerStatsBySource(source, callback)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        if callback then callback(nil) end
        return
    end
    Redzone.Server.Leaderboard.GetPlayerStats(identifier, callback)
end

-- =====================================================
-- SYSTÈME DISCORD WEBHOOK
-- =====================================================

---Récupère le webhook Discord depuis server.cfg
---@return string|nil webhook URL du webhook
local function GetDiscordWebhook()
    local webhook = GetConvar('redzone_leaderboard_webhook', '')
    if webhook == '' then
        return nil
    end
    return webhook
end

---Génère les médailles pour le classement
---@param rank number Le rang du joueur
---@return string emoji
local function GetRankEmoji(rank)
    if rank == 1 then return '🥇'
    elseif rank == 2 then return '🥈'
    elseif rank == 3 then return '🥉'
    else return '▫️'
    end
end

---Formate le K/D ratio
---@param kills number
---@param deaths number
---@return string
local function FormatKD(kills, deaths)
    if deaths == 0 then
        return tostring(kills) .. '.00'
    end
    return string.format('%.2f', kills / deaths)
end

---Envoie le leaderboard sur Discord via webhook
---@param limit number Nombre de joueurs à afficher (default: 15)
---@param callback function|nil Callback optionnel
function Redzone.Server.Leaderboard.SendToDiscord(limit, callback)
    local webhook = GetDiscordWebhook()
    if not webhook then
        print('^1[REDZONE LEADERBOARD] ERREUR: Webhook Discord non configuré!^0')
        print('^3[REDZONE LEADERBOARD] Ajoutez dans server.cfg: set redzone_leaderboard_webhook "VOTRE_WEBHOOK_URL"^0')
        if callback then callback(false, 'Webhook non configuré') end
        return
    end

    limit = limit or LeaderboardConfig.Discord.TopPlayersDiscord

    -- Récupérer le top joueurs directement depuis la BDD (sans cache)
    MySQL.Async.fetchAll([[
        SELECT identifier, name, kills, deaths,
               CASE WHEN deaths > 0 THEN ROUND(kills / deaths, 2) ELSE kills END as kd_ratio
        FROM redzone_leaderboard
        WHERE kills > 0
        ORDER BY kills DESC
        LIMIT ?
    ]], {limit}, function(results)
        if not results or #results == 0 then
            print('[REDZONE LEADERBOARD] Aucun joueur à afficher dans le classement')
            if callback then callback(false, 'Aucun joueur') end
            return
        end

        -- Construire le contenu du classement
        local leaderboardText = ''
        for i, player in ipairs(results) do
            local emoji = GetRankEmoji(i)
            local kd = FormatKD(player.kills, player.deaths)

            -- Format: 🥇 1. PlayerName - 156 kills (K/D: 3.71)
            if i <= 3 then
                -- Top 3 en gras
                leaderboardText = leaderboardText .. string.format(
                    '%s **%d. %s** - **%d** kills (%d deaths) • K/D: **%s**\n',
                    emoji, i, player.name, player.kills, player.deaths, kd
                )
            else
                leaderboardText = leaderboardText .. string.format(
                    '%s %d. %s - %d kills (%d deaths) • K/D: %s\n',
                    emoji, i, player.name, player.kills, player.deaths, kd
                )
            end
        end

        -- Statistiques globales
        MySQL.Async.fetchAll([[
            SELECT
                COUNT(*) as total_players,
                SUM(kills) as total_kills,
                SUM(deaths) as total_deaths
            FROM redzone_leaderboard
            WHERE kills > 0
        ]], {}, function(stats)
            local totalPlayers = stats and stats[1] and stats[1].total_players or 0
            local totalKills = stats and stats[1] and stats[1].total_kills or 0

            -- Construire l'embed Discord
            local embed = {
                {
                    title = LeaderboardConfig.Discord.Title,
                    description = leaderboardText,
                    color = LeaderboardConfig.Discord.EmbedColor,
                    thumbnail = {
                        url = LeaderboardConfig.Discord.LogoUrl
                    },
                    fields = {
                        {
                            name = '📊 Statistiques Globales',
                            value = string.format('**%d** joueurs classés\n**%d** kills au total', totalPlayers, totalKills),
                            inline = false
                        }
                    },
                    footer = {
                        text = '🎮 REDZONE LEAGUE • Classement mis à jour'
                    },
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
                }
            }

            -- Envoyer le webhook
            PerformHttpRequest(webhook, function(statusCode, response, headers)
                if statusCode >= 200 and statusCode < 300 then
                    print('[REDZONE LEADERBOARD] Classement envoyé sur Discord avec succès!')
                    if callback then callback(true) end
                else
                    print('^1[REDZONE LEADERBOARD] Erreur envoi Discord: ' .. tostring(statusCode) .. '^0')
                    if callback then callback(false, 'HTTP ' .. tostring(statusCode)) end
                end
            end, 'POST', json.encode({
                username = 'REDZONE LEAGUE',
                avatar_url = LeaderboardConfig.Discord.LogoUrl,
                embeds = embed
            }), {['Content-Type'] = 'application/json'})
        end)
    end)
end

-- Variable pour tracker si on a déjà envoyé aujourd'hui
local lastSendDate = nil

---Vérifie si c'est l'heure d'envoyer le classement
local function CheckAutoSend()
    if not LeaderboardConfig.Discord.AutoSend then return end

    local currentHour = tonumber(os.date('%H'))
    local currentMinute = tonumber(os.date('%M'))
    local currentDate = os.date('%Y-%m-%d')

    -- Vérifier si c'est l'heure configurée et qu'on n'a pas déjà envoyé aujourd'hui
    if currentHour == LeaderboardConfig.Discord.SendHour
       and currentMinute == LeaderboardConfig.Discord.SendMinute
       and lastSendDate ~= currentDate then

        lastSendDate = currentDate
        print('[REDZONE LEADERBOARD] Envoi automatique du classement quotidien...')
        Redzone.Server.Leaderboard.SendToDiscord(LeaderboardConfig.Discord.TopPlayersDiscord)
    end
end

-- Thread pour l'envoi automatique quotidien
CreateThread(function()
    -- Attendre que tout soit initialisé
    Wait(5000)

    while true do
        CheckAutoSend()
        -- Vérifier toutes les 30 secondes
        Wait(30000)
    end
end)

-- =====================================================
-- ÉVÉNEMENTS RÉSEAU
-- =====================================================

---Événement: Client demande le leaderboard
RegisterNetEvent('redzone:leaderboard:getTop')
AddEventHandler('redzone:leaderboard:getTop', function(limit)
    local source = source
    Redzone.Server.Leaderboard.GetTopPlayers(limit or 3, function(topPlayers)
        TriggerClientEvent('redzone:leaderboard:receiveTop', source, topPlayers)
    end)
end)

---Événement: Client demande ses propres stats
RegisterNetEvent('redzone:leaderboard:getMyStats')
AddEventHandler('redzone:leaderboard:getMyStats', function()
    local source = source
    Redzone.Server.Leaderboard.GetPlayerStatsBySource(source, function(stats)
        TriggerClientEvent('redzone:leaderboard:receiveMyStats', source, stats)
    end)
end)

-- =====================================================
-- EXPORTS
-- =====================================================

-- Export pour enregistrer un kill (utilisable par d'autres scripts)
exports('RegisterKill', function(killerSource, victimSource)
    Redzone.Server.Leaderboard.RegisterKill(killerSource, victimSource)
end)

-- Export pour récupérer le top (synchrone via callback)
exports('GetTopPlayers', function(limit, callback)
    Redzone.Server.Leaderboard.GetTopPlayers(limit, callback)
end)

-- Export pour récupérer les stats d'un joueur
exports('GetPlayerStats', function(identifier, callback)
    Redzone.Server.Leaderboard.GetPlayerStats(identifier, callback)
end)

-- Export pour envoyer le classement sur Discord
exports('SendLeaderboardToDiscord', function(limit, callback)
    Redzone.Server.Leaderboard.SendToDiscord(limit, callback)
end)

-- =====================================================
-- COMMANDES ADMIN (DEBUG)
-- =====================================================

RegisterCommand('redzone_top', function(source, args)
    local limit = tonumber(args[1]) or 3

    Redzone.Server.Leaderboard.GetTopPlayers(limit, function(topPlayers)
        print('[REDZONE LEADERBOARD] Top ' .. limit .. ' joueurs:')
        print('========================================')
        for i, player in ipairs(topPlayers) do
            print(string.format('#%d - %s: %d kills, %d deaths (K/D: %.2f)',
                i, player.name, player.kills, player.deaths, player.kd_ratio or 0))
        end
        print('========================================')

        -- Si c'est un joueur qui exécute la commande, lui envoyer aussi
        if source > 0 then
            TriggerClientEvent('redzone:leaderboard:receiveTop', source, topPlayers)
        end
    end)
end, false)

RegisterCommand('redzone_mystats', function(source, args)
    if source <= 0 then
        print('Cette commande doit être exécutée par un joueur')
        return
    end

    Redzone.Server.Leaderboard.GetPlayerStatsBySource(source, function(stats)
        if stats then
            TriggerClientEvent('chat:addMessage', source, {
                args = {'^2[REDZONE]', string.format('Tes stats: %d kills, %d deaths (K/D: %.2f) - Rang #%d',
                    stats.kills, stats.deaths, stats.kd_ratio or 0, stats.rank or 0)}
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                args = {'^2[REDZONE]', 'Tu n\'as pas encore de statistiques.'}
            })
        end
    end)
end, false)

---Commande admin pour envoyer le classement sur Discord
RegisterCommand('redzone_discord', function(source, args)
    -- Vérifier les permissions (console ou admin)
    if source > 0 then
        local xPlayer = ESX and ESX.GetPlayerFromId(source)
        if not xPlayer then
            TriggerClientEvent('chat:addMessage', source, {
                args = {'^1[REDZONE]', 'Erreur: Impossible de vérifier vos permissions.'}
            })
            return
        end

        local group = xPlayer.getGroup()
        if group ~= 'admin' and group ~= 'superadmin' and group ~= 'god' then
            TriggerClientEvent('chat:addMessage', source, {
                args = {'^1[REDZONE]', 'Vous n\'avez pas la permission d\'utiliser cette commande.'}
            })
            return
        end
    end

    local limit = tonumber(args[1]) or 15
    print('[REDZONE LEADERBOARD] Envoi manuel du classement demandé par ' .. (source > 0 and GetPlayerName(source) or 'Console'))

    Redzone.Server.Leaderboard.SendToDiscord(limit, function(success, error)
        local message
        if success then
            message = '^2[REDZONE] Classement envoyé sur Discord avec succès!^0'
        else
            message = '^1[REDZONE] Erreur lors de l\'envoi: ' .. tostring(error) .. '^0'
        end

        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                args = {'[REDZONE]', success and 'Classement envoyé sur Discord!' or ('Erreur: ' .. tostring(error))}
            })
        end
        print(message)
    end)
end, false)

-- =====================================================
-- DÉMARRAGE
-- =====================================================

CreateThread(function()
    -- Attendre que MySQL soit prêt
    Wait(1000)

    -- Vérifier que la table existe
    MySQL.Async.fetchAll('SHOW TABLES LIKE "redzone_leaderboard"', {}, function(result)
        if result and #result > 0 then
            Redzone.Shared.Debug('[LEADERBOARD] Table redzone_leaderboard trouvée')
        else
            print('^1[REDZONE LEADERBOARD] ATTENTION: La table redzone_leaderboard n\'existe pas!^0')
            print('^3[REDZONE LEADERBOARD] Exécutez le fichier sql/redzone_leaderboard.sql dans votre base de données^0')
        end
    end)

    Redzone.Shared.Debug('[SERVER/LEADERBOARD] Module Leaderboard chargé')
end)
