--[[
File: Modules/CIM/GenericFooter.lua
Purpose: Manages the Gamepad Bottom Bar (Footer) logic.
         Displays bag/bank capacity and various currencies (Gold, AP, Tel Var, etc.).
         Supports dynamic ordering and formatting of currency values.
Author: BetterUI Team
Last Modified: 2026-01-20

REFACTORED: Eliminated code duplication by using shared CURRENCY_DEFS table
            and helper functions for both main and fallback paths.
BACKWARDS COMPATIBILITY: Added support for pre-Update 49 clients where
            CURT_TRADE_BARS (formerly CURT_EVENT_TICKETS) and CURT_TOME_POINTS may not exist.
]]

local _

-- ============================================================================
-- SHARED CURRENCY DEFINITIONS
-- Single source of truth for all currency metadata
-- ============================================================================

-- Backwards Compatibility:
-- "Trade Bars" (Update 49+) used to be "Event Tickets".
-- "Tome Points" are new in Update 49 and may not exist on older clients.
local IS_LEGACY_TICKETS = (CURT_TRADE_BARS == nil) and (CURT_EVENT_TICKETS ~= nil)
local TRADE_BARS_ID = CURT_TRADE_BARS or CURT_EVENT_TICKETS
local TOME_POINTS_ID = CURT_TOME_POINTS -- can be nil

local CURRENCY_DEFS = {
    { token = "gold",      labelName = "GoldLabel",      settingKey = "showCurrencyGold",
      apiConst = CURT_MONEY, labelStringId = "SI_BETTERUI_FOOTER_GOLD_LABEL", color = "FFBF00",
      location = nil },
    { token = "ap",        labelName = "APLabel",        settingKey = "showCurrencyAlliancePoints",
      apiConst = CURT_ALLIANCE_POINTS, labelStringId = "SI_BETTERUI_FOOTER_AP_LABEL", color = "00FF00",
      location = nil },
    { token = "telvar",    labelName = "TVLabel",        settingKey = "showCurrencyTelVar",
      apiConst = CURT_TELVAR_STONES, labelStringId = "SI_BETTERUI_FOOTER_TELVAR_LABEL", color = "00FF00",
      location = nil },
    { token = "gems",      labelName = "GemsLabel",      settingKey = "showCurrencyCrownGems",
      apiConst = CURT_CROWN_GEMS, labelStringId = "SI_BETTERUI_FOOTER_GEMS_LABEL", color = "00FF00",
      location = CURRENCY_LOCATION_ACCOUNT },
    { token = "transmute", labelName = "TCLabel",        settingKey = "showCurrencyTransmute",
      apiConst = CURT_TRANSMUTE_CRYSTALS, labelStringId = "SI_BETTERUI_FOOTER_TRANSMUTE_LABEL", color = "00FF00",
      location = CURRENCY_LOCATION_ACCOUNT },
    { token = "crowns",    labelName = "CrownsLabel",    settingKey = "showCurrencyCrowns",
      apiConst = CURT_CROWNS, labelStringId = "SI_BETTERUI_FOOTER_CROWNS_LABEL", color = "00FF00",
      location = CURRENCY_LOCATION_ACCOUNT },
    { token = "writs",     labelName = "WritsLabel",     settingKey = "showCurrencyWritVouchers",
      apiConst = CURT_WRIT_VOUCHERS, labelStringId = "SI_BETTERUI_FOOTER_WRITS_LABEL", color = "00FF00",
      location = nil },
    { token = "tradebars", labelName = "TradeBarsLabel", settingKey = "showCurrencyTradeBars",
      apiConst = TRADE_BARS_ID, 
      labelStringId = IS_LEGACY_TICKETS and "SI_BETTERUI_FOOTER_EVENT_TICKETS_LABEL" or "SI_BETTERUI_FOOTER_TRADE_BARS_LABEL", 
      color = "00FF00",
      location = CURRENCY_LOCATION_ACCOUNT },
    { token = "keys",      labelName = "KeysLabel",      settingKey = "showCurrencyUndauntedKeys",
      apiConst = CURT_UNDAUNTED_KEYS, labelStringId = "SI_BETTERUI_FOOTER_KEYS_LABEL", color = "00FF00",
      location = CURRENCY_LOCATION_ACCOUNT },
    { token = "outfit",    labelName = "OutfitLabel",    settingKey = "showCurrencyOutfitTokens",
      apiConst = CURT_STYLE_STONES, labelStringId = "SI_BETTERUI_FOOTER_OUTFIT_LABEL", color = "00FF00",
      location = CURRENCY_LOCATION_ACCOUNT },
    { token = "seals",     labelName = "SealsLabel",     settingKey = "showCurrencySeals",
      apiConst = CURT_SEALS, labelStringId = "SI_BETTERUI_FOOTER_SEALS_LABEL", color = "00FF00",
      location = CURRENCY_LOCATION_ACCOUNT },
    -- Note: CURT_TOME_POINTS uses GetPlayerStoredCurrencyAmount instead of GetCurrencyAmount
    -- because Endless Archive currency storage is character-specific, not account-wide
    { token = "tomepoints", labelName = "TomePointsLabel", settingKey = "showCurrencyTomePoints",
      apiConst = TOME_POINTS_ID, labelStringId = "SI_BETTERUI_FOOTER_TOME_POINTS_LABEL", color = "00FF00",
      location = CURRENCY_LOCATION_ACCOUNT,
      useStoredAmount = true },
}

-- Build token-to-def lookup table for ordering
local TOKEN_TO_DEF = {}
for _, def in ipairs(CURRENCY_DEFS) do
    TOKEN_TO_DEF[def.token] = def
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--[[
Function: GetCurrencyValue
Description: Retrieves the current amount of a currency for display.
Rationale: Different currencies use different APIs - some are character-specific
           (GetPlayerStoredCurrencyAmount) while others are account-wide (GetCurrencyAmount
           with CURRENCY_LOCATION_ACCOUNT). This function abstracts that complexity.
Mechanism: Checks def.useStoredAmount flag first (for Tome Points), then checks
           def.location for account-wide currencies, otherwise uses default GetCurrencyAmount.
param: def (table) - Currency definition from CURRENCY_DEFS containing apiConst, location, useStoredAmount
return: number - The currency amount
]]
local function GetCurrencyValue(def)
    if def.useStoredAmount then
        return GetPlayerStoredCurrencyAmount(def.apiConst)
    elseif def.location then
        return GetCurrencyAmount(def.apiConst, def.location)
    else
        return GetCurrencyAmount(def.apiConst)
    end
end

--[[
Function: FormatCurrencyLabel
Description: Formats a currency label with localized text, color, value, and icon.
Rationale: Provides consistent formatting across all currency types in the footer.
Mechanism: Retrieves localized label string, gets currency icon, formats with
           zo_strformat using color codes and icon markup.
param: def (table) - Currency definition from CURRENCY_DEFS
param: amount (number) - The currency amount to display
return: string - Formatted label text with color codes and icon
]]
local function FormatCurrencyLabel(def, amount)
    local label = GetString(_G[def.labelStringId])
    local icon = BETTERUI.SafeIcon(GetCurrencyGamepadIcon(def.apiConst))
    return zo_strformat("<<1>> |c<<2>><<3>>|r |t24:24:<<4>>|t", 
        label, def.color, BETTERUI.AbbreviateNumber(amount), icon)
end

--[[
Function: GetLabelControl
Description: Retrieves a label control from the footer by name.
Rationale: Footer controls can be accessed either as direct properties or via
           GetNamedChild. This function handles both cases for compatibility.
Mechanism: Tries direct property access first, falls back to GetNamedChild.
param: footer (table) - The footer control object
param: labelName (string) - Name of the label to retrieve
return: control|nil - The label control or nil if not found
]]
local function GetLabelControl(footer, labelName)
    return footer[labelName] or footer:GetNamedChild(labelName)
end

--[[
Function: UpdateCurrencyLabels
Description: Updates all currency labels in the footer with current values.
Rationale: Called on refresh to sync footer display with current player currency amounts.
Mechanism: Iterates through CURRENCY_DEFS, checks if API constant exists (for backwards
           compatibility), checks user visibility settings, then formats and sets text.
           Currencies with nil apiConst (e.g., Tome Points on old clients) are hidden.
param: footer (table) - The footer control object
param: invSettings (table) - Inventory settings containing currency visibility flags
return: nil
]]
local function UpdateCurrencyLabels(footer, invSettings)
    for _, def in ipairs(CURRENCY_DEFS) do
        local label = GetLabelControl(footer, def.labelName)
        if label then
            -- If the API constant is missing (e.g. Tome Points on old versions), force hide the label.
            if def.apiConst == nil then
                label:SetHidden(true)
            else
                local enabled = invSettings[def.settingKey] ~= false
                label:SetHidden(not enabled)
                if enabled then
                    label:SetText(FormatCurrencyLabel(def, GetCurrencyValue(def)))
                end
            end
        end
    end
end

--- Build ordered list of visible currency tokens based on user settings
local function GetVisibleCurrencyOrder(invSettings)
    local orderStr = invSettings.currencyOrder or "gold,ap,telvar,keys,transmute,crowns,gems,writs,tradebars,outfit,seals,tomepoints"
    local seen = {}
    local visible = {}
    
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
    for _, def in ipairs(CURRENCY_DEFS) do
        if not seen[def.token] then
            if invSettings[def.settingKey] ~= false then
                table.insert(visible, def)
            end
        end
    end
    
    return visible
end

--[[
Function: PositionCurrencyLabels
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
]]
local function PositionCurrencyLabels(footer, invSettings)
    local visible = GetVisibleCurrencyOrder(invSettings)
    local yRows = BETTERUI_CURRENCY_ROWS or {32, 58, 84}
    local maxVisible = BETTERUI_MAX_VISIBLE_CURRENCIES or 12
    
    -- Hide excess currencies
    for idx, def in ipairs(visible) do
        local ctrl = GetLabelControl(footer, def.labelName)
        if ctrl and idx > maxVisible then
            ctrl:SetHidden(true)
        end
    end

    -- Layout Configuration
    local startX = BETTERUI_FOOTER_START_X                  -- Left anchor position
    local rightPadding = BETTERUI_FOOTER_RIGHT_PADDING             -- Safety buffer from right edge
    local footerWidth = footer:GetWidth()
    
    -- If footer width isn't valid yet (e.g. at startup), default to a standard 1080p width
    if footerWidth <= 0 then footerWidth = 1920 end
    
    local availableWidth = footerWidth - startX - rightPadding
    local numRows = #yRows - 1
    
    local visibleCount = math.min(#visible, maxVisible)
    local numCols = math.ceil(visibleCount / numRows)
    
    -- Phase 1: Measure Columns
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
    
    -- Phase 2: Calculate Spacing (Justify)
    local colGap = 0
    if numCols > 1 then
        local freeSpace = availableWidth - totalTextWidth
        -- Clamp freeSpace to 0 to prevent overlap if content exceeds width
        if freeSpace < 0 then freeSpace = 0 end
        colGap = freeSpace / (numCols - 1)
    end
    
    -- Phase 3: Position Items
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

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--[[
Function: BETTERUI.GenericFooter:Initialize
Description: Initializes the footer control reference.
Rationale: Links the Lua object to the XML control structure defined in GenericFooter.xml.
Mechanism: Finds the 'FooterContainer' child within the main control and caches the reference.
           Triggers an initial refresh if the control is ready.
param: control (table) - The parent control containing the footer.
return: nil
]]
function BETTERUI.GenericFooter:Initialize()
    if(self.footer == nil) then self.footer = self.control.container:GetNamedChild("FooterContainer").footer end

    if(self.footer.GoldLabel ~= nil) then BETTERUI.GenericFooter.Refresh(self) end
end

--[[
Function: BETTERUI.GenericFooter:Refresh
Description: Refreshes the footer content and layout.
Rationale: Updates displayed values (Capacity, Currencies) to reflect current player state.
Mechanism:
  1. Updates Capacity Labels (Backpack and Bank).
  2. Updates Currency Labels using shared CURRENCY_DEFS.
  3. Dynamically positions currency labels based on user-defined order.
References: Called on inventory updates (EVENT_INVENTORY_SINGLE_SLOT_UPDATE) and initialization.
]]
function BETTERUI.GenericFooter:Refresh()
    local invSettings = BETTERUI.Settings.Modules["Inventory"]
    local footer = self.footer
    
    -- Update capacity labels (works for both direct property and named child access)
    local cwLabel = GetLabelControl(footer, "CWLabel")
    local bankLabel = GetLabelControl(footer, "BankLabel")
    
    if cwLabel then
        cwLabel:SetText(zo_strformat("BAG: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", 
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
    end
    
    if bankLabel then
        bankLabel:SetText(zo_strformat("BANK: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", 
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, 
                GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK), 
                GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))
    end
    
    -- Update all currency labels with current values
    UpdateCurrencyLabels(footer, invSettings)
    
    -- Position labels based on user-defined order
    PositionCurrencyLabels(footer, invSettings)
end
