--[[
File: tools/tests/test_tabbar_selection_dispatch.lua
Purpose: Regression coverage for shared tab bar selection-callback dispatch.

Guards three ZO_-drift fixes in Modules/CIM/Lists/TabBarScrollList.lua:
  * SetSelectedIndex must fire the user selection callback EXACTLY ONCE per
    real change (carousel: direct call in UpdateAnchors; non-carousel: the
    _zo_selectedDataChangedWrapper), never on a same-index no-op.
  * SetSelectedIndexWithoutAnimation must pass forceAnimation=false into the
    native call (NOT the suppression flag) and honor suppression via the
    carousel UpdateAnchors blockSelectionChangedCallback (4th) argument.

Usage:
  lua tools/tests/test_tabbar_selection_dispatch.lua
]]

-- ---------------------------------------------------------------------------
-- Minimal ESO / BetterUI environment
-- ---------------------------------------------------------------------------
BETTERUI = {
    CIM = {
        CONST = {
            CAROUSEL = {
                startOffset = 710,
                itemSpacing = 50,
                verticalOffset = 12,
            },
        },
        ListGlobals = {
            TABBAR_MOVEMENT_TYPES = {
                PAGE_FORWARD = 1,
                PAGE_BACK = 2,
                PAGE_NAVIGATION_FAILED = 3,
            },
        },
    },
    GamepadParametricScrollListPlaySound = function() end,
}

ZO_PARAMETRIC_MOVEMENT_TYPES = { LAST = 100 }

CENTER = "CENTER"
LEFT = "LEFT"
RIGHT = "RIGHT"

function ZO_ClearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function zo_round(value)
    return math.floor(value + 0.5)
end

-- Records what the native SetSelectedIndexWithoutAnimation receives, so we can
-- assert the 3rd (forceAnimation) slot is never the suppression flag.
local nativeWithoutAnimationCalls = {}

-- ZO_ParametricScrollList native base used directly by the without-animation
-- override (it calls ZO_ParametricScrollList.SetSelectedIndexWithoutAnimation).
ZO_ParametricScrollList = {}
function ZO_ParametricScrollList.SetSelectedIndexWithoutAnimation(self, selectedIndex, allowEvenIfDisabled, forceAnimation)
    table.insert(nativeWithoutAnimationCalls, {
        selectedIndex = selectedIndex,
        allowEvenIfDisabled = allowEvenIfDisabled,
        forceAnimation = forceAnimation,
    })
    -- Mirror native: it delegates to SetSelectedIndex, which for the tab bar
    -- only advances targetSelectedIndex (the overridden UpdateAnchors advances
    -- selectedData/selectedIndex). Leave selectedData stale so the override's
    -- UpdateAnchors remains the sole dispatcher under test.
    self.targetSelectedIndex = selectedIndex
end

-- BETTERUI_HorizontalParametricScrollList is the immediate base class.
BETTERUI_HorizontalParametricScrollList = {}
function BETTERUI_HorizontalParametricScrollList:Subclass()
    local cls = {}
    cls.__index = cls
    setmetatable(cls, { __index = self })
    return cls
end
-- Native SetSelectedIndex base behavior used by SetSelectedIndex override.
-- IMPORTANT: native ZO_ParametricScrollList:SetSelectedIndex only updates
-- targetSelectedIndex (and fires TargetDataChanged). It does NOT set
-- self.selectedData/self.selectedIndex outside its own UpdateAnchors -- and the
-- tab bar OVERRIDES UpdateAnchors, so native never touches selectedData here.
-- The mock must preserve that: leave selectedData/selectedIndex stale so the
-- override's own UpdateAnchors is the sole place selection state advances.
function BETTERUI_HorizontalParametricScrollList.SetSelectedIndex(self, selectedIndex, allowEvenIfDisabled, forceAnimation)
    self.targetSelectedIndex = selectedIndex
end

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

dofile("Modules/CIM/Lists/TabBarScrollList.lua")

-- ---------------------------------------------------------------------------
-- Test fixture: a 3-entry tab bar with a counting selection callback.
-- ---------------------------------------------------------------------------
local function makeControl()
    return {
        ClearAnchors = function() end,
        SetAnchor = function() end,
        GetWidth = function() return 40 end,
        SetHidden = function() end,
    }
end

local function newTabBar(carouselMode)
    local dataList = {
        { name = "One" },
        { name = "Two" },
        { name = "Three" },
    }
    local tabBar
    tabBar = setmetatable({
        active = true,
        enabled = true,
        carouselMode = carouselMode,
        soundEnabled = false,
        jumping = false,
        dataList = dataList,
        visibleControls = {},
        unseenControls = {},
        scrollControl = {},
        selectedIndex = 1,
        targetSelectedIndex = 1,
        carouselStartOffset = BETTERUI.CIM.CONST.CAROUSEL.startOffset,
        carouselItemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing,
        carouselVerticalOffset = BETTERUI.CIM.CONST.CAROUSEL.verticalOffset,
        onPlaySoundFunction = function() end,
        -- ZO callback registry (RegisterCallback/FireCallbacks).
        _callbacks = {},
        GetDataForDataIndex = function(self, index)
            return self.dataList[index]
        end,
        AcquireControlAtDataIndex = function(self, dataIndex)
            self._controls = self._controls or {}
            if not self._controls[dataIndex] then
                self._controls[dataIndex] = makeControl()
            end
            return self._controls[dataIndex], false
        end,
        RunSetupOnControl = function() end,
        GetParametricFunctionForDataIndex = function() return nil end,
        ReleaseControl = function() end,
        RefreshPips = function() end,
        RegisterCallback = function(self, name, fn)
            self._callbacks[name] = self._callbacks[name] or {}
            table.insert(self._callbacks[name], fn)
        end,
        UnregisterCallback = function(self, name, fn)
            local list = self._callbacks[name]
            if not list then return end
            for i = #list, 1, -1 do
                if list[i] == fn then table.remove(list, i) end
            end
        end,
        FireCallbacks = function(self, name, ...)
            local list = self._callbacks[name]
            if not list then return end
            for _, fn in ipairs(list) do
                fn(...)
            end
        end,
    }, { __index = BETTERUI_TabBarScrollList })
    -- Seed selectedData to match the seeded selectedIndex.
    tabBar.selectedData = dataList[tabBar.selectedIndex]
    return tabBar
end

-- ---------------------------------------------------------------------------
-- 1. Carousel: SetSelectedIndex(2) from 1 -> callback fires EXACTLY ONCE.
-- ---------------------------------------------------------------------------
do
    local tabBar = newTabBar(true)
    local count = 0
    tabBar:SetOnSelectedDataChangedCallback(function() count = count + 1 end)

    tabBar:SetSelectedIndex(2, true, false)
    assertEq(count, 1, "carousel SetSelectedIndex(2) from 1 fires the selection callback exactly once")
end

-- ---------------------------------------------------------------------------
-- 2. Non-carousel: SetSelectedIndex(2) from 1 -> callback fires EXACTLY ONCE.
-- ---------------------------------------------------------------------------
do
    local tabBar = newTabBar(false)
    local count = 0
    tabBar:SetOnSelectedDataChangedCallback(function() count = count + 1 end)

    tabBar:SetSelectedIndex(2, true, false)
    assertEq(count, 1, "non-carousel SetSelectedIndex(2) from 1 fires the selection callback exactly once")
end

-- ---------------------------------------------------------------------------
-- 3. Carousel: SetSelectedIndex(1) from 1 (same index) -> NO callback.
-- ---------------------------------------------------------------------------
do
    local tabBar = newTabBar(true)
    local count = 0
    tabBar:SetOnSelectedDataChangedCallback(function() count = count + 1 end)

    tabBar:SetSelectedIndex(1, true, false)
    assertEq(count, 0, "carousel SetSelectedIndex(1) from 1 (same index) does not fire the selection callback")
end

-- 3b. Non-carousel same-index also fires nothing.
do
    local tabBar = newTabBar(false)
    local count = 0
    tabBar:SetOnSelectedDataChangedCallback(function() count = count + 1 end)

    tabBar:SetSelectedIndex(1, true, false)
    assertEq(count, 0, "non-carousel SetSelectedIndex(1) from 1 (same index) does not fire the selection callback")
end

-- ---------------------------------------------------------------------------
-- 4. SetSelectedIndexWithoutAnimation(idx, true, true): suppressed (count==0)
--    AND native receives forceAnimation == false (NOT the suppression flag).
-- ---------------------------------------------------------------------------
do
    nativeWithoutAnimationCalls = {}
    local tabBar = newTabBar(true)
    local count = 0
    tabBar:SetOnSelectedDataChangedCallback(function() count = count + 1 end)

    tabBar:SetSelectedIndexWithoutAnimation(2, true, true)

    assertEq(#nativeWithoutAnimationCalls, 1, "native SetSelectedIndexWithoutAnimation called exactly once")
    assertEq(nativeWithoutAnimationCalls[1].forceAnimation, false,
        "native SetSelectedIndexWithoutAnimation receives forceAnimation=false, not the suppression flag")
    assertEq(count, 0, "SetSelectedIndexWithoutAnimation with suppression=true fires no selection callback")
end

-- ---------------------------------------------------------------------------
-- 5. SetSelectedIndexWithoutAnimation(idx, true, false): NOT suppressed ->
--    callback fires exactly once, native still receives forceAnimation=false.
-- ---------------------------------------------------------------------------
do
    nativeWithoutAnimationCalls = {}
    local tabBar = newTabBar(true)
    local count = 0
    tabBar:SetOnSelectedDataChangedCallback(function() count = count + 1 end)

    tabBar:SetSelectedIndexWithoutAnimation(2, true, false)

    assertEq(#nativeWithoutAnimationCalls, 1, "native SetSelectedIndexWithoutAnimation called exactly once")
    assertEq(nativeWithoutAnimationCalls[1].forceAnimation, false,
        "native SetSelectedIndexWithoutAnimation receives forceAnimation=false (without-animation path)")
    assertEq(count, 1, "SetSelectedIndexWithoutAnimation with suppression=false fires the selection callback once")
end

print("test_tabbar_selection_dispatch.lua: PASS")
