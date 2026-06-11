BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Keybinds = BETTERUI.CIM.Keybinds or {}

--- Shared quickslot eligibility check for inventory slot data.
--- Re-exported by Modules/Inventory/Keybinds/InventoryKeybinds.lua as
--- BETTERUI.Inventory.Keybinds.IsQuickslottable (CIM loads before Inventory).
---@param slotData table|nil slot data with bagId/slotIndex
---@return boolean
function BETTERUI.CIM.IsQuickslottable(slotData)
    if not slotData or not slotData.bagId or not slotData.slotIndex then
        return false
    end

    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    if FindActionSlotMatchingItem
        and FindActionSlotMatchingItem(bagId, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        return true
    end

    if ZO_InventoryUtils_DoesNewItemMatchFilterType then
        if ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, ITEMFILTERTYPE_QUICKSLOT) then
            return true
        end

        if ITEMFILTERTYPE_QUEST_QUICKSLOT
            and ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, ITEMFILTERTYPE_QUEST_QUICKSLOT) then
            return true
        end
    end

    if IsValidItemForSlot and IsValidItemForSlot(bagId, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        return true
    end

    return false
end

local cachedFrame = -1
local contextCacheByReceiver = setmetatable({}, { __mode = "k" })
local inventoryActionLists = {}

function BETTERUI.CIM.Keybinds.RegisterInventoryActionModes(actionModes)
    inventoryActionLists = {}
    if type(actionModes) ~= "table" then
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
        return ctx
    end

    ctx.actionMode = self.actionMode
    ctx.actionListKey = nil

    -- Determine which list to query based on action mode
    local targetList, actionListKey = GetInventoryActionList(self, ctx.actionMode)
    ctx.actionListKey = actionListKey

    -- Get target data
    ctx.target = targetList and targetList.selectedData or nil

    if not ctx.target then
        ctx.filterType = nil
        ctx.isQuestItem = false
        ctx.isQuickslottable = false
        ctx.meetsUsage = false
        ctx.isGear = false
        ctx.isEquipment = false
        ctx.isUsableQuest = false
        return ctx
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

    return ctx
end

function BETTERUI.CIM.Keybinds.InvalidateActionContext()
    cachedFrame = -1
    contextCacheByReceiver = setmetatable({}, { __mode = "k" })
end

function BETTERUI.CIM.Keybinds.GetXButtonName(self)
    local ctx = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)

    if ctx.actionListKey == "itemList" then
        if ctx.isQuickslottable then
            return GetString(rawget(_G, "SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN"))
        elseif not ctx.isQuestItem and ctx.isEquipment then
            return GetString(rawget(_G, "SI_BETTERUI_INV_SWITCH_INFO"))
        elseif ctx.isUsableQuest then
            return GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
        else
            return GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
        end
    elseif ctx.actionListKey == "craftBagList" then
        return GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
    end

    return ""
end

function BETTERUI.CIM.Keybinds.GetXButtonVisible(self)
    local ctx = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)

    if ctx.actionListKey == "itemList" then
        if not ctx.target then return false end
        return not ctx.isQuestItem or ctx.isUsableQuest
    elseif ctx.actionListKey == "craftBagList" then
        return true
    end

    return false
end
