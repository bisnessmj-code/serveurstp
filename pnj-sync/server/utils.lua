--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    MODULE UTILITAIRES                            ║
    ╚══════════════════════════════════════════════════════════════════╝

    Ce module contient les fonctions utilitaires utilisées
    par l'ensemble du système de ban IP.
]]

-- ============================================================
-- NAMESPACE DU MODULE
-- ============================================================
Utils = {}

-- ============================================================
-- VALIDATION D'ADRESSES IP
-- ============================================================

--- Valider une adresse IPv4
-- @param ip string L'adresse IP à valider
-- @return boolean L'IP est-elle valide
function Utils.IsValidIPv4(ip)
    if not ip or type(ip) ~= 'string' then
        return false
    end

    -- Pattern pour une adresse IPv4
    local pattern = '^(%d+)%.(%d+)%.(%d+)%.(%d+)$'
    local a, b, c, d = ip:match(pattern)

    if not a then
        return false
    end

    -- Convertir en nombres et vérifier les plages
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)

    if a < 0 or a > 255 then return false end
    if b < 0 or b > 255 then return false end
    if c < 0 or c > 255 then return false end
    if d < 0 or d > 255 then return false end

    return true
end

--- Valider une adresse IPv6
-- @param ip string L'adresse IP à valider
-- @return boolean L'IP est-elle valide
function Utils.IsValidIPv6(ip)
    if not ip or type(ip) ~= 'string' then
        return false
    end

    -- Pattern simplifié pour IPv6
    -- Format complet: xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx
    local segments = 0

    for segment in ip:gmatch('[^:]+') do
        if not segment:match('^%x+$') or #segment > 4 then
            return false
        end
        segments = segments + 1
    end

    -- IPv6 a 8 segments (ou moins avec ::)
    return segments >= 1 and segments <= 8
end

--- Valider une adresse IP (IPv4 ou IPv6)
-- @param ip string L'adresse IP à valider
-- @return boolean L'IP est-elle valide
function Utils.IsValidIP(ip)
    return Utils.IsValidIPv4(ip) or Utils.IsValidIPv6(ip)
end

--- Extraire l'IP d'une chaîne potentiellement avec port
-- @param ipString string L'IP potentiellement avec port (ex: "192.168.1.1:30120")
-- @return string L'IP sans le port
function Utils.ExtractIP(ipString)
    if not ipString then
        return nil
    end

    -- Supprimer le préfixe "ip:" si présent
    ipString = ipString:gsub('^ip:', '')

    -- Supprimer le port si présent (IPv4)
    local ip = ipString:match('^([%d%.]+)')

    if ip and Utils.IsValidIPv4(ip) then
        return ip
    end

    -- Pour IPv6 avec port: [xxxx::xxxx]:port
    ip = ipString:match('^%[([%x:]+)%]')

    if ip and Utils.IsValidIPv6(ip) then
        return ip
    end

    -- Retourner tel quel si pas de port détecté
    return ipString:match('^([^:]+)') or ipString
end

-- ============================================================
-- NOTATION CIDR
-- ============================================================

--- Convertir une IP en nombre (pour comparaison CIDR)
-- @param ip string L'adresse IPv4
-- @return number L'IP en format numérique
function Utils.IPToNumber(ip)
    local a, b, c, d = ip:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$')

    if not a then
        return 0
    end

    return tonumber(a) * 16777216 + tonumber(b) * 65536 + tonumber(c) * 256 + tonumber(d)
end

--- Vérifier si une IP est dans un range CIDR
-- @param ip string L'adresse IP à vérifier
-- @param cidr string Le range CIDR (ex: "192.168.1.0/24")
-- @return boolean L'IP est-elle dans le range
function Utils.IsIPInCIDR(ip, cidr)
    if not Utils.IsValidIPv4(ip) then
        return false
    end

    local network, mask = cidr:match('^([%d%.]+)/(%d+)$')

    if not network or not Utils.IsValidIPv4(network) then
        return false
    end

    mask = tonumber(mask)

    if not mask or mask < 0 or mask > 32 then
        return false
    end

    local ipNum = Utils.IPToNumber(ip)
    local networkNum = Utils.IPToNumber(network)
    local maskBits = 0xFFFFFFFF - (2 ^ (32 - mask) - 1)

    -- Appliquer le masque et comparer
    return (ipNum & maskBits) == (networkNum & maskBits)
end

-- ============================================================
-- PARSING DE DURÉE
-- ============================================================

--- Parser une durée textuelle en secondes
-- @param durationStr string La durée (ex: "1h", "2d", "1w", "1m")
-- @return number|nil Durée en secondes ou nil si invalide
function Utils.ParseDuration(durationStr)
    if not durationStr or type(durationStr) ~= 'string' then
        return nil
    end

    -- Nettoyer la chaîne
    durationStr = durationStr:lower():gsub('%s+', '')

    local amount, unit = durationStr:match('^(%d+)(%a+)$')

    if not amount then
        return nil
    end

    amount = tonumber(amount)

    if not amount or amount <= 0 then
        return nil
    end

    -- Table des multiplicateurs
    local multipliers = {
        s = 1,              -- Secondes
        sec = 1,
        second = 1,
        seconds = 1,

        m = 60,             -- Minutes
        min = 60,
        minute = 60,
        minutes = 60,

        h = 3600,           -- Heures
        hr = 3600,
        hour = 3600,
        hours = 3600,

        d = 86400,          -- Jours
        day = 86400,
        days = 86400,

        w = 604800,         -- Semaines
        week = 604800,
        weeks = 604800,

        mo = 2592000,       -- Mois (30 jours)
        month = 2592000,
        months = 2592000,

        y = 31536000,       -- Années (365 jours)
        year = 31536000,
        years = 31536000,
    }

    local multiplier = multipliers[unit]

    if not multiplier then
        return nil
    end

    return amount * multiplier
end

--- Formater une durée en texte lisible
-- @param seconds number La durée en secondes
-- @return string La durée formatée
function Utils.FormatDuration(seconds)
    if not seconds or seconds <= 0 then
        return 'Permanent'
    end

    local units = {
        { 31536000, 'an', 'ans' },
        { 2592000, 'mois', 'mois' },
        { 604800, 'semaine', 'semaines' },
        { 86400, 'jour', 'jours' },
        { 3600, 'heure', 'heures' },
        { 60, 'minute', 'minutes' },
        { 1, 'seconde', 'secondes' },
    }

    for _, unit in ipairs(units) do
        local value = math.floor(seconds / unit[1])

        if value >= 1 then
            if value == 1 then
                return value .. ' ' .. unit[2]
            else
                return value .. ' ' .. unit[3]
            end
        end
    end

    return 'Instant'
end

-- ============================================================
-- FORMATAGE DE DATES
-- ============================================================

--- Formater un timestamp en date lisible
-- @param timestamp number Le timestamp Unix
-- @return string La date formatée
function Utils.FormatDate(timestamp)
    if not timestamp then
        return 'N/A'
    end

    return os.date('%d/%m/%Y %H:%M:%S', timestamp)
end

--- Formater une date d'expiration
-- @param expiresAt number|nil Le timestamp d'expiration
-- @return string La date ou "Permanent"
function Utils.FormatExpiration(expiresAt)
    if not expiresAt or expiresAt == 0 then
        return 'Permanent'
    end

    return Utils.FormatDate(expiresAt)
end

-- ============================================================
-- MANIPULATION DE CHAÎNES
-- ============================================================

--- Tronquer une chaîne si trop longue
-- @param str string La chaîne à tronquer
-- @param maxLength number La longueur maximale
-- @return string La chaîne tronquée
function Utils.Truncate(str, maxLength)
    if not str then
        return ''
    end

    if #str <= maxLength then
        return str
    end

    return str:sub(1, maxLength - 3) .. '...'
end

--- Échapper les caractères spéciaux pour affichage
-- @param str string La chaîne à échapper
-- @return string La chaîne échappée
function Utils.EscapeString(str)
    if not str then
        return ''
    end

    return str:gsub('[%^%~]', '')
end

--- Hasher une IP pour anonymisation dans les logs
-- @param ip string L'IP à hasher
-- @return string L'IP hashée
function Utils.HashIP(ip)
    if not ip then
        return 'UNKNOWN'
    end

    -- Hash simple utilisant les premiers et derniers caractères
    local hash = 0

    for i = 1, #ip do
        hash = (hash * 31 + ip:byte(i)) % 0x7FFFFFFF
    end

    return string.format('%s***%s [%08X]',
        ip:sub(1, 3),
        ip:sub(-2),
        hash
    )
end

-- ============================================================
-- IDENTIFIANTS JOUEUR
-- ============================================================

--- Obtenir tous les identifiants d'un joueur
-- @param source number L'ID serveur du joueur
-- @return table Liste des identifiants
function Utils.GetPlayerIdentifiers(source)
    local identifiers = {}

    if not source or source <= 0 then
        return identifiers
    end

    local numIdentifiers = GetNumPlayerIdentifiers(source)

    for i = 0, numIdentifiers - 1 do
        local identifier = GetPlayerIdentifier(source, i)

        if identifier then
            -- Extraire le type (steam:, license:, etc.)
            local idType = identifier:match('^([^:]+):')

            if idType then
                identifiers[idType] = identifier
            end
        end
    end

    return identifiers
end

--- Obtenir l'IP d'un joueur
-- @param source number L'ID serveur du joueur
-- @return string|nil L'adresse IP du joueur
function Utils.GetPlayerIP(source)
    if not source or source <= 0 then
        return nil
    end

    local identifiers = Utils.GetPlayerIdentifiers(source)

    if identifiers.ip then
        return Utils.ExtractIP(identifiers.ip)
    end

    -- Méthode alternative via l'endpoint
    local endpoint = GetPlayerEndpoint(source)

    if endpoint then
        return Utils.ExtractIP(endpoint)
    end

    return nil
end

--- Obtenir le nom d'un joueur de manière sécurisée
-- @param source number L'ID serveur du joueur
-- @return string Le nom du joueur
function Utils.GetPlayerName(source)
    if not source or source <= 0 then
        return 'Console'
    end

    local name = GetPlayerName(source)

    return name or 'Inconnu'
end

-- ============================================================
-- PAGINATION
-- ============================================================

--- Paginer une liste
-- @param list table La liste à paginer
-- @param page number Le numéro de page (1-based)
-- @param perPage number Nombre d'éléments par page
-- @return table, number, number Éléments de la page, page actuelle, nombre total de pages
function Utils.Paginate(list, page, perPage)
    perPage = perPage or 10
    page = page or 1

    local totalItems = #list
    local totalPages = math.ceil(totalItems / perPage)

    -- Borner la page
    page = math.max(1, math.min(page, totalPages))

    local startIndex = (page - 1) * perPage + 1
    local endIndex = math.min(startIndex + perPage - 1, totalItems)

    local pageItems = {}

    for i = startIndex, endIndex do
        table.insert(pageItems, list[i])
    end

    return pageItems, page, math.max(1, totalPages)
end

-- ============================================================
-- EXPORTS
-- ============================================================
exports('IsValidIP', Utils.IsValidIP)
exports('ExtractIP', Utils.ExtractIP)
exports('ParseDuration', Utils.ParseDuration)
exports('FormatDuration', Utils.FormatDuration)
exports('GetPlayerIP', Utils.GetPlayerIP)
