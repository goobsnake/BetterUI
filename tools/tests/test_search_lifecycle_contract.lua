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

local function function_body(source, signature)
    local startAt = source:find(signature, 1, true)
    if not startAt then return "" end
    local nextFunction = source:find("\nfunction ", startAt + #signature, true)
    return source:sub(startAt, nextFunction and (nextFunction - 1) or #source)
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
            accept = "AcceptSearchAndReturnToList",
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

    function screen:AcceptSearchAndReturnToList()
        calls[#calls + 1] = "accept"
        self.headerActive = false
        return true
    end

    function screen:ClearSearchInput()
        calls[#calls + 1] = "clear"
        self.searchQuery = ""
        editBox:SetText("")
    end

    function screen:ExitSearchMode()
        calls[#calls + 1] = "exit"
    end

    function screen:SetTextSearchFocused(value)
        calls[#calls + 1] = value and "focus" or "unfocus"
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

-- Search focus owns only Select, Back, and X Clear Search, matching the
-- gamepad search contract instead of leaking list actions into header focus.
do
    local screen, _, calls = buildScreen()
    local descriptors = BETTERUI.Interface.CreateSearchKeybindDescriptor(screen)

    assert_eq(descriptors[1].alignment, KEYBIND_STRIP_ALIGN_LEFT,
        "search Select keybind uses the left-aligned navigation lane")
    assert_eq(descriptors[2].alignment, KEYBIND_STRIP_ALIGN_LEFT,
        "search Back/Clear keybind stays adjacent to Select in the left-aligned lane")

    descriptors[1].callback()
    assert_contains(calls, "focus", "primary keybind keeps focus in the search edit box")

    screen.headerActive = true
    descriptors[1].callback()
    assert_contains(calls, "accept", "primary keybind accepts an already-focused search")

    descriptors[2].callback()
    assert_contains(calls, "exit", "negative keybind always backs out of search focus")
    assert_eq(screen.searchQuery, "needle", "negative keybind does not clear populated search text")

    assert_eq(descriptors[3].keybind, "UI_SHORTCUT_SECONDARY",
        "search clear action uses the gamepad X button")
    assert_true(descriptors[3].visible(), "search clear action is visible while query text exists")
    descriptors[3].callback()
    assert_contains(calls, "clear", "X clears search via the canonical contract")
    assert_eq(screen.searchQuery, "", "X clear action resets the search query")

    assert_true(not descriptors[3].visible(), "search clear action hides when the query is empty")
    assert_true(descriptors[4] ~= nil, "search descriptor retains the down-navigation entry")
    if descriptors[4] then
        descriptors[4].callback()
        assert_contains(calls, "exit", "down keybind exits via the canonical contract")
    end
end

-- Edit-box focus handlers should use the canonical request-enter and exit methods.
do
    local screen, editBox, calls = buildScreen()
    BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(screen, {
        isSceneShowing = function()
            return true
        end,
        onAcceptSearch = function(owner)
            return owner:AcceptSearchAndReturnToList()
        end,
    })

    editBox.handlers.OnFocusGained(editBox)
    assert_contains(calls, "requestEnter", "focus gained requests header enter via canonical contract")

    editBox.handlers.OnFocusLost(editBox)
    assert_contains(calls, "exit", "focus lost exits via canonical contract")

    editBox.handlers.OnEnter(editBox)
    assert_contains(calls, "accept", "edit-box enter accepts search and returns to the list")

    editBox.handlers.OnKeyDown(editBox, nil, nil, nil, nil, "UI_SHORTCUT_PRIMARY")
    assert_contains(calls, "accept", "primary keydown accepts search")

    editBox.handlers.OnKeyDown(editBox, nil, nil, nil, nil, "UI_SHORTCUT_DOWN")
    assert_contains(calls, "exit", "shortcut down exits via canonical contract")

    assert_true(type(editBox.handlers.OnShortcut) == "function",
        "shortcut handler is installed even when the edit box had no original OnShortcut handler")
    editBox.handlers.OnShortcut(editBox, "UI_SHORTCUT_PRIMARY")
    assert_contains(calls, "accept", "gamepad primary shortcut accepts search")
    editBox.handlers.OnShortcut(editBox, "UI_SHORTCUT_DOWN")
    assert_contains(calls, "exit", "gamepad shortcut down exits via canonical contract")
end

-- Companion accept must run before the inherited gamepad edit-box OnEnter,
-- whose LoseFocus callback would otherwise exit search first.
do
    local screen, editBox, calls = buildScreen()
    local inheritedOnEnterCalls = 0
    screen.headerActive = true
    screen.listInputActive = false
    screen.headerKeybindsActive = false

    function screen:ExitSearchMode()
        calls[#calls + 1] = "exit"
        self.headerActive = false
        self.listInputActive = true
        self.headerKeybindsActive = true
    end

    function screen:AcceptSearchAndReturnToList()
        calls[#calls + 1] = "accept"
        self:ExitSearchMode()
        return true
    end

    function editBox:LoseFocus()
        self.handlers.OnFocusLost(self)
    end

    editBox.handlers.OnEnter = function(eb)
        inheritedOnEnterCalls = inheritedOnEnterCalls + 1
        eb:LoseFocus()
    end

    BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(screen, {
        isSceneShowing = function()
            return true
        end,
        onAcceptSearch = function(owner)
            return owner:AcceptSearchAndReturnToList()
        end,
    })

    editBox.handlers.OnEnter(editBox)
    assert_eq(inheritedOnEnterCalls, 0,
        "search accept owns OnEnter before the inherited LoseFocus handler")
    assert_eq(calls[#calls - 1], "accept",
        "search accept transition begins before focus loss")
    assert_eq(calls[#calls], "exit",
        "search accept transition exits through the scene lifecycle")
    assert_true(screen.listInputActive,
        "search accept restores item-list input ownership")
    assert_true(screen.headerKeybindsActive,
        "search accept restores LB/RB carousel ownership")
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
    assert_true(function_body(bankingSource,
            "function BETTERUI.Banking.Class:SetSearchDirectionalInputUpdate"):find(
            "not self:IsSceneShowing()", 1, true) ~= nil,
        "Banking cannot acquire search directional input while hidden")
    assert_true(function_body(bankingSource,
            "function BETTERUI.Banking.Class:EnterSearchMode"):find(
            "not self:IsSceneShowing()", 1, true) ~= nil,
        "Banking cannot enter search mode while hidden")
    assert_true(bankingRuntimeSource:find("function%(editOrText%)") == nil,
        "Banking runtime search callback consumes the normalized string payload")

    local vendorSource = read_file("Modules/Vendor/Core/VendorClass.lua")
    local vendorBootstrapSource = read_file("Modules/Vendor/Core/VendorBootstrapRuntime.lua")
    local vendorKeybindsSource = read_file("Modules/Vendor/Core/VendorKeybinds.lua")
    assert_true(vendorSource:find('BETTERUI%.CIM%.TryCall%("Interface%.Window%.ClearSearchText"') == nil,
        "Vendor search manager avoids string-path clear dispatch")
    assert_true(vendorSource:find("Interface%.Window%.OnEnterHeader") == nil,
        "Vendor search manager avoids string-path header dispatch")
    assert_true(vendorSource:find("OnSearchTextChanged%(editBox%)") == nil,
        "Vendor search callback consumes the normalized string payload")
    assert_true(function_body(vendorSource,
            "function BETTERUI.Vendor.Class:SetSearchDirectionalInputUpdate"):find(
            "not self:IsSceneShowing()", 1, true) ~= nil,
        "Vendor cannot acquire search directional input while hidden")
    assert_true(function_body(vendorSource,
            "function BETTERUI.Vendor.Class:EnterSearchMode"):find(
            "not self:IsSceneShowing()", 1, true) ~= nil,
        "Vendor cannot enter search mode while hidden")
    assert_true(vendorSource:find("KEYBIND_STRIP%.keybindButtonGroups") == nil,
        "Vendor search cleanup never reads the nonexistent keybindButtonGroups field")
    assert_true(vendorSource:find("_searchTextChangedInProgress", 1, true) ~= nil,
        "Vendor search text updates guard against re-entrant focus callbacks")
    -- Inventory-model port (2026-07-04): search focus is ADDITIVE — the search
    -- keybind group stacks on top of the core group, so no owned-group removal
    -- (and no deferred cleanup task) may exist in the vendor source anymore.
    assert_true(vendorSource:find("BETTERUI%.Interface%.RemoveOwnedKeybindGroups%(") == nil,
        "Vendor search focus is additive: owned-group removal must not return")
    assert_true(vendorSource:find("function BETTERUI%.Vendor%.Class:RestoreSearchFocus") ~= nil,
        "Vendor search exit funnels through the unified RestoreSearchFocus")
    assert_true(vendorSource:find("_restoringVendorSearchFocus", 1, true) ~= nil,
        "Vendor search restore is reentrancy-guarded")
    assert_true(vendorSource:find("_searchRemovedKeybindGroups", 1, true) == nil,
        "Vendor search has no stale removed-group restore branch after the additive search port")
    assert_true(vendorSource:find("searchKeybindCleanup", 1, true) == nil,
        "Vendor search has no stale deferred cleanup task after the additive search port")
    assert_true(vendorSource:find("_searchKeybindCleanupToken", 1, true) == nil,
        "Vendor search has no stale cleanup generation token after the additive search port")
    assert_true(vendorSource:find("ZO_Gamepad_ParametricList_Screen.OnLeaveHeader", 1, true) ~= nil,
        "Vendor OnLeaveHeader runs the base parametric leave before search restore")
    assert_true(vendorSource:find("if self._preserveSearchFocusDuringRefresh", 1, true) ~= nil,
        "Vendor list-input activation preserves search focus during search text refresh")
    assert_true(vendorSource:find("_refreshingVendorHeaderAfterSearchExit", 1, true) ~= nil,
        "Vendor search exit refreshes the header strip after search focus leaves")
    assert_true(vendorSource:find("RequestLeaveHeader", 1, true) ~= nil,
        "Vendor search exit asks the base screen to leave header focus like Inventory")
    assert_true(vendorBootstrapSource:find("screen:EnsureListInputActive()", 1, true) ~= nil,
        "Vendor scene show reasserts item-list gamepad input after rebuilding the list")
    assert_true(vendorBootstrapSource:find('screen:RefreshCoreKeybindOwnership("sceneShowing", true)', 1, true) ~= nil,
        "Vendor scene show force-reclaims the core LB/RB keybind group after rebuilding the list")
    assert_true(vendorBootstrapSource:find("autoEnterOnListStart = false", 1, true) ~= nil,
        "Vendor list-top navigation routes to the search lifecycle instead of header sort")
    assert_true(vendorSource:find("ExitHeaderSortMode", 1, true) ~= nil,
        "Vendor search exit clears header sort mode before restoring list input")
    assert_true(vendorKeybindsSource:find("if not (vendorInstance._searchModeActive == true or vendorInstance._searchHeaderActive == true) then", 1, true) ~= nil,
        "Vendor shoulder cycling uses explicit search lifecycle flags as the primary ownership signal")
    assert_true(vendorKeybindsSource:find("if not IsVendorSearchEditFocused(vendorInstance) or IsVendorListInputActive(vendorInstance) then", 1, true) ~= nil,
        "Vendor shoulder cycling overrides stale search flags when edit focus is absent or the list actively owns input")
    assert_true(vendorKeybindsSource:find("HealStaleVendorSearchFlags", 1, true) ~= nil,
        "Vendor shoulder cycling heals stale search flags so downstream flag consumers recover")
    assert_true(vendorSource:find("function BETTERUI.Vendor.Class:SetSearchDirectionalInputUpdate", 1, true) ~= nil,
        "Vendor search installs a scoped directional-input object while search owns focus")
    assert_true(vendorSource:find("function BETTERUI.Vendor.Class:EnsureSearchMovementController", 1, true) ~= nil,
        "Vendor search owns a movement controller for joystick search-header navigation")
    assert_true(vendorSource:find("GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE)", 1, true) ~= nil,
        "Vendor search reads only the gamepad left stick instead of the unsafe DPad-backed base path")
    assert_true(vendorSource:find("function BETTERUI.Vendor.Class:UpdateSearchDirectionalInput", 1, true) ~= nil,
        "Vendor search handles search-header directional input without calling the base updater")
    assert_true(vendorSource:find("DIRECTIONAL_INPUT:Activate(inputObject, control)", 1, true) ~= nil,
        "Vendor search registers a scoped directional-input listener for focused search")
    assert_true(vendorSource:find("ZO_Gamepad_ParametricList_Screen.UpdateDirectionalInput", 1, true) == nil,
        "Vendor search avoids the base UpdateDirectionalInput path that can hit private key state")
    assert_true(vendorSource:find("OnUpdate", 1, true) == nil,
        "Vendor search does not use a control OnUpdate bridge for joystick handling")
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

    local companionSource = read_file("Modules/Companions/Core/CompanionsClass.lua")
    assert_true(function_body(companionSource,
            "function BETTERUI.Companions.Class:SetSearchDirectionalInputUpdate"):find(
            "not self:IsSceneShowing()", 1, true) ~= nil,
        "Companions cannot acquire search directional input while hidden")
    assert_true(function_body(companionSource,
            "function BETTERUI.Companions.Class:EnterSearchMode"):find(
            "not self:IsSceneShowing()", 1, true) ~= nil,
        "Companions cannot enter search mode while hidden")
end

-- Banking mirrors Vendor's stale deferred keybind-cleanup protection.
do
    local previousBanking = BETTERUI.Banking
    local previousKeybindStrip = KEYBIND_STRIP

    local addedGroups = {}
    local removedGroups = {}
    local scheduled = {}
    local exitOrder = {}
    local enterOrder = {}
    BETTERUI.Banking = {
        Class = {},
        EnsureKeybindGroupAdded = function(group)
            addedGroups[#addedGroups + 1] = group
            if group == "bank-search" then
                enterOrder[#enterOrder + 1] = "keybind"
            end
        end,
        Tasks = {
            Schedule = function(_, name, _, callback)
                scheduled[name] = callback
            end,
            Cancel = function() end,
        },
    }
    BETTERUI.Interface.RemoveKeybindGroupIfPresent = function(group)
        removedGroups[#removedGroups + 1] = group
    end
    BETTERUI.Interface.RemoveOwnedKeybindGroups = function()
        return { "removed-core" }
    end
    BETTERUI.Interface.RestoreKeybindGroups = function()
        exitOrder[#exitOrder + 1] = "restore"
    end
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
            Activate = function(self)
                self.active = true
                enterOrder[#enterOrder + 1] = "focus"
            end,
            Deactivate = function(self)
                self.active = false
                exitOrder[#exitOrder + 1] = "deactivate"
            end,
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
    assert_eq(enterOrder[1], "focus",
        "Banking activates header focus before installing search keybind ownership")
    assert_eq(enterOrder[2], "keybind",
        "Banking installs search keybind ownership into the active header state")
    local staleCleanup = scheduled.searchKeybindCleanup
    local searchAddCountAfterEnter = countSearchKeybindAdds()
    banking:ExitSearchMode()
    assert_eq(exitOrder[1], "deactivate",
        "Banking search exit pops header focus before restoring list keybind groups")
    assert_true(addedGroups[#addedGroups - 1] == "bank-transfer",
        "Banking fast search exit restores the transfer group even before deferred cleanup runs")
    assert_true(addedGroups[#addedGroups] == "bank-core",
        "Banking fast search exit restores the core group even before deferred cleanup runs")
    staleCleanup()
    assert_eq(countSearchKeybindAdds(), searchAddCountAfterEnter,
        "Banking stale search cleanup does not re-add the search keybind after exit")

    banking:OnHeaderEntered()
    local activeCleanup = scheduled.searchKeybindCleanup
    local searchAddCountBeforeCleanup = countSearchKeybindAdds()
    activeCleanup()
    assert_eq(countSearchKeybindAdds(), searchAddCountBeforeCleanup + 1,
        "Banking active search cleanup can add the search keybind for the current generation")
    exitOrder = {}
    banking:ExitSearchMode()
    assert_eq(exitOrder[1], "deactivate",
        "Banking normal search exit pops header focus before restoring list keybind groups")
    assert_eq(exitOrder[2], "restore",
        "Banking normal search exit restores removed groups only after the header state pop")

    local preservedDuringRefresh = false
    banking._searchModeActive = true
    banking.SaveListPosition = function() end
    banking.RefreshList = function(self)
        preservedDuringRefresh = self._preserveSearchFocusDuringRefresh == true
    end
    banking:OnSearchTextChanged("h")
    assert_true(preservedDuringRefresh,
        "Banking text-driven list refresh preserves search keybind ownership")
    assert_true(banking._preserveSearchFocusDuringRefresh ~= true,
        "Banking clears the refresh-preservation guard after the list commit")

    -- A stale search descriptor can still own B after focus teardown has already
    -- cleared the mode flag. Exit must remain idempotent so that no-op Back
    -- ownership is removed and the normal scene navigation group is reclaimed.
    addedGroups = {}
    removedGroups = {}
    banking._searchModeActive = false
    banking.textSearchHeaderFocus.active = false
    banking:ExitSearchMode()
    assert_contains(removedGroups, "bank-search",
        "Banking stale search exit removes the descriptor that can swallow Back")
    assert_contains(addedGroups, "bank-core",
        "Banking stale search exit reclaims the normal Back navigation group")

    local backCalls = 0
    banking.searchQuery = ""
    banking.CancelWithdrawDeposit = function()
        backCalls = backCalls + 1
    end
    local staleDescriptors = BETTERUI.Interface.CreateSearchKeybindDescriptor(banking)
    staleDescriptors[2].callback()
    assert_eq(backCalls, 1,
        "Banking stale search Back continues through the normal scene navigation callback")

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
    local deferredTasks = {}
    local keybindAddCalls = 0
    local keybindUpdateCalls = 0

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
        ReleaseDirectionalInputRegistrations = function(obj)
            if not obj or not DIRECTIONAL_INPUT or not DIRECTIONAL_INPUT.IsListening or not DIRECTIONAL_INPUT.Deactivate then
                return 0
            end

            local releasedCount = 0
            while DIRECTIONAL_INPUT:IsListening(obj) do
                DIRECTIONAL_INPUT:Deactivate(obj)
                releasedCount = releasedCount + 1
            end
            return releasedCount
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
                Cancel = function(_, name) deferredTasks[name] = nil end,
                Schedule = function(_, name, delayMs, fn)
                    deferredTasks[name] = { delayMs = delayMs, fn = fn }
                end,
            }
        end,
    }
    BETTERUI.Interface.RemoveKeybindGroupIfPresent = function() end
    BETTERUI.Interface.RestoreKeybindGroups = function() end
    BETTERUI.Interface.EnsureKeybindGroupAdded = function()
        keybindAddCalls = keybindAddCalls + 1
    end
    BETTERUI.Interface.UpdateKeybindGroup = function()
        keybindUpdateCalls = keybindUpdateCalls + 1
    end
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
        local originalDirectionalInput = DIRECTIONAL_INPUT
        local originalMovementController = ZO_MovementController
        local originalMovementDirection = MOVEMENT_CONTROLLER_DIRECTION_VERTICAL
        local originalMoveNext = MOVEMENT_CONTROLLER_MOVE_NEXT
        local originalMovePrevious = MOVEMENT_CONTROLLER_MOVE_PREVIOUS
        local originalLeftStick = ZO_DI_LEFT_STICK
        local originalLeftStickNoKeyboard = ZO_DI_LEFT_STICK_NO_KEYBOARD
        local originalIncludeDeadzone = GAMEPAD_INCLUDE_DEADZONE
        local originalGetLeftStickY = GetGamepadLeftStickY
        local movementController
        local consumed
        local activatedObject
        local deactivatedObject
        local deactivatedCounts = {}
        local lastDeadzoneFlag
        local strayInputObject = {}

        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL = "vertical"
        MOVEMENT_CONTROLLER_MOVE_NEXT = "next"
        MOVEMENT_CONTROLLER_MOVE_PREVIOUS = "previous"
        ZO_DI_LEFT_STICK = "left_stick"
        ZO_DI_LEFT_STICK_NO_KEYBOARD = "left_stick_no_keyboard"
        GAMEPAD_INCLUDE_DEADZONE = "include_deadzone"
        GetGamepadLeftStickY = function(includeDeadzone)
            lastDeadzoneFlag = includeDeadzone
            return 0.75
        end
        DIRECTIONAL_INPUT = {
            inputObjects = { strayInputObject },
            listening = { [strayInputObject] = true },
            Activate = function(self, object)
                self.listening[object] = true
                self.inputObjects[#self.inputObjects + 1] = object
                activatedObject = object
            end,
            Deactivate = function(self, object)
                deactivatedCounts[object] = (deactivatedCounts[object] or 0) + 1
                self.listening[object] = nil
                deactivatedObject = object
            end,
            IsListening = function(self, object)
                return self.listening[object] == true
            end,
            Consume = function(_, ...)
                consumed = { ... }
            end,
        }
        ZO_MovementController = {
            New = function(_, direction, _, stickYGetter)
                movementController = {
                    direction = direction,
                    stickYGetter = stickYGetter,
                    nextResult = MOVEMENT_CONTROLLER_MOVE_NEXT,
                    CheckMovement = function(self)
                        self.lastStickY = self.stickYGetter()
                        return self.nextResult
                    end,
                }
                return movementController
            end,
        }
        local control = {
            IsControlHidden = function() return false end,
        }
        local exitCalls = 0
        local vendor = setmetatable({
            textSearchHeaderControl = control,
            textSearchHeaderFocus = {},
            textSearchKeybindStripDescriptor = {},
            _searchModeActive = true,
            _searchHeaderActive = true,
            IsSceneShowing = function() return true end,
            ExitSearchMode = function(self)
                exitCalls = exitCalls + 1
                self._searchModeActive = false
                self._searchHeaderActive = false
            end,
        }, { __index = BETTERUI.Vendor.Class })

        assert_true(vendor:SetSearchDirectionalInputUpdate(true, "test"),
            "vendor search installs a scoped directional-input listener while search owns focus")
        assert_eq(activatedObject, vendor._betteruiVendorSearchDirectionalInputObject,
            "vendor search activates its scoped directional-input object")
        assert_eq(movementController.direction, MOVEMENT_CONTROLLER_DIRECTION_VERTICAL,
            "vendor search movement controller is vertical-only")
        vendor:NormalizeDirectionalInputOwnership("test")
        assert_true(DIRECTIONAL_INPUT:IsListening(vendor._betteruiVendorSearchDirectionalInputObject),
            "vendor search normalization preserves the scoped directional-input listener")
        assert_eq(deactivatedCounts[vendor._betteruiVendorSearchDirectionalInputObject], nil,
            "vendor search normalization does not release the scoped directional-input listener")
        assert_true(DIRECTIONAL_INPUT:IsListening(strayInputObject) == false,
            "vendor search normalization still releases unrelated directional-input listeners")
        activatedObject:UpdateDirectionalInput()
        assert_eq(exitCalls, 1,
            "vendor search directional-input listener exits search on joystick down")
        assert_eq(lastDeadzoneFlag, GAMEPAD_INCLUDE_DEADZONE,
            "vendor search left-stick polling includes the gamepad deadzone flag")
        assert_eq(movementController.lastStickY, 0.75,
            "vendor search movement controller uses the safe left-stick getter")
        assert_eq(consumed[1], ZO_DI_LEFT_STICK,
            "vendor search consumes the left-stick input after handling movement")
        assert_eq(consumed[2], ZO_DI_LEFT_STICK_NO_KEYBOARD,
            "vendor search consumes the no-keyboard left-stick input after handling movement")
        vendor:SetSearchDirectionalInputUpdate(false, "test")
        assert_eq(deactivatedObject, vendor._betteruiVendorSearchDirectionalInputObject,
            "vendor search deactivates its scoped directional-input object when search exits")

        DIRECTIONAL_INPUT = originalDirectionalInput
        ZO_MovementController = originalMovementController
        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL = originalMovementDirection
        MOVEMENT_CONTROLLER_MOVE_NEXT = originalMoveNext
        MOVEMENT_CONTROLLER_MOVE_PREVIOUS = originalMovePrevious
        ZO_DI_LEFT_STICK = originalLeftStick
        ZO_DI_LEFT_STICK_NO_KEYBOARD = originalLeftStickNoKeyboard
        GAMEPAD_INCLUDE_DEADZONE = originalIncludeDeadzone
        GetGamepadLeftStickY = originalGetLeftStickY
    end

    do
        local originalDirectionalInput = DIRECTIONAL_INPUT
        local originalMovementController = ZO_MovementController
        local originalMovementDirection = MOVEMENT_CONTROLLER_DIRECTION_VERTICAL
        local originalMoveNext = MOVEMENT_CONTROLLER_MOVE_NEXT
        local originalMovePrevious = MOVEMENT_CONTROLLER_MOVE_PREVIOUS
        local originalLeftStick = ZO_DI_LEFT_STICK
        local originalLeftStickNoKeyboard = ZO_DI_LEFT_STICK_NO_KEYBOARD
        local originalGetLeftStickY = GetGamepadLeftStickY
        local originalMainHand = EQUIP_SLOT_MAIN_HAND
        local originalOffHand = EQUIP_SLOT_OFF_HAND
        local activatedObject
        local consumed
        local movementController
        local directionalQueryInput
        local rawStickCalls = 0
        local acceptCalls = 0

        BETTERUI.Companions = {}
        EQUIP_SLOT_MAIN_HAND = "main_hand"
        EQUIP_SLOT_OFF_HAND = "off_hand"
        dofile("Modules/Companions/Core/CompanionsClass.lua")

        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL = "vertical"
        MOVEMENT_CONTROLLER_MOVE_NEXT = "next"
        MOVEMENT_CONTROLLER_MOVE_PREVIOUS = "previous"
        ZO_DI_LEFT_STICK = "left_stick"
        ZO_DI_LEFT_STICK_NO_KEYBOARD = "left_stick_no_keyboard"
        GetGamepadLeftStickY = function()
            rawStickCalls = rawStickCalls + 1
            return 0.75
        end
        DIRECTIONAL_INPUT = {
            listening = {},
            GetY = function(_, input)
                directionalQueryInput = input
                return 0.75
            end,
            Activate = function(self, object)
                self.listening[object] = true
                activatedObject = object
            end,
            Deactivate = function(self, object)
                self.listening[object] = nil
            end,
            IsListening = function(self, object)
                return self.listening[object] == true
            end,
            Consume = function(_, ...)
                consumed = { ... }
            end,
        }
        ZO_MovementController = {
            New = function(_, direction, _, stickYGetter)
                movementController = {
                    direction = direction,
                    stickYGetter = stickYGetter,
                    CheckMovement = function(self)
                        self.lastStickY = self.stickYGetter()
                        return MOVEMENT_CONTROLLER_MOVE_NEXT
                    end,
                }
                return movementController
            end,
        }

        local companion = setmetatable({
            textSearchHeaderControl = { IsControlHidden = function() return false end },
            _searchModeActive = true,
            _searchHeaderActive = true,
            IsSceneShowing = function() return true end,
            AcceptSearchAndReturnToList = function(self)
                acceptCalls = acceptCalls + 1
                self._searchModeActive = false
                self._searchHeaderActive = false
                return true
            end,
        }, { __index = BETTERUI.Companions.Class })

        local clearedSearchText = false
        local ensuredHeaderNavigation = false
        local forcedHeaderReactivation = false
        companion.searchQuery = "needle"
        companion.textSearchHeaderFocus = {
            ClearText = function()
                clearedSearchText = true
            end,
        }
        companion.EnsureHeaderKeybindsActive = function(_, forceReactivate)
            ensuredHeaderNavigation = true
            forcedHeaderReactivation = forceReactivate == true
        end
        companion:ClearSearchInput()
        assert_eq(companion.searchQuery, "", "companion clear resets the search query")
        assert_true(clearedSearchText, "companion clear resets the visible search text")
        assert_true(ensuredHeaderNavigation, "companion clear restores LB/RB category navigation")
        assert_true(forcedHeaderReactivation,
            "companion clear recycles stale LB/RB category navigation ownership")

        assert_true(companion:SetSearchDirectionalInputUpdate(true),
            "companion search installs a scoped directional-input listener")
        activatedObject:UpdateDirectionalInput()
        assert_eq(acceptCalls, 1,
            "companion joystick down accepts search and returns to the list")
        assert_eq(movementController.direction, MOVEMENT_CONTROLLER_DIRECTION_VERTICAL,
            "companion search movement controller is vertical-only")
        assert_eq(directionalQueryInput, ZO_DI_LEFT_STICK_NO_KEYBOARD,
            "companion search honors ESOUI directional-input arbitration")
        assert_eq(rawStickCalls, 0,
            "companion search does not bypass directional-input arbitration")
        assert_eq(consumed[1], ZO_DI_LEFT_STICK,
            "companion search consumes the left-stick input after handling movement")
        assert_eq(consumed[2], ZO_DI_LEFT_STICK_NO_KEYBOARD,
            "companion search consumes the no-keyboard left-stick input after handling movement")
        -- A focus-loss callback may clear both flags before ExitSearchMode runs.
        -- The exit path must still release the real scoped DI owner.
        companion._searchModeActive = false
        companion._searchHeaderActive = false
        companion:ExitSearchMode()
        assert_true(not DIRECTIONAL_INPUT:IsListening(companion._companionSearchDirectionalInputObject),
            "companion search releases its directional-input listener even after focus clears its flags")

        DIRECTIONAL_INPUT = originalDirectionalInput
        ZO_MovementController = originalMovementController
        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL = originalMovementDirection
        MOVEMENT_CONTROLLER_MOVE_NEXT = originalMoveNext
        MOVEMENT_CONTROLLER_MOVE_PREVIOUS = originalMovePrevious
        ZO_DI_LEFT_STICK = originalLeftStick
        ZO_DI_LEFT_STICK_NO_KEYBOARD = originalLeftStickNoKeyboard
        GetGamepadLeftStickY = originalGetLeftStickY
        EQUIP_SLOT_MAIN_HAND = originalMainHand
        EQUIP_SLOT_OFF_HAND = originalOffHand
    end

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
            isInHeaderSortMode = true,
            _vendorHeaderEntryCount = 1,
            coreKeybinds = { { keybind = "BETTERUI_VENDOR_BUY" } },
            scene = { IsShowing = function() return true end },
            headerGeneric = { tabBar = tabBar },
            headerActive = true,
            requestLeaveHeaderCalls = 0,
            textSearchHeaderFocus = {
                IsActive = function() return false end,
            },
            IsHeaderActive = function(self)
                return self.headerActive == true
            end,
            RequestLeaveHeader = function(self)
                self.requestLeaveHeaderCalls = self.requestLeaveHeaderCalls + 1
                self.headerActive = false
            end,
            ExitHeaderSortMode = function(self)
                self.exitHeaderSortCalls = (self.exitHeaderSortCalls or 0) + 1
                self.isInHeaderSortMode = false
            end,
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
        assert_eq(realExitVendor.requestLeaveHeaderCalls, 1,
            "vendor search exit asks the base screen to leave header focus")
        assert_eq(realExitVendor.headerActive, false,
            "vendor search exit clears base header focus before restoring list input")
        assert_eq(realExitVendor.exitHeaderSortCalls, 1,
            "vendor search exit clears any stale header sort ownership")
        assert_eq(realExitVendor.isInHeaderSortMode, false,
            "vendor search exit leaves header sort mode before restoring list input")
        assert_eq(updateAnchorCalls, 1, "vendor search exit refreshes the production header carousel immediately")
        assert_eq(tabBar.active, true, "vendor search exit reactivates the header tab bar")
        assert_eq(tabBar.lastSelectedIndex, 2, "vendor search exit preserves the selected header index")
        assert_eq(realExitVendor.headerInputEnsured, true, "vendor search exit restores header input ownership")
        assert_eq(realExitVendor.listInputEnsured, true, "vendor search exit restores list input ownership")
        assert_eq(realExitVendor.normalizedReason, "ExitSearchMode",
            "vendor search exit normalizes directional-input ownership")
        assert_eq(keybindAddCalls, 1, "vendor search exit immediately restores the core keybind group")
        assert_eq(keybindUpdateCalls, 0, "vendor search exit does not update a core group that was absent")
        assert_true(deferredTasks.coreKeybindRefresh ~= nil,
            "vendor search exit schedules a deferred core keybind refresh")
        assert_eq(deferredTasks.coreKeybindRefresh.delayMs, 0,
            "vendor search exit refreshes core keybinds on the next frame")
        deferredTasks.coreKeybindRefresh.fn()
        assert_eq(keybindAddCalls, 2, "deferred vendor search exit re-adds the core keybind group")
        assert_eq(keybindUpdateCalls, 0, "deferred vendor search exit does not update a core group that was absent")
        assert_eq(realExitVendor.normalizedReason, "exitSearchMode:deferred",
            "deferred vendor search exit normalizes directional-input ownership again")
        assert_eq(realExitVendor._refreshingVendorHeaderAfterSearchExit, nil,
            "vendor search-exit header refresh guard is cleared")
    end

    do
        local originalBase = ZO_Gamepad_ParametricList_Screen
        ZO_Gamepad_ParametricList_Screen = {
            RequestEnterHeader = function(self)
                self.requestEnterHeaderCalls = (self.requestEnterHeaderCalls or 0) + 1
                if self.OnEnterHeader then
                    self:OnEnterHeader()
                end
            end,
        }

        local vendor = setmetatable({
            headerFocus = { IsActive = function() return false end },
            textSearchHeaderFocus = { IsActive = function() return false end },
            textSearchHeaderControl = { IsHidden = function() return false end },
            EnterSearchMode = function(self)
                self.enterSearchModeCalls = (self.enterSearchModeCalls or 0) + 1
            end,
        }, { __index = BETTERUI.Vendor.Class })

        vendor:RequestHeaderFocus()
        assert_eq(vendor.requestEnterHeaderCalls, 1,
            "vendor search entry uses base RequestEnterHeader so joystick-down can leave search")
        assert_eq(vendor.enterSearchModeCalls, 1,
            "vendor base RequestEnterHeader still reaches vendor search mode through OnEnterHeader")
        ZO_Gamepad_ParametricList_Screen = originalBase
    end

    do
        deferredTasks.coreKeybindRefresh = nil
        local leaveVendor = setmetatable({
            _searchModeActive = true,
            _searchHeaderActive = true,
            coreKeybinds = { { keybind = "BETTERUI_VENDOR_BUY" } },
            scene = { IsShowing = function() return true end },
        }, { __index = BETTERUI.Vendor.Class })

        function leaveVendor:ExitSearchMode()
            self._searchModeActive = false
            self._searchHeaderActive = false
            self.exitedSearchMode = true
        end

        BETTERUI.Vendor.Class.OnLeaveHeader(leaveVendor)
        assert_eq(leaveVendor.exitedSearchMode, true,
            "vendor header leave exits search mode")
        assert_true(deferredTasks.coreKeybindRefresh ~= nil,
            "vendor header leave schedules a deferred core keybind refresh")
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
    -- A selection change while the list is ACTIVE means the user navigated the
    -- list; a lingering "active" header focus is stale in that state and must
    -- not preserve search mode (live deadlock repro, 2026-07-03). Programmatic
    -- refreshes preserve focus via _preserveSearchFocusDuringRefresh instead.
    assert_eq(focusedLostCalls(), 1, "vendor list selection change exits search even when header focus is stale-active")

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
