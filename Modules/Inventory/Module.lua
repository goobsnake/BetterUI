--[[
File: Modules/Inventory/Module.lua
Purpose: Handles settings, font customization, currency configuration, and module initialization.
Author: BetterUI Team
Last Modified: 2026-01-23
]]

-- Shared font choices for Inventory (matches Nameplates for consistency)
BETTERUI.Inventory = BETTERUI.Inventory or {}



-- ============================================================================
-- MODULE SETUP
-- ============================================================================

--- Initializes the Inventory module.
--- 1. Initializes the settings panel (`Init`).
--- 2. Replaces the native `GAMEPAD_INVENTORY` object with `BETTERUI.Inventory.Class`.
--- 3. Swaps the native inventory scene fragment with BetterUI's custom fragment.
--- 4. Configures tooltips and registers custom dialogs (e.g., BoE protection).
function BETTERUI.Inventory.Setup()
	BETTERUI.Inventory.RegisterSettings("Inventory", "Inventory")

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

	-- Configure tooltip appearance and behavior
	ZO_GamepadTooltipTopLevelLeftTooltipContainer.tip.maxFadeGradientSize = BETTERUI_TOOLTIP_MAX_FADE_GRADIENT_SIZE
    
    -- Only apply custom tooltip styles (font scaling) if enhancements are enabled
    -- Only apply custom tooltip styles (font scaling) if enhancements are enabled
    local cimSettings = BETTERUI.Settings.Modules["CIM"]
    if cimSettings and cimSettings.enableTooltipEnhancements then
	    BETTERUI.Inventory.ApplyTooltipStyles()
    end
    
	BETTERUI.Inventory.EnableTooltipMouseWheel()

	-- Position tooltip container
	local TOOLTIP_X_OFFSET = BETTERUI_TOOLTIP_X_OFFSET
	local TOOLTIP_Y_OFFSET = BETTERUI_TOOLTIP_Y_OFFSET
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.fragment.control.container:SetAnchor(3, ZO_GamepadTooltipTopLevelLeftTooltip, 3, TOOLTIP_X_OFFSET, TOOLTIP_Y_OFFSET, 0)

	-- Store reference for other modules (global 'inv' alias)
	inv = GAMEPAD_INVENTORY

	-- Register custom dialog for Bind on Equip protection (if SaveEquip addon is not handling it)
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
