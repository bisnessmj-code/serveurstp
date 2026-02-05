-- ========================================
-- PVP GUNFIGHT - FX MANIFEST
-- Version 5.2.0 - FANCA_ANTITANK INTEGRATION
-- ========================================

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'PVP GunFight'
description 'Système PVP GunFight Ultra-Optimisé 160+ Joueurs - v5.2.0 avec Fanca Antitank'
version '5.2.0'

-- ========================================
-- DÉPENDANCES
-- ========================================
dependencies {
    'es_extended',
    'oxmysql',
    'fanca_antitank'  -- ✅ NOUVEAU: Dépendance fanca_antitank
}

-- ========================================
-- SCRIPTS PARTAGÉS
-- ========================================
shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
    'shared/debug.lua',
    'config_discord_leaderboard.lua'
}

-- ========================================
-- SCRIPTS CLIENT (ORDRE IMPORTANT!)
-- ========================================
client_scripts {
    'client/cache.lua',              -- ✅ PREMIER: système de cache
    'client/inventory_bridge.lua',
    'client/damage_system.lua',
    'client/antitank_bridge.lua',    -- ✅ NOUVEAU: Bridge fanca_antitank (AVANT main.lua)
    'client/spectator.lua',          -- Système spectateur (avant main.lua)
    'client/main.lua',               -- APRÈS antitank_bridge.lua pour avoir accès aux fonctions
    'client/zones.lua',
    'client/teammate_hud.lua',
    'client/command_blocker.lua'
}

-- ========================================
-- SCRIPTS SERVEUR (VERSION 5.2.0)
-- ========================================
server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- ✅ Modules optimisés
    'server/elo.lua',
    'server/groups.lua',
    'server/discord.lua',

    -- ✅ Modules existants
    'server/inventory_bridge.lua',
    'server/webhook_manager.lua',
    'server/permissions.lua',
    'server/command_blocker.lua',

    -- ✅ NOUVEAU: Bridge fanca_antitank serveur (AVANT main.lua)
    'server/antitank_bridge.lua',

    -- ✅ Module principal (CRITIQUE - doit être chargé APRÈS les autres)
    'server/main.lua',

    -- ✅ Discord leaderboards
    'server/discord_leaderboard.lua'
}

-- ========================================
-- INTERFACE NUI
-- ========================================
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/logo.png',
}
