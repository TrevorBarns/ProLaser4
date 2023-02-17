HIST = { }
HIST.history = { }

local savePrefix = 'prolaser4_'
local pendingChanges = false

-- local function forward declarations
local GetTimeString, PadTime, CorrectHour

-- CLEAR SAVED DATA / KVPS
RegisterCommand('lidarwipe', function(source, args)
	DeleteResourceKvp(savePrefix .. 'history')
end)
TriggerEvent('chat:addSuggestion', '/lidarwipe', 'Deletes history data.')


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
		Wait(300000)
		if pendingChanges then
			SetResourceKvp(savePrefix .. 'history', json.encode(HIST.history))
			pendingChanges = false
		end
	end
end)

--	STORE LAST 100 CLOCKS IN DATA TABLE TO SEND TO NUI FOR DISPLAY
function HIST:StoreLidarData(target, speed, range, towards)
	-- format clock data
	local clockString = string.format("%03d mph %03.1f ft", speed, range)
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
		return
	end
	
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
	pendingChanges = true
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
