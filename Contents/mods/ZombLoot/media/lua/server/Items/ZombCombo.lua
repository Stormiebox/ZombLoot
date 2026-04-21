-- =============================================================================
-- Mod: ZombLoot
-- File: ZombCombo.lua
-- Author: Stormbox
-- Date: 04/20/2026
-- Description: Tracks player kill streaks. Rewards aggressive gameplay by 
-- guaranteeing a specific loot drop after a consecutive number of fast kills.
-- =============================================================================
require 'Items/SuburbsDistributions'

local ZC = {
	comboTarget = 10,
	timeWindow = 10, -- in seconds
	tmp = "",
	itemTable = {},
	dropLocation = 1,
	textShow = true,
	dropText = "Combo Bonus!"
}

local playerCombos = {}

-- Helper function to split a string into a table using a delimiter (e.g. "/")
local function Split(s, delimiter)
	local result = {}
	for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
		table.insert(result, match)
	end
	return result
end

-- Event handler triggered whenever a zombie dies, tracks player kill times for combos
local function ZombCombo_death(_zombie)
	if (#ZC.itemTable == 0) then return end

	local killer = _zombie:getAttackedBy()
	if not killer or not instanceof(killer, "IsoPlayer") then return end

	local username = killer:getUsername()
	local currentTime = os.time()

	if not playerCombos[username] then
		playerCombos[username] = { count = 0, lastKill = 0 }
	end

	local pData = playerCombos[username]

	-- Check if the kill was within the allowed time window to continue the combo
	if (currentTime - pData.lastKill) <= ZC.timeWindow then
		pData.count = pData.count + 1
	else
		pData.count = 1 -- Reset count if too much time passed
	end
	pData.lastKill = currentTime

	-- If the target is met, award the item
	if pData.count >= ZC.comboTarget then
		pData.count = 0 -- Reset combo for the next streak

		local ran = ZombRand(1, #ZC.itemTable + 1)
		local itemToDrop = ZC.itemTable[ran]

		if (ZC.dropLocation == 1) then
			_zombie:getInventory():AddItem(itemToDrop)
		else
			killer:getInventory():AddItem(itemToDrop)
		end

		if ZC.textShow and ZC.dropText and ZC.dropText ~= "" then
			killer:setHaloNote(ZC.dropText)
		end
	end
end

-- Reloads the current sandbox settings for combos into local memory
local function ZC_LootChange()
	if not getSandboxOptions() then return end
	ZC.comboTarget = getSandboxOptions():getOptionByName("ZombCombo.comboTarget"):getValue()
	ZC.timeWindow = getSandboxOptions():getOptionByName("ZombCombo.timeWindow"):getValue()
	ZC.dropLocation = getSandboxOptions():getOptionByName("ZombCombo.dropLocation"):getValue()
	ZC.tmp = getSandboxOptions():getOptionByName("ZombCombo.itemTable"):getValue()
	ZC.textShow = getSandboxOptions():getOptionByName("ZombCombo.textShow"):getValue()
	ZC.dropText = getSandboxOptions():getOptionByName("ZombCombo.dropText"):getValue()
	ZC.itemTable = Split(ZC.tmp, "/")
end

local initialized = false
-- Initialization step to bind the events without running multiple times
local function initMod()
	if initialized then return end
	initialized = true
	ZC_LootChange()
	Events.EveryTenMinutes.Add(ZC_LootChange)
	Events.OnZombieDead.Add(ZombCombo_death)
end

Events.OnGameStart.Add(initMod)
Events.OnServerStarted.Add(initMod)