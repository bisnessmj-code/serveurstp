--[[
    =====================================================
    REDZONE LEAGUE - Systeme de Loot
    =====================================================
    Ce fichier gere le systeme de fouille des joueurs morts.
    Permet de looter l'inventaire des victimes via qs-inventory.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Loot = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Etat du loot
local isLooting = false
local lootTarget = nil
local lootStartPos = nil
local lastLootAttempt = 0 -- Cooldown pour eviter spam
local waitingForServerResponse = false -- Pour le timeout de securite

-- Joueur mort le plus proche (pour loot)
local nearestLootablePlayer = nil
local nearestLootablePlayerDist = 999

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Verifie si le joueur est dans le redzone
---@return boolean
local function IsInRedzone()
    return Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone() or false
end

---Verifie si le joueur local est mort
---@return boolean
local function IsPlayerDead()
    local success, result = pcall(function()
        return exports['redzone']:IsPlayerDead()
    end)
    if success and result then return true end
    -- Fallback: vérifier le state bag local
    return LocalPlayer.state.isDead == true
end

---Obtient le joueur mort le plus proche (pour loot)
---@return number|nil playerId
---@return number distance
local function GetNearestLootablePlayer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = nil
    local closestDist = Config.Loot.InteractDistance

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(playerCoords - targetCoords)

                if dist <= closestDist then
                    -- Verifier si le joueur est mort via state bag (synchronise reseau)
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
-- SYSTEME DE LOOT
-- =====================================================

---Commence a fouiller un joueur (appele par keybind)
function Redzone.Client.Loot.TryLoot()
    -- PREMIER CHECK: Bloquer si deja en cours
    if isLooting then
        Redzone.Shared.Debug('[LOOT] TryLoot bloque: deja en cours de fouille')
        return
    end

    -- Verifier qu'on n'est pas mort
    if IsPlayerDead() then return end

    -- Verifier qu'on n'est pas dans un vehicule
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end

    -- Cooldown de 2 secondes pour eviter le spam
    local currentTime = GetGameTimer()
    if currentTime - lastLootAttempt < 2000 then return end

    -- Verifier qu'on est dans le redzone
    if not IsInRedzone() then return end

    -- Verifier qu'il y a un joueur mort proche
    if not nearestLootablePlayer then return end

    local targetPlayerId = nearestLootablePlayer
    local playerPed = PlayerPedId()
    local targetPed = GetPlayerPed(targetPlayerId)

    if not DoesEntityExist(targetPed) then return end

    -- Obtenir les IDs serveur
    local targetServerId = GetPlayerServerId(targetPlayerId)

    -- BLOQUER LES AUTRES APPELS - AVANT TOUT WAIT
    isLooting = true
    lootTarget = targetPlayerId
    lootStartPos = GetEntityCoords(playerPed)
    lastLootAttempt = currentTime

    Redzone.Shared.Debug('[LOOT] Debut fouille du joueur: ', targetPlayerId)

    -- Demander au serveur si on peut looter (pas deja pris)
    waitingForServerResponse = true
    TriggerServerEvent('redzone:loot:requestStart', targetServerId)

    -- Timeout de securite: si le serveur ne repond pas dans 5 secondes, reset l'etat
    SetTimeout(5000, function()
        if waitingForServerResponse then
            Redzone.Shared.Debug('[LOOT] Timeout: serveur n\'a pas repondu, reset de l\'etat')
            waitingForServerResponse = false
            isLooting = false
            lootTarget = nil
            lootStartPos = nil
        end
    end)
end

---Callback serveur: Loot autorise
RegisterNetEvent('redzone:loot:startConfirmed')
AddEventHandler('redzone:loot:startConfirmed', function(targetServerId)
    waitingForServerResponse = false -- Serveur a repondu
    if not isLooting then return end

    Redzone.Shared.Debug('[LOOT] Loot confirme par le serveur pour: ', targetServerId)

    local playerPed = PlayerPedId()

    -- Afficher la barre de progression NUI
    SendNUIMessage({
        action = 'showLootProgress',
        duration = Config.Loot.LootTime,
    })

    -- Notification
    Redzone.Client.Utils.NotifyInfo(Config.Loot.Messages.LootStarted)

    -- Animation genou a terre (meme que bandage)
    CreateThread(function()
        local animDict = 'amb@medic@standing@kneel@base'
        local animName = 'base'

        RequestAnimDict(animDict)
        local timeout = 500 -- 5s max pour charger l'anim
        while not HasAnimDictLoaded(animDict) and timeout > 0 do
            Wait(10)
            timeout = timeout - 1
        end

        if HasAnimDictLoaded(animDict) and isLooting then
            -- Bloquer le joueur
            FreezeEntityPosition(playerPed, true)
            SetPlayerCanDoDriveBy(PlayerId(), false)
            TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end)

    -- Thread de verification: annuler si mouvement/distance/espace
    CreateThread(function()
        local startTime = GetGameTimer()
        local lootTimeMs = Config.Loot.LootTime * 1000
        local cancelCooldown = GetGameTimer() + 500 -- Petit delai avant de pouvoir annuler

        while isLooting do
            Wait(0)

            -- Afficher le texte "Appuyez sur ESPACE pour annuler"
            Redzone.Client.Utils.DrawText2D(0.5, 0.93, 0.45, 'Appuyez sur ESPACE pour annuler', 255, 255, 255, 255)

            -- Bloquer les controles pendant le loot
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 47, true)  -- Weapon
            DisableControlAction(0, 58, true)  -- Weapon
            DisableControlAction(0, 263, true) -- Melee
            DisableControlAction(0, 264, true) -- Melee
            DisableControlAction(0, 140, true) -- Melee
            DisableControlAction(0, 141, true) -- Melee
            DisableControlAction(0, 142, true) -- Melee
            DisableControlAction(0, 143, true) -- Melee

            -- Verifier si le joueur est mort (state bag + natives GTA)
            local checkPed = PlayerPedId()
            if IsPlayerDead() or IsEntityDead(checkPed) or IsPedDeadOrDying(checkPed, true) or IsPedFatallyInjured(checkPed) then
                Redzone.Client.Loot.CancelLoot('joueur_mort')
                return
            end

            -- Verifier si le joueur appuie sur ESPACE pour annuler (apres le cooldown)
            if GetGameTimer() > cancelCooldown and IsControlJustPressed(0, 22) then -- 22 = ESPACE
                Redzone.Client.Utils.Notify(Config.ScriptName, 'Fouille annulée', Config.Notify.Types.Warning, 3000, false)
                Redzone.Client.Loot.CancelLoot('annule_par_joueur')
                return
            end

            -- Verifier que lootStartPos existe (securite)
            if not lootStartPos then
                Redzone.Client.Loot.CancelLoot('etat_invalide')
                return
            end

            local playerPed = PlayerPedId()
            local currentPos = GetEntityCoords(playerPed)

            -- Verifier si le joueur a bouge (plus de 1m)
            if #(currentPos - lootStartPos) > 1.0 then
                Redzone.Client.Loot.CancelLoot('mouvement')
                return
            end

            -- Verifier si le joueur cible est toujours present et mort
            local targetLocalId = GetPlayerFromServerId(targetServerId)
            if targetLocalId == -1 then
                Redzone.Client.Loot.CancelLoot('cible_absente')
                return
            end

            local targetPed = GetPlayerPed(targetLocalId)
            if not DoesEntityExist(targetPed) then
                Redzone.Client.Loot.CancelLoot('cible_absente')
                return
            end

            -- Verifier la distance avec la cible
            local targetCoords = GetEntityCoords(targetPed)
            if #(currentPos - targetCoords) > Config.Loot.InteractDistance + 1.0 then
                Redzone.Client.Loot.CancelLoot('trop_loin')
                return
            end

            -- Verifier si le temps est ecoule
            local elapsed = GetGameTimer() - startTime
            if elapsed >= lootTimeMs then
                -- Succes!
                Redzone.Client.Loot.FinishLoot(targetServerId)
                return
            end
        end
    end)
end)

---Callback serveur: Loot refuse
RegisterNetEvent('redzone:loot:startDenied')
AddEventHandler('redzone:loot:startDenied', function(reason)
    waitingForServerResponse = false -- Serveur a repondu
    Redzone.Shared.Debug('[LOOT] Loot refuse: ', reason)

    -- Reset les etats
    isLooting = false
    lootTarget = nil
    lootStartPos = nil

    -- Notification
    if reason == 'already_looted' then
        Redzone.Client.Utils.NotifyError(Config.Loot.Messages.AlreadyBeingLooted)
    else
        Redzone.Client.Utils.NotifyError(Config.Loot.Messages.CannotLoot)
    end
end)

---Termine le loot avec succes
---@param targetServerId number ID serveur de la cible
function Redzone.Client.Loot.FinishLoot(targetServerId)
    if not isLooting then return end

    -- Bloquer si le joueur est mort
    local checkPed = PlayerPedId()
    if IsPlayerDead() or IsEntityDead(checkPed) or IsPedDeadOrDying(checkPed, true) or IsPedFatallyInjured(checkPed) then
        Redzone.Client.Loot.CancelLoot('joueur_mort')
        return
    end

    Redzone.Shared.Debug('[LOOT] Fouille terminee avec succes')

    local playerPed = PlayerPedId()

    -- Debloquer le joueur
    FreezeEntityPosition(playerPed, false)
    SetPlayerCanDoDriveBy(PlayerId(), true)

    -- Arreter l'animation
    ClearPedTasks(playerPed)

    -- Cacher le cercle de progression
    SendNUIMessage({ action = 'hideLootProgress' })

    -- Notifier le serveur pour ouvrir l'inventaire
    TriggerServerEvent('redzone:loot:finish', targetServerId)

    -- Notification
    Redzone.Client.Utils.NotifySuccess(Config.Loot.Messages.LootComplete)

    -- Reset les etats
    isLooting = false
    lootTarget = nil
    lootStartPos = nil
end

---Annule le loot en cours
---@param reason string|nil Raison de l'annulation (pour debug)
function Redzone.Client.Loot.CancelLoot(reason)
    if not isLooting then return end

    Redzone.Shared.Debug('[LOOT] CancelLoot appele - Raison: ', reason or 'unknown')

    -- Sauvegarder la cible avant de reset
    local targetToCancel = lootTarget

    -- Reset immediat pour eviter les appels multiples
    isLooting = false
    lootTarget = nil
    lootStartPos = nil

    local playerPed = PlayerPedId()

    -- Debloquer le joueur
    FreezeEntityPosition(playerPed, false)
    SetPlayerCanDoDriveBy(PlayerId(), true)

    ClearPedTasks(playerPed)
    SendNUIMessage({ action = 'hideLootProgress' })

    -- Notifier le serveur
    if targetToCancel then
        local targetServerId = GetPlayerServerId(targetToCancel)
        TriggerServerEvent('redzone:loot:cancel', targetServerId)
    end

    -- Notification
    Redzone.Client.Utils.NotifyWarning(Config.Loot.Messages.LootCancelled)
end

-- =====================================================
-- THREAD D'INTERACTION (DETECTION DES JOUEURS MORTS)
-- =====================================================

---Demarre le thread d'interaction pour le loot
function Redzone.Client.Loot.StartInteractionThread()
    Redzone.Shared.Debug('[LOOT] Demarrage du thread d\'interaction loot')

    CreateThread(function()
        while true do
            local sleep = 500

            if IsInRedzone() and not IsPlayerDead() and not isLooting then
                sleep = 200

                -- Chercher un joueur mort proche
                nearestLootablePlayer, nearestLootablePlayerDist = GetNearestLootablePlayer()

                if nearestLootablePlayer then
                    sleep = 0
                    -- Le texte d'aide est affiche par death.lua (integre avec revive/carry)
                    -- On ne fait que tracker le joueur mort le plus proche ici
                end
            else
                nearestLootablePlayer = nil
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- EVENEMENTS
-- =====================================================

---Evenement: Inventaire ouvert par le serveur
RegisterNetEvent('redzone:loot:openInventory')
AddEventHandler('redzone:loot:openInventory', function(targetServerId)
    Redzone.Shared.Debug('[LOOT] Ouverture de l\'inventaire de: ', targetServerId)
    -- L'inventaire est ouvert cote serveur via qs-inventory
end)

---Evenement: Fermeture forcee du loot (victime a respawn)
RegisterNetEvent('redzone:loot:forceClose')
AddEventHandler('redzone:loot:forceClose', function()
    Redzone.Shared.Debug('[LOOT] Fermeture forcee - la victime a respawn')

    local playerPed = PlayerPedId()

    -- Debloquer le joueur
    FreezeEntityPosition(playerPed, false)
    SetPlayerCanDoDriveBy(PlayerId(), true)
    ClearPedTasks(playerPed)

    -- Reset les etats
    isLooting = false
    lootTarget = nil
    lootStartPos = nil

    -- Fermer l'inventaire qs-inventory via les events corrects (prefix = 'inventory')
    TriggerEvent('inventory:client:forceCloseInventory')
    TriggerEvent('inventory:client:closeinv')

    -- Aussi desactiver le focus NUI au cas ou
    SetNuiFocus(false, false)

    -- Notification
    Redzone.Client.Utils.NotifyWarning('Le joueur a respawn - fouille annulee')
end)

-- =====================================================
-- KEYMAPPING TOUCHE I (Fouiller un joueur)
-- =====================================================

-- Touche I pour fouiller un joueur mort (configurable dans les parametres FiveM)
RegisterKeyMapping('redzone_loot', 'Fouiller un joueur (Redzone)', 'keyboard', 'i')
RegisterCommand('redzone_loot', function()
    if Redzone.Client.Teleport.IsInRedzone() then
        Redzone.Client.Loot.TryLoot()
    end
end, false)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if isLooting then
        Redzone.Client.Loot.CancelLoot('resource_stop')
    end

    SendNUIMessage({ action = 'hideLootProgress' })
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

CreateThread(function()
    -- Attendre que les autres modules soient charges
    Wait(1000)
    Redzone.Client.Loot.StartInteractionThread()
end)

Redzone.Shared.Debug('[CLIENT/LOOT] Module Loot charge')
