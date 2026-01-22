---------------------------------------------------------------------------------------------------
-- BetterUI - General Interface Module
--
-- This module acts as the central configuration hub for various General Interface enhancements.
-- It integrates with LibAddonMenu to provide settings for:
-- 1. Tooltips: Font size, MasterMerchant/TTC integration, and mail deletion confirmation.
-- 2. Nameplates: Enabling/disabling, font customization, and style adjustments.
-- 3. Resource Orb Frames: Configuration for the custom resource orb UI (Health/Magicka/Stamina).
--
-- ARCHITECTURE:
--   This file defines the settings panel structure using LAM (LibAddonMenu2).
--   Actual functionality is implemented in separate files:
--     - Tooltips.lua: Tooltip enhancement logic
--     - Nameplates.lua: Nameplate font customization
--     - ResourceOrbFrames.lua: Orb UI implementation
--
-- TODO(architecture): This file is 1100+ lines and hard to navigate. Consider splitting
--                     settings into separate files per feature (TooltipSettings, NameplateSettings, etc.)
-- TODO(refactor): Many setFunc callbacks duplicate the pattern of updating setting + calling ApplySettings.
--                 Extract to helper function like `createSettingSetter(settingsPath, callback)`
-- TODO(cleanup): Some settings check for module existence multiple times in get/set/disabled.
--                Could be consolidated into wrapper functions.
---------------------------------------------------------------------------------------------------

local _
local LAM = LibAddonMenu2

--- Initializes the settings panel for General Interface options.
---
--- Purpose: Creates a LibAddonMenu panel with all configurable options.
--- Mechanics:
--- - Defines `optionsTable` with checkboxes, sliders, and submenus.
--- - Configures integration settings (MasterMerchant, TTC, ATT).
--- - Configures Nameplate settings (Font, Style, Size).
--- - Configures Resource Orb Frames (Scale, Offset, Colors).
--- - Configures Experience/Cast/Mount Bar settings.
--- - Uses `LAM:RegisterAddonPanel` and `LAM:RegisterOptionControls`.
---
--- References: Called during module setup.
---
--- @param mId string The Module ID (unused, for standardized module signature)
--- @param moduleName string The display name of the module for the settings panel
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "General Interface Settings")

	local optionsTable = {
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_GS_ERROR_SUPPRESS),
			tooltip = GetString(SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Tooltips"] then return false end
				return BETTERUI.Settings.Modules["Tooltips"].guildStoreErrorSuppress 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].guildStoreErrorSuppress = value
		            end,
            disabled = function() return ArkadiusTradeTools == nil and MasterMerchant == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ATT_INTEGRATION),
			tooltip = GetString(SI_BETTERUI_ATT_INTEGRATION_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].attIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].attIntegration = value
					end,
			disabled = function() return ArkadiusTradeTools == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_MM_INTEGRATION),
			tooltip = GetString(SI_BETTERUI_MM_INTEGRATION_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].mmIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].mmIntegration = value
					end,
			disabled = function() return MasterMerchant == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_TTC_INTEGRATION),
			tooltip = GetString(SI_BETTERUI_TTC_INTEGRATION_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].ttcIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].ttcIntegration = value
					end,
			disabled = function() return TamrielTradeCentre == nil end,
			width = "full",
			requiresReload = true,
		},
		{
		type = "checkbox",
			name = GetString(SI_BETTERUI_SHOW_STYLE_TRAIT),
			tooltip = GetString(SI_BETTERUI_SHOW_STYLE_TRAIT_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].showStyleTrait end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].showStyleTrait = value end,
			width = "full",
		},
		{
            type = "editbox",
            name = GetString(SI_BETTERUI_CHAT_HISTORY),
            tooltip = GetString(SI_BETTERUI_CHAT_HISTORY_TOOLTIP),
            getFunc = function() 
				if not BETTERUI.Settings.Modules["Tooltips"] then return 200 end
				return BETTERUI.Settings.Modules["Tooltips"].chatHistory or 200
			end,
            setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].chatHistory = tonumber(value)
            							if(ZO_ChatWindowTemplate1Buffer ~= nil) then ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings.Modules["Tooltips"].chatHistory) end end,
            default=200,
            width = "full",
        },
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog end,
			setFunc = function(value)
						BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog = value
					end,
			width = "full",
			requiresReload = true,
		},

		{
            type = "editbox",
            name = GetString(SI_BETTERUI_MOUSE_SCROLL_SPEED),
            tooltip = GetString(SI_BETTERUI_MOUSE_SCROLL_SPEED_TOOLTIP),
            getFunc = function() 
				if not BETTERUI.Settings.Modules["CIM"] then return 50 end
				return tostring(BETTERUI.Settings.Modules["CIM"].rhScrollSpeed)
			end,
            setFunc = function(value) 
				if BETTERUI.Settings.Modules["CIM"] then
					BETTERUI.Settings.Modules["CIM"].rhScrollSpeed = tonumber(value) or 50 
				end
			end,
            disabled = function() return not (BETTERUI.Settings.Modules["CIM"] and BETTERUI.Settings.Modules["CIM"].m_enabled) end,
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(SI_BETTERUI_TRIGGER_SKIP),
            tooltip = GetString(SI_BETTERUI_TRIGGER_SKIP_TOOLTIP),
            getFunc = function() 
				if not BETTERUI.Settings.Modules["CIM"] then return 10 end
				return tostring(BETTERUI.Settings.Modules["CIM"].triggerSpeed) 
			end,
            setFunc = function(value) 
				if BETTERUI.Settings.Modules["CIM"] then
					BETTERUI.Settings.Modules["CIM"].triggerSpeed = tonumber(value) or 10 
				end
			end,
            disabled = function() return not (BETTERUI.Settings.Modules["CIM"] and BETTERUI.Settings.Modules["CIM"].m_enabled) end,
            width = "full",
        },
		{
            type = "checkbox",
            name = "Enable BetterUI Tooltip Enhancements",
            tooltip = "Enables custom improvements, font scaling, and additional info in the tooltip header. If disabled, reverts to native UI with only Market Price added.\n\nNOTE: Tooltip Font Scaling requires this to be ENABLED.",
            getFunc = function() 
                local settings = BETTERUI.Settings.Modules["CIM"]
                if not settings then return false end
                if settings.enableTooltipEnhancements == nil then return false end
                return settings.enableTooltipEnhancements
            end,
            setFunc = function(value) 
                BETTERUI.Settings.Modules["CIM"].enableTooltipEnhancements = value 
            end,
            width = "full",
            requiresReload = true,
            default = false,
        },
        {
            type = "slider",
            name = "BetterUI Tooltip Font Size",
			tooltip = GetString(SI_BETTERUI_TOOLTIP_FONT_SIZE_TOOLTIP),
			min = 12,
			max = 48,
			step = 1,
            getFunc = function() 
                local settings = BETTERUI.Settings.Modules["CIM"]
                local val = 24
                if settings then
                    val = settings.tooltipSize or val
                end

                return val
            end,
            setFunc = function(value) BETTERUI.Settings.Modules["CIM"].tooltipSize = value end,
            disabled = function() 
                local settings = BETTERUI.Settings.Modules["CIM"]
                if not settings then return true end
                -- Disabled unless tooltip enhancements are enabled
                return settings.enableTooltipEnhancements ~= true 
            end,
            width = "full",
            requiresReload = true,
            default = 24,
        },
		-- ============================================================================
		-- ENHANCED NAMEPLATES SETTINGS
		-- ============================================================================
		{
			type = "header",
			name = GetString(SI_BETTERUI_NAMEPLATES_HEADER),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BETTERUI_NAMEPLATES_DESC),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_NAMEPLATES_ENABLED),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP),
			default = false,
			getFunc = function()
				return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled) or false
			end,
			setFunc = function(value)
				if BETTERUI.Settings.Modules["Nameplates"] then
					BETTERUI.Settings.Modules["Nameplates"].enabled = value
					if BETTERUI.Nameplates and BETTERUI.Nameplates.OnEnabledChanged then
						BETTERUI.Nameplates.OnEnabledChanged(value)
					end
				end
			end,
			width = "full",
		},
		{
			type = "dropdown",
			name = GetString(SI_BETTERUI_NAMEPLATES_FONT),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_FONT_TOOLTIP),
			choices = BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_CHOICES or {},
			choicesValues = BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_VALUES or {},
			default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.font,
			getFunc = function()
				local defaults = (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS) or {font="EsoUI/Common/Fonts/Univers57.otf"}
				return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].font) or defaults.font
			end,
			setFunc = function(value)
				if BETTERUI.Settings.Modules["Nameplates"] then
					BETTERUI.Settings.Modules["Nameplates"].font = value
					if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
						BETTERUI.Nameplates.ApplyCurrentSettings()
					end
				end
			end,
			disabled = function()
				return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled)
			end,
			width = "full",
			scrollable = true,
		},
		{
			type = "dropdown",
			name = GetString(SI_BETTERUI_NAMEPLATES_STYLE),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_STYLE_TOOLTIP),
			choices = BETTERUI.Nameplates and BETTERUI.Nameplates.FONTSTYLE_CHOICES or {},
			choicesValues = BETTERUI.Nameplates and BETTERUI.Nameplates.FONTSTYLE_VALUES or {},
			default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.style,
			getFunc = function()
				local defaults = (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS) or {style="outline"}
				return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].style) or defaults.style
			end,
			setFunc = function(value)
				if BETTERUI.Settings.Modules["Nameplates"] then
					BETTERUI.Settings.Modules["Nameplates"].style = value
					if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
						BETTERUI.Nameplates.ApplyCurrentSettings()
					end
				end
			end,
			disabled = function()
				return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled)
			end,
			width = "full",
		},
		{
			type = "slider",
			name = GetString(SI_BETTERUI_NAMEPLATES_SIZE),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_SIZE_TOOLTIP),
			min = 8,
			max = 64,
			step = 1,
			default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.size or 16,
			getFunc = function()
				return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].size) or 16
			end,
			setFunc = function(value)
				if BETTERUI.Settings.Modules["Nameplates"] then
					BETTERUI.Settings.Modules["Nameplates"].size = value
					if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
						BETTERUI.Nameplates.ApplyCurrentSettings()
					end
				end
			end,
			disabled = function()
				return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled)
			end,
			width = "full",
		},
		{
			type = "button",
			name = GetString(SI_BETTERUI_NAMEPLATES_RESET),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_RESET_TOOLTIP),
			func = function()
				if BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Nameplates then
					local defaults = BETTERUI.Nameplates.DEFAULTS
					BETTERUI.Settings.Modules["Nameplates"].font = defaults.font
					BETTERUI.Settings.Modules["Nameplates"].style = defaults.style
					BETTERUI.Settings.Modules["Nameplates"].size = defaults.size
					if BETTERUI.Nameplates.ApplyCurrentSettings then
						BETTERUI.Nameplates.ApplyCurrentSettings()
					end
				end
			end,
			disabled = function()
				return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled)
			end,
			width = "half",
		},
    }
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

--- Initializes Nameplates default settings.
---
--- Purpose: Ensures Nameplate configuration has valid default values.
--- Mechanics:
--- - Checks for enabled state, font path, style (outline/soft-shadow-thick), and size.
--- - Preserves existing values if present.
---
--- References: Called during module initialization.
---
--- @param m_options table The options table to initialize.
--- @return table The initialized options table.
function BETTERUI.Nameplates.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.Nameplates.DEFAULTS
    -- Only set defaults if not already present (preserve existing settings)
    if m_options.enabled == nil then m_options.enabled = defaults.enabled end
    if m_options.font == nil then m_options.font = defaults.font end
    if m_options.style == nil then m_options.style = defaults.style end
    if m_options.size == nil then m_options.size = defaults.size end
    return m_options
end

--- Initializes Tooltips default settings.
---
--- Purpose: Sets defaults for chat history, trait visibility, mail handling, and integrations.
--- Mechanics:
--- - Default Chat History: 200 lines.
--- - Integrations (MM, TTC, ATT) enabled by default.
--- - Guild Store error suppression disabled by default.
---
--- References: Called during module initialization.
---
--- @param m_options table The options table to initialize.
--- @return table The initialized options table.
function BETTERUI.Tooltips.InitModule(m_options)
    if m_options["chatHistory"] == nil then m_options["chatHistory"] = 200 end
    if m_options["showStyleTrait"] == nil then m_options["showStyleTrait"] = true end
    if m_options["removeDeleteDialog"] == nil then m_options["removeDeleteDialog"] = false end
    if m_options["guildStoreErrorSuppress"] == nil then m_options["guildStoreErrorSuppress"] = false end
    if m_options["attIntegration"] == nil then m_options["attIntegration"] = true end
    if m_options["mmIntegration"] == nil then m_options["mmIntegration"] = true end
    if m_options["ttcIntegration"] == nil then m_options["ttcIntegration"] = true end
    return m_options
end

--- Sets up the General Interface (Tooltips) module.
---
--- Purpose: Registers hooks and event handlers for tooltip enhancements.
--- Mechanics:
--- 1. Calls local `Init` to build the settings menu.
--- 2. Defines `ZO_IsIngameUI` polyfill if missing (for Scribing).
--- 3. Hooks `ZO_MailInbox_Gamepad` to allow 'X' keybind for deletion if enabled.
--- 4. Hooks Gamepad Tooltips (`LayoutItem`, `LayoutBagItem`, etc.) to inject custom data.
--- 5. Manages Guild Store error suppression based on scene state (`gamepad_trading_house`).
--- 6. Registers inventory update events to invalidate trait caches.
--- 7. Applies chat history limit.
---
--- References: Called by the core Addon initialization.
---
function BETTERUI.Tooltips.Setup()

	Init("General", "General Interface")

	if IsPrivateFunction('IsInUI') then
		ZO_IsIngameUI = function()
			return SCRIBING_DATA_MANAGER ~= nil
		end
	end

	if BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog then
		BETTERUI.PostHook(ZO_MailInbox_Gamepad, 'InitializeKeybindDescriptors', function(self)
			self.mainKeybindDescriptor[3]["callback"] = function() self:Delete() end
		end)
	end

	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink, "LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)
	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink, "LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)
	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_MOVABLE_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink, "LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)



	-- Move guild store error suppression to scene lifecycle to avoid frequent toggling during tooltip draws
	if BETTERUI.Settings.Modules["Tooltips"].guildStoreErrorSuppress then
		local scene = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes['gamepad_trading_house']
		if scene then
			scene:RegisterCallback("StateChange", function(oldState, newState)
				if newState == SCENE_SHOWING then
					EVENT_MANAGER:UnregisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
					gsErrorSuppress = 1
				elseif newState == SCENE_HIDDEN then
					EVENT_MANAGER:RegisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
					gsErrorSuppress = 0
				end
			end)
		end
	end

	-- Invalidate researchable trait cache on inventory changes
	local function invalidateCacheOnUpdate(_, bagId)
		if BETTERUI and BETTERUI.Tooltips and BETTERUI.Tooltips.InvalidateResearchableTraitCache then
			BETTERUI.Tooltips.InvalidateResearchableTraitCache(bagId)
		end
	end

	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvSingle", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, invalidateCacheOnUpdate)
	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvFull", EVENT_INVENTORY_FULL_UPDATE, invalidateCacheOnUpdate)

	if(ZO_ChatWindowTemplate1Buffer ~= nil) then ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings.Modules["Tooltips"].chatHistory) end
end
