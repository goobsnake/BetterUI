--[[
File: Modules/CIM/GenericFooter.lua
Purpose: Manages the Gamepad Bottom Bar (Footer) logic.
         Displays bag/bank capacity and various currencies (Gold, AP, Tel Var, etc.).
         Supports dynamic ordering and formatting of currency values.
Author: BetterUI Team
Last Modified: 2026-01-16

REFACTORED: Eliminated code duplication by using shared CURRENCY_DEFS table
            and helper functions for both main and fallback paths.
]]

local _

-- ============================================================================
-- SHARED CURRENCY DEFINITIONS
-- Single source of truth for all currency metadata
-- ============================================================================
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
      apiConst = CURT_TRADE_BARS, labelStringId = "SI_BETTERUI_FOOTER_TRADE_BARS_LABEL", color = "00FF00",
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
      apiConst = CURT_TOME_POINTS, labelStringId = "SI_BETTERUI_FOOTER_TOME_POINTS_LABEL", color = "00FF00",
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

--- Get currency amount using appropriate API based on currency type
local function GetCurrencyValue(def)
    if def.useStoredAmount then
        return GetPlayerStoredCurrencyAmount(def.apiConst)
    elseif def.location then
        return GetCurrencyAmount(def.apiConst, def.location)
    else
        return GetCurrencyAmount(def.apiConst)
    end
end

--- Format currency label text with localized label, color, value, and icon
local function FormatCurrencyLabel(def, amount)
    local label = GetString(_G[def.labelStringId])
    local icon = BETTERUI.SafeIcon(GetCurrencyGamepadIcon(def.apiConst))
    return zo_strformat("<<1>> |c<<2>><<3>>|r |t24:24:<<4>>|t", 
        label, def.color, BETTERUI.AbbreviateNumber(amount), icon)
end

--- Get a label control from the footer (works for both direct property and named child)
local function GetLabelControl(footer, labelName)
    return footer[labelName] or footer:GetNamedChild(labelName)
end

--- Update all currency labels with current values
local function UpdateCurrencyLabels(footer, invSettings)
    for _, def in ipairs(CURRENCY_DEFS) do
        local label = GetLabelControl(footer, def.labelName)
        if label then
            local enabled = invSettings[def.settingKey] ~= false
            label:SetHidden(not enabled)
            if enabled then
                label:SetText(FormatCurrencyLabel(def, GetCurrencyValue(def)))
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

--- Position currency labels based on visibility order (max display limit enforced)
local function PositionCurrencyLabels(footer, invSettings)
    local visible = GetVisibleCurrencyOrder(invSettings)
    local ltrX = BETTERUI_CURRENCY_COLUMNS or {200, 450, 700, 950, 1150}
    local yRows = BETTERUI_CURRENCY_ROWS or {32, 58, 84}
    local maxVisible = BETTERUI_MAX_VISIBLE_CURRENCIES or 10
    local perRow = #ltrX
    
    for idx, def in ipairs(visible) do
        local ctrl = GetLabelControl(footer, def.labelName)
        if ctrl then
            if idx > maxVisible then
                -- Hide currencies beyond the display limit
                ctrl:SetHidden(true)
            else
                ctrl:ClearAnchors()
                local col = ((idx - 1) % perRow) + 1
                local rowIdx = math.ceil(idx / perRow)
                local rowY = yRows[rowIdx] or yRows[1]
                ctrl:SetAnchor(LEFT, footer, BOTTOMLEFT, ltrX[col], rowY)
            end
        end
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
