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

-- Setter for SFX vars
function HUD:SendConfigData()
	SendNUIMessage({
		action = "SetConfigVars",
		clockSFX = cfg.clockSFX, 
		selfTestSFX = cfg.selfTestSFX,
		imgurApiKey = cfg.imgurApiKey,
		recordLimit = cfg.loggingSelectLimit,
		version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
		name = GetCurrentResourceName()
	})
end

-- Send Lidar return data
function HUD:SendLidarUpdate(speed, range, towards)
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
	self:SendLidarUpdate('0', '----', -1)
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
		SendNUIMessage({ action = "SetSelfTestState", state = false })
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
		Wait(2000)
		SendNUIMessage({ action = "SetSelfTestState", state = true, sound = true })
		Wait(500)
		self:ClearLidarDisplay()
		selfTestState = true
	end)
end

-- Handles initialization of self-test state
function HUD:SetSelfTestState(state, playSound)
	SendNUIMessage({ action = "SetSelfTestState", state = state, sound = playSound })
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
	SendNUIMessage({ action = "SendDatabaseRecords", name = GetPlayerName(PlayerId()), table = json.encode(dataTable) })
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

--[[Callback for JS -> LUA to get display information back]]
RegisterNUICallback('ReturnCurrentDisplayData', function(data, cb)
	TriggerServerEvent('prolaser4:SendDisplayData', targetPlayer, data)
end )

--On screen GTA V notification
function HUD:ShowNotification(text)
	SetNotificationTextEntry('STRING')
	AddTextComponentString(text)
	DrawNotification(false, true)
end

function HUD:DisplayControlHint()
	SetTextComponentFormat('STRING')
	AddTextComponentString('~INPUT_AIM~ Toggle ADS\n~INPUT_LOOK_BEHIND~ Change Scope Style')
	DisplayHelpTextFromStringLabel(0, 0, 0, 5000)
end