BETTERUI_CRAFTBAG_QUANTITY_DIALOG = "BETTERUI_CRAFTBAG_QUANTITY_DIALOG"

BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED = "BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED"

if not BETTERUI.Inventory.Dialogs then
    BETTERUI.Inventory.Dialogs = {}
end

local MAX_STACK_TRANSFER = 200

local function SetupSliderKeybindHints(dialog)
    if not dialog then return end

    local itemSlider = dialog:GetNamedChild("ItemSlider")
    if not itemSlider then return end

    if not dialog._minIconLabel then
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

    local isStow = dialog.data and dialog.data.isStow
    local leftLabel = isStow
        and GetString(rawget(_G, "SI_BETTERUI_SLIDER_KEEPS"))
        or GetString(rawget(_G, "SI_BETTERUI_SLIDER_STAYS"))
    local rightLabel = isStow
        and GetString(rawget(_G, "SI_BETTERUI_SLIDER_STOW"))
        or GetString(rawget(_G, "SI_BETTERUI_SLIDER_RETRIEVE"))
    dialog._minTextLabel:SetText(leftLabel .. ":")
    dialog._maxTextLabel:SetText(rightLabel .. ":")

    dialog._minIconLabel:SetHidden(false)
    dialog._maxIconLabel:SetHidden(false)
    dialog._minTextLabel:SetHidden(false)
    dialog._maxTextLabel:SetHidden(false)
end

---@return nil
function BETTERUI.Inventory.Dialogs.InitializeCraftBagQuantityDialog()
    if BETTERUI.CIM.Dialogs.IsRegistered(BETTERUI_CRAFTBAG_QUANTITY_DIALOG) then
        return
    end

    BETTERUI.CIM.Dialogs.Register(BETTERUI_CRAFTBAG_QUANTITY_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
        },
        finishedCallback = function()
            local inv = GAMEPAD_INVENTORY
            if inv and inv.SetSelectedInventoryData and inv.scene and inv.scene:IsShowing() then
                local selectedData
                if inv.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(inv.craftBagList)
                elseif inv.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(inv.itemList)
                end
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
                        if BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(data.expectedSlotIdentity, bagId, slotIndex) ~= true then
                            BETTERUI.CIM.UserNotify("CraftBagQuantity:StaleSlot",
                                GetString(rawget(_G, "SI_BETTERUI_ITEM_CHANGED_CANCELLED")))
                            ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_CRAFTBAG_QUANTITY_DIALOG)
                            return
                        end
                        local liveStackCount = GetSlotStackSize(bagId, slotIndex) or 0
                        if liveStackCount <= 0 then
                            ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_CRAFTBAG_QUANTITY_DIALOG)
                            return
                        end
                        quantity = zo_clamp(quantity, 1, math.min(liveStackCount, data.sliderMax or liveStackCount))
                        local inventorySlot = {
                            bagId = bagId,
                            slotIndex = slotIndex,
                        }
                        local moved
                        if isStow then
                            moved = BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_VIRTUAL, quantity)
                        else
                            moved = BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_BACKPACK, quantity)
                        end

                        if not moved then
                            return
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

---@param inventorySlot table|nil Inventory slot control reference
---@param isStow boolean Whether the operation is stowing (true) or retrieving (false)
---@return nil
function BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog(inventorySlot, isStow)
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "Showing craft bag quantity dialog") end
    if not inventorySlot then return end

    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId or not slotIndex then return end

    local stackCount = GetSlotStackSize(bagId, slotIndex) or 1

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
        expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bagId, slotIndex, inventorySlot),
    })
end

---@param inventorySlot table|nil Inventory slot control reference
---@return nil
function BETTERUI.Inventory.Dialogs.TryStowWithQuantity(inventorySlot)
    BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog(inventorySlot, true)
end

---@param inventorySlot table|nil Inventory slot control reference
---@return nil
function BETTERUI.Inventory.Dialogs.TryRetrieveWithQuantity(inventorySlot)
    BETTERUI.Inventory.Dialogs.ShowCraftBagQuantityDialog(inventorySlot, false)
end

---@param inventorySlot table|nil Inventory slot control reference
---@return nil
function BETTERUI.Inventory.Dialogs.StowFullStack(inventorySlot)
    if not inventorySlot then return end
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_VIRTUAL)
end

---@param inventorySlot table|nil Inventory slot control reference
---@return nil
function BETTERUI.Inventory.Dialogs.RetrieveFullStack(inventorySlot)
    if not inventorySlot then return end
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_BACKPACK)
end
