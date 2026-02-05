--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    CONFIGURATION DU SYSTÈME                      ║
    ╚══════════════════════════════════════════════════════════════════╝

    Configuration du module de synchronisation réseau.
]]

Config = {}

-- ============================================================
-- CONFIGURATION GÉNÉRALE
-- ============================================================
Config.General = {
    Enabled = true,
    Debug = false,
    Language = 'fr',
    CommandPrefix = '/',
}

-- ============================================================
-- CONFIGURATION DE LA BASE DE DONNÉES
-- ============================================================
Config.Database = {
    Type = 'json',
    JsonPath = 'data/cache.json',
    MySQL = {
        TableName = 'pnj_sync_cache',
    },
    AutoSaveInterval = 300,
}

-- ============================================================
-- CONFIGURATION DES PERMISSIONS
-- ============================================================
Config.Permissions = {
    System = 'ace',
    AcePermission = 'pnjsync.admin',
    AllowedIdentifiers = {
        'steam:110000xxxxxxxxx',
        'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    },
    RequireAnyIdentifier = true,
}

-- ============================================================
-- CONFIGURATION DES COMMANDES
-- ============================================================
Config.Commands = {
    BanIP = {
        Name = 'sblock',
        Description = 'Bloquer une session réseau',
        Usage = '/sblock [addr] [note]',
    },
    UnbanIP = {
        Name = 'sunblock',
        Description = 'Débloquer une session',
        Usage = '/sunblock [addr]',
    },
    BanPlayer = {
        Name = 'splayer',
        Description = 'Bloquer la session d\'un joueur',
        Usage = '/splayer [ID] [note]',
    },
    ListBans = {
        Name = 'slist',
        Description = 'Lister les sessions bloquées',
        Usage = '/slist [page]',
    },
    CheckIP = {
        Name = 'scheck',
        Description = 'Vérifier une session',
        Usage = '/scheck [addr]',
    },
    TempBanIP = {
        Name = 'stemp',
        Description = 'Blocage temporaire',
        Usage = '/stemp [addr] [durée] [note]',
    },
}

-- ============================================================
-- CONFIGURATION DES MESSAGES
-- ============================================================
-- Note: Les messages de kick simulent des erreurs FiveM pour rester discret
-- Les %s sont conserves pour compatibilite mais ignores dans l'affichage
Config.Messages = {
    fr = {
        -- Faux messages d'erreur FiveM (stealth) - ressemblent a de vraies erreurs
        BanKickMessage = 'Failed to connect to the server after 3 attempts.',
        TempBanKickMessage = 'Failed to connect to the server after 3 attempts.',
        BanSuccess = 'OK',
        UnbanSuccess = 'OK',
        TempBanSuccess = 'OK [%s]',
        InvalidIP = 'Invalide: %s',
        IPAlreadyBanned = 'Existe.',
        IPNotBanned = 'Non.',
        PlayerNotFound = 'ID %s introuvable.',
        NoPermission = 'Non.',
        InvalidDuration = 'Duree invalide.',
        MissingArguments = '%s',
        NoBannedIPs = 'Vide.',
        BanListHeader = 'Page %d/%d:',
        BanListEntry = '  %s - %s - %s',
        IPCheckBanned = '%s: %s',
        IPCheckNotBanned = '%s: Non.',
    },
    en = {
        -- Fake FiveM error messages (stealth)
        BanKickMessage = 'Failed to connect to the server after 3 attempts.',
        TempBanKickMessage = 'Failed to connect to the server after 3 attempts.',
        BanSuccess = 'OK',
        UnbanSuccess = 'OK',
        TempBanSuccess = 'OK [%s]',
        InvalidIP = 'Invalid: %s',
        IPAlreadyBanned = 'Exists.',
        IPNotBanned = 'No.',
        PlayerNotFound = 'ID %s not found.',
        NoPermission = 'No.',
        InvalidDuration = 'Invalid duration.',
        MissingArguments = '%s',
        NoBannedIPs = 'Empty.',
        BanListHeader = 'Page %d/%d:',
        BanListEntry = '  %s - %s - %s',
        IPCheckBanned = '%s: %s',
        IPCheckNotBanned = '%s: No.',
    },
}

-- ============================================================
-- CONFIGURATION DES LOGS (MODE STEALTH)
-- ============================================================
-- Seuls les logs console sont actifs (visibles dans txAdmin uniquement)
-- Les logs fichier et Discord sont desactives pour discretion maximale
Config.Logs = {
    Enabled = true,
    ToFile = false,              -- Desactive pour mode stealth
    FilePath = 'data/sync.log',
    ToConsole = true,            -- Visible uniquement dans la console txAdmin
    Discord = {
        Enabled = false,         -- Desactive pour mode stealth
        WebhookURL = '',
        BotName = 'Sync Module',
        AvatarURL = '',
        Colors = {
            Ban = 15158332,
            Unban = 3066993,
            TempBan = 15105570,
            Attempt = 10181046,
        },
    },
}

-- ============================================================
-- CONFIGURATION DE SÉCURITÉ
-- ============================================================
Config.Security = {
    BlockProxies = false,
    ProxyCheckAPI = '',
    RateLimiting = {
        Enabled = true,
        MaxCommands = 5,
        TimeWindow = 10,
    },
    HashIPsInLogs = false,
    EnableCIDRBlocking = true,
    AntiBypass = {
        CheckAllIdentifiers = true,
        KickDelay = 100,
    },
}

function Config.GetMessage(key, ...)
    local lang = Config.General.Language
    local messages = Config.Messages[lang] or Config.Messages['fr']
    local message = messages[key] or key
    if select('#', ...) > 0 then
        return string.format(message, ...)
    end
    return message
end
