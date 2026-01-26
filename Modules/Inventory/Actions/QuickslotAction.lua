--[[
File: Modules/Inventory/Actions/QuickslotAction.lua
Purpose: Handles the Quickslot Assignment dialog, allowing users to assign items to the quickslot wheel.
]]

--------------------------------------------------------------------------------
-- QUICKSLOT ASSIGNMENT DIALOG
--------------------------------------------------------------------------------

--- Initializes the custom dialog for visual quickslot assignment.
---
--- Purpose: Provides a visual wheel selection for assigning items to quickslots.
--[[
File: Modules/Inventory/Actions/QuickslotAction.lua
Purpose: Handles the Quickslot Assignment dialog, allowing users to assign items to the quickslot wheel.
]]

--------------------------------------------------------------------------------
-- HELPER: Shared Dialog Population
--------------------------------------------------------------------------------

--- Populates the parametric list with Quickslot Wheel entries.
--- Used by both the custom Quickslot Dialog and the hooked Action Dialog.
function BETTERUI.Inventory.PopulateQuickslotDialogEntries(parametricList, target)
    if not parametricList or not target then return end

    ZO_ClearNumericallyIndexedTable(parametricList)

    local hasUnassign = false
    local assignedIndex = nil

    if FindActionSlotMatchingItem then
        assignedIndex = FindActionSlotMatchingItem(target.bagId, target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if assignedIndex then
            hasUnassign = true
            local unassignEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_UNASSIGN),
                "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot_empty.dds")
            unassignEntry.action = "unassign"
            unassignEntry.setup = ZO_SharedGamepadEntry_OnSetup
            table.insert(
                parametricList,
                { template = "ZO_GamepadMenuEntryTemplate", entryData = unassignEntry }
            )
        end
    end

    local function slotLabel(idx)
        if idx == 4 then
            return GetString(SI_BETTERUI_DIR_NORTH)
        elseif idx == 5 then
            return GetString(SI_BETTERUI_DIR_NORTHWEST)
        elseif idx == 6 then
            return GetString(SI_BETTERUI_DIR_WEST)
        elseif idx == 7 then
            return GetString(SI_BETTERUI_DIR_SOUTHWEST)
        elseif idx == 8 then
            return GetString(SI_BETTERUI_DIR_SOUTH)
        elseif idx == 1 then
            return GetString(SI_BETTERUI_DIR_SOUTHEAST)
        elseif idx == 2 then
            return GetString(SI_BETTERUI_DIR_EAST)
        elseif idx == 3 then
            return GetString(SI_BETTERUI_DIR_NORTHEAST)
        end
        return tostring(idx)
    end

    -- Clockwise ordering starting at North: N, NE, E, SE, S, SW, W, NW
    local orderedSlots = { 4, 3, 2, 1, 8, 7, 6, 5 }

    for _, slotIndex in ipairs(orderedSlots) do
        local icon = GetSlotTexture and GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
        local lower = type(icon) == "string" and icon:lower() or nil
        if not lower or lower:find("gamepad/gp_inventory_icon_quickslot_empty") then
            icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot_empty.dds"
        end

        local name = slotLabel(slotIndex)
        local entryData = ZO_GamepadEntryData:New(name, icon)
        entryData.action = "assign"
        entryData.assignSlotIndex = slotIndex

        -- Highlight currently assigned slot
        local isCurrent = (assignedIndex == slotIndex)
        if isCurrent then
            entryData:SetSelected(true)
            entryData:SetIconTintOnSelection(true)
        end

        local shouldFlash = isCurrent
        entryData.showBarEvenWhenUnselected = shouldFlash
        entryData:SetIconTintOnSelection(shouldFlash)
        entryData.slotIndex = slotIndex
        entryData.setup = ZO_SharedGamepadEntry_OnSetup

        local templateName = isCurrent and "ZO_GamepadMenuEntryTemplate" or "ZO_GamepadItemEntryTemplate"
        table.insert(parametricList, { template = templateName, entryData = entryData })
    end

    return hasUnassign
end

--------------------------------------------------------------------------------

function BETTERUI.Inventory.Class:InitializeQuickslotAssignDialog()
    local SLOT_LABELS = {
        [1] = "Southeast",
        [2] = "East",
        [3] = "Northeast",
        [4] = "North",
        [5] = "Northwest",
        [6] = "West",
        [7] = "Southwest",
        [8] = "South",
    }

    ZO_Dialogs_RegisterCustomDialog("BETTERUI_QUICKSLOT_ASSIGN_DIALOG", {
        blockDirectionalInput = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            allowRightStickPassThrough = true,
        },
        title = {
            text = function(dialog)
                return GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN)
            end,
        },
        setup = function(dialog, data)
            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            -- If this item is currently assigned, add an Unassign action as the first row (avoids needing a tertiary button)
            local hasUnassign = false
            local assignedIndexForUnassign = nil
            if data and data.target and FindActionSlotMatchingItem then
                assignedIndexForUnassign = FindActionSlotMatchingItem(
                    data.target.bagId,
                    data.target.slotIndex,
                    HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                )
                if assignedIndexForUnassign then
                    hasUnassign = true
                    local entryData = ZO_GamepadEntryData:New(GetString(SI_ITEM_ACTION_REMOVE))
                    entryData:SetIconTintOnSelection(true)
                    entryData.isUnassign = true
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup
                    table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
                end
            end

            for slotIndex = 1, 8 do
                local icon
                if GetSlotTexture then
                    icon = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                end
                if not icon or icon == "" then
                    icon = "/esoui/art/quickslots/quickslot_empty.dds"
                end

                local entryData = ZO_GamepadEntryData:New(SLOT_LABELS[slotIndex] or tostring(slotIndex), icon)
                entryData:SetIconTintOnSelection(true)
                entryData.slotIndex = slotIndex
                entryData.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
            end

            dialog:setupFunc()
            -- Preselect currently assigned slot index if this item is already on the wheel
            if data and data.target and FindActionSlotMatchingItem then
                local assignedIndex = FindActionSlotMatchingItem(
                    data.target.bagId,
                    data.target.slotIndex,
                    HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                )
                if assignedIndex and dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                    local offset = hasUnassign and 1 or 0
                    dialog.entryList:SetSelectedIndexWithoutAnimation(
                        math.max(1, math.min(8 + offset, assignedIndex + offset)),
                        true,
                        false
                    )
                elseif dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                    dialog.entryList:SetSelectedIndexWithoutAnimation(hasUnassign and 2 or 1, true, false)
                end
            end
        end,
        mainText = {
            text = function(dialog)
                if dialog and dialog.data and dialog.data.target then
                    local t = dialog.data.target
                    local name = GetItemName(t.bagId, t.slotIndex)
                    if name and name ~= "" then
                        return zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                    end
                end
                return GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN)
            end,
        },
        parametricList = {},
        buttons = {
            { keybind = "DIALOG_NEGATIVE", text = GetString(SI_DIALOG_CANCEL) },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    local target = dialog.data and dialog.data.target
                    if target and target.bagId and target.slotIndex then
                        local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                        local selected = dialog.entryList
                            and dialog.entryList.GetTargetData
                            and SafeGetTargetData(dialog.entryList)
                        if selected and selected.isUnassign then
                            local assigned = FindActionSlotMatchingItem(target.bagId, target.slotIndex, quickslot_wheel)
                            if assigned then
                                CallSecureProtected("ClearSlot", assigned, quickslot_wheel)
                                if SOUNDS and PlaySound then
                                    PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
                                end
                            end
                        else
                            local wheelSlotIndex = selected and selected.slotIndex or 4 -- fallback to North (4)
                            CallSecureProtected(
                                "SelectSlotItem",
                                target.bagId,
                                target.slotIndex,
                                wheelSlotIndex,
                                quickslot_wheel
                            )
                            if SOUNDS and PlaySound then
                                PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
                            end
                        end
                        ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_QUICKSLOT_ASSIGN_DIALOG")
                        -- Delay to ensure focus transition completes
                        zo_callLater(function()
                            if GAMEPAD_INVENTORY then
                                GAMEPAD_INVENTORY:RefreshItemList()
                            end
                        end, 150)
                    end
                end,
            },
        },
    })
end

--- Displays the quickslot assignment dialog for a given item.
---
--- Purpose: Triggers the quickslot assignment flow.
--- Mechanics:
--- 1. Closes any existing Equip dialogs.
--- 2. Directly shows the "Y-Action" menu in "Quickslot Mode".
--- 3. If that fails to show after a single frame delay, falls back to the custom dialog.
---
--- @param bagId number The bag ID of the item.
--- @param slotIndex number The slot index of the item.
function BETTERUI.Inventory.Class:ShowQuickslotAssignDialog(bagId, slotIndex)
    local data = { quickslotAssign = true, target = { bagId = bagId, slotIndex = slotIndex } }

    if ZO_Dialogs_IsShowing(BETTERUI_EQUIP_SLOT_DIALOG) then
        ZO_Dialogs_ReleaseDialog(BETTERUI_EQUIP_SLOT_DIALOG)
    end

    -- Attempt to show the primary action dialog immediately
    ZO_Dialogs_ShowDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, data, nil, true, true)

    -- Robust fallback: If the dialog didn't show (possibly due to engine state),
    -- attempt once more in the next frame. If both fail, use the standalone dialog.
    -- Delay dialog init to prevent conflict with source dialog
    zo_callLater(function()
        if not ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
            ZO_Dialogs_ShowDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, data, nil, true, true)

            -- Final fallback to standalone if the unified dialog is unavailable/denied
            -- Nested delay to ensure clean state transition
            zo_callLater(function()
                if not ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                    ZO_Dialogs_ShowDialog(
                        "BETTERUI_QUICKSLOT_ASSIGN_DIALOG",
                        { target = { bagId = bagId, slotIndex = slotIndex } },
                        nil,
                        true,
                        true
                    )
                end
            end, 50)
        end
    end, 10)
end
