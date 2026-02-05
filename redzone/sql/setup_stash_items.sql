-- =====================================================
-- REDZONE LEAGUE - Configuration table stash_items
-- =====================================================
-- Ce script crée la table stash_items si elle n'existe pas.
-- Utilisée par qs-inventory pour stocker les coffres personnels.
--
-- FORMAT DES ITEMS (JSON object, pas array):
-- {"1":{"name":"item_name","amount":1,...}, "2":{...}}
-- =====================================================

-- Créer la table si elle n'existe pas
CREATE TABLE IF NOT EXISTS `stash_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `stash` varchar(255) NOT NULL,
  `items` longtext DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `stash` (`stash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Pour voir les stash existants:
-- SELECT stash, LENGTH(items) as size, updated_at FROM stash_items WHERE stash LIKE 'rzstash_%';
--
-- Pour vider un stash (debug):
-- UPDATE stash_items SET items = '{}' WHERE stash = 'rzstash_xxx';
--
-- Pour supprimer un stash (debug):
-- DELETE FROM stash_items WHERE stash = 'rzstash_xxx';
-- =====================================================
