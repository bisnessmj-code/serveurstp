-- =====================================================
-- REDZONE LEAGUE - Fake Data pour Tests
-- =====================================================
-- Données fictives pour tester le système de leaderboard
-- Exécuter APRES avoir créé la table redzone_leaderboard.sql
-- =====================================================

-- Vider la table avant d'insérer (optionnel, décommenter si besoin)
-- TRUNCATE TABLE redzone_leaderboard;

INSERT INTO redzone_leaderboard (identifier, name, kills, deaths, last_kill) VALUES
-- Top 3 (les meilleurs)
('license:a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0', 'xXDarkShadowXx', 156, 42, NOW() - INTERVAL 5 MINUTE),
('license:b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0a1', 'KingSlayer_FR', 142, 38, NOW() - INTERVAL 15 MINUTE),
('license:c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0a1b2', 'HeadshotMaster', 128, 51, NOW() - INTERVAL 1 HOUR),

-- Joueurs confirmés (4-10)
('license:d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0a1b2c3', 'NightHunter77', 98, 45, NOW() - INTERVAL 2 HOUR),
('license:e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0a1b2c3d4', 'SnipeGod_', 89, 32, NOW() - INTERVAL 30 MINUTE),
('license:f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0a1b2c3d4e5', 'PvPLegend', 85, 55, NOW() - INTERVAL 3 HOUR),
('license:g7h8i9j0k1l2m3n4o5p6q7r8s9t0a1b2c3d4e5f6', 'ColdBlooded_', 76, 41, NOW() - INTERVAL 1 DAY),
('license:h8i9j0k1l2m3n4o5p6q7r8s9t0a1b2c3d4e5f6g7', 'DeathDealer420', 72, 68, NOW() - INTERVAL 4 HOUR),
('license:i9j0k1l2m3n4o5p6q7r8s9t0a1b2c3d4e5f6g7h8', 'SilentKiller_X', 65, 29, NOW() - INTERVAL 45 MINUTE),
('license:j0k1l2m3n4o5p6q7r8s9t0a1b2c3d4e5f6g7h8i9', 'BulletStorm', 61, 52, NOW() - INTERVAL 6 HOUR),

-- Joueurs moyens (11-20)
('license:k1l2m3n4o5p6q7r8s9t0a1b2c3d4e5f6g7h8i9j0', 'RedzoneKing', 54, 48, NOW() - INTERVAL 2 DAY),
('license:l2m3n4o5p6q7r8s9t0a1b2c3d4e5f6g7h8i9j0k1', 'FragMachine', 48, 35, NOW() - INTERVAL 12 HOUR),
('license:m3n4o5p6q7r8s9t0a1b2c3d4e5f6g7h8i9j0k1l2', 'GunRunner_FR', 45, 42, NOW() - INTERVAL 1 DAY),
('license:n4o5p6q7r8s9t0a1b2c3d4e5f6g7h8i9j0k1l2m3', 'TriggerHappy', 42, 56, NOW() - INTERVAL 8 HOUR),
('license:o5p6q7r8s9t0a1b2c3d4e5f6g7h8i9j0k1l2m3n4', 'AimBot_Legal', 38, 31, NOW() - INTERVAL 3 DAY),
('license:p6q7r8s9t0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5', 'WarMachine_', 35, 40, NOW() - INTERVAL 5 HOUR),
('license:q7r8s9t0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', 'PainBringer', 32, 28, NOW() - INTERVAL 10 HOUR),
('license:r8s9t0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7', 'BloodThirsty', 29, 33, NOW() - INTERVAL 2 DAY),
('license:s9t0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8', 'RageQuit_Pro', 25, 45, NOW() - INTERVAL 4 DAY),
('license:t0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9', 'NoScope360', 22, 18, NOW() - INTERVAL 1 DAY),

-- Débutants (21-30)
('license:u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0', 'NewPlayer_01', 15, 25, NOW() - INTERVAL 6 DAY),
('license:v2w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1', 'FirstTimer', 12, 30, NOW() - INTERVAL 3 DAY),
('license:w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2', 'LearningPvP', 10, 22, NOW() - INTERVAL 5 DAY),
('license:x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3', 'CasualGamer', 8, 15, NOW() - INTERVAL 7 DAY),
('license:y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4', 'JustForFun', 6, 12, NOW() - INTERVAL 4 DAY),
('license:z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5', 'TryHard_Noob', 5, 20, NOW() - INTERVAL 2 DAY),
('license:a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6', 'GettingBetter', 4, 8, NOW() - INTERVAL 1 DAY),
('license:b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7', 'PeacefulPlayer', 3, 10, NOW() - INTERVAL 8 DAY),
('license:c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8', 'LuckyShot', 2, 5, NOW() - INTERVAL 10 DAY),
('license:d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9', 'OneKillWonder', 1, 15, NOW() - INTERVAL 14 DAY)

ON DUPLICATE KEY UPDATE
    kills = VALUES(kills),
    deaths = VALUES(deaths),
    name = VALUES(name),
    last_kill = VALUES(last_kill);

-- Vérification: Afficher le top 10
SELECT
    ROW_NUMBER() OVER (ORDER BY kills DESC) as `Rang`,
    name as `Joueur`,
    kills as `Kills`,
    deaths as `Deaths`,
    CASE
        WHEN deaths > 0 THEN ROUND(kills / deaths, 2)
        ELSE kills
    END as `K/D Ratio`,
    last_kill as `Dernier Kill`
FROM redzone_leaderboard
ORDER BY kills DESC
LIMIT 10;
