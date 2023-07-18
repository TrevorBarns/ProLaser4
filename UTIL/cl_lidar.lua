selfTestState = not cfg.performSelfTest

holdingLidarGun = false
local cfg = cfg
local lidarGunHash = GetHashKey(cfg.lidarGunHash)
local selfTestInProgress = false
local tempHidden = false
local shown = false
local hudMode = false
local isAiming = false
local isUsingKeyboard = false
local inFirstPersonPed = true
local fpAimDownSight = false
local tpAimDownSight = false
local ped, target
local playerId = PlayerId()
local targetHeading, pedHeading, towards
local lastTarget, lastDistance, lastTime
local beingShownLidarGun = false
local mainThreadRunning = true

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

local rangeScalar, velocityScalar
-- Metric vs Imperial
if cfg.useMetric then
	rangeScalar = 1.0
	velocityScalar = 3.6
else
	rangeScalar = 3.28084
	velocityScalar = 2.236936
end

-- local function forward declarations
local GetLidarReturn
local CheckInputRotation, HandleZoom
local PlayButtonPressBeep
local IsTriggerControlPressed, IsFpsAimControlPressed, IsFpsUnaimControlPressed, IsTpAimControlPressed, IsTpUnaimControlPressed

-- lidar jamming from sonoran [plate] = state.
local jammedList = { }

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
		local playerCoords = GetEntityCoords(ped)

		for i=1,#players do
			local targetPed = GetPlayerPed(players[i])
			if targetPed ~= ped then
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

--	RESIZE / MOVE OSD
RegisterCommand('lidarmove', function(source, args)
	if holdingLidarGun and shown and not hudMode then
		if args[1] ~= nil and string.upper(args[1]) == 'TRUE' then
			HUD:ResizeOnScreenDisplay(true)
			HUD:ShowNotification("~g~Success~s~: ProLaser4 OSD position and scale reset.")
		else
			HUD:ResizeOnScreenDisplay()
			HUD:DisplayControlHint('moveOSD')
		end
	end
end)
TriggerEvent('chat:addSuggestion', '/lidarmove', 'Move and resize Lidar OSD.', { { name = "reset (opt.)", help = "Optional: resets position and scale of OSD <true/false>." } } );

--Crash recovery command
RegisterCommand('lidarrecovercrash', function()
	if not mainThreadRunning then
		local timer = 3000
		local blocked = false
		CreateThread(function()
			while timer > 0 do
				timer = timer - 1
				if mainThreadRunning then
					blocked = true
				end
				Wait(1)
			end
		end)
		
		if not blocked then
			print("^3ProLaser4 Development Log: attempting to recover from a crash... This may not work. Please make a bug report with log file.")
			HUD:ShowNotification("~r~ProLaser4~w~: ~y~please make a bug report with log file~w~.")
			HUD:ShowNotification("~r~ProLaser4~w~: attempting to recover from a crash...")
			CreateThread(MainThread)
			return
		end
	end
	print("^3ProLaser4 Development: unable to recover, appears to be running. ~y~Please make a bug report with log file~w~.")
	HUD:ShowNotification("~r~ProLaser4~w~: unable to recover, running. ~y~Please make a bug report with log file~w~.")
end)
TriggerEvent('chat:addSuggestion', '/lidarrecovercrash', 'Attempts to recover ProLaser4 after the resource crashed.')

-- /lidarshow event - show lidar display to nearby player.
RegisterNetEvent("prolaser4:ReturnDisplayData")
AddEventHandler("prolaser4:ReturnDisplayData", function(displayData)
	if not shown then
		beingShownLidarGun = false
		
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
		
		beingShownLidarGun = true
		local timer = GetGameTimer() + 8000
		while GetGameTimer() < timer do
			-- if displayed again, do not hide return and use new event thread
			if not beingShownLidarGun then
				return
			end
			Wait(250)
		end
		
		HUD:SetLidarDisplayState(false)
		Wait(500)
		HUD:SetHistoryState(false)
		HUD:SetSelfTestState(selfTestState)
	end
end)

--	MAIN GET VEHICLE TO CLOCKTHREAD & START UP
CreateThread(function()
	CreateThread(MainThread)
	Wait(2000)
	-- Initalize lidar state and vars LUA->JS
	HUD:SetSelfTestState(selfTestState, false)
	HUD:SendBatteryPercentage()
	HUD:SendConfigData()

	-- Texture load check & label replacement.
	AddTextEntry(cfg.lidarNameHashString, "ProLaser 4")
	RequestStreamedTextureDict(cfg.lidarGunTextureDict)
	while not HasStreamedTextureDictLoaded(cfg.lidarGunTextureDict) do
		Wait(100)
	end

	while true do
		ped = PlayerPedId()
		holdingLidarGun = GetSelectedPedWeapon(ped) == lidarGunHash
		if holdingLidarGun then
			isInVehicle = IsPedInAnyVehicle(ped, true)
			isAiming = IsPlayerFreeAiming(playerId)
			isGtaMenuOpen = IsWarningMessageActive() or IsPauseMenuActive()
			Wait(100)		
		else
			Wait(500)
		end

	end
end)

-- REMOVE CONTROLS & HUD MESSAGE
CreateThread( function()
	while true do
		Wait(1)
		if holdingLidarGun then
			HideHudComponentThisFrame(2)
			if isAiming then
				if not hudMode then
					DrawSprite(cfg.lidarGunTextureDict, "lidar_reticle", 0.5, 0.5, 0.005, 0.01, 0.0, 200, 200, 200, 255)
				else
					DisableControlAction(0, 26, true) 			-- INPUT_LOOK_BEHIND
				end
				-- if aiming down sight disable change weapon to enable scrolling without HUD wheel opening
				DisableControlAction(0, 99, true)				-- INPUT_VEH_SELECT_NEXT_WEAPON
				DisableControlAction(0, 16, true)				-- INPUT_SELECT_NEXT_WEAPON
				DisableControlAction(0, 17, true)				-- INPUT_SELECT_PREV_WEAPON
			end
			DisablePlayerFiring(ped, true) 						-- Disable Weapon Firing
			DisableControlAction(0, 24, true) 					-- Disable Trigger Action
			DisableControlAction(0, cfg.previousHistory, true) 
			DisableControlAction(0, cfg.nextHistory, true) 
			DisableControlAction(0, 142, true) 					-- INPUT_MELEE_ATTACK_ALTERNATE
		end
	end
end)

-- ADS HUD Call -> JS
CreateThread( function()
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
function MainThread()
	while true do		
		--	Crash recovery variable, resets to true at end of loop.
		mainThreadRunning = false
		Wait(1)
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
			isUsingKeyboard = IsUsingKeyboard(0)
			-- toggle ADS if first person and aim, otherwise unADS
			if IsFpsAimControlPressed() then
				fpAimDownSight = true
				SetPlayerForcedAim(playerId, true)
			elseif IsFpsUnaimControlPressed() then
				fpAimDownSight = false
				SetPlayerForcedAim(playerId, false)
				-- Simulate control just released, if still holding right click disable the control till they unclick to prevent retoggling accidently
				while IsControlJustPressed(0,25) or IsDisabledControlPressed(0,25) or IsControlPressed(0,177) or IsDisabledControlPressed(0,177) or IsControlJustPressed(0,68) or IsDisabledControlPressed(0,68) do
					DisableControlAction(0, 25, true)		-- INPUT_AIM
					DisableControlAction(0, 177, true)		-- INPUT_CELLPHONE_CANCEL
					DisableControlAction(0, 68, true)		-- INPUT_VEH_AIM
					Wait(1)
				end
				Wait(100)
			elseif not fpAimDownSight and (inFirstPersonPed or inFirstPersonVeh) and isAiming then
				fpAimDownSight = true
				SetPlayerForcedAim(playerId, true)
			end	
			
			-- toggle ADS if in third person and aim, otherwide unaim
			if not (inFirstPersonPed or inFirstPersonVeh) then
				if IsTpAimControlPressed() then
					tpAimDownSight = true
					SetPlayerForcedAim(playerId, true)
				elseif IsTpUnaimControlPressed() then
					tpAimDownSight = false
					SetPlayerForcedAim(playerId, false)
					-- Simulate control just released, if still holding right click disable the control till they unclick to prevent retoggling accidently
					while IsControlJustPressed(0,25) or IsDisabledControlPressed(0,25) or IsControlPressed(0,177) or IsDisabledControlPressed(0,177) or IsControlJustPressed(0,68) or IsDisabledControlPressed(0,68) do
						DisableControlAction(0, 25, true)		-- INPUT_AIM
						DisableControlAction(0, 177, true)		-- INPUT_CELLPHONE_CANCEL
						DisableControlAction(0, 68, true)		-- INPUT_VEH_AIM						
						Wait(1)
					end
				end
			end
			
			--	Get target speed and update display
			if shown and not tempHidden and selfTestState then
				if IsTriggerControlPressed() then 
					found, target = GetEntityPlayerIsFreeAimingAt(playerId)
					if IsPedInAnyVehicle(target) then
						target = GetVehiclePedIsIn(target, false)
					end
					speed, range, towards = GetLidarReturn(target, ped)
					if towards ~= -1 then
						HUD:SendLidarUpdate(speed, range, towards)
						HIST:StoreLidarData(target, speed, range, towards)
					else
						HUD:ClearLidarDisplay()
					end
					Wait(250)
				--	Hides history if on first, otherwise go to previous history
				elseif IsDisabledControlPressed(0, cfg.previousHistory) and isUsingKeyboard and #HIST.history > 0 then
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
				elseif IsDisabledControlPressed(0, cfg.nextHistory) and isUsingKeyboard and #HIST.history > 0 then
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
				elseif IsDisabledControlJustReleased(0, cfg.changeSight) and isUsingKeyboard and fpAimDownSight then
					HUD:ChangeSightStyle()
				end
			end
		-- force unaim if no longer holding lidar gun
		elseif tpAimDownSight or fpAimDownSight then
			SetPlayerForcedAim(playerId, false)
			tpAimDownSight = false
			fpAimDownSight = false
		else
			Wait(500)
		end
		-- Crash detection: iteration completed successfully
		mainThreadRunning = true
	end
end

-- ADVANCED CONTROL HANDLING
--	Handles controller vs keyboard events, faster validation checking.
IsTriggerControlPressed = function()
	if not isAiming then
		return false
	end

	if isHistoryActive then
		return false
	end
	
	-- Angle Limitation
	if tpAimDownSight and (GetGameplayCamRelativeHeading() < -131 or GetGameplayCamRelativeHeading() > 178) then
		return false
	end
	
	-- INPUT_ATTACK or INPUT_VEH_HANDBRAKE (LCLICK, SPACEBAR, CONTROLLER RB)
	--	On foot, LMOUSE and Trigger																		In vehicle RB
	if (IsDisabledControlPressed(0, 24) and (not isInVehicle or isUsingKeyboard)) or (IsControlPressed(0, 76) and isInVehicle)  then
		return true
	end
	return false
end

-----------------------------------------
IsFpsAimControlPressed = function()
	if fpAimDownSight then
		return false
	end
	
	if not inFirstPersonPed or not inFirstPersonVeh then
		return false
	end
	
	-- LBUMPER OR LMOUSE IN VEHICLE
	if IsControlJustPressed(0,68) and isInVehicle then
		return true
	end
	
	-- LTRIGGER OR LMOUSE ON FOOT
	if IsControlJustPressed(0, 25) and not isInVehicle then
		return true
	end
	return false
end

-----------------------------------------
IsFpsUnaimControlPressed= function()
	if not fpAimDownSight then
		return false
	end

	if not (inFirstPersonPed or inFirstPersonVeh) then
		return true
	end
	
	-- LBUMPER OR LMOUSE IN VEHICLE
	if IsControlJustPressed(0,68) and isInVehicle then
		return true
	end
	
	-- LTRIGGER OR LMOUSE ON FOOT
	if IsControlJustPressed(0, 25) and not isInVehicle then
		return true
	end

	-- BACKSPACE, ESC, RMOUSE or V (view-change)
	if (isUsingKeyboard and (IsControlJustPressed(0,177)) or IsControlJustPressed(0, 0)) then
		return true
	end
	
	return false
end

-----------------------------------------
IsTpAimControlPressed = function()
	if tpAimDownSight then
		return false
	end
	-- LBUMPER OR LMOUSE IN VEHICLE
	if IsControlJustPressed(0,68) and isInVehicle then
		return true
	end
	
	-- LTRIGGER OR LMOUSE ON FOOT
	if IsControlJustPressed(0, 25) and not isInVehicle then
		return true
	end
	return false
end

-----------------------------------------
IsTpUnaimControlPressed = function()
	if not tpAimDownSight then
		return false
	end
	
	-- LBUMPER OR LMOUSE IN VEHICLE
	if IsControlJustPressed(0,68) and isInVehicle then
		return true
	end
	
	-- LTRIGGER OR LMOUSE ON FOOT
	if IsControlJustPressed(0, 25) and not isInVehicle then
		return true
	end

	-- BACKSPACE, ESC, RMOUSE or V (view-change)
	if (isUsingKeyboard and (IsControlJustPressed(0,177)) or IsControlJustPressed(0, 0)) then
		return true
	end
	
	return false
end

-----------------------------------------

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
					HUD:DisplayControlHint('fpADS')
					cfg.displayControls = false
				end

				while fpAimDownSight and not IsEntityDead(ped) do	
					if ((camInVehicle and not isInVehicle) or (not camInVehicle and isInVehicle)) or not holdingLidarGun then
						fpAimDownSight = false
						SetPlayerForcedAim(playerId, false)
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
	--	no target found
	if target == 0 then
		return 0, 0, -1
	end
	
	--	sonoran jammer
	if cfg.sonoranJammer then
		if IsEntityAVehicle(target) and next(jammedList) ~= nil then
			if jammedList[GetVehicleNumberPlateText(target)] then 
				return 0, 0, -1
			end
		end
	end

	--	towards calculations
	targetHeading = GetEntityHeading(target)
	if hudMode then
		pedHeading = GetCamRot(cam, 2)[3]
	else
		pedHeading = GetEntityHeading(ped) + GetGameplayCamRelativeHeading()
	end
	towards = false
	
	diffHeading = math.abs((pedHeading - targetHeading + 180) % 360 - 180)
	
	if ( diffHeading > 135 ) then
		towards = true
	end
	
	if diffHeading < 160 and diffHeading > 110 or
	   diffHeading > 20  and diffHeading < 70 then
		if math.random(0, 100) > 15 then
			return 0, 0, -1
		end
	end
	
	targetPos  = GetEntityCoords(target)
	distance = #(targetPos-GetEntityCoords(ped))
	if lastDistance ~= 0 and lastTarget == target then
		--	distance traveled in meters
		distanceTraveled = lastDistance - distance
		--	time between last clock and current
		timeElapsed = (lastTime - GetGameTimer()) / 1000
		--	distance over time with conversion from neters to miles.
		speedEstimate = math.abs((distanceTraveled * velocityScalar) / timeElapsed)
		--	update last values to determine next clock
		lastDistance, lastTarget, lastTime = distance, target, GetGameTimer()
	else
		lastDistance, lastTarget, lastTime = distance, target, GetGameTimer()
		return 0, 0, -1
	end
	
	return speedEstimate, distance, towards
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

--[[SONORAN RADAR / LIDAR JAMMER]]
if cfg.sonoranJammer then
	RegisterNetEvent( "Sonoran:SendJammedListToClient", function (listFromServer)
		jammedList = listFromServer
	end)
end

