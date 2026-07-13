--[[
File: Modules/TradingHouse/Core/TradingHouseRowSetup.lua
Purpose: Row setup callback for trading house list entries.
         Handles search results, sellable items, and active listings.
         Populates columns: ItemType, Trait, Stat, Value with TH-appropriate data.
]]

local TH = BETTERUI.TradingHouse

local SECONDS_PER_DAY = 86400
local SECONDS_PER_HOUR = 3600
local GOLD_ICON = "|t16:16:EsoUI/Art/currency/gamepad/gp_gold.dds|t"

-- Cache row child lookups; row controls are reused, so children are stable.
local function GetBuiRowChild(control, name)
    local cache = control._buiChildCache
    if not cache then
        cache = {}
        control._buiChildCache = cache
    end
    if cache[name] == nil then
        cache[name] = control:GetNamedChild(name) or false
    end
    return cache[name] or nil
end

local function SetHidden(control, hidden)
    if control and control.SetHidden then
        control:SetHidden(hidden)
    end
end

local function SetHorizontalAlignment(control, alignment)
    if control and control.SetHorizontalAlignment and alignment then
        control:SetHorizontalAlignment(alignment)
    end
end

local function SetWhite(control)
    if control and control.SetColor then
        control:SetColor(1, 1, 1, 1)
    end
end

local function FormatTimeRemaining(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return "-"
    end

    local days = math.floor(seconds / SECONDS_PER_DAY)
    if days > 0 then
        return tostring(days) .. "d"
    end

    local hours = math.floor(seconds / SECONDS_PER_HOUR)
    if hours > 0 then
        return tostring(hours) .. "h"
    end

    local minutes = math.floor(seconds / 60)
    if minutes > 0 then
        return tostring(minutes) .. "m"
    end

    return "<1m"
end

local function FormatWholeNumber(value)
    value = tonumber(value) or 0
    if type(ZO_CommaDelimitNumber) == "function" then
        return ZO_CommaDelimitNumber(value)
    end
    return tostring(value)
end

local function FormatUnitPrice(value)
    value = tonumber(value)
    if not value or value <= 0 then
        return "-"
    end

    local whole = math.floor(value)
    local text
    if value == whole then
        text = FormatWholeNumber(whole)
    else
        text = string.format("%.1f", value)
    end
    return text .. " " .. GOLD_ICON
end

local function FormatCurrency(value, currencyType)
    value = tonumber(value) or 0
    if value <= 0 then
        return "-"
    end

    local resolvedCurrencyType = currencyType or rawget(_G, "CURT_MONEY")
    if resolvedCurrencyType and type(ZO_Currency_FormatGamepad) == "function"
        and rawget(_G, "ZO_CURRENCY_FORMAT_AMOUNT_ICON") then
        return ZO_Currency_FormatGamepad(resolvedCurrencyType, math.floor(value + 0.5),
            ZO_CURRENCY_FORMAT_AMOUNT_ICON)
    end

    return FormatWholeNumber(math.floor(value + 0.5)) .. " " .. GOLD_ICON
end

local function ApplyBrowseResultColumns(itemTypeControl, traitControl, statControl, valueControl, ds)
    SetHidden(itemTypeControl, false)
    SetHidden(traitControl, true)
    SetHidden(statControl, false)
    SetHidden(valueControl, false)

    SetHorizontalAlignment(itemTypeControl, rawget(_G, "TEXT_ALIGN_LEFT"))
    SetHorizontalAlignment(statControl, rawget(_G, "TEXT_ALIGN_RIGHT"))
    SetHorizontalAlignment(valueControl, rawget(_G, "TEXT_ALIGN_RIGHT"))

    SetWhite(itemTypeControl)
    SetWhite(statControl)
    SetWhite(valueControl)

    itemTypeControl:SetText(FormatTimeRemaining(ds.timeRemaining))
    traitControl:SetText("")
    statControl:SetText(FormatUnitPrice(ds.unitPrice))

    local displayValue = tonumber(ds.purchasePrice) or 0
    local moneyType = rawget(_G, "CURT_MONEY")
    local currencyLocation = rawget(_G, "CURRENCY_LOCATION_CHARACTER")
    if displayValue > 0 and moneyType and currencyLocation and type(GetCurrencyAmount) == "function" then
        local gold = GetCurrencyAmount(moneyType, currencyLocation) or 0
        if gold < displayValue then
            valueControl:SetColor(1, 0.3, 0.3, 1)
        else
            valueControl:SetColor(0.3, 1, 0.3, 1)
        end
    end
    valueControl:SetText(FormatCurrency(displayValue, ds.currencyType))
end

local function ResetInventoryColumnState(itemTypeControl, traitControl, statControl, valueControl)
    SetHidden(itemTypeControl, false)
    SetHidden(traitControl, false)
    SetHidden(statControl, false)
    SetHidden(valueControl, false)

    SetHorizontalAlignment(itemTypeControl, rawget(_G, "TEXT_ALIGN_LEFT"))
    SetHorizontalAlignment(traitControl, rawget(_G, "TEXT_ALIGN_LEFT"))
    SetHorizontalAlignment(statControl, rawget(_G, "TEXT_ALIGN_LEFT"))
    SetHorizontalAlignment(valueControl, rawget(_G, "TEXT_ALIGN_RIGHT"))
end

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

    -- Trading House rows need more air between the 32px artwork and the item
    -- name than the shared default provides. Move only the artwork left so
    -- the name and data-column anchors remain aligned with their headers.
    local iconControl = control.icon
        or (control.GetNamedChild and control:GetNamedChild("Icon"))
    if iconControl and control.label and iconControl.ClearAnchors and iconControl.SetAnchor then
        iconControl:ClearAnchors()
        iconControl:SetAnchor(CENTER, control.label, LEFT, -40, 0)
    end

    local ds = data.dataSource or data

    -- Column controls
    local itemTypeControl = GetBuiRowChild(control, "ItemType")
    local traitControl = GetBuiRowChild(control, "Trait")
    local statControl = GetBuiRowChild(control, "Stat")
    local valueControl = GetBuiRowChild(control, "Value")
    if not itemTypeControl or not traitControl or not statControl or not valueControl then return end

    -- Column font
    local columnFont = BETTERUI.CIM.SharedItemSupport.ResolveColumnFontDescriptor("TradingHouse", "Inventory")
    if columnFont then
        itemTypeControl:SetFont(columnFont)
        traitControl:SetFont(columnFont)
        statControl:SetFont(columnFont)
        valueControl:SetFont(columnFont)
    end

    if ds.tradingHouseIndex ~= nil then
        ApplyBrowseResultColumns(itemTypeControl, traitControl, statControl, valueControl, ds)
    else
        ResetInventoryColumnState(itemTypeControl, traitControl, statControl, valueControl)

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

        -- Stat column: use unit price for listings, stat value for sell items
        local statText = ds.statValue
        if ds.unitPrice and ds.unitPrice > 0 then
            statText = TH.FormatUnitPrice(ds.purchasePrice or 0, ds.stackCount or 1)
        end
        if statText == nil or statText == "" then
            statText = "-"
        end
        statControl:SetText(statText)

        -- Value column: show purchase price or sell price
        local displayValue = ds.purchasePrice
            or ds.stackSellPrice
            or ds.sellPrice
            or 0
        valueControl:SetColor(1, 1, 1, 1)

        -- Color red if cannot afford (buyback/listing entries)
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
    end

    -- Icon setup (shared)
    BETTERUI_SharedGamepadEntryIconSetup(control.icon, control.stackCountLabel, data, selected)

    -- Hide original highlight — we use custom gradient selection bar
    if control.highlight then
        control.highlight:SetHidden(true)
    end

    -- Apply gradient selection bar
    BETTERUI.CIM.SelectionHighlight.Setup(control, selected, data)

    -- Cooldown and status icons
    if BETTERUI_CooldownSetup then
        BETTERUI_CooldownSetup(control, data)
    end
    if BETTERUI_IconSetup then
        BETTERUI_IconSetup(
            GetBuiRowChild(control, "StatusIndicator"),
            GetBuiRowChild(control, "EquippedMain"),
            data
        )
    end
end
