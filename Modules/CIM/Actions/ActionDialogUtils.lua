--[[
File: Modules/CIM/Actions/ActionDialogUtils.lua
Purpose: Shared action dialog utilities for Inventory and Banking modules.
         Provides factories for quickslot entries, action entry population, and common handlers.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

-- QUICKSLOT DIALOG UTILITIES

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

---@param slotIndex integer
---@return string
function BETTERUI.CIM.GetQuickslotLabel(slotIndex)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "quickslotLabel", {slotIndex = slotIndex})
    end
    return QUICKSLOT_LABELS[slotIndex] or tostring(slotIndex)
end

---@param dialog table
---@param target table
---@return {hasUnassign: boolean, assignedIndex: integer?, orderedSlots: integer[]}
function BETTERUI.CIM.BuildQuickslotDialogEntries(dialog, target)
    local parametricList = dialog.info.parametricList
    ZO_ClearNumericallyIndexedTable(parametricList)

    local hasUnassign = false
    local assignedIndex = nil

    -- Resolve wrapped entry data
    local rawTarget = target.dataSource or target

    -- Check if item is already assigned to a quickslot
    if FindActionSlotMatchingItem then
        assignedIndex = FindActionSlotMatchingItem(rawTarget.bagId, rawTarget.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if assignedIndex then
            hasUnassign = true
            -- Create "Remove" entry
            local removeText = GetString(SI_ITEM_ACTION_REMOVE_FROM_QUICKSLOT)
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

    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "buildQuickslotEntries", {hasUnassign = hasUnassign, assignedIndex = assignedIndex})
    end
    return {
        hasUnassign = hasUnassign,
        assignedIndex = assignedIndex,
        orderedSlots = QUICKSLOT_ORDERED_SLOTS,
    }
end

-- ACTION ENTRY POPULATION

---@param parametricList table[]
---@param slotActions table
---@param options {hideDestroy: boolean?, filterCallback: fun(actionName: string): boolean?}?
---@return nil
function BETTERUI.CIM.PopulateActionEntries(parametricList, slotActions, options)
    options = options or {}
    local hideDestroy = options.hideDestroy
    local filterCallback = options.filterCallback

    local numActions = slotActions:GetNumSlotActions()
    local includedCount = 0

    for i = 1, numActions do
        local action = slotActions:GetSlotAction(i)
        local actionName = slotActions:GetRawActionName(action)

        -- Check if this is a Destroy action (SI_ITEM_ACTION_DELETE never existed)
        local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))

        -- Apply filters
        local shouldInclude = true
        if hideDestroy and isDestroy then
            shouldInclude = false
        end
        if shouldInclude and filterCallback then
            shouldInclude = filterCallback(actionName)
        end

        if shouldInclude then
            includedCount = includedCount + 1
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

    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "populateActions", {numActions = numActions, includedCount = includedCount})
    end
end

-- LINK TO CHAT HANDLER

---@param targetData table?
---@return boolean
function BETTERUI.CIM.HandleLinkToChat(targetData)
    if not targetData then
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "linkToChat", {success = false, hasLink = false})
        end
        return false
    end

    local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
    if not bag or not slot then
        -- Fallback for ZO_GamepadEntryData wrappers that expose bagId/slotIndex on dataSource
        local rawData = targetData.dataSource or targetData
        bag, slot = rawData.bagId, rawData.slotIndex
    end
    if not bag or not slot then
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "linkToChat", {success = false, hasLink = false})
        end
        return false
    end

    local itemLink = GetItemLink(bag, slot)
    local success = itemLink and itemLink ~= ""
    if success then
        ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink))
    end
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "linkToChat", {success = success, hasLink = itemLink ~= nil})
    end
    return success
end

--- Registers the setup-owned inventory dialog invoker used by shared CIM actions.
---@param invokeDialog fun(methodName: string, ...: any): boolean
---@return boolean
function BETTERUI.CIM.RegisterInventoryDialogInvoker(invokeDialog)
    local registered = type(invokeDialog) == "function"
    if registered then
        BETTERUI.CIM._inventoryDialogInvoker = invokeDialog
    end
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "dialogInvoker", {registered = registered, methodName = nil})
    end
    return registered
end

--- Calls the registered inventory dialog invoker when available.
---@param methodName string
---@return boolean
function BETTERUI.CIM.InvokeInventoryDialog(methodName, ...)
    local invokeDialog = BETTERUI.CIM._inventoryDialogInvoker
    if type(invokeDialog) ~= "function" then
        if BETTERUI.Log then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "dialogInvoker", {registered = false, methodName = methodName})
        end
        return false
    end

    local result = invokeDialog(methodName, ...)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "dialogInvoker", {registered = true, methodName = methodName})
    end
    return result
end
