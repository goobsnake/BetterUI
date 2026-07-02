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

    value = zo_clamp(value, min, max)
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

local function L(stringIdName)
    return GetString(rawget(_G, stringIdName) or stringIdName)
end

local function GetCurrentDialogInfo(dialogName)
    local dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs
    if dialogs and type(dialogs.GetCurrentInfo) == "function" then
        return dialogs.GetCurrentInfo(dialogName)
    end
    return nil
end

local function RegisterPriceDialog(dialogName, dialogInfo)
    local dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs
    if not (dialogs and type(dialogs.Register) == "function") then
        TracePriceEntry("trading_house.price_entry", "register_skipped", {
            fn = "RegisterPriceDialog",
            reason = "missingDialogRegistry",
            dialog = dialogName,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
        return false
    end
    return dialogs.Register(dialogName, dialogInfo, { overwrite = true })
end

local function ChainPriorDialogSetup(priorDialog, setup)
    return function(dialog, ...)
        if priorDialog and type(priorDialog.setup) == "function" then
            priorDialog.setup(dialog, ...)
        end
        return setup(dialog, ...)
    end
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
    if not ZO_Dialogs_ShowGamepadDialog then
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

    local priorDialog = GetCurrentDialogInfo(DIGIT_PRICE_DIALOG)
    if not (priorDialog and priorDialog._betteruiTradingHouseDigitPriceDialog) then
        local dialogInfo = {
            _betteruiTradingHouseDigitPriceDialog = true,
            canQueue = true,
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = L("SI_BETTERUI_TH_PRICE_LABEL") or "SI_TRADING_HOUSE_POSTING_PRICE",
            },
            setup = ChainPriorDialogSetup(priorDialog, function(dialog)
                dialog:setupFunc()
            end),
            parametricList = {
                {
                    template = "ZO_GamepadCurrencySelectorTemplate",
                    text = L("SI_BETTERUI_TH_PRICE_LABEL") or "Price",
                    templateData = {
                        setup = function(control, data, selected)
                            local dialog = data.dialog or ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                            local dialogData = dialog and dialog.data
                            if not dialogData then
                                return
                            end

                            if ZO_CurrencySelector_Gamepad and ZO_CurrencySelector_Gamepad.New then
                                local selector = control._betteruiPriceSelector
                                if not selector then
                                    selector = ZO_CurrencySelector_Gamepad:New(control)
                                    control._betteruiPriceSelector = selector
                                    TracePriceEntry("trading_house.price_entry", "selector_created", {
                                        fn = "TradingHouse.PriceEntry.setup",
                                        control = control.GetName and control:GetName() or nil,
                                    })
                                end
                                selector:SetCurrencyType(CURT_MONEY)
                                selector:SetClampValues(true)
                                selector:SetMaxValue(dialogData.max)
                                selector:SetValue(dialogData.defaultPrice)
                                dialogData._priceSelector = selector
                            end

                            if dialogData._priceSelector then
                                if selected then
                                    dialogData._priceSelector:Activate()
                                else
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
                        local data = dialog.data
                        if not data or type(data.onConfirm) ~= "function" then
                            return
                        end
                        local value = data._priceSelector and data._priceSelector:GetValue()
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
                            if BETTERUI.Log then
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
        if not RegisterPriceDialog(DIGIT_PRICE_DIALOG, dialogInfo) then
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
