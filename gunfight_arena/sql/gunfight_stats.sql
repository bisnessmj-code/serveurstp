-- ================================================================================================
-- GUNFIGHT ARENA - TABLE DES STATISTIQUES
-- ================================================================================================

CREATE TABLE IF NOT EXISTS `gunfight_stats` (
    `license` VARCHAR(60) NOT NULL,
    `kills` INT(11) NOT NULL DEFAULT 0,
    `deaths` INT(11) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Index pour optimiser les requêtes de classement
CREATE INDEX IF NOT EXISTS `idx_kills` ON `gunfight_stats` (`kills` DESC);
