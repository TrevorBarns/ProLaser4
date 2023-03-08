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


--[[MISC CONFIGURATIONS]]
cfg.performSelfTest = true
--	On lidar first open perform a self-test sequence.
cfg.lidarGunHash = "WEAPON_VINTAGEPISTOL"
--	Lidar gun weapon string
cfg.clockSFX = 0.02
--	Sound effect volume when lidar is clocking (default: 0.02)
cfg.selfTestSFX = 0.02
--	Sound effect volume when lidar finishs self-test (default: 0.02)


--[[ADS Parameters]]
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


--[[RECORD TABLET (SQL REQUIRED)]]
cfg.logging = false
--	Send logged clocks to the server for SQL storage.
cfg.loggingPlayersOnly = false
--	Require vehicle be driven by player to log.
cfg.loggingOnlySpeeders = false
--	Only log clocks above speedlimit as defined in speedlimits.json.
--	How often, in minutes, to insert new records from the server.
cfg.loggingCleanUpInterval = 14
--	Age in days of records to automatically delete. disable: set equal to -1 (default: 14 days)
cfg.loggingSelectLimit = 2000
--	Maxmium number of records users can view in records tablet. Increasing this can increase load on server and database, which may induce lag.
cfg.imgurApiKey = ''
--	Enables "printing" records, uploads screenshot to Imgur and returns link. See docs. https://api.imgur.com/oauth2/addclient
--		Format:'Client-ID XXXXXXXXXXXXXXX' 


--[[DEBUGGING]]
cfg.serverDebugging = true
--	Increases server console printing.
