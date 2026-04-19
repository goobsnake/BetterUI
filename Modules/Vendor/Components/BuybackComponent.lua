--[[
File: Modules/Vendor/Components/BuybackComponent.lua
Purpose: Buyback tab component for the Vendor module.

Handles listing items the player recently sold and buying them back.
Uses GetNumBuybackItems/GetBuybackItemInfo to populate the list.
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
Vendor.BuybackComponent = {}
local Buyback = Vendor.BuybackComponent

local function GetBuybackItemCategoryName(itemLink)
    if not itemLink or itemLink == "" then
        return ""
    end

    if GetItemLinkItemType then
        local itemType = GetItemLinkItemType(itemLink)
        if itemType and itemType ~= ITEMTYPE_NONE then
            return GetString("SI_ITEMTYPE", itemType)
        end
    end

    return ""
end

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function Buyback:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buyback:Deactivate(vendorInstance)
    -- No cleanup needed
end

-- PRIMARY ACTION

---@return string name Localized buyback action label
function Buyback:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_BUYBACK"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if buyback is affordable and inventory has space
function Buyback:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    local price = ds.price or 0
    return vendorInstance:CanAfford(price) and vendorInstance:HasInventorySpace()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Buyback:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local entryIndex = ds.entryIndex
    if not entryIndex then return end

    -- Validate affordability
    local price = ds.price or 0
    if not vendorInstance:CanAfford(price) then
        BETTERUI.CIM.UserAlertText("Buyback:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    if not vendorInstance:HasInventorySpace() then
        BETTERUI.CIM.UserAlertText("Buyback:CannotCarry",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY")))
        return
    end

    BuybackItem(entryIndex)
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function Buyback:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local numItems = GetNumBuybackItems and GetNumBuybackItems() or 0
    if numItems == 0 then return end

    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil
    for entryIndex = 1, numItems do
        -- GetBuybackItemInfo returns: icon, name, stackCount, price,
        -- functionalQuality, meetsRequirementsToEquip, displayQuality
        local icon, name, stackCount, price, functionalQuality,
              meetsRequirements, displayQuality = GetBuybackItemInfo(entryIndex)

        if name and name ~= ""
            and (not Vendor.MatchesSearchQuery or Vendor.MatchesSearchQuery(searchQuery, name))
        then
            local itemLink = GetBuybackItemLink and GetBuybackItemLink(entryIndex) or nil
            -- Prefer displayQuality for color; functionalQuality for artifact guard
            local quality = displayQuality or functionalQuality or ITEM_DISPLAY_QUALITY_NORMAL

            local entryData = {
                entryIndex        = entryIndex,
                name              = zo_strformat(SI_TOOLTIP_ITEM_NAME, name) or name,
                icon              = icon,
                stackCount        = stackCount or 1,
                price             = price or 0,
                quality           = quality,
                functionalQuality = functionalQuality,
                meetsRequirements = meetsRequirements,
                itemLink          = itemLink,
                bestGamepadItemCategoryName = GetBuybackItemCategoryName(itemLink),
                statValue         = "",
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
