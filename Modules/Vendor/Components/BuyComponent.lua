--[[
File: Modules/Vendor/Components/BuyComponent.lua
Purpose: Buy tab component for the Vendor module.

Handles listing store items and purchasing them.
Uses GetNumStoreItems/GetStoreEntryInfo to populate the list.
]]

local Vendor = BETTERUI.Vendor

---@class VendorComponent
---@field Activate fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field Deactivate fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field GetPrimaryActionName fun(self: VendorComponent, vendorInstance?: BETTERUI.Vendor.Class): string
---@field IsPrimaryActionEnabled fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class): boolean
---@field OnPrimaryAction fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)
---@field BuildList fun(self: VendorComponent, vendorInstance: BETTERUI.Vendor.Class)

-- COMPONENT TABLE
Vendor.BuyComponent = {}
local Buy = Vendor.BuyComponent

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:Deactivate(vendorInstance)
    -- No cleanup needed for Buy mode
end

-- PRIMARY ACTION

---@return string name Localized action label
function Buy:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_TRADING_HOUSE_PURCHASE"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if a buy action is possible
function Buy:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return false end

    -- Check affordability using stored price
    local price = selectedData.price or 0
    local currencyType = selectedData.currencyType or CURT_MONEY
    return vendorInstance:CanAfford(price, currencyType)
        and vendorInstance:HasInventorySpace()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return end

    local entryIndex = selectedData.entryIndex
    if not entryIndex then return end

    -- Validate affordability one more time
    local price = selectedData.price or 0
    local currencyType = selectedData.currencyType or CURT_MONEY
    if not vendorInstance:CanAfford(price, currencyType) then
        BETTERUI.CIM.UserAlertText("Buy:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    if not vendorInstance:HasInventorySpace() then
        BETTERUI.CIM.UserAlertText("Buy:CannotCarry",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY")))
        return
    end

    -- Quantity = 1 for normal purchase (stack purchase would need spinner)
    BuyStoreItem(entryIndex, 1)
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function Buy:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local numItems = GetNumStoreItems and GetNumStoreItems() or 0
    if numItems == 0 then return end

    for entryIndex = 1, numItems do
        local icon, name, stack, price, sellPrice, meetsReqs, _, _, quality, _, currencyType1, currencyQuantity1,
            _, _, entryType = GetStoreEntryInfo(entryIndex)

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
