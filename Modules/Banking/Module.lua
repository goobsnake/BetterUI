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
}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Banking, "Banking")

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

---@type BetterUIModuleSetupHook
function Banking.Setup()
	BETTERUI.CIM.RegisterModuleAccessors(Banking, "Banking")
	if Banking._narrationLabelsRegistered ~= true
		and BETTERUI.CIM
		and BETTERUI.CIM.Narration
		and BETTERUI.CIM.Narration.RegisterBankingModeLabels
	then
		BETTERUI.CIM.Narration.RegisterBankingModeLabels({
			[Banking.LIST_DEPOSIT] = rawget(_G, "SI_BANK_DEPOSIT"),
			[Banking.LIST_WITHDRAW] = rawget(_G, "SI_BANK_WITHDRAW"),
		})
		Banking._narrationLabelsRegistered = true
	end
	BETTERUI.CIM.TryRegisterModulePanel(Banking, "Banking", "Bank", "Banking")
	Banking.Init()
end
