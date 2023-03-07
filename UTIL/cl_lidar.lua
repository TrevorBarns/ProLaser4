selfTestState = not cfg.performSelfTest

holdingLidarGun = false
local beingShownLidarGun = false

local cfg = cfg
local lidarGunHash = GetHashKey(cfg.lidarGunHash)
local selfTestInProgress = false
local tempHidden = false
local shown = false
local hudMode = false
local isAiming = false
local inFirstPersonPed = true
local fpAimDownSight = false
local tpAimDownSight = false
local ped, target
local targetHeading, pedHeading, towards
local velocity, range, adjacentDistance, laneOffsetDistance, distSquared, speedEstimate
local rangeAdjust = false
local speedAdjust

local lidarFOV = (cfg.minFOV+cfg.maxFOV)*0.5
local currentLidarFOV
local cam, weap, zoomvalue
local rightAxisX, rightAxisY, rotation
local camInVehicle
local inVehicleDeltaCamRot

local isHistoryActive = false
local historyIndex = 0

local slowScroll = 500
local fastScroll = 50
local scrollWait = slowScroll
local scrollDirection = nil

-- local function forward declarations
local GetLidarReturn
local CheckInputRotation, HandleZoom
local PlayButtonPressBeep, PlayFastAlertBeep

--	TOGGLE LIDAR DISPLAY COMMAND
RegisterCommand('lidar', function(source, args)
	if holdingLidarGun and not hudMode then
		-- open HUD Display and self-test
		if shown == true then
			HUD:SetLidarDisplayState(false)
		else
			HUD:SetLidarDisplayState(true)
		end	
		shown = not shown
		if not selfTestState and not selfTestInProgress then
			selfTestInProgress = true
			selfTestState = HUD:DisplaySelfTest()
		end
	end
end)
RegisterKeyMapping('lidar', 'Toggle Lidar Display', 'keyboard', cfg.toggleMenu)
TriggerEvent('chat:addSuggestion', '/lidar', 'Toggle lidar display.')

--	TOGGLE LIDAR WEAPON COMMAND
RegisterCommand('lidarweapon', function(source, args)
	if HasPedGotWeapon(ped, lidarGunHash) then
		RemoveWeaponFromPed(ped, lidarGunHash)
	else
		GiveWeaponToPed(ped, lidarGunHash, 0, false, false)
	end
end)
TriggerEvent('chat:addSuggestion', '/lidarweapon', 'Equip / Remove lidar weapon.')

--	SHOW LIDAR TO NEAREST PLAYER COMMAND
RegisterCommand('lidarshow', function(source, args)
	if holdingLidarGun and shown then
		local players = GetActivePlayers()
		local closestDistance = -1
		local closestPlayer = -1
		local playerPed = PlayerPedId()
		local playerCoords = GetEntityCoords(playerPed)

		for i=1,#players do
			local targetPed = GetPlayerPed(players[i])
			if targetPed ~= playerPed then
				local targetCoords = GetEntityCoords(targetPed)
				local distance = #(playerCoords - targetCoords)
				if distance <= 3 and (closestDistance == -1 or distance < closestDistance) then
					closestPlayer = players[i]
					closestDistance = distance
				end
			end
		end
		
		if closestPlayer ~= -1 then
			HUD:GetCurrentDisplayData(GetPlayerServerId(closestPlayer))
		end
	end
end)
TriggerEvent('chat:addSuggestion', '/lidarshow', 'Show lidar display to nearest player for 5 seconds.')

RegisterNetEvent("prolaser4:ReturnDisplayData")
AddEventHandler("prolaser4:ReturnDisplayData", function(displayData)
	if not beingShownLidarGun and not shown then
		beingShownLidarGun = true
		HUD:SetSelfTestState(true)
		if (displayData.onHistory) then
			HUD:SetHistoryState(true)
			HUD:SetHistoryData(displayData.counter, { time = displayData.time, clock = displayData.clock } )
		else
			HUD:SetHistoryState(false)
			HUD:SendPeersDisplayData(displayData)
		end
		Wait(500)
		HUD:SetLidarDisplayState(true)
		
		local timer = GetGameTimer() + 5000
		while GetGameTimer() < timer do
			Wait(1000)
		end
		HUD:SetLidarDisplayState(false)
		Wait(500)
		HUD:SetHistoryState(false)
		HUD:SetSelfTestState(selfTestState)
		beingShownLidarGun = false
	end
end)

--	MAIN GET VEHICLE TO CLOCKTHREAD
Citizen.CreateThread(function()
	Wait(500)
	-- initialize textures & replace weapon string name
	AddTextEntryByHash(GetHashKey("WT_VPISTOL"), "ProLaser 4")
	RequestStreamedTextureDict("w_pi_vintage_pistol")
	HUD:SetSelfTestState(selfTestState, false)
	HUD:SendBatteryPercentage()
	HUD:SendConfigData()
		
	while not HasStreamedTextureDictLoaded("w_pi_vintage_pistol") do
		Wait(100)
	end
	
	-- replace weapon wheel textures
	local txd = CreateRuntimeTxd('prolaser4')
	CreateRuntimeTextureFromImage(txd, 'weapons_dlc_bb', 'UI/weapons_dlc_bb.png')
	AddReplaceTexture('hud', 'weapons_dlc_bb', 'prolaser4', 'weapons_dlc_bb')

	while true do
		ped = PlayerPedId()
		holdingLidarGun = GetSelectedPedWeapon(ped) == lidarGunHash
		if holdingLidarGun then
			isInVehicle = IsPedInAnyVehicle(ped, true)
			isAiming = IsPlayerFreeAiming(PlayerId())
			isGtaMenuOpen = IsWarningMessageActive() or IsPauseMenuActive()
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
			HideHudComponentThisFrame(2)
			if isAiming then
				if not hudMode then
					DrawSprite("w_pi_vintage_pistol", "lidar_reticle", 0.5, 0.5, 0.005, 0.01, 0.0, 200, 200, 200, 255)
				else
					DisableControlAction(0, 26, true) 			-- INPUT_LOOK_BEHIND
				end
				-- if aiming down sight disable change weapon to enable scrolling without HUD wheel opening
				DisableControlAction(0, 99, true)				-- INPUT_VEH_SELECT_NEXT_WEAPON
				DisableControlAction(0, 16, true)				-- INPUT_SELECT_NEXT_WEAPON
				DisableControlAction(0, 17, true)				-- INPUT_SELECT_PREV_WEAPON
			end
			DisablePlayerFiring(ped, true) 						-- Disable Weapon Firing
			DisableControlAction(0, cfg.trigger, true) 			-- Disable Trigger Action
			DisableControlAction(0, cfg.previousHistory, true) 
			DisableControlAction(0, cfg.nextHistory, true) 
			DisableControlAction(0, 142, true) 					-- INPUT_MELEE_ATTACK_ALTERNATE
		end
	end
end)

-- ADS HUD Call -> JS
Citizen.CreateThread( function()
	while true do
		if holdingLidarGun or hudMode then
			inFirstPersonPed = not isInVehicle and GetFollowPedCamViewMode() == 4
			inFirstPersonVeh = isInVehicle and GetFollowVehicleCamViewMode() == 4
			if not hudMode and fpAimDownSight and (inFirstPersonPed or inFirstPersonVeh) then
				if not shown then
					shown = true
					if not selfTestState and not selfTestInProgress then
						selfTestInProgress = true
						HUD:DisplaySelfTest()
					end			
				end
				hudMode = true
				HUD:SetDisplayMode('ADS')
				DisplayRadar(false)
			elseif shown and hudMode and not (fpAimDownSight and (inFirstPersonPed or inFirstPersonVeh)) then
				hudMode = false
				HUD:SetDisplayMode('DISPLAY')
				DisplayRadar(true)
			end
			Wait(100)
		else
			Wait(500)
		end
	end
end)

--LIDAR MAIN THREAD: handle hiding lidar NUI, self-test, ADS aiming, clocking, and control handling.
Citizen.CreateThread( function()
	while true do
		Citizen.Wait(1)
		-- Hide HUD if weapon not selected, keep lidar on
		if ( ( not holdingLidarGun and not beingShownLidarGun ) or isGtaMenuOpen) and shown and not tempHidden then
			HUD:SetDisplayMode('DISPLAY')
			hudMode = false
			HUD:SetLidarDisplayState(false)
			tempHidden = true
		elseif holdingLidarGun and not isGtaMenuOpen and tempHidden then
			HUD:SetLidarDisplayState(true)
			tempHidden = false
		end

		if holdingLidarGun then
			-- toggle ADS if first person and aim, otherwise unADS
			if not fpAimDownSight and IsControlJustPressed(0,25) and (inFirstPersonPed or inFirstPersonVeh) then
				fpAimDownSight = true
				SetPlayerForcedAim(PlayerId(), true)
			elseif fpAimDownSight and (IsControlJustPressed(0,177) or IsControlJustPressed(0,25) or IsControlJustPressed(0, 0) or not (inFirstPersonPed or inFirstPersonVeh)) then
				fpAimDownSight = false
				SetPlayerForcedAim(PlayerId(), false)
				-- Simulate control just released, if still holding right click disable the control till they unclick to prevent retoggling accidently
				while IsControlJustPressed(0,25) or IsDisabledControlPressed(0,25) or IsControlPressed(0,177) or IsDisabledControlPressed(0,177) do
					DisableControlAction(0, 25, true)		-- INPUT_AIM
					DisableControlAction(0, 177, true)		-- INPUT_CELLPHONE_CANCEL
					DisableControlAction(0, 68, true)		-- INPUT_VEH_AIM
					Wait(1)
				end
				Wait(100)
			elseif not fpAimDownSight and (inFirstPersonPed or inFirstPersonVeh) and isAiming then
				fpAimDownSight = true
				SetPlayerForcedAim(PlayerId(), true)
			end	
			
			-- toggle ADS if in third person and aim, otherwide unaim
			if not (inFirstPersonPed or inFirstPersonVeh) then
				if not tpAimDownSight and IsControlJustPressed(0,25) then
					tpAimDownSight = true
					SetPlayerForcedAim(PlayerId(), true)
				elseif tpAimDownSight and (IsControlJustPressed(0,177) or IsControlJustPressed(0,25) or IsControlJustPressed(0, 0)) then
					tpAimDownSight = false
					SetPlayerForcedAim(PlayerId(), false)
					-- Simulate control just released, if still holding right click disable the control till they unclick to prevent retoggling accidently
					while IsControlJustPressed(0,25) or IsDisabledControlPressed(0,25) or IsControlPressed(0,177) or IsDisabledControlPressed(0,177) do
						DisableControlAction(0, 25, true)		-- INPUT_AIM
						DisableControlAction(0, 177, true)		-- INPUT_CELLPHONE_CANCEL
						DisableControlAction(0, 68, true)		-- INPUT_VEH_AIM
						Wait(1)
					end
				end
			end
			--	Get target speed and update display
			if shown and not tempHidden and selfTestState then
				if IsDisabledControlPressed(1, cfg.trigger) and not isHistoryActive and isAiming and not (tpAimDownSight and (GetGameplayCamRelativeHeading() < -131 or GetGameplayCamRelativeHeading() > 178)) then 
					found, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
					if IsPedInAnyVehicle(target) then
						target = GetVehiclePedIsIn(target, false)
					end
					speed, range, towards = GetLidarReturn(target, ped)
					if towards ~= -1 then
						HUD:SendLidarUpdate(speed, string.format("%.1f", range), towards)
						HIST:StoreLidarData(target, speed, range, towards)
					else
						HUD:ClearLidarDisplay()
					end
					Wait(250)
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
				elseif IsDisabledControlJustReleased(0, cfg.changeSight) and fpAimDownSight then
					HUD:ChangeSightStyle()
				end
			end
		else
			Wait(500)
		end
	end
end)

-- SCROLL SPEED: handles fast scrolling, if holding scroll increase scroll speed.
CreateThread(function()
	Wait(1000)
	while true do
		if holdingLidarGun and isHistoryActive then
			if IsDisabledControlPressed(0, cfg.nextHistory) then
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
			elseif IsDisabledControlPressed(0, cfg.previousHistory) then
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
			end
		else
			Wait(500)
		end
		Wait(0)
	end
end)

-- AIM DOWNSIGHTS CAM & ZOOM
CreateThread(function()
	while true do
		if holdingLidarGun then
			if fpAimDownSight then
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

				while fpAimDownSight and not IsEntityDead(ped) do	
					if ((camInVehicle and not isInVehicle) or (not camInVehicle and isInVehicle)) or not holdingLidarGun then
						fpAimDownSight = false
						SetPlayerForcedAim(PlayerId(), false)
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
--	COSINE ERROR CALULCATIONS AND TOWARDS/AWAY STATE
--	SEE: https://copradar.com/chapts/chapt2/ch2d1.html
GetLidarReturn = function(target, ped)
	targetHeading = GetEntityHeading(target)
	towards = false
	speedAdjust = 0.0
	if target == 0 then
		return 0, 0, -1
	end
	
	-- Get correct heading based on vehicle / hud sight
	if isInVehicle and fpAimDownSight then
		pedHeading = GetCamRot(cam, 2)[3]
	else
		pedHeading = GetEntityHeading(ped) + GetGameplayCamRelativeHeading()
	end
	
	local diffHeading = math.abs(pedHeading - targetHeading) % 180
	if ( diffHeading > 135 ) then
		towards = true
	end

	-- If the difference in heading is greater than 90 degrees, subtract it from 180 to get the angle regardless of direction
	if diffHeading > 90 then
	  diffHeading = 180 - diffHeading
	end	
	
	range  = GetDistanceBetweenCoords(GetEntityCoords(ped),GetEntityCoords(target), true)*3.2808399
	diffHeadingRadians = math.rad(diffHeading)
	velocity = GetEntitySpeed(target)*2.236936

	-- If diff abs heading > 45 degress zero out invalid angle
	if diffHeading > 15 then
		speedAdjust = 1 - (diffHeading / 100)
		rangeAdjust = not rangeAdjust
		if rangeAdjust then
			range = range - math.random(1,math.floor(range))
		end
	end
	
	if velocity > 0 then
		adjacentDistance = range * math.cos(diffHeadingRadians)
		laneOffsetDistance = range * math.sin(diffHeadingRadians)
		distSquared = adjacentDistance^2 + laneOffsetDistance^2
		speedEstimate = math.abs(math.floor(velocity * (adjacentDistance / math.sqrt(distSquared))-speedAdjust))
	elseif range > 1800 then
		return 0, 0, -1
	end
	
	return speedEstimate, range, towards
end

--	AIM DOWNSIGHTS PAN
CheckInputRotation = function(cam, zoomvalue)
	rightAxisX = GetDisabledControlNormal(0, 220)
	rightAxisY = GetDisabledControlNormal(0, 221)
	rotation = GetCamRot(cam, 2)
	if rightAxisX ~= 0.0 or rightAxisY ~= 0.0 then
		if isInVehicle then
			newZ = rotation.z + rightAxisX*-1.0*(cfg.verticalPanSpeed-zoomvalue*8) 
			newX = math.max(math.min(20.0, rotation.x + rightAxisY*-1.0*(cfg.horizontalPanSpeed-zoomvalue*8)), -20.0) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
			SetCamRot(cam, newX, 0.0, newZ, 2)
			SetGameplayCamRelativeRotation(0.0, 0.0, 0.0)
			-- limit ADS rotation while in vehicle
			inVehicleDeltaCamRot = (GetCamRot(cam, 2)[3] - GetEntityHeading(ped) + 180) % 360 - 180
			while inVehicleDeltaCamRot < -75 and inVehicleDeltaCamRot > -130 do
				newZ = newZ + 0.2
				SetCamRot(cam, newX, 0.0, newZ, 2)
				inVehicleDeltaCamRot = (GetCamRot(cam, 2)[3] - GetEntityHeading(ped) + 180) % 360 - 180
				Wait(1)
			end			
			while inVehicleDeltaCamRot > 178 or (inVehicleDeltaCamRot > -180 and inVehicleDeltaCamRot < -130) do
				newZ = newZ - 0.2
				SetCamRot(cam, newX, 0.0, newZ, 2)
				inVehicleDeltaCamRot = (GetCamRot(cam, 2)[3] - GetEntityHeading(ped) + 180) % 360 - 180
				Wait(1)
			end
		else
			newZ = rotation.z + rightAxisX*-1.0*(cfg.verticalPanSpeed-zoomvalue*8)
			newX = math.max(math.min(40.0, rotation.x + rightAxisY*-1.0*(cfg.horizontalPanSpeed-zoomvalue*8)), -89.5) -- Clamping at top (cant see top of heli) and at bottom (doesn't glitch out in -90deg)
			SetCamRot(cam, newX, 0.0, newZ, 2)
			SetGameplayCamRelativeRotation(0.0, newX, newZ)
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
	currentLidarFOV = GetCamFov(cam)
	if math.abs(lidarFOV-currentLidarFOV) < 0.1 then -- the difference is too small, just set the value directly to avoid unneeded updates to FOV of order 10^-5
		lidarFOV = currentLidarFOV
	end
	SetCamFov(cam, currentLidarFOV + (lidarFOV - currentLidarFOV)*0.03) -- Smoothing of camera zoom
end

--	Play NUI front in audio.
PlayButtonPressBeep = function()
	SendNUIMessage({
	  action  = 'PlayButtonPressBeep',
	  file   = 'LidarBeep',
	})
end

