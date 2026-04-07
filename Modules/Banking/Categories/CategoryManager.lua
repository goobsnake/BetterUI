--[[
---@module "Modules.Banking.Categories.CategoryManager"
File: Modules/Banking/Categories/CategoryManager.lua
Purpose: Centralizes banking category construction, matching, cycling, and header rebuilding.
]]

BETTERUI.Banking.CategoryManager = BETTERUI.Banking.CategoryManager or {}
local CategoryManager = BETTERUI.Banking.CategoryManager

local function DoesItemMatchBankCategory(itemData, category)
    return BETTERUI.Inventory.Categories.DoesItemMatchCategory(itemData, category)
end

function CategoryManager.ComputeVisibleBankCategories(self)
    local currentUsedBank = BETTERUI.Banking.currentUsedBank
    local isFurnitureVault = IsFurnitureVault and IsFurnitureVault(currentUsedBank)
    local allCategories = BETTERUI.Banking.BuildAllBankCategories(isFurnitureVault)
    local visibility = {}
    local itemCounts = {}

    for _, category in ipairs(allCategories) do
        visibility[category.key] = false
        itemCounts[category.key] = 0
    end
    if visibility["all"] ~= nil then
        visibility["all"] = true
    end

    local bags = BETTERUI.Banking.ResolveBagsAndSlotType(self)
    local function IsNotStolenItem(itemData)
        return not itemData.stolen
    end

    local data = SHARED_INVENTORY:GenerateFullSlotData(IsNotStolenItem, unpack(bags))
    local function IsJunkCategory(category)
        return category and (category.special == "junk" or category.furnitureVaultJunk == true)
    end

    local totalNonJunkItems = 0
    for i = 1, #data do
        local itemData = data[i]
        local isJunkItem = itemData and itemData.isJunk == true
        if not isJunkItem then
            totalNonJunkItems = totalNonJunkItems + 1
        end

        for _, category in ipairs(allCategories) do
            if category.key ~= "all" and DoesItemMatchBankCategory(itemData, category) then
                local categoryIsJunk = IsJunkCategory(category)
                local categoryCanMatchItem = (isJunkItem and categoryIsJunk) or ((not isJunkItem) and (not categoryIsJunk))
                if categoryCanMatchItem then
                    visibility[category.key] = true
                    itemCounts[category.key] = itemCounts[category.key] + 1
                end
            end
        end
    end
    if itemCounts["all"] ~= nil then
        itemCounts["all"] = totalNonJunkItems
    end

    local visibleCategories = {}
    for _, category in ipairs(allCategories) do
        if visibility[category.key] then
            category.itemCount = itemCounts[category.key]
            visibleCategories[#visibleCategories + 1] = category
        end
    end

    if isFurnitureVault and #visibleCategories == 0 and #allCategories > 0 then
        local furnishingCategory = allCategories[1]
        furnishingCategory.itemCount = 0
        visibleCategories[1] = furnishingCategory
    end

    return visibleCategories
end

function BETTERUI.Banking.Class.ComputeVisibleBankCategories(self)
    return CategoryManager.ComputeVisibleBankCategories(self)
end

function BETTERUI.Banking.Class:CycleCategory(delta)
    BETTERUI.CIM.HeaderNavigation.CycleCategory(self, delta, {
        categories = self.bankCategories,
        getCurrentIndex = function() return self.currentCategoryIndex or 1 end,
        setCurrentIndex = function(idx) self.currentCategoryIndex = idx end,
        tabBar = self.headerGeneric and self.headerGeneric.tabBar,
        onRefresh = function() self:RefreshList() end,
    })
end

function BETTERUI.Banking.Class:UpdateHeaderTitle()
    local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    local titleText
    if cat and cat.name then
        titleText = zo_strformat("<<1>>", cat.name)
    else
        titleText = GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE"))
    end

    if self.SetTitle then
        self:SetTitle(titleText)
    elseif self.titleControl and self.titleControl.SetText then
        self.titleControl:SetText(titleText)
    end

    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
end

function BETTERUI.Banking.Class:EnsureHeaderKeybindsActive()
    if self.isInHeaderSortMode then
        return
    end

    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end

    if tabBar.Activate and not tabBar.active then
        tabBar:Activate()
    end

    if tabBar.keybindStripDescriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(tabBar.keybindStripDescriptor)
    end
end

function BETTERUI.Banking.Class:RebuildHeaderCategories()
    if not (self.header and self.bankCategories) then return end
    local headerGeneric = self.headerGeneric
    if not headerGeneric then
        self:UpdateHeaderTitle()
        return
    end
    self.bankHeaderData = self.bankHeaderData or {}
    self.bankHeaderData.titleText = function()
        local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
        return (cat and cat.name) or GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_ALL"))
    end
    self.bankHeaderData.tabBarData = { parent = self }
    local isCarousel = BETTERUI.GetSetting("Banking", "enableCarousel", false)
    self.bankHeaderData.carouselConfig = {
        enabled = isCarousel,
        startOffset = BETTERUI.Banking.CONST.CAROUSEL.startOffset,
        verticalOffset = BETTERUI.Banking.CONST.CAROUSEL.verticalOffset,
        itemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing,
    }

    local coalescedHandler = BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler({
        delay = BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS,
        onSave = function(instance) instance:SaveListPosition() end,
        onApply = function(instance, newIndex)
            instance.currentCategoryIndex = newIndex
            instance:UpdateHeaderTitle()
            instance:RefreshList()
        end,
        sceneCheck = function()
            return BETTERUI.Utils.IsBankingSceneShowing()
        end,
    })
    self.bankHeaderData.onSelectedChanged = function(list, selectedData)
        coalescedHandler(self, list, selectedData)
    end

    if not headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(headerGeneric, self.bankHeaderData, false)
    end
    if headerGeneric.tabBar then
        headerGeneric.tabBar:Clear()
    end
    for i = 1, #self.bankCategories do
        local cat = self.bankCategories[i]
        local entryData = ZO_GamepadEntryData:New(cat.name, cat.iconFile)
        entryData.filterType = cat.filterType
        entryData.itemCount = cat.itemCount
        entryData.countBadgeOffsetY = 3
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(headerGeneric, entryData)
    end
    BETTERUI.GenericHeader.Refresh(headerGeneric, self.bankHeaderData, false)

    if headerGeneric.tabBar then
        local idx = zo_clamp(self.currentCategoryIndex or 1, 1, #self.bankCategories)
        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
        if state.justToggledMode then
            headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
        else
            state.suppressHeaderCallback = true
            headerGeneric.tabBar:SetSelectedIndex(idx, true, true)
            state.suppressHeaderCallback = false
        end
    end

    self:UpdateHeaderTitle()
    if self.scene and self.scene:IsShowing() then
        self:EnsureHeaderKeybindsActive()
    end

    if ZO_GamepadGenericHeader_SetHeaderFocusControl and self.textSearchHeaderControl then
        local headerTarget
        if headerGeneric.tabBar and headerGeneric.tabBar.control then
            headerTarget = headerGeneric.tabBar.control
        elseif headerGeneric then
            headerTarget = headerGeneric
        else
            headerTarget = self.header
        end
        ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
    end
end
