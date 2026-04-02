--[[
File: Modules/Inventory/Module.lua
Purpose: Handles settings, font customization, currency configuration, and module initialization.
Author: BetterUI Team
Last Modified: 2026-02-02
]]

-- Shared font choices for Inventory (matches Nameplates for consistency)
BETTERUI.Inventory = BETTERUI.Inventory or {}



-- ============================================================================
-- MODULE SETUP
-- ============================================================================

--- Initializes the Inventory module.
--- 1. Initializes the settings panel (`Init`).
--- 2. Installs BetterUI inventory object/fragment once (with native backup references).
--- 3. Swaps the native inventory scene fragment with BetterUI's custom fragment.
--- 4. Configures tooltips and registers custom dialogs (e.g., BoE protection).
function BETTERUI.Inventory.Setup()
	BETTERUI.Inventory.RegisterSettings("Inventory", "Inventory")

    BETTERUI.Inventory.NativeGlobals = BETTERUI.Inventory.NativeGlobals or {}
    local native = BETTERUI.Inventory.NativeGlobals
    if native.gamepadInventory == nil then
        native.gamepadInventory = GAMEPAD_INVENTORY
    end
    if native.gamepadInventoryFragment == nil then
        native.gamepadInventoryFragment = GAMEPAD_INVENTORY_FRAGMENT
    end
    if native.gamepadInventoryRootScene == nil then
        native.gamepadInventoryRootScene = GAMEPAD_INVENTORY_ROOT_SCENE
    end

	-- Replace the native GAMEPAD_INVENTORY global with our custom class once.
    if not GAMEPAD_INVENTORY or GAMEPAD_INVENTORY.class ~= BETTERUI.Inventory.Class then
	    GAMEPAD_INVENTORY = BETTERUI.Inventory.Class:New(BETTERUI_GamepadInventoryTopLevel)
    end

	-- Create the replacement scene fragment using our custom top level control
    if not GAMEPAD_INVENTORY_FRAGMENT or GAMEPAD_INVENTORY_FRAGMENT.control ~= BETTERUI_GamepadInventoryTopLevel then
	    GAMEPAD_INVENTORY_FRAGMENT = ZO_SimpleSceneFragment:New(BETTERUI_GamepadInventoryTopLevel)
    end
	GAMEPAD_INVENTORY_FRAGMENT:SetHideOnSceneHidden(true)

	-- Update the Inventory Scene with the new fragment
	-- Note: GAMEPAD_INVENTORY_ROOT_SCENE is the native scene, we are swapping the content fragment.
    if native.gamepadInventoryFragment
        and native.gamepadInventoryFragment ~= GAMEPAD_INVENTORY_FRAGMENT
        and GAMEPAD_INVENTORY_ROOT_SCENE
        and GAMEPAD_INVENTORY_ROOT_SCENE.RemoveFragment
    then
        GAMEPAD_INVENTORY_ROOT_SCENE:RemoveFragment(native.gamepadInventoryFragment)
    end
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

	-- Hook ZO_StackSplit_SplitItem to prevent duplicate dialogs using a lock flag.
    -- Uses ZO_PreHook instead of replacing the global function.
    if not BETTERUI.Inventory._splitStackHookInstalled and type(ZO_PreHook) == "function" then
        ZO_PreHook("ZO_StackSplit_SplitItem", function(inventorySlotControl)
            if BETTERUI.Inventory._splitStackLock then
                return true
            end

            BETTERUI.Inventory._splitStackLock = true

            local function ReleaseSplitLockIfNoDialog()
                if ZO_Dialogs_IsShowing and not ZO_Dialogs_IsShowing(ZO_GAMEPAD_SPLIT_STACK_DIALOG) then
                    BETTERUI.Inventory._splitStackLock = nil
                    if GAMEPAD_INVENTORY then
                        if GAMEPAD_INVENTORY.RefreshItemActions then
                            GAMEPAD_INVENTORY:RefreshItemActions()
                        end
                        if GAMEPAD_INVENTORY.RefreshKeybinds then
                            GAMEPAD_INVENTORY:RefreshKeybinds()
                        end
                    end
                end
            end

            if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Schedule then
                BETTERUI.Inventory.Tasks:Schedule("splitStackLockFallbackRelease", 250, ReleaseSplitLockIfNoDialog)
            else
                zo_callLater(ReleaseSplitLockIfNoDialog, 250)
            end

            return false
        end)
        BETTERUI.Inventory._splitStackHookInstalled = true
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
end
