local LAM = LibAddonMenu2

if BETTERUI == nil then BETTERUI = {} end

function BETTERUI.UpdateCIMState()
    if BETTERUI.Settings.Modules["Tooltips"].m_enabled or BETTERUI.Settings.Modules["Inventory"].m_enabled or BETTERUI.Settings.Modules["Banking"].m_enabled then
        BETTERUI.Settings.Modules["CIM"].m_enabled = true
    else
        BETTERUI.Settings.Modules["CIM"].m_enabled = false
    end
end

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
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].m_enabled = value
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
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].m_enabled = value
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
			setFunc = function(value) BETTERUI.Settings.Modules["Banking"].m_enabled = value
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
			setFunc = function(value) BETTERUI.Settings.Modules["Writs"].m_enabled = value  end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Common Interface Module",
			tooltip = "Enables added functionality to the completely redesigned \"Enhanced\" interfaces!",
			getFunc = function() return BETTERUI.Settings.Modules["CIM"].m_enabled end,
			setFunc = function(value) BETTERUI.Settings.Modules["CIM"].m_enabled = value
						BETTERUI.UpdateCIMState()
		            end,
            disabled = true,
			width = "full",
		},
	}

	LAM:RegisterAddonPanel("BETTERUI_".."Modules", panelData)
	LAM:RegisterOptionControls("BETTERUI_".."Modules", optionsTable)
end

function BETTERUI.ModuleOptions(m_namespace, m_options)
	m_options = m_namespace.InitModule(m_options)
	return m_namespace
end

function BETTERUI.LoadModules()

	if(not BETTERUI._initialized) then
		ddebug("Initializing BETTERUI...")
		BETTERUI.GetResearch()

		if(BETTERUI.Settings.Modules["CIM"].m_enabled) then
			if(BETTERUI.Settings.Modules["Inventory"].m_enabled) then
				BETTERUI.Inventory.HookDestroyItem()
				BETTERUI.Inventory.HookActionDialog()
				BETTERUI.Inventory.Setup()
			end
			if(BETTERUI.Settings.Modules["Banking"].m_enabled) then
				BETTERUI.Banking.Setup()
			end
		end
		if(BETTERUI.Settings.Modules["Writs"].m_enabled) then
			BETTERUI.Writs.Setup()
		end
		if(BETTERUI.Settings.Modules["Tooltips"].m_enabled) then
			BETTERUI.Tooltips.Setup()
		end

		ddebug("Finished! BETTERUI is loaded")
		BETTERUI._initialized = true
	end

end

function BETTERUI.Initialize(event, addon)
    -- filter for just BETTERUI addon event as EVENT_ADD_ON_LOADED is addon-blind
	if addon ~= BETTERUI.name then return end

	-- load our saved variables
	BETTERUI.Settings = ZO_SavedVars:New("BetterUISavedVars", 2.65, nil, BETTERUI.DefaultSettings)

	-- Has the settings savedvars JUST been applied? then re-init the module settings
	if(BETTERUI.Settings.firstInstall) then
		BETTERUI.ModuleOptions(BETTERUI.CIM, BETTERUI.Settings.Modules["CIM"])
		BETTERUI.ModuleOptions(BETTERUI.Inventory, BETTERUI.Settings.Modules["Inventory"])
		BETTERUI.ModuleOptions(BETTERUI.Banking, BETTERUI.Settings.Modules["Banking"])
		BETTERUI.ModuleOptions(BETTERUI.Writs, BETTERUI.Settings.Modules["Writs"])
		BETTERUI.ModuleOptions(BETTERUI.Tooltips, BETTERUI.Settings.Modules["Tooltips"])

		d("first install!")
		BETTERUI.Settings.firstInstall = false
	end

	BETTERUI.EventManager:UnregisterForEvent("BetterUIInitialize", EVENT_ADD_ON_LOADED)

	BETTERUI.InitModuleOptions()
	BETTERUI.UpdateCIMState()

	if(IsInGamepadPreferredMode()) then
		BETTERUI.LoadModules()
	else
		BETTERUI._initialized = false
	end

end

-- register our event handler function to be called to do initialization
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED, function(...) BETTERUI.Initialize(...) end)
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name.."_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function(code, inGamepad)  BETTERUI.LoadModules() end)
