--[[
    =====================================================
    REDZONE LEAGUE - Utilitaires Client
    =====================================================
    Ce fichier contient les fonctions utilitaires
    utilisées uniquement côté client.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Utils = {}

-- =====================================================
-- NOTIFICATIONS (brutal_notify)
-- =====================================================

---Envoie une notification au joueur via brutal_notify
---@param title string Titre de la notification
---@param message string Message de la notification
---@param type string Type de notification ('success', 'error', 'info', 'warning')
---@param duration number|nil Durée en ms (optionnel)
---@param sound boolean|nil Jouer un son (optionnel)
function Redzone.Client.Utils.Notify(title, message, type, duration, sound)
    -- Valeurs par défaut
    title = title or Config.ScriptName
    type = type or Config.Notify.Types.Info
    duration = duration or Config.Notify.DefaultDuration
    sound = sound ~= nil and sound or Config.Notify.Sound

    -- Debug
    Redzone.Shared.Debug('[NOTIFY] ', title, ' - ', message, ' (', type, ')')

    -- Envoi via brutal_notify
    exports['brutal_notify']:SendAlert(title, message, duration, type, sound)
end

---Notification de succès
---@param message string Message à afficher
function Redzone.Client.Utils.NotifySuccess(message)
    Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Success)
end

---Notification d'erreur
---@param message string Message à afficher
function Redzone.Client.Utils.NotifyError(message)
    Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Error)
end

---Notification d'information
---@param message string Message à afficher
function Redzone.Client.Utils.NotifyInfo(message)
    Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Info)
end

---Notification d'avertissement
---@param message string Message à afficher
function Redzone.Client.Utils.NotifyWarning(message)
    Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Warning)
end

-- =====================================================
-- GESTION DES MODÈLES
-- =====================================================

---Charge un modèle de manière asynchrone
---@param model string|number Le hash ou le nom du modèle
---@return boolean success True si le modèle est chargé
function Redzone.Client.Utils.LoadModel(model)
    -- Conversion en hash si nécessaire
    if type(model) == 'string' then
        model = GetHashKey(model)
    end

    -- Vérification de la validité du modèle
    if not IsModelValid(model) then
        Redzone.Shared.Debug('[ERROR] Modèle invalide: ', model)
        return false
    end

    -- Si déjà chargé, retourner true
    if HasModelLoaded(model) then
        return true
    end

    -- Demande de chargement
    RequestModel(model)

    -- Attente du chargement (timeout de 10 secondes)
    local timeout = 10000
    local startTime = GetGameTimer()

    while not HasModelLoaded(model) do
        if GetGameTimer() - startTime > timeout then
            Redzone.Shared.Debug('[ERROR] Timeout lors du chargement du modèle: ', model)
            return false
        end
        Wait(10)
    end

    Redzone.Shared.Debug('[MODEL] Modèle chargé: ', model)
    return true
end

---Libère un modèle de la mémoire
---@param model string|number Le hash ou le nom du modèle
function Redzone.Client.Utils.UnloadModel(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end

    SetModelAsNoLongerNeeded(model)
    Redzone.Shared.Debug('[MODEL] Modèle libéré: ', model)
end

-- =====================================================
-- GESTION DES ANIMATIONS
-- =====================================================

---Charge un dictionnaire d'animation
---@param dict string Le nom du dictionnaire
---@return boolean success True si chargé avec succès
function Redzone.Client.Utils.LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)

    local timeout = 5000
    local startTime = GetGameTimer()

    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - startTime > timeout then
            Redzone.Shared.Debug('[ERROR] Timeout lors du chargement du dictionnaire: ', dict)
            return false
        end
        Wait(10)
    end

    return true
end

-- =====================================================
-- GESTION DU JOUEUR
-- =====================================================

---Obtient les coordonnées actuelles du joueur
---@return vector3 coords Les coordonnées du joueur
function Redzone.Client.Utils.GetPlayerCoords()
    local playerPed = PlayerPedId()
    return GetEntityCoords(playerPed)
end

---Obtient le heading actuel du joueur
---@return number heading Le heading du joueur
function Redzone.Client.Utils.GetPlayerHeading()
    local playerPed = PlayerPedId()
    return GetEntityHeading(playerPed)
end

---Téléporte le joueur à des coordonnées données
---@param coords vector3|vector4 Les coordonnées de destination
---@param heading number|nil Le heading (optionnel si vector4)
function Redzone.Client.Utils.TeleportPlayer(coords, heading)
    local playerPed = PlayerPedId()

    -- Extraction du heading si vector4
    if type(coords) == 'vector4' then
        heading = coords.w
        coords = vector3(coords.x, coords.y, coords.z)
    end

    -- Fade out
    DoScreenFadeOut(500)
    Wait(500)

    -- Téléportation
    SetEntityCoords(playerPed, coords.x, coords.y, coords.z, false, false, false, true)

    if heading then
        SetEntityHeading(playerPed, heading)
    end

    -- Fade in
    Wait(500)
    DoScreenFadeIn(500)

    Redzone.Shared.Debug('[TELEPORT] Joueur téléporté à: ', coords)
end

---Gèle ou dégèle le joueur
---@param freeze boolean True pour geler, false pour dégeler
function Redzone.Client.Utils.FreezePlayer(freeze)
    local playerPed = PlayerPedId()
    SetEntityInvincible(playerPed, freeze)
    FreezeEntityPosition(playerPed, freeze)

    if freeze then
        Redzone.Shared.Debug('[PLAYER] Joueur figé')
    else
        Redzone.Shared.Debug('[PLAYER] Joueur libéré')
    end
end

-- =====================================================
-- AFFICHAGE TEXTE 3D / 2D
-- =====================================================

---Affiche un texte d'aide en bas à gauche de l'écran
---@param text string Le texte à afficher
function Redzone.Client.Utils.ShowHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

---Affiche un texte à l'écran (2D)
---@param x number Position X (0.0 à 1.0)
---@param y number Position Y (0.0 à 1.0)
---@param scale number Échelle du texte
---@param text string Le texte à afficher
---@param r number|nil Rouge (0-255)
---@param g number|nil Vert (0-255)
---@param b number|nil Bleu (0-255)
---@param a number|nil Alpha (0-255)
function Redzone.Client.Utils.DrawText2D(x, y, scale, text, r, g, b, a)
    r = r or 255
    g = g or 255
    b = b or 255
    a = a or 255

    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

---Affiche un texte 3D dans le monde
---@param coords vector3 Position dans le monde
---@param text string Le texte à afficher
---@param scale number|nil Échelle (optionnel)
function Redzone.Client.Utils.DrawText3D(coords, text, scale)
    scale = scale or 0.35

    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)

    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(true)
        SetTextColour(255, 255, 255, 255)
        SetTextDropShadow()
        SetTextOutline()
        SetTextCentre(true)
        SetTextEntry('STRING')
        AddTextComponentString(text)
        DrawText(screenX, screenY)
    end
end

-- =====================================================
-- UTILITAIRES DIVERS
-- =====================================================

---Vérifie si une touche est pressée (avec cooldown)
---@param key number Code de la touche
---@return boolean pressed True si la touche est pressée
local keyPressedCooldowns = {}
function Redzone.Client.Utils.IsKeyJustPressed(key)
    if IsControlJustPressed(0, key) then
        local currentTime = GetGameTimer()
        if not keyPressedCooldowns[key] or currentTime - keyPressedCooldowns[key] > 200 then
            keyPressedCooldowns[key] = currentTime
            return true
        end
    end
    return false
end

---Obtient la distance entre le joueur et un point
---@param coords vector3 Les coordonnées du point
---@return number distance La distance
function Redzone.Client.Utils.GetDistanceToPoint(coords)
    local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
    return #(playerCoords - coords)
end

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/UTILS] Utilitaires client chargés')
