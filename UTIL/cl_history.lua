local SPEED_LIMITS_RAW = LoadResourceFile(GetCurrentResourceName(), "/speedlimits.json")
local speedLimits = json.decode(SPEED_LIMITS_RAW)

HIST = { }
HIST.history = { }
HIST.loggedHistory = { }

local cfg = cfg
local savePrefix = 'prolaser4_'
local pendingChanges = false
local selfTestTimestamp = nil
local waitingForServer = false
local lastLoggedTarget

-- local function forward declarations
local GetTimeString, PadTime, CorrectHour
--	[[COMMANDS]]
-- CLEAR SAVED DATA / KVPS
RegisterCommand('lidarwipe', function(source, args)
	DeleteResourceKvp(savePrefix .. 'history')
	HUD:ShowNotification("~g~Success~s~: wiped local save data. Please restart for changes to take effect.")
	HUD:ResizeOnScreenDisplay(true)
end)
TriggerEvent('chat:addSuggestion', '/lidarwipe', 'Deletes all local save data including local history, lidar position and scale.')

if cfg.logging then
-- MANUAL SAVE COMMAND
	RegisterCommand('lidarupload', function(source, args)
		lastLoggedTarget = nil
		TriggerServerEvent('prolaser4:SendLogData', HIST.loggedHistory)
		HIST.loggedHistory = { }
	end)
	TriggerEvent('chat:addSuggestion', '/lidarupload', 'Manually upload lidar event data to server. (debugging purposes)')

	--	RECORDS INTERFACE
	RegisterCommand('lidarrecords', function(source, args)
		waitingForServer = true
		TriggerServerEvent('prolaser4:GetLogData')
		Wait(5000)
		if waitingForServer then
			HUD:ShowNotification("~r~Error~s~: Database timed out, check server console.")
			TriggerServerEvent('prolaser4:DatabaseTimeout')
		end
	end)
	TriggerEvent('chat:addSuggestion', '/lidarrecords', 'Review lidar records.')

	--	[[EVENTS]]
	RegisterNetEvent("prolaser4:ReturnLogData")
	AddEventHandler("prolaser4:ReturnLogData", function(databaseData)
		waitingForServer = false
		HUD:SendDatabaseRecords(databaseData)
		HUD:SetTabletState(true)
	end)
end

--	[[THREADS]]
--	SAVE/LOAD HISTORY THREAD: saves history if it's been changed every 5 minutes.
CreateThread(function()
	Wait(1000)
	-- load save history
	local historySaveData = GetResourceKvpString(savePrefix..'history')
	if historySaveData ~= nil then
		HIST.history = json.decode(historySaveData)
	end
	
	-- save pending changes to kvp
	while true do
		Wait(60000)
		if pendingChanges then
			-- as the data is being pushed, we don't want to attempt to update loggedData since it's being uploaded and emptied
			lastLoggedTarget = nil
			SetResourceKvp(savePrefix .. 'history', json.encode(HIST.history))
			
			if cfg.logging and #HIST.loggedHistory > 0 then
				TriggerServerEvent('prolaser4:SendLogData', HIST.loggedHistory)
				HIST.loggedHistory = { }
			end
			pendingChanges = false
		end
	end
end)

--	[[FUNCTION]]
--	STORE LAST 100 CLOCKS IN DATA TABLE TO SEND TO NUI FOR DISPLAY
function HIST:StoreLidarData(target, speed, range, towards)
	-- format clock data
	local clockString = string.format("%03.0f mph %03.1f ft", speed, range)
	if towards then
		clockString = '-'..clockString
	else
		clockString = '+'..clockString
	end
	
	-- check is this the same target we just clocked if so update clock time and return
	if self.history[1] ~= nil and self.history[1].target == target then
		-- if new record is of higher speed, update to the new speed
		if self.history[1].speed < speed then
			self.history[1].clock = clockString
			self.history[1].time = GetTimeString()
		end
	else
		-- different vehicle, store data in table and add
		local data = { 	target = target, 
						speed = speed,
						time = GetTimeString(),
						clock = clockString,
					}
		-- clear old history items FIFO (first-in-first-out)
		while #self.history > 99 do
			table.remove(self.history, 100)
		end
		table.insert(self.history, 1, data)
	end
	
	-- logging data
	if cfg.logging then
		if not cfg.loggingPlayersOnly or IsPedAPlayer(GetPedInVehicleSeat(target, -1)) then
			if lastLoggedTarget ~= target then
				local loggedData = { }
				loggedData['speed'] = speed
				loggedData['range'] = string.format("%03.1f", range)
				loggedData['time'] = GetTimeString()
				local targetPos = GetEntityCoords(target)
				loggedData['targetX'] = targetPos.x
				loggedData['targetY'] = targetPos.y
				loggedData['selfTestTimestamp'] = selfTestTimestamp

				local streetHash1, streetHash2 = GetStreetNameAtCoord(targetPos.x, targetPos.y, targetPos.z, Citizen.ResultAsInteger(), Citizen.ResultAsInteger())
				local streetName1 = GetStreetNameFromHashKey(streetHash1)
				local streetName2 = GetStreetNameFromHashKey(streetHash2)
				if not cfg.loggingOnlySpeeders or speed > speedLimits[streetName1] then
					if streetName2 == "" then
						loggedData['street'] = streetName1
					else
						loggedData['street'] = string.format("%s / %s", streetName1, streetName2)
					end
					lastLoggedTarget = target
					table.insert(self.loggedHistory, 1, loggedData)
					pendingChanges = true
				end
			else
				-- Update pending data to reflect higher clock.
				local loggedData = self.loggedHistory[1]
				if loggedData ~= nil and loggedData['speed'] ~= nil then
                    if speed > loggedData['speed'] then
                        loggedData['speed'] = speed
                        loggedData['range'] = string.format("%03.1f", range)
                        loggedData['time'] = GetTimeString()
                        local targetPos = GetEntityCoords(target)
                        loggedData['targetX'] = targetPos.x
                        loggedData['targetY'] = targetPos.y
                        loggedData['selfTestTimestamp'] = selfTestTimestamp

                        local streetHash1, streetHash2 = GetStreetNameAtCoord(targetPos.x, targetPos.y, targetPos.z, Citizen.ResultAsInteger(), Citizen.ResultAsInteger())
                        local streetName1 = GetStreetNameFromHashKey(streetHash1)
                        local streetName2 = GetStreetNameFromHashKey(streetHash2)
                        if streetName2 == "" then
                            loggedData['street'] = streetName1
                        else
                            loggedData['street'] = string.format("%s / %s", streetName1, streetName2)
                        end
				   end
				end
			end
		end
	end
end

-- [[ GLOBAL FUNCTIONS ]]
--	HUD->HIST store self-test datetime for SQL
function HIST:SetSelfTestTimestamp()
	selfTestTimestamp = GetTimeString()
end

--	HIST->HUD return KVP theme save int/enum
function HIST:GetTabletTheme()
	return GetResourceKvpInt(savePrefix..'tablet_theme')
end

--	HUD->HIST send NUI theme back to HIST for storage
function HIST:SaveTabletTheme(theme)
	SetResourceKvpInt(savePrefix .. 'tablet_theme', theme)
end

--	HUD->HIST send NUI OSD style back to HIST for storage
function HIST:SaveOsdStyle(data)
	SetResourceKvp(savePrefix .. 'osd_style', json.encode(data))
end

--	HIST->HUD return KVP for OSD style
function HIST:GetOsdStyle()
	local osdStyle = GetResourceKvpString(savePrefix..'osd_style')
	if osdStyle ~= nil then
		return GetResourceKvpString(savePrefix..'osd_style')
	end
	return false
end

-- [[ LOCAL FUNCTIONS ]]
-- 	Gets formatted zulu time 
GetTimeString = function()
	local year, month, day, hour, minute, second = GetPosixTime()
	-- for some reason PosixTime returns 1 hour ahead of correct time
	hour 	= CorrectHour(hour)
	-- pad time with leading zero if needed
	month 	= PadTime(month)
	day 	= PadTime(day)
	hour 	= PadTime(hour)
	minute 	= PadTime(minute)
	second 	= PadTime(second)
	return string.format("%s/%s/%s %s:%s:%s", month, day, year, hour, minute, second)
end

PadTime = function(time)
	if time < 10 then
		time = "0" .. time
	end
	return time
end

CorrectHour = function(hour)
	hour = hour - 1
	if hour < 1 then 
		hour = 23
	elseif hour > 23 then
		hour = 1
	end
	return hour
end
