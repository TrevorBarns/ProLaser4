------------------------------
fx_version 'adamant'
games { 'gta5' }
lua54 'on'

author 'Trevor Barns'
description 'Lidar Resource.'
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
	'metas/*.meta',
}

data_file 'WEAPONCOMPONENTSINFO_FILE' 'metas/dlc_hipster.meta'
data_file 'WEAPONINFO_FILE_PATCH' 'metas/weaponvintagepistol.meta'

client_scripts{
	'config.lua',
	'UTIL/cl_*.lua',
}
