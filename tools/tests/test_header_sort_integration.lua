--[[
File: tools/tests/test_header_sort_integration.lua
Purpose: Regression tests for the shared header sort installation contract.

Usage:
  lua tools/tests/test_header_sort_integration.lua
]]

if false then
    dofile("Modules/CIM/UI/HeaderSortIntegration.lua")
end

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

local createdControllers = {}

BETTERUI = {
    CIM = {
        UI = {},
    },
}

KEYBIND_STRIP = {
    added = {},
    removed = {},
    AddKeybindButtonGroup = function(self, descriptor)
        table.insert(self.added, descriptor)
    end,
    RemoveKeybindButtonGroup = function(self, descriptor)
        table.insert(self.removed, descriptor)
    end,
}

SOUNDS = {
    GAMEPAD_MENU_FORWARD = "forward",
    GAMEPAD_MENU_BACK = "back",
}

function PlaySound(_)
end

BETTERUI.CIM.UI.HeaderSortController = {
    New = function(_, list, columns, onSortChangedCallback)
        local controller = {
            list = list,
            columns = columns,
            onSortChangedCallback = onSortChangedCallback,
            enterCalls = 0,
            exitCalls = 0,
            active = false,
        }

        function controller:CreateKeybindDescriptor(exitCallback)
            self.exitCallback = exitCallback
            return {
                controller = self,
                exitCallback = exitCallback,
            }
        end

        function controller:EnterHeaderMode()
            self.enterCalls = self.enterCalls + 1
            self.active = true
        end

        function controller:ExitHeaderMode()
            self.exitCalls = self.exitCalls + 1
            self.active = false
        end

        function controller:IsActive()
            return self.active
        end

        table.insert(createdControllers, controller)
        return controller
    end,
}

dofile("Modules/CIM/UI/HeaderSortIntegration.lua")

local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration

local function buildOwner()
    return {
        list = {
            activateCalls = 0,
            GetNumItems = function()
                return 3
            end,
            Activate = function(self)
                self.activateCalls = self.activateCalls + 1
            end,
        },
        headerGeneric = {
            tabBar = {
                active = true,
                deactivateCalls = 0,
                activateCalls = 0,
                Deactivate = function(self)
                    self.active = false
                    self.deactivateCalls = self.deactivateCalls + 1
                end,
                Activate = function(self)
                    self.active = true
                    self.activateCalls = self.activateCalls + 1
                end,
            },
        },
        coreKeybinds = {
            id = "main",
        },
    }
end

do
    local owner = buildOwner()
    local onControllerCreatedCalls = 0
    local integration = HeaderSortIntegration.Install(owner, {
        list = owner.list,
        columns = {
            { key = "name" },
        },
        callbacks = {
            onSortChanged = function() end,
            onControllerCreated = function(instance, controller, list)
                onControllerCreatedCalls = onControllerCreatedCalls + 1
                assert_true(instance == owner, "controller created callback receives owner")
                assert_true(controller ~= nil, "controller created callback receives controller")
                assert_true(list == owner.list, "controller created callback receives list")
            end,
        },
        controllerContract = {
            field = "sortController",
            aliasFields = { "headerSortController" },
        },
        keybinds = {
            mainDescriptor = owner.coreKeybinds,
        },
    })

    local controller = HeaderSortIntegration.EnsureController(integration)
    assert_true(controller == owner.sortController, "ensure controller assigns primary field")
    assert_true(controller == owner.headerSortController, "ensure controller assigns alias field")
    assert_eq(controller.columns[1].key, "name", "ensure controller preserves columns")
    assert_eq(onControllerCreatedCalls, 1, "ensure controller triggers callback once")
    assert_true(HeaderSortIntegration.GetController(owner) == controller, "get controller resolves integration-owned controller")
    assert_true(HeaderSortIntegration.EnsureController(integration) == controller, "ensure controller reuses created controller")
end

do
    local owner = buildOwner()
    local integration = HeaderSortIntegration.Install(owner, {
        list = owner.list,
        columns = {
            { key = "value", defaultDirection = "descending" },
        },
        callbacks = {
            onSortChanged = function() end,
        },
        controllerContract = {
            field = "headerSortController",
        },
        keybinds = {
            mainDescriptor = owner.coreKeybinds,
        },
        navigation = {
            suspendTabBar = true,
        },
    })

    local controller = HeaderSortIntegration.EnsureController(integration)
    HeaderSortIntegration.EnterHeaderMode(integration)
    assert_eq(owner.headerGeneric.tabBar.deactivateCalls, 1, "enter header mode suspends tab bar")
    assert_eq(#KEYBIND_STRIP.added, 1, "enter header mode adds header keybinds")
    assert_eq(controller.enterCalls, 1, "enter header mode delegates to controller")
    assert_true(integration.isActive, "enter header mode marks integration active")

    HeaderSortIntegration.ExitHeaderMode(integration)
    assert_eq(owner.headerGeneric.tabBar.activateCalls, 1, "exit header mode restores tab bar")
    assert_eq(owner.list.activateCalls, 0, "exit header mode leaves list activation to owner callbacks")
    assert_eq(#KEYBIND_STRIP.removed, 1, "exit header mode removes header keybinds")
    assert_eq(controller.exitCalls, 1, "exit header mode delegates to controller")
    assert_true(not integration.isActive, "exit header mode clears integration active flag")
    assert_eq(#KEYBIND_STRIP.added, 2, "exit header mode restores owner keybinds")
end

do
    local legacyController = { id = "legacy" }
    assert_true(HeaderSortIntegration.GetController({ sortController = legacyController }) == legacyController,
        "get controller falls back to legacy sortController")
end

print(string.format("Passed: %d", passed))
if failed > 0 then
    print(string.format("Failed: %d", failed))
    os.exit(1)
end
print("OK")
