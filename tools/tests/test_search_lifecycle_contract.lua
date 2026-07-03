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

-- AddSearch should always normalize callback payloads to strings.
do
    BETTERUI.CIM.CONST = {
        SEARCH_CHILD_NAMES = {},
    }

    local delivered = {}
    local emittedCallback
    CreateControlFromVirtual = function()
        local control = {}
        function control:SetMouseEnabled(_enabled) end
        function control:SetHandler(_name, _callback) end
        function control:GetNamedChild(_name)
            return nil
        end
        return control
    end
    ZO_TextSearch_Header_Gamepad = {
        New = function(_self, _control, callback)
            emittedCallback = callback
            return {
                SetFocused = function() end,
                Activate = function() end,
                Deactivate = function() end,
                HasFocus = function()
                    return true
                end,
                GetEditBox = function()
                    return buildEditBox("")
                end,
            }
        end,
    }

    local screen = {
        header = {},
    }
    BETTERUI.Interface.SearchMixin.AddSearch(screen, {}, function(text)
        delivered[#delivered + 1] = text
    end)

    emittedCallback("direct")
    emittedCallback({
        GetText = function()
            return "from-control"
        end,
    })
    emittedCallback(nil)
    emittedCallback(false)

    assert_eq(delivered[1], "direct", "AddSearch passes through direct string payloads")
    assert_eq(delivered[2], "from-control", "AddSearch normalizes control payloads via GetText")
    assert_eq(delivered[3], "", "AddSearch normalizes nil payload to empty string")
    assert_eq(delivered[4], "false", "AddSearch normalizes non-string payloads with tostring")
end

-- Scene cleanup should drive the same canonical clear/exit lifecycle surface.
do
    local removedGroups = 0
    KEYBIND_STRIP = {
        RemoveKeybindButtonGroup = function(_, _)
            removedGroups = removedGroups + 1
        end,
    }
    BETTERUI.Interface.RemoveKeybindGroupIfPresent = function(group)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
        return true
    end

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
    local bankingRuntimeSource = read_file("Modules/Banking/Banking.lua")
    assert_true(bankingSource:find('BETTERUI%.CIM%.TryCall%("Interface%.Window%.ClearSearchText"') == nil,
        "Banking search manager avoids string-path clear dispatch")
    assert_true(bankingSource:find("Interface%.Window%.OnEnterHeader") == nil,
        "Banking search manager avoids string-path header dispatch")
    assert_true(bankingRuntimeSource:find("function%(editOrText%)") == nil,
        "Banking runtime search callback consumes the normalized string payload")

    local vendorSource = read_file("Modules/Vendor/Core/VendorClass.lua")
    local vendorBootstrapSource = read_file("Modules/Vendor/Core/VendorBootstrapRuntime.lua")
    assert_true(vendorSource:find('BETTERUI%.CIM%.TryCall%("Interface%.Window%.ClearSearchText"') == nil,
        "Vendor search manager avoids string-path clear dispatch")
    assert_true(vendorSource:find("Interface%.Window%.OnEnterHeader") == nil,
        "Vendor search manager avoids string-path header dispatch")
    assert_true(vendorSource:find("OnSearchTextChanged%(editBox%)") == nil,
        "Vendor search callback consumes the normalized string payload")
    assert_true(vendorSource:find("KEYBIND_STRIP%.keybindButtonGroups") == nil,
        "Vendor search cleanup never reads the nonexistent keybindButtonGroups field")
    assert_true(vendorSource:find("_searchTextChangedInProgress", 1, true) ~= nil,
        "Vendor search text updates guard against re-entrant focus callbacks")
    assert_true(vendorSource:find("BETTERUI%.Interface%.RemoveOwnedKeybindGroups%(") ~= nil,
        "Vendor search cleanup removes only vendor-owned keybind groups")
    assert_true(vendorSource:find("BETTERUI%.Interface%.RestoreKeybindGroups%(self%._searchRemovedKeybindGroups%)") ~= nil,
        "Vendor ExitSearchMode restores exactly the groups the cleanup removed")
    assert_true(vendorSource:find("_searchKeybindCleanupToken", 1, true) ~= nil,
        "Vendor search cleanup uses a generation token to ignore stale deferred callbacks")
    assert_true(vendorSource:find("cleanupToken ~= self._searchKeybindCleanupToken", 1, true) ~= nil,
        "Vendor deferred search cleanup aborts when search mode has exited")
    assert_true(vendorSource:find("if self._preserveSearchFocusDuringRefresh", 1, true) ~= nil,
        "Vendor list-input activation preserves search focus during search text refresh")
    assert_true(vendorSource:find("_refreshingVendorHeaderAfterSearchExit", 1, true) ~= nil,
        "Vendor search exit refreshes the header strip after search focus leaves")
    assert_true(bankingSource:find("KEYBIND_STRIP%.keybindButtonGroups") == nil,
        "Banking search cleanup never reads the nonexistent keybindButtonGroups field")
    assert_true(bankingSource:find("_searchKeybindCleanupToken", 1, true) ~= nil,
        "Banking search cleanup uses a generation token to ignore stale deferred callbacks")
    assert_true(bankingSource:find("cleanupToken ~= self._searchKeybindCleanupToken", 1, true) ~= nil,
        "Banking deferred search cleanup aborts when search mode has exited")
    assert_true(vendorBootstrapSource:find("HandleVendorSearchChanged%(editOrText%)") == nil,
        "Vendor bootstrap search bridge consumes the normalized string payload")

    local inventorySource = read_file("Modules/Inventory/Inventory.lua")
    assert_true(inventorySource:find('BETTERUI%.CIM%.TryCall%("Interface%.Window%.ClearSearchText"') == nil,
        "Inventory search clear avoids string-path dispatch")

    local inventoryClassSource = read_file("Modules/Inventory/Core/InventoryClass.lua")
    assert_true(inventoryClassSource:find('BETTERUI%.CIM%.TryResolve%("Interface%.Window%.AddSearch"') == nil,
        "Inventory class uses the explicit SearchMixin.AddSearch seam")
    assert_true(inventoryClassSource:find("Inventory%.search%.getText") == nil,
        "Inventory search callback consumes the normalized string payload")
end

-- Banking mirrors Vendor's stale deferred keybind-cleanup protection.
do
    local previousBanking = BETTERUI.Banking
    local previousKeybindStrip = KEYBIND_STRIP

    local addedGroups = {}
    local scheduled = {}
    BETTERUI.Banking = {
        Class = {},
        EnsureKeybindGroupAdded = function(group)
            addedGroups[#addedGroups + 1] = group
        end,
        Tasks = {
            Schedule = function(_, name, _, callback)
                scheduled[name] = callback
            end,
            Cancel = function() end,
        },
    }
    BETTERUI.Interface.RemoveKeybindGroupIfPresent = function() end
    BETTERUI.Interface.RemoveOwnedKeybindGroups = function()
        return { "removed-core" }
    end
    BETTERUI.Interface.RestoreKeybindGroups = function() end
    BETTERUI.Interface.UpdateKeybindGroup = function() end
    KEYBIND_STRIP = {}

    dofile("Modules/Banking/Search/SearchManager.lua")

    local function countSearchKeybindAdds()
        local count = 0
        for _, group in ipairs(addedGroups) do
            if group == "bank-search" then
                count = count + 1
            end
        end
        return count
    end

    local banking = setmetatable({
        textSearchHeaderControl = { IsHidden = function() return false end },
        textSearchHeaderFocus = {
            active = false,
            IsActive = function(self) return self.active == true end,
            Activate = function(self) self.active = true end,
            Deactivate = function(self) self.active = false end,
        },
        coreKeybinds = "bank-core",
        withdrawDepositKeybinds = "bank-transfer",
        currencyKeybinds = "bank-currency",
        textSearchKeybindStripDescriptor = "bank-search",
        IsSceneShowing = function() return true end,
        RefreshActiveKeybinds = function() end,
        EnsureHeaderKeybindsActive = function() end,
        UpdateActions = function() end,
        SetTextSearchFocused = function(self, value) self.searchFocused = value end,
    }, { __index = BETTERUI.Banking.Class })

    banking:OnHeaderEntered()
    local staleCleanup = scheduled.searchKeybindCleanup
    local searchAddCountAfterEnter = countSearchKeybindAdds()
    banking:ExitSearchMode()
    staleCleanup()
    assert_eq(countSearchKeybindAdds(), searchAddCountAfterEnter,
        "Banking stale search cleanup does not re-add the search keybind after exit")

    banking:OnHeaderEntered()
    local activeCleanup = scheduled.searchKeybindCleanup
    local searchAddCountBeforeCleanup = countSearchKeybindAdds()
    activeCleanup()
    assert_eq(countSearchKeybindAdds(), searchAddCountBeforeCleanup + 1,
        "Banking active search cleanup can add the search keybind for the current generation")

    BETTERUI.Banking = previousBanking
    KEYBIND_STRIP = previousKeybindStrip
end

-- Vendor search refreshes must not drop focus while each typed character
-- refreshes the list.
do
    local previousVendor = BETTERUI.Vendor
    local previousLog = BETTERUI.Log
    local previousKeybindStrip = KEYBIND_STRIP
    local previousSceneManager = SCENE_MANAGER

    BETTERUI.Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            SELL_VENGEANCE = 3,
            REPAIR = 4,
            BUYBACK = 5,
            FENCE_SELL = 6,
            FENCE_LAUNDER = 7,
            STABLE = 8,
        },
        VENDOR_INTERACTION = 1,
        ResolveModeName = function(mode) return tostring(mode) end,
        ResolveModeIcon = function(_) return "" end,
        ResolveNativeStoreMode = function(mode) return mode end,
        ModePolicy = {
            BuildActiveModeSet = function() return {} end,
            IsSellBuybackOnlyModeSet = function() return false end,
        },
        ControllerRuntime = {},
        PresentationRuntime = {},
        ExecuteSafely = function(_, fn, ...)
            return fn(...)
        end,
    }
    BETTERUI.CIM.CONST = BETTERUI.CIM.CONST or {
        HEADER_LAYOUT = { COLUMNS = {} },
        LAYOUT = { COLUMNS = {} },
    }
    BETTERUI.CIM.GenericWindow = {
        Subclass = function()
            return {}
        end,
        New = function(class)
            return setmetatable({}, { __index = class })
        end,
    }
    BETTERUI.CIM.DeferredTask = {
        CreateManager = function()
            return {}
        end,
        CreateLazyManagerProxy = function()
            return {
                Cancel = function() end,
            }
        end,
    }
    BETTERUI.Interface.RemoveKeybindGroupIfPresent = function() end
    BETTERUI.Interface.RestoreKeybindGroups = function() end
    BETTERUI.Interface.EnsureKeybindGroupAdded = function() end
    BETTERUI.CIM.Lists = nil
    BETTERUI.Log = nil
    KEYBIND_STRIP = {}
    SCENE_MANAGER = {
        GetScene = function()
            return { IsShowing = function() return true end }
        end,
    }

    dofile("Modules/Vendor/Core/VendorClass.lua")
    dofile("Modules/Vendor/Core/VendorBootstrapRuntime.lua")

    do
        assert_true(type(BETTERUI.Vendor.Class.EnsureHeaderKeybindsActive) == "function",
            "vendor search lifecycle uses a production EnsureHeaderKeybindsActive method")
        assert_true(type(BETTERUI.Vendor.Class.EnsureListInputActive) == "function",
            "vendor search lifecycle uses a production EnsureListInputActive method")
        assert_true(type(BETTERUI.Vendor.Class.NormalizeDirectionalInputOwnership) == "function",
            "vendor search lifecycle uses a production NormalizeDirectionalInputOwnership method")
        assert_true(type(BETTERUI.Vendor.Class.RefreshVendorHeader) == "function",
            "vendor search lifecycle uses a production RefreshVendorHeader method")

        local updateAnchorCalls = 0
        local tabBar = {
            active = false,
            dirty = true,
            selectedIndex = 2,
            RefreshVisible = function(self)
                self.refreshVisibleCalls = (self.refreshVisibleCalls or 0) + 1
            end,
            Commit = function(self)
                self.commitCalls = (self.commitCalls or 0) + 1
            end,
            UpdateAnchors = function(self, selectedIndex, animate, _force, _skipSound)
                updateAnchorCalls = updateAnchorCalls + 1
                self.lastSelectedIndex = selectedIndex
                self.lastAnimate = animate
            end,
        }
        local realExitVendor = setmetatable({
            _searchModeActive = true,
            _searchHeaderActive = true,
            _vendorHeaderEntryCount = 1,
            headerGeneric = { tabBar = tabBar },
            textSearchHeaderFocus = {
                IsActive = function() return false end,
            },
            EnsureHeaderKeybindsActive = function(self)
                self.headerInputEnsured = true
            end,
            EnsureListInputActive = function(self)
                self.listInputEnsured = true
            end,
            NormalizeDirectionalInputOwnership = function(self, reason)
                self.normalizedReason = reason
            end,
        }, { __index = BETTERUI.Vendor.Class })

        BETTERUI.Vendor.Class.ExitSearchMode(realExitVendor)
        assert_eq(updateAnchorCalls, 1, "vendor search exit refreshes the production header carousel immediately")
        assert_eq(tabBar.active, true, "vendor search exit reactivates the header tab bar")
        assert_eq(tabBar.lastSelectedIndex, 2, "vendor search exit preserves the selected header index")
        assert_eq(realExitVendor.headerInputEnsured, true, "vendor search exit restores header input ownership")
        assert_eq(realExitVendor.listInputEnsured, true, "vendor search exit restores list input ownership")
        assert_eq(realExitVendor.normalizedReason, "ExitSearchMode",
            "vendor search exit normalizes directional-input ownership")
        assert_eq(realExitVendor._refreshingVendorHeaderAfterSearchExit, nil,
            "vendor search-exit header refresh guard is cleared")
    end

    local function buildVendorSearchInstance()
        local exitCalls = 0
        local vendor = setmetatable({
            searchQuery = "",
            _searchModeActive = true,
            _searchHeaderActive = true,
            textSearchHeaderFocus = {
                active = false,
                IsActive = function(self) return self.active == true end,
                Activate = function(self) self.active = true end,
            },
        }, { __index = BETTERUI.Vendor.Class })

        function vendor:ExitSearchMode()
            exitCalls = exitCalls + 1
            self._searchModeActive = false
            self._searchHeaderActive = false
        end

        function vendor:RefreshList()
            self.refreshListCalls = (self.refreshListCalls or 0) + 1
            self:EnsureListInputActive()
        end

        function vendor:SetTextSearchFocused(value)
            self.textSearchFocused = value
        end

        return vendor, function() return exitCalls end
    end

    local preservedVendor, preservedExitCalls = buildVendorSearchInstance()
    preservedVendor:OnSearchTextChanged("n")
    assert_eq(preservedVendor.searchQuery, "n", "vendor search stores normalized search text")
    assert_eq(preservedVendor.refreshListCalls, 1, "vendor search refreshes once for typed text")
    assert_eq(preservedExitCalls(), 0, "vendor search refresh preserve path does not exit search mode")
    assert_eq(preservedVendor._searchModeActive, true, "vendor search mode remains active during preserve refresh")
    assert_eq(preservedVendor.textSearchHeaderFocus.active, true, "vendor search focus is restored after refresh")
    assert_eq(preservedVendor.textSearchFocused, true, "vendor search focus flag is restored after refresh")

    local exitVendor, exitCalls = buildVendorSearchInstance()
    exitVendor._preserveSearchFocusDuringRefresh = false
    exitVendor:EnsureListInputActive()
    assert_eq(exitCalls(), 1, "vendor list input exits search mode outside preserve refresh")
    assert_eq(exitVendor._exitSearchModeInProgress, nil, "vendor list-input exit guard is cleared")

    local function buildBootstrapInstance(headerFocusActive)
        local callback
        local focusLostCalls = 0
        local list = {
            IsActive = function() return true end,
            SetOnSelectedDataChangedCallback = function(_, fn) callback = fn end,
        }
        local instance = {
            _searchModeActive = true,
            _searchHeaderActive = true,
            textSearchHeaderFocus = {
                IsActive = function() return headerFocusActive == true end,
            },
            SetupList = function(self)
                self.list = list
            end,
            AddTemplate = function() end,
            InitializeCategoryHeader = function() end,
            InitializeScrollIndicator = function() end,
            OnItemSelectedChange = function(self)
                self.selectionChanged = (self.selectionChanged or 0) + 1
            end,
            UpdateScrollIndicator = function(self)
                self.scrollUpdated = (self.scrollUpdated or 0) + 1
            end,
            OnSearchFocusLost = function()
                focusLostCalls = focusLostCalls + 1
            end,
        }

        BETTERUI.Vendor.BootstrapRuntime.InitializeList(instance, {
            rowSetup = function() end,
            addColumns = function() end,
        })

        return instance, list, function() return callback end, function() return focusLostCalls end
    end

    local focusedInstance, focusedList, getFocusedCallback, focusedLostCalls = buildBootstrapInstance(true)
    getFocusedCallback()(focusedList, { name = "Sword" })
    assert_eq(focusedInstance.selectionChanged, 1, "vendor deferred refresh still updates selection")
    assert_eq(focusedLostCalls(), 0, "vendor deferred refresh keeps search focus when header focus is active")

    local unfocusedInstance, unfocusedList, getUnfocusedCallback, unfocusedLostCalls = buildBootstrapInstance(false)
    getUnfocusedCallback()(unfocusedList, { name = "Axe" })
    assert_eq(unfocusedInstance.selectionChanged, 1, "vendor list selection callback runs when search focus is gone")
    assert_eq(unfocusedLostCalls(), 1, "vendor list selection exits search when header focus is no longer active")

    BETTERUI.Vendor = previousVendor
    BETTERUI.Log = previousLog
    KEYBIND_STRIP = previousKeybindStrip
    SCENE_MANAGER = previousSceneManager
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
