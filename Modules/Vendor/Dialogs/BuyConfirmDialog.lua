--[[
File: Modules/Vendor/Dialogs/BuyConfirmDialog.lua
Purpose: Gamepad confirmation dialog for multi-quantity vendor purchases.

Shown from Vendor.BuyComponent:OnPrimaryAction when the dialed quantity is > 1
and the user has not enabled the "Skip Buy Confirmation" (skipBuyConfirm)
setting. The dialog restates the item name, dialed quantity, and running total,
then performs the purchase through a captured onConfirm closure. That closure
routes back through PerformVendorBuy, which re-clamps to the live
GetStoreEntryMaxBuyable, so a stale total (gold/space changed while the dialog
was open) can never over-purchase.

Gamepad dialogs push their own DIALOG_PRIMARY/DIALOG_NEGATIVE keybind layer, so
the Confirm/Cancel keys work inside the BETTERUI_VENDOR scene WITHOUT the
GamepadUIMode inheritsBindFrom workaround the keybind strip needs (see
gamepad-uimode-blocks-custom-keybinds tribal knowledge).
]]

if not BETTERUI.Vendor then return end
local Vendor = BETTERUI.Vendor

Vendor.Dialogs = Vendor.Dialogs or {}

local BUY_CONFIRM_DIALOG = "BETTERUI_VENDOR_CONFIRM_BUY_DIALOG"

local function TraceBuyConfirmDialog(phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Vendor"
    data.feature = "vendor-buy-confirm"
    data.dialog = BUY_CONFIRM_DIALOG
    data.fn = data.fn or "Vendor.Dialogs.BuyConfirm"
    L.TraceEvent((L.CATEGORY or {}).DIALOG or (L.CATEGORY or {}).ACTION, "vendor.buy_confirm", phase, data)
end

local function GetDialogRegistry()
    return BETTERUI.CIM and BETTERUI.CIM.Dialogs or nil
end

--- Wraps a dialog button descriptor with the shared CIM input anchor (tracing +
--- consistent keybind handling), mirroring the Companions dialog wiring.
local function WrapVendorDialogKeybind(entry, action)
    local keybinds = BETTERUI.CIM and BETTERUI.CIM.Keybinds
    local anchor = keybinds and keybinds.InputAnchor
    if anchor and type(anchor.Wrap) == "function" then
        return anchor.Wrap(entry, { module = "Vendor", action = action })
    end
    return entry
end

--- Formats a purchase total with the item's currency (gold/AP/writ vouchers/etc.)
--- in gamepad icon style, falling back to a comma-delimited number when the
--- currency helpers are unavailable.
---@param amount integer
---@param currencyType integer|nil
---@return string
local function FormatBuyTotal(amount, currencyType)
    amount = amount or 0
    -- Store BUY entries report gold as currencyType 0 (a sentinel the inline
    -- spinner's SetupCurrency tolerates). But 0 is NOT a real currency:
    -- ZO_Currency_GetGamepadFormattedCurrencyIcon does g_currenciesData[0] -> nil
    -- and throws. `0 or CURT_MONEY` never falls back because 0 is truthy in Lua,
    -- so coerce any non-positive / non-number type to gold explicitly.
    local curt = currencyType
    if type(curt) ~= "number" or curt <= 0 then
        curt = rawget(_G, "CURT_MONEY")
    end
    local formatGamepad = rawget(_G, "ZO_Currency_FormatGamepad")
    local iconFormat = rawget(_G, "ZO_CURRENCY_FORMAT_AMOUNT_ICON")
    if formatGamepad and iconFormat and type(curt) == "number" then
        -- pcall: a currency type with no gamepad icon must degrade to a plain
        -- number, never abort the purchase (this crash blocked the Buy keybind).
        local ok, formatted = pcall(formatGamepad, curt, amount, iconFormat)
        if ok and type(formatted) == "string" then
            return formatted
        end
    end
    local comma = rawget(_G, "ZO_CommaDelimitDecimalNumber") or rawget(_G, "ZO_CommaDelimitNumber")
    if comma then
        return comma(amount)
    end
    return tostring(amount)
end

--- Registers the buy-confirmation dialog once. Idempotent: no-ops if the dialog
--- is already registered (checked via the CIM dialog registry).
---@return boolean registered
local function EnsureRegistered()
    local dialogs = GetDialogRegistry()
    if not (dialogs and type(dialogs.Register) == "function") then
        TraceBuyConfirmDialog("register_skipped", { reason = "missingDialogRegistry" })
        return false
    end
    if type(dialogs.GetCurrentInfo) == "function" and dialogs.GetCurrentInfo(BUY_CONFIRM_DIALOG) then
        return true
    end

    local gamepadDialogs = rawget(_G, "GAMEPAD_DIALOGS")
    dialogs.Register(BUY_CONFIRM_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = gamepadDialogs and gamepadDialogs.BASIC or 1 },
        title = {
            text = function()
                return GetString(rawget(_G, "SI_BETTERUI_VENDOR_CONFIRM_BUY_TITLE")
                    or "SI_BETTERUI_VENDOR_CONFIRM_BUY_TITLE")
            end,
        },
        mainText = {
            text = function(dialog)
                local d = dialog and dialog.data or {}
                local qty = d.quantity or 1
                local name = d.itemName or ""
                local priceText = FormatBuyTotal(d.totalPrice, d.currencyType)
                local formatId = rawget(_G, "SI_BETTERUI_VENDOR_CONFIRM_BUY_FORMAT")
                if formatId then
                    return zo_strformat(GetString(formatId), qty, name, priceText)
                end
                return zo_strformat("Buy <<1>>x <<2>> for <<3>>?", qty, name, priceText)
            end,
        },
        buttons = {
            WrapVendorDialogKeybind({
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_DIALOG_CANCEL") or "SI_DIALOG_CANCEL"),
                callback = function(dialog)
                    TraceBuyConfirmDialog("cancel", {
                        quantity = dialog and dialog.data and dialog.data.quantity or nil,
                    })
                end,
            }, "buy_confirm_cancel"),
            WrapVendorDialogKeybind({
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_DIALOG_CONFIRM") or "SI_DIALOG_CONFIRM"),
                callback = function(dialog)
                    local d = dialog and dialog.data
                    TraceBuyConfirmDialog("confirm", {
                        quantity = d and d.quantity or nil,
                        hasConfirm = d and type(d.onConfirm) == "function" or false,
                    })
                    if d and type(d.onConfirm) == "function" then
                        d.onConfirm()
                    end
                end,
            }, "buy_confirm_confirm"),
        },
    }, { overwrite = true })
    return true
end

Vendor.Dialogs.RegisterBuyConfirmDialog = EnsureRegistered

--- Shows the multi-quantity buy confirmation. Registers the dialog lazily on
--- first use. Returns true when the dialog was shown (the caller must NOT buy
--- directly -- the Confirm button runs context.onConfirm); false when the
--- caller should perform the purchase itself (registry/context unavailable).
---@param context { itemName: string, quantity: integer, totalPrice: integer, currencyType: integer|nil, onConfirm: fun() }
---@return boolean shown
function Vendor.ShowBuyConfirmation(context)
    if not (context and type(context.onConfirm) == "function") then
        TraceBuyConfirmDialog("show_rejected", { reason = "missingContext" })
        return false
    end
    if not EnsureRegistered() then
        return false
    end
    local dialogs = GetDialogRegistry()
    if not (dialogs and type(dialogs.Show) == "function") then
        TraceBuyConfirmDialog("show_rejected", { reason = "missingShow" })
        return false
    end
    TraceBuyConfirmDialog("shown", { quantity = context.quantity })
    dialogs.Show(BUY_CONFIRM_DIALOG, {
        itemName = context.itemName,
        quantity = context.quantity,
        totalPrice = context.totalPrice,
        currencyType = context.currencyType,
        onConfirm = context.onConfirm,
    })
    return true
end
