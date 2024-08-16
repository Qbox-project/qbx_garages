fx_version 'cerulean'
game 'gta5'
version '1.1.1'

name 'qbx_garages'
description 'Garage system for Qbox'
repository 'https://github.com/Qbox-project/qbx_garages'
version '1.1.1'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/*',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/spawn-vehicle.lua',
}

files {
    'config/client.lua',
    'locales/*.json',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'