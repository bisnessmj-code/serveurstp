--[[
    ██████╗ ███████╗██████╗ ███████╗ ██████╗ ███╗   ██╗███████╗
    ██╔══██╗██╔════╝██╔══██╗╚══███╔╝██╔═══██╗████╗  ██║██╔════╝
    ██████╔╝█████╗  ██║  ██║  ███╔╝ ██║   ██║██╔██╗ ██║█████╗
    ██╔══██╗██╔══╝  ██║  ██║ ███╔╝  ██║   ██║██║╚██╗██║██╔══╝
    ██║  ██║███████╗██████╔╝███████╗╚██████╔╝██║ ╚████║███████╗
    ╚═╝  ╚═╝╚══════╝╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝

    REDZONE LEAGUE - Mode de jeu PvP
    Version: 1.0.0
    Auteur: DevTeam
]]

fx_version 'cerulean'
game 'gta5'

name 'redzone'
description 'REDZONE LEAGUE - Mode de jeu PvP instancié'
author 'DevTeam'
version '1.0.0'

-- Fichiers partagés (chargés avant client/server)
shared_scripts {
    '@es_extended/imports.lua', -- ESX Framework
    'config/config.lua',        -- Configuration principale
    'shared/shared.lua',        -- Fonctions partagées
}

-- Fichiers client
client_scripts {
    'client/utils.lua',         -- Utilitaires client
    'client/ped.lua',           -- Gestion des PEDs
    'client/menu.lua',          -- Système de menu
    'client/combatzone.lua',    -- Zone de combat dynamique (avant zones.lua)
    'client/cal50zone.lua',     -- Zone CAL50 dynamique (avant zones.lua)
    'client/weedfarm.lua',      -- Système de farm weed (avant zones.lua)
    'client/press.lua',         -- Système de press
    'client/zones.lua',         -- Gestion des zones safe et blips
    'client/stash.lua',         -- Système de coffre (client)
    'client/vehicle.lua',       -- Système de véhicule (PED)
    'client/shop.lua',          -- Système de shop armes (NUI)
    'client/death.lua',         -- Système de mort/réanimation
    'client/loot.lua',          -- Système de loot
    'client/laundering.lua',    -- Système de blanchiment
    'client/squad.lua',         -- Système de squad
    'client/bandage.lua',       -- Système de bandage
    'client/killfeed.lua',      -- Système de kill feed
    'client/exitped.lua',        -- PEDs de sortie du redzone
    'client/teleport.lua',      -- Système de téléportation
    'client/playerinteract.lua', -- Système ALT + Clic joueur
    'client/main.lua',          -- Script principal client
}

-- Fichiers serveur
server_scripts {
    '@oxmysql/lib/MySQL.lua',   -- MySQL pour la base de données
    'server/utils.lua',         -- Utilitaires serveur
    'server/leaderboard.lua',   -- Système de leaderboard/classement kills
    'server/stash.lua',         -- Système de coffre (serveur)
    'server/shop.lua',          -- Système de shop armes (serveur)
    'server/death.lua',         -- Système de mort/réanimation (serveur)
    'server/loot.lua',          -- Système de loot (serveur)
    'server/laundering.lua',    -- Système de blanchiment (serveur)
    'server/squad.lua',         -- Système de squad (serveur)
    'server/press.lua',         -- Système de press (serveur)
    'server/bandage.lua',       -- Système de bandage (serveur)
    'server/weedfarm.lua',      -- Système de farm weed (serveur)
    'server/main.lua',          -- Script principal serveur
}

-- Interface NUI (HTML/CSS/JS)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/assets/logo.png',
    -- Items
    'html/assets/bandage.png',
    'html/assets/medikit.png',
    'html/assets/vest.png',
    -- Ammo
    'html/assets/pistol_ammo.png',
    'html/assets/smg_ammo.png',
    'html/assets/rifle_ammo.png',
    'html/assets/shotgun_ammo.png',
    'html/assets/mg_ammo.png',
    -- Pistols
    'html/assets/weapon_pistol.png',
    'html/assets/weapon_pistol_mk2.png',
    'html/assets/weapon_pistol50.png',
    'html/assets/weapon_combatpistol.png',
    'html/assets/weapon_heavypistol.png',
    'html/assets/weapon_vintagepistol.png',
    'html/assets/weapon_appistol.png',
    'html/assets/weapon_ceramicpistol.png',
    'html/assets/weapon_revolver.png',
    'html/assets/weapon_revolver_mk2.png',
    'html/assets/weapon_navyrevolver.png',
    'html/assets/weapon_doubleaction.png',
    'html/assets/weapon_marksmanpistol.png',
    'html/assets/weapon_pistolxm3.png',
    'html/assets/weapon_tecpistol.PNG',
    -- SMGs
    'html/assets/weapon_microsmg.png',
    'html/assets/weapon_smg.png',
    'html/assets/weapon_assaultsmg.png',
    'html/assets/weapon_combatpdw.png',
    'html/assets/weapon_machinepistol.png',
    'html/assets/weapon_gusenberg.png',
    -- Rifles
    'html/assets/weapon_carbinerifle.png',
    'html/assets/weapon_carbinerifle_mk2.png',
    'html/assets/weapon_assaultrifle.png',
    'html/assets/weapon_assaultrifle_mk2.png',
    'html/assets/weapon_advancedrifle.png',
    'html/assets/weapon_specialcarbine.png',
    'html/assets/weapon_specialcarbine_mk2.png',
    'html/assets/weapon_bullpuprifle.png',
    'html/assets/weapon_bullpuprifle_mk2.png',
    'html/assets/weapon_compactrifle.png',
    'html/assets/weapon_militaryrifle.png',
    'html/assets/weapon_heavyrifle.png',
    -- Shotguns
    'html/assets/weapon_pumpshotgun.png',
    'html/assets/weapon_pumpshotgun_mk2.png',
    'html/assets/weapon_sawnoffshotgun.png',
    'html/assets/weapon_assaultshotgun.png',
    'html/assets/weapon_bullpupshotgun.png',
    'html/assets/weapon_heavyshotgun.png',
    'html/assets/weapon_dbshotgun.png',
    'html/assets/weapon_autoshotgun.png',
    'html/assets/weapon_combatshotgun.png',
    -- MGs
    'html/assets/weapon_mg.png',
    'html/assets/weapon_combatmg.png',
    'html/assets/weapon_combatmg_mk2.png',
}

-- Dépendances
dependencies {
    'es_extended',
    'oxmysql',
    'qs-inventory',
    'brutal_notify',
}

-- Exports Lua
lua54 'yes'
