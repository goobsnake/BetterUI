--[[
    BetterUI Inventory Module - Configuration & Initialization
    Description: Handles settings, font customization, currency configuration, and module initialization.
    Key Responsibilities:
    - Defines default settings for Fonts (Name/Column) and Currencies.
    - Creates the LibAddonMenu settings panel.
    - Replaces the native GAMEPAD_INVENTORY with BetterUI's custom implementation.
    - Configures Tooltip styles and Mouse Wheel scrolling support.

    TODO(architecture): This file is 1190 lines - split settings into InventorySettings.lua

]]

-- Shared font choices for Inventory (matches Nameplates for consistency)
BETTERUI.Inventory = BETTERUI.Inventory or {}


-- ============================================================================
-- TOOLTIP CONFIGURATION
-- ============================================================================

--- Configures the visual style of tooltips.
--- Applies font sizes (title, body, values) based on user settings.
--- Adjusts layout direction and spacing for the gamepad tooltip interface.
local function SetupTooltipStyles()
    local tooltipSize = BETTERUI.Settings.Modules["CIM"].tooltipSize or 24
    

    
    -- Calculate derived sizes from base font size
    local baseFontSize = tooltipSize
    local titleFontSize = baseFontSize + 6   -- Title is 6px larger
    local valueFontSize = baseFontSize + 4   -- Value is 4px larger
    
    -- Apply tooltip styles with size adjustments
    ZO_TOOLTIP_STYLES["topSection"] = {
        layoutPrimaryDirection = "up",
        layoutSecondaryDirection = "right",
        widthPercent = 100,
        childSpacing = 1,
        fontSize = baseFontSize,
        height = 64,
        uppercase = true,
        fontColorField = GENERAL_COLOR_OFF_WHITE,
    }
    ZO_TOOLTIP_STYLES["flavorText"] = {
        fontSize = baseFontSize,
    }
    ZO_TOOLTIP_STYLES["statValuePairStat"] = {
        fontSize = baseFontSize,
        uppercase = true,
        fontColorField = GENERAL_COLOR_OFF_WHITE,
    }
    ZO_TOOLTIP_STYLES["statValuePairValue"] = {
        fontSize = valueFontSize,
        fontColorField = GENERAL_COLOR_WHITE,
    }
    ZO_TOOLTIP_STYLES["title"] = {
        fontSize = titleFontSize,
        customSpacing = 8,
        widthPercent = 100,
        uppercase = true,
        fontColorField = GENERAL_COLOR_WHITE,
    }
    ZO_TOOLTIP_STYLES["bodyDescription"] = {
        fontSize = baseFontSize,
    }
end

--- Enables and configures mouse wheel scrolling for the left-side tooltip container.
--- Allows users to scroll long item descriptions using the mouse wheel.
local function SetupTooltipMouseWheel()
	local tip = ZO_GamepadTooltipTopLevelLeftTooltipContainerTip
	local tipScroll = ZO_GamepadTooltipTopLevelLeftTooltipContainerTipScroll
	if tip and tipScroll then
		tip:SetMouseEnabled(true)
		tipScroll:SetMouseEnabled(true)
		tip:SetHandler("OnMouseWheel", function(self, delta)
			local speed = (BETTERUI.Settings.Modules["CIM"].rhScrollSpeed) or 20
			local newScrollValue
			if delta > 0 then
				newScrollValue = (self.scrollValue or 0) - speed
			else
				newScrollValue = (self.scrollValue or 0) + speed
			end
			self.scrollValue = newScrollValue
			if self.scroll and self.scroll.SetVerticalScroll then
				self.scroll:SetVerticalScroll(newScrollValue)
			end
		end)
	end
end


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
    local cimSettings = BETTERUI.Settings.Modules["CIM"]
    if cimSettings and cimSettings.enableTooltipEnhancements then
	    SetupTooltipStyles()
    end
    
	SetupTooltipMouseWheel()

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
