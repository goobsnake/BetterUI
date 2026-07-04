--[[
File: Modules/Inventory/Core/Utils.lua
Purpose: Shared utility functions for the Inventory module.
         Delegates common functions to CIM.Utils for shared behavior.
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}

--- @class InventoryUtils
--- @field OnTabNext fun(parent: table, successful: boolean)
--- @field OnTabPrev fun(parent: table, successful: boolean)
--- @field SafeGetTargetData fun(list: table): table|nil
--- @field GetListTargetData fun(list: table): table|nil
BETTERUI.Inventory.Utils = BETTERUI.Inventory.Utils or {}

---@param parent table Inventory instance with categoryList
---@param step number Navigation step (+1 or -1)
local function CycleCategoryTab(parent, step)
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.NAV, "CycleCategoryTab bumper navigation", {step = step}) end
    if not parent.categoryList or not parent.categoryList.dataList or #parent.categoryList.dataList == 0 then
        return
    end

    BETTERUI.CIM.HeaderNavigation.CycleCategory(parent, step, {
        categories = parent.categoryList.dataList,
        getCurrentIndex = function()
            return parent.categoryList.targetSelectedIndex or parent.categoryList.selectedIndex or 1
        end,
        setCurrentIndex = function(idx)
            parent.categoryList.targetSelectedIndex = idx
            parent.categoryList.selectedIndex = idx
            parent.categoryList.selectedData = parent.categoryList.dataList[idx]
            parent.categoryList.defaultSelectedIndex = idx
        end,
        onRefresh = function()
            BETTERUI.GenericHeader.SetTitleText(parent.header, parent.categoryList.selectedData.text)
            parent:ToSavedPosition()
        end,
    })
end

--- Callback for Right Bumper (Next) navigation.
--- Usage: Passed to BETTERUI_TabBarScrollList in GenericHeader
--- Rationale: Delegates to CIM.HeaderNavigation.CycleCategory for shared behavior.
--- @param parent table Inventory instance with categoryList
--- @param successful boolean Whether the bumper press was successful
function BETTERUI.Inventory.Utils.OnTabNext(parent, successful)
    if not successful then return end
    CycleCategoryTab(parent, 1)
end

--- Callback for Left Bumper (Previous) navigation.
--- Usage: Passed to BETTERUI_TabBarScrollList in GenericHeader
--- Rationale: Delegates to CIM.HeaderNavigation.CycleCategory for shared behavior.
--- @param parent table Inventory instance with categoryList
--- @param successful boolean Whether the bumper press was successful
function BETTERUI.Inventory.Utils.OnTabPrev(parent, successful)
    if not successful then return end
    CycleCategoryTab(parent, -1)
end

BETTERUI.Inventory.Utils.SafeGetTargetData = BETTERUI.CIM.Utils.SafeGetTargetData
if type(BETTERUI.CIM.Utils.GetListTargetData) == "function" then
    BETTERUI.Inventory.Utils.SafeGetTargetData = BETTERUI.CIM.Utils.GetListTargetData
elseif type(BETTERUI.Inventory.Utils.SafeGetTargetData) ~= "function" then
    BETTERUI.Inventory.Utils.SafeGetTargetData = function(list)
        if not list then
            return nil
        end
        if list.GetTargetData then
            return list:GetTargetData()
        end
        if list.GetSelectedData then
            return list:GetSelectedData()
        end
        if list.targetData ~= nil then
            return list.targetData
        end
        return list.selectedData
    end
end
BETTERUI.Inventory.Utils.GetListTargetData = BETTERUI.Inventory.Utils.SafeGetTargetData

-- Slot-identity helpers now live in BETTERUI.CIM.Utils (CIM loads before
-- Inventory, see BetterUI.txt). These delegate to the shared CIM versions so
-- all existing Inventory.Utils call sites keep identical, byte-for-byte behavior
-- while the canonical implementation is shared with the CIM batch paths.
BETTERUI.Inventory.Utils.NormalizeIdentityValue = BETTERUI.CIM.Utils.NormalizeIdentityValue
BETTERUI.Inventory.Utils.CaptureSlotIdentity = BETTERUI.CIM.Utils.CaptureSlotIdentity
BETTERUI.Inventory.Utils.IsSlotIdentityCurrent = BETTERUI.CIM.Utils.IsSlotIdentityCurrent

--- Nil-safe uniqueId equality for parametric list templates.
--- Unlike the naive BETTERUI.CIM.MenuEntryTemplateEquality (raw ==), this normalizes
--- ids so distinct id64 userdata instances that represent the same item compare equal,
--- and two nil ids never report a (false) match. Shared by the Inventory item and
--- backpack lists, which both previously carried their own hardened copy.
local function NormalizeEntryUniqueId(value)
    if value == nil then
        return nil
    end
    local normalize = BETTERUI.Inventory.Utils.NormalizeIdentityValue
    if normalize then
        return normalize(value)
    end
    return tostring(value)
end

function BETTERUI.Inventory.Utils.MenuEntryTemplateEquality(left, right)
    local leftId = left and NormalizeEntryUniqueId(left.uniqueId)
    local rightId = right and NormalizeEntryUniqueId(right.uniqueId)
    return leftId ~= nil and leftId == rightId
end

--- True when an inventory entry carries an intrinsic quest marker (the quest-item flag,
--- a quest index, the quest slot type, or a "quest:" uniqueId). This is the base
--- predicate shared by the action, filtering, and formatting paths. The native
--- ITEMFILTERTYPE_QUEST fallback (with its module-specific warning routing) stays local
--- to the callers that need it, because those diverge (ACTION vs LIST category, distinct
--- throttle tables, and the formatting path deliberately omits the fallback entirely).
local function IsQuestUniqueId(uniqueId)
    return type(uniqueId) == "string" and uniqueId:find("^quest:") ~= nil
end

function BETTERUI.Inventory.Utils.HasQuestItemMarkers(itemData)
    if type(itemData) ~= "table" then
        return false
    end
    local source = itemData.dataSource or itemData
    if type(source) ~= "table" then
        return false
    end
    return itemData.isQuestItem == true
        or source.isQuestItem == true
        or source.questIndex ~= nil
        or (SLOT_TYPE_QUEST_ITEM ~= nil and itemData.slotType == SLOT_TYPE_QUEST_ITEM)
        or (SLOT_TYPE_QUEST_ITEM ~= nil and source.slotType == SLOT_TYPE_QUEST_ITEM)
        or IsQuestUniqueId(itemData.uniqueId)
        or IsQuestUniqueId(source.uniqueId)
end

--- Builds a gamepad item-sort tiebreaker schema for ZO_TableOrderingFunction. The
--- shared base chain (name -> requiredLevel -> requiredChampionPoints -> iconFile ->
--- uniqueId) is identical across the backpack and craft-bag lists; each list layers its
--- own category head on top (the backpack sorts category -> name directly, the craft bag
--- inserts a bestItemTypeName tiebreaker between category and name). A fresh table is
--- returned per call so callers never share/mutate the schema.
---@param categoryHead table Category-key sort entries merged over the base chain
---@return table schema
function BETTERUI.Inventory.Utils.BuildGamepadItemSort(categoryHead)
    local schema = {
        name = { tiebreaker = "requiredLevel" },
        requiredLevel = { tiebreaker = "requiredChampionPoints", isNumeric = true },
        requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
        iconFile = { tiebreaker = "uniqueId" },
        uniqueId = { isId64 = true },
    }
    for key, value in pairs(categoryHead) do
        schema[key] = value
    end
    return schema
end
