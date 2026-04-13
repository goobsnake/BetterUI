--[[
File: Modules/Vendor/Components/FenceSellComponent.lua
Purpose: Fence Sell Stolen tab component for the Vendor module.

Handles selling stolen items to the fence.
KEY SAFETY GUARDS:
- Artifact quality items (ITEM_FUNCTIONAL_QUALITY_ARTIFACT) blocked with dialog
- Transaction limit checked every action via GetFenceSellTransactionInfo()
- Only stolen items from BAG_BACKPACK shown in list
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
local FenceSell = {}
Vendor.FenceSellComponent = FenceSell

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function FenceSell:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceSell:Deactivate(vendorInstance)
    -- No cleanup needed
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
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    local remaining = GetRemainingSells()
    if remaining <= 0 then return false end

    if not (ds.bagId and ds.slotIndex) then return true end
    if IsArtifactItem(ds.bagId, ds.slotIndex) then return false end

    return true
end

---@param vendorInstance BETTERUI.Vendor.Class
function FenceSell:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
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

    -- Re-check remaining fence sells
    local remaining = GetRemainingSells()
    if remaining <= 0 then return end

    -- Validate the slot still has items
    local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
    if stackSize <= 0 then return end

    -- Sell full stack plus haggling bonus
    SellInventoryItem(bagId, slotIndex, stackSize)
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function FenceSell:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local searchQuery = Vendor.GetNormalizedSearchQuery and Vendor.GetNormalizedSearchQuery(vendorInstance) or nil
    local bagSize = GetBagSize(BAG_BACKPACK) or 0

    for slotIndex = 0, bagSize - 1 do
        -- Only show stolen items
        if IsItemStolen(BAG_BACKPACK, slotIndex) then
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

                local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
                entry:SetDataSource(entryData)
                entry.narrationText = function() return entryData.name end

                if quality then
                    local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                    entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                end

                -- Mark artifact items visually
                if isArtifact then
                    entry:SetIconDesaturation(0.5) -- Dim artifact items
                end

                list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
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
