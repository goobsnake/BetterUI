--[[
File: Modules/TradingHouse/Core/PriceEntry.lua
Purpose: Digit-entry price helpers for Trading House create-listing (TRC-004).

ClampListingPrice is pure and unit-testable. ShowDigitPriceDialog wires the
native ZO_CurrencySelector_Gamepad digit spinner as a first-cut alternative to
the coarse price slider for large price ranges.
]]

local TH = BETTERUI.TradingHouse

TH.PriceEntry = {}
local PriceEntry = TH.PriceEntry

local function TracePriceEntry(event, phase, data, category)
    if type(TH.Trace) == "function" then
        data = data or {}
        data.feature = data.feature or "trading-house-price-entry"
        data.fn = data.fn or "TradingHouse.PriceEntry"
        TH.Trace(category or (BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG), event, phase, TH.instance, data)
    end
end

local function SafeGetString(stringIdName, fallback)
    local stringId = rawget(_G, stringIdName)
    if stringId ~= nil and type(GetString) == "function" then
        local text = GetString(stringId)
        if text and text ~= "" then
            return text
        end
    end
    return fallback or stringIdName
end

local function GetListControl(thInstance)
    local list = thInstance and thInstance.list
    if list and list.control then
        return list.control
    end
    local container = thInstance and thInstance.control and thInstance.control.GetNamedChild
        and thInstance.control:GetNamedChild("Container") or nil
    return container and container.GetNamedChild and container:GetNamedChild("List") or nil
end

local function FormatColumnNumber(value)
    value = math.floor(tonumber(value) or 0)
    if BETTERUI and BETTERUI.FormatAbbreviatedNumber then
        return BETTERUI.FormatAbbreviatedNumber(value)
    end
    if BETTERUI and BETTERUI.DisplayNumber then
        return BETTERUI.DisplayNumber(value)
    end
    if type(ZO_CommaDelimitNumber) == "function" then
        return ZO_CommaDelimitNumber(value)
    end
    return tostring(value)
end

function TH.FormatTradingHouseColumnCurrency(value)
    value = math.floor(tonumber(value) or 0)
    if type(ZO_Currency_FormatGamepad) == "function" and CURT_MONEY and ZO_CURRENCY_FORMAT_AMOUNT_ICON then
        return ZO_Currency_FormatGamepad(CURT_MONEY, value, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
    end
    return "|t16:16:esoui/art/currency/currency_gold_32.dds|t " .. FormatColumnNumber(value)
end

function TH.FormatTradingHouseColumnUnitPrice(totalPrice, quantity)
    quantity = tonumber(quantity) or 0
    if quantity <= 0 then
        return "-"
    end
    return TH.FormatTradingHouseColumnCurrency(math.floor((tonumber(totalPrice) or 0) / quantity))
end

function TH.FormatTradingHouseListingTimeRemaining(timeRemaining)
    timeRemaining = math.max(0, math.floor(tonumber(timeRemaining) or 0))
    local days = math.floor(timeRemaining / 86400)
    if days > 0 then
        return tostring(days) .. "d"
    end
    local hours = math.floor(timeRemaining / 3600)
    if hours > 0 then
        return tostring(hours) .. "h"
    end
    local minutes = math.floor(timeRemaining / 60)
    if minutes > 0 then
        return tostring(minutes) .. "m"
    end
    return tostring(timeRemaining) .. "s"
end

function TH.GetTradingHouseNoPermissionText()
    return SafeGetString("SI_TRADING_HOUSE_POSTING_LOCKED_NOT_A_GUILD_MEMBER",
        "No Permission (You are not a member of this Guild)")
end

function TH.ResolveSelectedTradingHouseGuildDetails()
    local selectedGuildId = type(GetSelectedTradingHouseGuildId) == "function"
        and GetSelectedTradingHouseGuildId() or nil
    local numGuilds = type(GetNumTradingHouseGuilds) == "function" and (GetNumTradingHouseGuilds() or 0) or 0
    if type(GetTradingHouseGuildDetails) == "function" then
        for i = 1, numGuilds do
            local guildId, guildName = GetTradingHouseGuildDetails(i)
            if guildId and (selectedGuildId == nil or guildId == selectedGuildId) then
                return guildId, guildName, i
            end
        end
    end
    if selectedGuildId then
        local guildName = type(GetGuildName) == "function" and GetGuildName(selectedGuildId) or nil
        return selectedGuildId, guildName, nil
    end
    return nil, nil, nil
end

function TH.IsTradingHouseSellPermittedForCurrentGuild()
    local guildId, guildName, guildIndex = TH.ResolveSelectedTradingHouseGuildDetails()
    if type(CanSellOnTradingHouse) ~= "function" or not guildId then
        return true, guildId, guildName, guildIndex
    end
    return CanSellOnTradingHouse(guildId) == true, guildId, guildName, guildIndex
end

function TH.SetTradingHouseSectionHeaders(thInstance, labels)
    local columns = thInstance and thInstance.header and thInstance.header.columns
    if type(columns) ~= "table" then
        return false
    end
    if not thInstance._betteruiTHDefaultColumnHeaders then
        thInstance._betteruiTHDefaultColumnHeaders = {}
        for i, label in ipairs(columns) do
            thInstance._betteruiTHDefaultColumnHeaders[i] =
                label and label.GetText and label:GetText() or nil
        end
    end
    local header = thInstance and thInstance.header
    local anchor = header and header.GetNamedChild
        and (header:GetNamedChild("HeaderColumnBar") or header:GetNamedChild("HeaderTabBar")) or nil
    local layout = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.LAYOUT
    local rowColumns = layout and layout.COLUMNS or nil
    local nameOffset = rowColumns and rowColumns.SUBMENU and rowColumns.SUBMENU.OFFSET_X or 70
    local offsets = {
        nameOffset,
        nameOffset + (rowColumns and rowColumns.TYPE and rowColumns.TYPE.OFFSET_X or 513),
        nameOffset + (rowColumns and rowColumns.TRAIT and rowColumns.TRAIT.OFFSET_X or 773),
        nameOffset + (rowColumns and rowColumns.STAT and rowColumns.STAT.OFFSET_X or 963),
        nameOffset + (rowColumns and rowColumns.VALUE and rowColumns.VALUE.OFFSET_X or 1113),
    }
    local widths = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.LAYOUT
        and BETTERUI.CIM.CONST.LAYOUT.COLUMN_WIDTHS or nil
    local offsetY = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.LAYOUT
        and BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET or 109
    for i, label in ipairs(columns) do
        local spec = labels and labels[i] or nil
        local text = type(spec) == "table" and spec.text or spec
        local columnOffset = type(spec) == "table" and spec.offset or offsets[i]
        local columnWidth = type(spec) == "table" and spec.width or (widths and widths[i])
        if label and anchor and label.ClearAnchors and label.SetAnchor then
            label:ClearAnchors()
            label:SetAnchor(LEFT, anchor, BOTTOMLEFT, columnOffset, offsetY)
        end
        if label and columnWidth and label.SetDimensions then
            label:SetDimensions(columnWidth, 30)
        end
        if label and label.SetText then
            label:SetText(text or "")
        end
        if label and label.SetHidden then
            label:SetHidden(text == nil or text == "")
        end
        if label and label.SetHorizontalAlignment then
            label:SetHorizontalAlignment(type(spec) == "table" and spec.align or TEXT_ALIGN_LEFT)
        end
    end
    return true
end

function TH.RestoreTradingHouseSectionHeaders(thInstance)
    local defaults = thInstance and thInstance._betteruiTHDefaultColumnHeaders
    local columns = thInstance and thInstance.header and thInstance.header.columns
    if type(defaults) ~= "table" or type(columns) ~= "table" then
        return false
    end
    for i, label in ipairs(columns) do
        if label and label.SetText then
            label:SetText(defaults[i] or "")
        end
        if label and label.SetHidden then
            label:SetHidden(false)
        end
        if label and label.SetHorizontalAlignment then
            label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
    end
    return true
end

function TH.SetTradingHousePermissionMessage(thInstance, visible, text)
    local listControl = GetListControl(thInstance)
    if listControl and listControl.SetHidden then
        listControl:SetHidden(visible == true)
    end

    local parent = thInstance and thInstance.control
    if parent and parent.GetNamedChild then
        parent = parent:GetNamedChild("Container") or parent
    end
    if not (parent and parent.GetNamedChild) then
        return false
    end

    local label = thInstance._betteruiTHPermissionLabel
    if not label then
        local wm = WINDOW_MANAGER or BETTERUI.WindowManager
        if not (wm and wm.CreateControl) then
            return false
        end
        label = wm:CreateControl("BETTERUI_THNoPermissionMessage", parent, CT_LABEL)
        label:SetFont("ZoFontGamepad34")
        label:SetColor(1, 1, 1, 0.85)
        label:SetHorizontalAlignment(CENTER)
        label:SetVerticalAlignment(CENTER)
        label:SetDimensions(900, 140)
        label:ClearAnchors()
        label:SetAnchor(CENTER, listControl or parent, CENTER, 0, 0)
        thInstance._betteruiTHPermissionLabel = label
    end

    if label.SetText then
        label:SetText(text or TH.GetTradingHouseNoPermissionText())
    end
    if label.SetHidden then
        label:SetHidden(visible ~= true)
    end
    return true
end

local function GetBuiRowChild(control, name)
    local cache = control and control._buiChildCache
    if not cache and control then
        cache = {}
        control._buiChildCache = cache
    end
    if not cache then return nil end
    if cache[name] == nil then
        cache[name] = control.GetNamedChild and control:GetNamedChild(name) or false
    end
    return cache[name] or nil
end

local function ApplyColumnText(control, childName, text, align)
    local child = GetBuiRowChild(control, childName)
    if not child then return end
    if child.SetText then child:SetText(text or "") end
    -- SetHorizontalAlignment consumes TEXT_ALIGN_* values, not anchor-point
    -- constants such as RIGHT.
    if align == RIGHT then
        align = TEXT_ALIGN_RIGHT
    elseif align == LEFT then
        align = TEXT_ALIGN_LEFT
    end
    if child.SetHorizontalAlignment then
        child:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    end
    if child.SetColor then child:SetColor(1, 1, 1, 1) end
end

local SELL_ROW_COLUMNS = {
    ItemType = { offset = 450, width = 100 },
    Trait = { offset = 795, width = 180 },
    Value = { offset = 1050, width = 100 },
}

local function ApplySellColumnGeometry(control)
    local label = GetBuiRowChild(control, "Label")
    if not label then return end
    for childName, geometry in pairs(SELL_ROW_COLUMNS) do
        local child = GetBuiRowChild(control, childName)
        if child and child.ClearAnchors and child.SetAnchor then
            child:ClearAnchors()
            child:SetAnchor(LEFT, label, LEFT, geometry.offset, 0)
        end
        if child and child.SetWidth then
            child:SetWidth(geometry.width)
        end
    end
end

function TH.InstallTradingHouseSectionRowSetup()
    if TH._betteruiSectionRowSetupInstalled then
        return true
    end
    local originalSetup = TH.THEntrySetup
    if type(originalSetup) ~= "function" then
        return false
    end
    TH.THEntrySetup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
        originalSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
        local ds = data and (data.dataSource or data) or nil
        if not (ds and ds.thColumnMode) then
            return
        end

        if ds.thColumnMode == "sell" then
            ApplySellColumnGeometry(control)
        end

        -- Section rows reuse the inventory template but need TH-specific value columns.
        ApplyColumnText(control, "ItemType", ds.thColumn1Text or "", ds.thColumn1Align or TEXT_ALIGN_RIGHT)
        ApplyColumnText(control, "Trait", ds.thUnitText or "", TEXT_ALIGN_RIGHT)
        ApplyColumnText(control, "Stat", ds.thSpacerText or "", TEXT_ALIGN_RIGHT)
        ApplyColumnText(control, "Value", ds.thTotalText or "", TEXT_ALIGN_RIGHT)
    end
    TH._betteruiSectionRowSetupInstalled = true
    TracePriceEntry("trading_house.section_row_setup", "installed", {
        fn = "TradingHouse.InstallTradingHouseSectionRowSetup",
    })
    return true
end

TH.InstallTradingHouseSectionRowSetup()

-- PURE HELPERS ----------------------------------------------------------------

--- Clamp and sanitize a listing price to an integer within [min, max].
---@param value number|nil
---@param min number|nil
---@param max number|nil
---@return number price
function PriceEntry.ClampListingPrice(value, min, max)
    value = tonumber(value) or 0
    min = tonumber(min) or (MIN_TRADING_HOUSE_POST_PRICE or 1)
    max = tonumber(max) or (MAX_PLAYER_CURRENCY or 999999999)

    if min > max then
        min, max = max, min
    end

    if type(zo_clamp) == "function" then
        value = zo_clamp(value, min, max)
    elseif value < min then
        value = min
    elseif value > max then
        value = max
    end
    return math.floor(value + 0.5)
end

--- Heuristic for when the digit-entry selector should be offered in addition
--- to the slider. The slider is exact for ranges <= 10000; above that the step
--- becomes coarse, so a digit selector is useful.
---@param defaultPrice number
---@return boolean offer
function PriceEntry.ShouldOfferDigitEntry(defaultPrice)
    defaultPrice = tonumber(defaultPrice) or 0
    return defaultPrice > 10000
end

-- DIGIT-ENTRY DIALOG ----------------------------------------------------------

local DIGIT_PRICE_DIALOG = "BETTERUI_TRADING_HOUSE_DIGIT_PRICE"

local function L(stringIdName, fallback)
    return SafeGetString(stringIdName, fallback or stringIdName)
end

--- Show a first-cut digit-spinner price selector. onConfirm receives the
--- clamped price chosen by the player.
---@param defaultPrice number
---@param minPrice number|nil
---@param maxPrice number|nil
---@param onConfirm function(price)
---@return boolean shown
function PriceEntry.ShowDigitPriceDialog(defaultPrice, minPrice, maxPrice, onConfirm)
    TracePriceEntry("trading_house.price_entry", "show_begin", {
        fn = "TradingHouse.PriceEntry.ShowDigitPriceDialog",
        defaultPrice = defaultPrice,
        minPrice = minPrice,
        maxPrice = maxPrice,
        hasConfirm = type(onConfirm) == "function",
    })
    if type(ZO_Dialogs_ShowGamepadDialog) ~= "function" then
        TracePriceEntry("trading_house.price_entry", "show_rejected", {
            fn = "TradingHouse.PriceEntry.ShowDigitPriceDialog",
            reason = "missingDialogApi",
        })
        return false
    end

    if type(onConfirm) ~= "function" then
        TracePriceEntry("trading_house.price_entry", "show_rejected", {
            fn = "TradingHouse.PriceEntry.ShowDigitPriceDialog",
            reason = "missingConfirmCallback",
        })
        return false
    end

    minPrice = tonumber(minPrice) or (MIN_TRADING_HOUSE_POST_PRICE or 1)
    maxPrice = tonumber(maxPrice) or (MAX_PLAYER_CURRENCY or 999999999)
    defaultPrice = PriceEntry.ClampListingPrice(defaultPrice, minPrice, maxPrice)

    local Dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs
    local priorDialog = Dialogs and Dialogs.GetCurrentInfo and Dialogs.GetCurrentInfo(DIGIT_PRICE_DIALOG) or nil
    if not (priorDialog and priorDialog._betteruiTradingHouseDigitPriceDialog) then
        local dialogInfo = {
            _betteruiTradingHouseDigitPriceDialog = true,
            canQueue = true,
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.PARAMETRIC or nil,
            },
            title = {
                text = L("SI_BETTERUI_TH_PRICE_LABEL", "Price"),
            },
            -- Balance ZO_CurrencySelector_Gamepad activation: the parametric row
            -- deactivates the selector on unfocus, but a dialog dismissed while
            -- the row is focused may not fire that unfocus. Deactivate on close
            -- so input capture is always released (mirrors the create-listing
            -- dialog's _activeSlider teardown).
            finishedCallback = function(dialog)
                local dialogData = dialog and dialog.data
                if dialogData and dialogData._priceSelector and dialogData._priceSelector.Deactivate then
                    dialogData._priceSelector:Deactivate()
                    dialogData._priceSelector = nil
                end
            end,
            setup = function(dialog)
                if dialog and dialog.setupFunc then
                    dialog:setupFunc()
                end
            end,
            parametricList = {
                {
                    template = "ZO_GamepadCurrencySelectorTemplate",
                    text = L("SI_BETTERUI_TH_PRICE_LABEL", "Price"),
                    templateData = {
                        setup = function(control, data, selected)
                            local dialog = data and data.dialog or nil
                            if not dialog and type(ZO_GenericGamepadDialog_GetControl) == "function"
                                and GAMEPAD_DIALOGS then
                                dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                            end
                            local dialogData = dialog and dialog.data
                            if not dialogData then
                                return
                            end

                            if ZO_CurrencySelector_Gamepad and ZO_CurrencySelector_Gamepad.New and control then
                                local selector = control._betteruiPriceSelector
                                if not selector then
                                    selector = ZO_CurrencySelector_Gamepad:New(control)
                                    control._betteruiPriceSelector = selector
                                    TracePriceEntry("trading_house.price_entry", "selector_created", {
                                        fn = "TradingHouse.PriceEntry.setup",
                                        control = control.GetName and control:GetName() or nil,
                                    })
                                end
                                if selector.SetCurrencyType then selector:SetCurrencyType(CURT_MONEY) end
                                if selector.SetClampValues then selector:SetClampValues(true) end
                                if selector.SetMaxValue then selector:SetMaxValue(dialogData.max) end
                                if selector.SetValue then selector:SetValue(dialogData.defaultPrice) end
                                dialogData._priceSelector = selector
                            end

                            if dialogData._priceSelector then
                                if selected and dialogData._priceSelector.Activate then
                                    dialogData._priceSelector:Activate()
                                elseif dialogData._priceSelector.Deactivate then
                                    dialogData._priceSelector:Deactivate()
                                end
                            end
                        end,
                    },
                },
            },
            buttons = {
                {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog)
                        local data = dialog and dialog.data
                        if not data or type(data.onConfirm) ~= "function" then
                            return
                        end
                        local value = data._priceSelector and data._priceSelector.GetValue
                            and data._priceSelector:GetValue() or data.defaultPrice
                        value = PriceEntry.ClampListingPrice(value, data.min, data.max)
                        TracePriceEntry("trading_house.price_entry", "confirm", {
                            fn = "TradingHouse.PriceEntry.confirm",
                            value = value,
                            min = data.min,
                            max = data.max,
                        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
                        local ok, err = pcall(data.onConfirm, value)
                        if not ok then
                            TracePriceEntry("trading_house.price_entry", "confirm_error", {
                                fn = "TradingHouse.PriceEntry.confirm",
                                value = value,
                                error = err,
                            }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
                            if BETTERUI.Log and type(BETTERUI.Log.Error) == "function" then
                                BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.ACTION, "price digit confirmed", { error = err })
                            end
                        end
                    end,
                },
                {
                    text = SI_DIALOG_CANCEL,
                },
            },
        }
        if not (Dialogs and Dialogs.RegisterWithPriorChain and Dialogs.RegisterWithPriorChain(DIGIT_PRICE_DIALOG, dialogInfo)) then
            TracePriceEntry("trading_house.price_entry", "show_rejected", {
                fn = "TradingHouse.PriceEntry.ShowDigitPriceDialog",
                reason = "registryRejected",
                dialog = DIGIT_PRICE_DIALOG,
            }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
            return false
        end
    end

    ZO_Dialogs_ShowGamepadDialog(DIGIT_PRICE_DIALOG, {
        defaultPrice = defaultPrice,
        min = minPrice,
        max = maxPrice,
        onConfirm = onConfirm,
    })
    TracePriceEntry("trading_house.price_entry", "shown", {
        fn = "TradingHouse.PriceEntry.ShowDigitPriceDialog",
        dialog = DIGIT_PRICE_DIALOG,
        defaultPrice = defaultPrice,
        min = minPrice,
        max = maxPrice,
    })
    return true
end
