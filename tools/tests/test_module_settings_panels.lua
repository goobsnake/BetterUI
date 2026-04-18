--[[
File: tools/tests/test_module_settings_panels.lua
Purpose: Unit tests for module settings panel callbacks and reset wiring.
         Loads production settings panel files with lightweight LAM stubs.

Usage:
  lua tools/tests/test_module_settings_panels.lua
]]

local addonPanels = {}
local optionControls = {}
local registeredModulePanel = nil
local keybindUpdates = 0
local bankingSceneShowing = true
local sortAlphabetizeCalls = 0

local bankingState = {
    enableGuildBank = false,
    enableCarousel = false,
    useTriggersForSkip = true,
    triggerSpeed = 5,
}

local vendorState = {
    enableCarousel = false,
    enableBatchJunkSell = false,
    abbreviateVendorCurrency = false,
}

local tradingHouseState = {
    enableCarousel = false,
}

local companionsState = {
    enableCompanionEquipment = false,
    quickDestroy = true,
    batchDestroy = false,
    bindOnEquipProtection = false,
    enableCompanionJunk = false,
}

local inventoryState = {
    quickDestroy = false,
    enableBatchDestroy = false,
    enableCarousel = false,
    useTriggersForSkip = true,
    triggerSpeed = 5,
    bindOnEquipProtection = false,
    enableCompanionJunk = false,
}

local bankingWindow = {
    refreshListCount = 0,
    refreshKeybindCount = 0,
    rebuildHeaderCount = 0,
    triggerModeValue = nil,
}

function bankingWindow:RefreshList()
    self.refreshListCount = self.refreshListCount + 1
end

function bankingWindow:RefreshKeybinds()
    self.refreshKeybindCount = self.refreshKeybindCount + 1
end

function bankingWindow:RebuildHeaderCategories()
    self.rebuildHeaderCount = self.rebuildHeaderCount + 1
end

function bankingWindow:SetListsUseTriggerKeybinds(value)
    self.triggerModeValue = value
end

local vendorInstance = {
    sceneShowing = true,
    refreshListCount = 0,
    refreshFooterCount = 0,
    rebuildHeaderCount = 0,
}

function vendorInstance:IsSceneShowing()
    return self.sceneShowing
end

function vendorInstance:RefreshList()
    self.refreshListCount = self.refreshListCount + 1
end

function vendorInstance:RefreshVendorFooter()
    self.refreshFooterCount = self.refreshFooterCount + 1
end

function vendorInstance:RebuildCategoryHeader()
    self.rebuildHeaderCount = self.rebuildHeaderCount + 1
end

local tradingHouseInstance = {
    sceneShowing = true,
    refreshListCount = 0,
    refreshFooterCount = 0,
    updateTabHeaderCount = 0,
}

function tradingHouseInstance:IsSceneShowing()
    return self.sceneShowing
end

function tradingHouseInstance:RefreshList()
    self.refreshListCount = self.refreshListCount + 1
end

function tradingHouseInstance:RefreshTHFooter()
    self.refreshFooterCount = self.refreshFooterCount + 1
end

function tradingHouseInstance:UpdateTabHeader()
    self.updateTabHeaderCount = self.updateTabHeaderCount + 1
end

local companionsInstance = {
    sceneShowing = true,
    refreshListCount = 0,
    refreshFooterCount = 0,
}

function companionsInstance:IsSceneShowing()
    return self.sceneShowing
end

function companionsInstance:RefreshList()
    self.refreshListCount = self.refreshListCount + 1
end

function companionsInstance:RefreshCompanionFooter()
    self.refreshFooterCount = self.refreshFooterCount + 1
end

local inventoryWindow = {
    refreshListCount = 0,
    refreshHeaderCount = 0,
    refreshItemActionsCount = 0,
    refreshKeybindCount = 0,
    triggerModeValue = nil,
    scene = {
        IsShowing = function()
            return true
        end,
    },
    categoryHeaderData = {
        carouselConfig = {},
    },
}

function inventoryWindow:RefreshItemList()
    self.refreshListCount = self.refreshListCount + 1
end

function inventoryWindow:RefreshHeader()
    self.refreshHeaderCount = self.refreshHeaderCount + 1
end

function inventoryWindow:RefreshItemActions()
    self.refreshItemActionsCount = self.refreshItemActionsCount + 1
end

function inventoryWindow:RefreshKeybinds()
    self.refreshKeybindCount = self.refreshKeybindCount + 1
end

function inventoryWindow:SetListsUseTriggerKeybinds(value)
    self.triggerModeValue = value
end

LibAddonMenu2 = {
    RegisterAddonPanel = function(_, panelId, panelData)
        addonPanels[panelId] = panelData
    end,
    RegisterOptionControls = function(_, panelId, controls)
        optionControls[panelId] = controls
    end,
}

KEYBIND_STRIP = {
    UpdateCurrentKeybindButtonGroups = function()
        keybindUpdates = keybindUpdates + 1
    end,
}

BETTERUI = {
    Banking = {
        Settings = {},
        Window = bankingWindow,
        DEFAULTS = {},
        FONT_CHOICES = {},
        FONT_VALUES = {},
        FONTSTYLE_CHOICES = {},
        FONTSTYLE_VALUES = {},
    },
    Vendor = {
        Settings = {},
        instance = vendorInstance,
        DEFAULTS = {},
        FONT_CHOICES = {},
        FONT_VALUES = {},
        FONTSTYLE_CHOICES = {},
        FONTSTYLE_VALUES = {},
    },
    TradingHouse = {
        Settings = {},
        instance = tradingHouseInstance,
    },
    Companions = {
        Settings = {},
        instance = companionsInstance,
        DEFAULTS = {},
        FONT_CHOICES = {},
        FONT_VALUES = {},
        FONTSTYLE_CHOICES = {},
        FONTSTYLE_VALUES = {},
    },
    Inventory = {
        Settings = {},
    },
    Utils = {},
    CIM = {
        Settings = {},
    },
}

function BETTERUI.Debug(_) end

function BETTERUI.Init_ModulePanel(moduleName, moduleDesc)
    return {
        moduleName = moduleName,
        moduleDesc = moduleDesc,
    }
end

function BETTERUI.Utils.IsBankingSceneShowing()
    return bankingSceneShowing
end

function BETTERUI.Utils.IsInventorySceneShowing()
    return true
end

function BETTERUI.Banking.GetSetting(key)
    return bankingState[key]
end

function BETTERUI.Banking.SetSetting(key, value)
    bankingState[key] = value
end

function BETTERUI.Inventory.GetSetting(key)
    return inventoryState[key]
end

function BETTERUI.Inventory.SetSetting(key, value)
    inventoryState[key] = value
end

function BETTERUI.Vendor.GetSetting(key)
    return vendorState[key]
end

function BETTERUI.Vendor.SetSetting(key, value)
    vendorState[key] = value
end

function BETTERUI.TradingHouse.GetSetting(key)
    return tradingHouseState[key]
end

function BETTERUI.TradingHouse.SetSetting(key, value)
    tradingHouseState[key] = value
end

function BETTERUI.Companions.GetSetting(key)
    return companionsState[key]
end

function BETTERUI.Companions.SetSetting(key, value)
    companionsState[key] = value
end

function BETTERUI.CIM.TryCall(name, ...)
    error("Settings panels should not depend on TryCall for stable CIM.Settings seam: " .. tostring(name))
end

function BETTERUI.CIM.Settings.ResetModuleSettingsByGroup(_moduleName, _groupName)
    return false
end

function BETTERUI.CIM.Settings.SortSettingsAlphabetically(_optionsData, _recursive)
    sortAlphabetizeCalls = sortAlphabetizeCalls + 1
end

function BETTERUI.CIM.Settings.CreateIconCustomizationSubmenuOption(moduleName, refreshFn)
    return {
        type = "submenu",
        name = moduleName .. " icon settings",
        refresh = refreshFn,
    }
end

function BETTERUI.CIM.Settings.CreateFontSubmenuOptions()
    return {}
end

GAMEPAD_INVENTORY = inventoryWindow

function BETTERUI.CIM.Settings.RegisterModulePanel(panelId, panelData, optionsData)
    registeredModulePanel = {
        panelId = panelId,
        panelData = panelData,
        optionsData = optionsData,
    }
    addonPanels[panelId] = panelData
    optionControls[panelId] = optionsData
end

function GetString(value)
    return value
end

SI_BETTERUI_BANK_GENERAL_HEADER = "Bank General"
SI_BETTERUI_BANK_GENERAL_DESC = "Bank General Desc"
SI_BETTERUI_GUILD_BANK_ENABLED = "Guild Bank"
SI_BETTERUI_GUILD_BANK_ENABLED_TOOLTIP = "Guild Bank Tooltip"
SI_BETTERUI_ENABLE_CAROUSEL_NAV = "Enable Carousel"
SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP = "Enable Carousel Tooltip"
SI_BETTERUI_TRIGGER_SKIP_TYPE = "Use Triggers"
SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP = "Use Triggers Tooltip"
SI_BETTERUI_TRIGGER_SKIP = "Trigger Speed"
SI_BETTERUI_TRIGGER_SKIP_TOOLTIP = "Trigger Speed Tooltip"
SI_BETTERUI_GENERAL_RESET = "Reset"
SI_BETTERUI_GENERAL_RESET_TOOLTIP = "Reset Tooltip"
SI_BETTERUI_VENDOR_GENERAL_HEADER = "Vendor General"
SI_BETTERUI_VENDOR_GENERAL_DESC = "Vendor General Desc"
SI_BETTERUI_VENDOR_BATCH_JUNK_SELL = "Batch Junk Sell"
SI_BETTERUI_VENDOR_BATCH_JUNK_SELL_TOOLTIP = "Batch Junk Sell Tooltip"
SI_BETTERUI_ABBREVIATE_CURRENCY = "Abbreviate Currency"
SI_BETTERUI_ABBREVIATE_CURRENCY_TOOLTIP = "Abbreviate Currency Tooltip"
SI_BETTERUI_TH_GENERAL_HEADER = "Trading House General"
SI_BETTERUI_TH_GENERAL_DESC = "Trading House General Desc"
SI_BETTERUI_TH_FONT_HEADER = "Trading House Fonts"
SI_BETTERUI_TH_FONT_DESC = "Trading House Fonts Desc"
SI_BETTERUI_FONT_NAME_COLUMN = "Name Column"
SI_BETTERUI_FONT_OTHER_COLUMNS = "Other Columns"
SI_BETTERUI_BANK_NAME_FONT = "Font"
SI_BETTERUI_BANK_NAME_FONT_TOOLTIP = "Font Tooltip"
SI_BETTERUI_BANK_NAME_FONT_SIZE = "Size"
SI_BETTERUI_BANK_NAME_FONT_SIZE_TOOLTIP = "Size Tooltip"
SI_BETTERUI_BANK_NAME_FONT_STYLE = "Style"
SI_BETTERUI_BANK_NAME_FONT_STYLE_TOOLTIP = "Style Tooltip"
SI_BETTERUI_NAME_FONT_RESET = "Reset Name Font"
SI_BETTERUI_NAME_FONT_RESET_TOOLTIP = "Reset Name Font Tooltip"
SI_BETTERUI_BANK_COLUMN_FONT = "Column Font"
SI_BETTERUI_BANK_COLUMN_FONT_TOOLTIP = "Column Font Tooltip"
SI_BETTERUI_BANK_COLUMN_FONT_SIZE = "Column Size"
SI_BETTERUI_BANK_COLUMN_FONT_SIZE_TOOLTIP = "Column Size Tooltip"
SI_BETTERUI_BANK_COLUMN_FONT_STYLE = "Column Style"
SI_BETTERUI_BANK_COLUMN_FONT_STYLE_TOOLTIP = "Column Style Tooltip"
SI_BETTERUI_COLUMN_FONT_RESET = "Reset Column Font"
SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP = "Reset Column Font Tooltip"
SI_BETTERUI_COMPANIONS_GENERAL_HEADER = "Companions General"
SI_BETTERUI_COMPANIONS_GENERAL_DESC = "Companions General Desc"
SI_BETTERUI_COMPANIONS_ENABLE_EQUIPMENT = "Enable Companion Equipment"
SI_BETTERUI_COMPANIONS_ENABLE_EQUIPMENT_TOOLTIP = "Enable Companion Equipment Tooltip"
SI_BETTERUI_INV_GENERAL_HEADER = "Inventory General"
SI_BETTERUI_INV_GENERAL_DESC = "Inventory General Desc"
SI_BETTERUI_QUICK_DESTROY = "Quick Destroy"
SI_BETTERUI_QUICK_DESTROY_TOOLTIP = "Quick Destroy Tooltip"
SI_BETTERUI_QUICK_DESTROY_WARNING = "Quick Destroy Warning"
SI_BETTERUI_ENABLE_BATCH_DESTROY = "Batch Destroy"
SI_BETTERUI_ENABLE_BATCH_DESTROY_TOOLTIP = "Batch Destroy Tooltip"
SI_BETTERUI_ENABLE_BATCH_DESTROY_WARNING = "Batch Destroy Warning"
SI_BETTERUI_BOE_PROTECTION = "Bind-on-Equip Protection"
SI_BETTERUI_BOE_PROTECTION_TOOLTIP = "Bind-on-Equip Protection Tooltip"
SI_BETTERUI_ENABLE_COMPANION_JUNK = "Enable Companion Junk"
SI_BETTERUI_ENABLE_COMPANION_JUNK_TOOLTIP = "Enable Companion Junk Tooltip"
SI_BETTERUI_INV_QUICK_DESTROY = "Quick Destroy"
SI_BETTERUI_INV_QUICK_DESTROY_TOOLTIP = "Quick Destroy Tooltip"
SI_BETTERUI_INV_BATCH_DESTROY = "Batch Destroy"
SI_BETTERUI_INV_BATCH_DESTROY_TOOLTIP = "Batch Destroy Tooltip"
SI_BETTERUI_INV_BOE_PROTECTION = "Bind-on-Equip Protection"
SI_BETTERUI_INV_BOE_PROTECTION_TOOLTIP = "Bind-on-Equip Protection Tooltip"
SI_BETTERUI_INV_COMPANION_JUNK = "Enable Companion Junk"
SI_BETTERUI_INV_COMPANION_JUNK_TOOLTIP = "Enable Companion Junk Tooltip"

local testsPassed = 0
local testsFailed = 0

local function assertEqual(expected, actual, message)
    if expected == actual then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assertTrue(value, message)
    assertEqual(true, value, message)
end

local function findControl(controls, name)
    if type(controls) ~= "table" then
        return nil
    end
    for _, control in ipairs(controls) do
        if control.name == name then
            return control
        end
    end
    return nil
end

print("\n=== Module Settings Panel Tests ===\n")

dofile("Modules/Banking/Settings/SettingsPanel.lua")
dofile("Modules/Vendor/Settings/SettingsPanel.lua")
dofile("Modules/Inventory/Settings/SettingsPanel.lua")
dofile("Modules/TradingHouse/Settings/SettingsPanel.lua")
dofile("Modules/Companions/Settings/SettingsPanel.lua")

print("Test: Banking settings panel applies trigger settings and fallback reset")
BETTERUI.Banking.Settings.RegisterPanel("Bank", "Banking")
local bankingControls = optionControls["BETTERUI_Bank"]
local triggerToggle = findControl(bankingControls, SI_BETTERUI_TRIGGER_SKIP_TYPE)
local triggerSpeed = findControl(bankingControls, SI_BETTERUI_TRIGGER_SKIP)
local bankingReset = findControl(bankingControls, SI_BETTERUI_GENERAL_RESET)
assertTrue(triggerToggle ~= nil, "Banking trigger toggle registered")
assertTrue(triggerSpeed ~= nil, "Banking trigger speed registered")
triggerToggle.setFunc(true)
assertEqual(true, bankingState.useTriggersForSkip, "Banking trigger toggle stores setting")
assertEqual(true, bankingWindow.triggerModeValue, "Banking trigger toggle updates window mode")
triggerSpeed.setFunc("2000")
assertEqual(1000, bankingState.triggerSpeed, "Banking trigger speed clamps to maximum")
bankingState.enableGuildBank = false
bankingState.enableCarousel = false
bankingState.useTriggersForSkip = true
bankingState.triggerSpeed = 2
bankingReset.func()
assertEqual(true, bankingState.enableGuildBank, "Banking reset restores guild bank")
assertEqual(true, bankingState.enableCarousel, "Banking reset restores carousel")
assertEqual(false, bankingState.useTriggersForSkip, "Banking reset restores trigger mode")
assertEqual(10, bankingState.triggerSpeed, "Banking reset restores trigger speed")
assertTrue(sortAlphabetizeCalls > 0, "Settings panels use direct CIM.Settings sort helper")

print("\nTest: Vendor settings panel refreshes scene and fallback reset restores general settings")
BETTERUI.Vendor.Settings.RegisterPanel("Vendor", "Vendor")
local vendorControls = optionControls["BETTERUI_Vendor"]
local currencyToggle = findControl(vendorControls, SI_BETTERUI_ABBREVIATE_CURRENCY)
local vendorReset = findControl(vendorControls, SI_BETTERUI_GENERAL_RESET)
assertTrue(currencyToggle ~= nil, "Vendor currency toggle registered")
currencyToggle.setFunc(true)
assertEqual(true, vendorState.abbreviateVendorCurrency, "Vendor currency toggle stores setting")
assertTrue(vendorInstance.refreshListCount > 0, "Vendor toggle refreshes list when scene is showing")
vendorState.enableCarousel = false
vendorState.enableBatchJunkSell = false
vendorState.abbreviateVendorCurrency = false
vendorReset.func()
assertEqual(true, vendorState.enableCarousel, "Vendor reset restores carousel")
assertEqual(true, vendorState.enableBatchJunkSell, "Vendor reset restores batch junk sell")
assertEqual(true, vendorState.abbreviateVendorCurrency, "Vendor reset restores abbreviate currency")
assertTrue(keybindUpdates > 0, "Vendor refresh updates keybind groups")

print("\nTest: Trading House settings panel registers panel factory data and reset callback")
BETTERUI.TradingHouse.Settings.RegisterPanel("TradingHouse", "Trading House")
local thControls = registeredModulePanel.optionsData
local thReset = findControl(thControls, SI_BETTERUI_GENERAL_RESET)
assertTrue(thReset ~= nil, "Trading House reset button registered")
tradingHouseState.enableCarousel = false
thReset.func()
assertEqual(true, tradingHouseState.enableCarousel, "Trading House reset restores carousel")

print("\nTest: Inventory settings panel uses shared registration seam and reset callback")
BETTERUI.Inventory.Settings.GetCurrencyOptions = function()
    return nil
end
BETTERUI.Inventory.Settings.GetFontOptions = function()
    return nil
end
BETTERUI.Inventory.Settings.RegisterPanel("Inventory", "Inventory")
local inventoryControls = optionControls["BETTERUI_Inventory"]
local inventoryReset = findControl(inventoryControls, SI_BETTERUI_GENERAL_RESET)
assertTrue(inventoryReset ~= nil, "Inventory reset button registered")
inventoryState.enableCarousel = false
inventoryState.useTriggersForSkip = true
inventoryState.triggerSpeed = 2
inventoryState.bindOnEquipProtection = false
inventoryReset.func()
assertEqual(true, inventoryState.enableCarousel, "Inventory reset restores carousel")
assertEqual(false, inventoryState.useTriggersForSkip, "Inventory reset restores trigger mode")
assertEqual(10, inventoryState.triggerSpeed, "Inventory reset restores trigger speed")
assertEqual(true, inventoryState.bindOnEquipProtection, "Inventory reset restores bind-on-equip protection")

print("\nTest: Companions settings panel refreshes junk toggle and reset callback")
BETTERUI.Companions.Settings.RegisterPanel("Companions", "Companions")
local companionsControls = optionControls["BETTERUI_Companions"]
local junkToggle = findControl(companionsControls, SI_BETTERUI_INV_COMPANION_JUNK)
local companionsReset = findControl(companionsControls, SI_BETTERUI_GENERAL_RESET)
assertTrue(junkToggle ~= nil, "Companion junk toggle registered")
junkToggle.setFunc(true)
assertEqual(true, companionsState.enableCompanionJunk, "Companion junk toggle stores setting")
assertTrue(companionsInstance.refreshListCount > 0, "Companion junk toggle refreshes list")
companionsState.enableCompanionEquipment = false
companionsReset.func()
assertEqual(true, companionsState.enableCompanionEquipment, "Companions reset restores equipment setting")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
