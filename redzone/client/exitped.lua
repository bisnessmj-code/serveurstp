--[[
    =====================================================
    REDZONE LEAGUE - PEDs de Sortie
    =====================================================
    Ce fichier gère les PEDs permettant de quitter
    le redzone en appuyant sur E.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.ExitPed = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Stockage des PEDs de sortie créés
local exitPeds = {}

-- Menu state
local isExitMenuOpen = false
local exitMenuSelectedIndex = 1
local exitMenuMode = 'main' -- 'main' ou 'zones'
local currentExitData = nil

-- Dimensions et position du menu (style RageUI)
local EXIT_MENU = {
    x = 0.118,
    y = 0.070,
    width = 0.210,
    headerHeight = 0.038,
    itemHeight = 0.034,
    spacing = 0.0,
}

local function DrawExitMenuRect(x, y, w, h, r, g, b, a)
    DrawRect(x, y, w, h, r, g, b, a)
end

local function DrawExitMenuText(x, y, text, scale, r, g, b, a)
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

local function DrawExitMenuTextCentered(x, y, text, scale, r, g, b, a)
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

-- =====================================================
-- CRÉATION DES PEDS DE SORTIE
-- =====================================================

---Crée un PED de sortie
---@param location table Configuration de la location
---@return number|nil pedHandle Le handle du PED créé ou nil
local function CreateExitPed(location)
    local settings = Config.ExitPeds.Settings
    if not location or not location.Coords then
        Redzone.Shared.Debug('[EXITPED/ERROR] Configuration invalide')
        return nil
    end

    local modelHash = GetHashKey(settings.Model)
    if not Redzone.Client.Utils.LoadModel(modelHash) then
        Redzone.Shared.Debug('[EXITPED/ERROR] Impossible de charger le modèle: ', settings.Model)
        return nil
    end

    local coords = Redzone.Shared.Vec4ToVec3(location.Coords)
    local heading = Redzone.Shared.GetHeadingFromVec4(location.Coords)

    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, heading, false, true)

    if DoesEntityExist(ped) then
        if settings.Invincible then
            SetEntityInvincible(ped, true)
        end
        if settings.Frozen then
            FreezeEntityPosition(ped, true)
        end
        if settings.BlockEvents then
            SetBlockingOfNonTemporaryEvents(ped, true)
        end

        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        SetPedDiesWhenInjured(ped, false)

        if settings.Scenario then
            TaskStartScenarioInPlace(ped, settings.Scenario, 0, true)
        end

        Redzone.Client.Utils.UnloadModel(modelHash)
        Redzone.Shared.Debug('[EXITPED] PED de sortie créé: ', location.name)
        return ped
    end

    Redzone.Shared.Debug('[EXITPED/ERROR] Échec de la création du PED de sortie')
    return nil
end

---Crée tous les PEDs de sortie
function Redzone.Client.ExitPed.CreateAllPeds()
    Redzone.Client.ExitPed.DeleteAllPeds()

    for _, location in ipairs(Config.ExitPeds.Locations) do
        local ped = CreateExitPed(location)
        if ped then
            exitPeds[location.id] = {
                ped = ped,
                config = location
            }
        end
    end

    Redzone.Shared.Debug('[EXITPED] Tous les PEDs de sortie ont été créés')
end

---Supprime tous les PEDs de sortie
function Redzone.Client.ExitPed.DeleteAllPeds()
    for id, data in pairs(exitPeds) do
        if DoesEntityExist(data.ped) then
            DeleteEntity(data.ped)
        end
        exitPeds[id] = nil
    end
    Redzone.Shared.Debug('[EXITPED] Tous les PEDs de sortie ont été supprimés')
end

-- =====================================================
-- INTERACTION
-- =====================================================

---Vérifie si le joueur est proche d'un PED de sortie
---@return boolean isNear
---@return table|nil exitData
function Redzone.Client.ExitPed.IsPlayerNearExitPed()
    local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
    local closestDistance = Config.Interaction.InteractDistance
    local closestExit = nil

    for _, data in pairs(exitPeds) do
        if DoesEntityExist(data.ped) then
            local pedCoords = Redzone.Shared.Vec4ToVec3(data.config.Coords)
            local distance = #(playerCoords - pedCoords)

            if distance <= closestDistance then
                closestDistance = distance
                closestExit = data
            end
        end
    end

    return closestExit ~= nil, closestExit
end

---Sortie instantanée du redzone (sans countdown)
local function InstantLeave()
    if not Redzone.Client.Teleport.IsInRedzone() then
        return
    end

    Redzone.Client.Teleport.SetPlayerState(Redzone.Shared.Constants.PlayerStates.LEAVING)

    -- Cleanup des zones
    Redzone.Client.Zones.OnLeaveRedzone()

    -- Téléportation instantanée vers le point de sortie
    local exitPoint = Config.Gamemode.ExitPoint
    local playerPed = PlayerPedId()

    DoScreenFadeOut(500)
    Wait(500)

    SetEntityCoords(playerPed, exitPoint.x, exitPoint.y, exitPoint.z, false, false, false, true)
    SetEntityHeading(playerPed, exitPoint.w)

    Wait(500)
    DoScreenFadeIn(500)

    Redzone.Client.Teleport.SetPlayerState(Redzone.Shared.Constants.PlayerStates.OUTSIDE)
    Redzone.Client.Utils.NotifySuccess('Vous avez quitté le REDZONE LEAGUE.')

    TriggerServerEvent('redzone:playerLeft')

    Redzone.Shared.Debug('[EXITPED] Joueur sorti du redzone via PED de sortie')
end

---Téléporte le joueur vers une autre zone safe
---@param spawnPoint table Le point de spawn cible
local function TeleportToZone(spawnPoint)
    if not Redzone.Client.Teleport.IsInRedzone() then
        return
    end

    local playerPed = PlayerPedId()

    DoScreenFadeOut(500)
    Wait(500)

    SetEntityCoords(playerPed, spawnPoint.coords.x, spawnPoint.coords.y, spawnPoint.coords.z, false, false, false, true)
    SetEntityHeading(playerPed, spawnPoint.coords.w)

    Wait(500)
    DoScreenFadeIn(500)

    Redzone.Client.Utils.NotifySuccess('Téléporté vers : ' .. spawnPoint.name)
    Redzone.Shared.Debug('[EXITPED] Joueur téléporté vers zone safe: ' .. spawnPoint.name)
end

---Récupère les zones safe autres que celle où se trouve le joueur
---@return table zones Liste des zones disponibles
local function GetOtherSafeZones()
    local zones = {}
    local playerCoords = Redzone.Client.Utils.GetPlayerCoords()

    for _, spawn in ipairs(Config.SpawnPoints) do
        local spawnCoords = Redzone.Shared.Vec4ToVec3(spawn.coords)
        local distance = #(playerCoords - spawnCoords)
        -- Exclure la zone dans laquelle le joueur se trouve déjà (rayon 50m)
        if distance > 50.0 then
            table.insert(zones, spawn)
        end
    end

    return zones
end

---Ouvre le menu de téléportation (style RageUI)
local function OpenExitMenu()
    if isExitMenuOpen then return end
    isExitMenuOpen = true
    exitMenuSelectedIndex = 1
    exitMenuMode = 'main'

    CreateThread(function()
        while isExitMenuOpen do
            Wait(0)

            local items = {}
            local headerTitle = 'TÉLÉPORTATION'

            if exitMenuMode == 'main' then
                items = {
                    { label = 'Quitter le mode de jeu', action = 'leave' },
                    { label = 'Changer de zone safe', action = 'zones' },
                }
            elseif exitMenuMode == 'zones' then
                headerTitle = 'ZONES SAFE'
                local zones = GetOtherSafeZones()
                for _, zone in ipairs(zones) do
                    table.insert(items, { label = zone.name, action = 'teleport', data = zone })
                end
                if #items == 0 then
                    table.insert(items, { label = 'Aucune autre zone disponible', action = 'none' })
                end
            end

            local itemCount = #items
            if exitMenuSelectedIndex > itemCount then
                exitMenuSelectedIndex = itemCount
            end
            if exitMenuSelectedIndex < 1 then
                exitMenuSelectedIndex = 1
            end

            local currentY = EXIT_MENU.y + 0.015

            -- === HEADER ===
            local headerY = currentY + EXIT_MENU.headerHeight / 2
            DrawExitMenuRect(EXIT_MENU.x, headerY, EXIT_MENU.width, EXIT_MENU.headerHeight, 200, 0, 0, 240)
            DrawExitMenuTextCentered(EXIT_MENU.x, currentY + 0.005, headerTitle, 0.45, 255, 255, 255, 255)
            currentY = currentY + EXIT_MENU.headerHeight

            -- === ITEMS ===
            for i, item in ipairs(items) do
                local itemY = currentY + EXIT_MENU.itemHeight / 2

                if i == exitMenuSelectedIndex then
                    DrawExitMenuRect(EXIT_MENU.x, itemY, EXIT_MENU.width, EXIT_MENU.itemHeight, 255, 255, 255, 240)
                    DrawExitMenuText(EXIT_MENU.x - EXIT_MENU.width / 2 + 0.008, currentY + 0.005, item.label, 0.33, 0, 0, 0, 255)
                else
                    DrawExitMenuRect(EXIT_MENU.x, itemY, EXIT_MENU.width, EXIT_MENU.itemHeight, 0, 0, 0, 180)
                    DrawExitMenuText(EXIT_MENU.x - EXIT_MENU.width / 2 + 0.008, currentY + 0.005, item.label, 0.33, 255, 255, 255, 255)
                end

                currentY = currentY + EXIT_MENU.itemHeight + EXIT_MENU.spacing
            end

            -- === FOOTER ===
            local footerY = currentY + 0.012
            DrawExitMenuRect(EXIT_MENU.x, footerY, EXIT_MENU.width, 0.024, 0, 0, 0, 200)
            DrawExitMenuTextCentered(EXIT_MENU.x, currentY + 0.002, tostring(exitMenuSelectedIndex) .. ' / ' .. tostring(itemCount), 0.30, 255, 255, 255, 200)

            -- === CONTRÔLES ===
            DisableControlAction(0, 27, true)
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)

            -- Flèche Haut
            if IsDisabledControlJustPressed(0, 172) then
                exitMenuSelectedIndex = exitMenuSelectedIndex - 1
                if exitMenuSelectedIndex < 1 then
                    exitMenuSelectedIndex = itemCount
                end
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            end

            -- Flèche Bas
            if IsDisabledControlJustPressed(0, 173) then
                exitMenuSelectedIndex = exitMenuSelectedIndex + 1
                if exitMenuSelectedIndex > itemCount then
                    exitMenuSelectedIndex = 1
                end
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            end

            -- Entrée pour valider
            if IsControlJustPressed(0, 191) then
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                local selected = items[exitMenuSelectedIndex]

                if selected then
                    if selected.action == 'leave' then
                        isExitMenuOpen = false
                        InstantLeave()
                    elseif selected.action == 'zones' then
                        exitMenuMode = 'zones'
                        exitMenuSelectedIndex = 1
                    elseif selected.action == 'teleport' then
                        isExitMenuOpen = false
                        TeleportToZone(selected.data)
                    end
                end
            end

            -- Backspace pour retour/fermer
            if IsControlJustPressed(0, 177) then
                PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                if exitMenuMode == 'zones' then
                    exitMenuMode = 'main'
                    exitMenuSelectedIndex = 1
                else
                    isExitMenuOpen = false
                end
            end
        end
    end)
end

---Démarre le thread d'interaction avec les PEDs de sortie
function Redzone.Client.ExitPed.StartInteractionThread()
    Redzone.Shared.Debug('[EXITPED] Démarrage du thread d\'interaction sortie')

    CreateThread(function()
        while true do
            local sleep = 1000

            if Redzone.Client.Teleport.IsInRedzone() then
                sleep = 200

                -- Afficher le texte 3D [TÉLÉPORTATION] au-dessus des PEDs à moins de 15m
                local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
                for _, data in pairs(exitPeds) do
                    if DoesEntityExist(data.ped) then
                        local pedCoords = GetEntityCoords(data.ped)
                        local dist = #(playerCoords - pedCoords)
                        if dist <= 15.0 then
                            sleep = 0
                            Redzone.Client.Utils.DrawText3D(vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.3), '[TÉLÉPORTATION]', 0.45)
                        end
                    end
                end

                local near, exitData = Redzone.Client.ExitPed.IsPlayerNearExitPed()

                if near then
                    sleep = 0

                    Redzone.Client.Utils.ShowHelpText(Config.ExitPeds.Settings.HelpText)

                    if Redzone.Client.Utils.IsKeyJustPressed(Config.Interaction.InteractKey) then
                        OpenExitMenu()
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

function Redzone.Client.ExitPed.OnEnterRedzone()
    Redzone.Shared.Debug('[EXITPED] Joueur entré dans le redzone - Création des PEDs de sortie')
    Redzone.Client.ExitPed.CreateAllPeds()
end

function Redzone.Client.ExitPed.OnLeaveRedzone()
    Redzone.Shared.Debug('[EXITPED] Joueur sorti du redzone - Suppression des PEDs de sortie')
    Redzone.Client.ExitPed.DeleteAllPeds()
end

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Redzone.Client.ExitPed.DeleteAllPeds()
    Redzone.Shared.Debug('[EXITPED] Nettoyage des PEDs de sortie effectué')
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/EXITPED] Module PED de sortie chargé')
