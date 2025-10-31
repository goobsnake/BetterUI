local _
local LAM = LibAddonMenu2

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
			choices = {"Small", "Medium", "Large", "Default"},
            getFunc = function() return BETTERUI.Settings.Modules["CIM"].tooltipSize end,
            setFunc = function(value) BETTERUI.Settings.Modules["CIM"].tooltipSize = value
                      end,
            disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
            width = "full",
            requiresReload = true,
            default = "Default",
        },
        {
            type = "dropdown",
            name = "Interface and item list font size",
			tooltip = "Changes the font size of listed items in the inventory and bank. Different sizes make you see more or less items at once.",
			choices = {"Default", "Medium", "Large"},
            getFunc = function() return BETTERUI.Settings.Modules["CIM"].skinSize end,
            setFunc = function(value) BETTERUI.Settings.Modules["CIM"].skinSize = value
                      end,
            disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
            width = "full",
            requiresReload = true,
            default = "Default",
        },
	}
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

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

	if(ZO_ChatWindowTemplate1Buffer ~= nil) then ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings.Modules["Tooltips"].chatHistory) end
end
