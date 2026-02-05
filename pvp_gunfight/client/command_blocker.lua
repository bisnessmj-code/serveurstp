-- ========================================
-- PVP GUNFIGHT - BLOQUEUR DE COMMANDES
-- Version 1.0.0 - Bloquer commandes externes en match
-- ========================================

DebugClient('Module Command Blocker chargé')

-- ========================================
-- CONFIGURATION
-- ========================================
local BLOCKED_COMMANDS = {
    'spawn',      -- qs-multicharacter
}

-- ========================================
-- FONCTION: BLOQUER COMMANDE
-- ========================================
local function BlockCommand(commandName)
    RegisterCommand(commandName, function()
        if IsInMatch() or IsInQueue() then
            -- ✅ BRUTAL NOTIFY
            exports['brutal_notify']:SendAlert(
                'Commande Bloquée',
                'Impossible d\'utiliser /' .. commandName .. ' en PVP!',
                4000,
                'error'
            )
            
            DebugClient('🚫 Commande bloquée: /' .. commandName .. ' (en PVP)')
            
            return -- Bloquer l'exécution
        end
    end, false)
end

-- ========================================
-- BLOQUER TOUTES LES COMMANDES
-- ========================================
CreateThread(function()
    Wait(2000) -- Attendre que tout soit chargé
    
    for i = 1, #BLOCKED_COMMANDS do
        BlockCommand(BLOCKED_COMMANDS[i])
    end
    
    DebugSuccess('✅ %d commande(s) bloquée(s) en match PVP', #BLOCKED_COMMANDS)
end)

-- ========================================
-- ALTERNATIVE: SUGGÉRER ANNULATION RECHERCHE
-- ========================================
RegisterCommand('cancelquit', function()
    if IsInQueue() then
        TriggerServerEvent('pvp:cancelSearch')
        exports['brutal_notify']:SendAlert(
            'PVP Gunfight',
            'Recherche annulée - Vous pouvez maintenant quitter',
            3000,
            'success'
        )
    elseif IsInMatch() then
        exports['brutal_notify']:SendAlert(
            'PVP Gunfight',
            'Vous êtes en match! Attendez la fin ou contactez un admin',
            4000,
            'warning'
        )
    else
        exports['brutal_notify']:SendAlert(
            'PVP Gunfight',
            'Vous n\'êtes pas en PVP',
            2000,
            'info'
        )
    end
end, false)

DebugSuccess('Module Command Blocker initialisé')