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

--- Show a first-cut digit-spinner price selector. onConfirm receives the
--- clamped price chosen by the player.
---@param defaultPrice number
---@param minPrice number|nil
---@param maxPrice number|nil
---@param onConfirm function(price)
---@return boolean shown
function PriceEntry.ShowDigitPriceDialog(defaultPrice, minPrice, maxPrice, onConfirm)
    if not (ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_ShowGamepadDialog) then
        return false
    end

    if type(onConfirm) ~= "function" then
        return false
    end

    minPrice = tonumber(minPrice) or (MIN_TRADING_HOUSE_POST_PRICE or 1)
    maxPrice = tonumber(maxPrice) or (MAX_PLAYER_CURRENCY or 999999999)
    defaultPrice = PriceEntry.ClampListingPrice(defaultPrice, minPrice, maxPrice)

    if not ZO_Dialogs_IsDialogRegistered(DIGIT_PRICE_DIALOG) then
        ZO_Dialogs_RegisterCustomDialog(DIGIT_PRICE_DIALOG, {
            canQueue = true,
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = L("SI_BETTERUI_TH_PRICE_LABEL") or "SI_TRADING_HOUSE_POSTING_PRICE",
            },
            setup = function(dialog)
                dialog:setupFunc()
            end,
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

                            if not dialogData._priceSelector and ZO_CurrencySelector_Gamepad and ZO_CurrencySelector_Gamepad.New then
                                local selector = ZO_CurrencySelector_Gamepad:New(control)
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
                        local ok, err = pcall(data.onConfirm, value)
                        if not ok and BETTERUI.Log then
                            BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.ACTION, "price digit confirmed", { error = err })
                        end
                    end,
                },
                {
                    text = SI_DIALOG_CANCEL,
                },
            },
        })
    end

    ZO_Dialogs_ShowGamepadDialog(DIGIT_PRICE_DIALOG, {
        defaultPrice = defaultPrice,
        min = minPrice,
        max = maxPrice,
        onConfirm = onConfirm,
    })
    return true
end
