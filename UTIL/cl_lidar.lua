calibrated = not cfg.requireCalibration

local cfg = cfg
local calibrating = false
local tempHidden = false
local shown = false
local hudMode = false
local inFirstPersonPed = true
local LidarFOV = (cfg.minFOV+cfg.maxFOV)*0.5
local aim_down_sights = false

--	MAIN GET VEHICLE THREAD
local ped, t_ped, t_veh, holdingRadarGun
Citizen.CreateThread(function()
	Wait(100)
	-- Init
	AddTextEntryByHash(GetHashKey("WT_VPISTOL"), "ProLaser 4")
	RequestStreamedTextureDict("w_pi_vintage_pistol")
	HUD:SetCalibrationState(calibrated)
	HUD:SendAudioVolumes()
	while not HasStreamedTextureDictLoaded("w_pi_vintage_pistol") do
		Wait(5)
	end
	
	while(true) do
		ped = PlayerPedId()
		holdingRadarGun = GetSelectedPedWeapon(ped) == GetHashKey(cfg.lidarGunHash)
		isInVehicle = IsPedInAnyVehicle(ped, true)		
		if shown and holdingRadarGun and IsPlayerFreeAiming(PlayerId()) then
			found, t_ped = GetEntityPlayerIsFreeAimingAt(PlayerId())
			veh = GetVehiclePedIsIn(t_ped, false)
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
		if holdingRadarGun then
			if not hudMode and IsPlayerFreeAiming() then
				DrawSprite("w_pi_vintage_pistol", "lidar_reticle", 0.5, 0.5, 0.0030, 0.006, 0.0, 200, 200, 200, 255)
			end
			DisablePlayerFiring(ped, true ) 				-- Disable Weapon Firing
			DisableControlAction(0, cfg.toggleMenu, true) 	-- Disable ToggleMenu Action
			DisableControlAction(0, cfg.trigger, true) 		-- Disable Trigger Action
			DisableControlAction(0, 142, true) 				-- INPUT_MELEE_ATTACK_ALTERNATE
			DisableControlAction(0, 26, true) 				-- INPUT_LOOK_BEHIND
			DisableControlAction(0, 177, true)				-- INPUT_AIM
			DisableControlAction(0, 99, true)				-- INPUT_VEH_SELECT_NEXT_WEAPON
			DisableControlAction(0, 50, true)				-- INPUT_ACCURATE_AIM
			DisableControlAction(0, 16, true)				-- INPUT_SELECT_NEXT_WEAPON
			DisableControlAction(0, 17, true)				-- INPUT_SELECT_PREV_WEAPON
		end
	end
end)

-- ADS HUD Call -> JS
Citizen.CreateThread( function()
	while true do
		Citizen.Wait(100)
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
	end
end)


--RADAR NUI
Citizen.CreateThread( function()
	while true do
		Citizen.Wait(1)
		-- Hide HUD if weapon not selected, keep radar on
		if not holdingRadarGun and shown == true and not tempHidden then
			HUD:SetLidarDisplayState(false)
			tempHidden = true
		elseif holdingRadarGun and tempHidden then
			HUD:SetLidarDisplayState(true)
			tempHidden = false
		end

		if holdingRadarGun then
			-- Open HUD Display and calibrate
			if IsDisabledControlJustPressed(0, cfg.toggleMenu) then 
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

			--	Get vehicle speed and update display
			if shown and not tempHidden then
				if IsDisabledControlPressed(1, cfg.trigger) then 
					if IsEntityAVehicle(veh) then
						if calibrated then
							allowable, towards = GetLidarHeadingInfo(veh, ped)
							if allowable or not cfg.accurateAngle then
								speed = math.floor(GetEntitySpeed(veh)*2.236936) -- m/s to mph
								range = string.format("%.0f", (GetDistanceBetweenCoords(GetEntityCoords(ped),GetEntityCoords(veh), true)*3.2808399)) --m to ft
								HUD:SendLidarUpdate(speed, range, towards)
							else
								HUD:ClearLidarDisplay()
							end
						end
					end
				elseif IsDisabledControlJustPressed(0, cfg.changeSight) then
					HUD:ChangeSightStyle()
				end
			end
		else
			Wait(500)
		end
	end
end)


-- AIM DOWNSIGHTS CAM & ZOOM
local cam, weap, zoomvalue
CreateThread(function()
	while true do
        Wait(1)
		if aim_down_sights then
			cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
			weap = GetCurrentPedWeaponEntityIndex(ped)
			if isInVehicle then
				AttachCamToEntity(cam, weap, -0.018, -0.2, -0.05, true)
			else
				AttachCamToEntity(cam, weap, 0.0, -0.2, -0.0, true)
			end
			SetCamRot(cam, GetGameplayCamRot(2), 2)
			SetCamFov(cam, LidarFOV)
			RenderScriptCams(true, false, 0, 1, 0)
			if cfg.displayControls then
				HUD:DisplayControlHint()
				cfg.displayControls = false
			end

			while aim_down_sights and not IsEntityDead(ped) do	
				zoomvalue = (1.0/(cfg.maxFOV-cfg.minFOV))*(LidarFOV-cfg.minFOV)
				CheckInputRotation(cam, zoomvalue)			
				HandleZoom(cam)
				Wait(1)
			end

			RenderScriptCams(false, false, 0, 1, 0)
			SetScaleformMovieAsNoLongerNeeded(scaleform)
			DestroyCam(cam, false)
		end
	end
end)


--FUNCTIONS--
--	CALIBRATE RADAR DISPLAY
--	HEADING LIMIT VALIDATION AND TOWARDS/AWAY INFO
local veh_heading, ped_heading, allowable, towards, diff_heading
function GetLidarHeadingInfo( veh, ped )
	veh_heading = GetEntityHeading( veh )
	ped_heading = GetEntityHeading( ped ) + GetGameplayCamRelativeHeading()
	allowable = true
	towards = false
	
	diff_heading = math.abs((ped_heading - veh_heading + 180) % 360 - 180)
	if ( diff_heading > cfg.maxAngle and diff_heading < (180 - cfg.maxAngle) ) then
		allowable =  false
	end
	
	if ( diff_heading > 135 ) then
		towards = true
	end
	return allowable, towards
end

local rightAxisX, rightAxisY, rotation
--	AIM DOWNSIGHTS PAN
function CheckInputRotation(cam, zoomvalue)
	rightAxisX = GetDisabledControlNormal(0, 220)
	rightAxisY = GetDisabledControlNormal(0, 221)
	rotation = GetCamRot(cam, 2)
	if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
		if not isInVehicle then
			new_z = rotation.z + rightAxisX*-1.0*(cfg.verticalPanSpeed-zoomvalue*8)
			new_x = math.max(math.min(40.0, rotation.x + rightAxisY*-1.0*(cfg.horizontalPanSpeed-zoomvalue*8)), -89.5) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
			SetCamRot(cam, new_x, 0.0, new_z, 2)
			SetGameplayCamRelativeRotation(0.0, new_x, new_z)
		else
			new_z = rotation.z + rightAxisX*-1.0*(cfg.verticalPanSpeed-zoomvalue*8) 
			new_x = math.max(math.min(20.0, rotation.x + rightAxisY*-1.0*(cfg.horizontalPanSpeed-zoomvalue*8)), -20.0) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
			SetCamRot(cam, new_x, 0.0, new_z, 2)
			SetGameplayCamRelativeRotation(0.0, 0.0, 0.0)
		end
	end
end


--	AIM DOWNSIGHTS ZOOM
local current_LidarFOV
function HandleZoom(cam)
	if  IsDisabledControlPressed(0,15) or IsDisabledControlPressed(0, 99) then -- Scrollup
		LidarFOV = math.max(LidarFOV - cfg.zoomSpeed, cfg.maxFOV)
	end
	if  IsDisabledControlPressed(0,334) or IsDisabledControlPressed(0, 16) then
		LidarFOV = math.min(LidarFOV + cfg.zoomSpeed/6, cfg.minFOV) -- ScrollDown
	end
	current_LidarFOV = GetCamFov(cam)
	if math.abs(LidarFOV-current_LidarFOV) < 0.1 then -- the difference is too small, just set the value directly to avoid unneeded updates to FOV of order 10^-5
		LidarFOV = current_LidarFOV
	end
	SetCamFov(cam, current_LidarFOV + (LidarFOV - current_LidarFOV)*0.03) -- Smoothing of camera zoom
end

