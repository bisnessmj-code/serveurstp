--[[
    =====================================================
    REDZONE LEAGUE - Système de Coffre (Stash)
    =====================================================
    Ce fichier gère les PEDs coffre et les interactions
    pour le stockage personnel des joueurs.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Stash = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Stockage des PEDs coffre créés
local stashPeds = {}

-- État d'interaction
local isNearStash = false
local currentStashPed = nil

-- =====================================================
-- CRÉATION DES PEDS COFFRE
-- =====================================================

---Crée un PED coffre avec les paramètres spécifiés
---@param pedConfig table Configuration du PED
---@return number|nil pedHandle Le handle du PED créé ou nil si erreur
local function CreateStashPed(pedConfig)
    -- Validation de la configuration
    if not pedConfig or not pedConfig.Model or not pedConfig.Coords then
        Redzone.Shared.Debug('[STASH/ERROR] Configuration invalide pour la création du PED coffre')
        return nil
    end

    -- Chargement du modèle
    local modelHash = GetHashKey(pedConfig.Model)
    if not Redzone.Client.Utils.LoadModel(modelHash) then
        Redzone.Shared.Debug('[STASH/ERROR] Impossible de charger le modèle: ', pedConfig.Model)
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

        Redzone.Shared.Debug('[STASH] PED coffre créé: ', pedConfig.name)

        return ped
    end

    Redzone.Shared.Debug('[STASH/ERROR] Échec de la création du PED coffre')
    return nil
end

---Supprime un PED coffre
---@param ped number Le handle du PED à supprimer
local function DeleteStashPed(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
        Redzone.Shared.Debug('[STASH] PED coffre supprimé')
    end
end

-- =====================================================
-- INITIALISATION DES PEDS COFFRE
-- =====================================================

---Crée tous les PEDs coffre configurés
function Redzone.Client.Stash.CreateAllPeds()
    -- Supprimer les anciens PEDs s'ils existent
    Redzone.Client.Stash.DeleteAllPeds()

    -- Créer les nouveaux PEDs
    for _, location in ipairs(Config.StashPeds.Locations) do
        local ped = CreateStashPed(location)
        if ped then
            stashPeds[location.id] = {
                ped = ped,
                config = location
            }
        end
    end

    Redzone.Shared.Debug('[STASH] Tous les PEDs coffre ont été créés')
end

---Supprime tous les PEDs coffre
function Redzone.Client.Stash.DeleteAllPeds()
    for id, data in pairs(stashPeds) do
        DeleteStashPed(data.ped)
        stashPeds[id] = nil
    end
    Redzone.Shared.Debug('[STASH] Tous les PEDs coffre ont été supprimés')
end

-- =====================================================
-- INTERACTION AVEC LE COFFRE
-- =====================================================

---Vérifie si le joueur est proche d'un PED coffre
---@return boolean isNear True si proche d'un PED coffre
---@return table|nil stashData Les données du PED coffre le plus proche
function Redzone.Client.Stash.IsPlayerNearStashPed()
    local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
    local closestDistance = Config.Interaction.InteractDistance
    local closestStash = nil

    for id, data in pairs(stashPeds) do
        if DoesEntityExist(data.ped) then
            local pedCoords = Redzone.Shared.Vec4ToVec3(data.config.Coords)
            local distance = #(playerCoords - pedCoords)

            if distance <= closestDistance then
                closestDistance = distance
                closestStash = data
            end
        end
    end

    return closestStash ~= nil, closestStash
end

---Ouvre le coffre personnel du joueur via qs-inventory
function Redzone.Client.Stash.OpenStash()
    Redzone.Shared.Debug('[STASH] Ouverture du coffre personnel')

    -- Demander au serveur d'ouvrir le stash
    TriggerServerEvent('redzone:stash:open')
end

-- =====================================================
-- THREAD D'INTERACTION
-- =====================================================

---Démarre le thread d'interaction avec les PEDs coffre
function Redzone.Client.Stash.StartInteractionThread()
    Redzone.Shared.Debug('[STASH] Démarrage du thread d\'interaction coffre')

    CreateThread(function()
        while true do
            local sleep = 1000 -- Pause longue par défaut

            -- Vérifier seulement si le joueur est dans le redzone
            if Redzone.Client.Teleport.IsInRedzone() then
                sleep = 200 -- Vérification plus rapide dans le redzone

                -- Afficher le texte 3D [COFFRE] au-dessus des PEDs à moins de 15m
                local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
                for _, data in pairs(stashPeds) do
                    if DoesEntityExist(data.ped) then
                        local pedCoords = GetEntityCoords(data.ped)
                        local dist = #(playerCoords - pedCoords)
                        if dist <= 15.0 then
                            sleep = 0
                            Redzone.Client.Utils.DrawText3D(vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.3), '[COFFRE]', 0.45)
                        end
                    end
                end

                local near, stashData = Redzone.Client.Stash.IsPlayerNearStashPed()

                if near then
                    sleep = 0 -- Vérification chaque frame quand proche

                    isNearStash = true
                    currentStashPed = stashData

                    -- Affichage du texte d'aide
                    Redzone.Client.Utils.ShowHelpText(Config.StashPeds.Settings.HelpText)

                    -- Vérification de la touche d'interaction
                    if Redzone.Client.Utils.IsKeyJustPressed(Config.Interaction.InteractKey) then
                        Redzone.Client.Stash.OpenStash()
                    end
                else
                    isNearStash = false
                    currentStashPed = nil
                end
            else
                isNearStash = false
                currentStashPed = nil
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur entre dans le redzone
function Redzone.Client.Stash.OnEnterRedzone()
    Redzone.Shared.Debug('[STASH] Joueur entré dans le redzone - Création des PEDs coffre')
    Redzone.Client.Stash.CreateAllPeds()
end

---Appelé quand le joueur quitte le redzone
function Redzone.Client.Stash.OnLeaveRedzone()
    Redzone.Shared.Debug('[STASH] Joueur sorti du redzone - Suppression des PEDs coffre')
    Redzone.Client.Stash.DeleteAllPeds()
end

-- =====================================================
-- EXPORTS
-- =====================================================

-- Export pour ouvrir le coffre
exports('OpenRedzoneStash', function()
    Redzone.Client.Stash.OpenStash()
end)

-- Export pour vérifier si proche d'un coffre
exports('IsNearStash', function()
    return isNearStash
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

---Événement: Arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Supprimer tous les PEDs coffre
    Redzone.Client.Stash.DeleteAllPeds()

    Redzone.Shared.Debug('[STASH] Nettoyage des PEDs coffre effectué')
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/STASH] Module Stash chargé')
