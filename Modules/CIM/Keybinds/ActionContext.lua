--[[
File: Modules/CIM/Keybinds/ActionContext.lua
Purpose: Provides frame-based caching for keybind action context lookups.
         Reduces redundant API calls in keybind descriptors.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Keybinds = BETTERUI.CIM.Keybinds or {}

-- ACTION CONTEXT CACHE
-- Provides frame-based caching to avoid redundant API calls in keybind
-- name/visible/callback functions that all need the same item data.

local cachedFrame = -1    -- Frame number when cache was last computed
local cachedContext = nil -- The cached context data

function BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)
    local currentFrame = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0

    -- Return cached if same frame
    if currentFrame == cachedFrame and cachedContext then
        return cachedContext
    end

    -- Compute fresh context
    cachedFrame = currentFrame
    cachedContext = {}

    local ctx = cachedContext
    ctx.actionMode = self.actionMode

    -- Determine which list to query based on action mode
    local targetList = nil
    if ctx.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        targetList = self.itemList
    elseif ctx.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        targetList = self.craftBagList
    elseif ctx.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
        targetList = self.categoryList
    end

    -- Get target data
    ctx.target = targetList and targetList.selectedData or nil

    if not ctx.target then
        ctx.filterType = nil
        ctx.isQuestItem = false
        ctx.isQuickslottable = false
        ctx.meetsUsage = false
        ctx.isGear = false
        return cachedContext
    end

    local target = ctx.target

    -- Compute filter type once
    if target.bagId and target.slotIndex then
        ctx.filterType = GetItemFilterTypeInfo(target.bagId, target.slotIndex)
    else
        ctx.filterType = nil
    end

    -- Quest item check
    ctx.isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)

    -- Quickslot check
    ctx.isQuickslottable = IsQuickslottable(target)

    -- Usage requirements
    ctx.meetsUsage = target.meetsUsageRequirement

    -- Check if it's gear (weapons/armor/jewelry)
    ctx.isGear = ctx.filterType and (
        ctx.filterType == ITEMFILTERTYPE_WEAPONS or
        ctx.filterType == ITEMFILTERTYPE_ARMOR or
        ctx.filterType == ITEMFILTERTYPE_JEWELRY
    )

    return cachedContext
end

--[[
Function: BETTERUI.CIM.Keybinds.InvalidateActionContext
Description: Forces the action context cache to be recomputed on next access.
             Call when item selection changes or list switches.
]]
function BETTERUI.CIM.Keybinds.InvalidateActionContext()
    cachedFrame = -1
    cachedContext = nil
end

function BETTERUI.CIM.Keybinds.GetXButtonName(self)
    local ctx = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)

    if ctx.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        if ctx.isQuickslottable then
            return GetString(rawget(_G, "SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN"))
        elseif not ctx.isQuestItem and ctx.isGear then
            return GetString(rawget(_G, "SI_BETTERUI_INV_SWITCH_INFO"))
        elseif ctx.isQuestItem and ctx.meetsUsage then
            return GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
        else
            return GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
        end
    elseif ctx.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        return GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
    end

    return ""
end

function BETTERUI.CIM.Keybinds.GetXButtonVisible(self)
    local ctx = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)

    if ctx.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        if not ctx.target then return false end
        return not ctx.isQuestItem or ctx.meetsUsage
    elseif ctx.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        return true
    end

    return false
end
