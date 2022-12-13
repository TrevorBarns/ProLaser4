local hasJammer = false
JAM = {}
JAMMERS = {}
lastLasedVeh = nil
lastVeh = nil
local beingLased = false
local cooldown = false
local cooldownTimer = 0

--	Toggling Lidar
TriggerEvent('chat:addSuggestion', '/'..cfg.enableCommand, 'Toggle laser jammer for this vehicle.')
RegisterCommand(cfg.enableCommand, function()
	if isInVehicle then
		if GetVehicleClass(veh) < 13 or GetVehicleClass(veh) > 16 then
			hasJammer = not hasJammer
			HUD:SetJammerDisplayState(hasJammer)
			TriggerServerEvent('Jammer:Vehicle', NetworkGetNetworkIdFromEntity(veh), veh, hasJammer)
		end
	end
end)

--	Ped & Vehicle; Remove laserJammer on vehicle change
CreateThread(function()
	while true do
		ped = PlayerPedId()
		isInVehicle = IsPedInAnyVehicle(ped)
		if isInVehicle then
			veh = GetVehiclePedIsIn(ped)
			if lastVeh ~= veh then
				hasJammer = false
				HUD:SetJammerDisplayState(hasJammer)
				TriggerServerEvent('Jammer:Vehicle', NetworkGetNetworkIdFromEntity(veh), veh, hasJammer)
				lastVeh = veh
			end
		end
		Wait(1000)
	end
end)

--	Update jammer table for lidar use
RegisterNetEvent('Jammer:UpdateVehicles')
AddEventHandler('Jammer:UpdateVehicles', function(jammers)
	JAMMERS = jammers
end)

--	C->S->C Is currently being lased
RegisterNetEvent('Jammer:NotifyLase')
AddEventHandler('Jammer:NotifyLase', function(state)
	beingLased = state
end)

--	Return Jamming state, releases old vehicles
function JAM:IsVehJamming(veh)
	local netVeh = NetworkGetNetworkIdFromEntity(veh)
	if JAMMERS[netVeh] ~= nil then
		if netVeh ~= lastLasedVeh then
			TriggerServerEvent('Jammer:Lasing', lastLasedVeh, false)
			TriggerServerEvent('Jammer:Lasing', netVeh, true)
			lastLasedVeh = netVeh
		end
		return JAMMERS[netVeh].Jamming 
	end
	return false
end

--	Lidar Interface Updates & Jamming Cooldown
CreateThread(function()
	while true do
		if hasJammer then
			if not cooldown then
				if beingLased then
					HUD:SetJammerMode('red')
					cooldownTimer = cooldownTimer + 200
					if cooldownTimer > 3000 then
						HUD:SetJammerMode('green')
						cooldown = true
					else
						Wait(100)
					end
				else
					HUD:SetJammerMode('idle')
				end
			else
				TriggerServerEvent('Jammer:SetJamming', NetworkGetNetworkIdFromEntity(veh), false)
				while cooldownTimer > 0 do
					Wait(100)
					cooldownTimer = cooldownTimer -100
				end
				while beingLased do
					Wait(100)
				end
				Wait(cfg.cooldownTime*1000)
				TriggerServerEvent('Jammer:SetJamming', NetworkGetNetworkIdFromEntity(veh), true)
				cooldownTimer = 0
				cooldown = false
				HUD:SetJammerMode('idle')
			end
		else
			Wait(1000)
		end
		Wait(1)
	end
end)

--	Reset cooldown timer if lidar not shooting
CreateThread(function()
	while true do
		if hasJammer then
			if cooldownTimer > 0 then
				local checkTimer = cooldownTimer + 0.0
				Wait(500)
				if ( cooldownTimer - checkTimer == 0 )then
					cooldownTimer = 0
				end
			end
		else
			Wait(1000)
		end
		Wait(500)
	end
end)

--	Remove Non-existant Vehicles
CreateThread(function()
	while true do
		for netId, states in pairs(JAMMERS) do
			if not DoesEntityExist(NetToVeh(netId)) then
				TriggerServerEvent('Jammer:RemoveVehicle', NetworkGetNetworkIdFromEntity(veh))
			end
		end
		Wait(30000)
	end
end)

