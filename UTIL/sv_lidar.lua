local cfg = cfg

--	ShowLidar, repeater event to nearest player to show lidar to.
RegisterServerEvent('prolaser4:SendDisplayData')
AddEventHandler('prolaser4:SendDisplayData', function(target, data)
	TriggerClientEvent('prolaser4:ReturnDisplayData', target, data)
end)

--	Database timeout event from client->server for server console log.
RegisterServerEvent('prolaser4:DatabaseTimeout')
AddEventHandler('prolaser4:DatabaseTimeout', function()
	print(string.format('^8[ERROR]: ^3Database timed out for %s after 5 seconds. Lidar records tablet unavailable.\n\t\t1) Ensure your database is online.\n\t\t2) restart oxmysql.\n\t\t3) restart ProLaser4.^7', GetPlayerName(source)))
end)

function DebugPrint(text)
	if cfg.serverDebugging then
		print(text)
	end
end

--[[--------------- ADVANCED LOGGING --------------]]
if cfg.logging and MySQL ~= nil then
	local isInsertActive = false
	LOGGED_EVENTS = { }
	TEMP_LOGGED_EVENTS = { }
	
	---------------- QUERIES ----------------
	local insertQuery = [[
		INSERT INTO prolaser4 
			(timestamp, speed, distance, targetX, targetY, player, street, selfTestTimestamp) 
		VALUES 
			(STR_TO_DATE(?, "%m/%d/%Y %H:%i:%s"), ?, ?, ?, ?, ?, ?, STR_TO_DATE(?, "%m/%d/%Y %H:%i:%s"))
	]]
	local selectQueryRaw = [[
			SELECT 
				rid,
				DATE_FORMAT(timestamp, "%c/%d/%y %H:%i") AS timestamp, 
				speed, 
				distance as 'range',
				targetX, 
				targetY, 
				player, 
				street, 
				DATE_FORMAT(selfTestTimestamp, "%m/%d/%Y %H:%i") AS selfTestTimestamp 
			FROM prolaser4 
			ORDER BY timestamp
			LIMIT 
	]]
	local selectQuery = string.format("%s %s", selectQueryRaw, cfg.loggingSelectLimit)
	local countQuery = 'SELECT COUNT(*) FROM prolaser4'
	local cleanupQuery = 'DELETE FROM prolaser4 WHERE timestamp < DATE_SUB(NOW(), INTERVAL ? DAY);'
	-----------------------------------------
	-- Debugging Command
	RegisterCommand('lidarsqlupdate', function(source, args)
		-- check if from server console
		if source == 0 then
			DebugPrint('^3[INFO]: Manually inserting records to SQL.^7')
			InsertRecordsToSQL()
		else
			DebugPrint(string.format('^3[INFO]: Attempted to manually insert records but got source %s.^7', source))
			TriggerClientEvent('chat:addMessage', source, { args = { '^1Error', 'This command can only be executed from the console.' } })
		end
	end)
	
	-----------------------------------------
	-- Main thread, every restart remove old records if needed, insert records every X minutes as defined by cfg.loggingInsertInterval.
	CreateThread(function()
		local insertWait = cfg.loggingInsertInterval * 60000
		if cfg.loggingCleanUpInterval ~= -1 then
			CleanUpRecordsFromSQL()
		end
		while true do
			InsertRecordsToSQL()
			Wait(insertWait)
		end
	end)

	---------------- SETTER / INSERT ----------------
	--	Shared event handler colate all lidar data from all players for SQL submission.
	RegisterServerEvent('prolaser4:SendLogData')
	AddEventHandler('prolaser4:SendLogData', function(logData)
		local playerName = GetPlayerName(source)
		if not isInsertActive then
    		for i, entry in ipairs(logData) do
    			entry.player = playerName
    			table.insert(LOGGED_EVENTS, entry)
    		end
        else
			-- since the insertion is active, inserting now may result in lost data, store temporarily.
            for i, entry in ipairs(logData) do
    			entry.player = playerName
    			table.insert(TEMP_LOGGED_EVENTS, entry)
            end
	    end
	end)

	--	Inserts records to SQL table
	function InsertRecordsToSQL()
		if not isInsertActive then
			if #LOGGED_EVENTS > 0 then
				DebugPrint(string.format('^3[INFO]: Started inserting %s records.^7', #LOGGED_EVENTS))
				isInsertActive = true
				-- Execute the insert statement for each entry
				for _, entry in ipairs(LOGGED_EVENTS) do
					MySQL.insert(insertQuery, {entry.time, entry.speed, entry.range, entry.targetX, entry.targetY, entry.player, entry.street, entry.selfTestTimestamp}, function(returnData) end)
				end
				-- Remove processed records
				LOGGED_EVENTS = {}
				isInsertActive = false
				-- Copy over temp entries to be processed next run
				for _, entry in ipairs(TEMP_LOGGED_EVENTS) do
				    table.insert(LOGGED_EVENTS, entry)
				end
				-- Remove copied over values.
				TEMP_LOGGED_EVENTS = {}
				DebugPrint('^3[INFO]: Finished inserting records.^7')
			end
		end
	end
	
	---------------- GETTER / SELECT ----------------
	--	C->S request all record data
	RegisterNetEvent('prolaser4:GetLogData')
	AddEventHandler('prolaser4:GetLogData', function()
		SelectRecordsFromSQL(source)
	end)

	-- Get all record data and return to client
	function SelectRecordsFromSQL(source)
		DebugPrint(string.format('^3[INFO]: Getting records for %s.^7', GetPlayerName(source)))
		MySQL.query(selectQuery, {}, function(result)
			DebugPrint(string.format('^3[INFO]: Returned %s from select query.^7', #result))
			if result then
				TriggerClientEvent('prolaser4:ReturnLogData', source, result)
			end
		end)
	end
	
	------------------ AUTO CLEANUP -----------------
	--	Remove old records after X days old.
	function CleanUpRecordsFromSQL()
		DebugPrint('^3[INFO]: Removing old records.^7');
		MySQL.query(cleanupQuery, {cfg.loggingCleanUpInterval}, function(returnData)
			DebugPrint(string.format('^3[INFO]: Removed %s records (older than %s days)^7', returnData.affectedRows, cfg.loggingCleanUpInterval));
		end)
	end
	
	------------------ RECORD COUNT -----------------
	function GetRecordCount()
		local recordCount = '^8FAILED TO RETRIEVE        ^7'
		MySQL.query(countQuery, {}, function(returnData)
			if returnData and returnData[1] and returnData[1]['COUNT(*)'] then
				recordCount = returnData[1]['COUNT(*)']
			end
		end)
		Wait(500)
		return recordCount
	end
end

--[[------------ STARTUP / VERSION CHECKING -----------]]
CreateThread( function()
	local currentVersion = semver(GetResourceMetadata(GetCurrentResourceName(), 'version', 0))
	local repoVersion = semver('0.0.0')
	local recordCount = 0
	
-- Get prolaser4 version from github
	PerformHttpRequest('https://raw.githubusercontent.com/TrevorBarns/ProLaser4/main/version', function(err, responseText, headers)
		if responseText ~= nil and responseText ~= '' then
			repoVersion = semver(responseText:gsub('\n', ''))
		end
	end)
	
	if cfg.logging then
		if MySQL == nil then
			print('^3[WARNING]: logging enabled, but oxmysql not found. Did you uncomment the oxmysql\n\t\t  lines in fxmanifest.lua?\n\n\t\t  Remember, changes to fxmanifest are only loaded after running `refresh`, then `restart`.^7')
			recordCount = '^8NO CONNECTION^7'
		else
			recordCount = GetRecordCount()
		end
	end
	
	Wait(1000)
	print('\n\t^7 _______________________________________________________')
    print('\t|^8     ____             __                         __ __ ^7|')
    print('\t|^8    / __ \\_________  / /   ____  ________  _____/ // / ^7|')
    print('\t|^8   / /_/ / ___/ __ \\/ /   / __ `/ ___/ _ \\/ ___/ // /_ ^7|')
    print('\t|^8  / ____/ /  / /_/ / /___/ /_/ (__  )  __/ /  /__  __/ ^7|')
    print('\t|^8 /_/   /_/   \\____/_____/\\__,_/____/\\___/_/     /_/    ^7|')
	print('\t^7|_______________________________________________________|')
	print(('\t|\t           INSTALLED: %-26s|'):format(currentVersion))
	print(('\t|\t              LATEST: %-26s|'):format(repoVersion))
	if cfg.logging then
		if type(recordCount) == 'number' then
			print(('\t|\t        RECORD COUNT: %-26s|'):format(recordCount))
		else
			print(('\t|\t        RECORD COUNT: %-30s|'):format(recordCount))
		end
	end
	if currentVersion < repoVersion then
		print('\t^7|_______________________________________________________|')
		print('\t|\t         ^8STABLE UPDATE AVAILABLE                ^7|')
		print('\t|^8                      DOWNLOAD AT:                     ^7|')
		print('\t|^5       github.com/TrevorBarns/ProLaser4/releases       ^7|')
   end
	print('\t^7|_______________________________________________________|')
	print('\t^7|    Updates, Support, Feedback: ^5discord.gg/PXQ4T8wB9   ^7|')
	print('\t^7|_______________________________________________________|\n\n')
end)
