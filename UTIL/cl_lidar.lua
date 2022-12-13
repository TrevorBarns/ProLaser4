calibrated = not cfg.requireCalibration

local cfg = cfg
local calibrating = false
local tempHidden = false
local shown = false
local hudMode = false
local inFirstPersonPed = true
local lidarFOV = (cfg.minFOV+cfg.maxFOV)*0.5
local aimDownSights = false
local savePrefix = 'proLaser4_'
local useSniperScope = false

--	MAIN GET VEHICLE THREAD
local ped, tPed, tVeh, holdingRadarGun
CreateThread(function()
	Wait(100)
	-- Init - rename weapon, set volumes and calibration state
	AddTextEntryByHash(GetHashKey("WT_VPISTOL"), "ProLaser 4")
	HUD:SetCalibrationState(calibrated)
	HUD:SendAudioVolumes()
	useSniperScope = GetResourceKvpInt(savePrefix..'scopeStyle') == 1
	HUD:ChangeSightStyle(useSniperScope)
	-- Get Reticle Texture
	RequestStreamedTextureDict("w_pi_vintage_pistol")
	while not HasStreamedTextureDictLoaded("w_pi_vintage_pistol") do
		Wait(5)
	end
	
	while(true) do
		ped = PlayerPedId()
		holdingRadarGun = GetSelectedPedWeapon(ped) == GetHashKey(cfg.lidarGunHash)
		isInVehicle = IsPedInAnyVehicle(ped, true)		
		if shown and holdingRadarGun and IsPlayerFreeAiming(PlayerId()) then
			found, tPed = GetEntityPlayerIsFreeAimingAt(PlayerId())
			tVeh = GetVehiclePedIsIn(tPed, false)
			Citizen.Wait(200)			
		else
			Citizen.Wait(500)
		end
	end
end)

-- REMOVE CONTROLS & HUD MESSAGE
CreateThread( function()
	while true do
		Citizen.Wait(1)
		if holdingRadarGun then
			if hudMode then
				HideHudAndRadarThisFrame()
			elseif IsPlayerFreeAiming() then
				DisableControlAction(0, 16, true)				-- INPUT_SELECT_NEXT_WEAPON
				DisableControlAction(0, 17, true)				-- INPUT_SELECT_PREV_WEAPON
				DrawSprite("w_pi_vintage_pistol", "lidar_reticle", 0.5, 0.5, 0.0030, 0.006, 0.0, 200, 200, 200, 255)
			end
			DisablePlayerFiring(ped, true ) 				-- Disable Weapon Firing
			DisableControlAction(0, cfg.toggleMenu, true) 	-- Disable ToggleMenu Action
			DisableControlAction(0, cfg.trigger, true) 		-- Disable Trigger Action
			DisableControlAction(0, 142, true) 				-- INPUT_MELEE_ATTACK_ALTERNATE
			DisableControlAction(0, 26, true) 				-- INPUT_LOOK_BEHIND
			DisableControlAction(0, 177, true)				-- INPUT_AIM
			DisableControlAction(0, 99, true)				-- INPUT_VEH_SELECT_NEXT_WEAPON
		end
	end
end)

-- ADS HUD Call -> JS
CreateThread( function()
	while true do
		if holdingRadarGun then
			inFirstPersonPed = not isInVehicle and GetFollowPedCamViewMode() == 4
			if not hudMode and aimDownSights and inFirstPersonPed then
				if not shown then
					shown = true
					if not calibrated and not calibrating then
						calibrating = true
						HUD:DisplayCalibration()
					end			
				end
				hudMode = true
				HUD:SetDisplayMode('ADS')
			elseif shown and hudMode and not (aimDownSights and inFirstPersonPed) then
				hudMode = false
				HUD:SetDisplayMode('DISPLAY')
			end
			Wait(50)
		else
			Wait(500)
		end
	end
end)


--RADAR NUI
CreateThread( function()
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
			if not aimDownSights and IsControlJustPressed(0,25) and inFirstPersonPed then
				aimDownSights = true
				SetPlayerForcedAim(PlayerId(), true)
			elseif aimDownSights and (IsDisabledControlJustPressed(0,177) or IsControlJustPressed(0,25) or not inFirstPersonPed) then
				aimDownSights = false
				SetPlayerForcedAim(PlayerId(), false)
				Wait(100)
			elseif not aimDownSights and inFirstPersonPed and IsPlayerFreeAiming(PlayerId()) then
				aimDownSights = true
				SetPlayerForcedAim(PlayerId(), true)
			end	

			--	Get vehicle speed and update display
			if shown and not tempHidden then
				if IsDisabledControlPressed(1, cfg.trigger) then 
					if IsEntityAVehicle(tVeh) then
						if calibrated then
							allowable, towards = GetLidarHeadingInfo(tVeh, ped)
							if not JAM:IsVehJamming(tVeh) and (allowable or not cfg.accurateAngle) then
								speed = math.floor(GetEntitySpeed(tVeh)*2.236936) -- m/s to mph
								range = string.format("%.0f", (GetDistanceBetweenCoords(GetEntityCoords(ped),GetEntityCoords(tVeh), true)*3.2808399)) --m to ft
								HUD:SendLidarUpdate(speed, range, towards)
							else
								HUD:ClearLidarDisplay()
							end
						end
					end
				elseif IsDisabledControlJustReleased(0, cfg.trigger) then
					if lastLasedVeh ~= nil then
						TriggerServerEvent('Jammer:Lasing', lastLasedVeh, false)
						lastLasedVeh = nil
					end
				elseif IsDisabledControlJustPressed(0, cfg.changeSight) then
					useSniperScope = not useSniperScope
					HUD:ChangeSightStyle(useSniperScope)
					SetResourceKvpInt(savePrefix..'scopeStyle', useSniperScope)
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
		if holdingRadarGun and not isInVehicle then
			if aimDownSights then
				if not isInVehicle then
					cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
					weap = GetCurrentPedWeaponEntityIndex(ped)
					AttachCamToEntity(cam, weap, 0.0,0.00 ,0.0, true)
					SetCamRot(cam, GetGameplayCamRot(2), 2)
					SetCamFov(cam, lidarFOV)
					RenderScriptCams(true, false, 0, 1, 0)
					
					if cfg.displayControls then
						HUD:DisplayControlHint()
						cfg.displayControls = false
					end

					while aimDownSights and not IsEntityDead(ped) and not isInVehicle do	
						zoomvalue = (1.0/(cfg.maxFOV-cfg.minFOV))*(lidarFOV-cfg.minFOV)
						CheckInputRotation(cam, zoomvalue)			
						HandleZoom(cam)
						Wait(1)
					end

					RenderScriptCams(false, false, 0, 1, 0)
					SetScaleformMovieAsNoLongerNeeded(scaleform)
					DestroyCam(cam, false)
				end
			end
		else
			Wait(1000)
		end
	end
end)


--FUNCTIONS--
--	CALIBRATE RADAR DISPLAY
--	HEADING LIMIT VALIDATION AND TOWARDS/AWAY INFO
local vehHeading, pedHeading, allowable, towards, differenceHeading
function GetLidarHeadingInfo( veh, ped )
	vehHeading = GetEntityHeading( veh )
	pedHeading = GetEntityHeading( ped )
	allowable = true
	towards = false
	
	differenceHeading = math.abs((pedHeading - vehHeading + 180) % 360 - 180)
	if ( differenceHeading > cfg.maxAngle and differenceHeading < (180 - cfg.maxAngle) ) then
		allowable =  false
	end
	
	if ( differenceHeading > 135 ) then
		towards = true
	end
	return allowable, towards
end

local rightAxisX, rightAxisY, rotation, newX, newZ
--	AIM DOWNSIGHTS PAN
function CheckInputRotation(cam, zoomvalue)
	rightAxisX = GetDisabledControlNormal(0, 220)
	rightAxisY = GetDisabledControlNormal(0, 221)
	rotation = GetCamRot(cam, 2)
	if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
		newZ = rotation.z + rightAxisX*-1.0*(cfg.verticalPanSpeed-zoomvalue*8)
		newX = math.max(math.min(40.0, rotation.x + rightAxisY*-1.0*(cfg.horizontalPanSpeed-zoomvalue*8)), -89.5) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
		SetCamRot(cam, newX, 0.0, newZ, 2)
		SetGameplayCamRelativeRotation(0.0, newX, newZ)
	end
end

--	AIM DOWNSIGHTS ZOOM
local currentLidarFOV
function HandleZoom(cam)
	if  IsDisabledControlPressed(0,15) then -- Scrollup
		lidarFOV = math.max(lidarFOV - cfg.zoomSpeed, cfg.maxFOV)
	end
	if  IsDisabledControlPressed(0,334) then
		lidarFOV = math.min(lidarFOV + cfg.zoomSpeed/6, cfg.minFOV) -- ScrollDown
	end
	currentLidarFOV = GetCamFov(cam)
	if math.abs(lidarFOV-currentLidarFOV) < 0.1 then -- the difference is too small, just set the value directly to avoid unneeded updates to FOV of order 10^-5
		lidarFOV = currentLidarFOV
	end
	SetCamFov(cam, currentLidarFOV + (lidarFOV - currentLidarFOV)*0.03) -- Smoothing of camera zoom
end

