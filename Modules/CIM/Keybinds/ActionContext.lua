BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Keybinds = BETTERUI.CIM.Keybinds or {}

local actionContextFilterWarnings = {}

local function SafeDoesNewItemMatchFilterType(itemData, filterType, caller)
    if not itemData or filterType == nil or type(ZO_InventoryUtils_DoesNewItemMatchFilterType) ~= "function" then
        return false
    end

    local ok, matches = pcall(ZO_InventoryUtils_DoesNewItemMatchFilterType, itemData, filterType)
    if ok then
        return matches == true
    end

    local warningKey = table.concat({ tostring(caller or "unknown"), tostring(filterType), tostring(matches) }, "|")
    if not actionContextFilterWarnings[warningKey] and BETTERUI.Log and BETTERUI.Log.Warn then
        actionContextFilterWarnings[warningKey] = true
        local L = BETTERUI.Log
        local categories = L.CATEGORY or {}
        local itemForLog = type(itemData) == "table" and (itemData.dataSource or itemData) or itemData
        L.Warn(categories.KEYBIND, "keybind action filter failed", {
            fn = caller or "ActionContext",
            filterType = filterType,
            error = tostring(matches),
            item = L.DescribeItem and L.DescribeItem(itemForLog, "target") or nil,
        })
    end

    return false
end

local function IsQuestTarget(target)
    if type(target) ~= "table" then
        return false
    end

    local dataSource = target.dataSource or target
    if type(dataSource) ~= "table" then
        return false
    end

    local function IsQuestUniqueId(uniqueId)
        return type(uniqueId) == "string" and uniqueId:find("^quest:") ~= nil
    end

    return target.isQuestItem == true
        or dataSource.isQuestItem == true
        or dataSource.questIndex ~= nil
        or (SLOT_TYPE_QUEST_ITEM ~= nil and target.slotType == SLOT_TYPE_QUEST_ITEM)
        or (SLOT_TYPE_QUEST_ITEM ~= nil and dataSource.slotType == SLOT_TYPE_QUEST_ITEM)
        or IsQuestUniqueId(target.uniqueId)
        or IsQuestUniqueId(dataSource.uniqueId)
        or SafeDoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST, "ActionContext.IsQuestTarget")
end

--- Shared quickslot eligibility check for inventory slot data.
--- Re-exported by Modules/Inventory/Keybinds/InventoryKeybinds.lua as
--- BETTERUI.Inventory.Keybinds.IsQuickslottable (CIM loads before Inventory).
---@param slotData table|nil slot data with bagId/slotIndex
---@return boolean
function BETTERUI.CIM.IsQuickslottable(slotData)
    if not slotData or not slotData.bagId or not slotData.slotIndex then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "action: quickslot eligibility checked", {bagId = slotData and slotData.bagId, slotIndex = slotData and slotData.slotIndex, result = false})
        end
        return false
    end

    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    local result = false
    if FindActionSlotMatchingItem
        and FindActionSlotMatchingItem(bagId, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        result = true
    elseif ZO_InventoryUtils_DoesNewItemMatchFilterType then
        if SafeDoesNewItemMatchFilterType(slotData, ITEMFILTERTYPE_QUICKSLOT, "ActionContext.IsQuickslottable") then
            result = true
        elseif ITEMFILTERTYPE_QUEST_QUICKSLOT
            and SafeDoesNewItemMatchFilterType(slotData, ITEMFILTERTYPE_QUEST_QUICKSLOT, "ActionContext.IsQuickslottable") then
            result = true
        end
    elseif IsValidItemForSlot and IsValidItemForSlot(bagId, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        result = true
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "action: quickslot eligibility checked", {bagId = bagId, slotIndex = slotIndex, result = result})
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
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: action modes registered", {modeCount = 0})
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
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: action modes registered", {modeCount = modeCount})
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
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: action context resolved", {actionMode = ctx.actionMode, hasTarget = ctx.target ~= nil})
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
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: action context resolved", {actionMode = ctx.actionMode, hasTarget = ctx.target ~= nil})
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
    ctx.isQuestItem = IsQuestTarget(target)

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
    ctx.isUsableQuest = (ctx.isQuestItem == true and ctx.meetsUsage == true) or false

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        local L = BETTERUI.Log
        local categories = L.CATEGORY or {}
        L.Debug(categories.KEYBIND, "keybind: action context resolved", {actionMode = ctx.actionMode, hasTarget = ctx.target ~= nil})
    end
    return ctx
end

function BETTERUI.CIM.Keybinds.InvalidateActionContext()
    cachedFrame = -1
    contextCacheByReceiver = setmetatable({}, { __mode = "k" })
    if BETTERUI.Log and type(BETTERUI.Log.Trace) == "function" then
        local L = BETTERUI.Log
        local categories = L.CATEGORY or {}
        L.Trace(categories.KEYBIND, "keybind: action context invalidated")
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
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: X button resolved", {name = name, visible = true})
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
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: X button resolved", {name = nil, visible = visible})
    end
    return visible
end
