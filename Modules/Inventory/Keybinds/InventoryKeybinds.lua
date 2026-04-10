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

local GetItemLinkItemType = GetItemLinkItemType
local GetItemLinkSetInfo = GetItemLinkSetInfo
local GetItemLinkEnchantInfo = GetItemLinkEnchantInfo
local IsItemBound = IsItemBound
local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
local GetItemFont = BETTERUI.Inventory.CONST.GetItemFont
local WouldEquipmentBeHidden = WouldEquipmentBeHidden
local FindActionSlotMatchingItem = FindActionSlotMatchingItem
local FindActionSlotMatchingSimpleAction = FindActionSlotMatchingSimpleAction
local ACTION_TYPE_QUEST_ITEM = ACTION_TYPE_QUEST_ITEM
local PRIMARY_ACTION_TRANSITION_WINDOW_MS = 250
local PRIMARY_ACTION_EQUIP_TRANSITION_WINDOW_MS = 700

local function GetNowMilliseconds()
    return GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
end

local function NormalizeActionName(actionName)
    if type(actionName) ~= "string" then
        return actionName
    end
    if actionName == "" then
        return nil
    end
    return actionName
end

local function ResolvePrimaryActionState(self)
    if not self or not self.itemActions then
        return nil, nil
    end

    local slotActions = self.itemActions.slotActions
    local actionName = NormalizeActionName(self.itemActions.actionName)
    if not actionName and slotActions and slotActions.GetPrimaryActionName then
        actionName = NormalizeActionName(slotActions:GetPrimaryActionName())
    end
    if not actionName and slotActions then
        actionName = NormalizeActionName(slotActions._betterui_primaryName)
    end
    return actionName, slotActions
end

local function ClearStalePrimaryOverride(slotActions)
    if not slotActions then
        return
    end
    if slotActions._betterui_primaryOverride and not NormalizeActionName(slotActions._betterui_primaryName) then
        slotActions._betterui_primaryOverride = nil
        slotActions._betterui_primaryName = nil
    end
end

local function ResolveMultiSelectActionName(self, target, isCraftBag, afterToggle)
    if not self then
        return nil
    end
    local manager = isCraftBag and self.craftBagMultiSelectManager or self.multiSelectManager
    if not manager then
        return nil
    end

    local isSelected = target and manager:IsSelected(target) or false
    if afterToggle then
        isSelected = not isSelected
    end
    if isSelected then
        return GetString(SI_BETTERUI_DESELECT_ITEM)
    end

    local count = manager.GetSelectedCount and manager:GetSelectedCount() or 0
    if afterToggle and target then
        local currentlySelected = manager:IsSelected(target)
        if currentlySelected then
            count = math.max(0, count - 1)
        else
            count = count + 1
        end
    end
    return zo_strformat(GetString(SI_BETTERUI_SELECT_WITH_COUNT), count)
end

local function IsPrimaryActionTransitionActive(self)
    if not self or not self._primaryActionTransitionExpiresMs then
        return false
    end
    return GetNowMilliseconds() <= self._primaryActionTransitionExpiresMs
end

local function GetPrimaryActionTransitionWindowMs(actionName)
    local equipName = GetString(SI_ITEM_ACTION_EQUIP)
    local unequipName = GetString(SI_ITEM_ACTION_UNEQUIP)
    if actionName == equipName or actionName == unequipName then
        return PRIMARY_ACTION_EQUIP_TRANSITION_WINDOW_MS
    end
    return PRIMARY_ACTION_TRANSITION_WINDOW_MS
end

local function StartPrimaryActionTransition(self, actionName)
    if not self then return end
    local resolvedActionName = NormalizeActionName(actionName)
    if not resolvedActionName then
        resolvedActionName = select(1, ResolvePrimaryActionState(self))
    end
    if not resolvedActionName then
        resolvedActionName = NormalizeActionName(self._lastResolvedPrimaryActionName)
    end
    if resolvedActionName then
        self._primaryActionTransitionName = resolvedActionName
        self._lastResolvedPrimaryActionName = resolvedActionName
    end
    self._primaryActionTransitionExpiresMs = GetNowMilliseconds() + GetPrimaryActionTransitionWindowMs(resolvedActionName)
end


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
    -- Accept both standard quickslot items and quest quickslot items
    -- (matches ESO's native ZO_InventorySlot_CanQuickslotItem eligibility)
    if ZO_InventoryUtils_DoesNewItemMatchFilterType then
        if ZO_InventoryUtils_DoesNewItemMatchFilterType(sd, ITEMFILTERTYPE_QUICKSLOT) then
            return true
        end
        if ITEMFILTERTYPE_QUEST_QUICKSLOT
            and ZO_InventoryUtils_DoesNewItemMatchFilterType(sd, ITEMFILTERTYPE_QUEST_QUICKSLOT)
        then
            return true
        end
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

--- Returns the active list that drives the Y-button actions dialog.
--- @param self table Inventory instance
--- @return table|nil list
local function GetActionsTargetList(self)
    if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        return self.craftBagList
    end
    if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        return self.itemList
    end
    return nil
end

--- Validates that the current actions target is in a stable selected state.
--- Prevents ShowActions() while parametric lists are temporarily at selectedIndex 0
--- during rapid refresh/abort transitions.
--- @param self table Inventory instance
--- @return boolean valid
local function HasStableActionsTarget(self)
    local targetList = GetActionsTargetList(self)
    if not targetList then
        return false
    end

    local targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(targetList)
    if not targetData then
        return false
    end

    local innerList = targetList.list or (targetList.GetParametricList and targetList:GetParametricList()) or targetList
    if not innerList then
        return false
    end

    local selectedIndex = innerList.selectedIndex
    if type(selectedIndex) ~= "number" or selectedIndex < 1 then
        return false
    end

    local dataList = innerList.dataList
    if dataList and selectedIndex > #dataList then
        return false
    end

    return true
end

local function IsBagUpgradeAvailable()
    local currentUnlock = (GetCurrentBackpackUpgrade and GetCurrentBackpackUpgrade()) or 0
    local maxUnlock = (GetMaxBackpackUpgrade and GetMaxBackpackUpgrade()) or currentUnlock
    return currentUnlock < maxUnlock
end

local function IsBagUpgradeCategorySelected(self)
    local selectedCategory = self and self.categoryList and self.categoryList.selectedData
    return selectedCategory and selectedCategory.isBagSpaceEntry == true and IsBagUpgradeAvailable()
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
        -- Apply shared mixin with Inventory-specific hooks
        BETTERUI.CIM.MultiSelectMixin.Apply(self, {
            getList = function(s) return s.itemList end,
            refreshList = function(s) s:RefreshItemList() end,
            isSceneShowing = function()
                return BETTERUI.CIM.Utils.IsInventorySceneShowing()
            end,
            getSceneExitLabel = function()
                return GetString(SI_BETTERUI_SCENE_INVENTORY)
            end,
            refreshKeybinds = function(s)
                if s.isInHeaderSortMode then
                    return
                end

                -- During batch execution, the Inventory refresh guard intentionally
                -- skips full keybind rebuilds. We still need immediate label updates
                -- (e.g., Y -> Abort Action), so update the active group directly.
                if s:IsBatchProcessing() then
                    if s.mainKeybindStripDescriptor then
                        KEYBIND_STRIP:UpdateKeybindButtonGroup(s.mainKeybindStripDescriptor)
                    end
                    return
                end

                s:RefreshKeybinds()
            end,
        })
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

                if IsBagUpgradeCategorySelected(self) then
                    return GetString(SI_INVENTORY_BAG_UPGRADE_LABEL)
                end

                -- Use SafeGetTargetData for consistent access (handles inner list structure)
                local target
                if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                else
                    target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                end

                -- If in multi-select mode, show "Unselect" or "Select (count)"
                -- Check inventory multi-select manager
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    if not target and self.itemList then
                        target = self.itemList.selectedData
                    end
                    -- Quest items cannot be selected in multi-select mode
                    if target and ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST) then
                        return ""
                    end
                    local multiSelectActionName = ResolveMultiSelectActionName(self, target, false, false)
                    if multiSelectActionName then
                        self._lastResolvedPrimaryActionName = multiSelectActionName
                    end
                    return multiSelectActionName or ""
                end
                -- Check craftbag multi-select manager
                if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
                    local multiSelectActionName = ResolveMultiSelectActionName(self, target, true, false)
                    if multiSelectActionName then
                        self._lastResolvedPrimaryActionName = multiSelectActionName
                    end
                    return multiSelectActionName or ""
                end

                -- During an active transition, hold the label stable to prevent
                -- intermediate action names (e.g., "Destroy") from flashing
                -- while itemActions refreshes after an action.
                if IsPrimaryActionTransitionActive(self) and self._primaryActionTransitionName then
                    return self._primaryActionTransitionName
                end

                -- Use itemActions for proper action name discovery (Equip/Unequip/Use/Retrieve/etc.)
                local baseName = select(1, ResolvePrimaryActionState(self))
                if not baseName then
                    -- Fallback logic if itemActions not ready or target not yet selected
                    if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                        -- Craft Bag items always default to "Retrieve"
                        baseName = GetString(SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG)
                    elseif target and target.bagId and target.slotIndex and IsEquipable(target.bagId, target.slotIndex) then
                        baseName = GetString(SI_ITEM_ACTION_EQUIP)
                    elseif target then
                        baseName = GetString(SI_ITEM_ACTION_USE)
                    else
                        baseName = GetString(SI_ITEM_ACTION_USE)
                    end
                end

                baseName = NormalizeActionName(baseName)
                if baseName then
                    self._lastResolvedPrimaryActionName = baseName
                end
                return baseName
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                if self:IsBatchProcessing() then
                    return false
                end
                if self.actionMode ~= BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE
                    and self.actionMode ~= BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    return false
                end
                if IsPrimaryActionTransitionActive(self) then
                    return true
                end
                if IsBagUpgradeCategorySelected(self) then
                    return true
                end
                -- Hide A-button when in multi-select and targeting a quest item
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    local target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                    if not target and self.itemList then
                        target = self.itemList.selectedData
                    end
                    if target and ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST) then
                        return false
                    end
                    return true
                end
                if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
                    return true
                end
                -- Check itemActions visibility if available
                if self.itemActions and self.itemActions.slotActions then
                    local visible = self.itemActions.slotActions:CheckPrimaryActionVisibility()
                    if visible then
                        return true
                    end
                    if IsPrimaryActionTransitionActive(self) then
                        return true
                    end
                end
                -- Fallback: visible if we have selected data (use SafeGetTargetData for consistency)
                if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    if BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList) ~= nil then
                        return true
                    end
                    return IsPrimaryActionTransitionActive(self)
                end
                if BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList) ~= nil then
                    return true
                end
                return IsPrimaryActionTransitionActive(self)
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end

                if IsBagUpgradeCategorySelected(self) then
                    ZO_Dialogs_ShowGamepadDialog("BUY_BAG_SPACE_FROM_INVENTORY_GAMEPAD",
                        { cost = GetNextBackpackUpgradePrice() })
                    return
                end

                -- Check craftbag multi-select first
                if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
                    local target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                    if target then
                        StartPrimaryActionTransition(self, ResolveMultiSelectActionName(self, target, true, true))
                        self.craftBagMultiSelectManager:ToggleSelection(target)
                        self:RefreshCraftBagList()
                    end
                    return
                end
                -- Check inventory multi-select
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    local target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                    if not target and self.itemList then
                        target = self.itemList.selectedData
                    end
                    if target then
                        StartPrimaryActionTransition(self, ResolveMultiSelectActionName(self, target, false, true))
                        self.multiSelectManager:ToggleSelection(target)
                        self:RefreshItemList()
                    end
                else
                    local actionName, slotActions = ResolvePrimaryActionState(self)

                    -- Defensive check: selected data can be stale right after a dialog closes.
                    local currentTarget = nil
                    if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                        currentTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                    elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                        currentTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                    end
                    -- No valid target means no safe primary action to invoke.
                    if not currentTarget then
                        return
                    end

                    -- Use itemActions to execute the discovered primary action
                    if self.itemActions and slotActions then
                        local function HasExecutablePrimaryAction(actions, expectedActionName)
                            if not actions then
                                return false
                            end

                            local overrideName = NormalizeActionName(actions._betterui_primaryName)
                            if type(actions._betterui_primaryOverride) == "function"
                                and overrideName
                                and (not expectedActionName or expectedActionName == overrideName) then
                                return true
                            end

                            if not actions.m_slotActions or #actions.m_slotActions == 0 then
                                return false
                            end

                            if expectedActionName then
                                for i = 1, #actions.m_slotActions do
                                    local actionEntry = actions.m_slotActions[i]
                                    if actionEntry and actionEntry[1] == expectedActionName and type(actionEntry[2]) == "function" then
                                        return true
                                    end
                                end
                            end

                            local primaryActionName = NormalizeActionName(actions:GetPrimaryActionName())
                            if primaryActionName then
                                for i = 1, #actions.m_slotActions do
                                    local actionEntry = actions.m_slotActions[i]
                                    if actionEntry and actionEntry[1] == primaryActionName and type(actionEntry[2]) == "function" then
                                        return true
                                    end
                                end
                            end

                            local firstAction = actions.m_slotActions[1]
                            return firstAction and type(firstAction[2]) == "function"
                        end

                        local function ExecutePrimaryAction(actions, expectedActionName)
                            if not HasExecutablePrimaryAction(actions, expectedActionName) then
                                return false
                            end

                            local overrideName = NormalizeActionName(actions._betterui_primaryName)
                            if type(actions._betterui_primaryOverride) == "function"
                                and overrideName
                                and (not expectedActionName or expectedActionName == overrideName) then
                                actions._betterui_primaryOverride()
                            else
                                actions:DoPrimaryAction()
                            end
                            return true
                        end

                        if not actionName then
                            ClearStalePrimaryOverride(slotActions)
                            if self.RefreshItemActions then
                                self:RefreshItemActions()
                            end
                            actionName, slotActions = ResolvePrimaryActionState(self)
                        end

                        if not actionName or not slotActions then
                            return
                        end

                        StartPrimaryActionTransition(self, actionName)
                        local overrideName = NormalizeActionName(slotActions._betterui_primaryName)
                        if type(slotActions._betterui_primaryOverride) == "function"
                            and overrideName
                            and overrideName == actionName then
                            slotActions._betterui_primaryOverride()
                        elseif actionName == GetString(SI_ITEM_ACTION_USE)
                            or actionName == GetString(SI_ITEM_ACTION_SHOW_MAP)
                            or actionName == GetString(SI_ITEM_ACTION_START_SKILL_RESPEC)
                            or actionName == GetString(SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC) then
                            local target
                            if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                                target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                            elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                                target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                            end

                            if target then
                                local ds = target.dataSource or target
                                local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType and
                                ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)
                                if isQuestItem and ds.toolIndex then
                                    UseQuestTool(ds.questIndex, ds.toolIndex)
                                elseif isQuestItem and ds.stepIndex and ds.conditionIndex then
                                    UseQuestItem(ds.questIndex, ds.stepIndex, ds.conditionIndex)
                                else
                                    local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
                                    if bag and slot then
                                        CallSecureProtected("UseItem", bag, slot)
                                    end
                                end
                            end
                        elseif actionName == GetString(SI_ITEM_ACTION_PLACE_FURNITURE) then
                            local ds = currentTarget.dataSource or currentTarget
                            local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
                            if bag and slot and ZO_CanPlaceItemInCurrentHouse(bag, slot) then
                                ZO_TryPlaceFurnitureFromInventorySlot(bag, slot)
                            end
                        else
                            if ExecutePrimaryAction(slotActions, actionName) then
                                return
                            end

                            if self.RefreshItemActions then
                                self:RefreshItemActions()
                            end
                            actionName, slotActions = ResolvePrimaryActionState(self)
                            if actionName and slotActions then
                                StartPrimaryActionTransition(self, actionName)
                                ExecutePrimaryAction(slotActions, actionName)
                            else
                                ClearStalePrimaryOverride(slotActions)
                            end
                        end
                    else
                        -- Fallback: direct equip/use if itemActions not available
                        StartPrimaryActionTransition(self, actionName)
                        local target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                        if not target and self.itemList then
                            target = self.itemList.selectedData
                        end
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
                -- During an active primary action transition, hold the X-button label
                -- stable to prevent stale slot data from resolving the wrong label
                -- (e.g., "Link to Chat" flashing during equip/unequip).
                if IsPrimaryActionTransitionActive(self) and self._lastSecondaryActionName then
                    return self._lastSecondaryActionName
                end

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
                        local hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                        local slotNum = nil
                        if isQuestItem then
                            local questItemId
                            if target.toolIndex then
                                questItemId = GetQuestToolQuestItemId(target.questIndex, target.toolIndex)
                            else
                                questItemId = GetQuestConditionQuestItemId(target.questIndex, target.stepIndex,
                                    target.conditionIndex)
                            end
                            slotNum = FindActionSlotMatchingSimpleAction(ACTION_TYPE_QUEST_ITEM, questItemId,
                                hotbarCategory)
                        else
                            slotNum = FindActionSlotMatchingItem(target.bagId, target.slotIndex, hotbarCategory)
                        end
                        if slotNum then
                            -- Already slotted, label as "Unassign"
                            n = GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_UNASSIGN)
                        else
                            -- Not slotted, label as "Assign"
                            n = GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN)
                        end
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
                n = n or ""
                if n ~= "" then
                    self._lastSecondaryActionName = n
                end
                return n
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            -- (no hold callbacks here; tap behavior preserved)
            visible = function()
                if self:IsBatchProcessing() then
                    return false
                end
                if self.itemActions and self.itemActions.actionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
                    return false
                end
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
                if self:IsBatchProcessing() then
                    return
                end

                if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    --bag mode
                    local target = self.itemList.selectedData
                    local ft = (target and target.bagId and target.slotIndex)
                        and GetItemFilterTypeInfo(target.bagId, target.slotIndex)
                        or nil
                    if IsQuickslottable(target) then
                        local hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                        local slotNum = nil

                        if ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST) then
                            local questItemId
                            if target.toolIndex then
                                questItemId = GetQuestToolQuestItemId(target.questIndex, target.toolIndex)
                            else
                                questItemId = GetQuestConditionQuestItemId(target.questIndex, target.stepIndex,
                                    target.conditionIndex)
                            end
                            slotNum = FindActionSlotMatchingSimpleAction(ACTION_TYPE_QUEST_ITEM, questItemId,
                                hotbarCategory)
                        else
                            slotNum = FindActionSlotMatchingItem(target.bagId, target.slotIndex, hotbarCategory)
                        end

                        if slotNum then
                            -- Quick Unassign: clear the slot securely without opening the wheel
                            CallSecureProtected("ClearSlot", slotNum, hotbarCategory)
                            if SOUNDS and PlaySound then
                                PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
                            end
                            -- Use the transition mechanism to hold the X-button label stable
                            -- while the list rebuilds after quickslot unassign.
                            StartPrimaryActionTransition(self, nil)
                            if target and target.uniqueId then
                                self._preserveUniqueId = target.uniqueId
                            end

                            local function RefreshAfterQuickslotUnassign()
                                if self.control and self.control.IsHidden and self.control:IsHidden() then
                                    return
                                end
                                if self.actionMode ~= BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                                    return
                                end
                                if target and target.bagId and target.slotIndex and self.InvalidateItemMeta then
                                    self:InvalidateItemMeta(target.bagId, target.slotIndex)
                                end
                                if self.InvalidateSlotDataCache then
                                    self:InvalidateSlotDataCache()
                                end
                                self:RefreshKeybinds()
                                self:RefreshItemList()
                            end

                            -- Refresh immediately for responsiveness, then once more
                            -- after the secure clear settles so icon/button state
                            -- reflects the now-unassigned slot without reselection.
                            RefreshAfterQuickslotUnassign()
                            if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Schedule then
                                BETTERUI.Inventory.Tasks:Schedule("quickslotUnassignRefresh", 80,
                                    RefreshAfterQuickslotUnassign)
                            else
                                zo_callLater(RefreshAfterQuickslotUnassign, 80)
                            end
                        else
                            -- Not slotted, open the native quickslot wheel
                            -- Must use zo_callLater to break the callstack
                            zo_callLater(function() self:ShowQuickslot() end, 50)
                        end
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
                            -- UseQuestTool and UseQuestItem are NOT protected functions - call directly
                            -- Do NOT hide the scene — ESO handles scene transitions automatically
                            if ds.toolIndex then
                                UseQuestTool(ds.questIndex, ds.toolIndex)
                            elseif ds.stepIndex and ds.conditionIndex then
                                UseQuestItem(ds.questIndex, ds.stepIndex, ds.conditionIndex)
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
                if self:IsBatchProcessing() then
                    return GetString(SI_BETTERUI_ABORT_ACTION)
                end

                -- Always show "Actions" - the selected count is now on the A button
                return GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND)
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                if self:IsBatchProcessing() then
                    return true
                end

                -- Check craftbag multi-select manager first
                if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
                    return self.craftBagMultiSelectManager:HasSelections()
                end
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    return self.multiSelectManager:HasSelections()
                end

                return HasStableActionsTarget(self)
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    self:RequestBatchAbort()
                    return
                end

                -- Check craftbag multi-select manager first
                if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
                    self:ShowCraftBagBatchActionsMenu()
                    return
                end
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    -- Show batch actions dialog
                    self:ShowBatchActionsMenu()
                else
                    if not HasStableActionsTarget(self) then
                        return
                    end

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
                    and not IsBagUpgradeCategorySelected(self)
                    and not self:IsBatchProcessing()
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
            visible = function()
                return not self:IsBatchProcessing() and not IsBagUpgradeCategorySelected(self)
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end
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
                if self:IsBatchProcessing() then
                    return false
                end
                -- Visible in item list mode with items
                if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                    -- Hide for quest category (quest items can't be batch-operated)
                    local catData = self.categoryList and self.categoryList.selectedData
                    if catData and catData.filterType == ITEMFILTERTYPE_QUEST then
                        return false
                    end
                    return self.itemList and not self.itemList:IsEmpty()
                        and self.multiSelectManager ~= nil
                        and not self.multiSelectManager:IsActive()
                end
                -- Also visible in craftbag mode with items
                if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    return self.craftBagList and not self.craftBagList:IsEmpty()
                        and self.craftBagMultiSelectManager ~= nil
                        and not self.craftBagMultiSelectManager:IsActive()
                end
                return false
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end
                -- Enter appropriate selection mode based on current list
                if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
                    if self.craftBagMultiSelectManager and not self.craftBagMultiSelectManager:IsActive() then
                        self:EnterCraftBagSelectionMode()
                    end
                elseif self.multiSelectManager and not self.multiSelectManager:IsActive() then
                    self:EnterSelectionMode()
                end
            end,
        },
    }

    local leftTrigger, rightTrigger = BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(
        function()
            local currentList = self:GetCurrentList()
            if currentList == self.itemList or currentList == self.craftBagList then
                return currentList
            end
        end,
        nil,
        function() return BETTERUI.Inventory.GetSetting("triggerSpeed") end,
        function() return BETTERUI.Inventory.GetSetting("useTriggersForSkip") end
    )
    table.insert(self.mainKeybindStripDescriptor, leftTrigger)
    table.insert(self.mainKeybindStripDescriptor, rightTrigger)

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
end
