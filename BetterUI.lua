local LAM = LibAddonMenu2

if BETTERUI == nil then BETTERUI = {} end

--- Updates the Common Interface Module (CIM) state based on dependent modules. CIM is automatically enabled if any of the Tooltips, Inventory, or Banking modules are enabled, since it provides shared UI components like parametric scroll lists and headers.
function BETTERUI.UpdateCIMState()
	local settings = BETTERUI.Settings.Modules
	local shouldEnable = settings["Tooltips"].m_enabled or
	                    settings["Inventory"].m_enabled or
	                    settings["Banking"].m_enabled
	settings["CIM"].m_enabled = shouldEnable
end

--- Initializes the master module options panel using LibAddonMenu2. Creates checkboxes for enabling/disabling each BetterUI module, with tooltips explaining their functionality.
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

--- Loads and initializes all enabled BetterUI modules. This includes setting up UI elements, registering event handlers, and hooking into ESO's systems. Initialization only happens once to prevent duplicate setup, and modules are loaded conditionally based on their enabled state and dependencies.
function BETTERUI.LoadModules()
	if BETTERUI._initialized then return end

	ddebug("Initializing BETTERUI...")

	-- Apply runtime safety patches for ESO API issues (e.g., nil icon paths).
	-- These are applied early and only once to avoid modifying esoui/ files.
	if not BETTERUI._patchesApplied then
		-- Patch 1: Wrap global icon/text formatting helpers to handle nil paths gracefully.
		if type(zo_iconFormat) == "function" then
			local _orig_zo_iconFormat = zo_iconFormat
			zo_iconFormat = function(path, width, height)
				if path == nil then path = "" end
				local ok, res = pcall(function()
					return _orig_zo_iconFormat(path, width, height)
				end)
				return ok and res or ""
			end
		end

		if type(zo_iconFormatInheritColor) == "function" then
			local _orig_zo_iconFormatInheritColor = zo_iconFormatInheritColor
			zo_iconFormatInheritColor = function(path, width, height)
				if path == nil then path = "" end
				local ok, res = pcall(function()
					return _orig_zo_iconFormatInheritColor(path, width, height)
				end)
				return ok and res or ""
			end
		end

		if type(zo_iconTextFormat) == "function" then
			local _orig_zo_iconTextFormat = zo_iconTextFormat
			zo_iconTextFormat = function(path, width, height, text, inheritColor, noGrammar)
				if path == nil then path = "" end
				local ok, res = pcall(function()
					return _orig_zo_iconTextFormat(path, width, height, text, inheritColor, noGrammar)
				end)
				return ok and res or tostring(text or "")
			end
		end

		if type(zo_iconTextFormatAlignedRight) == "function" then
			local _orig_zo_iconTextFormatAlignedRight = zo_iconTextFormatAlignedRight
			zo_iconTextFormatAlignedRight = function(path, width, height, text, inheritColor, noGrammar)
				if path == nil then path = "" end
				local ok, res = pcall(function()
					return _orig_zo_iconTextFormatAlignedRight(path, width, height, text, inheritColor, noGrammar)
				end)
				return ok and res or tostring(text or "")
			end
		end

		if type(zo_iconTextFormatNoSpace) == "function" then
			local _orig_zo_iconTextFormatNoSpace = zo_iconTextFormatNoSpace
			zo_iconTextFormatNoSpace = function(path, width, height, text, inheritColor)
				if path == nil then path = "" end
				local ok, res = pcall(function()
					return _orig_zo_iconTextFormatNoSpace(path, width, height, text, inheritColor)
				end)
				return ok and res or tostring(text or "")
			end
		end

		if type(zo_iconTextFormatNoSpaceAlignedRight) == "function" then
			local _orig_zo_iconTextFormatNoSpaceAlignedRight = zo_iconTextFormatNoSpaceAlignedRight
			zo_iconTextFormatNoSpaceAlignedRight = function(path, width, height, text, inheritColor, noGrammar)
				if path == nil then path = "" end
				local ok, res = pcall(function()
					return _orig_zo_iconTextFormatNoSpaceAlignedRight(path, width, height, text, inheritColor, noGrammar)
				end)
				return ok and res or tostring(text or "")
			end
		end

		-- Patch 2: Wrap ZO_KeybindStrip:HandleDuplicateAddKeybind to safely evaluate descriptor names.
		-- The original function calls GetKeybindDescriptorDebugIdentifier on descriptors, which can
		-- call formatting helpers (like zo_iconFormat) with nil paths. We wrap this to silently
		-- handle any errors. On error, we attempt to remove the conflicting descriptor so the
		-- new one can be registered, restoring keybind strip functionality.
		if ZO_KeybindStrip and type(ZO_KeybindStrip.HandleDuplicateAddKeybind) == "function" then
			local _orig_HandleDuplicate = ZO_KeybindStrip.HandleDuplicateAddKeybind
			ZO_KeybindStrip.HandleDuplicateAddKeybind = function(self, existingButtonOrEtherealDescriptor, keybindButtonDescriptor, state, stateIndex, currentSceneName)
				local ok, res = pcall(function()
					return _orig_HandleDuplicate(self, existingButtonOrEtherealDescriptor, keybindButtonDescriptor, state, stateIndex, currentSceneName)
				end)
				-- If the call succeeded, return normally
				if ok then return res end
				
				-- If the call failed, attempt a safe recovery by removing the conflicting descriptor
				-- so the new keybind can be registered. This ensures LB/RB navigation is restored
				-- even when duplicate handling errors occur.
				pcall(function()
					if existingButtonOrEtherealDescriptor then
						local descriptor = existingButtonOrEtherealDescriptor
						-- If it's a button control, extract the descriptor
						if type(descriptor) == "userdata" and descriptor.keybindButtonDescriptor then
							descriptor = descriptor.keybindButtonDescriptor
						end
						-- Attempt removal
						if descriptor and self.RemoveKeybindButton then
							self:RemoveKeybindButton(descriptor, stateIndex)
						end
					end
				end)
				
				-- Do not log to chat/debug as per user requirement. The keybind strip will
				-- continue, and duplicate handling was attempted (even if it failed gracefully).
			end
		end

		BETTERUI._patchesApplied = true
	end

	-- Initialize research data once
	BETTERUI.GetResearch()

	local settings = BETTERUI.Settings.Modules

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

--- Main initialization function called when the addon loads. Handles loading saved variables from ESO's settings system, setting up default settings on first install by calling each module's InitModule function, registering the options panel, updating CIM state, and loading modules if the player is in gamepad mode.
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