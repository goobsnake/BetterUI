--[[
File: Modules/Inventory/Lists/CraftBagListManager.lua
Purpose: Manages the Craft Bag list for the Inventory module.
]]

local function QueueInventoryNarration()
    local queueSceneNarration = BETTERUI.Inventory and BETTERUI.Inventory.QueueSceneNarration
    if type(queueSceneNarration) == "function" then
        queueSceneNarration()
    end
end

--- Initializes the craft bag list.
--- Purpose: Sets up the visual scroll list for the craft bag.
---@return nil
function BETTERUI.Inventory.Class:InitializeCraftBagList()
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIST, "CraftBagList initialized") end
    local function OnSelectedDataCallback(list, selectedData)
        if selectedData ~= nil and self.scene and self.scene:IsShowing() then
            self.currentlySelectedData = selectedData
            self:UpdateItemLeftTooltip(selectedData)

            local currentList = self:GetCurrentList()
            if currentList == list or ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                self:SetSelectedInventoryData(selectedData)
                -- Ensure selectedItemUniqueId is set for craftbag items (needed for Y-button visibility)
                self:SetSelectedItemUniqueId(selectedData)
                if currentList == list then
                    QueueInventoryNarration()
                end
                if list and list.GetParametricList then
                    list:GetParametricList():RefreshVisible()
                end
            end
            -- Keybind Refresh - protected by RefreshKeybinds() override
            self:RefreshKeybinds()
        end
    end

    self.craftBagList = self:AddList(
        "CraftBag",
        -- No-op setup callback. BETTERUI.Inventory.List:Initialize already registers the
        -- entry templates and binds options.slotType per row, so this has nothing to do --
        -- but it MUST be a function, NOT nil. Native CreateAndSetupList runs self:SetupList(list)
        -- when callbackParam is nil, and native SetupList calls list:AddDataTemplate() on the
        -- BETTERUI.Inventory.List wrapper (not a raw parametric list), throwing "function
        -- expected instead of nil". A no-op keeps native on the callbackParam(list) branch and
        -- skips its incompatible default setup. (Passing nil here was the craft-bag regression.)
        function() end,
        BETTERUI.Inventory.CraftList,
        {
            inventoryType = BAG_VIRTUAL,
            slotType = SLOT_TYPE_CRAFT_BAG_ITEM,
            selectedDataCallback = OnSelectedDataCallback,
            useTriggers = false,
            template = "BETTERUI_GamepadItemSubEntryTemplate",
            listModuleName = "Inventory",
        }
    )
    self.craftBagList:SetNoItemText(GetString(SI_INVENTORY_ERROR_CRAFT_BAG_EMPTY))
    self.craftBagList:SetAlignToScreenCenter(true, 30)

    self.craftBagList:SetSortFunction(BETTERUI.Inventory.CraftListDefaultSortComparator)

    -- Initialize craftbag multi-select manager
    if not self.craftBagMultiSelectManager then
        self.craftBagMultiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(
            self.craftBagList,
            function(selectedCount)
                self:OnCraftBagSelectionCountChanged(selectedCount)
            end
        )
    end
end

--- Refreshes the Craft Bag list content.
---@return nil
function BETTERUI.Inventory.Class:RefreshCraftBagList()
    if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIST, "RefreshCraftBagList triggered") end
    if self:IsBatchProcessing() and self.batchSuppressUiUpdates then
        return
    end

    -- The craft bag list may not be built yet during early / re-entrant scene-show flows
    -- (a category-rebuild reselect can trigger a craft-bag switch before init completes).
    if not self.craftBagList then
        return
    end

    -- we need to pass in our current filterType, as refreshing the craft bag list is distinct from the item list's methods (only slightly)
    local craftCategoryTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
    local craftFilter = craftCategoryTarget and craftCategoryTarget.filterType or nil
    self.craftBagList:RefreshList(craftFilter, self.searchQuery)
end

--- Configure the tooltip for the Craft Bag header.
---@return nil
function BETTERUI.Inventory.Class:LayoutCraftBagTooltip()
    local title
    local description
    if HasCraftBagAccess() then
        title = GetString(rawget(_G, "SI_ESO_PLUS_STATUS_UNLOCKED"))
        description = GetString(rawget(_G, "SI_CRAFT_BAG_STATUS_ESO_PLUS_UNLOCKED_DESCRIPTION"))
    else
        title = GetString(rawget(_G, "SI_ESO_PLUS_STATUS_LOCKED"))
        description = GetString(rawget(_G, "SI_CRAFT_BAG_STATUS_LOCKED_DESCRIPTION"))
    end

    GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP, title, description)
end

--- Counts craft bag items for every filter type in a single pass for the
--- category badges (replacing a per-category counting call): each item is
--- bucketed by its filterData entries, which is exactly the membership test
--- ZO_InventoryUtils_DoesNewItemMatchFilterType applies for non-nil filters.
---@return table<number, number> countsByFilterType Item counts keyed by filter type
---@return number totalCount Total craft bag item count (the "All" category)
function BETTERUI.Inventory.Class:GetCraftBagCategoryItemCounts()
    local countsByFilterType = {}
    local totalCount = 0
    local virtualItems = SHARED_INVENTORY:GetBagCache(BAG_VIRTUAL)
    if virtualItems then
        for _, itemData in pairs(virtualItems) do
            totalCount = totalCount + 1
            local filterData = itemData.filterData
            if filterData then
                for i = 1, #filterData do
                    local filterType = filterData[i]
                    -- Guard duplicate filter entries so an item is counted at
                    -- most once per filter type, matching the boolean matcher.
                    local alreadyCounted = false
                    for j = 1, i - 1 do
                        if filterData[j] == filterType then
                            alreadyCounted = true
                            break
                        end
                    end
                    if not alreadyCounted then
                        countsByFilterType[filterType] = (countsByFilterType[filterType] or 0) + 1
                    end
                end
            end
        end
    end
    return countsByFilterType, totalCount
end
