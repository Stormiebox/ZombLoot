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
	if (#ZT.itemTable > 0) then
		local ran = ZombRand(0, 10000)
		if (ran < ZT.dropChance) then
			local ran2 = ZombRand(1, #ZT.itemTable + 1)
			local itemToDrop = ZT.itemTable[ran2]
			local killer = _zombie:getAttackedBy()

			if (ZT.dropLocation == 1) then
				_zombie:getInventory():AddItem(itemToDrop)
			else
				if killer and instanceof(killer, "IsoPlayer") then
					killer:getInventory():AddItem(itemToDrop)
				else
					_zombie:getInventory():AddItem(itemToDrop) -- Fallback to corpse
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
local function changeDrop()
	if not getSandboxOptions() then return end

	if getSandboxOptions():getOptionByName("ZombTime.Enable") then
		ZT.enabled = getSandboxOptions():getOptionByName("ZombTime.Enable"):getValue()
	end
	ZT.startTime = getSandboxOptions():getOptionByName("ZombTime.startTime"):getValue()
	ZT.endTime = getSandboxOptions():getOptionByName("ZombTime.endTime"):getValue()
	ZT.dropChance = getSandboxOptions():getOptionByName("ZombTime.dropChance"):getValue() * 100
	ZT.textShow = getSandboxOptions():getOptionByName("ZombTime.textShow"):getValue()
	ZT.dropLocation = getSandboxOptions():getOptionByName("ZombTime.dropLocation"):getValue()
	ZT.tmp = getSandboxOptions():getOptionByName("ZombTime.itemTable"):getValue()
	ZT.itemTable = Split(ZT.tmp, "/")

	if (ZT.textShow == true) then
		ZT.startText = getSandboxOptions():getOptionByName("ZombTime.startText"):getValue()
		ZT.endText = getSandboxOptions():getOptionByName("ZombTime.endText"):getValue()
		ZT.dropText = getSandboxOptions():getOptionByName("ZombTime.dropText"):getValue()
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