--[[
File: tools/tests/test_icon_settings_factory.lua
Purpose: Regression coverage for stable icon settings reset wiring.
Usage:
  lua tools/tests/test_icon_settings_factory.lua
]]

local passed = 0
local failed = 0
local refreshCalls = 0

local moduleSettings = {
    showIconUnboundItem = false,
    showIconEnchantment = false,
    showIconSetGear = false,
    showIconResearchableTrait = false,
    showIconUnknownRecipe = false,
    showIconUnknownBook = false,
}

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

BETTERUI = {
    CIM = {
        CONST = {
            ICONS = {},
        },
        Settings = {},
    },
    GeneralInterface = {
        _SettingsHelpers = {},
    },
}

function GetString(value)
    return tostring(value)
end

BETTERUI.CIM.TryCall = function(path)
    error("Icon settings factory should not use TryCall for stable CIM.Settings reset seam: " .. tostring(path))
end

BETTERUI.CIM.Settings.GetSettingMetadata = function()
    return nil
end

BETTERUI.CIM.Settings.ResetModuleSettingsByGroup = function(_moduleName, _groupName)
    return false
end

BETTERUI.GeneralInterface._SettingsHelpers.GetModuleSettings = function()
    return moduleSettings
end

BETTERUI.GeneralInterface._SettingsHelpers.EnsureModuleSettings = function()
    return moduleSettings
end

SI_BETTERUI_ICON_UNBOUND = "Unbound"
SI_BETTERUI_ICON_UNBOUND_TOOLTIP = "Unbound tooltip"
SI_BETTERUI_ICON_ENCHANTMENT = "Enchantment"
SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP = "Enchantment tooltip"
SI_BETTERUI_ICON_SET_GEAR = "Set gear"
SI_BETTERUI_ICON_SET_GEAR_TOOLTIP = "Set gear tooltip"
SI_BETTERUI_ICON_RESEARCHABLE_TRAIT = "Researchable"
SI_BETTERUI_ICON_RESEARCHABLE_TRAIT_TOOLTIP = "Researchable tooltip"
SI_BETTERUI_ICON_UNKNOWN_RECIPE = "Unknown recipe"
SI_BETTERUI_ICON_UNKNOWN_RECIPE_TOOLTIP = "Unknown recipe tooltip"
SI_BETTERUI_ICON_UNKNOWN_BOOK = "Unknown book"
SI_BETTERUI_ICON_UNKNOWN_BOOK_TOOLTIP = "Unknown book tooltip"
SI_BETTERUI_ICON_SUBMENU_HEADER = "Icon customization"
SI_BETTERUI_ICON_SUBMENU_TOOLTIP = "Icon customization tooltip"
SI_BETTERUI_ICON_SUBMENU_DESC = "Icon customization description"
SI_BETTERUI_ICON_SUBMENU_RESET = "Reset icons"
SI_BETTERUI_ICON_SUBMENU_RESET_TOOLTIP = "Reset icons tooltip"

dofile("Modules/CIM/Core/Settings/IconSettingsFactory.lua")

print("[IconSettingsFactory reset wiring]")

do
    local submenu = BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption("Inventory", function()
        refreshCalls = refreshCalls + 1
    end)
    local resetButton = submenu.controls[#submenu.controls]

    assert_eq(submenu.type, "submenu", "factory returns a submenu option")
    assert_true(type(resetButton.func) == "function", "reset button exposes a callback")

    resetButton.func()

    assert_eq(moduleSettings.showIconUnboundItem, true, "reset restores the unbound icon toggle")
    assert_eq(moduleSettings.showIconEnchantment, true, "reset restores the enchantment icon toggle")
    assert_eq(moduleSettings.showIconSetGear, true, "reset restores the set gear icon toggle")
    assert_eq(moduleSettings.showIconResearchableTrait, true, "reset restores the researchable icon toggle")
    assert_eq(moduleSettings.showIconUnknownRecipe, true, "reset restores the unknown recipe icon toggle")
    assert_eq(moduleSettings.showIconUnknownBook, true, "reset restores the unknown book icon toggle")
    assert_eq(refreshCalls, 1, "reset triggers the caller refresh callback")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
