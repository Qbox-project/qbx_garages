fx_version 'cerulean'
game 'gta5'

version '1.0.0'
repository 'https://github.com/Qbox-project/qb-garages'

shared_scripts {
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    '@ox_lib/init.lua'
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependency 'ox_lib'

lua54 'yes'
