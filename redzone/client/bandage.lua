--[[
    =====================================================
    REDZONE LEAGUE - Systeme de Bandage
    =====================================================
    Ce fichier gere l'utilisation des bandages pour
    restaurer la vie du joueur.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Bandage = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Configuration du bandage
local BANDAGE_DURATION = 8 -- Duree en secondes
local BANDAGE_ITEM = 'bandage' -- Nom de l'item dans l'inventaire

-- Etat du bandage
local isUsingBandage = false

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Verifie si le joueur peut utiliser un bandage
---@return boolean canUse True si le joueur peut utiliser un bandage
local function CanUseBandage()
    local playerPed = PlayerPedId()

    -- Ne peut pas utiliser si deja en train d'utiliser
    if isUsingBandage then
        return false
    end

    -- Ne peut pas utiliser si mort
    if IsEntityDead(playerPed) then
        return false
    end

    -- Ne peut pas utiliser si dans un vehicule
    if IsPedInAnyVehicle(playerPed, false) then
        return false
    end

    -- Ne peut pas utiliser si la vie est deja au max
    local maxHealth = GetEntityMaxHealth(playerPed)
    local currentHealth = GetEntityHealth(playerPed)
    if currentHealth >= maxHealth then
        return false
    end

    return true
end

---Calcule la moitie de la vie maximale
---@return number halfHealth La moitie de la vie max
local function GetHalfMaxHealth()
    local playerPed = PlayerPedId()
    local maxHealth = GetEntityMaxHealth(playerPed)
    -- La vie minimum est 100 (0-100 = mort, 100-200 = vivant)
    local healthRange = maxHealth - 100
    local halfHealthToAdd = math.floor(healthRange / 2)
    return halfHealthToAdd
end

-- =====================================================
-- FONCTION PRINCIPALE D'UTILISATION
-- =====================================================

---Utilise un bandage
function Redzone.Client.Bandage.UseBandage()
    if not CanUseBandage() then
        -- Notification cote client
        TriggerEvent('brutal_notify:SendAlert', 'warning', 'Impossible d\'utiliser le bandage maintenant', 3000)
        return
    end

    isUsingBandage = true
    local playerPed = PlayerPedId()

    Redzone.Shared.Debug('[BANDAGE] Debut utilisation bandage')

    -- Afficher le cercle de progression
    SendNUIMessage({
        action = 'showBandageProgress',
        duration = BANDAGE_DURATION,
    })

    -- Animation genou a terre (medic)
    local animDict = 'amb@medic@standing@kneel@base'
    local animName = 'base'

    -- Charger l'animation
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    -- Bloquer les mouvements du joueur
    FreezeEntityPosition(playerPed, true)
    SetPlayerCanDoDriveBy(PlayerId(), false)

    -- Jouer l'animation - flag 1 = loop
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
        Redzone.Shared.Debug('[BANDAGE] Animation medic kneel chargee et lancee')
    else
        Redzone.Shared.Debug('[BANDAGE] Echec chargement animation')
    end

    -- Attendre la duree du bandage
    local startTime = GetGameTimer()
    local bandageCompleted = true
    local cancelCooldown = GetGameTimer() + 500 -- Petit delai avant de pouvoir annuler

    while GetGameTimer() - startTime < BANDAGE_DURATION * 1000 do
        Wait(0)

        -- Garder le joueur bloque
        FreezeEntityPosition(playerPed, true)
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

        -- Verifier si le joueur appuie sur ESPACE pour annuler (apres le cooldown)
        if GetGameTimer() > cancelCooldown and IsControlJustPressed(0, 22) then -- 22 = ESPACE
            bandageCompleted = false
            Redzone.Client.Utils.Notify(Config.ScriptName, 'Bandage annulé', Config.Notify.Types.Warning, 3000, false)
            break
        end

        -- Verifier si le joueur est toujours en vie et peut continuer
        if IsEntityDead(playerPed) then
            bandageCompleted = false
            Redzone.Client.Utils.Notify(Config.ScriptName, 'Bandage annulé - Vous êtes mort', Config.Notify.Types.Error, 3000, false)
            break
        end
    end

    -- Debloquer les mouvements du joueur
    FreezeEntityPosition(playerPed, false)
    SetPlayerCanDoDriveBy(PlayerId(), true)

    -- Cacher le cercle de progression
    SendNUIMessage({
        action = 'hideBandageProgress',
    })

    -- Arreter l'animation
    ClearPedTasks(playerPed)

    -- Si le bandage a ete complete avec succes
    if bandageCompleted then
        -- Demander au serveur de retirer l'item et donner la vie
        TriggerServerEvent('redzone:bandage:complete')
        Redzone.Shared.Debug('[BANDAGE] Bandage complete avec succes')
    else
        Redzone.Shared.Debug('[BANDAGE] Bandage annule')
    end

    isUsingBandage = false
end

---Annule l'utilisation du bandage en cours
function Redzone.Client.Bandage.CancelBandage()
    if isUsingBandage then
        isUsingBandage = false

        local playerPed = PlayerPedId()

        -- Debloquer les mouvements du joueur
        FreezeEntityPosition(playerPed, false)
        SetPlayerCanDoDriveBy(PlayerId(), true)

        -- Cacher le cercle de progression
        SendNUIMessage({
            action = 'hideBandageProgress',
        })

        -- Arreter l'animation
        ClearPedTasks(playerPed)

        Redzone.Shared.Debug('[BANDAGE] Bandage annule manuellement')
    end
end

-- =====================================================
-- EVENEMENTS
-- =====================================================

---Evenement: Utiliser un bandage (declenche par l'inventaire ou le serveur)
RegisterNetEvent('redzone:bandage:use')
AddEventHandler('redzone:bandage:use', function()
    Redzone.Client.Bandage.UseBandage()
end)

---Evenement: Appliquer la vie (recu du serveur apres validation)
RegisterNetEvent('redzone:bandage:applyHealth')
AddEventHandler('redzone:bandage:applyHealth', function(healthToAdd)
    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)
    local maxHealth = GetEntityMaxHealth(playerPed)
    local newHealth = math.min(maxHealth, currentHealth + healthToAdd)

    SetEntityHealth(playerPed, newHealth)

    Redzone.Shared.Debug('[BANDAGE] Vie ajoutee: +', healthToAdd, ' (nouvelle vie: ', newHealth, ')')
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/BANDAGE] Module Bandage charge')
