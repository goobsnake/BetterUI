--[[
File: Modules/Inventory/InventorySettings.lua
Purpose: Handles font definitions, currency presets, and the LAM settings panel.
Author: BetterUI Team
Last Modified: 2026-01-23
]]

local LAM = LibAddonMenu2

-- Shared font choices for Inventory
BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.FONT_CHOICES = {
	"Univers 57 (Default)",
	"Univers 67 (Bold)",
	"Futura Condensed Light",
	"Futura Condensed Medium",
	"Futura Condensed Bold",
	"Prose Antique",
	"Handwritten Bold",
	"Trajan Pro",
	"Skyrim Handwritten",
	"Consolas",
}

BETTERUI.Inventory.FONT_VALUES = {
	"EsoUI/Common/Fonts/Univers57.otf",
	"EsoUI/Common/Fonts/Univers67.otf",
	"EsoUI/Common/Fonts/FTN47.otf",
	"EsoUI/Common/Fonts/FTN57.otf",
	"EsoUI/Common/Fonts/FTN87.otf",
	"EsoUI/Common/Fonts/ProseAntiquePSMT.otf",
	"EsoUI/Common/Fonts/Handwritten_Bold.otf",
	"EsoUI/Common/Fonts/TrajanPro-Regular.otf",
	"EsoUI/Common/Fonts/Skyrim_Handwritten.otf",
	"EsoUI/Common/Fonts/consola.otf",
}

BETTERUI.Inventory.FONTSTYLE_CHOICES = {
	"Normal",
	"Outline",
	"Thick Outline",
	"Shadow",
	"Soft Shadow (Thick)",
	"Soft Shadow (Thin)",
}

BETTERUI.Inventory.FONTSTYLE_VALUES = {
	"",               -- Normal (no style suffix)
	"outline",        -- Outline
	"thick-outline",  -- Thick Outline
	"shadow",         -- Shadow
	"soft-shadow-thick", -- Soft Shadow (Thick)
	"soft-shadow-thin", -- Soft Shadow (Thin)
}

BETTERUI.Inventory.DEFAULTS = {
	nameFont = "EsoUI/Common/Fonts/FTN57.otf",
	nameFontSize = 24,
	nameFontStyle = "",
	columnFont = "EsoUI/Common/Fonts/FTN57.otf",
	columnFontSize = 24,
	columnFontStyle = "",
}

--- Converts a font size setting to a pixel value.
local function GetFontSizeValue(sizeValue)
	if type(sizeValue) == "number" then
		return sizeValue
	end
	return 24
end

--- Returns the ESO font descriptor for the Name column.
function BETTERUI.Inventory.GetNameFontDescriptor()
	local s = BETTERUI.Settings.Modules["Inventory"]
	local d = BETTERUI.Inventory.DEFAULTS
	local path = s.nameFont or d.nameFont
	local size = GetFontSizeValue(s.nameFontSize or d.nameFontSize)
	local style = s.nameFontStyle or d.nameFontStyle
	return style ~= "" and string.format("%s|%d|%s", path, size, style) or string.format("%s|%d", path, size)
end

--- Returns the ESO font descriptor for other columns (Type, Trait, Stat, Value).
--- Returns the ESO font descriptor for other columns (Type, Trait, Stat, Value).
function BETTERUI.Inventory.GetColumnFontDescriptor()
	local s = BETTERUI.Settings.Modules["Inventory"]
	local d = BETTERUI.Inventory.DEFAULTS
	local path = s.columnFont or d.columnFont
	local size = GetFontSizeValue(s.columnFontSize or d.columnFontSize)
	local style = s.columnFontStyle or d.columnFontStyle
	return style ~= "" and string.format("%s|%d|%s", path, size, style) or string.format("%s|%d", path, size)
end

--- Retrieves a setting value for the Inventory module.
--- @param key string The setting key.
--- @return any The setting value or nil.
function BETTERUI.Inventory.GetSetting(key)
	if not BETTERUI.Settings.Modules["Inventory"] then return nil end
	return BETTERUI.Settings.Modules["Inventory"][key]
end

--- Sets a setting value for the Inventory module.
--- @param key string The setting key.
--- @param value any The value to set.
function BETTERUI.Inventory.SetSetting(key, value)
	if not BETTERUI.Settings.Modules["Inventory"] then return end
	BETTERUI.Settings.Modules["Inventory"][key] = value
end

--- Initializes the settings panel for the Inventory module.
function BETTERUI.Inventory.RegisterSettings(mId, moduleName)
	local panelData = BETTERUI.Init_ModulePanel(moduleName, "Inventory Improvement Settings")

	-- Safe refresh helper: only refresh header/footer when inventory scene is visible
	local function SafeRefresh(headerToo)
		if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY_ROOT_SCENE and GAMEPAD_INVENTORY_ROOT_SCENE.IsShowing and GAMEPAD_INVENTORY_ROOT_SCENE:IsShowing() then
			if headerToo and GAMEPAD_INVENTORY.RefreshHeader then
				GAMEPAD_INVENTORY:RefreshHeader(true)
			end
			if BETTERUI and BETTERUI.GenericFooter and BETTERUI.GenericFooter.Refresh then
				BETTERUI.GenericFooter:Refresh()
			end
		end
	end

	local function CanEnableMoreCurrencies()
		local inv = BETTERUI.Settings.Modules["Inventory"]
		if not inv then return false end
		local keys = {
			"showCurrencyGold", "showCurrencyAlliancePoints", "showCurrencyTelVar",
			"showCurrencyUndauntedKeys", "showCurrencyTransmute", "showCurrencyCrowns",
			"showCurrencyCrownGems", "showCurrencyWritVouchers", "showCurrencyTradeBars",
			"showCurrencyOutfitTokens", "showCurrencySeals", "showCurrencyTomePoints"
		}
		local count = 0
		for _, k in ipairs(keys) do
			if inv[k] ~= false then count = count + 1 end
		end
		return count < BETTERUI_MAX_VISIBLE_CURRENCIES
	end

	local function RecomputeCurrencyOrderString()
		local inv = BETTERUI.Settings.Modules["Inventory"]
		if not inv then return end
		local defaultsOrderIdx = {
			gold = 1,
			ap = 2,
			telvar = 3,
			keys = 4,
			transmute = 5,
			crowns = 6,
			gems = 7,
			writs = 8,
			tradebars = 9,
			outfit = 10,
			seals = 11,
			tomepoints = 12,
		}
		local map = {
			{ key = "gold",       orderKey = "orderCurrencyGold" },
			{ key = "ap",         orderKey = "orderCurrencyAlliancePoints" },
			{ key = "telvar",     orderKey = "orderCurrencyTelVar" },
			{ key = "keys",       orderKey = "orderCurrencyUndauntedKeys" },
			{ key = "transmute",  orderKey = "orderCurrencyTransmute" },
			{ key = "crowns",     orderKey = "orderCurrencyCrowns" },
			{ key = "gems",       orderKey = "orderCurrencyCrownGems" },
			{ key = "writs",      orderKey = "orderCurrencyWritVouchers" },
			{ key = "tradebars",  orderKey = "orderCurrencyTradeBars" },
			{ key = "outfit",     orderKey = "orderCurrencyOutfitTokens" },
			{ key = "seals",      orderKey = "orderCurrencySeals" },
			{ key = "tomepoints", orderKey = "orderCurrencyTomePoints" },
		}
		local items = {}
		for _, m in ipairs(map) do
			local v = tonumber(inv[m.orderKey]) or defaultsOrderIdx[m.key]
			if v < 1 then v = 1 elseif v > 12 then v = 12 end
			table.insert(items, { key = m.key, order = v, tiebreak = defaultsOrderIdx[m.key] })
		end
		table.sort(items, function(a, b)
			if a.order == b.order then
				return a.tiebreak < b.tiebreak
			end
			return a.order < b.order
		end)
		local out = {}
		for i = 1, #items do out[i] = items[i].key end
		inv.currencyOrder = table.concat(out, ",")
	end

	local CURRENCY_ORDER_CHOICES = {
		GetString(SI_BETTERUI_CURRENCY_POS_1), GetString(SI_BETTERUI_CURRENCY_POS_2),
		GetString(SI_BETTERUI_CURRENCY_POS_3), GetString(SI_BETTERUI_CURRENCY_POS_4),
		GetString(SI_BETTERUI_CURRENCY_POS_5), GetString(SI_BETTERUI_CURRENCY_POS_6),
		GetString(SI_BETTERUI_CURRENCY_POS_7), GetString(SI_BETTERUI_CURRENCY_POS_8),
		GetString(SI_BETTERUI_CURRENCY_POS_9), GetString(SI_BETTERUI_CURRENCY_POS_10),
		GetString(SI_BETTERUI_CURRENCY_POS_11), GetString(SI_BETTERUI_CURRENCY_POS_12),
	}
	local CURRENCY_ORDER_VALUES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

	local optionsTable = {
		-- Quick Destroy
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_QUICK_DESTROY),
			tooltip = GetString(SI_BETTERUI_QUICK_DESTROY_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("quickDestroy")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("quickDestroy", value) end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV),
			tooltip = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("enableCarousel")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("enableCarousel", value) end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_TRIGGER_SKIP_TYPE),
			tooltip = GetString(SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("useTriggersForSkip")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("useTriggersForSkip", value) end,
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_SHOW_MARKET_PRICE),
			tooltip = GetString(SI_BETTERUI_SHOW_MARKET_PRICE_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("showMarketPrice")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("showMarketPrice", value) end,
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_BOE_PROTECTION),
			tooltip = GetString(SI_BETTERUI_BOE_PROTECTION_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("bindOnEquipProtection")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("bindOnEquipProtection", value) end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_UNBOUND),
			tooltip = GetString(SI_BETTERUI_ICON_UNBOUND_TOOLTIP),
			getFunc = function()
				local v = BETTERUI.Inventory.GetSetting("showIconUnboundItem")
				return v == nil and true or v
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("showIconUnboundItem", value) end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_ENCHANTMENT),
			tooltip = GetString(SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP),
			getFunc = function()
				local v = BETTERUI.Inventory.GetSetting("showIconEnchantment")
				return v == nil and true or v
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("showIconEnchantment", value) end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_SET_GEAR),
			tooltip = GetString(SI_BETTERUI_ICON_SET_GEAR_TOOLTIP),
			getFunc = function()
				local v = BETTERUI.Inventory.GetSetting("showIconSetGear")
				return v == nil and true or v
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("showIconSetGear", value) end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_COMPANION_JUNK),
			tooltip = GetString(SI_BETTERUI_ENABLE_COMPANION_JUNK_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("enableCompanionJunk") == true
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("enableCompanionJunk", value) end,
			width = "full",
		},
		{
			type = "submenu",
			name = GetString(SI_BETTERUI_CURRENCY_SUBMENU),
			reference = "BETTERUI_Inventory_CurrencyVisibility_Submenu",
			controls = {
				{
					type = "description",
					text = GetString(SI_BETTERUI_CURRENCY_DESC),
					width = "full",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_PRESET),
					tooltip = GetString(SI_BETTERUI_CURRENCY_PRESET_TOOLTIP),
					choices = {
						GetString(SI_BETTERUI_CURRENCY_PRESET_DEFAULT),
						GetString(SI_BETTERUI_CURRENCY_PRESET_PVP),
						GetString(SI_BETTERUI_CURRENCY_PRESET_CRAFTER),
						GetString(SI_BETTERUI_CURRENCY_PRESET_EVENTS),
						GetString(SI_BETTERUI_CURRENCY_PRESET_CUSTOM),
					},
					choicesValues = { "default", "pvp", "crafter", "events", "custom" },
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return "custom" end
						return BETTERUI.Settings.Modules["Inventory"].currencyPreset or "custom"
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = value
						BETTERUI.ApplyCurrencyPreset(value)
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "full",
					scrollable = true,
				},
				{
					type = "divider",
					width = "full",
				},
				-- Gold
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_GOLD),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyGold ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyGold = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_GOLD),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyGold == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 1 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyGold or 1)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyGold = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- AP
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_AP),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_AP),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 2 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyAlliancePoints or 2)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyAlliancePoints = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Tel Var
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_TELVAR),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_TELVAR),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 3 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTelVar or 3)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyTelVar = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Undaunted Keys
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_KEYS),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_KEYS),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 4 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyUndauntedKeys or 4)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyUndauntedKeys = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Transmute
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_TRANSMUTE),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_TRANSMUTE),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 5 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTransmute or 5)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyTransmute = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Crowns
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_CROWNS),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_CROWNS),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 6 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrowns or 6)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrowns = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Crown Gems
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_GEMS),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_GEMS),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 7 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrownGems or 7)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrownGems = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Writ Vouchers
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_WRITS),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_WRITS),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 8 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyWritVouchers or 8)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyWritVouchers = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Trade Bars
				{
					type = "checkbox",
					name = ((CURT_TRADE_BARS == nil) and (CURT_EVENT_TICKETS ~= nil)) and
					GetString(SI_BETTERUI_CURRENCY_SHOW_EVENT_TICKETS) or GetString(SI_BETTERUI_CURRENCY_SHOW_TRADE_BARS),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTradeBars ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyTradeBars = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = ((CURT_TRADE_BARS == nil) and (CURT_EVENT_TICKETS ~= nil)) and
					GetString(SI_BETTERUI_CURRENCY_ORDER_EVENT_TICKETS) or
					GetString(SI_BETTERUI_CURRENCY_ORDER_TRADE_BARS),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTradeBars == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 9 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTradeBars or 9)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyTradeBars = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Outfit Tokens
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_OUTFIT),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return true end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens ~= false
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_OUTFIT),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 10 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyOutfitTokens or 10)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencyOutfitTokens = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				-- Seals
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_SEALS),
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return false end
						return BETTERUI.Settings.Modules["Inventory"].showCurrencySeals == true
					end,
					setFunc = function(value)
						if value and not CanEnableMoreCurrencies() then return end
						BETTERUI.Settings.Modules["Inventory"].showCurrencySeals = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_SEALS),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencySeals == false
					end,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return 11 end
						return (BETTERUI.Settings.Modules["Inventory"].orderCurrencySeals or 11)
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].orderCurrencySeals = value
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
				{
					type = "divider",
					width = "full",
				},
				{
					type = "button",
					name = GetString(SI_BETTERUI_CURRENCY_RESET),
					tooltip = GetString(SI_BETTERUI_CURRENCY_RESET_TOOLTIP),
					func = function()
						BETTERUI.ApplyCurrencyPreset("default")
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "default"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
			},
		},
		-- Font Customization
		{
			type = "header",
			name = GetString(SI_BETTERUI_INV_FONT_HEADER),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BETTERUI_INV_FONT_DESC),
			width = "full",
		},
		{
			type = "submenu",
			name = GetString(SI_BETTERUI_INV_NAME_FONT_SUBMENU),
			controls = {
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_INV_NAME_FONT),
					tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_TOOLTIP),
					choices = BETTERUI.Inventory.FONT_CHOICES,
					choicesValues = BETTERUI.Inventory.FONT_VALUES,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Inventory"] then return BETTERUI.Inventory.DEFAULTS.nameFont end
						return BETTERUI.Settings.Modules["Inventory"].nameFont or BETTERUI.Inventory.DEFAULTS.nameFont
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].nameFont = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					scrollable = true,
					requiresReload = true,
					default = BETTERUI.Inventory.DEFAULTS.nameFont,
				},
				{
					type = "slider",
					name = GetString(SI_BETTERUI_INV_NAME_FONT_SIZE),
					tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_SIZE_TOOLTIP),
					min = 12,
					max = 48,
					step = 1,
					getFunc = function()
						local settings = BETTERUI.Settings.Modules["Inventory"]
						local val = BETTERUI.Inventory.DEFAULTS.nameFontSize
						if settings then
							val = settings.nameFontSize or val
						end
						return val
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].nameFontSize = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					requiresReload = true,
					default = BETTERUI.Inventory.DEFAULTS.nameFontSize,
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_INV_NAME_FONT_STYLE),
					tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_STYLE_TOOLTIP),
					choices = BETTERUI.Inventory.FONTSTYLE_CHOICES,
					choicesValues = BETTERUI.Inventory.FONTSTYLE_VALUES,
					getFunc = function()
						return BETTERUI.Settings.Modules["Inventory"].nameFontStyle or
						BETTERUI.Inventory.DEFAULTS.nameFontStyle
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].nameFontStyle = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					requiresReload = true,
					default = BETTERUI.Inventory.DEFAULTS.nameFontStyle,
				},
				{
					type = "button",
					name = GetString(SI_BETTERUI_NAME_FONT_RESET),
					tooltip = GetString(SI_BETTERUI_NAME_FONT_RESET_TOOLTIP),
					func = function()
						local d = BETTERUI.Inventory.DEFAULTS
						local s = BETTERUI.Settings.Modules["Inventory"]
						s.nameFont = d.nameFont
						s.nameFontSize = d.nameFontSize
						s.nameFontStyle = d.nameFontStyle
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "half",
				},
			},
		},
		{
			type = "submenu",
			name = GetString(SI_BETTERUI_INV_COLUMN_FONT_SUBMENU),
			controls = {
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_INV_COLUMN_FONT),
					tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_TOOLTIP),
					choices = BETTERUI.Inventory.FONT_CHOICES,
					choicesValues = BETTERUI.Inventory.FONT_VALUES,
					getFunc = function()
						return BETTERUI.Settings.Modules["Inventory"].columnFont or
						BETTERUI.Inventory.DEFAULTS.columnFont
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].columnFont = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					scrollable = true,
					requiresReload = true,
					default = BETTERUI.Inventory.DEFAULTS.columnFont,
				},
				{
					type = "slider",
					name = GetString(SI_BETTERUI_INV_COLUMN_FONT_SIZE),
					tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_SIZE_TOOLTIP),
					min = 12,
					max = 48,
					step = 1,
					getFunc = function()
						local settings = BETTERUI.Settings.Modules["Inventory"]
						local val = BETTERUI.Inventory.DEFAULTS.columnFontSize
						if settings then
							val = settings.columnFontSize or val
						end
						return val
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].columnFontSize = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					requiresReload = true,
					default = BETTERUI.Inventory.DEFAULTS.columnFontSize,
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_INV_COLUMN_FONT_STYLE),
					tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_STYLE_TOOLTIP),
					choices = BETTERUI.Inventory.FONTSTYLE_CHOICES,
					choicesValues = BETTERUI.Inventory.FONTSTYLE_VALUES,
					getFunc = function()
						return BETTERUI.Settings.Modules["Inventory"].columnFontStyle or
						BETTERUI.Inventory.DEFAULTS.columnFontStyle
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Inventory"].columnFontStyle = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					requiresReload = true,
					default = BETTERUI.Inventory.DEFAULTS.columnFontStyle,
				},
				{
					type = "button",
					name = GetString(SI_BETTERUI_COLUMN_FONT_RESET),
					tooltip = GetString(SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP),
					func = function()
						local d = BETTERUI.Inventory.DEFAULTS
						local s = BETTERUI.Settings.Modules["Inventory"]
						s.columnFont = d.columnFont
						s.columnFontSize = d.columnFontSize
						s.columnFontStyle = d.columnFontStyle
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "half",
				},
			},
		},
	}

	-- Tome Points dynamic append
	if CURT_TOME_POINTS ~= nil then
		local currencySubmenu = nil
		for _, control in ipairs(optionsTable) do
			if control.reference == "BETTERUI_Inventory_CurrencyVisibility_Submenu" then
				currencySubmenu = control
				break
			end
		end
		if currencySubmenu and currencySubmenu.controls then
			table.insert(currencySubmenu.controls, {
				type = "checkbox",
				name = GetString(SI_BETTERUI_CURRENCY_SHOW_TOME_POINTS),
				getFunc = function()
					if not BETTERUI.Settings.Modules["Inventory"] then return false end
					return BETTERUI.Settings.Modules["Inventory"].showCurrencyTomePoints == true
				end,
				setFunc = function(value)
					if value and not CanEnableMoreCurrencies() then return end
					BETTERUI.Settings.Modules["Inventory"].showCurrencyTomePoints = value
					BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
					SafeRefresh(true)
				end,
				width = "half",
			})
			table.insert(currencySubmenu.controls, {
				type = "dropdown",
				name = GetString(SI_BETTERUI_CURRENCY_ORDER_TOME_POINTS),
				choices = CURRENCY_ORDER_CHOICES,
				choicesValues = CURRENCY_ORDER_VALUES,
				disabled = function()
					return BETTERUI.Settings.Modules["Inventory"].showCurrencyTomePoints ~= true
				end,
				getFunc = function()
					if not BETTERUI.Settings.Modules["Inventory"] then return 12 end
					return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTomePoints or 12)
				end,
				setFunc = function(value)
					BETTERUI.Settings.Modules["Inventory"].orderCurrencyTomePoints = value
					BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
					RecomputeCurrencyOrderString()
					SafeRefresh(true)
				end,
				width = "half",
			})
		end
	end

	LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end

--- Initialize inventory module settings with default values
function BETTERUI.Inventory.InitModule(m_options)
	if m_options["showMarketPrice"] == nil then m_options["showMarketPrice"] = false end
	if m_options["useTriggersForSkip"] == nil then m_options["useTriggersForSkip"] = false end
	if m_options["bindOnEquipProtection"] == nil then m_options["bindOnEquipProtection"] = true end
	if m_options["showIconEnchantment"] == nil then m_options["showIconEnchantment"] = true end
	if m_options["showIconSetGear"] == nil then m_options["showIconSetGear"] = true end
	if m_options["showIconUnboundItem"] == nil then m_options["showIconUnboundItem"] = true end
	if m_options["quickDestroy"] == nil then m_options["quickDestroy"] = false end
	if m_options["enableCarousel"] == nil then m_options["enableCarousel"] = false end
	if m_options["enableCompanionJunk"] == nil then m_options["enableCompanionJunk"] = false end

	local defaults = BETTERUI.Inventory.DEFAULTS
	m_options["nameFont"] = m_options["nameFont"] or defaults.nameFont
	m_options["nameFontSize"] = m_options["nameFontSize"] or defaults.nameFontSize
	m_options["nameFontStyle"] = m_options["nameFontStyle"] or defaults.nameFontStyle
	m_options["columnFont"] = m_options["columnFont"] or defaults.columnFont
	m_options["columnFontSize"] = m_options["columnFontSize"] or defaults.columnFontSize
	m_options["columnFontStyle"] = m_options["columnFontStyle"] or defaults.columnFontStyle

	-- Migration
	if m_options["font"] and not m_options["nameFont"] then
		m_options["nameFont"] = m_options["font"]
		m_options["columnFont"] = m_options["font"]
	end
	if m_options["skinSize"] and not m_options["nameFontSize"] then
		m_options["nameFontSize"] = m_options["skinSize"]
		m_options["columnFontSize"] = m_options["skinSize"]
	end
	if m_options["fontStyle"] and not m_options["nameFontStyle"] then
		local oldStyle = m_options["fontStyle"]
		if type(oldStyle) == "number" then
			local styleMap = { [0] = "", [1] = "outline", [2] = "thick-outline", [3] = "shadow", [4] =
			"soft-shadow-thick", [5] = "soft-shadow-thin" }
			oldStyle = styleMap[oldStyle] or defaults.nameFontStyle
		end
		m_options["nameFontStyle"] = oldStyle
		m_options["columnFontStyle"] = oldStyle
	end

	-- Currency visibility defaults
	if m_options["showCurrencyGold"] == nil then m_options["showCurrencyGold"] = true end
	if m_options["showCurrencyAlliancePoints"] == nil then m_options["showCurrencyAlliancePoints"] = true end
	if m_options["showCurrencyTelVar"] == nil then m_options["showCurrencyTelVar"] = true end
	if m_options["showCurrencyCrownGems"] == nil then m_options["showCurrencyCrownGems"] = true end
	if m_options["showCurrencyCrowns"] == nil then m_options["showCurrencyCrowns"] = true end
	if m_options["showCurrencyTransmute"] == nil then m_options["showCurrencyTransmute"] = true end
	if m_options["showCurrencyWritVouchers"] == nil then m_options["showCurrencyWritVouchers"] = true end
	if m_options["showCurrencyTradeBars"] == nil then m_options["showCurrencyTradeBars"] = true end
	if m_options["showCurrencyUndauntedKeys"] == nil then m_options["showCurrencyUndauntedKeys"] = true end
	if m_options["showCurrencyOutfitTokens"] == nil then m_options["showCurrencyOutfitTokens"] = true end
	if m_options["showCurrencySeals"] == nil then m_options["showCurrencySeals"] = false end
	if m_options["showCurrencyTomePoints"] == nil then m_options["showCurrencyTomePoints"] = false end

	-- Currency order defaults
	if m_options["orderCurrencyGold"] == nil then m_options["orderCurrencyGold"] = 1 end
	if m_options["orderCurrencyAlliancePoints"] == nil then m_options["orderCurrencyAlliancePoints"] = 2 end
	if m_options["orderCurrencyTelVar"] == nil then m_options["orderCurrencyTelVar"] = 3 end
	if m_options["orderCurrencyUndauntedKeys"] == nil then m_options["orderCurrencyUndauntedKeys"] = 4 end
	if m_options["orderCurrencyTransmute"] == nil then m_options["orderCurrencyTransmute"] = 5 end
	if m_options["orderCurrencyCrowns"] == nil then m_options["orderCurrencyCrowns"] = 6 end
	if m_options["orderCurrencyCrownGems"] == nil then m_options["orderCurrencyCrownGems"] = 7 end
	if m_options["orderCurrencyWritVouchers"] == nil then m_options["orderCurrencyWritVouchers"] = 8 end
	if m_options["orderCurrencyTradeBars"] == nil then m_options["orderCurrencyTradeBars"] = 9 end
	if m_options["orderCurrencyOutfitTokens"] == nil then m_options["orderCurrencyOutfitTokens"] = 10 end
	if m_options["orderCurrencySeals"] == nil then m_options["orderCurrencySeals"] = 11 end
	if m_options["orderCurrencyTomePoints"] == nil then m_options["orderCurrencyTomePoints"] = 12 end

	if m_options["currencyPreset"] == nil then m_options["currencyPreset"] = "default" end
	if m_options["currencyOrder"] == nil then m_options["currencyOrder"] =
		"gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints" end

	-- Migration: Rename showCurrencyEventTickets -> showCurrencyTradeBars
	if m_options["showCurrencyEventTickets"] ~= nil then
		m_options["showCurrencyTradeBars"] = m_options["showCurrencyEventTickets"]
		m_options["showCurrencyEventTickets"] = nil
	end
	if m_options["orderCurrencyEventTickets"] ~= nil then
		m_options["orderCurrencyTradeBars"] = m_options["orderCurrencyEventTickets"]
		m_options["orderCurrencyEventTickets"] = nil
	end
	if m_options["currencyOrder"] ~= nil then
		m_options["currencyOrder"] = string.gsub(m_options["currencyOrder"], "tickets", "tradebars")
	end

	return m_options
end
