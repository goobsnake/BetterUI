--[[
File: Modules/Inventory/Core/HeaderManager.lua
Purpose: Manages the inventory header, tab switches, and search focus integration.
Author: BetterUI Team
]]

local function InitializeHeader(self)
    local function UpdateTitleText()
        return GetString(
            self:GetCurrentList() == self.craftBagList and SI_BETTERUI_INV_ACTION_CB or SI_BETTERUI_INV_ACTION_INV
        )
    end

    local tabBarEntries = {
        {
            text = GetString(SI_GAMEPAD_INVENTORY_CATEGORY_HEADER),
            callback = function()
                self:SwitchActiveList(INVENTORY_CATEGORY_LIST)
            end,
        },
        {
            text = GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER),
            callback = function()
                self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
            end,
        },
    }

    local isCarousel = BETTERUI.Settings.Modules["Inventory"].enableCarousel

    self.categoryHeaderData = {
        titleText = UpdateTitleText,
        tabBarEntries = tabBarEntries,
        -- Use onNext/onPrev callbacks instead of onSelectedChanged
        tabBarData = { parent = self, onNext = BETTERUI.Inventory.Utils.OnTabNext, onPrev = BETTERUI.Inventory.Utils.OnTabPrev },
        carouselConfig = {
            enabled = isCarousel,
        },
    }

    -- Header data will be built dynamically in RefreshHeader based on settings
    self.craftBagHeaderData = nil
    self.itemListHeaderData = nil

    BETTERUI.GenericHeader.Initialize(self.header, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
    BETTERUI.GenericHeader.SetEquipText(self.header, self.isPrimaryWeapon)
    BETTERUI.GenericHeader.SetBackupEquipText(self.header, self.isPrimaryWeapon)

    BETTERUI.GenericHeader.Refresh(self.header, self.categoryHeaderData, ZO_GAMEPAD_HEADER_TABBAR_CREATE)

    -- Fix for non-clickable category icons: Ensure scrollList is explicitly linked to the UI control
    local tabBarControl = self.header:GetNamedChild("TabBar")
    if tabBarControl and self.header.tabBar then
        tabBarControl.scrollList = self.header.tabBar
    end

    BETTERUI.GenericFooter.Initialize(self)
end

local function OnCategoryClicked(self, index)
    if not index or not self.categoryList then return end

    local count = #self.categoryList.dataList
    if index < 1 or index > count then return end

    -- Usually clicking the active tab does nothing.
    if self.categoryList.selectedIndex == index then return end

    -- Save position of the OLD category before switching
    self:SaveListPosition()

    -- Update Inventory Class state to match the new selection
    self.categoryList.selectedIndex = index
    self.categoryList.targetSelectedIndex = index
    self.categoryList.selectedData = self.categoryList.dataList[index]
    self.categoryList.defaultSelectedIndex = index

    -- Refresh current list with new filter
    self:ToSavedPosition()
end

local function ActivateHeader(self)
    ZO_GamepadGenericHeader_Activate(self.header)
    self.header.tabBar:SetSelectedIndexWithoutAnimation(self.categoryList.selectedIndex, true, false)
end

local function OnEnterHeader(self)
    -- Exit header sort mode cleanly when navigating up to the Search/Header area
    if self.isInHeaderSortMode and self.ExitHeaderSortMode then
        self:ExitHeaderSortMode()
    end

    if ZO_GamepadInventory and ZO_GamepadInventory.OnEnterHeader then
        ZO_GamepadInventory.OnEnterHeader(self)
    else
        ZO_Gamepad_ParametricList_Screen.OnEnterHeader(self)
    end

    if self.textSearchHeaderControl and not self.textSearchHeaderControl:IsHidden() then
        if self.textSearchHeaderFocus and not self.textSearchHeaderFocus:IsActive() then
            self.textSearchHeaderFocus:Activate()
        end
        if self.SetTextSearchFocused then
            self:SetTextSearchFocused(true)
        end
    end
end

local function OnLeaveHeader(self)
    if ZO_GamepadInventory and ZO_GamepadInventory.OnLeaveHeader then
        ZO_GamepadInventory.OnLeaveHeader(self)
    else
        ZO_Gamepad_ParametricList_Screen.OnLeaveHeader(self)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Deactivate()
    end

    -- Zero-delay to defer keybind activation to next frame, preventing race conditions
    BETTERUI.Inventory.Tasks:Schedule("headerLeaveKeybinds", 0, function()
        if self.scene and self.scene:IsShowing() then
            if self.EnsureHeaderKeybindsActive then
                self:EnsureHeaderKeybindsActive()
            end
        end
    end)
end

local function EnsureHeaderKeybindsActive(self)
    local tabBar = self.header and self.header.tabBar
    if tabBar then
        -- Ensure the tabBar is active so LB/RB navigation works
        if tabBar.Activate and not tabBar.active then
            tabBar:Activate()
        end
        -- Ensure keybinds are registered
        if tabBar.keybindStripDescriptor then
            BETTERUI.Interface.EnsureKeybindGroupAdded(tabBar.keybindStripDescriptor)
        end
    end
end

local function ExitSearchFocus(self)
    -- Skip if in header sort mode to preserve header mode keybinds
    if self.isInHeaderSortMode then
        return
    end

    -- Remove search keybinds first
    if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
    end

    -- Add back main keybinds
    if self.mainKeybindStripDescriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.mainKeybindStripDescriptor)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
    end

    -- Deactivate the search header focus
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate then
        if self.textSearchHeaderFocus:IsActive() then
            if self.textSearchHeaderFocus.Deactivate then
                self.textSearchHeaderFocus:Deactivate()
            end
        end
    end

    -- Leave header if active
    if self:IsHeaderActive() then
        self:RequestLeaveHeader()
    end

    -- Activate the current list so it receives input
    local currentList = self:GetCurrentList()
    if currentList then
        if currentList.Activate and (not currentList.IsActive or not currentList:IsActive()) then
            currentList:Activate()
        end
    end
end

-- Register mixins
if BETTERUI.Inventory.RegisterMixin then
    BETTERUI.Inventory.RegisterMixin("InitializeHeader", InitializeHeader)
    BETTERUI.Inventory.RegisterMixin("OnCategoryClicked", OnCategoryClicked)
    BETTERUI.Inventory.RegisterMixin("ActivateHeader", ActivateHeader)
    BETTERUI.Inventory.RegisterMixin("OnEnterHeader", OnEnterHeader)
    BETTERUI.Inventory.RegisterMixin("OnLeaveHeader", OnLeaveHeader)
    BETTERUI.Inventory.RegisterMixin("EnsureHeaderKeybindsActive", EnsureHeaderKeybindsActive)
    BETTERUI.Inventory.RegisterMixin("ExitSearchFocus", ExitSearchFocus)
end
