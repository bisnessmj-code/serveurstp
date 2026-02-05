--[[
    =====================================================
    REDZONE LEAGUE - Système de Farm Weed
    =====================================================
    Ce fichier gère le système de récolte, traitement
    et vente de weed dans le redzone.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.WeedFarm = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Blips créés
local harvestBlips = {}
local processBlip = nil
local sellBlip = nil

-- PED vendeur
local sellPed = nil


-- État actuel
local isHarvesting = false
local isProcessing = false
local isSelling = false

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Vérifie si le joueur est VIP
---@return boolean isVip True si VIP
local function IsPlayerVip()
    -- Demander au serveur via callback serait plus propre, mais pour simplifier
    -- on va utiliser une variable synchronisée
    return Redzone.Client.WeedFarm.isVip or false
end

---Joue l'animation à genoux
---@param duration number Durée en ms
local function PlayKneelAnimation(duration)
    local playerPed = PlayerPedId()
    local animDict = 'amb@world_human_gardener_plant@male@base'
    local animName = 'base'

    -- Charger le dictionnaire d'animation
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end

    -- Jouer l'animation
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, duration, 1, 0, false, false, false)
end

---Arrête l'animation en cours
local function StopCurrentAnimation()
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
end

-- =====================================================
-- SYSTÈME DE RÉCOLTE
-- =====================================================

---Obtient le point de récolte le plus proche
---@return number|nil index L'index du point ou nil
---@return number distance La distance
local function GetNearestHarvestPoint()
    if not Config.WeedFarm or not Config.WeedFarm.Harvest then return nil, 999 end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestIndex = nil
    local nearestDistance = 999

    for i, pos in ipairs(Config.WeedFarm.Harvest.Positions) do
        local distance = #(playerCoords - vector3(pos.x, pos.y, pos.z))
        if distance < nearestDistance then
            nearestDistance = distance
            nearestIndex = i
        end
    end

    return nearestIndex, nearestDistance
end

---Récolte au point spécifié
---@param index number L'index du point
local function HarvestAtPoint(index)
    if isHarvesting then return end

    isHarvesting = true

    -- Déterminer la durée
    local duration = IsPlayerVip() and Config.WeedFarm.Harvest.VipDuration or Config.WeedFarm.Harvest.Duration
    local durationMs = duration * 1000

    -- Jouer l'animation
    PlayKneelAnimation(durationMs)

    -- Attendre la fin
    Wait(durationMs)

    -- Arrêter l'animation
    StopCurrentAnimation()

    -- Demander au serveur de donner l'item
    TriggerServerEvent('redzone:weed:harvest', index)

    isHarvesting = false
end

-- =====================================================
-- SYSTÈME DE TRAITEMENT
-- =====================================================

---Vérifie si le joueur est près du point de traitement
---@return boolean isNear True si proche
---@return number distance La distance
local function IsNearProcessPoint()
    if not Config.WeedFarm or not Config.WeedFarm.Process then return false, 999 end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local processPos = Config.WeedFarm.Process.Position
    local distance = #(playerCoords - vector3(processPos.x, processPos.y, processPos.z))

    return distance <= Config.WeedFarm.Process.InteractDistance, distance
end

---Traite la weed
local function ProcessWeed()
    if isProcessing then return end

    isProcessing = true

    -- Déterminer la durée
    local duration = IsPlayerVip() and Config.WeedFarm.Process.VipDuration or Config.WeedFarm.Process.Duration
    local durationMs = duration * 1000

    -- Jouer l'animation
    PlayKneelAnimation(durationMs)

    -- Attendre la fin
    Wait(durationMs)

    -- Arrêter l'animation
    StopCurrentAnimation()

    -- Demander au serveur de traiter
    TriggerServerEvent('redzone:weed:process')

    isProcessing = false
end

-- =====================================================
-- SYSTÈME DE VENTE
-- =====================================================

---Vérifie si le joueur est près du PED de vente
---@return boolean isNear True si proche
local function IsNearSellPed()
    if not sellPed or not DoesEntityExist(sellPed) then return false end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local pedCoords = GetEntityCoords(sellPed)
    local distance = #(playerCoords - pedCoords)

    return distance <= Config.WeedFarm.Sell.InteractDistance
end

---Vend tous les weed_brick
local function SellWeedBricks()
    if isSelling then return end

    isSelling = true

    -- Demander au serveur de vendre
    TriggerServerEvent('redzone:weed:sell')

    -- Petit délai pour éviter le spam
    Wait(500)

    isSelling = false
end

-- =====================================================
-- CRÉATION DES BLIPS ET PEDS
-- =====================================================

---Crée les blips de récolte
local function CreateHarvestBlips()
    if not Config.WeedFarm.Harvest.Blip.Enabled then return end

    for i, pos in ipairs(Config.WeedFarm.Harvest.Positions) do
        local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(blip, Config.WeedFarm.Harvest.Blip.Sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.WeedFarm.Harvest.Blip.Scale)
        SetBlipColour(blip, Config.WeedFarm.Harvest.Blip.Color)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.WeedFarm.Harvest.Blip.Name)
        EndTextCommandSetBlipName(blip)

        table.insert(harvestBlips, blip)
    end

    Redzone.Shared.Debug('[WEEDFARM] Blips de récolte créés')
end

---Crée le blip de traitement
local function CreateProcessBlip()
    if not Config.WeedFarm.Process.Blip.Enabled then return end

    local pos = Config.WeedFarm.Process.Position
    processBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(processBlip, Config.WeedFarm.Process.Blip.Sprite)
    SetBlipDisplay(processBlip, 4)
    SetBlipScale(processBlip, Config.WeedFarm.Process.Blip.Scale)
    SetBlipColour(processBlip, Config.WeedFarm.Process.Blip.Color)
    SetBlipAsShortRange(processBlip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.WeedFarm.Process.Blip.Name)
    EndTextCommandSetBlipName(processBlip)

    Redzone.Shared.Debug('[WEEDFARM] Blip de traitement créé')
end

---Crée le blip et PED de vente
local function CreateSellPoint()
    local config = Config.WeedFarm.Sell

    -- Créer le blip
    if config.Blip.Enabled then
        local pos = config.Ped.Position
        sellBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(sellBlip, config.Blip.Sprite)
        SetBlipDisplay(sellBlip, 4)
        SetBlipScale(sellBlip, config.Blip.Scale)
        SetBlipColour(sellBlip, config.Blip.Color)
        SetBlipAsShortRange(sellBlip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(config.Blip.Name)
        EndTextCommandSetBlipName(sellBlip)
    end

    -- Créer le PED
    local pedConfig = config.Ped
    local modelHash = GetHashKey(pedConfig.Model)

    -- Charger le modèle
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end

    -- Créer le PED
    local pos = pedConfig.Position
    sellPed = CreatePed(4, modelHash, pos.x, pos.y, pos.z - 1.0, pos.w, false, true)

    if DoesEntityExist(sellPed) then
        SetEntityInvincible(sellPed, pedConfig.Invincible)
        FreezeEntityPosition(sellPed, pedConfig.Frozen)
        SetBlockingOfNonTemporaryEvents(sellPed, pedConfig.BlockEvents)
        SetPedFleeAttributes(sellPed, 0, false)
        SetPedCombatAttributes(sellPed, 46, true)

        if pedConfig.Scenario then
            TaskStartScenarioInPlace(sellPed, pedConfig.Scenario, 0, true)
        end
    end

    SetModelAsNoLongerNeeded(modelHash)

    Redzone.Shared.Debug('[WEEDFARM] Point de vente créé')
end

---Supprime tous les blips et PEDs
local function DeleteAll()
    -- Supprimer les blips de récolte
    for _, blip in ipairs(harvestBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    harvestBlips = {}

    -- Supprimer le blip de traitement
    if processBlip and DoesBlipExist(processBlip) then
        RemoveBlip(processBlip)
        processBlip = nil
    end

    -- Supprimer le blip de vente
    if sellBlip and DoesBlipExist(sellBlip) then
        RemoveBlip(sellBlip)
        sellBlip = nil
    end

    -- Supprimer le PED de vente
    if sellPed and DoesEntityExist(sellPed) then
        DeleteEntity(sellPed)
        sellPed = nil
    end

    Redzone.Shared.Debug('[WEEDFARM] Tout nettoyé')
end

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur entre dans le redzone
function Redzone.Client.WeedFarm.OnEnterRedzone()
    if not Config.WeedFarm or not Config.WeedFarm.Enabled then return end

    Redzone.Shared.Debug('[WEEDFARM] Joueur entré dans le redzone')

    -- Créer les éléments
    CreateHarvestBlips()
    CreateProcessBlip()
    CreateSellPoint()

    -- Demander le statut VIP au serveur
    TriggerServerEvent('redzone:weed:checkVip')

end

---Appelé quand le joueur quitte le redzone
function Redzone.Client.WeedFarm.OnLeaveRedzone()
    Redzone.Shared.Debug('[WEEDFARM] Joueur sorti du redzone')
    DeleteAll()
end

-- =====================================================
-- THREAD PRINCIPAL D'INTERACTION
-- =====================================================

CreateThread(function()
    while true do
        local sleep = 1000

        -- Vérifier seulement si dans le redzone et système activé
        if Config.WeedFarm and Config.WeedFarm.Enabled and Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone() then
            sleep = 500

            -- Vérifier la proximité avec les points de récolte
            local harvestIndex, harvestDistance = GetNearestHarvestPoint()
            if harvestIndex and harvestDistance <= Config.WeedFarm.Harvest.InteractDistance then
                sleep = 0

                -- Afficher le texte d'aide
                Redzone.Client.Utils.ShowHelpText(Config.WeedFarm.Harvest.Messages.HelpText)

                -- Vérifier la touche d'interaction
                if Redzone.Client.Utils.IsKeyJustPressed(38) and not isHarvesting then -- E
                    HarvestAtPoint(harvestIndex)
                end
            end

            -- Vérifier la proximité avec le point de traitement
            local isNearProcess, processDistance = IsNearProcessPoint()
            if isNearProcess then
                sleep = 0

                -- Afficher le texte d'aide
                Redzone.Client.Utils.ShowHelpText(Config.WeedFarm.Process.Messages.HelpText)

                -- Vérifier la touche d'interaction
                if Redzone.Client.Utils.IsKeyJustPressed(38) and not isProcessing then -- E
                    ProcessWeed()
                end
            end

            -- Vérifier la proximité avec le PED de vente
            if IsNearSellPed() then
                sleep = 0

                -- Afficher le texte d'aide
                Redzone.Client.Utils.ShowHelpText(Config.WeedFarm.Sell.Messages.HelpText)

                -- Vérifier la touche d'interaction
                if Redzone.Client.Utils.IsKeyJustPressed(38) and not isSelling then -- E
                    SellWeedBricks()
                end
            end
        end

        Wait(sleep)
    end
end)

-- =====================================================
-- ÉVÉNEMENTS SERVEUR
-- =====================================================

---Réception du statut VIP
RegisterNetEvent('redzone:weed:vipStatus')
AddEventHandler('redzone:weed:vipStatus', function(isVip)
    Redzone.Client.WeedFarm.isVip = isVip
    Redzone.Shared.Debug('[WEEDFARM] Statut VIP: ', isVip)
end)

---Notification d'échec de traitement (pas assez de weed)
RegisterNetEvent('redzone:weed:processFailure')
AddEventHandler('redzone:weed:processFailure', function()
    Redzone.Client.Utils.NotifyError(Config.WeedFarm.Process.Messages.NotEnough)
end)

---Notification de succès de vente
RegisterNetEvent('redzone:weed:sellSuccess')
AddEventHandler('redzone:weed:sellSuccess', function(totalAmount)
    local message = string.format(Config.WeedFarm.Sell.Messages.Complete, totalAmount)
    Redzone.Client.Utils.NotifySuccess(message)
end)

---Notification d'échec de vente (pas d'item)
RegisterNetEvent('redzone:weed:sellFailure')
AddEventHandler('redzone:weed:sellFailure', function()
    Redzone.Client.Utils.NotifyError(Config.WeedFarm.Sell.Messages.NoItem)
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    DeleteAll()
    Redzone.Shared.Debug('[WEEDFARM] Nettoyage effectué')
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/WEEDFARM] Module Weed Farm chargé')
