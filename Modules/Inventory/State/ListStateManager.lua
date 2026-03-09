--[[
File: Modules/Inventory/State/ListStateManager.lua
Purpose: Manages high-level transitions between item lists (Backpack, Craft Bag, Categories).
Author: BetterUI Team
]]

-- Action mode constants: Replaced by BETTERUI.Inventory.CONST equivalents

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

    -- Save the current list position before switching so positions are restored correctly later
    -- CRITICAL: Only save when scene is actively showing. During SCENE_HIDDEN cleanup,
    -- SwitchActiveList(nil) is called AFTER DeactivateLists(), which may leave lists in
    -- a state where selectedIndex/selectedData are stale. Position is already correctly
    -- saved in SCENE_HIDING (before deactivation), so this guard prevents overwriting it.
    if self.currentListType and self.scene and self.scene:IsShowing() then
        self:SaveListPosition()
    end

    self.previousListType = self.currentListType
    self.currentListType = listDescriptor

    if self.previousListType then
        self.listWaitingOnDestroyRequest = nil
        self:TryClearNewStatusOnHidden()
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
            self:SetCurrentList(self.itemList)
            -- SetActiveKeybinds() is protected by UnifiedScreen override
            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
            self:RefreshCategoryList()

            -- ALWAYS restore saved inventory category when switching to inventory
            local targetIndex = 1
            if self.savedInventoryCategoryKey then
                local idx = BETTERUI.Inventory.FindCategoryIndexByKey(self, self.savedInventoryCategoryKey)
                if idx then targetIndex = idx end
            end
            -- Validate target is an inventory category, otherwise find first inventory category
            if not self.categoryList.dataList[targetIndex] or self.categoryList.dataList[targetIndex].onClickDirection then
                for i, d in ipairs(self.categoryList.dataList) do
                    if not d.onClickDirection then
                        targetIndex = i
                        break
                    end
                end
            end
            self.categoryList:SetSelectedIndexWithoutAnimation(zo_clamp(targetIndex, 1, #self.categoryList.dataList),
                true, false)

            -- Sync header tab - pass true for dontCallSelectedDataChangedCallback to avoid double refresh
            if self.header and self.header.tabBar then
                local headerTabBar = self.header.tabBar
                local idx = self.categoryList.selectedIndex or 1
                headerTabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
                -- Force carousel to update visual positions
                if headerTabBar.UpdateAnchors then
                    headerTabBar:UpdateAnchors(idx, true, false)
                end
            end

            -- Refresh and restore item position
            self:RefreshItemList()
            local key = BETTERUI.Inventory.GetCategoryKey(self.categoryList.selectedData)
            local itemIndex = 1
            -- Only restore saved position if one exists for this category
            if key and self.savedInventoryPositionsByKey and self.savedInventoryPositionsByKey[key] then
                itemIndex = self.savedInventoryPositionsByKey[key]
                -- Prefer unique ID restoration
                if self.savedInventorySelectedItemUniqueByKey and self.savedInventorySelectedItemUniqueByKey[key] then
                    local uid = self.savedInventorySelectedItemUniqueByKey[key]
                    local dataList = self.itemList.list and self.itemList.list.dataList or self.itemList.dataList
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
            local invDataList = self.itemList.list and self.itemList.list.dataList or self.itemList.dataList
            if invDataList and #invDataList > 0 then
                self.itemList:SetSelectedIndexWithoutAnimation(zo_clamp(itemIndex, 1, #invDataList), true, false)
            end

            self:SetSelectedItemUniqueId(BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList))
            self.actionMode = BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE
            self:RefreshItemActions()
            self:RefreshHeader(true) -- Pass BLOCK_TABBAR_CALLBACK

            -- Update header title to match the restored category (AFTER RefreshHeader which sets generic title)
            local selectedCatData = self.categoryList.selectedData
            if selectedCatData and selectedCatData.text then
                BETTERUI.GenericHeader.SetTitleText(self.header, selectedCatData.text)
            end

            self:UpdateItemLeftTooltip(self.itemList.selectedData)
        elseif listDescriptor == INVENTORY_CRAFT_BAG_LIST then
            self:SetCurrentList(self.craftBagList)
            -- SetActiveKeybinds() is protected by UnifiedScreen override
            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
            self:RefreshCategoryList()

            -- ALWAYS restore saved craft bag category when switching to craft bag
            local targetIndex = 1
            if self.savedCraftBagCategoryKey then
                local idx = BETTERUI.Inventory.FindCategoryIndexByKey(self, self.savedCraftBagCategoryKey)
                if idx then targetIndex = idx end
            end
            -- Validate target is a craft bag category, otherwise find first craft bag category
            if not self.categoryList.dataList[targetIndex] or not self.categoryList.dataList[targetIndex].onClickDirection then
                for i, d in ipairs(self.categoryList.dataList) do
                    if d.onClickDirection then
                        targetIndex = i
                        break
                    end
                end
            end
            self.categoryList:SetSelectedIndexWithoutAnimation(zo_clamp(targetIndex, 1, #self.categoryList.dataList),
                true, false)

            -- Sync header tab - pass true for dontCallSelectedDataChangedCallback to avoid double refresh
            if self.header and self.header.tabBar then
                local headerTabBar = self.header.tabBar
                local idx = self.categoryList.selectedIndex or 1
                headerTabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
                -- Force carousel to update visual positions
                if headerTabBar.UpdateAnchors then
                    headerTabBar:UpdateAnchors(idx, true, false)
                end
            end

            -- Refresh and restore item position
            self:RefreshCraftBagList()
            local key = BETTERUI.Inventory.GetCategoryKey(self.categoryList.selectedData)
            local itemIndex = 1
            -- Only restore saved position if one exists for this category
            if key and self.savedCraftBagPositionsByKey and self.savedCraftBagPositionsByKey[key] then
                itemIndex = self.savedCraftBagPositionsByKey[key]
                -- Prefer unique ID restoration
                if self.savedCraftBagSelectedItemUniqueByKey and self.savedCraftBagSelectedItemUniqueByKey[key] then
                    local uid = self.savedCraftBagSelectedItemUniqueByKey[key]
                    local dataList = self.craftBagList.list and self.craftBagList.list.dataList or
                        self.craftBagList.dataList
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
            local craftDataList = self.craftBagList.list and self.craftBagList.list.dataList or
                self.craftBagList.dataList
            if craftDataList and #craftDataList > 0 then
                -- craftBagList wraps an inner list; call SetSelectedIndexWithoutAnimation on the inner list
                local innerList = self.craftBagList.list or self.craftBagList
                if innerList.SetSelectedIndexWithoutAnimation then
                    innerList:SetSelectedIndexWithoutAnimation(zo_clamp(itemIndex, 1, #craftDataList), true, false)
                end
            end

            self:SetSelectedItemUniqueId(BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList))
            self.actionMode = BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE
            self:RefreshItemActions()
            self:RefreshHeader()

            -- Update header title to match the restored category (AFTER RefreshHeader which sets generic title)
            local selectedCatData = self.categoryList.selectedData
            if selectedCatData and selectedCatData.text then
                BETTERUI.GenericHeader.SetTitleText(self.header, selectedCatData.text)
            end

            if self.LayoutCraftBagTooltip then
                self:LayoutCraftBagTooltip(GAMEPAD_LEFT_TOOLTIP)
            end
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
