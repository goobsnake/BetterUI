--------------------------------------------------------------------------------
-- BetterUI Banking Module Registration
--
-- This file handles the initialization and configuration of the Banking module.
-- It integrates with LibAddonMenu (LAM) to provide a settings panel for user customization.
--
-- KEY RESPONSIBILITIES:
--
-- 1.  **Module Initialization (`Init`, `Setup`)**:
--     *   Registers the "Banking" panel in the BetterUI addon settings.
--     *   Defines default settings (`DEFAULTS`) for fonts and toggleable features.
--
-- 2.  **Configuration Options**:
--     *   **Fonts**: Custom font selection, size, and style for Name and Columns.
--     *   **Features**: Toggles for Carousel Navigation (navigating tabs via shoulders/triggers)
--         and icon visibility (Unbound, Enchanted, Set Gear).
--
-- 3.  **Font Helpers**:
--     *   `GetNameFontDescriptor`: Returns a valid font string for the item name column.
--     *   `GetColumnFontDescriptor`: Returns a valid font string for other columns (Trait, Value, etc.).
--------------------------------------------------------------------------------

local _
local LAM = LibAddonMenu2

-- Module initialization
BETTERUI.Banking = BETTERUI.Banking or {}

-- Available font choices (ESO built-in fonts)
BETTERUI.Banking.FONT_CHOICES = {
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

BETTERUI.Banking.FONT_VALUES = {
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

BETTERUI.Banking.FONTSTYLE_CHOICES = {
	"Normal",
	"Outline",
	"Thick Outline",
	"Shadow",
	"Soft Shadow (Thick)",
	"Soft Shadow (Thin)",
}

-- Font style values for ESO font descriptor format
BETTERUI.Banking.FONTSTYLE_VALUES = {
	"",                    -- Normal (no style suffix)
	"outline",             -- Outline
	"thick-outline",       -- Thick Outline
	"shadow",              -- Shadow
	"soft-shadow-thick",   -- Soft Shadow (Thick)
	"soft-shadow-thin",    -- Soft Shadow (Thin)
}

BETTERUI.Banking.DEFAULTS = {
	-- Name column font settings
	nameFont = "EsoUI/Common/Fonts/FTN57.otf",
	nameFontSize = 24,
	nameFontStyle = "",
	-- Other columns font settings (Type, Trait, Stat, Value)
	columnFont = "EsoUI/Common/Fonts/FTN57.otf",
	columnFontSize = 24,
	columnFontStyle = "",
}

--- Converts a font size setting to a numeric pixel value.
--- Purpose: Handles migration from legacy string values ("Small", "Large") to numbers.
--- @param sizeValue string|number The size setting value.
--- @return number The font size in pixels.
local function GetFontSizeValue(sizeValue)
	-- Handle new numeric values directly
	if type(sizeValue) == "number" then
		return sizeValue
	end
	-- Legacy string value migration
	local legacyMap = { Small = 20, Default = 24, Medium = 28, Large = 32, XLarge = 36 }
	return legacyMap[sizeValue] or 24
end

--- Generates the font descriptor string for the Name column.
--- @return string ESO font descriptor (path|size|style).
function BETTERUI.Banking.GetNameFontDescriptor()
	local settings = BETTERUI.Settings.Modules["Banking"]
	local defaults = BETTERUI.Banking.DEFAULTS
	
	local fontPath = settings.nameFont or defaults.nameFont
	local fontSize = GetFontSizeValue(settings.nameFontSize or defaults.nameFontSize)
	local fontStyle = settings.nameFontStyle or defaults.nameFontStyle
	
	if fontStyle and fontStyle ~= "" then
		return string.format("%s|%d|%s", fontPath, fontSize, fontStyle)
	else
		return string.format("%s|%d", fontPath, fontSize)
	end
end

--- Generates the font descriptor string for metadata columns (Type, Trait, etc.).
--- @return string ESO font descriptor (path|size|style).
function BETTERUI.Banking.GetColumnFontDescriptor()
	local settings = BETTERUI.Settings.Modules["Banking"]
	local defaults = BETTERUI.Banking.DEFAULTS
	
	local fontPath = settings.columnFont or defaults.columnFont
	local fontSize = GetFontSizeValue(settings.columnFontSize or defaults.columnFontSize)
	local fontStyle = settings.columnFontStyle or defaults.columnFontStyle
	
	if fontStyle and fontStyle ~= "" then
		return string.format("%s|%d|%s", fontPath, fontSize, fontStyle)
	else
		return string.format("%s|%d", fontPath, fontSize)
	end
end

--- Registers the Banking settings panel with LibAddonMenu.
--- @param mId string The module ID suffix.
--- @param moduleName string The display name for the panel.
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "Banking Improvement Settings")

	local optionsTable = {
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV),
			tooltip = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Banking"] then return false end
				return BETTERUI.Settings.Modules["Banking"].enableCarousel 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Banking"].enableCarousel = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_UNBOUND),
			tooltip = GetString(SI_BETTERUI_ICON_UNBOUND_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Banking"] then return true end
				return BETTERUI.Settings.Modules["Banking"].showIconUnboundItem 
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Banking"].showIconUnboundItem = value
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_ENCHANTMENT),
			tooltip = GetString(SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Banking"] then return true end
				return BETTERUI.Settings.Modules["Banking"].showIconEnchantment 
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Banking"].showIconEnchantment = value
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ICON_SET_GEAR),
			tooltip = GetString(SI_BETTERUI_ICON_SET_GEAR_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Banking"] then return true end
				return BETTERUI.Settings.Modules["Banking"].showIconSetGear 
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Banking"].showIconSetGear = value
			end,
			width = "full",
			requiresReload = true,
		},
		-- Font Customization Section (at bottom)
		{
			type = "header",
			name = GetString(SI_BETTERUI_BANK_FONT_HEADER),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BETTERUI_BANK_FONT_DESC),
			width = "full",
		},
		-- ========== NAME COLUMN FONT SETTINGS ==========
		{
			type = "submenu",
			name = GetString(SI_BETTERUI_BANK_NAME_FONT_SUBMENU),
			controls = {
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_BANK_NAME_FONT),
					tooltip = GetString(SI_BETTERUI_BANK_NAME_FONT_TOOLTIP),
					choices = BETTERUI.Banking.FONT_CHOICES,
					choicesValues = BETTERUI.Banking.FONT_VALUES,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Banking"] then return BETTERUI.Banking.DEFAULTS.nameFont end
						return BETTERUI.Settings.Modules["Banking"].nameFont or BETTERUI.Banking.DEFAULTS.nameFont
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Banking"].nameFont = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					scrollable = true,
					requiresReload = true,
					default = BETTERUI.Banking.DEFAULTS.nameFont,
				},
				{
					type = "slider",
					name = GetString(SI_BETTERUI_BANK_NAME_FONT_SIZE),
					tooltip = GetString(SI_BETTERUI_BANK_NAME_FONT_SIZE_TOOLTIP),
					min = 12,
					max = 48,
					step = 1,
					getFunc = function()
						local settings = BETTERUI.Settings.Modules["Banking"]
						local val = BETTERUI.Banking.DEFAULTS.nameFontSize
						if settings then
							val = settings.nameFontSize or val
						end
						if type(val) == "string" then
							local legacyMap = { Small = 20, Default = 24, Medium = 28, Large = 32, XLarge = 36 }
							return legacyMap[val] or 24
						end
						return val
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Banking"].nameFontSize = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					requiresReload = true,
					default = BETTERUI.Banking.DEFAULTS.nameFontSize,
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_BANK_NAME_FONT_STYLE),
					tooltip = GetString(SI_BETTERUI_BANK_NAME_FONT_STYLE_TOOLTIP),
					choices = BETTERUI.Banking.FONTSTYLE_CHOICES,
					choicesValues = BETTERUI.Banking.FONTSTYLE_VALUES,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Banking"] then return BETTERUI.Banking.DEFAULTS.nameFontStyle end
						return BETTERUI.Settings.Modules["Banking"].nameFontStyle or BETTERUI.Banking.DEFAULTS.nameFontStyle
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Banking"].nameFontStyle = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					requiresReload = true,
					default = BETTERUI.Banking.DEFAULTS.nameFontStyle,
				},
				{
					type = "button",
					name = GetString(SI_BETTERUI_NAME_FONT_RESET),
					tooltip = GetString(SI_BETTERUI_NAME_FONT_RESET_TOOLTIP),
					func = function()
						local defaults = BETTERUI.Banking.DEFAULTS
						BETTERUI.Settings.Modules["Banking"].nameFont = defaults.nameFont
						BETTERUI.Settings.Modules["Banking"].nameFontSize = defaults.nameFontSize
						BETTERUI.Settings.Modules["Banking"].nameFontStyle = defaults.nameFontStyle
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "half",
				},
			},
		},
		-- ========== OTHER COLUMNS FONT SETTINGS (Type, Trait, Stat, Value) ==========
		{
			type = "submenu",
			name = GetString(SI_BETTERUI_BANK_COLUMN_FONT_SUBMENU),
			controls = {
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_BANK_COLUMN_FONT),
					tooltip = GetString(SI_BETTERUI_BANK_COLUMN_FONT_TOOLTIP),
					choices = BETTERUI.Banking.FONT_CHOICES,
					choicesValues = BETTERUI.Banking.FONT_VALUES,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Banking"] then return BETTERUI.Banking.DEFAULTS.columnFont end
						return BETTERUI.Settings.Modules["Banking"].columnFont or BETTERUI.Banking.DEFAULTS.columnFont
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Banking"].columnFont = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					scrollable = true,
					requiresReload = true,
					default = BETTERUI.Banking.DEFAULTS.columnFont,
				},
				{
					type = "slider",
					name = GetString(SI_BETTERUI_BANK_COLUMN_FONT_SIZE),
					tooltip = GetString(SI_BETTERUI_BANK_COLUMN_FONT_SIZE_TOOLTIP),
					min = 12,
					max = 48,
					step = 1,
					getFunc = function()
						local settings = BETTERUI.Settings.Modules["Banking"]
						local val = BETTERUI.Banking.DEFAULTS.columnFontSize
						if settings then
							val = settings.columnFontSize or val
						end
						if type(val) == "string" then
							local legacyMap = { Small = 20, Default = 24, Medium = 28, Large = 32, XLarge = 36 }
							return legacyMap[val] or 24
						end
						return val
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Banking"].columnFontSize = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					requiresReload = true,
					default = BETTERUI.Banking.DEFAULTS.columnFontSize,
				},
				{
					type = "dropdown",
					name = GetString(SI_BETTERUI_BANK_COLUMN_FONT_STYLE),
					tooltip = GetString(SI_BETTERUI_BANK_COLUMN_FONT_STYLE_TOOLTIP),
					choices = BETTERUI.Banking.FONTSTYLE_CHOICES,
					choicesValues = BETTERUI.Banking.FONTSTYLE_VALUES,
					getFunc = function()
						if not BETTERUI.Settings.Modules["Banking"] then return BETTERUI.Banking.DEFAULTS.columnFontStyle end
						return BETTERUI.Settings.Modules["Banking"].columnFontStyle or BETTERUI.Banking.DEFAULTS.columnFontStyle
					end,
					setFunc = function(value)
						BETTERUI.Settings.Modules["Banking"].columnFontStyle = value
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "full",
					requiresReload = true,
					default = BETTERUI.Banking.DEFAULTS.columnFontStyle,
				},
				{
					type = "button",
					name = GetString(SI_BETTERUI_COLUMN_FONT_RESET),
					tooltip = GetString(SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP),
					func = function()
						local defaults = BETTERUI.Banking.DEFAULTS
						BETTERUI.Settings.Modules["Banking"].columnFont = defaults.columnFont
						BETTERUI.Settings.Modules["Banking"].columnFontSize = defaults.columnFontSize
						BETTERUI.Settings.Modules["Banking"].columnFontStyle = defaults.columnFontStyle
					end,
					disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
					width = "half",
				},
			},
		},
		-- Removed Global Reset Button
	}
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

--- Initializes default values and migrates legacy settings for the Banking module.
--- Purpose: Ensures all necessary settings exist and converts old formats (strings -> numbers).
--- @param m_options table The raw settings table for this module.
--- @return table The initialized and migrated settings table.
function BETTERUI.Banking.InitModule(m_options)
	-- Core settings (preserve existing user values)
	if m_options["showIconEnchantment"] == nil then m_options["showIconEnchantment"] = true end
	if m_options["showIconSetGear"] == nil then m_options["showIconSetGear"] = true end
	if m_options["showIconUnboundItem"] == nil then m_options["showIconUnboundItem"] = true end
	if m_options["enableCarousel"] == nil then m_options["enableCarousel"] = false end
	
	-- Font customization - Name column settings
	local defaults = BETTERUI.Banking.DEFAULTS
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
	-- Migrate legacy string font sizes to numeric values
	local legacySizeMap = { Small = 20, Default = 24, Medium = 28, Large = 32, XLarge = 36 }
	if type(m_options["nameFontSize"]) == "string" then
		m_options["nameFontSize"] = legacySizeMap[m_options["nameFontSize"]] or 24
	end
	if type(m_options["columnFontSize"]) == "string" then
		m_options["columnFontSize"] = legacySizeMap[m_options["columnFontSize"]] or 24
	end
	if m_options["fontStyle"] and not m_options["nameFontStyle"] then
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
	
	return m_options
end

--- Lifecycle hook to setup the Banking module.
--- Purpose: Called by the core when the module should initialize its keybinds, settings, and UI.
function BETTERUI.Banking.Setup()

	Init("Bank", "Banking")

	BETTERUI.Banking.Init()

end
