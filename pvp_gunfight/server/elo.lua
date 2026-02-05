-- ========================================
-- PVP GUNFIGHT - SYSTÈME ELO ULTRA-OPTIMISÉ
-- Version 7.0.0 - RANGS MASTER + DIFFICULTÉ PROGRESSIVE
-- ========================================
-- ✅ Cache stats joueurs (5 minutes)
-- ✅ Requêtes SQL asynchrones uniquement
-- ✅ Batch updates (plusieurs joueurs en 1 requête)
-- ✅ Calculs ELO simplifiés (pas de formules complexes)
-- ✅ Pas de SELECT avant UPDATE
-- ✅ Index MySQL optimisés
-- ✅ BRUTAL NOTIFY intégré
-- ✅ NOUVEAUX RANGS: Master 3, Master 2, Master 1
-- ✅ DIFFICULTÉ PROGRESSIVE à partir de Diamant
-- ========================================

DebugElo('Module ELO chargé (VERSION 7.0.0 - RANGS MASTER)')

-- ========================================
-- CONFIGURATION PERFORMANCE
-- ========================================
local PERF = {
    -- Cache
    playerStatsCacheDuration = 300000,  -- ✅ 5 minutes
    leaderboardCacheDuration = 60000,   -- ✅ 1 minute
    
    -- Batch
    maxBatchSize = 20,                  -- ✅ Max 20 requêtes par batch
    batchDelay = 100,                   -- ✅ 100ms entre batches
}

-- ========================================
-- CACHE GLOBAL
-- ========================================
local playerStatsCache = {}
local leaderboardCache = {}

-- ========================================
-- CONFIGURATION ELO AVEC DIFFICULTÉ PROGRESSIVE
-- ========================================
local ELO_CONFIG = {
    -- ✅ GAINS ET PERTES DE BASE
    baseWinElo = 30,        -- Gain de base par victoire
    baseLoseElo = 12,       -- Perte de base par défaite
    
    -- ✅ BONUS STREAK
    winStreakBonus = 5,     -- Bonus par victoire consécutive (max 3)
    maxStreakBonus = 15,    -- Bonus maximum de streak (3 victoires = +15)
    
    -- ✅ MULTIPLICATEURS PAR MODE (tous à 1.0 pour simplifier)
    modeMultipliers = {
        ['1v1'] = 1.0,
        ['2v2'] = 1.0,
        ['3v3'] = 1.0,
        ['4v4'] = 1.0
    },
    
    -- ✅ PROTECTION DE BASE
    maxLossPerMatch = 20,   -- Maximum d'ELO perdu en un match (pour rangs bas)
    minEloGain = 20,        -- Minimum d'ELO gagné (pour rangs bas)
    
    minimumElo = 0,
    startingElo = 0,
    
    -- ========================================
    -- ✅ RANGS AVEC MASTER 3, 2, 1
    -- ========================================
    rankThresholds = {
        -- Rangs faciles (progression normale)
        {id = 1, name = "Bronze",    min = 0,    max = 999,  color = "^9", emoji = "🥉"},
        {id = 2, name = "Argent",    min = 1000, max = 1499, color = "^7", emoji = "⚪"},
        {id = 3, name = "Or",        min = 1500, max = 1999, color = "^3", emoji = "🥇"},
        {id = 4, name = "Platine",   min = 2000, max = 2499, color = "^4", emoji = "💎"},
        {id = 5, name = "Émeraude",  min = 2500, max = 2999, color = "^2", emoji = "💚"},
        
        -- Rangs difficiles (progression réduite)
        {id = 6, name = "Diamant",   min = 3000, max = 3499, color = "^5", emoji = "💠"},
        {id = 7, name = "Master 3",  min = 3500, max = 3999, color = "^6", emoji = "🔥"},
        {id = 8, name = "Master 2",  min = 4000, max = 4499, color = "^6", emoji = "🔥🔥"},
        {id = 9, name = "Master 1",  min = 4500, max = 99999, color = "^1", emoji = "👑"},
    },
    
    -- ========================================
    -- ✅ MULTIPLICATEURS DE DIFFICULTÉ PAR RANG
    -- ========================================
    -- À partir de Diamant, la progression devient plus difficile
    -- gainMultiplier: multiplie les gains (< 1.0 = moins de gains)
    -- lossMultiplier: multiplie les pertes (> 1.0 = plus de pertes)
    -- streakMultiplier: multiplie le bonus de streak (< 1.0 = moins de bonus)
    -- minGain: gain minimum garanti pour ce rang
    -- maxLoss: perte maximum pour ce rang
    
    rankDifficulty = {
        -- Rangs faciles: progression normale
        [1] = { -- Bronze
            gainMultiplier = 1.0,
            lossMultiplier = 0.8,   -- Pertes réduites pour aider les nouveaux
            streakMultiplier = 1.0,
            minGain = 25,
            maxLoss = 15
        },
        [2] = { -- Argent
            gainMultiplier = 1.0,
            lossMultiplier = 0.9,
            streakMultiplier = 1.0,
            minGain = 22,
            maxLoss = 18
        },
        [3] = { -- Or
            gainMultiplier = 1.0,
            lossMultiplier = 1.0,
            streakMultiplier = 1.0,
            minGain = 20,
            maxLoss = 20
        },
        [4] = { -- Platine
            gainMultiplier = 0.95,
            lossMultiplier = 1.0,
            streakMultiplier = 1.0,
            minGain = 18,
            maxLoss = 22
        },
        [5] = { -- Émeraude
            gainMultiplier = 0.90,
            lossMultiplier = 1.1,
            streakMultiplier = 0.9,
            minGain = 16,
            maxLoss = 25
        },
        
        -- ========================================
        -- Rangs difficiles: progression réduite
        -- ========================================
        [6] = { -- Diamant (début de la difficulté)
            gainMultiplier = 0.75,      -- 25% de gains en moins
            lossMultiplier = 1.3,       -- 30% de pertes en plus
            streakMultiplier = 0.7,     -- Streak moins efficace
            minGain = 12,               -- Gain minimum réduit
            maxLoss = 30                -- Perte maximum augmentée
        },
        [7] = { -- Master 3 (très difficile)
            gainMultiplier = 0.60,      -- 40% de gains en moins
            lossMultiplier = 1.5,       -- 50% de pertes en plus
            streakMultiplier = 0.5,     -- Streak beaucoup moins efficace
            minGain = 10,
            maxLoss = 35
        },
        [8] = { -- Master 2 (extrêmement difficile)
            gainMultiplier = 0.50,      -- 50% de gains en moins
            lossMultiplier = 1.7,       -- 70% de pertes en plus
            streakMultiplier = 0.3,     -- Streak presque inutile
            minGain = 8,
            maxLoss = 40
        },
        [9] = { -- Master 1 (élite - le plus dur)
            gainMultiplier = 0.40,      -- 60% de gains en moins
            lossMultiplier = 2.0,       -- Pertes doublées
            streakMultiplier = 0.2,     -- Streak quasi inexistant
            minGain = 6,
            maxLoss = 50
        },
    },
    
    -- ✅ BONUS/MALUS SELON DIFFÉRENCE DE RANG
    -- Si tu bats quelqu'un de rang supérieur = bonus
    -- Si tu perds contre quelqu'un de rang inférieur = malus
    rankDifferenceBonus = {
        -- Victoire contre rang supérieur
        [1] = 1.1,   -- +1 rang = +10% ELO
        [2] = 1.25,  -- +2 rangs = +25% ELO
        [3] = 1.5,   -- +3 rangs = +50% ELO
        
        -- Défaite contre rang inférieur
        [-1] = 1.1,  -- -1 rang = +10% perte
        [-2] = 1.25, -- -2 rangs = +25% perte
        [-3] = 1.5,  -- -3 rangs = +50% perte
    }
}

-- ========================================
-- ✅ FONCTION: NETTOYER CACHE EXPIRÉ
-- ========================================
local function CleanExpiredCache(cache, maxAge)
    local now = GetGameTimer()
    local cleaned = 0
    
    for key, entry in pairs(cache) do
        if entry.timestamp and (now - entry.timestamp) > maxAge then
            cache[key] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        DebugElo('🧹 Cache nettoyé: %d entrées expirées', cleaned)
    end
end

-- ========================================
-- ✅ THREAD: CLEANUP CACHE AUTOMATIQUE (60s)
-- ========================================
CreateThread(function()
    while true do
        Wait(60000)
        
        CleanExpiredCache(playerStatsCache, PERF.playerStatsCacheDuration)
        CleanExpiredCache(leaderboardCache, PERF.leaderboardCacheDuration)
    end
end)

-- ========================================
-- ✅ FONCTION: OBTENIR RANG PAR ELO
-- ========================================
function GetRankByElo(elo)
    elo = elo or 0
    
    -- Parcourir du rang le plus haut au plus bas
    for i = #ELO_CONFIG.rankThresholds, 1, -1 do
        local rank = ELO_CONFIG.rankThresholds[i]
        if elo >= rank.min then
            return rank
        end
    end
    
    return ELO_CONFIG.rankThresholds[1] -- Bronze par défaut
end

-- ========================================
-- ✅ FONCTION: OBTENIR DIFFICULTÉ DU RANG
-- ========================================
local function GetRankDifficulty(rankId)
    return ELO_CONFIG.rankDifficulty[rankId] or ELO_CONFIG.rankDifficulty[1]
end

-- ========================================
-- ✅ FONCTION: OBTENIR BONUS/MALUS DIFFÉRENCE RANG
-- ========================================
local function GetRankDifferenceMultiplier(winnerRankId, loserRankId, isWinner)
    local diff = loserRankId - winnerRankId -- Positif si l'adversaire est plus haut
    
    if isWinner then
        -- Gagnant: bonus si adversaire plus haut rang
        return ELO_CONFIG.rankDifferenceBonus[diff] or 1.0
    else
        -- Perdant: malus si adversaire plus bas rang
        return ELO_CONFIG.rankDifferenceBonus[-diff] or 1.0
    end
end

-- ========================================
-- ✅ CALCUL ELO AVEC DIFFICULTÉ PROGRESSIVE
-- ========================================
function CalculateEloChange(winnerElo, loserElo, winnerRankId, loserRankId, scoreRatio, mode, winnerStreak)
    winnerStreak = winnerStreak or 0
    
    -- ✅ Récupérer les rangs complets
    local winnerRank = GetRankByElo(winnerElo)
    local loserRank = GetRankByElo(loserElo)
    
    -- ✅ Récupérer les difficultés de rang
    local winnerDifficulty = GetRankDifficulty(winnerRank.id)
    local loserDifficulty = GetRankDifficulty(loserRank.id)
    
    -- ✅ Multiplicateur de mode
    local modeMultiplier = ELO_CONFIG.modeMultipliers[mode] or 1.0
    
    -- ========================================
    -- CALCUL GAIN GAGNANT
    -- ========================================
    local winnerGain = ELO_CONFIG.baseWinElo
    
    -- ✅ Bonus de streak (affecté par la difficulté du rang)
    if winnerStreak > 0 then
        local baseStreakBonus = math.min(winnerStreak * ELO_CONFIG.winStreakBonus, ELO_CONFIG.maxStreakBonus)
        local streakBonus = math.floor(baseStreakBonus * winnerDifficulty.streakMultiplier)
        winnerGain = winnerGain + streakBonus
        
        DebugElo('🔥 Bonus streak: +%d ELO (base: %d, multiplier: %.2f, streak: %d)', 
            streakBonus, baseStreakBonus, winnerDifficulty.streakMultiplier, winnerStreak)
    end
    
    -- ✅ Appliquer multiplicateur de mode
    winnerGain = winnerGain * modeMultiplier
    
    -- ✅ Appliquer multiplicateur de difficulté du rang du GAGNANT
    winnerGain = math.floor(winnerGain * winnerDifficulty.gainMultiplier)
    
    -- ✅ Bonus si adversaire de rang supérieur
    local rankBonus = GetRankDifferenceMultiplier(winnerRank.id, loserRank.id, true)
    if rankBonus > 1.0 then
        winnerGain = math.floor(winnerGain * rankBonus)
        DebugElo('⬆️ Bonus rang supérieur: x%.2f', rankBonus)
    end
    
    -- ✅ Garantir le gain minimum du rang
    winnerGain = math.max(winnerGain, winnerDifficulty.minGain)
    
    -- ========================================
    -- CALCUL PERTE PERDANT
    -- ========================================
    local loserLoss = ELO_CONFIG.baseLoseElo
    
    -- ✅ Appliquer multiplicateur de mode
    loserLoss = loserLoss * modeMultiplier
    
    -- ✅ Appliquer multiplicateur de difficulté du rang du PERDANT
    loserLoss = math.floor(loserLoss * loserDifficulty.lossMultiplier)
    
    -- ✅ Malus si adversaire de rang inférieur
    local rankMalus = GetRankDifferenceMultiplier(loserRank.id, winnerRank.id, false)
    if rankMalus > 1.0 then
        loserLoss = math.floor(loserLoss * rankMalus)
        DebugElo('⬇️ Malus rang inférieur: x%.2f', rankMalus)
    end
    
    -- ✅ Limiter la perte maximum du rang
    loserLoss = math.min(loserLoss, loserDifficulty.maxLoss)
    
    -- ========================================
    -- CALCUL FINAL
    -- ========================================
    local winnerNewElo = winnerElo + winnerGain
    local loserNewElo = math.max(ELO_CONFIG.minimumElo, loserElo - loserLoss)
    
    -- ✅ Log détaillé
    DebugElo('📊 === CALCUL ELO ===')
    DebugElo('📊 Gagnant: %s (%d ELO) → +%d = %d ELO', winnerRank.name, winnerElo, winnerGain, winnerNewElo)
    DebugElo('📊 Perdant: %s (%d ELO) → -%d = %d ELO', loserRank.name, loserElo, loserLoss, loserNewElo)
    DebugElo('📊 Difficulté gagnant: gain x%.2f, streak x%.2f, min %d', 
        winnerDifficulty.gainMultiplier, winnerDifficulty.streakMultiplier, winnerDifficulty.minGain)
    DebugElo('📊 Difficulté perdant: loss x%.2f, max %d', 
        loserDifficulty.lossMultiplier, loserDifficulty.maxLoss)
    
    return {
        winnerNewElo = winnerNewElo,
        loserNewElo = loserNewElo,
        winnerChange = winnerGain,
        loserChange = -loserLoss,
        winnerRank = winnerRank,
        loserRank = loserRank,
        winnerNewRank = GetRankByElo(winnerNewElo),
        loserNewRank = GetRankByElo(loserNewElo)
    }
end

-- ========================================
-- ✅ INITIALISATION STATS (ASYNC + BATCH)
-- ========================================
function InitPlayerModeStats(identifier, playerName)
    DebugElo('Init stats par mode: %s', identifier)
    
    local modes = {'1v1', '2v2', '3v3', '4v4'}
    
    -- ✅ BATCH INSERT (1 seule requête pour tous les modes)
    local values = {}
    for i = 1, #modes do
        values[#values + 1] = string.format(
            "('%s', '%s', %d, 1, %d, 0, 0, 0, 0, 0, 0, 0)",
            identifier, modes[i], ELO_CONFIG.startingElo, ELO_CONFIG.startingElo
        )
    end
    
    local query = string.format([[
        INSERT IGNORE INTO pvp_stats_modes 
        (identifier, mode, elo, rank_id, best_elo, kills, deaths, wins, losses, matches_played, win_streak, best_win_streak) 
        VALUES %s
    ]], table.concat(values, ','))
    
    MySQL.query(query, {}, function(result)
        if result then
            DebugElo('✅ Stats initialisées pour %s (batch)', identifier)
        end
    end)
end

-- ========================================
-- ✅ RÉCUPÉRATION STATS (AVEC CACHE)
-- ========================================
function GetPlayerStatsByMode(identifier, mode, callback)
    local cacheKey = identifier .. '_' .. mode
    local now = GetGameTimer()
    
    -- ✅ Vérifier cache
    local cached = playerStatsCache[cacheKey]
    if cached and (now - cached.timestamp) < PERF.playerStatsCacheDuration then
        DebugElo('📦 Cache HIT: %s', cacheKey)
        callback(cached.data)
        return
    end
    
    -- ✅ Cache MISS - Requête SQL
    DebugElo('🔍 Cache MISS: %s - SQL query', cacheKey)
    
    MySQL.single([[
        SELECT * FROM pvp_stats_modes WHERE identifier = ? AND mode = ?
    ]], {identifier, mode}, function(result)
        if result then
            -- ✅ Mettre en cache
            playerStatsCache[cacheKey] = {
                data = result,
                timestamp = GetGameTimer()
            }
            callback(result)
        else
            -- ✅ Créer entrée si elle n'existe pas
            MySQL.insert([[
                INSERT INTO pvp_stats_modes 
                (identifier, mode, elo, rank_id, best_elo) VALUES (?, ?, ?, 1, ?)
            ]], {identifier, mode, ELO_CONFIG.startingElo, ELO_CONFIG.startingElo}, function()
                local newStats = {
                    identifier = identifier,
                    mode = mode,
                    elo = ELO_CONFIG.startingElo,
                    rank_id = 1,
                    best_elo = ELO_CONFIG.startingElo,
                    kills = 0,
                    deaths = 0,
                    wins = 0,
                    losses = 0,
                    matches_played = 0,
                    win_streak = 0,
                    best_win_streak = 0
                }
                
                -- ✅ Mettre en cache
                playerStatsCache[cacheKey] = {
                    data = newStats,
                    timestamp = GetGameTimer()
                }
                
                callback(newStats)
            end)
        end
    end)
end

-- ✅ INVALIDER CACHE (après update)
local function InvalidatePlayerCache(identifier, mode)
    local cacheKey = identifier .. '_' .. mode
    playerStatsCache[cacheKey] = nil
    DebugElo('🗑️ Cache invalidé: %s', cacheKey)
end

-- ========================================
-- ✅ RÉCUPÉRATION TOUS MODES (AVEC CACHE)
-- ========================================
function GetPlayerAllModeStats(identifier, callback)
    local cacheKey = identifier .. '_all'
    local now = GetGameTimer()
    
    -- ✅ Vérifier cache
    local cached = playerStatsCache[cacheKey]
    if cached and (now - cached.timestamp) < PERF.playerStatsCacheDuration then
        DebugElo('📦 Cache HIT: %s', cacheKey)
        callback(cached.data)
        return
    end
    
    -- ✅ Cache MISS - Requête SQL
    DebugElo('🔍 Cache MISS: %s - SQL query', cacheKey)
    
    MySQL.query([[
        SELECT * FROM pvp_stats_modes WHERE identifier = ? ORDER BY FIELD(mode, '1v1', '2v2', '3v3', '4v4')
    ]], {identifier}, function(results)
        local statsByMode = {}
        local modes = {'1v1', '2v2', '3v3', '4v4'}
        
        if results then
            for i = 1, #results do
                statsByMode[results[i].mode] = results[i]
            end
        end
        
        -- ✅ Remplir modes manquants
        for i = 1, #modes do
            if not statsByMode[modes[i]] then
                statsByMode[modes[i]] = {
                    identifier = identifier,
                    mode = modes[i],
                    elo = ELO_CONFIG.startingElo,
                    rank_id = 1,
                    best_elo = ELO_CONFIG.startingElo,
                    kills = 0,
                    deaths = 0,
                    wins = 0,
                    losses = 0,
                    matches_played = 0,
                    win_streak = 0,
                    best_win_streak = 0
                }
            end
        end
        
        -- ✅ Mettre en cache
        playerStatsCache[cacheKey] = {
            data = statsByMode,
            timestamp = GetGameTimer()
        }
        
        callback(statsByMode)
    end)
end

-- ========================================
-- ✅ MISE À JOUR ELO - 1V1 (OPTIMISÉE + BRUTAL NOTIFY)
-- ========================================
function UpdatePlayerElo1v1ByMode(winnerId, loserId, finalScore, mode)
    local xWinner = ESX.GetPlayerFromId(winnerId)
    local xLoser = ESX.GetPlayerFromId(loserId)
    
    if not xWinner or not xLoser then
        DebugError('Joueur introuvable pour mise à jour ELO')
        return
    end
    
    DebugElo('[%s] Mise à jour ELO 1v1 (AVEC DIFFICULTÉ PROGRESSIVE)', mode)
    
    -- ✅ Récupérer stats en parallèle
    GetPlayerStatsByMode(xWinner.identifier, mode, function(winnerStats)
        GetPlayerStatsByMode(xLoser.identifier, mode, function(loserStats)
            local winnerElo = winnerStats.elo or ELO_CONFIG.startingElo
            local loserElo = loserStats.elo or ELO_CONFIG.startingElo
            local winnerRankId = winnerStats.rank_id or 1
            local loserRankId = loserStats.rank_id or 1
            local winnerBestElo = winnerStats.best_elo or ELO_CONFIG.startingElo
            local loserBestElo = loserStats.best_elo or ELO_CONFIG.startingElo
            local winnerStreak = (winnerStats.win_streak or 0) + 1
            local winnerBestStreak = math.max(winnerStats.best_win_streak or 0, winnerStreak)
            
            local winnerScore = math.max(finalScore.team1, finalScore.team2)
            local loserScore = math.min(finalScore.team1, finalScore.team2)
            local scoreRatio = loserScore / winnerScore
            
            -- ✅ CALCUL AVEC DIFFICULTÉ PROGRESSIVE
            local eloResult = CalculateEloChange(winnerElo, loserElo, winnerRankId, loserRankId, scoreRatio, mode, winnerStreak - 1)
            
            local newWinnerBestElo = math.max(winnerBestElo, eloResult.winnerNewElo)
            local newLoserBestElo = math.max(loserBestElo, eloResult.loserNewElo)
            
            -- ✅ BATCH UPDATE (2 requêtes en parallèle)
            CreateThread(function()
                MySQL.update([[
                    UPDATE pvp_stats_modes 
                    SET elo = ?, rank_id = ?, best_elo = ?, wins = wins + 1, 
                        matches_played = matches_played + 1, win_streak = ?, best_win_streak = ?
                    WHERE identifier = ? AND mode = ?
                ]], {eloResult.winnerNewElo, eloResult.winnerNewRank.id, newWinnerBestElo, winnerStreak, winnerBestStreak, xWinner.identifier, mode}, function()
                    InvalidatePlayerCache(xWinner.identifier, mode)
                    InvalidatePlayerCache(xWinner.identifier, 'all')
                end)
            end)
            
            CreateThread(function()
                MySQL.update([[
                    UPDATE pvp_stats_modes 
                    SET elo = ?, rank_id = ?, best_elo = ?, losses = losses + 1, 
                        matches_played = matches_played + 1, win_streak = 0
                    WHERE identifier = ? AND mode = ?
                ]], {eloResult.loserNewElo, eloResult.loserNewRank.id, newLoserBestElo, xLoser.identifier, mode}, function()
                    InvalidatePlayerCache(xLoser.identifier, mode)
                    InvalidatePlayerCache(xLoser.identifier, 'all')
                end)
            end)
            
            -- ✅ Stats globales (async)
            CreateThread(function()
                UpdateGlobalStats(xWinner.identifier, eloResult.winnerNewElo, eloResult.winnerNewRank.id, true)
            end)
            
            CreateThread(function()
                UpdateGlobalStats(xLoser.identifier, eloResult.loserNewElo, eloResult.loserNewRank.id, false)
            end)
            
            -- ✅ BRUTAL NOTIFY - Gagnant (avec emoji rang)
            local winnerRankEmoji = eloResult.winnerNewRank.emoji or ""
            TriggerClientEvent('brutal_notify:SendAlert', winnerId, 
                winnerRankEmoji .. ' ELO ' .. mode,
                string.format('+%d ELO (%d) | %s | 🔥 Streak: %d', 
                    eloResult.winnerChange, eloResult.winnerNewElo, eloResult.winnerNewRank.name, winnerStreak),
                5000, 'success')
            
            -- ✅ BRUTAL NOTIFY - Perdant (avec emoji rang)
            local loserRankEmoji = eloResult.loserNewRank.emoji or ""
            TriggerClientEvent('brutal_notify:SendAlert', loserId, 
                loserRankEmoji .. ' ELO ' .. mode,
                string.format('%d ELO (%d) | %s', 
                    eloResult.loserChange, eloResult.loserNewElo, eloResult.loserNewRank.name),
                5000, 'error')
            
            -- ✅ BRUTAL NOTIFY - Promotion
            if eloResult.winnerNewRank.id > winnerRankId then
                local promoEmoji = eloResult.winnerNewRank.emoji or "🎉"
                TriggerClientEvent('brutal_notify:SendAlert', winnerId, 
                    promoEmoji .. ' PROMOTION ' .. mode,
                    string.format('Félicitations! Vous êtes maintenant %s!', eloResult.winnerNewRank.name),
                    6000, 'success')
                
                -- Message spécial pour les rangs Master
                if eloResult.winnerNewRank.id >= 7 then
                    TriggerClientEvent('brutal_notify:SendAlert', winnerId, 
                        '⚠️ ATTENTION',
                        'La progression devient plus difficile à ce rang!',
                        4000, 'warning')
                end
            end
            
            -- ✅ BRUTAL NOTIFY - Rétrogradation
            if eloResult.loserNewRank.id < loserRankId then
                local demoteEmoji = eloResult.loserNewRank.emoji or "⚠️"
                TriggerClientEvent('brutal_notify:SendAlert', loserId, 
                    demoteEmoji .. ' RÉTROGRADATION ' .. mode,
                    string.format('Vous êtes redescendu %s', eloResult.loserNewRank.name),
                    6000, 'warning')
            end
        end)
    end)
end

-- ========================================
-- ✅ MISE À JOUR ELO - ÉQUIPE (OPTIMISÉE + BRUTAL NOTIFY)
-- ========================================
function UpdateTeamEloByMode(winners, losers, finalScore, mode)
    DebugElo('[%s] Mise à jour ELO équipe (AVEC DIFFICULTÉ PROGRESSIVE)', mode)
    
    local winnersData = {}
    local losersData = {}
    local winnersProcessed = 0
    local losersProcessed = 0
    
    -- ✅ Récupérer toutes les stats en parallèle
    for i = 1, #winners do
        local xWinner = ESX.GetPlayerFromId(winners[i])
        if xWinner then
            GetPlayerStatsByMode(xWinner.identifier, mode, function(stats)
                winnersData[#winnersData + 1] = {
                    playerId = winners[i],
                    identifier = xWinner.identifier,
                    elo = stats.elo or ELO_CONFIG.startingElo,
                    rankId = stats.rank_id or 1,
                    bestElo = stats.best_elo or ELO_CONFIG.startingElo,
                    winStreak = (stats.win_streak or 0) + 1,
                    bestWinStreak = stats.best_win_streak or 0
                }
                winnersProcessed = winnersProcessed + 1
                
                if winnersProcessed == #winners and losersProcessed == #losers then
                    ProcessTeamEloUpdateByMode(winnersData, losersData, finalScore, mode)
                end
            end)
        else
            winnersProcessed = winnersProcessed + 1
        end
    end
    
    for i = 1, #losers do
        local xLoser = ESX.GetPlayerFromId(losers[i])
        if xLoser then
            GetPlayerStatsByMode(xLoser.identifier, mode, function(stats)
                losersData[#losersData + 1] = {
                    playerId = losers[i],
                    identifier = xLoser.identifier,
                    elo = stats.elo or ELO_CONFIG.startingElo,
                    rankId = stats.rank_id or 1,
                    bestElo = stats.best_elo or ELO_CONFIG.startingElo
                }
                losersProcessed = losersProcessed + 1
                
                if winnersProcessed == #winners and losersProcessed == #losers then
                    ProcessTeamEloUpdateByMode(winnersData, losersData, finalScore, mode)
                end
            end)
        else
            losersProcessed = losersProcessed + 1
        end
    end
end

function ProcessTeamEloUpdateByMode(winnersData, losersData, finalScore, mode)
    if #winnersData == 0 or #losersData == 0 then return end
    
    local avgWinnerElo, avgLoserElo = 0, 0
    local avgWinnerRank, avgLoserRank = 0, 0
    
    for i = 1, #winnersData do
        avgWinnerElo = avgWinnerElo + winnersData[i].elo
        avgWinnerRank = avgWinnerRank + winnersData[i].rankId
    end
    avgWinnerElo = math.floor(avgWinnerElo / #winnersData)
    avgWinnerRank = math.floor(avgWinnerRank / #winnersData)
    
    for i = 1, #losersData do
        avgLoserElo = avgLoserElo + losersData[i].elo
        avgLoserRank = avgLoserRank + losersData[i].rankId
    end
    avgLoserElo = math.floor(avgLoserElo / #losersData)
    avgLoserRank = math.floor(avgLoserRank / #losersData)
    
    local winnerScore = math.max(finalScore.team1, finalScore.team2)
    local loserScore = math.min(finalScore.team1, finalScore.team2)
    local scoreRatio = loserScore / winnerScore
    
    local teamStreak = winnersData[1].winStreak - 1
    
    -- ✅ CALCUL AVEC DIFFICULTÉ PROGRESSIVE (basé sur moyenne équipe)
    local baseEloResult = CalculateEloChange(avgWinnerElo, avgLoserElo, avgWinnerRank, avgLoserRank, scoreRatio, mode, teamStreak)
    
    -- ✅ BATCH UPDATE gagnants (en parallèle + BRUTAL NOTIFY)
    for i = 1, #winnersData do
        local data = winnersData[i]  -- Capturer AVANT CreateThread pour éviter le problème de closure
        CreateThread(function()
            -- ✅ Calculer le gain individuel basé sur le rang du joueur
            local playerRank = GetRankByElo(data.elo)
            local playerDifficulty = GetRankDifficulty(playerRank.id)
            
            -- Ajuster le gain selon la difficulté individuelle
            local individualGain = math.floor(baseEloResult.winnerChange * playerDifficulty.gainMultiplier / GetRankDifficulty(avgWinnerRank).gainMultiplier)
            individualGain = math.max(individualGain, playerDifficulty.minGain)
            
            local newElo = data.elo + individualGain
            local newRank = GetRankByElo(newElo)
            local newBestElo = math.max(data.bestElo, newElo)
            local newBestStreak = math.max(data.bestWinStreak, data.winStreak)
            
            MySQL.update([[
                UPDATE pvp_stats_modes 
                SET elo = ?, rank_id = ?, best_elo = ?, wins = wins + 1, 
                    matches_played = matches_played + 1, win_streak = ?, best_win_streak = ?
                WHERE identifier = ? AND mode = ?
            ]], {newElo, newRank.id, newBestElo, data.winStreak, newBestStreak, data.identifier, mode}, function()
                InvalidatePlayerCache(data.identifier, mode)
                InvalidatePlayerCache(data.identifier, 'all')
            end)
            
            -- ✅ BRUTAL NOTIFY
            local rankEmoji = newRank.emoji or ""
            TriggerClientEvent('brutal_notify:SendAlert', data.playerId, 
                rankEmoji .. ' ELO ' .. mode,
                string.format('+%d ELO (%d) | %s | 🔥 Streak: %d', 
                    individualGain, newElo, newRank.name, data.winStreak),
                5000, 'success')
            
            -- ✅ Promotion
            if newRank.id > data.rankId then
                TriggerClientEvent('brutal_notify:SendAlert', data.playerId, 
                    newRank.emoji .. ' PROMOTION ' .. mode,
                    string.format('Félicitations! Vous êtes maintenant %s!', newRank.name),
                    6000, 'success')
                
                if newRank.id >= 7 then
                    TriggerClientEvent('brutal_notify:SendAlert', data.playerId, 
                        '⚠️ ATTENTION',
                        'La progression devient plus difficile à ce rang!',
                        4000, 'warning')
                end
            end
            
            UpdateGlobalStats(data.identifier, newElo, newRank.id, true)
        end)
    end
    
    -- ✅ BATCH UPDATE perdants (en parallèle + BRUTAL NOTIFY)
    for i = 1, #losersData do
        local data = losersData[i]  -- Capturer AVANT CreateThread pour éviter le problème de closure
        CreateThread(function()
            -- ✅ Calculer la perte individuelle basée sur le rang du joueur
            local playerRank = GetRankByElo(data.elo)
            local playerDifficulty = GetRankDifficulty(playerRank.id)
            
            -- Ajuster la perte selon la difficulté individuelle
            local individualLoss = math.floor(math.abs(baseEloResult.loserChange) * playerDifficulty.lossMultiplier / GetRankDifficulty(avgLoserRank).lossMultiplier)
            individualLoss = math.min(individualLoss, playerDifficulty.maxLoss)
            
            local newElo = math.max(ELO_CONFIG.minimumElo, data.elo - individualLoss)
            local newRank = GetRankByElo(newElo)
            local newBestElo = math.max(data.bestElo, newElo)
            
            MySQL.update([[
                UPDATE pvp_stats_modes 
                SET elo = ?, rank_id = ?, best_elo = ?, losses = losses + 1, 
                    matches_played = matches_played + 1, win_streak = 0
                WHERE identifier = ? AND mode = ?
            ]], {newElo, newRank.id, newBestElo, data.identifier, mode}, function()
                InvalidatePlayerCache(data.identifier, mode)
                InvalidatePlayerCache(data.identifier, 'all')
            end)
            
            -- ✅ BRUTAL NOTIFY
            local rankEmoji = newRank.emoji or ""
            TriggerClientEvent('brutal_notify:SendAlert', data.playerId, 
                rankEmoji .. ' ELO ' .. mode,
                string.format('-%d ELO (%d) | %s', individualLoss, newElo, newRank.name),
                5000, 'error')
            
            -- ✅ Rétrogradation
            if newRank.id < data.rankId then
                TriggerClientEvent('brutal_notify:SendAlert', data.playerId, 
                    newRank.emoji .. ' RÉTROGRADATION ' .. mode,
                    string.format('Vous êtes redescendu %s', newRank.name),
                    6000, 'warning')
            end
            
            UpdateGlobalStats(data.identifier, newElo, newRank.id, false)
        end)
    end
end

-- ========================================
-- ✅ STATS GLOBALES (OPTIMISÉE - PAS DE SELECT)
-- ========================================
function UpdateGlobalStats(identifier, newElo, newRankId, isWin)
    -- ✅ UNE SEULE requête SQL - UPDATE direct sans SELECT
    if isWin then
        MySQL.update([[
            UPDATE pvp_stats 
            SET wins = wins + 1, 
                matches_played = matches_played + 1, 
                best_elo = GREATEST(best_elo, ?)
            WHERE identifier = ?
        ]], {newElo, identifier})
    else
        MySQL.update([[
            UPDATE pvp_stats 
            SET losses = losses + 1, 
                matches_played = matches_played + 1
            WHERE identifier = ?
        ]], {identifier})
    end
end

-- ========================================
-- ✅ KILLS/DEATHS (OPTIMISÉ - UPDATE DIRECT)
-- ========================================
function UpdatePlayerKillsByMode(playerId, amount, mode)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    -- ✅ BATCH UPDATE (2 requêtes en parallèle)
    CreateThread(function()
        MySQL.update('UPDATE pvp_stats_modes SET kills = kills + ? WHERE identifier = ? AND mode = ?', 
            {amount, xPlayer.identifier, mode}, function()
                InvalidatePlayerCache(xPlayer.identifier, mode)
            end)
    end)
    
    CreateThread(function()
        MySQL.update('UPDATE pvp_stats SET kills = kills + ? WHERE identifier = ?', 
            {amount, xPlayer.identifier})
    end)
end

function UpdatePlayerDeathsByMode(playerId, amount, mode)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    -- ✅ BATCH UPDATE (2 requêtes en parallèle)
    CreateThread(function()
        MySQL.update('UPDATE pvp_stats_modes SET deaths = deaths + ? WHERE identifier = ? AND mode = ?', 
            {amount, xPlayer.identifier, mode}, function()
                InvalidatePlayerCache(xPlayer.identifier, mode)
            end)
    end)
    
    CreateThread(function()
        MySQL.update('UPDATE pvp_stats SET deaths = deaths + ? WHERE identifier = ?', 
            {amount, xPlayer.identifier})
    end)
end

-- ========================================
-- ✅ LEADERBOARD (AVEC CACHE) - LIMIT 20
-- ========================================
function GetLeaderboardByMode(mode, limit, callback)
    limit = limit or 20
    local cacheKey = mode .. '_' .. limit
    local now = GetGameTimer()
    
    -- ✅ Vérifier cache
    local cached = leaderboardCache[cacheKey]
    if cached and (now - cached.timestamp) < PERF.leaderboardCacheDuration then
        DebugElo('📦 Leaderboard cache HIT: %s', cacheKey)
        callback(cached.data)
        return
    end
    
    -- ✅ Cache MISS - Requête SQL
    DebugElo('🔍 Leaderboard cache MISS: %s - SQL query', cacheKey)
    
    MySQL.query([[
        SELECT sm.*, s.name, s.discord_avatar
        FROM pvp_stats_modes sm
        LEFT JOIN pvp_stats s ON sm.identifier = s.identifier
        WHERE sm.mode = ?
        ORDER BY sm.elo DESC
        LIMIT ?
    ]], {mode, limit}, function(results)
        if results then
            for i = 1, #results do
                local player = results[i]
                player.kills = player.kills or 0
                player.deaths = player.deaths or 0
                player.name = player.name or ('Joueur ' .. i)
                player.avatar = player.discord_avatar or Config.Discord.defaultAvatar
                player.rank = GetRankByElo(player.elo)
            end
        end
        
        -- ✅ Mettre en cache
        leaderboardCache[cacheKey] = {
            data = results or {},
            timestamp = GetGameTimer()
        }
        
        callback(results or {})
    end)
end

-- ========================================
-- ✅ FONCTION: OBTENIR INFOS RANG (pour UI/Discord)
-- ========================================
function GetRankInfo(elo)
    local rank = GetRankByElo(elo)
    local difficulty = GetRankDifficulty(rank.id)
    
    -- Calculer progression vers prochain rang
    local nextRank = nil
    local progressPercent = 100
    
    for i = 1, #ELO_CONFIG.rankThresholds do
        if ELO_CONFIG.rankThresholds[i].id == rank.id + 1 then
            nextRank = ELO_CONFIG.rankThresholds[i]
            break
        end
    end
    
    if nextRank then
        local eloInRank = elo - rank.min
        local eloNeeded = nextRank.min - rank.min
        progressPercent = math.floor((eloInRank / eloNeeded) * 100)
    end
    
    return {
        rank = rank,
        difficulty = difficulty,
        nextRank = nextRank,
        progressPercent = progressPercent,
        eloToNextRank = nextRank and (nextRank.min - elo) or 0
    }
end

-- ========================================
-- COMPATIBILITÉ
-- ========================================
function UpdatePlayerElo1v1(winnerId, loserId, finalScore)
    UpdatePlayerElo1v1ByMode(winnerId, loserId, finalScore, '1v1')
end

function UpdateTeamElo(winners, losers, finalScore)
    UpdateTeamEloByMode(winners, losers, finalScore, '2v2')
end

-- ========================================
-- ✅ COMMANDE DEBUG: AFFICHER INFOS RANG
-- ========================================
RegisterCommand('pvprankinfo', function(source, args)
    if source == 0 then
        print('[PVP] Cette commande doit être utilisée en jeu')
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local mode = args[1] or '1v1'
    
    GetPlayerStatsByMode(xPlayer.identifier, mode, function(stats)
        local rankInfo = GetRankInfo(stats.elo)
        
        TriggerClientEvent('brutal_notify:SendAlert', source, 
            rankInfo.rank.emoji .. ' ' .. rankInfo.rank.name,
            string.format('ELO: %d | Streak: %d', stats.elo, stats.win_streak),
            4000, 'info')
        
        if rankInfo.nextRank then
            TriggerClientEvent('brutal_notify:SendAlert', source, 
                '📈 Progression',
                string.format('%d%% vers %s (%d ELO restants)', 
                    rankInfo.progressPercent, rankInfo.nextRank.name, rankInfo.eloToNextRank),
                4000, 'info')
        end
        
        TriggerClientEvent('brutal_notify:SendAlert', source, 
            '⚙️ Difficulté',
            string.format('Gains: x%.2f | Pertes: x%.2f | Streak: x%.2f', 
                rankInfo.difficulty.gainMultiplier, 
                rankInfo.difficulty.lossMultiplier,
                rankInfo.difficulty.streakMultiplier),
            5000, 'warning')
    end)
end, false)

-- ========================================
-- ✅ COMMANDE DEBUG: SIMULER CALCUL ELO
-- ========================================
RegisterCommand('pvpsimelo', function(source, args)
    if source ~= 0 and not exports['pvp_gunfight']:IsPlayerAdmin(source) then
        return
    end
    
    local winnerElo = tonumber(args[1]) or 3000
    local loserElo = tonumber(args[2]) or 3000
    local winnerStreak = tonumber(args[3]) or 0
    
    local winnerRank = GetRankByElo(winnerElo)
    local loserRank = GetRankByElo(loserElo)
    
    local result = CalculateEloChange(winnerElo, loserElo, winnerRank.id, loserRank.id, 0.5, '1v1', winnerStreak)
    
    local output = string.format(
        '\n=== SIMULATION ELO ===\n' ..
        'Gagnant: %s (%d ELO) → +%d = %d ELO (%s)\n' ..
        'Perdant: %s (%d ELO) → %d = %d ELO (%s)\n' ..
        'Streak gagnant: %d\n' ..
        '=====================',
        winnerRank.name, winnerElo, result.winnerChange, result.winnerNewElo, result.winnerNewRank.name,
        loserRank.name, loserElo, result.loserChange, result.loserNewElo, result.loserNewRank.name,
        winnerStreak
    )
    
    if source == 0 then
        print(output)
    else
        -- Envoyer en plusieurs notifications
        TriggerClientEvent('brutal_notify:SendAlert', source, 
            '🎮 Simulation ELO',
            string.format('Gagnant: %s %d → %d (+%d)', winnerRank.emoji, winnerElo, result.winnerNewElo, result.winnerChange),
            6000, 'success')
        TriggerClientEvent('brutal_notify:SendAlert', source, 
            '🎮 Simulation ELO',
            string.format('Perdant: %s %d → %d (%d)', loserRank.emoji, loserElo, result.loserNewElo, result.loserChange),
            6000, 'error')
    end
end, false)

-- ========================================
-- EXPORTS
-- ========================================
exports('UpdatePlayerElo1v1', UpdatePlayerElo1v1)
exports('UpdatePlayerElo1v1ByMode', UpdatePlayerElo1v1ByMode)
exports('UpdateTeamElo', UpdateTeamElo)
exports('UpdateTeamEloByMode', UpdateTeamEloByMode)
exports('GetRankByElo', GetRankByElo)
exports('GetRankInfo', GetRankInfo)
exports('CalculateEloChange', CalculateEloChange)
exports('GetPlayerStatsByMode', GetPlayerStatsByMode)
exports('GetPlayerAllModeStats', GetPlayerAllModeStats)
exports('GetLeaderboardByMode', GetLeaderboardByMode)
exports('InitPlayerModeStats', InitPlayerModeStats)
exports('UpdatePlayerKillsByMode', UpdatePlayerKillsByMode)
exports('UpdatePlayerDeathsByMode', UpdatePlayerDeathsByMode)

-- ========================================
-- LOG FINAL
-- ========================================
DebugSuccess('Système ELO initialisé (VERSION 7.0.0 - RANGS MASTER)')
DebugSuccess('✅ Cache: 5min | Batch updates | Pas de SELECT avant UPDATE')
DebugSuccess('✅ Rangs: Bronze → Argent → Or → Platine → Émeraude → Diamant → Master 3 → Master 2 → Master 1')
DebugSuccess('✅ Difficulté progressive activée à partir de Diamant')
DebugSuccess('📊 Exemple Diamant: Gains x0.75, Pertes x1.3, Streak x0.7')
DebugSuccess('📊 Exemple Master 1: Gains x0.40, Pertes x2.0, Streak x0.2')
DebugSuccess('✅ Notifications: brutal_notify intégrées')