-- BetterUI General Interface Module
-- Settings panel for tooltips, chat history, nameplates, and third-party integrations

local _
local LAM = LibAddonMenu2

-- Initializes settings panel for General Interface options
--- @param mId string: Module ID
--- @param moduleName string: Display name
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "General Interface Settings")

	local optionsTable = {
		{
			type = "checkbox",
			name = "Guild Store Error Suppression",
			tooltip = "Removes guild store error messages caused by MM or ATT",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].guildStoreErrorSuppress end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].guildStoreErrorSuppress = value
		            end,
            disabled = function() return ArkadiusTradeTools == nil and MasterMerchant == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Arkadius Trade Tools",
			tooltip = "Hooks ATT Price info into the item tooltips",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].attIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].attIntegration = value
					end,
			disabled = function() return ArkadiusTradeTools == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Master Merchant integration",
			tooltip = "Hooks Master Merchant into the item tooltips",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].mmIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].mmIntegration = value
					end,
			disabled = function() return MasterMerchant == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Tamriel Trade Centre integration",
			tooltip = "Hooks TTC Price info into the item tooltips",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].ttcIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].ttcIntegration = value
					end,
			disabled = function() return TamrielTradeCentre == nil end,
			width = "full",
			requiresReload = true,
		},
		{
		type = "checkbox",
			name = "Display item style and trait knowledge",
			tooltip = "On items, displays the style of the item and whether the trait can be researched",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].showStyleTrait end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].showStyleTrait = value end,
			width = "full",
		},
		{
            type = "editbox",
            name = "Chat window history size",
            tooltip = "Alters how many lines to store in the chat buffer, default=200",
            getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].chatHistory end,
            setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].chatHistory = tonumber(value)
            							if(ZO_ChatWindowTemplate1Buffer ~= nil) then ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings.Modules["Tooltips"].chatHistory) end end,
            default=200,
            width = "full",
        },
		{
			type = "checkbox",
			name = "Remove confirmation screen when deleting mail",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog end,
			setFunc = function(value)
						BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog = value
					end,
			width = "full",
			requiresReload = true,
		},
		{
            type = "editbox",
            name = "Mouse Scrolling speed on Left Hand tooltip",
            tooltip = "Change how quickly the menu skips when pressing the triggers.",
            getFunc = function() return BETTERUI.Settings.Modules["CIM"].rhScrollSpeed end,
            setFunc = function(value) BETTERUI.Settings.Modules["CIM"].rhScrollSpeed = value end,
            disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
            width = "full",
        },
        {
            type = "editbox",
            name = "Number of lines to skip on trigger",
            tooltip = "Change how quickly the menu skips when pressing the triggers.",
            getFunc = function() return BETTERUI.Settings.Modules["CIM"].triggerSpeed end,
            setFunc = function(value) BETTERUI.Settings.Modules["CIM"].triggerSpeed = value end,
            disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
            width = "full",
        },
		{
            type = "dropdown",
            name = "Tooltip font size",
			tooltip = "Allows more or less item information to be displayed at once in tooltips",
			choices = {"Small", "Default", "Medium", "Large", "XLarge"},
            getFunc = function() return BETTERUI.Settings.Modules["CIM"].tooltipSize end,
            setFunc = function(value) BETTERUI.Settings.Modules["CIM"].tooltipSize = value
                      end,
            disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
            width = "full",
            requiresReload = true,
            default = "Default",
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
				return BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled
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
				return BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].font
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
				return BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].style
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
				return BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].size or 16
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
		-- ============================================================================
		-- BETTERUI ORBS SETTINGS
		-- ============================================================================
		{
			type = "header",
			name = GetString(SI_BETTERUI_ORBS_HEADER),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ORBS_ENABLED),
			tooltip = GetString(SI_BETTERUI_ORBS_ENABLED_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Orbs"].enabled end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Orbs"].enabled = value
				if BETTERUI.Orbs and BETTERUI.Orbs.ApplySettings then
					BETTERUI.Orbs.ApplySettings()
				end
			end,
			width = "full",
		},
		{
			type = "slider",
			name = GetString(SI_BETTERUI_ORBS_SCALE),
			tooltip = GetString(SI_BETTERUI_ORBS_SCALE_TOOLTIP),
			min = 0.8,
			max = 2.0,
			step = 0.05,
			decimals = 2,
			getFunc = function() return BETTERUI.Settings.Modules["Orbs"].scale end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Orbs"].scale = value
				if BETTERUI.Orbs and BETTERUI.Orbs.ApplySettings then
					BETTERUI.Orbs.ApplySettings()
				end
			end,
			disabled = function() return not BETTERUI.Settings.Modules["Orbs"].enabled end,
			default = 1.15,
		},
		{
			type = "slider",
			name = GetString(SI_BETTERUI_ORBS_OFFSET),
			tooltip = GetString(SI_BETTERUI_ORBS_OFFSET_TOOLTIP),
			min = -300,
			max = 300,
			step = 5,
			getFunc = function() return BETTERUI.Settings.Modules["Orbs"].offsetY end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Orbs"].offsetY = value
				if BETTERUI.Orbs and BETTERUI.Orbs.ApplySettings then
					BETTERUI.Orbs.ApplySettings()
				end
			end,
			disabled = function() return not BETTERUI.Settings.Modules["Orbs"].enabled end,
			default = 40,
		},
		{
			type = "checkbox",
			name = GetString(BETTERUI_ORBS_USE_CUSTOM_TEXTURES),
			tooltip = GetString(BETTERUI_ORBS_USE_CUSTOM_TEXTURES_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Orbs"].useCustomTextures end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Orbs"].useCustomTextures = value
				ReloadUI()
			end,
			width = "full",
			warning = "Requires Reload UI",
		},
        {
            type = "checkbox",
            name = GetString(BETTERUI_ORBS_DOUBLE_BAR),
            tooltip = GetString(BETTERUI_ORBS_DOUBLE_BAR_TOOLTIP),
            getFunc = function() return BETTERUI.Settings.Modules["Orbs"].doubleBarEnabled end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["Orbs"].doubleBarEnabled = value
                ReloadUI()
            end,
            width = "full",
            warning = "Requires Reload UI",
        },
	}
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

-- Initializes Orbs default settings
--- @param m_options table: Options table
--- @return table: Initialized options
function BETTERUI.Orbs.InitModule(m_options)
    m_options = m_options or {}
    local defaults = {
        enabled = false,
        scale = 1.15,
        offsetY = 80,
        useHDTextures = false,
        customTextureBasePath = "",
    }
    -- Only set defaults if not already present
    if m_options.enabled == nil then m_options.enabled = defaults.enabled end
    if m_options.scale == nil then m_options.scale = defaults.scale end
    if m_options.offsetY == nil then m_options.offsetY = defaults.offsetY end
    if m_options.useHDTextures == nil then m_options.useHDTextures = defaults.useHDTextures end
    if m_options.customTextureBasePath == nil then m_options.customTextureBasePath = defaults.customTextureBasePath end
    return m_options
end

-- Initializes Nameplates default settings (preserves existing values)
--- @param m_options table: Options table
--- @return table: Initialized options
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

-- Initializes Tooltips default settings
--- @param m_options table: Options table
--- @return table: Initialized options
function BETTERUI.Tooltips.InitModule(m_options)
    m_options["chatHistory"] = 200
    m_options["showStyleTrait"] = true
	m_options["removeDeleteDialog"] = false
	m_options["guildStoreErrorSuppress"] = false
	m_options["attIntegration"] = true
	m_options["mmIntegration"] = true
	m_options["ttcIntegration"] = true
    return m_options
end

-- Sets up Tooltips module: registers hooks, event handlers, and scene callbacks
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
