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

--[[
Function: BETTERUI.Vendor.InitModule
Initializes defaults and migrates legacy settings for the Vendor module.

INIT CONTRACT: This function implements the standard InitModule signature.
It is called by BETTERUI.ModuleOptions() via pcall with only m_options.

Standard InitModule Signature (consistent across all modules):
  @param m_options table|nil The raw settings table to be initialized
  @return table The modified options table with default values applied

Wrapper Function (caller in BetterUI.lua):
  BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)

param: m_options (table|nil) - The raw settings table for this module.
return: table - The initialized and migrated settings table.
]]
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

--- Placeholder: Gets junk sell value summary for batch sell UX.
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

--[[
Function: BETTERUI.Vendor.Setup
Lifecycle hook to setup the Vendor module.
References: Called by BETTERUI.LoadModules() in BetterUI.lua.
]]
function BETTERUI.Vendor.Setup()
	BETTERUI.Vendor.Settings.RegisterPanel("Vendor", "Vendor")
	BETTERUI.Vendor.Init()
end
