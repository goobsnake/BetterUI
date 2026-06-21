--[[
File: Modules/Inventory/Core/HeaderManager.lua
Purpose: Manages the inventory header, tab switches, and search focus integration.
]]

local INVENTORY_CATEGORY_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.CATEGORY
local INVENTORY_ITEM_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.ITEM
local INVENTORY_CRAFT_BAG_LIST = BETTERUI.Inventory.CONST.LIST_TYPES.CRAFT_BAG

BETTERUI.Inventory.SEARCH_LIFECYCLE = {
    clear = "ClearSearchInput",
    exit = "ExitSearchMode",
    headerActive = "IsHeaderFocused",
    requestEnter = "RequestHeaderFocus",
    onEnter = "OnHeaderEntered",
}

--- @param self BetterUI_InventoryClass
--- @return integer stringId
local function GetActiveInventoryActionStringId(self)
    local activeListType = self.currentListType or INVENTORY_ITEM_LIST
    if activeListType == INVENTORY_CRAFT_BAG_LIST then
        return SI_BETTERUI_INV_ACTION_CB
    end
    return SI_BETTERUI_INV_ACTION_INV
end

--- @param self BetterUI_InventoryClass
local function InitializeHeader(self)
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.FOOTER, "InitializeHeader: setting up category header data") end
    local function UpdateTitleText()
        return GetString(GetActiveInventoryActionStringId(self))
    end

    local tabBarEntries = {
        {
            text = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_CATEGORY_HEADER")),
            callback = function()
                self:SwitchActiveList(INVENTORY_CATEGORY_LIST)
            end,
        },
        {
            text = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER")),
            callback = function()
                self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
            end,
        },
    }

    -- Inline default must match the registered module default (Module.lua: enableCarousel = true).
    local isCarousel = BETTERUI.GetSetting("Inventory", "enableCarousel", true)

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
        -- Category icon clicks route through this callback; CIM's generic tab
        -- bar no longer hard-codes inventory dispatch.
        self.header.tabBar.onCategoryClicked = function(_, index)
            if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.OnCategoryClicked then
                GAMEPAD_INVENTORY:OnCategoryClicked(index)
            end
        end
    end

    -- Footer is owned by the shared CIM unified footer controller, captured once via
    -- SetupUnifiedFooter (also consumed in InitializeDeferredInventoryDialogs). Avoid
    -- rebinding the legacy global GenericFooter singleton here.
    if self.SetupUnifiedFooter and not self.unifiedFooterController then
        self:SetupUnifiedFooter()
    end
end

--- @param self BetterUI_InventoryClass
--- @param index number 1-based category index
local function OnCategoryClicked(self, index)
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.NAV, "category clicked", {index = index}) end
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

--- @param self BetterUI_InventoryClass
local function ActivateHeader(self)
    ZO_GamepadGenericHeader_Activate(self.header)
    -- tabBar is created lazily by GenericHeader.Refresh; guard it in case deferred init was
    -- interrupted (other call sites in this file guard self.header.tabBar the same way).
    local tabBar = self.header and self.header.tabBar
    if tabBar then
        tabBar:SetSelectedIndexWithoutAnimation(self.categoryList and self.categoryList.selectedIndex or 1, true, false)
    end
end

--- @param self BetterUI_InventoryClass
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

--- @param self BetterUI_InventoryClass
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

--- @param self BetterUI_InventoryClass
local function EnsureHeaderKeybindsActive(self)
    local tabBar = self.header and self.header.tabBar
    if not tabBar then
        return
    end

    local descriptor = tabBar.keybindStripDescriptor
    -- PB-002: When an action dialog closes, KEYBIND_STRIP:PopKeybindGroupState()
    -- can restore a snapshot that no longer carries the ethereal LB/RB carousel
    -- group, while tabBar.active is left stale-true (the PARAMETRIC action dialog
    -- never calls tabBar:Deactivate()). A stale-true active flag would skip the
    -- plain Activate() below, leaving LB/RB paging dead. Detect the missing group
    -- and force a real re-activation cycle.
    local carouselMissing = descriptor and KEYBIND_STRIP
        and not KEYBIND_STRIP:HasKeybindButtonGroup(descriptor)

    if carouselMissing and tabBar.Deactivate and tabBar.Activate then
        -- Guarded Deactivate/Activate (NOT raw tabBar.active = false) so the
        -- single-registration parametric-list activation semantics hold.
        -- BETTERUI_TabBarScrollList sets SetDirectionalInputEnabled(false) at
        -- creation, so neither Deactivate nor Activate touches DIRECTIONAL_INPUT;
        -- Activate only (re)adds the carousel keybind group. This avoids the
        -- double-DI "fast scroll" failure mode documented in tribal-knowledge.
        tabBar:Deactivate()
        tabBar:Activate()
    elseif tabBar.Activate and not tabBar.active then
        -- Normal path: tabBar simply needs activating so LB/RB navigation works.
        tabBar:Activate()
    end

    -- Belt-and-suspenders: ensure the carousel keybind group is registered even
    -- if Activate was skipped (e.g. tabBar.active was already true and the group
    -- was present).
    if descriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor)
    end
end

--- @param self BetterUI_InventoryClass
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

--- @param self BetterUI_InventoryClass
local function ClearSearchInput(self)
    if self.ClearTextSearch then
        self:ClearTextSearch()
        return
    end

    self.searchQuery = ""

    local textSearchHeaderFocus = self.textSearchHeaderFocus
    if textSearchHeaderFocus and textSearchHeaderFocus.ClearText then
        textSearchHeaderFocus:ClearText()
    end
end

--- @param self BetterUI_InventoryClass
local function ExitSearchMode(self)
    if self.ExitSearchFocus then
        self:ExitSearchFocus()
        return
    end

    ExitSearchFocus(self)
end

--- @param self BetterUI_InventoryClass
--- @return boolean
local function IsHeaderFocused(self)
    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    if searchMixin and searchMixin.IsSearchHeaderActive then
        return searchMixin.IsSearchHeaderActive(self) == true
    end

    if self.IsHeaderActive then
        return self:IsHeaderActive() == true
    end

    return false
end

--- @param self BetterUI_InventoryClass
local function RequestHeaderFocus(self)
    if self.RequestEnterHeader then
        self:RequestEnterHeader()
        return
    end

    if self.OnEnterHeader then
        self:OnEnterHeader()
        return
    end

    OnEnterHeader(self)
end

--- @param self BetterUI_InventoryClass
local function OnHeaderEntered(self)
    if self.OnEnterHeader then
        self:OnEnterHeader()
        return
    end

    OnEnterHeader(self)
end

local Class = BETTERUI.Inventory.Class

function Class:InitializeHeader()
    return InitializeHeader(self)
end

function Class:OnCategoryClicked(direction)
    return OnCategoryClicked(self, direction)
end

function Class:ActivateHeader()
    return ActivateHeader(self)
end

function Class:OnEnterHeader()
    return OnEnterHeader(self)
end

function Class:OnHeaderEntered()
    return OnHeaderEntered(self)
end

function Class:OnLeaveHeader()
    return OnLeaveHeader(self)
end

function Class:EnsureHeaderKeybindsActive()
    return EnsureHeaderKeybindsActive(self)
end

function Class:ClearSearchInput()
    return ClearSearchInput(self)
end

function Class:ExitSearchMode(...)
    return ExitSearchMode(self, ...)
end

function Class:IsHeaderFocused()
    return IsHeaderFocused(self)
end

function Class:RequestHeaderFocus()
    return RequestHeaderFocus(self)
end

function Class:ExitSearchFocus()
    return ExitSearchFocus(self)
end

Class.SEARCH_LIFECYCLE = BETTERUI.Inventory.SEARCH_LIFECYCLE
