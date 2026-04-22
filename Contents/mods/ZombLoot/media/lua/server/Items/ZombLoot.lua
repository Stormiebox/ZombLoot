-- =============================================================================
-- Mod: ZombLoot
-- File: ZombLoot.lua
-- Author: Stormbox
-- Date: 04/20/2026
-- Description: Handles the core dynamic loot dropping mechanics. Allows admins
-- to freely change zombie loot tables and drop chances via sandbox options.
-- =============================================================================
require 'Items/SuburbsDistributions'

local ZL_enabled = true
local ZL_dropChance = 0
local ZL_tmp = ""
local ZL_dropLocation = 1
local ZL_dropTextShow = false
local ZL_itemTable = {}

-- Helper function to split a string (e.g. "Base.Axe/Base.Apple") into a table of item IDs
local function ZL_Split(s, delimiter)
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

-- Reloads the current sandbox settings into local memory (called on start and every 10 min)
local function ZL_LootChange()
	if not getSandboxOptions() then return end
	if getSandboxOptions():getOptionByName("ZombLoot.Enable") then
		ZL_enabled = getSandboxOptions():getOptionByName("ZombLoot.Enable"):getValue()
	end
	ZL_dropChance = getSandboxOptions():getOptionByName("ZombLoot.dropChance"):getValue() * 100
	ZL_dropLocation = getSandboxOptions():getOptionByName("ZombLoot.dropLocation"):getValue()
	ZL_tmp = getSandboxOptions():getOptionByName("ZombLoot.itemTable"):getValue()
	ZL_dropTextShow = getSandboxOptions():getOptionByName("ZombLoot.dropTextShow"):getValue()
	ZL_itemTable = ZL_Split(ZL_tmp, "/")
end

-- Event handler triggered whenever a zombie is killed
local function ZombLoot_death(_zombie)
	if not ZL_enabled then return end
	if (#ZL_itemTable > 0) then
		local ran = ZombRand(0, 10000)
		if (ran < ZL_dropChance) then
			local ran2 = ZombRand(1, #ZL_itemTable + 1)
			local itemToDrop = ZL_itemTable[ran2]
			local killer = _zombie:getAttackedBy()

			if (ZL_dropLocation == 1) then
				_zombie:getInventory():AddItem(itemToDrop)
			else
				if killer and instanceof(killer, "IsoPlayer") then
					killer:getInventory():AddItem(itemToDrop)
				end
			end

			if (ZL_dropTextShow == true) then
				if killer and instanceof(killer, "IsoPlayer") then
					killer:setHaloNote("!")
				end
			end
		end
	end
end

local initialized = false
-- Initialization step to bind the events without running multiple times
local function initMod()
	if initialized then return end
	initialized = true
	ZL_LootChange()
	Events.EveryTenMinutes.Add(ZL_LootChange)
	Events.OnZombieDead.Add(ZombLoot_death)
end

Events.OnGameStart.Add(initMod)
Events.OnServerStarted.Add(initMod)