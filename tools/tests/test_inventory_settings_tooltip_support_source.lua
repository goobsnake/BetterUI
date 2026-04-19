--[[
File: tools/tests/test_inventory_settings_tooltip_support_source.lua
Purpose: Source-level regression checks for inventory settings, position, and tooltip support modules.

Usage:
  lua tools/tests/test_inventory_settings_tooltip_support_source.lua
]]

if false then
    dofile("Modules/Inventory/Settings/FontSettings.lua")
    dofile("Modules/Inventory/Settings/SettingsPanel.lua")
    dofile("Modules/Inventory/State/PositionManager.lua")
    dofile("Modules/Inventory/UI/TooltipEquipped.lua")
    dofile("Modules/Inventory/UI/TooltipUtils.lua")
end

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local fontSettingsSource = read_file("Modules/Inventory/Settings/FontSettings.lua")
assert_true(fontSettingsSource:find("BETTERUI%.Inventory%.FONT_CHOICES = BETTERUI%.CIM%.Font%.CHOICES") ~= nil,
    "FontSettings reuses the shared CIM font choices")
assert_true(fontSettingsSource:find("local function GetInventoryFontDescriptors%(%)") ~= nil,
    "FontSettings lazily resolves inventory font descriptors")
assert_true(fontSettingsSource:find("function BETTERUI%.Inventory%.GetNameFontDescriptor%(%)") ~= nil,
    "FontSettings exposes the inventory name font descriptor through a lazy helper")
assert_true(fontSettingsSource:find("function BETTERUI%.Inventory%.Settings%.GetFontOptions%(%)") ~= nil,
    "FontSettings exposes GetFontOptions")

local settingsPanelSource = read_file("Modules/Inventory/Settings/SettingsPanel.lua")
assert_true(settingsPanelSource:find("function BETTERUI%.Inventory%.Settings%.RegisterPanel%(mId, moduleName%)") ~= nil,
    "SettingsPanel exposes RegisterPanel")
assert_true(settingsPanelSource:find("CreateIconCustomizationSubmenuOption") ~= nil
        and settingsPanelSource:find("\"Inventory\"") ~= nil,
    "SettingsPanel wires the shared icon customization submenu")
assert_true(settingsPanelSource:find("BETTERUI%.Inventory%.Settings%.GetCurrencyOptions%(%)") ~= nil,
    "SettingsPanel appends the currency options packet")

local positionManagerSource = read_file("Modules/Inventory/State/PositionManager.lua")
assert_true(positionManagerSource:find("function BETTERUI%.Inventory%.GetCategoryKey%(categoryData%)") ~= nil,
    "PositionManager exposes GetCategoryKey")
assert_true(positionManagerSource:find("function BETTERUI%.Inventory%.FindCategoryIndexByKey%(self, key%)") ~= nil,
    "PositionManager exposes FindCategoryIndexByKey")
assert_true(positionManagerSource:find("function BETTERUI%.Inventory%.ToSavedPosition%(self%)") ~= nil,
    "PositionManager exposes ToSavedPosition")
assert_true(positionManagerSource:find("function BETTERUI%.Inventory%.SaveListPosition%(self%)") ~= nil,
    "PositionManager exposes SaveListPosition")
assert_true(positionManagerSource:find("BETTERUI%.Inventory%.Class%.ToSavedPosition = BETTERUI%.Inventory%.ToSavedPosition") ~= nil,
    "PositionManager binds ToSavedPosition directly onto Inventory.Class")
assert_true(positionManagerSource:find("BETTERUI%.Inventory%.Class%.SaveListPosition = BETTERUI%.Inventory%.SaveListPosition") ~= nil,
    "PositionManager binds SaveListPosition directly onto Inventory.Class")

local tooltipEquippedSource = read_file("Modules/Inventory/UI/TooltipEquipped.lua")
assert_true(tooltipEquippedSource:find("function BETTERUI%.Inventory%.UpdateTooltipEquippedText%(tooltipType, equipSlot%)") ~= nil,
    "TooltipEquipped exposes UpdateTooltipEquippedText")
assert_true(tooltipEquippedSource:find("tooltip%._betterui_priceRendered = true") ~= nil,
    "TooltipEquipped marks price rendering ownership on the tooltip")

local tooltipUtilsSource = read_file("Modules/Inventory/UI/TooltipUtils.lua")
assert_true(tooltipUtilsSource:find("function BETTERUI%.Inventory%.ApplyTooltipStyles%(%)") ~= nil,
    "TooltipUtils exposes ApplyTooltipStyles")
assert_true(tooltipUtilsSource:find("function BETTERUI%.Inventory%.EnableTooltipMouseWheel%(%)") ~= nil,
    "TooltipUtils exposes EnableTooltipMouseWheel")
assert_true(tooltipUtilsSource:find("function BETTERUI%.Inventory%.CleanupEnhancedTooltip%(tooltipType%)") ~= nil,
    "TooltipUtils exposes CleanupEnhancedTooltip")
assert_true(tooltipUtilsSource:find("function BETTERUI%.Inventory%.IsItemComparisonEnabled%(%)") ~= nil,
    "TooltipUtils exposes IsItemComparisonEnabled")
assert_true(tooltipUtilsSource:find("function BETTERUI%.Inventory%.ShowComparisonOnTooltip%(container, result%)") ~= nil,
    "TooltipUtils exposes ShowComparisonOnTooltip")

if failed > 0 then
    error(string.format("test_inventory_settings_tooltip_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_inventory_settings_tooltip_support_source.lua: %d passed", passed))
