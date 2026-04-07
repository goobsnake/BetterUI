--[[
File: Modules/TradingHouse/Core/TradingHouseRowSetup.lua
Purpose: Row setup callback for trading house list entries.
         Handles search results, sellable items, and active listings.
         Populates columns: ItemType, Trait, Stat, Value with TH-appropriate data.
]]

local TH = BETTERUI.TradingHouse

--- Row setup function for trading house item entries.
---@param control table UI control for the row
---@param data table Entry data with item info
---@param selected boolean Whether this row is currently selected
---@param reselectingDuringRebuild boolean Whether reselecting during rebuild
---@param enabled boolean Whether the row is enabled
---@param active boolean Whether the row is active
function BETTERUI.TradingHouse.THEntrySetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    -- Label setup (shared with inventory/banking)
    BETTERUI_SharedGamepadEntryLabelSetup(control.label, data, selected)

    local ds = data.dataSource or data

    -- Column controls
    local itemTypeControl = control:GetNamedChild("ItemType")
    local traitControl = control:GetNamedChild("Trait")
    local statControl = control:GetNamedChild("Stat")
    local valueControl = control:GetNamedChild("Value")
    if not itemTypeControl or not traitControl or not statControl or not valueControl then return end

    -- Column font
    local columnFont
    if TH.GetColumnFontDescriptor then
        columnFont = TH.GetColumnFontDescriptor()
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

    -- Stat column: use unit price for browse results, stat value for sell items
    local statText = ds.statValue
    if ds.unitPrice and ds.unitPrice > 0 then
        -- Show unit price for search results and listings
        statText = TH.FormatUnitPrice(ds.purchasePrice or ds.listingPrice or 0, ds.stackCount or 1)
    end
    if statText == nil or statText == "" then
        statText = "-"
    end
    statControl:SetText(statText)

    -- Value column: show purchase price or listing price or sell price
    local displayValue = ds.purchasePrice
        or ds.listingPrice
        or ds.stackSellPrice
        or ds.sellPrice
        or 0
    valueControl:SetColor(1, 1, 1, 1)

    -- Color red if cannot afford (browse/buyback entries)
    if ds.purchasePrice and ds.purchasePrice > 0 then
        local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
        if gold < ds.purchasePrice then
            valueControl:SetColor(1, 0.3, 0.3, 1)
        else
            valueControl:SetColor(0.3, 1, 0.3, 1)
        end
    end

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
