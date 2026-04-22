-- =============================================================================
-- Mod: ZombLoot
-- File: ZombWeather.lua
-- Author: Stormbox
-- Date: 04/20/2026
-- Description: Implements extreme weather drops. Provides a unique loot table 
-- incentive for players to hunt zombies during rain, snow, or heavy fog.
-- =============================================================================
require 'Items/SuburbsDistributions'

local ZW = {
	enabled = true,
	dropChance = 500,
	tmp = "",
	itemTable = {},
	dropLocation = 1,
	textShow = true,
	dropText = "Storm Loot!"
}

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

-- Event handler triggered whenever a zombie dies, checks current climate
local function ZombWeather_death(_zombie)
	if not ZW.enabled then return end
	if (#ZW.itemTable == 0) then return end

	local climate = getClimateManager()
	if not climate then return end

	local rain = climate:getPrecipitationIntensity() or 0
	local fog = climate:getFogIntensity() or 0
	local snow = climate:getSnowIntensity() or 0

	-- If it's noticeably raining, snowing, or foggy
	if rain > 0.3 or fog > 0.3 or snow > 0.3 then
		local ran = ZombRand(0, 10000)
		if (ran < ZW.dropChance) then
			local ran2 = ZombRand(1, #ZW.itemTable + 1)
			local itemToDrop = ZW.itemTable[ran2]
			local killer = _zombie:getAttackedBy()

			if (ZW.dropLocation == 1) then
				_zombie:getInventory():AddItem(itemToDrop)
			else
				if killer and instanceof(killer, "IsoPlayer") then
					killer:getInventory():AddItem(itemToDrop)
				end
			end

			if ZW.textShow and ZW.dropText and ZW.dropText ~= "" then
				if killer and instanceof(killer, "IsoPlayer") then
					killer:setHaloNote(ZW.dropText)
				end
			end
		end
	end
end

-- Reloads the current sandbox settings for weather events into local memory
local function ZW_LootChange()
	if not getSandboxOptions() then return end
	if getSandboxOptions():getOptionByName("ZombWeather.Enable") then
		ZW.enabled = getSandboxOptions():getOptionByName("ZombWeather.Enable"):getValue()
	end
	ZW.dropChance = getSandboxOptions():getOptionByName("ZombWeather.dropChance"):getValue() * 100
	ZW.dropLocation = getSandboxOptions():getOptionByName("ZombWeather.dropLocation"):getValue()
	ZW.tmp = getSandboxOptions():getOptionByName("ZombWeather.itemTable"):getValue()
	ZW.textShow = getSandboxOptions():getOptionByName("ZombWeather.textShow"):getValue()
	ZW.dropText = getSandboxOptions():getOptionByName("ZombWeather.dropText"):getValue()
	ZW.itemTable = Split(ZW.tmp, "/")
end

local initialized = false
-- Initialization step to bind the events without running multiple times
local function initMod()
	if initialized then return end
	initialized = true
	ZW_LootChange()
	Events.EveryTenMinutes.Add(ZW_LootChange)
	Events.OnZombieDead.Add(ZombWeather_death)
end

Events.OnGameStart.Add(initMod)
Events.OnServerStarted.Add(initMod)