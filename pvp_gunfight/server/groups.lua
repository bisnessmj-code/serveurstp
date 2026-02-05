-- ========================================
-- PVP GUNFIGHT - SYSTÈME DE GROUPES ULTRA-OPTIMISÉ
-- Version 5.0.1 - BRUTAL NOTIFY INTEGRATION
-- ========================================
-- ✅ Cache groupes (évite recalculs)
-- ✅ Rate limiting sur events groupes
-- ✅ Batch broadcast (50 joueurs max)
-- ✅ Cleanup automatique groupes vides
-- ✅ Pas de boucles inutiles
-- ✅ Notifications brutal_notify
-- ========================================

DebugGroups('Module groupes chargé (VERSION ULTRA-OPTIMISÉE + Brutal Notify)')

-- ========================================
-- CONFIGURATION PERFORMANCE
-- ========================================
local PERF = {
    -- Cache
    groupDataCacheDuration = 5000,     -- ✅ 5 secondes
    
    -- Rate limiting
    rateLimitWindow = 2000,            -- ✅ 2s entre events groupes
    
    -- Batch
    maxPlayersPerBatch = 50,           -- ✅ 50 joueurs max par batch
    batchDelay = 100,                  -- ✅ 100ms entre batches
    
    -- Cleanup
    cleanupInterval = 30000,           -- ✅ 30s cleanup groupes vides
}

-- ========================================
-- VARIABLES
-- ========================================
local groups = {}
local playerGroups = {}
local pendingInvites = {}

-- ✅ CACHE
local groupDataCache = {}

-- ✅ RATE LIMITING
local playerEventTimestamps = {}

-- ========================================
-- ✅ FONCTION: RATE LIMITING
-- ========================================
local function IsRateLimited(playerId, eventName)
    local now = GetGameTimer()
    local key = playerId .. '_' .. eventName
    local lastTime = playerEventTimestamps[key] or 0
    
    if (now - lastTime) < PERF.rateLimitWindow then
        return true
    end
    
    playerEventTimestamps[key] = now
    return false
end

-- ========================================
-- ✅ THREAD: CLEANUP AUTOMATIQUE (30s)
-- ========================================
CreateThread(function()
    DebugGroups('Thread cleanup groupes démarré (30s)')
    
    while true do
        Wait(PERF.cleanupInterval)
        
        local now = GetGameTimer()
        local cleanedGroups = 0
        local cleanedCache = 0
        local cleanedRateLimit = 0
        
        -- ✅ Nettoyer groupes vides
        for groupId, group in pairs(groups) do
            if #group.members == 0 then
                groups[groupId] = nil
                cleanedGroups = cleanedGroups + 1
            end
        end
        
        -- ✅ Nettoyer cache expiré
        for key, entry in pairs(groupDataCache) do
            if entry.timestamp and (now - entry.timestamp) > PERF.groupDataCacheDuration then
                groupDataCache[key] = nil
                cleanedCache = cleanedCache + 1
            end
        end
        
        -- ✅ Nettoyer rate limiting
        for key, timestamp in pairs(playerEventTimestamps) do
            if (now - timestamp) > 60000 then
                playerEventTimestamps[key] = nil
                cleanedRateLimit = cleanedRateLimit + 1
            end
        end
        
        if cleanedGroups > 0 or cleanedCache > 0 or cleanedRateLimit > 0 then
            DebugGroups('🧹 Cleanup: %d groupes, %d cache, %d rate limit', 
                cleanedGroups, cleanedCache, cleanedRateLimit)
        end
    end
end)

-- ========================================
-- FONCTION: OBTENIR NOM FIVEM + ID
-- ========================================
local function GetPlayerFiveMNameWithID(playerId)
    if not playerId or playerId <= 0 then
        return "Joueur inconnu"
    end
    
    local playerName = GetPlayerName(playerId)
    
    if playerName then
        playerName = playerName:gsub("%^%d", "")
    else
        playerName = "Joueur"
    end
    
    return string.format("%s [%d]", playerName, playerId)
end

-- ========================================
-- ✅ GESTION GROUPES (OPTIMISÉE)
-- ========================================
local function CreateGroup(leaderId)
    local groupId = #groups + 1
    groups[groupId] = {
        id = groupId,
        leaderId = leaderId,
        members = {leaderId},
        ready = {[leaderId] = false}
    }
    playerGroups[leaderId] = groupId
    
    DebugGroups('✅ Groupe %d créé - Leader: %d', groupId, leaderId)
    
    return groupId
end

function GetPlayerGroup(playerId)
    local groupId = playerGroups[playerId]
    if not groupId then return nil end
    
    local group = groups[groupId]
    if not group then
        playerGroups[playerId] = nil
        return nil
    end
    
    -- ✅ Vérifier que le joueur est bien dans le groupe
    local found = false
    for i = 1, #group.members do
        if group.members[i] == playerId then
            found = true
            break
        end
    end
    
    if not found then
        playerGroups[playerId] = nil
        group.ready[playerId] = nil
        return nil
    end
    
    return group
end

-- ========================================
-- ✅ BROADCAST OPTIMISÉ (PAR BATCH)
-- ========================================
local function BroadcastToGroup(groupId)
    local group = groups[groupId]
    if not group then return end
    
    -- ✅ Invalider cache pour tous les membres
    for i = 1, #group.members do
        groupDataCache[group.members[i]] = nil
    end
    
    -- ✅ Broadcast par batch si beaucoup de membres
    local totalMembers = #group.members
    
    if totalMembers <= 10 then
        -- ✅ Petit groupe : broadcast direct
        for i = 1, #group.members do
            local memberId = group.members[i]
            CreateThread(function()
                GetGroupDataAsync(memberId, function(groupData)
                    TriggerClientEvent('pvp:updateGroupUI', memberId, groupData)
                end)
            end)
        end
    else
        -- ✅ Grand groupe : batch processing
        for i = 1, totalMembers, PERF.maxPlayersPerBatch do
            CreateThread(function()
                Wait((i - 1) / PERF.maxPlayersPerBatch * PERF.batchDelay)
                
                local endIndex = math.min(i + PERF.maxPlayersPerBatch - 1, totalMembers)
                
                for j = i, endIndex do
                    local memberId = group.members[j]
                    GetGroupDataAsync(memberId, function(groupData)
                        TriggerClientEvent('pvp:updateGroupUI', memberId, groupData)
                    end)
                end
            end)
        end
    end
end

-- ========================================
-- ✅ GET GROUP DATA (AVEC CACHE)
-- ========================================
function GetGroupDataAsync(playerId, callback)
    local now = GetGameTimer()
    
    -- ✅ Vérifier cache
    local cached = groupDataCache[playerId]
    if cached and (now - cached.timestamp) < PERF.groupDataCacheDuration then
        DebugGroups('📦 Cache HIT: Joueur %d', playerId)
        callback(cached.data)
        return
    end
    
    -- ✅ Cache MISS - Reconstruire data
    local group = GetPlayerGroup(playerId)
    if not group then 
        callback(nil)
        return
    end
    
    local members = {}
    local completed = 0
    local total = #group.members
    
    -- ✅ Récupérer avatars en parallèle
    for i = 1, #group.members do
        local memberId = group.members[i]
        
        local displayName = GetPlayerFiveMNameWithID(memberId)
        
        if Config.Discord and Config.Discord.enabled then
            exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(memberId, function(avatarUrl)
                members[#members + 1] = {
                    id = memberId,
                    name = displayName,
                    isLeader = memberId == group.leaderId,
                    isReady = group.ready[memberId] or false,
                    isYou = memberId == playerId,
                    yourId = playerId,
                    avatar = avatarUrl
                }
                
                completed = completed + 1
                if completed == total then
                    local groupData = {id = group.id, leaderId = group.leaderId, members = members}
                    
                    -- ✅ Mettre en cache
                    groupDataCache[playerId] = {
                        data = groupData,
                        timestamp = GetGameTimer()
                    }
                    
                    callback(groupData)
                end
            end)
        else
            members[#members + 1] = {
                id = memberId,
                name = displayName,
                isLeader = memberId == group.leaderId,
                isReady = group.ready[memberId] or false,
                isYou = memberId == playerId,
                yourId = playerId,
                avatar = Config.Discord and Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png'
            }
            
            completed = completed + 1
            if completed == total then
                local groupData = {id = group.id, leaderId = group.leaderId, members = members}
                
                -- ✅ Mettre en cache
                groupDataCache[playerId] = {
                    data = groupData,
                    timestamp = GetGameTimer()
                }
                
                callback(groupData)
            end
        end
    end
end

-- ✅ VERSION SYNC (SANS CACHE - pour compatibilité)
function GetGroupData(playerId)
    local group = GetPlayerGroup(playerId)
    if not group then return nil end
    
    local members = {}
    for i = 1, #group.members do
        local memberId = group.members[i]
        
        local displayName = GetPlayerFiveMNameWithID(memberId)
        local avatarUrl = Config.Discord and Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png'
        
        if Config.Discord and Config.Discord.enabled then
            avatarUrl = exports['pvp_gunfight']:GetPlayerDiscordAvatar(memberId)
        end
        
        members[#members + 1] = {
            id = memberId,
            name = displayName,
            isLeader = memberId == group.leaderId,
            isReady = group.ready[memberId] or false,
            isYou = memberId == playerId,
            yourId = playerId,
            avatar = avatarUrl
        }
    end
    
    return {id = group.id, leaderId = group.leaderId, members = members}
end

-- ========================================
-- ✅ GESTION MEMBRES (OPTIMISÉE)
-- ========================================
function RemovePlayerFromGroup(playerId)
    local group = GetPlayerGroup(playerId)
    if not group then
        playerGroups[playerId] = nil
        return
    end
    
    -- ✅ Retirer du groupe
    for i = #group.members, 1, -1 do
        if group.members[i] == playerId then
            table.remove(group.members, i)
            break
        end
    end
    
    group.ready[playerId] = nil
    playerGroups[playerId] = nil
    
    -- ✅ Invalider cache
    groupDataCache[playerId] = nil
    
    TriggerClientEvent('pvp:updateGroupUI', playerId, nil)
    
    -- ✅ Gérer groupe vide ou changement leader
    if #group.members == 0 then
        groups[group.id] = nil
        DebugGroups('🗑️ Groupe %d supprimé (vide)', group.id)
    else
        if group.leaderId == playerId then
            group.leaderId = group.members[1]
            -- ✅ BRUTAL NOTIFY
            TriggerClientEvent('brutal_notify:SendAlert', group.leaderId, 
                'Groupe PVP', 'Vous êtes maintenant le leader', 3000, 'info')
            DebugGroups('👑 Nouveau leader groupe %d: %d', group.id, group.leaderId)
        end
        BroadcastToGroup(group.id)
    end
end

function ForceCleanPlayerGroup(playerId)
    DebugGroups('🧹 Nettoyage forcé groupe - Joueur %d', playerId)
    
    local groupId = playerGroups[playerId]
    playerGroups[playerId] = nil
    groupDataCache[playerId] = nil
    
    if groupId and groups[groupId] then
        local group = groups[groupId]
        
        for i = #group.members, 1, -1 do
            if group.members[i] == playerId then
                table.remove(group.members, i)
                break
            end
        end
        
        group.ready[playerId] = nil
        
        if #group.members == 0 then
            groups[groupId] = nil
            DebugGroups('Groupe %d supprimé (vide)', groupId)
        else
            if group.leaderId == playerId then
                group.leaderId = group.members[1]
                DebugGroups('Nouveau leader: %d', group.leaderId)
            end
            BroadcastToGroup(groupId)
        end
    end
    
    TriggerClientEvent('pvp:updateGroupUI', playerId, nil)
    DebugGroups('✅ Nettoyage terminé - Joueur %d', playerId)
end

-- ========================================
-- ✅ RESTAURATION APRÈS MATCH (OPTIMISÉE)
-- ========================================
function RestoreGroupsAfterMatch(playerIds, wasSoloMatch)
    DebugGroups('Restauration groupes: %d joueurs (Solo: %s)', #playerIds, tostring(wasSoloMatch))
    
    if wasSoloMatch then
        DebugGroups('Match solo détecté - Nettoyage complet')
        
        -- ✅ Traiter en parallèle
        for i = 1, #playerIds do
            local playerId = playerIds[i]  -- Capturer AVANT CreateThread pour éviter le problème de closure
            CreateThread(function()
                if playerId > 0 and GetPlayerPing(playerId) > 0 then
                    ForceCleanPlayerGroup(playerId)
                end
            end)
        end
        
        return
    end
    
    local processedGroups = {}
    
    for i = 1, #playerIds do
        local playerId = playerIds[i]
        if playerId > 0 and GetPlayerPing(playerId) > 0 then
            local group = GetPlayerGroup(playerId)
            
            if group and not processedGroups[group.id] then
                BroadcastToGroup(group.id)
                processedGroups[group.id] = true
            end
        end
    end
end

function ResetPlayerReadyStatus(playerId)
    local group = GetPlayerGroup(playerId)
    if not group then return false end
    
    group.ready[playerId] = false
    
    -- ✅ Invalider cache
    groupDataCache[playerId] = nil
    
    return true
end

function BroadcastGroupUpdateForPlayer(playerId)
    local group = GetPlayerGroup(playerId)
    if group then
        BroadcastToGroup(group.id)
    end
end

-- ========================================
-- ✅ EVENTS RÉSEAU (AVEC RATE LIMITING + BRUTAL NOTIFY)
-- ========================================
RegisterNetEvent('pvp:inviteToGroup', function(targetId)
    local src = source
    
    -- ✅ Rate limiting
    if IsRateLimited(src, 'inviteToGroup') then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Veuillez patienter...', 2000, 'warning')
        return
    end
    
    local inviterName = GetPlayerFiveMNameWithID(src)
    local targetName = GetPlayerFiveMNameWithID(targetId)
    
    if not targetId or GetPlayerPing(targetId) <= 0 then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Joueur introuvable', 3000, 'error')
        return
    end
    
    local targetGroup = GetPlayerGroup(targetId)
    if targetGroup then
        if #targetGroup.members == 1 and targetGroup.members[1] == targetId then
            DebugGroups('⚠️ Groupe solo détecté pour joueur %d - Nettoyage', targetId)
            ForceCleanPlayerGroup(targetId)
        else
            TriggerClientEvent('brutal_notify:SendAlert', src, 
                'Groupe PVP', targetName .. ' est déjà dans un groupe!', 3000, 'error')
            return
        end
    end
    
    local group = GetPlayerGroup(src)
    if not group then
        CreateGroup(src)
        group = GetPlayerGroup(src)
    end
    
    if group.leaderId ~= src then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Seul le leader peut inviter', 3000, 'error')
        return
    end
    
    if #group.members >= 4 then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Groupe complet (4 max)', 3000, 'error')
        return
    end
    
    pendingInvites[targetId] = src
    
    if Config.Discord and Config.Discord.enabled then
        exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(src, function(avatar)
            TriggerClientEvent('pvp:receiveInvite', targetId, inviterName, src, avatar)
        end)
    else
        TriggerClientEvent('pvp:receiveInvite', targetId, inviterName, src, Config.Discord.defaultAvatar)
    end
    
    TriggerClientEvent('brutal_notify:SendAlert', src, 
        'Groupe PVP', 'Invitation envoyée à ' .. targetName, 3000, 'success')
end)

RegisterNetEvent('pvp:acceptInvite', function(inviterId)
    local src = source
    
    -- ✅ Rate limiting
    if IsRateLimited(src, 'acceptInvite') then
        return
    end
    
    local playerName = GetPlayerFiveMNameWithID(src)
    
    if not pendingInvites[src] or pendingInvites[src] ~= inviterId then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Invitation expirée', 3000, 'error')
        return
    end
    
    pendingInvites[src] = nil
    ForceCleanPlayerGroup(src)
    
    local group = GetPlayerGroup(inviterId)
    if not group then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Groupe inexistant', 3000, 'error')
        return
    end
    
    if #group.members >= 4 then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Groupe complet', 3000, 'error')
        return
    end
    
    group.members[#group.members + 1] = src
    group.ready[src] = false
    playerGroups[src] = group.id
    
    -- ✅ Invalider cache
    groupDataCache[src] = nil
    
    TriggerClientEvent('brutal_notify:SendAlert', src, 
        'Groupe PVP', 'Groupe rejoint!', 3000, 'success')
    TriggerClientEvent('brutal_notify:SendAlert', inviterId, 
        'Groupe PVP', playerName .. ' a rejoint', 3000, 'success')
    
    Wait(200)
    BroadcastToGroup(group.id)
end)

RegisterNetEvent('pvp:leaveGroup', function()
    local src = source
    
    -- ✅ Rate limiting
    if IsRateLimited(src, 'leaveGroup') then
        return
    end
    
    local group = GetPlayerGroup(src)
    
    if not group then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Vous n\'êtes pas dans un groupe', 3000, 'error')
        return
    end
    
    RemovePlayerFromGroup(src)
    TriggerClientEvent('brutal_notify:SendAlert', src, 
        'Groupe PVP', 'Groupe quitté', 3000, 'warning')
end)

RegisterNetEvent('pvp:kickFromGroup', function(targetId)
    local src = source
    
    -- ✅ Rate limiting
    if IsRateLimited(src, 'kickFromGroup') then
        return
    end
    
    local group = GetPlayerGroup(src)
    
    if not group or group.leaderId ~= src then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Vous n\'êtes pas le leader', 3000, 'error')
        return
    end
    
    local found = false
    for i = #group.members, 1, -1 do
        if group.members[i] == targetId then
            table.remove(group.members, i)
            found = true
            break
        end
    end
    
    if not found then
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Joueur introuvable', 3000, 'error')
        return
    end
    
    group.ready[targetId] = nil
    playerGroups[targetId] = nil

    -- ✅ Invalider cache
    groupDataCache[targetId] = nil

    -- ✅ Annuler la recherche en cours pour TOUS les membres du groupe
    exports['pvp_gunfight']:HandlePlayerDisconnectFromQueue(targetId)

    TriggerClientEvent('brutal_notify:SendAlert', targetId,
        'Groupe PVP', 'Vous avez été exclu', 3000, 'error')
    TriggerClientEvent('pvp:searchCancelled', targetId)
    TriggerClientEvent('pvp:updateGroupUI', targetId, nil)
    TriggerClientEvent('brutal_notify:SendAlert', src, 
        'Groupe PVP', 'Joueur exclu', 3000, 'warning')
    
    if #group.members == 1 then
        playerGroups[src] = nil
        group.ready[src] = nil
        groups[group.id] = nil
        TriggerClientEvent('brutal_notify:SendAlert', src, 
            'Groupe PVP', 'Groupe dissous', 3000, 'warning')
        TriggerClientEvent('pvp:updateGroupUI', src, nil)
    elseif #group.members > 1 then
        BroadcastToGroup(group.id)
    else
        groups[group.id] = nil
    end
end)

RegisterNetEvent('pvp:toggleReady', function()
    local src = source
    
    -- ✅ Rate limiting
    if IsRateLimited(src, 'toggleReady') then
        return
    end
    
    local group = GetPlayerGroup(src)
    if not group then
        CreateGroup(src)
        group = GetPlayerGroup(src)
    end
    
    group.ready[src] = not group.ready[src]
    
    -- ✅ BRUTAL NOTIFY (sans codes couleur)
    local notifType = group.ready[src] and 'success' or 'error'
    local status = group.ready[src] and 'Prêt' or 'Pas prêt'
    
    TriggerClientEvent('brutal_notify:SendAlert', src, 
        'Statut Groupe', status, 2000, notifType)
    
    -- ✅ Invalider cache
    groupDataCache[src] = nil
    
    BroadcastToGroup(group.id)
end)

-- ========================================
-- CALLBACKS
-- ========================================
ESX.RegisterServerCallback('pvp:getGroupInfo', function(source, cb)
    CreateThread(function()
        GetGroupDataAsync(source, function(groupData)
            cb(groupData)
        end)
    end)
end)

ESX.RegisterServerCallback('pvp:getPlayerAvatar', function(source, cb, targetId)
    local playerId = targetId or source
    
    if Config.Discord and Config.Discord.enabled then
        exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(playerId, function(avatarUrl)
            cb(avatarUrl)
        end)
    else
        cb(Config.Discord and Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png')
    end
end)

ESX.RegisterServerCallback('pvp:getPlayersAvatars', function(source, cb, playerIds)
    local avatars = {}
    local completed = 0
    local total = #playerIds
    
    if total == 0 then
        cb(avatars)
        return
    end
    
    for i = 1, #playerIds do
        local playerId = playerIds[i]
        if Config.Discord and Config.Discord.enabled then
            exports['pvp_gunfight']:GetPlayerDiscordAvatarAsync(playerId, function(avatarUrl)
                avatars[playerId] = avatarUrl
                completed = completed + 1
                if completed == total then cb(avatars) end
            end)
        else
            avatars[playerId] = Config.Discord and Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png'
            completed = completed + 1
            if completed == total then cb(avatars) end
        end
    end
end)

-- ========================================
-- CLEANUP DÉCONNEXION
-- ========================================
AddEventHandler('playerDropped', function()
    local src = source
    
    local group = GetPlayerGroup(src)
    if group then
        RemovePlayerFromGroup(src)
    end
    
    pendingInvites[src] = nil
    groupDataCache[src] = nil
    playerEventTimestamps[src .. '_inviteToGroup'] = nil
    playerEventTimestamps[src .. '_acceptInvite'] = nil
    playerEventTimestamps[src .. '_leaveGroup'] = nil
    playerEventTimestamps[src .. '_kickFromGroup'] = nil
    playerEventTimestamps[src .. '_toggleReady'] = nil
end)

-- ========================================
-- EXPORTS
-- ========================================
exports('GetPlayerGroup', GetPlayerGroup)
exports('RemovePlayerFromGroup', RemovePlayerFromGroup)
exports('ForceCleanPlayerGroup', ForceCleanPlayerGroup)
exports('GetGroupDataAsync', GetGroupDataAsync)
exports('RestoreGroupsAfterMatch', RestoreGroupsAfterMatch)
exports('ResetPlayerReadyStatus', ResetPlayerReadyStatus)
exports('BroadcastGroupUpdateForPlayer', BroadcastGroupUpdateForPlayer)

DebugSuccess('Module groupes initialisé (VERSION 5.0.1 - Brutal Notify)')
DebugSuccess('✅ Cache: 5s | Rate limit: 2s | Batch: 50 joueurs | Cleanup: 30s')