HUD = {}

local cfg = cfg
local lastMode = 'idle'

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
		jammingSFX = cfg.jammingSFX, 
	})
end

function HUD:SendLidarUpdate(speed, range, towards)
	SendNUIMessage({
		action = "SetClockData",
		speed = speed,
		range = range,
		towards = towards,
	})
end

function HUD:ClearLidarDisplay()
	self:SendLidarUpdate('---', '----', -1)
end

function HUD:ChangeSightStyle(useSniperScope)
	SendNUIMessage({
		action = "ToggleScopeStyle",
		sniperScope = useSniperScope
	})
end
							
function HUD:DisplayControlHint()
	SetTextComponentFormat('STRING')
	AddTextComponentString('~INPUT_AIM~ Toggle ADS\n~INPUT_LOOK_BEHIND~ Change Scope Style')
	DisplayHelpTextFromStringLabel(0, 0, 0, 5000)
end


function HUD:DisplayCalibration()
	CreateThread(function()
		local wait1 = math.random(7,50)*100
		local wait2 = math.random(150,750)
		local wait3 = math.random(7,20)*100
		SendNUIMessage({ action = "SetCalibrationState", state = false })
		Wait(1000)
		SendNUIMessage({action = "SetCalibrationProgress", progress = "[|||________________]" })
		Wait(wait1)
		SendNUIMessage({ action = "SetCalibrationProgress", progress = "[||||||||___________]" })
		Wait(wait2)
		SendNUIMessage({ action = "SetCalibrationProgress", progress = "[||||||||||||||||||_]" })		
		Wait(wait3)
		SendNUIMessage({ action = "SetCalibrationProgress", progress = "[|||||||||||||||||||]" })
		SendNUIMessage({ action = "SetCalibrationState", state = true })
		Wait(500)
		self:ClearLidarDisplay()
		calibrated = true
	end)
end


function HUD:SetCalibrationState(state)
	SendNUIMessage({ action = "SetCalibrationState", state = state })
	if state then
		HUD:ClearLidarDisplay()
	end
end


-- [[JAMMER]]
function HUD:SetJammerDisplayState(state)
	SendNUIMessage({ action = "SetJammerDisplayState", state = state })
end

function HUD:SetJammerMode(mode, override)
	override = override or false
	if mode ~= lastMode or override then
		SendNUIMessage({ action = "SetJammerMode", mode = mode })
		lastMode = mode
	end
end