--[[
    =====================================================
    REDZONE LEAGUE - Système de Squad (Serveur)
    =====================================================
    Ce fichier gère la logique serveur du système de squad.
]]

Redzone = Redzone or {}
Redzone.Server = Redzone.Server or {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

-- Squads actifs: {[squadId] = {id, host, members = {}, pendingInvites = {}}}
local activeSquads = {}

-- Index inversé: {[playerId] = squadId}
local playerSquads = {}

-- Invitations en attente: {[playerId] = {squadId, hostId, hostName, expireTime}}
local pendingInvites = {}

-- Compteur d'ID de squad
local squadIdCounter = 0

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Génère un nouvel ID de squad
---@return number
local function GenerateSquadId()
    squadIdCounter = squadIdCounter + 1
    return squadIdCounter
end

---Obtient le nom d'un joueur
---@param playerId number
---@return string
local function GetPlayerNameSafe(playerId)
    local name = GetPlayerName(playerId)
    if name and name ~= '' then
        return name
    end
    return 'Joueur ' .. playerId
end

---Vérifie si un joueur est dans le redzone
---@param playerId number
---@return boolean
local function IsPlayerInRedzone(playerId)
    -- On fait confiance au client pour ça, mais on pourrait ajouter une vérification serveur
    return true
end

---Obtient le squad d'un joueur
---@param playerId number
---@return table|nil
local function GetPlayerSquad(playerId)
    local squadId = playerSquads[playerId]
    if squadId then
        return activeSquads[squadId]
    end
    return nil
end

---Notifie tous les membres d'un squad
---@param squadId number
---@param eventName string
---@param ... any
local function NotifySquadMembers(squadId, eventName, ...)
    local squad = activeSquads[squadId]
    if not squad then return end

    for _, memberId in ipairs(squad.members) do
        TriggerClientEvent(eventName, memberId, ...)
    end
end

---Notifie tous les membres sauf un
---@param squadId number
---@param excludeId number
---@param eventName string
---@param ... any
local function NotifySquadMembersExcept(squadId, excludeId, eventName, ...)
    local squad = activeSquads[squadId]
    if not squad then return end

    for _, memberId in ipairs(squad.members) do
        if memberId ~= excludeId then
            TriggerClientEvent(eventName, memberId, ...)
        end
    end
end

---Retire un joueur d'un squad
---@param playerId number
---@param reason string 'left' | 'kicked' | 'disconnected' | 'left_redzone'
local function RemovePlayerFromSquad(playerId, reason)
    local squadId = playerSquads[playerId]
    if not squadId then return end

    local squad = activeSquads[squadId]
    if not squad then
        playerSquads[playerId] = nil
        return
    end

    local playerName = GetPlayerNameSafe(playerId)

    -- Retirer le joueur de la liste des membres
    for i, memberId in ipairs(squad.members) do
        if memberId == playerId then
            table.remove(squad.members, i)
            break
        end
    end

    playerSquads[playerId] = nil

    -- Si c'était l'hôte, dissoudre le squad
    if squad.host == playerId then
        -- Notifier tous les autres membres
        for _, memberId in ipairs(squad.members) do
            TriggerClientEvent('redzone:squad:disbanded', memberId)
            playerSquads[memberId] = nil
        end

        -- Supprimer le squad
        activeSquads[squadId] = nil

        Redzone.Shared.Debug('[SQUAD] Squad ', squadId, ' dissous (hôte parti)')
    else
        -- Notifier les autres membres
        if reason == 'kicked' then
            NotifySquadMembers(squadId, 'redzone:squad:playerKicked', playerId, playerName)
            TriggerClientEvent('redzone:squad:kicked', playerId)
        elseif reason == 'left' then
            NotifySquadMembers(squadId, 'redzone:squad:playerLeft', playerId, playerName)
            TriggerClientEvent('redzone:squad:left', playerId)
        elseif reason == 'disconnected' or reason == 'left_redzone' then
            NotifySquadMembers(squadId, 'redzone:squad:playerLeft', playerId, playerName)
        end

        -- Mettre à jour le squad pour les membres restants
        NotifySquadMembers(squadId, 'redzone:squad:updated', squad)

        Redzone.Shared.Debug('[SQUAD] Joueur ', playerId, ' retiré du squad ', squadId, ' (', reason, ')')
    end
end

-- =====================================================
-- ÉVÉNEMENTS
-- =====================================================

---Événement: Demande des données du squad
RegisterNetEvent('redzone:squad:requestData')
AddEventHandler('redzone:squad:requestData', function()
    local source = source

    local squad = GetPlayerSquad(source)
    local invite = pendingInvites[source]

    -- Vérifier si l'invitation a expiré
    if invite and os.time() > invite.expireTime then
        pendingInvites[source] = nil
        invite = nil
    end

    TriggerClientEvent('redzone:squad:data', source, squad, invite)
end)

---Événement: Créer un squad
RegisterNetEvent('redzone:squad:create')
AddEventHandler('redzone:squad:create', function()
    local source = source

    -- Vérifier si déjà dans un squad
    if playerSquads[source] then
        TriggerClientEvent('redzone:squad:error', source, 'AlreadyInSquad')
        return
    end

    -- Créer le squad
    local squadId = GenerateSquadId()
    local squad = {
        id = squadId,
        host = source,
        members = { source },
    }

    activeSquads[squadId] = squad
    playerSquads[source] = squadId

    TriggerClientEvent('redzone:squad:created', source, squad)

    Redzone.Shared.Debug('[SQUAD] Squad ', squadId, ' créé par joueur ', source)
end)

---Événement: Quitter le squad
RegisterNetEvent('redzone:squad:leave')
AddEventHandler('redzone:squad:leave', function()
    local source = source

    if not playerSquads[source] then
        TriggerClientEvent('redzone:squad:error', source, 'NotInSquad')
        return
    end

    RemovePlayerFromSquad(source, 'left')
end)

---Événement: Dissoudre le squad
RegisterNetEvent('redzone:squad:disband')
AddEventHandler('redzone:squad:disband', function()
    local source = source

    local squad = GetPlayerSquad(source)
    if not squad then
        TriggerClientEvent('redzone:squad:error', source, 'NotInSquad')
        return
    end

    if squad.host ~= source then
        TriggerClientEvent('redzone:squad:error', source, 'NotHost')
        return
    end

    -- Notifier tous les membres
    NotifySquadMembers(squad.id, 'redzone:squad:disbanded')

    -- Nettoyer
    for _, memberId in ipairs(squad.members) do
        playerSquads[memberId] = nil
    end

    activeSquads[squad.id] = nil

    Redzone.Shared.Debug('[SQUAD] Squad ', squad.id, ' dissous par l\'hôte')
end)

---Événement: Inviter un joueur
RegisterNetEvent('redzone:squad:invite')
AddEventHandler('redzone:squad:invite', function(targetId)
    local source = source

    -- Vérifier si l'inviteur est dans un squad
    local squad = GetPlayerSquad(source)
    if not squad then
        TriggerClientEvent('redzone:squad:error', source, 'NotInSquad')
        return
    end

    -- Vérifier si c'est l'hôte
    if squad.host ~= source then
        TriggerClientEvent('redzone:squad:error', source, 'NotHost')
        return
    end

    -- Vérifier si le joueur cible existe
    if GetPlayerPed(targetId) == 0 then
        TriggerClientEvent('redzone:squad:error', source, 'PlayerNotFound')
        return
    end

    -- Vérifier si c'est soi-même
    if targetId == source then
        TriggerClientEvent('redzone:squad:error', source, 'CannotInviteSelf')
        return
    end

    -- Vérifier si le squad est complet
    if #squad.members >= Config.Squad.MaxMembers then
        TriggerClientEvent('redzone:squad:error', source, 'SquadFull')
        return
    end

    -- Vérifier si la cible est déjà dans un squad
    if playerSquads[targetId] then
        TriggerClientEvent('redzone:squad:error', source, 'AlreadyInSquad')
        return
    end

    local hostName = GetPlayerNameSafe(source)
    local targetName = GetPlayerNameSafe(targetId)

    -- Créer l'invitation (expire après 60 secondes)
    pendingInvites[targetId] = {
        squadId = squad.id,
        hostId = source,
        hostName = hostName,
        expireTime = os.time() + 60,
    }

    -- Notifier le joueur invité
    TriggerClientEvent('redzone:squad:inviteReceived', targetId, squad.id, source, hostName)

    -- Notifier l'hôte
    TriggerClientEvent('redzone:squad:inviteSent', source, targetName)

    Redzone.Shared.Debug('[SQUAD] Joueur ', source, ' a invité ', targetId, ' au squad ', squad.id)
end)

---Événement: Accepter une invitation
RegisterNetEvent('redzone:squad:acceptInvite')
AddEventHandler('redzone:squad:acceptInvite', function(squadId)
    local source = source

    -- Vérifier l'invitation
    local invite = pendingInvites[source]
    if not invite or invite.squadId ~= squadId then
        TriggerClientEvent('redzone:squad:error', source, 'PlayerNotFound')
        return
    end

    -- Vérifier si l'invitation a expiré
    if os.time() > invite.expireTime then
        pendingInvites[source] = nil
        TriggerClientEvent('redzone:squad:error', source, 'PlayerNotFound')
        return
    end

    -- Vérifier si le squad existe encore
    local squad = activeSquads[squadId]
    if not squad then
        pendingInvites[source] = nil
        TriggerClientEvent('redzone:squad:error', source, 'PlayerNotFound')
        return
    end

    -- Vérifier si le squad est complet
    if #squad.members >= Config.Squad.MaxMembers then
        pendingInvites[source] = nil
        TriggerClientEvent('redzone:squad:error', source, 'SquadFull')
        return
    end

    -- Vérifier si déjà dans un squad
    if playerSquads[source] then
        pendingInvites[source] = nil
        TriggerClientEvent('redzone:squad:error', source, 'AlreadyInSquad')
        return
    end

    -- Ajouter au squad
    table.insert(squad.members, source)
    playerSquads[source] = squadId
    pendingInvites[source] = nil

    local playerName = GetPlayerNameSafe(source)
    local hostName = GetPlayerNameSafe(squad.host)

    -- Notifier le nouveau membre
    TriggerClientEvent('redzone:squad:joined', source, squad, hostName)

    -- Notifier les autres membres
    NotifySquadMembersExcept(squadId, source, 'redzone:squad:playerJoined', source, playerName)

    -- Mettre à jour le squad pour tous les membres (pour que les barres de vie s'affichent)
    NotifySquadMembers(squadId, 'redzone:squad:updated', squad)

    Redzone.Shared.Debug('[SQUAD] Joueur ', source, ' a rejoint le squad ', squadId)
end)

---Événement: Refuser une invitation
RegisterNetEvent('redzone:squad:declineInvite')
AddEventHandler('redzone:squad:declineInvite', function(squadId)
    local source = source

    if pendingInvites[source] then
        pendingInvites[source] = nil
    end
end)

---Événement: Kick un joueur
RegisterNetEvent('redzone:squad:kick')
AddEventHandler('redzone:squad:kick', function(targetId)
    local source = source

    local squad = GetPlayerSquad(source)
    if not squad then
        TriggerClientEvent('redzone:squad:error', source, 'NotInSquad')
        return
    end

    if squad.host ~= source then
        TriggerClientEvent('redzone:squad:error', source, 'NotHost')
        return
    end

    -- Vérifier que la cible est dans le squad
    local targetInSquad = false
    for _, memberId in ipairs(squad.members) do
        if memberId == targetId then
            targetInSquad = true
            break
        end
    end

    if not targetInSquad then
        TriggerClientEvent('redzone:squad:error', source, 'PlayerNotFound')
        return
    end

    -- Ne peut pas se kick soi-même
    if targetId == source then
        return
    end

    RemovePlayerFromSquad(targetId, 'kicked')
end)

---Événement: Joueur a quitté le redzone
RegisterNetEvent('redzone:squad:playerLeftRedzone')
AddEventHandler('redzone:squad:playerLeftRedzone', function()
    local source = source

    if playerSquads[source] then
        RemovePlayerFromSquad(source, 'left_redzone')
    end

    -- Annuler les invitations en attente
    if pendingInvites[source] then
        pendingInvites[source] = nil
    end
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

---Événement: Joueur déconnecté
AddEventHandler('playerDropped', function(reason)
    local source = source

    -- Retirer du squad si présent
    if playerSquads[source] then
        RemovePlayerFromSquad(source, 'disconnected')
    end

    -- Annuler les invitations en attente
    if pendingInvites[source] then
        pendingInvites[source] = nil
    end
end)

-- =====================================================
-- THREAD DE NETTOYAGE DES INVITATIONS EXPIRÉES
-- =====================================================

CreateThread(function()
    while true do
        Wait(30000) -- Vérifier toutes les 30 secondes

        local currentTime = os.time()
        for playerId, invite in pairs(pendingInvites) do
            if currentTime > invite.expireTime then
                pendingInvites[playerId] = nil
            end
        end
    end
end)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetPlayerSquad', function(playerId)
    return GetPlayerSquad(playerId)
end)

exports('IsPlayerInSquad', function(playerId)
    return playerSquads[playerId] ~= nil
end)

exports('GetSquadMembers', function(playerId)
    local squad = GetPlayerSquad(playerId)
    if squad then
        return squad.members
    end
    return nil
end)

---Vérifie si deux joueurs sont dans le même squad
---@param playerId1 number
---@param playerId2 number
---@return boolean
exports('ArePlayersInSameSquad', function(playerId1, playerId2)
    local squadId1 = playerSquads[playerId1]
    local squadId2 = playerSquads[playerId2]

    if squadId1 and squadId2 and squadId1 == squadId2 then
        return true
    end
    return false
end)

-- =====================================================
-- ANTI TEAM-KILL - WEAPON DAMAGE EVENT (NATIF FIVEM)
-- =====================================================

-- Intercepter tous les dégâts d'armes au niveau le plus bas
AddEventHandler('weaponDamageEvent', function(sender, data)
    -- data.damageFlags, data.weaponDamage, data.silenced, data.damageType
    -- data.isVehicleWeapon, data.weaponType, data.actionResultId
    -- data.overrideDefaultDamage, data.hitEntityWeapon
    -- data.hitComponent, data.hitGlobalId

    -- Identifier le tireur (sender est l'ID réseau, pas serverId)
    local attackerId = sender

    -- Obtenir l'entité touchée
    if data.hitGlobalId then
        local entityOwner = nil

        -- Parcourir tous les joueurs pour trouver qui possède cette entité
        for _, playerId in ipairs(GetPlayers()) do
            local playerPed = GetPlayerPed(playerId)
            if playerPed and playerPed ~= 0 then
                local playerNetId = NetworkGetNetworkIdFromEntity(playerPed)
                if playerNetId == data.hitGlobalId then
                    entityOwner = tonumber(playerId)
                    break
                end
            end
        end

        if entityOwner and attackerId ~= entityOwner then
            -- Vérifier si les deux sont dans le même squad
            local squadId1 = playerSquads[attackerId]
            local squadId2 = playerSquads[entityOwner]

            if squadId1 and squadId2 and squadId1 == squadId2 then
                print('[SQUAD] weaponDamageEvent bloqué: ' .. tostring(attackerId) .. ' -> ' .. tostring(entityOwner))
                CancelEvent()
                return
            end
        end
    end
end)

-- =====================================================
-- INTÉGRATION FANCA_ANTITANK (Anti Team-Kill)
-- =====================================================

-- Hook pour annuler les kills entre membres du même squad
AddEventHandler('fanca_antitank:kill', function(targetId, playerId)
    local squadId1 = playerSquads[targetId]
    local squadId2 = playerSquads[playerId]

    if squadId1 and squadId2 and squadId1 == squadId2 then
        CancelEvent()
        print('[SQUAD/ANTITANK] Kill annulé: ' .. tostring(playerId) .. ' -> ' .. tostring(targetId))
        TriggerClientEvent('redzone:squad:restoreHealth', targetId)
    end
end)

-- Hook pour l'événement hit
AddEventHandler('fanca_antitank:hit', function(targetId, playerId)
    local squadId1 = playerSquads[targetId]
    local squadId2 = playerSquads[playerId]

    if squadId1 and squadId2 and squadId1 == squadId2 then
        CancelEvent()
        print('[SQUAD/ANTITANK] Hit annulé: ' .. tostring(playerId) .. ' -> ' .. tostring(targetId))
        TriggerClientEvent('redzone:squad:restoreHealth', targetId)
    end
end)

-- Hook sur gameEventTriggered pour bloquer les morts entre coéquipiers
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local victimDied = args[4] == 1

        if victimDied and victim and attacker then
            -- Trouver les IDs serveur
            local victimServerId = nil
            local attackerServerId = nil

            for _, playerId in ipairs(GetPlayers()) do
                local playerPed = GetPlayerPed(playerId)
                if playerPed == victim then
                    victimServerId = tonumber(playerId)
                elseif playerPed == attacker then
                    attackerServerId = tonumber(playerId)
                end
            end

            if victimServerId and attackerServerId then
                local squadId1 = playerSquads[victimServerId]
                local squadId2 = playerSquads[attackerServerId]

                if squadId1 and squadId2 and squadId1 == squadId2 then
                    print('[SQUAD] Mort entre coéquipiers détectée - Résurrection: ' .. tostring(victimServerId))
                    TriggerClientEvent('redzone:squad:forceResurrect', victimServerId)
                end
            end
        end
    end
end)

-- Hook pour ajuster les dégâts via fanca_antitank
local antitankHookId = nil

CreateThread(function()
    Wait(2000)

    local success, antitank = pcall(function()
        return exports['fanca_antitank']
    end)

    if success and antitank then
        local hookSuccess, hookId = pcall(function()
            return antitank:registerHook("weaponDamageAdjust", function(payload)
                local attackerId = payload.source
                local targetId = payload.targetId

                local squadId1 = playerSquads[attackerId]
                local squadId2 = playerSquads[targetId]

                if squadId1 and squadId2 and squadId1 == squadId2 then
                    print('[SQUAD/ANTITANK] Dégâts annulés via hook: ' .. tostring(attackerId) .. ' -> ' .. tostring(targetId))
                    return false
                end

                return true
            end)
        end)

        if hookSuccess and hookId then
            antitankHookId = hookId
            print('[SQUAD] Hook fanca_antitank enregistré: ' .. tostring(antitankHookId))
        else
            print('[SQUAD] Erreur hook fanca_antitank')
        end
    else
        print('[SQUAD] fanca_antitank non disponible')
    end
end)

-- Événement pour vérifier si deux joueurs sont dans le même squad
RegisterNetEvent('redzone:squad:checkSameSquad')
AddEventHandler('redzone:squad:checkSameSquad', function(targetId, callback)
    local source = source
    local squadId1 = playerSquads[source]
    local squadId2 = playerSquads[targetId]

    local sameSquad = squadId1 and squadId2 and squadId1 == squadId2
    TriggerClientEvent('redzone:squad:sameSquadResult', source, targetId, sameSquad)
end)

-- Nettoyage du hook
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if antitankHookId then
        pcall(function()
            exports['fanca_antitank']:removeHooks(antitankHookId)
        end)
    end
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

Redzone.Shared.Debug('[SERVER/SQUAD] Module Squad serveur chargé')
