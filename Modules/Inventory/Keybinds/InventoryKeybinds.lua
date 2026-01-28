--[[
File: Modules/Inventory/Keybinds/InventoryKeybinds.lua
Purpose: Defines the main keybind strip for the BetterUI inventory.
         Contains all controller button mappings (X, Y, Sticks, etc.)
Author: BetterUI Team
Last Modified: 2026-01-28
]]

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

-- Action mode constants (must match other files)
-- Replaced by BETTERUI.Inventory.CONST equivalents

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
Function: IsQuickslottable
Description: Checks if an item can be assigned to a quickslot.
Rationale: Used by X-button keybind to show "Assign Quickslot" vs other actions.
Mechanism: Checks filter types, hotbar validity, and existing assignments.
param: sd (table) - Slot data of the item to check
return: boolean - True if item can be quickslotted

-- TODO(refactor): The X-button keybind logic (name/visible/callback) repeats the same
-- IsQuickslottable check, isQuestItem check, and filter type retrieval 3+ times.
-- Consider extracting to a helper like GetXButtonActionContext(self) that returns
-- {actionType, itemData, isQuest, filterType} to avoid redundant API calls.
]]
local function IsQuickslottable(sd)
    if not sd or not sd.bagId or not sd.slotIndex then
        return false
    end
    local bag, slot = sd.bagId, sd.slotIndex
    -- Already assigned is always eligible
    if FindActionSlotMatchingItem and FindActionSlotMatchingItem(bag, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        return true
    end
    -- Exclude quest items explicitly
    if
        ZO_InventoryUtils_DoesNewItemMatchFilterType
        and ZO_InventoryUtils_DoesNewItemMatchFilterType(sd, ITEMFILTERTYPE_QUEST)
    then
        return false
    end
    -- Prefer the UI's own quickslot filter (captures true quickslottables reliably)
    if
        ZO_InventoryUtils_DoesNewItemMatchFilterType
        and ZO_InventoryUtils_DoesNewItemMatchFilterType(sd, ITEMFILTERTYPE_QUICKSLOT)
    then
        return true
    end
    -- Engine validation as a secondary check
    if IsValidItemForSlot and IsValidItemForSlot(bag, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- KEYBIND INITIALIZATION
--------------------------------------------------------------------------------

--[[
Function: InitializeKeybindStrip
Description: Initializes the main keybind strip for the inventory.
Rationale: Defines all controller button mappings for inventory interactions.
Mechanism: Creates keybind descriptors for X (quick action), Y (actions menu),
           L-Stick (stack), R-Stick (switch bags), and Quaternary (clear search).
References: Called by OnDeferredInitialize
]]
function BETTERUI.Inventory.Class:InitializeKeybindStrip()
    self.mainKeybindStripDescriptor = {
        -- Primary (A) reserved for item primary actions (equip/use/etc.).
        --X Button for Quick Action
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                local n = ""
                if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    --bag mode
                    local isQuestItem =
                        ZO_InventoryUtils_DoesNewItemMatchFilterType(self.itemList.selectedData, ITEMFILTERTYPE_QUEST)
                    local target = self.itemList.selectedData
                    local ft = (target and target.bagId and target.slotIndex)
                        and GetItemFilterTypeInfo(target.bagId, target.slotIndex)
                        or nil
                    if IsQuickslottable(target) then
                        --assign
                        n = GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN)
                    elseif
                        not isQuestItem
                        and (ft == ITEMFILTERTYPE_WEAPONS or ft == ITEMFILTERTYPE_ARMOR or ft == ITEMFILTERTYPE_JEWELRY)
                    then
                        --switch compare
                        n = GetString(SI_BETTERUI_INV_SWITCH_INFO)
                    elseif isQuestItem and target.meetsUsageRequirement then
                        -- Use
                        n = GetString(SI_ITEM_ACTION_USE)
                    else
                        n = GetString(SI_ITEM_ACTION_LINK_TO_CHAT)
                    end
                elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    --craftbag mode
                    n = GetString(SI_ITEM_ACTION_LINK_TO_CHAT)
                else
                    n = ""
                end
                return n or ""
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            -- (no hold callbacks here; tap behavior preserved)
            visible = function()
                if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    if self.itemList.selectedData then
                        local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(
                            self.itemList.selectedData,
                            ITEMFILTERTYPE_QUEST
                        )
                        -- Show "A" if it's NOT a quest item OR if it IS a quest item that is usable
                        if not isQuestItem then
                            return true
                        else
                            return self.itemList.selectedData.meetsUsageRequirement
                        end
                    end
                    return false
                elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    return true
                end
            end,
            callback = function()
                if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    --bag mode
                    local target = self.itemList.selectedData
                    local ft = (target and target.bagId and target.slotIndex)
                        and GetItemFilterTypeInfo(target.bagId, target.slotIndex)
                        or nil
                    if IsQuickslottable(target) then
                        -- Open BetterUI quickslot assignment dialog to let user pick the wheel slot visually
                        self:ShowQuickslotAssignDialog(target.bagId, target.slotIndex)
                    else
                        -- If it's gear categories, toggle compare; otherwise link to chat
                        if
                            not ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)
                            and (
                                ft == ITEMFILTERTYPE_WEAPONS
                                or ft == ITEMFILTERTYPE_ARMOR
                                or ft == ITEMFILTERTYPE_JEWELRY
                            )
                        then
                            self:SwitchInfo()
                        elseif ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST) and target.meetsUsageRequirement then
                            -- Use the item (this handles scene transitions natively for books/maps)
                            -- Access dataSource for quest-specific properties
                            local ds = target.dataSource or target
                            -- Hide inventory scene to allow native scene transition
                            SCENE_MANAGER:Hide("gamepad_inventory_root")
                            if ds.toolIndex then
                                CallSecureProtected("UseQuestTool", ds.questIndex, ds.toolIndex)
                            elseif ds.stepIndex and ds.conditionIndex then
                                CallSecureProtected("UseQuestItem", ds.questIndex, ds.stepIndex, ds.conditionIndex)
                            else
                                -- Fallback for items without tool/step info (shouldn't happen but safe)
                                local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
                                if bag and slot then
                                    CallSecureProtected("UseItem", bag, slot)
                                end
                            end
                        else
                            local itemLink = GetItemLink(target.bagId, target.slotIndex)
                            if itemLink then
                                ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
                            end
                        end
                    end
                elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    --craftbag mode
                    local targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                    local itemLink
                    local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                    if bag and slot then
                        itemLink = GetItemLink(bag, slot)
                    end
                    if itemLink then
                        ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
                    end
                end
            end,
        },
        -- Y Button for Actions (CIM Factory)
        BETTERUI.CIM.Keybinds.CreateActionsKeybind(
            function()
                self:SaveListPosition()
                self:ShowActions()
            end,
            function()
                if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    return self.selectedItemUniqueId ~= nil or
                        self.currentlySelectedData ~= nil or
                        BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList) ~= nil
                elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    return self.selectedItemUniqueId ~= nil or
                        self.currentlySelectedData ~= nil or
                        BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList) ~= nil
                end
                return false
            end
        ),
        -- L-Stick for Stacking Items (CIM Factory)
        BETTERUI.CIM.Keybinds.CreateStackAllKeybind(
            BAG_BACKPACK,
            function()
                return self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE
            end
        ),
        --R Stick for Switching Bags
        {
            name = function()
                local s = zo_strformat(
                    GetString(SI_BETTERUI_INV_ACTION_TO_TEMPLATE),
                    GetString(
                        self:GetCurrentList() == self.craftBagList and SI_BETTERUI_INV_ACTION_INV
                        or SI_BETTERUI_INV_ACTION_CB
                    )
                )
                return s or ""
            end,
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            disabledDuringSceneHiding = true,
            callback = function()
                self:Switch()
            end,
        },
        -- Quaternary for Clear Search (CIM Factory)
        BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(
            function()
                if not (self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden())) then
                    return
                end
                if self.ClearTextSearch then
                    self:ClearTextSearch()
                end
                if self._searchModeActive then
                    self:ExitSearchFocus()
                else
                    pcall(function()
                        self:RefreshActiveKeybinds()
                    end)
                    pcall(function()
                        self:UpdateActions()
                    end)
                end
            end,
            function()
                return self.textSearchHeaderControl ~= nil
            end
        ),
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
end
