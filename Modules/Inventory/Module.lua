--[[
    BetterUI Inventory Module - Configuration & Initialization
    Description: Handles settings, font customization, currency configuration, and module initialization.
    Key Responsibilities:
    - Defines default settings for Fonts (Name/Column) and Currencies.
    - Creates the LibAddonMenu settings panel.
    - Replaces the native GAMEPAD_INVENTORY with BetterUI's custom implementation.
    - Configures Tooltip styles and Mouse Wheel scrolling support.

    TODO(architecture): This file is 1190 lines - split settings into InventorySettings.lua

]]

local _
local LAM = LibAddonMenu2

local GENERAL_COLOR_WHITE = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1
local GENERAL_COLOR_OFF_WHITE = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3

-- Shared font choices for Inventory (matches Nameplates for consistency)
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

-- Font style string values for ESO font descriptor format
BETTERUI.Inventory.FONTSTYLE_VALUES = {
	"",                    -- Normal (no style suffix)
	"outline",             -- Outline
	"thick-outline",       -- Thick Outline
	"shadow",              -- Shadow
	"soft-shadow-thick",   -- Soft Shadow (Thick)
	"soft-shadow-thin",    -- Soft Shadow (Thin)
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
---
--- Purpose: Handles migration from legacy string values ("Small", "Large") to numbers.
--- Mechanics: Checks type; if number, returns it. If string, looks up in legacyMap. Defaults to 24.
--- References: Used by GetNameFontDescriptor and GetColumnFontDescriptor.
---
--- @param sizeValue string|number The size setting value.
--- @return number The font size in pixels.
local function GetFontSizeValue(sizeValue)
	-- Handle new numeric values directly
	if type(sizeValue) == "number" then
		return sizeValue
	end
	return 24
end

--- Returns the ESO font descriptor for the Name column.
---
--- Purpose: Generates the font string for the main item name.
--- Mechanics: Reads settings (path, size, style), resolves defaults, and formats as "path|size|style".
--- References: Used by InventoryList.lua templates.
---
--- @return string The formatted font descriptor string.
function BETTERUI.Inventory.GetNameFontDescriptor()
	local s = BETTERUI.Settings.Modules["Inventory"]
	local d = BETTERUI.Inventory.DEFAULTS
	local path = s.nameFont or d.nameFont
	local size = GetFontSizeValue(s.nameFontSize or d.nameFontSize)
	local style = s.nameFontStyle or d.nameFontStyle
	return style ~= "" and string.format("%s|%d|%s", path, size, style) or string.format("%s|%d", path, size)
end

--- Returns the ESO font descriptor for other columns (Type, Trait, Stat, Value).
---
--- Purpose: Generates the font string for secondary columns.
--- Mechanics: Reads settings (path, size, style), resolves defaults, and formats as "path|size|style".
--- References: Used by InventoryList.lua templates.
---
--- @return string The formatted font descriptor string.
function BETTERUI.Inventory.GetColumnFontDescriptor()
	local s = BETTERUI.Settings.Modules["Inventory"]
	local d = BETTERUI.Inventory.DEFAULTS
	local path = s.columnFont or d.columnFont
	local size = GetFontSizeValue(s.columnFontSize or d.columnFontSize)
	local style = s.columnFontStyle or d.columnFontStyle
	return style ~= "" and string.format("%s|%d|%s", path, size, style) or string.format("%s|%d", path, size)
end

--- Initializes the settings panel for the Inventory module.
---
--- Purpose: Registers the "Inventory Improvement Settings" panel with LibAddonMenu.
--- Mechanics:
--- - Defines currency presets (Default, PvP, Crafter, etc.).
--- - Creates the options table (checkboxes, sliders, dropdowns).
--- - Setup callbacks to refresh the inventory view on setting changes.
--- References: Called by BETTERUI.Inventory.Setup().
---
--- @param mId string: Module ID for panel registration
--- @param moduleName string: Display name for the module
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

	--- Checks if the user can enable more currencies (limit defined in CONST)
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

	--- Attempts to enable a currency; shows alert if limit reached
	--- @param settingKey string The settings key (e.g., "showCurrencySeals")
	--- @param value boolean The new value to set
	--- @return boolean True if the setting was applied, false if blocked
	local function TryEnableCurrency(settingKey, value)
		if value and not CanEnableMoreCurrencies() then
			ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(SI_BETTERUI_CURRENCY_LIMIT_REACHED))
			return false
		end
		BETTERUI.Settings.Modules["Inventory"][settingKey] = value
		BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
		SafeRefresh(true)
		return true
	end

	--- Recomputes the currency order string based on user settings and default priorities
	local function RecomputeCurrencyOrderString()
		local inv = BETTERUI.Settings.Modules["Inventory"]
		if not inv then return end
		local defaultsOrderIdx = {
			gold = 1, ap = 2, telvar = 3, keys = 4, transmute = 5,
			crowns = 6, gems = 7, writs = 8, tradebars = 9, outfit = 10,
			seals = 11, tomepoints = 12,
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
			{ key = "tradebars",orderKey = "orderCurrencyTradeBars" },
			{ key = "outfit",   orderKey = "orderCurrencyOutfitTokens" },
			{ key = "seals",    orderKey = "orderCurrencySeals" },
			{ key = "tomepoints",orderKey = "orderCurrencyTomePoints" },
		}
		local items = {}
		for _, m in ipairs(map) do
			local v = tonumber(inv[m.orderKey]) or defaultsOrderIdx[m.key]
			if v < 1 then v = 1 elseif v > 12 then v = 12 end
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

	-- Currency order dropdown choices and values
	local CURRENCY_ORDER_CHOICES = {
		GetString(SI_BETTERUI_CURRENCY_POS_1), GetString(SI_BETTERUI_CURRENCY_POS_2),
		GetString(SI_BETTERUI_CURRENCY_POS_3), GetString(SI_BETTERUI_CURRENCY_POS_4),
		GetString(SI_BETTERUI_CURRENCY_POS_5), GetString(SI_BETTERUI_CURRENCY_POS_6),
		GetString(SI_BETTERUI_CURRENCY_POS_7), GetString(SI_BETTERUI_CURRENCY_POS_8),
		GetString(SI_BETTERUI_CURRENCY_POS_9), GetString(SI_BETTERUI_CURRENCY_POS_10),
		GetString(SI_BETTERUI_CURRENCY_POS_11), GetString(SI_BETTERUI_CURRENCY_POS_12),
	}
	local CURRENCY_ORDER_VALUES = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}



	local optionsTable = {
		-- Quick Destroy is available as an opt-in setting; default remains off for safety.
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_QUICK_DESTROY),
			tooltip = GetString(SI_BETTERUI_QUICK_DESTROY_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return false end
				return BETTERUI.Settings.Modules["Inventory"].quickDestroy 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].quickDestroy = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV),
			tooltip = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return false end
				return BETTERUI.Settings.Modules["Inventory"].enableCarousel 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].enableCarousel = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_TRIGGER_SKIP_TYPE),
			tooltip = GetString(SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return false end
				return BETTERUI.Settings.Modules["Inventory"].useTriggersForSkip 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].useTriggersForSkip = value end,
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_SHOW_MARKET_PRICE),
			tooltip = GetString(SI_BETTERUI_SHOW_MARKET_PRICE_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return false end
				return BETTERUI.Settings.Modules["Inventory"].showMarketPrice 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].showMarketPrice = value end,
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_BOE_PROTECTION),
			tooltip = GetString(SI_BETTERUI_BOE_PROTECTION_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return false end
				return BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_UNBOUND),
			tooltip = GetString(SI_BETTERUI_ICON_UNBOUND_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return true end
				return BETTERUI.Settings.Modules["Inventory"].showIconUnboundItem 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].showIconUnboundItem = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_ENCHANTMENT),
			tooltip = GetString(SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return true end
				return BETTERUI.Settings.Modules["Inventory"].showIconEnchantment 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].showIconEnchantment = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_SET_GEAR),
			tooltip = GetString(SI_BETTERUI_ICON_SET_GEAR_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return true end
				return BETTERUI.Settings.Modules["Inventory"].showIconSetGear 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].showIconSetGear = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_COMPANION_JUNK),
			tooltip = GetString(SI_BETTERUI_ENABLE_COMPANION_JUNK_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Inventory"] then return false end
				return BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk = value end,
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
					choicesValues = {"default", "pvp", "crafter", "events", "custom"},
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
                -- Currency Order Settings (One control per currency)
				--[[
				NIL-CHECK PATTERN DOCUMENTATION:
				- Original currencies (Gold, AP, etc.) use `~= false` in getFunc:
				  This returns TRUE for nil/missing values (default = ENABLED)
				- New currencies (Seals, Tome Points) use `== true` in getFunc:
				  This returns FALSE for nil/missing values (default = DISABLED)
				This pattern ensures proper defaults without requiring explicit initialization.
				]]
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
				-- Alliance Points
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
				-- Tel Var Stones
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
				-- Transmute Crystals
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
				-- Trade Bars (formerly Event Tickets)
				{
					type = "checkbox",
					name = GetString(SI_BETTERUI_CURRENCY_SHOW_TRADE_BARS),
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
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_TRADE_BARS),
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
				-- Outfit Change Tokens
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
				-- Tome Points
				{
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
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_CURRENCY_ORDER_TOME_POINTS),
					choices = CURRENCY_ORDER_CHOICES,
					choicesValues = CURRENCY_ORDER_VALUES,
					disabled = function()
						return BETTERUI.Settings.Modules["Inventory"].showCurrencyTomePoints == false
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
						ApplyCurrencyPreset("default")
						BETTERUI.Settings.Modules["Inventory"].currencyPreset = "default"
						RecomputeCurrencyOrderString()
						SafeRefresh(true)
					end,
					width = "half",
				},
			},
		},
		-- Font Customization Section (at bottom)
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
		-- ========== NAME COLUMN FONT SETTINGS ==========
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
						return BETTERUI.Settings.Modules["Inventory"].nameFontStyle or BETTERUI.Inventory.DEFAULTS.nameFontStyle
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
		-- ========== OTHER COLUMNS FONT SETTINGS (Type, Trait, Stat, Value) ==========
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
						return BETTERUI.Settings.Modules["Inventory"].columnFont or BETTERUI.Inventory.DEFAULTS.columnFont
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
						return BETTERUI.Settings.Modules["Inventory"].columnFontStyle or BETTERUI.Inventory.DEFAULTS.columnFontStyle
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
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)

end

--- Initialize inventory module settings with default values
--- @param m_options table: The module options table to initialize
--- @return table: The initialized options table
function BETTERUI.Inventory.InitModule(m_options)
	-- Core settings (preserve existing user values)
	if m_options["showMarketPrice"] == nil then m_options["showMarketPrice"] = false end
	if m_options["useTriggersForSkip"] == nil then m_options["useTriggersForSkip"] = false end
	if m_options["bindOnEquipProtection"] == nil then m_options["bindOnEquipProtection"] = true end
	if m_options["showIconEnchantment"] == nil then m_options["showIconEnchantment"] = true end
	if m_options["showIconSetGear"] == nil then m_options["showIconSetGear"] = true end
	if m_options["showIconUnboundItem"] == nil then m_options["showIconUnboundItem"] = true end
	if m_options["quickDestroy"] == nil then m_options["quickDestroy"] = false end
	if m_options["enableCarousel"] == nil then m_options["enableCarousel"] = false end
	if m_options["enableCompanionJunk"] == nil then m_options["enableCompanionJunk"] = false end

	-- Font customization - Name column settings
	local defaults = BETTERUI.Inventory.DEFAULTS
	m_options["nameFont"] = m_options["nameFont"] or defaults.nameFont
	m_options["nameFontSize"] = m_options["nameFontSize"] or defaults.nameFontSize
	m_options["nameFontStyle"] = m_options["nameFontStyle"] or defaults.nameFontStyle
	
	-- Font customization - Other columns settings (Type, Trait, Stat, Value)
	m_options["columnFont"] = m_options["columnFont"] or defaults.columnFont
	m_options["columnFontSize"] = m_options["columnFontSize"] or defaults.columnFontSize
	m_options["columnFontStyle"] = m_options["columnFontStyle"] or defaults.columnFontStyle
	
	-- Migrate old settings to new format if present
	if m_options["font"] and not m_options["nameFont"] then
		m_options["nameFont"] = m_options["font"]
		m_options["columnFont"] = m_options["font"]
	end
	if m_options["skinSize"] and not m_options["nameFontSize"] then
		m_options["nameFontSize"] = m_options["skinSize"]
		m_options["columnFontSize"] = m_options["skinSize"]
	end

	if m_options["fontStyle"] and not m_options["nameFontStyle"] then
		-- Handle migration from old numeric style to string
		local oldStyle = m_options["fontStyle"]
		if type(oldStyle) == "number" then
			local styleMap = {
				[0] = "",
				[1] = "outline",
				[2] = "thick-outline",
				[3] = "shadow",
				[4] = "soft-shadow-thick",
				[5] = "soft-shadow-thin",
			}
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

	-- Currency order numeric defaults (1..12)
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

	-- Currency preset tracking (default = all visible in default order)
	if m_options["currencyPreset"] == nil then m_options["currencyPreset"] = "default" end
	if m_options["currencyOrder"] == nil then m_options["currencyOrder"] = "gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints" end

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

-- ============================================================================
-- TOOLTIP CONFIGURATION
-- ============================================================================

--- Configures the visual style of tooltips.
--- Applies font sizes (title, body, values) based on user settings.
--- Adjusts layout direction and spacing for the gamepad tooltip interface.
local function SetupTooltipStyles()
    local tooltipSize = BETTERUI.Settings.Modules["CIM"].tooltipSize or 24
    

    
    -- Calculate derived sizes from base font size
    local baseFontSize = tooltipSize
    local titleFontSize = baseFontSize + 6   -- Title is 6px larger
    local valueFontSize = baseFontSize + 4   -- Value is 4px larger
    
    -- Apply tooltip styles with size adjustments
    ZO_TOOLTIP_STYLES["topSection"] = {
        layoutPrimaryDirection = "up",
        layoutSecondaryDirection = "right",
        widthPercent = 100,
        childSpacing = 1,
        fontSize = baseFontSize,
        height = 64,
        uppercase = true,
        fontColorField = GENERAL_COLOR_OFF_WHITE,
    }
    ZO_TOOLTIP_STYLES["flavorText"] = {
        fontSize = baseFontSize,
    }
    ZO_TOOLTIP_STYLES["statValuePairStat"] = {
        fontSize = baseFontSize,
        uppercase = true,
        fontColorField = GENERAL_COLOR_OFF_WHITE,
    }
    ZO_TOOLTIP_STYLES["statValuePairValue"] = {
        fontSize = valueFontSize,
        fontColorField = GENERAL_COLOR_WHITE,
    }
    ZO_TOOLTIP_STYLES["title"] = {
        fontSize = titleFontSize,
        customSpacing = 8,
        widthPercent = 100,
        uppercase = true,
        fontColorField = GENERAL_COLOR_WHITE,
    }
    ZO_TOOLTIP_STYLES["bodyDescription"] = {
        fontSize = baseFontSize,
    }
end

--- Enables and configures mouse wheel scrolling for the left-side tooltip container.
--- Allows users to scroll long item descriptions using the mouse wheel.
local function SetupTooltipMouseWheel()
	local tip = ZO_GamepadTooltipTopLevelLeftTooltipContainerTip
	local tipScroll = ZO_GamepadTooltipTopLevelLeftTooltipContainerTipScroll
	if tip and tipScroll then
		tip:SetMouseEnabled(true)
		tipScroll:SetMouseEnabled(true)
		tip:SetHandler("OnMouseWheel", function(self, delta)
			local speed = (BETTERUI.Settings.Modules["CIM"].rhScrollSpeed) or 20
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


-- ============================================================================
-- MODULE SETUP
-- ============================================================================

--- Initializes the Inventory module.
--- 1. Initializes the settings panel (`Init`).
--- 2. Replaces the native `GAMEPAD_INVENTORY` object with `BETTERUI.Inventory.Class`.
--- 3. Swaps the native inventory scene fragment with BetterUI's custom fragment.
--- 4. Configures tooltips and registers custom dialogs (e.g., BoE protection).
function BETTERUI.Inventory.Setup()
	Init("Inventory", "Inventory")

	-- Replace the native GAMEPAD_INVENTORY global with our custom class
	GAMEPAD_INVENTORY = BETTERUI.Inventory.Class:New(BETTERUI_GamepadInventoryTopLevel)

	-- Create the replacement scene fragment using our custom top level control
	GAMEPAD_INVENTORY_FRAGMENT = ZO_SimpleSceneFragment:New(BETTERUI_GamepadInventoryTopLevel)
	GAMEPAD_INVENTORY_FRAGMENT:SetHideOnSceneHidden(true)

	-- Update the Inventory Scene with the new fragment
	-- Note: GAMEPAD_INVENTORY_ROOT_SCENE is the native scene, we are swapping the content fragment.
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_INVENTORY_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(MINIMIZE_CHAT_FRAGMENT)
	GAMEPAD_INVENTORY_ROOT_SCENE:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)

	-- Configure tooltip appearance and behavior
	ZO_GamepadTooltipTopLevelLeftTooltipContainer.tip.maxFadeGradientSize = 10
    
    -- Only apply custom tooltip styles (font scaling) if enhancements are enabled
    local cimSettings = BETTERUI.Settings.Modules["CIM"]
    if cimSettings and cimSettings.enableTooltipEnhancements then
	    SetupTooltipStyles()
    end
    
	SetupTooltipMouseWheel()

	-- Position tooltip container
	local TOOLTIP_X_OFFSET = 40
	local TOOLTIP_Y_OFFSET = -100
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.fragment.control.container:SetAnchor(3, ZO_GamepadTooltipTopLevelLeftTooltip, 3, TOOLTIP_X_OFFSET, TOOLTIP_Y_OFFSET, 0)

	-- Store reference for other modules (global 'inv' alias)
	inv = GAMEPAD_INVENTORY

	-- Register custom dialog for Bind on Equip protection (if SaveEquip addon is not handling it)
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
