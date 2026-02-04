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

--[[
Function: GetXButtonActionContext
Description: Computes the action context for the X-button keybind.
Rationale: Eliminates redundant API calls by computing isQuickslottable, isQuestItem,
           and filterType once and reusing across name/visible/callback.
Mechanism: Retrieves target data and computes all relevant properties.
param: self (table) - The Inventory class instance.
return: table|nil - {target, isQuestItem, isQuickslottable, filterType, isEquipment, isUsableQuest}
]]
local function GetXButtonActionContext(self)
    if self.actionMode ~= BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        return nil
    end
    local target = self.itemList.selectedData
    if not target then return nil end

    local filterType = nil
    if target.bagId and target.slotIndex then
        filterType = GetItemFilterTypeInfo(target.bagId, target.slotIndex)
    end

    local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType
        and ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)
        or false

    local isEquipment = filterType == ITEMFILTERTYPE_WEAPONS
        or filterType == ITEMFILTERTYPE_ARMOR
        or filterType == ITEMFILTERTYPE_JEWELRY

    return {
        target = target,
        isQuestItem = isQuestItem,
        isQuickslottable = IsQuickslottable(target),
        filterType = filterType,
        isEquipment = isEquipment,
        isUsableQuest = isQuestItem and target.meetsUsageRequirement or false,
    }
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
    -- Initialize multi-select manager if not already done
    if not self.multiSelectManager then
        self.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(
            self.itemList,
            function(selectedCount)
                self:OnSelectionCountChanged(selectedCount)
            end
        )
    end

    self.mainKeybindStripDescriptor = {
        -- Primary (A) for Equip/Use/Retrieve actions
        -- Multi-Select entry is now via Y-Hold (QUINARY) button
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                if self.actionMode ~= BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE
                    and self.actionMode ~= BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    return ""
                end

                -- Use SafeGetTargetData for consistent access (handles inner list structure)
                local target
                if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                else
                    target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                end

                -- If in multi-select mode, show "Select"
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    return GetString(SI_BETTERUI_SELECT_ITEM)
                end

                -- Use itemActions for proper action name discovery (Equip/Unequip/Use/Retrieve/etc.)
                local baseName
                if self.itemActions and self.itemActions.actionName then
                    baseName = self.itemActions.actionName
                else
                    -- Fallback logic if itemActions not ready or target not yet selected
                    if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                        -- Craft Bag items always default to "Retrieve"
                        baseName = GetString(SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG)
                    elseif target and target.bagId and target.slotIndex and IsEquipable(target.bagId, target.slotIndex) then
                        baseName = GetString(SI_ITEM_ACTION_EQUIP)
                    elseif target then
                        baseName = GetString(SI_ITEM_ACTION_USE)
                    else
                        -- No target selected yet - show generic action
                        baseName = GetString(SI_ITEM_ACTION_USE)
                    end
                end

                return baseName
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                if self.actionMode ~= BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE
                    and self.actionMode ~= BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    return false
                end
                -- FLICKER FIX: Hide button during action transition when actionName cleared
                -- This prevents showing incorrect fallback text after equip/unequip
                if self.itemActions and self.itemActions.slotActions and not self.itemActions.actionName then
                    return false
                end
                -- Check itemActions visibility if available
                if self.itemActions and self.itemActions.slotActions then
                    return self.itemActions.slotActions:CheckPrimaryActionVisibility()
                end
                -- Fallback: visible if we have selected data (use SafeGetTargetData for consistency)
                if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    return BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList) ~= nil
                end
                return BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList) ~= nil
            end,
            callback = function()
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    -- In multi-select mode - toggle selection
                    local target = self.itemList and self.itemList.selectedData
                    if target then
                        self.multiSelectManager:ToggleSelection(target)
                        self:RefreshItemList()
                    end
                else
                    -- FLICKER FIX: Clear stale action name BEFORE executing action
                    -- This prevents fallback logic from showing incorrect text (e.g. "Use" instead of "Unequip")
                    if self.itemActions then
                        self.itemActions.actionName = nil
                    end

                    -- Use itemActions to execute the discovered primary action
                    if self.itemActions and self.itemActions.slotActions then
                        local slotActions = self.itemActions.slotActions
                        if slotActions._betterui_primaryOverride then
                            slotActions._betterui_primaryOverride()
                        else
                            slotActions:DoPrimaryAction()
                        end
                    else
                        -- Fallback: direct equip/use if itemActions not available
                        local target = self.itemList and self.itemList.selectedData
                        if target and target.bagId and target.slotIndex then
                            if IsEquipable(target.bagId, target.slotIndex) then
                                local inventorySlot = target.dataSource and target or { dataSource = target }
                                self:TryEquipItem(inventorySlot, false)
                            else
                                CallSecureProtected("UseItem", target.bagId, target.slotIndex)
                            end
                        end
                    end
                end
            end,
        },
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
        -- Y Button for Actions or Batch Actions in selection mode
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    local count = self.multiSelectManager:GetSelectedCount()
                    return zo_strformat(GetString(SI_BETTERUI_SELECTED_COUNT), count)
                end
                return GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND)
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    return self.multiSelectManager:HasSelections()
                end
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
            end,
            callback = function()
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    -- Show batch actions dialog
                    self:ShowBatchActionsMenu()
                else
                    -- Normal Y menu
                    self:SaveListPosition()
                    self:ShowActions()
                end
            end,
        },
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
        -- Only visible when search has text
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
                    -- Skip if in header sort mode
                    if not self.isInHeaderSortMode then
                        self:RefreshKeybinds()
                    end
                end
            end,
            function()
                return self.textSearchHeaderControl ~= nil
            end,
            function()
                -- Only show Clear Search when there is actually text to clear
                return self.searchQuery and self.searchQuery ~= ""
            end
        ),
        -- Y-Hold (QUINARY) for Multi-Select Mode
        -- Dedicated entry point for multi-select functionality
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = GetString(SI_BETTERUI_MULTI_SELECT),
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                -- Only visible in item list mode (not craft bag) with items
                -- Multi-select is only supported for regular inventory items
                if self.actionMode ~= BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    return false
                end
                -- Must have items in the list and multi-select manager available
                return self.itemList and not self.itemList:IsEmpty()
                    and self.multiSelectManager ~= nil
                    and not self.multiSelectManager:IsActive()
            end,
            callback = function()
                if self.multiSelectManager and not self.multiSelectManager:IsActive() then
                    self:EnterSelectionMode()
                end
            end,
        },
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
end
