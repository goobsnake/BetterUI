--[[
File: Modules/Vendor/Module.lua
Purpose: Entry point and settings configuration for the Vendor module.

Registers the Vendor panel in the BetterUI addon settings and provides font
descriptor factories for the name and column rendering.
]]


-- Module initialization
---@type BetterUIModuleRoot
BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
local ARCHETYPES = BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES or {}
local RUNTIME_COORDINATOR = ARCHETYPES.RUNTIME_COORDINATOR or "runtime-coordinator"

---@type BetterUIModuleArchetypeRuntimeCoordinator
Vendor.ARCHETYPE = RUNTIME_COORDINATOR

local function BuildDefaultVendorActionId(actionKey)
	if type(actionKey) ~= "string" then
		return nil
	end
	if actionKey == "SELL" or actionKey == "SELL_JUNK" or actionKey == "SELL_VENGEANCE" then
		return "vendor_" .. string.lower(actionKey)
	end
	if actionKey == "FENCE_SELL" or actionKey == "FENCE_LAUNDER" then
		return "fence_" .. string.lower(string.sub(actionKey, 7))
	end
	return nil
end

local function EnsureVendorActionIds()
	local actionIds = Vendor.ACTION
	if type(actionIds) ~= "table" then
		actionIds = {}
	end

	actionIds.SELL = actionIds.SELL or BuildDefaultVendorActionId("SELL")
	actionIds.SELL_JUNK = actionIds.SELL_JUNK or BuildDefaultVendorActionId("SELL_JUNK")
	actionIds.SELL_VENGEANCE = actionIds.SELL_VENGEANCE or BuildDefaultVendorActionId("SELL_VENGEANCE")
	actionIds.FENCE_SELL = actionIds.FENCE_SELL or BuildDefaultVendorActionId("FENCE_SELL")
	actionIds.FENCE_LAUNDER = actionIds.FENCE_LAUNDER or BuildDefaultVendorActionId("FENCE_LAUNDER")

	Vendor.ACTION = actionIds
	return actionIds
end

---@param actionKey string
---@return string|nil actionId
function BETTERUI.Vendor.ResolveActionId(actionKey)
	local actionIds = EnsureVendorActionIds()
	return actionIds[actionKey] or BuildDefaultVendorActionId(actionKey)
end

EnsureVendorActionIds()

Vendor.MODE = Vendor.MODE or {
	BUY = 1,
	SELL = 2,
	REPAIR = 3,
	BUYBACK = 4,
	FENCE_SELL = 5,
	FENCE_LAUNDER = 6,
	STABLE = 7,
	SELL_VENGEANCE = 8,
}
Vendor.CONST = Vendor.CONST or {}
Vendor.CONST.CAROUSEL = Vendor.CONST.CAROUSEL or {
	startOffset = 705,
	verticalOffset = -1,
}
---@type BetterUIModuleRootContract
Vendor.ROOT_CONTRACT = {
	name = "Vendor",
	archetype = Vendor.ARCHETYPE,
	init = true,
	setup = true,
}

-- Wire shared settings statics before runtime accessors register in Setup().
BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Vendor, "Vendor")

---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Initialized options with defaults applied
---@type BetterUIModuleInitHook
function BETTERUI.Vendor.InitModule(m_options)
	m_options = m_options or {}
	---@cast m_options BetterUIModuleOptions
	local defaults = BETTERUI.Vendor.DEFAULTS
	local moduleDefaults = BETTERUI.Defaults and BETTERUI.Defaults.GetModuleDefaults
		and BETTERUI.Defaults.GetModuleDefaults("Vendor") or nil

	m_options = BETTERUI.CIM.InitModuleDefaults("Vendor", m_options, defaults, moduleDefaults)
	return m_options
end

--- Normalizes search text for case-insensitive list filtering.
---@param query any
---@return string|nil normalized
local function NormalizeSearchText(query)
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

---@param query any
---@return string|nil normalized
function BETTERUI.Vendor.NormalizeSearchQuery(query)
	return NormalizeSearchText(query)
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

---@param flagName string|nil
---@return boolean
function BETTERUI.Vendor.IsDebugFlagEnabled(flagName)
	local debug = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.Debug
	if not (debug and debug.IsEnabled and debug.IsEnabled()) then
		return false
	end
	flagName = flagName or "DIRECTIONAL_INPUT"
	return debug.FLAGS and debug.FLAGS[flagName] == true or false
end

---@param flagName string|nil
---@param category string|nil
---@param message string|nil
---@return string|nil normalizedFlag
---@return string|nil normalizedCategory
---@return string|nil normalizedMessage
local function NormalizeDebugLogContract(flagName, category, message)
	-- Accept legacy reversed ordering `(category, flagName, message)` while preserving
	-- the canonical `(flagName, category, message)` contract.
	local debug = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.Debug
	local flags = debug and debug.FLAGS or nil
	if type(flagName) == "string" and type(category) == "string" and type(flags) == "table" then
		local firstIsKnownFlag = flags[flagName] ~= nil
		local secondIsKnownFlag = flags[category] ~= nil
		if not firstIsKnownFlag and secondIsKnownFlag then
			flagName, category = category, flagName
		end
	end
	return flagName, category, message
end

---@param flagName string|nil
---@param category string|nil
---@param message string
---@return nil
function BETTERUI.Vendor.LogDebug(flagName, category, message)
	flagName, category, message = NormalizeDebugLogContract(flagName, category, message)
	if BETTERUI.Vendor.IsDebugFlagEnabled(flagName) and BETTERUI and BETTERUI.CIM and BETTERUI.CIM.Debug and BETTERUI.CIM.Debug.Log then
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

--- Shared vendor authorization seam for primary and batch sell/launder actions.
---@param actionType string
---@param bagId number
---@param slotIndex number
---@param vendorInstance BETTERUI.Vendor.Class|nil
---@return boolean allowed
---@return string|nil reason
function BETTERUI.Vendor.AuthorizeInventoryAction(actionType, bagId, slotIndex, vendorInstance)
	local policy = BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy
	if policy and policy.CanVendorAction then
		local context = nil
		if vendorInstance and vendorInstance.CanAfford then
			context = {
				canAfford = function(cost)
					return vendorInstance:CanAfford(cost)
				end,
			}
		end
		return policy.CanVendorAction(actionType, bagId, slotIndex, context)
	end

	if not bagId or slotIndex == nil then
		return false, "no_item"
	end
	local stackSize = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
	if stackSize <= 0 then
		return false, "no_item"
	end
	return true
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

---@type BetterUIModuleSetupHook
function BETTERUI.Vendor.Setup()
	BETTERUI.CIM.RegisterModuleAccessors(Vendor, "Vendor")
	BETTERUI.CIM.TryRegisterModulePanel(Vendor, "Vendor", "Vendor", "Vendor")
	BETTERUI.Vendor.Init()
end
