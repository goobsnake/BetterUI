--[[
File: Modules/Inventory/Lists/CategoryListManager.lua
Purpose: Manages the Category list (tabs) for the Inventory module.
Author: BetterUI Team
]]

local function SetupCategoryList(list)
    list:AddDataTemplate(
        "BETTERUI_GamepadItemEntryTemplate",
        ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction
    )
end




--- Build the category list UI and wire up selection/target callbacks
--- Responds to category selection by switching between item and craft bag lists
--- Initializes the category list (tabs) for the inventory.
--- Sets up templates, selection callbacks, and target change handlers.
function BETTERUI.Inventory.Class:InitializeCategoryList()
    self.categoryList = self:AddList("Category", SetupCategoryList)
    self.categoryList:SetNoItemText(GetString(SI_GAMEPAD_INVENTORY_EMPTY))

    -- Match the tooltip to the selected data because it looks nicer
    local function OnSelectedCategoryChanged(list, selectedData)
        if selectedData ~= nil and self.scene:IsShowing() then
            self:UpdateCategoryLeftTooltip(selectedData)

            if selectedData.onClickDirection then
                self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
            else
                self:SwitchActiveList(INVENTORY_ITEM_LIST)
            end
        end
    end

    self.categoryList:SetOnSelectedDataChangedCallback(OnSelectedCategoryChanged)

    --Match the functionality to the target data
    local function OnTargetCategoryChanged(list, targetData)
        if targetData then
            self.selectedEquipSlot = targetData.equipSlot
            self:SetSelectedItemUniqueId(self:GenerateItemSlotData(targetData))
            self.selectedItemFilterType = targetData.filterType
        else
            self:SetSelectedItemUniqueId(nil)
        end

        self.currentlySelectedData = targetData
    end

    self.categoryList:SetOnTargetDataChangedCallback(OnTargetCategoryChanged)

    -- Note: Previously this code attempted to hide the search whenever the
    -- category list activated in order to prevent the search from being
    -- highlighted. That approach caused navigation/confusion in some flows.
    -- We removed the hide/wrap behavior and now rely on header-enter handling
    -- to focus the search when appropriate.
end

--- Adds a new category entry to the category list if it contains items.
---
--- Purpose: Dynamically populates the category bar.
--- Mechanics:
--- 1. Checks if items exist for the filter (via IsItemListEmpty).
--- 2. Checks for "New" items to tint the icon.
--- 3. Adds entry to both CategoryList (hidden logic) and Header (visual tab bar).
--- References: Called by RefreshCategoryList.
---
--- @param filterType number|nil The item filter type for the category.
--- @param iconFile string The path to the icon texture.
--- @param FilterFunct function|nil Optional custom filter function.
function BETTERUI.Inventory.Class:NewCategoryItem(filterType, iconFile, FilterFunct)
    if FilterFunct == nil then
        FilterFunct = ZO_InventoryUtils_DoesNewItemMatchFilterType
    end

    local isListEmpty = self:IsItemListEmpty(nil, filterType)
    if not isListEmpty then
        local name
        if filterType == nil then
            name = GetString(SI_BETTERUI_INV_ITEM_ALL)
        else
            name = GetString("SI_ITEMFILTERTYPE", filterType)
        end

        local hasAnyNewItems = self:AreAnyItemsNew(FilterFunct, filterType, BAG_BACKPACK)
        local data = ZO_GamepadEntryData:New(name, iconFile, nil, nil, hasAnyNewItems)
        data.filterType = filterType
        data.itemCount = self:GetCategoryItemCount(filterType) -- For category badge display
        data:SetIconTintOnSelection(true)
        self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
        BETTERUI.GenericHeader.AddToList(self.header, data)
        if not self.populatedCategoryPos then
            self.categoryPositions[#self.categoryPositions + 1] = 1
        end
    end
end

--- Rebuilds the category list based on the current state (Inventory vs Craft Bag).
---
--- Purpose: Dynamically adds categories like "All", "Weapons", "Armor", enc.
--- Mechanics:
--- 1. Detects active list mode (CraftBag vs Inventory).
--- 2. For CraftBag: Adds fixed categories (Alchemy, Blacksmithing, etc.). Disables if locked.
--- 3. For Inventory: Adds categories only if they contain items (via NewCategoryItem).
--- 4. Handles "Equipped", "Stolen", "Junk", "Quest" visibility dynamically.
--- 5. Restores previous selection if possible.
--- References: Called by RefreshItemList.
---
function BETTERUI.Inventory.Class:RefreshCategoryList()
    -- Skip refresh during batch processing to prevent flickering
    if self:IsBatchProcessing() then
        return
    end

    local function CountStolenNotJunk()
        local count = 0
        local backpack = self:GetCachedSlotData(BAG_BACKPACK)
        if backpack then
            for _, slotData in ipairs(backpack) do
                if slotData and slotData.stolen and not slotData.isJunk then
                    count = count + 1
                end
            end
        end

        -- Fallback if cache unavailable
        if count == 0 then
            local bagSize = GetBagSize(BAG_BACKPACK) or 0
            for slotIndex = 0, bagSize - 1 do
                if IsItemStolen(BAG_BACKPACK, slotIndex) and not IsItemJunk(BAG_BACKPACK, slotIndex) then
                    count = count + 1
                end
            end
        end
        return count
    end

    -- Store the current selected index before clearing so we can restore it
    local previousSelectedIndex = self.categoryList.selectedIndex

    self.categoryList:Clear()
    self.header.tabBar:Clear()

    local currentList = self:GetCurrentList()

    if currentList == self.craftBagList then
        local categories = BETTERUI.Inventory.Categories.CraftBag
        for _, catDef in ipairs(categories) do
            local name = GetString(catDef.nameStringId)
            local data = ZO_GamepadEntryData:New(name, catDef.iconFile)
            data.itemCount = self:GetCraftBagCategoryItemCount(catDef.filterType)
            data:SetIconTintOnSelection(true)

            if catDef.onClickDirection then
                data.onClickDirection = catDef.onClickDirection
            end

            if catDef.filterType ~= nil then
                data.filterType = catDef.filterType
            end

            if not HasCraftBagAccess() then
                data.enabled = false
            end

            self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
            BETTERUI.GenericHeader.AddToList(self.header, data)
            if not self.populatedCraftPos then
                self.categoryCraftPositions[#self.categoryCraftPositions + 1] = 1
            end
        end

        self.populatedCraftPos = true
    else
        local categories = BETTERUI.Inventory.Categories.Inventory
        for _, catDef in ipairs(categories) do
            local shouldAdd = false
            local data = nil

            -- SPECIAL CATEGORIES
            if catDef.key == "Equipped" then
                local usedBagSize = GetNumBagUsedSlots(BAG_WORN)
                if usedBagSize > 0 then
                    local name = GetString(catDef.nameStringId)
                    local hasAnyNewItems = self:AreAnyItemsNew(function() return true end, nil, BAG_WORN)
                    data = ZO_GamepadEntryData:New(name, catDef.iconFile, nil, nil, hasAnyNewItems)
                    data.showEquipped = true
                    data.itemCount = usedBagSize
                    shouldAdd = true
                end
            elseif catDef.key == "Quest" then
                local questCache = SHARED_INVENTORY:GenerateFullQuestCache()
                local questCount = 0
                for _ in pairs(questCache) do questCount = questCount + 1 end
                if questCount > 0 then
                    local name = GetString(catDef.nameStringId)
                    data = ZO_GamepadEntryData:New(name, catDef.iconFile)
                    data.filterType = catDef.filterType
                    data.itemCount = questCount
                    shouldAdd = true
                end
            elseif catDef.key == "Stolen" then
                local stolenCount = CountStolenNotJunk()
                if stolenCount > 0 then
                    local name = GetString(catDef.nameStringId)
                    local hasAnyNewItems = self:AreAnyItemsNew(function() return true end, nil, BAG_BACKPACK)
                    data = ZO_GamepadEntryData:New(name, catDef.iconFile, nil, nil, hasAnyNewItems)
                    data.showStolen = true
                    data.itemCount = stolenCount
                    shouldAdd = true
                end
            elseif catDef.key == "Junk" then
                local junkCount = self:CountJunkInBackpack()
                if junkCount > 0 then
                    -- Show Junk category if there are any junk items
                    local name = GetString(catDef.nameStringId)
                    local hasAnyNewItems = self:AreAnyItemsNew(function() return true end, nil,
                        BAG_BACKPACK)
                    data = ZO_GamepadEntryData:New(name, catDef.iconFile, nil, nil, hasAnyNewItems)
                    data.showJunk = true
                    data.itemCount = junkCount
                    shouldAdd = true
                end

                -- STANDARD CATEGORIES (All, Weapons, etc)
            else
                local isListEmpty = self:IsItemListEmpty(nil, catDef.filterType)

                if catDef.isStatic or not isListEmpty then
                    self:NewCategoryItem(catDef.filterType, catDef.iconFile)
                    shouldAdd = false -- Handled by NewCategoryItem
                end
            end

            if shouldAdd and data then
                data:SetIconTintOnSelection(true)
                self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
                BETTERUI.GenericHeader.AddToList(self.header, data)
                if not self.populatedCategoryPos then
                    self.categoryPositions[#self.categoryPositions + 1] = 1
                end
            end
        end

        self.populatedCategoryPos = true
    end

    local desiredIndex
    local categoryCount = #self.categoryList.dataList
    if categoryCount > 0 then
        if previousSelectedIndex and previousSelectedIndex > 0 and previousSelectedIndex <= categoryCount then
            desiredIndex = previousSelectedIndex
        else
            desiredIndex = 1
        end
    end

    -- Temporarily remove the callbacks before commit to prevent firing with wrong selection
    local headerTabBar = self.header and self.header.tabBar
    local savedHeaderCallback = nil
    local savedCategoryCallback = self.categoryList.onSelectedDataChangedCallback

    if headerTabBar then
        savedHeaderCallback = headerTabBar.onSelectedDataChangedCallback
        headerTabBar:RemoveOnSelectedDataChangedCallback(savedHeaderCallback)
    end
    self.categoryList:RemoveOnSelectedDataChangedCallback(savedCategoryCallback)

    self.categoryList:Commit()
    self.header.tabBar:Commit()

    if desiredIndex then
        self.categoryList:SetSelectedIndexWithoutAnimation(desiredIndex, true, false)
        if headerTabBar then
            local headerCount = #headerTabBar.dataList
            if headerCount > 0 then
                local clampedIndex = zo_clamp(desiredIndex, 1, headerCount)
                -- Pass true for dontCallSelectedDataChangedCallback to avoid triggering list refresh during rebuild
                headerTabBar:SetSelectedIndexWithoutAnimation(clampedIndex, true, true)
                headerTabBar.targetSelectedIndex = clampedIndex
                -- Force carousel to update visual positions
                if headerTabBar.UpdateAnchors then
                    headerTabBar:UpdateAnchors(clampedIndex, true, false)
                end
            end
        end
    end

    -- Restore the callbacks after selection is set
    if headerTabBar and savedHeaderCallback then
        headerTabBar:SetOnSelectedDataChangedCallback(savedHeaderCallback)
    end
    if savedCategoryCallback then
        self.categoryList:SetOnSelectedDataChangedCallback(savedCategoryCallback)
    end

    self:EnsureHeaderKeybindsActive()
end
