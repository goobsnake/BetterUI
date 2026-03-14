--[[
File: Modules/Vendor/Module.lua
Purpose: Vendor/store enhancements module scaffold for BetterUI.
         Provides namespace initialization and scene interception
         for the gamepad store UI.

ECO-002: Vendor enhancements with sorting, price context, batch junk sell.

This scaffold establishes:
- BETTERUI.Vendor namespace
- Scene interception for gamepad_store
- Foundation for enhanced sorting, price context, and batch sell UX
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}

local Vendor = BETTERUI.Vendor

-- Scene configuration
Vendor.SCENE_NAME = "BETTERUI_VENDOR"

--- Module setup function — called from BetterUI main initialization.
--- Registers namespace and store interaction hook.
function Vendor.Setup()
    -- Register for store interaction events
    if EVENT_MANAGER then
        EVENT_MANAGER:RegisterForEvent("BetterUI_Vendor",
            EVENT_OPEN_STORE, function()
                Vendor.storeOpen = true
            end)

        EVENT_MANAGER:RegisterForEvent("BetterUI_Vendor_Close",
            EVENT_CLOSE_STORE, function()
                Vendor.storeOpen = false
            end)
    end

    Vendor.initialized = true
end

--- Check if the Vendor module has been initialized.
--- @return boolean initialized
function Vendor.IsInitialized()
    return Vendor.initialized == true
end

--- Placeholder: Check if a store is currently open.
--- @return boolean isOpen
function Vendor.IsStoreOpen()
    return Vendor.storeOpen == true
end

--- Placeholder: Gets junk sell value summary for batch sell UX.
--- @return number totalValue Total gold value of all junk items
--- @return number itemCount Number of junk items
function Vendor.GetJunkSellSummary()
    local totalValue = 0
    local itemCount = 0

    local bagSize = GetBagSize(BAG_BACKPACK) or 0
    for slotIndex = 0, bagSize - 1 do
        if IsItemJunk(BAG_BACKPACK, slotIndex) then
            local sellPrice = GetItemSellValueWithBonuses(BAG_BACKPACK, slotIndex) or 0
            local stackCount = GetSlotStackSize(BAG_BACKPACK, slotIndex) or 1
            totalValue = totalValue + (sellPrice * stackCount)
            itemCount = itemCount + 1
        end
    end

    return totalValue, itemCount
end
