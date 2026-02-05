--[[
    =====================================================
    REDZONE LEAGUE - Utilitaires Serveur
    =====================================================
    Ce fichier contient les fonctions utilitaires
    utilisées uniquement côté serveur.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}
Redzone.Server.Utils = {}

-- =====================================================
-- NOTIFICATIONS
-- =====================================================

---Envoie une notification à un joueur via brutal_notify
---@param source number L'ID du joueur
---@param title string Titre de la notification
---@param message string Message de la notification
---@param type string Type de notification ('success', 'error', 'info', 'warning')
---@param duration number|nil Durée en ms (optionnel)
---@param sound boolean|nil Jouer un son (optionnel)
function Redzone.Server.Utils.Notify(source, title, message, type, duration, sound)
    -- Valeurs par défaut
    title = title or Config.ScriptName
    type = type or Config.Notify.Types.Info
    duration = duration or Config.Notify.DefaultDuration
    sound = sound ~= nil and sound or Config.Notify.Sound

    -- Debug
    Redzone.Shared.Debug('[NOTIFY/SERVER] -> ', source, ': ', title, ' - ', message)

    -- Envoi via brutal_notify (trigger client)
    TriggerClientEvent('brutal_notify:SendAlert', source, title, message, duration, type, sound)
end

---Notification de succès
---@param source number L'ID du joueur
---@param message string Message à afficher
function Redzone.Server.Utils.NotifySuccess(source, message)
    Redzone.Server.Utils.Notify(source, Config.ScriptName, message, Config.Notify.Types.Success)
end

---Notification d'erreur
---@param source number L'ID du joueur
---@param message string Message à afficher
function Redzone.Server.Utils.NotifyError(source, message)
    Redzone.Server.Utils.Notify(source, Config.ScriptName, message, Config.Notify.Types.Error)
end

---Notification d'information
---@param source number L'ID du joueur
---@param message string Message à afficher
function Redzone.Server.Utils.NotifyInfo(source, message)
    Redzone.Server.Utils.Notify(source, Config.ScriptName, message, Config.Notify.Types.Info)
end

---Notification d'avertissement
---@param source number L'ID du joueur
---@param message string Message à afficher
function Redzone.Server.Utils.NotifyWarning(source, message)
    Redzone.Server.Utils.Notify(source, Config.ScriptName, message, Config.Notify.Types.Warning)
end

---Notification à tous les joueurs
---@param title string Titre de la notification
---@param message string Message de la notification
---@param type string Type de notification
function Redzone.Server.Utils.NotifyAll(title, message, type)
    TriggerClientEvent('brutal_notify:SendAlert', -1, title, message, Config.Notify.DefaultDuration, type, Config.Notify.Sound)
    Redzone.Shared.Debug('[NOTIFY/ALL] ', title, ' - ', message)
end

-- =====================================================
-- GESTION DES JOUEURS
-- =====================================================

---Obtient les identifiants d'un joueur
---@param source number L'ID du joueur
---@return table identifiers Table contenant les identifiants
function Redzone.Server.Utils.GetPlayerIdentifiers(source)
    local identifiers = {
        steam = nil,
        license = nil,
        discord = nil,
        ip = nil,
        xbl = nil,
        live = nil,
        fivem = nil,
    }

    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            if string.match(id, 'steam:') then
                identifiers.steam = id
            elseif string.match(id, 'license:') then
                identifiers.license = id
            elseif string.match(id, 'discord:') then
                identifiers.discord = id
            elseif string.match(id, 'ip:') then
                identifiers.ip = id
            elseif string.match(id, 'xbl:') then
                identifiers.xbl = id
            elseif string.match(id, 'live:') then
                identifiers.live = id
            elseif string.match(id, 'fivem:') then
                identifiers.fivem = id
            end
        end
    end

    return identifiers
end

---Obtient le nom du joueur
---@param source number L'ID du joueur
---@return string name Le nom du joueur
function Redzone.Server.Utils.GetPlayerName(source)
    return GetPlayerName(source) or 'Inconnu'
end

---Vérifie si un joueur est connecté
---@param source number L'ID du joueur
---@return boolean connected True si connecté
function Redzone.Server.Utils.IsPlayerConnected(source)
    return GetPlayerName(source) ~= nil
end

-- =====================================================
-- GESTION DE L'INVENTAIRE (qs-inventory)
-- =====================================================

---Retire toutes les armes du joueur
---@param source number L'ID du joueur
---@return table|nil weapons Les armes retirées ou nil
function Redzone.Server.Utils.RemoveWeapons(source)
    -- Utilisation de qs-inventory pour retirer les armes
    -- Cette fonction doit être adaptée selon l'API de qs-inventory
    local weapons = {}

    -- Essai d'utiliser l'export de qs-inventory
    local success, result = pcall(function()
        return exports['qs-inventory']:GetPlayerWeapons(source)
    end)

    if success and result then
        weapons = result

        -- Retirer les armes de l'inventaire
        for _, weapon in ipairs(weapons) do
            pcall(function()
                exports['qs-inventory']:RemoveItem(source, weapon.name, weapon.count)
            end)
        end

        Redzone.Shared.Debug('[INVENTORY] Armes retirées pour le joueur: ', source)
    end

    return weapons
end

---Restaure les armes d'un joueur
---@param source number L'ID du joueur
---@param weapons table Les armes à restaurer
function Redzone.Server.Utils.RestoreWeapons(source, weapons)
    if not weapons or #weapons == 0 then return end

    -- Restaurer les armes via qs-inventory
    for _, weapon in ipairs(weapons) do
        pcall(function()
            exports['qs-inventory']:AddItem(source, weapon.name, weapon.count, weapon.slot, weapon.info)
        end)
    end

    Redzone.Shared.Debug('[INVENTORY] Armes restaurées pour le joueur: ', source)
end

-- =====================================================
-- LOGS ET MONITORING
-- =====================================================

---Log une action dans la console serveur
---@param action string L'action effectuée
---@param source number|nil L'ID du joueur (optionnel)
---@param details string|nil Détails supplémentaires (optionnel)
function Redzone.Server.Utils.Log(action, source, details)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local playerInfo = ''

    if source then
        local name = Redzone.Server.Utils.GetPlayerName(source)
        local ids = Redzone.Server.Utils.GetPlayerIdentifiers(source)
        playerInfo = string.format(' | Player: %s (ID: %d, License: %s)', name, source, ids.license or 'N/A')
    end

    local logMessage = string.format('[%s][REDZONE] %s%s', timestamp, action, playerInfo)

    if details then
        logMessage = logMessage .. ' | ' .. details
    end

    print(logMessage)
end

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[SERVER/UTILS] Utilitaires serveur chargés')
