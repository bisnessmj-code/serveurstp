-- ========================================
-- PVP GUNFIGHT - MODULE DISCORD ULTRA-OPTIMISÉ
-- Version 5.0.0 - HAUTE CHARGE (160+ JOUEURS)
-- ========================================
-- ✅ Cache avatars 30 minutes (au lieu de 5)
-- ✅ Rate limiting requêtes HTTP Discord
-- ✅ Batch preload avatars
-- ✅ Fallback immédiat si pas de token
-- ✅ Cleanup automatique cache
-- ✅ Queue requêtes HTTP (max 5 simultanées)
-- ========================================

DebugServer('Module Discord chargé (VERSION ULTRA-OPTIMISÉE)')

-- ========================================
-- CONFIGURATION PERFORMANCE
-- ========================================
local PERF = {
    -- Cache (CRITIQUE)
    cacheDuration = 1800000,           -- ✅ 30 minutes (au lieu de 5)
    
    -- Rate limiting HTTP
    maxConcurrentRequests = 5,         -- ✅ Max 5 requêtes HTTP simultanées
    requestDelay = 200,                -- ✅ 200ms entre requêtes
    
    -- Cleanup
    cleanupInterval = 300000,          -- ✅ 5 minutes
    
    -- Preload
    preloadBatchSize = 10,             -- ✅ 10 avatars à la fois
    preloadDelay = 500,                -- ✅ 500ms entre batches
}

-- ========================================
-- CACHE DES AVATARS
-- ========================================
local avatarCache = {}
local pendingRequests = {}

-- ✅ QUEUE REQUÊTES HTTP
local httpRequestQueue = {}
local activeHttpRequests = 0

-- ✅ STATS (pour monitoring)
local stats = {
    cacheHits = 0,
    cacheMisses = 0,
    httpRequests = 0,
    httpErrors = 0
}

-- Configuration
local DISCORD_CONFIG = {
    defaultAvatar = Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png',
    avatarSize = Config.Discord.avatarSize or 128,
    avatarFormat = Config.Discord.avatarFormat or 'png',
    enabled = Config.Discord.enabled or false,
    hasToken = false
}

-- ========================================
-- ✅ THREAD: CLEANUP AUTOMATIQUE (5min)
-- ========================================
CreateThread(function()
    DebugServer('Thread cleanup avatars démarré (5min)')
    
    while true do
        Wait(PERF.cleanupInterval)
        
        local now = GetGameTimer()
        local cleaned = 0
        
        -- ✅ Nettoyer cache expiré
        for playerId, cached in pairs(avatarCache) do
            if (now - cached.timestamp) > PERF.cacheDuration then
                avatarCache[playerId] = nil
                cleaned = cleaned + 1
            end
        end
        
        -- ✅ Nettoyer pending requests orphelins
        for playerId, callbacks in pairs(pendingRequests) do
            if GetPlayerPing(playerId) <= 0 then
                pendingRequests[playerId] = nil
            end
        end
        
        if cleaned > 0 then
            DebugServer('🧹 Discord cache nettoyé: %d avatars expirés', cleaned)
        end
        
        -- ✅ Log stats
        if stats.httpRequests > 0 then
            DebugServer('📊 Discord stats: Hits=%d Miss=%d HTTP=%d Errors=%d', 
                stats.cacheHits, stats.cacheMisses, stats.httpRequests, stats.httpErrors)
        end
    end
end)

-- ========================================
-- ✅ THREAD: PROCESS HTTP QUEUE
-- ========================================
CreateThread(function()
    while true do
        Wait(PERF.requestDelay)
        
        -- ✅ Traiter queue si requêtes disponibles
        if #httpRequestQueue > 0 and activeHttpRequests < PERF.maxConcurrentRequests then
            local request = table.remove(httpRequestQueue, 1)
            
            if request then
                activeHttpRequests = activeHttpRequests + 1
                
                CreateThread(function()
                    request.func()
                    activeHttpRequests = activeHttpRequests - 1
                end)
            end
        end
    end
end)

-- ========================================
-- ✅ FONCTION: AJOUTER À QUEUE HTTP
-- ========================================
local function QueueHttpRequest(func)
    httpRequestQueue[#httpRequestQueue + 1] = {
        func = func,
        timestamp = GetGameTimer()
    }
end

-- ========================================
-- FONCTIONS UTILITAIRES
-- ========================================
local function GetPlayerDiscordId(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    
    if not identifiers then return nil end
    
    for i = 1, #identifiers do
        local identifier = identifiers[i]
        if string.sub(identifier, 1, 8) == 'discord:' then
            return string.sub(identifier, 9)
        end
    end
    
    return nil
end

local function GetDefaultDiscordAvatar(discordId)
    if not discordId then
        return DISCORD_CONFIG.defaultAvatar
    end
    
    local avatarIndex = tonumber(discordId) % 5
    return string.format('https://cdn.discordapp.com/embed/avatars/%d.png', avatarIndex)
end

-- ========================================
-- ✅ FETCH CUSTOM AVATAR (OPTIMISÉ)
-- ========================================
local function FetchCustomDiscordAvatar(playerId, discordId, callback)
    -- ✅ Vérifier si token disponible
    if not DISCORD_CONFIG.hasToken then
        callback(GetDefaultDiscordAvatar(discordId))
        return
    end
    
    -- ✅ Vérifier si déjà en cours
    if pendingRequests[playerId] then
        pendingRequests[playerId][#pendingRequests[playerId] + 1] = callback
        return
    end
    
    pendingRequests[playerId] = {callback}
    
    -- ✅ Ajouter à la queue au lieu de fetch direct
    QueueHttpRequest(function()
        stats.httpRequests = stats.httpRequests + 1
        
        PerformHttpRequest(
            'https://discord.com/api/v10/users/' .. discordId,
            function(statusCode, responseBody, headers)
                local callbacks = pendingRequests[playerId]
                pendingRequests[playerId] = nil
                
                if not callbacks then return end
                
                local avatarUrl = GetDefaultDiscordAvatar(discordId)
                
                if statusCode == 200 then
                    local success, data = pcall(json.decode, responseBody)
                    
                    if success and data and data.avatar then
                        avatarUrl = string.format(
                            'https://cdn.discordapp.com/avatars/%s/%s.%s?size=%d',
                            discordId, data.avatar, DISCORD_CONFIG.avatarFormat, DISCORD_CONFIG.avatarSize
                        )
                        
                        -- ✅ Mise à jour DB (async, pas bloquant)
                        CreateThread(function()
                            local xPlayer = ESX.GetPlayerFromId(playerId)
                            if xPlayer then
                                MySQL.update('UPDATE pvp_stats SET discord_avatar = ? WHERE identifier = ?', {
                                    avatarUrl, xPlayer.identifier
                                })
                            end
                        end)
                    end
                else
                    stats.httpErrors = stats.httpErrors + 1
                    DebugWarn('Discord API error: Status %d for player %d', statusCode, playerId)
                end
                
                -- ✅ Mettre en cache (30 minutes)
                avatarCache[playerId] = {
                    url = avatarUrl,
                    discordId = discordId,
                    timestamp = GetGameTimer()
                }
                
                -- ✅ Callback tous les pending
                for i = 1, #callbacks do
                    callbacks[i](avatarUrl)
                end
            end,
            'GET',
            '',
            {
                ['Authorization'] = 'Bot ' .. Config.Discord.botToken,
                ['Content-Type'] = 'application/json'
            }
        )
    end)
end

-- ========================================
-- ✅ GET AVATAR ASYNC (OPTIMISÉ)
-- ========================================
function GetPlayerDiscordAvatarAsync(playerId, callback)
    -- ✅ Vérifier cache (CRITIQUE)
    local cached = avatarCache[playerId]
    if cached and (GetGameTimer() - cached.timestamp) < PERF.cacheDuration then
        stats.cacheHits = stats.cacheHits + 1
        callback(cached.url)
        return
    end
    
    stats.cacheMisses = stats.cacheMisses + 1
    
    -- ✅ Vérifier si Discord activé
    if not DISCORD_CONFIG.enabled then
        callback(DISCORD_CONFIG.defaultAvatar)
        return
    end
    
    local discordId = GetPlayerDiscordId(playerId)
    
    if not discordId then
        callback(DISCORD_CONFIG.defaultAvatar)
        return
    end
    
    -- ✅ Fetch custom avatar (avec queue)
    FetchCustomDiscordAvatar(playerId, discordId, callback)
end

-- ========================================
-- ✅ GET AVATAR SYNC (AVEC CACHE)
-- ========================================
function GetPlayerDiscordAvatar(playerId)
    -- ✅ Retourner cache si disponible
    local cached = avatarCache[playerId]
    if cached then
        stats.cacheHits = stats.cacheHits + 1
        return cached.url
    end
    
    stats.cacheMisses = stats.cacheMisses + 1
    
    if not DISCORD_CONFIG.enabled then
        return DISCORD_CONFIG.defaultAvatar
    end
    
    local discordId = GetPlayerDiscordId(playerId)
    if not discordId then
        return DISCORD_CONFIG.defaultAvatar
    end
    
    -- ✅ Lancer fetch async (non bloquant)
    CreateThread(function()
        GetPlayerDiscordAvatarAsync(playerId, function() end)
    end)
    
    -- ✅ Retourner default en attendant
    return GetDefaultDiscordAvatar(discordId)
end

-- ========================================
-- ✅ GET DISCORD INFO (OPTIMISÉ)
-- ========================================
function GetPlayerDiscordInfo(playerId)
    local discordId = GetPlayerDiscordId(playerId)
    local avatarUrl = DISCORD_CONFIG.defaultAvatar
    
    -- ✅ Utiliser cache si disponible
    local cached = avatarCache[playerId]
    if cached then
        avatarUrl = cached.url
    elseif discordId then
        avatarUrl = GetDefaultDiscordAvatar(discordId)
    end
    
    return {
        discordId = discordId,
        avatarUrl = avatarUrl,
        hasDiscord = discordId ~= nil
    }
end

-- ========================================
-- ✅ PRELOAD AVATARS (BATCH)
-- ========================================
function PreloadAvatarsAsync(playerIds, callback)
    local completed = 0
    local total = #playerIds
    
    if total == 0 then
        callback()
        return
    end
    
    DebugServer('📥 Preload %d avatars (batch)', total)
    
    -- ✅ Traiter par batch
    for i = 1, total, PERF.preloadBatchSize do
        CreateThread(function()
            Wait((i - 1) / PERF.preloadBatchSize * PERF.preloadDelay)
            
            local endIndex = math.min(i + PERF.preloadBatchSize - 1, total)
            
            for j = i, endIndex do
                GetPlayerDiscordAvatarAsync(playerIds[j], function()
                    completed = completed + 1
                    if completed == total then
                        DebugServer('✅ Preload terminé: %d avatars', total)
                        callback()
                    end
                end)
            end
        end)
    end
end

-- ========================================
-- DÉCONNEXION
-- ========================================
AddEventHandler('playerDropped', function()
    local src = source
    
    -- ✅ NE PAS nettoyer le cache (on garde 30min)
    -- avatarCache[src] = nil  -- ❌ Commenté pour garder cache
    
    pendingRequests[src] = nil
end)

-- ========================================
-- ✅ VÉRIFICATION TOKEN AU DÉMARRAGE
-- ========================================
CreateThread(function()
    Wait(2000)
    
    if not DISCORD_CONFIG.enabled then
        DebugWarn('Système avatars Discord DÉSACTIVÉ')
        return
    end
    
    if not Config.Discord.botToken or Config.Discord.botToken == '' then
        DebugWarn('Token Discord non configuré - Avatars par défaut uniquement')
        DISCORD_CONFIG.hasToken = false
        return
    end
    
    -- ✅ Vérifier token (avec queue)
    QueueHttpRequest(function()
        PerformHttpRequest(
            'https://discord.com/api/v10/users/@me',
            function(statusCode, responseBody)
                if statusCode == 200 then
                    local success, data = pcall(json.decode, responseBody)
                    if success and data then
                        DISCORD_CONFIG.hasToken = true
                        DebugSuccess('✅ Bot Discord connecté: %s', data.username or 'Unknown')
                        DebugSuccess('✅ Avatars personnalisés activés (cache 30min)')
                    else
                        DISCORD_CONFIG.hasToken = false
                        DebugWarn('Token Discord invalide - Avatars par défaut')
                    end
                else
                    DISCORD_CONFIG.hasToken = false
                    DebugError('Token Discord invalide (Status: %d)', statusCode)
                    DebugWarn('Avatars par défaut uniquement')
                end
            end,
            'GET',
            '',
            {
                ['Authorization'] = 'Bot ' .. Config.Discord.botToken,
                ['Content-Type'] = 'application/json'
            }
        )
    end)
end)

-- ========================================
-- ✅ COMMANDE DEBUG (ADMIN)
-- ========================================
RegisterCommand('discordstats', function(source)
    if source ~= 0 and not exports['pvp_gunfight']:IsPlayerAdmin(source) then
        return
    end
    
    local cacheSize = 0
    for _ in pairs(avatarCache) do
        cacheSize = cacheSize + 1
    end
    
    local queueSize = #httpRequestQueue
    
    local output = string.format(
        '📊 Discord Stats:\n' ..
        '  Cache: %d avatars (30min)\n' ..
        '  Hits: %d | Miss: %d (%.1f%% hit rate)\n' ..
        '  HTTP: %d requêtes | Errors: %d\n' ..
        '  Queue: %d pending | Active: %d/%d\n' ..
        '  Token: %s',
        cacheSize,
        stats.cacheHits, stats.cacheMisses,
        stats.cacheHits > 0 and (stats.cacheHits / (stats.cacheHits + stats.cacheMisses) * 100) or 0,
        stats.httpRequests, stats.httpErrors,
        queueSize, activeHttpRequests, PERF.maxConcurrentRequests,
        DISCORD_CONFIG.hasToken and 'Valide' or 'Manquant/Invalide'
    )
    
    if source == 0 then
        print(output)
    else
        for line in output:gmatch("[^\n]+") do
            TriggerClientEvent('esx:showNotification', source, '~b~' .. line)
        end
    end
end, false)

RegisterCommand('discordclearcache', function(source)
    if source ~= 0 and not exports['pvp_gunfight']:IsPlayerAdmin(source) then
        return
    end
    
    local count = 0
    for _ in pairs(avatarCache) do
        count = count + 1
    end
    
    avatarCache = {}
    stats = {
        cacheHits = 0,
        cacheMisses = 0,
        httpRequests = 0,
        httpErrors = 0
    }
    
    local msg = string.format('✅ Cache Discord nettoyé (%d avatars)', count)
    
    if source == 0 then
        print(msg)
    else
        TriggerClientEvent('esx:showNotification', source, '~g~' .. msg)
    end
end, false)

-- ========================================
-- EXPORTS
-- ========================================
exports('GetPlayerDiscordId', GetPlayerDiscordId)
exports('GetPlayerDiscordAvatar', GetPlayerDiscordAvatar)
exports('GetPlayerDiscordAvatarAsync', GetPlayerDiscordAvatarAsync)
exports('GetPlayerDiscordInfo', GetPlayerDiscordInfo)
exports('PreloadAvatarsAsync', PreloadAvatarsAsync)

DebugSuccess('Module Discord initialisé (VERSION 5.0.0 - ULTRA-OPTIMISÉ)')
DebugSuccess('✅ Cache: 30min | Queue HTTP: 5 max | Batch preload: 10 avatars')