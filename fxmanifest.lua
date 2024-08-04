fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'harley029'
description 'Player death screen with ems notification'
version '1.0.0'



shared_scripts {
	'@qb-core/shared/locale.lua',
	'en.lua',
	'config.lua'
}

client_scripts {
	'client/client.lua',
	
	
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
	'server/server.lua',
	
	
}

ui_page 'client/html/index.html'
files {
	'client/html/index.html',
	'client/html/sounds/*.ogg',
}
