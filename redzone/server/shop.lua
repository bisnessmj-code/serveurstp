--[[
    =====================================================
    REDZONE LEAGUE - Système de Shop Armes (Serveur)
    =====================================================
    Ce fichier gère la validation, le paiement et
    l'attribution des armes/items aux joueurs depuis le shop.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Framework ESX
local ESX = nil

-- Liste des produits valides avec leurs données (construite à partir de la config)
local validProducts = {}

-- =====================================================
-- INITIALISATION
-- =====================================================

---Initialise ESX
local function InitShopESX()
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX == nil do
        Wait(100)
    end
end

---Construit la liste des produits valides à partir de la config
local function BuildValidProductsList()
    for category, products in pairs(Config.ShopPeds.Products) do
        for _, product in ipairs(products) do
            validProducts[product.model] = {
                name = product.name,
                price = product.price,
                category = category,
                type = product.type or 'weapon',
                image = product.image,
                ammoType = product.ammoType,
                ammoAmount = product.ammoAmount,
            }
        end
    end
    Redzone.Shared.Debug('[SERVER/SHOP] Liste des produits valides construite')
end

---Vérifie si un joueur est VIP
---@param xPlayer table L'objet joueur ESX
---@return boolean isVip True si le joueur est VIP
local function IsPlayerVip(xPlayer)
    if not xPlayer then return false end
    local playerGroup = xPlayer.getGroup()
    for _, group in ipairs(Config.ShopPeds.VipGroups) do
        if group == playerGroup then
            return true
        end
    end
    return false
end

---Calcule le prix final avec réduction VIP
---@param basePrice number Prix de base
---@param isVip boolean Si le joueur est VIP
---@return number finalPrice Prix après réduction
local function CalculatePrice(basePrice, isVip)
    if isVip then
        local discount = Config.ShopPeds.Settings.VipDiscount / 100
        return math.floor(basePrice * (1 - discount))
    end
    return basePrice
end

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

---Événement: Achat d'un produit (arme ou item)
---@param productModel string Le modèle du produit
---@param quantity number|nil La quantité (pour les munitions uniquement)
RegisterNetEvent('redzone:shop:buyWeapon')
AddEventHandler('redzone:shop:buyWeapon', function(productModel, quantity)
    local source = source

    -- Vérification de sécurité
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end

    -- Valider que le produit existe dans la config
    if not validProducts[productModel] then
        Redzone.Shared.Debug('[SHOP/ERROR] Produit invalide demandé par joueur ', source, ': ', productModel)
        Redzone.Server.Utils.NotifyError(source, 'Produit invalide.')
        return
    end

    -- Obtenir le joueur ESX
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        Redzone.Shared.Debug('[SHOP/ERROR] Joueur ESX introuvable: ', source)
        Redzone.Server.Utils.NotifyError(source, 'Erreur: joueur introuvable.')
        return
    end

    -- Obtenir les infos du produit
    local productData = validProducts[productModel]
    local isVip = IsPlayerVip(xPlayer)

    -- Calculer le prix selon le type
    local finalPrice = 0
    local ammoQuantity = 1

    if productData.type == 'ammo' then
        -- C'est des munitions - prix par unité × quantité
        quantity = tonumber(quantity) or productData.ammoAmount or 50
        -- Limiter la quantité (min 1, max 500)
        quantity = math.max(1, math.min(500, quantity))
        ammoQuantity = quantity
        local unitPrice = CalculatePrice(productData.price, isVip)
        finalPrice = unitPrice * quantity
    else
        -- Produit normal - prix fixe
        finalPrice = CalculatePrice(productData.price, isVip)
    end

    -- Vérifier la quantité de l'item money
    local moneyCount = 0
    local success, result = pcall(function()
        return exports['qs-inventory']:GetItemTotalAmount(source, 'money')
    end)

    if success and result then
        moneyCount = result
    end

    if moneyCount < finalPrice then
        local manque = finalPrice - moneyCount
        Redzone.Server.Utils.NotifyError(source, 'Fonds insuffisants! Il vous manque $' .. manque)
        Redzone.Shared.Debug('[SHOP] Fonds insuffisants pour joueur ', source, ': besoin ', finalPrice, ', a ', moneyCount)
        return
    end

    -- Retirer l'item money
    local removeSuccess = pcall(function()
        exports['qs-inventory']:RemoveItem(source, 'money', finalPrice)
    end)

    if not removeSuccess then
        Redzone.Server.Utils.NotifyError(source, 'Erreur lors du paiement')
        Redzone.Shared.Debug('[SHOP] Erreur lors du retrait de l\'item money pour joueur ', source)
        return
    end

    -- Donner le produit selon son type
    if productData.type == 'weapon' then
        -- C'est une arme - utiliser addWeapon
        xPlayer.addWeapon(productModel, Config.ShopPeds.Settings.DefaultAmmo)
        Redzone.Shared.Debug('[SHOP] Arme donnée au joueur ', source, ': ', productModel)
    elseif productData.type == 'ammo' then
        -- C'est des munitions - ajouter à l'inventaire ET aux armes
        xPlayer.addInventoryItem(productModel, ammoQuantity)
        Redzone.Shared.Debug('[SHOP] Munitions ajoutées à l\'inventaire: ', productModel, ' x', ammoQuantity)
        -- Envoyer au client pour ajouter les munitions aux armes équipées
        TriggerClientEvent('redzone:shop:giveAmmo', source, productData.ammoType, ammoQuantity)
        Redzone.Shared.Debug('[SHOP] Munitions données au joueur ', source, ': ', productData.ammoType, ' x', ammoQuantity)
    else
        -- C'est un item - ajouter à l'inventaire
        xPlayer.addInventoryItem(productModel, 1)
        Redzone.Shared.Debug('[SHOP] Item ajouté à l\'inventaire: ', productModel)

        -- Actions supplémentaires selon le type
        if productModel == 'armor' then
            -- Gilet pare-balles - envoyer au client pour ajouter l'armure
            TriggerClientEvent('redzone:shop:giveArmor', source)
            Redzone.Shared.Debug('[SHOP] Armure donnée au joueur ', source)
        end
    end

    -- Notification de succès
    local discountText = ''
    if isVip then
        discountText = ' (VIP -' .. Config.ShopPeds.Settings.VipDiscount .. '%)'
    end

    local quantityText = ''
    if productData.type == 'ammo' then
        quantityText = ' x' .. ammoQuantity
    end

    Redzone.Server.Utils.NotifySuccess(source, productData.name .. quantityText .. ' acheté pour $' .. finalPrice .. discountText)

    Redzone.Shared.Debug('[SHOP] Achat par joueur ', source, ': ', productModel, quantityText, ' pour $', finalPrice)
    Redzone.Server.Utils.Log('SHOP_BUY', source, productModel .. quantityText .. ' | Prix: $' .. finalPrice .. (isVip and ' (VIP)' or ''))
end)

-- =====================================================
-- CALLBACK: Vérifier le statut VIP du joueur
-- =====================================================

RegisterNetEvent('redzone:shop:getVipStatus')
AddEventHandler('redzone:shop:getVipStatus', function()
    local source = source
    if not Redzone.Server.Utils.IsPlayerConnected(source) then return end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local isVip = IsPlayerVip(xPlayer)
    TriggerClientEvent('redzone:shop:vipStatus', source, isVip)
end)

-- =====================================================
-- DÉMARRAGE
-- =====================================================

CreateThread(function()
    InitShopESX()
    BuildValidProductsList()
    Redzone.Shared.Debug('[SERVER/SHOP] Module Shop serveur chargé')
end)
