--[[
File: Modules/Inventory/Settings/CurrencySettings.lua
Purpose: Manages currency visibility and ordering settings.
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Settings = BETTERUI.Inventory.Settings or {}

local function SafeRefresh(headerToo)
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY_ROOT_SCENE and GAMEPAD_INVENTORY_ROOT_SCENE.IsShowing and GAMEPAD_INVENTORY_ROOT_SCENE:IsShowing() then
        if headerToo and GAMEPAD_INVENTORY.RefreshHeader then
            GAMEPAD_INVENTORY:RefreshHeader(true)
        end
        if BETTERUI and BETTERUI.GenericFooter and BETTERUI.GenericFooter.Refresh then
            BETTERUI.GenericFooter:Refresh()
        end
    end
end

local function CanEnableMoreCurrencies()
    local inv = BETTERUI.Settings.Modules["Inventory"]
    if not inv then return false end
    local keys = {
        "showCurrencyGold", "showCurrencyAlliancePoints", "showCurrencyTelVar",
        "showCurrencyUndauntedKeys", "showCurrencyTransmute", "showCurrencyCrowns",
        "showCurrencyCrownGems", "showCurrencyWritVouchers", "showCurrencyTradeBars",
        "showCurrencyOutfitTokens", "showCurrencySeals", "showCurrencyTomePoints"
    }
    local count = 0
    for _, k in ipairs(keys) do
        if inv[k] ~= false then count = count + 1 end
    end
    -- Must define explicit limit or assume global constant
    local max = BETTERUI_MAX_VISIBLE_CURRENCIES or 5
    return count < max
end

local function RecomputeCurrencyOrderString()
    local inv = BETTERUI.Settings.Modules["Inventory"]
    if not inv then return end
    local defaultsOrderIdx = {
        gold = 1,
        ap = 2,
        telvar = 3,
        keys = 4,
        transmute = 5,
        crowns = 6,
        gems = 7,
        writs = 8,
        tradebars = 9,
        outfit = 10,
        seals = 11,
        tomepoints = 12,
    }
    local map = {
        { key = "gold",       orderKey = "orderCurrencyGold" },
        { key = "ap",         orderKey = "orderCurrencyAlliancePoints" },
        { key = "telvar",     orderKey = "orderCurrencyTelVar" },
        { key = "keys",       orderKey = "orderCurrencyUndauntedKeys" },
        { key = "transmute",  orderKey = "orderCurrencyTransmute" },
        { key = "crowns",     orderKey = "orderCurrencyCrowns" },
        { key = "gems",       orderKey = "orderCurrencyCrownGems" },
        { key = "writs",      orderKey = "orderCurrencyWritVouchers" },
        { key = "tradebars",  orderKey = "orderCurrencyTradeBars" },
        { key = "outfit",     orderKey = "orderCurrencyOutfitTokens" },
        { key = "seals",      orderKey = "orderCurrencySeals" },
        { key = "tomepoints", orderKey = "orderCurrencyTomePoints" },
    }
    local items = {}
    for _, m in ipairs(map) do
        local v = tonumber(inv[m.orderKey]) or defaultsOrderIdx[m.key]
        if v < 1 then v = 1 elseif v > 12 then v = 12 end
        table.insert(items, { key = m.key, order = v, tiebreak = defaultsOrderIdx[m.key] })
    end
    table.sort(items, function(a, b)
        if a.order == b.order then
            return a.tiebreak < b.tiebreak
        end
        return a.order < b.order
    end)
    local out = {}
    for i = 1, #items do out[i] = items[i].key end
    inv.currencyOrder = table.concat(out, ",")
end

--- Applies a currency preset by enabling/disabling specific currencies.
--- @param presetName string The name of the preset ("default", "pvp", "crafter", "events", "custom").
function BETTERUI.ApplyCurrencyPreset(presetName)
    local inv = BETTERUI.Settings.Modules["Inventory"]
    if not inv then return end

    -- Use centralized preset definitions from Modules/CIM/Constants.lua
    if BETTERUI.CURRENCY_PRESETS and BETTERUI.CURRENCY_PRESETS[presetName] then
        for k, v in pairs(BETTERUI.CURRENCY_PRESETS[presetName]) do
            inv[k] = v
        end
        return
    end

    -- Fallback handling (if constants missing)
    local function Set(gold, ap, telvar, keys, transmute, crowns, gems, writs, tradebars, outfit, seals, tome)
        inv.showCurrencyGold = gold
        inv.showCurrencyAlliancePoints = ap
        inv.showCurrencyTelVar = telvar
        inv.showCurrencyUndauntedKeys = keys
        inv.showCurrencyTransmute = transmute
        inv.showCurrencyCrowns = crowns
        inv.showCurrencyCrownGems = gems
        inv.showCurrencyWritVouchers = writs
        inv.showCurrencyTradeBars = tradebars
        inv.showCurrencyOutfitTokens = outfit
        inv.showCurrencySeals = seals
        inv.showCurrencyTomePoints = tome
    end

    if presetName == "default" then
        -- Default: All ON (matches Constants.lua)
        Set(true, true, true, true, true, true, true, true, true, true, true, true)
    elseif presetName == "pvp" then
        Set(true, true, true, false, true, false, false, false, false, false, false, false)
    end
end

--- Returns the LAM control for Currency Submenu.
function BETTERUI.Inventory.Settings.GetCurrencyOptions()
    local CURRENCY_ORDER_CHOICES = {
        GetString(SI_BETTERUI_CURRENCY_POS_1), GetString(SI_BETTERUI_CURRENCY_POS_2),
        GetString(SI_BETTERUI_CURRENCY_POS_3), GetString(SI_BETTERUI_CURRENCY_POS_4),
        GetString(SI_BETTERUI_CURRENCY_POS_5), GetString(SI_BETTERUI_CURRENCY_POS_6),
        GetString(SI_BETTERUI_CURRENCY_POS_7), GetString(SI_BETTERUI_CURRENCY_POS_8),
        GetString(SI_BETTERUI_CURRENCY_POS_9), GetString(SI_BETTERUI_CURRENCY_POS_10),
        GetString(SI_BETTERUI_CURRENCY_POS_11), GetString(SI_BETTERUI_CURRENCY_POS_12),
    }
    local CURRENCY_ORDER_VALUES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

    local submenu = {
        type = "submenu",
        name = GetString(SI_BETTERUI_CURRENCY_SUBMENU),
        reference = "BETTERUI_Inventory_CurrencyVisibility_Submenu",
        controls = {
            {
                type = "description",
                text = GetString(SI_BETTERUI_CURRENCY_DESC),
                width = "full",
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_PRESET),
                tooltip = GetString(SI_BETTERUI_CURRENCY_PRESET_TOOLTIP),
                choices = {
                    GetString(SI_BETTERUI_CURRENCY_PRESET_DEFAULT),
                    GetString(SI_BETTERUI_CURRENCY_PRESET_PVP),
                    GetString(SI_BETTERUI_CURRENCY_PRESET_CRAFTER),
                    GetString(SI_BETTERUI_CURRENCY_PRESET_EVENTS),
                    GetString(SI_BETTERUI_CURRENCY_PRESET_CUSTOM),
                },
                choicesValues = { "default", "pvp", "crafter", "events", "custom" },
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return "custom" end
                    return BETTERUI.Settings.Modules["Inventory"].currencyPreset or "custom"
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = value
                    BETTERUI.ApplyCurrencyPreset(value)
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "full",
                scrollable = true,
                requiresReload = true,
            },
            {
                type = "divider",
                width = "full",
            },
            -- Gold
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_GOLD),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyGold ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyGold = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_GOLD),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyGold == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 1 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyGold or 1)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyGold = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- AP
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_AP),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_AP),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyAlliancePoints == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 2 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyAlliancePoints or 2)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyAlliancePoints = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Tel Var
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_TELVAR),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_TELVAR),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyTelVar == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 3 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTelVar or 3)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyTelVar = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Undaunted Keys
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_KEYS),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_KEYS),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyUndauntedKeys == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 4 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyUndauntedKeys or 4)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyUndauntedKeys = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Transmute
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_TRANSMUTE),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_TRANSMUTE),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyTransmute == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 5 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTransmute or 5)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyTransmute = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Crowns
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_CROWNS),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_CROWNS),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrowns == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 6 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrowns or 6)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrowns = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Crown Gems
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_GEMS),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_GEMS),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyCrownGems == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 7 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrownGems or 7)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyCrownGems = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Writ Vouchers
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_WRITS),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_WRITS),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyWritVouchers == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 8 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyWritVouchers or 8)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyWritVouchers = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Trade Bars
            {
                type = "checkbox",
                name = ((CURT_TRADE_BARS == nil) and (CURT_EVENT_TICKETS ~= nil)) and
                    GetString(SI_BETTERUI_CURRENCY_SHOW_EVENT_TICKETS) or
                    GetString(SI_BETTERUI_CURRENCY_SHOW_TRADE_BARS),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyTradeBars ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyTradeBars = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = ((CURT_TRADE_BARS == nil) and (CURT_EVENT_TICKETS ~= nil)) and
                    GetString(SI_BETTERUI_CURRENCY_ORDER_EVENT_TICKETS) or
                    GetString(SI_BETTERUI_CURRENCY_ORDER_TRADE_BARS),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyTradeBars == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 9 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTradeBars or 9)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyTradeBars = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Outfit Tokens
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_OUTFIT),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return true end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens ~= false
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_OUTFIT),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencyOutfitTokens == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 10 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyOutfitTokens or 10)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencyOutfitTokens = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Seals
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_CURRENCY_SHOW_SEALS),
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return false end
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencySeals == true
                end,
                setFunc = function(value)
                    if value and not CanEnableMoreCurrencies() then return end
                    BETTERUI.Settings.Modules["Inventory"].showCurrencySeals = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            {
                type = "dropdown",
                name = GetString(SI_BETTERUI_CURRENCY_ORDER_SEALS),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    return BETTERUI.Settings.Modules["Inventory"].showCurrencySeals == false
                end,
                getFunc = function()
                    if not BETTERUI.Settings.Modules["Inventory"] then return 11 end
                    return (BETTERUI.Settings.Modules["Inventory"].orderCurrencySeals or 11)
                end,
                setFunc = function(value)
                    BETTERUI.Settings.Modules["Inventory"].orderCurrencySeals = value
                    BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
                requiresReload = true,
            },
            -- Tome Points dynamic append
            -- (Moved out of separate if-block to be inline, or inserted before Reset)
            -- We will dynamic insert here using a marker?
            -- Actually, simpler to just use table.insert at calculation time if we want to support dynamic availability.
            -- But we can structure it:
            -- ... Seals ...
            -- ... TomePoints ... (Conditionally added)
            -- ... Divider ...
            -- ... Reset ...
        },
    }

    -- Tome Points dynamic append (Before Divider/Reset)
    -- Reset is last. Divider is second to last.
    if CURT_TOME_POINTS ~= nil then
        local controls = submenu.controls
        local insertIndex = #controls -- Before the Divider (which is #controls - 1, and Reset is #controls)
        -- Actually, current table ends with Reset. Index N. Divider is N-1.
        -- We want to insert before Divider. So at index N-1.
        -- Wait, lets check indices.
        -- ... Seals (2 controls)
        -- Divider (Index N-1)
        -- Reset (Index N)
        local dividerIndex = #controls - 1

        table.insert(controls, dividerIndex, {
            type = "checkbox",
            name = GetString(SI_BETTERUI_CURRENCY_SHOW_TOME_POINTS),
            getFunc = function()
                if not BETTERUI.Settings.Modules["Inventory"] then return false end
                return BETTERUI.Settings.Modules["Inventory"].showCurrencyTomePoints == true
            end,
            setFunc = function(value)
                if value and not CanEnableMoreCurrencies() then return end
                BETTERUI.Settings.Modules["Inventory"].showCurrencyTomePoints = value
                BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                SafeRefresh(true)
            end,
            width = "half",
            requiresReload = true,
        })
        -- Divider moved to N. Reset to N+1.
        -- Insert Dropdown at dividerIndex + 1
        table.insert(controls, dividerIndex + 1, {
            type = "dropdown",
            name = GetString(SI_BETTERUI_CURRENCY_ORDER_TOME_POINTS),
            choices = CURRENCY_ORDER_CHOICES,
            choicesValues = CURRENCY_ORDER_VALUES,
            disabled = function()
                return BETTERUI.Settings.Modules["Inventory"].showCurrencyTomePoints ~= true
            end,
            getFunc = function()
                if not BETTERUI.Settings.Modules["Inventory"] then return 12 end
                return (BETTERUI.Settings.Modules["Inventory"].orderCurrencyTomePoints or 12)
            end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["Inventory"].orderCurrencyTomePoints = value
                BETTERUI.Settings.Modules["Inventory"].currencyPreset = "custom"
                RecomputeCurrencyOrderString()
                SafeRefresh(true)
            end,
            width = "half",
            requiresReload = true,
        })
    end

    -- Ensure Divider/Reset are at the end
    local controls = submenu.controls
    table.insert(controls, {
        type = "divider",
        width = "full",
    })
    table.insert(controls, {
        type = "button",
        name = GetString(SI_BETTERUI_CURRENCY_RESET),
        tooltip = GetString(SI_BETTERUI_CURRENCY_RESET_TOOLTIP),
        func = function()
            BETTERUI.ApplyCurrencyPreset("default")
            BETTERUI.Settings.Modules["Inventory"].currencyPreset = "default"
            RecomputeCurrencyOrderString()
            SafeRefresh(true)
        end,
        width = "half",
    })

    -- Note: I removed the Divider/Reset from the initial table definition to append them here.
    -- This logic assumes I edit the `controls` table definition above to remove them.
    -- Let's do that in the write.

    return submenu
end
