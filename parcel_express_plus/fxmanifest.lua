fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'parcel_express by Codex'
description 'وظيفة توصيل طرود احترافية متوافقة مع QBCore + oxmysql + qb-target'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/vehicle.lua',
    'client/animation.lua',
    'client/delivery.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/payments.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-inventory',
    'oxmysql'
}
