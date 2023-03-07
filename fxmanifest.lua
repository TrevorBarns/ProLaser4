------------------------------
fx_version 'cerulean'
games { 'gta5' }
lua54 'on'

author 'Trevor Barns'
description 'Lidar Resource.'

version '1.0.0'			-- Readonly version of currently installed version.
------------------------------
ui_page('UI/html/index.html')

dependencies {
    -- 'oxmysql',		-- uncomment for persistent records & record management tablet. See docs and configs.
}

files {
	'speedlimits.json',
	'UI/html/index.html',
	'UI/html/jquery.js',
	'UI/html/fonts/**.ttf',
	'UI/html/**.png',
	'UI/html/**.jpg',
	'UI/html/lidar.js',
	'UI/html/style.css',
	'UI/html/sounds/*.ogg',
	'UI/weapons_dlc_bb.png',
	'metas/*.meta',
}

data_file 'WEAPONCOMPONENTSINFO_FILE' 'metas/dlc_hipster.meta'
data_file 'WEAPONINFO_FILE_PATCH' 'metas/weaponvintagepistol.meta'

client_scripts {
	'UTIL/cl_*.lua',
}

server_scripts {
    -- '@oxmysql/lib/MySQL.lua', -- uncomment for persistent records & record management tablet. See docs and configs.
	'UTIL/sv_*.lua',
	'UTIL/semver.lua'
}

shared_scripts {
	'config.lua',
}