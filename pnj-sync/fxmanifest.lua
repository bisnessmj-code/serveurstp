--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║                    PNJ SYNC - FiveM                              ║
    ║              Module de Synchronisation Réseau                    ║
    ║                     Version: 1.0.0                               ║
    ╚══════════════════════════════════════════════════════════════════╝

    Module de synchronisation réseau pour entités et sessions.
]]

fx_version 'cerulean'
game 'gta5'

name 'pnj-sync'
author 'DevTeam'
description 'Module de synchronisation réseau pour entités'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    'server/database.lua',
    'server/utils.lua',
    'server/security.lua',
    'server/main.lua',
    'server/commands.lua',
}

lua54 'yes'
