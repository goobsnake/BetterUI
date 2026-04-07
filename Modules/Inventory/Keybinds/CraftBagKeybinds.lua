--[[
File: Modules/Inventory/Keybinds/CraftBagKeybinds.lua
Purpose: Hosts craft bag and cross-list keybind helpers used by the
         main inventory keybind strip.
]]

local InventoryKeybinds = BETTERUI.Inventory.Keybinds
local InventoryConst = BETTERUI.Inventory.CONST
local InventoryUtils = BETTERUI.Inventory.Utils

local function IsBagUpgradeAvailable()
    local currentUnlock = (GetCurrentBackpackUpgrade and GetCurrentBackpackUpgrade()) or 0
    local maxUnlock = (GetMaxBackpackUpgrade and GetMaxBackpackUpgrade()) or currentUnlock
    return currentUnlock < maxUnlock
end

local function IsBagUpgradeCategorySelected(self)
    local selectedCategory = self and self.categoryList and self.categoryList.selectedData
    return selectedCategory and selectedCategory.isBagSpaceEntry == true and IsBagUpgradeAvailable()
end

local function GetCurrentTarget(self)
    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        return InventoryUtils.SafeGetTargetData(self.craftBagList)
    end
    if self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE then
        return InventoryUtils.SafeGetTargetData(self.itemList)
    end
    return nil
end

local function GetQuestItemId(target)
    if not target then
        return nil
    end

    if target.toolIndex then
        return GetQuestToolQuestItemId(target.questIndex, target.toolIndex)
    end

    if target.stepIndex and target.conditionIndex then
        return GetQuestConditionQuestItemId(target.questIndex, target.stepIndex, target.conditionIndex)
    end

    return nil
end

local function GetAssignedQuickslot(target, isQuestItem)
    if not target then
        return nil
    end

    local hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    if isQuestItem then
        local questItemId = GetQuestItemId(target)
        if questItemId then
            return FindActionSlotMatchingSimpleAction(ACTION_TYPE_QUEST_ITEM, questItemId, hotbarCategory)
        end
        return nil
    end

    return FindActionSlotMatchingItem(target.bagId, target.slotIndex, hotbarCategory)
end

local function ExecuteTargetUse(target)
    if not target then
        return
    end

    local dataSource = target.dataSource or target
    local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType
        and ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)

    if isQuestItem and dataSource.toolIndex then
        UseQuestTool(dataSource.questIndex, dataSource.toolIndex)
        return
    end

    if isQuestItem and dataSource.stepIndex and dataSource.conditionIndex then
        UseQuestItem(dataSource.questIndex, dataSource.stepIndex, dataSource.conditionIndex)
        return
    end

    local bag, slot = ZO_Inventory_GetBagAndIndex(dataSource)
    if bag and slot then
        CallSecureProtected("UseItem", bag, slot)
    end
end

local function InsertTargetLink(target)
    if not target then
        return
    end

    local dataSource = target.dataSource or target
    local bag, slot = ZO_Inventory_GetBagAndIndex(dataSource)
    if not (bag and slot) then
        return
    end

    local itemLink = GetItemLink(bag, slot)
    if itemLink then
        ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
    end
end

---@param self table Inventory class instance
---@return table|nil targetList The active list for the current action mode
function InventoryKeybinds.GetActionsTargetList(self)
    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        return self.craftBagList
    end
    if self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE then
        return self.itemList
    end
    return nil
end

---@param self table Inventory class instance
---@return boolean hasTarget Whether a valid actions target exists
function InventoryKeybinds.HasStableActionsTarget(self)
    local targetList = InventoryKeybinds.GetActionsTargetList(self)
    if not targetList then
        return false
    end

    local targetData = InventoryUtils.SafeGetTargetData(targetList)
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

InventoryKeybinds.IsBagUpgradeCategorySelected = IsBagUpgradeCategorySelected

---@param self table Inventory class instance
---@return string name Localized keybind label for primary action
function InventoryKeybinds.GetPrimaryKeybindName(self)
    if self.actionMode ~= InventoryConst.ITEM_LIST_ACTION_MODE
        and self.actionMode ~= InventoryConst.CRAFT_BAG_ACTION_MODE then
        return ""
    end

    if IsBagUpgradeCategorySelected(self) then
        return GetString(SI_INVENTORY_BAG_UPGRADE_LABEL)
    end

    local target = GetCurrentTarget(self)

    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        if target and ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST) then
            return ""
        end
        if target and self.multiSelectManager:IsSelected(target) then
            return GetString(rawget(_G, "SI_BETTERUI_DESELECT_ITEM"))
        end
        local count = self.multiSelectManager:GetSelectedCount()
        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_SELECT_WITH_COUNT")), count)
    end

    if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
        if target and self.craftBagMultiSelectManager:IsSelected(target) then
            return GetString(rawget(_G, "SI_BETTERUI_DESELECT_ITEM"))
        end
        local count = self.craftBagMultiSelectManager:GetSelectedCount()
        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_SELECT_WITH_COUNT")), count)
    end

    if self.itemActions and self.itemActions.actionName then
        return self.itemActions.actionName
    end

    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        return GetString(rawget(_G, "SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG"))
    end

    if target and target.bagId and target.slotIndex and IsEquipable(target.bagId, target.slotIndex) then
        return GetString(rawget(_G, "SI_ITEM_ACTION_EQUIP"))
    end

    return GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
end

---@param self table Inventory class instance
---@return boolean visible Whether the primary keybind should be shown
function InventoryKeybinds.IsPrimaryKeybindVisible(self)
    if self:IsBatchProcessing() then
        return false
    end

    if self.actionMode ~= InventoryConst.ITEM_LIST_ACTION_MODE
        and self.actionMode ~= InventoryConst.CRAFT_BAG_ACTION_MODE then
        return false
    end

    if IsBagUpgradeCategorySelected(self) then
        return true
    end

    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        local target = self.itemList and self.itemList.selectedData
        if target and ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST) then
            return false
        end
    end

    if self.itemActions and self.itemActions.slotActions and not self.itemActions.actionName then
        return false
    end

    if self.itemActions and self.itemActions.slotActions then
        return self.itemActions.slotActions:CheckPrimaryActionVisibility()
    end

    return GetCurrentTarget(self) ~= nil
end

---@param self table Inventory class instance
---@return nil
function InventoryKeybinds.HandlePrimaryKeybind(self)
    if self:IsBatchProcessing() then
        return
    end

    if IsBagUpgradeCategorySelected(self) then
        ZO_Dialogs_ShowGamepadDialog("BUY_BAG_SPACE_FROM_INVENTORY_GAMEPAD", { cost = GetNextBackpackUpgradePrice() })
        return
    end

    if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
        local target = InventoryUtils.SafeGetTargetData(self.craftBagList)
        if target then
            self.craftBagMultiSelectManager:ToggleSelection(target)
            self:RefreshCraftBagList()
        end
        return
    end

    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        local target = self.itemList and self.itemList.selectedData
        if target then
            self.multiSelectManager:ToggleSelection(target)
            self:RefreshItemList()
        end
        return
    end

    local actionName
    if self.itemActions then
        actionName = self.itemActions.actionName
        self.itemActions.actionName = nil
    end

    if self.itemActions and self.itemActions.slotActions then
        local slotActions = self.itemActions.slotActions
        if slotActions._betterui_primaryOverride then
            slotActions._betterui_primaryOverride()
        elseif actionName == GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
            or actionName == GetString(rawget(_G, "SI_ITEM_ACTION_SHOW_MAP"))
            or actionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_SKILL_RESPEC"))
            or actionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC")) then
            ExecuteTargetUse(GetCurrentTarget(self))
        else
            slotActions:DoPrimaryAction()
        end
        return
    end

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

---@param self table Inventory class instance
---@return string name Localized keybind label for secondary action
function InventoryKeybinds.GetSecondaryKeybindName(self)
    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        return GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
    end

    local actionContext = InventoryKeybinds.GetXButtonActionContext(self)
    if not actionContext then
        return ""
    end

    if actionContext.isQuickslottable then
        local slotNum = GetAssignedQuickslot(actionContext.target, actionContext.isQuestItem)
        if slotNum then
            return GetString(rawget(_G, "SI_BETTERUI_INV_ACTION_QUICKSLOT_UNASSIGN"))
        end
        return GetString(rawget(_G, "SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN"))
    end

    if not actionContext.isQuestItem and actionContext.isEquipment then
        return GetString(rawget(_G, "SI_BETTERUI_INV_SWITCH_INFO"))
    end

    if actionContext.isUsableQuest then
        return GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
    end

    return GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
end

---@param self table Inventory class instance
---@return boolean visible Whether the secondary keybind should be shown
function InventoryKeybinds.IsSecondaryKeybindVisible(self)
    if self:IsBatchProcessing() then
        return false
    end

    if self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE then
        local actionContext = InventoryKeybinds.GetXButtonActionContext(self)
        if not actionContext then
            return false
        end
        return not actionContext.isQuestItem or actionContext.isUsableQuest
    end

    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        return true
    end

    return false
end

---@param self table Inventory class instance
---@return nil
function InventoryKeybinds.HandleSecondaryKeybind(self)
    if self:IsBatchProcessing() then
        return
    end

    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        InsertTargetLink(GetCurrentTarget(self))
        return
    end

    local actionContext = InventoryKeybinds.GetXButtonActionContext(self)
    if not actionContext then
        return
    end

    if actionContext.isQuickslottable then
        local hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
        local slotNum = GetAssignedQuickslot(actionContext.target, actionContext.isQuestItem)

        if slotNum then
            CallSecureProtected("ClearSlot", slotNum, hotbarCategory)
            if SOUNDS and PlaySound then
                PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
            end

            local preserveId = actionContext.target and actionContext.target.uniqueId
            zo_callLater(function()
                if self.RefreshKeybinds and self.itemList then
                    if preserveId then
                        self._preserveUniqueId = preserveId
                    end
                    self:RefreshKeybinds()
                    self:RefreshItemList()
                end
            end, 100)
        else
            zo_callLater(function()
                self:ShowQuickslot()
            end, 50)
        end
        return
    end

    if not actionContext.isQuestItem and actionContext.isEquipment then
        self:SwitchInfo()
        return
    end

    if actionContext.isUsableQuest then
        ExecuteTargetUse(actionContext.target)
        return
    end

    InsertTargetLink(actionContext.target)
end

---@param self table Inventory class instance
---@return boolean visible Whether the tertiary keybind should be shown
function InventoryKeybinds.IsTertiaryKeybindVisible(self)
    if self:IsBatchProcessing() then
        return true
    end

    if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
        return self.craftBagMultiSelectManager:HasSelections()
    end

    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        return self.multiSelectManager:HasSelections()
    end

    return InventoryKeybinds.HasStableActionsTarget(self)
end

---@param self table Inventory class instance
---@return nil
function InventoryKeybinds.HandleTertiaryKeybind(self)
    if self:IsBatchProcessing() then
        self:RequestBatchAbort()
        return
    end

    if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
        self:ShowCraftBagBatchActionsMenu()
        return
    end

    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        self:ShowBatchActionsMenu()
        return
    end

    if not InventoryKeybinds.HasStableActionsTarget(self) then
        return
    end

    self:SaveListPosition()
    self:ShowActions()
end

---@param self table Inventory class instance
---@return boolean visible Whether the multi-select entry keybind should be shown
function InventoryKeybinds.IsMultiSelectEntryVisible(self)
    if self:IsBatchProcessing() then
        return false
    end

    if self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE then
        local categoryData = self.categoryList and self.categoryList.selectedData
        if categoryData and categoryData.filterType == ITEMFILTERTYPE_QUEST then
            return false
        end

        return self.itemList and not self.itemList:IsEmpty()
            and self.multiSelectManager ~= nil
            and not self.multiSelectManager:IsActive()
    end

    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        return self.craftBagList and not self.craftBagList:IsEmpty()
            and self.craftBagMultiSelectManager ~= nil
            and not self.craftBagMultiSelectManager:IsActive()
    end

    return false
end

---@param self table Inventory class instance
---@return nil
function InventoryKeybinds.HandleMultiSelectEntry(self)
    if self:IsBatchProcessing() then
        return
    end

    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        if self.craftBagMultiSelectManager and not self.craftBagMultiSelectManager:IsActive() then
            self:EnterCraftBagSelectionMode()
        end
        return
    end

    if self.multiSelectManager and not self.multiSelectManager:IsActive() then
        self:EnterSelectionMode()
    end
end
