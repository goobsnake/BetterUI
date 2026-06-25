--[[
File: Modules/Banking/UI/HeaderManager.lua
Purpose: Manages the banking header UI (categories, tabs, title).
         Uses CIM.HeaderNavigation for shared navigation logic.
]]

-- SHARED CONSTANTS

local function TraceBankHeader(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = data.module or "Banking"
    data.feature = data.feature or "header"
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.STATE, event, phase, data)
end

function BETTERUI.Banking.Class:CycleCategory(delta)
    TraceBankHeader("bank.header", "cycle_requested", {
        fn = "CycleCategory",
        delta = delta,
        currentCategoryIndex = self.currentCategoryIndex,
        categoryCount = self.bankCategories and #self.bankCategories or 0,
        headerSortMode = self.isInHeaderSortMode == true,
    })
    BETTERUI.CIM.HeaderNavigation.CycleCategory(self, delta, {
        categories = self.bankCategories,
        getCurrentIndex = function() return self.currentCategoryIndex or 1 end,
        setCurrentIndex = function(idx) self.currentCategoryIndex = idx end,
        tabBar = self.headerGeneric and self.headerGeneric.tabBar,
        onRefresh = function() self:RefreshList() end,
    })
end

--- Updates the header title text to match the current category.
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

    -- Reposition the search control so it sits under the header/title (above the list)
    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
    TraceBankHeader("bank.header", "title_updated", {
        fn = "UpdateHeaderTitle",
        titleText = titleText,
        categoryIndex = self.currentCategoryIndex or 1,
        categoryName = cat and cat.name or nil,
        positionedSearch = self.PositionSearchControl ~= nil,
    })
end

--- Activates the category tab bar keybinds.
function BETTERUI.Banking.Class:EnsureHeaderKeybindsActive()
    if self.isInHeaderSortMode then
        TraceBankHeader("bank.header_keybinds", "skipped", {
            fn = "EnsureHeaderKeybindsActive",
            reason = "headerSortMode",
        })
        return
    end

    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        TraceBankHeader("bank.header_keybinds", "skipped", {
            fn = "EnsureHeaderKeybindsActive",
            reason = "missingTabBar",
        })
        return
    end

    if tabBar.Activate and not tabBar.active then
        tabBar:Activate()
    end

    if tabBar.keybindStripDescriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(tabBar.keybindStripDescriptor)
    end
    TraceBankHeader("bank.header_keybinds", "active", {
        fn = "EnsureHeaderKeybindsActive",
        activated = tabBar.Activate ~= nil,
        hasDescriptor = tabBar.keybindStripDescriptor ~= nil,
    })
end

--- Rebuilds the banking category header.
function BETTERUI.Banking.Class:RebuildHeaderCategories()
    if not (self.header and self.bankCategories) then
        TraceBankHeader("bank.header", "rebuild_skipped", {
            fn = "RebuildHeaderCategories",
            reason = not self.header and "missingHeader" or "missingCategories",
        })
        return
    end
    local headerGeneric = self.headerGeneric
    if not headerGeneric then
        self:UpdateHeaderTitle()
        TraceBankHeader("bank.header", "rebuild_skipped", {
            fn = "RebuildHeaderCategories",
            reason = "missingGenericHeader",
            updatedTitle = true,
        })
        return
    end

    -- Prepare header data and entries
    self.bankHeaderData = self.bankHeaderData or {}
    self.bankHeaderData.titleText = function()
        local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
        return (cat and cat.name) or GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_ALL"))
    end
    self.bankHeaderData.tabBarData = { parent = self }
    -- Carousel configuration for banking - uses constants from BetterUI.CONST.lua
    local isCarousel = BETTERUI.GetSetting("Banking", "enableCarousel", false)
    self.bankHeaderData.carouselConfig = {
        enabled = isCarousel,
        startOffset = BETTERUI.Banking.CONST.CAROUSEL.startOffset,
        verticalOffset = BETTERUI.Banking.CONST.CAROUSEL.verticalOffset,
        itemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing,
    }
    -- Create coalesced handler using CIM NavigationState
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
    -- Wrap to pass self as first argument (onSelectedChanged receives list, selectedData)
    self.bankHeaderData.onSelectedChanged = function(list, selectedData)
        coalescedHandler(self, list, selectedData)
    end


    -- Ensure tabbar exists then clear and repopulate
    if not headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(headerGeneric, self.bankHeaderData, false)
    end
    if headerGeneric.tabBar then
        headerGeneric.tabBar:Clear()
    end
    for i = 1, #self.bankCategories do
        local cat = self.bankCategories[i]
        local entryData = ZO_GamepadEntryData:New(cat.name, cat.iconFile)
        entryData.filterType = cat.filterType -- influences icon tint like inventory
        entryData.itemCount = cat.itemCount   -- For category badge display
        entryData.countBadgeOffsetY = 3       -- Position badge lower for banking header layout
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(headerGeneric, entryData)
    end
    TraceBankHeader("bank.header", "entries_built", {
        fn = "RebuildHeaderCategories",
        categoryCount = #self.bankCategories,
        currentCategoryIndex = self.currentCategoryIndex or 1,
        carousel = isCarousel == true,
    })
    BETTERUI.GenericHeader.Refresh(headerGeneric, self.bankHeaderData, false)
    -- Select the current category in the header
    if headerGeneric.tabBar then
        local idx = zo_clamp(self.currentCategoryIndex or 1, 1, #self.bankCategories)
        -- Use NavigationState to check mode toggle status
        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
        -- During mode toggle, use animation-free selection to avoid callback interference
        if state.justToggledMode then
            headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
            TraceBankHeader("bank.header", "selection_applied", {
                fn = "RebuildHeaderCategories",
                index = idx,
                mode = "withoutAnimation",
                justToggledMode = true,
            })
        else
            -- Set suppression flag during rebuild to prevent callback overriding our selection
            state.suppressHeaderCallback = true
            headerGeneric.tabBar:SetSelectedIndex(idx, true, true)
            state.suppressHeaderCallback = false
            TraceBankHeader("bank.header", "selection_applied", {
                fn = "RebuildHeaderCategories",
                index = idx,
                mode = "normal",
                suppressedCallback = true,
            })
        end
    end

    -- Update title to match
    self:UpdateHeaderTitle()
    -- Only activate header keybinds when scene is showing.
    -- Calling EnsureHeaderKeybindsActive during addon load (before scene shows)
    -- registers with DIRECTIONAL_INPUT prematurely, causing joystick lock-up.
    if self.scene and self.scene:IsShowing() then
        self:EnsureHeaderKeybindsActive()
    end
    -- Ensure the header's focus control includes the search control when present so
    -- vertical navigation can move into the header/search like Inventory. Prefer the
    -- module's generic header target when available (self.headerGeneric) to match
    -- where the tabBar and focusable controls were initialized.
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
        TraceBankHeader("bank.header", "focus_control_set", {
            fn = "RebuildHeaderCategories",
            hasHeaderTarget = headerTarget ~= nil,
            hasSearchControl = true,
        })
    end
    TraceBankHeader("bank.header", "rebuild_complete", {
        fn = "RebuildHeaderCategories",
        categoryCount = #self.bankCategories,
        sceneShowing = self.scene and self.scene.IsShowing and self.scene:IsShowing() or nil,
        activatedHeaderKeybinds = self.scene and self.scene.IsShowing and self.scene:IsShowing() or false,
    })
end
