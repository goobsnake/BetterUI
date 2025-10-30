local LAM = LibAddonMenu2

if BETTERUI == nil then BETTERUI = {} end

--- Updates the Common Interface Module state based on dependent modules
function BETTERUI.UpdateCIMState()
	local settings = BETTERUI.Settings and BETTERUI.Settings.Modules
	if not settings then return end

	local shouldEnable = settings["Tooltips"].m_enabled or
	                    settings["Inventory"].m_enabled or
	                    settings["Banking"].m_enabled
	settings["CIM"].m_enabled = shouldEnable
end

--- Initializes the master module options panel
function BETTERUI.InitModuleOptions()
	local panelData = Init_ModulePanel("Master", "Master Addon Settings")

	local optionsTable = {
		{
			type = "header",
			name = "Master Settings",
			width = "full",
		},
		{
			type = "checkbox",
			name = "Enable |c0066FFGeneral Interface Improvements|r",
			tooltip = "Vast improvements to the ingame tooltips and UI",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].m_enabled end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Tooltips"].m_enabled = value
				BETTERUI.UpdateCIMState()
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Enable |c0066FFEnhanced Inventory|r",
			tooltip = "Completely redesigns the gamepad's inventory interface",
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
			name = "Enable |c0066FFEnhanced Banking|r",
			tooltip = "Completely redesigns the gamepad's banking interface",
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
			name = "Enable |c0066FFDaily Writ module|r",
			tooltip = "Displays the daily writ, and progress, at each crafting station",
			getFunc = function() return BETTERUI.Settings.Modules["Writs"].m_enabled end,
			setFunc = function(value) BETTERUI.Settings.Modules["Writs"].m_enabled = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Common Interface Module",
			tooltip = "Enables added functionality to the completely redesigned \"Enhanced\" interfaces!",
			getFunc = function() return BETTERUI.Settings.Modules["CIM"].m_enabled end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["CIM"].m_enabled = value
				BETTERUI.UpdateCIMState()
			end,
			disabled = true,
			width = "full",
		},
	}

	LAM:RegisterAddonPanel("BETTERUI_".."Modules", panelData)
	LAM:RegisterOptionControls("BETTERUI_".."Modules", optionsTable)
end

--- Initializes module settings by calling the module's InitModule function
--- @param m_namespace table: The module namespace table
--- @param m_options table: The module options table
--- @return table: The initialized module namespace
function BETTERUI.ModuleOptions(m_namespace, m_options)
	if m_namespace and m_namespace.InitModule then
		m_options = m_namespace.InitModule(m_options)
	end
	return m_namespace
end

--- Loads and initializes all enabled BetterUI modules
--- Only performs initialization once, subsequent calls are no-ops
function BETTERUI.LoadModules()
	if BETTERUI._initialized then return end

	ddebug("Initializing BETTERUI...")

	-- Initialize research data once
	BETTERUI.GetResearch()

	local settings = BETTERUI.Settings and BETTERUI.Settings.Modules
	if not settings then
		ddebug("Error: Settings not available")
		return
	end

	-- Initialize CIM-dependent modules
	if settings["CIM"].m_enabled then
		if settings["Inventory"].m_enabled and BETTERUI.Inventory then
			if BETTERUI.Inventory.HookDestroyItem then BETTERUI.Inventory.HookDestroyItem() end
			if BETTERUI.Inventory.HookActionDialog then BETTERUI.Inventory.HookActionDialog() end
			if BETTERUI.Inventory.Setup then BETTERUI.Inventory.Setup() end
		end

		if settings["Banking"].m_enabled and BETTERUI.Banking and BETTERUI.Banking.Setup then
			BETTERUI.Banking.Setup()
		end
	end

	-- Initialize independent modules
	if settings["Writs"].m_enabled and BETTERUI.Writs and BETTERUI.Writs.Setup then
		BETTERUI.Writs.Setup()
	end

	if settings["Tooltips"].m_enabled and BETTERUI.Tooltips and BETTERUI.Tooltips.Setup then
		BETTERUI.Tooltips.Setup()
	end

	ddebug("Finished! BETTERUI is loaded")
	BETTERUI._initialized = true
end

--- Main initialization function called when the addon loads
--- @param event string: The event type
--- @param addon string: The addon name that triggered the event
function BETTERUI.Initialize(event, addon)
	-- Filter for just BETTERUI addon event as EVENT_ADD_ON_LOADED is addon-blind
	if addon ~= BETTERUI.name then return end

	-- Load saved variables
	BETTERUI.Settings = ZO_SavedVars:New("BetterUISavedVars", 2.80, nil, BETTERUI.DefaultSettings)

	-- Initialize module settings on first install
	if BETTERUI.Settings.firstInstall then
		local modules = {
			{"CIM", BETTERUI.CIM},
			{"Inventory", BETTERUI.Inventory},
			{"Banking", BETTERUI.Banking},
			{"Writs", BETTERUI.Writs},
			{"Tooltips", BETTERUI.Tooltips}
		}

		for _, moduleInfo in ipairs(modules) do
			local moduleName, moduleNamespace = moduleInfo[1], moduleInfo[2]
			if moduleNamespace then
				BETTERUI.ModuleOptions(moduleNamespace, BETTERUI.Settings.Modules[moduleName])
			end
		end

		ddebug("First install detected - initializing module settings")
		BETTERUI.Settings.firstInstall = false
	end

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
end

-- Register event handlers for addon initialization and gamepad mode changes
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED, function(...) BETTERUI.Initialize(...) end)
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name.."_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function(code, inGamepad) BETTERUI.LoadModules() end)