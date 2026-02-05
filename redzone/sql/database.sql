--[[
    =====================================================
    REDZONE LEAGUE - Script SQL
    =====================================================
    Exécutez ce script dans votre base de données
    pour créer les tables nécessaires.
]]

-- =====================================================
-- TABLE: redzone_stash
-- Stockage des coffres personnels des joueurs
-- =====================================================

CREATE TABLE IF NOT EXISTS `redzone_stash` (
    `identifier` VARCHAR(60) NOT NULL COMMENT 'License du joueur',
    `items` LONGTEXT DEFAULT '[]' COMMENT 'Items stockés en JSON',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- INDEX pour optimiser les recherches
-- =====================================================

-- Pas d'index supplémentaire nécessaire car la PRIMARY KEY est déjà indexée
