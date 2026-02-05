-- ========================================
-- PVP GUNFIGHT - BLOQUEUR DE COMMANDES SERVEUR
-- Version 1.0.0 - Protection serveur
-- ========================================

DebugServer('Module Command Blocker Server chargé')

-- ========================================
-- LISTE COMMANDES BLOQUÉES
-- ========================================
local BLOCKED_COMMANDS_SERVER = {
    'spawn',
}

-- ========================================
-- VÉRIFIER SI JOUEUR EN MATCH
-- ========================================
local function IsPlayerInPVP(playerId)
    -- Vérifier si en match
    if playerCurrentMatch[playerId] then
        return true
    end
    
    -- Vérifier si en queue
    if playersInQueue[playerId] then
        return true
    end
    
    return false
end

-- ========================================
-- BLOQUER COMMANDES
-- ========================================
for i = 1, #BLOCKED_COMMANDS_SERVER do
    local commandName = BLOCKED_COMMANDS_SERVER[i]
    
    RegisterCommand(commandName, function(source, args, rawCommand)
        if source == 0 then
            return -- Console = toujours autorisée
        end
        
        if IsPlayerInPVP(source) then
            TriggerClientEvent('brutal_notify:SendAlert', source,
                'Commande Bloquée',
                'Impossible d\'utiliser /' .. commandName .. ' en PVP!',
                4000,
                'error'
            )
            
            DebugServer('🚫 Commande bloquée: /' .. commandName .. ' (Joueur %d en PVP)', source)
            
            return -- Bloquer
        end
    end, false)
end

DebugSuccess('✅ %d commande(s) serveur bloquée(s) en PVP', #BLOCKED_COMMANDS_SERVER)