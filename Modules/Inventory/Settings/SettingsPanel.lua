--[[
File: Modules/Inventory/Settings/SettingsPanel.lua
Purpose: Handles the LAM settings panel construction for the Inventory module.
         Aggregates settings from FontSettings, CurrencySettings, and internal general settings.
Last Modified: 2026-02-08
]]

local LAM = LibAddonMenu2

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Settings = BETTERUI.Inventory.Settings or {}

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
--- @param mId string The module ID
--- @param moduleName string The display name of the module
function BETTERUI.Inventory.RegisterSettings(mId, moduleName)
	local panelData = BETTERUI.Init_ModulePanel(moduleName, "Inventory Improvement Settings")

	local function GetInventoryWindow()
		return GAMEPAD_INVENTORY
	end

	local function RefreshInventoryList()
		local inv = GetInventoryWindow()
		if inv and inv.RefreshItemList then
			inv:RefreshItemList()
		end
	end

	local function RefreshBankingList()
		local bankingWindow = BETTERUI.Banking and BETTERUI.Banking.Window
		if bankingWindow and bankingWindow.RefreshList then
			bankingWindow:RefreshList()
		end
	end

	local function ApplyTriggerMode(useCategoryJump)
		local inv = GetInventoryWindow()
		if not inv then return end
		if inv.SetListsUseTriggerKeybinds then
			inv:SetListsUseTriggerKeybinds(useCategoryJump)
		end
		if inv.RefreshKeybinds then
			inv:RefreshKeybinds()
		end
	end

	local optionsTable = {
		-- Quick Destroy
		{
			type = "checkbox",
			name = "⚠️ " .. GetString(SI_BETTERUI_QUICK_DESTROY),
			tooltip = GetString(SI_BETTERUI_QUICK_DESTROY_TOOLTIP),
			warning = GetString(SI_BETTERUI_QUICK_DESTROY_WARNING),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("quickDestroy")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("quickDestroy", value) end,
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV),
			tooltip = GetString(SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("enableCarousel")
			end,
			setFunc = function(value)
				BETTERUI.Inventory.SetSetting("enableCarousel", value)
				local inv = GetInventoryWindow()
				if inv and inv.categoryHeaderData then
					inv.categoryHeaderData.carouselConfig = inv.categoryHeaderData.carouselConfig or {}
					inv.categoryHeaderData.carouselConfig.enabled = value
					if inv.RefreshHeader then
						inv:RefreshHeader(true)
					end
				end
			end,
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_TRIGGER_SKIP_TYPE),
			tooltip = GetString(SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("useTriggersForSkip")
			end,
			setFunc = function(value)
				BETTERUI.Inventory.SetSetting("useTriggersForSkip", value)
				ApplyTriggerMode(value)
			end,
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_SHOW_MARKET_PRICE),
			tooltip = GetString(SI_BETTERUI_SHOW_MARKET_PRICE_TOOLTIP),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("showMarketPrice")
			end,
			setFunc = function(value)
				BETTERUI.Inventory.SetSetting("showMarketPrice", value)
				RefreshInventoryList()
				RefreshBankingList()
			end,
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
		},
		-- Icon Visibility (using shared CIM factory)
	}

	-- Item Icon Customization submenu (using shared CIM factory)
	table.insert(optionsTable, BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption("Inventory", function()
		RefreshInventoryList()
	end))

	-- Continue with remaining options
	table.insert(optionsTable, {
		type = "checkbox",
		name = GetString(SI_BETTERUI_ENABLE_COMPANION_JUNK),
		tooltip = GetString(SI_BETTERUI_ENABLE_COMPANION_JUNK_TOOLTIP),
		getFunc = function()
			return BETTERUI.Inventory.GetSetting("enableCompanionJunk") == true
		end,
		setFunc = function(value)
			BETTERUI.Inventory.SetSetting("enableCompanionJunk", value)
			local inv = GetInventoryWindow()
			if inv and inv.RefreshItemActions then
				inv:RefreshItemActions()
			end
		end,
		width = "full",
	})

	-- Append Currency Settings (if available)
	if BETTERUI.Inventory.Settings.GetCurrencyOptions then
		local currencyOptions = BETTERUI.Inventory.Settings.GetCurrencyOptions()
		if currencyOptions then
			table.insert(optionsTable, currencyOptions)
		end
	end

	-- Append Font Settings (if available)
	if BETTERUI.Inventory.Settings.GetFontOptions then
		local fontOptions = BETTERUI.Inventory.Settings.GetFontOptions()
		if fontOptions then
			for _, opt in ipairs(fontOptions) do
				table.insert(optionsTable, opt)
			end
		end
	end

	LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end

--- Initialize inventory module settings with default values
--- @param m_options table The module options table
--- @return table m_options The initialized options table
function BETTERUI.Inventory.InitModule(m_options)
	-- Apply centralized defaults from DefaultsRegistry
	if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
		m_options = BETTERUI.Defaults.ApplyModuleDefaults("Inventory", m_options)
	else
		-- Fallback if DefaultsRegistry not loaded yet
		if m_options["showMarketPrice"] == nil then m_options["showMarketPrice"] = true end
		if m_options["useTriggersForSkip"] == nil then m_options["useTriggersForSkip"] = false end
		if m_options["bindOnEquipProtection"] == nil then m_options["bindOnEquipProtection"] = true end
		if m_options["showIconEnchantment"] == nil then m_options["showIconEnchantment"] = true end
		if m_options["showIconSetGear"] == nil then m_options["showIconSetGear"] = true end
		if m_options["showIconUnboundItem"] == nil then m_options["showIconUnboundItem"] = true end
		if m_options["showIconResearchableTrait"] == nil then m_options["showIconResearchableTrait"] = true end
		if m_options["showIconUnknownRecipe"] == nil then m_options["showIconUnknownRecipe"] = true end
		if m_options["showIconUnknownBook"] == nil then m_options["showIconUnknownBook"] = true end
		if m_options["quickDestroy"] == nil then m_options["quickDestroy"] = false end
		if m_options["enableCarousel"] == nil then m_options["enableCarousel"] = true end
		if m_options["enableCompanionJunk"] == nil then m_options["enableCompanionJunk"] = false end
	end

	-- Defaults from FontSettings (accessed globally if available, otherwise local defaults)
	local funcDefaults = BETTERUI.Inventory.DEFAULTS or {
		nameFont = "$(GAMEPAD_MEDIUM_FONT)",
		nameFontSize = 24,
		nameFontStyle = "",
		columnFont = "$(GAMEPAD_MEDIUM_FONT)",
		columnFontSize = 24,
		columnFontStyle = "",
	}

	m_options["nameFont"] = m_options["nameFont"] or funcDefaults.nameFont
	m_options["nameFontSize"] = m_options["nameFontSize"] or funcDefaults.nameFontSize
	m_options["nameFontStyle"] = m_options["nameFontStyle"] or funcDefaults.nameFontStyle
	m_options["columnFont"] = m_options["columnFont"] or funcDefaults.columnFont
	m_options["columnFontSize"] = m_options["columnFontSize"] or funcDefaults.columnFontSize
	m_options["columnFontStyle"] = m_options["columnFontStyle"] or funcDefaults.columnFontStyle

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
			local styleMap = {
				[0] = "",
				[1] = "outline",
				[2] = "thick-outline",
				[3] = "shadow",
				[4] =
				"soft-shadow-thick",
				[5] = "soft-shadow-thin"
			}
			oldStyle = styleMap[oldStyle] or funcDefaults.nameFontStyle
		end
		m_options["nameFontStyle"] = oldStyle
		m_options["columnFontStyle"] = oldStyle
	end

	-- Migration: Western-only fonts -> Localized font (for CJK/Russian support)
	-- Only migrate non-English users; English users keep their font selections
	local currentLang = GetCVar("language.2") or "en"
	local isEnglish = (currentLang == "en")

	if not isEnglish then
		local westernOnlyFonts = {
			["EsoUI/Common/Fonts/FTN57.otf"] = true,
			["EsoUI/Common/Fonts/FTN47.otf"] = true,
			["EsoUI/Common/Fonts/FTN87.otf"] = true,
			["EsoUI/Common/Fonts/Univers57.otf"] = true,
			["EsoUI/Common/Fonts/Univers67.otf"] = true,
			["EsoUI/Common/Fonts/ProseAntiquePSMT.otf"] = true,
			["EsoUI/Common/Fonts/Handwritten_Bold.otf"] = true,
			["EsoUI/Common/Fonts/TrajanPro-Regular.otf"] = true,
			["EsoUI/Common/Fonts/Skyrim_Handwritten.otf"] = true,
			["EsoUI/Common/Fonts/consola.otf"] = true,
		}
		if m_options["nameFont"] and westernOnlyFonts[m_options["nameFont"]] then
			m_options["nameFont"] = "$(GAMEPAD_MEDIUM_FONT)"
		end
		if m_options["columnFont"] and westernOnlyFonts[m_options["columnFont"]] then
			m_options["columnFont"] = "$(GAMEPAD_MEDIUM_FONT)"
		end
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
	if m_options["currencyOrder"] == nil then
		m_options["currencyOrder"] =
		"gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints"
	end

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
