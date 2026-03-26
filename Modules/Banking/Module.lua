--[[
File: Modules/Banking/Module.lua
Purpose: Entry point and settings configuration for the Banking module.
Authors: BUI Team
Last Modified: 2026-01-16

Registers the Banking panel in the BetterUI addon settings and provides font
descriptor factories for the name and column rendering.
]]


-- Module initialization
BETTERUI.Banking = BETTERUI.Banking or {}

-- Font choices/values now use CIM shared definitions (see CIM/Core/FontDefinitions.lua)
BETTERUI.Banking.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
BETTERUI.Banking.FONT_VALUES = BETTERUI.CIM.Font.VALUES
BETTERUI.Banking.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
BETTERUI.Banking.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
BETTERUI.Banking.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS

-- Font descriptor closures via CIM factory (see CIM/Core/FontDefinitions.lua)
do
    local descriptors = BETTERUI.CIM.Font.CreateModuleDescriptors("Banking")
    BETTERUI.Banking.GetNameFontDescriptor = descriptors.name
    BETTERUI.Banking.GetColumnFontDescriptor = descriptors.column
end

--- Retrieves a setting value for the Banking module.
--- @param key string The setting key.
--- @return any The setting value or nil.
function BETTERUI.Banking.GetSetting(key)
	return BETTERUI.GetSetting("Banking", key)
end

--- Sets a setting value for the Banking module.
--- @param key string The setting key.
--- @param value any The value to set.
function BETTERUI.Banking.SetSetting(key, value)
	if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return end
	if not BETTERUI.Settings.Modules["Banking"] then
		BETTERUI.Settings.Modules["Banking"] = {}
	end
	BETTERUI.Settings.Modules["Banking"][key] = value
end

-- Settings registration moved to Banking/Settings/SettingsPanel.lua

--- Initializes defaults and migrates legacy settings for the Banking module.
--- @param m_options table The raw settings table for this module.
--- @return table The initialized and migrated settings table.
function BETTERUI.Banking.InitModule(m_options)
	local defaults = BETTERUI.Banking.DEFAULTS
	local fallbackDefaults = {
		showIconEnchantment = true,
		showIconSetGear = true,
		showIconUnboundItem = true,
		showIconResearchableTrait = true,
		showIconUnknownRecipe = true,
		showIconUnknownBook = true,
		enableCarousel = true,
	}

	m_options = BETTERUI.CIM.InitModuleDefaults("Banking", m_options, defaults, fallbackDefaults, function(options, moduleDefaults)
		-- Migrate old settings to new format if present
		if options["font"] and not options["nameFont"] then
			options["nameFont"] = options["font"]
			options["columnFont"] = options["font"]
		end
		if options["skinSize"] and not options["nameFontSize"] then
			options["nameFontSize"] = options["skinSize"]
			options["columnFontSize"] = options["skinSize"]
		end

		if options["fontStyle"] and not options["nameFontStyle"] then
			local oldStyle = options["fontStyle"]
			if type(oldStyle) == "number" then
				local styleMap = {
					[0] = "",
					[1] = "outline",
					[2] = "thick-outline",
					[3] = "shadow",
					[4] = "soft-shadow-thick",
					[5] = "soft-shadow-thin",
				}
				oldStyle = styleMap[oldStyle] or moduleDefaults.nameFontStyle
			end
			options["nameFontStyle"] = oldStyle
			options["columnFontStyle"] = oldStyle
		end
	end)

	return m_options
end

--- Lifecycle hook: registers settings and starts the Banking class.
function BETTERUI.Banking.Setup()
	BETTERUI.Banking.Settings.RegisterPanel("Bank", "Banking")
	BETTERUI.Banking.Init()
end
