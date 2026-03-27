--[[
File: Modules/Banking/Module.lua
Purpose: Entry point and settings configuration for the Banking module.
Authors: BUI Team
Last Modified: 2026-01-16

Registers the Banking panel in the BetterUI addon settings and provides font
descriptor factories for the name and column rendering.
]]


--- @class BetterUIBankingModule
--- @field FONT_CHOICES table
--- @field FONT_VALUES table
--- @field FONTSTYLE_CHOICES table
--- @field FONTSTYLE_VALUES table
--- @field DEFAULTS table

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

--- Settings Accessor Protocol:
--- GetSetting(key) -> value: Returns saved setting value or default
--- SetSetting(key, value): Persists setting and triggers change notification
---
--- Retrieves a setting value for the Banking module.
--- @param key string The setting key.
--- @return any The setting value or module default.
function BETTERUI.Banking.GetSetting(key)
	if key == nil then return nil end
	local defaultValue = BETTERUI.Defaults and BETTERUI.Defaults.GetDefault and BETTERUI.Defaults.GetDefault("Banking", key) or nil
	return BETTERUI.GetSetting("Banking", key, defaultValue)
end

--- Sets a setting value for the Banking module.
--- @param key string The setting key.
--- @param value any The value to set.
function BETTERUI.Banking.SetSetting(key, value)
	BETTERUI.SetSetting("Banking", key, value)
end

-- Settings registration moved to Banking/Settings/SettingsPanel.lua

--- Initializes defaults and migrates legacy settings for the Banking module.
---
--- INIT CONTRACT: This function implements the standard InitModule signature.
--- It is called by BETTERUI.ModuleOptions() via pcall with only m_options.
---
--- Standard InitModule Signature (consistent across all modules):
---   @param m_options table|nil The raw settings table to be initialized
---   @return table The modified options table with default values applied
---
--- Wrapper Function (caller in BetterUI.lua):
---   BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
---
function BETTERUI.Banking.InitModule(m_options)
	m_options = m_options or {}
	---@cast m_options table
	local defaults = BETTERUI.Banking.DEFAULTS
	local fallbackDefaults = {
		showIconEnchantment = true,
		showIconSetGear = true,
		showIconUnboundItem = true,
		showIconResearchableTrait = true,
		showIconUnknownRecipe = true,
		showIconUnknownBook = true,
		enableCarousel = true,
	}

	m_options = BETTERUI.CIM.InitModuleDefaults("Banking", m_options, defaults, fallbackDefaults)

	return m_options
end

--- Lifecycle hook: registers settings and starts the Banking class.
--- @return nil
function BETTERUI.Banking.Setup()
	BETTERUI.Banking.Settings.RegisterPanel("Bank", "Banking")
	BETTERUI.Banking.Init()
end
