HUD = {}
local cfg = cfg
local targetPlayer = nil
--------------------FUNCTIONS--------------------
-- Toggle display
function HUD:SetLidarDisplayState(state)
	SendNUIMessage({ action = "SetLidarDisplayState", state = state })
end

-- Set ADS mode
function HUD:SetDisplayMode(mode)
	SendNUIMessage({ action = "SetDisplayMode", mode = mode })
end

-- Move & Resize
function HUD:ResizeOnScreenDisplay(reset)
	reset = reset or false
	if reset then
		SendNUIMessage({ action = "SendResizeAndMove", reset = reset })
	else
		SendNUIMessage({ action = "SendResizeAndMove" })
		SetNuiFocus(true, true)
	end
end

-- Setter for SFX vars
function HUD:SendConfigData()
	SendNUIMessage({
		action = "SetConfigVars",
		clockSFX = cfg.clockSFX, 
		selfTestSFX = cfg.selfTestSFX,
		imgurApiKey = cfg.imgurApiKey,
		discordApiKey = cfg.discordWebhook,
		recordLimit = cfg.loggingSelectLimit,
		version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
		name = GetCurrentResourceName(),
		metric = cfg.useMetric,
		theme = HIST:GetTabletTheme(),
		osdStyle = HIST:GetOsdStyle(),
	})
end

-- Send Lidar return data
function HUD:SendLidarUpdate(speed, range, towards)
	if type(speed) == 'number' or type(range) == 'number' then
		speed = string.format('%.0f', speed)
		range = string.format("%.1f", range)
	end
	SendNUIMessage({
		action = "SendClockData",
		speed = speed,
		range = range,
		towards = towards,
	})
end

-- Send Lidar return data
function HUD:SendPeersDisplayData(dataTable)
	SendNUIMessage({
		action = "SendPeersDisplayData",
		speed = dataTable.speed,
		range = dataTable.range,
		arrow = dataTable.arrow,
		elapsedTime = dataTable.elapsedTime,
		battery = dataTable.battery,
	})
end

-- Send clear lidar strings
function HUD:ClearLidarDisplay()
	self:SendLidarUpdate('---', '----', -1)
end

-- Send change scope style
function HUD:ChangeSightStyle()
	SendNUIMessage({
		action = "scopestyle",
	})
end

--  Sends loading bar for random time
function HUD:DisplaySelfTest()
	local wait1 = math.random(10,50)*100
	local wait2 = math.random(150,750)
	local wait3 = math.random(7,10)*100
	CreateThread(function()
		HUD:SetSelfTestState(false, false)
		Wait(1000)
		SendNUIMessage({action = "SendSelfTestProgress", progress = "[|||________________]" })
		Wait(wait1)
		SendNUIMessage({ action = "SendSelfTestProgress", progress = "[||||||||___________]" })
		Wait(wait2)
		SendNUIMessage({ action = "SendSelfTestProgress", progress = "[||||||||||||||||||_]" })		
		Wait(wait3)
		SendNUIMessage({ action = "SendSelfTestProgress", progress = "[|||||||||||||||||||]", stopTimer = true })
		Wait(100)
		SendNUIMessage({ action = "SendSelfTestProgress", progress = "EEPROM   =   PASS" })
		Wait(2000)
		SendNUIMessage({ action = "SendSelfTestProgress", progress = "TIMER    =   PASS" })
		Wait(2000)
		SendNUIMessage({ action = "SendSelfTestProgress", progress = "CHECKSUM =   PASS" })
		Wait(2500)
		HUD:SetSelfTestState(true, true)
	end)
end

-- Handles initialization of self-test state
function HUD:SetSelfTestState(state, playSound)
	selfTestState = state
	SendNUIMessage({ action = "SetSelfTestState", state = selfTestState, sound = playSound })
	if state then
		HIST:SetSelfTestTimestamp()
		HUD:ClearLidarDisplay()
	end
end

function HUD:SetHistoryState(state)
	SendNUIMessage({ action = "SetHistoryState", state = state })
end

function HUD:SetHistoryData(index, data)
	SendNUIMessage({ action = "SendHistoryData", counter = index, time = data.time, clock = data.clock })
end

function HUD:SendDatabaseRecords(dataTable)
	SendNUIMessage({ action = "SendDatabaseRecords", name = GetPlayerName(PlayerId()), table = json.encode(dataTable), time = string.format("%s:%s:00", GetClockHours(), GetClockMinutes()) })
end
	
function HUD:SetTabletState(state)
	SetNuiFocus(state, state)
	SendNUIMessage({ action = "SetTabletState", state = state })
end

function HUD:GetCurrentDisplayData(closestPlayer)
	targetPlayer = closestPlayer
	SendNUIMessage({ action = "GetCurrentDisplayData" })
end

function HUD:SendBatteryPercentage(percentage)
	percentage = percentage or math.random(1,100)

	local bars = 4
	-- default full charge do not need to send NUI
	if percentage > 40 then
		return
	end
	-- 60%-4, 25%-3, 10%-2, 5%-1
	if percentage < 40 and percentage > 15 then
		bars = 3
	elseif percentage < 15 and percentage > 5 then
		bars = 2
	else
		bars = 1
	end
	SendNUIMessage({ action = "SendBatteryAmount", bars = bars })
end

--[[Callback for JS -> LUA to close tablet on html button]]
RegisterNUICallback('CloseTablet', function(cb)
	HUD:SetTabletState(false)
end )

--[[Callback for JS -> LUA to save current theme option]]
RegisterNUICallback('SendTheme', function(data, cb)
	HIST:SaveTabletTheme(data)
end )

--[[Callback for JS -> LUA to get display information back]]
RegisterNUICallback('ReturnCurrentDisplayData', function(data, cb)
	TriggerServerEvent('prolaser4:SendDisplayData', targetPlayer, data)
end )

--[[Callback for JS -> LUA to get OSD position and scale]]
RegisterNUICallback('ReturnOsdScaleAndPos', function(data, cb)
	HIST:SaveOsdStyle(data)
	SetNuiFocus(false, false)
end )

--[[Callback for JS -> LUA Notify of resolution change and temporary position reset]]
RegisterNUICallback('ResolutionChange', function(data, cb)
	if data.restore then
		HUD:ShowNotification("~y~Info~w~: resolution changed, restoring old ProLaser4 position.")
	else
		HUD:ShowNotification("~y~Info~w~: resolution changed, resetting ProLaser4 position temporarily.")
	end
end )

--On screen GTA V notification
function HUD:ShowNotification(text)
	SetNotificationTextEntry('STRING')
	AddTextComponentString(text)
	DrawNotification(false, true)
end

function HUD:DisplayControlHint(hint)
	SetTextComponentFormat('STRING')
	if hint == 'fpADS' then
		AddTextComponentString('~INPUT_AIM~ Toggle ADS\n~INPUT_LOOK_BEHIND~ Change Scope Style')
		DisplayHelpTextFromStringLabel(0, 0, 0, 5000)
	elseif hint == 'moveOSD' then
		AddTextEntry('prolaser4_move', '~INPUT_LOOK_LR~ Move\n~INPUT_WEAPON_WHEEL_PREV~ Resize Larger\n~INPUT_WEAPON_WHEEL_NEXT~ Resize Smaller')
		AddTextComponentSubstringTextLabel('prolaser4_move')
		DisplayHelpTextFromStringLabel(0, 0, 0, 7000)
	end
end