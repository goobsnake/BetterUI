--[[
File: tools/tests/test_vendor_authorization_surface_source.lua
Purpose: Behavior-first regression checks for the shared vendor authorization
         seam across primary and batch sell/launder flows.

Usage:
  lua tools/tests/test_vendor_authorization_surface_source.lua
]]

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function assert_eq(actual, expected, label)
    assert_true(actual == expected, string.format("%s (expected=%s, actual=%s)", label, tostring(expected), tostring(actual)))
end

local function slot_key(bagId, slotIndex)
    return tostring(bagId) .. ":" .. tostring(slotIndex)
end

local slot_state = {}
local sold_items = {}
local laundered_items = {}
local shown_dialogs = {}
local user_alerts = {}

local function set_slot(bagId, slotIndex, state)
    slot_state[slot_key(bagId, slotIndex)] = state or {}
end

local function get_slot(bagId, slotIndex)
    return slot_state[slot_key(bagId, slotIndex)] or {}
end

local function reset_runtime_state()
    slot_state = {}
    sold_items = {}
    laundered_items = {}
    shown_dialogs = {}
    user_alerts = {}
end

local function merge_into(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            local node = target[key]
            if type(node) ~= "table" then
                node = {}
                target[key] = node
            end
            merge_into(node, value)
        else
            target[key] = value
        end
    end
end

BAG_BACKPACK = 1
BAG_VENGEANCE = 2
ITEM_FUNCTIONAL_QUALITY_ARTIFACT = 5
CURT_NONE = 0
CURT_MONEY = 1
SI_ITEM_ACTION_SELL = "SI_ITEM_ACTION_SELL"
SI_ITEM_ACTION_LAUNDER = "SI_ITEM_ACTION_LAUNDER"
SI_ITEM_ACTION_BUY = "SI_ITEM_ACTION_BUY"
SI_ITEM_ACTION_BUYBACK = "SI_ITEM_ACTION_BUYBACK"
SI_BETTERUI_VENDOR_CANNOT_AFFORD = "SI_BETTERUI_VENDOR_CANNOT_AFFORD"
ZO_VENGEANCE_BAG_SELL_ENABLED = true

function GetString(value)
    return tostring(value)
end

function zo_max(left, right)
    if left > right then
        return left
    end
    return right
end

function IsCurrentCampaignVengeanceRuleset()
    return true
end

function GetSlotStackSize(bagId, slotIndex)
    local slot = get_slot(bagId, slotIndex)
    return slot.stackSize or 0
end

function GetItemSellValueWithBonuses(bagId, slotIndex)
    local slot = get_slot(bagId, slotIndex)
    return slot.sellPrice or 0
end

function GetItemInfo(bagId, slotIndex)
    local slot = get_slot(bagId, slotIndex)
    return slot.iconFile or "icon.dds", slot.stackSize or 0, slot.sellPrice or 0
end

function GetItemLaunderPrice(bagId, slotIndex)
    local slot = get_slot(bagId, slotIndex)
    return slot.launderCost or 0
end

function IsItemStolen(bagId, slotIndex)
    local slot = get_slot(bagId, slotIndex)
    return slot.stolen == true
end

function IsItemJunk(bagId, slotIndex)
    local slot = get_slot(bagId, slotIndex)
    return slot.junk == true
end

function IsItemPlayerLocked(bagId, slotIndex)
    local slot = get_slot(bagId, slotIndex)
    return slot.playerLocked == true
end

function GetItemFunctionalQuality(bagId, slotIndex)
    local slot = get_slot(bagId, slotIndex)
    return slot.functionalQuality
end

function SellInventoryItem(bagId, slotIndex, stackSize)
    sold_items[#sold_items + 1] = {
        bagId = bagId,
        slotIndex = slotIndex,
        stackSize = stackSize,
    }
end

function LaunderItem(bagId, slotIndex, stackSize)
    laundered_items[#laundered_items + 1] = {
        bagId = bagId,
        slotIndex = slotIndex,
        stackSize = stackSize,
    }
end

function ZO_Dialogs_ShowGamepadDialog(dialogName, payload)
    shown_dialogs[#shown_dialogs + 1] = {
        name = dialogName,
        payload = payload,
    }
end

local fence_sell_total = 20
local fence_sell_used = 0
local fence_launder_total = 20
local fence_launder_used = 0

function GetFenceSellTransactionInfo()
    return fence_sell_total, fence_sell_used, 0
end

function GetFenceLaunderTransactionInfo()
    return fence_launder_total, fence_launder_used, 0
end

BETTERUI = {
    Vendor = {},
    CIM = {
        ARCHETYPES = {
            RUNTIME_COORDINATOR = "runtime-coordinator",
            THIN_ENTRYPOINT = "thin-entrypoint",
            SETTINGS_OWNER = "settings-owner",
        },
        ItemTaxonomy = {
            VENDOR_SELL_CATEGORY_DEFS = {
                {
                    key = "all",
                    nameStringId = "SI_BETTERUI_INV_ITEM_ALL",
                },
            },
        },
        ApplyModuleSharedSettingsStatics = function(moduleNamespace)
            moduleNamespace.GetSetting = moduleNamespace.GetSetting or function()
                return true
            end
        end,
        InitModuleDefaults = function(_, moduleOptions, defaults, fallbackDefaults)
            local resolved = moduleOptions or {}
            if type(defaults) == "table" then
                for key, value in pairs(defaults) do
                    if resolved[key] == nil then
                        resolved[key] = value
                    end
                end
            end
            if type(fallbackDefaults) == "table" then
                for key, value in pairs(fallbackDefaults) do
                    if resolved[key] == nil then
                        resolved[key] = value
                    end
                end
            end
            return resolved
        end,
        UserAlertText = function(context, message)
            user_alerts[#user_alerts + 1] = {
                context = context,
                message = message,
            }
        end,
    },
}

BETTERUI.CIM.BatchConfig = {
    HasItemAtSlot = function(bagId, slotIndex)
        local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
        return (stackCount or 0) > 0
    end,
    WithServer = function(config)
        return { server = config }
    end,
    WithAck = function(config)
        return { ack = config }
    end,
    WithPacing = function(config)
        return { pacing = config }
    end,
    ComposeBatchOptions = function(...)
        local resolved = {}
        for i = 1, select("#", ...) do
            local options = select(i, ...)
            if type(options) == "table" then
                merge_into(resolved, options)
            end
        end
        return resolved
    end,
    NormalizeBatchOptions = function(options)
        return options or {}
    end,
    BatchStepHandled = function()
        return "handled"
    end,
    BatchStepQueued = function()
        return "queued"
    end,
    BatchStepSkipped = function()
        return "skipped"
    end,
    ResolveBatchThrottleProfile = function()
        return {
            DELAY_MS = 100,
            SHOW_PROGRESS = false,
        }
    end,
    ResolveBatchAbortBindingMarkup = function()
        return "X"
    end,
    GetNowMs = function()
        return 0
    end,
    SERVER_RATE_WINDOW_MS = 1000,
    RecordServerAction = function() end,
}

dofile("Modules/Vendor/Module.lua")
dofile("Modules/CIM/Actions/ProtectionPolicy.lua")

-- BUI-CONS-001/008: shared helpers the migrated components + batch runtime now
-- call. Defined before the component dofiles because the fence/vengeance
-- components bind Vendor.PerRefreshCache at load. Mirror VendorModePolicy/CIM.
BETTERUI.CIM.Utils = BETTERUI.CIM.Utils or {}
BETTERUI.CIM.Utils.SafeGetTargetData = BETTERUI.CIM.Utils.SafeGetTargetData or function(list)
    if not list then return nil end
    if list.GetTargetData then return list:GetTargetData() end
    if list.GetSelectedData then return list:GetSelectedData() end
    if list.targetData ~= nil then return list.targetData end
    return list.selectedData
end
BETTERUI.Vendor.AuthorizeAction = BETTERUI.Vendor.AuthorizeAction or function(actionType, bagId, slotIndex, vendorInstance)
    local f = BETTERUI.Vendor.AuthorizeInventoryAction
    assert(type(f) == "function", "Vendor.AuthorizeInventoryAction must load")
    local allowed, reason = f(actionType, bagId, slotIndex, vendorInstance)
    return allowed == true, reason
end
BETTERUI.Vendor.IsAtGoldCap = BETTERUI.Vendor.IsAtGoldCap or function()
    if type(GetMaxPossibleCurrency) ~= "function" then return false end
    local carried = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    local maxPossible = GetMaxPossibleCurrency(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    return maxPossible > 0 and carried >= maxPossible
end
BETTERUI.Vendor.DispatchTracedAction = BETTERUI.Vendor.DispatchTracedAction or function(event, traceData, fn)
    local V = BETTERUI.Vendor
    local goldBefore = V.TraceActionRequested and V.TraceActionRequested(event, traceData) or nil
    fn()
    if V.ScheduleActionSettled then V.ScheduleActionSettled(event, traceData, goldBefore) end
end
BETTERUI.Vendor.IsSellVengeanceModeAvailable = BETTERUI.Vendor.IsSellVengeanceModeAvailable or function()
    return rawget(_G, "BAG_VENGEANCE") ~= nil
        and rawget(_G, "ZO_VENGEANCE_BAG_SELL_ENABLED") == true
        and type(IsCurrentCampaignVengeanceRuleset) == "function"
        and IsCurrentCampaignVengeanceRuleset()
end
BETTERUI.Vendor.PerRefreshCache = BETTERUI.Vendor.PerRefreshCache or function(computeFn)
    local cachedValue, cachedFrameMs
    local function invalidate() cachedValue, cachedFrameMs = nil, nil end
    local function get(...)
        local frameMs = (type(GetFrameTimeMilliseconds) == "function") and GetFrameTimeMilliseconds() or nil
        if frameMs and cachedValue ~= nil and cachedFrameMs == frameMs then return cachedValue end
        local value = computeFn(...)
        if frameMs then cachedValue, cachedFrameMs = value, frameMs else cachedValue, cachedFrameMs = nil, nil end
        return value
    end
    return get, invalidate
end

dofile("Modules/Vendor/Components/SellComponent.lua")
dofile("Modules/Vendor/Components/FenceSellComponent.lua")
dofile("Modules/Vendor/Components/FenceLaunderComponent.lua")
dofile("Modules/Vendor/Components/SellVengeanceComponent.lua")
dofile("Modules/Vendor/Core/VendorBatchRuntime.lua")

assert_eq(BETTERUI.Vendor.ResolveActionId("SELL"), "vendor_sell",
    "Vendor module resolves SELL action through canonical action-id helpers")
assert_eq(BETTERUI.Vendor.ResolveActionId("FENCE_LAUNDER"), "fence_launder",
    "Vendor module resolves FENCE_LAUNDER action through canonical action-id helpers")

local function make_vendor_instance(slotData, canAfford)
    return {
        list = {
            GetSelectedData = function()
                return {
                    dataSource = slotData,
                }
            end,
        },
        CanAfford = function(_, cost)
            if type(canAfford) == "function" then
                return canAfford(cost)
            end
            return canAfford ~= false
        end,
        RefreshList = function() end,
        SuppressListUpdates = function() end,
        FlushListUpdates = function() end,
    }
end

do
    reset_runtime_state()
    set_slot(BAG_BACKPACK, 5, {
        stackSize = 1,
        sellPrice = 42,
        stolen = false,
    })

    local canAffordProbe = nil
    local allow, reason = BETTERUI.Vendor.AuthorizeInventoryAction(BETTERUI.Vendor.ACTION.SELL, BAG_BACKPACK, 5, {
        CanAfford = function(_, cost)
            canAffordProbe = cost
            return cost == 123
        end,
    })
    assert_true(allow == true and reason == nil,
        "Vendor.AuthorizeInventoryAction allows SELL for valid non-stolen sellable slots")

    local contextAllowed = BETTERUI.CIM.ProtectionPolicy.CanVendorAction(BETTERUI.Vendor.ACTION.SELL, BAG_BACKPACK, 5, {
        canAfford = function(cost)
            return cost == 123
        end,
    })
    assert_true(contextAllowed == true,
        "ProtectionPolicy.CanVendorAction accepts the Vendor affordability context contract")
    assert_eq(canAffordProbe, nil,
        "Vendor affordability callback remains lazy and is only invoked when policy asks for it")

    set_slot(BAG_BACKPACK, 6, {
        stackSize = 1,
        sellPrice = 99,
        stolen = true,
    })
    local denied, denyReason = BETTERUI.Vendor.AuthorizeInventoryAction(BETTERUI.Vendor.ACTION.SELL, BAG_BACKPACK, 6, nil)
    assert_true(denied == false and denyReason == BETTERUI.CIM.ProtectionPolicy.DENY.STOLEN,
        "Vendor authorization seam preserves explicit policy deny reason for stolen SELL actions")

    -- Player-locked items must be denied for the regular sell flows only:
    -- native GetSellItems/GetSellVengeanceItems filter on isPlayerLocked,
    -- while GetStolenSellItems/GetLaunderItems (fence lists) do not.
    set_slot(BAG_BACKPACK, 7, {
        stackSize = 1,
        sellPrice = 30,
        stolen = false,
        junk = true,
        playerLocked = true,
    })
    set_slot(BAG_BACKPACK, 8, {
        stackSize = 1,
        sellPrice = 30,
        stolen = true,
        launderCost = 5,
        playerLocked = true,
    })
    local lockedSellActions = { "SELL", "SELL_JUNK", "SELL_VENGEANCE" }
    for _, actionKey in ipairs(lockedSellActions) do
        local lockedAllowed, lockedReason = BETTERUI.CIM.ProtectionPolicy.CanVendorAction(
            BETTERUI.Vendor.ResolveActionId(actionKey), BAG_BACKPACK, 7, nil)
        assert_true(lockedAllowed == false and lockedReason == BETTERUI.CIM.ProtectionPolicy.DENY.PLAYER_LOCKED,
            "ProtectionPolicy.CanVendorAction denies player-locked items for " .. actionKey)
    end
    local lockedFenceActions = { "FENCE_SELL", "FENCE_LAUNDER" }
    for _, actionKey in ipairs(lockedFenceActions) do
        local lockedAllowed, lockedReason = BETTERUI.CIM.ProtectionPolicy.CanVendorAction(
            BETTERUI.Vendor.ResolveActionId(actionKey), BAG_BACKPACK, 8, nil)
        assert_true(lockedAllowed == true and lockedReason == nil,
            "ProtectionPolicy.CanVendorAction allows player-locked stolen items for " .. actionKey
                .. " (native fence lists do not filter locked items)")
    end

    local savedPolicy = BETTERUI.CIM.ProtectionPolicy
    local missingPolicyOk, missingPolicyErr = pcall(function()
        BETTERUI.CIM.ProtectionPolicy = nil
        BETTERUI.Vendor.AuthorizeInventoryAction(BETTERUI.Vendor.ACTION.SELL, BAG_BACKPACK, 5, nil)
    end)
    BETTERUI.CIM.ProtectionPolicy = savedPolicy
    assert_true(missingPolicyOk == false
            and type(missingPolicyErr) == "string"
            and string.find(missingPolicyErr, "CIM.ProtectionPolicy must load before Vendor.AuthorizeInventoryAction", 1, true) ~= nil,
        "Vendor authorization seam fails closed when CIM.ProtectionPolicy is missing")

    local savedMethod = BETTERUI.CIM.ProtectionPolicy.CanVendorAction
    local missingMethodOk, missingMethodErr = pcall(function()
        BETTERUI.CIM.ProtectionPolicy.CanVendorAction = nil
        BETTERUI.Vendor.AuthorizeInventoryAction(BETTERUI.Vendor.ACTION.SELL, BAG_BACKPACK, 5, nil)
    end)
    BETTERUI.CIM.ProtectionPolicy.CanVendorAction = savedMethod
    assert_true(missingMethodOk == false
            and type(missingMethodErr) == "string"
            and string.find(missingMethodErr, "CIM.ProtectionPolicy.CanVendorAction must load", 1, true) ~= nil,
        "Vendor authorization seam fails closed when CanVendorAction is missing")
end

do
    reset_runtime_state()
    set_slot(BAG_BACKPACK, 1, {
        stackSize = 2,
        sellPrice = 40,
        stolen = false,
    })
    set_slot(BAG_BACKPACK, 2, {
        stackSize = 3,
        sellPrice = 80,
        stolen = true,
        launderCost = 20,
    })
    set_slot(BAG_VENGEANCE, 3, {
        stackSize = 1,
        sellPrice = 120,
        stolen = false,
    })

    local authorization_calls = {}
    local original_authorize = BETTERUI.Vendor.AuthorizeInventoryAction
    BETTERUI.Vendor.AuthorizeInventoryAction = function(actionType, bagId, slotIndex, vendorInstance)
        authorization_calls[#authorization_calls + 1] = {
            actionType = actionType,
            bagId = bagId,
            slotIndex = slotIndex,
            vendorInstance = vendorInstance,
        }
        return false, "blocked"
    end

    local sellVendor = make_vendor_instance({
        bagId = BAG_BACKPACK,
        slotIndex = 1,
        sellPrice = 40,
        stackSellPrice = 40,
    }, true)
    assert_true(BETTERUI.Vendor.SellComponent:IsPrimaryActionEnabled(sellVendor) == false,
        "SellComponent:IsPrimaryActionEnabled denies actions unless shared authorization explicitly allows")
    BETTERUI.Vendor.SellComponent:OnPrimaryAction(sellVendor)
    assert_eq(#sold_items, 0, "SellComponent:OnPrimaryAction blocks sell execution when authorization denies")
    assert_eq(authorization_calls[1].actionType, BETTERUI.Vendor.ACTION.SELL,
        "SellComponent routes primary action through Vendor.AuthorizeInventoryAction")

    local fenceSellVendor = make_vendor_instance({
        bagId = BAG_BACKPACK,
        slotIndex = 2,
        sellPrice = 80,
    }, true)
    assert_true(BETTERUI.Vendor.FenceSellComponent:IsPrimaryActionEnabled(fenceSellVendor) == false,
        "FenceSellComponent:IsPrimaryActionEnabled denies actions unless shared authorization explicitly allows")
    BETTERUI.Vendor.FenceSellComponent:OnPrimaryAction(fenceSellVendor)
    assert_eq(#sold_items, 0, "FenceSellComponent:OnPrimaryAction blocks sell execution when authorization denies")
    assert_eq(authorization_calls[3].actionType, BETTERUI.Vendor.ACTION.FENCE_SELL,
        "FenceSellComponent routes primary action through Vendor.AuthorizeInventoryAction")

    local fenceLaunderVendor = make_vendor_instance({
        bagId = BAG_BACKPACK,
        slotIndex = 2,
        launderCost = 20,
    }, true)
    assert_true(BETTERUI.Vendor.FenceLaunderComponent:IsPrimaryActionEnabled(fenceLaunderVendor) == false,
        "FenceLaunderComponent:IsPrimaryActionEnabled denies actions unless shared authorization explicitly allows")
    BETTERUI.Vendor.FenceLaunderComponent:OnPrimaryAction(fenceLaunderVendor)
    assert_eq(#laundered_items, 0, "FenceLaunderComponent:OnPrimaryAction blocks laundering when authorization denies")
    assert_eq(authorization_calls[5].actionType, BETTERUI.Vendor.ACTION.FENCE_LAUNDER,
        "FenceLaunderComponent routes primary action through Vendor.AuthorizeInventoryAction")

    local vengeanceVendor = make_vendor_instance({
        bagId = BAG_VENGEANCE,
        slotIndex = 3,
        sellPrice = 120,
    }, true)
    assert_true(BETTERUI.Vendor.SellVengeanceComponent:IsPrimaryActionEnabled(vengeanceVendor) == false,
        "SellVengeanceComponent:IsPrimaryActionEnabled denies actions unless shared authorization explicitly allows")
    BETTERUI.Vendor.SellVengeanceComponent:OnPrimaryAction(vengeanceVendor)
    assert_eq(#sold_items, 0, "SellVengeanceComponent:OnPrimaryAction blocks sell execution when authorization denies")
    assert_eq(authorization_calls[7].actionType, BETTERUI.Vendor.ACTION.SELL_VENGEANCE,
        "SellVengeanceComponent routes primary action through Vendor.AuthorizeInventoryAction")

    BETTERUI.Vendor.AuthorizeInventoryAction = original_authorize
end

do
    reset_runtime_state()
    set_slot(BAG_BACKPACK, 10, {
        stackSize = 2,
        sellPrice = 30,
        stolen = false,
    })
    set_slot(BAG_BACKPACK, 11, {
        stackSize = 1,
        sellPrice = 20,
        stolen = true,
        launderCost = 15,
    })
    set_slot(BAG_BACKPACK, 13, {
        stackSize = 4,
        sellPrice = 50,
        stolen = true,
        launderCost = 15,
    })

    local original_authorize = BETTERUI.Vendor.AuthorizeInventoryAction
    local authorization_calls = {}
    BETTERUI.Vendor.AuthorizeInventoryAction = function(actionType, bagId, slotIndex, vendorInstance)
        authorization_calls[#authorization_calls + 1] = {
            actionType = actionType,
            bagId = bagId,
            slotIndex = slotIndex,
            vendorInstance = vendorInstance,
        }
        if slotIndex == 13 then
            return false, BETTERUI.CIM.ProtectionPolicy.DENY.ARTIFACT
        end
        return true, nil
    end

    local vendorInstance = make_vendor_instance({
        bagId = BAG_BACKPACK,
        slotIndex = 10,
        sellPrice = 30,
    }, true)
    BETTERUI.Vendor.instance = vendorInstance

    BETTERUI.Vendor.SellComponent:OnPrimaryAction(vendorInstance)
    assert_eq(#sold_items, 1, "SellComponent sells when shared authorization allows the slot")
    assert_eq(sold_items[1].slotIndex, 10, "SellComponent sells the selected slot")

    local fenceSellVendor = make_vendor_instance({
        bagId = BAG_BACKPACK,
        slotIndex = 13,
        sellPrice = 50,
    }, true)
    BETTERUI.Vendor.FenceSellComponent:OnPrimaryAction(fenceSellVendor)
    assert_eq(#shown_dialogs, 1,
        "FenceSellComponent surfaces explicit artifact deny reasons through the native fence dialog")
    assert_eq(#sold_items, 1, "FenceSellComponent does not sell when shared authorization denies")

    local fenceLaunderVendor = make_vendor_instance({
        bagId = BAG_BACKPACK,
        slotIndex = 13,
        launderCost = 15,
    }, true)
    BETTERUI.Vendor.FenceLaunderComponent:OnPrimaryAction(fenceLaunderVendor)
    assert_eq(#laundered_items, 0, "FenceLaunderComponent does not launder when shared authorization denies")

    local sellBatchResult = BETTERUI.Vendor.BatchRuntime.ExecuteBatchAction(BETTERUI.Vendor.MODE.SELL, {
        bagId = BAG_BACKPACK,
        slotIndex = 10,
    })
    assert_eq(sellBatchResult, "queued", "VendorBatchRuntime queues SELL actions when shared authorization allows")

    local vengeanceBatchResult = BETTERUI.Vendor.BatchRuntime.ExecuteBatchAction(BETTERUI.Vendor.MODE.SELL_VENGEANCE, {
        bagId = BAG_BACKPACK,
        slotIndex = 10,
    })
    assert_eq(vengeanceBatchResult, "queued",
        "VendorBatchRuntime queues SELL_VENGEANCE actions when shared authorization allows")
    assert_eq(authorization_calls[#authorization_calls].actionType, BETTERUI.Vendor.ACTION.SELL_VENGEANCE,
        "VendorBatchRuntime routes SELL_VENGEANCE through the dedicated authorization action")

    local deniedBatchResult = BETTERUI.Vendor.BatchRuntime.ExecuteBatchAction(BETTERUI.Vendor.MODE.FENCE_SELL, {
        bagId = BAG_BACKPACK,
        slotIndex = 13,
    })
    assert_eq(deniedBatchResult, "skipped",
        "VendorBatchRuntime skips FENCE_SELL actions when shared authorization denies")

    local launderBatchResult = BETTERUI.Vendor.BatchRuntime.ExecuteBatchAction(BETTERUI.Vendor.MODE.FENCE_LAUNDER, {
        bagId = BAG_BACKPACK,
        slotIndex = 11,
    })
    assert_eq(launderBatchResult, "queued",
        "VendorBatchRuntime queues FENCE_LAUNDER actions when shared authorization allows")

    assert_true(#authorization_calls >= 6,
        "primary and batch vendor flows both route through the shared authorization seam")

    BETTERUI.Vendor.AuthorizeInventoryAction = original_authorize
end

if failed > 0 then
    error(string.format("test_vendor_authorization_surface_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_vendor_authorization_surface_source.lua: %d passed", passed))
