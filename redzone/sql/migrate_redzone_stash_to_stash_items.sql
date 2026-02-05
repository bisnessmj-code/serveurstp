-- =====================================================
-- MIGRATION: redzone_stash vers stash_items
-- =====================================================
-- Ce script migre les données de l'ancienne table redzone_stash
-- vers la table stash_items utilisée par qs-inventory.
--
-- IMPORTANT: Exécuter ce script UNE SEULE FOIS
-- =====================================================

-- Étape 1: Migrer les données de redzone_stash vers stash_items
INSERT INTO `stash_items` (`stash`, `items`, `created_at`)
SELECT
    CONCAT('rzstash_', REPLACE(REPLACE(`identifier`, 'char0:', ''), ':', '')) as stash,
    `items`,
    `created_at`
FROM `redzone_stash`
ON DUPLICATE KEY UPDATE
    `items` = VALUES(`items`);

-- Afficher les résultats de la migration
SELECT
    'Migration terminée!' as message,
    COUNT(*) as total_migrated
FROM `stash_items`
WHERE `stash` LIKE 'rzstash_%';

-- Étape 2 (OPTIONNEL): Renommer l'ancienne table pour backup
-- Décommentez la ligne suivante si vous voulez garder un backup
-- RENAME TABLE `redzone_stash` TO `redzone_stash_backup_old`;

-- Étape 3 (OPTIONNEL): Supprimer l'ancienne table
-- Décommentez la ligne suivante UNIQUEMENT après avoir vérifié que tout fonctionne
-- DROP TABLE IF EXISTS `redzone_stash`;
