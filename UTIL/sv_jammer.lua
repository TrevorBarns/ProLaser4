local JAMMERS = {}
--[NETID] = { Enabled = boolean, Jamming = boolean }

RegisterServerEvent('Jammer:Vehicle')
AddEventHandler('Jammer:Vehicle', function(netID, veh, state)
	print(netID, veh, state)
	JAMMERS[netID] = { ServerHandle = veh, Enabled = state, Jamming = state, Driver = source }
	TriggerClientEvent('Jammer:UpdateVehicles', -1, JAMMERS)
	print('sending vehicles')
end)

RegisterServerEvent('Jammer:SetJamming')
AddEventHandler('Jammer:SetJamming', function(netID, state)
	print('SetJamming', state, json.encode(JAMMERS))
	JAMMERS[netID].Jamming = state
	TriggerClientEvent('Jammer:UpdateVehicles', -1, JAMMERS)
end)

RegisterServerEvent('Jammer:Lasing')
AddEventHandler('Jammer:Lasing', function(netID, state)
	if JAMMERS[netID] ~= nil then
		TriggerClientEvent('Jammer:NotifyLase', JAMMERS[netID].Driver, state)
	end
end)

RegisterServerEvent('Jammer:RemoveVehicle')
AddEventHandler('Jammer:RemoveVehicle', function(netID)
	if JAMMERS[netID] ~= nil then
		JAMMERS[netID] = nil
	end
end)
