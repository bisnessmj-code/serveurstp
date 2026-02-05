--[[
    =====================================================
    REDZONE LEAGUE - Système Kill Feed
    =====================================================
    Ce fichier gère l'affichage du kill feed sur l'écran
    des joueurs lorsqu'un kill est effectué dans le redzone.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Killfeed = {}

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

---Événement: Recevoir un kill à afficher
RegisterNetEvent('redzone:killfeed:add')
AddEventHandler('redzone:killfeed:add', function(data)
    if not data then return end
    if not Redzone.Client.Teleport.IsInRedzone() then return end

    Redzone.Shared.Debug('[KILLFEED] Nouveau kill: ', data.killerName, ' -> ', data.victimName)

    -- Envoyer au NUI
    SendNUIMessage({
        action = 'addKillFeed',
        killerName = data.killerName,
        killerId = data.killerId,
        victimName = data.victimName,
        victimId = data.victimId,
    })
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[CLIENT/KILLFEED] Module KillFeed chargé')
