--[[
    =====================================================
    REDZONE LEAGUE - Système de Blanchiment d'Argent
    =====================================================
    Ce fichier gère le système de blanchiment d'argent sale.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Laundering = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- État du blanchiment
local isLaundering = false
local isNearLaunderingZone = false
local launderingBlip = nil
local launderingStartPos = nil
local shouldContinueLaundering = false  -- Pour le mode automatique

-- Système de positions dynamiques
local currentPositionIndex = 1
local currentLaunderingZone = nil
local lastZoneChange = 0

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Vérifie si le joueur est dans le redzone
---@return boolean
local function IsInRedzone()
    return Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone() or false
end

---Dessine un cercle au sol
---@param coords vector3 Position du cercle
---@param radius number Rayon du cercle
---@param r number Rouge
---@param g number Vert
---@param b number Bleu
---@param a number Alpha
local function DrawGroundCircle(coords, radius, r, g, b, a)
    DrawMarker(
        1,                          -- Type: Cercle
        coords.x, coords.y, coords.z - 0.98,  -- Position (légèrement sous le sol)
        0.0, 0.0, 0.0,              -- Direction
        0.0, 0.0, 0.0,              -- Rotation
        radius * 2, radius * 2, 1.0, -- Scale
        r, g, b, a,                 -- Couleur RGBA
        false,                      -- Bob up and down
        false,                      -- Face camera
        2,                          -- p19
        false,                      -- Rotate
        nil, nil,                   -- Texture
        false                       -- Draw on entities
    )
end

-- =====================================================
-- CRÉATION DU BLIP
-- =====================================================

---Crée le blip de blanchiment à la position actuelle
function Redzone.Client.Laundering.CreateBlip()
    if not Config.MoneyLaundering.Enabled then return end
    if not Config.MoneyLaundering.Blip.Enabled then return end

    -- Supprimer l'ancien blip s'il existe
    Redzone.Client.Laundering.DeleteBlip()

    -- Obtenir la position actuelle
    if not currentLaunderingZone or not currentLaunderingZone.coords then return end

    local coords = currentLaunderingZone.coords
    local blipConfig = Config.MoneyLaundering.Blip

    launderingBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(launderingBlip, blipConfig.Sprite)
    SetBlipDisplay(launderingBlip, 4)
    SetBlipScale(launderingBlip, blipConfig.Scale)
    SetBlipColour(launderingBlip, blipConfig.Color)
    SetBlipAsShortRange(launderingBlip, false) -- Visible de loin
    SetBlipFlashes(launderingBlip, true) -- Clignoter au changement

    -- Arrêter le clignotement après 5 secondes
    SetTimeout(5000, function()
        if launderingBlip and DoesBlipExist(launderingBlip) then
            SetBlipFlashes(launderingBlip, false)
        end
    end)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipConfig.Name .. ' - ' .. currentLaunderingZone.name)
    EndTextCommandSetBlipName(launderingBlip)

    Redzone.Shared.Debug('[LAUNDERING] Blip créé pour: ', currentLaunderingZone.name)
end

---Supprime le blip de blanchiment
function Redzone.Client.Laundering.DeleteBlip()
    if launderingBlip and DoesBlipExist(launderingBlip) then
        RemoveBlip(launderingBlip)
        launderingBlip = nil
        Redzone.Shared.Debug('[LAUNDERING] Blip supprimé')
    end
end

-- =====================================================
-- SYSTÈME DE POSITIONS DYNAMIQUES
-- =====================================================

---Initialise la position de blanchiment
---NOTE: La position sera synchronisée par le serveur via 'redzone:syncLaunderingZone'
function Redzone.Client.Laundering.InitializePosition()
    local positions = Config.MoneyLaundering.Positions
    if not positions or #positions == 0 then return end

    -- La position sera définie quand le serveur enverra la synchronisation
    -- Ne pas initialiser à l'index 1 ici, attendre le serveur
    Redzone.Shared.Debug('[LAUNDERING] En attente de synchronisation du serveur...')
end

---Change la position de blanchiment vers la suivante
function Redzone.Client.Laundering.ChangePosition()
    local positions = Config.MoneyLaundering.Positions
    if not positions or #positions == 0 then return end

    -- Annuler le blanchiment en cours si nécessaire
    if isLaundering or shouldContinueLaundering then
        Redzone.Client.Laundering.CancelLaundering('zone_changed')
    end

    -- Passer à la position suivante (boucle)
    currentPositionIndex = currentPositionIndex + 1
    if currentPositionIndex > #positions then
        currentPositionIndex = 1
    end

    currentLaunderingZone = positions[currentPositionIndex]
    lastZoneChange = GetGameTimer()

    -- Recréer le blip à la nouvelle position
    Redzone.Client.Laundering.CreateBlip()

    -- Notifier le joueur - sans son
    if Config.MoneyLaundering.Messages.ZoneChanged then
        local message = string.format(Config.MoneyLaundering.Messages.ZoneChanged, currentLaunderingZone.name)
        if Redzone.Client.Utils and Redzone.Client.Utils.Notify then
            Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Warning, nil, false)
        end
    end

    Redzone.Shared.Debug('[LAUNDERING] Position changée vers: ', currentLaunderingZone.name)
end

---Obtient la position actuelle de blanchiment
---@return table|nil zone La zone actuelle
function Redzone.Client.Laundering.GetCurrentPosition()
    return currentLaunderingZone
end

-- NOTE: Le changement automatique de position est maintenant géré côté serveur
-- pour assurer la synchronisation entre tous les joueurs.
-- Le client écoute l'event 'redzone:syncLaunderingZone' pour recevoir les mises à jour.

---Change la position de blanchiment vers un index spécifique (appelé par le serveur)
---@param positionIndex number L'index de la nouvelle position
function Redzone.Client.Laundering.SetPositionIndex(positionIndex)
    local positions = Config.MoneyLaundering.Positions
    if not positions or #positions == 0 then return end

    -- Vérifier que l'index est valide
    if positionIndex < 1 or positionIndex > #positions then
        Redzone.Shared.Debug('[LAUNDERING] Index de position invalide: ', positionIndex)
        return
    end

    -- Ne rien faire si c'est déjà la même position (sauf première sync)
    local isFirstSync = currentLaunderingZone == nil
    if currentPositionIndex == positionIndex and currentLaunderingZone then
        Redzone.Shared.Debug('[LAUNDERING] Position déjà à l\'index: ', positionIndex)
        return
    end

    local oldIndex = currentPositionIndex

    -- Annuler le blanchiment en cours si c'est un vrai changement (pas première sync)
    if not isFirstSync and (isLaundering or shouldContinueLaundering) then
        Redzone.Client.Laundering.CancelLaundering('zone_changed')
    end

    currentPositionIndex = positionIndex
    currentLaunderingZone = positions[currentPositionIndex]

    -- Recréer le blip à la nouvelle position
    Redzone.Client.Laundering.CreateBlip()

    -- Notifier le joueur seulement si c'est un changement (pas la première synchronisation) - sans son
    if not isFirstSync and oldIndex ~= positionIndex then
        if Config.MoneyLaundering.Messages.ZoneChanged then
            local message = string.format(Config.MoneyLaundering.Messages.ZoneChanged, currentLaunderingZone.name)
            if Redzone.Client.Utils and Redzone.Client.Utils.Notify then
                Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Warning, nil, false)
            end
        end
    end

    Redzone.Shared.Debug('[LAUNDERING] Position synchronisée vers: ', currentLaunderingZone.name, ' (index: ', positionIndex, ')')
end

---Event: Synchronisation de la zone de blanchiment depuis le serveur
RegisterNetEvent('redzone:syncLaunderingZone')
AddEventHandler('redzone:syncLaunderingZone', function(positionIndex)
    if not Config.MoneyLaundering.Enabled then return end

    -- Vérifier si on est dans le redzone
    if IsInRedzone() then
        Redzone.Client.Laundering.SetPositionIndex(positionIndex)
    end
end)

-- =====================================================
-- SYSTÈME DE BLANCHIMENT
-- =====================================================

---Démarre ou arrête le processus de blanchiment (mode automatique)
function Redzone.Client.Laundering.ToggleLaundering()
    -- Si déjà en cours, arrêter
    if isLaundering or shouldContinueLaundering then
        Redzone.Client.Laundering.CancelLaundering('player_stopped')
        return
    end

    if not isNearLaunderingZone then return end

    isLaundering = true
    shouldContinueLaundering = true
    launderingStartPos = GetEntityCoords(PlayerPedId())

    -- Demander au serveur de vérifier et lancer le blanchiment
    TriggerServerEvent('redzone:laundering:start')
end

---Démarre le processus de blanchiment (pour compatibilité)
function Redzone.Client.Laundering.StartLaundering()
    Redzone.Client.Laundering.ToggleLaundering()
end

---Callback: Blanchiment autorisé par le serveur
RegisterNetEvent('redzone:laundering:confirmed')
AddEventHandler('redzone:laundering:confirmed', function(duration, fee, amount)
    if not isLaundering then return end

    Redzone.Shared.Debug('[LAUNDERING] Blanchiment confirmé - Durée: ', duration, 's, Fee: ', fee, '%')

    local playerPed = PlayerPedId()

    -- Afficher la barre de progression NUI
    SendNUIMessage({
        action = 'showLaunderingProgress',
        duration = duration,
    })

    -- Notification (seulement la première fois) - sans son
    if shouldContinueLaundering then
        Redzone.Client.Utils.Notify(Config.ScriptName, Config.MoneyLaundering.Messages.LaunderingInProgress, Config.Notify.Types.Info, nil, false)
    end

    -- Animation
    CreateThread(function()
        local animDict = 'anim@heists@ornate_bank@grab_cash'
        local animName = 'grab'

        RequestAnimDict(animDict)
        local timeout = 50
        while not HasAnimDictLoaded(animDict) and timeout > 0 do
            Wait(10)
            timeout = timeout - 1
        end

        if HasAnimDictLoaded(animDict) and isLaundering then
            TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end)

    -- Thread de vérification
    CreateThread(function()
        local startTime = GetGameTimer()
        local durationMs = duration * 1000

        while isLaundering do
            Wait(100)

            local playerPed = PlayerPedId()
            local currentPos = GetEntityCoords(playerPed)

            -- Vérifier si le joueur a bougé (par rapport à la position initiale)
            if launderingStartPos and #(currentPos - launderingStartPos) > 1.5 then
                Redzone.Client.Laundering.CancelLaundering('mouvement')
                return
            end

            -- Vérifier si le temps est écoulé
            local elapsed = GetGameTimer() - startTime
            if elapsed >= durationMs then
                -- Succès! Demander au serveur de finaliser et vérifier s'il reste de l'argent
                Redzone.Client.Laundering.FinishLaundering()
                return
            end
        end
    end)
end)

---Callback: Blanchiment refusé
RegisterNetEvent('redzone:laundering:denied')
AddEventHandler('redzone:laundering:denied', function(reason)
    local wasActive = isLaundering

    isLaundering = false
    shouldContinueLaundering = false
    launderingStartPos = nil

    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
    SendNUIMessage({ action = 'hideLaunderingProgress' })

    if reason == 'not_enough' then
        -- Si c'était en mode auto et plus d'argent, message différent - sans son
        if wasActive then
            Redzone.Client.Utils.Notify(Config.ScriptName, 'Blanchiment terminé - Plus d\'argent sale', Config.Notify.Types.Info, nil, false)
        else
            Redzone.Client.Utils.Notify(Config.ScriptName, Config.MoneyLaundering.Messages.NotEnoughDirtyMoney, Config.Notify.Types.Error, nil, false)
        end
    else
        Redzone.Client.Utils.Notify(Config.ScriptName, 'Impossible de blanchir l\'argent', Config.Notify.Types.Error, nil, false)
    end
end)

---Termine le blanchiment avec succès (un cycle)
function Redzone.Client.Laundering.FinishLaundering()
    if not isLaundering then return end

    Redzone.Shared.Debug('[LAUNDERING] Cycle de blanchiment terminé')

    -- Cacher la barre de progression temporairement
    SendNUIMessage({ action = 'hideLaunderingProgress' })

    -- Notifier le serveur - il va vérifier s'il reste de l'argent et relancer automatiquement
    TriggerServerEvent('redzone:laundering:finish')
end

---Annule le blanchiment en cours
---@param reason string|nil Raison de l'annulation
function Redzone.Client.Laundering.CancelLaundering(reason)
    if not isLaundering and not shouldContinueLaundering then return end

    Redzone.Shared.Debug('[LAUNDERING] Annulé - Raison: ', reason or 'unknown')

    shouldContinueLaundering = false
    isLaundering = false
    launderingStartPos = nil

    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)

    SendNUIMessage({ action = 'hideLaunderingProgress' })

    TriggerServerEvent('redzone:laundering:cancel')

    -- Message différent selon la raison - sans son
    if reason == 'player_stopped' then
        Redzone.Client.Utils.Notify(Config.ScriptName, 'Blanchiment arrêté', Config.Notify.Types.Info, nil, false)
    elseif reason == 'zone_changed' then
        Redzone.Client.Utils.Notify(Config.ScriptName, 'Blanchiment annulé - La zone a changé de position !', Config.Notify.Types.Warning, nil, false)
    else
        Redzone.Client.Utils.Notify(Config.ScriptName, Config.MoneyLaundering.Messages.LaunderingCancelled, Config.Notify.Types.Warning, nil, false)
    end
end

---Callback: Blanchiment réussi (un cycle)
RegisterNetEvent('redzone:laundering:success')
AddEventHandler('redzone:laundering:success', function(cleanAmount, totalLaundered)
    -- Notification désactivée (trop de bruit)
    -- local message = string.format('+$%s blanchis', cleanAmount)
    -- Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Success, nil, false)
end)

---Callback: Continuer le blanchiment automatiquement
RegisterNetEvent('redzone:laundering:continue')
AddEventHandler('redzone:laundering:continue', function(duration, fee, amount)
    if not shouldContinueLaundering then return end

    Redzone.Shared.Debug('[LAUNDERING] Continuation automatique...')

    -- Petit délai avant le prochain cycle
    Wait(200)

    -- Vérifier qu'on est toujours dans la zone
    local playerPed = PlayerPedId()
    local currentPos = GetEntityCoords(playerPed)

    if launderingStartPos and #(currentPos - launderingStartPos) > 1.5 then
        Redzone.Client.Laundering.CancelLaundering('mouvement')
        return
    end

    -- Continuer avec le prochain cycle
    isLaundering = true

    -- Afficher la barre de progression NUI
    SendNUIMessage({
        action = 'showLaunderingProgress',
        duration = duration,
    })

    -- Animation
    CreateThread(function()
        local animDict = 'anim@heists@ornate_bank@grab_cash'
        local animName = 'grab'

        RequestAnimDict(animDict)
        local timeout = 50
        while not HasAnimDictLoaded(animDict) and timeout > 0 do
            Wait(10)
            timeout = timeout - 1
        end

        if HasAnimDictLoaded(animDict) and isLaundering then
            TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end)

    -- Thread de vérification
    CreateThread(function()
        local startTime = GetGameTimer()
        local durationMs = duration * 1000

        while isLaundering do
            Wait(100)

            local playerPed = PlayerPedId()
            local currentPos = GetEntityCoords(playerPed)

            -- Vérifier si le joueur a bougé
            if launderingStartPos and #(currentPos - launderingStartPos) > 1.5 then
                Redzone.Client.Laundering.CancelLaundering('mouvement')
                return
            end

            -- Vérifier si le temps est écoulé
            local elapsed = GetGameTimer() - startTime
            if elapsed >= durationMs then
                Redzone.Client.Laundering.FinishLaundering()
                return
            end
        end
    end)
end)

---Callback: Blanchiment complètement terminé (plus d'argent)
RegisterNetEvent('redzone:laundering:complete')
AddEventHandler('redzone:laundering:complete', function(totalLaundered)
    isLaundering = false
    shouldContinueLaundering = false
    launderingStartPos = nil

    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
    SendNUIMessage({ action = 'hideLaunderingProgress' })

    local message = string.format('Blanchiment terminé ! Total: $%s', totalLaundered)
    Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Success, nil, false)
end)

---Callback: Blanchiment arrêté par le joueur (avec total)
RegisterNetEvent('redzone:laundering:stopped')
AddEventHandler('redzone:laundering:stopped', function(totalLaundered)
    if totalLaundered > 0 then
        local message = string.format('Blanchiment arrêté - Total blanchi: $%s', totalLaundered)
        Redzone.Client.Utils.Notify(Config.ScriptName, message, Config.Notify.Types.Success, nil, false)
    end
end)

-- =====================================================
-- THREAD D'INTERACTION
-- =====================================================

---Démarre le thread d'interaction pour le blanchiment
function Redzone.Client.Laundering.StartInteractionThread()
    if not Config.MoneyLaundering.Enabled then
        Redzone.Shared.Debug('[LAUNDERING] Système désactivé')
        return
    end

    Redzone.Shared.Debug('[LAUNDERING] Démarrage du thread d\'interaction')

    CreateThread(function()
        while true do
            local sleep = 1000

            if IsInRedzone() and currentLaunderingZone and currentLaunderingZone.coords then
                local playerCoords = GetEntityCoords(PlayerPedId())
                local zoneCoords = currentLaunderingZone.coords
                local distance = #(playerCoords - vector3(zoneCoords.x, zoneCoords.y, zoneCoords.z))

                -- Afficher le cercle si proche
                if distance < 10.0 then
                    sleep = 0

                    -- Dessiner le cercle rouge (vert si en cours de blanchiment)
                    if isLaundering or shouldContinueLaundering then
                        DrawGroundCircle(
                            vector3(zoneCoords.x, zoneCoords.y, zoneCoords.z),
                            Config.MoneyLaundering.InteractRadius,
                            0, 255, 0, 100  -- Vert quand actif
                        )
                    else
                        DrawGroundCircle(
                            vector3(zoneCoords.x, zoneCoords.y, zoneCoords.z),
                            Config.MoneyLaundering.InteractRadius,
                            255, 0, 0, 100  -- Rouge quand inactif
                        )
                    end

                    -- Vérifier si dans la zone d'interaction
                    if distance <= Config.MoneyLaundering.InteractRadius then
                        isNearLaunderingZone = true

                        -- Afficher le texte d'aide approprié
                        if isLaundering or shouldContinueLaundering then
                            Redzone.Client.Utils.ShowHelpText('Appuyez sur ~INPUT_CONTEXT~ pour arrêter le blanchiment')
                        else
                            Redzone.Client.Utils.ShowHelpText(Config.MoneyLaundering.Messages.HelpText)
                        end

                        -- Vérifier l'input pour démarrer OU arrêter
                        if Redzone.Client.Utils.IsKeyJustPressed(Config.Interaction.InteractKey) then
                            Redzone.Client.Laundering.ToggleLaundering()
                        end
                    else
                        isNearLaunderingZone = false
                    end
                else
                    sleep = 500
                    isNearLaunderingZone = false
                end
            else
                isNearLaunderingZone = false
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur entre dans le redzone
function Redzone.Client.Laundering.OnEnterRedzone()
    -- Initialiser la position si pas encore fait
    if not currentLaunderingZone then
        Redzone.Client.Laundering.InitializePosition()
    end

    -- Créer le blip
    Redzone.Client.Laundering.CreateBlip()

    -- Notifier le joueur de la position active
    if currentLaunderingZone then
        Redzone.Shared.Debug('[LAUNDERING] Zone de blanchiment active: ', currentLaunderingZone.name)
    end
end

---Appelé quand le joueur quitte le redzone
function Redzone.Client.Laundering.OnLeaveRedzone()
    Redzone.Client.Laundering.DeleteBlip()
    if isLaundering or shouldContinueLaundering then
        Redzone.Client.Laundering.CancelLaundering('left_redzone')
    end
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetCurrentLaunderingZone', function()
    return currentLaunderingZone
end)

exports('IsNearLaunderingZone', function()
    return isNearLaunderingZone
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Redzone.Client.Laundering.DeleteBlip()
    if isLaundering or shouldContinueLaundering then
        isLaundering = false
        shouldContinueLaundering = false
        launderingStartPos = nil
        SendNUIMessage({ action = 'hideLaunderingProgress' })
    end
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

CreateThread(function()
    Wait(1500)

    -- Initialiser (en attente de synchronisation serveur)
    Redzone.Client.Laundering.InitializePosition()

    -- Démarrer le thread d'interaction
    Redzone.Client.Laundering.StartInteractionThread()

    -- NOTE: Le thread de changement automatique est maintenant géré côté serveur
    -- Le client écoute l'event 'redzone:syncLaunderingZone' pour les mises à jour
end)

Redzone.Shared.Debug('[CLIENT/LAUNDERING] Module Blanchiment chargé')
