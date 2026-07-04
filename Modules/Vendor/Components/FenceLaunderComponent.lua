--[[
File: Modules/Vendor/Components/FenceLaunderComponent.lua
Purpose: Fence Launder tab component for the Vendor module.
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
Vendor.FenceLaunderComponent = Vendor.FenceLaunderComponent or {}
local FenceLaunder = Vendor.FenceLaunderComponent

-- BUI-CONS-001: focused-row resolution uses BETTERUI.CIM.Utils.SafeGetTargetData.

-- BUI-CONS-008: authorization assert-wrapper unified in Vendor.AuthorizeAction.
local function AuthorizeVendorAction(actionType, bagId, slotIndex, vendorInstance)
    return Vendor.AuthorizeAction(actionType, bagId, slotIndex, vendorInstance)
end

-- One refresh pass calls GetCategories and BuildList back to back, each of
-- which needs the stolen-item scan; the shared per-refresh memoize
-- (BUI-CONS-008) walks the backpack once per frame instead of once per caller.
local GetStolenSlotsCached, invalidateStolenSlots = Vendor.PerRefreshCache(function()
    local slots = {}
    for slotIndex = 0, (GetBagSize(BAG_BACKPACK) or 0) - 1 do
        if IsItemStolen(BAG_BACKPACK, slotIndex) then
            slots[#slots + 1] = slotIndex
        end
    end
    return slots
end)

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:Deactivate(vendorInstance)
    -- Drop the per-frame stolen-slot cache so a stale scan can never be
    -- reused after the tab deactivates.
    invalidateStolenSlots()
end

-- HELPERS

--- Get remaining fence launders and total allowed
---@return number remaining Available launder transactions
---@return number total Maximum launder transactions
---@return number resetTimeSeconds Seconds until transaction reset
local function GetRemainingLaunders()
    if GetFenceLaunderTransactionInfo then
        local totalLaunders, laundersUsed, resetTimeSeconds = GetFenceLaunderTransactionInfo()
        totalLaunders = totalLaunders or 0
        laundersUsed = laundersUsed or 0
        return zo_max(totalLaunders - laundersUsed, 0), totalLaunders, resetTimeSeconds
    end
    return 0, 0, 0
end

--- Get launder cost for an item
---@param bagId number Bag identifier
---@param slotIndex number Slot index within the bag
---@return number cost Launder cost in gold
local function GetLaunderCost(bagId, slotIndex)
    if GetItemLaunderPrice then
        return GetItemLaunderPrice(bagId, slotIndex) or 0
    end
    return 0
end

-- PRIMARY ACTION

---@return string name Localized launder action label
function FenceLaunder:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_LAUNDER"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if launder is affordable and transactions remain
function FenceLaunder:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Must have remaining launders
    local remaining = GetRemainingLaunders()
    if remaining <= 0 then return false end

    -- Must be able to afford
    if ds.bagId == nil or ds.slotIndex == nil then
        return false
    end

    local cost = GetLaunderCost(ds.bagId, ds.slotIndex)
    if not vendorInstance:CanAfford(cost) then
        return false
    end

    local allowed = AuthorizeVendorAction(Vendor.ACTION.FENCE_LAUNDER, ds.bagId, ds.slotIndex, vendorInstance)
    return allowed == true
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:OnPrimaryAction(vendorInstance)
    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    if bagId == nil or slotIndex == nil then return end

    local canLaunder, denyReason = AuthorizeVendorAction(Vendor.ACTION.FENCE_LAUNDER, bagId, slotIndex, vendorInstance)
    if canLaunder ~= true then
        local deny = BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy and BETTERUI.CIM.ProtectionPolicy.DENY
        if denyReason == (deny and deny.CANNOT_AFFORD) then
            BETTERUI.CIM.UserAlertText("FenceLaunder:CannotAfford",
                GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        end
        return
    end

    -- Re-check remaining launders
    local remaining = GetRemainingLaunders()
    if remaining <= 0 then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK,
            GetString("SI_ITEMLAUNDERRESULT", ITEM_LAUNDER_RESULT_AT_LIMIT))
        return
    end

    -- Validate the slot still has items
    local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
    if stackSize <= 0 then return end

    -- Each item consumes one launder transaction; clamp the stack like ZOS
    -- does (fencewindowlaunder_gamepad.lua spinnerMax).
    local quantity = zo_min(stackSize, remaining)

    -- Re-check affordability for the clamped quantity. GetItemLaunderPrice is
    -- the per-unit price (ZOS passes it as the spinner unit price).
    local cost = GetLaunderCost(bagId, slotIndex) * quantity
    if not vendorInstance:CanAfford(cost) then
        BETTERUI.CIM.UserAlertText("FenceLaunder:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    local L = BETTERUI.Log
    local traceData = {
        module = "Vendor",
        scene = BETTERUI_VENDOR_SCENE_NAME,
        feature = "vendor-fence-launder",
        fn = "Vendor.FenceLaunderComponent.OnPrimaryAction",
        ["function"] = "Vendor.FenceLaunderComponent.OnPrimaryAction",
        mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
        bagId = bagId,
        slotIndex = slotIndex,
        quantity = quantity,
        expectedPrice = cost,
        cost = cost,
        currencyType = rawget(_G, "CURT_MONEY"),
        item = L and L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name,
    }
    Vendor.DispatchTracedAction("vendor.fence_launder", traceData, function()
        LaunderItem(bagId, slotIndex, quantity)
    end)
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil

    -- Only stolen items are listed; the per-frame scan is shared with
    -- GetCategories so the backpack is walked once per refresh.
    for _, slotIndex in ipairs(GetStolenSlotsCached()) do
        local icon, stackCount = GetItemInfo(BAG_BACKPACK, slotIndex)
        local name = GetItemName(BAG_BACKPACK, slotIndex)

        if name and name ~= ""
            and (not Vendor.MatchesSearchQuery or Vendor.MatchesSearchQuery(searchQuery, name))
        then
            name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
            local quality = GetItemDisplayQuality(BAG_BACKPACK, slotIndex)
                or ITEM_DISPLAY_QUALITY_NORMAL
            local launderCost = GetLaunderCost(BAG_BACKPACK, slotIndex)

            local entryData = {
                name             = name,
                icon             = icon,
                stackCount       = stackCount or 1,
                launderCost      = launderCost,
                quality          = quality,
                bagId            = BAG_BACKPACK,
                slotIndex        = slotIndex,
                stolen           = true,
                itemLink         = GetItemLink(BAG_BACKPACK, slotIndex),
                bestGamepadItemCategoryName = "",
                statValue        = "",
            }

            Vendor.AddItemRow(list, entryData)
        end
    end
end

-- FOOTER INFO

--- Returns footer text showing remaining launders and reset timer
---@return string text Formatted text showing remaining launders and timer
function FenceLaunder:GetFooterText()
    local remaining, total, resetTimeSeconds = GetRemainingLaunders()
    local text = zo_strformat(SI_BETTERUI_FENCE_LAUNDERS_REMAINING, remaining, total)

    if resetTimeSeconds and resetTimeSeconds > 0 then
        local timeStr = ZO_FormatCountdownTimer(resetTimeSeconds)
        if timeStr then
            text = text .. " (" .. timeStr .. ")"
        end
    end

    return text
end

-- CATEGORIES


--- Returns the single "Stolen" category tab for the fence launder list.
--- All items eligible for laundering are stolen, so no other categories are needed.
---@return table categories Single-entry category list
function FenceLaunder:GetCategories(_vendorInstance)
    return {
        {
            key      = "all",
            name     = GetString(SI_BETTERUI_STOLEN),
            iconFile = "EsoUI/Art/Inventory/inventory_stolenItem_icon.dds",
            itemCount = #GetStolenSlotsCached(),
        }
    }
end
