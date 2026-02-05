--[[
    =====================================================
    REDZONE LEAGUE - Système de Press (Serveur)
    =====================================================
    Ce fichier gère la logique serveur du système de press.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

---Événement: Un joueur presse un autre joueur
RegisterNetEvent('redzone:press:pressPlayer')
AddEventHandler('redzone:press:pressPlayer', function(targetServerId)
    local source = source

    -- Vérifier que la cible existe
    if not GetPlayerPed(targetServerId) or GetPlayerPed(targetServerId) == 0 then
        Redzone.Shared.Debug('[PRESS] Cible invalide: ', targetServerId)
        return
    end

    -- Vérifier que ce n'est pas soi-même
    if source == targetServerId then
        Redzone.Shared.Debug('[PRESS] Tentative de se presser soi-même')
        return
    end

    -- Notifier la cible qu'elle est pressée
    TriggerClientEvent('redzone:press:beingPressed', targetServerId, source)

    Redzone.Shared.Debug('[PRESS] Joueur ', source, ' a pressé joueur ', targetServerId)
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[SERVER/PRESS] Module Press serveur chargé')
