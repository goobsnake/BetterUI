--[[
File: tools/tests/test_header_sort_integration.lua
Purpose: Regression tests for shared header sort owner integration hooks.

Usage:
  lua tools/tests/test_header_sort_integration.lua
]]

BETTERUI = {
    CIM = {
        UI = {},
    },
}

KEYBIND_STRIP = {
    added = {},
    removed = {},
    removedAll = 0,
}

function KEYBIND_STRIP:AddKeybindButtonGroup(group)
    self.added[#self.added + 1] = group
end

function KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
    self.removed[#self.removed + 1] = group
end

function KEYBIND_STRIP:RemoveAllKeyButtonGroups()
    self.removedAll = self.removedAll + 1
end

function KEYBIND_STRIP:UpdateKeybindButtonGroup(_)
end

SOUNDS = {
    GAMEPAD_MENU_FORWARD = "forward",
    GAMEPAD_MENU_BACK = "back",
}

local playedSounds = {}
function PlaySound(sound)
    playedSounds[#playedSounds + 1] = sound
end

local passed = 0
local failed = 0

local function assertEqual(expected, actual, message)
    if expected == actual then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function resetKeybindStrip()
    KEYBIND_STRIP.added = {}
    KEYBIND_STRIP.removed = {}
    KEYBIND_STRIP.removedAll = 0
    playedSounds = {}
end

dofile("Modules/CIM/UI/HeaderSortIntegration.lua")

local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration

local function newList(itemCount)
    local list = {
        itemCount = itemCount or 1,
    }

    function list:GetNumItems()
        return self.itemCount
    end

    function list:SetOnHitBeginningOfListCallback(callback)
        self.onHitBeginning = callback
    end

    return list
end

local function newController()
    local controller = {
        enterCount = 0,
        exitCount = 0,
    }

    function controller:EnterHeaderMode()
        self.enterCount = self.enterCount + 1
    end

    function controller:ExitHeaderMode()
        self.exitCount = self.exitCount + 1
    end

    function controller:CreateKeybindDescriptor(exitCallback)
        return {
            exitCallback = exitCallback,
        }
    end

    return controller
end

print("\n=== Header Sort Integration Tests ===\n")

do
    resetKeybindStrip()

    local navigationTransitions = {}
    local owner = {
        mainKeybindStripDescriptor = { id = "main" },
        list = newList(3),
    }

    local controller = newController()

    local integration = HeaderSortIntegration.Install(owner, {
        list = owner.list,
        keybindDescriptor = owner.mainKeybindStripDescriptor,
        headerControllerFn = function()
            return controller
        end,
        deactivateNavigationFn = function(instance)
            navigationTransitions[#navigationTransitions + 1] = "deactivate:" .. tostring(instance == owner)
        end,
        reactivateNavigationFn = function(instance)
            navigationTransitions[#navigationTransitions + 1] = "reactivate:" .. tostring(instance == owner)
        end,
    })

    owner:EnterHeaderSortMode()

    assertEqual(integration, owner._headerSortIntegration, "install stores the shared integration on the owner")
    assertEqual("deactivate:true", navigationTransitions[1], "enter deactivates external navigation through shared hook")
    assertEqual(true, owner.isInHeaderSortMode, "enter toggles shared header sort mode")
    assertEqual(1, controller.enterCount, "enter delegates to controller")
    assertEqual(1, KEYBIND_STRIP.removedAll, "enter clears stale keybind groups")
    assertEqual(1, #KEYBIND_STRIP.added, "enter installs header keybind descriptor")

    owner:ExitHeaderSortMode()

    assertEqual(false, owner.isInHeaderSortMode, "exit clears shared header sort mode")
    assertEqual(1, controller.exitCount, "exit delegates to controller")
    assertEqual("reactivate:true", navigationTransitions[2], "exit restores external navigation through shared hook")
    assertEqual(owner.mainKeybindStripDescriptor, KEYBIND_STRIP.added[#KEYBIND_STRIP.added], "exit restores main keybind descriptor")
end

do
    resetKeybindStrip()

    local navigationTransitions = {}
    local owner = {
        mainKeybindStripDescriptor = { id = "main-empty" },
        list = newList(0),
    }

    HeaderSortIntegration.Install(owner, {
        list = owner.list,
        headerControllerFn = function()
            return newController()
        end,
        deactivateNavigationFn = function()
            navigationTransitions[#navigationTransitions + 1] = "deactivate"
        end,
        reactivateNavigationFn = function()
            navigationTransitions[#navigationTransitions + 1] = "reactivate"
        end,
    })

    owner:EnterHeaderSortMode()

    assertEqual("deactivate", navigationTransitions[1], "empty-list enter still uses shared deactivate hook")
    assertEqual("reactivate", navigationTransitions[2], "empty-list enter reactivates navigation when header mode does not start")
    assertEqual(false, owner.isInHeaderSortMode == true, "empty-list enter leaves header mode inactive")
    assertEqual(0, #KEYBIND_STRIP.added, "empty-list enter does not install header keybinds")
end

do
    resetKeybindStrip()

    local owner = {
        list = newList(2),
        mainKeybindStripDescriptor = { id = "main-hit-beginning" },
    }
    local controller = newController()

    HeaderSortIntegration.Install(owner, {
        list = owner.list,
        keybindDescriptor = owner.mainKeybindStripDescriptor,
        headerControllerFn = function()
            return controller
        end,
        autoEnterOnListStart = true,
    })

    owner.list.onHitBeginning()

    assertEqual(true, owner.isInHeaderSortMode, "hit-beginning callback enters shared header sort mode through unified installer")
    assertEqual(1, controller.enterCount, "hit-beginning callback reuses the shared owner contract")
end

print(string.format("\nPassed: %d  Failed: %d", passed, failed))
if failed > 0 then
    os.exit(1)
end
