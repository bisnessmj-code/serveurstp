--[[
    =====================================================
    REDZONE LEAGUE - Gestion des Zones
    =====================================================
    Ce fichier gère les zones safe, les blips et
    les cercles de zone sur la minimap.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Zones = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Stockage des blips créés
local spawnBlips = {}
local zoneCircles = {}

-- État de la zone safe
local isInSafeZone = false
local currentSafeZone = nil

-- Protection de santé en zone safe
local savedHealthInSafeZone = 200
local savedArmorInSafeZone = 0

-- =====================================================
-- CONFIGURATION DES ZONES
-- =====================================================

-- Rayon des zones safe en mètres
local SAFE_ZONE_RADIUS = 40.0

-- =====================================================
-- GESTION DES BLIPS (visibles seulement dans le redzone)
-- =====================================================

---Crée les blips pour les points de spawn
function Redzone.Client.Zones.CreateBlips()
    -- Supprimer les anciens blips s'ils existent
    Redzone.Client.Zones.DeleteBlips()

    for _, spawn in ipairs(Config.SpawnPoints) do
        if spawn.blip and spawn.blip.enabled then
            local coords = Redzone.Shared.Vec4ToVec3(spawn.coords)

            -- Créer le blip de position
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, spawn.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, spawn.blip.scale)
            SetBlipColour(blip, spawn.blip.color)
            SetBlipAsShortRange(blip, false) -- Visible de loin dans le redzone

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(spawn.blip.name)
            EndTextCommandSetBlipName(blip)

            table.insert(spawnBlips, blip)

            -- Créer le cercle de zone (rayon de 40m)
            local radiusBlip = AddBlipForRadius(coords.x, coords.y, coords.z, SAFE_ZONE_RADIUS)
            SetBlipHighDetail(radiusBlip, true)
            SetBlipColour(radiusBlip, 1) -- Rouge
            SetBlipAlpha(radiusBlip, 128) -- Semi-transparent

            table.insert(zoneCircles, radiusBlip)

            Redzone.Shared.Debug('[ZONES] Blip et zone créés pour: ', spawn.name)
        end
    end
end

---Supprime tous les blips
function Redzone.Client.Zones.DeleteBlips()
    -- Supprimer les blips de position
    for _, blip in ipairs(spawnBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    spawnBlips = {}

    -- Supprimer les cercles de zone
    for _, blip in ipairs(zoneCircles) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    zoneCircles = {}

    Redzone.Shared.Debug('[ZONES] Tous les blips supprimés')
end

-- =====================================================
-- GESTION DES ZONES SAFE
-- =====================================================

---Vérifie si le joueur est dans une zone safe
---@return boolean inZone True si dans une zone safe
---@return table|nil zone La zone dans laquelle le joueur se trouve
function Redzone.Client.Zones.IsPlayerInSafeZone()
    local playerCoords = Redzone.Client.Utils.GetPlayerCoords()

    for _, spawn in ipairs(Config.SpawnPoints) do
        local spawnCoords = Redzone.Shared.Vec4ToVec3(spawn.coords)
        local distance = #(playerCoords - spawnCoords)

        if distance <= SAFE_ZONE_RADIUS then
            return true, spawn
        end
    end

    return false, nil
end

---Désarme le joueur (retire l'arme actuelle)
function Redzone.Client.Zones.DisarmPlayer()
    local playerPed = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(playerPed)

    -- Si le joueur a une arme (pas les poings)
    if currentWeapon ~= GetHashKey('WEAPON_UNARMED') then
        SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
        Redzone.Shared.Debug('[ZONES] Joueur désarmé')
    end
end

---Active la protection de zone safe (invincibilité)
---@param enabled boolean Activer ou désactiver
function Redzone.Client.Zones.SetSafeZoneProtection(enabled)
    local playerPed = PlayerPedId()

    if enabled then
        -- Sauvegarder la santé/armure actuelle
        local currentHealth = GetEntityHealth(playerPed)
        local currentArmor = GetPedArmour(playerPed)
        if currentHealth > 100 then
            savedHealthInSafeZone = currentHealth
        else
            savedHealthInSafeZone = 200
        end
        savedArmorInSafeZone = currentArmor

        -- Invincibilité locale
        SetEntityInvincible(playerPed, true)
        -- Empêcher le joueur de viser/tirer
        SetPlayerCanDoDriveBy(PlayerId(), false)
        -- Désactiver les dégâts de toutes sources
        SetEntityCanBeDamaged(playerPed, false)
        SetEntityProofs(playerPed, true, true, true, true, true, true, true, true)
    else
        -- Retirer l'invincibilité
        SetEntityInvincible(playerPed, false)
        -- Permettre de viser/tirer à nouveau
        SetPlayerCanDoDriveBy(PlayerId(), true)
        -- Réactiver les dégâts
        SetEntityCanBeDamaged(playerPed, true)
        SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)
    end
end

---Restaure la santé du joueur en zone safe (appelé en boucle)
local function RestoreHealthInSafeZone()
    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)
    local currentArmor = GetPedArmour(playerPed)

    -- Si la santé a baissé, la restaurer immédiatement
    if currentHealth < savedHealthInSafeZone then
        SetEntityHealth(playerPed, savedHealthInSafeZone)
    end

    -- Si l'armure a baissé, la restaurer
    if currentArmor < savedArmorInSafeZone then
        SetPedArmour(playerPed, savedArmorInSafeZone)
    end

    -- Effacer les dégâts visibles
    ClearEntityLastDamageEntity(playerPed)
end

-- =====================================================
-- THREAD DE SURVEILLANCE DES ZONES
-- =====================================================

---Démarre le thread de surveillance des zones safe
function Redzone.Client.Zones.StartZoneThread()
    Redzone.Shared.Debug('[ZONES] Démarrage du thread de surveillance des zones')

    CreateThread(function()
        while true do
            local sleep = 500 -- Vérification toutes les 500ms par défaut

            -- Vérifier seulement si le joueur est dans le redzone
            if Redzone.Client.Teleport.IsInRedzone() then
                sleep = 100 -- Vérification plus rapide dans le redzone

                -- STAMINA INFINI: Restaurer le stamina à 100% en permanence dans le redzone
                RestorePlayerStamina(PlayerId(), 1.0)

                local inZone, zone = Redzone.Client.Zones.IsPlayerInSafeZone()

                if inZone then
                    -- Joueur dans une zone safe
                    if not isInSafeZone then
                        -- Vient d'entrer dans la zone
                        isInSafeZone = true
                        currentSafeZone = zone
                        Redzone.Client.Zones.SetSafeZoneProtection(true)
                        Redzone.Client.Utils.NotifyInfo('Zone safe - Vous êtes protégé')
                        Redzone.Shared.Debug('[ZONES] Joueur entré dans zone safe: ', zone.name)
                    end

                    -- PROTECTION CONTINUE: Restaurer la santé si elle baisse (protection contre dégâts réseau)
                    RestoreHealthInSafeZone()

                    -- Maintenir l'invincibilité active (au cas où elle serait désactivée)
                    local playerPed = PlayerPedId()
                    SetEntityInvincible(playerPed, true)
                    SetEntityCanBeDamaged(playerPed, false)

                    -- Désarmer le joueur en continu dans la zone safe
                    Redzone.Client.Zones.DisarmPlayer()

                    -- Bloquer le tir
                    DisablePlayerFiring(PlayerId(), true)
                    DisableControlAction(0, 24, true)  -- Attack
                    DisableControlAction(0, 25, true)  -- Aim
                    DisableControlAction(0, 140, true) -- Melee Attack Light
                    DisableControlAction(0, 141, true) -- Melee Attack Heavy
                    DisableControlAction(0, 142, true) -- Melee Attack Alternate
                    DisableControlAction(0, 143, true) -- Melee Block

                    sleep = 0 -- Vérification chaque frame dans la zone safe
                else
                    -- Joueur hors zone safe
                    if isInSafeZone then
                        -- Vient de sortir de la zone
                        isInSafeZone = false
                        currentSafeZone = nil
                        Redzone.Client.Zones.SetSafeZoneProtection(false)
                        Redzone.Client.Utils.NotifyWarning('Vous quittez la zone safe!')
                        Redzone.Shared.Debug('[ZONES] Joueur sorti de la zone safe')
                    end
                end
            else
                -- Joueur hors du redzone, s'assurer que la protection est désactivée
                if isInSafeZone then
                    isInSafeZone = false
                    currentSafeZone = nil
                    Redzone.Client.Zones.SetSafeZoneProtection(false)
                end
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur entre dans le redzone
function Redzone.Client.Zones.OnEnterRedzone()
    Redzone.Shared.Debug('[ZONES] Joueur entré dans le redzone - Création des blips')
    Redzone.Client.Zones.CreateBlips()

    -- Créer les PEDs coffre
    Redzone.Client.Stash.OnEnterRedzone()

    -- Créer les PEDs véhicule
    Redzone.Client.Vehicle.OnEnterRedzone()

    -- Créer les PEDs shop armes
    Redzone.Client.Shop.OnEnterRedzone()

    -- Créer les PEDs de sortie
    Redzone.Client.ExitPed.OnEnterRedzone()

    -- Créer le blip de blanchiment
    Redzone.Client.Laundering.OnEnterRedzone()

    -- Créer la zone de combat dynamique (vérifier si le module est chargé)
    if Redzone.Client.CombatZone and Redzone.Client.CombatZone.OnEnterRedzone then
        Redzone.Client.CombatZone.OnEnterRedzone()
    end

    -- Créer la zone CAL50 dynamique (vérifier si le module est chargé)
    if Redzone.Client.Cal50Zone and Redzone.Client.Cal50Zone.OnEnterRedzone then
        Redzone.Client.Cal50Zone.OnEnterRedzone()
    end

    -- Créer le système de weed farm (vérifier si le module est chargé)
    if Redzone.Client.WeedFarm and Redzone.Client.WeedFarm.OnEnterRedzone then
        Redzone.Client.WeedFarm.OnEnterRedzone()
    end
end

---Appelé quand le joueur quitte le redzone
function Redzone.Client.Zones.OnLeaveRedzone()
    Redzone.Shared.Debug('[ZONES] Joueur sorti du redzone - Suppression des blips')
    Redzone.Client.Zones.DeleteBlips()

    -- Supprimer les PEDs coffre
    Redzone.Client.Stash.OnLeaveRedzone()

    -- Supprimer les PEDs véhicule
    Redzone.Client.Vehicle.OnLeaveRedzone()

    -- Supprimer les PEDs shop armes
    Redzone.Client.Shop.OnLeaveRedzone()

    -- Supprimer les PEDs de sortie
    Redzone.Client.ExitPed.OnLeaveRedzone()

    -- Supprimer le blip de blanchiment
    Redzone.Client.Laundering.OnLeaveRedzone()

    -- Quitter le squad
    Redzone.Client.Squad.OnLeaveRedzone()

    -- Supprimer la zone de combat dynamique (vérifier si le module est chargé)
    if Redzone.Client.CombatZone and Redzone.Client.CombatZone.OnLeaveRedzone then
        Redzone.Client.CombatZone.OnLeaveRedzone()
    end

    -- Supprimer la zone CAL50 dynamique (vérifier si le module est chargé)
    if Redzone.Client.Cal50Zone and Redzone.Client.Cal50Zone.OnLeaveRedzone then
        Redzone.Client.Cal50Zone.OnLeaveRedzone()
    end

    -- Supprimer le système de weed farm (vérifier si le module est chargé)
    if Redzone.Client.WeedFarm and Redzone.Client.WeedFarm.OnLeaveRedzone then
        Redzone.Client.WeedFarm.OnLeaveRedzone()
    end

    -- S'assurer que la protection est retirée
    if isInSafeZone then
        isInSafeZone = false
        currentSafeZone = nil
        Redzone.Client.Zones.SetSafeZoneProtection(false)
    end
end

-- =====================================================
-- EXPORTS
-- =====================================================

-- Export pour vérifier si le joueur est dans une zone safe
exports('IsInSafeZone', function()
    return isInSafeZone
end)

-- Export pour obtenir la zone safe actuelle
exports('GetCurrentSafeZone', function()
    return currentSafeZone
end)

-- =====================================================
-- PROTECTION CONTRE LES DÉGÂTS RÉSEAU EN ZONE SAFE
-- =====================================================

-- Intercepter les événements de dégâts réseau
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local victimDied = args[4] == 1

        local myPed = PlayerPedId()

        -- Si on est la victime ET en zone safe
        if victim == myPed and isInSafeZone then
            -- Restaurer immédiatement la santé
            SetEntityHealth(myPed, savedHealthInSafeZone)
            SetPedArmour(myPed, savedArmorInSafeZone)
            ClearEntityLastDamageEntity(myPed)

            -- Si on était censé mourir, annuler
            if victimDied then
                -- Résurrection immédiate si besoin
                if IsEntityDead(myPed) or GetEntityHealth(myPed) <= 100 then
                    local coords = GetEntityCoords(myPed)
                    local heading = GetEntityHeading(myPed)
                    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
                    Wait(0)
                    myPed = PlayerPedId()
                    SetEntityHealth(myPed, savedHealthInSafeZone)
                    SetPedArmour(myPed, savedArmorInSafeZone)
                end
            end

            Redzone.Shared.Debug('[ZONES] Dégâts annulés en zone safe')
        end
    end
end)

-- Thread de protection de santé en zone safe (backup)
CreateThread(function()
    while true do
        Wait(50) -- Vérification très fréquente

        if isInSafeZone then
            local playerPed = PlayerPedId()
            local currentHealth = GetEntityHealth(playerPed)

            -- Si la santé a baissé, restaurer immédiatement
            if currentHealth < savedHealthInSafeZone and currentHealth > 0 then
                SetEntityHealth(playerPed, savedHealthInSafeZone)
                SetPedArmour(playerPed, savedArmorInSafeZone)
            end

            -- Si le joueur est mort en zone safe (ne devrait pas arriver)
            if IsEntityDead(playerPed) or currentHealth <= 100 then
                local coords = GetEntityCoords(playerPed)
                local heading = GetEntityHeading(playerPed)
                NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
                Wait(0)
                playerPed = PlayerPedId()
                SetEntityHealth(playerPed, savedHealthInSafeZone)
                SetPedArmour(playerPed, savedArmorInSafeZone)
                SetEntityInvincible(playerPed, true)
                Redzone.Shared.Debug('[ZONES] Résurrection forcée en zone safe')
            end
        end
    end
end)

-- =====================================================
-- SYSTÈME DE STAMINA INFINI
-- =====================================================

---Thread pour maintenir le stamina à 100% dans le redzone
CreateThread(function()
    while true do
        if Redzone.Client.Teleport.IsInRedzone() then
            -- Restaurer le stamina à 100% à chaque frame
            RestorePlayerStamina(PlayerId(), 1.0)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

Redzone.Shared.Debug('[ZONES] Système de stamina infini activé')

-- =====================================================
-- SYSTÈME DE FARM AFK EN ZONE SAFE
-- =====================================================

-- Variable pour tracker le temps en zone safe
local farmStartTime = 0
local lastFarmReward = 0
local farmNotified = false

---Démarre le thread de farm AFK en zone safe
function Redzone.Client.Zones.StartSafeZoneFarmThread()
    if not Config.SafeZoneFarm or not Config.SafeZoneFarm.Enabled then
        Redzone.Shared.Debug('[ZONES] Système de farm AFK désactivé')
        return
    end

    Redzone.Shared.Debug('[ZONES] Démarrage du système de farm AFK')

    CreateThread(function()
        while true do
            local sleep = 1000 -- Vérifier toutes les secondes

            -- Vérifier si le joueur est dans le redzone ET dans une zone safe
            if Redzone.Client.Teleport.IsInRedzone() and isInSafeZone then
                local currentTime = GetGameTimer()

                -- Initialiser le temps de départ si pas encore fait
                if farmStartTime == 0 then
                    farmStartTime = currentTime
                    lastFarmReward = currentTime
                    farmNotified = false
                end

                -- Notifier une seule fois que le farm est actif
                if not farmNotified then
                    farmNotified = true
                    if Config.SafeZoneFarm.Messages.Started then
                        Redzone.Client.Utils.NotifyInfo(Config.SafeZoneFarm.Messages.Started)
                    end
                end

                -- Vérifier si l'intervalle est écoulé
                local intervalMs = Config.SafeZoneFarm.Interval * 1000
                if currentTime - lastFarmReward >= intervalMs then
                    -- Demander au serveur de donner la récompense
                    TriggerServerEvent('redzone:safezone:farmReward')
                    lastFarmReward = currentTime
                    Redzone.Shared.Debug('[ZONES] Récompense de farm demandée')
                end
            else
                -- Réinitialiser quand le joueur quitte la zone safe
                if farmStartTime ~= 0 then
                    farmStartTime = 0
                    lastFarmReward = 0
                    farmNotified = false
                    Redzone.Shared.Debug('[ZONES] Farm AFK arrêté - joueur hors zone safe')
                end
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- NETTOYAGE
-- =====================================================

---Événement: Arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Supprimer tous les blips
    Redzone.Client.Zones.DeleteBlips()

    -- Retirer la protection
    Redzone.Client.Zones.SetSafeZoneProtection(false)

    Redzone.Shared.Debug('[ZONES] Nettoyage des zones effectué')
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

-- Démarrer le thread de farm AFK au chargement
CreateThread(function()
    Wait(2000) -- Attendre que les autres modules soient chargés
    Redzone.Client.Zones.StartSafeZoneFarmThread()
end)

Redzone.Shared.Debug('[CLIENT/ZONES] Module Zones chargé')
