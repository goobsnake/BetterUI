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
---
--- Wrapper Function (caller in BetterUI.lua):
---   BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
---
---@param m_options table|nil Module options table
---@return table m_options Initialized options with defaults applied
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
                local fallbackDefaults = {
                    showCurrencyGold = true,
                    showCurrencyAlliancePoints = true,
                    showCurrencyTelVar = true,
                    showCurrencyCrownGems = true,
                    showCurrencyCrowns = true,
                    showCurrencyTransmute = true,
                    showCurrencyWritVouchers = true,
                    showCurrencyTradeBars = true,
                    showCurrencyUndauntedKeys = true,
                    showCurrencyOutfitTokens = true,
                    showCurrencySeals = true,
                    showCurrencyTomePoints = false,
                    orderCurrencyGold = 1,
                    orderCurrencyAlliancePoints = 2,
                    orderCurrencyTelVar = 3,
                    orderCurrencyUndauntedKeys = 4,
                    orderCurrencyTransmute = 5,
                    orderCurrencyCrowns = 6,
                    orderCurrencyCrownGems = 7,
                    orderCurrencyWritVouchers = 8,
                    orderCurrencyTradeBars = 9,
                    orderCurrencyOutfitTokens = 10,
                    orderCurrencySeals = 11,
                    orderCurrencyTomePoints = 12,
                }
                for key, value in pairs(fallbackDefaults) do
                    if options[key] == nil then
                        options[key] = value
                    end
                end
            end

            if options["currencyPreset"] == nil then options["currencyPreset"] = "default" end
            if options["currencyOrder"] == nil then
                options["currencyOrder"] =
                "gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints"
            end
        end)

    return m_options
end

-- MODULE SETUP

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
	local dialogOk = BETTERUI.CIM.TryCall("Inventory.Dialogs.InitializeCraftBagQuantityDialog")
	if not dialogOk then
		d("[BetterUI] Inventory: CraftBagQuantityDialog init failed")
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
	local narrOk = BETTERUI.CIM.TryCall("CIM.Narration.RegisterListNarration",
		"gamepadInventory",
		function()
			return GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.currentlySelectedData
		end,
		function()
			return GetString(rawget(_G, "SI_BETTERUI_INV_TITLE"))
		end
	)
	if not narrOk then
		d("[BetterUI] Inventory: Narration registration failed")
	end
end
