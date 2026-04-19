--[[
File: Modules/Vendor/Components/FenceLaunderComponent.lua
Purpose: Fence Launder tab component for the Vendor module.

Handles laundering stolen items at the fence.
KEY MECHANICS:
- Transaction limit checked every action via GetFenceLaunderTransactionInfo()
- Player must be able to afford launder cost
- Only stolen items from BAG_BACKPACK shown in list
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
Vendor.FenceLaunderComponent = {}
local FenceLaunder = Vendor.FenceLaunderComponent

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:Deactivate(vendorInstance)
    -- No cleanup needed
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
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Must have remaining launders
    local remaining = GetRemainingLaunders()
    if remaining <= 0 then return false end

    -- Must be able to afford
    local cost = 0
    if ds.bagId and ds.slotIndex then
        cost = GetLaunderCost(ds.bagId, ds.slotIndex)
    end
    if not vendorInstance:CanAfford(cost) then
        return false
    end

    return Vendor.AuthorizeInventoryAction
        and Vendor.AuthorizeInventoryAction(Vendor.ACTION.FENCE_LAUNDER, ds.bagId, ds.slotIndex, vendorInstance)
        or true
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    if bagId == nil or slotIndex == nil then return end

    if Vendor.AuthorizeInventoryAction then
        local canLaunder, denyReason = Vendor.AuthorizeInventoryAction(Vendor.ACTION.FENCE_LAUNDER, bagId, slotIndex,
            vendorInstance)
        if not canLaunder then
            local deny = BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy and BETTERUI.CIM.ProtectionPolicy.DENY
            if denyReason == (deny and deny.CANNOT_AFFORD) then
                BETTERUI.CIM.UserAlertText("FenceLaunder:CannotAfford",
                    GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
            end
            return
        end
    end

    -- Re-check remaining launders
    local remaining = GetRemainingLaunders()
    if remaining <= 0 then return end

    -- Re-check affordability
    local cost = GetLaunderCost(bagId, slotIndex)
    if not vendorInstance:CanAfford(cost) then
        BETTERUI.CIM.UserAlertText("FenceLaunder:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    -- Validate the slot still has items
    local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
    if stackSize <= 0 then return end

    -- Launder full stack
    LaunderItem(bagId, slotIndex, stackSize)
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil
    local bagSize = GetBagSize(BAG_BACKPACK) or 0

    for slotIndex = 0, bagSize - 1 do
        -- Only show stolen items
        if IsItemStolen(BAG_BACKPACK, slotIndex) then
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

                local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
                entry:SetDataSource(entryData)
                entry.narrationText = function() return entryData.name end

                if quality then
                    local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                    entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                end

                list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
            end
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
    local count = 0
    for slotIndex = 0, (GetBagSize(BAG_BACKPACK) or 0) - 1 do
        if IsItemStolen(BAG_BACKPACK, slotIndex) then
            count = count + 1
        end
    end
    return {
        {
            key      = "all",
            name     = GetString(SI_BETTERUI_STOLEN),
            iconFile = "EsoUI/Art/Inventory/inventory_stolenItem_icon.dds",
            itemCount = count,
        }
    }
end
