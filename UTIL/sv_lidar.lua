local cfg = cfg
local isInsertAlreadyActive = false

--	Repeater for display data to target player
RegisterServerEvent('prolaser4:SendDisplayData')
AddEventHandler('prolaser4:SendDisplayData', function(target, data)
	TriggerClientEvent('prolaser4:ReturnDisplayData', target, data)
end)

function DebugPrint(text)
	if cfg.serverDebugging then
		print(text)
	end
end

if cfg.logging then
	LOGGED_EVENTS = { }
	
	--	-------------- INSERT DATA --------------
	local insertQuery = [[
		INSERT INTO prolaser4 
			(timestamp, speed, distance, targetX, targetY, player, street, selfTestTimestamp) 
		VALUES 
			(STR_TO_DATE(?, "%m/%d/%Y %H:%i"), ?, ?, ?, ?, ?, ?, STR_TO_DATE(?, "%m/%d/%Y %H:%i"))
	]]
	
	local selectQueryRaw = [[
			SELECT 
				rid,
				DATE_FORMAT(timestamp, "%m/%d/%Y %H:%i") AS timestamp, 
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
	-- Debugging Command
	RegisterCommand('lidarsqlupdate', function(source, args)
		-- check if from server console
		if source == 0 then
			InsertRecordsToSQL()
		else
			TriggerClientEvent('chat:addMessage', source, { args = { '^1Error', 'This command can only be executed from the console.' } })
		end
	end)

	-- Main thread, every restart remove old records if needed, insert records every 5 minutes.
	CreateThread(function()
		while cfg.logging do
			InsertRecordsToSQL()
			Wait(60000)
		end
	end)

	--	Shared event handler colate all lidar data from all players for SQL submission.
	RegisterServerEvent('prolaser4:SendLogData')
	AddEventHandler('prolaser4:SendLogData', function(logData)
		local playerName = GetPlayerName(source)
		for i, entry in ipairs(logData) do
			entry.player = playerName
			table.insert(LOGGED_EVENTS, entry)
		end
	end)

	--	Inserts records to SQL table
	function InsertRecordsToSQL()
		if not isInsertAlreadyActive then
			if #LOGGED_EVENTS > 0 then
				DebugPrint(string.format('^3[INFO]: Started inserting %s records.^7', #LOGGED_EVENTS))
				isInsertAlreadyActive = true
				-- Execute the prepared statement for each entry
				for _, entry in ipairs(LOGGED_EVENTS) do
					-- Bind the parameters to the statement
					MySQL.prepare(insertQuery, {entry.time, entry.speed, entry.range, entry.targetX, entry.targetY, entry.player, entry.street, entry.selfTestTimestamp}, function(returnData) end)
				end
				LOGGED_EVENTS = {}
				isInsertAlreadyActive = false
				DebugPrint('^3[INFO]: Finished inserting records.^7')
			end
		end
	end
	
	--	-------------- GETTER / SELECT --------------
	--	C->S request all record data
	RegisterNetEvent('prolaser4:GetLogData')
	AddEventHandler('prolaser4:GetLogData', function()
		SelectRecordsFromSQL(source)
	end)

	-- Get all record data and return to client
	function SelectRecordsFromSQL(source)
		DebugPrint(string.format('^3[INFO]: Getting records for %s.^7', GetPlayerName(source)))
		MySQL.query(selectQuery, {}, function(result)
			DebugPrint(string.format('^3[INFO]: Returned %s from select query.^7', result))
			if result then
				TriggerClientEvent('prolaser4:ReturnLogData', source, result)
			end
		end)
	end

	--	Database timeout event from client->server for server console log.
	RegisterServerEvent('prolaser4:DatabaseTimeout')
	AddEventHandler('prolaser4:DatabaseTimeout', function()
		print(string.format('^8[ERROR]: ^3Database timed out for %s after 5 seconds.\n\t\t1) Ensure your database is online\n\t\t2) restart oxmysql.^7', GetPlayerName(source)))
	end)

	--	-------------- AUTO CLEANUP --------------
	-- Calls sql to prune records every 6 hours
	CreateThread(function()
		if cfg.loggingCleanUpInterval ~= -1 then
			while true do
				CleanUpRecordsFromSQL()
				Wait(21600000)
			end
		end
	end)
	
	--	Clean up records after 30 days old.
	function CleanUpRecordsFromSQL()
		MySQL.query(cleanupQuery, {cfg.loggingCleanUpInterval}, function(returnData)
			if returnData.affectedRows > 0 then
				DebugPrint(string.format('^3[INFO]: Cleaned up %s records (older than %s days)^7', rowsAffected, cfg.loggingCleanUpInterval));
			end
		end)
	end
	
	--	-------------- RECORD COUNT --------------
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

-- Startup & Version Checking
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
		recordCount = GetRecordCount()
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
		print(('\t|\t        RECORD COUNT: %-26s|'):format(recordCount))
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