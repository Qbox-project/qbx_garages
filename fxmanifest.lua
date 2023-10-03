fx_version 'cerulean'
game 'gta5'

version '1.0.0'
repository 'https://github.com/Qbox-project/qbx_garages'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/import.lua',
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

modules {
    'qbx_core:playerdata',
    'qbx_core:utils',
}

dependency 'ox_lib'

provide 'qb-garages'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
