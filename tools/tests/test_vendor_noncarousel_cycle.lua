--[[
File: tools/tests/test_vendor_noncarousel_cycle.lua
Purpose: Regression coverage for vendor non-carousel category cycling.
]]

BETTERUI = {
    CIM = {
        CONST = {
            CAROUSEL = {
                startOffset = 710,
                verticalOffset = 12,
                itemSpacing = 50,
            },
        },
    },
    Banking = {
        CONST = {
            CAROUSEL = {
                startOffset = 705,
                verticalOffset = -1,
            },
        },
    },
    Vendor = {
        CONST = {
            CAROUSEL = {
                startOffset = 705,
                verticalOffset = -1,
            },
        },
        MODE = {
            BUY = 1,
            SELL = 2,
        },
    },
}

local Vendor = BETTERUI.Vendor

function Vendor.GetSetting(key)
    if key == "enableCarousel" then
        return false
    end
    return nil
end

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assertNil(value, message)
    if value ~= nil then
        error(string.format("%s (expected nil, actual=%s)", message, tostring(value)))
    end
end

local VendorClass = {}
VendorClass.__index = VendorClass

function VendorClass:New(tabBar)
    return setmetatable({
        headerGeneric = { tabBar = tabBar },
        categoryIndexByMode = {},
    }, self)
end

function VendorClass:GetCurrentMode()
    return Vendor.MODE.BUY
end

function VendorClass:SetModeCategories(mode, categories)
    self.modeCategories = self.modeCategories or {}
    self.categoryIndexByMode = self.categoryIndexByMode or {}
    local previousCategories = self.modeCategories[mode]

    self.modeCategories[mode] = categories
    local selectedIndex = self.categoryIndexByMode[mode] or 1
    if selectedIndex < 1 or selectedIndex > #categories then
        selectedIndex = 1
    end
    self.categoryIndexByMode[mode] = selectedIndex

    if mode == self:GetCurrentMode() then
        self.currentCategoryIndex = selectedIndex
        local shouldRebuildHeader = self.vendorHeaderData == nil or not self:AreCategoriesEquivalent(previousCategories, categories)
        if shouldRebuildHeader then
            self.rebuilds = (self.rebuilds or 0) + 1
        else
            self.titleUpdates = (self.titleUpdates or 0) + 1
        end
    end
end

function VendorClass:AreCategoriesEquivalent(left, right)
    if left == right then
        return true
    end
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    if #left ~= #right then
        return false
    end

    for index = 1, #left do
        local leftCategory = left[index] or {}
        local rightCategory = right[index] or {}
        if (leftCategory.key or leftCategory.name or index) ~= (rightCategory.key or rightCategory.name or index)
            or leftCategory.name ~= rightCategory.name
            or leftCategory.iconFile ~= rightCategory.iconFile
            or leftCategory.filterType ~= rightCategory.filterType
            or leftCategory.itemCount ~= rightCategory.itemCount
            or leftCategory.special ~= rightCategory.special then
            return false
        end
    end

    return true
end

function VendorClass:CycleTabs(direction)
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    local headerEntryCount = self._vendorHeaderEntryCount or 0
    if tabBar and headerEntryCount > 1 then
        if direction < 0 then
            tabBar:MovePrevious(true)
        else
            tabBar:MoveNext(true)
        end
        return
    end

    self:CycleModeTabs(direction)
end

function VendorClass:CycleModeTabs(direction)
    self.modeCycleCalls = (self.modeCycleCalls or 0) + 1
    self.lastModeCycleDirection = direction
end

function VendorClass:SaveListPosition()
    self.savedPositions = (self.savedPositions or 0) + 1
end

function VendorClass:RefreshList()
    self.refreshes = (self.refreshes or 0) + 1
end

function VendorClass:UpdateVendorHeaderTitle()
    self.titleRefreshes = (self.titleRefreshes or 0) + 1
end

function VendorClass:RefreshVendorHeaderCarouselLayout()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end

    tabBar.carouselMode = Vendor.GetSetting("enableCarousel") ~= false

    if tabBar.UpdateAnchors then
        local selectedIndex = tabBar.targetSelectedIndex or tabBar.selectedIndex or 1
        tabBar:UpdateAnchors(selectedIndex, true, false, false)
    end
end

local function buildVendorCarouselConfig()
    return {
        enabled = Vendor.GetSetting("enableCarousel") ~= false,
        startOffset = BETTERUI.Vendor.CONST.CAROUSEL.startOffset,
        verticalOffset = BETTERUI.Vendor.CONST.CAROUSEL.verticalOffset,
        itemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing,
    }
end

local function isFallbackShoulderVisible(vendor, activeTabCount)
    if vendor.headerGeneric and vendor.headerGeneric.tabBar then
        return false
    end
    if vendor._vendorHeaderEntryCount and vendor._vendorHeaderEntryCount > 1 then
        return true
    end
    return activeTabCount > 1
end

local function applyHeaderSelection(state, tabBar, selectedHeaderIndex)
    if state and state.justToggledMode then
        tabBar:SetSelectedIndexWithoutAnimation(selectedHeaderIndex, true, true)
        return
    end

    if state then
        state.suppressHeaderCallback = true
    end
    tabBar:SetSelectedIndex(selectedHeaderIndex, true, true)
    if state then
        state.suppressHeaderCallback = false
    end
end

local function buildTabBar(selectedIndex)
    return {
        selectedIndex = selectedIndex,
        carouselMode = true,
        lastSelectedIndex = nil,
        moveNextCalled = false,
        movePreviousCalled = false,
        lastAllowWrapping = nil,
        lastCarouselModeAtMove = nil,
        lastCarouselModeAtSet = nil,
        updateAnchorsCalls = {},
        MoveNext = function(self, allowWrapping)
            self.moveNextCalled = true
            self.lastAllowWrapping = allowWrapping
            self.lastCarouselModeAtMove = self.carouselMode
            self.selectedIndex = self.selectedIndex + 1
        end,
        MovePrevious = function(self, allowWrapping)
            self.movePreviousCalled = true
            self.lastAllowWrapping = allowWrapping
            self.lastCarouselModeAtMove = self.carouselMode
            self.selectedIndex = self.selectedIndex - 1
        end,
        SetSelectedIndex = function(self, selectedIndex)
            self.lastCarouselModeAtSet = self.carouselMode
            self.selectedIndex = selectedIndex
            self.setSelectedIndexCalled = (self.setSelectedIndexCalled or 0) + 1
        end,
        SetSelectedIndexWithoutAnimation = function(self, selectedIndex)
            self.selectedIndex = selectedIndex
            self.setSelectedIndexWithoutAnimationCalled = (self.setSelectedIndexWithoutAnimationCalled or 0) + 1
        end,
        UpdateAnchors = function(self, selectedIndex, initialUpdate)
            self.updateAnchorsCalls[#self.updateAnchorsCalls + 1] = {
                selectedIndex = selectedIndex,
                initialUpdate = initialUpdate,
            }
        end,
    }
end

-- Test: CycleTabs forward uses MoveNext with wrapping always enabled
do
    local tabBar = buildTabBar(5)
    local vendor = VendorClass:New(tabBar)
    vendor._vendorHeaderEntryCount = 8

    vendor:CycleTabs(1)
    assertEq(tabBar.moveNextCalled, true, "CycleTabs(1) delegates to tab bar MoveNext")
    assertEq(tabBar.lastAllowWrapping, true, "CycleTabs(1) always enables wrapping")
    assertEq(tabBar.movePreviousCalled, false, "CycleTabs(1) does not call MovePrevious")
end

-- Test: CycleTabs backward uses MovePrevious with wrapping always enabled
do
    local tabBar = buildTabBar(5)
    local vendor = VendorClass:New(tabBar)
    vendor._vendorHeaderEntryCount = 8

    vendor:CycleTabs(-1)
    assertEq(tabBar.movePreviousCalled, true, "CycleTabs(-1) delegates to tab bar MovePrevious")
    assertEq(tabBar.lastAllowWrapping, true, "CycleTabs(-1) always enables wrapping")
    assertEq(tabBar.moveNextCalled, false, "CycleTabs(-1) does not call MoveNext")
end

-- Test: Tab bar movement traverses both mode tabs and categories
-- (the unified header has mode entries followed by category entries)
do
    local tabBar = buildTabBar(3)  -- start on first category (index 3, with 2 mode entries before)
    local vendor = VendorClass:New(tabBar)
    vendor._vendorHeaderEntryCount = 8
    vendor._vendorHeaderModeEntryCount = 2
    vendor._vendorHeaderCategoryCount = 6

    vendor:CycleTabs(-1)
    assertEq(tabBar.movePreviousCalled, true, "tab bar movement can cross from category region toward mode tabs")
    -- MovePrevious decrements: 3 -> 2 (a mode entry), proving navigation reaches mode tabs
    assertEq(tabBar.selectedIndex, 2, "MovePrevious from first category reaches last mode tab entry")
end

-- Test: CycleTabs falls back to CycleModeTabs when no tab bar
do
    local vendor = VendorClass:New(nil)
    vendor._vendorHeaderEntryCount = 0

    vendor:CycleTabs(1)
    assertEq(vendor.modeCycleCalls, 1, "CycleTabs falls back to CycleModeTabs when no tab bar exists")
    assertEq(vendor.lastModeCycleDirection, 1, "CycleTabs passes correct direction to CycleModeTabs fallback")
end

-- Test: CycleTabs falls back to CycleModeTabs when only 1 entry
do
    local tabBar = buildTabBar(1)
    local vendor = VendorClass:New(tabBar)
    vendor._vendorHeaderEntryCount = 1

    vendor:CycleTabs(1)
    assertEq(tabBar.moveNextCalled, false, "CycleTabs with single entry does not call MoveNext")
    assertEq(vendor.modeCycleCalls, 1, "CycleTabs with single entry falls back to CycleModeTabs")
end

do
    local vendor = VendorClass:New(buildTabBar(1))
    local categories = {
        { key = "all", name = "All", itemCount = 5 },
        { key = "furniture", name = "Furniture", itemCount = 2 },
    }

    vendor.vendorHeaderData = { titleText = function() return "Header" end }
    vendor.categoryIndexByMode[Vendor.MODE.BUY] = 1
    vendor:SetModeCategories(Vendor.MODE.BUY, categories)
    assertEq(vendor.rebuilds or 0, 1, "first category assignment rebuilds the header")

    vendor:SetModeCategories(Vendor.MODE.BUY, {
        { key = "all", name = "All", itemCount = 5 },
        { key = "furniture", name = "Furniture", itemCount = 2 },
    })
    assertEq(vendor.rebuilds or 0, 1, "equivalent categories do not rebuild the header on refresh")
    assertEq(vendor.titleUpdates or 0, 1, "equivalent categories only update the title state")
end

do
    local carouselConfig = buildVendorCarouselConfig()
    assertEq(carouselConfig.startOffset, BETTERUI.Vendor.CONST.CAROUSEL.startOffset, "vendor header uses the vendor-owned start offset")
    assertEq(carouselConfig.verticalOffset, BETTERUI.Vendor.CONST.CAROUSEL.verticalOffset, "vendor header uses the vendor-owned vertical offset")
    assertEq(carouselConfig.startOffset == BETTERUI.CIM.CONST.CAROUSEL.startOffset, false, "vendor header does not use the inventory default offset")
end

do
    local tabBar = buildTabBar(2)
    local state = { justToggledMode = false, suppressHeaderCallback = false }

    applyHeaderSelection(state, tabBar, 4)
    assertEq(tabBar.setSelectedIndexCalled, 1, "steady-state vendor rebuilds use animated selection like banking")
    assertEq(tabBar.setSelectedIndexWithoutAnimationCalled, nil, "steady-state vendor rebuilds avoid animation-free selection")
    assertEq(state.suppressHeaderCallback, false, "steady-state vendor rebuilds restore callback suppression state")
end

do
    local tabBar = buildTabBar(2)
    local state = { justToggledMode = true, suppressHeaderCallback = false }

    applyHeaderSelection(state, tabBar, 4)
    assertEq(tabBar.setSelectedIndexWithoutAnimationCalled, 1, "mode-toggle vendor rebuilds use animation-free selection like banking")
    assertEq(tabBar.setSelectedIndexCalled, nil, "mode-toggle vendor rebuilds skip animated selection")
end

do
    local previousSetting = Vendor.GetSetting
    Vendor.GetSetting = function(key)
        if key == "enableCarousel" then
            return true
        end
        return previousSetting(key)
    end

    local tabBar = buildTabBar(4)
    local vendor = VendorClass:New(tabBar)
    vendor:RefreshVendorHeaderCarouselLayout()
    assertEq(tabBar.carouselMode, true, "vendor header layout refresh applies the live carousel setting to the tab bar")
    assertEq(tabBar.updateAnchorsCalls[#tabBar.updateAnchorsCalls].selectedIndex, 4, "vendor header layout refresh reapplies anchors for the current header selection")

    Vendor.GetSetting = previousSetting
end

do
    local vendor = VendorClass:New(buildTabBar(3))
    vendor._vendorHeaderEntryCount = 5

    assertEq(isFallbackShoulderVisible(vendor, 3), false, "vendor fallback shoulder keybinds stay hidden while the header tab bar owns category navigation")
end

do
    local vendor = VendorClass:New(nil)
    vendor._vendorHeaderEntryCount = 0

    assertEq(isFallbackShoulderVisible(vendor, 3), true, "vendor fallback shoulder keybinds remain available when there is no header tab bar")
end

-- Regression: Lua and/or ternary trap
-- The pattern `GetSetting and (GetSetting("x") ~= false) or true` ALWAYS returns true
-- because when the comparison yields false, `truthy and false` = false, then `false or true` = true.
-- The correct pattern is `(not GetSetting) or (GetSetting("x") ~= false)`.
do
    local function BrokenPattern(getSetting)
        return getSetting and (getSetting("enableCarousel") ~= false) or true
    end
    local function CorrectPattern(getSetting)
        return (not getSetting) or (getSetting("enableCarousel") ~= false)
    end

    local getSettingFalse = function(key) if key == "enableCarousel" then return false end end
    local getSettingTrue  = function(key) if key == "enableCarousel" then return true end end

    -- Broken pattern always returns true regardless of setting
    assertEq(BrokenPattern(getSettingFalse), true, "broken and/or pattern returns true even when carousel is disabled")
    assertEq(BrokenPattern(getSettingTrue), true, "broken and/or pattern returns true when carousel is enabled")
    assertEq(BrokenPattern(nil), true, "broken and/or pattern returns true when GetSetting is nil")

    -- Correct pattern respects the setting
    assertEq(CorrectPattern(getSettingFalse), false, "correct pattern returns false when carousel is disabled")
    assertEq(CorrectPattern(getSettingTrue), true, "correct pattern returns true when carousel is enabled")
    assertEq(CorrectPattern(nil), true, "correct pattern defaults to true when GetSetting is nil")
end

print("test_vendor_noncarousel_cycle.lua: PASS")
