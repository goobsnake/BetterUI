--[[
File: Modules/Vendor/Module.lua
Purpose: Entry point and settings configuration for the Vendor module.

Registers the Vendor panel in the BetterUI addon settings and provides font
descriptor factories for the name and column rendering.
]]


-- Module initialization
BETTERUI.Vendor = BETTERUI.Vendor or {}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
BETTERUI.CIM.RegisterModuleAccessors("Vendor")

-- Initializes defaults and migrates legacy settings for the Vendor module.
-- Called by BETTERUI.ModuleOptions() via pcall with m_options.
---@param m_options table|nil Module options from saved variables
---@return table m_options Initialized options with defaults applied
function BETTERUI.Vendor.InitModule(m_options)
	m_options = m_options or {}
	---@cast m_options table
	local defaults = BETTERUI.Vendor.DEFAULTS
	local fallbackDefaults = {
		showIconEnchantment = true,
		showIconSetGear = true,
		showIconUnboundItem = true,
		showIconResearchableTrait = true,
		showIconUnknownRecipe = true,
		showIconUnknownBook = true,
		enableCarousel = true,
		enableBatchJunkSell = true,
	}

	m_options = BETTERUI.CIM.InitModuleDefaults("Vendor", m_options, defaults, fallbackDefaults)
	return m_options
end

--- Normalizes search text for case-insensitive list filtering.
---@param query any
---@return string|nil normalized
function BETTERUI.Vendor.NormalizeSearchQuery(query)
	if query == nil then
		return nil
	end

	local text = tostring(query)
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return nil
	end

	return (zo_strlower and zo_strlower(text)) or string.lower(text)
end

--- Returns the active normalized search query for a vendor instance.
---@param vendorInstance table|nil
---@return string|nil normalized
function BETTERUI.Vendor.GetNormalizedSearchQuery(vendorInstance)
	return BETTERUI.Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery)
end

--- Checks whether text matches the active normalized search query.
---@param normalizedQuery string|nil
---@param text any
---@return boolean matched
function BETTERUI.Vendor.MatchesSearchQuery(normalizedQuery, text)
	if not normalizedQuery then
		return true
	end

	local haystack = tostring(text or "")
	if haystack == "" then
		return false
	end

	haystack = (zo_strlower and zo_strlower(haystack)) or string.lower(haystack)
	return string.find(haystack, normalizedQuery, 1, true) ~= nil
end

---@param tabs table[]|nil
---@return table<number, boolean> modeSet
function BETTERUI.Vendor.BuildActiveModeSet(tabs)
	local modeSet = {}
	for _, tab in ipairs(tabs or {}) do
		if tab and tab.mode then
			modeSet[tab.mode] = true
		end
	end
	return modeSet
end

---@param modeSet table<number, boolean>|nil
---@param isFenceInteraction boolean|nil
---@return boolean
function BETTERUI.Vendor.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)
	if isFenceInteraction then
		return false
	end

	local mode = BETTERUI.Vendor.MODE or {}
	local sellMode = mode.SELL or 2
	local buybackMode = mode.BUYBACK or 4
	local buyMode = mode.BUY or 1
	local repairMode = mode.REPAIR or 3

	modeSet = modeSet or {}
	local hasSell = modeSet[sellMode] == true
	local hasBuyback = modeSet[buybackMode] == true
	local hasBuy = modeSet[buyMode] == true
	local hasRepair = modeSet[repairMode] == true
	return hasSell and hasBuyback and not hasBuy and not hasRepair
end

---@param flagName string|nil
---@return boolean
function BETTERUI.Vendor.IsDebugFlagEnabled(flagName)
	local debug = BETTERUI.CIM and BETTERUI.CIM.Debug
	if not (debug and debug.IsEnabled and debug.IsEnabled()) then
		return false
	end
	flagName = flagName or "DIRECTIONAL_INPUT"
	return debug.FLAGS and debug.FLAGS[flagName] == true or false
end

---@param message string
---@param flagName string|nil
---@param category string|nil
---@return nil
function BETTERUI.Vendor.DebugLog(message, flagName, category)
	if BETTERUI.Vendor.IsDebugFlagEnabled(flagName) and BETTERUI.CIM and BETTERUI.CIM.Debug and BETTERUI.CIM.Debug.Log then
		BETTERUI.CIM.Debug.Log(message, category or "Vendor")
	end
end

---@param obj table|nil
---@return boolean
function BETTERUI.Vendor.IsDirectionalInputListening(obj)
	if not obj or not DIRECTIONAL_INPUT or not DIRECTIONAL_INPUT.IsListening then
		return false
	end
	return DIRECTIONAL_INPUT:IsListening(obj)
end

---@param obj table|nil
---@param includeMovementController boolean|nil
---@return number releasedCount
function BETTERUI.Vendor.ReleaseDirectionalInputRegistrations(obj, includeMovementController)
	if not obj or not DIRECTIONAL_INPUT or not DIRECTIONAL_INPUT.IsListening or not DIRECTIONAL_INPUT.Deactivate then
		return 0
	end

	local releasedCount = 0
	local releasedCandidates = {}
	local function ReleaseCandidate(candidate)
		if not candidate or releasedCandidates[candidate] then
			return
		end
		releasedCandidates[candidate] = true
		local safetyCounter = 0
		while candidate and DIRECTIONAL_INPUT:IsListening(candidate) and safetyCounter < 8 do
			DIRECTIONAL_INPUT:Deactivate(candidate)
			releasedCount = releasedCount + 1
			safetyCounter = safetyCounter + 1
		end
	end

	ReleaseCandidate(obj)
	ReleaseCandidate(obj.spinner)
	if includeMovementController then
		ReleaseCandidate(obj.movementController)
		ReleaseCandidate(obj.horizontalMovementController)
		ReleaseCandidate(obj.verticalMovementController)
	end

	return releasedCount
end

--- Gets junk sell value summary for batch sell UX.
---@return number totalValue Total gold value of all junk items
---@return number itemCount Number of junk items in backpack
function BETTERUI.Vendor.GetJunkSellSummary()
	local totalValue = 0
	local itemCount = 0

	local bagSize = GetBagSize(BAG_BACKPACK) or 0
	for slotIndex = 0, bagSize - 1 do
		if IsItemJunk(BAG_BACKPACK, slotIndex) then
			local sellPrice = GetItemSellValueWithBonuses(BAG_BACKPACK, slotIndex) or 0
			local stackCount = GetSlotStackSize(BAG_BACKPACK, slotIndex) or 1
			totalValue = totalValue + (sellPrice * stackCount)
			itemCount = itemCount + 1
		end
	end

	return totalValue, itemCount
end

--- Formats a currency value for vendor displays based on user settings.
---@param value number
---@return string
function BETTERUI.Vendor.FormatCurrency(value)
	if BETTERUI.Vendor.GetSetting("abbreviateVendorCurrency") ~= false then
		if BETTERUI.FormatAbbreviatedNumber then
			return BETTERUI.FormatAbbreviatedNumber(value)
		end
	end
	return tostring(value)
end

--[[
Function: BETTERUI.Vendor.Setup
Lifecycle hook to setup the Vendor module.
References: Called by BETTERUI.LoadModules() in BetterUI.lua.
]]
---@return nil
function BETTERUI.Vendor.Setup()
	BETTERUI.Vendor.Settings.RegisterPanel("Vendor", "Vendor")
	BETTERUI.Vendor.Init()
end
