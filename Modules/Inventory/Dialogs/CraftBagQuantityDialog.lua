--[[
File: Modules/Inventory/Dialogs/CraftBagQuantityDialog.lua
Purpose: Manages the quantity dialog for Craft Bag stow/retrieve operations.
         Displays a slider allowing users to select how many items to stow or retrieve.
Author: BetterUI Team
Last Modified: 2026-02-06
]]

-- Dialog name constant
BETTERUI_CRAFTBAG_QUANTITY_DIALOG = "BETTERUI_CRAFTBAG_QUANTITY_DIALOG"

-- Event fired when the dialog completes
BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED = "BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED"

-- Initialize the namespace
if not BETTERUI.Inventory.Dialogs then
    BETTERUI.Inventory.Dialogs = {}
end

-- Maximum items that can be transferred in a single operation (ESO game limit)
local MAX_STACK_TRANSFER = 200

--[[
Function: BETTERUI.Inventory.Dialogs.InitializeCraftBagQuantityDialog
Registers the quantity selection dialog for Craft Bag operations.
]]
--- @param dialog table
local function SetupSliderKeybindHints(dialog)
    if not dialog then return end

    local itemSlider = dialog:GetNamedChild("ItemSlider")
    if not itemSlider then return end

    if not dialog._minIconLabel then
        -- Button icons above the item icons
        local minIcon = WINDOW_MANAGER:CreateControl(nil, itemSlider, CT_LABEL)
        minIcon:SetFont("ZoFontGamepad27")
        minIcon:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        minIcon:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        minIcon:SetAnchor(BOTTOM, dialog.icon1, TOP, 0, -11)
        dialog._minIconLabel = minIcon

        local maxIcon = WINDOW_MANAGER:CreateControl(nil, itemSlider, CT_LABEL)
        maxIcon:SetFont("ZoFontGamepad27")
        maxIcon:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        maxIcon:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        maxIcon:SetAnchor(BOTTOM, dialog.icon2, TOP, 0, -11)
        dialog._maxIconLabel = maxIcon

        -- Auto-size number values and center under icons
        if dialog.sliderValue1 then
            dialog.sliderValue1:ClearAnchors()
            dialog.sliderValue1:SetWidth(0)
            dialog.sliderValue1:SetAnchor(TOP, dialog.icon1, BOTTOM, 0, 4)
            dialog.sliderValue1:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        end
        if dialog.sliderValue2 then
            dialog.sliderValue2:ClearAnchors()
            dialog.sliderValue2:SetWidth(0)
            dialog.sliderValue2:SetAnchor(TOP, dialog.icon2, BOTTOM, 0, 4)
            dialog.sliderValue2:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        end

        -- Contextual label text to the left of the numbers
        local minText = WINDOW_MANAGER:CreateControl(nil, itemSlider, CT_LABEL)
        minText:SetFont("ZoFontGamepad34")
        minText:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        minText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        minText:SetAnchor(RIGHT, dialog.sliderValue1, LEFT, -4, 0)
        dialog._minTextLabel = minText

        local maxText = WINDOW_MANAGER:CreateControl(nil, itemSlider, CT_LABEL)
        maxText:SetFont("ZoFontGamepad34")
        maxText:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        maxText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        maxText:SetAnchor(RIGHT, dialog.sliderValue2, LEFT, -4, 0)
        dialog._maxTextLabel = maxText
    end

    local xIcon = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
        "DIALOG_SECONDARY", KEYBIND_TEXT_OPTIONS_ABBREVIATED_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, true)
    local yIcon = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
        "DIALOG_TERTIARY", KEYBIND_TEXT_OPTIONS_ABBREVIATED_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, true)

    dialog._minIconLabel:SetText(xIcon or "")
    dialog._maxIconLabel:SetText(yIcon or "")

    -- Contextual labels based on action type
    local isStow = dialog.data and dialog.data.isStow
    local leftLabel = isStow
        and GetString(rawget(_G, "SI_BETTERUI_SLIDER_KEEPS"))
        or GetString(rawget(_G, "SI_BETTERUI_SLIDER_STAYS"))
    local rightLabel = isStow
        and GetString(rawget(_G, "SI_BETTERUI_SLIDER_STOW"))
        or GetString(rawget(_G, "SI_BETTERUI_SLIDER_RETRIEVE"))
    dialog._minTextLabel:SetText(leftLabel .. ":")
    dialog._maxTextLabel:SetText(rightLabel .. ":")

    -- Ensure controls are visible (split stack dialog hides them on the shared template)
    dialog._minIconLabel:SetHidden(false)
    dialog._maxIconLabel:SetHidden(false)
    dialog._minTextLabel:SetHidden(false)
    dialog._maxTextLabel:SetHidden(false)
end

--- Registers the quantity selection dialog for Craft Bag operations.
function BETTERUI.Inventory.Dialogs.InitializeCraftBagQuantityDialog()
    -- Only register once (CIM registry handles duplicate check)
    if BETTERUI.CIM.Dialogs.IsRegistered(BETTERUI_CRAFTBAG_QUANTITY_DIALOG) then
        return
    end

    BETTERUI.CIM.Dialogs.Register(BETTERUI_CRAFTBAG_QUANTITY_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
        },
        -- Restore keybind strip after dialog closes (both confirm and cancel).
        -- The A button callback clears itemActions.actionName before opening this dialog
        -- (FLICKER FIX in InventoryKeybinds.lua). Without re-populating it after close,
        -- the A button shows with no text because actionName stays nil.
        finishedCallback = function()
            local inv = GAMEPAD_INVENTORY
            if inv and inv.SetSelectedInventoryData and inv.scene and inv.scene:IsShowing() then
                -- Determine the currently selected item data based on action mode
                local selectedData
                if inv.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(inv.craftBagList)
                elseif inv.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(inv.itemList)
                end
                -- Re-trigger PrimaryCommandActivate to restore actionName
                inv:SetSelectedInventoryData(selectedData)
            end
        end,
        title = {
            text = function(dialog)
                if dialog.data and dialog.data.isStow then
                    return GetString(rawget(_G, "SI_BETTERUI_STOW_QUANTITY"))
                else
                    return GetString(rawget(_G, "SI_BETTERUI_RETRIEVE_QUANTITY"))
                end
            end,
        },
        mainText = {
            text = function(dialog)
                if dialog.data and dialog.data.isStow then
                    return GetString(rawget(_G, "SI_BETTERUI_STOW_PROMPT"))
                else
                    return GetString(rawget(_G, "SI_BETTERUI_RETRIEVE_PROMPT"))
                end
            end,
        },
        setup = function(dialog, data)
            dialog:setupFunc()
            SetupSliderKeybindHints(dialog)
        end,
        OnSliderValueChanged = function(dialog, sliderControl, value)
            if dialog and dialog.data and value then
                local sliderMax = dialog.data.sliderMax or 0
                local remaining = sliderMax - value
                if dialog.sliderValue1 then
                    dialog.sliderValue1:SetText(tostring(remaining))
                end
                if dialog.sliderValue2 then
                    dialog.sliderValue2:SetText(tostring(value))
                end
            end
        end,
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    if not dialog or not dialog.data then return end

                    local data = dialog.data
                    local quantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)

                    if not quantity or quantity <= 0 then return end

                    local bagId = data.bagId
                    local slotIndex = data.slotIndex
                    local isStow = data.isStow

                    if bagId and slotIndex then
                        if isStow then
                            CallSecureProtected("PickupInventoryItem", bagId, slotIndex, quantity)
                            CallSecureProtected("PlaceInInventory", BAG_VIRTUAL, 0)
                        else
                            if DoesBagHaveSpaceFor(BAG_BACKPACK, bagId, slotIndex) then
                                local destinationSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex,
                                    BAG_BACKPACK)
                                if destinationSlot == nil then
                                    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
                                        SI_INVENTORY_ERROR_INVENTORY_FULL)
                                    return
                                end
                                CallSecureProtected("PickupInventoryItem", bagId, slotIndex, quantity)
                                CallSecureProtected("PlaceInInventory", BAG_BACKPACK, destinationSlot)
                            else
                                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
                                    SI_INVENTORY_ERROR_INVENTORY_FULL)
                            end
                        end

                        CALLBACK_MANAGER:FireCallbacks(BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED)
                    end

                    ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_CRAFTBAG_QUANTITY_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function(dialog)
                    ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_CRAFTBAG_QUANTITY_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = GetString(rawget(_G, "SI_BETTERUI_BANK_SLIDER_MIN")),
                callback = function(dialog)
                    if dialog and dialog.slider then
                        dialog.slider:SetValue(dialog.data.sliderMin or 1)
                    end
                end,
            },
            {
                keybind = "DIALOG_TERTIARY",
                text = GetString(rawget(_G, "SI_BETTERUI_BANK_SLIDER_MAX")),
                callback = function(dialog)
                    if dialog and dialog.slider then
                        dialog.slider:SetValue(dialog.data.sliderMax or 1)
                    end
                end,
            },
        },
    })
end

--[[
Function: BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog
Description: Displays the quantity selection dialog for stow/retrieve operations.
param: inventorySlot (table) - The inventory slot data containing bagId and slotIndex.
param: isStow (boolean) - True if stowing to Craft Bag, false if retrieving.
]]
--- Displays the quantity selection dialog for stow/retrieve operations.
--- @param inventorySlot table The inventory slot data
--- @param isStow boolean True if stowing to Craft Bag, false if retrieving
function BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog(inventorySlot, isStow)
    if not inventorySlot then return end

    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId or not slotIndex then return end

    local stackCount = GetSlotStackSize(bagId, slotIndex) or 1

    -- If only 1 item, just move it directly without dialog
    if stackCount <= 1 then
        if isStow then
            BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_VIRTUAL)
        else
            BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_BACKPACK)
        end
        return
    end

    local itemLink = GetItemLink(bagId, slotIndex)
    local itemName = GetItemName(bagId, slotIndex)

    ZO_Dialogs_ShowGamepadDialog(BETTERUI_CRAFTBAG_QUANTITY_DIALOG, {
        bagId = bagId,
        slotIndex = slotIndex,
        sliderMin = 1,
        sliderMax = math.min(stackCount, MAX_STACK_TRANSFER),
        sliderStartValue = 1,
        isStow = isStow,
        itemLink = itemLink,
        itemName = itemName,
    })
end

--[[
Function: BETTERUI.Inventory.Dialogs.TryStowWithQuantity
Description: Attempts to stow an item to the Craft Bag, prompting for quantity if stacked.
param: inventorySlot (table) - The inventory slot data.
]]
--- Attempts to stow an item to the Craft Bag, prompting for quantity if stacked.
--- @param inventorySlot table The inventory slot data
function BETTERUI.Inventory.Dialogs.TryStowWithQuantity(inventorySlot)
    BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog(inventorySlot, true)
end

--[[
Function: BETTERUI.Inventory.Dialogs.TryRetrieveWithQuantity
Description: Attempts to retrieve an item from the Craft Bag, prompting for quantity if stacked.
param: inventorySlot (table) - The inventory slot data.
]]
--- Attempts to retrieve an item from the Craft Bag, prompting for quantity if stacked.
--- @param inventorySlot table The inventory slot data
function BETTERUI.Inventory.Dialogs.TryRetrieveWithQuantity(inventorySlot)
    BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog(inventorySlot, false)
end

--[[
Function: BETTERUI.Inventory.Dialogs.StowFullStack
Description: Immediately stows the full stack to the Craft Bag without prompting.
param: inventorySlot (table) - The inventory slot data.
]]
--- Immediately stows the full stack to the Craft Bag without prompting.
--- @param inventorySlot table The inventory slot data
function BETTERUI.Inventory.Dialogs.StowFullStack(inventorySlot)
    if not inventorySlot then return end
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_VIRTUAL)
end

--[[
Function: BETTERUI.Inventory.Dialogs.RetrieveFullStack
Description: Immediately retrieves the full stack from the Craft Bag without prompting.
param: inventorySlot (table) - The inventory slot data.
]]
--- Immediately retrieves the full stack from the Craft Bag without prompting.
--- @param inventorySlot table The inventory slot data
function BETTERUI.Inventory.Dialogs.RetrieveFullStack(inventorySlot)
    if not inventorySlot then return end
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_BACKPACK)
end
