--[[
File: Modules/Vendor/Core/List/VendorRowSetup.lua
Purpose: Row setup callback for vendor list entries.
         Handles both bag-based items (sell/repair/fence) and store-based items (buy/buyback).
         Populates columns: ItemType, Trait, Stat, Value with vendor-appropriate data.
]]

---@param ds table|nil
---@return boolean
local function IsStableTrainingRow(ds)
    return ds and ds.trainingType ~= nil
end

---@param ds table
---@return string
local function ResolveStableTrainingTypeText(ds)
    local typeName = ds.bestGamepadItemCategoryName
        or GetString(rawget(_G, "SI_STATS_RIDING_SKILL") or "SI_STATS_RIDING_SKILL")
        or ""
    return string.upper(typeName)
end

---@param ds table
---@return string
local function ResolveStableTrainingTraitText(ds)
    local traitText = ds.trainStateText
    if traitText == nil or traitText == "" then
        traitText = "-"
    end
    return traitText
end

---@param ds table
---@return string
local function ResolveStableTrainingStatText(ds)
    local statText = ds.statValue
    if statText == nil or statText == "" then
        statText = "-"
    end
    return statText
end

---@param ds table
---@return string
local function ResolveStableTrainingValueText(ds)
    if ds.valueText and ds.valueText ~= "" then
        return ds.valueText
    end

    local displayValue = ds.price or 0
    if displayValue <= 0 then
        return "-"
    end

    if BETTERUI.Vendor.FormatCurrency then
        return BETTERUI.Vendor.FormatCurrency(displayValue)
    end

    return tostring(displayValue)
end

---@param control table
---@param ds table
local function ConfigureStableTrainingProgress(control, ds)
    local trainingProgress = control:GetNamedChild("TrainingProgress")
    local trainingProgressBackdrop = control:GetNamedChild("TrainingProgressBackdrop")
    if not trainingProgress then
        return
    end

    local progressCurrent = tonumber(ds.progressCurrent or ds.bonus or 0) or 0
    local progressMax = tonumber(ds.progressMax or ds.maxBonus or 0) or 0
    local shouldShow = progressMax > 0

    if trainingProgressBackdrop then
        trainingProgressBackdrop:SetHidden(not shouldShow)
    end
    trainingProgress:SetHidden(not shouldShow)
    if not shouldShow then
        return
    end

    trainingProgress:SetMinMax(0, progressMax)
    trainingProgress:SetValue(zo_min(progressCurrent, progressMax))
    trainingProgress:SetColor(196 / 255, 166 / 255, 77 / 255, 1)
end

---@param control table
local function ResetStableTrainingProgress(control)
    local trainingProgress = control:GetNamedChild("TrainingProgress")
    local trainingProgressBackdrop = control:GetNamedChild("TrainingProgressBackdrop")
    if trainingProgress then
        trainingProgress:SetHidden(true)
    end
    if trainingProgressBackdrop then
        trainingProgressBackdrop:SetHidden(true)
    end
end

--- Row setup function for vendor item entries.
--- Registered as the setup callback for BETTERUI_GamepadItemSubEntryTemplate in the vendor list.
---@param control table UI control for the row
---@param data table Entry data with item info (may or may not have bagId/slotIndex)
---@param selected boolean Whether this row is currently selected
---@param reselectingDuringRebuild boolean Whether reselecting during rebuild
---@param enabled boolean Whether the row is enabled
---@param active boolean Whether the row is active
function BETTERUI.Vendor.VendorEntrySetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    -- Get data source (SetDataSource stores it in data.dataSource)
    local ds = data.dataSource or data

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "vendor row setup", {
            selected = selected,
            name = ds and ds.name or nil,
            bagId = ds and ds.bagId or nil,
            slotIndex = ds and ds.slotIndex or nil,
        })
    end

    -- Label setup (shared with inventory/banking)
    BETTERUI_SharedGamepadEntryLabelSetup(control.label, data, selected)

    -- Column controls
    local itemTypeControl = control:GetNamedChild("ItemType")
    local traitControl = control:GetNamedChild("Trait")
    local statControl = control:GetNamedChild("Stat")
    local valueControl = control:GetNamedChild("Value")
    if not itemTypeControl or not traitControl or not statControl or not valueControl then return end

    -- Column font
    local columnFont = BETTERUI.CIM.SharedItemSupport.ResolveColumnFontDescriptor("Vendor", "Inventory")
    if columnFont then
        itemTypeControl:SetFont(columnFont)
        traitControl:SetFont(columnFont)
        statControl:SetFont(columnFont)
        valueControl:SetFont(columnFont)
    end

    ResetStableTrainingProgress(control)

    if IsStableTrainingRow(ds) then
        itemTypeControl:SetText(ResolveStableTrainingTypeText(ds))
        traitControl:SetText(ResolveStableTrainingTraitText(ds))
        statControl:SetText(ResolveStableTrainingStatText(ds))
        valueControl:SetColor(1, 1, 1, 1)
        valueControl:SetText(ResolveStableTrainingValueText(ds))
        ConfigureStableTrainingProgress(control, ds)
    else
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
        -- Alt-currency buy entries: Buy:BuildList folds currencyQuantity1 into
        -- ds.price for non-gold rows, so displayValue is non-zero. Detect the
        -- alt-currency by currencyType1 rather than a zero price, otherwise the
        -- icon+amount branch is skipped and a bare number renders.
        local altCurrencyText
        local hasAltCurrency = ds.currencyType1 ~= nil
            and ds.currencyType1 ~= CURT_MONEY and ds.currencyType1 ~= CURT_NONE
        if hasAltCurrency or (not displayValue or displayValue == 0) then
            local altType, altQty
            if ds.currencyType1 and ds.currencyType1 ~= CURT_MONEY and ds.currencyType1 ~= CURT_NONE
                and (ds.currencyQuantity1 or 0) > 0 then
                altType, altQty = ds.currencyType1, ds.currencyQuantity1
            elseif ds.currencyType2 and ds.currencyType2 ~= CURT_MONEY and ds.currencyType2 ~= CURT_NONE
                and (ds.currencyQuantity2 or 0) > 0 then
                altType, altQty = ds.currencyType2, ds.currencyQuantity2
            end
            if altType then
                if type(ZO_Currency_FormatGamepad) == "function" then
                    altCurrencyText = ZO_Currency_FormatGamepad(altType, altQty, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
                else
                    altCurrencyText = tostring(altQty)
                end
            end
        end
        if altCurrencyText then
            valueControl:SetText(altCurrencyText)
        elseif BETTERUI.Vendor.FormatCurrency then
            valueControl:SetText(BETTERUI.Vendor.FormatCurrency(displayValue))
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
    BETTERUI.CIM.SelectionHighlight.Setup(control, selected)

    -- Show selection indicator for multi-selected entries (inventory/banking parity)
    local selectionIndicator = control:GetNamedChild("SelectionIndicator")
    local selectionBar = control:GetNamedChild("SelectionBar")
    local isMultiSelected = false

    local multiSelectManager = BETTERUI.CIM.MultiSelectManager
    if multiSelectManager and multiSelectManager.GetActiveInstance then
        local manager = multiSelectManager.GetActiveInstance()
        if manager and manager:IsActive() then
            isMultiSelected = manager:IsSelected(data)
        end
    end

    if selectionIndicator then
        selectionIndicator:SetHidden(not isMultiSelected)
        if isMultiSelected then
            selectionIndicator:SetColor(0.2, 0.9, 0.2, 1)
        end
    end

    if selectionBar then
        if isMultiSelected then
            selectionBar:SetHidden(false)
            selectionBar:SetColor(0.2, 0.8, 0.3, 0.6)
        elseif selected then
            selectionBar:SetColor(0.77, 0.65, 0.30, 0.45)
        end
    end

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
