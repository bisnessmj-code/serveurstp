--[[
    =====================================================
    REDZONE LEAGUE - Systeme de Bandage (Serveur)
    =====================================================
    Ce fichier gere la validation et l'application
    des bandages cote serveur.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Framework ESX
local ESX = nil

-- Configuration
local BANDAGE_ITEM = 'bandage'
local HEALTH_RESTORE_PERCENT = 50 -- Pourcentage de vie a restaurer (moitie = 50%)

-- =====================================================
-- INITIALISATION
-- =====================================================

---Initialise ESX
local function InitBandageESX()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX == nil do
        Wait(100)
    end
end

-- =====================================================
-- EVENEMENTS
-- =====================================================

---Evenement: Bandage complete - valider et appliquer
RegisterNetEvent('redzone:bandage:complete')
AddEventHandler('redzone:bandage:complete', function()
    local source = source

    -- Verifier que le joueur est connecte
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end

    -- Obtenir le joueur ESX
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        Redzone.Shared.Debug('[BANDAGE/ERROR] Joueur ESX introuvable: ', source)
        return
    end

    -- Verifier que le joueur a un bandage dans son inventaire
    local bandageItem = xPlayer.getInventoryItem(BANDAGE_ITEM)
    if not bandageItem or bandageItem.count < 1 then
        Redzone.Shared.Debug('[BANDAGE/ERROR] Joueur ', source, ' n\'a pas de bandage')
        Redzone.Server.Utils.NotifyError(source, 'Vous n\'avez pas de bandage.')
        return
    end

    -- Retirer le bandage de l'inventaire
    xPlayer.removeInventoryItem(BANDAGE_ITEM, 1)

    -- Calculer la vie a restaurer (moitie de la vie max)
    -- Dans GTA V, la vie va de 100 (mort) a 200 (max)
    -- Donc la plage de vie est de 100 points
    local healthRange = 100 -- 200 - 100
    local healthToAdd = math.floor(healthRange * (HEALTH_RESTORE_PERCENT / 100))

    -- Envoyer au client pour appliquer la vie
    TriggerClientEvent('redzone:bandage:applyHealth', source, healthToAdd)

    -- Notification
    Redzone.Server.Utils.NotifySuccess(source, 'Bandage applique ! +' .. healthToAdd .. ' points de vie')

    Redzone.Shared.Debug('[BANDAGE] Joueur ', source, ' a utilise un bandage (+', healthToAdd, ' PV)')
    Redzone.Server.Utils.Log('BANDAGE_USE', source, 'Bandage utilise | +' .. healthToAdd .. ' PV')
end)

-- =====================================================
-- INTEGRATION AVEC QS-INVENTORY / ESX
-- =====================================================

-- Cette fonction est appelee quand le joueur utilise l'item bandage depuis son inventaire
-- Elle doit etre enregistree aupres de votre systeme d'inventaire

---Enregistre l'item bandage comme utilisable
local function RegisterBandageItem()
    -- Pour ESX standard
    ESX.RegisterUsableItem(BANDAGE_ITEM, function(source)
        -- Verifier si le joueur est dans le redzone
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end

        -- Declencher l'utilisation cote client
        TriggerClientEvent('redzone:bandage:use', source)

        Redzone.Shared.Debug('[BANDAGE] Joueur ', source, ' commence a utiliser un bandage')
    end)

    Redzone.Shared.Debug('[SERVER/BANDAGE] Item bandage enregistre comme utilisable')
end

-- =====================================================
-- DEMARRAGE
-- =====================================================

CreateThread(function()
    InitBandageESX()
    RegisterBandageItem()
    Redzone.Shared.Debug('[SERVER/BANDAGE] Module Bandage serveur charge')
end)
