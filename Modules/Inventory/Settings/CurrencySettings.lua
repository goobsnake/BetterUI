--[[
File: Modules/Inventory/Settings/CurrencySettings.lua
Purpose: Manages currency visibility and ordering settings using a data-driven approach.
Last Modified: 2026-01-28
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
        -- Dynamic label handled in Init or access
        labelStr = SI_BETTERUI_CURRENCY_SHOW_TRADE_BARS,
        orderStr = SI_BETTERUI_CURRENCY_ORDER_TRADE_BARS,
        defaultOrder = 9,
        dynamicLabel = true
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
}

local function GetInventorySettings()
    local modules = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
    if not modules then
        return nil
    end
    return modules["Inventory"]
end

local function EnsureInventorySettings()
    if not BETTERUI or not BETTERUI.Settings then
        return nil
    end
    BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
    if type(BETTERUI.Settings.Modules["Inventory"]) ~= "table" then
        BETTERUI.Settings.Modules["Inventory"] = {}
    end
    return BETTERUI.Settings.Modules["Inventory"]
end

-- Resolve dynamic labels
local function GetCurrencyLabel(dataEntry)
    if dataEntry.dynamicLabel and dataEntry.id == "tradebars" then
        if (CURT_TRADE_BARS == nil) and (CURT_EVENT_TICKETS ~= nil) then
            return GetString(SI_BETTERUI_CURRENCY_SHOW_EVENT_TICKETS)
        end
    end
    return GetString(dataEntry.labelStr)
end

local function GetOrderLabel(dataEntry)
    if dataEntry.dynamicLabel and dataEntry.id == "tradebars" then
        if (CURT_TRADE_BARS == nil) and (CURT_EVENT_TICKETS ~= nil) then
            return GetString(SI_BETTERUI_CURRENCY_ORDER_EVENT_TICKETS)
        end
    end
    return GetString(dataEntry.orderStr)
end

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
    local inv = GetInventorySettings()
    if not inv then return false end

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

local function NotifyCurrencyEnableLimitReached()
    local maxVisible = BETTERUI_MAX_VISIBLE_CURRENCIES or 5
    local warningText = zo_strformat(GetString(SI_BETTERUI_CURRENCY_ENABLE_LIMIT_WARNING), maxVisible)
    BETTERUI.Debug(warningText)
    if PlaySound and SOUNDS and SOUNDS.NEGATIVE_CLICK then
        PlaySound(SOUNDS.NEGATIVE_CLICK)
    end
end

local function RecomputeCurrencyOrderString()
    local inv = GetInventorySettings()
    if not inv then return end

    local items = {}
    for _, data in ipairs(CURRENCY_DATA) do
        -- Skip if required global is missing
        if not data.requiredGlobal or _G[data.requiredGlobal] ~= nil then
            local v = tonumber(inv[data.orderKey]) or data.defaultOrder
            if v < 1 then v = 1 elseif v > 12 then v = 12 end
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
    inv.currencyOrder = table.concat(out, ",")
end

--- Applies a currency preset by enabling/disabling specific currencies.
--- @param presetName string The name of the preset ("default", "pvp", "crafter", "events", "custom").
function BETTERUI.ApplyCurrencyPreset(presetName)
    local inv = EnsureInventorySettings()
    if not inv then return end

    -- Use centralized preset definitions from Modules/CIM/Constants.lua
    if BETTERUI.CURRENCY_PRESETS and BETTERUI.CURRENCY_PRESETS[presetName] then
        for k, v in pairs(BETTERUI.CURRENCY_PRESETS[presetName]) do
            inv[k] = v
        end
        return
    end

    -- Fallback handling
    local function SetState(key, state)
        inv[key] = state
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
        GetString(SI_BETTERUI_CURRENCY_POS_1), GetString(SI_BETTERUI_CURRENCY_POS_2),
        GetString(SI_BETTERUI_CURRENCY_POS_3), GetString(SI_BETTERUI_CURRENCY_POS_4),
        GetString(SI_BETTERUI_CURRENCY_POS_5), GetString(SI_BETTERUI_CURRENCY_POS_6),
        GetString(SI_BETTERUI_CURRENCY_POS_7), GetString(SI_BETTERUI_CURRENCY_POS_8),
        GetString(SI_BETTERUI_CURRENCY_POS_9), GetString(SI_BETTERUI_CURRENCY_POS_10),
        GetString(SI_BETTERUI_CURRENCY_POS_11), GetString(SI_BETTERUI_CURRENCY_POS_12),
    }
    local CURRENCY_ORDER_VALUES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

    local controls = {
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
                local settings = GetInventorySettings()
                if not settings then return "custom" end
                return settings.currencyPreset or "custom"
            end,
            setFunc = function(value)
                local settings = EnsureInventorySettings()
                if not settings then
                    return
                end
                settings.currencyPreset = value
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
                        NotifyCurrencyEnableLimitReached()
                        return
                    end
                    settings[data.settingKey] = value
                    settings.currencyPreset = "custom"
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
                    settings[data.orderKey] = value
                    settings.currencyPreset = "custom"
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
        name = GetString(SI_BETTERUI_CURRENCY_RESET),
        tooltip = GetString(SI_BETTERUI_CURRENCY_RESET_TOOLTIP),
        func = function()
            BETTERUI.ApplyCurrencyPreset("default")
            local settings = EnsureInventorySettings()
            if settings then
                settings.currencyPreset = "default"
            end
            RecomputeCurrencyOrderString()
            SafeRefresh(true)
        end,
        width = "half",
    })

    return {
        type = "submenu",
        name = GetString(SI_BETTERUI_CURRENCY_SUBMENU),
        reference = "BETTERUI_Inventory_CurrencyVisibility_Submenu",
        disableAutoSort = true,
        controls = controls,
    }
end
