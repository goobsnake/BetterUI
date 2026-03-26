--[[
File: Modules/Banking/Module.lua
Purpose: Entry point and settings configuration for the Banking module.
Authors: BUI Team
Last Modified: 2026-01-16

Registers the Banking panel in the BetterUI addon settings and provides font
descriptor factories for the name and column rendering.
]]


-- Module initialization
BETTERUI.Banking = BETTERUI.Banking or {}

-- Font choices/values now use CIM shared definitions (see CIM/Core/FontDefinitions.lua)
BETTERUI.Banking.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
BETTERUI.Banking.FONT_VALUES = BETTERUI.CIM.Font.VALUES
BETTERUI.Banking.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
BETTERUI.Banking.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
BETTERUI.Banking.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS

-- Font descriptor closures via CIM factory (see CIM/Core/FontDefinitions.lua)
do
    local descriptors = BETTERUI.CIM.Font.CreateModuleDescriptors("Banking")
    BETTERUI.Banking.GetNameFontDescriptor = descriptors.name
    BETTERUI.Banking.GetColumnFontDescriptor = descriptors.column
end

--- Retrieves a setting value for the Banking module.
--- @param key string The setting key.
--- @return any The setting value or nil.
function BETTERUI.Banking.GetSetting(key)
	return BETTERUI.GetSetting("Banking", key)
end

--- Sets a setting value for the Banking module.
--- @param key string The setting key.
--- @param value any The value to set.
function BETTERUI.Banking.SetSetting(key, value)
	if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return end
	if not BETTERUI.Settings.Modules["Banking"] then
		BETTERUI.Settings.Modules["Banking"] = {}
	end
	BETTERUI.Settings.Modules["Banking"][key] = value
end

-- Settings registration moved to Banking/Settings/SettingsPanel.lua

--- Initializes defaults and migrates legacy settings for the Banking module.
--- @param m_options table The raw settings table for this module.
--- @return table The initialized and migrated settings table.
function BETTERUI.Banking.InitModule(m_options)
	-- Apply centralized defaults from DefaultsRegistry
	if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
		m_options = BETTERUI.Defaults.ApplyModuleDefaults("Banking", m_options)
	else
		-- Fallback if DefaultsRegistry not loaded yet
		if m_options["showIconEnchantment"] == nil then m_options["showIconEnchantment"] = true end
		if m_options["showIconSetGear"] == nil then m_options["showIconSetGear"] = true end
		if m_options["showIconUnboundItem"] == nil then m_options["showIconUnboundItem"] = true end
		if m_options["showIconResearchableTrait"] == nil then m_options["showIconResearchableTrait"] = true end
		if m_options["showIconUnknownRecipe"] == nil then m_options["showIconUnknownRecipe"] = true end
		if m_options["showIconUnknownBook"] == nil then m_options["showIconUnknownBook"] = true end
		if m_options["enableCarousel"] == nil then m_options["enableCarousel"] = true end
	end

	-- Font customization - Name column settings
	local defaults = BETTERUI.Banking.DEFAULTS
	m_options["nameFont"] = m_options["nameFont"] or defaults.nameFont
	m_options["nameFontSize"] = m_options["nameFontSize"] or defaults.nameFontSize
	m_options["nameFontStyle"] = m_options["nameFontStyle"] or defaults.nameFontStyle

	-- Font customization - Other columns settings (Type, Trait, Stat, Value)
	m_options["columnFont"] = m_options["columnFont"] or defaults.columnFont
	m_options["columnFontSize"] = m_options["columnFontSize"] or defaults.columnFontSize
	m_options["columnFontStyle"] = m_options["columnFontStyle"] or defaults.columnFontStyle

	-- Migrate old settings to new format if present
	if m_options["font"] and not m_options["nameFont"] then
		m_options["nameFont"] = m_options["font"]
		m_options["columnFont"] = m_options["font"]
	end
	if m_options["skinSize"] and not m_options["nameFontSize"] then
		m_options["nameFontSize"] = m_options["skinSize"]
		m_options["columnFontSize"] = m_options["skinSize"]
	end

	if m_options["fontStyle"] and not m_options["nameFontStyle"] then
		local oldStyle = m_options["fontStyle"]
		if type(oldStyle) == "number" then
			local styleMap = {
				[0] = "",
				[1] = "outline",
				[2] = "thick-outline",
				[3] = "shadow",
				[4] = "soft-shadow-thick",
				[5] = "soft-shadow-thin",
			}
			oldStyle = styleMap[oldStyle] or defaults.nameFontStyle
		end
		m_options["nameFontStyle"] = oldStyle
		m_options["columnFontStyle"] = oldStyle
	end

	-- Migration: Western-only fonts -> Localized font (for CJK/Russian support)
	-- Only migrate non-English users; English users keep their font selections
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

--- Lifecycle hook: registers settings and starts the Banking class.
function BETTERUI.Banking.Setup()
	BETTERUI.Banking.Settings.RegisterPanel("Bank", "Banking")
	BETTERUI.Banking.Init()
end
