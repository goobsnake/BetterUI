BETTERUI_CRAFTBAG_QUANTITY_DIALOG = "BETTERUI_CRAFTBAG_QUANTITY_DIALOG"

BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED = "BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED"

if not BETTERUI.Inventory.Dialogs then
    BETTERUI.Inventory.Dialogs = {}
end

local MAX_STACK_TRANSFER = 200

local function IsCraftBagQuantityTraceActive()
    local L = BETTERUI.Log
    return L and L.TraceEvent and (not L.IsActive or L.IsActive())
end

local function TraceCraftBagQuantity(phase, data)
    local L = BETTERUI.Log
    if not IsCraftBagQuantityTraceActive() then return end
    data = data or {}
    data.module = "Inventory"
    data.feature = "craftBagQuantityDialog"
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.ACTION or "ACTION", "craftbag.quantity_dialog", phase, data)
end

local function ShouldTraceSliderPreview(dialog, value)
    if not (dialog and dialog.data and value) then return false end
    local sliderMin = dialog.data.sliderMin or 1
    local sliderMax = dialog.data.sliderMax or sliderMin
    local span = math.max(sliderMax - sliderMin, 1)
    local bucketSize = math.max(1, math.floor(span / 10))
    local bucket = math.floor((value - sliderMin) / bucketSize)
    local key = table.concat({ tostring(bucket), tostring(value == sliderMin), tostring(value == sliderMax) }, ":")
    if dialog._betteruiLastSliderTraceKey == key then
        return false
    end
    dialog._betteruiLastSliderTraceKey = key
    dialog._betteruiLastSliderTraceBucket = bucket
    return true
end

local function TraceSlotPayload(bagId, slotIndex, data)
    data = data or {}
    data.bagId = bagId
    data.slotIndex = slotIndex
    if bagId and slotIndex and IsCraftBagQuantityTraceActive() and type(GetItemLink) == "function" then
        local ok, link = pcall(GetItemLink, bagId, slotIndex, LINK_STYLE_BRACKETS)
        if ok and link ~= "" then data.itemLink = link end
    end
    return data
end

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
            if dialog then
                dialog._betteruiLastSliderTraceKey = nil
                dialog._betteruiLastSliderTraceBucket = nil
            end
            if dialog and dialog.setupFunc then
                dialog:setupFunc()
            end
            SetupSliderKeybindHints(dialog)
            data = data or dialog and dialog.data or {}
            TraceCraftBagQuantity("setup", TraceSlotPayload(data.bagId, data.slotIndex, {
                isStow = data.isStow,
                sliderMin = data.sliderMin,
                sliderMax = data.sliderMax,
                sliderStartValue = data.sliderStartValue,
                itemName = data.itemName,
            }))
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
                if ShouldTraceSliderPreview(dialog, value) then
                    TraceCraftBagQuantity("slider_changed", TraceSlotPayload(dialog.data.bagId, dialog.data.slotIndex, {
                        isStow = dialog.data.isStow,
                        value = value,
                        remaining = remaining,
                        sliderMin = dialog.data.sliderMin or 1,
                        sliderMax = sliderMax,
                        traceBucket = dialog._betteruiLastSliderTraceBucket,
                        coalesced = true,
                    }))
                end
            end
        end,
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    if not dialog or not dialog.data then
                        TraceCraftBagQuantity("confirm_blocked", { reason = "missingDialogData" })
                        return
                    end

                    local data = dialog.data
                    local quantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)

                    if not quantity or quantity <= 0 then
                        TraceCraftBagQuantity("confirm_blocked", TraceSlotPayload(data.bagId, data.slotIndex, {
                            reason = "invalidQuantity",
                            quantity = quantity,
                            isStow = data.isStow,
                        }))
                        return
                    end

                    local bagId = data.bagId
                    local slotIndex = data.slotIndex
                    local isStow = data.isStow

                    if bagId and slotIndex then
                        if BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(data.expectedSlotIdentity, bagId, slotIndex) ~= true then
                            TraceCraftBagQuantity("confirm_blocked", TraceSlotPayload(bagId, slotIndex, {
                                reason = "staleSlot",
                                quantity = quantity,
                                isStow = isStow,
                            }))
                            BETTERUI.CIM.UserNotify("CraftBagQuantity:StaleSlot",
                                GetString(rawget(_G, "SI_BETTERUI_ITEM_CHANGED_CANCELLED")))
                            ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_CRAFTBAG_QUANTITY_DIALOG)
                            return
                        end
                        local liveStackCount = GetSlotStackSize(bagId, slotIndex) or 0
                        if liveStackCount <= 0 then
                            TraceCraftBagQuantity("confirm_blocked", TraceSlotPayload(bagId, slotIndex, {
                                reason = "emptyLiveStack",
                                quantity = quantity,
                                isStow = isStow,
                                liveStackCount = liveStackCount,
                            }))
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

                        TraceCraftBagQuantity("move_result", TraceSlotPayload(bagId, slotIndex, {
                            quantity = quantity,
                            requestedQuantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog),
                            isStow = isStow,
                            destinationBag = isStow and BAG_VIRTUAL or BAG_BACKPACK,
                            moved = moved == true,
                        }))
                        if not moved then
                            return
                        end

                        CALLBACK_MANAGER:FireCallbacks(BETTERUI_EVENT_CRAFTBAG_QUANTITY_DIALOG_FINISHED)
                        TraceCraftBagQuantity("finished", TraceSlotPayload(bagId, slotIndex, {
                            quantity = quantity,
                            isStow = isStow,
                        }))
                    end

                    ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_CRAFTBAG_QUANTITY_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function(dialog)
                    local data = dialog and dialog.data or {}
                    TraceCraftBagQuantity("cancel", TraceSlotPayload(data.bagId, data.slotIndex, {
                        isStow = data.isStow,
                    }))
                    ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_CRAFTBAG_QUANTITY_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = GetString(rawget(_G, "SI_BETTERUI_BANK_SLIDER_MIN")),
                callback = function(dialog)
                    if dialog and dialog.slider then
                        local data = dialog.data or {}
                        TraceCraftBagQuantity("slider_min", TraceSlotPayload(data.bagId, data.slotIndex, {
                            isStow = data.isStow,
                            value = data.sliderMin or 1,
                        }))
                        dialog.slider:SetValue(data.sliderMin or 1)
                    end
                end,
            },
            {
                keybind = "DIALOG_TERTIARY",
                text = GetString(rawget(_G, "SI_BETTERUI_BANK_SLIDER_MAX")),
                callback = function(dialog)
                    if dialog and dialog.slider then
                        local data = dialog.data or {}
                        TraceCraftBagQuantity("slider_max", TraceSlotPayload(data.bagId, data.slotIndex, {
                            isStow = data.isStow,
                            value = data.sliderMax or 1,
                        }))
                        dialog.slider:SetValue(data.sliderMax or 1)
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
    TraceCraftBagQuantity("show_request", { isStow = isStow })
    if not inventorySlot then
        TraceCraftBagQuantity("show_blocked", { reason = "missingInventorySlot", isStow = isStow })
        return
    end

    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId or not slotIndex then
        TraceCraftBagQuantity("show_blocked", { reason = "invalidSlot", isStow = isStow })
        return
    end

    local stackCount = GetSlotStackSize(bagId, slotIndex) or 1

    if stackCount <= 1 then
        local destinationBag = isStow and BAG_VIRTUAL or BAG_BACKPACK
        local moved = BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, destinationBag)
        TraceCraftBagQuantity("full_stack_move", TraceSlotPayload(bagId, slotIndex, {
            isStow = isStow,
            stackCount = stackCount,
            destinationBag = destinationBag,
            moved = moved == true,
        }))
        return
    end

    local itemLink = GetItemLink(bagId, slotIndex)
    local itemName = GetItemName(bagId, slotIndex)
    local sliderMax = math.min(stackCount, MAX_STACK_TRANSFER)

    TraceCraftBagQuantity("show_dialog", TraceSlotPayload(bagId, slotIndex, {
        isStow = isStow,
        stackCount = stackCount,
        sliderMin = 1,
        sliderMax = sliderMax,
        sliderStartValue = 1,
        itemName = itemName,
    }))

    ZO_Dialogs_ShowGamepadDialog(BETTERUI_CRAFTBAG_QUANTITY_DIALOG, {
        bagId = bagId,
        slotIndex = slotIndex,
        sliderMin = 1,
        sliderMax = sliderMax,
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
