--[[
File: Modules/Inventory/State/ListStateManager.lua
Purpose: Manages high-level transitions between item lists (Backpack, Craft Bag, Categories).
]]

-- Local aliases for list type constants (migrated from bare globals)
local INVENTORY_CATEGORY_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.CATEGORY
local INVENTORY_ITEM_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.ITEM
local INVENTORY_CRAFT_BAG_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.CRAFT_BAG

-- Action mode constants: Replaced by BETTERUI.Inventory.CONST equivalents

--- @class ListActivationConfig
--- @field savedCategoryKey string|nil Saved category key for position restoration
--- @field isCraftBag boolean Whether this is a craft bag list
--- @field refreshListFn fun(self: BetterUI_InventoryClass) Refresh function for this list
--- @field savedPositionsByKey table<string, number>|nil Saved item positions per category
--- @field savedItemUniqueByKey table<string, userdata>|nil Saved item unique IDs per category
--- @field actionMode number|nil Action mode constant

--- Activates a list, restoring its saved category and item positions.
--- @param self BetterUI_InventoryClass
--- @param listControl table UI scroll list control
--- @param config ListActivationConfig
local function ActivateListWithState(self, listControl, config)
    self:SetCurrentList(listControl)
    self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
    self:RefreshCategoryList()

    -- Restore saved category position
    local targetIndex = 1
    if config.savedCategoryKey then
        local idx = BETTERUI.Inventory.FindCategoryIndexByKey(self, config.savedCategoryKey)
        if idx then targetIndex = idx end
    end
    -- Validate target is the correct category type (inventory vs craft bag)
    local catData = self.categoryList.dataList[targetIndex]
    local isCraftBagEntry = catData and catData.onClickDirection
    if not catData or (config.isCraftBag and not isCraftBagEntry) or (not config.isCraftBag and isCraftBagEntry) then
        for i, d in ipairs(self.categoryList.dataList) do
            local match = config.isCraftBag and d.onClickDirection or (not config.isCraftBag and not d.onClickDirection)
            if match then
                targetIndex = i
                break
            end
        end
    end
    self.categoryList:SetSelectedIndexWithoutAnimation(zo_clamp(targetIndex, 1, #self.categoryList.dataList), true, false)

    -- Sync header tab
    if self.header and self.header.tabBar then
        local headerTabBar = self.header.tabBar
        local idx = self.categoryList.selectedIndex or 1
        headerTabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
        if headerTabBar.UpdateAnchors then
            headerTabBar:UpdateAnchors(idx, true, false)
        end
    end

    -- Refresh and restore item position
    config.refreshListFn(self)
    local key = BETTERUI.Inventory.GetCategoryKey(self.categoryList.selectedData)
    local itemIndex = 1
    if key and config.savedPositionsByKey and config.savedPositionsByKey[key] then
        itemIndex = config.savedPositionsByKey[key]
        if config.savedItemUniqueByKey and config.savedItemUniqueByKey[key] then
            local uid = config.savedItemUniqueByKey[key]
            local dataList = listControl.list and listControl.list.dataList or listControl.dataList
            if dataList then
                for i, entry in ipairs(dataList) do
                    if entry and entry.uniqueId == uid then
                        itemIndex = i
                        break
                    end
                end
            end
        end
    end
    local dataList = listControl.list and listControl.list.dataList or listControl.dataList
    if dataList and #dataList > 0 then
        local innerList = listControl.list or listControl
        if innerList.SetSelectedIndexWithoutAnimation then
            innerList:SetSelectedIndexWithoutAnimation(zo_clamp(itemIndex, 1, #dataList), true, false)
        end
    end

    self:SetSelectedItemUniqueId(BETTERUI.Inventory.Utils.SafeGetTargetData(listControl))
    self.actionMode = config.actionMode
    self:RefreshItemActions()
    self:RefreshHeader(not config.isCraftBag or nil)

    -- Update header title to match the restored category
    local selectedCatData = self.categoryList.selectedData
    if selectedCatData and selectedCatData.text then
        BETTERUI.GenericHeader.SetTitleText(self.header, selectedCatData.text)
    end

    -- Craft bag: show tooltip for selected item
    if config.isCraftBag and self.LayoutCraftBagTooltip then
        self:LayoutCraftBagTooltip(GAMEPAD_LEFT_TOOLTIP)
    end
    -- Inventory: show left tooltip for selected item
    if not config.isCraftBag then
        self:UpdateItemLeftTooltip(self.itemList.selectedData)
    end
end

--- Switches the active list between Inventory and Craft Bag.
--- @param self BetterUI_InventoryClass
--- @param listDescriptor number LIST_TYPES constant
local function SwitchActiveList(self, listDescriptor)
    if listDescriptor == self.currentListType then
        return
    end

    -- Clear multi-select state when switching between inventory/craftbag
    -- Selected items are not compatible across list contexts
    if self.isInSelectionMode then
        self:ExitSelectionMode()
    end
    if self.isInCraftBagSelectionMode then
        self:ExitCraftBagSelectionMode()
    end

    -- Only save position when scene is showing; SCENE_HIDDEN fires after DeactivateLists()
    -- which leaves selectedIndex/selectedData stale. SCENE_HIDING already saved correctly.
    if self.currentListType and self.scene and self.scene:IsShowing() then
        self:SaveListPosition()
    end

    self.previousListType = self.currentListType
    self.currentListType = listDescriptor

    if self.previousListType then
        self.listWaitingOnDestroyRequest = nil
        BETTERUI.Inventory.NewItemTracker.CommitPendingClears()
    end

    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)

    if listDescriptor == INVENTORY_CATEGORY_LIST then
        listDescriptor = INVENTORY_ITEM_LIST
    elseif listDescriptor ~= INVENTORY_ITEM_LIST and listDescriptor ~= INVENTORY_CATEGORY_LIST then
        listDescriptor = INVENTORY_CRAFT_BAG_LIST
    end

    if self.scene:IsShowing() then
        if listDescriptor == INVENTORY_ITEM_LIST then
            -- Only restore saved inventory category when entering from a different context.
            -- If we're already in inventory context (item list <-> category view),
            -- keep the selection chosen by RefreshCategoryList().
            local shouldRestoreSavedInventoryCategory = self.previousListType ~= INVENTORY_ITEM_LIST
                and self.previousListType ~= INVENTORY_CATEGORY_LIST
            ActivateListWithState(self, self.itemList, {
                savedCategoryKey = shouldRestoreSavedInventoryCategory and self.savedInventoryCategoryKey or nil,
                savedPositionsByKey = self.savedInventoryPositionsByKey,
                savedItemUniqueByKey = self.savedInventorySelectedItemUniqueByKey,
                isCraftBag = false,
                actionMode = BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE,
                refreshListFn = function(s) s:RefreshItemList() end,
            })
        elseif listDescriptor == INVENTORY_CRAFT_BAG_LIST then
            ActivateListWithState(self, self.craftBagList, {
                savedCategoryKey = self.savedCraftBagCategoryKey,
                savedPositionsByKey = self.savedCraftBagPositionsByKey,
                savedItemUniqueByKey = self.savedCraftBagSelectedItemUniqueByKey,
                isCraftBag = true,
                actionMode = BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE,
                refreshListFn = function(s) s:RefreshCraftBagList() end,
            })
        end

        if self.headerSortControllers and self.headerSortControllers[self.currentListType] then
            self.headerSortControllers[self.currentListType]:UpdateVisuals()
        end

        -- RefreshKeybinds() is protected by InventoryClass override
        self:RefreshKeybinds()
    else
        self.actionMode = nil
    end
end

-- Register mixins
if BETTERUI.Inventory.RegisterMixin then
    BETTERUI.Inventory.RegisterMixin("SwitchActiveList", SwitchActiveList)
end
