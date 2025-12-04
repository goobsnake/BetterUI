-- BetterUI Banking Module
-- Settings panel and font customization for enhanced banking interface

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
	nameFontSize = "Default",
	nameFontStyle = "",
	-- Other columns font settings (Type, Trait, Stat, Value)
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

-- Returns font descriptor string for Name column
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

-- Returns font descriptor string for column labels (Type, Trait, Stat, Value)
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

-- Initializes settings panel for Banking module
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "Banking Improvement Settings")

	local optionsTable = {
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_USE_LEGACY_NAV),
			tooltip = GetString(SI_BETTERUI_USE_LEGACY_NAV_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Banking"].enableLegacyNavigation end,
			setFunc = function(value) BETTERUI.Settings.Modules["Banking"].enableLegacyNavigation = value end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Item Icon - Unbound Items",
			tooltip = "Show an icon after unbound items.",
			getFunc = function() return BETTERUI.Settings.Modules["Banking"].showIconUnboundItem end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Banking"].showIconUnboundItem = value
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Item Icon - Enchantment",
			tooltip = "Show an icon after enchanted item.",
			getFunc = function() return BETTERUI.Settings.Modules["Banking"].showIconEnchantment end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["Banking"].showIconEnchantment = value
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Item Icon - Set Gear",
			tooltip = "Show an icon after set gears.",
			getFunc = function() return BETTERUI.Settings.Modules["Banking"].showIconSetGear end,
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
					type = "dropdown",
					name = GetString(SI_BETTERUI_BANK_NAME_FONT_SIZE),
					tooltip = GetString(SI_BETTERUI_BANK_NAME_FONT_SIZE_TOOLTIP),
					choices = {GetString(SI_BETTERUI_FONT_SIZE_SMALL), GetString(SI_BETTERUI_FONT_SIZE_DEFAULT), GetString(SI_BETTERUI_FONT_SIZE_MEDIUM), GetString(SI_BETTERUI_FONT_SIZE_LARGE), GetString(SI_BETTERUI_FONT_SIZE_XLARGE)},
					choicesValues = {"Small", "Default", "Medium", "Large", "XLarge"},
					getFunc = function()
						return BETTERUI.Settings.Modules["Banking"].nameFontSize or BETTERUI.Banking.DEFAULTS.nameFontSize
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
					type = "dropdown",
					name = GetString(SI_BETTERUI_BANK_COLUMN_FONT_SIZE),
					tooltip = GetString(SI_BETTERUI_BANK_COLUMN_FONT_SIZE_TOOLTIP),
					choices = {GetString(SI_BETTERUI_FONT_SIZE_SMALL), GetString(SI_BETTERUI_FONT_SIZE_DEFAULT), GetString(SI_BETTERUI_FONT_SIZE_MEDIUM), GetString(SI_BETTERUI_FONT_SIZE_LARGE), GetString(SI_BETTERUI_FONT_SIZE_XLARGE)},
					choicesValues = {"Small", "Default", "Medium", "Large", "XLarge"},
					getFunc = function()
						return BETTERUI.Settings.Modules["Banking"].columnFontSize or BETTERUI.Banking.DEFAULTS.columnFontSize
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
			},
		},
		{
			type = "button",
			name = GetString(SI_BETTERUI_BANK_FONT_RESET),
			tooltip = GetString(SI_BETTERUI_BANK_FONT_RESET_TOOLTIP),
			func = function()
				local defaults = BETTERUI.Banking.DEFAULTS
				-- Reset Name font settings
				BETTERUI.Settings.Modules["Banking"].nameFont = defaults.nameFont
				BETTERUI.Settings.Modules["Banking"].nameFontSize = defaults.nameFontSize
				BETTERUI.Settings.Modules["Banking"].nameFontStyle = defaults.nameFontStyle
				-- Reset Column font settings
				BETTERUI.Settings.Modules["Banking"].columnFont = defaults.columnFont
				BETTERUI.Settings.Modules["Banking"].columnFontSize = defaults.columnFontSize
				BETTERUI.Settings.Modules["Banking"].columnFontStyle = defaults.columnFontStyle
			end,
			disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
			width = "half",
		},
	}
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

-- Initializes Banking default settings (handles legacy migration)
--- @param m_options table: Options table
--- @return table: Initialized options
function BETTERUI.Banking.InitModule(m_options)
	m_options["showIconEnchantment"] = true
	m_options["showIconSetGear"] = true
	m_options["showIconUnboundItem"] = true
	
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

-- Sets up Banking module
function BETTERUI.Banking.Setup()

	Init("Bank", "Banking")

	BETTERUI.Banking.Init()

end
