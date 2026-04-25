-- =============================================================================
-- Mod: ZombLoot
-- File: ZombTime.lua
-- Author: Stormbox
-- Date: 04/20/2026
-- Description: Implements "Loot Bonus Time" (Fever Time). Grants special loot 
-- drops when killing zombies within a designated in-game time window.
-- =============================================================================
require 'Items/SuburbsDistributions'

local ZT = {
	enabled = true,
	state = 0,
	startTime = 0,
	endTime = 5,
	dropChance = 200,
	tmp = "",
	startText = "",
	endText = "",
	dropText = "",
	textShow = true,
	dropLocation = 1,
	itemTable = {}
}

-- Function to broadcast a message/halo note to players safely on Dedicated Servers
local function broadcastHaloNote(text)
	if not text or text == "" then return end
	if isServer() then
		local players = getOnlinePlayers()
		if players then
			for i=0, players:size()-1 do
				local p = players:get(i)
				p:setHaloNote(text)
			end
		end
	else
		local p = getPlayer()
		if p then p:setHaloNote(text) end
	end
end

-- Helper function to split a string into a table using a delimiter (e.g. "/")
local function Split(s, delimiter)
	local result = {}
	if not s or s == "" then return result end
	for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
		local item = match:match("^%s*(.-)%s*$")
		if item and item ~= "" then
			table.insert(result, item)
		end
	end
	return result
end

-- Event handler triggered whenever a zombie dies (only active during Fever Time)
local function ZombTime_death(_zombie)
	if not _zombie then return end
	if (#ZT.itemTable > 0) then
		local ran = ZombRand(0, 10000)
		if (ran < ZT.dropChance) then
			local ran2 = ZombRand(1, #ZT.itemTable + 1)
			local itemToDrop = ZT.itemTable[ran2]
			if not itemToDrop or itemToDrop == "" then
				return
			end

			local killer = _zombie:getAttackedBy()
			local zombieInventory = _zombie.getInventory and _zombie:getInventory() or nil

			if (ZT.dropLocation == 1) then
				if zombieInventory then
					zombieInventory:AddItem(itemToDrop)
				end
			else
				if killer and instanceof(killer, "IsoPlayer") then
					killer:getInventory():AddItem(itemToDrop)
				elseif zombieInventory then
					zombieInventory:AddItem(itemToDrop) -- Fallback to corpse
				end
			end

			if ZT.textShow and ZT.dropText and ZT.dropText ~= "" then
				if killer and instanceof(killer, "IsoPlayer") then
					killer:setHaloNote(ZT.dropText)
				end
			end
		end
	end
end

-- Logic to check if the current in-game time falls within the configured start and end time
local function checkZedTime()
	local currentTime = getGameTime()
	if not currentTime then return end
	local hour = currentTime:getTimeOfDay()
	local isZedTime = false

	if ZT.enabled then
		if ZT.startTime < ZT.endTime then
			isZedTime = (hour >= ZT.startTime and hour < ZT.endTime)
		else
			isZedTime = (hour >= ZT.startTime or hour < ZT.endTime)
		end
	end

	if isZedTime then
		-- Turn Fever Time ON
		if (ZT.state == 0) then
			if ZT.textShow then broadcastHaloNote(ZT.startText) end
			Events.OnZombieDead.Add(ZombTime_death)
			ZT.state = 1
		end
	elseif (ZT.state == 1) then
		-- Turn Fever Time OFF
		if ZT.textShow then broadcastHaloNote(ZT.endText) end
		Events.OnZombieDead.Remove(ZombTime_death)
		ZT.state = 0
	end
end

-- Reloads the current sandbox settings for time events into local memory
local function getSandboxOptionValue(options, optionName, defaultValue)
	if not options then
		return defaultValue
	end

	local option = options:getOptionByName(optionName)
	if option then
		return option:getValue()
	end

	return defaultValue
end

local function changeDrop()
	local options = getSandboxOptions and getSandboxOptions() or nil
	if not options then return end

	ZT.enabled = getSandboxOptionValue(options, "ZombTime.Enable", ZT.enabled)
	ZT.startTime = tonumber(getSandboxOptionValue(options, "ZombTime.startTime", ZT.startTime)) or ZT.startTime
	ZT.endTime = tonumber(getSandboxOptionValue(options, "ZombTime.endTime", ZT.endTime)) or ZT.endTime
	ZT.dropChance = (tonumber(getSandboxOptionValue(options, "ZombTime.dropChance", 0)) or 0) * 100
	ZT.textShow = getSandboxOptionValue(options, "ZombTime.textShow", ZT.textShow) == true
	ZT.dropLocation = tonumber(getSandboxOptionValue(options, "ZombTime.dropLocation", ZT.dropLocation)) or ZT.dropLocation
	ZT.tmp = tostring(getSandboxOptionValue(options, "ZombTime.itemTable", "") or "")
	ZT.itemTable = Split(ZT.tmp, "/")

	if ZT.textShow then
		ZT.startText = tostring(getSandboxOptionValue(options, "ZombTime.startText", "") or "")
		ZT.endText = tostring(getSandboxOptionValue(options, "ZombTime.endText", "") or "")
		ZT.dropText = tostring(getSandboxOptionValue(options, "ZombTime.dropText", "") or "")
	else
		ZT.startText = ""
		ZT.endText = ""
		ZT.dropText = ""
	end

	checkZedTime()
end

local initialized = false
-- Initialization step to bind the events without running multiple times
local function initMod()
	if initialized then return end
	initialized = true
	changeDrop()
	Events.EveryTenMinutes.Add(changeDrop)
end

Events.OnGameStart.Add(initMod)
Events.OnServerStarted.Add(initMod)