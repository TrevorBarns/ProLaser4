cfg = {}
-- DO NOT TOUCH cfg = {}

--[[CONTROLS]]
cfg.toggleMenu = 'I'
--	Open / Close UI (default: I)
cfg.trigger = 24 		
--	Check Vehicle Speed / Pull Trigger (default: RTrigger / LMouse)
cfg.changeSight = 26
--	Changes ADS style between sniper scope and modeled ProLaser 4 sight (default: C)
cfg.nextHistory = 175
--	Scorols next in history menu, opens if not open.
cfg.previousHistory = 174
--	Scrolls previous in history menu, closes if on first history item.

cfg.requireCalibration = true
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
cfg.zoomSpeed = 3.0
--	Rate at which to zoom in and out (default: 3.0)
cfg.horizontalPanSpeed = 10.0
--	Speed at which to pan camera left-right (default: 10.0)
cfg.verticalPanSpeed = 10.0
--	Speed at which to pan camera up-down (default: 10.0)
cfg.displayControls = true