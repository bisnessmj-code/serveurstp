--[[
    =====================================================
    REDZONE LEAGUE - Système de Téléportation
    =====================================================
    Ce fichier gère la téléportation des joueurs
    vers le redzone et le système de sortie.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Teleport = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- État actuel du joueur
local playerState = Redzone.Shared.Constants.PlayerStates.OUTSIDE

-- Téléportation en cours
local isTeleporting = false
local cancelTeleport = false

-- =====================================================
-- GESTION DE L'ÉTAT DU JOUEUR
-- =====================================================

---Obtient l'état actuel du joueur
---@return number state L'état du joueur
function Redzone.Client.Teleport.GetPlayerState()
    return playerState
end

---Définit l'état du joueur
---@param state number Le nouvel état
function Redzone.Client.Teleport.SetPlayerState(state)
    playerState = state
    Redzone.Shared.Debug('[TELEPORT] État du joueur changé: ', state)
end

---Vérifie si le joueur est dans le redzone
---@return boolean inRedzone True si dans le redzone
function Redzone.Client.Teleport.IsInRedzone()
    return playerState == Redzone.Shared.Constants.PlayerStates.IN_REDZONE
end

-- =====================================================
-- TÉLÉPORTATION VERS LE REDZONE
-- =====================================================

---Démarre la téléportation vers un point de spawn
---@param spawnId number L'ID du point de spawn
function Redzone.Client.Teleport.StartTeleport(spawnId)
    -- Vérification si déjà en téléportation
    if isTeleporting then
        Redzone.Client.Utils.NotifyWarning('Une téléportation est déjà en cours!')
        return
    end

    -- Recherche du point de spawn
    local spawnPoint = nil
    for _, spawn in ipairs(Config.SpawnPoints) do
        if spawn.id == spawnId then
            spawnPoint = spawn
            break
        end
    end

    if not spawnPoint then
        Redzone.Client.Utils.NotifyError('Point de spawn invalide!')
        return
    end

    -- Démarrage de la téléportation
    isTeleporting = true
    cancelTeleport = false
    Redzone.Client.Teleport.SetPlayerState(Redzone.Shared.Constants.PlayerStates.TELEPORTING)

    Redzone.Shared.Debug(Config.DebugMessages.TeleportStarted)
    Redzone.Client.Utils.NotifyInfo('Téléportation vers ' .. spawnPoint.name .. ' dans 3 secondes...')

    -- Thread de téléportation avec compte à rebours court
    CreateThread(function()
        local countdown = 3
        local endTime = GetGameTimer() + (countdown * 1000)

        -- Boucle d'affichage du countdown
        while GetGameTimer() < endTime and not cancelTeleport do
            local remaining = math.ceil((endTime - GetGameTimer()) / 1000)
            Redzone.Client.Utils.DrawText2D(0.5, 0.4, 1.5, 'TÉLÉPORTATION DANS ' .. remaining, 255, 0, 0, 255)
            Wait(0)
        end

        if not cancelTeleport then
            -- Téléportation effective vers le point de spawn sélectionné
            Redzone.Client.Utils.TeleportPlayer(spawnPoint.coords)
            Redzone.Client.Teleport.SetPlayerState(Redzone.Shared.Constants.PlayerStates.IN_REDZONE)

            -- Sauvegarder le spawn point pour le système de mort
            if Redzone.Client.Death and Redzone.Client.Death.SetChosenSpawn then
                Redzone.Client.Death.SetChosenSpawn(spawnId)
            end

            -- Créer les blips et activer les zones (via zones.lua)
            Redzone.Client.Zones.OnEnterRedzone()

            -- Notification de succès
            Redzone.Client.Utils.NotifySuccess('Bienvenue dans le REDZONE LEAGUE!')

            -- Informer le serveur
            TriggerServerEvent('redzone:playerEntered', spawnId)

            Redzone.Shared.Debug(Config.DebugMessages.TeleportCompleted)
        end

        isTeleporting = false
    end)
end

-- =====================================================
-- SORTIE DU REDZONE
-- =====================================================

---Démarre le processus de sortie du redzone
function Redzone.Client.Teleport.StartLeaving()
    -- Vérification si le joueur est dans le redzone
    if not Redzone.Client.Teleport.IsInRedzone() then
        Redzone.Client.Utils.NotifyWarning('Vous n\'êtes pas dans le REDZONE!')
        return
    end

    -- Vérification si déjà en cours de sortie
    if playerState == Redzone.Shared.Constants.PlayerStates.LEAVING then
        Redzone.Client.Utils.NotifyWarning('Sortie déjà en cours! Appuyez sur X pour annuler.')
        return
    end

    -- Changement d'état
    Redzone.Client.Teleport.SetPlayerState(Redzone.Shared.Constants.PlayerStates.LEAVING)
    cancelTeleport = false

    local countdownSeconds = Config.Gamemode.QuitCountdown
    Redzone.Client.Utils.NotifyInfo('Sortie du REDZONE dans ' .. countdownSeconds .. ' secondes. Appuyez sur X pour annuler.')

    -- Thread de compte à rebours
    CreateThread(function()
        local endTime = GetGameTimer() + (countdownSeconds * 1000)

        -- Boucle d'affichage du countdown
        while GetGameTimer() < endTime and not cancelTeleport do
            local remaining = math.ceil((endTime - GetGameTimer()) / 1000)

            -- Affichage du compte à rebours au centre de l'écran
            Redzone.Client.Utils.DrawText2D(0.5, 0.4, 1.5, 'SORTIE DANS ' .. remaining, 255, 0, 0, 255)
            Redzone.Client.Utils.DrawText2D(0.5, 0.48, 0.5, 'Appuyez sur X pour annuler', 255, 255, 255, 200)
            

            -- Vérification de l'annulation
            if IsControlJustPressed(0, Config.Interaction.CancelKey) then
                cancelTeleport = true
            end

            Wait(0)
        end

        if cancelTeleport then
            -- Annulation de la sortie
            Redzone.Client.Teleport.SetPlayerState(Redzone.Shared.Constants.PlayerStates.IN_REDZONE)
            Redzone.Client.Utils.NotifyInfo('Sortie annulée.')
            Redzone.Shared.Debug(Config.DebugMessages.TeleportCancelled)
        else
            -- Supprimer les blips et désactiver les zones (via zones.lua)
            Redzone.Client.Zones.OnLeaveRedzone()

            -- Téléportation vers le point de sortie fixe
            Redzone.Client.Utils.TeleportPlayer(Config.Gamemode.ExitPoint)

            Redzone.Client.Teleport.SetPlayerState(Redzone.Shared.Constants.PlayerStates.OUTSIDE)
            Redzone.Client.Utils.NotifySuccess('Vous avez quitté le REDZONE LEAGUE.')

            -- Informer le serveur
            TriggerServerEvent('redzone:playerLeft')

            Redzone.Shared.Debug(Config.DebugMessages.TeleportCompleted)
        end
    end)
end

---Annule la sortie en cours
function Redzone.Client.Teleport.CancelLeaving()
    if playerState == Redzone.Shared.Constants.PlayerStates.LEAVING then
        cancelTeleport = true
        Redzone.Shared.Debug('[TELEPORT] Sortie annulée par le joueur')
    end
end

-- =====================================================
-- COMMANDE DE SORTIE
-- =====================================================

---Enregistrement de la commande /quitredzone
RegisterCommand(Config.Gamemode.QuitCommand, function()
    if Redzone.Client.Teleport.IsInRedzone() then
        if playerState == Redzone.Shared.Constants.PlayerStates.LEAVING then
            -- Annuler si déjà en cours
            Redzone.Client.Teleport.CancelLeaving()
        else
            -- Démarrer la sortie
            Redzone.Client.Teleport.StartLeaving()
        end
    else
        Redzone.Client.Utils.NotifyError('Vous n\'êtes pas dans le REDZONE!')
    end
end, false)

-- =====================================================
-- NOTE: La sortie du redzone se fait désormais via les PEDs de sortie (exitped.lua)
-- L'ancien système de touche X a été remplacé.
-- =====================================================

-- =====================================================
-- ÉVÉNEMENTS SERVEUR (KICK FORCÉ)
-- =====================================================

---Événement: Forcer le kick du redzone (par un staff)
RegisterNetEvent('redzone:forceKick')
AddEventHandler('redzone:forceKick', function(exitCoords)
    -- Annuler tout ce qui est en cours
    cancelTeleport = true
    isTeleporting = false

    -- Supprimer les blips et désactiver les zones
    if Redzone.Client.Zones and Redzone.Client.Zones.OnLeaveRedzone then
        Redzone.Client.Zones.OnLeaveRedzone()
    end

    -- Supprimer le blip de blanchiment
    if Redzone.Client.Laundering and Redzone.Client.Laundering.OnLeaveRedzone then
        Redzone.Client.Laundering.OnLeaveRedzone()
    end

    -- Supprimer le blip de combat zone
    if Redzone.Client.CombatZone and Redzone.Client.CombatZone.OnLeaveRedzone then
        Redzone.Client.CombatZone.OnLeaveRedzone()
    end

    -- Reset de l'état de mort si nécessaire
    if Redzone.Client.Death and Redzone.Client.Death.ForceResetState then
        Redzone.Client.Death.ForceResetState()
    end

    -- Téléportation immédiate vers le point de sortie
    local playerPed = PlayerPedId()

    -- Fade out
    DoScreenFadeOut(500)
    Wait(500)

    -- Téléportation
    SetEntityCoords(playerPed, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, true)
    SetEntityHeading(playerPed, exitCoords.w)

    -- Remettre la vie complète si nécessaire
    if GetEntityHealth(playerPed) < 200 then
        SetEntityHealth(playerPed, 200)
    end

    -- Arrêter toute animation/ragdoll
    ClearPedTasksImmediately(playerPed)
    SetPedCanRagdoll(playerPed, true)

    -- Réactiver tous les contrôles
    EnableAllControlActions(0)
    SetNuiFocus(false, false)

    -- Fermer les NUI potentiellement ouverts
    SendNUIMessage({ action = 'hideDeathScreen' })
    SendNUIMessage({ action = 'hideReviveProgress' })
    SendNUIMessage({ action = 'hideLootProgress' })
    SendNUIMessage({ action = 'hideBandageProgress' })

    -- Fade in
    Wait(500)
    DoScreenFadeIn(500)

    -- Changer l'état
    Redzone.Client.Teleport.SetPlayerState(Redzone.Shared.Constants.PlayerStates.OUTSIDE)

    Redzone.Shared.Debug('[TELEPORT] Joueur kick du redzone par un staff')
end)

-- =====================================================
-- EXPORTS
-- =====================================================

-- Export pour téléporter vers le redzone
exports('TeleportToRedzone', function(spawnId)
    Redzone.Client.Teleport.StartTeleport(spawnId)
end)

-- Export pour quitter le redzone
exports('LeaveRedzone', function()
    Redzone.Client.Teleport.StartLeaving()
end)

-- Export pour vérifier si le joueur est dans le redzone
exports('IsInRedzone', function()
    return Redzone.Client.Teleport.IsInRedzone()
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/TELEPORT] Module Téléportation chargé')
