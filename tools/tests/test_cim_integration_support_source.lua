--[[
File: tools/tests/test_cim_integration_support_source.lua
Purpose: Source-level regression checks for shared CIM data, integration, and
         presentation support modules that currently sit at the front of the
         desloppify coverage queue.

Usage:
  lua tools/tests/test_cim_integration_support_source.lua
]]

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

local typesSource = read_file("Modules/CIM/Core/Data/Types.lua")
assert_true(typesSource:find("BETTERUI%.CIM%.Types = %{%}") ~= nil,
    "Types initializes the shared CIM types namespace")
assert_true(typesSource:find('---@alias ModuleName') ~= nil,
    "Types defines the shared ModuleName alias")
assert_true(typesSource:find('---@class BetterUIModuleRootContract') ~= nil,
    "Types defines the BetterUIModuleRootContract type")
assert_true(typesSource:find('---@class KeybindDescriptor') ~= nil,
    "Types defines the shared keybind descriptor type")

local developerDebug = read_file("Modules/CIM/Core/Diagnostics/DeveloperDebug.lua")
assert_true(developerDebug:find("BETTERUI%.CIM%.Debug = %{%}") ~= nil,
    "DeveloperDebug initializes the CIM debug table")
assert_true(developerDebug:find("BETTERUI%.CIM%.Debug%.FLAGS = %{%s*") ~= nil,
    "DeveloperDebug defines shared debug flags")
assert_true(developerDebug:find("function BETTERUI%.CIM%.Debug%.IsEnabled%(%)") ~= nil,
    "DeveloperDebug exposes IsEnabled")
assert_true(developerDebug:find("function BETTERUI%.CIM%.Debug%.ShouldShowDeveloperSettings%(%)") ~= nil,
    "DeveloperDebug exposes ShouldShowDeveloperSettings")
assert_true(developerDebug:find("function BETTERUI%.CIM%.Debug%.Log%(message, category%)") ~= nil,
    "DeveloperDebug exposes Log")
assert_true(developerDebug:find("function BETTERUI%.CIM%.Debug%.SetFlag%(flagName, enabled%)") ~= nil,
    "DeveloperDebug exposes SetFlag")

local autoCategory = read_file("Modules/CIM/Core/Integration/AutoCategoryIntegration.lua")
assert_true(autoCategory:find("BETTERUI%.CIM%.AutoCategoryIntegration = BETTERUI%.CIM%.AutoCategoryIntegration or %{%}") ~= nil,
    "AutoCategoryIntegration initializes the shared integration table")
assert_true(autoCategory:find("function AutoCategoryIntegration%.GetCustomCategory%(itemData%)") ~= nil,
    "AutoCategoryIntegration exposes GetCustomCategory")
assert_true(autoCategory:find("BETTERUI%.GetCustomCategory = AutoCategoryIntegration%.GetCustomCategory") ~= nil,
    "AutoCategoryIntegration publishes the shared GetCustomCategory alias")

local interfaces = read_file("Modules/CIM/Core/Integration/Interfaces.lua")
assert_true(interfaces:find("BETTERUI%.CIM%.Interfaces = %{%}") ~= nil,
    "Interfaces initializes the shared interface validator table")
assert_true(interfaces:find("function BETTERUI%.CIM%.Interfaces%.ValidateModule%(module, requiredFields%)") ~= nil,
    "Interfaces exposes ValidateModule")
assert_true(interfaces:find('return false, "Module%.Setup must be a function"') ~= nil,
    "Interfaces guards the Setup contract")

local marketIntegration = read_file("Modules/CIM/Core/Integration/MarketIntegration.lua")
assert_true(marketIntegration:find("BETTERUI%.CIM%.MarketIntegration = BETTERUI%.CIM%.MarketIntegration or %{%}") ~= nil,
    "MarketIntegration initializes the shared market integration table")
assert_true(marketIntegration:find("function MarketIntegration%.GetMarketPriceInfo%(itemLink, stackCount%)") ~= nil,
    "MarketIntegration exposes GetMarketPriceInfo")
assert_true(marketIntegration:find("marketPricePriority") ~= nil,
    "MarketIntegration reads the shared market price priority setting")

local narrationHelper = read_file("Modules/CIM/Core/Integration/NarrationHelper.lua")
assert_true(narrationHelper:find("BETTERUI%.CIM%.Narration = %{%}") ~= nil,
    "NarrationHelper initializes the shared narration table")
assert_true(narrationHelper:find("function Narration%.RegisterBankingModeLabels%(labelsByMode%)") ~= nil,
    "NarrationHelper exposes RegisterBankingModeLabels")
assert_true(narrationHelper:find("function Narration%.NarrateBankingMode%(mode%)") ~= nil,
    "NarrationHelper exposes NarrateBankingMode")

local researchCache = read_file("Modules/CIM/Core/Integration/ResearchCache.lua")
assert_true(researchCache:find("BETTERUI%.CIM%.ResearchCache = BETTERUI%.CIM%.ResearchCache or %{%}") ~= nil,
    "ResearchCache initializes the shared research cache table")
assert_true(researchCache:find("function ResearchCache%.GetResearch%(forceRefresh%)") ~= nil,
    "ResearchCache exposes GetResearch")
assert_true(researchCache:find("function ResearchCache%.GetTraits%(%)") ~= nil,
    "ResearchCache exposes GetTraits")
assert_true(researchCache:find("BETTERUI%.GetResearch = ResearchCache%.GetResearch") ~= nil,
    "ResearchCache publishes the shared GetResearch alias")

local fontDefinitions = read_file("Modules/CIM/Core/Presentation/FontDefinitions.lua")
assert_true(fontDefinitions:find("BETTERUI%.CIM%.Font%.CHOICES = %{%s*") ~= nil,
    "FontDefinitions defines font choices")
assert_true(fontDefinitions:find("BETTERUI%.CIM%.Font%.VALUES = %{%s*") ~= nil,
    "FontDefinitions defines font values")
assert_true(fontDefinitions:find("BETTERUI%.CIM%.Font%.DEFAULTS = %{%s*") ~= nil,
    "FontDefinitions defines shared default font settings")
assert_true(fontDefinitions:find("function BETTERUI%.CIM%.Font%.NormalizeModuleFontSettings%(m_options, defaults%)") ~= nil,
    "FontDefinitions exposes NormalizeModuleFontSettings")
assert_true(fontDefinitions:find("function BETTERUI%.CIM%.Font%.BuildDescriptor%(fontPath, fontSize, fontStyle%)") ~= nil,
    "FontDefinitions exposes BuildDescriptor")

local fontLocalization = read_file("Modules/CIM/Core/Presentation/FontLocalization.lua")
assert_true(fontLocalization:find("BETTERUI%.CIM%.Font%.Localization = %{%}") ~= nil
        or fontLocalization:find("BETTERUI%.CIM%.Font%.Localization = %{%} end") ~= nil,
    "FontLocalization initializes the shared font-localization table")
assert_true(fontLocalization:find("Localization%.WESTERN_ONLY_FONTS = %{%s*") ~= nil,
    "FontLocalization defines the Western-only font map")
assert_true(fontLocalization:find("function Localization%.GetCurrentLanguageGroup%(%)") ~= nil,
    "FontLocalization exposes GetCurrentLanguageGroup")
assert_true(fontLocalization:find("function Localization%.IsFontLocalizedForLanguage%(fontPath%)") ~= nil,
    "FontLocalization exposes IsFontLocalizedForLanguage")
assert_true(fontLocalization:find("function Localization%.GetFontCompatibilityWarning%(fontPath%)") ~= nil,
    "FontLocalization exposes GetFontCompatibilityWarning")

local keybindHelpers = read_file("Modules/CIM/Core/Presentation/KeybindHelpers.lua")
assert_true(keybindHelpers:find("BETTERUI%.Interface = BETTERUI%.Interface or %{%}") ~= nil,
    "KeybindHelpers initializes the shared interface helper table")
assert_true(keybindHelpers:find("function BETTERUI%.Interface%.EnsureKeybindGroupAdded%(descriptor%)") ~= nil,
    "KeybindHelpers exposes EnsureKeybindGroupAdded")
assert_true(keybindHelpers:find("KEYBIND_STRIP:AddKeybindButtonGroup%(descriptor%)") ~= nil,
    "KeybindHelpers adds missing keybind groups")
assert_true(keybindHelpers:find("KEYBIND_STRIP:UpdateKeybindButtonGroup%(descriptor%)") ~= nil,
    "KeybindHelpers refreshes keybind groups after ensuring them")

if failed > 0 then
    error(string.format("test_cim_integration_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_cim_integration_support_source.lua: %d passed", passed))
