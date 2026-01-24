--[[
File: Modules/Banking/UI/HeaderManager.lua
Purpose: Manages the banking header UI (categories, tabs, title).
         Extracted from Banking.lua.
Author: BetterUI Team
Last Modified: 2026-01-24
]]

local _

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

--[[
Function: BETTERUI.Banking.Class:CycleCategory
Description: Cycles the selected category via shoulder buttons (Left/Right).
param: delta (number) - Direction (+1 or -1).
]]
function BETTERUI.Banking.Class:CycleCategory(delta)
    if not (self.bankCategories and #self.bankCategories > 1) then return end
    local count = #self.bankCategories
    local idx = (self.currentCategoryIndex or 1) + delta
    if idx < 1 then idx = count end
    if idx > count then idx = 1 end
    self:SaveListPosition()
    -- Drive selection via header tabbar; onSelectedChanged will handle refresh
    if self.headerGeneric and self.headerGeneric.tabBar then
        self.headerGeneric.tabBar:SetSelectedIndex(idx, true, true)
    else
        self.currentCategoryIndex = idx
        self:RefreshList()
    end
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
        startOffset = BETTERUI_BANKING_CAROUSEL_START_OFFSET,
        verticalOffset = BETTERUI_BANKING_CAROUSEL_VERTICAL_OFFSET,
        itemSpacing = BETTERUI_CAROUSEL_ITEM_SPACING,
    }
    self.bankHeaderData.onSelectedChanged = function(list, selectedData)
        -- Skip callback during mode toggle to prevent override
        if self._justToggledMode then
            return
        end
        -- Skip callback during rebuild to prevent override after category removal
        if self._suppressHeaderCallback then
            return
        end
        -- Coalesce rapid tab changes: only refresh once after navigation settles
        self.currentCategoryIndex = list.selectedIndex or 1
        self._categoryChangeToken = (self._categoryChangeToken or 0) + 1
        local myToken = self._categoryChangeToken
        -- Assert suppression tied to this token
        self._suppressListUpdatesToken = myToken
        self._suppressListUpdates = true
        -- Wait a short moment; if more changes occur, older timers abort via token check
        zo_callLater(function()
            -- If the banking scene is no longer visible, drop this refresh to avoid
            -- re-activating controls or keybinds while hidden
            if not (SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing()) then
                -- clear suppression for safety
                if self._suppressListUpdatesToken == myToken then
                    self._suppressListUpdates = false
                    self._suppressListUpdatesToken = nil
                end
                return
            end
            if myToken ~= self._categoryChangeToken then
                -- A newer selection occurred; let the latest timer handle refresh/suppression
                return
            end
            -- We're the latest change; clear suppression and refresh once
            if self._suppressListUpdates and self._suppressListUpdatesToken == myToken then
                self._suppressListUpdates = false
                self._suppressListUpdatesToken = nil
            end
            self:UpdateHeaderTitle()
            self:RefreshList()
        end, 100) -- ~6 frames; avoids loading intermediate categories during wrap
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
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(self.headerGeneric, entryData)
    end
    BETTERUI.GenericHeader.Refresh(self.headerGeneric, self.bankHeaderData, false)
    -- Select the current category in the header
    if self.headerGeneric.tabBar then
        local idx = zo_clamp(self.currentCategoryIndex or 1, 1, #self.bankCategories)
        -- During mode toggle, use animation-free selection to avoid callback interference
        if self._justToggledMode then
            self.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
        else
            -- Suppress callback during rebuild to prevent it overriding our selection
            self._suppressHeaderCallback = true
            self.headerGeneric.tabBar:SetSelectedIndex(idx, true, true)
            self._suppressHeaderCallback = false
        end
    end
    -- Update title to match
    self:UpdateHeaderTitle()
    self:EnsureHeaderKeybindsActive()
    -- Ensure the header's focus control includes the search control when present so
    -- vertical navigation can move into the header/search like Inventory. Prefer the
    -- module's generic header target when available (self.headerGeneric) to match
    -- where the tabBar and focusable controls were initialized.
    if ZO_GamepadGenericHeader_SetHeaderFocusControl and self.textSearchHeaderControl then
        pcall(function()
            local headerTarget = nil
            if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.control then
                headerTarget = self.headerGeneric.tabBar.control
            elseif self.headerGeneric then
                headerTarget = self.headerGeneric
            else
                headerTarget = self.header
            end
            ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
        end)
    end
end
