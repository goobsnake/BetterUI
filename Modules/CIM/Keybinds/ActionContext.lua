BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Keybinds = BETTERUI.CIM.Keybinds or {}

--- Shared quickslot eligibility check for inventory slot data.
--- Re-exported by Modules/Inventory/Keybinds/InventoryKeybinds.lua as
--- BETTERUI.Inventory.Keybinds.IsQuickslottable (CIM loads before Inventory).
---@param slotData table|nil slot data with bagId/slotIndex
---@return boolean
function BETTERUI.CIM.IsQuickslottable(slotData)
    if not slotData or not slotData.bagId or not slotData.slotIndex then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "quickslotEligibility", {bagId = slotData and slotData.bagId, slotIndex = slotData and slotData.slotIndex, result = false})
        end
        return false
    end

    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    local result = false
    if FindActionSlotMatchingItem
        and FindActionSlotMatchingItem(bagId, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        result = true
    elseif ZO_InventoryUtils_DoesNewItemMatchFilterType then
        if ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, ITEMFILTERTYPE_QUICKSLOT) then
            result = true
        elseif ITEMFILTERTYPE_QUEST_QUICKSLOT
            and ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, ITEMFILTERTYPE_QUEST_QUICKSLOT) then
            result = true
        end
    elseif IsValidItemForSlot and IsValidItemForSlot(bagId, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        result = true
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "quickslotEligibility", {bagId = bagId, slotIndex = slotIndex, result = result})
    end
    return result
end

local cachedFrame = -1
local contextCacheByReceiver = setmetatable({}, { __mode = "k" })
local inventoryActionLists = {}

function BETTERUI.CIM.Keybinds.RegisterInventoryActionModes(actionModes)
    inventoryActionLists = {}
    if type(actionModes) ~= "table" then
        if BETTERUI.Log then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "registerActionModes", {modeCount = 0})
        end
        return
    end

    if actionModes.itemList ~= nil then
        inventoryActionLists[actionModes.itemList] = "itemList"
    end
    if actionModes.craftBag ~= nil then
        inventoryActionLists[actionModes.craftBag] = "craftBagList"
    end
    if actionModes.category ~= nil then
        inventoryActionLists[actionModes.category] = "categoryList"
    end
    if BETTERUI.Log then
        local modeCount = 0
        for _ in pairs(inventoryActionLists) do modeCount = modeCount + 1 end
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "registerActionModes", {modeCount = modeCount})
    end
end

local function GetInventoryActionList(self, actionMode)
    local listKey = inventoryActionLists[actionMode]
    if not listKey then
        return nil, nil
    end
    return self[listKey], listKey
end

function BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)
    local currentFrame = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0

    if currentFrame ~= cachedFrame then
        cachedFrame = currentFrame
        contextCacheByReceiver = setmetatable({}, { __mode = "k" })
    end

    local cachedContext = contextCacheByReceiver[self]
    if cachedContext then
        return cachedContext
    end

    local ctx = {}
    if type(self) == "table" then
        contextCacheByReceiver[self] = ctx
    end

    if type(self) ~= "table" then
        ctx.actionMode = nil
        ctx.actionListKey = nil
        ctx.target = nil
        ctx.filterType = nil
        ctx.isQuestItem = false
        ctx.isQuickslottable = false
        ctx.meetsUsage = false
        ctx.isGear = false
        ctx.isEquipment = false
        ctx.isUsableQuest = false
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.KEYBIND, "actionContext", {actionMode = ctx.actionMode, hasTarget = ctx.target ~= nil})
        end
        return ctx
    end

    ctx.actionMode = self.actionMode
    ctx.actionListKey = nil

    -- Determine which list to query based on action mode
    local targetList, actionListKey = GetInventoryActionList(self, ctx.actionMode)
    ctx.actionListKey = actionListKey

    -- Get target data (prefer GetSelectedData for wrapper lists)
    ctx.target = targetList and (targetList.GetSelectedData and targetList:GetSelectedData() or targetList.selectedData) or nil

    if not ctx.target then
        ctx.filterType = nil
        ctx.isQuestItem = false
        ctx.isQuickslottable = false
        ctx.meetsUsage = false
        ctx.isGear = false
        ctx.isEquipment = false
        ctx.isUsableQuest = false
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.KEYBIND, "actionContext", {actionMode = ctx.actionMode, hasTarget = ctx.target ~= nil})
        end
        return ctx
    end

    local target = ctx.target

    -- Compute filter type once (read from dataSource wrapper if present)
    local rawTarget = target.dataSource or target
    if rawTarget.bagId and rawTarget.slotIndex then
        ctx.filterType = GetItemFilterTypeInfo(rawTarget.bagId, rawTarget.slotIndex)
    else
        ctx.filterType = nil
    end

    -- Quest item check
    ctx.isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)

    -- Quickslot check
    ctx.isQuickslottable = BETTERUI.CIM.IsQuickslottable(target)

    -- Usage requirements
    ctx.meetsUsage = target.meetsUsageRequirement

    -- Check if it's gear (weapons/armor/jewelry)
    ctx.isGear = ctx.filterType and (
        ctx.filterType == ITEMFILTERTYPE_WEAPONS or
        ctx.filterType == ITEMFILTERTYPE_ARMOR or
        ctx.filterType == ITEMFILTERTYPE_JEWELRY
    )
    ctx.isEquipment = ctx.isGear
    ctx.isUsableQuest = ctx.isQuestItem and ctx.meetsUsage == true or false

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.KEYBIND, "actionContext", {actionMode = ctx.actionMode, hasTarget = ctx.target ~= nil})
    end
    return ctx
end

function BETTERUI.CIM.Keybinds.InvalidateActionContext()
    cachedFrame = -1
    contextCacheByReceiver = setmetatable({}, { __mode = "k" })
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "invalidateActionContext")
    end
end

function BETTERUI.CIM.Keybinds.GetXButtonName(self)
    local ctx = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)

    local name = ""
    if ctx.actionListKey == "itemList" then
        if ctx.isQuickslottable then
            name = GetString(rawget(_G, "SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN"))
        elseif not ctx.isQuestItem and ctx.isEquipment then
            name = GetString(rawget(_G, "SI_BETTERUI_INV_SWITCH_INFO"))
        elseif ctx.isUsableQuest then
            name = GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
        else
            name = GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
        end
    elseif ctx.actionListKey == "craftBagList" then
        name = GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "xButton", {name = name, visible = true})
    end
    return name
end

function BETTERUI.CIM.Keybinds.GetXButtonVisible(self)
    local ctx = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)

    local visible = false
    if ctx.actionListKey == "itemList" then
        visible = ctx.target ~= nil and (not ctx.isQuestItem or ctx.isUsableQuest)
    elseif ctx.actionListKey == "craftBagList" then
        visible = true
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "xButton", {name = nil, visible = visible})
    end
    return visible
end
