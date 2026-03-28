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

-- ─── Constants ───────────────────────────────────────────────────────────────
local SAVED_VARS_SCHEMA_VERSION = 2.89

-- ============================================================================
-- MODULE REGISTRY
-- ============================================================================

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
			BETTERUI.CIM.TryCall("Inventory.HookDestroyItem")
			BETTERUI.CIM.TryCall("Inventory.HookActionDialog")
			return true
		end
	},
	{ name = "Banking", namespace = "Banking", dependsOnCIM = true },
	{ name = "Vendor", namespace = "Vendor", dependsOnCIM = true },

	-- Independent modules
	{ name = "Writs", namespace = "Writs" },
	{ name = "GeneralInterface", namespace = "GeneralInterface" },
	{
		name = "Nameplates",
		namespace = "Nameplates",
		depends = "GeneralInterface"
	},
	{ name = "ResourceOrbFrames", namespace = "ResourceOrbFrames" },
}

-- ============================================================================
-- NAMESPACE INITIALIZATION (Required before module files load)
-- ============================================================================

-- Core addon metadata
BETTERUI.name = "BetterUI"
BETTERUI.version = "3.02"

-- Module namespace tables
BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Banking = BETTERUI.Banking or {}
BETTERUI.Vendor = BETTERUI.Vendor or {}
BETTERUI.Writs = BETTERUI.Writs or {}
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.GeneralInterface = BETTERUI.GeneralInterface or {}
BETTERUI.Nameplates = BETTERUI.Nameplates or {}
BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}

-- UI Component namespaces
BETTERUI.GenericHeader = BETTERUI.GenericHeader or {}
BETTERUI.GenericFooter = BETTERUI.GenericFooter or {}
BETTERUI.Interface = BETTERUI.Interface or {}

-- Legacy namespace (deprecated — consumers migrated to module-scoped CONST paths)
BETTERUI.CONST = BETTERUI.CONST or {}

-- Engine helper references
BETTERUI.WindowManager = GetWindowManager()
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
--- Purpose: Ensures CIM is enabled if any module requiring it (Inventory, Banking) is active.
--- Mechanics: Checks settings for Tooltips, Inventory, and Banking.
---            Updates the CIM m_enabled setting accordingly.
--- References: Called when toggling module settings in the options panel.
---
function BETTERUI.UpdateCIMState()
	local shouldEnable = BETTERUI.GetModuleEnabled("GeneralInterface") or
		BETTERUI.GetModuleEnabled("Inventory") or
		BETTERUI.GetModuleEnabled("Banking") or
		BETTERUI.GetModuleEnabled("Vendor")
	BETTERUI.SetSetting("CIM", "m_enabled", shouldEnable)
end

--- Initializes the module options panel in the settings menu.
---
--- Purpose: Registers the add-on settings panel using LibAddonMenu2.
--- Mechanics: Construct a table of options including checkboxes for each module.
---            Registers the panel and options with LAM.
--- References: Called during BETTERUI.Initialize.
---
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

--- Normalizes a module toggle name for sorting by removing color codes, textures,
--- whitespace, and language-specific "Enable" prefixes.
--- @param name string The raw toggle name to normalize
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

	-- Keep "Use Global Settings" first, then sort module toggles by displayed label content.
	local moduleToggleOptions = {
		{
			sortKey = "Banking",
			type = "checkbox",
			name = GetStringByName("SI_BETTERUI_ENABLE_BANKING"),
			tooltip = GetStringByName("SI_BETTERUI_ENABLE_BANKING_TOOLTIP"),
			getFunc = function()
				local modules = BETTERUI.Settings and BETTERUI.Settings.Modules
				return modules and modules["Banking"] and modules["Banking"].m_enabled or false
			end,
			setFunc = function(value)
				BETTERUI.SetSetting("Banking", "m_enabled", value)
				BETTERUI.UpdateCIMState()
			end,
			width = "full",
			requiresReload = true,
		},
		{
			sortKey = "Vendor",
			type = "checkbox",
			name = GetStringByName("SI_BETTERUI_ENABLE_VENDOR"),
			tooltip = GetStringByName("SI_BETTERUI_ENABLE_VENDOR_TOOLTIP"),
			getFunc = function()
				local modules = BETTERUI.Settings and BETTERUI.Settings.Modules
				return modules and modules["Vendor"] and modules["Vendor"].m_enabled or false
			end,
			setFunc = function(value)
				BETTERUI.SetSetting("Vendor", "m_enabled", value)
				BETTERUI.UpdateCIMState()
			end,
			width = "full",
			requiresReload = true,
		},
		{
			sortKey = "General Interface",
			type = "checkbox",
			name = GetStringByName("SI_BETTERUI_ENABLE_TOOLTIPS"),
			tooltip = GetStringByName("SI_BETTERUI_ENABLE_TOOLTIPS_TOOLTIP"),
			getFunc = function()
				local modules = BETTERUI.Settings and BETTERUI.Settings.Modules
				return modules and modules["GeneralInterface"] and modules["GeneralInterface"].m_enabled or false
			end,
			setFunc = function(value)
				BETTERUI.SetSetting("GeneralInterface", "m_enabled", value)
				BETTERUI.UpdateCIMState()
			end,
			width = "full",
			requiresReload = true,
		},
		{
			sortKey = "Inventory",
			type = "checkbox",
			name = GetStringByName("SI_BETTERUI_ENABLE_INVENTORY"),
			tooltip = GetStringByName("SI_BETTERUI_ENABLE_INVENTORY_TOOLTIP"),
			getFunc = function()
				local modules = BETTERUI.Settings and BETTERUI.Settings.Modules
				return modules and modules["Inventory"] and modules["Inventory"].m_enabled or false
			end,
			setFunc = function(value)
				BETTERUI.SetSetting("Inventory", "m_enabled", value)
				BETTERUI.UpdateCIMState()
			end,
			width = "full",
			requiresReload = true,
		},
		{
			sortKey = "Resource Orb Frames",
			type = "checkbox",
			name = GetStringByName("SI_BETTERUI_ENABLE_ORBS"),
			tooltip = GetStringByName("SI_BETTERUI_ENABLE_ORBS_TOOLTIP"),
			getFunc = function()
				return BETTERUI.GetModuleEnabled("ResourceOrbFrames")
			end,
			setFunc = function(value)
				BETTERUI.SetSetting("ResourceOrbFrames", "m_enabled", value)
			end,
			width = "full",
			requiresReload = true,
		},
		{
			sortKey = "Writs",
			type = "checkbox",
			name = GetStringByName("SI_BETTERUI_ENABLE_WRITS"),
			tooltip = GetStringByName("SI_BETTERUI_ENABLE_WRITS_TOOLTIP"),
			getFunc = function()
				local modules = BETTERUI.Settings and BETTERUI.Settings.Modules
				return modules and modules["Writs"] and modules["Writs"].m_enabled or false
			end,
			setFunc = function(value)
				BETTERUI.SetSetting("Writs", "m_enabled", value)
			end,
			width = "full",
			requiresReload = true,
		},
	}

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
		table.insert(optionsTable, control)
	end

	-- NOTE: CIM toggle removed in v2.93 - CIM is now auto-managed internally
	-- based on dependent modules (Inventory, Banking, GeneralInterface)

	-- Developer-only feature flag controls (hidden for normal users)
	local _, showDeveloperSettings = BETTERUI.CIM.TryCall("CIM.Debug.ShouldShowDeveloperSettings")

	if showDeveloperSettings then
		local _, allFlags = BETTERUI.CIM.TryCall("CIM.FeatureFlags.GetAllFlags")
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
			BETTERUI.CIM.TryCall("CIM.Settings.ResetAllSettingsToDefaults")
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
--- See: CIM.InitModule, Inventory.InitModule, Banking.InitModule, Vendor.InitModule
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

--[[
Function: BETTERUI.ValidateAndSetupModule
Description: Validates and initializes a module listed in MODULE_REGISTRY.
Rationale: Only modules in MODULE_REGISTRY participate in the Setup() lifecycle.
           Scaffold modules (future features) should NOT define Setup() — they only
           establish namespace tables and utility functions.
Mechanism: Uses CIM.Interfaces.ValidateModule if available, falls back to basic check.
param: moduleName (string) - The name of the module for logging
param: moduleNamespace (table) - The module's namespace table
return: boolean - True if module was successfully set up
]]
local function ValidateAndSetupModule(moduleName, moduleNamespace)
	if not moduleNamespace then
		BETTERUI.Debug(string.format("[Validation] Module '%s' namespace is nil", moduleName))
		return false
	end

	-- Prevent double Setup (LAM:RegisterAddonPanel will crash with "Duplicate name")
	if moduleNamespace._setupComplete then return true end

	-- Validate using CIM interface validation if available
	if BETTERUI.CIM and BETTERUI.CIM.Interfaces and BETTERUI.CIM.Interfaces.ValidateModule then
		-- Temporarily add name for validation (modules don't store their own name)
		local tempModule = { name = moduleName, Setup = moduleNamespace.Setup }
		local valid, err = BETTERUI.CIM.Interfaces.ValidateModule(tempModule)
		if not valid then
			BETTERUI.Debug(string.format("[Validation] Module '%s' failed validation: %s", moduleName, tostring(err)))
			return false
		end
	else
		-- Fallback: basic Setup check
		if type(moduleNamespace.Setup) ~= "function" then
			BETTERUI.Debug(string.format("[Validation] Module '%s' has no Setup function", moduleName))
			return false
		end
	end

	-- Module is valid, call Setup
	-- Wrap in pcall so one module failure doesn't cascade-kill subsequent modules
	local success, err = pcall(moduleNamespace.Setup)
	if not success then
		BETTERUI.Debug(string.format("[Error] Setup() failed for '%s': %s", moduleName, tostring(err)))
		return false
	end
	moduleNamespace._setupComplete = true
	return true
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

--- Loads and initializes all enabled modules.
---
--- Purpose: Orchestrates the loading of sub-modules when in Gamepad mode.
--- Mechanics: Calls RuntimeSetup.Apply() for API patches and settings migrations.
---            Validates modules using CIM.Interfaces before calling Setup.
---            Initializes research data and module-specific setups (Inventory, Banking, Writs, etc.).
--- References: Called on initialization and when switching to Gamepad mode.
---
function BETTERUI.LoadModules()
	if BETTERUI._initialized then return end

	BETTERUI.Debug("Initializing BETTERUI...")

	-- Apply runtime safety patches and settings migrations
	-- (Extracted to Modules/CIM/RuntimeSetup.lua for cleaner separation)
	BETTERUI.CIM.TryCall("CIM.RuntimeSetup.Apply", BETTERUI.Settings)

	-- Initialize research data once
	BETTERUI.GetResearch()

	-- Iterate the module registry for declarative loading
	for _, entry in ipairs(MODULE_REGISTRY) do
		if ShouldLoadModule(entry) then
			local moduleNamespace = BETTERUI[entry.namespace]

			-- Run pre-setup hooks if defined
			if entry.preSetup then
				entry.preSetup()
			end

			-- Validate and setup the module
			ValidateAndSetupModule(entry.name, moduleNamespace)
		end
	end

	BETTERUI.Debug("Finished! BETTERUI is loaded")
	BETTERUI._initialized = true
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
	local ok, result = pcall(ZO_SavedVars.New, ZO_SavedVars, "BetterUISavedVars", SAVED_VARS_SCHEMA_VERSION, nil, BETTERUI.DefaultSettings)
	BETTERUI.SavedVars = ok and result or BETTERUI.DefaultSettings
	local okGlobal, resultGlobal = pcall(ZO_SavedVars.NewAccountWide, ZO_SavedVars, "BetterUISavedVars", SAVED_VARS_SCHEMA_VERSION, nil, BETTERUI.DefaultSettings)
	BETTERUI.GlobalVars = okGlobal and resultGlobal or BETTERUI.DefaultSettings

	-- Determine which settings to use
	if BETTERUI.SavedVars.useAccountWide then
		BETTERUI.Settings = BETTERUI.GlobalVars
	else
		BETTERUI.Settings = BETTERUI.SavedVars
	end

	-- Initialize or update module settings with defaults
	-- This runs for EVERYONE to ensure new settings (like showStyleTrait) are merged into existing SavedVars
	for _, entry in ipairs(MODULE_REGISTRY) do
		local moduleName, moduleNamespace = entry.name, BETTERUI[entry.namespace]
		if moduleNamespace then
			-- Ensure the settings table exists before initializing
			if BETTERUI.Settings.Modules[moduleName] == nil then
				BETTERUI.Settings.Modules[moduleName] = {}
			end
			local moduleInitResult = BETTERUI.ModuleOptions(moduleNamespace, BETTERUI.Settings.Modules[moduleName], moduleName)
			if not moduleInitResult then
				BETTERUI.Debug("[Warning] Skipping broken module: " .. moduleName)
			end
		end
	end

	-- Apply first-install defaults and mark as complete
	if BETTERUI.Settings.firstInstall then
		-- Apply module enable defaults from centralized registry
		BETTERUI.CIM.TryCall("Defaults.ApplyFirstInstallDefaults", BETTERUI.Settings)
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

	-- Load modules if in gamepad mode
	if IsInGamepadPreferredMode() then
		BETTERUI.LoadModules()
	else
		BETTERUI._initialized = false
		-- Keyboard mode: register ALL module settings panels so users on "Automatic"
		-- input can always access addon configuration regardless of current UI mode.
		-- NOTE: Only LAM settings panels are registered here. Gameplay hooks (inventory
		-- destroy/action hooks, etc.) remain in LoadModules() and only activate
		-- when gamepad mode is entered.
		for _, entry in ipairs(MODULE_REGISTRY) do
			if entry.name ~= "CIM" then -- Skip CIM, it's internal
				if BETTERUI.GetModuleEnabled(entry.name) and BETTERUI[entry.namespace] then
					-- For Nameplates, also check GeneralInterface dependency
					if entry.name == "Nameplates" then
						if BETTERUI.GetModuleEnabled("GeneralInterface") then
							ValidateAndSetupModule(entry.name, BETTERUI[entry.namespace])
						end
					else
						ValidateAndSetupModule(entry.name, BETTERUI[entry.namespace])
					end
				end
			end
		end
	end
	-- Ensure companion equip patch is queued even if modules didn't hook above
	BETTERUI.CIM.TryCall("Inventory.EnsureCompanionEquipPatched")
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
