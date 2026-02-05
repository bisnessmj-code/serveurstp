--[[
    =====================================================
    REDZONE LEAGUE - Script Principal Client
    =====================================================
    Ce fichier est le point d'entrée du script côté client.
    Il initialise tous les modules et gère les événements globaux.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================

-- Framework ESX
local ESX = nil

-- État d'initialisation
local isInitialized = false

-- =====================================================
-- INITIALISATION DU FRAMEWORK
-- =====================================================

---Initialise la connexion avec ESX
local function InitializeESX()
    -- Attendre que ESX soit prêt
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Wait(100)
    end

    Redzone.Shared.Debug('[MAIN] ESX chargé avec succès')
    return true
end

-- =====================================================
-- NOTE: Les blips sont gérés dans zones.lua
-- Ils n'apparaissent que quand le joueur est dans le redzone
-- =====================================================

-- =====================================================
-- INITIALISATION PRINCIPALE
-- =====================================================

---Fonction principale d'initialisation
local function Initialize()
    if isInitialized then
        Redzone.Shared.Debug('[MAIN] Script déjà initialisé')
        return
    end

    Redzone.Shared.Debug('[MAIN] Démarrage de l\'initialisation...')

    -- Initialisation d'ESX
    InitializeESX()

    -- Attendre que le joueur soit complètement chargé
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    -- NOTE: Les blips ne sont plus créés ici
    -- Ils sont créés dans zones.lua quand le joueur entre dans le redzone

    -- Initialisation des PEDs
    Redzone.Client.Ped.Initialize()

    -- Démarrage du thread d'interaction
    Redzone.Client.Ped.StartInteractionThread()

    -- Démarrage du thread d'affichage du nombre de joueurs au-dessus du PED
    Redzone.Client.Ped.StartPlayerCountDisplayThread()

    -- Démarrage du thread de surveillance des zones
    Redzone.Client.Zones.StartZoneThread()

    -- Démarrage du thread d'interaction des PEDs de sortie
    Redzone.Client.ExitPed.StartInteractionThread()

    -- Démarrage du thread d'interaction des coffres
    Redzone.Client.Stash.StartInteractionThread()

    -- Démarrage du thread d'interaction des véhicules
    Redzone.Client.Vehicle.StartInteractionThread()

    -- Démarrage du thread d'interaction du shop armes
    Redzone.Client.Shop.StartInteractionThread()

    -- Démarrage du thread de détection de mort
    Redzone.Client.Death.StartDeathThread()

    -- Démarrage du thread d'interaction réanimation/transport
    Redzone.Client.Death.StartInteractionThread()

    -- Marquer comme initialisé
    isInitialized = true

    -- Message de confirmation
    Redzone.Shared.Debug(Config.DebugMessages.ScriptLoaded)

    -- Notification au joueur (optionnel, peut être désactivé)
    if Config.Debug then
        Wait(2000) -- Attendre un peu pour que le joueur voit la notification
        Redzone.Client.Utils.NotifyInfo('REDZONE LEAGUE chargé! Interagissez avec le PED pour jouer.')
    end
end

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

---Événement: Joueur chargé (ESX)
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    Redzone.Shared.Debug('[EVENT] esx:playerLoaded déclenché')
    Initialize()
end)

---Événement: Ressource démarrée
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Redzone.Shared.Debug('[EVENT] onClientResourceStart déclenché')

    -- Si le joueur est déjà chargé (reconnexion ou restart de ressource)
    CreateThread(function()
        Wait(1000)
        if not isInitialized then
            Initialize()
        end
    end)
end)

---Événement: Notification depuis le serveur
RegisterNetEvent('redzone:notify')
AddEventHandler('redzone:notify', function(title, message, type, duration)
    Redzone.Client.Utils.Notify(title, message, type, duration)
end)

---Événement: Ouverture forcée du menu
RegisterNetEvent('redzone:openMenu')
AddEventHandler('redzone:openMenu', function()
    Redzone.Client.Menu.Open()
end)

---Événement: Fermeture forcée du menu
RegisterNetEvent('redzone:closeMenu')
AddEventHandler('redzone:closeMenu', function()
    Redzone.Client.Menu.Close()
end)

---Événement: Téléportation forcée vers le redzone
RegisterNetEvent('redzone:forceEnter')
AddEventHandler('redzone:forceEnter', function(spawnId)
    Redzone.Client.Teleport.StartTeleport(spawnId or 1)
end)

---Événement: Sortie forcée du redzone
RegisterNetEvent('redzone:forceLeave')
AddEventHandler('redzone:forceLeave', function()
    Redzone.Client.Teleport.StartLeaving()
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

---Événement: Arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Redzone.Shared.Debug('[MAIN] Nettoyage en cours...')

    -- Fermer le menu si ouvert
    if Redzone.Client.Menu.IsOpen() then
        Redzone.Client.Menu.Close()
    end

    -- Supprimer les PEDs
    Redzone.Client.Ped.DeleteAll()

    Redzone.Shared.Debug('[MAIN] Nettoyage terminé')
end)

-- =====================================================
-- COMMANDES DE DEBUG
-- =====================================================

if Config.Debug then
    -- Commande pour afficher l'état du joueur
    RegisterCommand('redzone_status', function()
        local state = Redzone.Client.Teleport.GetPlayerState()
        local stateNames = {
            [0] = 'OUTSIDE',
            [1] = 'IN_MENU',
            [2] = 'TELEPORTING',
            [3] = 'IN_REDZONE',
            [4] = 'LEAVING'
        }
        print('[REDZONE DEBUG] État du joueur: ' .. (stateNames[state] or 'UNKNOWN'))
        print('[REDZONE DEBUG] Menu ouvert: ' .. tostring(Redzone.Client.Menu.IsOpen()))
        print('[REDZONE DEBUG] Dans le redzone: ' .. tostring(Redzone.Client.Teleport.IsInRedzone()))
    end, false)
end

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/MAIN] Module principal chargé')
