--[[
File: Modules/Inventory/Settings/CurrencySettings.lua
Purpose: Manages currency visibility and ordering settings using a data-driven approach.
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Settings = BETTERUI.Inventory.Settings or {}

-- Central Currency Definition Table
-- Order determines the default display order.
local CURRENCY_DATA = {
    {
        id = "gold",
        settingKey = "showCurrencyGold",
        orderKey = "orderCurrencyGold",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_GOLD,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_GOLD,
        defaultOrder = 1
    },
    {
        id = "ap",
        settingKey = "showCurrencyAlliancePoints",
        orderKey = "orderCurrencyAlliancePoints",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_AP,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_AP,
        defaultOrder = 2
    },
    {
        id = "telvar",
        settingKey = "showCurrencyTelVar",
        orderKey = "orderCurrencyTelVar",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_TELVAR,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_TELVAR,
        defaultOrder = 3
    },
    {
        id = "keys",
        settingKey = "showCurrencyUndauntedKeys",
        orderKey = "orderCurrencyUndauntedKeys",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_KEYS,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_KEYS,
        defaultOrder = 4
    },
    {
        id = "transmute",
        settingKey = "showCurrencyTransmute",
        orderKey = "orderCurrencyTransmute",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_TRANSMUTE,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_TRANSMUTE,
        defaultOrder = 5
    },
    {
        id = "crowns",
        settingKey = "showCurrencyCrowns",
        orderKey = "orderCurrencyCrowns",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_CROWNS,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_CROWNS,
        defaultOrder = 6
    },
    {
        id = "gems",
        settingKey = "showCurrencyCrownGems",
        orderKey = "orderCurrencyCrownGems",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_GEMS,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_GEMS,
        defaultOrder = 7
    },
    {
        id = "writs",
        settingKey = "showCurrencyWritVouchers",
        orderKey = "orderCurrencyWritVouchers",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_WRITS,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_WRITS,
        defaultOrder = 8
    },
    {
        id = "tradebars",
        settingKey = "showCurrencyTradeBars",
        orderKey = "orderCurrencyTradeBars",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_TRADE_BARS,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_TRADE_BARS,
        defaultOrder = 9
    },
    {
        id = "outfit",
        settingKey = "showCurrencyOutfitTokens",
        orderKey = "orderCurrencyOutfitTokens",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_OUTFIT,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_OUTFIT,
        defaultOrder = 10
    },
    {
        id = "seals",
        settingKey = "showCurrencySeals",
        orderKey = "orderCurrencySeals",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_SEALS,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_SEALS,
        defaultOrder = 11
    },
    {
        id = "tomepoints",
        settingKey = "showCurrencyTomePoints",
        orderKey = "orderCurrencyTomePoints",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_TOME_POINTS,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_TOME_POINTS,
        defaultOrder = 12,
        requiredGlobal = "CURT_TOME_POINTS"
    },
    {
        id = "archival",
        settingKey = "showCurrencyArchival",
        orderKey = "orderCurrencyArchival",
        labelStr = SI_BETTERUI_CURRENCY_SHOW_ARCHIVAL,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_ARCHIVAL,
        defaultOrder = 13,
        requiredGlobal = "CURT_ARCHIVAL_FORTUNES"
    },
}

local function GetInventorySettings()
    return BETTERUI.GetModuleSettings("Inventory")
end

local function EnsureInventorySettings()
    return BETTERUI.EnsureModuleSettings("Inventory")
end

local function TraceCurrencySetting(phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Inventory"
    data.feature = "currencySettings"
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.SETTINGS or categories.SETTING or "SETTINGS", "inventory.currency_setting", phase, data)
end

local function SetCurrencySetting(settings, key, value, source)
    if not settings then
        TraceCurrencySetting("set_skipped", {
            key = key,
            newValue = value,
            source = source,
            reason = "missingSettings",
        })
        return false
    end
    local oldValue = settings[key]
    settings[key] = value
    TraceCurrencySetting("set", {
        key = key,
        oldValue = oldValue,
        newValue = value,
        changed = oldValue ~= value,
        source = source,
    })
    return true
end

local function GetCurrencyLabel(dataEntry)
    return GetString(dataEntry.labelStr)
end

local function GetOrderLabel(dataEntry)
    return GetString(dataEntry.orderStr)
end

local function SafeRefresh(headerToo)
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY_ROOT_SCENE and GAMEPAD_INVENTORY_ROOT_SCENE.IsShowing and GAMEPAD_INVENTORY_ROOT_SCENE:IsShowing() then
        if headerToo and GAMEPAD_INVENTORY.RefreshHeader then
            GAMEPAD_INVENTORY:RefreshHeader(true)
        end
        -- Route through RefreshFooter so the shared CIM unified footer controller is used
        -- (Inventory migrated off the legacy GenericFooter singleton); fall back to the
        -- singleton only if the controller path is unavailable.
        if GAMEPAD_INVENTORY.RefreshFooter then
            GAMEPAD_INVENTORY:RefreshFooter()
        elseif BETTERUI and BETTERUI.GenericFooter and BETTERUI.GenericFooter.Refresh then
            BETTERUI.GenericFooter:Refresh()
        end
    end
end

local function CanEnableMoreCurrencies()
    local inv = GetInventorySettings()

    local count = 0
    for _, data in ipairs(CURRENCY_DATA) do
        -- Check if currency is available (global check)
        if not data.requiredGlobal or _G[data.requiredGlobal] ~= nil then
            if inv[data.settingKey] ~= false then
                count = count + 1
            end
        end
    end

    -- Must define explicit limit or assume global constant
    local max = BETTERUI_MAX_VISIBLE_CURRENCIES or 5
    return count < max
end

local function NotifyCurrencyEnableLimitReached(data)
    local maxVisible = BETTERUI_MAX_VISIBLE_CURRENCIES or 5
    local warningText = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_CURRENCY_ENABLE_LIMIT_WARNING")), maxVisible)
    TraceCurrencySetting("change_blocked", {
        currencyId = data and data.currencyId,
        settingKey = data and data.settingKey,
        attemptedValue = data and data.attemptedValue,
        maxVisible = maxVisible,
        reason = "visibleLimitReached",
    })
    BETTERUI.Debug(warningText)
    if PlaySound and SOUNDS and SOUNDS.NEGATIVE_CLICK then
        PlaySound(SOUNDS.NEGATIVE_CLICK)
    end
end

local function RecomputeCurrencyOrderString()
    local inv = GetInventorySettings()

    local items = {}
    for _, data in ipairs(CURRENCY_DATA) do
        -- Skip if required global is missing
        if not data.requiredGlobal or _G[data.requiredGlobal] ~= nil then
            local v = tonumber(inv[data.orderKey]) or data.defaultOrder
            if v < 1 then v = 1 elseif v > 13 then v = 13 end
            table.insert(items, { key = data.id, order = v, tiebreak = data.defaultOrder })
        end
    end

    table.sort(items, function(a, b)
        if a.order == b.order then
            return a.tiebreak < b.tiebreak
        end
        return a.order < b.order
    end)

    local out = {}
    for i = 1, #items do out[i] = items[i].key end
    SetCurrencySetting(inv, "currencyOrder", table.concat(out, ","), "orderRecompute")
end

--- Applies a currency preset by enabling/disabling specific currencies.
function BETTERUI.ApplyCurrencyPreset(presetName)
    local inv = EnsureInventorySettings()
    if not inv then return end

    -- Use centralized preset definitions from Modules/CIM/Constants.lua
    if BETTERUI.CURRENCY_PRESETS and BETTERUI.CURRENCY_PRESETS[presetName] then
        local applied = 0
        TraceCurrencySetting("preset_begin", { preset = presetName, knownPreset = true })
        for k, v in pairs(BETTERUI.CURRENCY_PRESETS[presetName]) do
            if SetCurrencySetting(inv, k, v, "preset:" .. tostring(presetName)) then
                applied = applied + 1
            end
        end
        TraceCurrencySetting("preset_end", { preset = presetName, knownPreset = true, applied = applied })
        return
    end
    TraceCurrencySetting("preset_begin", { preset = presetName, knownPreset = false })

    -- Fallback handling
    local function SetState(key, state)
        SetCurrencySetting(inv, key, state, "preset:" .. tostring(presetName))
    end

    -- Default all to ON (true)
    if presetName == "default" then
        for _, data in ipairs(CURRENCY_DATA) do
            SetState(data.settingKey, true)
        end
    elseif presetName == "pvp" then
        -- Gold, AP, TelVar, Transmute
        for _, data in ipairs(CURRENCY_DATA) do
            local on = (data.id == "gold" or data.id == "ap" or data.id == "telvar" or data.id == "transmute")
            SetState(data.settingKey, on)
        end
    end
end

--- Returns the LAM control for Currency Submenu.
function BETTERUI.Inventory.Settings.GetCurrencyOptions()
    local CURRENCY_ORDER_CHOICES = {
        GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_1")), GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_2")),
        GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_3")), GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_4")),
        GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_5")), GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_6")),
        GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_7")), GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_8")),
        GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_9")), GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_10")),
        GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_11")), GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_12")),
        GetString(rawget(_G, "SI_BETTERUI_CURRENCY_POS_13")),
    }
    local CURRENCY_ORDER_VALUES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }

    local controls = {
        {
            type = "description",
            text = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_DESC")),
            width = "full",
        },
        {
            type = "dropdown",
            name = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_PRESET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_PRESET_TOOLTIP")),
            choices = {
                GetString(rawget(_G, "SI_BETTERUI_CURRENCY_PRESET_DEFAULT")),
                GetString(rawget(_G, "SI_BETTERUI_CURRENCY_PRESET_PVP")),
                GetString(rawget(_G, "SI_BETTERUI_CURRENCY_PRESET_CRAFTER")),
                GetString(rawget(_G, "SI_BETTERUI_CURRENCY_PRESET_EVENTS")),
                GetString(rawget(_G, "SI_BETTERUI_CURRENCY_PRESET_CUSTOM")),
            },
            choicesValues = { "default", "pvp", "crafter", "events", "custom" },
            getFunc = function()
                local settings = GetInventorySettings()
                if not settings then return "custom" end
                return settings.currencyPreset or "custom"
            end,
            setFunc = function(value)
                local settings = EnsureInventorySettings()
                if not settings then
                    return
                end
                SetCurrencySetting(settings, "currencyPreset", value, "presetDropdown")
                BETTERUI.ApplyCurrencyPreset(value)
                RecomputeCurrencyOrderString()
                SafeRefresh(true)
            end,
            width = "full",
            scrollable = true,
        },
        {
            type = "divider",
            width = "full",
        }
    }

    -- Generated Controls
    for _, data in ipairs(CURRENCY_DATA) do
        -- If required global is missing, skip control generation
        if not data.requiredGlobal or _G[data.requiredGlobal] ~= nil then
            -- Checkbox
            table.insert(controls, {
                type = "checkbox",
                name = GetCurrencyLabel(data),
                getFunc = function()
                    local settings = GetInventorySettings()
                    if not settings then
                        return data.id ~= "seals" and
                            data.id ~= "tomepoints"
                    end -- defaults logic
                    -- Default behavior if nil is usually true, except for newer currencies maybe?
                    -- In original code, 'getFunc' returned 'inv[k] ~= false' which implies default true.
                    -- Except 'Seals' and 'TomePoints' returned '== true' which implies default false.
                    if data.id == "seals" or data.id == "tomepoints" then
                        return settings[data.settingKey] == true
                    else
                        return settings[data.settingKey] ~= false
                    end
                end,
                setFunc = function(value)
                    local settings = EnsureInventorySettings()
                    if not settings then
                        return
                    end
                    if value and not CanEnableMoreCurrencies() then
                        NotifyCurrencyEnableLimitReached({
                            currencyId = data.id,
                            settingKey = data.settingKey,
                            attemptedValue = value,
                        })
                        return
                    end
                    SetCurrencySetting(settings, data.settingKey, value, "currencyToggle")
                    SetCurrencySetting(settings, "currencyPreset", "custom", "currencyToggle")
                    SafeRefresh(true)
                end,
                width = "half",
            })

            -- Order Dropdown
            table.insert(controls, {
                type = "dropdown",
                name = GetOrderLabel(data),
                choices = CURRENCY_ORDER_CHOICES,
                choicesValues = CURRENCY_ORDER_VALUES,
                disabled = function()
                    local settings = GetInventorySettings()
                    if not settings then
                        return true
                    end
                    local val = settings[data.settingKey]
                    if data.id == "seals" or data.id == "tomepoints" then
                        return val ~= true
                    else
                        return val == false
                    end
                end,
                getFunc = function()
                    local settings = GetInventorySettings()
                    if not settings then return data.defaultOrder end
                    return (settings[data.orderKey] or data.defaultOrder)
                end,
                setFunc = function(value)
                    local settings = EnsureInventorySettings()
                    if not settings then
                        return
                    end
                    SetCurrencySetting(settings, data.orderKey, value, "currencyOrder")
                    SetCurrencySetting(settings, "currencyPreset", "custom", "currencyOrder")
                    RecomputeCurrencyOrderString()
                    SafeRefresh(true)
                end,
                width = "half",
            })
        end
    end

    -- Append Reset
    table.insert(controls, {
        type = "divider",
        width = "full",
    })
    table.insert(controls, {
        type = "button",
        name = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_RESET")),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_RESET_TOOLTIP")),
        func = function()
            BETTERUI.ApplyCurrencyPreset("default")
            local settings = EnsureInventorySettings()
            if settings then
                SetCurrencySetting(settings, "currencyPreset", "default", "currencyReset")
            end
            RecomputeCurrencyOrderString()
            SafeRefresh(true)
        end,
        width = "half",
    })

    return {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_SUBMENU")),
        reference = "BETTERUI_Inventory_CurrencyVisibility_Submenu",
        disableAutoSort = true,
        controls = controls,
    }
end
