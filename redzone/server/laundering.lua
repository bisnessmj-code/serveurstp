--[[
    =====================================================
    REDZONE LEAGUE - Système de Blanchiment (Serveur)
    =====================================================
    Ce fichier gère la logique serveur du blanchiment d'argent.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Framework ESX
local ESX = nil

-- Joueurs en cours de blanchiment
local launderingPlayers = {}

-- Total blanchi par session (pour le message final)
local totalLaunderedSession = {}

-- =====================================================
-- INITIALISATION
-- =====================================================

local function InitLaunderingESX()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX == nil do
        Wait(100)
    end
end

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Obtient le groupe ESX d'un joueur
---@param playerId number ID serveur du joueur
---@return string group Le groupe du joueur
local function GetPlayerGroup(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        return xPlayer.getGroup()
    end
    return 'user'
end

---Vérifie si le joueur est VIP
---@param playerId number ID serveur du joueur
---@return boolean isVip
local function IsPlayerVIP(playerId)
    local group = GetPlayerGroup(playerId)
    for _, vipGroup in ipairs(Config.MoneyLaundering.VIP.Groups) do
        if group == vipGroup then
            return true
        end
    end
    return false
end

---Obtient la quantité d'un item dans l'inventaire
---@param playerId number ID serveur du joueur
---@param itemName string Nom de l'item
---@return number count Quantité
local function GetItemCount(playerId, itemName)
    local success, result = pcall(function()
        return exports['qs-inventory']:GetItemTotalAmount(playerId, itemName)
    end)

    if success and result then
        return result
    end
    return 0
end

---Retire un item de l'inventaire
---@param playerId number ID serveur du joueur
---@param itemName string Nom de l'item
---@param count number Quantité à retirer
---@return boolean success
local function RemoveItem(playerId, itemName, count)
    local success, err = pcall(function()
        exports['qs-inventory']:RemoveItem(playerId, itemName, count)
    end)
    return success
end

---Ajoute l'item money (argent propre) à l'inventaire
---@param playerId number ID serveur du joueur
---@param amount number Montant à ajouter
---@return boolean success
local function AddMoneyItem(playerId, amount)
    local success, err = pcall(function()
        exports['qs-inventory']:AddItem(playerId, 'money', amount)
    end)
    return success
end

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

---Événement: Demande de blanchiment
RegisterNetEvent('redzone:laundering:start')
AddEventHandler('redzone:laundering:start', function()
    local source = source

    -- Vérifier si déjà en cours
    if launderingPlayers[source] then
        return
    end

    -- Vérifier la quantité d'argent sale
    local dirtyMoney = GetItemCount(source, Config.MoneyLaundering.DirtyMoneyItem)
    local amountNeeded = Config.MoneyLaundering.AmountPerTransaction

    if dirtyMoney < amountNeeded then
        TriggerClientEvent('redzone:laundering:denied', source, 'not_enough')
        return
    end

    -- Déterminer les paramètres selon le grade
    local isVip = IsPlayerVIP(source)
    local duration, fee

    if isVip then
        duration = Config.MoneyLaundering.VIP.Duration
        fee = Config.MoneyLaundering.VIP.Fee
    else
        duration = Config.MoneyLaundering.Normal.Duration
        fee = Config.MoneyLaundering.Normal.Fee
    end

    -- Marquer le joueur comme en cours de blanchiment
    launderingPlayers[source] = {
        startTime = os.time(),
        amount = amountNeeded,
        fee = fee,
        isVip = isVip,
        duration = duration,
    }

    -- Initialiser le total de session
    if not totalLaunderedSession[source] then
        totalLaunderedSession[source] = 0
    end

    -- Confirmer au client
    TriggerClientEvent('redzone:laundering:confirmed', source, duration, fee, amountNeeded)

    Redzone.Shared.Debug('[LAUNDERING] Blanchiment démarré pour joueur ', source, ' (VIP: ', isVip, ')')
end)

---Événement: Blanchiment terminé (un cycle)
RegisterNetEvent('redzone:laundering:finish')
AddEventHandler('redzone:laundering:finish', function()
    local source = source

    -- Vérifier si le joueur était bien en cours de blanchiment
    local session = launderingPlayers[source]
    if not session then
        return
    end

    -- Retirer l'argent sale
    local amount = session.amount
    local fee = session.fee

    local success = RemoveItem(source, Config.MoneyLaundering.DirtyMoneyItem, amount)
    if not success then
        Redzone.Shared.Debug('[LAUNDERING] Erreur lors du retrait de l\'argent sale')
        launderingPlayers[source] = nil
        totalLaunderedSession[source] = nil
        return
    end

    -- Calculer le montant propre (après frais)
    local cleanAmount = math.floor(amount * (100 - fee) / 100)

    -- Ajouter l'item money (argent propre)
    local moneySuccess = AddMoneyItem(source, cleanAmount)
    if moneySuccess then
        -- Ajouter au total de session
        totalLaunderedSession[source] = (totalLaunderedSession[source] or 0) + cleanAmount

        -- Notifier le client du succès de ce cycle
        TriggerClientEvent('redzone:laundering:success', source, cleanAmount, totalLaunderedSession[source])

        Redzone.Shared.Debug('[LAUNDERING] Cycle réussi: ', source, ' - Montant: $', cleanAmount)

        -- Log
        if Redzone.Server.Utils then
            Redzone.Server.Utils.Log('MONEY_LAUNDERING', source,
                'Blanchi $' .. amount .. ' -> $' .. cleanAmount .. ' (Fee: ' .. fee .. '%)')
        end
    else
        Redzone.Shared.Debug('[LAUNDERING] Erreur lors de l\'ajout de l\'item money')
        launderingPlayers[source] = nil
        totalLaunderedSession[source] = nil
        return
    end

    -- Nettoyer la session actuelle
    launderingPlayers[source] = nil

    -- Vérifier s'il reste de l'argent sale pour continuer
    Wait(100) -- Petit délai pour laisser l'inventaire se mettre à jour

    local remainingDirtyMoney = GetItemCount(source, Config.MoneyLaundering.DirtyMoneyItem)
    local amountNeeded = Config.MoneyLaundering.AmountPerTransaction

    if remainingDirtyMoney >= amountNeeded then
        -- Il reste de l'argent, continuer automatiquement
        local isVip = session.isVip
        local duration = session.duration

        -- Recréer la session
        launderingPlayers[source] = {
            startTime = os.time(),
            amount = amountNeeded,
            fee = fee,
            isVip = isVip,
            duration = duration,
        }

        -- Envoyer l'événement pour continuer
        TriggerClientEvent('redzone:laundering:continue', source, duration, fee, amountNeeded)

        Redzone.Shared.Debug('[LAUNDERING] Continuation automatique pour joueur ', source)
    else
        -- Plus assez d'argent, terminer complètement
        local totalLaundered = totalLaunderedSession[source] or 0
        TriggerClientEvent('redzone:laundering:complete', source, totalLaundered)

        totalLaunderedSession[source] = nil

        Redzone.Shared.Debug('[LAUNDERING] Blanchiment terminé - Total: $', totalLaundered)
    end
end)

---Événement: Blanchiment annulé
RegisterNetEvent('redzone:laundering:cancel')
AddEventHandler('redzone:laundering:cancel', function()
    local source = source

    local totalLaundered = totalLaunderedSession[source] or 0

    if launderingPlayers[source] then
        launderingPlayers[source] = nil
    end

    -- Envoyer le total blanchi au client s'il y en a
    if totalLaundered > 0 then
        TriggerClientEvent('redzone:laundering:stopped', source, totalLaundered)
        Redzone.Shared.Debug('[LAUNDERING] Blanchiment arrêté - Total blanchi: $', totalLaundered)
    end

    totalLaunderedSession[source] = nil
    Redzone.Shared.Debug('[LAUNDERING] Blanchiment annulé pour joueur ', source)
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('playerDropped', function(reason)
    local source = source

    if launderingPlayers[source] then
        launderingPlayers[source] = nil
    end

    if totalLaunderedSession[source] then
        totalLaunderedSession[source] = nil
    end
end)

-- =====================================================
-- DÉMARRAGE
-- =====================================================

CreateThread(function()
    InitLaunderingESX()
    Redzone.Shared.Debug('[SERVER/LAUNDERING] Module Blanchiment serveur chargé')
end)
