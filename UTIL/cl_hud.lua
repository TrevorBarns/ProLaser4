HUD = {}

local cfg = cfg

function HUD:SetLidarDisplayState(state)
	SendNUIMessage({ action = "SetLidarDisplayState", state = state })
end

function HUD:SetDisplayMode(mode)
	SendNUIMessage({ action = "SetDisplayMode", mode = mode })
end

function HUD:SendAudioVolumes()
	SendNUIMessage({
		action = "SetConfigVars",
		clockSFX = cfg.clockSFX, 
		calibrationSFX = cfg.calibrationSFX, 
	})
end

function HUD:SendLidarUpdate(speed, range, towards)
	SendNUIMessage({
		action = "SendClockData",
		speed = speed,
		range = range,
		towards = towards,
	})
end

function HUD:ClearLidarDisplay()
	self:SendLidarUpdate('---', '----', -1)
end

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
	CreateThread(function()
		local wait1 = math.random(7,80)*100
		local wait2 = math.random(150,750)
		local wait3 = math.random(7,30)*100
		SendNUIMessage({ action = "SendCalibrationState", state = false })
		Wait(1000)
		SendNUIMessage({action = "SendCalibrationProgress", progress = "[|||________________]" })
		Wait(wait1)
		SendNUIMessage({ action = "SendCalibrationProgress", progress = "[||||||||___________]" })
		Wait(wait2)
		SendNUIMessage({ action = "SendCalibrationProgress", progress = "[||||||||||||||||||_]" })		
		Wait(wait3)
		SendNUIMessage({ action = "SendCalibrationProgress", progress = "[|||||||||||||||||||]" })
		SendNUIMessage({ action = "SendCalibrationState", state = true })
		Wait(500)
		self:ClearLidarDisplay()
		calibrated = true
	end)
end


function HUD:SetCalibrationState(state)
	SendNUIMessage({ action = "SendCalibrationState", state = state })
	if state then
		HUD:ClearLidarDisplay()
	end
end
