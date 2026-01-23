-- BetterUI.lua
---
--- Purpose: Main entry point for the BetterUI addon.
---          Handles module initialization, event registration, and runtime patches.
--- Mechanics: Listens for EVENT_ADD_ON_LOADED to initialize itself.
---            Manages the loading of sub-modules based on Gamepad mode.
---

local LAM = LibAddonMenu2

if BETTERUI == nil then BETTERUI = {} end


-- Shared font choices for Inventory (matches Nameplates for consistency)
BETTERUI.Inventory = BETTERUI.Inventory or {}


-- ============================================================================
-- SETTINGS HELPER FACTORY
-- ============================================================================

--[[
Function: CreateSettingAccessors
Description: Factory to generate getFunc/setFunc/disabled for LAM settings.
Rationale: Reduces repetitive code across 50+ settings definitions.
param: moduleName (string) - The settings module name (e.g., "Nameplates", "Tooltips")
param: settingKey (string) - The key within the module settings table
param: applyCallback (function|nil) - Optional callback to run after setting is changed
param: defaultValue (any|nil) - Optional default value if setting is nil
return: table - { get = function, set = function, disabled = function }
]]
function BETTERUI.CreateSettingAccessors(moduleName, settingKey, applyCallback, defaultValue)
    return {
        get = function()
            local settings = BETTERUI.Settings.Modules[moduleName]
            if not settings then return defaultValue end
            local value = settings[settingKey]
            if value == nil then return defaultValue end
            return value
        end,
        set = function(value)
            if BETTERUI.Settings.Modules[moduleName] then
                BETTERUI.Settings.Modules[moduleName][settingKey] = value
                if applyCallback then
                    applyCallback(value)
                end
            end
        end,
        disabled = function()
            return not BETTERUI.Settings.Modules[moduleName]
        end
    }
end

--- Updates the Common Interface Module (CIM) state based on dependents.
---
--- Purpose: Ensures CIM is enabled if any module requiring it (Inventory, Banking) is active.
--- Mechanics: Checks settings for Tooltips, Inventory, and Banking.
---            Updates the CIM m_enabled setting accordingly.
--- References: Called when toggling module settings in the options panel.
---
function BETTERUI.UpdateCIMState()
	local settings = BETTERUI.Settings.Modules
	local shouldEnable = settings["Tooltips"].m_enabled or
	                    settings["Inventory"].m_enabled or
	                    settings["Banking"].m_enabled
	settings["CIM"].m_enabled = shouldEnable
end

--- Initializes the module options panel in the settings menu.
---
--- Purpose: Registers the add-on settings panel using LibAddonMenu2.
--- Mechanics: Construct a table of options including checkboxes for each module.
---            Registers the panel and options with LAM.
--- References: Called during BETTERUI.Initialize.
---
function BETTERUI.InitModuleOptions()
	local panelData = Init_ModulePanel("Master", GetString(SI_BETTERUI_MASTER_SETTINGS_TITLE))

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
            -- TODO(refactor): Rename "Tooltips" module key to "GeneralInterface".
            -- Also standardize settings property names:
            --   CURRENT: m_enabled (Tooltips, Inventory, Banking, Writs, CIM)
            --            enabled (ResourceOrbFrames)
            --   TARGET: All modules should use either 'm_enabled' OR 'enabled' consistently.
            -- Recommend: Use 'enabled' (simpler) and migrate m_enabled during next major version.
            -- TODO(refactor): Rename "Tooltips" module key to "GeneralInterface" to avoid confusion.
            -- Currently "Tooltips" acts as the master switch for the entire General Interface module.
			tooltip = GetString(SI_BETTERUI_ENABLE_TOOLTIPS_TOOLTIP),
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
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
				return BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled 
			end,
			setFunc = function(value)
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then BETTERUI.Settings.Modules["ResourceOrbFrames"] = {} end
				BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled = value
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

	LAM:RegisterAddonPanel("BETTERUI_".."Modules", panelData)
	LAM:RegisterOptionControls("BETTERUI_".."Modules", optionsTable)
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
--- Mechanics: Applies runtime patches for API compatibility.
---            Initializes research data and module-specific setups (Inventory, Banking, Wraps, etc.).
---            Includes Monkey-Patches for ZO_Global functions to prevent crashes with nil icon paths.
--- References: Called on initialization and when switching to Gamepad mode.
--- References: Called on initialization and when switching to Gamepad mode.
---
function BETTERUI.LoadModules()
	if BETTERUI._initialized then return end

	ddebug("Initializing BETTERUI...")

	-- Apply runtime safety patches for ESO API issues (nil icon paths)
	if not BETTERUI._patchesApplied then
		-- Patch 1: Wrap global icon/text formatting helpers to handle nil paths gracefully.
		-- TODO(refactor): The zo_icon* patches use pcall for safety but are well-documented.
		-- Consider extracting to Modules/CIM/RuntimePatches.lua for better organization.
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
				
				-- Schedule a deferred re-add of the new keybind to handle timing edge cases where
				-- removal and re-add happen too quickly in the same frame. This is especially important
				-- during scene transitions (like search enter/exit) where multiple duplicate keybind
				-- errors may occur in quick succession. Use zo_callLater with a 0ms delay to defer
				-- until the next frame cycle, ensuring the removal has settled.
				pcall(function()
					if zo_callLater and type(zo_callLater) == "function" then
						zo_callLater(function()
							pcall(function()
								-- Only re-add if not already present
								if self and self.HasKeybindButton then
									local present = self:HasKeybindButton(keybindButtonDescriptor, stateIndex)
									if not present then
										self:AddKeybindButton(keybindButtonDescriptor, stateIndex)
										-- Force update keybind strip layout to ensure buttons are visible
										if self.UpdateAnchors then
											self:UpdateAnchors()
										end
									end
								end
							end)
						end, 0)
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

	-- Initialize General Interface (Settings & Tooltips)
	-- We call this conditionally (based on Master Setting "Enable General Interface Improvements")
	if settings["Tooltips"].m_enabled and BETTERUI.GeneralInterface and BETTERUI.GeneralInterface.Setup then
		BETTERUI.GeneralInterface.Setup()
	end

	-- Initialize Independent modules (Settings-aware)
    -- Nameplates (Dependent on General Interface Master Setting)
	if settings["Tooltips"].m_enabled and settings["Nameplates"].m_enabled and BETTERUI.Nameplates and BETTERUI.Nameplates.Setup then
		BETTERUI.Nameplates.Setup()
	end

	-- Resource Orb Frames
    -- Logic: If enabled, load it. If disabled, do NOT load it (so settings panel won't register).
	if settings["ResourceOrbFrames"].enabled and BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.Setup then
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

	-- Initialize module settings on first install
	if BETTERUI.Settings.firstInstall then
		local modules = {
			{"CIM", BETTERUI.CIM},
			{"Inventory", BETTERUI.Inventory},
			{"Banking", BETTERUI.Banking},
			{"Writs", BETTERUI.Writs},
			{"Tooltips", BETTERUI.Tooltips},
			{"Nameplates", BETTERUI.Nameplates},
			{"ResourceOrbFrames", BETTERUI.ResourceOrbFrames}
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

	-- Ensure ResourceOrbFrames module settings exist for existing users
	if BETTERUI.Settings.Modules["ResourceOrbFrames"] == nil then
		BETTERUI.Settings.Modules["ResourceOrbFrames"] = {}
	end
	if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.InitModule then
		BETTERUI.ResourceOrbFrames.InitModule(BETTERUI.Settings.Modules["ResourceOrbFrames"])
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
	-- Ensure companion equip patch is queued even if modules didn't hook above
	if BETTERUI.Inventory and BETTERUI.Inventory.EnsureCompanionEquipPatched then
		BETTERUI.Inventory.EnsureCompanionEquipPatched()
	end
end

-- Event handlers for initialization and gamepad mode changes
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED, function(...) BETTERUI.Initialize(...) end)
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name.."_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function(code, inGamepad) BETTERUI.LoadModules() end)