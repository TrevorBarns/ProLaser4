cfg = {}

--[[CONTROLS]]
cfg.toggleMenu = 246
--	Open / Close UI (default: Y)
cfg.trigger = 24 		
--	Check Vehicle Speed / Pull Trigger (default: RTrigger / LMouse)
cfg.changeSight = 26
--	Changes ADS style between sniper scope and modeled ProLaser 4 sight (default: C)

cfg.requireCalibration = false
--	Require players to calibrate or override calibration message.
cfg.lidarGunHash = "WEAPON_VINTAGEPISTOL"
--	Lidar gun weapon string
cfg.clockSFX = 0.02
--	Sound effect volume when lidar is clocking (default: 0.02)
cfg.calibrationSFX = 0.02
--	Sound effect volume when lidar finishs calibration (default: 0.02)
cfg.accurateAngle = true
--	Require target vehicle and lidar gun heading to be within max angle. IRL: Greater the angle the less accurate.
cfg.maxAngle = 20.0
--	Maximum angle difference between lidar gun and vehicle. 

--	[[ADS Parameters]]
cfg.maxFOV = 15.0
--	Max FOV when aiming down sight, lower is more zoomed in (default: 15.0)
cfg.minFOV = 50.0
--	Min FOV when aiming down sight, lower is more zoomed in (default: 50.0)
cfg.zoomSpeed = 2.0
--	Rate at which to zoom in and out (default: 3.0)
cfg.horizontalPanSpeed = 10.0
--	Speed at which to pan camera left-right (default: 10.0)
cfg.verticalPanSpeed = 10.0
--	Speed at which to pan camera up-down (default: 10.0)
cfg.displayControls = true
--	Display ADS controls: right-click toggle; C change scope style

--	[[JAMMER Paremeters]]
cfg.enableCommand = 'laserjammer'
--	Command to toggle lidar jammer
cfg.cooldownTime = 4
--	Time is seconds after jamming before re-enabling jamming
cfg.jammingSFX = 0.2
--	Volume to play lidar detection alert
