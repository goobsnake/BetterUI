--[[
File: Modules/Inventory/Module.lua
Purpose: Entry point and settings configuration for the Inventory module.
]]

-- Module initialization
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
BETTERUI.CIM.RegisterModuleAccessors("Inventory")

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
    local defaults = BETTERUI.Inventory.DEFAULTS
    local fallbackDefaults = {
        quickDestroy = false,
        enableBatchDestroy = false,
        enableCarousel = true,
        useTriggersForSkip = false,
        triggerSpeed = 10,
        bindOnEquipProtection = true,
        enableCompanionJunk = false,
        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,
    }

    m_options = BETTERUI.CIM.InitModuleDefaults("Inventory", m_options, defaults, fallbackDefaults,
        function(options)
            -- Currency defaults should match the canonical "default" preset.
            local defaultCurrencyPreset = BETTERUI.CURRENCY_PRESETS and BETTERUI.CURRENCY_PRESETS.default
            if type(defaultCurrencyPreset) == "table" then
                for key, value in pairs(defaultCurrencyPreset) do
                    if options[key] == nil then
                        options[key] = value
                    end
                end
            else
                -- Fallback defaults if preset table is unavailable.
                if options["showCurrencyGold"] == nil then options["showCurrencyGold"] = true end
                if options["showCurrencyAlliancePoints"] == nil then options["showCurrencyAlliancePoints"] = true end
                if options["showCurrencyTelVar"] == nil then options["showCurrencyTelVar"] = true end
                if options["showCurrencyCrownGems"] == nil then options["showCurrencyCrownGems"] = true end
                if options["showCurrencyCrowns"] == nil then options["showCurrencyCrowns"] = true end
                if options["showCurrencyTransmute"] == nil then options["showCurrencyTransmute"] = true end
                if options["showCurrencyWritVouchers"] == nil then options["showCurrencyWritVouchers"] = true end
                if options["showCurrencyTradeBars"] == nil then options["showCurrencyTradeBars"] = true end
                if options["showCurrencyUndauntedKeys"] == nil then options["showCurrencyUndauntedKeys"] = true end
                if options["showCurrencyOutfitTokens"] == nil then options["showCurrencyOutfitTokens"] = true end
                if options["showCurrencySeals"] == nil then options["showCurrencySeals"] = true end
                if options["showCurrencyTomePoints"] == nil then options["showCurrencyTomePoints"] = false end

                if options["orderCurrencyGold"] == nil then options["orderCurrencyGold"] = 1 end
                if options["orderCurrencyAlliancePoints"] == nil then options["orderCurrencyAlliancePoints"] = 2 end
                if options["orderCurrencyTelVar"] == nil then options["orderCurrencyTelVar"] = 3 end
                if options["orderCurrencyUndauntedKeys"] == nil then options["orderCurrencyUndauntedKeys"] = 4 end
                if options["orderCurrencyTransmute"] == nil then options["orderCurrencyTransmute"] = 5 end
                if options["orderCurrencyCrowns"] == nil then options["orderCurrencyCrowns"] = 6 end
                if options["orderCurrencyCrownGems"] == nil then options["orderCurrencyCrownGems"] = 7 end
                if options["orderCurrencyWritVouchers"] == nil then options["orderCurrencyWritVouchers"] = 8 end
                if options["orderCurrencyTradeBars"] == nil then options["orderCurrencyTradeBars"] = 9 end
                if options["orderCurrencyOutfitTokens"] == nil then options["orderCurrencyOutfitTokens"] = 10 end
                if options["orderCurrencySeals"] == nil then options["orderCurrencySeals"] = 11 end
                if options["orderCurrencyTomePoints"] == nil then options["orderCurrencyTomePoints"] = 12 end
            end

            if options["currencyPreset"] == nil then options["currencyPreset"] = "default" end
            if options["currencyOrder"] == nil then
                options["currencyOrder"] =
                "gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints"
            end
        end)

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
	if BETTERUI.GetSetting("CIM", "enableTooltipEnhancements", true) ~= false then
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
				return GetString(rawget(_G, "SI_BETTERUI_INV_TITLE"))
			end
		)
	end
end
