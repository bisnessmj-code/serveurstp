-- ========================================
-- PVP GUNFIGHT - DISCORD LEADERBOARDS ULTRA-OPTIMISÉ
-- Version 5.1.0 - FIX EMBED 400 + 9 RANGS MASTER
-- ========================================
-- ✅ Embed compact (évite erreur 400)
-- ✅ 9 rangs (Bronze → Master 1)
-- ✅ Cache leaderboards (5 minutes)
-- ✅ Rate limiting envois Discord
-- ✅ Queue webhooks (évite spam)
-- ========================================

DebugServer('Module Discord Leaderboards chargé (v5.1.0 - FIX 400)')

-- ========================================
-- CONFIGURATION PERFORMANCE
-- ========================================
local PERF = {
    leaderboardCacheDuration = 300000,
    minTimeBetweenSends = 60000,
    maxConcurrentWebhooks = 2,
    webhookDelay = 2000,
    cleanupInterval = 300000,
}

-- ========================================
-- VARIABLES
-- ========================================
local lastSendTime = {}
local isSending = false
local leaderboardCache = {}
local webhookQueue = {}
local activeWebhooks = 0

local stats = {
    cacheHits = 0,
    cacheMisses = 0,
    webhooksSent = 0,
    webhookErrors = 0
}

-- ========================================
-- THREAD: CLEANUP AUTOMATIQUE
-- ========================================
CreateThread(function()
    DebugServer('Thread cleanup leaderboards démarré')
    
    while true do
        Wait(PERF.cleanupInterval)
        
        local now = GetGameTimer()
        local cleaned = 0
        
        for key, entry in pairs(leaderboardCache) do
            if (now - entry.timestamp) > PERF.leaderboardCacheDuration then
                leaderboardCache[key] = nil
                cleaned = cleaned + 1
            end
        end
        
        if cleaned > 0 then
            DebugServer('🧹 Leaderboard cache nettoyé: %d entrées', cleaned)
        end
    end
end)

-- ========================================
-- THREAD: PROCESS WEBHOOK QUEUE
-- ========================================
CreateThread(function()
    while true do
        Wait(PERF.webhookDelay)
        
        if #webhookQueue > 0 and activeWebhooks < PERF.maxConcurrentWebhooks then
            local request = table.remove(webhookQueue, 1)
            
            if request then
                activeWebhooks = activeWebhooks + 1
                
                CreateThread(function()
                    request.func()
                    activeWebhooks = activeWebhooks - 1
                end)
            end
        end
    end
end)

-- ========================================
-- FONCTION: AJOUTER À QUEUE WEBHOOK
-- ========================================
local function QueueWebhook(func)
    webhookQueue[#webhookQueue + 1] = {
        func = func,
        timestamp = GetGameTimer()
    }
end

-- ========================================
-- LOGGING
-- ========================================
local function LogError(msg) print("^1[PVP-Discord ERROR]^0 " .. tostring(msg)) end
local function LogSuccess(msg) print("^2[PVP-Discord OK]^0 " .. tostring(msg)) end
local function LogInfo(msg) print("^6[PVP-Discord]^0 " .. tostring(msg)) end

-- ========================================
-- SANITIZATION
-- ========================================
local function SanitizePlayerName(name)
    if not name or name == "" then 
        return "Joueur"
    end
    
    name = tostring(name)
    local cleaned = ""
    
    for i = 1, #name do
        local char = name:sub(i, i)
        local byte = string.byte(char)
        if (byte >= 65 and byte <= 90) or 
           (byte >= 97 and byte <= 122) or 
           (byte >= 48 and byte <= 57) or 
           byte == 32 or byte == 45 or byte == 95 or byte == 46 then
            cleaned = cleaned .. char
        end
    end
    
    if cleaned == "" or cleaned:match("^%s*$") then
        return "Joueur"
    end
    
    return cleaned:match("^%s*(.-)%s*$")
end

local function FormatPlayerName(name, maxLength)
    name = SanitizePlayerName(name)
    maxLength = maxLength or 15
    if #name > maxLength then
        return string.sub(name, 1, maxLength - 2) .. ".."
    end
    return name
end

local function SafeNumber(num, default)
    local n = tonumber(num)
    if n and n == n and n ~= math.huge and n ~= -math.huge then
        return n
    end
    return default or 0
end

local function CalculateKD(kills, deaths)
    kills = SafeNumber(kills, 0)
    deaths = SafeNumber(deaths, 0)
    if deaths == 0 then
        return kills > 0 and string.format("%.1f", kills) or "0.0"
    end
    return string.format("%.1f", kills / deaths)
end

local function FormatNumber(num)
    return tostring(math.floor(SafeNumber(num, 0)))
end

-- ========================================
-- OBTENIR RANG PAR ELO (9 RANGS)
-- ========================================
local function GetRankByElo(elo)
    elo = SafeNumber(elo, 0)
    
    for _, rank in ipairs(ConfigDiscordLeaderboard.RankSystem.ranks) do
        if elo >= rank.min_elo then
            return rank
        end
    end
    return ConfigDiscordLeaderboard.RankSystem.ranks[#ConfigDiscordLeaderboard.RankSystem.ranks]
end

-- ========================================
-- CONSTANTES
-- ========================================
local EMOJIS = {
    rank = {[1] = "🥇", [2] = "🥈", [3] = "🥉"},
    stats = {
        kills = "⚔️",
        deaths = "💀",
        kd = "📊",
        elo = "⚡",
        wins = "🏆",
        streak = "🔥",
        players = "👥"
    }
}

local COLORS = {
    ['1v1'] = 15158332,
    ['2v2'] = 3447003,
    ['3v3'] = 16750848,
    ['4v4'] = 5763719
}

local MODE_NAMES = {
    ['1v1'] = '1v1',
    ['2v2'] = '2v2',
    ['3v3'] = '3v3',
    ['4v4'] = '4v4'
}

-- ========================================
-- ✅ CRÉATION EMBED COMPACT (FIX 400)
-- ========================================
local function CreateLeaderboardEmbed(mode, leaderboardData)
    local modeName = MODE_NAMES[mode] or mode:upper()
    local color = COLORS[mode] or 15158332
    local logoUrl = 'https://r2.fivemanage.com/65OINTV6xwj2vOK7XWptj/logo.png'

    local fields = {}

    -- STATS GLOBALES (basées sur les 15 affichés)
    local totalPlayers = math.min(15, #leaderboardData)
    local totalKills = 0
    local totalDeaths = 0
    local totalElo = 0
    local bestStreak = 0

    for i = 1, totalPlayers do
        local p = leaderboardData[i]
        totalKills = totalKills + SafeNumber(p.kills, 0)
        totalDeaths = totalDeaths + SafeNumber(p.deaths, 0)
        totalElo = totalElo + SafeNumber(p.elo, 0)
        if SafeNumber(p.best_streak, 0) > bestStreak then
            bestStreak = SafeNumber(p.best_streak, 0)
        end
    end

    local avgElo = totalPlayers > 0 and math.floor(totalElo / totalPlayers) or 0
    local globalKD = CalculateKD(totalKills, totalDeaths)

    -- HEADER STATS
    if ConfigDiscordLeaderboard.ShowGlobalStatsTop then
        table.insert(fields, {
            name = "\u{200b}",
            value = string.format(
                "```\n👥 %s joueurs   ⚡ %s ELO moy   📊 %s K/D\n```",
                FormatNumber(totalPlayers), FormatNumber(avgElo), globalKD
            ),
            inline = false
        })
    end

    -- CLASSEMENT
    if #leaderboardData > 0 then
        local rankingText = ""

        for i = 1, math.min(15, #leaderboardData) do
            local data = leaderboardData[i]
            local playerName = FormatPlayerName(data.name, 14)
            local elo = SafeNumber(data.elo, 0)
            local kills = SafeNumber(data.kills, 0)
            local deaths = SafeNumber(data.deaths, 0)
            local kd = CalculateKD(kills, deaths)
            local rank = GetRankByElo(elo)
            local medal = EMOJIS.rank[i] or string.format("`#%d`", i)

            if i <= 3 then
                -- Top 3 : format detaille
                rankingText = rankingText .. string.format(
                    "%s **%s** %s %s\n┗ `%d ELO` • `%s K/D` • `%d/%d`\n\n",
                    medal, playerName, rank.emoji, rank.name,
                    elo, kd, kills, deaths
                )
            else
                -- 4-10 : format compact
                rankingText = rankingText .. string.format(
                    "`#%d` **%s** — %s %s • `%d` ⚡ • `%s` K/D\n",
                    i, playerName, rank.emoji, rank.name, elo, kd
                )
            end
        end

        table.insert(fields, {
            name = "CLASSEMENT",
            value = rankingText,
            inline = false
        })
    else
        table.insert(fields, {
            name = "CLASSEMENT",
            value = "Aucun joueur dans le classement.",
            inline = false
        })
    end

    -- CONSTRUCTION EMBED
    local embed = {
        author = {
            name = "RANKED FIGHT LEAGUE • SAISON 2",
            icon_url = logoUrl
        },
        title = "━━━  " .. modeName .. "  ━━━",
        color = color,
        fields = fields,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        thumbnail = { url = logoUrl },
        footer = {
            text = "Ranked Fight League PVP • " .. os.date("%d/%m/%Y %H:%M"),
            icon_url = logoUrl
        }
    }

    return embed
end

-- ========================================
-- ENVOYER CLASSEMENT (AVEC CACHE + QUEUE)
-- ========================================
local function SendLeaderboardToDiscord(mode, callback)
    local now = os.time()
    local lastSend = lastSendTime[mode] or 0
    
    if (now - lastSend) < (PERF.minTimeBetweenSends / 1000) then
        LogInfo('Rate limited: %s', mode)
        if callback then callback(false) end
        return
    end
    
    LogInfo('Récupération webhook ' .. mode .. ' (sécurisé)...')
    
    exports['pvp_gunfight']:GetWebhookURL(mode, function(webhook)
        if not webhook or webhook == '' then
            LogError('Webhook Discord manquant pour mode: ' .. mode)
            LogInfo('💡 Utilisez /gfrankedsetwebhook ' .. mode .. ' [url]')
            if callback then callback(false) end
            return
        end
        
        LogInfo('Webhook ' .. mode .. ' récupéré')
        
        local cacheKey = mode .. '_leaderboard'
        local cached = leaderboardCache[cacheKey]
        
        if cached and (GetGameTimer() - cached.timestamp) < PERF.leaderboardCacheDuration then
            stats.cacheHits = stats.cacheHits + 1
            LogInfo('📦 Cache HIT: Leaderboard ' .. mode)
            
            local embed = cached.embed
            
            QueueWebhook(function()
                SendWebhookEmbed(webhook, embed, mode, callback)
            end)
        else
            stats.cacheMisses = stats.cacheMisses + 1
            LogInfo('🔍 Cache MISS: Leaderboard ' .. mode .. ' - SQL query')
            
            exports['pvp_gunfight']:GetLeaderboardByMode(mode, 50, function(leaderboard)
                if not leaderboard then
                    LogError('Impossible de récupérer le classement pour ' .. mode)
                    if callback then callback(false) end
                    return
                end
                
                LogInfo('Classement ' .. mode .. ' récupéré: ' .. #leaderboard .. ' joueurs')
                
                local embed = CreateLeaderboardEmbed(mode, leaderboard)
                
                leaderboardCache[cacheKey] = {
                    embed = embed,
                    timestamp = GetGameTimer()
                }
                
                QueueWebhook(function()
                    SendWebhookEmbed(webhook, embed, mode, callback)
                end)
            end)
        end
    end)
end

-- ========================================
-- ENVOYER EMBED WEBHOOK
-- ========================================
function SendWebhookEmbed(webhook, embed, mode, callback)
    local payload = {
        username = 'Fight League',
        embeds = {embed}
    }
    
    if ConfigDiscordLeaderboard.BotAvatar and ConfigDiscordLeaderboard.BotAvatar ~= "" then
        payload.avatar_url = ConfigDiscordLeaderboard.BotAvatar
    end
    
    local success, jsonPayload = pcall(json.encode, payload)
    
    if not success then
        LogError('Erreur encodage JSON: ' .. tostring(jsonPayload))
        if callback then callback(false) end
        return
    end
    
    -- ✅ VÉRIFICATION TAILLE (< 6000 chars)
    if #jsonPayload > 5900 then
        LogError('Embed trop long: ' .. #jsonPayload .. ' chars (max 6000)')
        if callback then callback(false) end
        return
    end
    
    stats.webhooksSent = stats.webhooksSent + 1
    
    PerformHttpRequest(webhook, function(statusCode, responseBody, headers)
        if statusCode == 204 or statusCode == 200 then
            LogSuccess('Classement ' .. mode .. ' envoyé sur Discord ✅')
            lastSendTime[mode] = os.time()
            if callback then callback(true) end
        else
            stats.webhookErrors = stats.webhookErrors + 1
            LogError('Erreur envoi Discord ' .. mode .. ' (Status: ' .. tostring(statusCode) .. ')')
            if responseBody then
                LogError('Réponse: ' .. string.sub(tostring(responseBody), 1, 200))
            end
            if callback then callback(false) end
        end
    end, 'POST', jsonPayload, {
        ['Content-Type'] = 'application/json'
    })
end

-- ========================================
-- ENVOYER TOUS LES CLASSEMENTS
-- ========================================
local function SendAllLeaderboards(callback)
    if isSending then
        LogInfo('Envoi déjà en cours...')
        if callback then callback(false) end
        return
    end
    
    isSending = true
    LogInfo('=============================================')
    LogInfo('ENVOI CLASSEMENTS DISCORD (4 modes) 🔒')
    LogInfo('=============================================')
    
    local modes = {'1v1', '2v2', '3v3', '4v4'}
    local completed = 0
    local success = 0
    
    for i = 1, #modes do
        local mode = modes[i]
        
        Citizen.SetTimeout(i * 2000, function()
            SendLeaderboardToDiscord(mode, function(result)
                completed = completed + 1
                if result then success = success + 1 end
                
                if completed == #modes then
                    isSending = false
                    LogInfo('=============================================')
                    LogSuccess('ENVOI TERMINÉ: ' .. success .. '/' .. #modes .. ' MODES')
                    LogInfo('=============================================')
                    if callback then callback(success == #modes) end
                end
            end)
        end)
    end
end

-- ========================================
-- VÉRIFIER SI HEURE D'ENVOI
-- ========================================
local function ShouldSendNow()
    if not ConfigDiscordLeaderboard.AutoSend then
        return false
    end
    
    local currentTime = os.time()
    local currentDate = os.date("*t", currentTime)
    
    if ConfigDiscordLeaderboard.AutoSendTime then
        local targetHour = ConfigDiscordLeaderboard.AutoSendTime.hour
        local targetMinute = ConfigDiscordLeaderboard.AutoSendTime.minute or 0
        
        if currentDate.hour == targetHour and currentDate.min == targetMinute then
            local lastSend = lastSendTime['daily'] or 0
            local daysSinceLastSend = math.floor((currentTime - lastSend) / 86400)
            return daysSinceLastSend >= 1
        end
        return false
    else
        local lastSend = lastSendTime['interval'] or 0
        local hoursSinceLastSend = (currentTime - lastSend) / 3600
        return hoursSinceLastSend >= ConfigDiscordLeaderboard.AutoSendInterval
    end
end

-- ========================================
-- THREAD: ENVOI AUTOMATIQUE
-- ========================================
if ConfigDiscordLeaderboard.AutoSend then
    CreateThread(function()
        Wait(10000)
        LogSuccess('Système d\'envoi automatique activé (Webhooks sécurisés)')
        
        if ConfigDiscordLeaderboard.AutoSendTime then
            LogInfo('Envoi quotidien: ' .. string.format('%02d:%02d', 
                ConfigDiscordLeaderboard.AutoSendTime.hour,
                ConfigDiscordLeaderboard.AutoSendTime.minute or 0
            ))
        else
            LogInfo('Intervalle: toutes les ' .. ConfigDiscordLeaderboard.AutoSendInterval .. ' heures')
        end
        
        while true do
            Wait(60000)
            if ShouldSendNow() then
                SendAllLeaderboards(function(success)
                    if success then
                        if ConfigDiscordLeaderboard.AutoSendTime then
                            lastSendTime['daily'] = os.time()
                        else
                            lastSendTime['interval'] = os.time()
                        end
                    end
                end)
            end
        end
    end)
end

-- ========================================
-- COMMANDES ADMIN
-- ========================================
RegisterCommand(ConfigDiscordLeaderboard.Commands.sendLeaderboard or 'pvpleaderboard', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, ConfigDiscordLeaderboard.AdminAce) then
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        end
        return
    end
    
    if source > 0 then
        TriggerClientEvent('esx:showNotification', source, '~b~Envoi des classements... 🔒')
    else
        print('[PVP] Envoi des 4 classements - Webhooks sécurisés...')
    end
    
    SendAllLeaderboards(function(success)
        if source > 0 then
            if success then
                TriggerClientEvent('esx:showNotification', source, '~g~Classements envoyés! ✅')
            else
                TriggerClientEvent('esx:showNotification', source, '~o~Erreur lors de l\'envoi')
            end
        else
            if success then
                print('[PVP] Classements envoyés avec succès')
            else
                print('[PVP] Erreur lors de l\'envoi')
            end
        end
    end)
end, false)

RegisterCommand('pvpsendmode', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, ConfigDiscordLeaderboard.AdminAce) then
        return
    end
    
    local mode = args[1]
    if not mode then
        if source > 0 then
            TriggerClientEvent('esx:showNotification', source, '~r~Mode invalide. Utilisez: 1v1, 2v2, 3v3, 4v4')
        else
            print('[PVP] Mode invalide. Utilisez: 1v1, 2v2, 3v3, 4v4')
        end
        return
    end
    
    SendLeaderboardToDiscord(mode, function(success)
        if source > 0 then
            if success then
                TriggerClientEvent('esx:showNotification', source, '~g~Classement ' .. mode .. ' envoyé! ✅')
            else
                TriggerClientEvent('esx:showNotification', source, '~r~Erreur envoi ' .. mode)
            end
        end
    end)
end, false)

-- ========================================
-- COMMANDE: CLEAR CACHE
-- ========================================
RegisterCommand('pvpclearcache', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, ConfigDiscordLeaderboard.AdminAce) then
        return
    end
    
    leaderboardCache = {}
    
    local msg = '✅ Cache leaderboard vidé'
    if source == 0 then
        print(msg)
    else
        TriggerClientEvent('esx:showNotification', source, '~g~' .. msg)
    end
end, false)

-- ========================================
-- EXPORTS
-- ========================================
exports('SendLeaderboardToDiscord', SendLeaderboardToDiscord)
exports('SendAllLeaderboards', SendAllLeaderboards)

LogSuccess('Module Discord Leaderboards v5.1.0 (FIX 400) initialisé')
LogSuccess('✅ 9 rangs Master | Embed compact | Cache 5min')