--[[
File: tools/tests/test_vendor_tabs.lua
Purpose: Unit tests for vendor tab resolution and runtime guard helpers using
         the live VendorModePolicy seam under a standalone Lua harness.
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            REPAIR = 3,
            BUYBACK = 4,
            FENCE_SELL = 5,
            FENCE_LAUNDER = 6,
            STABLE = 7,
            SELL_VENGEANCE = 8,
        },
    },
}

ZO_MODE_STORE_BUY = 10
ZO_MODE_STORE_SELL = 20
ZO_MODE_STORE_REPAIR = 30
ZO_MODE_STORE_BUY_BACK = 40
ZO_MODE_STORE_SELL_STOLEN = 50
ZO_MODE_STORE_LAUNDER = 60
ZO_MODE_STORE_STABLE = 70
ZO_MODE_STORE_SELL_VENGEANCE = 80

function GetString(s) return tostring(s or "") end
function rawget(t, k) return t[k] end
function CanStoreRepair() return true end

-- ============================================================================
-- LIVE VENDOR MODE-POLICY SEAM
-- ============================================================================

local Vendor = BETTERUI.Vendor
local MODE = Vendor.MODE

local MODE_LABELS = {
    [MODE.BUY] = "Buy",
    [MODE.SELL] = "Sell",
    [MODE.REPAIR] = "Repair",
    [MODE.BUYBACK] = "Buyback",
    [MODE.FENCE_SELL] = "Fence Sell",
    [MODE.FENCE_LAUNDER] = "Fence Launder",
    [MODE.STABLE] = "Stable",
    [MODE.SELL_VENGEANCE] = "Sell Vengeance",
}

local function BuildTab(mode)
    return {
        mode = mode,
        name = function()
            return MODE_LABELS[mode]
        end,
    }
end

local function BuildTabs(modeOrder)
    local tabs = {}
    for _, mode in ipairs(modeOrder or {}) do
        tabs[#tabs + 1] = BuildTab(mode)
    end
    return tabs
end

local VENDOR_TABS = BuildTabs({
    MODE.BUY,
    MODE.SELL,
    MODE.SELL_VENGEANCE,
    MODE.REPAIR,
    MODE.STABLE,
    MODE.BUYBACK,
})

local STABLE_TABS = BuildTabs({
    MODE.BUY,
    MODE.REPAIR,
    MODE.STABLE,
})

local FENCE_TABS = BuildTabs({
    MODE.FENCE_SELL,
    MODE.FENCE_LAUNDER,
})

dofile("Modules/Vendor/Core/Policy/VendorModePolicy.lua")

Vendor.GetModeDescriptor = function(mode)
    local descriptors = {
        [MODE.BUY] = {
            nameStringId = "BUY",
            nativeModeGlobalKey = "ZO_MODE_STORE_BUY",
        },
        [MODE.SELL] = {
            nameStringId = "SELL",
            nativeModeGlobalKey = "ZO_MODE_STORE_SELL",
        },
        [MODE.REPAIR] = {
            nameStringId = "REPAIR",
            nativeModeGlobalKey = "ZO_MODE_STORE_REPAIR",
        },
        [MODE.BUYBACK] = {
            nameStringId = "BUYBACK",
            nativeModeGlobalKey = "ZO_MODE_STORE_BUY_BACK",
        },
        [MODE.FENCE_SELL] = {
            nameStringId = "FENCE_SELL",
            nativeModeGlobalKey = "ZO_MODE_STORE_SELL_STOLEN",
        },
        [MODE.FENCE_LAUNDER] = {
            nameStringId = "FENCE_LAUNDER",
            nativeModeGlobalKey = "ZO_MODE_STORE_LAUNDER",
        },
        [MODE.STABLE] = {
            nameStringId = "STABLE",
            nativeModeGlobalKey = "ZO_MODE_STORE_STABLE",
        },
        [MODE.SELL_VENGEANCE] = {
            nameStringId = "SELL_VENGEANCE",
            nativeModeGlobalKey = "ZO_MODE_STORE_SELL_VENGEANCE",
        },
    }
    return descriptors[mode]
end

-- State variables (mirroring Vendor.lua locals)
local isFenceInteraction = false
local isStableInteraction = false
local fenceEnableSell = false
local fenceEnableLaunder = false
local sessionHasBuyMode = false
local activeNativeModes = {}
local sellVengeanceAvailable = true

local function IsModeTabAvailable(mode)
    return mode ~= MODE.SELL_VENGEANCE or sellVengeanceAvailable
end

local function GetActiveTabs()
    local storeManager = { activeComponents = {} }
    for nativeMode in pairs(activeNativeModes) do
        storeManager.activeComponents[#storeManager.activeComponents + 1] = {
            GetStoreMode = function()
                return nativeMode
            end,
        }
    end

    return Vendor.ModePolicy.GetActiveTabs({
        isFenceInteraction = isFenceInteraction,
        isStableInteraction = isStableInteraction,
        fenceEnableSell = fenceEnableSell,
        fenceEnableLaunder = fenceEnableLaunder,
        sessionHasBuyMode = sessionHasBuyMode,
        vendorTabs = VENDOR_TABS,
        stableTabs = STABLE_TABS,
        fenceTabs = FENCE_TABS,
        isModeTabAvailable = IsModeTabAvailable,
        storeManager = storeManager,
    })
end

local function BuildActiveModeSet(tabs)
    return Vendor.ModePolicy.BuildActiveModeSet(tabs)
end

local function IsSellBuybackOnlyModeSet(modeSet)
    return Vendor.ModePolicy.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)
end

local function GetToggleModePair()
    return Vendor.ModePolicy.GetToggleModePair({
        isFenceInteraction = isFenceInteraction,
        isStableInteraction = isStableInteraction,
        sessionHasBuyMode = sessionHasBuyMode,
        tabs = GetActiveTabs(),
    })
end

Vendor.instance = nil
Vendor._isClosing = false

local function ShouldAbortOpenStoreSync()
    if Vendor._isClosing then
        return true
    end
    if not Vendor.instance then
        return true
    end
    if isFenceInteraction then
        return true
    end
    if Vendor.instance.IsSceneActiveOrShowing and not Vendor.instance:IsSceneActiveOrShowing() then
        return true
    end
    return false
end

local function ShouldAbortDeferredVendorRefresh(vendorInstance, expectedMode)
    if Vendor._isClosing then
        return true
    end
    if not vendorInstance then
        return true
    end
    if expectedMode and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() ~= expectedMode then
        return true
    end
    if vendorInstance.IsSceneShowing then
        return not vendorInstance:IsSceneShowing()
    end
    if vendorInstance.IsSceneActiveOrShowing then
        return not vendorInstance:IsSceneActiveOrShowing()
    end
    return false
end

local DIRECTIONAL_INPUT = {
    inputObjects = {},
}

function DIRECTIONAL_INPUT:IsListening(obj)
    for _, entry in ipairs(self.inputObjects) do
        if entry == obj then
            return true
        end
    end
    return false
end

function DIRECTIONAL_INPUT:Deactivate(obj)
    for index = #self.inputObjects, 1, -1 do
        if self.inputObjects[index] == obj then
            table.remove(self.inputObjects, index)
            return
        end
    end
end

local function CountDirectionalInputRegistrations(obj)
    if not obj then
        return 0
    end

    local registrationCount = 0
    for _, registeredObject in ipairs(DIRECTIONAL_INPUT.inputObjects) do
        if registeredObject == obj then
            registrationCount = registrationCount + 1
        end
    end

    return registrationCount
end

local function SetTabBarVisualActive(tabBar, active)
    if not tabBar or tabBar.active == active then
        return
    end

    tabBar.active = active
    tabBar.dirty = false

    local onActivatedChanged = (tabBar.GetOnActivatedChangedFunction and tabBar:GetOnActivatedChangedFunction())
        or tabBar.onActivatedChangedFunction
    if onActivatedChanged then
        onActivatedChanged(tabBar, active)
    end

    if tabBar.RefreshVisible then
        tabBar:RefreshVisible()
    end
    if tabBar.Commit then
        tabBar:Commit()
    end
end

local function ReleaseDirectionalInputRegistrations(obj, includeMovementController)
    if not obj then
        return 0
    end

    local releasedCount = 0
    local releasedCandidates = {}
    local function ReleaseCandidate(candidate)
        if not candidate or releasedCandidates[candidate] then
            return
        end
        releasedCandidates[candidate] = true
        local safetyCounter = 0
        while candidate and DIRECTIONAL_INPUT:IsListening(candidate) and safetyCounter < 8 do
            DIRECTIONAL_INPUT:Deactivate(candidate)
            releasedCount = releasedCount + 1
            safetyCounter = safetyCounter + 1
        end
    end

    ReleaseCandidate(obj)
    ReleaseCandidate(obj.spinner)
    if includeMovementController then
        ReleaseCandidate(obj.movementController)
        ReleaseCandidate(obj.horizontalMovementController)
        ReleaseCandidate(obj.verticalMovementController)
    end

    return releasedCount
end

local function ReleaseSpinnerDirectionalInput(spinner)
    if not spinner then
        return
    end

    if spinner.DetachFromListEntry then
        spinner:DetachFromListEntry()
    end
    if spinner.Deactivate then
        spinner:Deactivate()
    end

    ReleaseDirectionalInputRegistrations(spinner, true)

    if spinner.spinner then
        if spinner.spinner.Deactivate then
            spinner.spinner:Deactivate()
        end
        ReleaseDirectionalInputRegistrations(spinner.spinner, true)
    end
end

local function ForEachHeaderDirectionalInputCandidate(header, callback)
    if not header or type(callback) ~= "function" then
        return
    end

    local seen = {}
    local function Visit(candidate)
        if not candidate or seen[candidate] then
            return
        end
        seen[candidate] = true
        callback(candidate)
    end

    Visit(header.headerFocus)
    Visit(header.headerFocusControl)
    Visit(header.headerFocusControl and header.headerFocusControl.owner)
    Visit(header.tabBar)
    Visit(header.tabBar and header.tabBar.control)
end

local function ReleaseHeaderDirectionalInput(header)
    local releasedCount = 0

    ForEachHeaderDirectionalInputCandidate(header, function(candidate)
        if candidate.Deactivate then
            candidate:Deactivate()
        end
        releasedCount = releasedCount + ReleaseDirectionalInputRegistrations(candidate, true)
    end)

    return releasedCount
end

local function NormalizeDirectionalInputOwnership(context)
    if not context or not context.sceneShowing then
        return 0
    end

    local allowed = {}
    local function Allow(obj, includeMovementController)
        if not obj then
            return
        end

        allowed[obj] = true
        if obj.spinner then
            allowed[obj.spinner] = true
        end
        if includeMovementController then
            if obj.movementController then
                allowed[obj.movementController] = true
            end
            if obj.spinner and obj.spinner.spinner then
                allowed[obj.spinner.spinner] = true
            end
        end
    end

    local function AllowHeader(header)
        ForEachHeaderDirectionalInputCandidate(header, function(candidate)
            Allow(candidate, true)
        end)
    end

    if context.confirmationMode then
        Allow(context.spinner, true)
    elseif context.searchModeActive or context.searchHeaderActive then
        Allow(context.textSearchHeaderFocus, true)
        Allow(context.headerFocus, true)
        Allow(context.textSearchHeaderControl, true)
        AllowHeader(context.headerGeneric)
        AllowHeader(context.header)
    elseif context.isInHeaderSortMode then
        Allow(context.headerGeneric and context.headerGeneric.tabBar, true)
        AllowHeader(context.headerGeneric)
        AllowHeader(context.header)
    else
        Allow(context.list, true)
    end

    local snapshot = {}
    for index, obj in ipairs(DIRECTIONAL_INPUT.inputObjects) do
        snapshot[index] = obj
    end

    local releasedCount = 0
    for _, obj in ipairs(snapshot) do
        if obj and not allowed[obj] then
            releasedCount = releasedCount + ReleaseDirectionalInputRegistrations(obj, true)
        end
    end

    return releasedCount
end

local function EnsureListInputActive(context)
    local list = context and context.list
    if not (context and context.sceneShowing and list) then
        return
    end

    local listRegistrationCount = CountDirectionalInputRegistrations(list)
    local controllerRegistrationCount = CountDirectionalInputRegistrations(list.movementController)
    local listListening = listRegistrationCount > 0
    local controllerListening = controllerRegistrationCount > 0
    local shouldResetListInput = listRegistrationCount > 1 or controllerRegistrationCount > 1
        or (controllerListening and not listListening)
    local isListActive = not list.IsActive or list:IsActive()

    if shouldResetListInput then
        ReleaseDirectionalInputRegistrations(list, true)
        if list.SetActive then
            list:SetActive(false)
        elseif list.Deactivate and (not list.IsActive or list:IsActive()) then
            list:Deactivate()
        end
        listListening = false
        controllerListening = false
        isListActive = false
    end

    local shouldActivateList = list.Activate and (shouldResetListInput or not isListActive)
    if shouldActivateList then
        list.directionalInputEnabled = true
    elseif list.SetDirectionalInputEnabled and not listListening then
        list:SetDirectionalInputEnabled(true)
        listListening = CountDirectionalInputRegistrations(list) > 0
    end

    controllerListening = CountDirectionalInputRegistrations(list.movementController) > 0
    if shouldActivateList then
        list:Activate()
    end

    if not context.confirmationMode and not context.searchModeActive and not context.searchHeaderActive then
        NormalizeDirectionalInputOwnership(context)
    end
end

local function DeferredNormalizeDirectionalInputOwnership(context)
    if not context or not context.sceneShowing then
        return 0
    end

    if context.confirmationMode or context.searchModeActive or context.searchHeaderActive then
        return 0
    end

    return NormalizeDirectionalInputOwnership(context)
end

local function SupportsVendorHeaderSearch(context)
    return context
        and context.textSearchKeybindStripDescriptor ~= nil
        and context.textSearchHeaderControl ~= nil
        and context.textSearchHeaderFocus ~= nil
end

local function DetachUnexpectedSearchHeaderFocus(context)
    if SupportsVendorHeaderSearch(context) then
        return false
    end

    local focusControl = context and context.textSearchHeaderControl
    local focusObject = context and context.textSearchHeaderFocus
    local hadSearchFocus = context and (focusControl ~= nil or focusObject ~= nil or context.headerFocus ~= nil)
    if not hadSearchFocus then
        return false
    end

    local function ClearHeader(header)
        if not header then
            return
        end
        if header.headerFocusControl == focusControl then
            header.headerFocusControl = nil
        end
        if header.headerFocus == focusObject or header.headerFocus == focusControl then
            header.headerFocus = nil
        end
        local tabBarControl = header.tabBar and header.tabBar.control
        if tabBarControl then
            if tabBarControl.headerFocusControl == focusControl then
                tabBarControl.headerFocusControl = nil
            end
            if tabBarControl.headerFocus == focusObject or tabBarControl.headerFocus == focusControl then
                tabBarControl.headerFocus = nil
            end
        end
    end

    if focusObject and focusObject.SetFocused then
        focusObject:SetFocused(false)
    end
    if focusObject and focusObject.Deactivate then
        focusObject:Deactivate()
    end
    if focusObject then
        ReleaseDirectionalInputRegistrations(focusObject, true)
    end
    if focusControl and focusControl.SetHidden then
        focusControl:SetHidden(true)
    end
    if focusControl then
        ReleaseDirectionalInputRegistrations(focusControl, true)
    end

    ClearHeader(context.headerGeneric)
    ClearHeader(context.header)

    if context.headerFocus == focusObject or context.headerFocus == focusControl then
        context.headerFocus = nil
    end

    context._searchModeActive = false
    context._searchHeaderActive = false
    return true
end

local function EnsureHeaderKeybindsActive(header, sceneShowing, isInHeaderSortMode)
    local tabBar = header and header.tabBar
    if isInHeaderSortMode or not sceneShowing or not tabBar then
        return
    end

    ReleaseHeaderDirectionalInput(header)
    SetTabBarVisualActive(tabBar, true)
end

local function DeactivateListInput(list)
    if not list then
        return
    end
    if list.SetDirectionalInputEnabled then
        list:SetDirectionalInputEnabled(false)
    end
    if list.Deactivate and (not list.IsActive or list:IsActive()) then
        list:Deactivate()
    end
    ReleaseDirectionalInputRegistrations(list, true)
end

-- Helpers to set state for tests
local function setRegularStore()
    isFenceInteraction = false
    isStableInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false
    sessionHasBuyMode = false
    activeNativeModes = {
        [ZO_MODE_STORE_BUY] = true,
        [ZO_MODE_STORE_SELL] = true,
        [ZO_MODE_STORE_REPAIR] = true,
        [ZO_MODE_STORE_BUY_BACK] = true,
    }
end

local function setStableStore()
    isFenceInteraction = false
    isStableInteraction = true
    fenceEnableSell = false
    fenceEnableLaunder = false
    sessionHasBuyMode = true
    activeNativeModes = {
        [ZO_MODE_STORE_BUY] = true,
        [ZO_MODE_STORE_REPAIR] = true,
        [ZO_MODE_STORE_STABLE] = true,
    }
end

local function setFence(sell, launder)
    isFenceInteraction = true
    isStableInteraction = false
    fenceEnableSell = sell
    fenceEnableLaunder = launder
    sessionHasBuyMode = false
    activeNativeModes = {}
end

local function withMockedTabs(mockTabs, fn)
    local originalGetActiveTabs = GetActiveTabs
    GetActiveTabs = function()
        return mockTabs
    end
    local ok, err = pcall(fn)
    GetActiveTabs = originalGetActiveTabs
    if not ok then
        error(err)
    end
end

-- ============================================================================
-- TEST INFRASTRUCTURE
-- ============================================================================

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

-- ============================================================================
-- TESTS: GetActiveTabs
-- ============================================================================

print("[GetActiveTabs]")

-- Regular store returns all 4 vendor tabs
setRegularStore()
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 4, "regular store: 4 tabs")
    assert_eq(tabs[1].mode, MODE.BUY, "regular store: first tab is BUY")
    assert_eq(tabs[2].mode, MODE.SELL, "regular store: second tab is SELL")
    assert_eq(tabs[3].mode, MODE.REPAIR, "regular store: third tab is REPAIR")
    assert_eq(tabs[4].mode, MODE.BUYBACK, "regular store: fourth tab is BUYBACK")
end

setStableStore()
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 3, "stable store: 3 tabs")
    assert_eq(tabs[1].mode, MODE.BUY, "stable store: first tab is BUY")
    assert_eq(tabs[2].mode, MODE.REPAIR, "stable store: second tab is REPAIR")
    assert_eq(tabs[3].mode, MODE.STABLE, "stable store: third tab is STABLE")
end

setRegularStore()
do
    activeNativeModes[ZO_MODE_STORE_SELL_VENGEANCE] = true
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 5, "vengeance store: 5 tabs when sell vengeance is active")
    assert_eq(tabs[3].mode, MODE.SELL_VENGEANCE, "vengeance store: third tab is SELL_VENGEANCE")
end

-- Fence with both sell and launder
setFence(true, true)
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 2, "fence both: 2 tabs")
    assert_eq(tabs[1].mode, MODE.FENCE_SELL, "fence both: first is FENCE_SELL")
    assert_eq(tabs[2].mode, MODE.FENCE_LAUNDER, "fence both: second is FENCE_LAUNDER")
end

-- Fence with only sell
setFence(true, false)
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 1, "fence sell-only: 1 tab")
    assert_eq(tabs[1].mode, MODE.FENCE_SELL, "fence sell-only: FENCE_SELL")
end

-- Fence with only launder
setFence(false, true)
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 1, "fence launder-only: 1 tab")
    assert_eq(tabs[1].mode, MODE.FENCE_LAUNDER, "fence launder-only: FENCE_LAUNDER")
end

-- Fence with neither (safety fallback)
setFence(false, false)
do
    local tabs = GetActiveTabs()
    assert_eq(#tabs, 1, "fence none: safety fallback 1 tab")
    assert_eq(tabs[1].mode, MODE.FENCE_SELL, "fence none: safety fallback is FENCE_SELL")
end

-- Tab name functions return strings
setRegularStore()
do
    local tabs = GetActiveTabs()
    assert_eq(type(tabs[1].name()), "string", "tab name returns string")
end

print("[GetToggleModePair]")

setRegularStore()
do
    local firstMode, secondMode = GetToggleModePair()
    assert_eq(firstMode, MODE.BUY, "regular store toggle: first mode BUY")
    assert_eq(secondMode, MODE.SELL, "regular store toggle: second mode SELL")
end

setFence(true, true)
do
    local firstMode, secondMode = GetToggleModePair()
    assert_eq(firstMode, MODE.FENCE_SELL, "fence toggle: first mode FENCE_SELL")
    assert_eq(secondMode, MODE.FENCE_LAUNDER, "fence toggle: second mode FENCE_LAUNDER")
end

setStableStore()
do
    local firstMode, secondMode = GetToggleModePair()
    assert_eq(firstMode, MODE.BUY, "stable toggle: first mode BUY")
    assert_eq(secondMode, MODE.STABLE, "stable toggle: second mode STABLE")
end

setRegularStore()
withMockedTabs({
    { mode = MODE.SELL },
    { mode = MODE.BUYBACK },
}, function()
    local firstMode, secondMode = GetToggleModePair()
    assert_eq(firstMode, MODE.SELL, "sell-buyback toggle: first mode SELL")
    assert_eq(secondMode, MODE.BUYBACK, "sell-buyback toggle: second mode BUYBACK")
end)

print("[IsSellBuybackOnlyModeSet]")

setRegularStore()
do
    local isSellBuybackOnly = IsSellBuybackOnlyModeSet({
        [MODE.SELL] = true,
        [MODE.BUYBACK] = true,
    })
    assert_eq(isSellBuybackOnly, true, "sell+buyback modes are detected as sell-buyback-only")
end

do
    local isSellBuybackOnly = IsSellBuybackOnlyModeSet({
        [MODE.BUY] = true,
        [MODE.SELL] = true,
    })
    assert_eq(isSellBuybackOnly, false, "buy+sell modes are not sell-buyback-only")
end

print("[ShouldAbortOpenStoreSync]")

setRegularStore()
Vendor._isClosing = false
Vendor.instance = nil
do
    assert_eq(ShouldAbortOpenStoreSync(), true, "sync aborts without vendor instance")
end

Vendor.instance = {
    IsSceneActiveOrShowing = function()
        return true
    end,
}
do
    assert_eq(ShouldAbortOpenStoreSync(), false, "sync proceeds for active regular vendor scene")
end

Vendor._isClosing = true
do
    assert_eq(ShouldAbortOpenStoreSync(), true, "sync aborts while close is in progress")
end

Vendor._isClosing = false
setFence(true, false)
do
    assert_eq(ShouldAbortOpenStoreSync(), true, "sync aborts during fence interaction")
end

setRegularStore()
Vendor.instance = {
    IsSceneActiveOrShowing = function()
        return false
    end,
}
do
    assert_eq(ShouldAbortOpenStoreSync(), true, "sync aborts when vendor scene is no longer active")
end

print("[ShouldAbortDeferredVendorRefresh]")

Vendor._isClosing = false
do
    assert_eq(ShouldAbortDeferredVendorRefresh(nil, MODE.BUY), true,
        "deferred refresh aborts without vendor instance")
end

Vendor._isClosing = true
do
    assert_eq(ShouldAbortDeferredVendorRefresh({ IsSceneShowing = function() return true end }, MODE.BUY), true,
        "deferred refresh aborts while vendor is closing")
end

Vendor._isClosing = false
do
    local vendorInstance = {
        GetCurrentMode = function()
            return MODE.SELL
        end,
        IsSceneShowing = function()
            return true
        end,
    }
    assert_eq(ShouldAbortDeferredVendorRefresh(vendorInstance, MODE.BUY), true,
        "deferred refresh aborts when mode changed")
end

do
    local vendorInstance = {
        GetCurrentMode = function()
            return MODE.BUY
        end,
        IsSceneShowing = function()
            return false
        end,
        IsSceneActiveOrShowing = function()
            return true
        end,
    }
    assert_eq(ShouldAbortDeferredVendorRefresh(vendorInstance, MODE.BUY), true,
        "deferred refresh aborts while scene is transitioning out")
end

do
    local vendorInstance = {
        GetCurrentMode = function()
            return MODE.BUY
        end,
        IsSceneShowing = function()
            return true
        end,
    }
    assert_eq(ShouldAbortDeferredVendorRefresh(vendorInstance, MODE.BUY), false,
        "deferred refresh proceeds only while buy scene is fully showing")
end

print("[DirectionalInput list cleanup]")

do
    local movementController = { id = "movementController" }
    local list = {
        setActiveCalls = 0,
        movementController = movementController,
        directionalInputEnabled = false,
        activated = 0,
        active = false,
        SetDirectionalInputEnabled = function(self, enabled)
            self.directionalInputEnabled = enabled
            if enabled then
                table.insert(DIRECTIONAL_INPUT.inputObjects, self)
            else
                DIRECTIONAL_INPUT:Deactivate(self)
            end
        end,
        SetActive = function(self, active)
            self.setActiveCalls = self.setActiveCalls + 1
            self.active = active
            if not active then
                DIRECTIONAL_INPUT:Deactivate(self)
            end
        end,
        IsActive = function(self)
            return self.active
        end,
        Activate = function(self)
            self.activated = self.activated + 1
            self.active = true
            if self.directionalInputEnabled then
                table.insert(DIRECTIONAL_INPUT.inputObjects, self)
            end
        end,
        Deactivate = function(self)
            self.active = false
            DIRECTIONAL_INPUT:Deactivate(self)
            DIRECTIONAL_INPUT:Deactivate(self.movementController)
        end,
    }

    EnsureListInputActive({ sceneShowing = true, list = list })
    assert_eq(list.activated, 1, "list activates once when not already listening")
    assert_eq(DIRECTIONAL_INPUT:IsListening(list), true,
        "list activation registers vendor list")
    assert_eq(CountDirectionalInputRegistrations(list), 1,
        "list activation registers vendor list exactly once")

    EnsureListInputActive({ sceneShowing = true, list = list })
    assert_eq(list.activated, 1, "list does not reactivate while already listening")
    assert_eq(CountDirectionalInputRegistrations(list), 1,
        "list does not duplicate vendor list registrations while already active")

    table.insert(DIRECTIONAL_INPUT.inputObjects, list)
    table.insert(DIRECTIONAL_INPUT.inputObjects, list)
    table.insert(DIRECTIONAL_INPUT.inputObjects, movementController)
    EnsureListInputActive({ sceneShowing = true, list = list })
    assert_eq(CountDirectionalInputRegistrations(list), 1,
        "list input activation collapses duplicate vendor list registrations")
    assert_eq(CountDirectionalInputRegistrations(movementController), 0,
        "list input activation clears duplicate movement-controller registrations")
    assert_eq(list.setActiveCalls, 1,
        "list input activation resets stale active state before reactivation")

    table.insert(DIRECTIONAL_INPUT.inputObjects, movementController)
    assert_eq(ReleaseDirectionalInputRegistrations(list, true), 2,
        "release helper removes vendor list and movement-controller registrations")
    assert_eq(DIRECTIONAL_INPUT:IsListening(list), false,
        "release helper clears vendor list registrations")
    assert_eq(DIRECTIONAL_INPUT:IsListening(movementController), false,
        "release helper clears all movement-controller registrations")

    table.insert(DIRECTIONAL_INPUT.inputObjects, list)
    table.insert(DIRECTIONAL_INPUT.inputObjects, movementController)
    table.insert(DIRECTIONAL_INPUT.inputObjects, movementController)
    list.active = true
    DeactivateListInput(list)
    assert_eq(list.directionalInputEnabled, false, "deactivate disables list directional input")
    assert_eq(DIRECTIONAL_INPUT:IsListening(list), false,
        "deactivate clears vendor list registrations")
    assert_eq(DIRECTIONAL_INPUT:IsListening(movementController), false,
        "deactivate clears remaining movement-controller registrations")
end

do
    local list = {
        activationCount = 0,
        directionalInputEnabled = false,
        active = false,
        SetDirectionalInputEnabled = function(self, enabled)
            self.directionalInputEnabled = enabled
            if enabled then
                table.insert(DIRECTIONAL_INPUT.inputObjects, self)
            else
                DIRECTIONAL_INPUT:Deactivate(self)
            end
        end,
        SetActive = function(self, active)
            self.active = active
            if not active then
                DIRECTIONAL_INPUT:Deactivate(self)
            end
        end,
        IsActive = function(self)
            return self.active
        end,
        Activate = function(self)
            self.activationCount = self.activationCount + 1
            self.active = true
            if self.directionalInputEnabled then
                table.insert(DIRECTIONAL_INPUT.inputObjects, self)
            end
        end,
        Deactivate = function(self)
            self.active = false
            DIRECTIONAL_INPUT:Deactivate(self)
        end,
    }

    EnsureListInputActive({ sceneShowing = true, list = list })
    assert_eq(list.activationCount, 1,
        "list input activation runs one clean activate cycle")
    assert_eq(CountDirectionalInputRegistrations(list), 1,
        "list input activation avoids double-registering a parametric list")

    ReleaseDirectionalInputRegistrations(list, true)
end

print("[DirectionalInput header cleanup]")

do
    local headerMovementController = { id = "headerMovementController" }
    local tabBar = {
        movementController = headerMovementController,
        activationChanges = {},
        refreshVisibleCalls = 0,
        commitCalls = 0,
        activated = 0,
        active = false,
        GetOnActivatedChangedFunction = function(self)
            return self.onActivatedChangedFunction
        end,
        onActivatedChangedFunction = function(self, active)
            self.activationChanges[#self.activationChanges + 1] = active
        end,
        RefreshVisible = function(self)
            self.refreshVisibleCalls = self.refreshVisibleCalls + 1
        end,
        Commit = function(self)
            self.commitCalls = self.commitCalls + 1
        end,
        Activate = function(self)
            self.activated = self.activated + 1
            self.active = true
            table.insert(DIRECTIONAL_INPUT.inputObjects, self.movementController)
        end,
        Deactivate = function(self)
            self.active = false
            DIRECTIONAL_INPUT:Deactivate(self.movementController)
        end,
    }

    table.insert(DIRECTIONAL_INPUT.inputObjects, headerMovementController)
    EnsureHeaderKeybindsActive({ tabBar = tabBar }, true, false)
    assert_eq(tabBar.activated, 0, "header helper does not activate tab bar directional input")
    assert_eq(tabBar.active, true, "header helper keeps tab bar visually active")
    assert_eq(DIRECTIONAL_INPUT:IsListening(headerMovementController), false,
        "header helper clears header movement-controller registrations")
    assert_eq(tabBar.refreshVisibleCalls, 1, "header helper refreshes header visuals")
    assert_eq(tabBar.commitCalls, 1, "header helper commits header visuals")
end

do
    local tabBar = {
        refreshVisibleCalls = 0,
        commitCalls = 0,
        active = false,
        RefreshVisible = function(self)
            self.refreshVisibleCalls = self.refreshVisibleCalls + 1
        end,
        Commit = function(self)
            self.commitCalls = self.commitCalls + 1
        end,
    }

    EnsureHeaderKeybindsActive({ tabBar = tabBar }, false, false)
    assert_eq(tabBar.active, false,
        "header helper does not alter visuals before the scene is showing")
    assert_eq(tabBar.refreshVisibleCalls, 0,
        "header helper does not refresh visuals before the scene is showing")
    assert_eq(tabBar.commitCalls, 0,
        "header helper does not commit visuals before the scene is showing")
end

do
    local tabBar = {
        refreshVisibleCalls = 0,
        commitCalls = 0,
        active = false,
        RefreshVisible = function(self)
            self.refreshVisibleCalls = self.refreshVisibleCalls + 1
        end,
        Commit = function(self)
            self.commitCalls = self.commitCalls + 1
        end,
    }

    EnsureHeaderKeybindsActive({ tabBar = tabBar }, true, true)
    assert_eq(tabBar.active, false,
        "header helper does not alter visuals while header sort mode owns focus")
    assert_eq(tabBar.refreshVisibleCalls, 0,
        "header helper does not refresh visuals while header sort mode owns focus")
    assert_eq(tabBar.commitCalls, 0,
        "header helper does not commit visuals while header sort mode owns focus")
end

do
    local anonymousOwner = { id = "anonymousHeaderOwner" }
    local header = {
        tabBar = {},
        headerFocusControl = { owner = anonymousOwner },
    }

    table.insert(DIRECTIONAL_INPUT.inputObjects, anonymousOwner)
    EnsureHeaderKeybindsActive(header, true, false)
    assert_eq(DIRECTIONAL_INPUT:IsListening(anonymousOwner), false,
        "header helper clears headerFocusControl owner registrations")
end

print("[DirectionalInput spinner cleanup]")

do
    local nestedSpinner = {
        Deactivate = function(self)
            DIRECTIONAL_INPUT:Deactivate(self)
        end,
    }
    local spinner = {
        spinner = nestedSpinner,
        detached = 0,
        deactivated = 0,
        DetachFromListEntry = function(self)
            self.detached = self.detached + 1
        end,
        Deactivate = function(self)
            self.deactivated = self.deactivated + 1
        end,
    }

    table.insert(DIRECTIONAL_INPUT.inputObjects, nestedSpinner)
    ReleaseSpinnerDirectionalInput(spinner)

    assert_eq(spinner.detached, 1, "spinner cleanup detaches anchored spinner")
    assert_eq(spinner.deactivated, 1, "spinner cleanup deactivates spinner wrapper")
    assert_eq(DIRECTIONAL_INPUT:IsListening(nestedSpinner), false,
        "spinner cleanup clears nested spinner directional input")
end

print("[DirectionalInput ownership normalization]")

do
    local strayObject = { id = "strayObject" }
    local list = {
        movementController = { id = "listMovementController" },
    }

    table.insert(DIRECTIONAL_INPUT.inputObjects, strayObject)
    table.insert(DIRECTIONAL_INPUT.inputObjects, list)

    assert_eq(NormalizeDirectionalInputOwnership({ sceneShowing = true, list = list }), 1,
        "normalization removes one stray directional input owner")
    assert_eq(DIRECTIONAL_INPUT:IsListening(strayObject), false,
        "normalization removes stray directional input owner")
    assert_eq(DIRECTIONAL_INPUT:IsListening(list), true,
        "normalization preserves vendor list ownership")

    DIRECTIONAL_INPUT:Deactivate(list)
end

do
    local strayObject = { id = "postActivateStray" }
    local list = {
        movementController = { id = "listMovementControllerPostActivate" },
        active = false,
        IsActive = function(self)
            return self.active
        end,
        Activate = function(self)
            self.active = true
            table.insert(DIRECTIONAL_INPUT.inputObjects, self.movementController)
            table.insert(DIRECTIONAL_INPUT.inputObjects, strayObject)
        end,
    }

    EnsureListInputActive({ sceneShowing = true, list = list })
    assert_eq(DIRECTIONAL_INPUT:IsListening(strayObject), false,
        "post-activation normalization removes stray owner registered during list activation")
    assert_eq(DIRECTIONAL_INPUT:IsListening(list.movementController), true,
        "post-activation normalization preserves list movement controller")

    DIRECTIONAL_INPUT:Deactivate(list.movementController)
end

do
    local list = {
        activationCount = 0,
        directionalInputEnabled = false,
        active = false,
        SetDirectionalInputEnabled = function(self, enabled)
            self.directionalInputEnabled = enabled
        end,
        IsActive = function(self)
            return self.active
        end,
        Activate = function(self)
            self.activationCount = self.activationCount + 1
            self.active = true
        end,
    }

    EnsureListInputActive({ sceneShowing = false, list = list })
    assert_eq(list.activationCount, 0,
        "list helper does not activate input before the scene is showing")
    assert_eq(list.directionalInputEnabled, false,
        "list helper does not enable directional input before the scene is showing")
end

do
    local lateStrayObject = { id = "lateStrayObject" }
    local list = {
        movementController = { id = "lateNormalizeMovementController" },
        active = true,
        IsActive = function(self)
            return self.active
        end,
    }

    table.insert(DIRECTIONAL_INPUT.inputObjects, list.movementController)
    table.insert(DIRECTIONAL_INPUT.inputObjects, lateStrayObject)

    assert_eq(DeferredNormalizeDirectionalInputOwnership({ sceneShowing = true, list = list }), 1,
        "deferred normalization removes late stray owner")
    assert_eq(DIRECTIONAL_INPUT:IsListening(lateStrayObject), false,
        "deferred normalization clears late stray owner")
    assert_eq(DIRECTIONAL_INPUT:IsListening(list.movementController), true,
        "deferred normalization preserves active list ownership")

    DIRECTIONAL_INPUT:Deactivate(list.movementController)
end

print("[DirectionalInput stale search cleanup]")

do
    local focusObject = {
        deactivated = 0,
        focused = true,
        SetFocused = function(self, isFocused)
            self.focused = isFocused
        end,
        Deactivate = function(self)
            self.deactivated = self.deactivated + 1
        end,
    }
    local focusControl = {
        hidden = false,
        SetHidden = function(self, hidden)
            self.hidden = hidden
        end,
    }
    local context = {
        textSearchHeaderFocus = focusObject,
        textSearchHeaderControl = focusControl,
        headerFocus = focusObject,
        headerGeneric = {
            headerFocusControl = focusControl,
        },
        header = {
            headerFocusControl = focusControl,
        },
        _searchModeActive = true,
        _searchHeaderActive = true,
    }

    assert_eq(DetachUnexpectedSearchHeaderFocus(context), true,
        "unexpected search header focus is detached for vendor")
    assert_eq(context.headerFocus, nil,
        "detaching stale vendor search clears screen headerFocus")
    assert_eq(context.headerGeneric.headerFocusControl, nil,
        "detaching stale vendor search clears generic headerFocusControl")
    assert_eq(context.header.headerFocusControl, nil,
        "detaching stale vendor search clears root headerFocusControl")
    assert_eq(context._searchModeActive, false,
        "detaching stale vendor search clears search mode flag")
    assert_eq(context._searchHeaderActive, false,
        "detaching stale vendor search clears search header flag")
    assert_eq(focusControl.hidden, true,
        "detaching stale vendor search hides text search control")
    assert_eq(focusObject.deactivated, 1,
        "detaching stale vendor search deactivates search focus object")
end

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
