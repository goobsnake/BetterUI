--[[
File: tools/tests/test_tabbar_noncarousel_keybinds.lua
Purpose: Regression coverage for shared tab bar shoulder navigation wrapping.
]]

BETTERUI = {
    Interface = {
        ensured = 0,
        EnsureKeybindGroupAdded = function()
            BETTERUI.Interface.ensured = BETTERUI.Interface.ensured + 1
        end,
        RemoveKeybindGroupIfPresent = function() end,
        RemoveKeybindGroupFromAllStates = function() end,
    },
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
}

ZO_PARAMETRIC_MOVEMENT_TYPES = { LAST = 100 }

BETTERUI_HorizontalParametricScrollList = {}
function BETTERUI_HorizontalParametricScrollList:Subclass()
    local cls = {}
    cls.__index = cls
    setmetatable(cls, { __index = self })
    return cls
end
function BETTERUI_HorizontalParametricScrollList.Activate(self)
    self.baseActivateCalls = (self.baseActivateCalls or 0) + 1
    self.active = true
end
function BETTERUI_HorizontalParametricScrollList.Deactivate(self)
    self.baseDeactivateCalls = (self.baseDeactivateCalls or 0) + 1
    self.active = false
end

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

dofile("Modules/CIM/Lists/TabBarScrollList.lua")

do
    BETTERUI.Interface.ensured = 0
    local hiddenOwner = {
        IsSceneShowing = function() return false end,
    }
    local tabBar = setmetatable({
        parent = hiddenOwner,
        keybindStripDescriptor = { id = "hidden-carousel" },
    }, { __index = BETTERUI_TabBarScrollList })

    assertEq(tabBar:Activate(), false,
        "hidden scene tab bar rejects input activation")
    assertEq(BETTERUI.Interface.ensured, 0,
        "hidden scene tab bar cannot add its keybind group")
    assertEq(tabBar.baseActivateCalls, nil,
        "hidden scene tab bar cannot activate directional input")
end

do
    local lastAllowWrapping = nil
    local tabBar = setmetatable({
        active = true,
        carouselMode = false,
        MovePrevious = function(_, allowWrapping)
            lastAllowWrapping = allowWrapping
            return true
        end,
        MoveNext = function(_, allowWrapping)
            lastAllowWrapping = allowWrapping
            return true
        end,
    }, { __index = BETTERUI_TabBarScrollList })

    BETTERUI_TabBarScrollList.InitializeKeybindStripDescriptors(tabBar)
    tabBar.keybindStripDescriptor[1].callback()
    assertEq(lastAllowWrapping, true, "tab bar left-shoulder keybind always enables wrapping regardless of carousel mode")

    tabBar.keybindStripDescriptor[2].callback()
    assertEq(lastAllowWrapping, true, "tab bar right-shoulder keybind always enables wrapping regardless of carousel mode")
end

do
    local leftAllowWrapping = nil
    local rightAllowWrapping = nil
    local scrollList = {
        carouselMode = false,
        MovePrevious = function(_, allowWrapping)
            leftAllowWrapping = allowWrapping
        end,
        MoveNext = function(_, allowWrapping)
            rightAllowWrapping = allowWrapping
        end,
    }
    local tabBarControl = {
        scrollList = scrollList,
        GetParent = function(self)
            return self
        end,
    }

    BETTERUI_TabBar_OnLeftIconClicked(tabBarControl)
    BETTERUI_TabBar_OnRightIconClicked(tabBarControl)

    assertEq(leftAllowWrapping, true, "tab bar left icon always enables wrapping regardless of carousel mode")
    assertEq(rightAllowWrapping, true, "tab bar right icon always enables wrapping regardless of carousel mode")
end

print("test_tabbar_noncarousel_keybinds.lua: PASS")