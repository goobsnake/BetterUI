--[[
File: Modules/Inventory/Settings/SettingsPanel.lua
Purpose: Handles the LAM settings panel construction for the Inventory module.
         Aggregates settings from FontSettings, CurrencySettings, and internal general settings.
]]

local LAM = LibAddonMenu2

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Settings = BETTERUI.Inventory.Settings or {}

--- Initializes the settings panel for the Inventory module.
function BETTERUI.Inventory.Settings.RegisterPanel(mId, moduleName)
	local panelData = BETTERUI.Init_ModulePanel(moduleName, "Inventory Improvement Settings")

	local function GetInventoryWindow()
		return GAMEPAD_INVENTORY
	end

	local function IsInventorySceneShowing(inv)
		if not inv then return false end
		if inv.scene and inv.scene.IsShowing then
			return inv.scene:IsShowing()
		end
		return false
	end

	local function RefreshInventoryList()
		local inv = GetInventoryWindow()
		if inv and IsInventorySceneShowing(inv) and inv.RefreshItemList then
			inv:RefreshItemList()
		end
	end

	local function ApplyTriggerMode(_useCategoryJump)
		local inv = GetInventoryWindow()
		if not inv then return end
		if inv.SetListsUseTriggerKeybinds then
			inv:SetListsUseTriggerKeybinds(false)
		end
		if inv.RefreshKeybinds and IsInventorySceneShowing(inv) then
			inv:RefreshKeybinds()
		end
	end

	local function ResetInventoryGeneralSettings()
		if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
			BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("Inventory", "general")
		else
			BETTERUI.Inventory.SetSetting("quickDestroy", false)
			BETTERUI.Inventory.SetSetting("enableBatchDestroy", false)
			BETTERUI.Inventory.SetSetting("enableCarousel", true)
			BETTERUI.Inventory.SetSetting("useTriggersForSkip", false)
			BETTERUI.Inventory.SetSetting("triggerSpeed", 10)
			BETTERUI.Inventory.SetSetting("bindOnEquipProtection", true)
			BETTERUI.Inventory.SetSetting("enableCompanionJunk", false)
		end

		local inv = GetInventoryWindow()
		if inv and inv.categoryHeaderData then
			inv.categoryHeaderData.carouselConfig = inv.categoryHeaderData.carouselConfig or {}
			inv.categoryHeaderData.carouselConfig.enabled = BETTERUI.Inventory.GetSetting("enableCarousel")
			if inv.RefreshHeader then
				inv:RefreshHeader(true)
			end
		end

		ApplyTriggerMode(BETTERUI.Inventory.GetSetting("useTriggersForSkip"))

		if inv and IsInventorySceneShowing(inv) and inv.RefreshItemActions then
			inv:RefreshItemActions()
		end

		RefreshInventoryList()
	end

	local optionsTable = {
		{
			type = "header",
			name = GetString(rawget(_G, "SI_BETTERUI_INV_GENERAL_HEADER")),
			width = "full",
		},
		{
			type = "description",
			text = GetString(rawget(_G, "SI_BETTERUI_INV_GENERAL_DESC")),
			width = "full",
		},
		-- Quick Destroy
		{
			type = "checkbox",
			name = "|t24:24:EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds|t " .. GetString(rawget(_G, "SI_BETTERUI_QUICK_DESTROY")),
			tooltip = GetString(rawget(_G, "SI_BETTERUI_QUICK_DESTROY_TOOLTIP")),
			warning = GetString(rawget(_G, "SI_BETTERUI_QUICK_DESTROY_WARNING")),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("quickDestroy")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("quickDestroy", value) end,
			width = "full",
		},
		-- Batch Destroy (multi-select)
		{
			type = "checkbox",
			name = "|t24:24:EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds|t " ..
			GetString(rawget(_G, "SI_BETTERUI_ENABLE_BATCH_DESTROY")),
			tooltip = GetString(rawget(_G, "SI_BETTERUI_ENABLE_BATCH_DESTROY_TOOLTIP")),
			warning = GetString(rawget(_G, "SI_BETTERUI_ENABLE_BATCH_DESTROY_WARNING")),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("enableBatchDestroy")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("enableBatchDestroy", value) end,
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(rawget(_G, "SI_BETTERUI_ENABLE_CAROUSEL_NAV")),
			tooltip = GetString(rawget(_G, "SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP")),
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
			name = GetString(rawget(_G, "SI_BETTERUI_TRIGGER_SKIP_TYPE")),
			tooltip = GetString(rawget(_G, "SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP")),
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
			type = "editbox",
			name = GetString(rawget(_G, "SI_BETTERUI_TRIGGER_SKIP")),
			tooltip = GetString(rawget(_G, "SI_BETTERUI_TRIGGER_SKIP_TOOLTIP")),
			getFunc = function()
				local value = BETTERUI.Inventory.GetSetting("triggerSpeed")
				return value and tostring(value) or "10"
			end,
			setFunc = function(value)
				local parsedValue = tonumber(value) or 10
				if parsedValue < 1 then parsedValue = 1 end
				if parsedValue > 1000 then parsedValue = 1000 end
				BETTERUI.Inventory.SetSetting("triggerSpeed", parsedValue)
				ApplyTriggerMode(BETTERUI.Inventory.GetSetting("useTriggersForSkip"))
			end,
			disabled = function() return not BETTERUI.Inventory.GetSetting("useTriggersForSkip") end,
			width = "full",
			sortAlwaysLast = true,
		},
		{
			type = "checkbox",
			name = GetString(rawget(_G, "SI_BETTERUI_BOE_PROTECTION")),
			tooltip = GetString(rawget(_G, "SI_BETTERUI_BOE_PROTECTION_TOOLTIP")),
			getFunc = function()
				return BETTERUI.Inventory.GetSetting("bindOnEquipProtection")
			end,
			setFunc = function(value) BETTERUI.Inventory.SetSetting("bindOnEquipProtection", value) end,
			width = "full",
		},
	}

	-- Continue with remaining options
	table.insert(optionsTable, {
		type = "checkbox",
		name = GetString(rawget(_G, "SI_BETTERUI_ENABLE_COMPANION_JUNK")),
		tooltip = GetString(rawget(_G, "SI_BETTERUI_ENABLE_COMPANION_JUNK_TOOLTIP")),
		getFunc = function()
			return BETTERUI.Inventory.GetSetting("enableCompanionJunk") == true
		end,
		setFunc = function(value)
			BETTERUI.Inventory.SetSetting("enableCompanionJunk", value)
			local inv = GetInventoryWindow()
			if inv and IsInventorySceneShowing(inv) and inv.RefreshItemActions then
				inv:RefreshItemActions()
			end
		end,
		width = "full",
	})
	table.insert(optionsTable, {
		type = "button",
		name = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET")),
		tooltip = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET_TOOLTIP")),
		func = function()
			ResetInventoryGeneralSettings()
		end,
		width = "half",
	})

	-- Append Currency Settings (if available)
	if BETTERUI.Inventory.Settings.GetCurrencyOptions then
		local currencyOptions = BETTERUI.Inventory.Settings.GetCurrencyOptions()
		if currencyOptions then
			table.insert(optionsTable, currencyOptions)
		end
	end

	-- Item Icon Customization submenu (using shared CIM factory)
	table.insert(optionsTable, BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption("Inventory", function()
		RefreshInventoryList()
	end))

	-- Append Font Settings (if available)
	if BETTERUI.Inventory.Settings.GetFontOptions then
		local fontOptions = BETTERUI.Inventory.Settings.GetFontOptions()
		if fontOptions then
			for _, opt in ipairs(fontOptions) do
				table.insert(optionsTable, opt)
			end
		end
	end

	-- Alphabetize top-level General settings and all submenu settings.
	if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.SortSettingsAlphabetically then
		BETTERUI.CIM.Settings.SortSettingsAlphabetically(optionsTable, true)
	end

	LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end
