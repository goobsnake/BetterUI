--[[
File: Modules/Banking/Module.lua
Purpose: Entry point and settings configuration for the Banking module.
Authors: BUI Team
Last Modified: 2026-01-16

This file handles the initialization and configuration of the Banking module.
It integrates with LibAddonMenu (LAM) to provide a settings panel for user customization.

KEY RESPONSIBILITIES:
1.  **Module Initialization (`Init`, `Setup`)**:
    *   Registers the "Banking" panel in the BetterUI addon settings.
    *   Defines default settings (`DEFAULTS`) for fonts and toggleable features.
2.  **Configuration Options**:
    *   **Fonts**: Custom font selection, size, and style for Name and Columns.
    *   **Features**: Toggles for Carousel Navigation (navigating tabs via shoulders/triggers)
        and icon visibility (Unbound, Enchanted, Set Gear).
3.  **Font Helpers**:
    *   `GetNameFontDescriptor`: Returns a valid font string for the item name column.
    *   `GetColumnFontDescriptor`: Returns a valid font string for other columns (Trait, Value, etc.).
]]


-- Module initialization
BETTERUI.Banking = BETTERUI.Banking or {}

-- Font choices/values now use CIM shared definitions (see CIM/Core/FontDefinitions.lua)
BETTERUI.Banking.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
BETTERUI.Banking.FONT_VALUES = BETTERUI.CIM.Font.VALUES
BETTERUI.Banking.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
BETTERUI.Banking.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
BETTERUI.Banking.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS

--[[
Function: BETTERUI.Banking.GetNameFontDescriptor
Description: Generates the font descriptor string for the Name column.
Rationale: Delegates to CIM.Font.GetModuleFontDescriptor with module-specific settings.
return: string - ESO font descriptor (path|size|style).
]]
function BETTERUI.Banking.GetNameFontDescriptor()
	return BETTERUI.CIM.Font.GetModuleFontDescriptor("Banking", "name")
end

--[[
Function: BETTERUI.Banking.GetColumnFontDescriptor
Description: Generates the font descriptor string for metadata columns.
Rationale: Delegates to CIM.Font.GetModuleFontDescriptor with module-specific settings.
return: string - ESO font descriptor (path|size|style).
]]
function BETTERUI.Banking.GetColumnFontDescriptor()
	return BETTERUI.CIM.Font.GetModuleFontDescriptor("Banking", "column")
end

--- Retrieves a setting value for the Banking module.
--- @param key string The setting key.
--- @return any The setting value or nil.
function BETTERUI.Banking.GetSetting(key)
	if not BETTERUI.Settings.Modules["Banking"] then return nil end
	return BETTERUI.Settings.Modules["Banking"][key]
end

--- Sets a setting value for the Banking module.
--- @param key string The setting key.
--- @param value any The value to set.
function BETTERUI.Banking.SetSetting(key, value)
	if not BETTERUI.Settings.Modules["Banking"] then return end
	BETTERUI.Settings.Modules["Banking"][key] = value
end

-- Settings registration moved to Banking/Settings/SettingsPanel.lua

--[[
Function: BETTERUI.Banking.InitModule
Description: Initializes default values and migrates legacy settings for the Banking module.
Rationale: Ensures all necessary settings exist and converts old formats.
Mechanism:
  - Sets defaults for icons and carousel.
  - Migrates `nameFont` / `nameFontSize` from older generic keys.
  - Converts string sizes ("Small", "Medium") to integer pixels.
  - Converts numeric font styles to string identifiers ("outline").
param: m_options (table) - The raw settings table for this module.
return: table - The initialized and migrated settings table.
]]
function BETTERUI.Banking.InitModule(m_options)
	-- Apply centralized defaults from DefaultsRegistry
	if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
		m_options = BETTERUI.Defaults.ApplyModuleDefaults("Banking", m_options)
	else
		-- Fallback if DefaultsRegistry not loaded yet
		if m_options["showIconEnchantment"] == nil then m_options["showIconEnchantment"] = true end
		if m_options["showIconSetGear"] == nil then m_options["showIconSetGear"] = true end
		if m_options["showIconUnboundItem"] == nil then m_options["showIconUnboundItem"] = true end
		if m_options["enableCarousel"] == nil then m_options["enableCarousel"] = true end
	end

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

--[[
Function: BETTERUI.Banking.Setup
Description: Lifecycle hook to setup the Banking module.
Rationale: Called by the core when the module should initialize its keybinds, settings, and UI.
Mechanism: Calls Init to register settings menu, then calls BETTERUI.Banking.Init to start the class.
References: Called by BETTERUI.LoadModules() in BetterUI.lua.
]]
function BETTERUI.Banking.Setup()
	d("[BetterUI] Banking.Setup() ENTER")

	d("[BetterUI] Checking Settings.RegisterPanel: " ..
	tostring(BETTERUI.Banking.Settings ~= nil and BETTERUI.Banking.Settings.RegisterPanel ~= nil))
	local ok1, err1 = pcall(function()
		BETTERUI.Banking.Settings.RegisterPanel("Bank", "Banking")
	end)
	if not ok1 then
		d("[BetterUI] ERROR in Settings.RegisterPanel: " .. tostring(err1))
	else
		d("[BetterUI] Settings.RegisterPanel done")
	end

	d("[BetterUI] Checking Banking.Init: " .. tostring(BETTERUI.Banking.Init ~= nil))
	local ok2, err2 = pcall(BETTERUI.Banking.Init)
	if not ok2 then
		d("[BetterUI] ERROR in Banking.Init: " .. tostring(err2))
	else
		d("[BetterUI] Banking.Init completed")
	end

	d("[BetterUI] Banking.Setup() EXIT")
end
