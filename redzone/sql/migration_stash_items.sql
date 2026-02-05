-- =====================================================
-- MIGRATION: redzone_stash vers stash_items
-- =====================================================
-- Ce script migre les données de l'ancienne table redzone_stash
-- vers la table stash_items utilisée par qs-inventory
-- =====================================================

-- Créer la table stash_items si elle n'existe pas
CREATE TABLE IF NOT EXISTS `stash_items` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `stash` VARCHAR(255) NOT NULL,
    `items` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `stash` (`stash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Migrer les données si l'ancienne table existe
INSERT INTO `stash_items` (`stash`, `items`)
SELECT
    CONCAT('rzstash_', REPLACE(REPLACE(`identifier`, 'char', 'char'), ':', '')) as stash,
    `items`
FROM `redzone_stash`
WHERE NOT EXISTS (
    SELECT 1 FROM `stash_items`
    WHERE `stash` = CONCAT('rzstash_', REPLACE(REPLACE(`identifier`, 'char', 'char'), ':', ''))
)
AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'redzone_stash');

-- Optionnel: Supprimer l'ancienne table après vérification
-- Décommentez cette ligne SEULEMENT après avoir vérifié que la migration a fonctionné
-- DROP TABLE IF EXISTS `redzone_stash`;

-- =====================================================
-- VÉRIFICATION
-- =====================================================
-- Après avoir exécuté ce script, vérifiez que vos données ont été migrées:
-- SELECT * FROM stash_items WHERE stash LIKE 'rzstash_%';
