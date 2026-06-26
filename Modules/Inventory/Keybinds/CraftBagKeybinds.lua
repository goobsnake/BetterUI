local InventoryKeybinds = BETTERUI.Inventory.Keybinds
local InventoryConst = BETTERUI.Inventory.CONST
local InventoryUtils = BETTERUI.Inventory.Utils
local PRIMARY_ACTION_TRANSITION_WINDOW_MS = 250
local PRIMARY_ACTION_EQUIP_TRANSITION_WINDOW_MS = 700

local function GetNowMilliseconds()
    return GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
end

local function NotifySecureActionFailed(context)
    local failedStringId = rawget(_G, "SI_BETTERUI_SECURE_ACTION_FAILED")
    BETTERUI.CIM.UserNotify(context,
        (failedStringId and GetString(failedStringId)) or "The action could not be completed.")
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
    return BETTERUI.CIM.Keybinds.GetMultiSelectToggleLabel(manager, target, afterToggle)
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
    if not self then
        return
    end
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

local function IsSecondaryActionTransitionActive(self)
    if not self or not self._secondaryActionTransitionName or not self._secondaryActionTransitionExpiresMs then
        return false
    end
    return GetNowMilliseconds() <= self._secondaryActionTransitionExpiresMs
end

local function StartSecondaryActionTransition(self, actionName)
    local resolvedActionName = NormalizeActionName(actionName)
    if not self or not resolvedActionName then
        return
    end
    self._secondaryActionTransitionName = resolvedActionName
    self._secondaryActionTransitionExpiresMs = GetNowMilliseconds() + PRIMARY_ACTION_TRANSITION_WINDOW_MS
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

local function GetCurrentTarget(self)
    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        return InventoryUtils.SafeGetTargetData(self.craftBagList)
    end
    if self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE then
        return InventoryUtils.SafeGetTargetData(self.itemList)
    end
    return nil
end

local function GetCurrentSceneName()
    local sceneManager = rawget(_G, "SCENE_MANAGER")
    if sceneManager and sceneManager.GetCurrentSceneName then
        local ok, sceneName = pcall(sceneManager.GetCurrentSceneName, sceneManager)
        if ok then
            return sceneName
        end
    end
    return nil
end

local function IsQuestTarget(target)
    if type(target) ~= "table" then
        return false
    end
    local dataSource = target and (target.dataSource or target) or nil
    if type(dataSource) ~= "table" then
        return false
    end

    if target.isQuestItem == true
        or dataSource.isQuestItem == true
        or dataSource.questIndex ~= nil
        or dataSource.slotType == SLOT_TYPE_QUEST_ITEM
        or target.slotType == SLOT_TYPE_QUEST_ITEM then
        return true
    end

    local uniqueId = dataSource.uniqueId or target.uniqueId
    return type(uniqueId) == "string" and uniqueId:find("^quest:") ~= nil
end

local function DescribeKeybindTarget(target)
    local L = BETTERUI.Log
    if L and L.DescribeItem and target then
        return L.DescribeItem(target.dataSource or target, "target")
    end
    return nil
end

local function TraceCraftBagSwitchVisibility(self, visible, reason, target)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then
        return
    end

    local sceneName = GetCurrentSceneName()
    local uniqueId = target and (target.uniqueId or (target.dataSource and target.dataSource.uniqueId)) or nil
    local traceKey = table.concat({
        tostring(visible == true),
        tostring(reason or ""),
        tostring(sceneName or ""),
        tostring(self and self.actionMode or ""),
        tostring(uniqueId or ""),
    }, "|")
    if self and self._betteruiCraftBagSwitchVisibilityTraceKey == traceKey then
        return
    end
    if self then
        self._betteruiCraftBagSwitchVisibilityTraceKey = traceKey
    end

    local data = {
        visible = visible == true,
        reason = reason,
        scene = sceneName,
        actionMode = self and self.actionMode,
        target = DescribeKeybindTarget(target),
    }

    if visible then
        L.TraceEvent(L.CATEGORY.KEYBIND, "inventory.craft_bag_switch_keybind", "visible", data)
    elseif reason == "questTarget" or reason == "sceneMismatch" then
        L.TraceEvent(L.CATEGORY.KEYBIND, "inventory.craft_bag_switch_keybind", "blocked", data)
    else
        L.TraceEvent(L.CATEGORY.KEYBIND, "inventory.craft_bag_switch_keybind", "hidden", data)
    end
end

local function ResolveQuestIndex(target)
    local dataSource = target and (target.dataSource or target) or nil
    return dataSource and dataSource.questIndex or nil
end

local function OpenQuestJournalForTarget(target, source)
    local questIndex = ResolveQuestIndex(target)
    local questJournal = SYSTEMS and SYSTEMS.GetObject and SYSTEMS:GetObject("questJournal") or nil
    local L = BETTERUI.Log
    local data = {
        source = source,
        questIndex = questIndex,
        hasJournal = questJournal ~= nil,
        target = DescribeKeybindTarget(target),
    }

    if L and L.TraceEvent then
        L.TraceEvent(L.CATEGORY.ACTION, "inventory.show_quest", "before", data, L.LEVEL.INFO)
    end

    if questJournal and questJournal.OpenQuestJournalToQuest and questIndex then
        questJournal:OpenQuestJournalToQuest(questIndex)
        if L and L.TraceEvent then
            data.dispatched = true
            L.TraceEvent(L.CATEGORY.ACTION, "inventory.show_quest", "after", data, L.LEVEL.INFO)
        end
        return true
    end

    local reason = not questJournal and "missingJournal" or "missingQuestIndex"
    data.reason = reason
    if L and L.Warn then
        L.Warn(L.CATEGORY.ACTION, "show quest in journal blocked", data)
    elseif L and L.TraceEvent then
        L.TraceEvent(L.CATEGORY.ACTION, "inventory.show_quest", "blocked", data, L.LEVEL.INFO)
    end
    return false, reason
end

--- A usable item on use-cooldown (e.g. a just-opened container) temporarily
--- loses its "Use" slot action, letting the next action (often "Mark as Junk")
--- float to primary. Pin the primary to "Use" while the cooldown runs so
--- spamming the key cannot junk or otherwise mutate the item unexpectedly.
---@param self table Inventory class instance
---@return string|nil useName Localized "Use" label when the pin applies
local function GetCooldownPinnedUseName(self)
    local target = GetCurrentTarget(self)
    local dataSource = target and (target.dataSource or target)
    if not (dataSource and dataSource.bagId and dataSource.slotIndex) then
        return nil
    end
    if not GetItemCooldownInfo then
        return nil
    end
    local remaining = GetItemCooldownInfo(dataSource.bagId, dataSource.slotIndex)
    if remaining and remaining > 0 then
        return GetString(SI_ITEM_ACTION_USE)
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
    local isQuestItem = IsQuestTarget(target)

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
        if not CallSecureProtected("UseItem", bag, slot) then
            NotifySecureActionFailed("CraftBagKeybinds:UseItem")
        end
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

    local itemLink = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
    if itemLink and itemLink ~= "" then
        ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink))
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
---@return boolean visible Whether the inventory/craft-bag switch keybind is valid now
---@return string|nil reason Hidden reason for diagnostics
function InventoryKeybinds.CanShowCraftBagSwitch(self)
    if not self then
        return false, "missingInventory"
    end

    if self:IsBatchProcessing() then
        return false, "batchProcessing"
    end

    if self.actionMode ~= InventoryConst.ITEM_LIST_ACTION_MODE
        and self.actionMode ~= InventoryConst.CRAFT_BAG_ACTION_MODE then
        TraceCraftBagSwitchVisibility(self, false, "actionMode", nil)
        return false, "actionMode"
    end

    if IsBagUpgradeCategorySelected(self) then
        TraceCraftBagSwitchVisibility(self, false, "bagUpgrade", nil)
        return false, "bagUpgrade"
    end

    local sceneName = GetCurrentSceneName()
    if sceneName and sceneName ~= "gamepad_inventory_root" then
        TraceCraftBagSwitchVisibility(self, false, "sceneMismatch", nil)
        return false, "sceneMismatch"
    end

    local currentList = self.GetCurrentList and self:GetCurrentList() or nil
    if currentList ~= self.itemList and currentList ~= self.craftBagList then
        TraceCraftBagSwitchVisibility(self, false, "listMismatch", nil)
        return false, "listMismatch"
    end

    local target = GetCurrentTarget(self)
    if self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE and IsQuestTarget(target) then
        TraceCraftBagSwitchVisibility(self, false, "questTarget", target)
        return false, "questTarget"
    end

    TraceCraftBagSwitchVisibility(self, true, nil, target)
    return true, nil
end

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
        if target and IsQuestTarget(target) then
            return ""
        end
        local multiSelectActionName = ResolveMultiSelectActionName(self, target, false, false)
        return multiSelectActionName or ""
    end

    if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
        local multiSelectActionName = ResolveMultiSelectActionName(self, target, true, false)
        return multiSelectActionName or ""
    end

    local pinnedUseName = GetCooldownPinnedUseName(self)
    if pinnedUseName then
        return pinnedUseName
    end

    if IsPrimaryActionTransitionActive(self) and self._primaryActionTransitionName then
        return self._primaryActionTransitionName
    end

    local baseName = select(1, ResolvePrimaryActionState(self))
    if not baseName then
        if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
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
    return baseName or ""
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

    if IsPrimaryActionTransitionActive(self) then
        return true
    end

    if IsBagUpgradeCategorySelected(self) then
        return true
    end

    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        local target = InventoryUtils.SafeGetTargetData(self.itemList)
        if not target and self.itemList then
            target = self.itemList.selectedData
        end
        if target and IsQuestTarget(target) then
            return false
        end
        return true
    end

    if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
        return true
    end

    if self.itemActions and self.itemActions.slotActions then
        local visible = self.itemActions.slotActions:CheckPrimaryActionVisibility()
        if visible then
            return true
        end
        if IsPrimaryActionTransitionActive(self) then
            return true
        end
    end

    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        if InventoryUtils.SafeGetTargetData(self.craftBagList) ~= nil then
            return true
        end
        return IsPrimaryActionTransitionActive(self)
    end

    if InventoryUtils.SafeGetTargetData(self.itemList) ~= nil then
        return true
    end

    return IsPrimaryActionTransitionActive(self)
end

---@param self table Inventory class instance
---@return nil
function InventoryKeybinds.HandlePrimaryKeybind(self)
    if self:IsBatchProcessing() then
        return false, "batchProcessing"
    end

    if IsBagUpgradeCategorySelected(self) then
        ZO_Dialogs_ShowGamepadDialog("BUY_BAG_SPACE_FROM_INVENTORY_GAMEPAD", { cost = GetNextBackpackUpgradePrice() })
        return true, nil, "bagUpgradeDialog"
    end

    if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
        local target = InventoryUtils.SafeGetTargetData(self.craftBagList)
        if target then
            StartPrimaryActionTransition(self, ResolveMultiSelectActionName(self, target, true, true))
            self.craftBagMultiSelectManager:ToggleSelection(target)
            self:RefreshCraftBagList()
            return true, nil, "craftBagMultiSelectToggle"
        end
        return false, "noCraftBagTarget", "craftBagMultiSelectToggle"
    end

    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        local target = InventoryUtils.SafeGetTargetData(self.itemList)
        if not target and self.itemList then
            target = self.itemList.selectedData
        end
        if target then
            StartPrimaryActionTransition(self, ResolveMultiSelectActionName(self, target, false, true))
            self.multiSelectManager:ToggleSelection(target)
            self:RefreshItemList()
            return true, nil, "inventoryMultiSelectToggle"
        end
        return false, "noInventoryTarget", "inventoryMultiSelectToggle"
    end

    local actionName, slotActions = ResolvePrimaryActionState(self)

    local currentTarget = nil
    if self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE then
        currentTarget = InventoryUtils.SafeGetTargetData(self.itemList)
    elseif self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        currentTarget = InventoryUtils.SafeGetTargetData(self.craftBagList)
    end
    if not currentTarget then
        return false, "noTarget"
    end

    -- While the selected item is on use-cooldown its "Use" slot action is
    -- temporarily absent and the fall-through action (often "Mark as Junk")
    -- would fire instead. Route the press to Use — a safe no-op during the
    -- cooldown — so the displayed and executed action always match.
    local pinnedUseName = GetCooldownPinnedUseName(self)
    if pinnedUseName then
        StartPrimaryActionTransition(self, pinnedUseName)
        ExecuteTargetUse(currentTarget)
        return true, nil, "cooldownPinnedUse"
    end

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
            return false, "noPrimaryAction"
        end

        StartPrimaryActionTransition(self, actionName)
        local overrideName = NormalizeActionName(slotActions._betterui_primaryName)
        if type(slotActions._betterui_primaryOverride) == "function"
            and overrideName
            and overrideName == actionName then
            slotActions._betterui_primaryOverride()
        elseif actionName == GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
            or actionName == GetString(rawget(_G, "SI_ITEM_ACTION_SHOW_MAP"))
            or actionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_SKILL_RESPEC"))
            or actionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC")) then
            ExecuteTargetUse(currentTarget)
        elseif actionName == GetString(rawget(_G, "SI_ITEM_ACTION_SHOW_QUEST")) then
            local opened, reason = OpenQuestJournalForTarget(currentTarget, "primary_keybind")
            if opened then
                return true, nil, "showQuest"
            end
            return false, reason, "showQuest"
        elseif actionName == GetString(rawget(_G, "SI_ITEM_ACTION_PLACE_FURNITURE")) then
            local ds = currentTarget.dataSource or currentTarget
            local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
            if bag and slot and ZO_CanPlaceItemInCurrentHouse(bag, slot) then
                ZO_TryPlaceFurnitureFromInventorySlot(bag, slot)
                return true, nil, "placeFurniture"
            end
            return false, "cannotPlaceFurniture", "placeFurniture"
        else
            if ExecutePrimaryAction(slotActions, actionName) then
                return true, nil, "slotAction"
            end

            if self.RefreshItemActions then
                self:RefreshItemActions()
            end
            actionName, slotActions = ResolvePrimaryActionState(self)
            if actionName and slotActions then
                StartPrimaryActionTransition(self, actionName)
                if ExecutePrimaryAction(slotActions, actionName) then
                    return true, nil, "refreshedSlotAction"
                end
                return false, "noExecutablePrimaryAction", "refreshedSlotAction"
            else
                ClearStalePrimaryOverride(slotActions)
                return false, "stalePrimaryAction"
            end
        end
        return true, nil, "primaryAction"
    end

    StartPrimaryActionTransition(self, actionName)
    local target = currentTarget
    if target and target.bagId and target.slotIndex then
        if IsEquipable(target.bagId, target.slotIndex) then
            local inventorySlot = target.dataSource and target or { dataSource = target }
            self:TryEquipItem(inventorySlot, false)
            return true, nil, "equip"
        else
            if not CallSecureProtected("UseItem", target.bagId, target.slotIndex) then
                NotifySecureActionFailed("CraftBagKeybinds:PrimaryUseItem")
                return false, "secureUseFailed", "useItem"
            end
            return true, nil, "useItem"
        end
    end
    return false, "invalidTarget"
end

---@param self table Inventory class instance
---@return string name Localized keybind label for secondary action
function InventoryKeybinds.GetSecondaryKeybindName(self)
    if IsSecondaryActionTransitionActive(self) then
        return self._secondaryActionTransitionName
    end

    local name
    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        name = GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
    else
        local actionContext = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)
        if not actionContext then
            return ""
        end

        if actionContext.isQuickslottable then
            local slotNum = GetAssignedQuickslot(actionContext.target, actionContext.isQuestItem)
            if slotNum then
                name = GetString(rawget(_G, "SI_BETTERUI_INV_ACTION_QUICKSLOT_UNASSIGN"))
            else
                name = GetString(rawget(_G, "SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN"))
            end
        elseif not actionContext.isQuestItem and actionContext.isEquipment then
            name = GetString(rawget(_G, "SI_BETTERUI_INV_SWITCH_INFO"))
        elseif actionContext.isUsableQuest then
            name = GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
        else
            name = GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT"))
        end
    end

    return name or ""
end

---@param self table Inventory class instance
---@return boolean visible Whether the secondary keybind should be shown
function InventoryKeybinds.IsSecondaryKeybindVisible(self)
    if self:IsBatchProcessing() then
        return false
    end

    if self.itemActions and self.itemActions.actionName == GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")) then
        return false
    end

    if self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE then
        local actionContext = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)
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
        return false, "batchProcessing"
    end

    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        local target = GetCurrentTarget(self)
        if not target then
            return false, "noTarget", "linkCraftBag"
        end
        InsertTargetLink(target)
        return true, nil, "linkCraftBag"
    end

    local actionContext = BETTERUI.CIM.Keybinds.GetXButtonActionContext(self)
    if not actionContext then
        return false, "noActionContext"
    end

    if actionContext.isQuickslottable then
        local hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
        local slotNum = GetAssignedQuickslot(actionContext.target, actionContext.isQuestItem)

        if slotNum then
            StartSecondaryActionTransition(self, InventoryKeybinds.GetSecondaryKeybindName(self))
            if not CallSecureProtected("ClearSlot", slotNum, hotbarCategory) then
                NotifySecureActionFailed("CraftBagKeybinds:QuickslotClear")
            end
            if SOUNDS and PlaySound then
                PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
            end

            StartPrimaryActionTransition(self, nil)
            if actionContext.target and actionContext.target.uniqueId then
                self._preserveUniqueId = actionContext.target.uniqueId
            end

            local function RefreshAfterQuickslotUnassign()
                if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.KEYBIND, "CraftBag quickslot unassign refresh keybinds") end
                if self.control and self.control.IsHidden and self.control:IsHidden() then
                    return
                end
                if self.actionMode ~= InventoryConst.ITEM_LIST_ACTION_MODE then
                    return
                end
                local target = actionContext.target
                if target and target.bagId and target.slotIndex and self.InvalidateItemMeta then
                    self:InvalidateItemMeta(target.bagId, target.slotIndex)
                end
                if self.InvalidateSlotDataCache then
                    self:InvalidateSlotDataCache()
                end
                self:RefreshKeybinds()
                self:RefreshItemList()
            end

            RefreshAfterQuickslotUnassign()
            if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Schedule then
                BETTERUI.Inventory.Tasks:Schedule("quickslotUnassignRefresh", 80, RefreshAfterQuickslotUnassign)
            else
                zo_callLater(RefreshAfterQuickslotUnassign, 80)
            end
            return true, nil, "quickslotUnassign"
        else
            zo_callLater(function()
                self:ShowQuickslot()
            end, 50)
            return true, nil, "quickslotAssign"
        end
    end

    if not actionContext.isQuestItem and actionContext.isEquipment then
        self:SwitchInfo()
        return true, nil, "switchInfo"
    end

    if actionContext.isUsableQuest then
        ExecuteTargetUse(actionContext.target)
        return true, nil, "questUse"
    end

    InsertTargetLink(actionContext.target)
    return true, nil, "linkToChat"
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

    if self.itemActions and self.itemActions.actionName == GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")) then
        return false
    end

    return InventoryKeybinds.HasStableActionsTarget(self)
end

---@param self table Inventory class instance
---@return nil
function InventoryKeybinds.HandleTertiaryKeybind(self)
    if self:IsBatchProcessing() then
        self:RequestBatchAbort()
        return true, nil, "batchAbort"
    end

    if self.craftBagMultiSelectManager and self.craftBagMultiSelectManager:IsActive() then
        self:ShowCraftBagBatchActionsMenu()
        return true, nil, "craftBagBatchActions"
    end

    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        self:ShowBatchActionsMenu()
        return true, nil, "inventoryBatchActions"
    end

    if not InventoryKeybinds.HasStableActionsTarget(self) then
        return false, "unstableActionsTarget"
    end

    self:SaveListPosition()
    self:ShowActions()
    return true, nil, "showActions"
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
        return false, "batchProcessing"
    end

    if self.actionMode == InventoryConst.CRAFT_BAG_ACTION_MODE then
        if self.craftBagMultiSelectManager and not self.craftBagMultiSelectManager:IsActive() then
            self:EnterCraftBagSelectionMode()
            return true, nil, "craftBagSelectionMode"
        end
        return false, "craftBagSelectionUnavailable"
    end

    if self.multiSelectManager and not self.multiSelectManager:IsActive() then
        self:EnterSelectionMode()
        return true, nil, "inventorySelectionMode"
    end
    return false, "inventorySelectionUnavailable"
end
