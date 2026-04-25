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
	enabled = true,
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
	if not s or s == "" then return result end
	for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
		local item = match:match("^%s*(.-)%s*$")
		if item and item ~= "" then
			table.insert(result, item)
		end
	end
	return result
end

-- Event handler triggered whenever a zombie dies, tracks player kill times for combos
local function ZombCombo_death(_zombie)
	if not ZC.enabled or not _zombie then return end
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
		if not itemToDrop or itemToDrop == "" then
			return
		end

		local zombieInventory = _zombie.getInventory and _zombie:getInventory() or nil
		if (ZC.dropLocation == 1) then
			if zombieInventory then
				zombieInventory:AddItem(itemToDrop)
			end
		else
			killer:getInventory():AddItem(itemToDrop)
		end

		if ZC.textShow and ZC.dropText and ZC.dropText ~= "" then
			killer:setHaloNote(ZC.dropText)
		end
	end
end

-- Reloads the current sandbox settings for combos into local memory
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

local function ZC_LootChange()
	local options = getSandboxOptions and getSandboxOptions() or nil
	if not options then return end

	ZC.enabled = getSandboxOptionValue(options, "ZombCombo.Enable", ZC.enabled)
	ZC.comboTarget = tonumber(getSandboxOptionValue(options, "ZombCombo.comboTarget", ZC.comboTarget)) or ZC.comboTarget
	ZC.timeWindow = tonumber(getSandboxOptionValue(options, "ZombCombo.timeWindow", ZC.timeWindow)) or ZC.timeWindow
	ZC.dropLocation = tonumber(getSandboxOptionValue(options, "ZombCombo.dropLocation", ZC.dropLocation)) or ZC.dropLocation
	ZC.tmp = tostring(getSandboxOptionValue(options, "ZombCombo.itemTable", "") or "")
	ZC.textShow = getSandboxOptionValue(options, "ZombCombo.textShow", ZC.textShow) == true
	ZC.dropText = tostring(getSandboxOptionValue(options, "ZombCombo.dropText", ZC.dropText) or "")
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