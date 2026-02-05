--[[
    =====================================================
    REDZONE LEAGUE - Système de Véhicule (PED)
    =====================================================
    Ce fichier gère les PEDs véhicule et l'interface
    de sélection de véhicule pour les joueurs.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Vehicle = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Stockage des PEDs véhicule créés
local vehiclePeds = {}

-- État d'interaction
local isNearVehiclePed = false
local currentVehiclePedData = nil

-- État du menu de sélection
local isMenuOpen = false

-- Véhicule actuel du joueur (un seul à la fois)
local currentVehicle = nil

-- =====================================================
-- VÉRIFICATION DES GROUPES (PERMISSIONS)
-- =====================================================

---Obtient le groupe ESX du joueur
---@return string group Le groupe du joueur ('user' par défaut)
local function GetPlayerGroup()
    local playerData = ESX.GetPlayerData()
    if playerData and playerData.group then
        return playerData.group
    end
    return 'user'
end

---Vérifie si le joueur a accès à un véhicule
---@param vehicle table Configuration du véhicule
---@return boolean hasAccess True si le joueur peut utiliser ce véhicule
local function CanAccessVehicle(vehicle)
    -- Pas de restriction = accessible à tous
    if not vehicle.groups then
        return true
    end

    local playerGroup = GetPlayerGroup()
    for _, group in ipairs(vehicle.groups) do
        if group == playerGroup then
            return true
        end
    end

    return false
end

---Filtre les véhicules accessibles au joueur
---@return table accessibleVehicles Liste des véhicules accessibles
local function GetAccessibleVehicles()
    local accessible = {}
    for _, vehicle in ipairs(Config.VehiclePeds.Vehicles) do
        if CanAccessVehicle(vehicle) then
            table.insert(accessible, vehicle)
        end
    end
    return accessible
end

-- =====================================================
-- CRÉATION DES PEDS VÉHICULE
-- =====================================================

---Crée un PED véhicule avec les paramètres spécifiés
---@param pedConfig table Configuration du PED
---@return number|nil pedHandle Le handle du PED créé ou nil si erreur
local function CreateVehiclePed(pedConfig)
    if not pedConfig or not pedConfig.Model or not pedConfig.Coords then
        Redzone.Shared.Debug('[VEHICLE/ERROR] Configuration invalide pour la création du PED véhicule')
        return nil
    end

    local modelHash = GetHashKey(pedConfig.Model)
    if not Redzone.Client.Utils.LoadModel(modelHash) then
        Redzone.Shared.Debug('[VEHICLE/ERROR] Impossible de charger le modèle: ', pedConfig.Model)
        return nil
    end

    local coords = Redzone.Shared.Vec4ToVec3(pedConfig.Coords)
    local heading = Redzone.Shared.GetHeadingFromVec4(pedConfig.Coords)

    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, heading, false, true)

    if DoesEntityExist(ped) then
        if pedConfig.Invincible then
            SetEntityInvincible(ped, true)
        end

        if pedConfig.Frozen then
            FreezeEntityPosition(ped, true)
        end

        if pedConfig.BlockEvents then
            SetBlockingOfNonTemporaryEvents(ped, true)
        end

        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        SetPedDiesWhenInjured(ped, false)

        if pedConfig.Scenario then
            TaskStartScenarioInPlace(ped, pedConfig.Scenario, 0, true)
        end

        Redzone.Client.Utils.UnloadModel(modelHash)
        Redzone.Shared.Debug('[VEHICLE] PED véhicule créé: ', pedConfig.name)

        return ped
    end

    Redzone.Shared.Debug('[VEHICLE/ERROR] Échec de la création du PED véhicule')
    return nil
end

---Supprime un PED véhicule
---@param ped number Le handle du PED à supprimer
local function DeleteVehiclePed(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
        Redzone.Shared.Debug('[VEHICLE] PED véhicule supprimé')
    end
end

-- =====================================================
-- INITIALISATION DES PEDS VÉHICULE
-- =====================================================

---Crée tous les PEDs véhicule configurés
function Redzone.Client.Vehicle.CreateAllPeds()
    Redzone.Client.Vehicle.DeleteAllPeds()

    for _, location in ipairs(Config.VehiclePeds.Locations) do
        local ped = CreateVehiclePed(location)
        if ped then
            vehiclePeds[location.id] = {
                ped = ped,
                config = location
            }
        end
    end

    Redzone.Shared.Debug('[VEHICLE] Tous les PEDs véhicule ont été créés')
end

---Supprime tous les PEDs véhicule
function Redzone.Client.Vehicle.DeleteAllPeds()
    for id, data in pairs(vehiclePeds) do
        DeleteVehiclePed(data.ped)
        vehiclePeds[id] = nil
    end
    Redzone.Shared.Debug('[VEHICLE] Tous les PEDs véhicule ont été supprimés')
end

-- =====================================================
-- GESTION DU VÉHICULE
-- =====================================================

---Supprime le véhicule actuel du joueur
local function DeleteCurrentVehicle()
    if currentVehicle and DoesEntityExist(currentVehicle) then
        DeleteEntity(currentVehicle)
        Redzone.Shared.Debug('[VEHICLE] Ancien véhicule supprimé')
    end
    currentVehicle = nil
end

---Vérifie si un véhicule existe déjà au point de spawn
---@param spawnPoint vector4 Point de spawn
---@return boolean hasVehicle True si un véhicule est présent
---@return number|nil existingVehicle Le véhicule existant ou nil
local function IsSpawnPointOccupied(spawnPoint)
    local coords = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehCoords)
            -- Si un véhicule est à moins de 3 mètres du point de spawn
            if distance < 3.0 then
                return true, vehicle
            end
        end
    end

    return false, nil
end

---Spawn un véhicule au point de spawn associé au PED
---@param vehicleConfig table Configuration du véhicule (model, name)
---@param spawnPoint vector4 Point de spawn du véhicule
local function SpawnVehicle(vehicleConfig, spawnPoint)
    -- Supprimer l'ancien véhicule du joueur
    DeleteCurrentVehicle()

    -- Vérifier si le point de spawn est occupé
    local isOccupied, existingVehicle = IsSpawnPointOccupied(spawnPoint)

    if isOccupied then
        -- Notifier le joueur et attendre ou utiliser un offset
        Redzone.Client.Utils.NotifyWarning('Place occupée, tentative de spawn...')

        -- Option 1: Essayer de supprimer le véhicule existant s'il est vide
        if existingVehicle and DoesEntityExist(existingVehicle) then
            local driver = GetPedInVehicleSeat(existingVehicle, -1)
            if not DoesEntityExist(driver) or not IsPedAPlayer(driver) then
                -- Véhicule vide ou sans joueur dedans, le supprimer
                DeleteEntity(existingVehicle)
                Wait(100)
                Redzone.Shared.Debug('[VEHICLE] Véhicule vide supprimé du point de spawn')
            end
        end
    end

    -- Charger le modèle du véhicule
    local modelHash = GetHashKey(vehicleConfig.model)
    if not Redzone.Client.Utils.LoadModel(modelHash) then
        Redzone.Client.Utils.NotifyError('Impossible de charger le véhicule: ' .. vehicleConfig.name)
        return
    end

    -- Créer le véhicule (true = networked, visible par tous les joueurs)
    local coords = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
    local heading = spawnPoint.w

    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, true)

    if DoesEntityExist(vehicle) then
        currentVehicle = vehicle

        -- S'assurer que le véhicule est bien synchronisé sur le réseau
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        SetNetworkIdCanMigrate(netId, true)
        SetEntityAsMissionEntity(vehicle, true, true)

        -- IMPORTANT: Ne PAS désactiver SetEntityCollision car ça fait tomber sous la map !
        -- On utilise uniquement SetEntityNoCollisionEntity pour les collisions entre véhicules

        -- Désactiver immédiatement les collisions avec les véhicules proches du spawn
        local nearbyVehicles = GetGamePool('CVehicle')
        for _, otherVeh in ipairs(nearbyVehicles) do
            if otherVeh ~= vehicle and DoesEntityExist(otherVeh) then
                local otherCoords = GetEntityCoords(otherVeh)
                local dist = #(coords - otherCoords)
                if dist < 8.0 then
                    SetEntityNoCollisionEntity(vehicle, otherVeh, true)
                    SetEntityNoCollisionEntity(otherVeh, vehicle, true)
                end
            end
        end

        -- Placer le joueur dans le véhicule
        local playerPed = PlayerPedId()
        TaskWarpPedIntoVehicle(playerPed, vehicle, -1)

        -- Thread pour maintenir l'anti-collision pendant le départ du spawn
        CreateThread(function()
            local spawnCoords = coords
            local startTime = GetGameTimer()

            -- Maintenir l'anti-collision pendant 3 secondes ou jusqu'à ce qu'on s'éloigne
            while GetGameTimer() - startTime < 3000 do
                if not DoesEntityExist(vehicle) then break end

                local vehCoords = GetEntityCoords(vehicle)
                local distFromSpawn = #(vehCoords - spawnCoords)

                -- Si le véhicule s'est éloigné de plus de 8 mètres, arrêter
                if distFromSpawn > 8.0 then
                    break
                end

                -- Continuer à désactiver les collisions avec les véhicules proches
                local vehicles = GetGamePool('CVehicle')
                for _, otherVeh in ipairs(vehicles) do
                    if otherVeh ~= vehicle and DoesEntityExist(otherVeh) then
                        local otherCoords = GetEntityCoords(otherVeh)
                        local dist = #(vehCoords - otherCoords)
                        if dist < 8.0 then
                            SetEntityNoCollisionEntity(vehicle, otherVeh, true)
                            SetEntityNoCollisionEntity(otherVeh, vehicle, true)
                        end
                    end
                end

                Wait(0)
            end

            Redzone.Shared.Debug('[VEHICLE] Anti-collision spawn terminé')
        end)

        -- Libérer le modèle
        Redzone.Client.Utils.UnloadModel(modelHash)

        Redzone.Shared.Debug('[VEHICLE] Véhicule spawné (networked): ', vehicleConfig.name)
        Redzone.Client.Utils.NotifySuccess('Véhicule ' .. vehicleConfig.name .. ' prêt !')
    else
        Redzone.Client.Utils.NotifyError('Erreur lors du spawn du véhicule')
        Redzone.Client.Utils.UnloadModel(modelHash)
    end
end

-- =====================================================
-- MENU DE SÉLECTION (Style RageUI)
-- =====================================================

-- Index de sélection actuel
local selectedIndex = 1

-- Dimensions et position du menu (haut-gauche, style RageUI)
local MENU = {
    x = 0.118,           -- Position X du centre du menu
    y = 0.070,             -- Position Y de départ (haut)
    width = 0.210,       -- Largeur du menu
    headerHeight = 0.038, -- Hauteur du header
    itemHeight = 0.034,  -- Hauteur de chaque item
    spacing = 0.0,       -- Espacement entre items
}

---Dessine un rectangle à l'écran
---@param x number Position X du centre 
---@param y number Position Y du centre
---@param w number Largeur
---@param h number Hauteur
---@param r number Rouge
---@param g number Vert
---@param b number Bleu
---@param a number Alpha
local function DrawMenuRect(x, y, w, h, r, g, b, a)
    DrawRect(x, y, w, h, r, g, b, a)
end

---Dessine un texte aligné à gauche dans le menu
---@param x number Position X de départ
---@param y number Position Y
---@param text string Texte à afficher
---@param scale number Échelle
---@param r number Rouge
---@param g number Vert
---@param b number Bleu
---@param a number Alpha
local function DrawMenuText(x, y, text, scale, r, g, b, a)
    SetTextFont(0)
    SetTextProportional(true)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropShadow()
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

---Dessine un texte centré dans le menu
---@param x number Position X centre
---@param y number Position Y
---@param text string Texte à afficher
---@param scale number Échelle
---@param r number Rouge
---@param g number Vert
---@param b number Bleu
---@param a number Alpha
local function DrawMenuTextCentered(x, y, text, scale, r, g, b, a)
    SetTextFont(1)
    SetTextProportional(true)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextCentre(true)
    SetTextDropShadow()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

---Affiche le menu de sélection de véhicule (style RageUI)
---@param pedData table Données du PED (contient config avec SpawnPoint)
local function ShowVehicleMenu(pedData)
    isMenuOpen = true
    selectedIndex = 1

    local vehicles = GetAccessibleVehicles()
    local itemCount = #vehicles

    if itemCount == 0 then
        Redzone.Client.Utils.NotifyError('Aucun véhicule disponible pour votre groupe.')
        isMenuOpen = false
        return
    end

    CreateThread(function()
        while isMenuOpen do
            Wait(0)

            local currentY = MENU.y + 0.015

            -- === HEADER (bandeau bleu) ===
            -- === HEADER (bandeau ROUGE) ===
            local headerY = currentY + MENU.headerHeight / 2
            -- Les paramètres sont : (x, y, largeur, hauteur, R, G, B, Alpha)
            -- On met R à 200, G à 0, B à 0 pour un beau rouge
            DrawMenuRect(MENU.x, headerY, MENU.width, MENU.headerHeight, 200, 0, 0, 240) 
            DrawMenuTextCentered(MENU.x, currentY + 0.005, 'VEHICULES', 0.45, 255, 255, 255, 255)
            currentY = currentY + MENU.headerHeight

            -- === ITEMS ===
            for i, vehicle in ipairs(vehicles) do
                local itemY = currentY + MENU.itemHeight / 2

                if i == selectedIndex then
                    -- Item sélectionné (fond blanc)
                    DrawMenuRect(MENU.x, itemY, MENU.width, MENU.itemHeight, 255, 255, 255, 240)
                    DrawMenuText(MENU.x - MENU.width / 2 + 0.008, currentY + 0.005, vehicle.name, 0.33, 0, 0, 0, 255)
                else
                    -- Item normal (fond noir semi-transparent)
                    DrawMenuRect(MENU.x, itemY, MENU.width, MENU.itemHeight, 0, 0, 0, 180)
                    DrawMenuText(MENU.x - MENU.width / 2 + 0.008, currentY + 0.005, vehicle.name, 0.33, 255, 255, 255, 255)
                end

                currentY = currentY + MENU.itemHeight + MENU.spacing
            end

            -- === FOOTER (compteur) ===
            local footerY = currentY + 0.012
            DrawMenuRect(MENU.x, footerY, MENU.width, 0.024, 0, 0, 0, 200)
            DrawMenuTextCentered(MENU.x, currentY + 0.002, tostring(selectedIndex) .. ' / ' .. tostring(itemCount), 0.30, 255, 255, 255, 200)

            -- === CONTRÔLES ===
            -- Désactiver les contrôles de jeu qui interfèrent
            DisableControlAction(0, 27, true)  -- Phone
            DisableControlAction(0, 172, true) -- Arrow Up (pour éviter l'action par défaut)
            DisableControlAction(0, 173, true) -- Arrow Down

            -- Flèche Haut
            if IsDisabledControlJustPressed(0, 172) then -- ARROW UP
                selectedIndex = selectedIndex - 1
                if selectedIndex < 1 then
                    selectedIndex = itemCount
                end
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            end

            -- Flèche Bas
            if IsDisabledControlJustPressed(0, 173) then -- ARROW DOWN
                selectedIndex = selectedIndex + 1
                if selectedIndex > itemCount then
                    selectedIndex = 1
                end
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            end

            -- Entrée pour valider
            if IsControlJustPressed(0, 191) then -- ENTER
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                isMenuOpen = false
                SpawnVehicle(vehicles[selectedIndex], pedData.config.SpawnPoint)
            end

            -- Backspace pour fermer
            if IsControlJustPressed(0, 177) then -- BACKSPACE
                PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                isMenuOpen = false
                Redzone.Shared.Debug('[VEHICLE] Menu fermé par le joueur')
            end
        end
    end)
end

-- =====================================================
-- INTERACTION AVEC LES PEDS VÉHICULE
-- =====================================================

---Vérifie si le joueur est proche d'un PED véhicule
---@return boolean isNear True si proche d'un PED véhicule
---@return table|nil pedData Les données du PED véhicule le plus proche
function Redzone.Client.Vehicle.IsPlayerNearVehiclePed()
    local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
    local closestDistance = Config.Interaction.InteractDistance
    local closestPed = nil

    for id, data in pairs(vehiclePeds) do
        if DoesEntityExist(data.ped) then
            local pedCoords = Redzone.Shared.Vec4ToVec3(data.config.Coords)
            local distance = #(playerCoords - pedCoords)

            if distance <= closestDistance then
                closestDistance = distance
                closestPed = data
            end
        end
    end

    return closestPed ~= nil, closestPed
end

-- =====================================================
-- THREAD D'INTERACTION
-- =====================================================

---Démarre le thread d'interaction avec les PEDs véhicule
function Redzone.Client.Vehicle.StartInteractionThread()
    Redzone.Shared.Debug('[VEHICLE] Démarrage du thread d\'interaction véhicule')

    CreateThread(function()
        while true do
            local sleep = 1000

            if Redzone.Client.Teleport.IsInRedzone() then
                sleep = 200

                -- Afficher le texte 3D [VEHICULE] au-dessus des PEDs à moins de 15m
                local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
                for _, data in pairs(vehiclePeds) do
                    if DoesEntityExist(data.ped) then
                        local pedCoords = GetEntityCoords(data.ped)
                        local dist = #(playerCoords - pedCoords)
                        if dist <= 15.0 then
                            sleep = 0
                            Redzone.Client.Utils.DrawText3D(vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.3), '[VEHICULE]', 0.45)
                        end
                    end
                end

                if not isMenuOpen then
                    local near, pedData = Redzone.Client.Vehicle.IsPlayerNearVehiclePed()

                    if near then
                        sleep = 0
                        isNearVehiclePed = true
                        currentVehiclePedData = pedData

                        Redzone.Client.Utils.ShowHelpText(Config.VehiclePeds.Settings.HelpText)

                        if Redzone.Client.Utils.IsKeyJustPressed(Config.Interaction.InteractKey) then
                            ShowVehicleMenu(pedData)
                        end
                    else
                        isNearVehiclePed = false
                        currentVehiclePedData = nil
                    end
                end
            else
                isNearVehiclePed = false
                currentVehiclePedData = nil
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur entre dans le redzone
function Redzone.Client.Vehicle.OnEnterRedzone()
    Redzone.Shared.Debug('[VEHICLE] Joueur entré dans le redzone - Création des PEDs véhicule')
    Redzone.Client.Vehicle.CreateAllPeds()
end

---Appelé quand le joueur quitte le redzone
function Redzone.Client.Vehicle.OnLeaveRedzone()
    Redzone.Shared.Debug('[VEHICLE] Joueur sorti du redzone - Suppression des PEDs véhicule')
    Redzone.Client.Vehicle.DeleteAllPeds()
    DeleteCurrentVehicle()
    isMenuOpen = false

    -- Restaurer le handling original si on est dans un véhicule
    if boostedVehicle and DoesEntityExist(boostedVehicle) then
        RestoreOriginalHandling(boostedVehicle)
    end
end

-- =====================================================
-- SYSTÈME ANTI CAR-KILL
-- =====================================================

-- Variable pour tracker si l'anti car-kill est actif
local antiCarKillActive = false

-- Variable pour tracker le véhicule avec handling modifié
local boostedVehicle = nil
local originalHandling = {}

---Obtient tous les véhicules proches conduits par d'autres joueurs
---@return table vehicles Liste des véhicules
local function GetNearbyPlayerVehicles()
    local vehicles = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerId = PlayerId()

    -- Parcourir tous les joueurs actifs
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= playerId then
            local targetPed = GetPlayerPed(player)
            if DoesEntityExist(targetPed) then
                -- Vérifier si le joueur est dans un véhicule
                if IsPedInAnyVehicle(targetPed, false) then
                    local vehicle = GetVehiclePedIsIn(targetPed, false)
                    if DoesEntityExist(vehicle) then
                        -- Vérifier la distance (optimisation)
                        local vehCoords = GetEntityCoords(vehicle)
                        local dist = #(playerCoords - vehCoords)
                        if dist < 50.0 then
                            table.insert(vehicles, vehicle)
                        end
                    end
                end
            end
        end
    end

    return vehicles
end

---Démarre le thread anti car-kill
function Redzone.Client.Vehicle.StartAntiCarKillThread()
    if not Config.VehiclePeds.Settings.AntiCarKill then
        Redzone.Shared.Debug('[VEHICLE] Anti Car-Kill désactivé dans la config')
        return
    end

    Redzone.Shared.Debug('[VEHICLE] Démarrage du système Anti Car-Kill')

    CreateThread(function()
        while true do
            local sleep = 500

            -- Seulement actif dans le redzone
            if Redzone.Client.Teleport.IsInRedzone() then
                local playerPed = PlayerPedId()

                -- Seulement si le joueur est à pied (pas dans un véhicule)
                if not IsPedInAnyVehicle(playerPed, false) then
                    sleep = 0 -- Besoin de vérifier chaque frame pour la collision

                    -- Obtenir TOUS les véhicules (occupés ou non)
                    local allVehicles = GetGamePool('CVehicle')

                    for _, vehicle in ipairs(allVehicles) do
                        if DoesEntityExist(vehicle) then
                            local vehCoords = GetEntityCoords(vehicle)
                            local dist = #(GetEntityCoords(playerPed) - vehCoords)
                            if dist < 50.0 then
                                -- Désactiver la collision entre le joueur et le véhicule
                                SetEntityNoCollisionEntity(playerPed, vehicle, false)
                                SetEntityNoCollisionEntity(vehicle, playerPed, false)
                            end
                        end
                    end

                    -- Empêcher le ragdoll au contact véhicule
                    SetPedCanBeKnockedOffVehicle(playerPed, 1)
                    SetPedConfigFlag(playerPed, 32, false) -- Ne pas ragdoll au contact véhicule

                    antiCarKillActive = true
                else
                    -- Le joueur est dans un véhicule, pas besoin de protection
                    sleep = 200
                    antiCarKillActive = false
                end
            else
                antiCarKillActive = false
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- SYSTÈME BOOST HANDLING REDZONE
-- =====================================================

-- Configuration du boost handling
local HANDLING_BOOST = {
    -- Puissance et vitesse (multiplicateurs pour le handling)
    fInitialDriveForce = 1.0,             -- Multiplicateur accélération
    fClutchChangeRateScaleUpShift = 1.0,  -- Multiplicateur passage de vitesses

    -- Adhérence et tenue de route
    fTractionCurveMax = 2.0,              -- Multiplicateur adhérence max
    fTractionCurveMin = 2.0,              -- Multiplicateur adhérence min
    fTractionCurveLateral = 1.5,          -- Multiplicateur traction latérale
    fLowSpeedTractionLossMult = 0.3,      -- Réduction patinage

    -- Stabilité et survie
    fBrakeForce = 2.5,                    -- Multiplicateur force de freinage
    fSuspensionForce = 2.0,               -- Multiplicateur suspension
    fAntiRollBarForce = 2.0,              -- Multiplicateur anti-roll bar
    fCollisionDamageMult = 0.1,           -- Multiplicateur dégâts collision (très réduit)
    fDeformationDamageMult = 0.1,         -- Multiplicateur dégâts déformation
    fEngineDamageMult = 0.1,              -- Multiplicateur dégâts moteur
}

-- Configuration vitesse (natives spéciales nécessaires)
local SPEED_BOOST = {
    topSpeedMultiplier = 0.5    ,             -- Multiplicateur vitesse max (ModifyVehicleTopSpeed)
    powerMultiplier = 5.0,               -- Boost de puissance (SetVehicleCheatPowerIncrease)
}

-- Liste des champs de handling à modifier
local HANDLING_FIELDS = {
    'fInitialDriveForce',
    'fClutchChangeRateScaleUpShift',
    'fTractionCurveMax',
    'fTractionCurveMin',
    'fTractionCurveLateral',
    'fLowSpeedTractionLossMult',
    'fBrakeForce',
    'fSuspensionForce',
    'fAntiRollBarForce',
    'fCollisionDamageMult',
    'fDeformationDamageMult',
    'fEngineDamageMult',
}

---Sauvegarde le handling original d'un véhicule
---@param vehicle number Handle du véhicule
local function SaveOriginalHandling(vehicle)
    if not DoesEntityExist(vehicle) then return end

    originalHandling = {}

    for _, field in ipairs(HANDLING_FIELDS) do
        local value = GetVehicleHandlingFloat(vehicle, 'CHandlingData', field)
        originalHandling[field] = value
        Redzone.Shared.Debug('[VEHICLE/HANDLING] Sauvegarde ', field, ' = ', value)
    end
end

---Applique le handling boosté à un véhicule
---@param vehicle number Handle du véhicule
local function ApplyBoostedHandling(vehicle)
    if not DoesEntityExist(vehicle) then return end

    -- Sauvegarder le handling original si pas déjà fait
    if not originalHandling or not originalHandling.fInitialDriveForce then
        SaveOriginalHandling(vehicle)
    end

    -- Appliquer les multiplicateurs de handling
    for field, multiplier in pairs(HANDLING_BOOST) do
        local originalValue = originalHandling[field]
        if originalValue then
            local newValue = originalValue * multiplier
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', field, newValue)
            Redzone.Shared.Debug('[VEHICLE/HANDLING] ', field, ': ', originalValue, ' -> ', newValue)
        end
    end

    -- =====================================================
    -- BOOST DE VITESSE (natives spéciales)
    -- =====================================================

    -- Augmente la vitesse max du véhicule (bypass la limite du jeu)
    -- Le multiplicateur s'applique à la vitesse max native du véhicule
    ModifyVehicleTopSpeed(vehicle, SPEED_BOOST.topSpeedMultiplier)
    Redzone.Shared.Debug('[VEHICLE/SPEED] TopSpeed multiplier: x', SPEED_BOOST.topSpeedMultiplier)

    -- Boost de puissance du moteur (accélération massive)
    SetVehicleCheatPowerIncrease(vehicle, SPEED_BOOST.powerMultiplier)
    Redzone.Shared.Debug('[VEHICLE/SPEED] Power boost: +', SPEED_BOOST.powerMultiplier)

    -- =====================================================
    -- BONUS SUPPLÉMENTAIRES
    -- =====================================================

    -- Désactiver les dégâts visuels
    SetVehicleCanBeVisiblyDamaged(vehicle, false)

    -- Rendre le véhicule plus résistant
    SetVehicleStrong(vehicle, true)
    SetVehicleHasStrongAxles(vehicle, true)

    -- Améliorer la traction
    SetVehicleOnGroundProperly(vehicle, true)

    -- Désactiver les pneus crevables
    SetVehicleTyresCanBurst(vehicle, false)

    -- Empêcher les fenêtres de casser
    SetVehicleCanBreak(vehicle, false)

    -- Turbo automatique
    ToggleVehicleMod(vehicle, 18, true) -- Turbo

    boostedVehicle = vehicle
    Redzone.Shared.Debug('[VEHICLE/HANDLING] Handling boosté appliqué au véhicule')
end

---Restaure le handling original d'un véhicule
---@param vehicle number Handle du véhicule
local function RestoreOriginalHandling(vehicle)
    if not DoesEntityExist(vehicle) then return end
    if not originalHandling or not originalHandling.fInitialDriveForce then return end

    -- Restaurer les valeurs originales de handling
    for field, originalValue in pairs(originalHandling) do
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', field, originalValue)
    end

    -- Restaurer la vitesse normale (multiplicateur 1.0 = normal)
    ModifyVehicleTopSpeed(vehicle, 1.0)

    -- Retirer le boost de puissance (0.0 = normal)
    SetVehicleCheatPowerIncrease(vehicle, 0.0)

    -- Restaurer les propriétés par défaut
    SetVehicleCanBeVisiblyDamaged(vehicle, true)
    SetVehicleTyresCanBurst(vehicle, true)
    SetVehicleCanBreak(vehicle, true)

    boostedVehicle = nil
    originalHandling = {}
    Redzone.Shared.Debug('[VEHICLE/HANDLING] Handling original restauré')
end

---Démarre le thread de gestion du handling boosté
function Redzone.Client.Vehicle.StartHandlingBoostThread()
    Redzone.Shared.Debug('[VEHICLE] Démarrage du système Handling Boost Redzone')

    CreateThread(function()
        while true do
            local sleep = 500

            local playerPed = PlayerPedId()
            local inRedzone = Redzone.Client.Teleport.IsInRedzone()

            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)

                if DoesEntityExist(vehicle) then
                    local driver = GetPedInVehicleSeat(vehicle, -1)

                    -- Seulement si le joueur est le conducteur
                    if driver == playerPed then
                        if inRedzone then
                            -- Dans le redzone: appliquer le boost
                            if boostedVehicle ~= vehicle then
                                -- Nouveau véhicule ou premier boost
                                if boostedVehicle and DoesEntityExist(boostedVehicle) then
                                    RestoreOriginalHandling(boostedVehicle)
                                end
                                ApplyBoostedHandling(vehicle)
                            end

                            -- Coller la voiture au sol avec une gravité augmentée
                            SetVehicleGravityAmount(vehicle, 35.0)

                            sleep = 200
                        else
                            -- Hors du redzone: restaurer si nécessaire
                            if boostedVehicle == vehicle then
                                RestoreOriginalHandling(vehicle)
                                SetVehicleGravityAmount(vehicle, 9.8) -- Gravité normale
                            end
                        end
                    end
                end
            else
                -- Joueur à pied: restaurer le handling si on avait un véhicule boosté
                if boostedVehicle and DoesEntityExist(boostedVehicle) then
                    RestoreOriginalHandling(boostedVehicle)
                    SetVehicleGravityAmount(boostedVehicle, 9.8) -- Gravité normale
                end
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- SYSTÈME DE DESCENTE INSTANTANÉE DU VÉHICULE
-- =====================================================

---Démarre le thread de descente instantanée du véhicule
---Permet de descendre du véhicule sans l'animation d'ouverture de portière
function Redzone.Client.Vehicle.StartInstantExitThread()
    Redzone.Shared.Debug('[VEHICLE] Démarrage du système de descente instantanée')

    CreateThread(function()
        while true do
            local sleep = 200

            -- Seulement actif dans le redzone
            if Redzone.Client.Teleport.IsInRedzone() then
                local playerPed = PlayerPedId()

                -- Vérifier si le joueur est dans un véhicule
                if IsPedInAnyVehicle(playerPed, false) then
                    sleep = 0 -- Besoin de vérifier chaque frame pour la touche

                    -- IMPORTANT: Désactiver le contrôle AVANT de vérifier s'il est pressé
                    -- Control 75 = INPUT_VEH_EXIT (F par défaut)
                    DisableControlAction(0, 75, true)

                    -- Utiliser IsDisabledControlJustPressed car le contrôle est désactivé
                    if IsDisabledControlJustPressed(0, 75) then
                        local vehicle = GetVehiclePedIsIn(playerPed, false)

                        if DoesEntityExist(vehicle) then
                            -- Obtenir la position de sortie (côté du joueur)
                            local vehicleCoords = GetEntityCoords(vehicle)
                            local playerSeat = -2 -- Valeur par défaut

                            -- Trouver dans quel siège est le joueur
                            for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
                                if GetPedInVehicleSeat(vehicle, seat) == playerPed then
                                    playerSeat = seat
                                    break
                                end
                            end

                            -- Calculer la position de sortie basée sur le côté du véhicule
                            local offset
                            if playerSeat == -1 or playerSeat == 1 then
                                -- Conducteur ou passager arrière gauche = sortir à gauche
                                offset = GetOffsetFromEntityInWorldCoords(vehicle, -2.0, 0.0, 0.0)
                            else
                                -- Passager avant ou passager arrière droit = sortir à droite
                                offset = GetOffsetFromEntityInWorldCoords(vehicle, 2.0, 0.0, 0.0)
                            end

                            -- Trouver le sol à cette position
                            local groundZ = vehicleCoords.z
                            local found, z = GetGroundZFor_3dCoord(offset.x, offset.y, offset.z + 2.0, false)
                            if found then
                                groundZ = z
                            end

                            -- Méthode directe: téléporter le joueur hors du véhicule instantanément
                            SetPedIntoVehicle(playerPed, vehicle, -2) -- -2 = éjecter du véhicule
                            SetEntityCoords(playerPed, offset.x, offset.y, groundZ + 0.5, false, false, false, false)

                            -- Annuler toute tâche en cours pour éviter les animations résiduelles
                            ClearPedTasksImmediately(playerPed)

                            Redzone.Shared.Debug('[VEHICLE] Descente instantanée effectuée')
                        end
                    end
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

    -- Restaurer le handling original si nécessaire
    if boostedVehicle and DoesEntityExist(boostedVehicle) then
        RestoreOriginalHandling(boostedVehicle)
    end

    Redzone.Client.Vehicle.DeleteAllPeds()
    DeleteCurrentVehicle()
    isMenuOpen = false

    Redzone.Shared.Debug('[VEHICLE] Nettoyage des PEDs véhicule effectué')
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

-- Démarrer les threads au chargement
CreateThread(function()
    Wait(2000) -- Attendre que les autres modules soient chargés
    Redzone.Client.Vehicle.StartAntiCarKillThread()
    Redzone.Client.Vehicle.StartHandlingBoostThread()
    Redzone.Client.Vehicle.StartInstantExitThread()
end)

Redzone.Shared.Debug('[CLIENT/VEHICLE] Module Véhicule chargé')
