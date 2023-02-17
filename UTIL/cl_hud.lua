HUD = {}

local cfg = cfg
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
function HUD:SendAudioVolumes()
	SendNUIMessage({
		action = "SetConfigVars",
		clockSFX = cfg.clockSFX, 
		calibrationSFX = cfg.calibrationSFX, 
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
							
function HUD:DisplayControlHint()
	SetTextComponentFormat('STRING')
	AddTextComponentString('~INPUT_AIM~ Toggle ADS\n~INPUT_LOOK_BEHIND~ Change Scope Style')
	DisplayHelpTextFromStringLabel(0, 0, 0, 5000)
end


function HUD:DisplayCalibration()
	local wait1 = math.random(7,80)*100
	local wait2 = math.random(150,750)
	local wait3 = math.random(7,30)*100
	CreateThread(function()
		SendNUIMessage({ action = "SendCalibrationState", state = false })
		Wait(1000)
		SendNUIMessage({action = "SendCalibrationProgress", progress = "[|||________________]" })
		Wait(wait1)
		SendNUIMessage({ action = "SendCalibrationProgress", progress = "[||||||||___________]" })
		Wait(wait2)
		SendNUIMessage({ action = "SendCalibrationProgress", progress = "[||||||||||||||||||_]" })		
		Wait(wait3)
		SendNUIMessage({ action = "SendCalibrationProgress", progress = "[|||||||||||||||||||]" })
		SendNUIMessage({ action = "SendCalibrationState", state = true, sound = true })
		Wait(500)
		self:ClearLidarDisplay()
		calibrated = true
	end)
end


function HUD:SetCalibrationState(state, playSound)
	self:SendBatteryAmount(math.random(1,100))
	SendNUIMessage({ action = "SendCalibrationState", state = state, sound = playSound })
	if state then
		HUD:ClearLidarDisplay()
	end
end

function HUD:SetHistoryState(state)
	SendNUIMessage({ action = "SetHistoryState", state = state })
end

function HUD:SetHistoryData(index, data)
	SendNUIMessage({ action = "SendHistoryData", counter = index, time = data.time, clock = data.clock })
end

-- function HUD:SetFastSpeedState(state)
	-- SendNUIMessage({ action = "SetFastSpeedState", state = state })
-- end

-- function HUD:SendFastLimit(speed)
	-- SendNUIMessage({ action = "SendFastLimit", speed = speed })
-- end

function HUD:SendBatteryAmount(percentage)
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