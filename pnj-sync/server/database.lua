--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    MODULE DE STOCKAGE                            ║
    ╚══════════════════════════════════════════════════════════════════╝

    Gestion du cache de synchronisation réseau.
]]

-- ============================================================
-- NAMESPACE DU MODULE
-- ============================================================
Database = {}
Database.__index = Database

-- ============================================================
-- VARIABLES PRIVÉES
-- ============================================================
local bannedIPs = {}        -- Cache en mémoire des IPs bannies
local isLoaded = false      -- État de chargement de la base
local lastSaveTime = 0      -- Timestamp de la dernière sauvegarde

-- ============================================================
-- STRUCTURE D'UN BAN
-- ============================================================
--[[
    Structure d'une entrée de ban:
    {
        ip = "192.168.1.1",             -- Adresse IP bannie
        reason = "Cheating",             -- Raison du ban
        bannedBy = "Admin",              -- Nom de l'admin
        bannedByIdentifier = "steam:x",  -- Identifiant de l'admin
        timestamp = 1234567890,          -- Unix timestamp du ban
        expiresAt = nil,                 -- nil = permanent, sinon timestamp d'expiration
        playerName = "Player1",          -- Nom du joueur au moment du ban
        additionalInfo = {}              -- Informations supplémentaires
    }
]]

-- ============================================================
-- FONCTIONS UTILITAIRES PRIVÉES
-- ============================================================

--- Obtenir le chemin complet du fichier de données
-- @return string Le chemin complet du fichier
local function GetDataFilePath()
    return GetResourcePath(GetCurrentResourceName()) .. '/' .. Config.Database.JsonPath
end

--- Vérifier et créer le dossier data si nécessaire
local function EnsureDataDirectory()
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local dataPath = resourcePath .. '/data'

    -- Créer le dossier si inexistant
    os.execute('mkdir "' .. dataPath .. '" 2>nul')
end

--- Sérialiser une table en JSON
-- @param tbl table La table à sérialiser
-- @return string Le JSON résultant
local function TableToJSON(tbl)
    return json.encode(tbl, { indent = true })
end

--- Désérialiser du JSON en table
-- @param str string Le JSON à désérialiser
-- @return table La table résultante
local function JSONToTable(str)
    if not str or str == '' then
        return {}
    end

    local success, result = pcall(json.decode, str)
    if success then
        return result or {}
    end

    return {}
end

-- ============================================================
-- FONCTIONS DE STOCKAGE JSON
-- ============================================================

--- Charger les données depuis le fichier JSON
-- @return boolean Succès du chargement
local function LoadFromJSON()
    EnsureDataDirectory()

    local filePath = GetDataFilePath()
    local file = io.open(filePath, 'r')

    if file then
        local content = file:read('*all')
        file:close()

        bannedIPs = JSONToTable(content)

        if Config.General.Debug then
            print('^2[SYNC]^0 Chargé ' .. Database.GetBanCount() .. ' IPs bannies depuis le fichier JSON.')
        end

        return true
    else
        -- Créer un fichier vide si inexistant
        bannedIPs = {}
        Database.Save()

        if Config.General.Debug then
            print('^3[SYNC]^0 Fichier de données créé: ' .. filePath)
        end

        return true
    end
end

--- Sauvegarder les données dans le fichier JSON
-- @return boolean Succès de la sauvegarde
local function SaveToJSON()
    EnsureDataDirectory()

    local filePath = GetDataFilePath()
    local file = io.open(filePath, 'w')

    if file then
        file:write(TableToJSON(bannedIPs))
        file:close()

        lastSaveTime = os.time()

        if Config.General.Debug then
            print('^2[SYNC]^0 Données sauvegardées avec succès.')
        end

        return true
    else
        print('^1[SYNC] ERREUR^0 Impossible de sauvegarder les données!')
        return false
    end
end

-- ============================================================
-- FONCTIONS DE STOCKAGE MYSQL
-- ============================================================

--- Initialiser la table MySQL
local function InitMySQL()
    if not MySQL then
        print('^1[SYNC] ERREUR^0 oxmysql non trouvé! Installez oxmysql ou utilisez le stockage JSON.')
        return false
    end

    local tableName = Config.Database.MySQL.TableName

    -- Créer la table si elle n'existe pas
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `]] .. tableName .. [[` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `ip` VARCHAR(45) NOT NULL UNIQUE,
            `reason` TEXT NOT NULL,
            `banned_by` VARCHAR(255) NOT NULL,
            `banned_by_identifier` VARCHAR(255),
            `timestamp` BIGINT NOT NULL,
            `expires_at` BIGINT DEFAULT NULL,
            `player_name` VARCHAR(255),
            `additional_info` JSON,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_ip` (`ip`),
            INDEX `idx_expires` (`expires_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    return true
end

--- Charger les données depuis MySQL
-- @return boolean Succès du chargement
local function LoadFromMySQL()
    if not InitMySQL() then
        return false
    end

    local tableName = Config.Database.MySQL.TableName

    MySQL.Async.fetchAll('SELECT * FROM `' .. tableName .. '`', {}, function(results)
        bannedIPs = {}

        for _, row in ipairs(results or {}) do
            bannedIPs[row.ip] = {
                ip = row.ip,
                reason = row.reason,
                bannedBy = row.banned_by,
                bannedByIdentifier = row.banned_by_identifier,
                timestamp = row.timestamp,
                expiresAt = row.expires_at,
                playerName = row.player_name,
                additionalInfo = row.additional_info and json.decode(row.additional_info) or {},
            }
        end

        isLoaded = true

        if Config.General.Debug then
            print('^2[SYNC]^0 Chargé ' .. Database.GetBanCount() .. ' IPs bannies depuis MySQL.')
        end
    end)

    return true
end

--- Sauvegarder une entrée dans MySQL
-- @param banData table Les données du ban
-- @return boolean Succès de la sauvegarde
local function SaveToMySQL(banData)
    if not MySQL then return false end

    local tableName = Config.Database.MySQL.TableName

    MySQL.Async.execute([[
        INSERT INTO `]] .. tableName .. [[`
        (ip, reason, banned_by, banned_by_identifier, timestamp, expires_at, player_name, additional_info)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        reason = VALUES(reason),
        banned_by = VALUES(banned_by),
        banned_by_identifier = VALUES(banned_by_identifier),
        timestamp = VALUES(timestamp),
        expires_at = VALUES(expires_at),
        player_name = VALUES(player_name),
        additional_info = VALUES(additional_info)
    ]], {
        banData.ip,
        banData.reason,
        banData.bannedBy,
        banData.bannedByIdentifier,
        banData.timestamp,
        banData.expiresAt,
        banData.playerName,
        banData.additionalInfo and json.encode(banData.additionalInfo) or '{}',
    })

    return true
end

--- Supprimer une entrée de MySQL
-- @param ip string L'IP à supprimer
-- @return boolean Succès de la suppression
local function DeleteFromMySQL(ip)
    if not MySQL then return false end

    local tableName = Config.Database.MySQL.TableName
    MySQL.Async.execute('DELETE FROM `' .. tableName .. '` WHERE `ip` = ?', { ip })

    return true
end

-- ============================================================
-- FONCTIONS PUBLIQUES
-- ============================================================

--- Initialiser et charger la base de données
-- @return boolean Succès de l'initialisation
function Database.Load()
    if isLoaded then
        return true
    end

    local success = false

    if Config.Database.Type == 'mysql' then
        success = LoadFromMySQL()
    else
        success = LoadFromJSON()
    end

    isLoaded = success
    return success
end

--- Sauvegarder la base de données
-- @return boolean Succès de la sauvegarde
function Database.Save()
    if Config.Database.Type == 'json' then
        return SaveToJSON()
    end

    -- Pour MySQL, les données sont sauvegardées en temps réel
    return true
end

--- Ajouter un ban
-- @param banData table Les données du ban
-- @return boolean Succès de l'ajout
function Database.AddBan(banData)
    if not banData or not banData.ip then
        return false
    end

    -- Ajouter au cache mémoire
    bannedIPs[banData.ip] = banData

    -- Persister selon le type de stockage
    if Config.Database.Type == 'mysql' then
        SaveToMySQL(banData)
    else
        Database.Save()
    end

    return true
end

--- Retirer un ban
-- @param ip string L'IP à débannir
-- @return boolean Succès de la suppression
function Database.RemoveBan(ip)
    if not ip or not bannedIPs[ip] then
        return false
    end

    -- Retirer du cache mémoire
    bannedIPs[ip] = nil

    -- Persister selon le type de stockage
    if Config.Database.Type == 'mysql' then
        DeleteFromMySQL(ip)
    else
        Database.Save()
    end

    return true
end

--- Vérifier si une IP est bannie
-- @param ip string L'IP à vérifier
-- @return boolean, table|nil Est bannie, Données du ban
function Database.IsBanned(ip)
    if not ip then
        return false, nil
    end

    local banData = bannedIPs[ip]

    if not banData then
        return false, nil
    end

    -- Vérifier si le ban a expiré
    if banData.expiresAt and banData.expiresAt > 0 then
        if os.time() > banData.expiresAt then
            -- Le ban a expiré, le supprimer
            Database.RemoveBan(ip)
            return false, nil
        end
    end

    return true, banData
end

--- Obtenir les données d'un ban
-- @param ip string L'IP à rechercher
-- @return table|nil Les données du ban
function Database.GetBan(ip)
    return bannedIPs[ip]
end

--- Obtenir toutes les IPs bannies
-- @return table Liste des bans
function Database.GetAllBans()
    local bans = {}

    for ip, data in pairs(bannedIPs) do
        -- Exclure les bans expirés
        if not data.expiresAt or data.expiresAt == 0 or os.time() <= data.expiresAt then
            table.insert(bans, data)
        end
    end

    return bans
end

--- Obtenir le nombre d'IPs bannies
-- @return number Nombre de bans actifs
function Database.GetBanCount()
    local count = 0

    for ip, data in pairs(bannedIPs) do
        -- Exclure les bans expirés
        if not data.expiresAt or data.expiresAt == 0 or os.time() <= data.expiresAt then
            count = count + 1
        end
    end

    return count
end

--- Nettoyer les bans expirés
-- @return number Nombre de bans supprimés
function Database.CleanExpiredBans()
    local removed = 0
    local currentTime = os.time()

    for ip, data in pairs(bannedIPs) do
        if data.expiresAt and data.expiresAt > 0 and currentTime > data.expiresAt then
            Database.RemoveBan(ip)
            removed = removed + 1
        end
    end

    if removed > 0 and Config.General.Debug then
        print('^3[SYNC]^0 Nettoyé ' .. removed .. ' ban(s) expiré(s).')
    end

    return removed
end

--- Vérifier si la base est chargée
-- @return boolean État de chargement
function Database.IsLoaded()
    return isLoaded
end

-- ============================================================
-- THREADS DE MAINTENANCE
-- ============================================================

-- Thread de sauvegarde automatique
CreateThread(function()
    -- Attendre le chargement initial
    Wait(5000)

    while true do
        -- Intervalle de sauvegarde automatique
        Wait(Config.Database.AutoSaveInterval * 1000)

        -- Nettoyer les bans expirés
        Database.CleanExpiredBans()

        -- Sauvegarder si nécessaire (JSON uniquement)
        if Config.Database.Type == 'json' then
            Database.Save()
        end
    end
end)

-- ============================================================
-- EXPORT DES FONCTIONS
-- ============================================================
exports('IsBanned', Database.IsBanned)
exports('GetBanCount', Database.GetBanCount)
exports('GetAllBans', Database.GetAllBans)
