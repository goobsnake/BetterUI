---@class BETTERUI

local LAM = LibAddonMenu2
local ZO_STRLOWER = rawget(_G, "zo_strlower")

local function GetStringByName(globalName)
	local stringId = rawget(_G, globalName)
	if stringId ~= nil then
		return GetString(stringId)
	end
	return globalName
end

if BETTERUI == nil then BETTERUI = {} end

-- Bootstrap error channel: BetterUI.lua loads before CIM Utilities, which
-- replaces this with the full ungated implementation. Kept minimal so error
-- reporting works even if CIM never loads.
if BETTERUI.DebugError == nil then
	function BETTERUI.DebugError(str)
		local chatPrint = rawget(_G, "d")
		if type(chatPrint) == "function" then
			chatPrint("|c0066ff[BETTERUI]|r " .. tostring(str))
		end
	end
end

local SAVED_VARS_SCHEMA_VERSION = 2.89

---@class ModuleRegistryEntry
---@field name string The unique name of the module (used for settings keys)
---@field namespace string The namespace key in BETTERUI table
---@field required boolean|nil Whether this module is required (always enabled)
---@field dependsOnCIM boolean|nil Whether the module requires the CIM shared platform
---@field condition function|nil Optional condition function that must return true to load
---@field preSetup function|nil Optional function to call before Setup (e.g., for hooks)
---@field depends string|nil Name of another module that must be enabled for this to load

---@type ModuleRegistryEntry[]
local MODULE_REGISTRY = {
	-- Core infrastructure (required by other modules)
	{ name = "CIM", namespace = "CIM", required = true },

	-- CIM-dependent modules (require CIM to be enabled)
	{
		name = "Inventory",
		namespace = "Inventory",
		dependsOnCIM = true,
		preSetup = function()
			if BETTERUI.Inventory and BETTERUI.Inventory.HookDestroyItem then
				BETTERUI.Inventory.HookDestroyItem()
			end
			if BETTERUI.Inventory and BETTERUI.Inventory.HookActionDialog then
				BETTERUI.Inventory.HookActionDialog()
			end
			return true
		end
	},
	{ name = "Banking", namespace = "Banking", dependsOnCIM = true },
	{ name = "Vendor", namespace = "Vendor", dependsOnCIM = true },
	{ name = "TradingHouse", namespace = "TradingHouse", dependsOnCIM = true },
	{ name = "Companions", namespace = "Companions", dependsOnCIM = true },

	-- CIM-dependent interface and feature modules
	{ name = "Writs", namespace = "Writs" },
	{ name = "GeneralInterface", namespace = "GeneralInterface", dependsOnCIM = true },
	{
		name = "Nameplates",
		namespace = "Nameplates",
		dependsOnCIM = true,
	},
	{ name = "ResourceOrbFrames", namespace = "ResourceOrbFrames", dependsOnCIM = true },
}

local function ModuleDependsOnCIM(moduleName)
	for _, entry in ipairs(MODULE_REGISTRY) do
		if entry.name == moduleName then
			return entry.dependsOnCIM == true
		end
	end

	return false
end

BETTERUI.name = "BetterUI"
BETTERUI.version = "3.06"

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Banking = BETTERUI.Banking or {}
BETTERUI.Vendor = BETTERUI.Vendor or {}
BETTERUI.TradingHouse = BETTERUI.TradingHouse or {}
BETTERUI.Companions = BETTERUI.Companions or {}
BETTERUI.Writs = BETTERUI.Writs or {}
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.GeneralInterface = BETTERUI.GeneralInterface or {}
BETTERUI.Nameplates = BETTERUI.Nameplates or {}
BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}

BETTERUI.GenericHeader = BETTERUI.GenericHeader or {}
BETTERUI.GenericFooter = BETTERUI.GenericFooter or {}
BETTERUI.Interface = BETTERUI.Interface or {}

---@type userdata
BETTERUI.WindowManager = GetWindowManager()
---@type userdata
BETTERUI.EventManager = GetEventManager()

BETTERUI.ResearchTraits = BETTERUI.ResearchTraits or {}

-- Default settings structure
BETTERUI.DefaultSettings = {
	firstInstall = true,
	useAccountWide = false,
	Modules = {}
}


--- Update CIM enabled state from dependent module settings.
function BETTERUI.UpdateCIMState()
	local shouldEnable = false
	for _, entry in ipairs(MODULE_REGISTRY) do
		if entry.dependsOnCIM and BETTERUI.GetModuleEnabled(entry.name) then
			shouldEnable = true
			break
		end
	end
	BETTERUI.SetSetting("CIM", "m_enabled", shouldEnable)
end

---@class ModuleToggleBlueprint
---@field moduleName string
---@field nameStringId string
---@field tooltipStringId string
---@field updatesCIM boolean|nil

---@type ModuleToggleBlueprint[]
local MODULE_TOGGLE_BLUEPRINTS = {
	{ moduleName = "Banking", nameStringId = "SI_BETTERUI_ENABLE_BANKING", tooltipStringId = "SI_BETTERUI_ENABLE_BANKING_TOOLTIP", updatesCIM = true },
	{ moduleName = "Vendor", nameStringId = "SI_BETTERUI_ENABLE_VENDOR", tooltipStringId = "SI_BETTERUI_ENABLE_VENDOR_TOOLTIP", updatesCIM = true },
	{ moduleName = "Companions", nameStringId = "SI_BETTERUI_ENABLE_COMPANIONS", tooltipStringId = "SI_BETTERUI_ENABLE_COMPANIONS_TOOLTIP", updatesCIM = true },
	{ moduleName = "TradingHouse", nameStringId = "SI_BETTERUI_ENABLE_TRADING_HOUSE", tooltipStringId = "SI_BETTERUI_ENABLE_TRADING_HOUSE_TOOLTIP", updatesCIM = true },
	{ moduleName = "GeneralInterface", nameStringId = "SI_BETTERUI_ENABLE_TOOLTIPS", tooltipStringId = "SI_BETTERUI_ENABLE_TOOLTIPS_TOOLTIP", updatesCIM = true },
	{ moduleName = "Nameplates", nameStringId = "SI_BETTERUI_NAMEPLATES_ENABLED", tooltipStringId = "SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP", updatesCIM = true },
	{ moduleName = "Inventory", nameStringId = "SI_BETTERUI_ENABLE_INVENTORY", tooltipStringId = "SI_BETTERUI_ENABLE_INVENTORY_TOOLTIP", updatesCIM = true },
	{ moduleName = "ResourceOrbFrames", nameStringId = "SI_BETTERUI_ENABLE_ORBS", tooltipStringId = "SI_BETTERUI_ENABLE_ORBS_TOOLTIP" },
	{ moduleName = "Writs", nameStringId = "SI_BETTERUI_ENABLE_WRITS", tooltipStringId = "SI_BETTERUI_ENABLE_WRITS_TOOLTIP" },
}

local function SetModuleToggleEnabled(moduleName, value, updatesCIM)
	BETTERUI.SetSetting(moduleName, "m_enabled", value)
	if updatesCIM then
		BETTERUI.UpdateCIMState()
	end
end

--- Normalizes a module toggle name for sorting by removing color codes, textures,
--- whitespace, and language-specific "Enable" prefixes.
--- @param name string|nil The raw toggle name to normalize
--- @return string normalized The normalized sort key
local function NormalizeModuleToggleSortName(name)
	if type(name) ~= "string" then
		return ""
	end

	local normalized = name
	normalized = normalized:gsub("|c%x%x%x%x%x%x", "")
	normalized = normalized:gsub("|r", "")
	normalized = normalized:gsub("|t[^|]+|t", "")
	normalized = normalized:gsub("^%s+", "")
	normalized = normalized:gsub("%s+$", "")

	-- Sort by the feature wording after "Enable ..." for consistency.
	normalized = normalized:gsub("^Enable%s+", "")
	normalized = normalized:gsub("^Activer%s+", "")
	normalized = normalized:gsub("^Activar%s+", "")
	normalized = normalized:gsub("^Aktivieren%s+", "")
	normalized = normalized:gsub("^Включить%s+", "")
	normalized = normalized:gsub("^启用", "")
	normalized = normalized:gsub("^有効にする%s*", "")

	if ZO_STRLOWER then
		return ZO_STRLOWER(normalized)
	end
	return string.lower(normalized)
end

local function BuildModuleToggleOptions()
	local moduleToggleOptions = {}

	for _, blueprint in ipairs(MODULE_TOGGLE_BLUEPRINTS) do
		local moduleName = blueprint.moduleName
		local updatesCIM = blueprint.updatesCIM
		if updatesCIM == nil then
			updatesCIM = ModuleDependsOnCIM(moduleName)
		end
		local toggleName = GetStringByName(blueprint.nameStringId)
		local tooltip = GetStringByName(blueprint.tooltipStringId)

		moduleToggleOptions[#moduleToggleOptions + 1] = {
			type = "checkbox",
			name = toggleName,
			tooltip = tooltip,
			getFunc = function()
				return BETTERUI.GetModuleEnabled(moduleName)
			end,
			setFunc = function(value)
				SetModuleToggleEnabled(moduleName, value, updatesCIM)
			end,
			width = "full",
			requiresReload = true,
		}
	end

	for _, control in ipairs(moduleToggleOptions) do
		control.sortKey = NormalizeModuleToggleSortName(control.name)
	end

	table.sort(moduleToggleOptions, function(left, right)
		if left.sortKey == right.sortKey then
			return tostring(left.name) < tostring(right.name)
		end
		return left.sortKey < right.sortKey
	end)

	for _, control in ipairs(moduleToggleOptions) do
		control.sortKey = nil
	end

	return moduleToggleOptions
end

local function InitializeRegisteredModuleSettings()
	for _, entry in ipairs(MODULE_REGISTRY) do
		local moduleName, moduleNamespace = entry.name, BETTERUI[entry.namespace]
		if moduleNamespace then
			local moduleSettings = BETTERUI.EnsureModuleSettings(moduleName)
			local moduleInitResult = BETTERUI.ModuleOptions(moduleNamespace, moduleSettings, moduleName)
			if not moduleInitResult then
				BETTERUI.DebugError("[Warning] Skipping broken module: " .. moduleName)
			end
		end
	end
end

function BETTERUI.InitModuleOptions()
	local panelData = BETTERUI.Init_ModulePanel("Master", GetStringByName("SI_BETTERUI_MASTER_SETTINGS_TITLE"))

	local optionsTable = {
		{
			type = "header",
			name = GetStringByName("SI_BETTERUI_MASTER_SETTINGS_HEADER"),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetStringByName("SI_BETTERUI_ENABLE_GLOBAL_SETTINGS"),
			tooltip = GetStringByName("SI_BETTERUI_ENABLE_GLOBAL_TOOLTIP"),
			getFunc = function() return BETTERUI.SavedVars.useAccountWide end,
			setFunc = function(value)
				BETTERUI.SavedVars.useAccountWide = value
			end,
			width = "full",
			requiresReload = true,
		},
	}

	local moduleToggleOptions = BuildModuleToggleOptions()

	for _, control in ipairs(moduleToggleOptions) do
		table.insert(optionsTable, control)
	end

	local cimDebug = BETTERUI.CIM and BETTERUI.CIM.Debug
	local showDeveloperSettings = cimDebug
		and cimDebug.ShouldShowDeveloperSettings
		and cimDebug.ShouldShowDeveloperSettings()
		or false

	if showDeveloperSettings then
		local featureFlags = BETTERUI.CIM and BETTERUI.CIM.FeatureFlags
		local allFlags = featureFlags and featureFlags.GetAllFlags and featureFlags.GetAllFlags()
		if allFlags then
			local flagControls = {
				{
					type = "header",
					name = GetStringByName("SI_BETTERUI_FEATURE_FLAGS_HEADER"),
					width = "full",
				},
				{
					type = "description",
					text = GetStringByName("SI_BETTERUI_FEATURE_FLAGS_DESC"),
					width = "full",
				},
			}

			local sortedFlags = {}
			for name in pairs(allFlags) do
				table.insert(sortedFlags, name)
			end
			table.sort(sortedFlags)

			for _, flagName in ipairs(sortedFlags) do
				local flagData = allFlags[flagName]
				local def = (flagData and flagData.definition) or {}
				table.insert(flagControls, {
					type = "checkbox",
					name = def.name or flagName,
					tooltip = (def.description or flagName) .. " | Version " .. (def.version or "?"),
					getFunc = function()
						return BETTERUI.CIM.FeatureFlags.IsEnabled(flagName)
					end,
					setFunc = function(value)
						BETTERUI.CIM.FeatureFlags.SetEnabled(flagName, value)
					end,
					width = "full",
					requiresReload = (flagName == "ENHANCED_TOOLTIPS"),
				})
			end

			for _, control in ipairs(flagControls) do
				table.insert(optionsTable, control)
			end
		end
	end

	table.insert(optionsTable, {
		type = "divider",
		width = "full",
	})
	table.insert(optionsTable, {
		type = "button",
		name = GetStringByName("SI_BETTERUI_MASTER_RESET_ALL"),
		tooltip = GetStringByName("SI_BETTERUI_MASTER_RESET_ALL_TOOLTIP"),
		func = function()
			local settingsApi = BETTERUI.CIM and BETTERUI.CIM.Settings
			if settingsApi and settingsApi.ResetAllSettingsToDefaults then
				settingsApi.ResetAllSettingsToDefaults()
			end
		end,
		width = "full",
	})

	LAM:RegisterAddonPanel("BETTERUI_" .. "Modules", panelData)
	LAM:RegisterOptionControls("BETTERUI_" .. "Modules", optionsTable)
end

--- Wrap module initialization and isolate failures.
---@param m_namespace table Module namespace.
---@param m_options table Module settings table.
---@param moduleName string|nil Module name for diagnostics.
---@return table|nil Module namespace table on success, nil on failure.
function BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
	local moduleContract = type(m_namespace) == "table" and type(m_namespace.ROOT_CONTRACT) == "table" and m_namespace.ROOT_CONTRACT or nil
	local shouldCallInit = moduleContract == nil or moduleContract.init ~= false
	if shouldCallInit then
		if not (m_namespace and m_namespace.InitModule) then
			local name = moduleName or "unknown"
			BETTERUI.DebugError("[Validation] Module has no InitModule: " .. name)
			if moduleName then
				BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
				BETTERUI._sessionDisabledModules[moduleName] = true
				BETTERUI.DebugError("[Recovery] Module skipped for this session (will retry on reload): " .. name)
			end
			return nil
		end
		local success, result = pcall(m_namespace.InitModule, m_options)
		if success then
			if type(result) == "table" and moduleName and result ~= m_options then
				BETTERUI.Settings = BETTERUI.Settings or {}
				BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
				BETTERUI.Settings.Modules[moduleName] = result
			end
		else
			local name = moduleName or "unknown"
			BETTERUI.DebugError("[Error] InitModule failed for " .. name .. ": " .. tostring(result))
			if moduleName then
				BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
				BETTERUI._sessionDisabledModules[moduleName] = true
				BETTERUI.DebugError("[Recovery] Module skipped for this session (will retry on reload): " .. name)
			end
			return nil
		end
	end
	return m_namespace
end

local function RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
	if moduleNamespace then
		moduleNamespace._setupComplete = nil
	end

	if type(BETTERUI.SetModuleSessionDisabled) == "function" then
		BETTERUI.SetModuleSessionDisabled(moduleName, true)
	else
		BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
		BETTERUI._sessionDisabledModules[moduleName] = true
	end

	if failedModules then
		failedModules._seen = failedModules._seen or {}
		if not failedModules._seen[moduleName] then
			failedModules._seen[moduleName] = true
			failedModules[#failedModules + 1] = moduleName
		end
	end
end
local function ValidateAndSetupModule(moduleName, moduleNamespace, failedModules)
	if not moduleNamespace then
		BETTERUI.Debug(string.format("[Validation] Module '%s' namespace is nil", moduleName))
		RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
		return false
	end

	-- Prevent double Setup (LAM:RegisterAddonPanel will crash with "Duplicate name")
	if moduleNamespace._setupComplete then return true end

	-- Validate using CIM interface validation if available
	local interfaces = BETTERUI.CIM and BETTERUI.CIM.Interfaces
	local validateFn = interfaces and interfaces.ValidateModule
	local moduleContract = type(moduleNamespace.ROOT_CONTRACT) == "table" and moduleNamespace.ROOT_CONTRACT or nil
	local shouldCallSetup = moduleContract == nil or moduleContract.setup ~= false
	if validateFn then
		local valid, err = validateFn(moduleNamespace, nil, moduleName)
		if not valid then
			BETTERUI.Debug(string.format("[Validation] Module '%s' failed validation: %s", moduleName, tostring(err)))
			RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
			return false
		end
	else
		-- Fallback: basic Setup check for modules that opt into setup.
		if shouldCallSetup and type(moduleNamespace.Setup) ~= "function" then
			BETTERUI.Debug(string.format("[Validation] Module '%s' has no Setup function", moduleName))
			RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
			return false
		end
	end

	if not shouldCallSetup then
		moduleNamespace._setupComplete = true
		return true
	end

	-- Wrap Setup in pcall so one module failure does not cascade into later modules.
	local success, setupResult, setupDetail = pcall(moduleNamespace.Setup)
	if not success then
		BETTERUI.DebugError(string.format("[Error] Setup() failed for '%s': %s", moduleName, tostring(setupResult)))
		RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
		return false
	end

	if setupResult == false then
		local detail = setupDetail ~= nil and tostring(setupDetail) or "setup returned false"
		BETTERUI.DebugError(string.format("[Error] Setup() returned false for '%s': %s", moduleName, detail))
		RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
		return false
	end
	moduleNamespace._setupComplete = true
	return true
end

local function ReportModuleSetupFailures(failedModules, contextLabel)
	if not failedModules or #failedModules == 0 then
		return false
	end

	BETTERUI.DebugError(string.format("[Recovery] Modules disabled after setup failure (%s): %s",
		contextLabel,
		table.concat(failedModules, ", ")))
	return true
end

local function DeepCopySettingsTable(source)
	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = DeepCopySettingsTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function LoadSavedVarsWithFallback(loaderName, loader)
	local ok, result = pcall(loader, ZO_SavedVars, "BetterUISavedVars", SAVED_VARS_SCHEMA_VERSION, nil, BETTERUI.DefaultSettings)
	if not ok then
		BETTERUI.DebugError(string.format("[SavedVars] %s failed, using defaults: %s", loaderName, tostring(result)))
	end
	-- On failure return an independent deep copy so SavedVars and GlobalVars
	-- never alias the same DefaultSettings table when both loaders fail.
	return ok and result or DeepCopySettingsTable(BETTERUI.DefaultSettings)
end

local function ShouldSetupKeyboardModeModule(entry)
	if entry.name == "CIM" then
		return false
	end

	if not BETTERUI.GetModuleEnabled(entry.name) then
		return false
	end

	if not BETTERUI[entry.namespace] then
		return false
	end

	return true
end

local function SetupKeyboardModeModules()
	local failedModules = {}
	local allModulesLoaded = true
	for _, entry in ipairs(MODULE_REGISTRY) do
		if ShouldSetupKeyboardModeModule(entry) then
			local setupSucceeded = ValidateAndSetupModule(entry.name, BETTERUI[entry.namespace], failedModules)
			if not setupSucceeded then
				allModulesLoaded = false
			end
		end
	end
	return allModulesLoaded, failedModules
end

---@param entry ModuleRegistryEntry The registry entry to evaluate
---@return boolean Whether the module should be loaded
local function ShouldLoadModule(entry)
	local moduleNamespace = BETTERUI[entry.namespace]

	if not moduleNamespace then
		return false
	end

	if entry.required then
		return true
	end

	if not BETTERUI.GetModuleEnabled(entry.name) then
		return false
	end

	if entry.condition and not entry.condition() then
		return false
	end

	if entry.depends and not BETTERUI.GetModuleEnabled(entry.depends) then
		return false
	end

	if entry.dependsOnCIM and not BETTERUI.GetModuleEnabled("CIM") then
		return false
	end

	return true
end

local function LoadConfiguredModules()
	local failedModules = {}
	local allModulesLoaded = true
	for _, entry in ipairs(MODULE_REGISTRY) do
		if ShouldLoadModule(entry) then
			local moduleLoaded = true
			local moduleNamespace = BETTERUI[entry.namespace]
			if entry.preSetup then
				local preSetupSucceeded, preSetupErr = pcall(entry.preSetup)
				if not preSetupSucceeded then
					BETTERUI.DebugError(string.format("[Error] preSetup() failed for '%s': %s", entry.name, tostring(preSetupErr)))
					RecordModuleSetupFailure(failedModules, entry.name, moduleNamespace)
					moduleLoaded = false
				end
			end
			if moduleLoaded then
				moduleLoaded = ValidateAndSetupModule(entry.name, moduleNamespace, failedModules)
			end
			if not moduleLoaded then
				allModulesLoaded = false
			end
		end
	end
	return allModulesLoaded, failedModules
end

--- Load enabled modules for active mode.
function BETTERUI.LoadModules()
	if BETTERUI._initialized then return true end

	BETTERUI.Debug("Initializing BETTERUI...")

	local researchCache = BETTERUI.CIM and BETTERUI.CIM.ResearchCache
	if researchCache and type(researchCache.RefreshResearchTraits) == "function" then
		researchCache.RefreshResearchTraits()
	end

	local allModulesLoaded, failedModules = LoadConfiguredModules()
	ReportModuleSetupFailures(failedModules, "load")

	BETTERUI.Debug("Finished! BETTERUI is loaded")
	BETTERUI._initialized = true
	return allModulesLoaded
end

---@param event number The event ID.
---@param addon string The name of the addon being loaded.
function BETTERUI.Initialize(event, addon)
	if addon ~= BETTERUI.name then return end

	BETTERUI.SavedVars = LoadSavedVarsWithFallback("ZO_SavedVars.New", ZO_SavedVars.New)
	BETTERUI.GlobalVars = LoadSavedVarsWithFallback("ZO_SavedVars.NewAccountWide", ZO_SavedVars.NewAccountWide)

	if BETTERUI.SavedVars.useAccountWide then
		BETTERUI.Settings = BETTERUI.GlobalVars
	else
		BETTERUI.Settings = BETTERUI.SavedVars
	end

	local runtimeSetup = BETTERUI.CIM and BETTERUI.CIM.RuntimeSetup
	if runtimeSetup and runtimeSetup.Apply then
		runtimeSetup.Apply(BETTERUI.Settings)
	end

	InitializeRegisteredModuleSettings()

	if BETTERUI.Settings.firstInstall then
		if BETTERUI.Defaults and BETTERUI.Defaults.ApplyFirstInstallDefaults then
			BETTERUI.Defaults.ApplyFirstInstallDefaults(BETTERUI.Settings)
		end
		BETTERUI.Debug("First install detected - applied default module states")
		BETTERUI.Settings.firstInstall = false
	end

	BETTERUI.EventManager:UnregisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED)

	BETTERUI.InitModuleOptions()
	BETTERUI.UpdateCIMState()

	local function SetupInitialModuleState()
		if IsInGamepadPreferredMode() then
			return BETTERUI.LoadModules()
		end

		BETTERUI._initialized = false
		local keyboardSetupSucceeded, failedModules = SetupKeyboardModeModules()
		ReportModuleSetupFailures(failedModules, "keyboard")
		return keyboardSetupSucceeded
	end

	local setupSucceeded = SetupInitialModuleState()

	if BETTERUI.Inventory and BETTERUI.Inventory.EnsureCompanionEquipPatched then
		BETTERUI.Inventory.EnsureCompanionEquipPatched()
	end
	return setupSucceeded
end

BETTERUI.EventManager:RegisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED, function(...) BETTERUI.Initialize(...) end)
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
	function(code, inGamepad)
		if inGamepad then
			BETTERUI.LoadModules()
		end
	end)
