--[[
    =====================================================
    REDZONE LEAGUE - Système de Shop Armes
    =====================================================
    Ce fichier gère les PEDs shop armes et l'ouverture
    de l'interface NUI pour sélectionner des armes.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Shop = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Stockage des PEDs shop créés
local shopPeds = {}

-- État d'interaction
local isNearShop = false
local currentShopPed = nil

-- État du shop NUI
local isShopOpen = false

-- Statut VIP du joueur
local isPlayerVip = false

-- =====================================================
-- CRÉATION DES PEDS SHOP
-- =====================================================

---Crée un PED shop avec les paramètres spécifiés
---@param pedConfig table Configuration du PED
---@return number|nil pedHandle Le handle du PED créé ou nil si erreur
local function CreateShopPed(pedConfig)
    if not pedConfig or not pedConfig.Model or not pedConfig.Coords then
        Redzone.Shared.Debug('[SHOP/ERROR] Configuration invalide pour la création du PED shop')
        return nil
    end

    local modelHash = GetHashKey(pedConfig.Model)
    if not Redzone.Client.Utils.LoadModel(modelHash) then
        Redzone.Shared.Debug('[SHOP/ERROR] Impossible de charger le modèle: ', pedConfig.Model)
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
        Redzone.Shared.Debug('[SHOP] PED shop créé: ', pedConfig.name)

        return ped
    end

    Redzone.Shared.Debug('[SHOP/ERROR] Échec de la création du PED shop')
    return nil
end

---Supprime un PED shop
---@param ped number Le handle du PED à supprimer
local function DeleteShopPed(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
        Redzone.Shared.Debug('[SHOP] PED shop supprimé')
    end
end

-- =====================================================
-- INITIALISATION DES PEDS SHOP
-- =====================================================

---Crée tous les PEDs shop configurés
function Redzone.Client.Shop.CreateAllPeds()
    Redzone.Client.Shop.DeleteAllPeds()

    for _, location in ipairs(Config.ShopPeds.Locations) do
        local ped = CreateShopPed(location)
        if ped then
            shopPeds[location.id] = {
                ped = ped,
                config = location
            }
        end
    end

    Redzone.Shared.Debug('[SHOP] Tous les PEDs shop ont été créés')
end

---Supprime tous les PEDs shop
function Redzone.Client.Shop.DeleteAllPeds()
    for id, data in pairs(shopPeds) do
        DeleteShopPed(data.ped)
        shopPeds[id] = nil
    end
    Redzone.Shared.Debug('[SHOP] Tous les PEDs shop ont été supprimés')
end

-- =====================================================
-- INTERACTION AVEC LE SHOP
-- =====================================================

---Vérifie si le joueur est proche d'un PED shop
---@return boolean isNear True si proche d'un PED shop
---@return table|nil shopData Les données du PED shop le plus proche
function Redzone.Client.Shop.IsPlayerNearShopPed()
    local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
    local closestDistance = Config.Interaction.InteractDistance
    local closestShop = nil

    for id, data in pairs(shopPeds) do
        if DoesEntityExist(data.ped) then
            local pedCoords = Redzone.Shared.Vec4ToVec3(data.config.Coords)
            local distance = #(playerCoords - pedCoords)

            if distance <= closestDistance then
                closestDistance = distance
                closestShop = data
            end
        end
    end

    return closestShop ~= nil, closestShop
end

---Ouvre le shop NUI
function Redzone.Client.Shop.OpenShop()
    if isShopOpen then return end

    Redzone.Shared.Debug('[SHOP] Ouverture du shop armes')

    isShopOpen = true

    -- Demander le statut VIP au serveur
    TriggerServerEvent('redzone:shop:getVipStatus')

    -- Préparer les données des produits pour le NUI (avec prix et images)
    local productsData = {}
    for category, products in pairs(Config.ShopPeds.Products) do
        productsData[category] = products
    end

    -- Envoyer au NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openShop',
        products = productsData,
        isVip = isPlayerVip,
        vipDiscount = Config.ShopPeds.Settings.VipDiscount,
    })
end

---Ferme le shop NUI
function Redzone.Client.Shop.CloseShop()
    if not isShopOpen then return end

    Redzone.Shared.Debug('[SHOP] Fermeture du shop armes')

    isShopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeShop',
    })
end

-- =====================================================
-- NUI CALLBACKS
-- =====================================================

---Callback: Fermer le shop
RegisterNUICallback('closeShop', function(data, cb)
    Redzone.Client.Shop.CloseShop()
    cb('ok')
end)

---Callback: Acheter un produit
RegisterNUICallback('buyWeapon', function(data, cb)
    if not data or not data.model then
        cb('error')
        return
    end

    local quantity = data.quantity or nil
    Redzone.Shared.Debug('[SHOP] Achat: ', data.model, ' x', tostring(quantity or 1))

    -- Demander au serveur d'acheter le produit (validation + paiement côté serveur)
    TriggerServerEvent('redzone:shop:buyWeapon', data.model, quantity)

    -- Fermer le shop
    Redzone.Client.Shop.CloseShop()

    cb('ok')
end)

-- =====================================================
-- ÉVÉNEMENTS SERVEUR
-- =====================================================

---Réception du statut VIP depuis le serveur
RegisterNetEvent('redzone:shop:vipStatus')
AddEventHandler('redzone:shop:vipStatus', function(vipStatus)
    isPlayerVip = vipStatus

    -- Mettre à jour le NUI si le shop est ouvert
    if isShopOpen then
        SendNUIMessage({
            action = 'updateVipStatus',
            isVip = isPlayerVip,
            vipDiscount = Config.ShopPeds.Settings.VipDiscount,
        })
    end

    Redzone.Shared.Debug('[SHOP] Statut VIP reçu: ', tostring(isPlayerVip))
end)

---Réception des munitions depuis le serveur
RegisterNetEvent('redzone:shop:giveAmmo')
AddEventHandler('redzone:shop:giveAmmo', function(ammoType, amount)
    local playerPed = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(playerPed)

    -- Ajouter les munitions à l'arme actuelle si compatible, sinon à toutes les armes du type
    local ammoHash = GetHashKey(ammoType)

    -- Liste des armes par type de munitions
    local weaponsByAmmo = {
        ['AMMO_PISTOL'] = {'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL', 'WEAPON_CERAMICPISTOL', 'WEAPON_REVOLVER', 'WEAPON_REVOLVER_MK2', 'WEAPON_DOUBLEACTION', 'WEAPON_NAVYREVOLVER', 'WEAPON_MARKSMANPISTOL'},
        ['AMMO_SMG'] = {'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW', 'WEAPON_MACHINEPISTOL', 'WEAPON_MINISMG'},
        ['AMMO_RIFLE'] = {'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE', 'WEAPON_CARBINERIFLE_MK2', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE', 'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE', 'WEAPON_BULLPUPRIFLE_MK2', 'WEAPON_COMPACTRIFLE', 'WEAPON_MILITARYRIFLE', 'WEAPON_HEAVYRIFLE'},
        ['AMMO_SHOTGUN'] = {'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_ASSAULTSHOTGUN', 'WEAPON_BULLPUPSHOTGUN', 'WEAPON_HEAVYSHOTGUN', 'WEAPON_DBSHOTGUN', 'WEAPON_AUTOSHOTGUN', 'WEAPON_COMBATSHOTGUN'},
        ['AMMO_MG'] = {'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2', 'WEAPON_GUSENBERG'},
    }

    local weapons = weaponsByAmmo[ammoType]
    if weapons then
        for _, weaponName in ipairs(weapons) do
            local weaponHash = GetHashKey(weaponName)
            if HasPedGotWeapon(playerPed, weaponHash, false) then
                AddAmmoToPed(playerPed, weaponHash, amount)
            end
        end
    end

    Redzone.Shared.Debug('[SHOP] Munitions ajoutées: ', ammoType, ' x', amount)
end)

---Réception de l'armure depuis le serveur
RegisterNetEvent('redzone:shop:giveArmor')
AddEventHandler('redzone:shop:giveArmor', function()
    local playerPed = PlayerPedId()
    SetPedArmour(playerPed, 100)
    Redzone.Shared.Debug('[SHOP] Armure ajoutée: 100')
end)

-- =====================================================
-- THREAD D'INTERACTION
-- =====================================================

---Démarre le thread d'interaction avec les PEDs shop
function Redzone.Client.Shop.StartInteractionThread()
    Redzone.Shared.Debug('[SHOP] Démarrage du thread d\'interaction shop')

    CreateThread(function()
        while true do
            local sleep = 1000

            if Redzone.Client.Teleport.IsInRedzone() then
                sleep = 200

                -- Afficher le texte 3D [ARMURERIE] au-dessus des PEDs à moins de 15m
                local playerCoords = Redzone.Client.Utils.GetPlayerCoords()
                for _, data in pairs(shopPeds) do
                    if DoesEntityExist(data.ped) then
                        local pedCoords = GetEntityCoords(data.ped)
                        local dist = #(playerCoords - pedCoords)
                        if dist <= 15.0 then
                            sleep = 0
                            Redzone.Client.Utils.DrawText3D(vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.3), '[ARMURERIE]', 0.45)
                        end
                    end
                end

                if not isShopOpen then
                    local near, shopData = Redzone.Client.Shop.IsPlayerNearShopPed()

                    if near then
                        sleep = 0
                        isNearShop = true
                        currentShopPed = shopData

                        Redzone.Client.Utils.ShowHelpText(Config.ShopPeds.Settings.HelpText)

                        if Redzone.Client.Utils.IsKeyJustPressed(Config.Interaction.InteractKey) then
                            Redzone.Client.Shop.OpenShop()
                        end
                    else
                        isNearShop = false
                        currentShopPed = nil
                    end
                end
            else
                isNearShop = false
                currentShopPed = nil
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur entre dans le redzone
function Redzone.Client.Shop.OnEnterRedzone()
    Redzone.Shared.Debug('[SHOP] Joueur entré dans le redzone - Création des PEDs shop')
    Redzone.Client.Shop.CreateAllPeds()
end

---Appelé quand le joueur quitte le redzone
function Redzone.Client.Shop.OnLeaveRedzone()
    Redzone.Shared.Debug('[SHOP] Joueur sorti du redzone - Suppression des PEDs shop')
    Redzone.Client.Shop.DeleteAllPeds()
    Redzone.Client.Shop.CloseShop()
end

-- =====================================================
-- NETTOYAGE
-- =====================================================

---Événement: Arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Redzone.Client.Shop.DeleteAllPeds()
    Redzone.Client.Shop.CloseShop()

    Redzone.Shared.Debug('[SHOP] Nettoyage des PEDs shop effectué')
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/SHOP] Module Shop chargé')
