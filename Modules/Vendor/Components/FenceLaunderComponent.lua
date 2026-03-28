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

    -- Must have remaining launders
    local remaining = GetRemainingLaunders()
    if remaining <= 0 then return false end

    -- Must be able to afford
    local cost = 0
    if selectedData.bagId and selectedData.slotIndex then
        cost = GetLaunderCost(selectedData.bagId, selectedData.slotIndex)
    end
    return vendorInstance:CanAfford(cost)
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceLaunder:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return end

    local bagId = selectedData.bagId
    local slotIndex = selectedData.slotIndex
    if bagId == nil or slotIndex == nil then return end

    -- Re-check remaining launders
    local remaining = GetRemainingLaunders()
    if remaining <= 0 then return end

    -- Re-check affordability
    local cost = GetLaunderCost(bagId, slotIndex)
    if not vendorInstance:CanAfford(cost) then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil,
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

    local bagSize = GetBagSize(BAG_BACKPACK) or 0

    for slotIndex = 0, bagSize - 1 do
        -- Only show stolen items
        if IsItemStolen(BAG_BACKPACK, slotIndex) then
            local icon, stackCount, _ = GetItemInfo(BAG_BACKPACK, slotIndex)
            local name = GetItemName(BAG_BACKPACK, slotIndex)

            if name and name ~= "" then
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

                list:AddEntry("BUI_Gamepad_ItemEntry", entry)
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
