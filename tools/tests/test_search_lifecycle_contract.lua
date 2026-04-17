--[[
File: tools/tests/test_search_lifecycle_contract.lua
Purpose: Regression coverage for the canonical search lifecycle contract shared by CIM, Banking, Vendor, and Companions.
Usage:
  lua tools/tests/test_search_lifecycle_contract.lua
]]

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

local function assert_contains(list, expected, label)
    for _, value in ipairs(list) do
        if value == expected then
            passed = passed + 1
            return
        end
    end

    failed = failed + 1
    print(string.format("  FAIL: %s -- missing %s", label, tostring(expected)))
end

local function read_file(path)
    local handle = io.open(path, "r")
    if not handle then
        failed = failed + 1
        print(string.format("  FAIL: unable to open %s", path))
        return ""
    end

    local content = handle:read("*a") or ""
    handle:close()
    return content
end

BETTERUI = {
    Interface = {},
    CIM = {},
}

KEYBIND_STRIP_ALIGN_LEFT = 1
KEYBIND_STRIP_ALIGN_RIGHT = 2
SI_GAMEPAD_SELECT_OPTION = "select"
SI_BETTERUI_CLEAR_SEARCH = "clear"
SI_GAMEPAD_BACK_OPTION = "back"
SI_GAMEPAD_SCRIPTS_KEYBIND_DOWN = "down"

function GetString(value)
    return tostring(value)
end

local function buildEditBox(initialText)
    local editBox = {
        handlers = {},
        text = initialText or "",
    }

    function editBox:GetHandler(name)
        return self.handlers[name]
    end

    function editBox:SetHandler(name, callback)
        self.handlers[name] = callback
    end

    function editBox:GetText()
        return self.text
    end

    function editBox:SetText(value)
        self.text = value
    end

    return editBox
end

local function buildScreen()
    local calls = {}
    local editBox = buildEditBox("needle")
    local screen = {
        SEARCH_LIFECYCLE = {
            clear = "ClearSearchInput",
            exit = "ExitSearchMode",
            headerActive = "IsHeaderFocused",
            requestEnter = "RequestHeaderFocus",
            onEnter = "OnHeaderEntered",
        },
        searchQuery = "needle",
        headerActive = false,
        textSearchKeybindStripDescriptor = {},
        textSearchHeaderControl = {
            IsHidden = function()
                return false
            end,
        },
        textSearchHeaderFocus = {
            GetEditBox = function()
                return editBox
            end,
        },
    }

    function screen:ClearSearchInput()
        calls[#calls + 1] = "clear"
        self.searchQuery = ""
        editBox:SetText("")
    end

    function screen:ExitSearchMode()
        calls[#calls + 1] = "exit"
    end

    function screen:IsHeaderFocused()
        calls[#calls + 1] = "headerActive"
        return self.headerActive == true
    end

    function screen:RequestHeaderFocus()
        calls[#calls + 1] = "requestEnter"
        self.headerActive = true
    end

    function screen:OnHeaderEntered()
        calls[#calls + 1] = "onEnter"
    end

    return screen, editBox, calls
end

dofile("Modules/CIM/Core/Data/SearchManager.lua")
dofile("Modules/CIM/Core/Lifecycle/SceneCleanup.lua")

print("test_search_lifecycle_contract")

-- Canonical lifecycle helpers resolve SEARCH_LIFECYCLE method names directly.
do
    local screen, _, calls = buildScreen()
    local method, methodName = BETTERUI.Interface.SearchMixin.GetSearchLifecycleMethod(screen, "clear")
    assert_eq(methodName, "ClearSearchInput", "canonical clear method name is resolved")
    assert_true(type(method) == "function", "canonical clear method is callable")

    BETTERUI.Interface.SearchMixin.CallSearchLifecycle(screen, "clear")
    assert_eq(screen.searchQuery, "", "canonical clear handler resets query")
    assert_contains(calls, "clear", "canonical clear handler is invoked")
end

-- Descriptor callbacks should use the canonical clear/exit contract instead of alias-only names.
do
    local screen, _, calls = buildScreen()
    local descriptors = BETTERUI.Interface.CreateSearchKeybindDescriptor(screen)

    descriptors[2].callback()
    assert_contains(calls, "clear", "negative keybind clears via canonical contract when query exists")

    screen.searchQuery = ""
    descriptors[2].callback()
    assert_contains(calls, "exit", "negative keybind exits via canonical contract when query empty")

    descriptors[1].callback()
    descriptors[3].callback()
    assert_contains(calls, "exit", "primary/down keybinds exit via canonical contract")
end

-- Edit-box focus handlers should use the canonical request-enter and exit methods.
do
    local screen, editBox, calls = buildScreen()
    BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(screen, {
        isSceneShowing = function()
            return true
        end,
    })

    editBox.handlers.OnFocusGained(editBox)
    assert_contains(calls, "requestEnter", "focus gained requests header enter via canonical contract")

    editBox.handlers.OnFocusLost(editBox)
    assert_contains(calls, "exit", "focus lost exits via canonical contract")

    editBox.handlers.OnKeyDown(editBox, nil, nil, nil, nil, "UI_SHORTCUT_DOWN")
    assert_contains(calls, "exit", "shortcut down exits via canonical contract")
end

-- Scene cleanup should drive the same canonical clear/exit lifecycle surface.
do
    local removedGroups = 0
    KEYBIND_STRIP = {
        RemoveKeybindButtonGroup = function(_, _)
            removedGroups = removedGroups + 1
        end,
    }

    local screen, editBox, calls = buildScreen()
    BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)

    assert_eq(screen.searchQuery, "", "scene cleanup clears the canonical query state")
    assert_eq(editBox:GetText(), "", "scene cleanup clears the edit box through canonical clear")
    assert_eq(removedGroups, 1, "scene cleanup removes search keybinds once")
    assert_contains(calls, "exit", "scene cleanup exits via canonical contract")
    assert_contains(calls, "clear", "scene cleanup clears via canonical contract")
end

-- Legacy alias-only screens should no longer resolve once every module speaks
-- the canonical SEARCH_LIFECYCLE contract.
do
    local calls = {}
    local legacyScreen = {
        ClearTextSearch = function(self)
            calls[#calls + 1] = "clear"
            self.searchQuery = ""
        end,
        ExitSearchFocus = function(_)
            calls[#calls + 1] = "exit"
        end,
        IsHeaderActive = function()
            return false
        end,
        RequestEnterHeader = function(_)
            calls[#calls + 1] = "requestEnter"
        end,
        OnEnterHeader = function(_)
            calls[#calls + 1] = "onEnter"
        end,
        searchQuery = "legacy",
        textSearchHeaderControl = {
            IsHidden = function()
                return false
            end,
        },
        textSearchHeaderFocus = {
            GetEditBox = function()
                return buildEditBox("legacy")
            end,
        },
    }

    local clearMethod = BETTERUI.Interface.SearchMixin.CallSearchLifecycle(legacyScreen, "clear")
    local exitMethod = BETTERUI.Interface.SearchMixin.CallSearchLifecycle(legacyScreen, "exit")
    local requestEnterMethod = BETTERUI.Interface.SearchMixin.CallSearchLifecycle(legacyScreen, "requestEnter")
    local onEnterMethod = BETTERUI.Interface.SearchMixin.CallSearchLifecycle(legacyScreen, "onEnter")

    assert_eq(clearMethod, nil, "legacy clear alias no longer resolves without SEARCH_LIFECYCLE")
    assert_eq(exitMethod, nil, "legacy exit alias no longer resolves without SEARCH_LIFECYCLE")
    assert_eq(requestEnterMethod, nil, "legacy request-enter alias no longer resolves without SEARCH_LIFECYCLE")
    assert_eq(onEnterMethod, nil, "legacy on-enter alias no longer resolves without SEARCH_LIFECYCLE")
    assert_eq(#calls, 0, "legacy alias-only screen callbacks stay unused")
end

do
    local searchManagerSource = read_file("Modules/CIM/Core/Data/SearchManager.lua")
    assert_true(searchManagerSource:find("SEARCH_LIFECYCLE_FALLBACK_METHODS") == nil,
        "search manager no longer keeps legacy alias fallback tables")

    local sceneCleanupSource = read_file("Modules/CIM/Core/Lifecycle/SceneCleanup.lua")
    assert_true(sceneCleanupSource:find("screen:LeaveSearchMode", 1, true) == nil,
        "scene cleanup clears search through canonical lifecycle helpers")
    assert_true(sceneCleanupSource:find("screen:ClearTextSearch", 1, true) == nil,
        "scene cleanup avoids direct legacy clear calls")

    local unifiedScreenSource = read_file("Modules/CIM/Core/Window/UnifiedScreen.lua")
    assert_true(unifiedScreenSource:find("self:ClearTextSearch()", 1, true) == nil,
        "unified screen shutdown avoids direct legacy clear calls")

    local bankingSource = read_file("Modules/Banking/Search/SearchManager.lua")
    assert_true(bankingSource:find('BETTERUI%.CIM%.TryCall%("Interface%.Window%.ClearSearchText"') == nil,
        "Banking search manager avoids string-path clear dispatch")
    assert_true(bankingSource:find("Interface%.Window%.OnEnterHeader") == nil,
        "Banking search manager avoids string-path header dispatch")

    local vendorSource = read_file("Modules/Vendor/Core/VendorClass.lua")
    assert_true(vendorSource:find('BETTERUI%.CIM%.TryCall%("Interface%.Window%.ClearSearchText"') == nil,
        "Vendor search manager avoids string-path clear dispatch")
    assert_true(vendorSource:find("Interface%.Window%.OnEnterHeader") == nil,
        "Vendor search manager avoids string-path header dispatch")

    local inventorySource = read_file("Modules/Inventory/Inventory.lua")
    assert_true(inventorySource:find('BETTERUI%.CIM%.TryCall%("Interface%.Window%.ClearSearchText"') == nil,
        "Inventory search clear avoids string-path dispatch")

    local inventoryClassSource = read_file("Modules/Inventory/Core/InventoryClass.lua")
    assert_true(inventoryClassSource:find('BETTERUI%.CIM%.TryResolve%("Interface%.Window%.AddSearch"') == nil,
        "Inventory class uses the explicit SearchMixin.AddSearch seam")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
