-- ========================================
-- PVP GUNFIGHT - SYSTÈME DE DEBUG CENTRALISÉ
-- Version 2.0.0 - Contrôle par Config
-- ========================================

-- ========================================
-- FONCTIONS DE DEBUG (avec vérification Config)
-- ========================================

function DebugClient(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.client then return end
    
    local formattedMsg = string.format(message, ...)
    print('^6[PVP CLIENT]^0 ' .. formattedMsg)
end

function DebugServer(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.server then return end
    
    local formattedMsg = string.format(message, ...)
    print('^5[PVP SERVER]^0 ' .. formattedMsg)
end

function DebugSuccess(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.success then return end
    
    local formattedMsg = string.format(message, ...)
    print('^2[PVP SUCCESS]^0 ' .. formattedMsg)
end

function DebugWarn(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.warning then return end
    
    local formattedMsg = string.format(message, ...)
    print('^3[PVP WARNING]^0 ' .. formattedMsg)
end

function DebugError(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.error then return end
    
    local formattedMsg = string.format(message, ...)
    print('^1[PVP ERROR]^0 ' .. formattedMsg)
end

function DebugUI(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.ui then return end
    
    local formattedMsg = string.format(message, ...)
    print('^4[PVP UI]^0 ' .. formattedMsg)
end

function DebugBucket(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.bucket then return end
    
    local formattedMsg = string.format(message, ...)
    print('^6[PVP BUCKET]^0 ' .. formattedMsg)
end

function DebugElo(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.elo then return end
    
    local formattedMsg = string.format(message, ...)
    print('^3[PVP ELO]^0 ' .. formattedMsg)
end

function DebugZones(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.zones then return end
    
    local formattedMsg = string.format(message, ...)
    print('^5[PVP ZONES]^0 ' .. formattedMsg)
end

function DebugGroups(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.groups then return end
    
    local formattedMsg = string.format(message, ...)
    print('^2[PVP GROUPS]^0 ' .. formattedMsg)
end

function DebugMatchmaking(message, ...)
    if not Config or not Config.Debug then return end
    if not Config.Debug.enabled then return end
    if not Config.Debug.levels.matchmaking then return end
    
    local formattedMsg = string.format(message, ...)
    print('^4[PVP MATCHMAKING]^0 ' .. formattedMsg)
end

-- ========================================
-- COMMANDE ADMIN: TOGGLE DEBUG EN JEU
-- ========================================
if IsDuplicityVersion() then
    -- VERSION SERVEUR
    RegisterCommand('pvpdebug', function(source, args)
        -- Vérifier permissions admin
        if source ~= 0 and not exports['pvp_gunfight']:IsPlayerAdmin(source) then
            if source > 0 then
                TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
            end
            return
        end
        
        local action = args[1] -- 'on', 'off', ou nom d'un niveau
        
        if not action then
            -- Afficher l'état actuel
            local status = Config.Debug.enabled and '~g~ACTIVÉ' or '~r~DÉSACTIVÉ'
            
            if source == 0 then
                print('[PVP] Debug: ' .. (Config.Debug.enabled and 'ACTIVÉ' or 'DÉSACTIVÉ'))
                print('[PVP] Niveaux actifs:')
                for level, enabled in pairs(Config.Debug.levels) do
                    if enabled then
                        print('  - ' .. level)
                    end
                end
            else
                TriggerClientEvent('esx:showNotification', source, '~b~Debug: ' .. status)
            end
            return
        end
        
        action = action:lower()
        
        if action == 'on' or action == 'true' or action == '1' then
            Config.Debug.enabled = true
            local msg = '✅ Debug ACTIVÉ (tous les niveaux)'
            if source == 0 then
                print('[PVP] ' .. msg)
            else
                TriggerClientEvent('esx:showNotification', source, '~g~' .. msg)
            end
            
        elseif action == 'off' or action == 'false' or action == '0' then
            Config.Debug.enabled = false
            local msg = '❌ Debug DÉSACTIVÉ'
            if source == 0 then
                print('[PVP] ' .. msg)
            else
                TriggerClientEvent('esx:showNotification', source, '~r~' .. msg)
            end
            
        elseif Config.Debug.levels[action] ~= nil then
            -- Toggle un niveau spécifique
            Config.Debug.levels[action] = not Config.Debug.levels[action]
            local status = Config.Debug.levels[action] and 'ACTIVÉ' or 'DÉSACTIVÉ'
            local msg = string.format('Debug %s: %s', action, status)
            
            if source == 0 then
                print('[PVP] ' .. msg)
            else
                TriggerClientEvent('esx:showNotification', source, '~b~' .. msg)
            end
        else
            local msg = 'Usage: /pvpdebug [on|off|niveau]'
            if source == 0 then
                print('[PVP] ' .. msg)
                print('[PVP] Niveaux disponibles: client, server, success, warning, error, ui, bucket, elo, zones, groups, matchmaking')
            else
                TriggerClientEvent('esx:showNotification', source, '~y~' .. msg)
            end
        end
    end, false)
    
else
    -- VERSION CLIENT
    RegisterCommand('pvpdebug', function(args)
        -- Le client demande au serveur de changer le debug
        TriggerServerEvent('pvp:toggleDebug', args)
    end, false)
end

-- ========================================
-- COMMANDE: AFFICHER AIDE DEBUG
-- ========================================
if IsDuplicityVersion() then
    RegisterCommand('pvpdebughelp', function(source)
        if source ~= 0 and not exports['pvp_gunfight']:IsPlayerAdmin(source) then
            if source > 0 then
                TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
            end
            return
        end
        
        local help = [[
========================================
SYSTÈME DE DEBUG PVP GUNFIGHT
========================================

COMMANDES:
  /pvpdebug              - Voir état actuel
  /pvpdebug on           - Activer TOUT le debug
  /pvpdebug off          - Désactiver TOUT le debug
  /pvpdebug [niveau]     - Toggle un niveau spécifique

NIVEAUX DISPONIBLES:
  - client      : Logs client
  - server      : Logs serveur
  - success     : Messages de succès
  - warning     : Avertissements
  - error       : Erreurs critiques
  - ui          : Interface utilisateur
  - bucket      : Routing buckets
  - elo         : Système ELO
  - zones       : Zones de combat
  - groups      : Système de groupes
  - matchmaking : Matchmaking

EXEMPLES:
  /pvpdebug on          → Active tout
  /pvpdebug off         → Désactive tout
  /pvpdebug elo         → Toggle debug ELO
  /pvpdebug error       → Toggle erreurs

CONFIG:
  Éditez config.lua pour définir l'état par défaut
  
========================================
        ]]
        
        if source == 0 then
            print(help)
        else
            for line in help:gmatch("[^\n]+") do
                TriggerClientEvent('esx:showNotification', source, '~b~' .. line)
                Wait(100)
            end
        end
    end, false)
end

-- ========================================
-- MESSAGE DE DÉMARRAGE
-- ========================================
CreateThread(function()
    Wait(1000)
    
    if Config and Config.Debug then
        local status = Config.Debug.enabled and '^2ACTIVÉ^0' or '^1DÉSACTIVÉ^0'
        print('^5========================================^0')
        print('^5[PVP DEBUG] Système initialisé^0')
        print('^5[PVP DEBUG] État: ' .. status)
        
        if Config.Debug.enabled then
            print('^5[PVP DEBUG] Niveaux actifs:^0')
            for level, enabled in pairs(Config.Debug.levels) do
                if enabled then
                    print('^2  ✓ ' .. level .. '^0')
                end
            end
        end
        
        print('^5[PVP DEBUG] Commande: /pvpdebug [on|off|niveau]^0')
        print('^5========================================^0')
    end
end)