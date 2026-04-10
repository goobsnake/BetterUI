-- Modules/Vendor/Core/VendorClass.lua
-- Core class definition, constants, and mode-routing for the Vendor module.
--
-- Component-tab model: each tab is a separate "mode" with its own list builder
-- and keybinds. Active mode tracked in self.currentMode, changed via SetMode().

-- NAMESPACE & GUARD
if not BETTERUI.Vendor then BETTERUI.Vendor = {} end

-- SCENE CONSTANTS

BETTERUI_VENDOR_SCENE_NAME = "BETTERUI_VENDOR"

BETTERUI.Vendor.VENDOR_INTERACTION = STORE_INTERACTION

-- Fence shares the vendor scene but opens via EVENT_OPEN_FENCE.
BETTERUI.Vendor.FENCE_INTERACTION = {
    type = "Fence",
    interactTypes = { INTERACTION_VENDOR },
}

-- MODE CONSTANTS

BETTERUI.Vendor.MODE = {
    BUY           = 1,
    SELL          = 2,
    REPAIR        = 3,
    BUYBACK       = 4,
    FENCE_SELL    = 5,
    FENCE_LAUNDER = 6,
}

local DEFAULT_VENDOR_CATEGORY_ICON = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"

local function ResolveNativeStoreMode(mode)
    if mode == BETTERUI.Vendor.MODE.BUY then
        return rawget(_G, "ZO_MODE_STORE_BUY")
    elseif mode == BETTERUI.Vendor.MODE.SELL then
        return rawget(_G, "ZO_MODE_STORE_SELL")
    elseif mode == BETTERUI.Vendor.MODE.REPAIR then
        return rawget(_G, "ZO_MODE_STORE_REPAIR")
    elseif mode == BETTERUI.Vendor.MODE.BUYBACK then
        return rawget(_G, "ZO_MODE_STORE_BUY_BACK")
    elseif mode == BETTERUI.Vendor.MODE.FENCE_SELL then
        return rawget(_G, "ZO_MODE_STORE_SELL_STOLEN")
    elseif mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER then
        return rawget(_G, "ZO_MODE_STORE_LAUNDER")
    end
    return nil
end

local function ResolveModeName(mode)
    if mode == BETTERUI.Vendor.MODE.BUY then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY") or "SI_BETTERUI_VENDOR_TAB_BUY")
    elseif mode == BETTERUI.Vendor.MODE.SELL then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL") or "SI_BETTERUI_VENDOR_TAB_SELL")
    elseif mode == BETTERUI.Vendor.MODE.REPAIR then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_REPAIR") or "SI_BETTERUI_VENDOR_TAB_REPAIR")
    elseif mode == BETTERUI.Vendor.MODE.BUYBACK then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUYBACK") or "SI_BETTERUI_VENDOR_TAB_BUYBACK")
    elseif mode == BETTERUI.Vendor.MODE.FENCE_SELL then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_SELL") or "SI_BETTERUI_VENDOR_TAB_FENCE_SELL")
    elseif mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER") or "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER")
    end
    return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TITLE") or "SI_BETTERUI_VENDOR_TITLE")
end

local function ResolveModeIcon(mode)
    if mode == BETTERUI.Vendor.MODE.BUY then
        return "EsoUI/Art/Vendor/vendor_tabIcon_buy_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.SELL then
        return "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.REPAIR then
        return "EsoUI/Art/Vendor/vendor_tabIcon_repair_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.BUYBACK then
        return "EsoUI/Art/Vendor/vendor_tabIcon_buyBack_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.FENCE_SELL then
        return "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER then
        return "EsoUI/Art/Vendor/vendor_tabIcon_fence_up.dds"
    end
    return DEFAULT_VENDOR_CATEGORY_ICON
end

local function BuildHeaderModeTabs(activeTabs)
    local modeTabs = {}
    local isFenceInteraction = BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction()

    for _, tab in ipairs(activeTabs or {}) do
        if isFenceInteraction then
            modeTabs[#modeTabs + 1] = tab
        elseif tab.mode ~= BETTERUI.Vendor.MODE.BUY and tab.mode ~= BETTERUI.Vendor.MODE.SELL then
            modeTabs[#modeTabs + 1] = tab
        end
    end

    return modeTabs
end

local function BuildFallbackCategory()
    return {
        key = "all",
        name = GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_ALL") or "SI_BETTERUI_INV_ITEM_ALL"),
        iconFile = DEFAULT_VENDOR_CATEGORY_ICON,
        itemCount = 0,
    }
end

local function SafeCall(context, fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end

    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute then
        return BETTERUI.CIM.SafeExecute(context, fn, ...)
    end

    local ok, result = pcall(fn, ...)
    return ok, result
end

local HEADER_COLUMN_KEYS = { "NAME", "TYPE", "TRAIT", "STAT", "VALUE" }
local LAYOUT_COLUMN_KEYS = { "SUBMENU", "TYPE", "TRAIT", "STAT", "VALUE" }

local function ResolveHeaderColumnOffset(columnIndex)
    if not columnIndex then
        return nil
    end

    local headerColumns = BETTERUI.CIM.CONST.HEADER_LAYOUT and BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    if headerColumns then
        local headerKey = HEADER_COLUMN_KEYS[columnIndex]
        if headerKey and headerColumns[headerKey] then
            return headerColumns[headerKey]
        end
    end

    local layoutColumns = BETTERUI.CIM.CONST.LAYOUT and BETTERUI.CIM.CONST.LAYOUT.COLUMNS
    if layoutColumns then
        local layoutKey = LAYOUT_COLUMN_KEYS[columnIndex]
        local columnDef = layoutKey and layoutColumns[layoutKey]
        if type(columnDef) == "table" and columnDef.OFFSET_X then
            return columnDef.OFFSET_X
        end

        local legacyOffset = layoutColumns[columnIndex]
        if type(legacyOffset) == "number" then
            return legacyOffset
        end
    end

    return nil
end

-- MODULE-SCOPE TASK MANAGER (for coalescing list refreshes)
assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask, "BetterUI: CIM.DeferredTask must load before Vendor/Core/VendorClass")
BETTERUI.Vendor.Tasks = BETTERUI.CIM.DeferredTask.Manager:New()

-- CLASS DEFINITION

---@class BETTERUI.Vendor.Class : BETTERUI.CIM.GenericWindow
---@field currentMode number Current active vendor mode (see BETTERUI.Vendor.MODE)
---@field components table<number, VendorComponent> Registered mode components
---@field list table|nil Parametric list control
---@field coreKeybinds table Core keybind button group
---@field header table|nil Header control with SetTitle method
---@field _keybindsAdded boolean Whether keybinds are currently registered
---@field _suppressListUpdates boolean Whether list refreshes are suppressed
---@field _isDirty boolean Whether list needs refresh after suppression ends
---@field unifiedFooterController table|nil Footer controller reference
BETTERUI.Vendor.Class = BETTERUI.CIM.GenericWindow:Subclass()

---@param ... any Arguments forwarded to GenericWindow:New
---@return BETTERUI.Vendor.Class
function BETTERUI.Vendor.Class:New(...)
    local obj = BETTERUI.CIM.GenericWindow.New(self, ...)
    return obj --[[@as BETTERUI.Vendor.Class]]
end

---@return boolean showing True if the vendor scene is currently showing
function BETTERUI.Vendor.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

---@return boolean active True when the vendor scene is not hidden (showing/shown/transitioning)
function BETTERUI.Vendor.Class:IsSceneActiveOrShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then
        return false
    end
    if scene.GetState and rawget(_G, "SCENE_HIDDEN") then
        return scene:GetState() ~= SCENE_HIDDEN
    end
    return scene:IsShowing()
end

-- MODE ROUTING

---@return number mode Current vendor mode constant
function BETTERUI.Vendor.Class:GetCurrentMode()
    return self.currentMode or BETTERUI.Vendor.MODE.BUY
end

---@param mode number|nil
---@return nil
function BETTERUI.Vendor.Class:ApplyNativeStoreMode(mode)
    local targetMode = ResolveNativeStoreMode(mode or self:GetCurrentMode())
    if targetMode == nil then
        return
    end

    if type(SetStoreMode) == "function" then
        local currentMode = nil
        if type(GetStoreMode) == "function" then
            local okGetMode, modeResult = SafeCall("Vendor.ApplyNativeStoreMode:GetStoreMode", GetStoreMode)
            if okGetMode then
                currentMode = modeResult
            end
        end
        if currentMode ~= targetMode then
            SafeCall("Vendor.ApplyNativeStoreMode:SetStoreMode", SetStoreMode, targetMode)
        end
    end

    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if not storeManager then
        return
    end

    if type(storeManager.SetMode) ~= "function" then
        return
    end

    local isBuyMode = (mode or self:GetCurrentMode()) == BETTERUI.Vendor.MODE.BUY
    if isBuyMode and BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
        BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
    end

    local activeComponents = storeManager.activeComponents
    if type(activeComponents) ~= "table" or #activeComponents == 0 then
        return
    end

    local hasTargetMode = false
    for _, component in ipairs(activeComponents) do
        if component and type(component.GetStoreMode) == "function" then
            local okMode, componentMode = SafeCall("Vendor.ApplyNativeStoreMode:ComponentMode", component.GetStoreMode, component)
            if okMode and componentMode == targetMode then
                hasTargetMode = true
                break
            end
        end
    end

    if not hasTargetMode then
        if isBuyMode and BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
            BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
            activeComponents = storeManager.activeComponents
            if type(activeComponents) == "table" and #activeComponents > 0 then
                for _, component in ipairs(activeComponents) do
                    if component and type(component.GetStoreMode) == "function" then
                        local okMode, componentMode = SafeCall("Vendor.ApplyNativeStoreMode:ComponentModeRetry", component.GetStoreMode, component)
                        if okMode and componentMode == targetMode then
                            hasTargetMode = true
                            break
                        end
                    end
                end
            end
        end

        if not hasTargetMode then
            return
        end
    end

    local currentMode = nil
    if type(storeManager.GetCurrentMode) == "function" then
        local okCurrent, currentResult = SafeCall("Vendor.ApplyNativeStoreMode:GetCurrentMode", storeManager.GetCurrentMode, storeManager)
        if okCurrent then
            currentMode = currentResult
        end
    end

    if currentMode ~= targetMode then
        SafeCall("Vendor.ApplyNativeStoreMode:StoreManagerSetMode", storeManager.SetMode, storeManager, targetMode)
    end
end

---@return nil
function BETTERUI.Vendor.Class:InitializeCategoryHeader()
    self.modeCategories = self.modeCategories or {}
    self.categoryIndexByMode = self.categoryIndexByMode or {}

    self.headerGeneric = (self.header and self.header:GetNamedChild("Header")) or self.header
    if not self.headerGeneric then
        return
    end

    BETTERUI.GenericHeader.Initialize(self.headerGeneric, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
end

---@param mode number
---@return table[] categories
function BETTERUI.Vendor.Class:GetModeCategories(mode)
    self.modeCategories = self.modeCategories or {}
    local categories = self.modeCategories[mode]
    if not categories or #categories == 0 then
        categories = { BuildFallbackCategory() }
        self.modeCategories[mode] = categories
    end
    return categories
end

---@param mode number
---@param categories table[]|nil
---@return nil
function BETTERUI.Vendor.Class:SetModeCategories(mode, categories)
    self.modeCategories = self.modeCategories or {}
    self.categoryIndexByMode = self.categoryIndexByMode or {}

    if not categories or #categories == 0 then
        categories = { BuildFallbackCategory() }
    end

    self.modeCategories[mode] = categories

    local selectedIndex = self.categoryIndexByMode[mode] or 1
    if selectedIndex < 1 or selectedIndex > #categories then
        selectedIndex = 1
    end
    self.categoryIndexByMode[mode] = selectedIndex

    if mode == self:GetCurrentMode() then
        self.currentCategoryIndex = selectedIndex
        self:RebuildCategoryHeader()
    end
end

---@return table category
function BETTERUI.Vendor.Class:GetCurrentCategory()
    local mode = self:GetCurrentMode()
    local categories = self:GetModeCategories(mode)
    local selectedIndex = (self.categoryIndexByMode and self.categoryIndexByMode[mode]) or 1
    if selectedIndex < 1 or selectedIndex > #categories then
        selectedIndex = 1
        self.categoryIndexByMode[mode] = selectedIndex
    end
    self.currentCategoryIndex = selectedIndex
    return categories[selectedIndex]
end

---@return nil
function BETTERUI.Vendor.Class:EnsureHeaderKeybindsActive()
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

---@return nil
function BETTERUI.Vendor.Class:BindHeaderMouseBumpers()
    local headerGeneric = self.headerGeneric
    local tabBar = headerGeneric and headerGeneric.tabBar
    local tabBarControl = headerGeneric and headerGeneric:GetNamedChild("TabBar")
    if not (tabBar and tabBarControl) then
        return
    end

    -- Keep XML click handlers targeting the current active tab-bar list.
    -- Inventory/Banking rely on this scrollList link and let XML handlers fire.
    tabBarControl.scrollList = tabBar

    local function BindTabBarButton(buttonName)
        local button = tabBarControl:GetNamedChild(buttonName)
        if not button then
            return
        end

        button:SetMouseEnabled(true)
        -- GenericHeader.xml already wires OnClicked -> BETTERUI_TabBar_On*IconClicked().
        -- Vendor previously added an extra OnMouseUp handler here, which caused one mouse
        -- click to advance twice and could race against a header rebuild after a mode switch.
        -- Clear any legacy runtime handler and let the shared XML path own bumper clicks.
        button:SetHandler("OnMouseUp", nil)
    end

    BindTabBarButton("LeftIcon")
    BindTabBarButton("RightIcon")
end

---@return nil
function BETTERUI.Vendor.Class:EnsureListInputActive()
    local list = self.list
    if not list then
        return
    end

    if list.SetDirectionalInputEnabled then
        list:SetDirectionalInputEnabled(true)
    end

    if list.Activate and (not list.IsActive or not list:IsActive()) then
        list:Activate()
    end
end

---@return nil
function BETTERUI.Vendor.Class:InitializeScrollIndicator()
    if not (self.list and self.list.control and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator) then
        return
    end

    BETTERUI.CIM.ScrollIndicator.Initialize(self.list.control, 25, -5, -10, self.list)
end

---@return nil
function BETTERUI.Vendor.Class:ApplyListLayoutTuning()
    local list = self.list
    if not list then
        return
    end

    list.maxOffset = rawget(_G, "BETTERUI_BANK_LIST_MAX_OFFSET") or 30

    local headerPaddingScale = rawget(_G, "BETTERUI_BANK_HEADER_PADDING_SCALE") or 0.75
    if list.SetHeaderPadding and GAMEPAD_HEADER_DEFAULT_PADDING and GAMEPAD_HEADER_SELECTED_PADDING then
        list:SetHeaderPadding(
            GAMEPAD_HEADER_DEFAULT_PADDING * headerPaddingScale,
            GAMEPAD_HEADER_SELECTED_PADDING * headerPaddingScale
        )
    end
    if list.SetUniversalPostPadding and GAMEPAD_DEFAULT_POST_PADDING then
        list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * headerPaddingScale)
    end

    if list.SetFixedCenterOffset then
        -- Align selected row with the tooltip arrow like Inventory/Banking.
        list:SetFixedCenterOffset(-50)
    end
end

---@param list table|nil
---@return nil
function BETTERUI.Vendor.Class:UpdateScrollIndicator(list)
    local targetList = list or self.list
    local listControl = targetList and targetList.control
    if not (listControl and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator) then
        return
    end

    local currentIndex = targetList.targetSelectedIndex
        or (targetList.GetSelectedIndex and targetList:GetSelectedIndex())
        or 1
    local totalItems = (targetList.GetNumItems and targetList:GetNumItems())
        or (targetList.dataList and #targetList.dataList)
        or 0
    local visibleItems = BETTERUI.CIM.CONST.UI.BANKING_VISIBLE_ITEMS or 10

    BETTERUI.CIM.ScrollIndicator.Update(listControl, currentIndex, totalItems, visibleItems)
end

---@return nil
function BETTERUI.Vendor.Class:DeactivateListInput()
    local list = self.list
    if not list then
        return
    end
    if list.Deactivate and (not list.IsActive or list:IsActive()) then
        list:Deactivate()
    end
end

---@return nil
function BETTERUI.Vendor.Class:EnsureColumnHeadersVisible()
    if not (self.header and self.header.columns) then
        return
    end

    local anchorTarget = (self.header and self.header:GetNamedChild("HeaderTabBar"))
        or (self.headerGeneric and self.headerGeneric:GetNamedChild("TabBar"))
        or (self.header and self.header:GetNamedChild("HeaderColumnBar"))

    for _, label in ipairs(self.header.columns) do
        if label then
            if anchorTarget then
                local idx = label.columnIndex
                local xOffset = ResolveHeaderColumnOffset(idx)
                if xOffset then
                    label:ClearAnchors()
                    label:SetAnchor(LEFT, anchorTarget, BOTTOMLEFT, xOffset, BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET)
                end
            end
            label:SetHidden(false)
            label:SetAlpha(1)
            if label.SetDrawLayer then
                label:SetDrawLayer(DL_OVERLAY)
            end
            if label.SetDrawTier then
                label:SetDrawTier(DT_HIGH)
            end
            if label.SetDrawLevel then
                label:SetDrawLevel(10)
            end
        end
    end
end

---@return nil
function BETTERUI.Vendor.Class:DeactivateHeaderKeybinds()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end
    if tabBar.Deactivate and tabBar.active then
        tabBar:Deactivate()
    end
end

---@return nil
function BETTERUI.Vendor.Class:RebuildCategoryHeader()
    local headerGeneric = self.headerGeneric
    if not headerGeneric then
        return
    end

    local mode = self:GetCurrentMode()
    local categories = self:GetModeCategories(mode)
    local activeTabs = (BETTERUI.Vendor.GetActiveTabs and BETTERUI.Vendor.GetActiveTabs()) or {}
    local modeTabs = BuildHeaderModeTabs(activeTabs)
    local selectedIndex = (self.categoryIndexByMode and self.categoryIndexByMode[mode]) or 1
    selectedIndex = zo_clamp(selectedIndex, 1, #categories)
    self.categoryIndexByMode[mode] = selectedIndex
    self.currentCategoryIndex = selectedIndex

    local selectedCategory = categories[selectedIndex]
    local modeEntryCount = #modeTabs
    local selectedHeaderIndex = modeEntryCount + selectedIndex
    local preferredModeSelection = self._preferredModeHeaderSelectionMode
    if preferredModeSelection and modeEntryCount > 0 then
        for modeEntryIndex, tab in ipairs(modeTabs) do
            if tab.mode == preferredModeSelection then
                selectedHeaderIndex = modeEntryIndex
                break
            end
        end
    end
    self._preferredModeHeaderSelectionMode = nil
    local headerEntries = {}
    for _, tab in ipairs(modeTabs) do
        headerEntries[#headerEntries + 1] = {
            modeSwitchMode = tab.mode,
            name = ResolveModeName(tab.mode),
            iconFile = ResolveModeIcon(tab.mode),
        }
    end
    for categoryIndex, category in ipairs(categories) do
        headerEntries[#headerEntries + 1] = {
            categoryIndex = categoryIndex,
            name = category.name,
            iconFile = category.iconFile or DEFAULT_VENDOR_CATEGORY_ICON,
            filterType = category.filterType,
            itemCount = category.itemCount,
        }
    end

    self.vendorHeaderData = self.vendorHeaderData or {}
    self.vendorHeaderData.titleText = function()
        if selectedCategory and selectedCategory.name and selectedCategory.name ~= "" then
            return zo_strformat("<<1>> - <<2>>", ResolveModeName(mode), selectedCategory.name)
        end
        return ResolveModeName(mode)
    end
    self.vendorHeaderData.tabBarData = { parent = self }
    local carouselStartOffset = (BETTERUI.Banking and BETTERUI.Banking.CONST and BETTERUI.Banking.CONST.CAROUSEL and BETTERUI.Banking.CONST.CAROUSEL.startOffset)
        or BETTERUI.CIM.CONST.CAROUSEL.startOffset
    local carouselVerticalOffset = (BETTERUI.Banking and BETTERUI.Banking.CONST and BETTERUI.Banking.CONST.CAROUSEL and BETTERUI.Banking.CONST.CAROUSEL.verticalOffset)
        or BETTERUI.CIM.CONST.CAROUSEL.verticalOffset
    self.vendorHeaderData.carouselConfig = {
        enabled = BETTERUI.Vendor.GetSetting and (BETTERUI.Vendor.GetSetting("enableCarousel") ~= false) or true,
        startOffset = carouselStartOffset,
        verticalOffset = carouselVerticalOffset,
        itemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing,
    }
    self.vendorHeaderData.onSelectedChanged = function(list)
        if self._suppressVendorHeaderSelection then
            return
        end

        local index = list and list.selectedIndex or selectedHeaderIndex
        index = zo_clamp(index, 1, #headerEntries)
        local selectedEntry = headerEntries[index]
        if not selectedEntry then
            return
        end

        if selectedEntry.modeSwitchMode then
            local targetMode = selectedEntry.modeSwitchMode
            if targetMode ~= mode then
                self._preferredModeHeaderSelectionMode = targetMode
                self:SetMode(targetMode)
                return
            end
            return
        end

        local categoryIndex = selectedEntry.categoryIndex or 1
        if self.categoryIndexByMode[mode] == categoryIndex then
            return
        end

        self.categoryIndexByMode[mode] = categoryIndex
        self.currentCategoryIndex = categoryIndex
        self:RefreshList()
    end

    self._suppressVendorHeaderSelection = true
    if not headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(headerGeneric, self.vendorHeaderData, false)
    end
    if headerGeneric.tabBar then
        headerGeneric.tabBar:Clear()
    end

    for _, entryInfo in ipairs(headerEntries) do
        local entryData = ZO_GamepadEntryData:New(entryInfo.name, entryInfo.iconFile or DEFAULT_VENDOR_CATEGORY_ICON)
        entryData.filterType = entryInfo.filterType
        entryData.itemCount = entryInfo.itemCount
        entryData.modeSwitchMode = entryInfo.modeSwitchMode
        entryData.categoryIndex = entryInfo.categoryIndex
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(headerGeneric, entryData)
    end

    BETTERUI.GenericHeader.Refresh(headerGeneric, self.vendorHeaderData, false)

    if headerGeneric.tabBar then
        headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(selectedHeaderIndex, true, true)
    end
    self._suppressVendorHeaderSelection = false
    self:BindHeaderMouseBumpers()

    if self:IsSceneShowing() then
        self:EnsureHeaderKeybindsActive()
        self:EnsureListInputActive()
    end

    self:EnsureColumnHeadersVisible()
end

---@return nil
function BETTERUI.Vendor.Class:ToggleBuySellMode()
    if BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction() then
        return
    end

    local mode = self:GetCurrentMode()
    if mode == BETTERUI.Vendor.MODE.BUY then
        self:SetMode(BETTERUI.Vendor.MODE.SELL)
    elseif mode == BETTERUI.Vendor.MODE.SELL then
        self:SetMode(BETTERUI.Vendor.MODE.BUY)
    else
        return
    end
end

---@param mode number Vendor mode constant from BETTERUI.Vendor.MODE
function BETTERUI.Vendor.Class:SetMode(mode)
    if not mode then return end
    if self.currentMode == mode then return end

    -- Deactivate the current component if any
    local oldComponent = self:GetActiveComponent()
    if oldComponent and oldComponent.Deactivate then
        oldComponent:Deactivate(self)
    end

    self.currentMode = mode

    self:ApplyNativeStoreMode(mode)

    -- Activate the new component
    local newComponent = self:GetActiveComponent()
    if newComponent and newComponent.Activate then
        newComponent:Activate(self)
    end

    -- Update keybinds for new mode
    if self:IsSceneShowing() then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end

    self:RebuildCategoryHeader()
    self:RefreshVendorFooter()
end

---@return VendorComponent|nil component The currently active component, or nil
function BETTERUI.Vendor.Class:GetActiveComponent()
    if not self.components then return nil end
    return self.components[self:GetCurrentMode()]
end

---@param mode number Vendor mode constant from BETTERUI.Vendor.MODE
---@param component VendorComponent Component implementing Activate/Deactivate/BuildList
function BETTERUI.Vendor.Class:RegisterComponent(mode, component)
    if not mode or not component then return end
    self.components = self.components or {}
    self.components[mode] = component
end

-- LIST MANAGEMENT

--- Clears and rebuilds the list from the active component's BuildList.
---@return nil
function BETTERUI.Vendor.Class:RefreshList()
    if self._suppressListUpdates then
        self._isDirty = true
        return
    end

    if not self.list then return end

    self:ApplyListLayoutTuning()

    local component = self:GetActiveComponent()
    if component and component.GetCategories then
        self:SetModeCategories(self:GetCurrentMode(), component:GetCategories(self))
    else
        self:SetModeCategories(self:GetCurrentMode(), nil)
    end

    -- Clear existing data
    self.list:Clear()

    -- Delegate to the active component's BuildList
    if component and component.BuildList then
        component:BuildList(self)
    end

    self.list:Commit()
    self._isDirty = false

    self:EnsureColumnHeadersVisible()
    if self:IsSceneShowing() then
        self:EnsureListInputActive()
        self:OnItemSelectedChange(self.list, self.list:GetTargetData())
    end
    self:UpdateScrollIndicator(self.list)

    if self:GetCurrentMode() == BETTERUI.Vendor.MODE.BUY then
        local entryCount = (self.list.dataList and #self.list.dataList) or 0
        if entryCount == 0 and self:IsSceneActiveOrShowing() then
            local retryCount = (self._buyListRetryCount or 0) + 1
            self._buyListRetryCount = retryCount
            if retryCount <= 20 then
                BETTERUI.Vendor.Tasks:Cancel("buyListRetry")
                BETTERUI.Vendor.Tasks:Schedule("buyListRetry", 180, function()
                    if self and self.IsSceneActiveOrShowing and self:IsSceneActiveOrShowing()
                        and self.GetCurrentMode and self:GetCurrentMode() == BETTERUI.Vendor.MODE.BUY then
                        if BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
                            BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
                        end
                        self:ApplyNativeStoreMode(BETTERUI.Vendor.MODE.BUY)
                        self:RefreshList()
                    end
                end)
            end
        else
            self._buyListRetryCount = 0
        end
    else
        self._buyListRetryCount = 0
    end
end

---@param _list table
---@param selectedData table|nil
---@return nil
function BETTERUI.Vendor.Class:OnItemSelectedChange(_list, selectedData)
    if not GAMEPAD_TOOLTIPS then
        return
    end

    if BETTERUI.Inventory and BETTERUI.Inventory.CleanupEnhancedTooltip then
        BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
        BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
    end

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    if not ds then
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        return
    end

    local mode = self:GetCurrentMode()
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)

    if (mode == BETTERUI.Vendor.MODE.BUY or mode == BETTERUI.Vendor.MODE.BUYBACK) and GAMEPAD_TOOLTIPS.LayoutStoreWindowItem then
        if ds.dataSource == nil then
            ds.dataSource = ds
        end
        GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:LayoutStoreWindowItem(GAMEPAD_LEFT_TOOLTIP, ds)
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        if tooltip then
            tooltip._betterui_itemLink = ds.itemLink or ((GetStoreItemLink and ds.entryIndex) and GetStoreItemLink(ds.entryIndex)) or nil
            tooltip._betterui_bagId = nil
            tooltip._betterui_slotIndex = nil
            tooltip._betterui_storeStackCount = ds.stackCount or ds.stack or 1
            tooltip._betterui_priceRendered = false
        end
    elseif ds.bagId and ds.slotIndex and GAMEPAD_TOOLTIPS.LayoutBagItem then
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        if tooltip then
            tooltip._betterui_bagId = ds.bagId
            tooltip._betterui_slotIndex = ds.slotIndex
            tooltip._betterui_itemLink = GetItemLink(ds.bagId, ds.slotIndex)
            tooltip._betterui_storeStackCount = nil
            tooltip._betterui_priceRendered = false
        end
    else
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    end

    if BETTERUI.Inventory and BETTERUI.Inventory.UpdateTooltipEquippedText then
        BETTERUI.Inventory.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)
    end

    -- Vendor uses a single visible tooltip panel. Force the right tooltip
    -- inactive so equipped-comparison content cannot overlap the primary panel.
    local rightTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
    if rightTooltip then
        rightTooltip._betterui_itemLink = nil
        rightTooltip._betterui_bagId = nil
        rightTooltip._betterui_slotIndex = nil
        rightTooltip._betterui_storeStackCount = nil
        rightTooltip._betterui_priceRendered = true
    end
    if GAMEPAD_TOOLTIPS.ClearStatusLabel then
        GAMEPAD_TOOLTIPS:ClearStatusLabel(GAMEPAD_RIGHT_TOOLTIP)
    end
end

--- Suppresses list refreshes until FlushListUpdates is called.
---@return nil
function BETTERUI.Vendor.Class:SuppressListUpdates()
    self._suppressListUpdates = true
    self._isDirty = false
end

--- Releases suppressed list updates and refreshes if dirty.
---@return nil
function BETTERUI.Vendor.Class:FlushListUpdates()
    self._suppressListUpdates = false
    if self._isDirty then
        self:RefreshList()
    end
end

-- STORE/FENCE STATE QUERIES

---@return boolean isFence True if current mode is a fence mode
function BETTERUI.Vendor.Class:IsFenceMode()
    local mode = self:GetCurrentMode()
    return mode == BETTERUI.Vendor.MODE.FENCE_SELL
        or mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER
end

---@return number currencyType1 Primary currency type
---@return number|nil currencyType2 Secondary currency type, or nil
function BETTERUI.Vendor.Class:GetStoreCurrencyTypes()
    if GetStoreUsedCurrencyTypes then
        return GetStoreUsedCurrencyTypes()
    end
    return CURT_MONEY, nil
end

---@param cost number|nil Item cost to check
---@param currencyType number|nil Currency type (defaults to CURT_MONEY)
---@return boolean canAfford True if player can afford the cost
function BETTERUI.Vendor.Class:CanAfford(cost, currencyType)
    if not cost or cost <= 0 then return true end
    currencyType = currencyType or CURT_MONEY
    local current = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER) or 0
    return current >= cost
end

---@return boolean hasSpace True if backpack has at least one free slot
function BETTERUI.Vendor.Class:HasInventorySpace()
    local numFree = GetNumBagFreeSlots(BAG_BACKPACK)
    return numFree and numFree > 0
end


--- Initializes the vendor footer by relabelling the embedded Withdraw/Deposit
--- controls to show buy/sell list toggles.
--- Called once during Init after the window is created.
---@return nil
function BETTERUI.Vendor.Class:InitVendorFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- Keep centre divider visible for buy/sell list switching.
    local dividerCentre = footerRoot:GetNamedChild("DividerCentre")
    if dividerCentre then dividerCentre:SetHidden(false) end

    -- LEFT SIDE: Relabel "WITHDRAW" -> Buy list
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", function()
                if BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction() then
                    return
                end
                self:SetMode(BETTERUI.Vendor.MODE.BUY)
            end)

            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY") or "SI_BETTERUI_VENDOR_TAB_BUY"))
            end
        end
        -- Keep current icon style.
        local icon = withdraw:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/currency/currency_gold_64.dds")
        end
    end

    -- RIGHT SIDE: Relabel "DEPOSIT" -> Sell list
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", function()
                if BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction() then
                    return
                end
                self:SetMode(BETTERUI.Vendor.MODE.SELL)
            end)

            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL") or "SI_BETTERUI_VENDOR_TAB_SELL"))
            end
        end
        -- Keep current icon style.
        local icon = deposit:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
        end
    end

    self:RefreshVendorFooter()
end

--- Refreshes the vendor footer values (gold amount, bag capacity).
--- Called on scene showing and after inventory changes.
---@return nil
function BETTERUI.Vendor.Class:RefreshVendorFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    local currentMode = self:GetCurrentMode()
    local isBuySellMode = (currentMode == BETTERUI.Vendor.MODE.BUY) or (currentMode == BETTERUI.Vendor.MODE.SELL)
    local isSellMode = (currentMode == BETTERUI.Vendor.MODE.SELL)
    local activeColor = { 1, 1, 1, 1 }
    local inactiveColor = BETTERUI_BANK_INACTIVE_LABEL_COLOR or { 0.35, 0.35, 0.35, 1 }

    local selectBg = footerRoot:GetNamedChild("SelectBg")
    if selectBg then
        local rotation = 0
        if isSellMode then
            rotation = BETTERUI_BANK_DEPOSIT_ARROW_ROTATION or 0
        end
        selectBg:SetTextureRotation(rotation)
    end

    -- LEFT SIDE: Gold amount
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            local label = btn:GetNamedChild("Label")
            if label then
                if isBuySellMode then
                    label:SetColor(unpack(isSellMode and inactiveColor or activeColor))
                else
                    label:SetColor(unpack(activeColor))
                end
            end

            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
                spaceLabel:SetText("|t24:24:esoui/art/currency/currency_gold_32.dds|t " ..
                    BETTERUI.DisplayNumber(gold))
            end
        end
    end

    -- RIGHT SIDE: Bag capacity
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            local label = btn:GetNamedChild("Label")
            if label then
                if isBuySellMode then
                    label:SetColor(unpack(isSellMode and activeColor or inactiveColor))
                else
                    label:SetColor(unpack(activeColor))
                end
            end

            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                spaceLabel:SetText(
                    "|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t " ..
                    zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                        GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)))
            end
        end
    end
end
