--[[
    =====================================================
    REDZONE LEAGUE - Système de Mort/Réanimation
    =====================================================
    Ce fichier gère l'état de mort des joueurs,
    le timer de bleedout, et le système de réanimation.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Death = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- État du joueur
local isDead = false
local isBeingRevived = false
local bleedoutTimer = 0
local canRespawn = false -- true après 30 secondes
local justRespawned = false -- Protection temporaire après respawn

-- État de réanimation en cours
local isReviving = false
local reviveTarget = nil
local lastReviveAttempt = 0 -- Cooldown pour éviter spam

-- État du transport
local isCarrying = false
local carriedPlayer = nil
local isBeingCarried = false
local carrierPlayer = nil

-- Joueur à terre le plus proche
local nearestDeadPlayer = nil
local nearestDeadPlayerDist = 999

-- Zone de spawn choisie (stockée quand le joueur entre dans le redzone)
local chosenSpawnPoint = nil

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Vérifie si le joueur est dans le redzone
---@return boolean
local function IsInRedzone()
    return Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone() or false
end

---Obtient le joueur mort le plus proche
---@return number|nil playerId
---@return number distance
local function GetNearestDeadPlayer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = nil
    local closestDist = Config.Death.InteractDistance

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(playerCoords - targetCoords)

                if dist <= closestDist then
                    -- Vérifier si le joueur est mort via state bag (synchronisé réseau)
                    local targetServerId = GetPlayerServerId(playerId)
                    local targetIsDead = Player(targetServerId).state.isDead
                    if targetIsDead or IsEntityDead(targetPed) or IsPedDeadOrDying(targetPed, true) then
                        closestDist = dist
                        closestPlayer = playerId
                    end
                end
            end
        end
    end

    return closestPlayer, closestDist
end

-- =====================================================
-- GESTION DU SPAWN POINT
-- =====================================================

---Sauvegarde le point de spawn choisi
---@param spawnId number ID du spawn point
function Redzone.Client.Death.SetChosenSpawn(spawnId)
    if Config.SpawnPoints[spawnId] then
        chosenSpawnPoint = Config.SpawnPoints[spawnId]
        Redzone.Shared.Debug('[DEATH] Spawn point sauvegardé: ', spawnId)
    end
end

-- =====================================================
-- GESTION DE LA MORT
-- =====================================================

---Vérifie si un joueur est dans notre squad (via export)
---@param serverId number
---@return boolean
local function IsKillerInMySquad(serverId)
    if not serverId then return false end
    local success, result = pcall(function()
        return exports['redzone']:IsPlayerInMySquad(serverId)
    end)
    if success and result then
        return true
    end
    return false
end

-- Alias pour la réanimation (même fonction)
local function IsTargetInMySquad(serverId)
    return IsKillerInMySquad(serverId)
end

---Vérifie si on a un squad (via export)
---@return boolean
local function HasSquad()
    local success, result = pcall(function()
        return exports['redzone']:HasSquad()
    end)
    if success and result then
        return true
    end
    return false
end

---Met le joueur en état de mort (à terre)
---@param forceKillerServerId number|nil ID du tueur forcé (optionnel)
function Redzone.Client.Death.OnPlayerDeath(forceKillerServerId)
    if isDead then return end
    if not IsInRedzone() then return end

    -- Bloquer la mort en zone safe
    local inSafeZone = false
    local success, result = pcall(function() return exports['redzone']:IsInSafeZone() end)
    if success and result then return end

    local playerPed = PlayerPedId()

    -- Détecter le tueur
    local killerPed = GetPedSourceOfDeath(playerPed)
    local killerServerId = forceKillerServerId

    if not killerServerId and killerPed and DoesEntityExist(killerPed) and IsEntityAPed(killerPed) and IsPedAPlayer(killerPed) then
        local killerPlayerId = NetworkGetPlayerIndexFromPed(killerPed)
        if killerPlayerId and killerPlayerId ~= PlayerId() then
            killerServerId = GetPlayerServerId(killerPlayerId)
        end
    end

    -- VÉRIFICATION SQUAD: Si le tueur est un coéquipier, IGNORER la mort
    if killerServerId and IsKillerInMySquad(killerServerId) then
        Redzone.Shared.Debug('[DEATH] Mort par coéquipier ignorée - Tueur: ', killerServerId)
        -- Restaurer immédiatement la santé
        SetEntityHealth(playerPed, 200)
        ClearPedTasksImmediately(playerPed)
        SetPedCanRagdoll(playerPed, false)
        Wait(100)
        SetPedCanRagdoll(playerPed, true)
        return -- NE PAS déclencher la mort
    end

    isDead = true
    bleedoutTimer = Config.Death.BleedoutTime
    isBeingRevived = false
    canRespawn = false

    -- Annuler le loot en cours si applicable
    if Redzone.Client.Loot and Redzone.Client.Loot.CancelLoot then
        Redzone.Client.Loot.CancelLoot('joueur_mort')
    end

    -- Annuler la réanimation en cours si applicable
    if isReviving then
        Redzone.Client.Death.CancelRevive('joueur_mort')
    end

    -- Fermer l'inventaire qs-inventory si ouvert
    TriggerEvent('inventory:client:forceCloseInventory')
    TriggerEvent('inventory:client:closeinv')

    -- Ressusciter le joueur d'abord pour pouvoir jouer l'animation
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    Wait(0)

    -- Récupérer le ped après résurrection (peut avoir changé)
    playerPed = PlayerPedId()

    -- Rendre invincible et bloquer
    SetEntityHealth(playerPed, 200)
    SetEntityInvincible(playerPed, true)
    SetPedCanRagdoll(playerPed, false)

    -- Marquer comme mort via state bag (synchronisé réseau pour les autres joueurs)
    LocalPlayer.state:set('isDead', true, true)

    -- Jouer l'animation "sleep" (allongé au sol)
    local animDict = 'timetable@tracy@sleep@'
    local animName = 'idle_b'
    RequestAnimDict(animDict)
    local timeout = 50
    while not HasAnimDictLoaded(animDict) and timeout > 0 do
        Wait(10)
        timeout = timeout - 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    -- Ouvrir le NUI du timer
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'showDeathScreen',
        timer = bleedoutTimer,
        message = Config.Death.Messages.Died,
    })

    -- Notifier le serveur (avec l'ID du tueur si trouvé)
    TriggerServerEvent('redzone:death:playerDied', killerServerId)

    -- Démarrer le timer de bleedout
    CreateThread(function()
        while isDead and bleedoutTimer > 0 do
            Wait(1000)
            if not isBeingRevived then
                bleedoutTimer = bleedoutTimer - 1
            end
        end

        -- Timer expiré, permettre le respawn
        if isDead then
            canRespawn = true
            SendNUIMessage({
                action = 'updateDeathScreen',
                message = Config.Death.Messages.CanRespawn,
                canRespawn = true,
            })
        end
    end)

    Redzone.Shared.Debug('[DEATH] Joueur mort - Timer: ', bleedoutTimer)
end

---Réanime le joueur sur place
function Redzone.Client.Death.Revive()
    if not isDead then return end

    Redzone.Shared.Debug('[DEATH] Réanimation en cours...')

    -- PROTECTION: Empêcher le thread de mort de désactiver les contrôles
    justRespawned = true

    -- Notifier le serveur que la victime respawn (fermer le loot si en cours)
    TriggerServerEvent('redzone:loot:victimRespawned')

    -- Reset de tous les états AVANT tout
    isDead = false
    isBeingRevived = false
    isBeingCarried = false
    carrierPlayer = nil
    bleedoutTimer = 0
    canRespawn = false

    -- Retirer le state bag de mort
    LocalPlayer.state:set('isDead', false, true)

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    -- Se détacher si on était porté
    DetachEntity(playerPed, true, true)

    -- Résurrection complète du joueur (réseau)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)

    -- Attendre un frame pour que la résurrection prenne effet
    Wait(0)

    -- Récupérer le PED après résurrection (peut avoir changé)
    playerPed = PlayerPedId()

    -- Retirer l'invincibilité
    SetEntityInvincible(playerPed, false)

    -- Remettre la vie complète
    SetEntityHealth(playerPed, 200)

    -- Effacer tous les états de dégâts/mort
    ClearPedBloodDamage(playerPed)
    ClearEntityLastDamageEntity(playerPed)
    ResetPedVisibleDamage(playerPed)

    -- Arrêter le ragdoll et les animations
    ClearPedTasksImmediately(playerPed)
    SetPedCanRagdoll(playerPed, false)

    -- Réactiver TOUS les contrôles immédiatement
    EnableAllControlActions(0)

    -- Réactiver les contrôles de véhicule spécifiquement
    EnableControlAction(0, 71, true)  -- VehicleAccelerate
    EnableControlAction(0, 72, true)  -- VehicleBrake
    EnableControlAction(0, 59, true)  -- VehicleMoveLeftRight
    EnableControlAction(0, 60, true)  -- VehicleMoveUpDown
    EnableControlAction(0, 63, true)  -- VehicleMoveUpOnly
    EnableControlAction(0, 64, true)  -- VehicleMoveDownOnly
    EnableControlAction(0, 75, true)  -- VehicleExit
    EnableControlAction(0, 76, true)  -- VehicleHandbrake

    -- Réactiver le menu pause (Échap)
    EnableControlAction(0, 199, true) -- Pause Menu
    EnableControlAction(0, 200, true) -- Pause Menu Alternate

    -- S'assurer que le NUI n'a pas le focus
    SetNuiFocus(false, false)

    -- Fermer le NUI
    SendNUIMessage({
        action = 'hideDeathScreen',
    })

    -- Thread de sécurité pour s'assurer que les contrôles restent actifs
    CreateThread(function()
        for i = 1, 20 do
            Wait(100)
            if not isDead and justRespawned then
                EnableAllControlActions(0)
                EnableControlAction(0, 71, true)  -- VehicleAccelerate
                EnableControlAction(0, 72, true)  -- VehicleBrake
                EnableControlAction(0, 199, true) -- Pause Menu
                EnableControlAction(0, 200, true) -- Pause Menu Alternate
            end
        end
        -- Réactiver ragdoll après
        SetPedCanRagdoll(PlayerPedId(), true)
        -- Désactiver la protection après 2 secondes
        justRespawned = false
    end)

    -- Notification de réanimation
    Redzone.Client.Utils.NotifySuccess(Config.Death.Messages.Revived)

    -- Notifier le serveur
    TriggerServerEvent('redzone:death:playerRevived')

    Redzone.Shared.Debug('[DEATH] Joueur réanimé')
end

---Force le reset complet de l'état de mort (appelé par d'autres modules comme squad)
---Cette fonction ne fait PAS de résurrection, elle remet juste les variables à zéro
function Redzone.Client.Death.ForceResetState()
    Redzone.Shared.Debug('[DEATH] Force reset de l\'état de mort')

    -- Reset de tous les états
    isDead = false
    isBeingRevived = false
    isBeingCarried = false
    carrierPlayer = nil
    bleedoutTimer = 0
    canRespawn = false
    justRespawned = true  -- Protection temporaire

    -- Retirer le state bag de mort
    LocalPlayer.state:set('isDead', false, true)

    local playerPed = PlayerPedId()

    -- Se détacher si attaché
    DetachEntity(playerPed, true, true)

    -- Retirer l'invincibilité si elle était active
    SetEntityInvincible(playerPed, false)

    -- Arrêter le ragdoll
    ClearPedTasksImmediately(playerPed)
    SetPedCanRagdoll(playerPed, false)

    -- Réactiver TOUS les contrôles immédiatement
    EnableAllControlActions(0)

    -- Contrôles spécifiques
    EnableControlAction(0, 71, true)  -- VehicleAccelerate
    EnableControlAction(0, 72, true)  -- VehicleBrake
    EnableControlAction(0, 59, true)  -- VehicleMoveLeftRight
    EnableControlAction(0, 60, true)  -- VehicleMoveUpDown
    EnableControlAction(0, 75, true)  -- VehicleExit
    EnableControlAction(0, 76, true)  -- VehicleHandbrake
    EnableControlAction(0, 199, true) -- Pause Menu
    EnableControlAction(0, 200, true) -- Pause Menu Alternate

    -- S'assurer que le NUI n'a pas le focus
    SetNuiFocus(false, false)

    -- Fermer le NUI de mort
    SendNUIMessage({ action = 'hideDeathScreen' })
    SendNUIMessage({ action = 'hideReviveProgress' })

    -- Thread de sécurité pour maintenir les contrôles actifs
    CreateThread(function()
        for i = 1, 30 do  -- 3 secondes de protection
            Wait(100)
            if not isDead and justRespawned then
                EnableAllControlActions(0)
                EnableControlAction(0, 199, true)
                EnableControlAction(0, 200, true)
            end
        end
        SetPedCanRagdoll(PlayerPedId(), true)
        justRespawned = false
    end)
end

---Respawn le joueur à la zone safe choisie
function Redzone.Client.Death.RespawnAtSafeZone()
    if not isDead then return end
    if not canRespawn then
        Redzone.Client.Utils.NotifyError('Vous devez attendre la fin du timer!')
        return
    end

    Redzone.Shared.Debug('[DEATH] Respawn en zone safe...')

    -- PROTECTION: Empêcher le thread de mort de désactiver les contrôles
    justRespawned = true

    -- Notifier le serveur que la victime respawn (fermer le loot si en cours)
    TriggerServerEvent('redzone:loot:victimRespawned')

    -- Reset de tous les états AVANT tout
    isDead = false
    isBeingRevived = false
    isBeingCarried = false
    carrierPlayer = nil
    bleedoutTimer = 0
    canRespawn = false

    -- Retirer le state bag de mort
    LocalPlayer.state:set('isDead', false, true)

    local playerPed = PlayerPedId()

    -- Se détacher si on était porté
    DetachEntity(playerPed, true, true)

    -- Téléporter vers la zone safe choisie AVANT la résurrection
    local spawnPoint = chosenSpawnPoint or Config.SpawnPoints[1]
    local coords = spawnPoint and spawnPoint.coords or vector4(0, 0, 0, 0)

    -- Résurrection complète du joueur (réseau)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w, true, false)

    -- Attendre un frame pour que la résurrection prenne effet
    Wait(0)

    -- Récupérer le PED après résurrection (peut avoir changé)
    playerPed = PlayerPedId()

    -- Retirer l'invincibilité
    SetEntityInvincible(playerPed, false)

    -- Remettre la vie complète
    SetEntityHealth(playerPed, 200)
    SetPedArmour(playerPed, 0)

    -- Effacer tous les états de dégâts/mort
    ClearPedBloodDamage(playerPed)
    ClearEntityLastDamageEntity(playerPed)
    ResetPedVisibleDamage(playerPed)

    -- Arrêter le ragdoll et les animations
    ClearPedTasksImmediately(playerPed)
    SetPedCanRagdoll(playerPed, false)

    -- Réactiver TOUS les contrôles immédiatement
    EnableAllControlActions(0)

    -- Réactiver les contrôles de véhicule spécifiquement
    EnableControlAction(0, 71, true)  -- VehicleAccelerate
    EnableControlAction(0, 72, true)  -- VehicleBrake
    EnableControlAction(0, 59, true)  -- VehicleMoveLeftRight
    EnableControlAction(0, 60, true)  -- VehicleMoveUpDown
    EnableControlAction(0, 75, true)  -- VehicleExit
    EnableControlAction(0, 76, true)  -- VehicleHandbrake

    -- Réactiver le menu pause (Échap)
    EnableControlAction(0, 199, true) -- Pause Menu
    EnableControlAction(0, 200, true) -- Pause Menu Alternate

    -- S'assurer que le NUI n'a pas le focus
    SetNuiFocus(false, false)

    -- Fermer le NUI
    SendNUIMessage({
        action = 'hideDeathScreen',
    })

    -- Thread de sécurité pour s'assurer que les contrôles restent actifs
    CreateThread(function()
        for i = 1, 20 do
            Wait(100)
            if not isDead and justRespawned then
                EnableAllControlActions(0)
                EnableControlAction(0, 71, true)  -- VehicleAccelerate
                EnableControlAction(0, 72, true)  -- VehicleBrake
                EnableControlAction(0, 199, true) -- Pause Menu
                EnableControlAction(0, 200, true) -- Pause Menu Alternate
            end
        end
        -- Réactiver ragdoll après
        SetPedCanRagdoll(PlayerPedId(), true)
        -- Désactiver la protection après 2 secondes
        justRespawned = false
    end)

    -- Notification
    Redzone.Client.Utils.NotifyInfo(Config.Death.Messages.Respawning)

    -- Notifier le serveur
    TriggerServerEvent('redzone:death:playerRevived')

    Redzone.Shared.Debug('[DEATH] Joueur respawn en zone safe')
end

-- =====================================================
-- THREAD DE MORT (DÉTECTION)
-- =====================================================

---Démarre le thread de gestion de la mort
function Redzone.Client.Death.StartDeathThread()
    Redzone.Shared.Debug('[DEATH] Démarrage du thread de mort')

    -- Thread de détection de mort
    CreateThread(function()
        while true do
            local sleep = 500

            if IsInRedzone() then
                local playerPed = PlayerPedId()
                local playerHealth = GetEntityHealth(playerPed)
                local isActuallyDead = IsEntityDead(playerPed) or playerHealth <= 100

                -- Détecter la mort (sauf si on vient de respawn)
                if not isDead and not justRespawned and (IsEntityDead(playerPed) or IsPedDeadOrDying(playerPed, true)) then
                    -- Vérifier si le joueur est en zone safe
                    local inSafeZone = false
                    local success, result = pcall(function() return exports['redzone']:IsInSafeZone() end)
                    if success and result then inSafeZone = true end

                    if inSafeZone then
                        -- En zone safe: annuler la mort, ressusciter immédiatement
                        local coords = GetEntityCoords(playerPed)
                        local heading = GetEntityHeading(playerPed)
                        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
                        Wait(0)
                        playerPed = PlayerPedId()
                        SetEntityHealth(playerPed, 200)
                        SetEntityInvincible(playerPed, true)
                        ClearPedTasksImmediately(playerPed)
                        Redzone.Shared.Debug('[DEATH] Mort en zone safe annulée - Résurrection immédiate')
                    else
                        -- Vérifier d'abord si c'est un coéquipier qui nous a tué
                        local killerPed = GetPedSourceOfDeath(playerPed)
                        local shouldIgnoreDeath = false

                        if killerPed and DoesEntityExist(killerPed) and IsEntityAPed(killerPed) and IsPedAPlayer(killerPed) then
                            local killerPlayerId = NetworkGetPlayerIndexFromPed(killerPed)
                            if killerPlayerId and killerPlayerId ~= PlayerId() then
                                local killerServerId = GetPlayerServerId(killerPlayerId)
                                if IsKillerInMySquad(killerServerId) then
                                    -- Coéquipier = ignorer la mort et ressusciter
                                    shouldIgnoreDeath = true
                                    Redzone.Shared.Debug('[DEATH] Mort par coéquipier détectée dans thread - Ignorée')
                                    SetEntityHealth(playerPed, 200)
                                    ClearPedTasksImmediately(playerPed)
                                end
                            end
                        end

                        if not shouldIgnoreDeath then
                            Redzone.Client.Death.OnPlayerDeath()
                        end
                    end
                end

                -- Si mort (état script), gérer les contrôles
                if isDead and not justRespawned then
                    sleep = 0

                    -- Si le ped est mort nativement (ne devrait pas arriver car on résurrectionne), re-résurrectionner
                    if IsEntityDead(playerPed) then
                        local c = GetEntityCoords(playerPed)
                        local h = GetEntityHeading(playerPed)
                        NetworkResurrectLocalPlayer(c.x, c.y, c.z, h, true, false)
                        Wait(0)
                        playerPed = PlayerPedId()
                        SetEntityHealth(playerPed, 200)
                        SetEntityInvincible(playerPed, true)
                        SetPedCanRagdoll(playerPed, false)
                        -- Rejouer l'animation sleep
                        local animDict = 'timetable@tracy@sleep@'
                        RequestAnimDict(animDict)
                        local t = 50
                        while not HasAnimDictLoaded(animDict) and t > 0 do Wait(10) t = t - 1 end
                        if HasAnimDictLoaded(animDict) then
                            TaskPlayAnim(playerPed, animDict, 'idle_b', 8.0, -8.0, -1, 1, 0, false, false, false)
                        end
                    end

                    -- Garder au sol mais permettre de regarder autour
                    DisableAllControlActions(0)
                    EnableControlAction(0, 1, true)  -- LookLeftRight
                    EnableControlAction(0, 2, true)  -- LookUpDown
                end
            else
                -- Hors redzone, reset
                if isDead then
                    Redzone.Client.Death.Revive()
                end
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- THREAD D'INTERACTION (RÉANIMATION/TRANSPORT)
-- =====================================================

---Démarre le thread d'interaction avec les joueurs morts
function Redzone.Client.Death.StartInteractionThread()
    Redzone.Shared.Debug('[DEATH] Démarrage du thread d\'interaction')

    CreateThread(function()
        while true do
            local sleep = 500

            if IsInRedzone() and not isDead and not isReviving then
                sleep = 200

                -- Chercher un joueur mort proche
                nearestDeadPlayer, nearestDeadPlayerDist = GetNearestDeadPlayer()

                if nearestDeadPlayer and not isCarrying then
                    sleep = 0

                    -- Vérifier si le joueur mort est dans notre squad
                    local targetServerId = GetPlayerServerId(nearestDeadPlayer)
                    local isInMySquad = HasSquad() and IsTargetInMySquad(targetServerId)

                    if isInMySquad then
                        -- Coéquipier mort: afficher toutes les options (réanimer, porter, fouiller)
                        Redzone.Client.Utils.ShowHelpText(Config.Death.HelpTexts.ReviveCarryLoot)
                    else
                        -- Joueur hors squad: afficher porter et fouiller (pas de réanimation)
                        Redzone.Client.Utils.ShowHelpText('[G] Porter ~s~| [I] Fouiller')
                    end
                end

                -- Gestion du transport (si on porte quelqu'un)
                if isCarrying then
                    sleep = 0
                    -- Afficher l'aide pour lâcher
                    Redzone.Client.Utils.ShowHelpText(Config.Death.HelpTexts.DropCarry)
                end
            else
                nearestDeadPlayer = nil
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- SYSTÈME DE RÉANIMATION
-- =====================================================

---Commence à réanimer un joueur (appelé par keybind)
function Redzone.Client.Death.TryRevive()
    -- PREMIER CHECK: Bloquer si déjà en cours
    if isReviving then
        Redzone.Shared.Debug('[DEATH] TryRevive bloqué: déjà en cours de réanimation')
        return
    end

    -- Autres vérifications
    if isDead or isCarrying then return end

    -- Cooldown de 2 secondes pour éviter le spam
    local currentTime = GetGameTimer()
    if currentTime - lastReviveAttempt < 2000 then return end

    if not nearestDeadPlayer then return end
    if not IsInRedzone() then return end

    local targetPlayerId = nearestDeadPlayer
    local playerPed = PlayerPedId()
    local targetPed = GetPlayerPed(targetPlayerId)

    if not DoesEntityExist(targetPed) then return end

    -- VÉRIFICATION SQUAD: On ne peut réanimer que les membres de notre squad
    local targetServerId = GetPlayerServerId(targetPlayerId)

    -- Si on n'a pas de squad, on ne peut pas réanimer
    if not HasSquad() then
        Redzone.Client.Utils.NotifyError('Vous devez être dans une squad pour réanimer!')
        lastReviveAttempt = currentTime
        return
    end

    -- Si la cible n'est pas dans notre squad, refuser
    if not IsTargetInMySquad(targetServerId) then
        Redzone.Client.Utils.NotifyError('Ce joueur n\'est pas dans votre squad!')
        lastReviveAttempt = currentTime
        return
    end

    -- BLOQUER LES AUTRES APPELS - AVANT TOUT WAIT
    isReviving = true
    reviveTarget = targetPlayerId
    lastReviveAttempt = currentTime

    Redzone.Shared.Debug('[DEATH] Début réanimation du joueur: ', targetPlayerId)

    local targetServerId = GetPlayerServerId(targetPlayerId)

    -- Notifier le serveur qu'on commence la réanimation
    TriggerServerEvent('redzone:death:startRevive', targetServerId)

    -- Afficher la barre de progression NUI
    SendNUIMessage({
        action = 'showReviveProgress',
        duration = Config.Death.ReviveTime,
    })

    -- Animation de réanimation (charger en arrière-plan)
    CreateThread(function()
        local animDict = 'mini@cpr@char_a@cpr_str'
        local animName = 'cpr_pumpchest'

        RequestAnimDict(animDict)
        local timeout = 50 -- 500ms max pour charger l'anim
        while not HasAnimDictLoaded(animDict) and timeout > 0 do
            Wait(10)
            timeout = timeout - 1
        end

        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end)

    -- Thread de réanimation avec possibilité d'annuler avec ESPACE
    CreateThread(function()
        local reviveTimeMs = Config.Death.ReviveTime * 1000
        local startTime = GetGameTimer()
        local cancelCooldown = startTime + 500 -- Petit delai avant de pouvoir annuler
        local reviveCancelled = false

        -- Boucle d'attente avec détection de la touche ESPACE
        while GetGameTimer() - startTime < reviveTimeMs do
            Wait(0)

            -- Vérifier qu'on est toujours en train de réanimer
            if not isReviving or reviveTarget ~= targetPlayerId then
                Redzone.Shared.Debug('[DEATH] Réanimation avortée - état changé')
                return
            end

            -- Vérifier si le joueur est mort
            local checkPed = PlayerPedId()
            if isDead or IsEntityDead(checkPed) or IsPedDeadOrDying(checkPed, true) or IsPedFatallyInjured(checkPed) then
                reviveCancelled = true
                break
            end

            -- Vérifier si le joueur appuie sur ESPACE pour annuler (après le cooldown)
            if GetGameTimer() > cancelCooldown and IsControlJustPressed(0, 22) then -- 22 = ESPACE
                reviveCancelled = true
                break
            end
        end

        local myPed = PlayerPedId()
        ClearPedTasks(myPed)
        SendNUIMessage({ action = 'hideReviveProgress' })

        if reviveCancelled then
            -- Annulation par le joueur
            TriggerServerEvent('redzone:death:cancelRevive', targetServerId)
            Redzone.Client.Utils.Notify(Config.ScriptName, 'Réanimation annulée', Config.Notify.Types.Warning, 3000, false)
            Redzone.Shared.Debug('[DEATH] Réanimation annulée par le joueur')
        else
            -- Succès!
            TriggerServerEvent('redzone:death:finishRevive', targetServerId)
            Redzone.Client.Utils.NotifySuccess(Config.Death.Messages.RevivedPlayer)
            Redzone.Shared.Debug('[DEATH] Réanimation terminée avec succès après ', Config.Death.ReviveTime, ' secondes')
        end

        isReviving = false
        reviveTarget = nil
    end)
end

---Annule la réanimation en cours (ne devrait être appelé que par onResourceStop)
---@param reason string|nil Raison de l'annulation (pour debug)
function Redzone.Client.Death.CancelRevive(reason)
    if not isReviving then return end

    Redzone.Shared.Debug('[DEATH] CancelRevive appelé - Raison: ', reason or 'cleanup')

    -- Sauvegarder la cible avant de reset
    local targetToCancel = reviveTarget

    -- Reset immédiat pour éviter les appels multiples
    isReviving = false
    reviveTarget = nil

    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
    SendNUIMessage({ action = 'hideReviveProgress' })

    if targetToCancel then
        TriggerServerEvent('redzone:death:cancelRevive', GetPlayerServerId(targetToCancel))
    end
end

-- =====================================================
-- SYSTÈME DE TRANSPORT
-- =====================================================

---Toggle porter/lâcher un joueur (appelé par keybind)
function Redzone.Client.Death.ToggleCarry()
    if isDead or isReviving then return end
    if not IsInRedzone() then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end

    if isCarrying then
        -- Lâcher le joueur
        Redzone.Client.Death.StopCarrying()
    else
        -- Porter le joueur
        if nearestDeadPlayer then
            Redzone.Client.Death.StartCarrying(nearestDeadPlayer)
        end
    end
end

---Commence à porter un joueur
---@param targetPlayerId number ID du joueur à porter
function Redzone.Client.Death.StartCarrying(targetPlayerId)
    if isCarrying then return end

    local playerPed = PlayerPedId()
    local targetPed = GetPlayerPed(targetPlayerId)

    if not DoesEntityExist(targetPed) then return end

    isCarrying = true
    carriedPlayer = targetPlayerId

    -- Animation de port pour le porteur seulement
    local animDict = 'missfinale_c2mcs_1'
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    TaskPlayAnim(playerPed, animDict, 'fin_c2_mcs_1_camman', 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Notifier le serveur (le joueur porté s'attachera lui-même de son côté)
    TriggerServerEvent('redzone:death:startCarry', GetPlayerServerId(targetPlayerId))

    Redzone.Client.Utils.NotifyInfo('Vous portez le joueur')
    Redzone.Shared.Debug('[DEATH] Début transport du joueur: ', targetPlayerId)
end

---Arrête de porter un joueur
function Redzone.Client.Death.StopCarrying()
    if not isCarrying then return end

    local playerPed = PlayerPedId()

    -- Arrêter l'animation du porteur
    ClearPedTasks(playerPed)

    -- Notifier le serveur (le joueur porté se détachera lui-même)
    if carriedPlayer then
        TriggerServerEvent('redzone:death:stopCarry', GetPlayerServerId(carriedPlayer))
    end

    isCarrying = false
    carriedPlayer = nil

    Redzone.Client.Utils.NotifyInfo('Vous avez lâché le joueur')
    Redzone.Shared.Debug('[DEATH] Fin transport')
end

-- =====================================================
-- ÉVÉNEMENTS SERVEUR
-- =====================================================

---Événement: Être réanimé par un autre joueur
RegisterNetEvent('redzone:death:revived')
AddEventHandler('redzone:death:revived', function()
    Redzone.Client.Death.Revive()
end)

---Événement: Quelqu'un commence à nous réanimer
RegisterNetEvent('redzone:death:beingRevived')
AddEventHandler('redzone:death:beingRevived', function(reviverId)
    isBeingRevived = true
    SendNUIMessage({
        action = 'updateDeathScreen',
        message = 'Réanimation en cours...',
        beingRevived = true,
    })
end)

---Événement: Réanimation annulée
RegisterNetEvent('redzone:death:reviveCancelled')
AddEventHandler('redzone:death:reviveCancelled', function()
    isBeingRevived = false
    SendNUIMessage({
        action = 'updateDeathScreen',
        message = Config.Death.Messages.WaitingRevive,
        beingRevived = false,
    })
end)

---Événement: Force reset de l'état de mort (utilisé par squad et autres modules)
RegisterNetEvent('redzone:death:forceReset')
AddEventHandler('redzone:death:forceReset', function()
    Redzone.Shared.Debug('[DEATH] Force reset demandé via événement')
    Redzone.Client.Death.ForceResetState()
end)

---Événement: Être porté par un autre joueur
RegisterNetEvent('redzone:death:beingCarried')
AddEventHandler('redzone:death:beingCarried', function(carrierId)
    if not isDead then return end

    isBeingCarried = true
    carrierPlayer = carrierId

    local myPed = PlayerPedId()
    local carrierLocalId = GetPlayerFromServerId(carrierId)
    local carrierPed = GetPlayerPed(carrierLocalId)

    if not DoesEntityExist(carrierPed) then
        isBeingCarried = false
        return
    end

    Redzone.Shared.Debug('[DEATH] Je suis porté par: ', carrierId)

    -- Arrêter l'animation sleep et préparer pour l'attachement
    ClearPedTasks(myPed)
    SetPedCanRagdoll(myPed, false)

    -- Jouer l'animation dead pour que le joueur soit mou/allongé sur l'épaule
    local animDict = 'dead'
    local animName = 'dead_a'
    RequestAnimDict(animDict)
    local t = 50
    while not HasAnimDictLoaded(animDict) and t > 0 do Wait(10) t = t - 1 end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(myPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    -- S'attacher au porteur (sur l'épaule)
    AttachEntityToEntity(
        myPed,           -- entity1 (moi)
        carrierPed,      -- entity2 (porteur)
        11816,           -- bone index (SKEL_Spine3 - dos)
        0.27, 0.15, 0.63, -- offset x, y, z (sur l'épaule)
        0.0, 0.0, 0.0,  -- rotation
        false,           -- p9
        false,           -- useSoftPinning
        false,           -- collision
        false,           -- isPed
        2,               -- vertexIndex
        true             -- fixedRot
    )

    -- Thread pour désactiver les contrôles pendant le transport
    CreateThread(function()
        local timeout = 0
        local maxTimeout = 300 -- 30 secondes max
        while isBeingCarried and isDead and timeout < maxTimeout do
            Wait(100)
            timeout = timeout + 1
            DisableAllControlActions(0)
        end

        Redzone.Shared.Debug('[DEATH] Thread beingCarried terminé')
    end)
end)

---Événement: Être lâché
RegisterNetEvent('redzone:death:droppedCarry')
AddEventHandler('redzone:death:droppedCarry', function()
    Redzone.Shared.Debug('[DEATH] Je suis lâché')

    local myPed = PlayerPedId()

    -- Se détacher d'abord
    DetachEntity(myPed, true, true)

    isBeingCarried = false
    carrierPlayer = nil

    if isDead then
        -- Rejouer l'animation sleep
        SetPedCanRagdoll(myPed, false)
        local animDict = 'timetable@tracy@sleep@'
        RequestAnimDict(animDict)
        local timeout = 50
        while not HasAnimDictLoaded(animDict) and timeout > 0 do
            Wait(10)
            timeout = timeout - 1
        end
        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(myPed, animDict, 'idle_b', 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    else
        -- Pas mort, réactiver les contrôles
        EnableAllControlActions(0)
        EnableControlAction(0, 199, true)
        EnableControlAction(0, 200, true)
    end
end)

-- =====================================================
-- NUI CALLBACKS
-- =====================================================

---Callback: Demande de respawn (après timer)
RegisterNUICallback('requestRespawn', function(data, cb)
    Redzone.Client.Death.RespawnAtSafeZone()
    cb('ok')
end)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('IsPlayerDead', function()
    return isDead
end)

exports('CanRespawn', function()
    return canRespawn
end)

exports('RevivePlayer', function()
    Redzone.Client.Death.Revive()
end)

---Force le reset complet de l'état de mort (utilisé par d'autres modules comme squad)
exports('ForceResetDeathState', function()
    Redzone.Client.Death.ForceResetState()
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    local playerPed = PlayerPedId()

    if isDead then
        SetEntityInvincible(playerPed, false)
        SetEntityHealth(playerPed, 200)
    end

    if isCarrying then
        Redzone.Client.Death.StopCarrying()
    end

    if isReviving then
        Redzone.Client.Death.CancelRevive()
    end

    -- Reset tous les états
    isDead = false
    isBeingRevived = false
    isBeingCarried = false
    carrierPlayer = nil

    -- Détacher si attaché
    DetachEntity(playerPed, true, true)

    -- Réactiver tous les contrôles
    EnableAllControlActions(0)
    SetNuiFocus(false, false)

    SendNUIMessage({ action = 'hideDeathScreen' })
    SendNUIMessage({ action = 'hideReviveProgress' })
end)

-- =====================================================
-- THREAD DE SÉCURITÉ (RÉACTIVATION DES CONTRÔLES)
-- =====================================================

-- Thread de sécurité qui vérifie périodiquement que les contrôles sont actifs si le joueur n'est pas mort
CreateThread(function()
    while true do
        Wait(100) -- Vérifier toutes les 100ms (plus fréquent pour éviter les bugs)

        -- Ne rien faire si le joueur est dans l'état de mort script (isDead=true)
        -- Le joueur est techniquement vivant (ressuscité + invincible) mais en état de mort pour le script
        if not isDead then
            local playerPed = PlayerPedId()

            -- Réinitialiser les états si nécessaires
            if isBeingCarried then
                isBeingCarried = false
                carrierPlayer = nil
                DetachEntity(playerPed, true, true)
            end

            -- S'assurer que les contrôles importants fonctionnent
            EnableControlAction(0, 199, true) -- Pause Menu
            EnableControlAction(0, 200, true) -- Pause Menu Alternate
            EnableControlAction(0, 71, true)  -- VehicleAccelerate
            EnableControlAction(0, 72, true)  -- VehicleBrake
            EnableControlAction(0, 59, true)  -- VehicleMoveLeftRight
            EnableControlAction(0, 75, true)  -- VehicleExit

            -- Si on n'est pas mort et pas en train de justRespawned, réactiver tout
            if not justRespawned then
                EnableAllControlActions(0)
            end
        end
    end
end)

-- =====================================================
-- KEYMAPPING (Touches configurables dans les paramètres FiveM)
-- =====================================================

-- Touche E pour réanimer un joueur (appui simple)
RegisterKeyMapping('redzone_revive', 'Réanimer un joueur (Redzone)', 'keyboard', 'e')
RegisterCommand('redzone_revive', function()
    Redzone.Client.Death.TryRevive()
end, false)

-- Touche Backspace pour respawn en zone safe (après timer)
RegisterKeyMapping('redzone_respawn', 'Respawn en zone safe (Redzone)', 'keyboard', 'back')
RegisterCommand('redzone_respawn', function()
    if isDead and canRespawn then
        Redzone.Client.Death.RespawnAtSafeZone()
    end
end, false)

-- =====================================================
-- DETECTION DES TOUCHES (sans commandes chat)
-- =====================================================

CreateThread(function()
    while true do
        local sleep = 200

        if Redzone.Client.Teleport.IsInRedzone() then
            sleep = 0
            -- Touche G (INPUT_WEAPON_SPECIAL = 47) pour porter/lâcher
            if IsControlJustPressed(0, 47) then
                Redzone.Client.Death.ToggleCarry()
            end
        end

        Wait(sleep)
    end
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/DEATH] Module Death chargé')
