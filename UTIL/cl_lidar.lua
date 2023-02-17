calibrated = not cfg.requireCalibration

local cfg = cfg
local calibrating = false
local tempHidden = false
local shown = false
local hudMode = false
local inFirstPersonPed = true
local aim_down_sights = false
local ped, target, holdingLidarGun
local target_heading, ped_heading, allowable, towards, diff_heading

local lidarFOV = (cfg.minFOV+cfg.maxFOV)*0.5
local current_lidarFOV
local cam, weap, zoomvalue
local rightAxisX, rightAxisY, rotation
local camInVehicle
local inVehicleDeltaCamRot, last_z, last_x

local isHistoryActive = false
local historyIndex = 0

-- local speedMax = 200
-- local speedMin = 20
-- local speedLimit = 85

local slowScroll = 500
local fastScroll = 50
local scrollWait = slowScroll
local scrollDirection = nil

-- local function forward declarations
local GetLidarHeadingInfo
local CheckInputRotation, HandleZoom
local PlayButtonPressBeep, PlayFastAlertBeep

--	TOGGLE LIDAR DISPLAY COMMAND
RegisterCommand('lidar', function(source, args)
	if holdingLidarGun then
		-- open HUD Display and calibrate
		if shown == true then
			HUD:SetLidarDisplayState(false)
		else
			HUD:SetLidarDisplayState(true)
		end	
		shown = not shown
		if not calibrated and not calibrating then
			calibrating = true
			calibrated = HUD:DisplayCalibration()
		end
	end
end)
RegisterKeyMapping('lidar', 'Toggle Lidar Display', 'keyboard', cfg.toggleMenu)
TriggerEvent('chat:addSuggestion', '/lidar', 'Toggle lidar display.')


--	MAIN GET VEHICLE TO CLOCKTHREAD
Citizen.CreateThread(function()
	Wait(1000)
	-- Initialize Textures
	AddTextEntryByHash(GetHashKey("WT_VPISTOL"), "ProLaser 4")
	RequestStreamedTextureDict("w_pi_vintage_pistol")
	HUD:SetCalibrationState(calibrated, false)
	HUD:SendAudioVolumes()
		
	while not HasStreamedTextureDictLoaded("w_pi_vintage_pistol") do
		Wait(100)
	end
	
	while true do
		ped = PlayerPedId()
		holdingLidarGun = GetSelectedPedWeapon(ped) == GetHashKey(cfg.lidarGunHash)
		isInVehicle = IsPedInAnyVehicle(ped, true)
		if shown and holdingLidarGun and IsPlayerFreeAiming(PlayerId()) then
			found, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
			if IsPedInAnyVehicle(target) then
				target = GetVehiclePedIsIn(target, false)
			end
			Citizen.Wait(100)			
		else
			Citizen.Wait(500)
		end

	end
end)



-- REMOVE CONTROLS & HUD MESSAGE
Citizen.CreateThread( function()
	while true do
		Citizen.Wait(1)
		if holdingLidarGun then
			if not hudMode and IsPlayerFreeAiming(PlayerId()) then
				DrawSprite("w_pi_vintage_pistol", "lidar_reticle", 0.5, 0.5, 0.005, 0.01, 0.0, 200, 200, 200, 255)
			end
			DisablePlayerFiring(ped, true ) 				-- Disable Weapon Firing
			DisableControlAction(0, cfg.trigger, true) 		-- Disable Trigger Action
			DisableControlAction(0, cfg.previousHistory, true) 
			DisableControlAction(0, cfg.nextHistory, true) 
			DisableControlAction(0, 142, true) 				-- INPUT_MELEE_ATTACK_ALTERNATE
			DisableControlAction(0, 26, true) 				-- INPUT_LOOK_BEHIND
			DisableControlAction(0, 177, true)				-- INPUT_AIM
			-- if aiming down sight disable change weapon to enable scrolling without HUD wheel opening
			if IsPlayerFreeAiming(PlayerId()) then
				DisableControlAction(0, 99, true)				-- INPUT_VEH_SELECT_NEXT_WEAPON
				DisableControlAction(0, 16, true)				-- INPUT_SELECT_NEXT_WEAPON
				DisableControlAction(0, 17, true)				-- INPUT_SELECT_PREV_WEAPON
			end
		end
	end
end)

-- ADS HUD Call -> JS
Citizen.CreateThread( function()
	while true do
		if holdingLidarGun or hudMode then
			inFirstPersonPed = not isInVehicle and GetFollowPedCamViewMode() == 4
			inFirstPersonVeh = isInVehicle and GetFollowVehicleCamViewMode() == 4
			if not hudMode and aim_down_sights and (inFirstPersonPed or inFirstPersonVeh) then
				if not shown then
					shown = true
					if not calibrated and not calibrating then
						calibrating = true
						HUD:DisplayCalibration()
					end			
				end
				hudMode = true
				HUD:SetDisplayMode('ADS')
			elseif shown and hudMode and not (aim_down_sights and (inFirstPersonPed or inFirstPersonVeh)) then
				hudMode = false
				HUD:SetDisplayMode('DISPLAY')
			end
			Wait(100)
		else
			Wait(500)
		end
	end
end)

--LIDAR MAIN THREAD: handle hiding lidar NUI, calibration, ADS aiming, clocking, and control handling.
Citizen.CreateThread( function()
	while true do
		Citizen.Wait(1)
		-- Hide HUD if weapon not selected, keep lidar on
		if (not holdingLidarGun or IsWarningMessageActive() or IsPauseMenuActive()) and shown and not tempHidden then
			HUD:SetDisplayMode('DISPLAY')
			hudMode = false
			HUD:SetLidarDisplayState(false)
			tempHidden = true
		elseif holdingLidarGun and not (IsWarningMessageActive() or IsPauseMenuActive()) and tempHidden then
			HUD:SetLidarDisplayState(true)
			tempHidden = false
		end

		if holdingLidarGun then
			-- toggle ADS if first person and aim, otherwise unADS
			if not aim_down_sights and IsControlJustPressed(0,25) and (inFirstPersonPed or inFirstPersonVeh) then
				aim_down_sights = true
				SetPlayerForcedAim(PlayerId(), true)
			elseif aim_down_sights and (IsDisabledControlJustPressed(0,177) or IsControlJustPressed(0,25) or not (inFirstPersonPed or inFirstPersonVeh)) then
				aim_down_sights = false
				SetPlayerForcedAim(PlayerId(), false)
				Wait(100)
			elseif not aim_down_sights and (inFirstPersonPed or inFirstPersonVeh) and IsPlayerFreeAiming(PlayerId()) then
				aim_down_sights = true
				SetPlayerForcedAim(PlayerId(), true)
			end

			--	Get target speed and update display
			if shown and not tempHidden and calibrated then
				if IsDisabledControlPressed(1, cfg.trigger) and not isHistoryActive and IsPlayerFreeAiming(PlayerId())  then 
					allowable, towards = GetLidarHeadingInfo(target, ped)
					if allowable or not cfg.accurateAngle then
						speed = math.floor(GetEntitySpeed(target)*2.236936) -- m/s to mph
						range  = GetDistanceBetweenCoords(GetEntityCoords(ped),GetEntityCoords(target), true)*3.2808399	--m to ft
						if speed > 0 then
							HUD:SendLidarUpdate(speed, string.format("%.1f", range), towards)
							HIST:StoreLidarData(target, speed, range, towards)
						end
					else
						HUD:ClearLidarDisplay()
					end
				--	Hides history if on first, otherwise go to previous history
				elseif IsDisabledControlPressed(0, cfg.previousHistory) and #HIST.history > 0 then
					if isHistoryActive then
						historyIndex = historyIndex - 1
						if scrollWait == slowScroll then
							PlayButtonPressBeep()
						end
						if historyIndex > 0 then
							HUD:SetHistoryData(historyIndex, HIST.history[historyIndex])
							Wait(scrollWait)
						else
							isHistoryActive = false
							HUD:SetHistoryState(false)
						end
					end
				-- Displays history if not shown, otherwise go to next history page.
				elseif IsDisabledControlPressed(0, cfg.nextHistory) and #HIST.history > 0 then
					isHistoryActive = true
					HUD:SetHistoryState(isHistoryActive)
					if historyIndex < #HIST.history then
						if scrollWait == slowScroll then
							PlayButtonPressBeep()
						end
						historyIndex = historyIndex + 1
						HUD:SetHistoryData(historyIndex, HIST.history[historyIndex])
						Wait(scrollWait)
					end
				elseif IsDisabledControlJustReleased(0, cfg.changeSight) and aim_down_sights then
					HUD:ChangeSightStyle()
				end
				--[[
				-- Increase fast speed.
				elseif IsDisabledControlPressed(0, cfg.increaseFastSpeed) and not isHistoryActive then
					if not isFastSpeedActive then
						HUD:SetFastSpeedState(true)
						isFastSpeedActive = true
					end
					if speedLimit < speedMax then
						speedLimit = speedLimit + 1
					end
					if scrollWait == slowScroll then
						PlayButtonPressBeep()
					end
					HUD:SendFastLimit(speedLimit)
					Wait(scrollWait)
				-- Decrease fast speed.
				elseif IsDisabledControlPressed(0, cfg.decreaseFastSpeed) and not isHistoryActive then
					if not isFastSpeedActive then
						HUD:SetFastSpeedState(true)
						isFastSpeedActive = true
					end
					isFastSpeedActive = true
					if speedLimit > speedMin then
						speedLimit = speedLimit - 1
					end
					if scrollWait == slowScroll then
						PlayButtonPressBeep()
					end
					HUD:SendFastLimit(speedLimit)
					Wait(scrollWait)	
				-- Close fast speed.
				elseif IsDisabledControlPressed(2, cfg.closeFastSpeed) and isFastSpeedActive then
					isFastSpeedActive = false
					HUD:SetFastSpeedState(false)
				end]]
			end
		else
			Wait(500)
		end
	end
end)

-- SCROLL NEXT SPEED: handles fast scrolling, if holding scroll increase scroll speed.
CreateThread(function()
	Wait(1000)
	while true do
		if holdingLidarGun then
			if isHistoryActive then
				local count = 0
				while IsDisabledControlPressed(0, cfg.nextHistory) do
					count = count + 1
					if count > 15 then
						scrollDirection = 'next'
						scrollWait = fastScroll
						break;
					end
					Wait(100)
				end
				if scrollDirection == 'next' and not IsDisabledControlPressed(0, cfg.nextHistory) then
					scrollWait = slowScroll
				end
			else
				Wait(200)
			end
		else
			Wait(500)
		end
		Wait(0)
	end
end)

-- SCROLL PREVIOUS SPEED: handles fast scrolling, if holding scroll increase scroll speed.
CreateThread(function()
	while true do
		if holdingLidarGun then
			if isHistoryActive then
				local count = 0
				while IsDisabledControlPressed(0, cfg.previousHistory) do
					count = count + 1
					if count > 15 then
						scrollDirection = 'prev'
						scrollWait = fastScroll
						break;
					end
					Wait(100)
				end
				if scrollDirection == 'prev' and not IsDisabledControlPressed(0, cfg.previousHistory) then
					scrollWait = slowScroll
				end
			else
				Wait(200)
			end
		else
			Wait(500)
		end
		Wait(0)
	end
end)

--[[ SCROLL NEXT SPEED: handles fast scrolling, if holding scroll increase scroll speed.
CreateThread(function()
	Wait(1000)
	while true do
		if holdingLidarGun then
			if isFastSpeedActive then
				local count = 0
				while IsDisabledControlPressed(0, cfg.increaseFastSpeed) do
					count = count + 1
					if count > 15 then
						scrollDirection = 'increase'
						scrollWait = fastScroll
						break;
					end
					Wait(100)
				end
				if scrollDirection == 'next' and not IsDisabledControlPressed(0, cfg.increaseFastSpeed) then
					scrollWait = slowScroll
				end
			else
				Wait(200)
			end
		else
			Wait(500)
		end
		Wait(0)
	end
end)

-- SCROLL PREVIOUS SPEED: handles fast scrolling, if holding scroll increase scroll speed.
CreateThread(function()
	while true do
		if holdingLidarGun then
			if isFastSpeedActive then
				local count = 0
				while IsDisabledControlPressed(0, cfg.decreaseFastSpeed) do
					count = count + 1
					if count > 15 then
						scrollDirection = 'decrease'
						scrollWait = fastScroll
						break;
					end
					Wait(100)
				end
				if scrollDirection == 'decrease' and not IsDisabledControlPressed(0, cfg.decreaseFastSpeed) then
					scrollWait = slowScroll
				end
			else
				Wait(200)
			end
		else
			Wait(500)
		end
		Wait(0)
	end
end)]]

-- AIM DOWNSIGHTS CAM & ZOOM
CreateThread(function()
	while true do
		if holdingLidarGun then
			if aim_down_sights then
				cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
				weap = GetCurrentPedWeaponEntityIndex(ped)
				if isInVehicle then
					AttachCamToEntity(cam, weap, -0.018, -0.2, -0.05, true)
					camInVehicle = true
				else
					AttachCamToEntity(cam, weap, 0.0, -0.2, -0.0, true)
					camInVehicle = false
				end
				SetCamRot(cam, GetGameplayCamRot(2), 2)
				SetCamFov(cam, lidarFOV)
				RenderScriptCams(true, false, 0, 1, 0)
				if cfg.displayControls then
					HUD:DisplayControlHint()
					cfg.displayControls = false
				end

				while aim_down_sights and not IsEntityDead(ped) do	
					if ((camInVehicle and not isInVehicle) or (not camInVehicle and isInVehicle)) or not holdingLidarGun then
						aim_down_sights = false
						SetPlayerForcedAim(PlayerId(), false)
						delayEntry = true
						break
					end
					zoomvalue = (1.0/(cfg.maxFOV-cfg.minFOV))*(lidarFOV-cfg.minFOV)
					CheckInputRotation(cam, zoomvalue)			
					HandleZoom(cam)
					Wait(1)
				end
				RenderScriptCams(false, false, 0, 1, 0)
				SetScaleformMovieAsNoLongerNeeded(scaleform)
				DestroyCam(cam, false)
			end
			Wait(1)
		else
			Wait(500)
		end
	end
end)


--FUNCTIONS--
--	HEADING LIMIT VALIDATION AND TOWARDS/AWAY INFO
GetLidarHeadingInfo = function(target, ped)
	target_heading = GetEntityHeading(target)
	if isInVehicle then
		ped_heading = GetCamRot(cam, 2)[3]
	else
		ped_heading = GetEntityHeading(ped) + GetGameplayCamRelativeHeading()
	end
	allowable = true
	towards = false
	
	diff_heading = math.abs((ped_heading - target_heading + 180) % 360 - 180)
	if ( diff_heading > cfg.maxAngle and diff_heading < (180 - cfg.maxAngle) ) then
		allowable =  false
	end
	
	if ( diff_heading > 135 ) then
		towards = true
	end
	return allowable, towards
end

--	AIM DOWNSIGHTS PAN
CheckInputRotation = function(cam, zoomvalue)
	rightAxisX = GetDisabledControlNormal(0, 220)
	rightAxisY = GetDisabledControlNormal(0, 221)
	rotation = GetCamRot(cam, 2)
	if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
		if isInVehicle then
			new_z = rotation.z + rightAxisX*-1.0*(cfg.verticalPanSpeed-zoomvalue*8) 
			new_x = math.max(math.min(20.0, rotation.x + rightAxisY*-1.0*(cfg.horizontalPanSpeed-zoomvalue*8)), -20.0) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
			SetCamRot(cam, new_x, 0.0, new_z, 2)
			SetGameplayCamRelativeRotation(0.0, 0.0, 0.0)
			-- limit ADS rotation while in vehicle
			inVehicleDeltaCamRot = (GetCamRot(cam, 2)[3] - GetEntityHeading(ped) + 180) % 360 - 180
			while inVehicleDeltaCamRot < -75 and inVehicleDeltaCamRot > -130 do
				new_z = new_z + 0.2
				SetCamRot(cam, new_x, 0.0, new_z, 2)
				inVehicleDeltaCamRot = (GetCamRot(cam, 2)[3] - GetEntityHeading(ped) + 180) % 360 - 180
				Wait(1)
			end			
			while inVehicleDeltaCamRot > 178 or (inVehicleDeltaCamRot > -180 and inVehicleDeltaCamRot < -130) do
				new_z = new_z - 0.2
				SetCamRot(cam, new_x, 0.0, new_z, 2)
				inVehicleDeltaCamRot = (GetCamRot(cam, 2)[3] - GetEntityHeading(ped) + 180) % 360 - 180
				Wait(1)
			end
		else
			new_z = rotation.z + rightAxisX*-1.0*(cfg.verticalPanSpeed-zoomvalue*8)
			new_x = math.max(math.min(40.0, rotation.x + rightAxisY*-1.0*(cfg.horizontalPanSpeed-zoomvalue*8)), -89.5) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
			SetCamRot(cam, new_x, 0.0, new_z, 2)
			SetGameplayCamRelativeRotation(0.0, new_x, new_z)
		end
	end
end

--	AIM DOWNSIGHTS ZOOM
HandleZoom = function(cam)
	if  IsDisabledControlPressed(0,15) or IsDisabledControlPressed(0, 99) then -- Scrollup
		lidarFOV = math.max(lidarFOV - cfg.zoomSpeed, cfg.maxFOV)
	end
	if  IsDisabledControlPressed(0,334) or IsDisabledControlPressed(0, 16) then
		lidarFOV = math.min(lidarFOV + cfg.zoomSpeed/6, cfg.minFOV) -- ScrollDown
	end
	current_lidarFOV = GetCamFov(cam)
	if math.abs(lidarFOV-current_lidarFOV) < 0.1 then -- the difference is too small, just set the value directly to avoid unneeded updates to FOV of order 10^-5
		lidarFOV = current_lidarFOV
	end
	SetCamFov(cam, current_lidarFOV + (lidarFOV - current_lidarFOV)*0.03) -- Smoothing of camera zoom
end

--	Play NUI front in audio.
PlayButtonPressBeep = function()
	SendNUIMessage({
	  action  = 'PlayButtonPressBeep',
	  file   = 'LidarBeep',
	})
end

--[[
PlayFastAlertBeep = function()
	SendNUIMessage({
	  action  = 'PlayFastAlertBeep',
	  file   = 'LidarFastAlert',
	})
end
]]

