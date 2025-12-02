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

-- Shared font choices for Inventory (same as Nameplates for consistency)
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
	nameFontSize = "Default",
	nameFontStyle = "",
	columnFont = "EsoUI/Common/Fonts/FTN57.otf",
	columnFontSize = "Default",
	columnFontStyle = "",
}

-- Converts size string to pixel value
local function GetFontSizeValue(sizeStr)
	if sizeStr == "XLarge" then
		return 36
	elseif sizeStr == "Large" then
		return 32
	elseif sizeStr == "Medium" then
		return 28
	elseif sizeStr == "Small" then
		return 20
	else
		return 24  -- Default
	end
end

-- Returns font descriptor for Name column: "fontPath|size|style"
function BETTERUI.Inventory.GetNameFontDescriptor()
	local s = BETTERUI.Settings.Modules["Inventory"]
	local d = BETTERUI.Inventory.DEFAULTS
	local path = s.nameFont or d.nameFont
	local size = GetFontSizeValue(s.nameFontSize or d.nameFontSize)
	local style = s.nameFontStyle or d.nameFontStyle
	return style ~= "" and string.format("%s|%d|%s", path, size, style) or string.format("%s|%d", path, size)
end

-- Returns font descriptor for column labels (Type, Trait, Stat, Value): "fontPath|size|style"
function BETTERUI.Inventory.GetColumnFontDescriptor()
	local s = BETTERUI.Settings.Modules["Inventory"]
	local d = BETTERUI.Inventory.DEFAULTS
	local path = s.columnFont or d.columnFont
	local size = GetFontSizeValue(s.columnFontSize or d.columnFontSize)
	local style = s.columnFontStyle or d.columnFontStyle
	return style ~= "" and string.format("%s|%d|%s", path, size, style) or string.format("%s|%d", path, size)
end

--- Initializes the settings panel for the Inventory module
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

	--- Recomputes the currency order string based on user settings and default priorities
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
		-- Quick Destroy is available as an opt-in setting; default remains off for safety.
		{
			type = "checkbox",
			name = "Enable quick destroy functionality",
			tooltip = "**USE WITH CAUTION** Quickly destroys items without a confirmation dialog!",
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
					type = "dropdown",
					name = GetString(SI_BETTERUI_INV_NAME_FONT_SIZE),
					tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_SIZE_TOOLTIP),
					choices = {GetString(SI_BETTERUI_FONT_SIZE_SMALL), GetString(SI_BETTERUI_FONT_SIZE_DEFAULT), GetString(SI_BETTERUI_FONT_SIZE_MEDIUM), GetString(SI_BETTERUI_FONT_SIZE_LARGE), GetString(SI_BETTERUI_FONT_SIZE_XLARGE)},
					choicesValues = {"Small", "Default", "Medium", "Large", "XLarge"},
					getFunc = function()
						return BETTERUI.Settings.Modules["Inventory"].nameFontSize or BETTERUI.Inventory.DEFAULTS.nameFontSize
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
					type = "dropdown",
					name = GetString(SI_BETTERUI_INV_COLUMN_FONT_SIZE),
					tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_SIZE_TOOLTIP),
					choices = {GetString(SI_BETTERUI_FONT_SIZE_SMALL), GetString(SI_BETTERUI_FONT_SIZE_DEFAULT), GetString(SI_BETTERUI_FONT_SIZE_MEDIUM), GetString(SI_BETTERUI_FONT_SIZE_LARGE), GetString(SI_BETTERUI_FONT_SIZE_XLARGE)},
					choicesValues = {"Small", "Default", "Medium", "Large", "XLarge"},
					getFunc = function()
						return BETTERUI.Settings.Modules["Inventory"].columnFontSize or BETTERUI.Inventory.DEFAULTS.columnFontSize
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
			},
		},
		{
			type = "button",
			name = GetString(SI_BETTERUI_INV_FONT_RESET),
			tooltip = GetString(SI_BETTERUI_INV_FONT_RESET_TOOLTIP),
			func = function()
				local d = BETTERUI.Inventory.DEFAULTS
				local s = BETTERUI.Settings.Modules["Inventory"]
				s.nameFont = d.nameFont
				s.nameFontSize = d.nameFontSize
				s.nameFontStyle = d.nameFontStyle
				s.columnFont = d.columnFont
				s.columnFontSize = d.columnFontSize
				s.columnFontStyle = d.columnFontStyle
			end,
			disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
			width = "half",
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

--- Sets up tooltip styles based on CIM's tooltipSize setting.
local function SetupTooltipStyles()
    local tooltipSize = BETTERUI.Settings.Modules["CIM"].tooltipSize or "Default"
    
    -- Convert size setting to pixel values
    local baseFontSize, titleFontSize, valueFontSize
    if tooltipSize == "Small" then
        baseFontSize = 20
        titleFontSize = 26
        valueFontSize = 24
    elseif tooltipSize == "Medium" then
        baseFontSize = 28
        titleFontSize = 34
        valueFontSize = 32
    elseif tooltipSize == "Large" then
        baseFontSize = 32
        titleFontSize = 38
        valueFontSize = 36
    elseif tooltipSize == "XLarge" then
        baseFontSize = 36
        titleFontSize = 42
        valueFontSize = 40
    else -- Default
        baseFontSize = 24
        titleFontSize = 30
        valueFontSize = 28
    end
    
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

--- Sets up mouse wheel scrolling for tooltips. Hooks the tooltip control to respond to mouse wheel events, allowing players to scroll through long tooltip text that exceeds the display area.
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
-------------------------------------------------------------------------------------------------------------------------------------------------------
--
--    Finally, the Setup() function which replaces the inventory system with a duplicate that I've heavily modified. Duplication is necessary as I don't
--    have access to the beginning :New() method of ZO_GamepadInventory. Will mess quite a few addons up, but will make GAMEPAD_INVENTORY a reference at the end
--
-------------------------------------------------------------------------------------------------------------------------------------------------------

--- Sets up the Inventory module by replacing the default gamepad inventory with a custom implementation
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
