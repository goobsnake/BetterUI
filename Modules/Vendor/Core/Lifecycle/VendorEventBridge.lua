--[[
File: Modules/Vendor/Core/Lifecycle/VendorEventBridge.lua
Purpose: Centralize vendor event registration so Vendor.lua owns handlers, not registration plumbing.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.EventBridge = Vendor.EventBridge or {}
local EventBridge = Vendor.EventBridge

local function RegisterEvent(eventManager, eventNamespace, suffix, eventCode, callback)
    if not eventCode or type(callback) ~= "function" then
        return
    end
    eventManager:RegisterForEvent(eventNamespace .. "_" .. suffix, eventCode, callback)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = suffix })
    end
end

---@param eventManager table|nil
---@param eventNamespace string
---@param handlers table
---@return nil
function EventBridge.Register(eventManager, eventNamespace, handlers)
    if not eventManager then
        return
    end

    RegisterEvent(eventManager, eventNamespace, "StableStart", rawget(_G, "EVENT_STABLE_INTERACT_START"), handlers.onStableInteractStart)
    RegisterEvent(eventManager, eventNamespace, "StableEnd", rawget(_G, "EVENT_STABLE_INTERACT_END"), handlers.onStableInteractEnd)
    RegisterEvent(eventManager, eventNamespace, "StableMountInfo", rawget(_G, "EVENT_MOUNT_INFO_UPDATED"), handlers.onStableInfoUpdated or handlers.onInventoryUpdated)

    RegisterEvent(eventManager, eventNamespace, "Open", EVENT_OPEN_STORE, handlers.onOpenStore)
    RegisterEvent(eventManager, eventNamespace, "OpenFence", EVENT_OPEN_FENCE, handlers.onOpenFence)
    RegisterEvent(eventManager, eventNamespace, "Close", EVENT_CLOSE_STORE, handlers.onCloseStore)
    RegisterEvent(eventManager, eventNamespace, "InvUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "InvFull", EVENT_INVENTORY_FULL_UPDATE, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "SellReceipt", EVENT_SELL_RECEIPT, handlers.onSellReceipt)
    RegisterEvent(eventManager, eventNamespace, "BuyReceipt", EVENT_BUY_RECEIPT, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "BuybackReceipt", EVENT_BUYBACK_RECEIPT, handlers.onInventoryUpdated)
    -- Repair failure: alert the player (native FailedRepairMessageBox parity)
    -- and still refresh; fall back to a silent refresh when no alert handler.
    RegisterEvent(eventManager, eventNamespace, "RepairItem", EVENT_ITEM_REPAIR_FAILURE, handlers.onRepairFailure or handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "ItemLaunder", EVENT_ITEM_LAUNDER_RESULT, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "FenceUpdate", EVENT_JUSTICE_FENCE_UPDATE, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "MoneyUpdate", EVENT_MONEY_UPDATE, handlers.onMoneyUpdated)
    RegisterEvent(eventManager, eventNamespace, "CurrencyUpdate", rawget(_G, "EVENT_CURRENCY_UPDATE"), handlers.onMoneyUpdated)
    -- Staleness triggers also wired by native ZO_GamepadStoreManager: a newly
    -- acquired antiquity lead or a collection update can change store entries
    -- (e.g. already-owned collectibles), so route both to the inventory refresh.
    RegisterEvent(eventManager, eventNamespace, "AntiquityLead", rawget(_G, "EVENT_ANTIQUITY_LEAD_ACQUIRED"), handlers.onInventoryUpdated)

    EventBridge.RegisterCollectionUpdated(handlers.onInventoryUpdated)

    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "vendor events registered", { namespace = eventNamespace })
    end
end

--- Register (idempotently) a ZO_COLLECTIBLE_DATA_MANAGER "OnCollectionUpdated"
--- callback routed to the inventory-updated refresh. Registered once for the
--- addon lifetime (mirroring native), never unregistered; the _collectionCallback-
--- Registered guard makes repeated calls no-ops. Guarded because the manager may
--- not exist in every load context / test harness.
---@param onInventoryUpdated function|nil
---@return nil
function EventBridge.RegisterCollectionUpdated(onInventoryUpdated)
    local manager = rawget(_G, "ZO_COLLECTIBLE_DATA_MANAGER")
    if type(onInventoryUpdated) ~= "function"
        or not manager
        or type(manager.RegisterCallback) ~= "function"
        or EventBridge._collectionCallbackRegistered then
        return
    end
    EventBridge._collectionCallback = function() onInventoryUpdated() end
    manager:RegisterCallback("OnCollectionUpdated", EventBridge._collectionCallback)
    EventBridge._collectionCallbackRegistered = true
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = "OnCollectionUpdated" })
    end
end
