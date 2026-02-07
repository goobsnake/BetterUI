--[[
File: Modules/CIM/UI/CurrencyManager.lua
Purpose: Shared currency definitions, formatting, and layout logic.
Author: BetterUI Team
Last Modified: 2026-01-26

This module provides:
  - CURRENCY_DEFS: Single source of truth for all currency metadata
  - Formatting functions for currency display
  - Layout/positioning logic for currency labels in footers
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Currency = BETTERUI.CIM.Currency or {}

-- ============================================================================
-- CURRENCY DEFINITIONS
-- Single source of truth for all currency metadata
-- ============================================================================

-- Backwards Compatibility:
-- "Trade Bars" (Update 49+) used to be "Event Tickets".
-- "Seals" used to be "Endeavor Seals" (renamed in upcoming release).
-- "Tome Points" are new in Update 49 and may not exist on older clients.
local IS_LEGACY_TICKETS = (CURT_TRADE_BARS == nil) and (CURT_EVENT_TICKETS ~= nil)
local TRADE_BARS_ID = CURT_TRADE_BARS or CURT_EVENT_TICKETS
local SEALS_ID = CURT_SEALS or CURT_ENDEAVOR_SEALS
local TOME_POINTS_ID = CURT_TOME_POINTS -- can be nil

BETTERUI.CIM.Currency.DEFS = {
    {
        token = "gold",
        labelName = "GoldLabel",
        settingKey = "showCurrencyGold",
        apiConst = CURT_MONEY,
        labelStringId = "SI_BETTERUI_FOOTER_GOLD_LABEL",
        color = "FFBF00",
        location = nil
    },
    {
        token = "ap",
        labelName = "APLabel",
        settingKey = "showCurrencyAlliancePoints",
        apiConst = CURT_ALLIANCE_POINTS,
        labelStringId = "SI_BETTERUI_FOOTER_AP_LABEL",
        color = "00FF00",
        location = nil
    },
    {
        token = "telvar",
        labelName = "TVLabel",
        settingKey = "showCurrencyTelVar",
        apiConst = CURT_TELVAR_STONES,
        labelStringId = "SI_BETTERUI_FOOTER_TELVAR_LABEL",
        color = "00FF00",
        location = nil
    },
    {
        token = "gems",
        labelName = "GemsLabel",
        settingKey = "showCurrencyCrownGems",
        apiConst = CURT_CROWN_GEMS,
        labelStringId = "SI_BETTERUI_FOOTER_GEMS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        token = "transmute",
        labelName = "TCLabel",
        settingKey = "showCurrencyTransmute",
        apiConst = CURT_TRANSMUTE_CRYSTALS,
        labelStringId = "SI_BETTERUI_FOOTER_TRANSMUTE_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        token = "crowns",
        labelName = "CrownsLabel",
        settingKey = "showCurrencyCrowns",
        apiConst = CURT_CROWNS,
        labelStringId = "SI_BETTERUI_FOOTER_CROWNS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        token = "writs",
        labelName = "WritsLabel",
        settingKey = "showCurrencyWritVouchers",
        apiConst = CURT_WRIT_VOUCHERS,
        labelStringId = "SI_BETTERUI_FOOTER_WRITS_LABEL",
        color = "00FF00",
        location = nil
    },
    {
        token = "tradebars",
        labelName = "TradeBarsLabel",
        settingKey = "showCurrencyTradeBars",
        apiConst = TRADE_BARS_ID,
        labelStringId = IS_LEGACY_TICKETS and "SI_BETTERUI_FOOTER_EVENT_TICKETS_LABEL" or
            "SI_BETTERUI_FOOTER_TRADE_BARS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        token = "keys",
        labelName = "KeysLabel",
        settingKey = "showCurrencyUndauntedKeys",
        apiConst = CURT_UNDAUNTED_KEYS,
        labelStringId = "SI_BETTERUI_FOOTER_KEYS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        token = "outfit",
        labelName = "OutfitLabel",
        settingKey = "showCurrencyOutfitTokens",
        apiConst = CURT_STYLE_STONES,
        labelStringId = "SI_BETTERUI_FOOTER_OUTFIT_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT
    },
    {
        token = "seals",
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
        token = "tomepoints",
        labelName = "TomePointsLabel",
        settingKey = "showCurrencyTomePoints",
        apiConst = TOME_POINTS_ID,
        labelStringId = "SI_BETTERUI_FOOTER_TOME_POINTS_LABEL",
        color = "00FF00",
        location = CURRENCY_LOCATION_ACCOUNT,
        useStoredAmount = true
    },
}

-- Build token-to-def lookup table for ordering
BETTERUI.CIM.Currency.TOKEN_TO_DEF = {}
for _, def in ipairs(BETTERUI.CIM.Currency.DEFS) do
    BETTERUI.CIM.Currency.TOKEN_TO_DEF[def.token] = def
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--[[
Function: BETTERUI.CIM.Currency.GetValue
Description: Retrieves the current amount of a currency for display.
Rationale: Different currencies use different APIs - some are character-specific
           (GetPlayerStoredCurrencyAmount) while others are account-wide (GetCurrencyAmount
           with CURRENCY_LOCATION_ACCOUNT). This function abstracts that complexity.
Mechanism: Checks def.useStoredAmount flag first (for Tome Points), then checks
           def.location for account-wide currencies, otherwise uses default GetCurrencyAmount.
param: def (table) - Currency definition from CURRENCY_DEFS containing apiConst, location, useStoredAmount
return: number - The currency amount
]]
function BETTERUI.CIM.Currency.GetValue(def)
    if def.useStoredAmount then
        return GetPlayerStoredCurrencyAmount(def.apiConst)
    elseif def.location then
        return GetCurrencyAmount(def.apiConst, def.location)
    else
        return GetCurrencyAmount(def.apiConst)
    end
end

--[[
Function: BETTERUI.CIM.Currency.FormatLabel
Description: Formats a currency label with localized text, color, value, and icon.
Rationale: Provides consistent formatting across all currency types in the footer.
Mechanism: Retrieves localized label string, gets gamepad currency icon (with keyboard
           fallback), formats via string concatenation with color codes and icon markup.
param: def (table) - Currency definition from CURRENCY_DEFS
param: amount (number) - The currency amount to display
return: string - Formatted label text with color codes and icon
]]
function BETTERUI.CIM.Currency.FormatLabel(def, amount)
    local label = GetString(_G[def.labelStringId])
    -- Fallback: if the _LABEL string ID isn't registered, label will be empty.
    if not label or label == "" then
        label = zo_strupper(def.token) .. ":"
    end

    -- Try gamepad icon first, fall back to keyboard icon.
    local icon = GetCurrencyGamepadIcon(def.apiConst)
    if not icon or icon == "" then
        icon = GetCurrencyKeyboardIcon and GetCurrencyKeyboardIcon(def.apiConst) or ""
    end
    icon = BETTERUI.SafeIcon(icon)

    -- Build label: "LABEL |cCOLORVALUE|r [icon]"
    local valueStr = tostring(BETTERUI.AbbreviateNumber(amount) or "0")
    local formatted = label .. " |c" .. def.color .. valueStr .. "|r"
    if icon ~= "" then
        formatted = formatted .. " |t24:24:" .. icon .. "|t"
    end
    return formatted
end

--[[
Function: BETTERUI.CIM.Currency.GetLabelControl
Description: Retrieves a label control from the footer by name.
Rationale: Footer controls can be accessed either as direct properties or via
           GetNamedChild. This function handles both cases for compatibility.
Mechanism: Tries direct property access first, falls back to GetNamedChild.
param: footer (table) - The footer control object
param: labelName (string) - Name of the label to retrieve
return: control|nil - The label control or nil if not found
]]
--- @param footer table The footer control object
--- @param labelName string Name of the label to retrieve
--- @return Control|nil label The label control or nil
function BETTERUI.CIM.Currency.GetLabelControl(footer, labelName)
    if not footer._controlCache then footer._controlCache = {} end
    if not footer._controlCache[labelName] then
        -- Use global GetControl to resolve $(parent)Suffix naming automatically
        footer._controlCache[labelName] = GetControl(footer, labelName)
    end
    return footer._controlCache[labelName]
end

--[[
Function: BETTERUI.CIM.Currency.UpdateLabels
Description: Updates all currency labels in the footer with current values.
Rationale: Called on refresh to sync footer display with current player currency amounts.
Mechanism: Iterates through CURRENCY_DEFS, checks if API constant exists (for backwards
           compatibility), checks user visibility settings, then formats and sets text.
           Currencies with nil apiConst (e.g., Tome Points on old clients) are hidden.
param: footer (table) - The footer control object
param: invSettings (table) - Inventory settings containing currency visibility flags
return: boolean - True if any labels changed
]]
--- @param footer table The footer control object
--- @param invSettings table Inventory settings containing currency visibility flags
--- @return boolean changed True if any labels changed
function BETTERUI.CIM.Currency.UpdateLabels(footer, invSettings)
    if not footer._valueCache then footer._valueCache = {} end
    local cache = footer._valueCache
    local anyChanged = false
    local DEFS = BETTERUI.CIM.Currency.DEFS
    local GetLabelControl = BETTERUI.CIM.Currency.GetLabelControl
    local GetValue = BETTERUI.CIM.Currency.GetValue
    local FormatLabel = BETTERUI.CIM.Currency.FormatLabel

    for _, def in ipairs(DEFS) do
        local label = GetLabelControl(footer, def.labelName)
        if label then
            local cached = cache[def.token] or {}

            -- Runtime availability check:
            --   API constant missing (e.g. CURT_TOME_POINTS on pre-U49 clients)
            --   means this currency system does not exist on this client.
            local available = def.apiConst ~= nil

            if not available then
                if not label:IsHidden() then
                    label:SetHidden(true)
                    anyChanged = true
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

                    cache[def.token] = { enabled = enabled, amount = val }
                    anyChanged = true
                end
            end
        end
    end
    return anyChanged
end

--[[
Function: BETTERUI.CIM.Currency.GetVisibleOrder
Description: Build ordered list of visible currency definitions based on user settings.
param: invSettings (table) - Inventory settings containing currency order and visibility flags
return: table - Array of visible currency definitions in user-specified order
]]
function BETTERUI.CIM.Currency.GetVisibleOrder(invSettings)
    local orderStr = invSettings.currencyOrder or
        "gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints"
    local seen = {}
    local visible = {}
    local DEFS = BETTERUI.CIM.Currency.DEFS
    local TOKEN_TO_DEF = BETTERUI.CIM.Currency.TOKEN_TO_DEF

    -- First pass: Add enabled tokens found in the order string
    for token in string.gmatch(string.lower(orderStr), "[^,%s]+") do
        local def = TOKEN_TO_DEF[token]
        if def then
            seen[token] = true
            if invSettings[def.settingKey] ~= false then
                table.insert(visible, def)
            end
        end
    end

    -- Second pass: Add any remaining enabled tokens not in order string (fallback)
    for _, def in ipairs(DEFS) do
        if not seen[def.token] then
            if invSettings[def.settingKey] ~= false then
                table.insert(visible, def)
            end
        end
    end

    return visible
end

--[[
Function: BETTERUI.CIM.Currency.PositionLabels
Description: Dynamically positions currency labels in the footer using a proper justified layout.
Rationale:  Different currencies have vastly different text widths (e.g., "AP" vs "CRYSTALS").
            Fixed column widths waste space or cause overlap. A justified layout spreads
            currencies evenly across the *current* footer width, maximizing readability
            and adapting to any combination of selected currencies (4, 8, 12, etc.).
Mechanism:
  1.  Calculates the maximum text width for each column (comparing Row 1 and Row 2).
  2.  Computes available horizontal space (Total Width - Anchors - Padding).
  3.  Determines the necessary gapSize to evenly distribute columns (Space-Between).
  4.  Iterates through columns, setting anchors with the calculated dynamic gap.
param: footer (table) - The footer control object
param: invSettings (table) - Inventory settings containing currency visibility flags
]]
--- @param footer table The footer control object
--- @param invSettings table Inventory settings containing currency visibility flags
function BETTERUI.CIM.Currency.PositionLabels(footer, invSettings)
    local visible = BETTERUI.CIM.Currency.GetVisibleOrder(invSettings)
    local GetLabelControl = BETTERUI.CIM.Currency.GetLabelControl
    local yRows = BETTERUI_CURRENCY_ROWS or { 32, 58, 84 }
    local maxVisible = BETTERUI_MAX_VISIBLE_CURRENCIES or 12

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
