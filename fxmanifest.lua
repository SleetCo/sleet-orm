fx_version  'cerulean'
game        'gta5'
name        'sleet'
description 'Elegant ORM for FiveM + oxmysql, inspired by Drizzle'
version     '0.1.1'
url         'https://github.com/SleetCo/sleet-orm'

author 'woozievert & sleet-orm contributors'

dependency 'oxmysql'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'sleet.lua',
}
