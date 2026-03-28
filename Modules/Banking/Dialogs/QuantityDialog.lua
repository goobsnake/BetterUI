--[[
File: Modules/Banking/Dialogs/QuantityDialog.lua
Purpose: Implements a proper modal dialog for partial stack withdraw/deposit operations.
         Uses ESO's GAMEPAD_DIALOGS.ITEM_SLIDER pattern (same as gamepad split stack).
         Replaces the legacy inline spinner overlay on the item list.
]]

--[[
Dialog: BETTERUI_BANK_QUANTITY_DIALOG
Description: Modal quantity selection dialog for banking partial stack moves.
           This provides a consistent, polished UX compared to inline spinners.
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
  - dialog.data contains: bagId, slotIndex, sliderMin, sliderMax, sliderStartValue, isDeposit, itemLink
  - OnSliderValueChanged updates the split preview labels
  - Primary button callback calls MoveItem with selected quantity
]]
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
    local isDeposit = dialog.data and dialog.data.isDeposit
    local leftLabel = isDeposit
        and GetString(rawget(_G, "SI_BETTERUI_SLIDER_KEEPS"))
        or GetString(rawget(_G, "SI_BETTERUI_SLIDER_STAYS"))
    local rightLabel = isDeposit
        and GetString(rawget(_G, "SI_BETTERUI_SLIDER_DEPOSIT"))
        or GetString(rawget(_G, "SI_BETTERUI_SLIDER_WITHDRAW"))
    dialog._minTextLabel:SetText(leftLabel .. ":")
    dialog._maxTextLabel:SetText(rightLabel .. ":")

    -- Ensure controls are visible (split stack dialog hides them on the shared template)
    dialog._minIconLabel:SetHidden(false)
    dialog._maxIconLabel:SetHidden(false)
    dialog._minTextLabel:SetHidden(false)
    dialog._maxTextLabel:SetHidden(false)
end

--- Registers the quantity selection dialog for banking operations.
function BETTERUI.Banking.InitializeQuantityDialog()
    BETTERUI.CIM.Dialogs.Register(BETTERUI_BANK_QUANTITY_DIALOG, {
        blockDirectionalInput = true,
        blockDialogReleaseOnPress = true,
        canQueue = true,

        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
        },

        setup = function(dialog, data)
            if dialog.setupFunc then
                dialog:setupFunc()
            end
            SetupSliderKeybindHints(dialog)
        end,

        title = {
            text = function(dialog)
                if dialog and dialog.data and dialog.data.isDeposit then
                    return GetString(rawget(_G, "SI_BETTERUI_BANK_DEPOSIT_QUANTITY")) or "Deposit How Many?"
                else
                    return GetString(rawget(_G, "SI_BETTERUI_BANK_WITHDRAW_QUANTITY")) or "Withdraw How Many?"
                end
            end,
        },

        mainText = {
            text = function(dialog)
                if dialog and dialog.data and dialog.data.isDeposit then
                    return GetString(rawget(_G, "SI_BETTERUI_BANK_DEPOSIT_PROMPT")) or "Select the amount to deposit"
                else
                    return GetString(rawget(_G, "SI_BETTERUI_BANK_WITHDRAW_PROMPT")) or "Select the amount to withdraw"
                end
            end,
        },

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

        narrationText = function(dialog, itemName)
            if not dialog or not dialog.slider then return nil end
            local stack2 = dialog.slider:GetValue()
            local stack1 = (dialog.data.sliderMax or 0) - stack2
            return SCREEN_NARRATION_MANAGER:CreateNarratableObject(
                zo_strformat(SI_GAMEPAD_INVENTORY_SPLIT_STACK_NARRATION_FORMATTER, itemName, stack1, stack2)
            )
        end,

        additionalInputNarrationFunction = function()
            return ZO_GetHorizontalDirectionalInputNarrationData(
                GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_SPLIT_STACK_LEFT_NARRATION")),
                GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_SPLIT_STACK_RIGHT_NARRATION"))
            )
        end,

        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
                callback = function(dialog)
                    if not dialog or not dialog.data then return end

                    local quantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)

                    if BETTERUI.Banking.Window and BETTERUI.Banking.Window.MoveItem then
                        BETTERUI.Banking.Window:MoveItem(BETTERUI.Banking.Window.list, quantity)
                    end

                    ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_BANK_QUANTITY_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_DIALOG_CANCEL")),
                callback = function(dialog)
                    ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_BANK_QUANTITY_DIALOG)
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

    -- Suppress list updates while the dialog is open so that OnInventoryUpdated
    -- (fired by the server after the move) does not call RefreshList / list:Deactivate()
    -- while the dialog is still on screen. The deferred refresh below handles the update
    -- once the dialog fully closes.
    self._suppressListUpdates = true

    -- ESO's ITEM_SLIDER dialog expects: sliderMin, sliderMax, sliderStartValue, bagId, slotIndex
    ZO_Dialogs_ShowGamepadDialog(BETTERUI_BANK_QUANTITY_DIALOG, {
        bagId = targetData.bagId,
        slotIndex = targetData.slotIndex,
        sliderMin = 1,
        sliderMax = stackCount,
        sliderStartValue = stackCount, -- Default to full stack for convenience
        isDeposit = isDeposit,
        itemLink = itemLink,
        itemName = GetItemName(targetData.bagId, targetData.slotIndex),
    })
end
