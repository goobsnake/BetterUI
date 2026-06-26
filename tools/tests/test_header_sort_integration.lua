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

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local createdControllers = {}
local logEvents = {}

BETTERUI = {
    CIM = {
        UI = {},
        -- Production loads SafeExecute before CIM/UI; stub it for the harness.
        SafeExecute = function(_, fn, ...) return pcall(fn, ...) end,
    },
    Log = {
        CATEGORY = { KEYBIND = "KEYBIND", NAV = "NAV", SORT = "SORT" },
        IsActive = function()
            return true
        end,
        Trace = function(category, message, data)
            logEvents[#logEvents + 1] = { level = "Trace", category = category, message = message, data = data }
        end,
        Debug = function(category, message, data)
            logEvents[#logEvents + 1] = { level = "Debug", category = category, message = message, data = data }
        end,
        Info = function(category, message, data)
            logEvents[#logEvents + 1] = { level = "Info", category = category, message = message, data = data }
        end,
        Warn = function(category, message, data)
            logEvents[#logEvents + 1] = { level = "Warn", category = category, message = message, data = data }
        end,
    },
}

local function findLogMessage(message)
    for _, event in ipairs(logEvents) do
        if event.message == message then
            return event
        end
    end
    return nil
end

KEYBIND_STRIP = {
    added = {},
    removed = {},
    groups = {},
    AddKeybindButtonGroup = function(self, descriptor)
        table.insert(self.added, descriptor)
        self.groups[descriptor] = true
    end,
    RemoveKeybindButtonGroup = function(self, descriptor)
        table.insert(self.removed, descriptor)
        self.groups[descriptor] = nil
    end,
    HasKeybindButtonGroup = function(self, descriptor)
        return self.groups[descriptor] == true
    end,
    UpdateKeybindButtonGroup = function(self, descriptor)
        self.updateCalls = (self.updateCalls or 0) + 1
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

dofile("Modules/CIM/Core/Presentation/KeybindHelpers.lua")
dofile("Modules/CIM/UI/HeaderSortIntegration.lua")

local typesSource = read_file("Modules/CIM/Core/Data/Types.lua")
assert_true(typesSource:find("ownedDescriptors table%[%]|nil", 1, false) ~= nil,
    "Header sort keybind contract documents ownedDescriptors")
assert_true(typesSource:find("suspendedKeybindGroups table%[%]|nil", 1, false) ~= nil,
    "Header sort integration contract documents suspended keybind groups")

local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration

local function buildOwner()
    return {
        list = {
            active = true,
            deactivateCalls = 0,
            activateCalls = 0,
            GetNumItems = function()
                return 3
            end,
            IsActive = function(self)
                return self.active
            end,
            Deactivate = function(self)
                self.active = false
                self.deactivateCalls = self.deactivateCalls + 1
            end,
            Activate = function(self)
                self.active = true
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

    assert_true(HeaderSortIntegration.PeekController(owner) == nil, "peek controller does not initialize integration state")
    assert_true(HeaderSortIntegration.GetController(owner) == nil, "get controller remains side-effect-free before ensure")
    assert_eq(onControllerCreatedCalls, 0, "get/peek do not trigger controller creation callbacks")

    local controller = HeaderSortIntegration.EnsureControllerForOwner(owner)
    assert_true(controller ~= nil, "ensure controller for owner initializes controller")
    assert_true(controller == owner.sortController, "ensure controller assigns primary field")
    assert_true(controller == owner.headerSortController, "ensure controller assigns alias field")
    assert_eq(controller.columns[1].key, "name", "ensure controller preserves columns")
    assert_eq(onControllerCreatedCalls, 1, "ensure controller triggers callback once")
    assert_true(HeaderSortIntegration.PeekController(owner) == controller, "peek controller returns initialized controller")
    assert_true(HeaderSortIntegration.GetController(owner) == controller, "get controller resolves integration-owned controller")
    assert_true(HeaderSortIntegration.EnsureController(integration) == controller, "ensure controller reuses created controller")
    assert_true(HeaderSortIntegration.EnsureControllerForOwner(owner) == controller, "owner ensure reuses created controller")
end

do
    logEvents = {}
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
    assert_eq(owner.list.deactivateCalls, 0, "enter header mode preserves the active list by default")
    assert_true(findLogMessage("header sort list preserved") ~= nil,
        "enter header mode logs that the active list was preserved")
    assert_eq(#KEYBIND_STRIP.added, 1, "enter header mode adds header keybinds")
    assert_eq(controller.enterCalls, 1, "enter header mode delegates to controller")
    assert_true(integration.isActive, "enter header mode marks integration active")

    HeaderSortIntegration.ExitHeaderMode(integration)
    assert_eq(owner.headerGeneric.tabBar.activateCalls, 1, "exit header mode restores tab bar")
    assert_eq(owner.list.activateCalls, 0, "exit header mode does not reactivate a preserved list")
    assert_eq(#KEYBIND_STRIP.removed, 1, "exit header mode removes header keybinds")
    assert_eq(controller.exitCalls, 1, "exit header mode delegates to controller")
    assert_true(not integration.isActive, "exit header mode clears integration active flag")
    assert_eq(#KEYBIND_STRIP.added, 2, "exit header mode restores owner keybinds")
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
        keybinds = {
            mainDescriptor = owner.coreKeybinds,
        },
        navigation = {
            suspendList = true,
        },
    })

    HeaderSortIntegration.EnsureController(integration)
    HeaderSortIntegration.EnterHeaderMode(integration)
    assert_eq(owner.list.deactivateCalls, 1, "explicit suspendList keeps the legacy list suspension path available")

    HeaderSortIntegration.ExitHeaderMode(integration)
    assert_eq(owner.list.activateCalls, 1, "explicit suspendList restores the active list on exit")
end

do
    -- Owned main keybinds present on the strip are suspended on enter and
    -- restored on exit; groups owned by the native UI / other addons survive.
    KEYBIND_STRIP.added = {}
    KEYBIND_STRIP.removed = {}
    KEYBIND_STRIP.groups = {}
    local owner = buildOwner()
    local foreignGroup = { id = "foreign" }
    KEYBIND_STRIP:AddKeybindButtonGroup(foreignGroup)
    KEYBIND_STRIP:AddKeybindButtonGroup(owner.coreKeybinds)

    local integration = HeaderSortIntegration.Install(owner, {
        list = owner.list,
        columns = {
            { key = "name" },
        },
        callbacks = {
            onSortChanged = function() end,
        },
        keybinds = {
            mainDescriptor = owner.coreKeybinds,
        },
    })

    HeaderSortIntegration.EnsureController(integration)
    HeaderSortIntegration.EnterHeaderMode(integration)
    assert_true(KEYBIND_STRIP.groups[foreignGroup] == true, "enter header mode leaves foreign keybind groups on the strip")
    assert_true(KEYBIND_STRIP.groups[owner.coreKeybinds] == nil, "enter header mode suspends owned main keybinds")

    HeaderSortIntegration.ExitHeaderMode(integration)
    assert_true(KEYBIND_STRIP.groups[foreignGroup] == true, "exit header mode leaves foreign keybind groups on the strip")
    assert_true(KEYBIND_STRIP.groups[owner.coreKeybinds] == true, "exit header mode restores suspended main keybinds")
    assert_true(integration.suspendedKeybindGroups == nil, "exit header mode clears suspended group tracking")
end

do
    -- Extra owner-supplied groups (e.g. the tab bar's LB/RB descriptor) are
    -- suspended together with the main descriptor and restored on exit, and
    -- the tab bar is suspended even without an explicit navigation contract.
    KEYBIND_STRIP.added = {}
    KEYBIND_STRIP.removed = {}
    KEYBIND_STRIP.groups = {}
    local owner = buildOwner()
    local tabBarGroup = { id = "tabbar-lb-rb" }
    KEYBIND_STRIP:AddKeybindButtonGroup(owner.coreKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(tabBarGroup)

    local integration = HeaderSortIntegration.Install(owner, {
        list = owner.list,
        columns = {
            { key = "name" },
        },
        callbacks = {
            onSortChanged = function() end,
        },
        keybinds = {
            mainDescriptor = owner.coreKeybinds,
            ownedDescriptors = { tabBarGroup },
        },
    })

    HeaderSortIntegration.EnsureController(integration)
    HeaderSortIntegration.EnterHeaderMode(integration)
    assert_true(KEYBIND_STRIP.groups[owner.coreKeybinds] == nil, "enter header mode suspends the main descriptor")
    assert_true(KEYBIND_STRIP.groups[tabBarGroup] == nil, "enter header mode suspends extra owned descriptors")
    assert_eq(owner.headerGeneric.tabBar.deactivateCalls, 1,
        "enter header mode suspends the tab bar without an explicit navigation contract")

    HeaderSortIntegration.ExitHeaderMode(integration)
    assert_true(KEYBIND_STRIP.groups[owner.coreKeybinds] == true, "exit header mode restores the main descriptor")
    assert_true(KEYBIND_STRIP.groups[tabBarGroup] == true, "exit header mode restores extra owned descriptors")
    assert_eq(owner.headerGeneric.tabBar.activateCalls, 1, "exit header mode reactivates the tab bar")
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
