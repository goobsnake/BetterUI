--[[
File: Modules/Banking/Dialogs/QuantityDialog.lua
Purpose: Implements a proper modal dialog for partial stack withdraw/deposit operations.
         Uses ESO's GAMEPAD_DIALOGS.ITEM_SLIDER pattern (same as gamepad split stack).
         Replaces the legacy inline spinner overlay on the item list.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

--[[
Dialog: BETTERUI_BANK_QUANTITY_DIALOG
Description: Modal quantity selection dialog for banking partial stack moves.
Rationale: ESO uses GAMEPAD_DIALOGS.ITEM_SLIDER for all quantity selection (see esoui/ingame/inventory/gamepad/gamepadinventory.lua:546-605).
           This provides a consistent, polished UX compared to inline spinners.
Mechanism:
  - Registered via ZO_Dialogs_RegisterCustomDialog
  - Uses standard ITEM_SLIDER dialog type with min=1, max=stackCount
  - Callback invokes BETTERUI.Banking.Window:MoveItem(list, quantity)
  - Fires BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED on completion
References: Called by Banking keybinds when partial stack move is requested.
]]

BETTERUI_BANK_QUANTITY_DIALOG = "BETTERUI_BANK_QUANTITY_DIALOG"

--[[
Function: BETTERUI.Banking.InitializeQuantityDialog
Description: Registers the quantity selection dialog for banking operations.
Rationale: Creates a reusable dialog for both withdraw and deposit partial stacks.
Mechanism:
  - dialog.data contains: bagId, slotIndex, stackSize, isDeposit, itemLink
  - OnSliderValueChanged updates the split preview labels
  - Primary button callback calls MoveItem with selected quantity
]]
function BETTERUI.Banking.InitializeQuantityDialog()
    ZO_Dialogs_RegisterCustomDialog(BETTERUI_BANK_QUANTITY_DIALOG, {
        blockDirectionalInput = true,
        canQueue = true,

        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
        },

        setup = function(dialog, data)
            dialog:setupFunc()
        end,

        title = {
            text = function(dialog)
                if dialog and dialog.data and dialog.data.isDeposit then
                    return GetString(SI_BETTERUI_BANK_DEPOSIT_QUANTITY) or "Deposit How Many?"
                else
                    return GetString(SI_BETTERUI_BANK_WITHDRAW_QUANTITY) or "Withdraw How Many?"
                end
            end,
        },

        mainText = {
            text = SI_GAMEPAD_INVENTORY_SPLIT_STACK_PROMPT,
        },

        OnSliderValueChanged = function(dialog, sliderControl, value)
            if dialog and dialog.data then
                local remaining = dialog.data.stackSize - value
                if dialog.sliderValue1 then
                    dialog.sliderValue1:SetText(tostring(remaining))
                end
                if dialog.sliderValue2 then
                    dialog.sliderValue2:SetText(tostring(value))
                end
            end
        end,

        narrationText = function(dialog, itemName)
            if not dialog or not dialog.slider then return nil end
            local stack2 = dialog.slider:GetValue()
            local stack1 = dialog.data.stackSize - stack2
            return SCREEN_NARRATION_MANAGER:CreateNarratableObject(
                zo_strformat(SI_GAMEPAD_INVENTORY_SPLIT_STACK_NARRATION_FORMATTER, itemName, stack1, stack2)
            )
        end,

        additionalInputNarrationFunction = function()
            return ZO_GetHorizontalDirectionalInputNarrationData(
                GetString(SI_GAMEPAD_INVENTORY_SPLIT_STACK_LEFT_NARRATION),
                GetString(SI_GAMEPAD_INVENTORY_SPLIT_STACK_RIGHT_NARRATION)
            )
        end,

        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    if not dialog or not dialog.data then return end

                    local data = dialog.data
                    local quantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)

                    -- Perform the move operation
                    if BETTERUI.Banking.Window and BETTERUI.Banking.Window.MoveItem then
                        BETTERUI.Banking.Window:MoveItem(BETTERUI.Banking.Window.list, quantity)
                    end

                    -- Fire completion callback for list refresh
                    CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED")
                end,
            },
        },
    })
end

--[[
Function: BETTERUI.Banking.Class:ShowQuantityDialog
Description: Shows the quantity selection dialog for partial stack moves.
Rationale: Called when user wants to move a partial stack instead of the full stack.
Mechanism:
  - Gets selected item data from list
  - Validates stackCount > 1 (otherwise just move the single item)
  - Configures dialog with item info and calls ZO_Dialogs_ShowGamepadDialog
param: isDeposit (boolean) - True if depositing to bank, false if withdrawing.
]]
function BETTERUI.Banking.Class:ShowQuantityDialog(isDeposit)
    local list = self:GetList()
    if not list or not list.selectedData then return end

    local targetData = list.selectedData
    if not targetData.bagId or not targetData.slotIndex then return end

    local stackCount = targetData.stackCount or GetSlotStackSize(targetData.bagId, targetData.slotIndex) or 1

    -- If only 1 item, just move it directly without dialog
    if stackCount <= 1 then
        self:MoveItem(list, 1)
        return
    end

    local itemLink = GetItemLink(targetData.bagId, targetData.slotIndex)

    ZO_Dialogs_ShowGamepadDialog(BETTERUI_BANK_QUANTITY_DIALOG, {
        bagId = targetData.bagId,
        slotIndex = targetData.slotIndex,
        stackSize = stackCount,
        isDeposit = isDeposit,
        itemLink = itemLink,
        itemName = GetItemName(targetData.bagId, targetData.slotIndex),
    })
end
