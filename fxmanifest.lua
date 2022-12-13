------------------------------
fx_version 'adamant'
games { 'gta5' }
lua54 'on'

author 'Trevor Barns'
description 'Lidar & Lidar Jammer Resource.'
------------------------------
ui_page('html/index.html')

files {
	'html/index.html',
	'html/jquery.js',
	'html/fonts/**.ttf',
	'html/**.png',
	'html/lidar.js',
	'html/style.css',
	'html/sounds/*.ogg',
}

client_scripts{
	'config.lua',
	'UTIL/cl_*.lua',
}

server_scripts{
	'UTIL/sv_*.lua',
}

escrow_ignore {
	'/config.lua',
}
dependency '/assetpacks'