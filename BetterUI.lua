--[[
File: BetterUI.lua
Purpose: Main entry point for the BetterUI addon.
         Handles module initialization and event registration.
Mechanics: Listens for EVENT_ADD_ON_LOADED to initialize itself.
           Manages the loading of sub-modules based on Gamepad mode.
           Runtime patches and settings migrations are delegated to CIM/RuntimeSetup.lua.
Author: BetterUI Team
Last Modified: 2026-01-24

-- TODO(ARCHITECTURE): Consider adopting a formal module registration pattern.
-- Current approach: Each module is manually listed in LoadModules() and Initialize().
-- Proposed: BETTERUI.RegisterModule(name, namespace, dependencies) that auto-wires:
--   1. Settings initialization
--   2. Setup() call ordering based on dependencies
--   3. Settings panel registration
-- This would reduce boilerplate and ensure consistent module structure.
-- See: WoW's AceAddon or similar patterns for inspiration.
]]

local LAM = LibAddonMenu2

if BETTERUI == nil then BETTERUI = {} end

-- ============================================================================
-- NAMESPACE INITIALIZATION (Required before module files load)
-- ============================================================================

-- Core addon metadata
BETTERUI.name = "BetterUI"
BETTERUI.version = "2.93"

-- Module namespace tables
BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Banking = BETTERUI.Banking or {}
BETTERUI.Writs = BETTERUI.Writs or {}
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.GeneralInterface = BETTERUI.GeneralInterface or {}
BETTERUI.Nameplates = BETTERUI.Nameplates or {}
BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}

-- UI Component namespaces
BETTERUI.GenericHeader = BETTERUI.GenericHeader or {}
BETTERUI.GenericFooter = BETTERUI.GenericFooter or {}
BETTERUI.Interface = BETTERUI.Interface or {}

-- Legacy namespace for backward compatibility
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
		BETTERUI.GetModuleEnabled("Banking")
	if BETTERUI.Settings.Modules["CIM"] then
		BETTERUI.Settings.Modules["CIM"].m_enabled = shouldEnable
	end
end

--- Initializes the module options panel in the settings menu.
---
--- Purpose: Registers the add-on settings panel using LibAddonMenu2.
--- Mechanics: Construct a table of options including checkboxes for each module.
---            Registers the panel and options with LAM.
--- References: Called during BETTERUI.Initialize.
---
function BETTERUI.InitModuleOptions()
	local panelData = BETTERUI.Init_ModulePanel("Master", GetString(SI_BETTERUI_MASTER_SETTINGS_TITLE))

	local optionsTable = {
		{
			type = "header",
			name = GetString(SI_BETTERUI_MASTER_SETTINGS_HEADER),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_GLOBAL_SETTINGS),
			tooltip = GetString(SI_BETTERUI_ENABLE_GLOBAL_TOOLTIP),
			getFunc = function() return BETTERUI.SavedVars.useAccountWide end,
			setFunc = function(value)
				BETTERUI.SavedVars.useAccountWide = value
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_TOOLTIPS),
			tooltip = GetString(SI_BETTERUI_ENABLE_TOOLTIPS_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["GeneralInterface"].m_enabled end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["GeneralInterface"].m_enabled = value
				BETTERUI.UpdateCIMState()
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_INVENTORY),
			tooltip = GetString(SI_BETTERUI_ENABLE_INVENTORY_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Inventory"].m_enabled end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Inventory"].m_enabled = value
				BETTERUI.UpdateCIMState()
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_BANKING),
			tooltip = GetString(SI_BETTERUI_ENABLE_BANKING_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Banking"].m_enabled end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Banking"].m_enabled = value
				BETTERUI.UpdateCIMState()
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_ORBS),
			tooltip = GetString(SI_BETTERUI_ENABLE_ORBS_TOOLTIP),
			getFunc = function()
				return BETTERUI.GetModuleEnabled("ResourceOrbFrames")
			end,
			setFunc = function(value)
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then BETTERUI.Settings.Modules["ResourceOrbFrames"] = {} end
				BETTERUI.Settings.Modules["ResourceOrbFrames"].m_enabled = value
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_WRITS),
			tooltip = GetString(SI_BETTERUI_ENABLE_WRITS_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Writs"].m_enabled end,
			setFunc = function(value) BETTERUI.Settings.Modules["Writs"].m_enabled = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_CIM),
			tooltip = GetString(SI_BETTERUI_ENABLE_CIM_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["CIM"].m_enabled end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["CIM"].m_enabled = value
				BETTERUI.UpdateCIMState()
			end,
			disabled = true,
			width = "full",
		},
	}

	LAM:RegisterAddonPanel("BETTERUI_" .. "Modules", panelData)
	LAM:RegisterOptionControls("BETTERUI_" .. "Modules", optionsTable)
end

--- Calls a module's InitModule function to set up default options.
---
--- Purpose: Standardizes the initialization of module-specific settings.
--- Mechanics: Checks if the module has an InitModule function and calls it with provided options.
--- References: Called by BETTERUI.Initialize for each registered module (Inventory, Banking, etc.).
---
--- @param m_namespace table The module's namespace table.
--- @param m_options table The options table for the module.
--- @return table The initialized module namespace.
function BETTERUI.ModuleOptions(m_namespace, m_options)
	if m_namespace and m_namespace.InitModule then
		m_options = m_namespace.InitModule(m_options)
	end
	return m_namespace
end

--- Loads and initializes all enabled modules.
---
--- Purpose: Orchestrates the loading of sub-modules when in Gamepad mode.
--- Mechanics: Calls RuntimeSetup.Apply() for API patches and settings migrations.
---            Initializes research data and module-specific setups (Inventory, Banking, Writs, etc.).
--- References: Called on initialization and when switching to Gamepad mode.
---
function BETTERUI.LoadModules()
	if BETTERUI._initialized then return end

	ddebug("Initializing BETTERUI...")

	-- Apply runtime safety patches and settings migrations
	-- (Extracted to Modules/CIM/RuntimeSetup.lua for cleaner separation)
	if BETTERUI.CIM and BETTERUI.CIM.RuntimeSetup and BETTERUI.CIM.RuntimeSetup.Apply then
		BETTERUI.CIM.RuntimeSetup.Apply(BETTERUI.Settings)
	end

	-- Initialize research data once
	BETTERUI.GetResearch()

	local settings = BETTERUI.Settings.Modules

	-- Initialize CIM-dependent modules
	-- Initialize CIM-dependent modules
	if BETTERUI.GetModuleEnabled("CIM") then
		if BETTERUI.GetModuleEnabled("Inventory") and BETTERUI.Inventory then
			if BETTERUI.Inventory.HookDestroyItem then BETTERUI.Inventory.HookDestroyItem() end
			if BETTERUI.Inventory.HookActionDialog then BETTERUI.Inventory.HookActionDialog() end
			if BETTERUI.Inventory.Setup then BETTERUI.Inventory.Setup() end
		end

		if BETTERUI.GetModuleEnabled("Banking") and BETTERUI.Banking and BETTERUI.Banking.Setup then
			BETTERUI.Banking.Setup()
		end
	end

	-- Initialize independent modules
	if BETTERUI.GetModuleEnabled("Writs") and BETTERUI.Writs and BETTERUI.Writs.Setup then
		BETTERUI.Writs.Setup()
	end

	-- Initialize General Interface (Settings & Tooltips)
	-- We call this conditionally (based on Master Setting "Enable General Interface Improvements")
	if BETTERUI.GetModuleEnabled("GeneralInterface") and BETTERUI.GeneralInterface and BETTERUI.GeneralInterface.Setup then
		BETTERUI.GeneralInterface.Setup()
	end

	-- Initialize Independent modules (Settings-aware)
	-- Nameplates (Dependent on General Interface Master Setting)
	if BETTERUI.GetModuleEnabled("GeneralInterface") and BETTERUI.GetModuleEnabled("Nameplates") and BETTERUI.Nameplates and BETTERUI.Nameplates.Setup then
		BETTERUI.Nameplates.Setup()
	end

	-- Resource Orb Frames
	-- Logic: If enabled, load it. If disabled, do NOT load it (so settings panel won't register).
	if BETTERUI.GetModuleEnabled("ResourceOrbFrames") and BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.Setup then
		BETTERUI.ResourceOrbFrames.Setup()
	end

	ddebug("Finished! BETTERUI is loaded")
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
	BETTERUI.SavedVars = ZO_SavedVars:New("BetterUISavedVars", 2.89, nil, BETTERUI.DefaultSettings)
	BETTERUI.GlobalVars = ZO_SavedVars:NewAccountWide("BetterUISavedVars", 2.89, nil, BETTERUI.DefaultSettings)

	-- Determine which settings to use
	if BETTERUI.SavedVars.useAccountWide then
		BETTERUI.Settings = BETTERUI.GlobalVars
	else
		BETTERUI.Settings = BETTERUI.SavedVars
	end

	-- Initialize or update module settings with defaults
	-- This runs for EVERYONE to ensure new settings (like showStyleTrait) are merged into existing SavedVars
	local modules = {
		{ "CIM",               BETTERUI.CIM },
		{ "Inventory",         BETTERUI.Inventory },
		{ "Banking",           BETTERUI.Banking },
		{ "Writs",             BETTERUI.Writs },
		{ "GeneralInterface",  BETTERUI.GeneralInterface },
		{ "Nameplates",        BETTERUI.Nameplates },
		{ "ResourceOrbFrames", BETTERUI.ResourceOrbFrames }
	}

	for _, moduleInfo in ipairs(modules) do
		local moduleName, moduleNamespace = moduleInfo[1], moduleInfo[2]
		if moduleNamespace then
			-- Ensure the settings table exists before initializing
			if BETTERUI.Settings.Modules[moduleName] == nil then
				BETTERUI.Settings.Modules[moduleName] = {}
			end
			BETTERUI.ModuleOptions(moduleNamespace, BETTERUI.Settings.Modules[moduleName])
		end
	end

	-- Mark first install as complete
	if BETTERUI.Settings.firstInstall then
		ddebug("First install detected - initialized module settings")
		BETTERUI.Settings.firstInstall = false
	end


	-- Note: Settings migrations (Tooltips->GeneralInterface, enabled->m_enabled)
	-- are now handled in Modules/CIM/RuntimeSetup.lua via RuntimeSetup.Apply()

	-- Unregister the initialization event
	BETTERUI.EventManager:UnregisterForEvent("BetterUIInitialize", EVENT_ADD_ON_LOADED)

	-- Initialize the options panel
	BETTERUI.InitModuleOptions()
	BETTERUI.UpdateCIMState()

	-- Load modules if in gamepad mode
	if IsInGamepadPreferredMode() then
		BETTERUI.LoadModules()
	else
		BETTERUI._initialized = false
	end
	-- Ensure companion equip patch is queued even if modules didn't hook above
	if BETTERUI.Inventory and BETTERUI.Inventory.EnsureCompanionEquipPatched then
		BETTERUI.Inventory.EnsureCompanionEquipPatched()
	end
end

-- Event handlers for initialization and gamepad mode changes
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED, function(...) BETTERUI.Initialize(...) end)
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
	function(code, inGamepad) BETTERUI.LoadModules() end)
