--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    MODULE DE SÉCURITÉ                            ║
    ╚══════════════════════════════════════════════════════════════════╝

    Ce module gère la sécurité du système:
    - Vérification des permissions
    - Protection anti-abus (rate limiting)
    - Système de logs sécurisé
    - Intégration Discord webhook
]]

-- ============================================================
-- NAMESPACE DU MODULE
-- ============================================================
Security = {}

-- ============================================================
-- VARIABLES PRIVÉES
-- ============================================================
local commandHistory = {}       -- Historique des commandes par joueur (rate limiting)
local logBuffer = {}            -- Buffer pour les logs en lot

-- ============================================================
-- VÉRIFICATION DES PERMISSIONS
-- ============================================================

--- Vérifier si un joueur a la permission admin
-- @param source number L'ID serveur du joueur
-- @return boolean Le joueur a-t-il la permission
function Security.HasPermission(source)
    -- La console a toujours la permission
    if source == 0 then
        return true
    end

    local permSystem = Config.Permissions.System

    if permSystem == 'ace' then
        return Security.CheckACEPermission(source)
    elseif permSystem == 'identifier' then
        return Security.CheckIdentifierPermission(source)
    end

    return false
end

--- Vérifier la permission via le système ACE de FiveM
-- @param source number L'ID serveur du joueur
-- @return boolean Le joueur a-t-il la permission ACE
function Security.CheckACEPermission(source)
    local permission = Config.Permissions.AcePermission

    if IsPlayerAceAllowed(source, permission) then
        return true
    end

    -- Vérifications alternatives communes
    if IsPlayerAceAllowed(source, 'command') then
        return true
    end

    return false
end

--- Vérifier la permission via la liste d'identifiants
-- @param source number L'ID serveur du joueur
-- @return boolean Le joueur a-t-il un identifiant autorisé
function Security.CheckIdentifierPermission(source)
    local playerIdentifiers = Utils.GetPlayerIdentifiers(source)
    local allowedIdentifiers = Config.Permissions.AllowedIdentifiers

    for _, allowedId in ipairs(allowedIdentifiers) do
        for idType, playerId in pairs(playerIdentifiers) do
            if playerId == allowedId then
                return true
            end
        end
    end

    return false
end

-- ============================================================
-- RATE LIMITING
-- ============================================================

--- Vérifier si un joueur peut exécuter une commande (rate limit)
-- @param source number L'ID serveur du joueur
-- @return boolean, string Peut exécuter, Message d'erreur
function Security.CheckRateLimit(source)
    if not Config.Security.RateLimiting.Enabled then
        return true, nil
    end

    -- La console n'est pas limitée
    if source == 0 then
        return true, nil
    end

    local currentTime = os.time()
    local maxCommands = Config.Security.RateLimiting.MaxCommands
    local timeWindow = Config.Security.RateLimiting.TimeWindow

    -- Initialiser l'historique du joueur si nécessaire
    if not commandHistory[source] then
        commandHistory[source] = {}
    end

    local history = commandHistory[source]

    -- Nettoyer les anciennes entrées
    local validEntries = {}

    for _, timestamp in ipairs(history) do
        if currentTime - timestamp < timeWindow then
            table.insert(validEntries, timestamp)
        end
    end

    commandHistory[source] = validEntries

    -- Vérifier la limite
    if #validEntries >= maxCommands then
        return false, string.format(
            '❌ Trop de commandes. Attendez %d secondes.',
            timeWindow - (currentTime - validEntries[1])
        )
    end

    -- Ajouter la nouvelle commande
    table.insert(commandHistory[source], currentTime)

    return true, nil
end

--- Nettoyer l'historique des commandes d'un joueur déconnecté
-- @param source number L'ID serveur du joueur
function Security.ClearPlayerHistory(source)
    commandHistory[source] = nil
end

-- ============================================================
-- SYSTÈME DE LOGS
-- ============================================================

--- Enregistrer un log
-- @param logType string Type de log ('BAN', 'UNBAN', 'TEMPBAN', 'ATTEMPT', 'ERROR', 'INFO')
-- @param message string Le message à logger
-- @param data table|nil Données supplémentaires
function Security.Log(logType, message, data)
    if not Config.Logs.Enabled then
        return
    end

    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local logEntry = string.format('[%s] [%s] %s', timestamp, logType, message)

    -- Log dans la console serveur
    if Config.Logs.ToConsole then
        local color = '^0'

        if logType == 'BAN' or logType == 'ERROR' then
            color = '^1'
        elseif logType == 'UNBAN' or logType == 'INFO' then
            color = '^2'
        elseif logType == 'TEMPBAN' then
            color = '^3'
        elseif logType == 'ATTEMPT' then
            color = '^5'
        end

        print(color .. '[SYNC] ' .. logEntry .. '^0')
    end

    -- Log dans un fichier
    if Config.Logs.ToFile then
        Security.WriteLogToFile(logEntry)
    end

    -- Log vers Discord
    if Config.Logs.Discord.Enabled and Config.Logs.Discord.WebhookURL ~= '' then
        Security.SendDiscordLog(logType, message, data)
    end
end

--- Écrire un log dans un fichier
-- @param logEntry string L'entrée de log formatée
function Security.WriteLogToFile(logEntry)
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local logPath = resourcePath .. '/' .. Config.Logs.FilePath

    -- Créer le dossier data si nécessaire
    os.execute('mkdir "' .. resourcePath .. '/data" 2>nul')

    local file = io.open(logPath, 'a')

    if file then
        file:write(logEntry .. '\n')
        file:close()
    end
end

--- Envoyer un log vers Discord via webhook
-- @param logType string Type de log
-- @param message string Le message
-- @param data table|nil Données supplémentaires
function Security.SendDiscordLog(logType, message, data)
    local webhookURL = Config.Logs.Discord.WebhookURL

    if not webhookURL or webhookURL == '' then
        return
    end

    -- Déterminer la couleur de l'embed
    local colors = Config.Logs.Discord.Colors
    local color = colors.Ban -- Par défaut

    if logType == 'UNBAN' then
        color = colors.Unban
    elseif logType == 'TEMPBAN' then
        color = colors.TempBan
    elseif logType == 'ATTEMPT' then
        color = colors.Attempt
    end

    -- Construire l'embed
    local embed = {
        {
            title = '🔄 Sync Module - ' .. logType,
            description = message,
            color = color,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            footer = {
                text = Config.Logs.Discord.BotName,
            },
            fields = {},
        },
    }

    -- Ajouter les données supplémentaires comme champs
    if data then
        if data.ip then
            local displayIP = data.ip

            if Config.Security.HashIPsInLogs then
                displayIP = Utils.HashIP(data.ip)
            end

            table.insert(embed[1].fields, {
                name = '📍 IP',
                value = '`' .. displayIP .. '`',
                inline = true,
            })
        end

        if data.reason then
            table.insert(embed[1].fields, {
                name = '📋 Raison',
                value = data.reason,
                inline = true,
            })
        end

        if data.admin then
            table.insert(embed[1].fields, {
                name = '👤 Admin',
                value = data.admin,
                inline = true,
            })
        end

        if data.playerName then
            table.insert(embed[1].fields, {
                name = '🎮 Joueur',
                value = data.playerName,
                inline = true,
            })
        end

        if data.duration then
            table.insert(embed[1].fields, {
                name = '⏰ Durée',
                value = data.duration,
                inline = true,
            })
        end

        if data.expiresAt then
            table.insert(embed[1].fields, {
                name = '📅 Expire',
                value = Utils.FormatExpiration(data.expiresAt),
                inline = true,
            })
        end
    end

    -- Payload pour Discord
    local payload = {
        username = Config.Logs.Discord.BotName,
        avatar_url = Config.Logs.Discord.AvatarURL ~= '' and Config.Logs.Discord.AvatarURL or nil,
        embeds = embed,
    }

    -- Envoyer la requête HTTP
    PerformHttpRequest(webhookURL, function(statusCode, response, headers)
        if statusCode ~= 200 and statusCode ~= 204 then
            if Config.General.Debug then
                print('^1[SYNC] Erreur Discord webhook: ' .. tostring(statusCode) .. '^0')
            end
        end
    end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json',
    })
end

-- ============================================================
-- VALIDATION DE SÉCURITÉ
-- ============================================================

--- Valider et nettoyer une raison de ban
-- @param reason string La raison brute
-- @return string La raison nettoyée
function Security.SanitizeReason(reason)
    if not reason or type(reason) ~= 'string' then
        return 'Aucune raison fournie'
    end

    -- Supprimer les caractères potentiellement dangereux
    reason = reason:gsub('[%^%~%`]', '')

    -- Limiter la longueur
    reason = Utils.Truncate(reason, 500)

    -- Trim
    reason = reason:match('^%s*(.-)%s*$')

    if reason == '' then
        return 'Aucune raison fournie'
    end

    return reason
end

--- Vérifier si une IP est une IP locale/privée
-- @param ip string L'adresse IP
-- @return boolean L'IP est-elle locale
function Security.IsPrivateIP(ip)
    if not ip then
        return false
    end

    -- IPs locales IPv4
    local privateRanges = {
        '^127%.', -- Loopback
        '^10%.', -- Classe A privée
        '^192%.168%.', -- Classe C privée
        '^172%.1[6-9]%.', -- Classe B privée
        '^172%.2[0-9]%.', -- Classe B privée
        '^172%.3[0-1]%.', -- Classe B privée
        '^0%.', -- Réseau local
        '^255%.', -- Broadcast
    }

    for _, pattern in ipairs(privateRanges) do
        if ip:match(pattern) then
            return true
        end
    end

    return false
end

--- Générer un identifiant unique pour les logs
-- @return string L'identifiant unique
function Security.GenerateLogID()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = ''

    for i = 1, 8 do
        local randIndex = math.random(1, #chars)
        id = id .. chars:sub(randIndex, randIndex)
    end

    return id
end

-- ============================================================
-- NETTOYAGE À LA DÉCONNEXION
-- ============================================================
AddEventHandler('playerDropped', function()
    local source = source
    Security.ClearPlayerHistory(source)
end)

-- ============================================================
-- EXPORTS
-- ============================================================
exports('HasPermission', Security.HasPermission)
exports('Log', Security.Log)
exports('SanitizeReason', Security.SanitizeReason)
