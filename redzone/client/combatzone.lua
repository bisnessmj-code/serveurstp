--[[
    =====================================================
    REDZONE LEAGUE - Zone de Combat Dynamique
    =====================================================
    Ce fichier gère la zone de combat qui change de position
    automatiquement selon l'intervalle configuré.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.CombatZone = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Blips de la zone de combat
local combatZoneBlip = nil
local combatZoneCircle = nil

-- Index de la position actuelle
local currentPositionIndex = 1

-- Zone actuelle
local currentZone = nil

-- Timer pour le changement de zone
local lastZoneChange = 0

-- =====================================================
-- FONCTIONS DE GESTION DES BLIPS
-- =====================================================

---Supprime les blips de la zone de combat
local function DeleteCombatZoneBlips()
    if combatZoneBlip and DoesBlipExist(combatZoneBlip) then
        RemoveBlip(combatZoneBlip)
        combatZoneBlip = nil
    end

    if combatZoneCircle and DoesBlipExist(combatZoneCircle) then
        RemoveBlip(combatZoneCircle)
        combatZoneCircle = nil
    end

    Redzone.Shared.Debug('[COMBATZONE] Blips supprimés')
end

---Crée les blips pour la zone de combat à la position donnée
---@param zone table La zone avec coords et name
local function CreateCombatZoneBlips(zone)
    -- Supprimer les anciens blips
    DeleteCombatZoneBlips()

    if not zone or not zone.coords then return end

    local coords = vector3(zone.coords.x, zone.coords.y, zone.coords.z)

    -- Créer le blip central (icône)
    combatZoneBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(combatZoneBlip, Config.CombatZone.Blip.Sprite)
    SetBlipDisplay(combatZoneBlip, 4)
    SetBlipScale(combatZoneBlip, Config.CombatZone.Blip.Scale)
    SetBlipColour(combatZoneBlip, Config.CombatZone.Blip.Color)
    SetBlipAsShortRange(combatZoneBlip, false) -- Visible de loin
    SetBlipFlashes(combatZoneBlip, true) -- Faire clignoter au changement

    -- Arrêter le clignotement après 5 secondes
    SetTimeout(5000, function()
        if combatZoneBlip and DoesBlipExist(combatZoneBlip) then
            SetBlipFlashes(combatZoneBlip, false)
        end
    end)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.CombatZone.Blip.Name)
    EndTextCommandSetBlipName(combatZoneBlip)

    -- Créer le cercle de zone (rayon configurable)
    combatZoneCircle = AddBlipForRadius(coords.x, coords.y, coords.z, Config.CombatZone.Radius)
    SetBlipHighDetail(combatZoneCircle, true)
    SetBlipColour(combatZoneCircle, Config.CombatZone.CircleColor)
    SetBlipAlpha(combatZoneCircle, Config.CombatZone.CircleAlpha)

    currentZone = zone

    Redzone.Shared.Debug('[COMBATZONE] Blips créés pour: ', zone.name)
end

-- =====================================================
-- FONCTIONS DE CHANGEMENT DE ZONE
-- =====================================================

---Change la zone de combat vers la prochaine position
function Redzone.Client.CombatZone.ChangeZone()
    local positions = Config.CombatZone.Positions
    if not positions or #positions == 0 then return end

    -- Passer à la position suivante (boucle)
    currentPositionIndex = currentPositionIndex + 1
    if currentPositionIndex > #positions then
        currentPositionIndex = 1
    end

    local newZone = positions[currentPositionIndex]

    -- Créer les nouveaux blips
    CreateCombatZoneBlips(newZone)

    -- Notifier le joueur
    local message = string.format(Config.CombatZone.Messages.ZoneChanged, newZone.name)
    if Redzone.Client.Utils and Redzone.Client.Utils.NotifyWarning then
        Redzone.Client.Utils.NotifyWarning(message)
    end

    -- Mettre à jour le timer
    lastZoneChange = GetGameTimer()

    Redzone.Shared.Debug('[COMBATZONE] Zone changée vers: ', newZone.name)
end

---Obtient la zone de combat actuelle
---@return table|nil zone La zone actuelle
function Redzone.Client.CombatZone.GetCurrentZone()
    return currentZone
end

---Vérifie si le joueur est dans la zone de combat
---@return boolean inZone True si dans la zone
function Redzone.Client.CombatZone.IsPlayerInCombatZone()
    if not currentZone or not currentZone.coords then
        return false
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local zoneCoords = vector3(currentZone.coords.x, currentZone.coords.y, currentZone.coords.z)
    local distance = #(playerCoords - zoneCoords)

    return distance <= Config.CombatZone.Radius
end

-- =====================================================
-- INITIALISATION ET THREAD PRINCIPAL
-- =====================================================

---Initialise la zone de combat
---NOTE: La zone sera synchronisée par le serveur via 'redzone:syncCombatZone'
function Redzone.Client.CombatZone.Initialize()
    if not Config.CombatZone.Enabled then
        Redzone.Shared.Debug('[COMBATZONE] Système désactivé dans la config')
        return
    end

    -- La zone sera créée quand le serveur enverra la synchronisation
    -- Ne pas initialiser à l'index 1 ici, attendre le serveur
    Redzone.Shared.Debug('[COMBATZONE] En attente de synchronisation du serveur...')
end

---Vérifie si le joueur est dans le redzone (avec vérification de sécurité)
local function IsInRedzoneSafe()
    if Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone then
        return Redzone.Client.Teleport.IsInRedzone()
    end
    return false
end

-- NOTE: Le changement automatique de zone est maintenant géré côté serveur
-- pour assurer la synchronisation entre tous les joueurs.
-- Le client écoute l'event 'redzone:syncCombatZone' pour recevoir les mises à jour.

---Change la zone de combat vers un index spécifique (appelé par le serveur)
---@param positionIndex number L'index de la nouvelle position
function Redzone.Client.CombatZone.SetZoneIndex(positionIndex)
    local positions = Config.CombatZone.Positions
    if not positions or #positions == 0 then return end

    -- Vérifier que l'index est valide
    if positionIndex < 1 or positionIndex > #positions then
        Redzone.Shared.Debug('[COMBATZONE] Index de zone invalide: ', positionIndex)
        return
    end

    -- Ne rien faire si c'est déjà la même zone
    if currentPositionIndex == positionIndex and currentZone then
        Redzone.Shared.Debug('[COMBATZONE] Zone déjà à l\'index: ', positionIndex)
        return
    end

    local oldIndex = currentPositionIndex
    currentPositionIndex = positionIndex
    local newZone = positions[currentPositionIndex]

    -- Créer les nouveaux blips
    CreateCombatZoneBlips(newZone)

    -- Notifier le joueur seulement si c'est un changement (pas la première synchronisation)
    if oldIndex ~= positionIndex and currentZone then
        local message = string.format(Config.CombatZone.Messages.ZoneChanged, newZone.name)
        if Redzone.Client.Utils and Redzone.Client.Utils.NotifyWarning then
            Redzone.Client.Utils.NotifyWarning(message)
        end
    end

    Redzone.Shared.Debug('[COMBATZONE] Zone synchronisée vers: ', newZone.name, ' (index: ', positionIndex, ')')
end

---Event: Synchronisation de la zone de combat depuis le serveur
RegisterNetEvent('redzone:syncCombatZone')
AddEventHandler('redzone:syncCombatZone', function(positionIndex)
    if not Config.CombatZone.Enabled then return end

    -- Vérifier si on est dans le redzone
    if IsInRedzoneSafe() then
        Redzone.Client.CombatZone.SetZoneIndex(positionIndex)
    end
end)

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur entre dans le redzone
function Redzone.Client.CombatZone.OnEnterRedzone()
    if not Config.CombatZone.Enabled then return end

    Redzone.Shared.Debug('[COMBATZONE] Joueur entré dans le redzone')

    -- Initialiser la zone de combat
    Redzone.Client.CombatZone.Initialize()

    -- Notifier le joueur de la zone active
    if currentZone then
        local message = string.format(Config.CombatZone.Messages.ZoneActive, currentZone.name)
        if Redzone.Client.Utils and Redzone.Client.Utils.NotifyInfo then
            Redzone.Client.Utils.NotifyInfo(message)
        end
    end
end

---Appelé quand le joueur quitte le redzone
function Redzone.Client.CombatZone.OnLeaveRedzone()
    Redzone.Shared.Debug('[COMBATZONE] Joueur sorti du redzone')
    DeleteCombatZoneBlips()
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetCurrentCombatZone', function()
    return currentZone
end)

exports('IsInCombatZone', function()
    return Redzone.Client.CombatZone.IsPlayerInCombatZone()
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    DeleteCombatZoneBlips()
    Redzone.Shared.Debug('[COMBATZONE] Nettoyage effectué')
end)

-- =====================================================
-- INITIALISATION AU DÉMARRAGE
-- =====================================================

CreateThread(function()
    -- Attendre que les autres modules soient chargés
    Wait(2000)

    -- NOTE: Le thread de changement automatique est maintenant géré côté serveur
    -- Le client écoute l'event 'redzone:syncCombatZone' pour les mises à jour

    Redzone.Shared.Debug('[CLIENT/COMBATZONE] Module Zone de Combat chargé (synchronisation serveur)')
end)
