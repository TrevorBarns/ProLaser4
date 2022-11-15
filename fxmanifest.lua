------------------------------
fx_version 'adamant'
games { 'gta5' }

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
	'html/sounds/LidarCalibration.ogg',
	'html/sounds/LidarPress.ogg',
}

client_scripts{
	'config.lua',
	'UTIL/cl_*.lua',
}
