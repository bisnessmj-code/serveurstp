
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'kichta'
description 'Gunfight Arena Lite - Mode de jeu pur'
version '1.0.2'

dependencies {
    'es_extended',
    'oxmysql'
}

shared_scripts {
    '@es_extended/imports.lua',
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/zones.lua',
    'client/ui_controller.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/cache.lua',
    'server/zones_manager.lua',
    'server/stats.lua',
    'server/discord.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.webp',
    'html/images/*.png'
}
