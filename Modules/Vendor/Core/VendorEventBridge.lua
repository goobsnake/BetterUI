--[[
File: Modules/Vendor/Core/VendorEventBridge.lua
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

    RegisterEvent(eventManager, eventNamespace, "Open", EVENT_OPEN_STORE, handlers.onOpenStore)
    RegisterEvent(eventManager, eventNamespace, "OpenFence", EVENT_OPEN_FENCE, handlers.onOpenFence)
    RegisterEvent(eventManager, eventNamespace, "Close", EVENT_CLOSE_STORE, handlers.onCloseStore)
    RegisterEvent(eventManager, eventNamespace, "InvUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "InvFull", EVENT_INVENTORY_FULL_UPDATE, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "SellReceipt", EVENT_SELL_RECEIPT, handlers.onSellReceipt)
    RegisterEvent(eventManager, eventNamespace, "BuyReceipt", EVENT_BUY_RECEIPT, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "BuybackReceipt", EVENT_BUYBACK_RECEIPT, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "RepairItem", EVENT_ITEM_REPAIR_ALREADY_APPLIED_CONFIRMATION, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "ItemLaunder", EVENT_ITEM_LAUNDER_RESULT, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "FenceUpdate", EVENT_JUSTICE_FENCE_UPDATE, handlers.onInventoryUpdated)
    RegisterEvent(eventManager, eventNamespace, "MoneyUpdate", EVENT_MONEY_UPDATE, handlers.onMoneyUpdated)
    RegisterEvent(eventManager, eventNamespace, "CurrencyUpdate", rawget(_G, "EVENT_CURRENCY_UPDATE"), handlers.onMoneyUpdated)
end
