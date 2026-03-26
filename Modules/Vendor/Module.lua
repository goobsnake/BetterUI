--[[
File: Modules/Vendor/Module.lua
Purpose: Entry point and settings configuration for the Vendor module.
Authors: BUI Team
Last Modified: 2026-03-14

Registers the Vendor panel in the BetterUI addon settings and provides font
descriptor factories for the name and column rendering.
]]


-- Module initialization
BETTERUI.Vendor = BETTERUI.Vendor or {}

-- Font choices/values now use CIM shared definitions (see CIM/Core/FontDefinitions.lua)
BETTERUI.Vendor.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
BETTERUI.Vendor.FONT_VALUES = BETTERUI.CIM.Font.VALUES
BETTERUI.Vendor.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
BETTERUI.Vendor.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
BETTERUI.Vendor.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS

-- Font descriptor closures via CIM factory (see CIM/Core/FontDefinitions.lua)
do
    local descriptors = BETTERUI.CIM.Font.CreateModuleDescriptors("Vendor")
    BETTERUI.Vendor.GetNameFontDescriptor = descriptors.name
    BETTERUI.Vendor.GetColumnFontDescriptor = descriptors.column
end

--- Retrieves a setting value for the Vendor module.
--- @param key string The setting key.
--- @return any The setting value or nil.
function BETTERUI.Vendor.GetSetting(key)
	return BETTERUI.GetSetting("Vendor", key)
end

--- Sets a setting value for the Vendor module.
--- @param key string The setting key.
--- @param value any The value to set.
function BETTERUI.Vendor.SetSetting(key, value)
	if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return end
	if not BETTERUI.Settings.Modules["Vendor"] then
		BETTERUI.Settings.Modules["Vendor"] = {}
	end
	BETTERUI.Settings.Modules["Vendor"][key] = value
end

--[[
Function: BETTERUI.Vendor.InitModule
Initializes default values and migrates legacy settings for the Vendor module.
param: m_options (table) - The raw settings table for this module.
return: table - The initialized and migrated settings table.
]]
--- @param m_options any Description
--- @return any Description
function BETTERUI.Vendor.InitModule(m_options)
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
--- @return number totalValue Total gold value of all junk items
--- @return number itemCount Number of junk items
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
--- @return any Description
function BETTERUI.Vendor.Setup()
	BETTERUI.Vendor.Settings.RegisterPanel("Vendor", "Vendor")
	BETTERUI.Vendor.Init()
end
