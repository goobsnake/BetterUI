--[[
File: Modules/Inventory/Module.lua
Purpose: Entry point and settings configuration for the Inventory module.
Author: BetterUI Team
Last Modified: 2026-03-26
]]

-- Module initialization
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Font choices/values now use CIM shared definitions (see CIM/Core/FontDefinitions.lua)
BETTERUI.Inventory.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
BETTERUI.Inventory.FONT_VALUES = BETTERUI.CIM.Font.VALUES
BETTERUI.Inventory.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
BETTERUI.Inventory.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
BETTERUI.Inventory.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS

-- Font descriptor closures via CIM factory (see CIM/Core/FontDefinitions.lua)
do
    local descriptors = BETTERUI.CIM.Font.CreateModuleDescriptors("Inventory")
    BETTERUI.Inventory.GetNameFontDescriptor = descriptors.name
    BETTERUI.Inventory.GetColumnFontDescriptor = descriptors.column
end

--- Settings Accessor Protocol:
--- GetSetting(key) -> value: Returns saved setting value or default
--- SetSetting(key, value): Persists setting and triggers change notification
---
--- Retrieves a setting value for the Inventory module.
--- @param key string The setting key.
--- @return any The setting value or module default.
function BETTERUI.Inventory.GetSetting(key)
	if key == nil then return nil end
	local defaultValue = BETTERUI.Defaults and BETTERUI.Defaults.GetDefault and BETTERUI.Defaults.GetDefault("Inventory", key) or nil
	return BETTERUI.GetSetting("Inventory", key, defaultValue)
end

--- Sets a setting value for the Inventory module.
--- @param key string The setting key.
--- @param value any The value to set.
function BETTERUI.Inventory.SetSetting(key, value)
	BETTERUI.SetSetting("Inventory", key, value)
end

--- Initializes defaults and migrates legacy settings for the Inventory module.
---
--- INIT CONTRACT: This function implements the standard InitModule signature.
--- It is called by BETTERUI.ModuleOptions() via pcall with only m_options.
---
--- Standard InitModule Signature (consistent across all modules):
---   @param m_options table|nil The raw settings table to be initialized
---   @return table The modified options table with default values applied
---
--- Wrapper Function (caller in BetterUI.lua):
---   BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
---
function BETTERUI.Inventory.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options table
    -- Apply centralized defaults from DefaultsRegistry
    if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
        m_options = BETTERUI.Defaults.ApplyModuleDefaults("Inventory", m_options)
    else
        -- Fallback if DefaultsRegistry not loaded yet
        if m_options["quickDestroy"] == nil then m_options["quickDestroy"] = false end
        if m_options["enableBatchDestroy"] == nil then m_options["enableBatchDestroy"] = false end
        if m_options["enableCarousel"] == nil then m_options["enableCarousel"] = true end
        if m_options["useTriggersForSkip"] == nil then m_options["useTriggersForSkip"] = false end
        if m_options["triggerSpeed"] == nil then m_options["triggerSpeed"] = 10 end
        if m_options["bindOnEquipProtection"] == nil then m_options["bindOnEquipProtection"] = true end
        if m_options["enableCompanionJunk"] == nil then m_options["enableCompanionJunk"] = false end
        if m_options["showIconEnchantment"] == nil then m_options["showIconEnchantment"] = true end
        if m_options["showIconSetGear"] == nil then m_options["showIconSetGear"] = true end
        if m_options["showIconUnboundItem"] == nil then m_options["showIconUnboundItem"] = true end
        if m_options["showIconResearchableTrait"] == nil then m_options["showIconResearchableTrait"] = true end
        if m_options["showIconUnknownRecipe"] == nil then m_options["showIconUnknownRecipe"] = true end
        if m_options["showIconUnknownBook"] == nil then m_options["showIconUnknownBook"] = true end
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
                [4] = "soft-shadow-thick",
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

    -- Currency defaults should match the canonical "default" preset (same behavior as reset).
    local defaultCurrencyPreset = BETTERUI.CURRENCY_PRESETS and BETTERUI.CURRENCY_PRESETS.default
    if type(defaultCurrencyPreset) == "table" then
        for key, value in pairs(defaultCurrencyPreset) do
            if m_options[key] == nil then
                m_options[key] = value
            end
        end
    else
        -- Fallback defaults if preset table is unavailable.
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
        if m_options["showCurrencySeals"] == nil then m_options["showCurrencySeals"] = true end
        if m_options["showCurrencyTomePoints"] == nil then m_options["showCurrencyTomePoints"] = false end

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
    end

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
        m_options["showCurrencyTradeBars"] = m_options["orderCurrencyEventTickets"]
        m_options["orderCurrencyEventTickets"] = nil
    end
    if m_options["currencyOrder"] ~= nil then
        m_options["currencyOrder"] = string.gsub(m_options["currencyOrder"], "tickets", "tradebars")
    end

    -- Persisted font sizes may exceed current slider caps from prior versions.
    if BETTERUI.CIM and BETTERUI.CIM.Font and BETTERUI.CIM.Font.NormalizeModuleFontSettings then
        BETTERUI.CIM.Font.NormalizeModuleFontSettings(m_options, funcDefaults)
    end

    return m_options
end

-- Settings registration moved to Inventory/Settings/SettingsPanel.lua



-- ============================================================================
-- MODULE SETUP
-- ============================================================================

--- Lifecycle hook: registers settings and initializes the Inventory module.
--- Registers settings, replaces native GAMEPAD_INVENTORY, and configures tooltips.
function BETTERUI.Inventory.Setup()
	BETTERUI.Inventory.Settings.RegisterPanel("Inventory", "Inventory")

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

	-- Initialize the Craft Bag quantity dialog for stow/retrieve operations
	if BETTERUI.Inventory.Dialogs and BETTERUI.Inventory.Dialogs.InitializeCraftBagQuantityDialog then
		BETTERUI.Inventory.Dialogs.InitializeCraftBagQuantityDialog()
	end

	-- Hook ZO_StackSplit_SplitItem to prevent duplicate dialogs using a lock flag
	-- This is the ONLY guard needed - it blocks at the source
	local originalSplitItem = ZO_StackSplit_SplitItem
	ZO_StackSplit_SplitItem = function(inventorySlotControl)
		-- Guard: If we're in the middle of a split stack operation, block
		if BETTERUI.Inventory._splitStackLock then
			return false
		end

		-- Set lock BEFORE showing dialog
		BETTERUI.Inventory._splitStackLock = true

		-- Call original - dialog will show
		local result = originalSplitItem(inventorySlotControl)

		-- If dialog didn't show (e.g., item not splittable), clear lock immediately
		if not result then
			BETTERUI.Inventory._splitStackLock = nil
		end
		-- Otherwise, lock will be cleared by OnHiddenCallback in Inventory.lua

		return result
	end

	-- Configure tooltip appearance and behavior
	ZO_GamepadTooltipTopLevelLeftTooltipContainer.tip.maxFadeGradientSize = BETTERUI.CIM.CONST
		.TOOLTIP_MAX_FADE_GRADIENT_SIZE

	-- Only apply custom tooltip styles (font scaling) if enhancements are enabled
	local cimSettings = BETTERUI.Settings.Modules["CIM"]
	if cimSettings and cimSettings.enableTooltipEnhancements ~= false then
		BETTERUI.Inventory.ApplyTooltipStyles()
	end

	BETTERUI.Inventory.EnableTooltipMouseWheel()

	-- Register custom dialog for Bind on Equip protection (if SaveEquip addon is not handling it)
	if not SaveEquip then
		BETTERUI.CIM.Dialogs.Register("CONFIRM_EQUIP_BOE", {
			gamepadInfo = {
				dialogType = GAMEPAD_DIALOGS.BASIC,
			},
			title = {
				text = SI_BETTERUI_SAVE_EQUIP_CONFIRM_TITLE,
			},
			mainText = {
				text = SI_BETTERUI_SAVE_EQUIP_CONFIRM_EQUIP_BOE,
			},
			buttons = {
				[1] = {
					text = SI_BETTERUI_SAVE_EQUIP_EQUIP,
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

	-- Register narration for Inventory scene (ACC-001)
	if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
		BETTERUI.CIM.Narration.RegisterListNarration(
			"gamepadInventory",
			function()
				return GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.currentlySelectedData
			end,
			function()
				return GetString(SI_BETTERUI_INV_TITLE)
			end
		)
	end
end
