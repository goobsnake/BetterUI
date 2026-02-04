--[[
File: Modules/Banking/UI/HeaderManager.lua
Purpose: Manages the banking header UI (categories, tabs, title).
         Uses CIM.HeaderNavigation for shared navigation logic.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

--[[
Function: BETTERUI.Banking.Class:CycleCategory
Description: Cycles the selected category via shoulder buttons (Left/Right).
Rationale: Delegates to CIM.HeaderNavigation for shared navigation logic.
param: delta (number) - Direction (+1 or -1).
]]
function BETTERUI.Banking.Class:CycleCategory(delta)
    BETTERUI.CIM.HeaderNavigation.CycleCategory(self, delta, {
        categories = self.bankCategories,
        getCurrentIndex = function() return self.currentCategoryIndex or 1 end,
        setCurrentIndex = function(idx) self.currentCategoryIndex = idx end,
        tabBar = self.headerGeneric and self.headerGeneric.tabBar,
        onRefresh = function() self:RefreshList() end,
    })
end

--[[
Function: BETTERUI.Banking.Class:UpdateHeaderTitle
Description: Updates the header title text to match the current category.
]]
function BETTERUI.Banking.Class:UpdateHeaderTitle()
    local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    if cat and cat.name then
        -- Match inventory: use default title color (white), no custom color tags
        self:SetTitle(zo_strformat("<<1>>", cat.name))
    else
        self.titleControl:SetText(GetString(SI_BETTERUI_BANK_TITLE))
    end
    -- Reposition the search control so it sits under the header/title (above the list)
    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
end

--[[
Function: BETTERUI.Banking.Class:EnsureHeaderKeybindsActive
Description: Activates the category tab bar keybinds.
]]
function BETTERUI.Banking.Class:EnsureHeaderKeybindsActive()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if tabBar and tabBar.keybindStripDescriptor then
        tabBar:Activate()
    end
end

--[[
Function: BETTERUI.Banking.Class:RebuildHeaderCategories
Description: Rebuilds the banking category header.
Rationale: Refresh the tab bar with icons for the current bank mode.
Mechanism:
  - Configures the generic header data (Title, Carousel Config).
  - Defines the `onSelectedChanged` callback to handle tab navigation with coalescence.
  - Clears andRepopulates the Generic Header list with `bankCategories`.
  - Selects the current category (handling animation suppression if needed).
  - Updates Keybinds.
  - Links the Text Search control to the Header Focus chain.
References: Called on Initialize, ToggleList, and Slot Updates.
]]
function BETTERUI.Banking.Class:RebuildHeaderCategories()
    if not (self.header and self.bankCategories) then return end
    -- Prepare header data and entries
    self.bankHeaderData = self.bankHeaderData or {}
    self.bankHeaderData.titleText = function()
        local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
        return (cat and cat.name) or GetString(SI_BETTERUI_INV_ITEM_ALL)
    end
    self.bankHeaderData.tabBarData = { parent = self }
    -- Carousel configuration for banking - uses constants from BetterUI.CONST.lua
    local isCarousel = BETTERUI.Settings.Modules["Banking"].enableCarousel
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
            return BETTERUI.CIM.Utils.IsBankingSceneShowing()
        end,
    })
    -- Wrap to pass self as first argument (onSelectedChanged receives list, selectedData)
    self.bankHeaderData.onSelectedChanged = function(list, selectedData)
        coalescedHandler(self, list, selectedData)
    end


    -- Ensure tabbar exists then clear and repopulate
    if not self.headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(self.headerGeneric, self.bankHeaderData, false)
    end
    if self.headerGeneric.tabBar then
        self.headerGeneric.tabBar:Clear()
    end
    for i = 1, #self.bankCategories do
        local cat = self.bankCategories[i]
        local entryData = ZO_GamepadEntryData:New(cat.name, cat.iconFile)
        entryData.filterType = cat.filterType -- influences icon tint like inventory
        entryData.itemCount = cat.itemCount   -- For category badge display
        entryData.countBadgeOffsetY = 3       -- Position badge lower for banking header layout
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(self.headerGeneric, entryData)
    end
    BETTERUI.GenericHeader.Refresh(self.headerGeneric, self.bankHeaderData, false)
    -- Select the current category in the header
    if self.headerGeneric.tabBar then
        local idx = zo_clamp(self.currentCategoryIndex or 1, 1, #self.bankCategories)
        -- Use NavigationState to check mode toggle status
        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
        local NavState = BETTERUI.CIM.NavigationState
        -- During mode toggle, use animation-free selection to avoid callback interference
        if state.justToggledMode then
            self.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
        else
            -- Set suppression flag during rebuild to prevent callback overriding our selection
            state.suppressHeaderCallback = true
            self.headerGeneric.tabBar:SetSelectedIndex(idx, true, true)
            state.suppressHeaderCallback = false
        end
    end

    -- Update title to match
    self:UpdateHeaderTitle()
    -- CRITICAL: Only activate header keybinds when scene is showing
    -- Calling EnsureHeaderKeybindsActive during addon load (before scene shows)
    -- registers with DIRECTIONAL_INPUT prematurely, causing joystick lock-up
    if self.scene and self.scene:IsShowing() then
        self:EnsureHeaderKeybindsActive()
    end
    -- Ensure the header's focus control includes the search control when present so
    -- vertical navigation can move into the header/search like Inventory. Prefer the
    -- module's generic header target when available (self.headerGeneric) to match
    -- where the tabBar and focusable controls were initialized.
    if ZO_GamepadGenericHeader_SetHeaderFocusControl and self.textSearchHeaderControl then
        local headerTarget = nil
        if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.control then
            headerTarget = self.headerGeneric.tabBar.control
        elseif self.headerGeneric then
            headerTarget = self.headerGeneric
        else
            headerTarget = self.header
        end
        ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
    end
end
