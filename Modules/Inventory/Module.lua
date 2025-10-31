-------------------------------------------------------------------------------------------------------------------------------------------------------
--
--    BetterUI Inventory Module - Configuration and Setup
--    This module handles inventory-related settings and initializes the custom inventory system
--
-------------------------------------------------------------------------------------------------------------------------------------------------------

local _
local LAM = LibAddonMenu2

local GENERAL_COLOR_WHITE = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1
local GENERAL_COLOR_OFF_WHITE = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3

local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "Inventory Improvement Settings")

	-- Safe refresh helper: only refresh header/footer when inventory scene is visible
	local function SafeRefresh(headerToo)
		if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY_ROOT_SCENE and GAMEPAD_INVENTORY_ROOT_SCENE.IsShowing and GAMEPAD_INVENTORY_ROOT_SCENE:IsShowing() then
			if headerToo and GAMEPAD_INVENTORY.RefreshHeader then
				GAMEPAD_INVENTORY:RefreshHeader(true)
			end
			if BETTERUI and BETTERUI.GenericFooter and BETTERUI.GenericFooter.Refresh then
				BETTERUI.GenericFooter.Refresh(GAMEPAD_INVENTORY)
			end
		end
	end

	local function RecomputeCurrencyOrderString()
		local inv = BETTERUI.Settings.Modules["Inventory"]
		if not inv then return end
		local defaultsOrderIdx = {
			gold = 1, ap = 2, telvar = 3, keys = 4, transmute = 5,
			crowns = 6, gems = 7, writs = 8, tickets = 9, outfit = 10,
		}
		local map = {
			{ key = "gold",     orderKey = "orderCurrencyGold" },
			{ key = "ap",       orderKey = "orderCurrencyAlliancePoints" },
			{ key = "telvar",   orderKey = "orderCurrencyTelVar" },
			{ key = "keys",     orderKey = "orderCurrencyUndauntedKeys" },
			{ key = "transmute",orderKey = "orderCurrencyTransmute" },
			{ key = "crowns",   orderKey = "orderCurrencyCrowns" },
			{ key = "gems",     orderKey = "orderCurrencyCrownGems" },
			{ key = "writs",    orderKey = "orderCurrencyWritVouchers" },
			{ key = "tickets",  orderKey = "orderCurrencyEventTickets" },
			{ key = "outfit",   orderKey = "orderCurrencyOutfitTokens" },
		}
		local items = {}
		for _, m in ipairs(map) do
			local v = tonumber(inv[m.orderKey]) or defaultsOrderIdx[m.key]
			if v < 1 then v = 1 elseif v > 10 then v = 10 end
			table.insert(items, { key = m.key, order = v, tiebreak = defaultsOrderIdx[m.key] })
		end
		table.sort(items, function(a,b)
			if a.order == b.order then
				return a.tiebreak < b.tiebreak
			end
			return a.order < b.order
		end)
		local out = {}
		for i=1,#items do out[i] = items[i].key end
		inv.currencyOrder = table.concat(out, ",")
	end

	local optionsTable = {
		{
			type = "checkbox",
			name = "Enable quick destroy functionality",
			tooltip = "**USE WITH CAUTION** Quickly destroys items without a confirmation dialog or needing to mark as junk",
			getFunc = function() return BETTERUI.Settings.Modules["Inventory"].quickDestroy end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].quickDestroy = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Use triggers to move to next item type",
			tooltip = "Rather than skip a certain number of items every trigger press (default global behaviour), this will move to the next item type",
			getFunc = function() return BETTERUI.Settings.Modules["Inventory"].useTriggersForSkip end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].useTriggersForSkip = value end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Replace \"Value\" with the market's price",
			tooltip = "Replaces the item \"Value\" with either MM's, ATT's or TTC's average price",
			getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showMarketPrice end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].showMarketPrice = value end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Bind on Equip Protection",
			tooltip = "Show a dialog before equipping Bind on Equip items",
			getFunc = function() return BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Item Icon - Unbound Items",
			tooltip = "Show an icon after unbound items",
			getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showIconUnboundItem end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].showIconUnboundItem = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Item Icon - Enchantment",
			tooltip = "Show an icon after enchanted item",
			getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showIconEnchantment end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].showIconEnchantment = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Item Icon - Set Gear",
			tooltip = "Show an icon after set gears",
			getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showIconSetGear end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].showIconSetGear = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "submenu",
			name = "Currency visibility",
			reference = "BETTERUI_Inventory_CurrencyVisibility_Submenu",
			controls = {
				{
					type = "checkbox",
					name = "Gold",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyGold ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyGold = value
						SafeRefresh(true)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Gold order",
					tooltip = "Place Gold in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyGold == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyGold or 1)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyGold = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Alliance Points",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints = value
						SafeRefresh(true)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Alliance Points order",
					tooltip = "Place Alliance Points in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyAlliancePoints or 2)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyAlliancePoints = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Tel Var Stones",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar = value
						SafeRefresh(true)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Tel Var order",
					tooltip = "Place Tel Var Stones in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTelVar or 3)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyTelVar = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Crown Gems",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems = value
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Crown Gems order",
					tooltip = "Place Crown Gems in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrownGems or 7)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrownGems = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Crowns",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns = value
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Crowns order",
					tooltip = "Place Crowns in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrowns or 6)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrowns = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Transmute Crystals",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute = value
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Transmute order",
					tooltip = "Place Transmute Crystals in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTransmute or 5)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyTransmute = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Writ Vouchers",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers = value
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Writ Vouchers order",
					tooltip = "Place Writ Vouchers in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyWritVouchers or 8)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyWritVouchers = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Event Tickets",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyEventTickets ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyEventTickets = value
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Event Tickets order",
					tooltip = "Place Event Tickets in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyEventTickets == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyEventTickets or 9)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyEventTickets = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Undaunted Keys",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys = value
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Undaunted Keys order",
					tooltip = "Place Undaunted Keys in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyUndauntedKeys or 4)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyUndauntedKeys = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "checkbox",
					name = "Outfit Change Tokens",
					getFunc = function() return BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens ~= false end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens = value
						SafeRefresh(false)
					end,
					width = "full",
				},
				{
					type = "slider",
					name = "Outfit Tokens order",
					tooltip = "Place Outfit Change Tokens in order 1 (first) through 10 (last). If multiple currencies share the same number, a default tie-breaker is applied.",
					min = 1,
					max = 10,
					step = 1,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens == false
					end,
					getFunc = function()
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyOutfitTokens or 10)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyOutfitTokens = zo_clamp(value, 1, 10)
						RecomputeCurrencyOrderString()
						SafeRefresh(false)
					end,
					width = "full",
				},
			},
		},
	}
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)

end

--- Initialize inventory module settings with default values
--- @param m_options table: The module options table to initialize
--- @return table: The initialized options table
function BETTERUI.Inventory.InitModule(m_options)
	m_options["showMarketPrice"] = false
	m_options["useTriggersForSkip"] = false
	m_options["bindOnEquipProtection"] = true
	m_options["showIconEnchantment"] = true
	m_options["showIconSetGear"] = true
	m_options["showIconUnboundItem"] = true
	m_options["quickDestroy"] = false

	-- Currency visibility defaults
	m_options["showCurrencyGold"] = true
	m_options["showCurrencyAlliancePoints"] = true
	m_options["showCurrencyTelVar"] = true
	m_options["showCurrencyCrownGems"] = true
	m_options["showCurrencyCrowns"] = true
	m_options["showCurrencyTransmute"] = true
	m_options["showCurrencyWritVouchers"] = true
	m_options["showCurrencyEventTickets"] = true
	m_options["showCurrencyUndauntedKeys"] = true
	m_options["showCurrencyOutfitTokens"] = true

	-- Currency order numeric defaults (1..10) and fallback legacy string
	m_options["orderCurrencyGold"] = 1
	m_options["orderCurrencyAlliancePoints"] = 2
	m_options["orderCurrencyTelVar"] = 3
	m_options["orderCurrencyUndauntedKeys"] = 4
	m_options["orderCurrencyTransmute"] = 5
	m_options["orderCurrencyCrowns"] = 6
	m_options["orderCurrencyCrownGems"] = 7
	m_options["orderCurrencyWritVouchers"] = 8
	m_options["orderCurrencyEventTickets"] = 9
	m_options["orderCurrencyOutfitTokens"] = 10

	m_options["currencyOrder"] = "gold,ap,telvar,keys,transmute,crowns,gems,writs,tickets,outfit"

	return m_options
end

-------------------------------------------------------------------------------------------------------------------------------------------------------
--
--    Helper functions for tooltip configuration
--
-------------------------------------------------------------------------------------------------------------------------------------------------------

--- Sets up tooltip styles based on the configured tooltip size
local function SetupTooltipStyles()
    if BETTERUI.Settings.Modules["CIM"].tooltipSize == "Small" then
        ZO_TOOLTIP_STYLES["topSection"] = {
            layoutPrimaryDirection = "up",
            layoutSecondaryDirection = "right",
            widthPercent = 100,
            childSpacing = 1,
            fontSize = 22,
            height = 64,
            uppercase = true,
            fontColorField = GENERAL_COLOR_OFF_WHITE,
        }
        ZO_TOOLTIP_STYLES["flavorText"] = {
            fontSize = 22,
        }
        ZO_TOOLTIP_STYLES["statValuePairStat"] = {
            fontSize = 22,
            uppercase = true,
            fontColorField = GENERAL_COLOR_OFF_WHITE,
        }
        ZO_TOOLTIP_STYLES["statValuePairValue"] = {
            fontSize = 30,
            fontColorField = GENERAL_COLOR_WHITE,
        }
        ZO_TOOLTIP_STYLES["title"] = {
            fontSize = 32,
            customSpacing = 8,
            uppercase = true,
            fontColorField = GENERAL_COLOR_WHITE,
        }
        ZO_TOOLTIP_STYLES["bodyDescription"] = {
            fontSize = 22,
        }
    elseif BETTERUI.Settings.Modules["CIM"].tooltipSize == "Medium" then
        ZO_TOOLTIP_STYLES["topSection"] = {
            layoutPrimaryDirection = "up",
            layoutSecondaryDirection = "right",
            widthPercent = 100,
            childSpacing = 1,
            fontSize = 25,
            uppercase = true,
            fontColorField = GENERAL_COLOR_OFF_WHITE,
        }
        ZO_TOOLTIP_STYLES["flavorText"] = {
            fontSize = 34,
        }
        ZO_TOOLTIP_STYLES["statValuePairStat"] = {
            fontSize = 27,
            uppercase = true,
            fontColorField = GENERAL_COLOR_OFF_WHITE,
        }
        ZO_TOOLTIP_STYLES["statValuePairValue"] = {
            fontSize = 38,
            fontColorField = GENERAL_COLOR_WHITE,
        }
        ZO_TOOLTIP_STYLES["title"] = {
            fontSize = 34,
            customSpacing = 8,
            widthPercent = 100,
            uppercase = true,
            fontColorField = GENERAL_COLOR_WHITE,
        }
        ZO_TOOLTIP_STYLES["bodyDescription"] = {
            fontSize = 34,
        }
    elseif BETTERUI.Settings.Modules["CIM"].tooltipSize == "Large" then
        ZO_TOOLTIP_STYLES["topSection"] = {
            layoutPrimaryDirection = "up",
            layoutSecondaryDirection = "right",
            widthPercent = 100,
            childSpacing = 1,
            fontSize = 27,
            height = 64,
            uppercase = true,
            fontColorField = GENERAL_COLOR_OFF_WHITE,
        }
        ZO_TOOLTIP_STYLES["flavorText"] = {
            fontSize = 38,
        }
        ZO_TOOLTIP_STYLES["statValuePairStat"] = {
            fontSize = 27,
            uppercase = true,
            fontColorField = GENERAL_COLOR_OFF_WHITE,
        }
        ZO_TOOLTIP_STYLES["statValuePairValue"] = {
            fontSize = 42,
            fontColorField = GENERAL_COLOR_WHITE,
        }
        ZO_TOOLTIP_STYLES["title"] = {
            fontSize = 38,
            customSpacing = 8,
            widthPercent = 100,
            uppercase = true,
            fontColorField = GENERAL_COLOR_WHITE,
        }
        ZO_TOOLTIP_STYLES["bodyDescription"] = {
            fontSize = 38,
        }
    end
end

--- Sets up mouse wheel scrolling for tooltips
local function SetupTooltipMouseWheel()
	local tip = ZO_GamepadTooltipTopLevelLeftTooltipContainerTip
	local tipScroll = ZO_GamepadTooltipTopLevelLeftTooltipContainerTipScroll
	if tip and tipScroll then
		tip:SetMouseEnabled(true)
		tipScroll:SetMouseEnabled(true)
		tip:SetHandler("OnMouseWheel", function(self, delta)
			local speed = (BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["CIM"] and BETTERUI.Settings.Modules["CIM"].rhScrollSpeed) or 20
			local newScrollValue
			if delta > 0 then
				newScrollValue = (self.scrollValue or 0) - speed
			else
				newScrollValue = (self.scrollValue or 0) + speed
			end
			self.scrollValue = newScrollValue
			if self.scroll and self.scroll.SetVerticalScroll then
				self.scroll:SetVerticalScroll(newScrollValue)
			end
		end)
	end
end
-------------------------------------------------------------------------------------------------------------------------------------------------------
--
--    Finally, the Setup() function which replaces the inventory system with a duplicate that I've heavily modified. Duplication is necessary as I don't
--    have access to the beginning :New() method of ZO_GamepadInventory. Will mess quite a few addons up, but will make GAMEPAD_INVENTORY a reference at the end
--
-------------------------------------------------------------------------------------------------------------------------------------------------------

function BETTERUI.Inventory.Setup()
	Init("Inventory", "Inventory")

	GAMEPAD_INVENTORY = BETTERUI.Inventory.Class:New(BETTERUI_GamepadInventoryTopLevel) -- Bam! Initialise the custom inventory class so it's integrated neatly

	GAMEPAD_INVENTORY_FRAGMENT = ZO_SimpleSceneFragment:New(BETTERUI_GamepadInventoryTopLevel) -- **Replaces** the old inventory with a new one defined in "Templates/GamepadInventory.xml"
	GAMEPAD_INVENTORY_FRAGMENT:SetHideOnSceneHidden(true)

	-- Now update the changes throughout the interface...
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_INVENTORY_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(MINIMIZE_CHAT_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)

	-- Configure tooltip appearance and behavior
	ZO_GamepadTooltipTopLevelLeftTooltipContainer.tip.maxFadeGradientSize = 10
	SetupTooltipStyles()
	SetupTooltipMouseWheel()

	-- Position tooltip container
	local TOOLTIP_X_OFFSET = 40
	local TOOLTIP_Y_OFFSET = -100
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.fragment.control.container:SetAnchor(3, ZO_GamepadTooltipTopLevelLeftTooltip, 3, TOOLTIP_X_OFFSET, TOOLTIP_Y_OFFSET, 0)

	-- Store reference for other modules
	inv = GAMEPAD_INVENTORY

	-- Register custom dialog for Bind on Equip protection (only if SaveEquip addon is not present)
	if not SaveEquip then
		ZO_Dialogs_RegisterCustomDialog("CONFIRM_EQUIP_BOE", {
			gamepadInfo = {
				dialogType = GAMEPAD_DIALOGS.BASIC,
			},
			title = {
				text = SI_SAVE_EQUIP_CONFIRM_TITLE,
			},
			mainText = {
				text = SI_SAVE_EQUIP_CONFIRM_EQUIP_BOE,
			},
			buttons = {
				[1] = {
					text = SI_SAVE_EQUIP_EQUIP,
					callback = function(dialog)
						dialog.data.callback()
					end
				},
				[2] = {
					text = SI_DIALOG_CANCEL,
				}
			}
		})
	end
end
