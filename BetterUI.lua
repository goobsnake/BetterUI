--[[
File: BetterUI.lua
Purpose: Main entry point for the BetterUI addon.
         Handles module initialization and event registration.
Mechanics: Listens for EVENT_ADD_ON_LOADED to initialize itself.
           Manages the loading of sub-modules based on Gamepad mode.
           Runtime patches and settings migrations are delegated to CIM/RuntimeSetup.lua.
Author: BetterUI Team
Last Modified: 2026-02-08

-- NOTE(ARCHITECTURE): Modules are now registered declaratively via MODULE_REGISTRY.
-- This reduces boilerplate and makes the loading order and conditions explicit.
-- See the registry definition below for module configuration.
]]

---@class BETTERUI
--- Lifecycle: Addon load -> EVENT_ADD_ON_LOADED -> Initialize() -> LoadModules() -> per-module setup.

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

local SAVED_VARS_SCHEMA_VERSION = 2.89

---@class ModuleRegistryEntry
---@field name string The unique name of the module (used for settings keys)
---@field namespace string The namespace key in BETTERUI table
---@field required boolean|nil Whether this module is required (always enabled)
---@field condition function|nil Optional condition function that must return true to load
---@field preSetup function|nil Optional function to call before Setup (e.g., for hooks)
---@field depends string|nil Name of another module that must be enabled for this to load

--- Declarative module registry. Add new modules here to include them in loading.
--- The order of entries determines initialization order.
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
			-- Pre-Setup hooks (must run before Setup)
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

	-- Independent modules
	{ name = "Writs", namespace = "Writs" },
	{ name = "GeneralInterface", namespace = "GeneralInterface", dependsOnCIM = true },
	{
		name = "Nameplates",
		namespace = "Nameplates",
		depends = "GeneralInterface"
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

-- Core addon metadata
BETTERUI.name = "BetterUI"
BETTERUI.version = "3.06"

-- Module namespace tables
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

-- UI Component namespaces
BETTERUI.GenericHeader = BETTERUI.GenericHeader or {}
BETTERUI.GenericFooter = BETTERUI.GenericFooter or {}
BETTERUI.Interface = BETTERUI.Interface or {}

-- Engine helper references
---@type userdata
BETTERUI.WindowManager = GetWindowManager()
---@type userdata
BETTERUI.EventManager = GetEventManager()

-- Research traits cache (populated by CIM/Core/ResearchCache.lua)
BETTERUI.ResearchTraits = BETTERUI.ResearchTraits or {}

-- Default settings structure
BETTERUI.DefaultSettings = {
	firstInstall = true,
	useAccountWide = false,
	Modules = {}
}


--- Updates the Common Interface Module (CIM) state based on dependents.
---
--- Purpose: Ensures CIM is enabled if any registry-declared dependent module is active.
--- Mechanics: Checks the module registry for entries marked dependsOnCIM and turns
---            CIM on whenever any of those modules are enabled.
---            Updates the CIM m_enabled setting accordingly.
--- References: Called when toggling module settings in the options panel.
---
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
				BETTERUI.Debug("[Warning] Skipping broken module: " .. moduleName)
			end
		end
	end
end

--- Initializes the module options panel in the settings menu.
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

	-- Developer-only feature flag controls (hidden for normal users)
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

			-- Sort flag names for consistent ordering
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

			-- Append flag controls to options table
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

--- Calls a module's InitModule function to set up default options.
---
--- Purpose: Standardizes the initialization of module-specific settings.
--- Mechanics: Checks if the module has an InitModule function and calls it with provided options.
---   On failure, disables the module to prevent cascading errors.
--- References: Called by BETTERUI.Initialize for each registered module (Inventory, Banking, etc.).
---
--- INIT CONTRACT: BETTERUI.ModuleOptions (Wrapper) vs Module InitModule (Callee)
--- ============================================================================
--- This function is the WRAPPER that orchestrates module initialization.
--- It receives the full context but passes only m_options to the module.
---
--- Wrapper Signature (this function):
---   - m_namespace (table): The module's namespace table (e.g., BETTERUI.Inventory)
---   - m_options (table): The raw settings table to populate with defaults
---   - moduleName (string): Optional name for error reporting (e.g., "Inventory")
---   - Returns (table|nil): Returns m_namespace on success, nil on failure
---
--- Module InitModule Signature (called via pcall):
---   - m_options (table|nil): The raw settings table to be initialized
---   - Returns (table): The modified options table with defaults applied
---
--- Why the signatures differ:
---   - ModuleOptions needs m_namespace and moduleName for error context and return
---   - InitModule only needs m_options because modules access their namespace
---     directly via the global BETTERUI table (e.g., BETTERUI.CIM.CONST)
---
--- See: CIM.InitModule, Inventory.InitModule, Banking.InitModule, Vendor.InitModule,
---      ResourceOrbFrames.InitModule
---
--- @param m_namespace table The module's namespace table (e.g., BETTERUI.Inventory)
--- @param m_options table The raw settings table to populate with defaults
--- @param moduleName string|nil Optional name for error reporting (e.g., "Inventory")
--- @return table|nil Returns m_namespace on success, nil on failure
function BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
	if m_namespace and m_namespace.InitModule then
		-- Wrap in pcall to prevent one module's error from breaking the entire addon
		local success, result = pcall(m_namespace.InitModule, m_options)
		if success then
			-- InitModule mutates/persists module settings; return value is not used here.
		else
			local name = moduleName or "unknown"
			BETTERUI.Debug("[Error] InitModule failed for " .. name .. ": " .. tostring(result))
			-- Session-only disable: skip module for this session without persisting to SavedVars
			-- so the module recovers on next /reloadui instead of being permanently broken
			if moduleName then
				BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
				BETTERUI._sessionDisabledModules[moduleName] = true
				BETTERUI.Debug("[Recovery] Module skipped for this session (will retry on reload): " .. name)
			end
			return nil -- Signal to caller that init failed
		end
	end
	return m_namespace
end

--- Validates and calls Setup() on a module. Falls back to basic check if CIM validation unavailable.
local function RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
	if moduleNamespace then
		moduleNamespace._setupComplete = nil
	end

	if type(BETTERUI.SetModuleEnabled) == "function" then
		BETTERUI.SetModuleEnabled(moduleName, false)
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
	if validateFn then
		-- Temporarily add name for validation (modules don't store their own name)
		local tempModule = { name = moduleName, Setup = moduleNamespace.Setup }
		local valid, err = validateFn(tempModule)
		if not valid then
			BETTERUI.Debug(string.format("[Validation] Module '%s' failed validation: %s", moduleName, tostring(err)))
			RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
			return false
		end
	else
		-- Fallback: basic Setup check
		if type(moduleNamespace.Setup) ~= "function" then
			BETTERUI.Debug(string.format("[Validation] Module '%s' has no Setup function", moduleName))
			RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
			return false
		end
	end

	-- Module is valid, call Setup
	-- Wrap in pcall so one module failure doesn't cascade-kill subsequent modules
	local success, setupResult, setupDetail = pcall(moduleNamespace.Setup)
	if not success then
		BETTERUI.Debug(string.format("[Error] Setup() failed for '%s': %s", moduleName, tostring(setupResult)))
		RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
		return false
	end

	if setupResult == false then
		local detail = setupDetail ~= nil and tostring(setupDetail) or "setup returned false"
		BETTERUI.Debug(string.format("[Error] Setup() returned false for '%s': %s", moduleName, detail))
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

	BETTERUI.Debug(string.format("[Recovery] Modules disabled after setup failure (%s): %s",
		contextLabel,
		table.concat(failedModules, ", ")))
	return true
end

local function LoadSavedVarsWithFallback(loaderName, loader)
	local ok, result = pcall(loader, ZO_SavedVars, "BetterUISavedVars", SAVED_VARS_SCHEMA_VERSION, nil, BETTERUI.DefaultSettings)
	if not ok then
		BETTERUI.Debug(string.format("[SavedVars] %s failed, using defaults: %s", loaderName, tostring(result)))
	end
	return ok and result or BETTERUI.DefaultSettings
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

	if entry.name == "Nameplates" and not BETTERUI.GetModuleEnabled("GeneralInterface") then
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

--- Checks if a module should be loaded based on registry entry.
--- Evaluates conditions, dependencies, and CIM requirements.
---@param entry ModuleRegistryEntry The registry entry to evaluate
---@return boolean Whether the module should be loaded
local function ShouldLoadModule(entry)
	local moduleNamespace = BETTERUI[entry.namespace]

	-- Check if namespace exists
	if not moduleNamespace then
		return false
	end

	-- Required modules always load
	if entry.required then
		return true
	end

	-- Check if module is enabled in settings
	if not BETTERUI.GetModuleEnabled(entry.name) then
		return false
	end

	-- Check custom condition function if present
	if entry.condition and not entry.condition() then
		return false
	end

	-- Check dependency if present
	if entry.depends and not BETTERUI.GetModuleEnabled(entry.depends) then
		return false
	end

	-- CIM-dependent modules require CIM to be enabled
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
					BETTERUI.Debug(string.format("[Error] preSetup() failed for '%s': %s", entry.name, tostring(preSetupErr)))
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

--- Loads and initializes all enabled modules.
---
--- Purpose: Orchestrates the loading of sub-modules when in Gamepad mode.
--- Mechanics: Assumes runtime setup already ran during Initialize().
---            Validates modules using CIM.Interfaces before calling Setup.
---            Initializes research data and module-specific setups (Inventory, Banking, Writs, etc.).
--- References: Called on initialization and when switching to Gamepad mode.
---
function BETTERUI.LoadModules()
	if BETTERUI._initialized then return true end

	BETTERUI.Debug("Initializing BETTERUI...")

	-- Initialize research data once
	BETTERUI.GetResearch()

	local allModulesLoaded, failedModules = LoadConfiguredModules()
	ReportModuleSetupFailures(failedModules, "load")

	BETTERUI.Debug("Finished! BETTERUI is loaded")
	BETTERUI._initialized = true
	return allModulesLoaded
end

--- Main addon initialization handler.
---
--- Purpose: Responds to the EVENT_ADD_ON_LOADED event.
--- Mechanics: Loads saved variables, initializes settings, and sets up event listeners.
---            Decides whether to load modules immediately (if in Gamepad mode).
--- References: Registered to EVENT_ADD_ON_LOADED.
---
--- @param event number The event ID.
--- @param addon string The name of the addon being loaded.
function BETTERUI.Initialize(event, addon)
	-- Only handle our own addon load event
	if addon ~= BETTERUI.name then return end

	-- Load saved variables
	-- Changed version to 2.89 to prevent issues with prior saved variables
	-- Wrap in pcall so corrupted SavedVars don't crash the entire addon
	BETTERUI.SavedVars = LoadSavedVarsWithFallback("ZO_SavedVars.New", ZO_SavedVars.New)
	BETTERUI.GlobalVars = LoadSavedVarsWithFallback("ZO_SavedVars.NewAccountWide", ZO_SavedVars.NewAccountWide)

	-- Determine which settings to use
	if BETTERUI.SavedVars.useAccountWide then
		BETTERUI.Settings = BETTERUI.GlobalVars
	else
		BETTERUI.Settings = BETTERUI.SavedVars
	end

	local runtimeSetup = BETTERUI.CIM and BETTERUI.CIM.RuntimeSetup
	if runtimeSetup and runtimeSetup.Apply then
		runtimeSetup.Apply(BETTERUI.Settings)
	end

	-- Initialize or update module settings with defaults
	-- This runs for EVERYONE to ensure new settings (like showStyleTrait) are merged into existing SavedVars
	InitializeRegisteredModuleSettings()

	-- Apply first-install defaults and mark as complete
	if BETTERUI.Settings.firstInstall then
		-- Apply module enable defaults from centralized registry
		if BETTERUI.Defaults and BETTERUI.Defaults.ApplyFirstInstallDefaults then
			BETTERUI.Defaults.ApplyFirstInstallDefaults(BETTERUI.Settings)
		end
		BETTERUI.Debug("First install detected - applied default module states")
		BETTERUI.Settings.firstInstall = false
	end


	-- Note: Settings migrations (Tooltips->GeneralInterface, enabled->m_enabled)
	-- are now handled in Modules/CIM/RuntimeSetup.lua via RuntimeSetup.Apply()

	-- Unregister the initialization event
	-- Use the same namespace that was registered at the bottom of this file
	BETTERUI.EventManager:UnregisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED)

	-- Initialize the options panel
	BETTERUI.InitModuleOptions()
	BETTERUI.UpdateCIMState()

	local setupSucceeded

	-- Load modules if in gamepad mode
	if IsInGamepadPreferredMode() then
		setupSucceeded = BETTERUI.LoadModules()
	else
		BETTERUI._initialized = false
		-- Keyboard mode: register ALL module settings panels so users on "Automatic"
		-- input can always access addon configuration regardless of current UI mode.
		-- NOTE: Only LAM settings panels are registered here. Gameplay hooks (inventory
		-- destroy/action hooks, etc.) remain in LoadModules() and only activate
		-- when gamepad mode is entered.
		local failedModules
		setupSucceeded, failedModules = SetupKeyboardModeModules()
		ReportModuleSetupFailures(failedModules, "keyboard")
	end

	-- Ensure companion equip patch is queued even if modules didn't hook above
	if BETTERUI.Inventory and BETTERUI.Inventory.EnsureCompanionEquipPatched then
		BETTERUI.Inventory.EnsureCompanionEquipPatched()
	end
	return setupSucceeded
end

-- Event handlers for initialization and gamepad mode changes
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED, function(...) BETTERUI.Initialize(...) end)
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
	function(code, inGamepad)
		if inGamepad then
			-- Switching to gamepad: load all modules (idempotent via _initialized guard)
			BETTERUI.LoadModules()
		end
		-- Switching to keyboard: ResourceOrbFrames handles its own mode-change event
		-- inside SetupModule(). All other modules remain inactive in keyboard mode.
	end)

-- Debug commands are now in Modules/CIM/Core/DeveloperDebug.lua
-- Enable debug mode via the DEBUG_LOGGING feature flag or set BETTERUI_DEBUG = true
