--[[
    =====================================================
    REDZONE LEAGUE - Gestion du Menu NUI
    =====================================================
    Ce fichier gère l'interface NUI du script
    (ouverture, fermeture, communication avec JS).
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Menu = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- État du menu
local isMenuOpen = false

-- =====================================================
-- OUVERTURE / FERMETURE DU MENU
-- =====================================================

---Ouvre le menu NUI
function Redzone.Client.Menu.Open()
    if isMenuOpen then
        Redzone.Shared.Debug('[MENU] Menu déjà ouvert')
        return
    end

    isMenuOpen = true

    -- Préparation des données à envoyer au NUI
    local data = {
        action = 'open',
        config = {
            scriptName = Config.ScriptName,
            gamemodeName = Config.Gamemode.Name,
            gamemodeDescription = Config.Gamemode.Description,
        },
        rules = Config.Rules,
        spawnPoints = Config.SpawnPoints,
    }

    -- Activation du NUI
    SetNuiFocus(Config.NUI.ShowCursor, Config.NUI.ShowCursor)

    -- Envoi des données au NUI
    SendNUIMessage(data)

    Redzone.Shared.Debug(Config.DebugMessages.MenuOpened, GetPlayerServerId(PlayerId()))
end

---Ferme le menu NUI
function Redzone.Client.Menu.Close()
    if not isMenuOpen then
        Redzone.Shared.Debug('[MENU] Menu déjà fermé')
        return
    end

    isMenuOpen = false

    -- Désactivation du focus NUI
    SetNuiFocus(false, false)

    -- Envoi de la commande de fermeture
    SendNUIMessage({
        action = 'close'
    })

    -- Réinitialiser l'état d'interaction
    Redzone.Client.Ped.SetInteracting(false)

    Redzone.Shared.Debug(Config.DebugMessages.MenuClosed)
end

---Vérifie si le menu est ouvert
---@return boolean isOpen True si le menu est ouvert
function Redzone.Client.Menu.IsOpen()
    return isMenuOpen
end

-- =====================================================
-- CALLBACKS NUI (Réception des messages du JS)
-- =====================================================

---Callback: Fermeture du menu depuis le NUI
RegisterNUICallback('closeMenu', function(data, cb)
    Redzone.Shared.Debug('[NUI] Callback: closeMenu')
    Redzone.Client.Menu.Close()
    cb('ok')
end)

---Callback: Sélection d'un point de spawn
RegisterNUICallback('selectSpawn', function(data, cb)
    Redzone.Shared.Debug('[NUI] Callback: selectSpawn - ID: ', data.spawnId)

    -- Fermer le menu
    Redzone.Client.Menu.Close()

    -- Démarrer la téléportation
    if data.spawnId then
        Redzone.Client.Teleport.StartTeleport(data.spawnId)
    end

    cb('ok')
end)

---Callback: Confirmation des règles
RegisterNUICallback('confirmRules', function(data, cb)
    Redzone.Shared.Debug('[NUI] Callback: confirmRules')

    -- Notification de confirmation
    Redzone.Client.Utils.NotifySuccess('Vous avez accepté les règles du REDZONE LEAGUE !')

    cb('ok')
end)

---Callback: Demande des données de configuration
RegisterNUICallback('getData', function(data, cb)
    Redzone.Shared.Debug('[NUI] Callback: getData')

    cb({
        config = {
            scriptName = Config.ScriptName,
            gamemodeName = Config.Gamemode.Name,
            gamemodeDescription = Config.Gamemode.Description,
        },
        rules = Config.Rules,
        spawnPoints = Config.SpawnPoints,
    })
end)

-- =====================================================
-- GESTION DE LA TOUCHE ÉCHAP
-- =====================================================

---Thread pour gérer la fermeture avec Échap
CreateThread(function()
    while true do
        if isMenuOpen and Config.NUI.AllowEscape then
            -- Désactiver la pause menu par défaut
            DisableControlAction(0, 200, true) -- ESC / Pause Menu

            if IsDisabledControlJustPressed(0, 200) then
                Redzone.Client.Menu.Close()
            end
        end
        Wait(0)
    end
end)

-- =====================================================
-- EXPORTS
-- =====================================================

-- Export pour ouvrir le menu depuis d'autres scripts
exports('OpenRedzoneMenu', function()
    Redzone.Client.Menu.Open()
end)

-- Export pour fermer le menu depuis d'autres scripts
exports('CloseRedzoneMenu', function()
    Redzone.Client.Menu.Close()
end)

-- Export pour vérifier si le menu est ouvert
exports('IsRedzoneMenuOpen', function()
    return Redzone.Client.Menu.IsOpen()
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/MENU] Module Menu chargé')
