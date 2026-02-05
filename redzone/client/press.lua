--[[
    =====================================================
    REDZONE LEAGUE - Système de Press
    =====================================================
    Ce fichier gère le système de press entre joueurs.
    Permet de presser un joueur adverse pour lui demander
    de drop ses items.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Press = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- État du système
local lastPressTime = 0
local isBeingPressed = false
local presserPlayerId = nil
local pressedPlayerId = nil
local pressEndTime = 0
local sphereEndTime = 0

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Vérifie si le joueur est dans le redzone
---@return boolean
local function IsInRedzone()
    if Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone then
        return Redzone.Client.Teleport.IsInRedzone()
    end
    return false
end

---Vérifie si un joueur est dans notre squad
---@param targetServerId number
---@return boolean
local function IsInMySquad(targetServerId)
    if Redzone.Client.Squad and Redzone.Client.Squad.IsPlayerInMySquad then
        return Redzone.Client.Squad.IsPlayerInMySquad(targetServerId)
    end
    return false
end

---Trouve le joueur le plus proche (pas dans notre squad)
---@return number|nil playerId L'ID local du joueur
---@return number|nil serverId L'ID serveur du joueur
---@return number|nil distance La distance
local function GetNearestPlayer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local myServerId = GetPlayerServerId(PlayerId())

    local closestPlayer = nil
    local closestServerId = nil
    local closestDistance = Config.Press.MaxDistance

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(playerCoords - targetCoords)

                if distance < closestDistance then
                    local targetServerId = GetPlayerServerId(playerId)

                    -- Vérifier que ce n'est pas un coéquipier
                    if not IsInMySquad(targetServerId) then
                        closestPlayer = playerId
                        closestServerId = targetServerId
                        closestDistance = distance
                    end
                end
            end
        end
    end

    return closestPlayer, closestServerId, closestDistance
end

---Dessine une sphère autour d'un joueur
---@param playerId number L'ID local du joueur
local function DrawSphereAroundPlayer(playerId)
    local targetPed = GetPlayerPed(playerId)
    if not DoesEntityExist(targetPed) then return end

    local coords = GetEntityCoords(targetPed)
    local color = Config.Press.SphereColor
    local radius = Config.Press.SphereRadius

    -- Dessiner la sphère (marker type 28 = sphere)
    DrawMarker(
        28,                                     -- Type: Sphere
        coords.x, coords.y, coords.z,           -- Position
        0.0, 0.0, 0.0,                          -- Direction
        0.0, 0.0, 0.0,                          -- Rotation
        radius * 2, radius * 2, radius * 2,    -- Scale
        color.r, color.g, color.b, color.a,    -- Couleur RGBA
        false,                                  -- Bob up and down
        false,                                  -- Face camera
        2,                                      -- p19
        false,                                  -- Rotate
        nil, nil,                               -- Texture
        false                                   -- Draw on entities
    )
end

-- =====================================================
-- SYSTÈME DE PRESS
-- =====================================================

---Presser un joueur proche
function Redzone.Client.Press.PressPlayer()
    -- Vérifications de base
    if not Config.Press.Enabled then return end

    if not IsInRedzone() then
        if Redzone.Client.Utils and Redzone.Client.Utils.NotifyError then
            Redzone.Client.Utils.NotifyError(Config.Press.Messages.NotInRedzone)
        end
        return
    end

    -- Vérifier le cooldown
    local currentTime = GetGameTimer()
    local cooldownMs = Config.Press.Cooldown * 1000
    if currentTime - lastPressTime < cooldownMs then
        if Redzone.Client.Utils and Redzone.Client.Utils.NotifyError then
            Redzone.Client.Utils.NotifyError(Config.Press.Messages.OnCooldown)
        end
        return
    end

    -- Trouver le joueur le plus proche
    local targetPlayerId, targetServerId, distance = GetNearestPlayer()

    if not targetPlayerId then
        if Redzone.Client.Utils and Redzone.Client.Utils.NotifyError then
            Redzone.Client.Utils.NotifyError(Config.Press.Messages.NoPlayerNearby)
        end
        return
    end

    -- Enregistrer le press
    lastPressTime = currentTime
    pressedPlayerId = targetPlayerId
    sphereEndTime = currentTime + (Config.Press.SphereDisplayDuration * 1000)

    -- Notifier le serveur pour qu'il notifie l'autre joueur
    TriggerServerEvent('redzone:press:pressPlayer', targetServerId)

    -- Afficher le message pour le joueur qui presse
    SendNUIMessage({
        action = 'showPressNotification',
        type = 'presser',
        title = Config.Press.Messages.YouPressed,
        subtitle = Config.Press.Messages.YouPressedSub,
        duration = Config.Press.NotificationDuration,
    })

    Redzone.Shared.Debug('[PRESS] Joueur pressé: ', targetServerId)
end

---Appelé quand on se fait presser
---@param presserServerId number L'ID serveur du joueur qui nous presse
function Redzone.Client.Press.OnBeingPressed(presserServerId)
    local currentTime = GetGameTimer()

    isBeingPressed = true
    pressEndTime = currentTime + (Config.Press.NotificationDuration * 1000)
    sphereEndTime = currentTime + (Config.Press.SphereDisplayDuration * 1000)

    -- Trouver l'ID local du presser
    for _, playerId in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(playerId) == presserServerId then
            presserPlayerId = playerId
            break
        end
    end

    -- Afficher la notification style Apple
    SendNUIMessage({
        action = 'showPressNotification',
        type = 'pressed',
        title = Config.Press.Messages.BeingPressed,
        subtitle = Config.Press.Messages.BeingPressedSub,
        duration = Config.Press.NotificationDuration,
    })

    Redzone.Shared.Debug('[PRESS] Je suis pressé par: ', presserServerId)
end

-- =====================================================
-- ÉVÉNEMENTS SERVEUR
-- =====================================================

RegisterNetEvent('redzone:press:beingPressed')
AddEventHandler('redzone:press:beingPressed', function(presserServerId)
    Redzone.Client.Press.OnBeingPressed(presserServerId)
end)

-- =====================================================
-- DETECTION TOUCHE H (Presser un joueur)
-- =====================================================

CreateThread(function()
    while true do
        local sleep = 200

        if IsInRedzone() then
            sleep = 0
            -- Touche H (INPUT_VEH_HEADLIGHT = 74)
            if IsControlJustPressed(0, 74) then
                Redzone.Client.Press.PressPlayer()
            end
        end

        Wait(sleep)
    end
end)

-- =====================================================
-- THREAD DE RENDU DES SPHÈRES
-- =====================================================

CreateThread(function()
    while true do
        local sleep = 500

        if IsInRedzone() then
            local currentTime = GetGameTimer()

            -- Dessiner la sphère autour du joueur pressé (pour celui qui presse)
            if pressedPlayerId and currentTime < sphereEndTime then
                sleep = 0
                DrawSphereAroundPlayer(pressedPlayerId)
            else
                pressedPlayerId = nil
            end

            -- Dessiner la sphère autour du joueur qui nous presse (pour celui qui est pressé)
            if isBeingPressed and presserPlayerId and currentTime < sphereEndTime then
                sleep = 0
                DrawSphereAroundPlayer(presserPlayerId)
            end

            -- Reset l'état si le temps est écoulé
            if isBeingPressed and currentTime >= pressEndTime then
                isBeingPressed = false
                presserPlayerId = nil
            end
        end

        Wait(sleep)
    end
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    SendNUIMessage({ action = 'hidePressNotification' })
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/PRESS] Module Press chargé')
