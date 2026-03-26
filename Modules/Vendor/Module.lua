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
Description: Initializes default values and migrates legacy settings for the Vendor module.
Rationale: Ensures all necessary settings exist and converts old formats.
Mechanism:
  - Sets defaults for icons and carousel.
  - Migrates `nameFont` / `nameFontSize` from older generic keys.
  - Converts string sizes ("Small", "Medium") to integer pixels.
  - Converts numeric font styles to string identifiers ("outline").
param: m_options (table) - The raw settings table for this module.
return: table - The initialized and migrated settings table.
]]
function BETTERUI.Vendor.InitModule(m_options)
	-- Apply centralized defaults from DefaultsRegistry
	if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
		m_options = BETTERUI.Defaults.ApplyModuleDefaults("Vendor", m_options)
	else
		-- Fallback if DefaultsRegistry not loaded yet
		if m_options["showIconEnchantment"] == nil then m_options["showIconEnchantment"] = true end
		if m_options["showIconSetGear"] == nil then m_options["showIconSetGear"] = true end
		if m_options["showIconUnboundItem"] == nil then m_options["showIconUnboundItem"] = true end
		if m_options["showIconResearchableTrait"] == nil then m_options["showIconResearchableTrait"] = true end
		if m_options["showIconUnknownRecipe"] == nil then m_options["showIconUnknownRecipe"] = true end
		if m_options["showIconUnknownBook"] == nil then m_options["showIconUnknownBook"] = true end
		if m_options["enableCarousel"] == nil then m_options["enableCarousel"] = true end
		if m_options["enableBatchJunkSell"] == nil then m_options["enableBatchJunkSell"] = true end
	end

	-- Font customization - Name column settings
	local defaults = BETTERUI.Vendor.DEFAULTS
	m_options["nameFont"] = m_options["nameFont"] or defaults.nameFont
	m_options["nameFontSize"] = m_options["nameFontSize"] or defaults.nameFontSize
	m_options["nameFontStyle"] = m_options["nameFontStyle"] or defaults.nameFontStyle

	-- Font customization - Other columns settings (Type, Trait, Stat, Value)
	m_options["columnFont"] = m_options["columnFont"] or defaults.columnFont
	m_options["columnFontSize"] = m_options["columnFontSize"] or defaults.columnFontSize
	m_options["columnFontStyle"] = m_options["columnFontStyle"] or defaults.columnFontStyle

	-- Migration: Western-only fonts -> Localized font (for CJK/Russian support)
	local currentLang = GetCVar("language.2") or "en"
	local isEnglish = (currentLang == "en")

	if not isEnglish then
		local westernOnlyFonts = {
			["EsoUI/Common/Fonts/FTN57.otf"] = true,
			["EsoUI/Common/Fonts/FTN47.otf"] = true,
			["EsoUI/Common/Fonts/FTN87.otf"] = true,
			["EsoUI/Common/Fonts/Univers57.otf"] = true,
			["EsoUI/Common/Fonts/Univers67.otf"] = true,
			["EsoUI/Common/Fonts/ProseAntiquePSMT.otf"] = true,
			["EsoUI/Common/Fonts/Handwritten_Bold.otf"] = true,
			["EsoUI/Common/Fonts/TrajanPro-Regular.otf"] = true,
			["EsoUI/Common/Fonts/Skyrim_Handwritten.otf"] = true,
			["EsoUI/Common/Fonts/consola.otf"] = true,
		}
		if m_options["nameFont"] and westernOnlyFonts[m_options["nameFont"]] then
			m_options["nameFont"] = "$(GAMEPAD_MEDIUM_FONT)"
		end
		if m_options["columnFont"] and westernOnlyFonts[m_options["columnFont"]] then
			m_options["columnFont"] = "$(GAMEPAD_MEDIUM_FONT)"
		end
	end

	-- Persisted font sizes may exceed current slider caps from prior versions.
	if BETTERUI.CIM and BETTERUI.CIM.Font and BETTERUI.CIM.Font.NormalizeModuleFontSettings then
		BETTERUI.CIM.Font.NormalizeModuleFontSettings(m_options, defaults)
	end

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
Description: Lifecycle hook to setup the Vendor module.
Rationale: Called by the core when the module should initialize its keybinds, settings, and UI.
Mechanism: Calls Settings.RegisterPanel to register the settings menu,
           then calls BETTERUI.Vendor.Init to create the vendor class instance.
References: Called by BETTERUI.LoadModules() in BetterUI.lua.
]]
function BETTERUI.Vendor.Setup()
	BETTERUI.Vendor.Settings.RegisterPanel("Vendor", "Vendor")
	BETTERUI.Vendor.Init()
end
