-- =====================================================
-- REDZONE LEAGUE - Table Leaderboard (Classement Kills)
-- =====================================================
-- Cette table stocke les statistiques de kills des joueurs
-- pour afficher un classement des meilleurs tueurs.
-- =====================================================

CREATE TABLE IF NOT EXISTS `redzone_leaderboard` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(100) NOT NULL,
    `name` VARCHAR(50) DEFAULT 'Inconnu',
    `kills` INT(11) NOT NULL DEFAULT 0,
    `deaths` INT(11) NOT NULL DEFAULT 0,
    `last_kill` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`),
    KEY `idx_kills` (`kills` DESC),
    KEY `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Index pour optimiser les requêtes de classement
-- Le classement top 3 sera très rapide grâce à idx_kills
