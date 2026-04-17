--[[
File: Modules/Banking/Module.lua
Purpose: Entry point and settings configuration for the Banking module.

Registers the Banking panel in the BetterUI addon settings and provides font
descriptor factories for the name and column rendering.
]]


-- Module initialization
---@type BetterUIModuleRoot
BETTERUI.Banking = BETTERUI.Banking or {}
local Banking = BETTERUI.Banking

Banking.ARCHETYPE = "runtime-coordinator"
---@type BetterUIModuleRootContract
Banking.ROOT_CONTRACT = {
	name = "Banking",
	archetype = Banking.ARCHETYPE,
	initOwner = "Modules/Banking/Module.lua",
	setupOwner = "Modules/Banking/Module.lua",
	runtimeOwner = "Modules/Banking/Banking.lua + Modules/Banking/Core/ + Modules/Banking/Scene/ + Modules/Banking/UI/",
	settingsOwner = "Modules/Banking/Module.lua + Modules/Banking/Settings/",
	notes = "Module.lua owns Init/Setup wiring, delegates module-setting defaults to DefaultsRegistry, and uses shared CIM font defaults while runtime flow lives under Banking.lua, Core/, Scene/, and UI/.",
}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
BETTERUI.CIM.RegisterModuleAccessors("Banking")

--- Initializes defaults and migrates legacy settings for the Banking module.
---
--- INIT CONTRACT: This function implements the standard InitModule signature.
--- It is called by BETTERUI.ModuleOptions() via pcall with only m_options.
---
--- Standard InitModule Signature (consistent across all modules):
---
--- Wrapper Function (caller in BetterUI.lua):
---   BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
---
---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Initialized options with defaults applied
---@type BetterUIModuleInitHook
function Banking.InitModule(m_options)
	m_options = m_options or {}
	---@cast m_options BetterUIModuleOptions
	local defaults = Banking.DEFAULTS
	local moduleDefaults = BETTERUI.Defaults and BETTERUI.Defaults.GetModuleDefaults
		and BETTERUI.Defaults.GetModuleDefaults("Banking") or nil

	m_options = BETTERUI.CIM.InitModuleDefaults("Banking", m_options, defaults, moduleDefaults)

	return m_options
end

--- Lifecycle hook: registers settings and starts the Banking class.
---@type BetterUIModuleSetupHook
function Banking.Setup()
	Banking.Settings.RegisterPanel("Bank", "Banking")
	Banking.Init()
end
