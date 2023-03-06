------------------------------
fx_version 'adamant'
games { 'gta5' }
lua54 'on'

author 'Trevor Barns'
description 'Lidar Resource.'

version '1.0.0'			-- Readonly version of currently installed version.
------------------------------
ui_page('html/index.html')

dependencies {
    'oxmysql',
}

files {
	'speedlimits.json',
	'html/index.html',
	'html/jquery.js',
	'html/fonts/**.ttf',
	'html/**.png',
	'html/**.jpg',
	'html/lidar.js',
	'html/style.css',
	'html/sounds/*.ogg',
	'metas/*.meta',
}

data_file 'WEAPONCOMPONENTSINFO_FILE' 'metas/dlc_hipster.meta'
data_file 'WEAPONINFO_FILE_PATCH' 'metas/weaponvintagepistol.meta'

client_scripts {
	'UTIL/cl_*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
	'UTIL/sv_*.lua',
	'UTIL/semver.lua'
}

shared_scripts {
	'config.lua',
}