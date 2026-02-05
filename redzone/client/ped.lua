--[[
    =====================================================
    REDZONE LEAGUE - Gestion des PEDs
    =====================================================
    Ce fichier gère la création et l'interaction
    avec les PEDs du script.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Ped = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Stockage des PEDs créés
local spawnedPeds = {}

-- Nombre de joueurs dans le redzone (synchronisé par le serveur)
local redzonePlayerCount = 0

-- Distance maximale pour afficher le texte 3D au-dessus du PED
local PLAYER_COUNT_DISPLAY_DISTANCE = 15.0

-- =====================================================
-- CRÉATION DES PEDS
-- =====================================================

---Crée un PED avec les paramètres spécifiés
---@param pedConfig table Configuration du PED
---@return number|nil pedHandle Le handle du PED créé ou nil si erreur
function Redzone.Client.Ped.Create(pedConfig)
    -- Validation de la configuration
    if not pedConfig or not pedConfig.Model or not pedConfig.Coords then
        Redzone.Shared.Debug('[PED/ERROR] Configuration invalide pour la création du PED')
        return nil
    end

    -- Chargement du modèle
    local modelHash = GetHashKey(pedConfig.Model)
    if not Redzone.Client.Utils.LoadModel(modelHash) then
        Redzone.Shared.Debug('[PED/ERROR] Impossible de charger le modèle: ', pedConfig.Model)
        return nil
    end

    -- Extraction des coordonnées
    local coords = Redzone.Shared.Vec4ToVec3(pedConfig.Coords)
    local heading = Redzone.Shared.GetHeadingFromVec4(pedConfig.Coords)

    -- Création du PED
    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, heading, false, true)

    -- Configuration du PED
    if DoesEntityExist(ped) then
        -- Rendre invincible si configuré
        if pedConfig.Invincible then
            SetEntityInvincible(ped, true)
        end

        -- Figer le PED si configuré
        if pedConfig.Frozen then
            FreezeEntityPosition(ped, true)
        end

        -- Bloquer les événements si configuré
        if pedConfig.BlockEvents then
            SetBlockingOfNonTemporaryEvents(ped, true)
        end

        -- Empêcher le PED de fuir
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        SetPedDiesWhenInjured(ped, false)

        -- Appliquer un scénario si configuré
        if pedConfig.Scenario then
            TaskStartScenarioInPlace(ped, pedConfig.Scenario, 0, true)
        end

        -- Libérer le modèle de la mémoire
        Redzone.Client.Utils.UnloadModel(modelHash)

        Redzone.Shared.Debug(Config.DebugMessages.PedSpawned, coords)

        return ped
    end

    Redzone.Shared.Debug('[PED/ERROR] Échec de la création du PED')
    return nil
end

---Supprime un PED
---@param ped number Le handle du PED à supprimer
function Redzone.Client.Ped.Delete(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
        Redzone.Shared.Debug('[PED] PED supprimé: ', ped)
    end
end

---Supprime tous les PEDs créés par le script
function Redzone.Client.Ped.DeleteAll()
    for id, ped in pairs(spawnedPeds) do
        Redzone.Client.Ped.Delete(ped)
        spawnedPeds[id] = nil
    end
    Redzone.Shared.Debug('[PED] Tous les PEDs ont été supprimés')
end

-- =====================================================
-- INITIALISATION DES PEDS
-- =====================================================

---Initialise tous les PEDs configurés
function Redzone.Client.Ped.Initialize()
    Redzone.Shared.Debug('[PED] Initialisation des PEDs...')

    -- Création du PED du menu principal
    if Config.Peds.MenuPed then
        local menuPed = Redzone.Client.Ped.Create(Config.Peds.MenuPed)
        if menuPed then
            spawnedPeds['menu'] = menuPed
            Redzone.Shared.Debug('[PED] PED du menu créé avec succès')
        end
    end
end

-- =====================================================
-- INTERACTIONS AVEC LES PEDS
-- =====================================================

---Vérifie si le joueur est proche du PED du menu
---@return boolean isNear True si le joueur est proche
function Redzone.Client.Ped.IsPlayerNearMenuPed()
    local pedConfig = Config.Peds.MenuPed
    if not pedConfig then return false end

    local pedCoords = Redzone.Shared.Vec4ToVec3(pedConfig.Coords)
    local distance = Redzone.Client.Utils.GetDistanceToPoint(pedCoords)

    return distance <= Config.Interaction.InteractDistance
end

---Obtient le PED du menu
---@return number|nil ped Le handle du PED ou nil
function Redzone.Client.Ped.GetMenuPed()
    return spawnedPeds['menu']
end

-- =====================================================
-- THREAD D'INTERACTION
-- =====================================================

-- Variable pour contrôler l'état d'interaction
local isInteracting = false

---Démarre le thread d'interaction avec les PEDs
function Redzone.Client.Ped.StartInteractionThread()
    Redzone.Shared.Debug('[PED] Démarrage du thread d\'interaction')

    CreateThread(function()
        while true do
            local sleep = 1000 -- Pause longue par défaut

            -- Vérification de la proximité avec le PED du menu
            if Redzone.Client.Ped.IsPlayerNearMenuPed() then
                sleep = 0 -- Vérification rapide quand proche

                -- Affichage du texte d'aide
                Redzone.Client.Utils.ShowHelpText(Config.Interaction.HelpText)

                -- Vérification de la touche d'interaction
                if Redzone.Client.Utils.IsKeyJustPressed(Config.Interaction.InteractKey) then
                    if not isInteracting then
                        isInteracting = true
                        Redzone.Shared.Debug(Config.DebugMessages.MenuOpened, GetPlayerServerId(PlayerId()))

                        -- Ouvrir le menu NUI
                        Redzone.Client.Menu.Open()
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

---Définit l'état d'interaction
---@param state boolean Le nouvel état
function Redzone.Client.Ped.SetInteracting(state)
    isInteracting = state
end

-- =====================================================
-- AFFICHAGE DU NOMBRE DE JOUEURS AU-DESSUS DU PED
-- =====================================================

---Dessine un texte 3D dans le monde
---@param x number Position X
---@param y number Position Y
---@param z number Position Z
---@param text string Le texte à afficher
---@param scale number L'échelle du texte
local function DrawText3D(x, y, z, text, scale)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - vector3(x, y, z))

    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextCentre(true)
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

---Démarre le thread d'affichage du nombre de joueurs
function Redzone.Client.Ped.StartPlayerCountDisplayThread()
    Redzone.Shared.Debug('[PED] Démarrage du thread d\'affichage du nombre de joueurs')

    CreateThread(function()
        -- Demander le nombre de joueurs actuel au serveur
        TriggerServerEvent('redzone:requestPlayerCount')

        while true do
            local sleep = 1000 -- Pause longue par défaut

            local pedConfig = Config.Peds.MenuPed
            if pedConfig then
                local pedCoords = Redzone.Shared.Vec4ToVec3(pedConfig.Coords)
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - pedCoords)

                -- Afficher le texte seulement si le joueur est à moins de 15 mètres
                if distance <= PLAYER_COUNT_DISPLAY_DISTANCE then
                    sleep = 0 -- Mise à jour rapide pour le rendu

                    -- Construire le texte à afficher
                    local displayText = string.format('[ REDZONE %d JOUEUR%s ]',
                        redzonePlayerCount,
                        redzonePlayerCount > 1 and 'S' or ''
                    )

                    -- Position au-dessus du PED (1.2 mètre au-dessus)
                    local textZ = pedCoords.z + 1.2

                    -- Calculer l'échelle en fonction de la distance (plus proche = plus grand)
                    local scale = 0.5 - (distance / PLAYER_COUNT_DISPLAY_DISTANCE) * 0.2
                    if scale < 0.3 then scale = 0.3 end

                    DrawText3D(pedCoords.x, pedCoords.y, textZ, displayText, scale)
                end
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- ÉVÉNEMENTS DE SYNCHRONISATION
-- =====================================================

---Événement: Réception du nombre de joueurs du serveur
RegisterNetEvent('redzone:syncPlayerCount')
AddEventHandler('redzone:syncPlayerCount', function(count)
    redzonePlayerCount = count or 0
    Redzone.Shared.Debug('[PED] Nombre de joueurs mis à jour: ', redzonePlayerCount)
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

---Nettoie les ressources lors de l'arrêt du script
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Redzone.Client.Ped.DeleteAll()
    Redzone.Shared.Debug('[PED] Nettoyage effectué')
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/PED] Module PED chargé')
