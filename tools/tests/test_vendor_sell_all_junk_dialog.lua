--[[
File: tools/tests/test_vendor_sell_all_junk_dialog.lua
Purpose: Regression coverage for vendor sell-all-junk dialog routing.
]]

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assertTrue(value, message)
    assertEq(value == true, true, message)
end

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            REPAIR = 3,
            BUYBACK = 4,
            FENCE_SELL = 5,
            FENCE_LAUNDER = 6,
            STABLE = 7,
        },
        Class = {},
    },
    CIM = {
        SafeExecute = function(_, fn, ...)
            return true, fn(...)
        end,
    },
}

local shownGamepadDialogs = {}
local shownDialogs = {}
local registeredDialogs = {}

GAMEPAD_DIALOGS = { BASIC = "basic" }

function GetString(value)
    return tostring(value)
end

function ZO_Dialogs_IsDialogRegistered(name)
    return registeredDialogs[name] ~= nil
end

function ZO_Dialogs_RegisterCustomDialog(name, info)
    registeredDialogs[name] = info
end

function ZO_Dialogs_ShowGamepadDialog(name, data)
    shownGamepadDialogs[#shownGamepadDialogs + 1] = {
        name = name,
        data = data,
    }
end

function ZO_Dialogs_ShowDialog(name, data)
    shownDialogs[#shownDialogs + 1] = {
        name = name,
        data = data,
    }
end

SI_PROMPT_TITLE_SELL_ITEMS = "Sell All Junk"
SI_SELL_ALL_JUNK = "Sell all junk?"
SI_SELL_ALL_JUNK_CONFIRM = "Sell"
SI_DIALOG_CANCEL = "Cancel"

dofile("Modules/Vendor/Core/VendorSafeExecute.lua")
dofile("Modules/Vendor/Core/VendorKeybinds.lua")
dofile("Modules/Vendor/Vendor.lua")

do
    local vendorInstance = { id = "vendor" }
    local sellCalls = 0
    local sellComponent = {
        SellAllJunk = function(self, instance)
            sellCalls = sellCalls + 1
            assertEq(instance, vendorInstance, "confirm callback forwards the vendor instance")
        end,
    }

    local shown = BETTERUI.Vendor.ShowSellAllJunkDialog(vendorInstance, sellComponent)
    assertTrue(shown, "sell-all-junk helper shows a dialog")
    assertEq(shownGamepadDialogs[1].name, "BETTERUI_VENDOR_SELL_ALL_JUNK_DIALOG", "gamepad flow uses the custom BetterUI dialog")
    assertEq(registeredDialogs.BETTERUI_VENDOR_SELL_ALL_JUNK_DIALOG ~= nil, true, "custom gamepad dialog is registered")

    local confirmButton = registeredDialogs.BETTERUI_VENDOR_SELL_ALL_JUNK_DIALOG.buttons[1]
    confirmButton.callback({ data = shownGamepadDialogs[1].data })
    assertEq(sellCalls, 1, "confirm callback sells all junk through the component")
end

do
    shownGamepadDialogs = {}
    shownDialogs = {}
    registeredDialogs = {}

    GAMEPAD_DIALOGS = nil

    local vendorInstance = { id = "fallbackVendor" }
    local sellComponent = {
        SellAllJunk = function()
        end,
    }

    local shown = BETTERUI.Vendor.ShowSellAllJunkDialog(vendorInstance, sellComponent)
    assertTrue(shown, "sell-all-junk helper falls back to keyboard dialog when gamepad registration is unavailable")
    assertEq(#shownGamepadDialogs, 0, "fallback path does not try to show a gamepad dialog")
    assertEq(shownDialogs[1].name, "SELL_ALL_JUNK", "fallback path uses the native SELL_ALL_JUNK dialog")
    assertEq(shownDialogs[1].data.vendorInstance, vendorInstance, "fallback dialog receives the vendor instance")
end

print("test_vendor_sell_all_junk_dialog.lua: PASS")
