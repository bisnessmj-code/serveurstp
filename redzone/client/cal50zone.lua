--[[
    =====================================================
    REDZONE LEAGUE - Zone CAL50 (Combat Spéciale)
    =====================================================
    Ce fichier gère la zone CAL50 qui change de position
    automatiquement selon l'intervalle configuré.
    Dans cette zone, seul le CAL50 est autorisé.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Cal50Zone = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Blips de la zone CAL50
local cal50ZoneBlip = nil
local cal50ZoneCircle = nil

-- Index de la position actuelle
local currentPositionIndex = 1

-- Zone actuelle
local currentZone = nil

-- =====================================================
-- FONCTIONS DE GESTION DES BLIPS
-- =====================================================

---Supprime les blips de la zone CAL50
local function DeleteCal50ZoneBlips()
    if cal50ZoneBlip and DoesBlipExist(cal50ZoneBlip) then
        RemoveBlip(cal50ZoneBlip)
        cal50ZoneBlip = nil
    end

    if cal50ZoneCircle and DoesBlipExist(cal50ZoneCircle) then
        RemoveBlip(cal50ZoneCircle)
        cal50ZoneCircle = nil
    end

    Redzone.Shared.Debug('[CAL50ZONE] Blips supprimés')
end

---Crée les blips pour la zone CAL50 à la position donnée
---@param zone table La zone avec coords et name
local function CreateCal50ZoneBlips(zone)
    -- Supprimer les anciens blips
    DeleteCal50ZoneBlips()

    if not zone or not zone.coords then return end

    local coords = vector3(zone.coords.x, zone.coords.y, zone.coords.z)

    -- Créer le blip central (icône)
    cal50ZoneBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(cal50ZoneBlip, Config.Cal50Zone.Blip.Sprite)
    SetBlipDisplay(cal50ZoneBlip, 4)
    SetBlipScale(cal50ZoneBlip, Config.Cal50Zone.Blip.Scale)
    SetBlipColour(cal50ZoneBlip, Config.Cal50Zone.Blip.Color)
    SetBlipAsShortRange(cal50ZoneBlip, false) -- Visible de loin
    SetBlipFlashes(cal50ZoneBlip, true) -- Faire clignoter au changement

    -- Arrêter le clignotement après 5 secondes
    SetTimeout(5000, function()
        if cal50ZoneBlip and DoesBlipExist(cal50ZoneBlip) then
            SetBlipFlashes(cal50ZoneBlip, false)
        end
    end)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Cal50Zone.Blip.Name)
    EndTextCommandSetBlipName(cal50ZoneBlip)

    -- Créer le cercle de zone (rayon configurable)
    cal50ZoneCircle = AddBlipForRadius(coords.x, coords.y, coords.z, Config.Cal50Zone.Radius)
    SetBlipHighDetail(cal50ZoneCircle, true)
    SetBlipColour(cal50ZoneCircle, Config.Cal50Zone.CircleColor)
    SetBlipAlpha(cal50ZoneCircle, Config.Cal50Zone.CircleAlpha)

    currentZone = zone

    Redzone.Shared.Debug('[CAL50ZONE] Blips créés pour: ', zone.name)
end

-- =====================================================
-- FONCTIONS DE CHANGEMENT DE ZONE
-- =====================================================

---Obtient la zone CAL50 actuelle
---@return table|nil zone La zone actuelle
function Redzone.Client.Cal50Zone.GetCurrentZone()
    return currentZone
end

---Vérifie si le joueur est dans la zone CAL50
---@return boolean inZone True si dans la zone
function Redzone.Client.Cal50Zone.IsPlayerInCal50Zone()
    if not currentZone or not currentZone.coords then
        return false
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local zoneCoords = vector3(currentZone.coords.x, currentZone.coords.y, currentZone.coords.z)
    local distance = #(playerCoords - zoneCoords)

    return distance <= Config.Cal50Zone.Radius
end

-- =====================================================
-- INITIALISATION ET SYNCHRONISATION
-- =====================================================

---Initialise la zone CAL50
---NOTE: La zone sera synchronisée par le serveur via 'redzone:syncCal50Zone'
function Redzone.Client.Cal50Zone.Initialize()
    if not Config.Cal50Zone.Enabled then
        Redzone.Shared.Debug('[CAL50ZONE] Système désactivé dans la config')
        return
    end

    -- La zone sera créée quand le serveur enverra la synchronisation
    Redzone.Shared.Debug('[CAL50ZONE] En attente de synchronisation du serveur...')
end

---Vérifie si le joueur est dans le redzone (avec vérification de sécurité)
local function IsInRedzoneSafe()
    if Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone then
        return Redzone.Client.Teleport.IsInRedzone()
    end
    return false
end

---Change la zone CAL50 vers un index spécifique (appelé par le serveur)
---@param positionIndex number L'index de la nouvelle position
function Redzone.Client.Cal50Zone.SetZoneIndex(positionIndex)
    local positions = Config.Cal50Zone.Positions
    if not positions or #positions == 0 then return end

    -- Vérifier que l'index est valide
    if positionIndex < 1 or positionIndex > #positions then
        Redzone.Shared.Debug('[CAL50ZONE] Index de zone invalide: ', positionIndex)
        return
    end

    -- Ne rien faire si c'est déjà la même zone
    if currentPositionIndex == positionIndex and currentZone then
        Redzone.Shared.Debug('[CAL50ZONE] Zone déjà à l\'index: ', positionIndex)
        return
    end

    local oldIndex = currentPositionIndex
    currentPositionIndex = positionIndex
    local newZone = positions[currentPositionIndex]

    -- Créer les nouveaux blips
    CreateCal50ZoneBlips(newZone)

    -- Notifier le joueur seulement si c'est un changement (pas la première synchronisation)
    if oldIndex ~= positionIndex and currentZone then
        local message = string.format(Config.Cal50Zone.Messages.ZoneChanged, newZone.name)
        if Redzone.Client.Utils and Redzone.Client.Utils.NotifyInfo then
            Redzone.Client.Utils.NotifyInfo(message)
        end
    end

    Redzone.Shared.Debug('[CAL50ZONE] Zone synchronisée vers: ', newZone.name, ' (index: ', positionIndex, ')')
end

---Event: Synchronisation de la zone CAL50 depuis le serveur
RegisterNetEvent('redzone:syncCal50Zone')
AddEventHandler('redzone:syncCal50Zone', function(positionIndex)
    if not Config.Cal50Zone.Enabled then return end

    -- Vérifier si on est dans le redzone
    if IsInRedzoneSafe() then
        Redzone.Client.Cal50Zone.SetZoneIndex(positionIndex)
    end
end)

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur entre dans le redzone
function Redzone.Client.Cal50Zone.OnEnterRedzone()
    if not Config.Cal50Zone.Enabled then return end

    Redzone.Shared.Debug('[CAL50ZONE] Joueur entré dans le redzone')

    -- Initialiser la zone CAL50
    Redzone.Client.Cal50Zone.Initialize()

    -- Notifier le joueur de la zone active
    if currentZone then
        local message = string.format(Config.Cal50Zone.Messages.ZoneActive, currentZone.name)
        if Redzone.Client.Utils and Redzone.Client.Utils.NotifyInfo then
            Redzone.Client.Utils.NotifyInfo(message)
        end
    end
end

---Appelé quand le joueur quitte le redzone
function Redzone.Client.Cal50Zone.OnLeaveRedzone()
    Redzone.Shared.Debug('[CAL50ZONE] Joueur sorti du redzone')
    DeleteCal50ZoneBlips()
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetCurrentCal50Zone', function()
    return currentZone
end)

exports('IsInCal50Zone', function()
    return Redzone.Client.Cal50Zone.IsPlayerInCal50Zone()
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    DeleteCal50ZoneBlips()
    Redzone.Shared.Debug('[CAL50ZONE] Nettoyage effectué')
end)

-- =====================================================
-- INITIALISATION AU DÉMARRAGE
-- =====================================================

CreateThread(function()
    -- Attendre que les autres modules soient chargés
    Wait(2000)

    Redzone.Shared.Debug('[CLIENT/CAL50ZONE] Module Zone CAL50 chargé (synchronisation serveur)')
end)
