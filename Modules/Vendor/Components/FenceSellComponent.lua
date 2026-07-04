--[[
File: Modules/Vendor/Components/FenceSellComponent.lua
Purpose: Fence Sell Stolen tab component for the Vendor module.
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
Vendor.FenceSellComponent = Vendor.FenceSellComponent or {}
local FenceSell = Vendor.FenceSellComponent

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
function FenceSell:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceSell:Deactivate(vendorInstance)
    -- Drop the per-frame stolen-slot cache so a stale scan can never be
    -- reused after the tab deactivates.
    invalidateStolenSlots()
end

-- HELPERS

--- Get remaining fence sells and total allowed
---@return number remaining Available sell transactions
---@return number total Maximum sell transactions
---@return number resetTimeSeconds Seconds until transaction reset
local function GetRemainingSells()
    if GetFenceSellTransactionInfo then
        local totalSells, sellsUsed, resetTimeSeconds = GetFenceSellTransactionInfo()
        totalSells = totalSells or 0
        sellsUsed = sellsUsed or 0
        return zo_max(totalSells - sellsUsed, 0), totalSells, resetTimeSeconds
    end
    return 0, 0, 0
end

--- Check if item is artifact quality (cannot be sold to fence)
---@param bagId number Bag identifier
---@param slotIndex number Slot index within the bag
---@return boolean isArtifact True if item is artifact quality or higher
local function IsArtifactItem(bagId, slotIndex)
    if GetItemFunctionalQuality then
        local funcQuality = GetItemFunctionalQuality(bagId, slotIndex)
        -- ESO uses >= for artifact check (consistent with fencewindowsell_gamepad.lua)
        return funcQuality ~= nil and funcQuality >= ITEM_FUNCTIONAL_QUALITY_ARTIFACT
    end
    return false
end

-- PRIMARY ACTION

---@return string name Localized sell action label
function FenceSell:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_SELL"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if fence sell is possible
function FenceSell:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    local remaining = GetRemainingSells()
    if remaining <= 0 then return false end

    if not (ds.bagId and ds.slotIndex) then return false end
    if IsArtifactItem(ds.bagId, ds.slotIndex) then return false end

    local allowed = AuthorizeVendorAction(Vendor.ACTION.FENCE_SELL, ds.bagId, ds.slotIndex, vendorInstance)
    return allowed == true
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceSell:OnPrimaryAction(vendorInstance)
    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    if bagId == nil or slotIndex == nil then return end

    -- Re-check artifact guard (critical safety)
    -- ESO dialog: CANT_BUYBACK_FROM_FENCE (same dialog used by vanilla fence sell)
    if IsArtifactItem(bagId, slotIndex) then
        ZO_Dialogs_ShowGamepadDialog("CANT_BUYBACK_FROM_FENCE", { bag = bagId, slot = slotIndex })
        return
    end

    local canSell, denyReason = AuthorizeVendorAction(Vendor.ACTION.FENCE_SELL, bagId, slotIndex, vendorInstance)
    if canSell ~= true then
        local deny = BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy and BETTERUI.CIM.ProtectionPolicy.DENY
        if denyReason == (deny and deny.ARTIFACT) then
            ZO_Dialogs_ShowGamepadDialog("CANT_BUYBACK_FROM_FENCE", { bag = bagId, slot = slotIndex })
        end
        return
    end

    -- Re-check remaining fence sells
    local remaining = GetRemainingSells()
    if remaining <= 0 then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK,
            GetString("SI_STOREFAILURE", STORE_FAILURE_AT_FENCE_LIMIT))
        return
    end

    -- Validate the slot still has items
    local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
    if stackSize <= 0 then return end

    -- Each stolen item consumes one fence sell transaction; clamp the stack
    -- like ZOS does (fencewindowsell_gamepad.lua spinnerMax).
    local quantity = zo_min(stackSize, remaining)

    local L = BETTERUI.Log
    local unitPrice = ds.sellPrice
        or (stackSize > 0 and ds.stackSellPrice and (ds.stackSellPrice / stackSize))
        or (GetItemSellValueWithBonuses and GetItemSellValueWithBonuses(bagId, slotIndex))
        or 0
    local expectedPrice = unitPrice * quantity
    local traceData = {
        module = "Vendor",
        scene = BETTERUI_VENDOR_SCENE_NAME,
        feature = "vendor-fence-sell",
        fn = "Vendor.FenceSellComponent.OnPrimaryAction",
        ["function"] = "Vendor.FenceSellComponent.OnPrimaryAction",
        mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
        bagId = bagId,
        slotIndex = slotIndex,
        quantity = quantity,
        expectedPrice = expectedPrice,
        unitPrice = unitPrice,
        currencyType = rawget(_G, "CURT_MONEY"),
        item = L and L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name,
    }
    Vendor.DispatchTracedAction("vendor.fence_sell", traceData, function()
        SellInventoryItem(bagId, slotIndex, quantity)
    end)
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function FenceSell:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil

    -- Only stolen items are listed; the per-frame scan is shared with
    -- GetCategories so the backpack is walked once per refresh.
    for _, slotIndex in ipairs(GetStolenSlotsCached()) do
        local icon, stackCount, sellPrice = GetItemInfo(BAG_BACKPACK, slotIndex)
        local name = GetItemName(BAG_BACKPACK, slotIndex)

        if name and name ~= ""
            and (not Vendor.MatchesSearchQuery or Vendor.MatchesSearchQuery(searchQuery, name))
        then
            name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
            local quality = GetItemDisplayQuality(BAG_BACKPACK, slotIndex)
                or ITEM_DISPLAY_QUALITY_NORMAL
            local isArtifact = IsArtifactItem(BAG_BACKPACK, slotIndex)

            -- Calculate sell price with haggling bonus
            local fenceSellPrice = GetItemSellValueWithBonuses(BAG_BACKPACK, slotIndex) or sellPrice or 0
            local hagglingBonus = GetTotalFenceHagglingBonus and GetTotalFenceHagglingBonus() or 0

            local entryData = {
                name             = name,
                icon             = icon,
                stackCount       = stackCount or 1,
                sellPrice        = fenceSellPrice,
                stackSellPrice   = fenceSellPrice * (stackCount or 1),
                quality          = quality,
                bagId            = BAG_BACKPACK,
                slotIndex        = slotIndex,
                stolen           = true,
                isArtifact       = isArtifact,
                hagglingBonus    = hagglingBonus,
                itemLink         = GetItemLink(BAG_BACKPACK, slotIndex),
                bestGamepadItemCategoryName = "",
                statValue        = "",
            }

            local entry = Vendor.AddItemRow(list, entryData)

            -- Mark artifact items visually. The list holds the entry by
            -- reference, so setting this after AddEntry (inside AddItemRow) is
            -- equivalent to the previous pre-AddEntry ordering.
            if isArtifact and entry then
                entry:SetIconDesaturation(0.5) -- Dim artifact items
            end
        end
    end
end

-- FOOTER INFO

--- Returns footer text showing remaining sells and reset timer
---@return string text Formatted text showing remaining sells and timer
function FenceSell:GetFooterText()
    local remaining, total, resetTimeSeconds = GetRemainingSells()
    local text = zo_strformat(SI_BETTERUI_FENCE_SELLS_REMAINING, remaining, total)

    if resetTimeSeconds and resetTimeSeconds > 0 then
        local timeStr = ZO_FormatCountdownTimer(resetTimeSeconds)
        if timeStr then
            text = text .. " (" .. timeStr .. ")"
        end
    end

    return text
end


-- CATEGORIES



--- Returns the single "Stolen" category tab for the fence sell list.
--- All items eligible for fencing are stolen, so no other categories are needed.
---@return table categories Single-entry category list
function FenceSell:GetCategories(_vendorInstance)
    return {
        {
            key      = "all",
            name     = GetString(SI_BETTERUI_STOLEN),
            iconFile = "EsoUI/Art/Inventory/inventory_stolenItem_icon.dds",
            itemCount = #GetStolenSlotsCached(),
        }
    }
end
