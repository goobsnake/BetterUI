--[[
File: tools/tests/test_vendor_stable_transition.lua
Purpose: Regression test for stablemaster state leaking into the next normal vendor.
]]

local passed = 0
local failed = 0

local MODE = {
    BUY = 1,
    SELL = 2,
    REPAIR = 3,
    BUYBACK = 4,
    STABLE = 7,
}

local ZO_MODE_STORE_BUY = 11
local ZO_MODE_STORE_SELL = 12
local ZO_MODE_STORE_REPAIR = 13
local ZO_MODE_STORE_BUY_BACK = 14
local ZO_MODE_STORE_STABLE = 15

local INTERACTION_VENDOR = 21
local INTERACTION_STABLE = 22

local VENDOR_TABS = {
    { mode = MODE.BUY },
    { mode = MODE.SELL },
    { mode = MODE.REPAIR },
    { mode = MODE.BUYBACK },
}

local STABLE_TABS = {
    { mode = MODE.BUY },
    { mode = MODE.REPAIR },
    { mode = MODE.STABLE },
}

local Vendor = {
    _sessionHasBuyMode = false,
}

local isStableInteraction = false
local currentInteractionType = nil
local isFenceInteraction = false

local storeManager = {
    activeComponents = {},
    components = {},
}

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function ResolveNativeModeForVendorMode(mode)
    if mode == MODE.BUY then
        return ZO_MODE_STORE_BUY
    elseif mode == MODE.SELL then
        return ZO_MODE_STORE_SELL
    elseif mode == MODE.REPAIR then
        return ZO_MODE_STORE_REPAIR
    elseif mode == MODE.BUYBACK then
        return ZO_MODE_STORE_BUY_BACK
    elseif mode == MODE.STABLE then
        return ZO_MODE_STORE_STABLE
    end
    return nil
end

local function GetNativeActiveModeSet()
    local modeSet = {}
    for _, component in ipairs(storeManager.activeComponents or {}) do
        local mode = component and (component.mode or (component.GetStoreMode and component:GetStoreMode()))
        if mode then
            modeSet[mode] = true
        end
    end
    return modeSet
end

local function SetActiveComponents(_, rebuiltModes)
    local rebuilt = {}
    for _, mode in ipairs(rebuiltModes or {}) do
        rebuilt[#rebuilt + 1] = {
            mode = mode,
            GetStoreMode = function(self)
                return self.mode
            end,
        }
    end
    storeManager.activeComponents = rebuilt
end

storeManager.SetActiveComponents = SetActiveComponents
for _, mode in ipairs({ ZO_MODE_STORE_BUY, ZO_MODE_STORE_SELL, ZO_MODE_STORE_REPAIR, ZO_MODE_STORE_BUY_BACK, ZO_MODE_STORE_STABLE }) do
    storeManager.components[mode] = true
end

local function IsNativeStableModeActive()
    local nativeModeSet = GetNativeActiveModeSet()
    return nativeModeSet[ZO_MODE_STORE_STABLE] == true
end

local function EnsureNativeStoreComponents()
    local componentTable = {}
    local seenActiveModes = {}
    for _, component in ipairs(storeManager.activeComponents or {}) do
        local mode = component and (component.mode or (component.GetStoreMode and component:GetStoreMode()))
        if mode and not seenActiveModes[mode] then
            seenActiveModes[mode] = true
            componentTable[#componentTable + 1] = mode
        end
    end

    local includeBuy = Vendor._sessionHasBuyMode == true or seenActiveModes[ZO_MODE_STORE_BUY] == true
    if includeBuy then
        Vendor._sessionHasBuyMode = true
    end

    local needRebuild = false
    if isStableInteraction then
        needRebuild = (#componentTable == 0)
            or (includeBuy and not seenActiveModes[ZO_MODE_STORE_BUY])
            or not seenActiveModes[ZO_MODE_STORE_STABLE]
            or seenActiveModes[ZO_MODE_STORE_SELL]
            or seenActiveModes[ZO_MODE_STORE_BUY_BACK]
    else
        needRebuild = (#componentTable == 0)
            or (not isFenceInteraction and includeBuy and not seenActiveModes[ZO_MODE_STORE_BUY])
            or seenActiveModes[ZO_MODE_STORE_STABLE]
    end

    if not needRebuild then
        return
    end

    local rebuiltModes = {}
    local modeSet = {}
    local function AddMode(mode)
        if mode and not modeSet[mode] and storeManager.components[mode] then
            modeSet[mode] = true
            rebuiltModes[#rebuiltModes + 1] = mode
        end
    end

    if isStableInteraction then
        if includeBuy then
            AddMode(ZO_MODE_STORE_BUY)
        end
        AddMode(ZO_MODE_STORE_STABLE)
        AddMode(ZO_MODE_STORE_REPAIR)
    else
        if includeBuy then
            AddMode(ZO_MODE_STORE_BUY)
        end
        AddMode(ZO_MODE_STORE_SELL)
        AddMode(ZO_MODE_STORE_BUY_BACK)
        AddMode(ZO_MODE_STORE_REPAIR)
    end

    for _, mode in ipairs(componentTable) do
        if isStableInteraction then
            if mode == ZO_MODE_STORE_BUY or mode == ZO_MODE_STORE_REPAIR or mode == ZO_MODE_STORE_STABLE then
                AddMode(mode)
            end
        elseif mode ~= ZO_MODE_STORE_STABLE then
            AddMode(mode)
        end
    end

    storeManager:SetActiveComponents(rebuiltModes)
end

local function GetActiveTabs()
    local activeModeSet = GetNativeActiveModeSet()
    local sourceTabs = isStableInteraction and STABLE_TABS or VENDOR_TABS
    local tabs = {}
    for _, tab in ipairs(sourceTabs) do
        local nativeMode = ResolveNativeModeForVendorMode(tab.mode)
        if (nativeMode and activeModeSet[nativeMode])
            or (tab.mode == MODE.BUY and Vendor._sessionHasBuyMode == true) then
            tabs[#tabs + 1] = tab
        end
    end
    if #tabs == 0 then
        if isStableInteraction then
            return STABLE_TABS
        end
        return VENDOR_TABS
    end
    return tabs
end

local function OnOpenStore()
    isStableInteraction = false
    Vendor._sessionHasBuyMode = false

    local interactionType = currentInteractionType
    local allowNativeStableFallback = interactionType == nil
    isStableInteraction = isStableInteraction
        or interactionType == INTERACTION_STABLE
        or (allowNativeStableFallback and IsNativeStableModeActive())

    EnsureNativeStoreComponents()
    if not isStableInteraction and allowNativeStableFallback and IsNativeStableModeActive() then
        isStableInteraction = true
        EnsureNativeStoreComponents()
    end

    return GetActiveTabs()
end

local function OnCloseStore()
    isStableInteraction = false
    Vendor._sessionHasBuyMode = false
    storeManager.activeComponents = {}
end

print("[Vendor stable transition]")

do
    storeManager.activeComponents = {
        { mode = ZO_MODE_STORE_BUY },
        { mode = ZO_MODE_STORE_STABLE },
    }
    currentInteractionType = INTERACTION_STABLE
    local stableTabs = OnOpenStore()
    assert_eq(stableTabs[2].mode, MODE.STABLE, "stable open exposes the riding trainer tab set")

    OnCloseStore()
    assert_eq(#storeManager.activeComponents, 0, "closing the stable clears native active components")

    storeManager.activeComponents = {
        { mode = ZO_MODE_STORE_BUY },
        { mode = ZO_MODE_STORE_STABLE },
    }
    currentInteractionType = INTERACTION_VENDOR
    local vendorTabs = OnOpenStore()
    assert_eq(vendorTabs[2].mode, MODE.SELL,
        "normal vendor after stable should restore BUY/SELL instead of reusing the riding trainer tab")
    assert_eq(isStableInteraction, false,
        "normal vendor with stale native stable mode does not re-enter stable interaction")
    assert_eq(IsNativeStableModeActive(), false,
        "normal vendor rebuild strips stale stable mode from native active components")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end