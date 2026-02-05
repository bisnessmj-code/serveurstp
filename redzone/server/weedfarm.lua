--[[
    =====================================================
    REDZONE LEAGUE - Système de Farm Weed (Serveur)
    =====================================================
    Ce fichier gère la logique serveur du système de
    récolte, traitement et vente de weed.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}
Redzone.Server.WeedFarm = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Framework ESX
local ESX = nil


-- =====================================================
-- INITIALISATION ESX
-- =====================================================

CreateThread(function()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX == nil do
        Wait(100)
    end
    Redzone.Shared.Debug('[SERVER/WEEDFARM] ESX chargé')
end)

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Vérifie si un joueur est VIP
---@param source number L'ID du joueur
---@return boolean isVip True si VIP
local function IsPlayerVip(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local group = xPlayer.getGroup()
    for _, vipGroup in ipairs(Config.WeedFarm.VipGroups) do
        if group == vipGroup then
            return true
        end
    end

    return false
end

---Donne un item au joueur via qs-inventory
---@param source number L'ID du joueur
---@param item string Le nom de l'item
---@param amount number La quantité
local function GiveItem(source, item, amount)
    exports['qs-inventory']:AddItem(source, item, amount)
end

---Retire un item au joueur via qs-inventory
---@param source number L'ID du joueur
---@param item string Le nom de l'item
---@param amount number La quantité
---@return boolean success True si réussi
local function RemoveItem(source, item, amount)
    local hasItem = exports['qs-inventory']:GetItemTotalAmount(source, item)
    if hasItem >= amount then
        exports['qs-inventory']:RemoveItem(source, item, amount)
        return true
    end
    return false
end

---Obtient la quantité d'un item
---@param source number L'ID du joueur
---@param item string Le nom de l'item
---@return number amount La quantité
local function GetItemCount(source, item)
    return exports['qs-inventory']:GetItemTotalAmount(source, item) or 0
end

-- =====================================================
-- SYSTÈME DE RÉCOLTE
-- =====================================================

---Événement: Joueur récolte
RegisterNetEvent('redzone:weed:harvest')
AddEventHandler('redzone:weed:harvest', function(pointIndex)
    local source = source

    -- Vérifications de sécurité
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end
    if not Config.WeedFarm or not Config.WeedFarm.Enabled then return end

    -- Donner l'item au joueur
    local amount = Config.WeedFarm.Harvest.Amount
    GiveItem(source, Config.WeedFarm.Harvest.Item, amount)

    -- Log
    Redzone.Server.Utils.Log('WEED_HARVEST', source, 'Point: ' .. pointIndex .. ', Amount: ' .. amount)
end)

-- =====================================================
-- SYSTÈME DE TRAITEMENT
-- =====================================================

---Événement: Joueur traite la weed
RegisterNetEvent('redzone:weed:process')
AddEventHandler('redzone:weed:process', function()
    local source = source

    -- Vérifications de sécurité
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end
    if not Config.WeedFarm or not Config.WeedFarm.Enabled then return end

    local config = Config.WeedFarm.Process

    -- Vérifier si le joueur a assez de weed
    local weedCount = GetItemCount(source, config.InputItem)
    if weedCount < config.InputAmount then
        TriggerClientEvent('redzone:weed:processFailure', source)
        return
    end

    -- Retirer la weed
    if not RemoveItem(source, config.InputItem, config.InputAmount) then
        TriggerClientEvent('redzone:weed:processFailure', source)
        return
    end

    -- Donner le weed_brick
    GiveItem(source, config.OutputItem, config.OutputAmount)

    -- Log
    Redzone.Server.Utils.Log('WEED_PROCESS', source, 'Input: ' .. config.InputAmount .. ' weed, Output: ' .. config.OutputAmount .. ' weed_brick')
end)

-- =====================================================
-- SYSTÈME DE VENTE
-- =====================================================

---Événement: Joueur vend ses weed_brick
RegisterNetEvent('redzone:weed:sell')
AddEventHandler('redzone:weed:sell', function()
    local source = source

    -- Vérifications de sécurité
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end
    if not Config.WeedFarm or not Config.WeedFarm.Enabled then return end

    local config = Config.WeedFarm.Sell
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Compter les weed_brick
    local brickCount = GetItemCount(source, config.Item)
    if brickCount <= 0 then
        TriggerClientEvent('redzone:weed:sellFailure', source)
        return
    end

    -- Calculer le montant total
    local totalAmount = brickCount * config.PricePerUnit

    -- Retirer tous les weed_brick
    if not RemoveItem(source, config.Item, brickCount) then
        TriggerClientEvent('redzone:weed:sellFailure', source)
        return
    end

    -- Donner l'argent sale
    xPlayer.addAccountMoney('black_money', totalAmount)

    -- Notifier le joueur
    TriggerClientEvent('redzone:weed:sellSuccess', source, totalAmount)

    -- Log
    Redzone.Server.Utils.Log('WEED_SELL', source, 'Bricks: ' .. brickCount .. ', Total: $' .. totalAmount)
end)

-- =====================================================
-- SYNCHRONISATION
-- =====================================================

---Événement: Client demande son statut VIP
RegisterNetEvent('redzone:weed:checkVip')
AddEventHandler('redzone:weed:checkVip', function()
    local source = source
    local isVip = IsPlayerVip(source)
    TriggerClientEvent('redzone:weed:vipStatus', source, isVip)
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[SERVER/WEEDFARM] Module Weed Farm chargé')
