--[[
File: Modules/CIM/Actions/ActionDialogUtils.lua
Purpose: Shared action dialog utilities for Inventory and Banking modules.
         Provides factories for quickslot entries, action entry population, and common handlers.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

-------------------------------------------------------------------------------------------------
-- QUICKSLOT DIALOG UTILITIES
-------------------------------------------------------------------------------------------------

-- Ordered clockwise starting at North: N, NE, E, SE, S, SW, W, NW
local QUICKSLOT_ORDERED_SLOTS = { 4, 3, 2, 1, 8, 7, 6, 5 }

-- Quickslot directional labels
local QUICKSLOT_LABELS = {
    [1] = "Southeast",
    [2] = "East",
    [3] = "Northeast",
    [4] = "North",
    [5] = "Northwest",
    [6] = "West",
    [7] = "Southwest",
    [8] = "South",
}

--[[
Function: BETTERUI.CIM.GetQuickslotLabel
Description: Returns a human-readable directional label for a quickslot index.
param: slotIndex (number) - The quickslot index (1-8).
return: string - The directional label.
]]
function BETTERUI.CIM.GetQuickslotLabel(slotIndex)
    return QUICKSLOT_LABELS[slotIndex] or tostring(slotIndex)
end

--[[
Function: BETTERUI.CIM.BuildQuickslotDialogEntries
Description: Populates the parametric list with quickslot wheel entries.
Rationale: Shared quickslot assignment UI used by the Inventory module's action dialog.
Mechanism:
  1. Clears the parametric list.
  2. Adds "Remove" entry if item is already assigned to a slot.
  3. Adds entries for each of the 8 quickslot positions in clockwise order.
param: dialog (table) - The dialog object containing the parametricList.
param: target (table) - The target item data (bagId, slotIndex).
return: table - { hasUnassign = boolean, assignedIndex = number|nil, orderedSlots = table }
]]
--- @param dialog table The dialog object containing the parametricList
--- @param target table The target item data (bagId, slotIndex)
--- @return table result Information about the populated entries
function BETTERUI.CIM.BuildQuickslotDialogEntries(dialog, target)
    local parametricList = dialog.info.parametricList
    ZO_ClearNumericallyIndexedTable(parametricList)

    local hasUnassign = false
    local assignedIndex = nil

    -- Check if item is already assigned to a quickslot
    if FindActionSlotMatchingItem then
        assignedIndex = FindActionSlotMatchingItem(target.bagId, target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if assignedIndex then
            hasUnassign = true
            -- Create "Remove" entry
            local removeText = GetString(SI_ITEM_ACTION_REMOVE)
            if not removeText or removeText == "" then
                removeText = "Remove"
            end
            local unassignEntry = ZO_GamepadEntryData:New(removeText)
            unassignEntry:SetIconTintOnSelection(true)
            local normalColor = ZO_NORMAL_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
            local selectedColor = ZO_SELECTED_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
            if unassignEntry.SetNameColors then
                unassignEntry:SetNameColors(normalColor, selectedColor)
            end
            unassignEntry.isUnassign = true
            unassignEntry.setup = ZO_SharedGamepadEntry_OnSetup
            table.insert(parametricList, { template = "ZO_GamepadMenuEntryTemplate", entryData = unassignEntry })
        end
    end

    -- Build entries for each quickslot position
    for _, slotIndex in ipairs(QUICKSLOT_ORDERED_SLOTS) do
        local icon = GetSlotTexture and GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
        local lower = type(icon) == "string" and icon:lower() or nil

        -- Empty slots show no icon (nil) - a fallback would show as white box
        if icon == "" or (lower and string.find(lower, "quickslot_empty", 1, true)) then
            icon = nil
        end

        local entryData = ZO_GamepadEntryData:New(BETTERUI.CIM.GetQuickslotLabel(slotIndex), icon)
        if entryData.AddIcon and icon then
            entryData:AddIcon(icon)
        end

        -- Flash all non-current slots; keep the currently assigned slot steady
        local isCurrent = assignedIndex ~= nil and (slotIndex == assignedIndex)
        local shouldFlash = not isCurrent
        entryData.alphaChangeOnSelection = shouldFlash
        entryData.showBarEvenWhenUnselected = shouldFlash
        entryData:SetIconTintOnSelection(shouldFlash)
        entryData.slotIndex = slotIndex
        entryData.setup = ZO_SharedGamepadEntry_OnSetup

        local templateName = isCurrent and "ZO_GamepadMenuEntryTemplate" or "ZO_GamepadItemEntryTemplate"
        table.insert(parametricList, { template = templateName, entryData = entryData })
    end

    return {
        hasUnassign = hasUnassign,
        assignedIndex = assignedIndex,
        orderedSlots = QUICKSLOT_ORDERED_SLOTS,
    }
end

--[[
Function: BETTERUI.CIM.SetQuickslotDialogSelection
Description: Sets the initial selection in the quickslot dialog.
param: dialog (table) - The dialog object.
param: quickslotInfo (table) - Result from BuildQuickslotDialogEntries.
]]
function BETTERUI.CIM.SetQuickslotDialogSelection(dialog, quickslotInfo)
    if dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
        local offset = quickslotInfo.hasUnassign and 1 or 0
        if quickslotInfo.assignedIndex then
            -- Map the quickslot index to its position in the ordered list
            local indexMap = {}
            for pos, idx in ipairs(quickslotInfo.orderedSlots) do
                indexMap[idx] = pos
            end
            local listPos = (indexMap[quickslotInfo.assignedIndex] or 1) + offset
            dialog.entryList:SetSelectedIndexWithoutAnimation(listPos, true, false)
        else
            dialog.entryList:SetSelectedIndexWithoutAnimation(quickslotInfo.hasUnassign and 2 or 1, true, false)
        end
    end
end

-------------------------------------------------------------------------------------------------
-- ACTION ENTRY POPULATION
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.PopulateActionEntries
Description: Populates the parametric list with discovered slot actions.
Rationale: Shared action entry building used by Inventory and Banking Y-menus.
param: parametricList (table) - The dialog's parametric list to populate.
param: slotActions (object) - The slot actions object with GetNumSlotActions/GetSlotAction.
param: options (table|nil) - Configuration options:
  - hideDestroy (boolean): Hide Destroy/Delete actions.
  - filterCallback (function): Optional function(actionName) returning true to include action.
]]
--- @param parametricList table The dialog's parametric list to populate
--- @param slotActions table The slot actions object with GetNumSlotActions/GetSlotAction
--- @param options table|nil Configuration options
function BETTERUI.CIM.PopulateActionEntries(parametricList, slotActions, options)
    options = options or {}
    local hideDestroy = options.hideDestroy
    local filterCallback = options.filterCallback

    local numActions = slotActions:GetNumSlotActions()

    for i = 1, numActions do
        local action = slotActions:GetSlotAction(i)
        local actionName = slotActions:GetRawActionName(action)

        -- Check if this is a Destroy/Delete action
        local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
            or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))

        -- Apply filters
        local shouldInclude = true
        if hideDestroy and isDestroy then
            shouldInclude = false
        end
        if shouldInclude and filterCallback then
            shouldInclude = filterCallback(actionName)
        end

        if shouldInclude then
            local entryData = ZO_GamepadEntryData:New(actionName)
            entryData:SetIconTintOnSelection(true)
            entryData.action = action
            entryData.setup = ZO_SharedGamepadEntry_OnSetup

            table.insert(parametricList, {
                template = "ZO_GamepadItemEntryTemplate",
                entryData = entryData,
            })
        end
    end
end

-------------------------------------------------------------------------------------------------
-- LINK TO CHAT HANDLER
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.HandleLinkToChat
Description: Links an item to chat from target data.
param: targetData (table) - The item data containing bagId and slotIndex.
return: boolean - True if link was inserted, false otherwise.
]]
function BETTERUI.CIM.HandleLinkToChat(targetData)
    if not targetData then return false end

    local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
    if not bag or not slot then return false end

    local itemLink = GetItemLink(bag, slot)
    if itemLink and itemLink ~= "" then
        ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
        return true
    end
    return false
end
