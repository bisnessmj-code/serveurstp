fx_version 'cerulean'

game 'gta5'

lua54 'yes'

version '3.6.13'

name 'qs-inventory'
author 'Quasar Store'

data_file 'WEAPONINFO_FILE_PATCH' 'weaponsnspistol.meta'

-- 'http://127.0.0.1:5500/html/ui.html'
ui_page 'html/ui.html'

ox_libs {
    'table',
}

files {
    'config/*.js',
    'html/ui.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/js/modules/*.js',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/cloth/*.png',
    'html/icons/**',
    'html/font/**',
    'html/*.ttf',
    'weaponsnspistol.meta',
    'html/sounds/*.wav',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua',
    'config/*.lua',
    'locales/*.lua',
}

client_script {
    'client/custom/framework/*.lua',
    'client/*.lua',
    'client/modules/*.lua',
    'client/custom/misc/*.lua',
    'client/custom/clothing/*.lua',
    'client/custom/target/*.lua',
    'client/custom/provider/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/custom/framework/*.lua',
    'server/custom/webhook/*.lua',
    'server/custom/misc/StashPersistence.lua', -- PATCH: Fonctions de persistance des stash
    'server/*.lua',
    'server/modules/*.lua',
    'server/custom/**/**.lua',
}

escrow_ignore {
    'shared/items.lua',
    'shared/weapons.lua',
    'config/*.lua',
    'locales/*.lua',
    'client/custom/framework/*.lua',
    'client/custom/misc/*.lua',
    'client/custom/target/*.lua',
    'client/custom/provider/*.lua',
    'client/modules/suggestion.lua',
    'server/custom/framework/*.lua',
    'server/custom/webhook/*.lua',
    'server/custom/misc/*.lua',
    'client/modules/weapons.lua',
    'server/modules/weapons.lua'
}

dependencies {
    '/server:4752', -- ⚠️PLEASE READ⚠️ This requires at least server build 4700 or higher
    'ox_lib',       -- Required
}

provide {
    -- 'ox_inventory' -- Uncomment this line only if you have qbx but better way is the remove 'ox_inventory' dependency on every scripts.
}

dependency '/assetpacks'

dependency '/assetpacks'