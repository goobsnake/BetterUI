--[[
File: tools/tests/test_font_settings_scope.lua
Purpose: Regression coverage that shared font settings mutate only their target module.

Usage:
  lua tools/tests/test_font_settings_scope.lua
]]

local passed = 0
local failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

function GetString(value)
    return tostring(value)
end

function zo_strlower(value)
    return string.lower(value)
end

BETTERUI = {
    Settings = {
        Modules = {
            Inventory = {
                nameFont = "InventoryName",
                nameFontSize = 31,
                nameFontStyle = "InventoryNameStyle",
                columnFont = "InventoryColumn",
                columnFontSize = 29,
                columnFontStyle = "InventoryColumnStyle",
            },
            Banking = {
                nameFont = "BankNameCustom",
                nameFontSize = 33,
                nameFontStyle = "BankNameStyleCustom",
                columnFont = "BankColumnCustom",
                columnFontSize = 34,
                columnFontStyle = "BankColumnStyleCustom",
            },
            Vendor = {
                nameFont = "VendorName",
                nameFontSize = 32,
                nameFontStyle = "VendorNameStyle",
                columnFont = "VendorColumn",
                columnFontSize = 30,
                columnFontStyle = "VendorColumnStyle",
            },
        },
    },
    CIM = {
        Settings = {},
        Font = {
            CHOICES = { "Default", "Alternate" },
            VALUES = { "DefaultFont", "AlternateFont" },
            STYLE_CHOICES = { "None", "Shadow" },
            STYLE_VALUES = { "", "shadow" },
            SIZE_MIN = 12,
            SIZE_MAX = 48,
            DEFAULTS = {
                nameFont = "DefaultName",
                nameFontSize = 20,
                nameFontStyle = "",
                columnFont = "DefaultColumn",
                columnFontSize = 18,
                columnFontStyle = "soft-shadow-thin",
            },
            Localization = {
                GetFilteredFontArrays = function(choices, values)
                    return choices, values
                end,
            },
            GetSizeValue = function(value)
                return tonumber(value) or 0
            end,
        },
    },
}

function BETTERUI.GetModuleEnabled()
    return true
end

local function clone(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = clone(item)
    end
    return copy
end

function BETTERUI.GetModuleSettings(moduleName)
    return clone(BETTERUI.Settings.Modules[moduleName] or {})
end

function BETTERUI.EnsureModuleSettings(moduleName)
    BETTERUI.Settings.Modules[moduleName] = BETTERUI.Settings.Modules[moduleName] or {}
    return BETTERUI.Settings.Modules[moduleName]
end

print("\n=== Font Settings Scope Tests ===\n")

dofile("Modules/CIM/Core/Settings/SettingsFactory.lua")

local options = BETTERUI.CIM.Settings.CreateFontSubmenuOptions({
    moduleName = "Banking",
    defaults = BETTERUI.CIM.Font.DEFAULTS,
    fontChoices = BETTERUI.CIM.Font.CHOICES,
    fontValues = BETTERUI.CIM.Font.VALUES,
    styleChoices = BETTERUI.CIM.Font.STYLE_CHOICES,
    styleValues = BETTERUI.CIM.Font.STYLE_VALUES,
    strings = {
        header = "Fonts",
        desc = "Font settings",
        nameSubmenu = "Name Font",
        nameFont = "Name Font",
        nameFontTooltip = "Name Font Tooltip",
        nameFontSize = "Name Font Size",
        nameFontSizeTooltip = "Name Font Size Tooltip",
        nameFontStyle = "Name Font Style",
        nameFontStyleTooltip = "Name Font Style Tooltip",
        nameReset = "Reset Name Font",
        nameResetTooltip = "Reset Name Font Tooltip",
        columnSubmenu = "Column Font",
        columnFont = "Column Font",
        columnFontTooltip = "Column Font Tooltip",
        columnFontSize = "Column Font Size",
        columnFontSizeTooltip = "Column Font Size Tooltip",
        columnFontStyle = "Column Font Style",
        columnFontStyleTooltip = "Column Font Style Tooltip",
        columnReset = "Reset Column Font",
        columnResetTooltip = "Reset Column Font Tooltip",
    },
})

local nameFontControl = options[3].controls[1]
local nameResetControl = options[3].controls[4]
local columnFontControl = options[4].controls[1]
local columnResetControl = options[4].controls[4]

nameFontControl.setFunc("BankNameChanged")
columnFontControl.setFunc("BankColumnChanged")

assert_equal("BankNameChanged", BETTERUI.Settings.Modules.Banking.nameFont,
    "name font set writes only to Banking")
assert_equal("BankColumnChanged", BETTERUI.Settings.Modules.Banking.columnFont,
    "column font set writes only to Banking")
assert_equal("InventoryName", BETTERUI.Settings.Modules.Inventory.nameFont,
    "Inventory name font is untouched by Banking set")
assert_equal("VendorColumn", BETTERUI.Settings.Modules.Vendor.columnFont,
    "Vendor column font is untouched by Banking set")

nameResetControl.func()
columnResetControl.func()

assert_equal("DefaultName", BETTERUI.Settings.Modules.Banking.nameFont,
    "name font reset writes Banking default")
assert_equal(20, BETTERUI.Settings.Modules.Banking.nameFontSize,
    "name font size reset writes Banking default")
assert_equal("", BETTERUI.Settings.Modules.Banking.nameFontStyle,
    "name font style reset writes Banking default")
assert_equal("DefaultColumn", BETTERUI.Settings.Modules.Banking.columnFont,
    "column font reset writes Banking default")
assert_equal(18, BETTERUI.Settings.Modules.Banking.columnFontSize,
    "column font size reset writes Banking default")
assert_equal("soft-shadow-thin", BETTERUI.Settings.Modules.Banking.columnFontStyle,
    "column font style reset writes Banking default")

assert_equal("InventoryName", BETTERUI.Settings.Modules.Inventory.nameFont,
    "Inventory name font is untouched by Banking reset")
assert_equal(31, BETTERUI.Settings.Modules.Inventory.nameFontSize,
    "Inventory name font size is untouched by Banking reset")
assert_equal("InventoryColumn", BETTERUI.Settings.Modules.Inventory.columnFont,
    "Inventory column font is untouched by Banking reset")
assert_equal("VendorName", BETTERUI.Settings.Modules.Vendor.nameFont,
    "Vendor name font is untouched by Banking reset")
assert_equal("VendorColumnStyle", BETTERUI.Settings.Modules.Vendor.columnFontStyle,
    "Vendor column font style is untouched by Banking reset")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
