fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qb-fbi'
author 'Codex'
description 'qb-smartdispatch tactical command system for QBCore + qb-target'
version '3.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

dependency 'qb-core'
dependency 'qb-target'
