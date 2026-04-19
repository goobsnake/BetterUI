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

local MODULE_NAME = "Banking"
local MODULE_OWNER_FILE = "Modules/Banking/Module.lua"
local ROOT_CONTRACT_INIT_OWNER = MODULE_OWNER_FILE
local ROOT_CONTRACT_SETUP_OWNER = MODULE_OWNER_FILE

Banking.ARCHETYPE = "runtime-coordinator"
---@type BetterUIModuleRootContract
Banking.ROOT_CONTRACT = {
	name = MODULE_NAME,
	archetype = Banking.ARCHETYPE,
	initOwner = ROOT_CONTRACT_INIT_OWNER,
	setupOwner = ROOT_CONTRACT_SETUP_OWNER,
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

local function EnsureBankingSetupContracts()
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
end

---@type BetterUIModuleSetupHook
function Banking.Setup()
	EnsureBankingSetupContracts()
	Banking.Init()
end
