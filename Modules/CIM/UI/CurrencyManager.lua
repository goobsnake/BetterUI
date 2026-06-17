--[[
File: Modules/CIM/UI/CurrencyManager.lua
Purpose: Shared currency definitions, formatting, and layout logic.

This module provides:
  - CURRENCY_DEFS: Single source of truth for all currency metadata
  - Formatting functions for currency display
  - Layout/positioning logic for currency labels in footers
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Currency = BETTERUI.CIM.Currency or {}

-- CURRENCY DEFINITIONS
-- Single source of truth for all currency metadata

-- Update 50 (API 101050): CURT_TRADE_BARS, CURT_SEALS, CURT_TOME_POINTS, and
-- CURT_ARCHIVAL_FORTUNES are all part of the live API.
local TRADE_BARS_ID = CURT_TRADE_BARS
local SEALS_ID = CURT_SEALS
local TOME_POINTS_ID = CURT_TOME_POINTS

BETTERUI.CIM.Currency.DEFS = {
    {
        iconKey = "gold",
        labelName = "GoldLabel",
        settingKey = "showCurrencyGold",
        apiConst = CURT_MONEY,
        labelStringId = "SI_BETTERUI_FOOTER_GOLD_LABEL",
        color = "FFBF00",
        location = nil
    },
    {
        iconKey = "ap",
        labelName = "APLabel",
        settingKey = "showCurrencyAlliancePoints",
        apiConst = CURT_ALLIANCE_POINTS,
        labelStringId = "SI_BETTERUI_FOOTER_AP_LABEL",
        color = "00FF00",
        location = nil
    },
    {
        iconKey = "telvar",
        labelName = "TVLabel",
        settingKey = "showCurrencyTelVar",
        apiConst = CURT_TELVAR_STONES,
        labelStringId = "SI_BETTERUI_FOOTER_TELVAR_LABEL",
        color = "00FF00",
        location = nil
    },
    {
        iconKey = "gems",
        labelName = "GemsLabel",
        settingKey = "showCurrencyCrownGems",
        apiConst = CURT_CROWN_GEMS,
        labelStringId = "SI_BETTERUI_FOOTER_GEMS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        iconKey = "transmute",
        labelName = "TCLabel",
        settingKey = "showCurrencyTransmute",
        apiConst = CURT_TRANSMUTE_CRYSTALS,
        labelStringId = "SI_BETTERUI_FOOTER_TRANSMUTE_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        iconKey = "crowns",
        labelName = "CrownsLabel",
        settingKey = "showCurrencyCrowns",
        apiConst = CURT_CROWNS,
        labelStringId = "SI_BETTERUI_FOOTER_CROWNS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        iconKey = "writs",
        labelName = "WritsLabel",
        settingKey = "showCurrencyWritVouchers",
        apiConst = CURT_WRIT_VOUCHERS,
        labelStringId = "SI_BETTERUI_FOOTER_WRITS_LABEL",
        color = "00FF00",
        location = nil
    },
    {
        iconKey = "tradebars",
        labelName = "TradeBarsLabel",
        settingKey = "showCurrencyTradeBars",
        apiConst = TRADE_BARS_ID,
        labelStringId = "SI_BETTERUI_FOOTER_TRADE_BARS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        iconKey = "keys",
        labelName = "KeysLabel",
        settingKey = "showCurrencyUndauntedKeys",
        apiConst = CURT_UNDAUNTED_KEYS,
        labelStringId = "SI_BETTERUI_FOOTER_KEYS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        iconKey = "outfit",
        labelName = "OutfitLabel",
        settingKey = "showCurrencyOutfitTokens",
        apiConst = CURT_STYLE_STONES,
        labelStringId = "SI_BETTERUI_FOOTER_OUTFIT_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        iconKey = "seals",
        labelName = "SealsLabel",
        settingKey = "showCurrencySeals",
        apiConst = SEALS_ID,
        labelStringId = "SI_BETTERUI_FOOTER_SEALS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    -- Note: CURT_TOME_POINTS uses GetPlayerStoredCurrencyAmount instead of GetCurrencyAmount
    -- because Endless Archive currency storage is character-specific, not account-wide
    {
        iconKey = "tomepoints",
        labelName = "TomePointsLabel",
        settingKey = "showCurrencyTomePoints",
        apiConst = TOME_POINTS_ID,
        labelStringId = "SI_BETTERUI_FOOTER_TOME_POINTS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT,
        useStoredAmount = true
    },
    -- Archival Fortunes (Infinite Archive, Update 44+). Unlike Tome Points,
    -- this is a regular account-location currency read via GetCurrencyAmount;
    -- GetPlayerStoredCurrencyAmount only services the Tamriel Tomes currencies.
    {
        iconKey = "archival",
        labelName = "ArchivalLabel",
        settingKey = "showCurrencyArchival",
        apiConst = CURT_ARCHIVAL_FORTUNES,
        labelStringId = "SI_BETTERUI_FOOTER_ARCHIVAL_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT,
    },
}

-- Build iconKey-to-def lookup table for ordering
BETTERUI.CIM.Currency.TOKEN_TO_DEF = {}
for _, def in ipairs(BETTERUI.CIM.Currency.DEFS) do
    BETTERUI.CIM.Currency.TOKEN_TO_DEF[def.iconKey] = def
end

-- HELPER FUNCTIONS

--- Retrieves the current amount of a currency for display.
---@param def table
---@return integer
function BETTERUI.CIM.Currency.GetValue(def)
    if not def or not def.apiConst then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.FOOTER, "currencyGetValueMissingDef")
        end
        return 0 end
    if def.useStoredAmount then
        local val = GetPlayerStoredCurrencyAmount(def.apiConst)
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "currencyGetStoredValue", { iconKey = def.iconKey, value = val })
        end
        return val
    else
        -- currencyLocation is a required argument in the U50 API; default to
        -- the character location when a def omits it.
        local val = GetCurrencyAmount(def.apiConst, def.location or CURRENCY_LOCATION_CHARACTER)
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "currencyGetValue", { iconKey = def.iconKey, value = val, location = def.location })
        end
        return val
    end
end

--- Formats a currency label with localized text, color, value, and icon.
---@param def table
---@param amount integer
---@return string
function BETTERUI.CIM.Currency.FormatLabel(def, amount)
    if not def then return "" end
    local label = GetString(_G[def.labelStringId])
    -- Fallback: if the _LABEL string ID isn't registered, label will be empty.
    if not label or label == "" then
        label = zo_strupper(def.iconKey or "") .. ":"
    end

    -- Try gamepad icon first, fall back to keyboard icon.
    local icon = def.apiConst and GetCurrencyGamepadIcon(def.apiConst) or ""
    if not icon or icon == "" then
        icon = def.apiConst and GetCurrencyKeyboardIcon(def.apiConst) or ""
    end
    icon = BETTERUI.SafeIcon(icon)

    -- Build label: "LABEL |cCOLORVALUE|r [icon]"
    local valueStr = tostring(BETTERUI.FormatNumber(amount, { case = "lower", style = "smart" }) or "0")
    local formatted = label .. " |c" .. def.color .. valueStr .. "|r"
    if icon ~= "" then
        formatted = formatted .. " |t24:24:" .. icon .. "|t"
    end
    return formatted
end

---@param footer table
---@param labelName string
---@return table?
function BETTERUI.CIM.Currency.GetLabelControl(footer, labelName)
    if not footer._controlCache then footer._controlCache = {} end
    if not footer._controlCache[labelName] then
        -- Use global GetControl to resolve $(parent)Suffix naming automatically
        footer._controlCache[labelName] = GetControl(footer, labelName)
    end
    return footer._controlCache[labelName]
end

---@param footer table
---@param invSettings table
---@return boolean anyChanged
function BETTERUI.CIM.Currency.UpdateLabels(footer, invSettings)
    if not footer._valueCache then footer._valueCache = {} end
    local cache = footer._valueCache
    local anyChanged = false
    local DEFS = BETTERUI.CIM.Currency.DEFS
    local GetLabelControl = BETTERUI.CIM.Currency.GetLabelControl
    local GetValue = BETTERUI.CIM.Currency.GetValue
    local FormatLabel = BETTERUI.CIM.Currency.FormatLabel
    local logActive = BETTERUI.Log and BETTERUI.Log.IsActive()

    if logActive then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "currencyUpdateLabels")
    end

    for _, def in ipairs(DEFS) do
        local label = GetLabelControl(footer, def.labelName)
        if label then
            local cached = cache[def.iconKey] or {}

            -- Runtime availability check:
            --   API constant missing (e.g. CURT_TOME_POINTS on pre-U49 clients)
            --   means this currency system does not exist on this client.
            local available = def.apiConst ~= nil

            if not available then
                if not label:IsHidden() then
                    label:SetHidden(true)
                    anyChanged = true
                    if logActive then
                        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "currencyLabelUnavailable", { iconKey = def.iconKey })
                    end
                end
            else
                local enabled = invSettings[def.settingKey] ~= false
                local val = enabled and GetValue(def) or 0

                -- Check if state changed
                if cached.enabled ~= enabled or (enabled and cached.amount ~= val) then
                    label:SetHidden(not enabled)
                    if enabled then
                        label:SetText(FormatLabel(def, val))
                    end

                    cache[def.iconKey] = { enabled = enabled, amount = val }
                    anyChanged = true
                    if logActive then
                        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "currencyLabelUpdated", { iconKey = def.iconKey, enabled = enabled, value = val })
                    end
                end
            end
        end
    end
    return anyChanged
end

--- Build ordered list of visible currency definitions based on user settings.
---@param invSettings table
---@return table[] visible
function BETTERUI.CIM.Currency.GetVisibleOrder(invSettings)
    local orderStr = invSettings.currencyOrder or
        "gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints,archival"
    local seen = {}
    local visible = {}
    local DEFS = BETTERUI.CIM.Currency.DEFS
    local TOKEN_TO_DEF = BETTERUI.CIM.Currency.TOKEN_TO_DEF

    -- First pass: Add enabled iconKeys found in the order string
    for iconKey in string.gmatch(string.lower(orderStr), "[^,%s]+") do
        local def = TOKEN_TO_DEF[iconKey]
        if def then
            seen[iconKey] = true
            if invSettings[def.settingKey] ~= false then
                table.insert(visible, def)
            end
        end
    end

    -- Second pass: Add any remaining enabled iconKeys not in order string (fallback)
    for _, def in ipairs(DEFS) do
        if not seen[def.iconKey] then
            if invSettings[def.settingKey] ~= false then
                table.insert(visible, def)
            end
        end
    end

    return visible
end

---@param footer table
---@param invSettings table
---@return nil
function BETTERUI.CIM.Currency.PositionLabels(footer, invSettings)
    local visible = BETTERUI.CIM.Currency.GetVisibleOrder(invSettings)
    local GetLabelControl = BETTERUI.CIM.Currency.GetLabelControl
    local yRows = BETTERUI_CURRENCY_ROWS or { 32, 58, 84 }
    local maxVisible = BETTERUI_MAX_VISIBLE_CURRENCIES or 12
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "currencyPositionLabels", { visibleCount = #visible, maxVisible = maxVisible, numRows = #yRows - 1 })
    end

    -- Hide excess currencies
    for idx, def in ipairs(visible) do
        local ctrl = GetLabelControl(footer, def.labelName)
        if ctrl and idx > maxVisible then
            ctrl:SetHidden(true)
        end
    end

    -- Layout Configuration
    local startX = BETTERUI_FOOTER_START_X             -- Left anchor position
    local rightPadding = BETTERUI_FOOTER_RIGHT_PADDING -- Safety buffer from right edge
    local footerWidth = footer:GetWidth()

    -- If footer width isn't valid yet (e.g. at startup), default to a standard 1080p width
    if footerWidth <= 0 then footerWidth = 1920 end

    local availableWidth = footerWidth - startX - rightPadding
    local numRows = #yRows - 1

    local visibleCount = math.min(#visible, maxVisible)
    local numCols = math.ceil(visibleCount / numRows)

    -- Step 1: Measure Columns
    local columnWidths = {}
    local totalTextWidth = 0
    local columnData = {} -- Store data to avoid re-looping for ctrls

    for col = 1, numCols do
        local maxColWidth = 0
        local items = {}

        for row = 1, numRows do
            local idx = (col - 1) * numRows + row
            if idx <= visibleCount then
                local def = visible[idx]
                local ctrl = GetLabelControl(footer, def.labelName)
                if ctrl then
                    table.insert(items, { control = ctrl, rowY = yRows[row] })
                    local width = ctrl:GetTextWidth()
                    if width > maxColWidth then maxColWidth = width end
                end
            end
        end

        columnWidths[col] = maxColWidth
        totalTextWidth = totalTextWidth + maxColWidth
        columnData[col] = items
    end

    -- Step 2: Calculate Spacing (Justify)
    local colGap = 0
    if numCols > 1 then
        local freeSpace = availableWidth - totalTextWidth
        -- Clamp freeSpace to 0 to prevent overlap if content exceeds width
        if freeSpace < 0 then freeSpace = 0 end
        colGap = freeSpace / (numCols - 1)
    end

    -- Step 3: Position Items
    local currentX = startX
    for col = 1, numCols do
        local items = columnData[col]
        for _, item in ipairs(items) do
            item.control:ClearAnchors()
            item.control:SetAnchor(LEFT, footer, BOTTOMLEFT, currentX, item.rowY)
        end

        currentX = currentX + columnWidths[col] + colGap
    end
end
