--[[
File: tools/tests/test_cim_integration_support_source.lua
Purpose: Source-level regression checks for shared CIM data, integration, and
         presentation support modules that currently sit at the front of the
         desloppify coverage queue.

Usage:
  lua tools/tests/test_cim_integration_support_source.lua
]]

if false then
    dofile("Modules/CIM/Core/Data/Types.lua")
    dofile("Modules/CIM/Core/Diagnostics/DeveloperDebug.lua")
    dofile("Modules/CIM/Core/Integration/AutoCategoryIntegration.lua")
    dofile("Modules/CIM/Core/Integration/Interfaces.lua")
    dofile("Modules/CIM/Core/Integration/MarketIntegration.lua")
    dofile("Modules/CIM/UI/HeaderSortIntegration.lua")
    dofile("Modules/CIM/Core/Integration/NarrationHelper.lua")
    dofile("Modules/CIM/Core/Integration/ResearchCache.lua")
    dofile("Modules/CIM/Core/Presentation/FontDefinitions.lua")
    dofile("Modules/CIM/Core/Presentation/FontLocalization.lua")
    dofile("Modules/CIM/Core/Presentation/KeybindHelpers.lua")
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

local function assert_eq(actual, expected, label)
    assert_true(actual == expected, string.format("%s (expected %s, got %s)", label, tostring(expected), tostring(actual)))
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
assert_true(typesSource:find('---@field runtimeOwner string') == nil,
    "Types trims documentary runtimeOwner metadata from the shared module contract")
assert_true(typesSource:find('---@field settingsOwner string|nil') == nil,
    "Types trims documentary settingsOwner metadata from the shared module contract")
assert_true(typesSource:find('---@field notes string') == nil,
    "Types trims documentary notes metadata from the shared module contract")
assert_true(typesSource:find('---@class BetterUIKeybindDescriptor') ~= nil,
    "Types defines the shared keybind descriptor type")
assert_true(typesSource:find('---@class BetterUIHeaderSortControllerContract') ~= nil,
    "Types defines the shared header sort controller contract")
assert_true(typesSource:find('---@class BetterUIHeaderSortInstallOptions') ~= nil,
    "Types defines the shared header sort installer contract")
assert_true(typesSource:find('---@class BetterUIHeaderSortIntegration') ~= nil,
    "Types defines the shared header sort integration type")

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
assert_true(interfaces:find("BETTERUI%.CIM%.Interfaces = BETTERUI%.CIM%.Interfaces or %{%}") ~= nil,
    "Interfaces initializes the shared interface validator table")
assert_true(interfaces:find("function BETTERUI%.CIM%.Interfaces%.ValidateModule%(module, requiredFields, expectedName%)") ~= nil,
    "Interfaces exposes ValidateModule")
assert_true(interfaces:find('return false, "Module%.ROOT_CONTRACT must be a table"') ~= nil,
    "Interfaces enforces the root contract presence for real module validation")
assert_true(interfaces:find('init must be a boolean') ~= nil,
    "Interfaces requires an explicit init lifecycle flag")
assert_true(interfaces:find('init is true but Module%.InitModule must be a function') ~= nil,
    "Interfaces enforces InitModule only when init is enabled")
assert_true(interfaces:find('setup is true but Module%.Setup must be a function') ~= nil,
    "Interfaces enforces Setup only when setup is enabled")

local cimModuleSource = read_file("Modules/CIM/Module.lua")
assert_true(cimModuleSource:find("Modules/GeneralInterface/ %(tooltips and shared interface hooks%)") ~= nil,
    "CIM module docs identify GeneralInterface as the tooltip/shared-hooks module")
assert_true(cimModuleSource:find("Modules/Nameplates/ %(nameplates runtime/settings%-owner surface%)") ~= nil,
    "CIM module docs identify Nameplates as its own settings-owner boundary")
assert_true(cimModuleSource:find("Domain%-specific features %(Tooltips, Nameplates%) have been extracted to") == nil,
    "CIM module docs no longer collapse Nameplates into the GeneralInterface boundary note")

local betterUISource = read_file("BetterUI.lua")
assert_true(betterUISource:find("local valid, err = validateFn%(moduleNamespace, nil, moduleName%)") ~= nil,
    "Bootstrap validates real module namespaces instead of synthetic temp tables")
assert_true(betterUISource:find("local shouldCallInit = moduleContract == nil or moduleContract%.init ~= false") ~= nil,
    "Bootstrap derives init execution from the root contract init flag")
assert_true(betterUISource:find("if shouldCallInit then") ~= nil,
    "Bootstrap only calls InitModule for modules that opt into init execution")
assert_true(betterUISource:find("local shouldCallSetup = moduleContract == nil or moduleContract%.setup ~= false") ~= nil,
    "Bootstrap derives setup execution from the root contract setup flag")
assert_true(betterUISource:find("if not shouldCallSetup then") ~= nil,
    "Bootstrap skips Setup calls for modules that intentionally disable setup")

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
assert_true(researchCache:find("function ResearchCache%.GetResearch%(%)") ~= nil,
    "ResearchCache exposes side-effect-free GetResearch")
assert_true(researchCache:find("function ResearchCache%.GetTraits%(%)") ~= nil,
    "ResearchCache exposes GetTraits")
assert_true(researchCache:find("function ResearchCache%.GetResearchTraits%(%)") == nil,
    "ResearchCache removes the deprecated GetResearchTraits wrapper")
assert_true(researchCache:find("RefreshResearchTraits%(%)") ~= nil,
    "ResearchCache still exposes the explicit refresh entrypoint")
assert_true(researchCache:find("BETTERUI%.GetResearch = ResearchCache%.GetResearch") == nil,
    "ResearchCache no longer publishes the deprecated BETTERUI.GetResearch alias")
assert_true(betterUISource:find("researchCache%.RefreshResearchTraits%(%)") ~= nil,
    "Bootstrap refreshes research data through the canonical ResearchCache seam")

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
assert_true(keybindHelpers:find("KEYBIND_STRIP:HasKeybindButtonGroup%(descriptor%)") ~= nil,
    "KeybindHelpers dedupes through the public HasKeybindButtonGroup API")
assert_true(keybindHelpers:find("keybindButtonGroups") == nil,
    "KeybindHelpers never reads the nonexistent keybindButtonGroups field")
assert_true(keybindHelpers:find("function BETTERUI%.Interface%.RemoveOwnedKeybindGroups%(ownedGroups, keepDescriptor%)") ~= nil,
    "KeybindHelpers exposes RemoveOwnedKeybindGroups")
assert_true(keybindHelpers:find("function BETTERUI%.Interface%.RestoreKeybindGroups%(removedGroups%)") ~= nil,
    "KeybindHelpers exposes RestoreKeybindGroups")

local headerSortIntegration = read_file("Modules/CIM/UI/HeaderSortIntegration.lua")
assert_true(headerSortIntegration:find("local function NormalizeControllerContract%(options%)") ~= nil,
    "HeaderSortIntegration normalizes the shared controller contract")
assert_true(headerSortIntegration:find("local function NormalizeKeybindContract%(options%)") ~= nil,
    "HeaderSortIntegration normalizes the shared keybind contract")
assert_true(headerSortIntegration:find("local function NormalizeNavigationContract%(options%)") ~= nil,
    "HeaderSortIntegration normalizes the shared navigation contract")
assert_true(headerSortIntegration:find("controllerContract = controllerContract") ~= nil,
    "HeaderSortIntegration stores the normalized controller contract on the integration")
assert_true(headerSortIntegration:find("function HeaderSortIntegration%.EnsureControllerForOwner%(owner%)") ~= nil,
    "HeaderSortIntegration exposes explicit owner-level ensure semantics")
assert_true(headerSortIntegration:find("function HeaderSortIntegration%.PeekController%(owner%)") ~= nil,
    "HeaderSortIntegration exposes side-effect-free controller peek semantics")
assert_true(headerSortIntegration:find("return HeaderSortIntegration%.PeekController%(owner%)") ~= nil,
    "HeaderSortIntegration getter delegates to side-effect-free peek behavior")

local safeExecute = read_file("Modules/CIM/Core/Diagnostics/SafeExecute.lua")
assert_true(safeExecute:find("local function ResolveOptionalBetterUIPath%(path%)") ~= nil,
    "SafeExecute keeps optional BETTERUI path resolution private")
assert_true(safeExecute:find("local function CallOptionalBetterUIPath%(path, %.%.%.%)") ~= nil,
    "SafeExecute keeps optional BETTERUI dispatch private")
assert_true(safeExecute:find("function BETTERUI%.CIM%.TryResolve") == nil,
    "SafeExecute no longer exports TryResolve")
assert_true(safeExecute:find("function BETTERUI%.CIM%.TryCall") == nil,
    "SafeExecute no longer exports TryCall")
assert_true(safeExecute:find("function BETTERUI%.CIM%.SafeCall%(path, %.%.%.%)") == nil,
    "SafeExecute no longer exports SafeCall")

local generalInterfaceModule = read_file("Modules/GeneralInterface/Module.lua")
assert_true(generalInterfaceModule:find("TryCall/TryResolve") == nil,
    "GeneralInterface module docs no longer advertise TryCall/TryResolve dependencies")

local generalInterfaceSetup = read_file("Modules/GeneralInterface/Setup.lua")
assert_true(generalInterfaceSetup:find("GeneralInterface%.Settings = GeneralInterface%.Settings or %{%}") ~= nil,
    "GeneralInterface setup exposes the settings panel registration seam")
assert_true(generalInterfaceSetup:find("GeneralInterface%.Settings%.RegisterPanel = Init") ~= nil,
    "GeneralInterface setup binds panel construction to the settings seam")
assert_true(
    generalInterfaceSetup:find(
        'BETTERUI%.CIM%.RegisterModulePanelWithLogging%(GeneralInterface, "GeneralInterface", "General", "General Interface"%)') ~=
    nil,
    "GeneralInterface setup routes panel registration through the lifecycle-safe seam")

local resourceOrbFramesModule = read_file("Modules/ResourceOrbFrames/Module.lua")
assert_true(resourceOrbFramesModule:find("ResourceOrbFrames%.Settings = ResourceOrbFrames%.Settings or %{%}") ~= nil,
    "ResourceOrbFrames exposes the settings panel registration seam")
assert_true(resourceOrbFramesModule:find("ResourceOrbFrames%.Settings%.RegisterPanel = InitSettingsPanel") ~= nil,
    "ResourceOrbFrames binds panel construction to the settings seam")
assert_true(
    resourceOrbFramesModule:find(
        'BETTERUI%.CIM%.RegisterModulePanelWithLogging%(ResourceOrbFrames, "ResourceOrbFrames", "ResourceOrbFrames",') ~= nil,
    "ResourceOrbFrames setup routes panel registration through the lifecycle-safe seam")

BETTERUI = {
    name = "BetterUI",
    version = "1.0",
    CIM = {
        CONST = {
            SEARCH_CHILD_NAMES = {},
        },
        UI = {},
        Settings = {},
    },
    Interface = {},
}

LibAddonMenu2 = {
    panelCalls = {},
    optionCalls = {},
    RegisterAddonPanel = function(self, panelId, panelData)
        table.insert(self.panelCalls, { panelId = panelId, panelData = panelData })
    end,
    RegisterOptionControls = function(self, panelId, optionsData)
        table.insert(self.optionCalls, { panelId = panelId, optionsData = optionsData })
    end,
}

KEYBIND_STRIP = {
    added = {},
    removed = {},
    groups = {},
    AddKeybindButtonGroup = function(self, descriptor)
        table.insert(self.added, descriptor)
        self.groups[descriptor] = true
    end,
    RemoveKeybindButtonGroup = function(self, descriptor)
        table.insert(self.removed, descriptor)
        self.groups[descriptor] = nil
    end,
    HasKeybindButtonGroup = function(self, descriptor)
        return self.groups[descriptor] == true
    end,
    UpdateKeybindButtonGroup = function() end,
}

KEYBIND_STRIP_ALIGN_LEFT = 1
KEYBIND_STRIP_ALIGN_RIGHT = 2
SOUNDS = {
    GAMEPAD_MENU_FORWARD = "forward",
    GAMEPAD_MENU_BACK = "back",
}
SI_GAMEPAD_SELECT_OPTION = "Select"
SI_BETTERUI_CLEAR_SEARCH = "Clear"
SI_GAMEPAD_BACK_OPTION = "Back"
SI_GAMEPAD_SCRIPTS_KEYBIND_DOWN = "Down"

function PlaySound(_)
end

function GetString(value)
    return tostring(value)
end

function zo_strlower(value)
    return string.lower(value)
end

BETTERUI.CIM.UI.HeaderSortController = {
    New = function(_, list, columns, onSortChanged)
        local controller = {
            list = list,
            columns = columns,
            onSortChanged = onSortChanged,
            enterCalls = 0,
            exitCalls = 0,
            active = false,
        }

        function controller:CreateKeybindDescriptor(exitCallback)
            self.exitCallback = exitCallback
            return {
                controller = self,
                exitCallback = exitCallback,
            }
        end

        function controller:EnterHeaderMode()
            self.enterCalls = self.enterCalls + 1
            self.active = true
        end

        function controller:ExitHeaderMode()
            self.exitCalls = self.exitCalls + 1
            self.active = false
        end

        return controller
    end,
}

dofile("Modules/CIM/Core/Presentation/KeybindHelpers.lua")
dofile("Modules/CIM/UI/HeaderSortIntegration.lua")
dofile("Modules/CIM/Core/Data/SearchManager.lua")
dofile("Modules/CIM/Core/Settings/SettingsFactory.lua")

do
    local owner = {
        list = {
            GetNumItems = function()
                return 3
            end,
        },
        coreKeybinds = { id = "main" },
    }

    local integration = BETTERUI.CIM.UI.HeaderSortIntegration.Install(owner, {
        list = owner.list,
        columns = {
            { key = "name" },
        },
        controllerContract = {
            field = "headerSortController",
        },
        keybinds = {
            mainDescriptor = owner.coreKeybinds,
        },
    })

    local firstController = BETTERUI.CIM.UI.HeaderSortIntegration.EnsureController(integration)
    local secondController = BETTERUI.CIM.UI.HeaderSortIntegration.EnsureController(integration)
    assert_true(firstController == secondController, "HeaderSortIntegration reuses the same controller instance")

    BETTERUI.CIM.UI.HeaderSortIntegration.EnterHeaderMode(integration)
    BETTERUI.CIM.UI.HeaderSortIntegration.ExitHeaderMode(integration)
    assert_eq(#KEYBIND_STRIP.added, 2, "HeaderSortIntegration swaps header keybinds in and owner keybinds back")
    assert_eq(#KEYBIND_STRIP.removed, 1, "HeaderSortIntegration removes the temporary header keybind group")
end

do
    local lifecycleCalls = {}
    local searchContext = {
        SEARCH_LIFECYCLE = {
            clear = "ClearSearchInput",
            exit = "ExitSearchMode",
            headerActive = "IsHeaderFocused",
            requestEnter = "RequestHeaderFocus",
            onEnter = "OnHeaderEntered",
        },
        searchQuery = "widgets",
        textSearchHeaderControl = {
            IsHidden = function()
                return false
            end,
        },
        ClearSearchInput = function(self)
            table.insert(lifecycleCalls, "clear")
            self.searchQuery = ""
        end,
        ExitSearchMode = function()
            table.insert(lifecycleCalls, "exit")
        end,
        IsHeaderFocused = function()
            return false
        end,
        RequestHeaderFocus = function()
            table.insert(lifecycleCalls, "requestEnter")
        end,
        OnHeaderEntered = function()
            table.insert(lifecycleCalls, "onEnter")
        end,
    }

    local descriptors = BETTERUI.Interface.CreateSearchKeybindDescriptor(searchContext)
    descriptors[1].callback()
    descriptors[2].callback()
    searchContext.searchQuery = ""
    descriptors[2].callback()

    local requestMethod, requestName = BETTERUI.Interface.SearchMixin.GetSearchLifecycleMethod(searchContext, "requestEnter")
    assert_true(type(requestMethod) == "function", "SearchMixin resolves the canonical requestEnter lifecycle method")
    assert_eq(requestName, "RequestHeaderFocus", "SearchMixin returns the canonical requestEnter method name")

    BETTERUI.Interface.SearchMixin.CallSearchLifecycle(searchContext, "requestEnter")
    assert_true(not BETTERUI.Interface.SearchMixin.IsSearchLifecycleHeaderActive(searchContext),
        "SearchMixin reports header lifecycle inactive when the canonical callback returns false")

    local editBox = {
        text = "search text",
        handlers = {},
        GetHandler = function(self, name)
            return self.handlers[name]
        end,
        SetHandler = function(self, name, handler)
            self.handlers[name] = handler
        end,
        GetText = function(self)
            return self.text
        end,
    }
    searchContext.textSearchHeaderFocus = {
        GetEditBox = function()
            return editBox
        end,
    }

    BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(searchContext, {
        isSceneShowing = function()
            return true
        end,
    })
    editBox.handlers.OnFocusGained(editBox)

    assert_eq(table.concat(lifecycleCalls, ","), "exit,clear,exit,requestEnter,requestEnter",
        "SearchMixin routes search descriptor callbacks and focus registration through the canonical lifecycle")
end

do
    local panelId = BETTERUI.CIM.Settings.RegisterModulePanel("Inventory", { name = "Inventory Panel" }, {
        { type = "submenu", name = "Zulu" },
        { type = "submenu", name = "Alpha" },
        { type = "checkbox", name = "Beta" },
        { type = "checkbox", name = "Alpha" },
    })

    assert_eq(panelId, "BETTERUI_Inventory", "SettingsFactory normalizes module names to canonical panel IDs")
    assert_eq(LibAddonMenu2.panelCalls[#LibAddonMenu2.panelCalls].panelId, "BETTERUI_Inventory",
        "SettingsFactory registers the normalized panel ID")
    assert_eq(LibAddonMenu2.optionCalls[#LibAddonMenu2.optionCalls].optionsData[1].name, "Alpha",
        "SettingsFactory sorts top-level submenu registrations alphabetically")
    assert_eq(LibAddonMenu2.optionCalls[#LibAddonMenu2.optionCalls].optionsData[3].name, "Alpha",
        "SettingsFactory sorts contiguous setting controls alphabetically before registration")
end

if failed > 0 then
    error(string.format("test_cim_integration_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_cim_integration_support_source.lua: %d passed", passed))
