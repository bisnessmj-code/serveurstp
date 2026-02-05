--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    COMMANDES MODULE                              ║
    ╚══════════════════════════════════════════════════════════════════╝

    Commandes de gestion du module de synchronisation.
]]

-- ============================================================
-- FONCTION D'ENVOI DE MESSAGE (STEALTH MODE)
-- ============================================================

--- Envoyer un message uniquement vers la console (mode discret)
-- Les messages ne sont jamais envoyés dans le chat pour rester invisible
-- @param source number L'ID serveur (0 = console)
-- @param message string Le message à envoyer
local function SendMessage(source, message)
    -- Mode stealth: tous les messages vont uniquement dans la console serveur
    -- Aucun message n'est affiché dans le chat du jeu
    print('[SYNC] ' .. message:gsub('[✅❌📋🔍🚫]', ''))
end

-- ============================================================
-- COMMANDE: /banip [IP] [Raison]
-- ============================================================
RegisterCommand(Config.Commands.BanIP.Name, function(source, args, rawCommand)
    -- Vérifier les permissions
    if not Security.HasPermission(source) then
        SendMessage(source, Config.GetMessage('NoPermission'))
        return
    end

    -- Vérifier le rate limit
    local canExecute, rateLimitMsg = Security.CheckRateLimit(source)

    if not canExecute then
        SendMessage(source, rateLimitMsg)
        return
    end

    -- Vérifier les arguments
    if #args < 1 then
        SendMessage(source, Config.GetMessage('MissingArguments', Config.Commands.BanIP.Usage))
        return
    end

    local ip = args[1]
    local reason = table.concat(args, ' ', 2) or 'Aucune raison fournie'

    -- Exécuter le ban
    local success, message = IPBan.BanIP(ip, reason, source, nil, nil)
    SendMessage(source, message)
end, false)

-- ============================================================
-- COMMANDE: /unbanip [IP]
-- ============================================================
RegisterCommand(Config.Commands.UnbanIP.Name, function(source, args, rawCommand)
    -- Vérifier les permissions
    if not Security.HasPermission(source) then
        SendMessage(source, Config.GetMessage('NoPermission'))
        return
    end

    -- Vérifier le rate limit
    local canExecute, rateLimitMsg = Security.CheckRateLimit(source)

    if not canExecute then
        SendMessage(source, rateLimitMsg)
        return
    end

    -- Vérifier les arguments
    if #args < 1 then
        SendMessage(source, Config.GetMessage('MissingArguments', Config.Commands.UnbanIP.Usage))
        return
    end

    local ip = args[1]

    -- Exécuter le déban
    local success, message = IPBan.UnbanIP(ip, source)
    SendMessage(source, message)
end, false)

-- ============================================================
-- COMMANDE: /banplayer [ID] [Raison]
-- ============================================================
RegisterCommand(Config.Commands.BanPlayer.Name, function(source, args, rawCommand)
    -- Vérifier les permissions
    if not Security.HasPermission(source) then
        SendMessage(source, Config.GetMessage('NoPermission'))
        return
    end

    -- Vérifier le rate limit
    local canExecute, rateLimitMsg = Security.CheckRateLimit(source)

    if not canExecute then
        SendMessage(source, rateLimitMsg)
        return
    end

    -- Vérifier les arguments
    if #args < 1 then
        SendMessage(source, Config.GetMessage('MissingArguments', Config.Commands.BanPlayer.Usage))
        return
    end

    local targetId = tonumber(args[1])

    if not targetId then
        SendMessage(source, Config.GetMessage('PlayerNotFound', args[1]))
        return
    end

    local reason = table.concat(args, ' ', 2) or 'Aucune raison fournie'

    -- Exécuter le ban
    local success, message = IPBan.BanPlayer(targetId, reason, source, nil)
    SendMessage(source, message)
end, false)

-- ============================================================
-- COMMANDE: /tempbanip [IP] [Durée] [Raison]
-- ============================================================
RegisterCommand(Config.Commands.TempBanIP.Name, function(source, args, rawCommand)
    -- Vérifier les permissions
    if not Security.HasPermission(source) then
        SendMessage(source, Config.GetMessage('NoPermission'))
        return
    end

    -- Vérifier le rate limit
    local canExecute, rateLimitMsg = Security.CheckRateLimit(source)

    if not canExecute then
        SendMessage(source, rateLimitMsg)
        return
    end

    -- Vérifier les arguments
    if #args < 2 then
        SendMessage(source, Config.GetMessage('MissingArguments', Config.Commands.TempBanIP.Usage))
        return
    end

    local ip = args[1]
    local durationStr = args[2]
    local reason = table.concat(args, ' ', 3) or 'Aucune raison fournie'

    -- Parser la durée
    local duration = Utils.ParseDuration(durationStr)

    if not duration then
        SendMessage(source, Config.GetMessage('InvalidDuration'))
        return
    end

    -- Exécuter le ban temporaire
    local success, message = IPBan.BanIP(ip, reason, source, duration, nil)
    SendMessage(source, message)
end, false)

-- ============================================================
-- COMMANDE: /listbans [page]
-- ============================================================
RegisterCommand(Config.Commands.ListBans.Name, function(source, args, rawCommand)
    -- Vérifier les permissions
    if not Security.HasPermission(source) then
        SendMessage(source, Config.GetMessage('NoPermission'))
        return
    end

    -- Vérifier le rate limit
    local canExecute, rateLimitMsg = Security.CheckRateLimit(source)

    if not canExecute then
        SendMessage(source, rateLimitMsg)
        return
    end

    local page = tonumber(args[1]) or 1
    local perPage = 10

    -- Récupérer la liste
    local bans, currentPage, totalPages = IPBan.GetBanList(page, perPage)

    if #bans == 0 then
        SendMessage(source, Config.GetMessage('NoBannedIPs'))
        return
    end

    -- Afficher l'en-tête
    SendMessage(source, Config.GetMessage('BanListHeader', currentPage, totalPages))

    -- Afficher chaque ban
    for _, ban in ipairs(bans) do
        local displayIP = ban.ip

        if Config.Security.HashIPsInLogs and source > 0 then
            displayIP = Utils.HashIP(ban.ip)
        end

        local expiration = ''

        if ban.expiresAt and ban.expiresAt > 0 then
            expiration = ' [Expire: ' .. Utils.FormatDate(ban.expiresAt) .. ']'
        end

        SendMessage(source, Config.GetMessage('BanListEntry',
            displayIP,
            Utils.Truncate(ban.reason or 'N/A', 30),
            ban.bannedBy or 'N/A'
        ) .. expiration)
    end

    -- Afficher la pagination
    if totalPages > 1 then
        SendMessage(source, string.format('📄 Page %d/%d - Utilisez /%s [numéro] pour naviguer',
            currentPage, totalPages, Config.Commands.ListBans.Name))
    end
end, false)

-- ============================================================
-- COMMANDE: /checkip [IP]
-- ============================================================
RegisterCommand(Config.Commands.CheckIP.Name, function(source, args, rawCommand)
    -- Vérifier les permissions
    if not Security.HasPermission(source) then
        SendMessage(source, Config.GetMessage('NoPermission'))
        return
    end

    -- Vérifier le rate limit
    local canExecute, rateLimitMsg = Security.CheckRateLimit(source)

    if not canExecute then
        SendMessage(source, rateLimitMsg)
        return
    end

    -- Vérifier les arguments
    if #args < 1 then
        SendMessage(source, Config.GetMessage('MissingArguments', Config.Commands.CheckIP.Usage))
        return
    end

    local ip = args[1]

    -- Vérifier l'IP
    local isBanned, banData = IPBan.CheckIP(ip)

    if isBanned then
        local displayIP = ip

        if Config.Security.HashIPsInLogs and source > 0 then
            displayIP = Utils.HashIP(ip)
        end

        SendMessage(source, Config.GetMessage('IPCheckBanned', displayIP, banData.reason or 'N/A'))

        -- Afficher les détails supplémentaires
        SendMessage(source, string.format('  📅 Banni le: %s', Utils.FormatDate(banData.timestamp)))
        SendMessage(source, string.format('  👤 Par: %s', banData.bannedBy or 'N/A'))

        if banData.expiresAt and banData.expiresAt > 0 then
            SendMessage(source, string.format('  ⏰ Expire: %s', Utils.FormatDate(banData.expiresAt)))
        else
            SendMessage(source, '  ⏰ Durée: Permanent')
        end

        if banData.playerName then
            SendMessage(source, string.format('  🎮 Joueur: %s', banData.playerName))
        end
    else
        SendMessage(source, Config.GetMessage('IPCheckNotBanned', ip))
    end
end, false)

-- ============================================================
-- COMMANDE: /shelp
-- ============================================================
RegisterCommand('shelp', function(source, args, rawCommand)
    if not Security.HasPermission(source) then
        SendMessage(source, Config.GetMessage('NoPermission'))
        return
    end

    SendMessage(source, '═══════ SYNC MODULE - AIDE ═══════')
    SendMessage(source, '📌 Commandes:')
    SendMessage(source, '')

    SendMessage(source, string.format('  /%s [addr] [note]',
        Config.Commands.BanIP.Name))
    SendMessage(source, '    └─ ' .. Config.Commands.BanIP.Description)

    SendMessage(source, string.format('  /%s [addr]',
        Config.Commands.UnbanIP.Name))
    SendMessage(source, '    └─ ' .. Config.Commands.UnbanIP.Description)

    SendMessage(source, string.format('  /%s [ID] [note]',
        Config.Commands.BanPlayer.Name))
    SendMessage(source, '    └─ ' .. Config.Commands.BanPlayer.Description)

    SendMessage(source, string.format('  /%s [addr] [durée] [note]',
        Config.Commands.TempBanIP.Name))
    SendMessage(source, '    └─ ' .. Config.Commands.TempBanIP.Description)

    SendMessage(source, string.format('  /%s [page]',
        Config.Commands.ListBans.Name))
    SendMessage(source, '    └─ ' .. Config.Commands.ListBans.Description)

    SendMessage(source, string.format('  /%s [addr]',
        Config.Commands.CheckIP.Name))
    SendMessage(source, '    └─ ' .. Config.Commands.CheckIP.Description)

    SendMessage(source, '')
    SendMessage(source, '═══════════════════════════════════')
end, false)

-- ============================================================
-- SUGGESTIONS DE COMMANDES DESACTIVEES (mode stealth)
-- ============================================================
-- Les suggestions sont desactivees pour garder les commandes invisibles
-- Les admins doivent connaitre les commandes par coeur

if Config.General.Debug then
    print('^2[SYNC]^0 Commandes chargées')
end
