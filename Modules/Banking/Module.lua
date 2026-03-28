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

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
BETTERUI.CIM.RegisterModuleAccessors("Banking")

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
