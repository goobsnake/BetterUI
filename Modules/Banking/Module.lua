-- Banking module entrypoint and settings registration.

---@type BetterUIModuleRoot
BETTERUI.Banking = BETTERUI.Banking or {}
local Banking = BETTERUI.Banking
local ARCHETYPES = BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES or {}
local RUNTIME_COORDINATOR = ARCHETYPES.RUNTIME_COORDINATOR or "runtime-coordinator"
local MODULE_NAME = "Banking"

---@type BetterUIModuleArchetypeRuntimeCoordinator
Banking.ARCHETYPE = RUNTIME_COORDINATOR
---@type BetterUIModuleRootContract
Banking.ROOT_CONTRACT = {
	name = MODULE_NAME,
	archetype = Banking.ARCHETYPE,
	init = true,
	setup = true,
}

-- Wire shared settings statics before runtime accessors register in Setup().
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

	m_options = BETTERUI.CIM.InitModuleDefaults(MODULE_NAME, m_options, defaults, moduleDefaults)

	return m_options
end

---@type BetterUIModuleSetupHook
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
