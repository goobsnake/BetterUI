--[[
File: Modules/Vendor/Core/VendorRowSetup.lua
Purpose: Row setup callback for vendor list entries.
         Handles both bag-based items (sell/repair/fence) and store-based items (buy/buyback).
         Populates columns: ItemType, Trait, Stat, Value with vendor-appropriate data.
]]

local Vendor = BETTERUI.Vendor

--- Row setup function for vendor item entries.
--- Registered as the setup callback for BETTERUI_GamepadItemSubEntryTemplate in the vendor list.
---@param control table UI control for the row
---@param data table Entry data with item info (may or may not have bagId/slotIndex)
---@param selected boolean Whether this row is currently selected
---@param reselectingDuringRebuild boolean Whether reselecting during rebuild
---@param enabled boolean Whether the row is enabled
---@param active boolean Whether the row is active
function BETTERUI.Vendor.VendorEntrySetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    -- Label setup (shared with inventory/banking)
    BETTERUI_SharedGamepadEntryLabelSetup(control.label, data, selected)

    -- Get data source (SetDataSource stores it in data.dataSource)
    local ds = data.dataSource or data

    -- Column controls
    local itemTypeControl = control:GetNamedChild("ItemType")
    local traitControl = control:GetNamedChild("Trait")
    local statControl = control:GetNamedChild("Stat")
    local valueControl = control:GetNamedChild("Value")
    if not itemTypeControl or not traitControl or not statControl or not valueControl then return end

    -- Column font
    local columnFont
    if Vendor.GetColumnFontDescriptor then
        columnFont = Vendor.GetColumnFontDescriptor()
    elseif BETTERUI.Inventory and BETTERUI.Inventory.GetColumnFontDescriptor then
        columnFont = BETTERUI.Inventory.GetColumnFontDescriptor()
    end
    if columnFont then
        itemTypeControl:SetFont(columnFont)
        traitControl:SetFont(columnFont)
        statControl:SetFont(columnFont)
        valueControl:SetFont(columnFont)
    end

    -- ItemType column
    local typeName = ds.bestGamepadItemCategoryName or ds.bestItemTypeName or ""
    itemTypeControl:SetText(string.upper(typeName))

    -- Trait column
    local traitName = ds.traitName or ds.cached_traitName
    if not traitName then
        local itemLink = ds.itemLink or ds.cached_itemLink
        if itemLink and GetItemLinkTraitInfo then
            local traitType = GetItemLinkTraitInfo(itemLink)
            if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                traitName = string.upper(GetString("SI_ITEMTRAITTYPE", traitType))
            end
        end
    end
    traitControl:SetText(traitName or "-")

    -- Stat column
    local statText = ds.statValue
    if statText == nil or statText == "" then
        statText = "-"
    end
    statControl:SetText(statText)

    -- Value column: prioritize vendor-specific price fields
    local displayValue = ds.price
        or ds.repairCost
        or ds.launderCost
        or ds.stackSellPrice
        or ds.sellPrice
        or 0
    valueControl:SetColor(1, 1, 1, 1)
    if BETTERUI.FormatAbbreviatedNumber then
        valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(displayValue))
    else
        valueControl:SetText(tostring(displayValue))
    end

    -- Icon setup (shared)
    BETTERUI_SharedGamepadEntryIconSetup(control.icon, control.stackCountLabel, data, selected)

    -- Hide original highlight — we use custom gradient selection bar
    if control.highlight then
        control.highlight:SetHidden(true)
    end

    -- Apply gradient selection bar
    BETTERUI.CIM.SelectionHighlight.Setup(control, selected)

    -- Cooldown and status icons
    if BETTERUI_CooldownSetup then
        BETTERUI_CooldownSetup(control, data)
    end
    if BETTERUI_IconSetup then
        BETTERUI_IconSetup(
            control:GetNamedChild("StatusIndicator"),
            control:GetNamedChild("EquippedMain"),
            data
        )
    end
end
