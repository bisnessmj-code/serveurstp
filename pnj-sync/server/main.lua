--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    LOGIQUE PRINCIPALE                            ║
    ╚══════════════════════════════════════════════════════════════════╝

    Ce module contient la logique principale du système de ban IP:
    - Interception des connexions
    - Gestion des bannissements
    - API pour les autres ressources
]]

-- ============================================================
-- NAMESPACE DU MODULE
-- ============================================================
IPBan = {}

-- ============================================================
-- INITIALISATION
-- ============================================================

--- Initialiser le système de ban IP
local function Initialize()
    -- Vérifier si le système est activé
    if not Config.General.Enabled then
        print('^3[SYNC]^0 Système désactivé dans la configuration.')
        return
    end

    -- Charger la base de données
    if not Database.Load() then
        print('^1[SYNC] ERREUR^0 Impossible de charger la base de données!')
        return
    end

    -- Log d'initialisation
    local banCount = Database.GetBanCount()

    print('^2[SYNC]^0 ══════════════════════════════════════════')
    print('^2[SYNC]^0   Module de synchronisation chargé')
    print('^2[SYNC]^0   Version: 1.0.0')
    print('^2[SYNC]^0   Entrées cache: ' .. banCount)
    print('^2[SYNC]^0   Stockage: ' .. Config.Database.Type)
    print('^2[SYNC]^0 ══════════════════════════════════════════')

    Security.Log('INFO', 'Module sync initialisé - ' .. banCount .. ' entrée(s)')
end

-- ============================================================
-- INTERCEPTION DES CONNEXIONS
-- ============================================================

--- Event déclenché lors d'une tentative de connexion
-- C'est le point d'entrée principal pour bloquer les joueurs bannis
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local source = source

    -- Différer la connexion pour effectuer les vérifications
    deferrals.defer()

    -- Message de chargement discret (simule un chargement normal FiveM)
    deferrals.update('Establishing connection...')

    -- Petit délai pour éviter les race conditions
    Wait(Config.Security.AntiBypass.KickDelay)

    -- Récupérer l'IP du joueur
    local playerIP = Utils.GetPlayerIP(source)

    if not playerIP then
        -- Impossible de récupérer l'IP, autoriser par précaution
        if Config.General.Debug then
            print('^3[SYNC]^0 Impossible de récupérer l\'IP pour ' .. playerName)
        end

        deferrals.done()
        return
    end

    -- Vérifier si l'IP est bannie
    local isBanned, banData = Database.IsBanned(playerIP)

    if isBanned then
        -- Message de kick stealth (simule une erreur FiveM generique)
        local kickMessage = Config.GetMessage('BanKickMessage')

        -- Logger la tentative de connexion (uniquement console serveur)
        Security.Log('ATTEMPT', 'Connexion bloquee: ' .. playerName, {
            ip = playerIP,
            playerName = playerName,
            reason = banData.reason,
        })

        -- Rejeter la connexion avec faux message d'erreur
        deferrals.done(kickMessage)
        return
    end

    -- Vérification CIDR si activée
    if Config.Security.EnableCIDRBlocking then
        local allBans = Database.GetAllBans()

        for _, ban in ipairs(allBans) do
            -- Vérifier si c'est une notation CIDR
            if ban.ip:match('/%d+$') then
                if Utils.IsIPInCIDR(playerIP, ban.ip) then
                    -- Message stealth (fausse erreur FiveM)
                    local kickMessage = Config.GetMessage('BanKickMessage')

                    Security.Log('ATTEMPT', 'Connexion bloquee (CIDR): ' .. playerName, {
                        ip = playerIP,
                        playerName = playerName,
                        cidr = ban.ip,
                    })

                    deferrals.done(kickMessage)
                    return
                end
            end
        end
    end

    -- Toutes les vérifications passées, autoriser la connexion
    deferrals.done()

    if Config.General.Debug then
        print('^2[SYNC]^0 Connexion autorisée: ' .. playerName .. ' (' .. playerIP .. ')')
    end
end)

-- ============================================================
-- FONCTIONS DE BANNISSEMENT
-- ============================================================

--- Bannir une adresse IP
-- @param ip string L'adresse IP à bannir
-- @param reason string La raison du ban
-- @param adminSource number L'ID serveur de l'admin (0 pour console)
-- @param duration number|nil Durée en secondes (nil = permanent)
-- @param targetName string|nil Nom du joueur banni
-- @return boolean, string Succès, Message
function IPBan.BanIP(ip, reason, adminSource, duration, targetName)
    -- Valider l'IP
    if not Utils.IsValidIP(ip) and not ip:match('/%d+$') then
        return false, Config.GetMessage('InvalidIP', ip)
    end

    -- Vérifier si déjà banni
    local isBanned, _ = Database.IsBanned(ip)

    if isBanned then
        return false, Config.GetMessage('IPAlreadyBanned')
    end

    -- Préparer les données du ban
    local adminName = Utils.GetPlayerName(adminSource)
    local adminIdentifier = nil

    if adminSource > 0 then
        local identifiers = Utils.GetPlayerIdentifiers(adminSource)
        adminIdentifier = identifiers.steam or identifiers.license or identifiers.discord
    end

    local banData = {
        ip = ip,
        reason = Security.SanitizeReason(reason),
        bannedBy = adminName,
        bannedByIdentifier = adminIdentifier,
        timestamp = os.time(),
        expiresAt = duration and (os.time() + duration) or nil,
        playerName = targetName,
        additionalInfo = {
            serverTime = os.date('%Y-%m-%d %H:%M:%S'),
        },
    }

    -- Ajouter le ban
    local success = Database.AddBan(banData)

    if success then
        local logType = duration and 'TEMPBAN' or 'BAN'
        local message

        if duration then
            message = Config.GetMessage('TempBanSuccess', ip, Utils.FormatDate(banData.expiresAt))
        else
            message = Config.GetMessage('BanSuccess', ip)
        end

        Security.Log(logType, 'IP bannie: ' .. ip .. ' par ' .. adminName, {
            ip = ip,
            reason = banData.reason,
            admin = adminName,
            playerName = targetName,
            duration = duration and Utils.FormatDuration(duration) or 'Permanent',
            expiresAt = banData.expiresAt,
        })

        -- Kicker le joueur s'il est connecté
        IPBan.KickByIP(ip, banData)

        return true, message
    end

    return false, '❌ Erreur lors de l\'ajout du ban.'
end

--- Débannir une adresse IP
-- @param ip string L'adresse IP à débannir
-- @param adminSource number L'ID serveur de l'admin
-- @return boolean, string Succès, Message
function IPBan.UnbanIP(ip, adminSource)
    -- Vérifier si l'IP est bannie
    local isBanned, banData = Database.IsBanned(ip)

    if not isBanned then
        return false, Config.GetMessage('IPNotBanned')
    end

    -- Retirer le ban
    local success = Database.RemoveBan(ip)

    if success then
        local adminName = Utils.GetPlayerName(adminSource)

        Security.Log('UNBAN', 'IP débannie: ' .. ip .. ' par ' .. adminName, {
            ip = ip,
            admin = adminName,
            originalReason = banData and banData.reason or 'N/A',
        })

        return true, Config.GetMessage('UnbanSuccess', ip)
    end

    return false, '❌ Erreur lors du retrait du ban.'
end

--- Kicker tous les joueurs ayant une IP spécifique (mode stealth)
-- @param ip string L'adresse IP
-- @param banData table Les données du ban
function IPBan.KickByIP(ip, banData)
    local players = GetPlayers()

    for _, playerId in ipairs(players) do
        local playerIP = Utils.GetPlayerIP(tonumber(playerId))

        if playerIP == ip then
            -- Message stealth (fausse erreur FiveM)
            local kickMessage = Config.GetMessage('BanKickMessage')

            DropPlayer(playerId, kickMessage)

            -- Log uniquement en console (pas visible en jeu)
            print('[SYNC] Session terminee: ' .. (GetPlayerName(playerId) or 'Unknown'))
        end
    end
end

--- Bannir un joueur par son ID serveur
-- @param targetSource number L'ID serveur du joueur
-- @param reason string La raison du ban
-- @param adminSource number L'ID serveur de l'admin
-- @param duration number|nil Durée en secondes
-- @return boolean, string Succès, Message
function IPBan.BanPlayer(targetSource, reason, adminSource, duration)
    -- Vérifier si le joueur existe
    local targetName = GetPlayerName(targetSource)

    if not targetName then
        return false, Config.GetMessage('PlayerNotFound', tostring(targetSource))
    end

    -- Récupérer l'IP du joueur
    local playerIP = Utils.GetPlayerIP(targetSource)

    if not playerIP then
        return false, '❌ Impossible de récupérer l\'IP du joueur.'
    end

    -- Bannir l'IP
    return IPBan.BanIP(playerIP, reason, adminSource, duration, targetName)
end

--- Vérifier si une IP est bannie
-- @param ip string L'adresse IP
-- @return boolean, table|nil Est bannie, Données du ban
function IPBan.CheckIP(ip)
    return Database.IsBanned(ip)
end

--- Obtenir la liste des bans avec pagination
-- @param page number Numéro de page
-- @param perPage number Éléments par page
-- @return table, number, number Bans, Page actuelle, Total pages
function IPBan.GetBanList(page, perPage)
    local allBans = Database.GetAllBans()

    -- Trier par date (plus récent en premier)
    table.sort(allBans, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)

    return Utils.Paginate(allBans, page, perPage or 10)
end

-- ============================================================
-- INITIALISATION AU DÉMARRAGE
-- ============================================================
CreateThread(function()
    -- Attendre que toutes les ressources soient chargées
    Wait(1000)
    Initialize()
end)

-- ============================================================
-- EXPORTS POUR LES AUTRES RESSOURCES
-- ============================================================
exports('BanIP', IPBan.BanIP)
exports('UnbanIP', IPBan.UnbanIP)
exports('BanPlayer', IPBan.BanPlayer)
exports('CheckIP', IPBan.CheckIP)
exports('GetBanList', IPBan.GetBanList)
exports('KickByIP', IPBan.KickByIP)

-- ============================================================
-- ÉVÉNEMENTS SERVEUR POUR INTÉGRATION EXTERNE
-- ============================================================

--- Event pour bannir une IP depuis une autre ressource
RegisterNetEvent('pnjsync:server:banIP')
AddEventHandler('pnjsync:server:banIP', function(ip, reason, duration)
    local source = source

    -- Vérifier les permissions
    if not Security.HasPermission(source) then
        return
    end

    IPBan.BanIP(ip, reason, source, duration)
end)

--- Event pour débannir une IP depuis une autre ressource
RegisterNetEvent('pnjsync:server:unbanIP')
AddEventHandler('pnjsync:server:unbanIP', function(ip)
    local source = source

    if not Security.HasPermission(source) then
        return
    end

    IPBan.UnbanIP(ip, source)
end)
