--[[
File: Modules/Vendor/Components/BuyComponent.lua
Purpose: Buy tab component for the Vendor module.
Authors: BUI Team
Last Modified: 2026-03-14

Handles listing store items and purchasing them.
Uses GetNumStoreItems/GetStoreEntryInfo to populate the list.
]]

local Vendor = BETTERUI.Vendor
local MODE   = Vendor.MODE

-- ============================================================================
-- COMPONENT TABLE
-- ============================================================================
Vendor.BuyComponent = {}
local Buy = Vendor.BuyComponent

-- ============================================================================
-- ACTIVATE / DEACTIVATE
-- ============================================================================

--- @param vendorInstance any Description
--- @return any Description
function Buy:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

--- @param vendorInstance any Description
--- @return any Description
function Buy:Deactivate(vendorInstance)
    -- No cleanup needed for Buy mode
end

-- ============================================================================
-- PRIMARY ACTION
-- ============================================================================

--- @return any Description
function Buy:GetPrimaryActionName()
    return GetString(SI_TRADING_HOUSE_PURCHASE)
end

--- @param vendorInstance any Description
--- @return any Description
function Buy:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return false end

    -- Check affordability using stored price
    local price = selectedData.price or 0
    local currencyType = selectedData.currencyType or CURT_MONEY
    return vendorInstance:CanAfford(price, currencyType)
        and vendorInstance:HasInventorySpace()
end

--- @param vendorInstance any Description
--- @return any Description
function Buy:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return end

    local entryIndex = selectedData.entryIndex
    if not entryIndex then return end

    -- Validate affordability one more time
    local price = selectedData.price or 0
    local currencyType = selectedData.currencyType or CURT_MONEY
    if not vendorInstance:CanAfford(price, currencyType) then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil,
            GetString(SI_BETTERUI_VENDOR_CANNOT_AFFORD))
        return
    end

    if not vendorInstance:HasInventorySpace() then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil,
            GetString(SI_BETTERUI_VENDOR_CANNOT_CARRY))
        return
    end

    -- Quantity = 1 for normal purchase (stack purchase would need spinner)
    BuyStoreItem(entryIndex, 1)
end

-- ============================================================================
-- LIST BUILDING
-- ============================================================================

--- @param vendorInstance any Description
--- @return any Description
function Buy:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local numItems = GetNumStoreItems and GetNumStoreItems() or 0
    if numItems == 0 then return end

    for entryIndex = 1, numItems do
        local icon, name, stack, price, sellPrice, meetsReqs, equipType,
            itemStyle, quality, questNameColor, currencyType1, currencyQuantity1,
            currencyType2, currencyQuantity2, entryType = GetStoreEntryInfo(entryIndex)

        if name and name ~= "" then
            local itemLink = GetStoreItemLink(entryIndex)
            local itemData = {
                entryIndex       = entryIndex,
                name             = zo_strformat(SI_TOOLTIP_ITEM_NAME, name) or name,
                icon             = icon,
                stackCount       = stack or 1,
                price            = currencyQuantity1 or price or 0,
                currencyType     = currencyType1 or CURT_MONEY,
                sellPrice        = sellPrice or 0,
                meetsRequirements = meetsReqs,
                quality          = quality or ITEM_DISPLAY_QUALITY_NORMAL,
                itemLink         = itemLink,
                entryType        = entryType,
                -- Trait/type info
                bestGamepadItemCategoryName = GetBestItemCategoryDescription(itemLink) or "",
                statValue        = "",
            }

            -- Get trait info if available
            if itemLink and GetItemLinkTraitInfo then
                local traitType = GetItemLinkTraitInfo(itemLink)
                if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                    itemData.traitName = GetString("SI_ITEMTRAITTYPE", traitType)
                end
            end

            local entry = ZO_GamepadEntryData:New(itemData.name, itemData.icon)
            entry:SetDataSource(itemData)
            entry.narrationText = function() return itemData.name end

            -- Set quality color
            if quality then
                local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
            end

            list:AddEntry("BUI_Gamepad_ItemEntry", entry)
        end
    end
end
