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
Description: Registers the quantity selection dialog for Craft Bag operations.
Rationale: Uses GAMEPAD_DIALOGS.ITEM_SLIDER for consistent UX with Banking module.
]]
function BETTERUI.Inventory.Dialogs.InitializeCraftBagQuantityDialog()
    -- Only register once
    if ESO_Dialogs[BETTERUI_CRAFTBAG_QUANTITY_DIALOG] then
        return
    end

    ESO_Dialogs[BETTERUI_CRAFTBAG_QUANTITY_DIALOG] = {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
        },
        title = {
            text = function(dialog)
                if dialog.data and dialog.data.isStow then
                    return GetString(SI_BETTERUI_STOW_QUANTITY)
                else
                    return GetString(SI_BETTERUI_RETRIEVE_QUANTITY)
                end
            end,
        },
        mainText = {
            text = function(dialog)
                if dialog.data and dialog.data.isStow then
                    return GetString(SI_BETTERUI_STOW_PROMPT)
                else
                    return GetString(SI_BETTERUI_RETRIEVE_PROMPT)
                end
            end,
        },
        setup = function(dialog, data)
            dialog:setupFunc()
        end,
        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
            },
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
                        -- Perform the transfer with selected quantity
                        if isStow then
                            -- Stow: Inventory -> Craft Bag
                            CallSecureProtected("PickupInventoryItem", bagId, slotIndex, quantity)
                            CallSecureProtected("PlaceInInventory", BAG_VIRTUAL, 0)
                        else
                            -- Retrieve: Craft Bag -> Inventory
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

                        -- Fire completion event
                        CALLBACK_MANAGER:FireCallbacks(BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED)
                    end
                end,
            },
        },
    }
end

--[[
Function: BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog
Description: Displays the quantity selection dialog for stow/retrieve operations.
param: inventorySlot (table) - The inventory slot data containing bagId and slotIndex.
param: isStow (boolean) - True if stowing to Craft Bag, false if retrieving.
]]
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
function BETTERUI.Inventory.Dialogs.TryStowWithQuantity(inventorySlot)
    BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog(inventorySlot, true)
end

--[[
Function: BETTERUI.Inventory.Dialogs.TryRetrieveWithQuantity
Description: Attempts to retrieve an item from the Craft Bag, prompting for quantity if stacked.
param: inventorySlot (table) - The inventory slot data.
]]
function BETTERUI.Inventory.Dialogs.TryRetrieveWithQuantity(inventorySlot)
    BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog(inventorySlot, false)
end

--[[
Function: BETTERUI.Inventory.Dialogs.StowFullStack
Description: Immediately stows the full stack to the Craft Bag without prompting.
param: inventorySlot (table) - The inventory slot data.
]]
function BETTERUI.Inventory.Dialogs.StowFullStack(inventorySlot)
    if not inventorySlot then return end
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_VIRTUAL)
end

--[[
Function: BETTERUI.Inventory.Dialogs.RetrieveFullStack
Description: Immediately retrieves the full stack from the Craft Bag without prompting.
param: inventorySlot (table) - The inventory slot data.
]]
function BETTERUI.Inventory.Dialogs.RetrieveFullStack(inventorySlot)
    if not inventorySlot then return end
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_BACKPACK)
end
