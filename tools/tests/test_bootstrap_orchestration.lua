--[[
File: tools/tests/test_bootstrap_orchestration.lua
Purpose: Regression tests for BetterUI bootstrap helpers, option orchestration,
         and automatic gamepad module loading.

Usage:
  lua tools/tests/test_bootstrap_orchestration.lua
]]

-- This suite executes live production roots directly; avoid dead-code coverage
-- hints so coverage stays tied to behavior.

local passed = 0
local failed = 0

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

local function deepcopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[deepcopy(key)] = deepcopy(nestedValue)
    end
    return copy
end

local function read_source(path)
    local handle = io.open(path, "r")
    assert_true(handle ~= nil, "opens source file " .. tostring(path))
    if not handle then return "" end
    local content = handle:read("*a") or ""
    handle:close()
    return content
end

local function post_hook(control, methodName, callback)
    local original = control[methodName]
    control[methodName] = function(self, ...)
        local results = { original(self, ...) }
        callback(self, ...)
        local unpack_fn = table.unpack or unpack
        return unpack_fn(results)
    end
end

local function pre_hook(control, methodName, callback)
    local original = control[methodName]
    control[methodName] = function(self, ...)
        if callback(self, ...) then
            return
        end
        return original(self, ...)
    end
end

local addonPanels = {}
local optionControls = {}
local registeredEvents = {}
local runtimeSetupCalls = 0
local ensureLifecycleRuntimeStateCalls = 0
local ensurePatchCalls = 0
local researchCalls = 0
local inventoryHookCalls = 0
local inventoryActionHookCalls = 0
local setupCounts = {}
local debugMessages = {}
local tooltipsRuntimeInitialized = 0
local enabledModules = {
    CIM = true,
    Inventory = true,
    Banking = true,
    Vendor = true,
    TradingHouse = true,
    Companions = true,
    Writs = true,
    GeneralInterface = true,
    Nameplates = true,
    ResourceOrbFrames = true,
}

local stringMap = {
    SI_BETTERUI_MASTER_SETTINGS_TITLE = "Master Settings",
    SI_BETTERUI_MASTER_SETTINGS_HEADER = "General Settings",
    SI_BETTERUI_ENABLED_MODULE_SETTINGS_DESC = "Each tab has its module toggle and settings. Disabled modules remain available.",
    SI_BETTERUI_SETTINGS_TAB_GENERAL = "General",
    SI_BETTERUI_SETTINGS_TAB_BANKING = "Banking",
    SI_BETTERUI_SETTINGS_TAB_VENDOR = "Vendor",
    SI_BETTERUI_SETTINGS_TAB_COMPANIONS = "Companions",
    SI_BETTERUI_SETTINGS_TAB_TRADING = "Trading",
    SI_BETTERUI_SETTINGS_TAB_INTERFACE = "Interface",
    SI_BETTERUI_SETTINGS_TAB_NAMEPLATES = "Nameplates",
    SI_BETTERUI_SETTINGS_TAB_INVENTORY = "Inventory",
    SI_BETTERUI_SETTINGS_TAB_RESOURCE_ORBS = "Resource Orbs",
    SI_BETTERUI_SETTINGS_TAB_WRITS = "Writs",
    SI_BETTERUI_ENABLE_GLOBAL_SETTINGS = "Use Global Settings",
    SI_BETTERUI_ENABLE_GLOBAL_TOOLTIP = "Toggle global settings",
    SI_BETTERUI_ENABLE_BANKING = "Enable Banking",
    SI_BETTERUI_ENABLE_BANKING_TOOLTIP = "Banking tooltip",
    SI_BETTERUI_GUILD_BANK_ENABLED = "Enable Guild Bank",
    SI_BETTERUI_GUILD_BANK_ENABLED_TOOLTIP = "Guild bank tooltip",
    SI_BETTERUI_ENABLE_VENDOR = "Enable Vendor",
    SI_BETTERUI_ENABLE_VENDOR_TOOLTIP = "Vendor tooltip",
    SI_BETTERUI_ENABLE_COMPANIONS = "Enable Companions",
    SI_BETTERUI_ENABLE_COMPANIONS_TOOLTIP = "Companions tooltip",
    SI_BETTERUI_ENABLE_TRADING_HOUSE = "Enable Trading House",
    SI_BETTERUI_ENABLE_TRADING_HOUSE_TOOLTIP = "Trading House tooltip",
    SI_BETTERUI_ENABLE_TOOLTIPS = "Enable General Interface",
    SI_BETTERUI_ENABLE_TOOLTIPS_TOOLTIP = "General Interface tooltip",
    SI_BETTERUI_NAMEPLATES_ENABLED = "Enable Nameplates",
    SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP = "Nameplates tooltip",
    SI_BETTERUI_ENABLE_INVENTORY = "Enable Inventory",
    SI_BETTERUI_ENABLE_INVENTORY_TOOLTIP = "Inventory tooltip",
    SI_BETTERUI_ENABLE_ORBS = "Enable Resource Orb Frames",
    SI_BETTERUI_ENABLE_ORBS_TOOLTIP = "Resource Orb tooltip",
    SI_BETTERUI_ENABLE_WRITS = "Enable Writs",
    SI_BETTERUI_ENABLE_WRITS_TOOLTIP = "Writs tooltip",
    SI_BETTERUI_MASTER_RESET_ALL = "Reset All",
    SI_BETTERUI_MASTER_RESET_ALL_TOOLTIP = "Reset all settings",
}

for stringId in pairs(stringMap) do
    _G[stringId] = stringId
end

LibAddonMenu2 = {
    RegisterAddonPanel = function(_, panelId, panelData)
        addonPanels[panelId] = panelData
    end,
    RegisterOptionControls = function(_, panelId, controls)
        optionControls[panelId] = controls
    end,
}

local eventManager = {
    handlers = {},
}

function eventManager:RegisterForEvent(name, eventCode, callback)
    self.handlers[name] = { eventCode = eventCode, callback = callback }
    registeredEvents[name] = callback
end

function eventManager:UnregisterForEvent(name)
    self.handlers[name] = nil
end

ZO_PostHook = post_hook
ZO_PreHook = pre_hook

function GetWindowManager()
    return {}
end

function GetEventManager()
    return eventManager
end

function GetString(value)
    return stringMap[value] or tostring(value)
end

ZO_Object = {}

function ZO_Object:Subclass()
    local subclass = {}
    subclass.__index = subclass
    return setmetatable(subclass, { __index = self })
end

function ZO_Object.New(class)
    return setmetatable({}, class)
end

local scheduledCallId = 0

function zo_callLater(callback, _)
    scheduledCallId = scheduledCallId + 1
    return scheduledCallId
end

function zo_removeCallLater(_) end

function GetCVar(key)
    if key == "language.2" then
        return "en"
    end
    return nil
end

local savedVarsFailures = {
    character = nil,
    accountWide = nil,
}
local nextSavedVarsResult = nil
local nextGlobalVarsResult = nil

ZO_SavedVars = {
    New = function()
        if savedVarsFailures.character ~= nil then
            error(savedVarsFailures.character)
        end
        return deepcopy(nextSavedVarsResult or {
            useAccountWide = false,
            firstInstall = false,
            Modules = {},
        })
    end,
    NewAccountWide = function()
        if savedVarsFailures.accountWide ~= nil then
            error(savedVarsFailures.accountWide)
        end
        return deepcopy(nextGlobalVarsResult or {
            useAccountWide = false,
            firstInstall = false,
            Modules = {},
        })
    end,
}

EVENT_ADD_ON_LOADED = 1
EVENT_GAMEPAD_PREFERRED_MODE_CHANGED = 2
EVENT_PLAYER_ACTIVATED = 3

local inGamepadPreferredMode = false

function IsInGamepadPreferredMode()
    return inGamepadPreferredMode
end

BETTERUI = nil

dofile("BetterUI.lua")

BETTERUI.Debug = function(message)
    debugMessages[#debugMessages + 1] = tostring(message)
end
-- Error/recovery paths route through the ungated DebugError channel.
BETTERUI.DebugError = function(message)
    debugMessages[#debugMessages + 1] = tostring(message)
end
BETTERUI.EnsureModuleSettings = function(moduleName)
    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
    BETTERUI.Settings.Modules[moduleName] = BETTERUI.Settings.Modules[moduleName] or {}
    return BETTERUI.Settings.Modules[moduleName]
end
BETTERUI.GetModuleSettings = function(moduleName)
    return BETTERUI.Settings
        and BETTERUI.Settings.Modules
        and BETTERUI.Settings.Modules[moduleName]
        or nil
end
BETTERUI.GetModuleEnabled = function(moduleName)
    return enabledModules[moduleName] ~= false
end
BETTERUI.SetSetting = function(moduleName, key, value)
    if key == "m_enabled" then
        enabledModules[moduleName] = value
    end
end
BETTERUI.Init_ModulePanel = function(moduleName, moduleDesc)
    return {
        moduleName = moduleName,
        moduleDesc = moduleDesc,
    }
end

BETTERUI.CIM.EventRegistry = {
    EnsureRuntimeState = function()
        ensureLifecycleRuntimeStateCalls = ensureLifecycleRuntimeStateCalls + 1
    end,
}
BETTERUI.CIM.ResearchCache = {
    RefreshResearchTraits = function()
        researchCalls = researchCalls + 1
    end,
}
dofile("Modules/CIM/Core/Lifecycle/DeferredTask.lua")
dofile("Modules/CIM/Core/Lifecycle/RuntimeSetup.lua")
local applyRuntimeSetup = BETTERUI.CIM.RuntimeSetup.Apply
BETTERUI.CIM.RuntimeSetup.Apply = function(settings)
    runtimeSetupCalls = runtimeSetupCalls + 1
    return applyRuntimeSetup(settings)
end
BETTERUI.CIM.TryCall = function(path)
    error("unexpected internal string-path dispatch: " .. tostring(path))
end
BETTERUI.CIM.TryResolve = function(path)
    error("unexpected internal string-path resolution: " .. tostring(path))
end

BETTERUI.CIM.ARCHETYPES = BETTERUI.CIM.ARCHETYPES or {
    RUNTIME_COORDINATOR = "runtime-coordinator",
    THIN_ENTRYPOINT = "thin-entrypoint",
    SETTINGS_OWNER = "settings-owner",
}
BETTERUI.CIM.CONST = BETTERUI.CIM.CONST or {
    DEFAULTS = {
        DEFAULT_RH_SCROLL_SPEED = 10,
        DEFAULT_TOOLTIP_SIZE = 18,
    },
}
BETTERUI.CIM.ApplyModuleSharedSettingsStatics = function(moduleNamespace, moduleName)
    if type(moduleNamespace) ~= "table" then
        return
    end

    moduleNamespace.GetSetting = moduleNamespace.GetSetting or function(_, key, fallback)
        local moduleSettings = BETTERUI.Settings
            and BETTERUI.Settings.Modules
            and BETTERUI.Settings.Modules[moduleName]
            or nil
        local value = moduleSettings and moduleSettings[key]
        if value == nil then
            return fallback
        end
        return value
    end
end
BETTERUI.CIM.InitModuleDefaults = function(_, m_options, defaults, fallbackDefaults, postProcess)
    local options = m_options or {}
    if type(defaults) == "table" then
        for key, value in pairs(defaults) do
            if options[key] == nil then
                options[key] = value
            end
        end
    end
    if type(fallbackDefaults) == "table" then
        for key, value in pairs(fallbackDefaults) do
            if options[key] == nil then
                options[key] = value
            end
        end
    end
    if type(postProcess) == "function" then
        postProcess(options)
    end
    return options
end
BETTERUI.CIM.RegisterModuleAccessors = function() end
BETTERUI.CIM.TryRegisterModulePanel = function()
    return true, nil
end
BETTERUI.CIM.RegisterModulePanelWithLogging = function(moduleNamespace, moduleName, moduleId, moduleLabel)
    return BETTERUI.CIM.TryRegisterModulePanel(moduleNamespace, moduleName, moduleId, moduleLabel)
end
BETTERUI.CIM.Narration = BETTERUI.CIM.Narration or {}
BETTERUI.CIM.Narration.RegisterBankingModeLabels = function() end

BETTERUI.Defaults = BETTERUI.Defaults or {}
BETTERUI.Defaults.GetModuleDefaults = function(moduleName)
    if moduleName == "CIM" then
        return {
            enhanceCompat = false,
            rhScrollSpeed = 10,
            tooltipSize = 18,
            enableTooltipEnhancements = true,
        }
    end
    if moduleName == "GeneralInterface" then
        return {
            chatHistory = 200,
            showMarketPrice = true,
            marketPricePriority = "mm_att_ttc",
            showStyleTrait = true,
            showKnowledgeStatus = true,
            removeDeleteDialog = false,
            guildStoreErrorSuppress = true,
            attIntegration = true,
            mmIntegration = true,
            ttcIntegration = true,
        }
    end
    return {}
end
BETTERUI.Defaults.ApplyModuleDefaults = function(moduleName, options)
    local resolved = options or {}
    local defaults = BETTERUI.Defaults.GetModuleDefaults(moduleName)
    if type(defaults) == "table" then
        for key, value in pairs(defaults) do
            if resolved[key] == nil then
                resolved[key] = value
            end
        end
    end
    return resolved
end

local bootstrapRootFiles = {
    "Modules/CIM/Module.lua",
    "Modules/Inventory/Module.lua",
    "Modules/Banking/Module.lua",
    "Modules/Vendor/Module.lua",
    "Modules/TradingHouse/Module.lua",
    "Modules/Companions/Module.lua",
    "Modules/Writs/Module.lua",
    "Modules/GeneralInterface/Module.lua",
    "Modules/Nameplates/Nameplates.lua",
    "Modules/ResourceOrbFrames/Module.lua",
}

for _, path in ipairs(bootstrapRootFiles) do
    dofile(path)
end

local setupModuleNamespaces = {
    "CIM",
    "Inventory",
    "Banking",
    "Vendor",
    "TradingHouse",
    "Companions",
    "Writs",
    "GeneralInterface",
    "Nameplates",
    "ResourceOrbFrames",
}

local setupShimModules = {
    Inventory = true,
    Banking = true,
    Vendor = true,
    TradingHouse = true,
    Companions = true,
    Writs = true,
    GeneralInterface = true,
}
local runtimeInitNoops = {
    Banking = true,
    Vendor = true,
    TradingHouse = true,
    Companions = true,
}

for _, namespace in ipairs(setupModuleNamespaces) do
    local moduleNamespace = BETTERUI[namespace]
    if type(moduleNamespace) == "table" and namespace ~= "CIM" then
        if runtimeInitNoops[namespace] then
            moduleNamespace.Init = function()
                return true
            end
        end

        local originalSetup = moduleNamespace.Setup
        if setupShimModules[namespace] or type(originalSetup) ~= "function" then
            moduleNamespace.Setup = function()
                setupCounts[namespace] = (setupCounts[namespace] or 0) + 1
                return true
            end
        else
            moduleNamespace.Setup = function(...)
                setupCounts[namespace] = (setupCounts[namespace] or 0) + 1
                return originalSetup(...)
            end
        end
    end
end

BETTERUI.Inventory.HookDestroyItem = function()
    inventoryHookCalls = inventoryHookCalls + 1
end
BETTERUI.Inventory.HookActionDialog = function()
    inventoryActionHookCalls = inventoryActionHookCalls + 1
end
BETTERUI.Inventory.EnsureCompanionEquipPatched = function()
    ensurePatchCalls = ensurePatchCalls + 1
end

local function setSavedVarsResults(savedVars, globalVars)
    nextSavedVarsResult = deepcopy(savedVars)
    nextGlobalVarsResult = deepcopy(globalVars)
    savedVarsFailures.character = nil
    savedVarsFailures.accountWide = nil
end

local function resetSetupState()
    BETTERUI._initialized = false
    BETTERUI._sessionDisabledModules = nil
    BETTERUI.CIM.Tasks = nil
    for _, namespace in ipairs(setupModuleNamespaces) do
        local moduleTable = BETTERUI[namespace]
        if type(moduleTable) == "table" then
            moduleTable._setupComplete = nil
        end
    end
end

print("[Bootstrap orchestration]")
assert_true(type(BETTERUI.Inventory.ROOT_CONTRACT) == "table",
    "bootstrap harness loads the live Inventory root contract")
assert_true(type(BETTERUI.Vendor.ROOT_CONTRACT) == "table",
    "bootstrap harness loads the live Vendor root contract")
assert_true(type(BETTERUI.Nameplates.ROOT_CONTRACT) == "table",
    "bootstrap harness loads the live Nameplates root contract")

BETTERUI.InitModuleOptions()
local controls = optionControls["BETTERUI_Modules"] or {}
local tabControl = controls[1] or {}
local pages = tabControl.pages or {}
local pageByKey = {}
for _, page in ipairs(pages) do
    if page.key then
        pageByKey[page.key] = page
    end
end

assert_eq("custom", tabControl.type, "master settings panel uses a custom tab window control")
assert_eq("General", pages[1] and pages[1].key, "General tab is first for module-agnostic settings")
assert_eq("General", pages[1] and pages[1].name, "General tab uses localized label text")
assert_eq("Trading", pageByKey.TradingHouse and pageByKey.TradingHouse.name,
    "module tabs use short localized labels")
assert_eq("General", pageByKey.Banking and pageByKey.Banking.controls[1].name,
    "Banking tab starts with its General section")
assert_eq("Enable Banking", pageByKey.Banking and pageByKey.Banking.controls[2].name,
    "Banking master module toggle is the top option in General")
assert_eq("General", pageByKey.Writs and pageByKey.Writs.controls[1].name,
    "Writs tab creates a General section without dedicated sub-settings")
assert_eq("Enable Writs", pageByKey.Writs and pageByKey.Writs.controls[2].name,
    "Writs master module toggle is inside General")
assert_true(pageByKey.Inventory ~= nil and pageByKey.ResourceOrbFrames ~= nil,
    "module tab list includes configured module pages")
local nameplateEnableControlCount = 0
for _, control in ipairs((pageByKey.Nameplates and pageByKey.Nameplates.controls) or {}) do
    if control.name == "Enable Nameplates" then
        nameplateEnableControlCount = nameplateEnableControlCount + 1
    end
end
assert_eq(1, nameplateEnableControlCount, "Nameplates tab keeps one master enable gate")
assert_true((pageByKey.Banking and pageByKey.Banking.controls[2].disabled) == nil,
    "module master toggle remains available when the module is off")
assert_true(addonPanels["BETTERUI_Modules"] ~= nil, "master settings panel registers once")

local betterUiSource = read_source("BetterUI.lua")
local bankingSettingsSource = read_source("Modules/Banking/Settings/SettingsPanel.lua")
assert_true(betterUiSource:find("SI_BETTERUI_GUILD_BANK_ENABLED", 1, true) == nil
    and bankingSettingsSource:find("SI_BETTERUI_GUILD_BANK_ENABLED", 1, true) ~= nil,
    "module tab redundant-gate filter does not remove Banking's module-specific Guild Bank setting")
assert_true(betterUiSource:find('if controls[2] and controls[2].type == "description" then', 1, true) ~= nil
    and betterUiSource:find("InsertModuleMasterToggleInGeneralSection", 1, true) ~= nil,
    "module master toggles insert after any General description row")
assert_true(betterUiSource:find("GetSettingsTabButtonsPerRow", 1, true) ~= nil
    and betterUiSource:find("minButtonWidth = 150", 1, true) ~= nil,
    "tab window uses a minimum button width before adding another tab column")
assert_true(betterUiSource:find("CreateSettingsTwinContainer", 1, true) ~= nil
    and betterUiSource:find("RefreshSettingsWidgetTree", 1, true) ~= nil
    and betterUiSource:find("GetWidgetCreationParent", 1, true) ~= nil,
    "tab window keeps half-width rows stable and refreshes visible lazy controls")
assert_true(betterUiSource:find("GetControlHeight", 1, true) ~= nil
    and betterUiSource:find("container:SetHeight(math.max(GetControlHeight(leftWidget), GetControlHeight(rightWidget)))", 1, true) ~= nil,
    "half-width tab rows reserve child height so submenu children cannot collapse together")
assert_true(betterUiSource:find("SETTINGS_TAB_MIN_USABLE_WIDTH = 320", 1, true) ~= nil
    and betterUiSource:find("ReadMeasuredWidth", 1, true) ~= nil
    and betterUiSource:find("local contentWidth = width - 60", 1, true) ~= nil
    and betterUiSource:find("return SETTINGS_TAB_DEFAULT_WIDTH", 1, true) ~= nil,
    "tab layout derives width from the resolved LAM panel instead of the narrow custom tab control")
assert_true(betterUiSource:find("local pageParent = ReadControlField(lamPanel, \"scroll\") or lamPanel or tabControl", 1, true) ~= nil
    and betterUiSource:find("local container = wm:CreateControl(nil, pageParent, CT_CONTROL)", 1, true) ~= nil
    and betterUiSource:find("container.panel = lamPanel or tabControl", 1, true) ~= nil
    and betterUiSource:find("container:SetAnchor(TOPLEFT, tabControl, BOTTOMLEFT, 0, 10)", 1, true) ~= nil,
    "tab pages are S'rendarr-style siblings under the LAM scroll, not children of the tab custom control")
assert_true(betterUiSource:find("local controlPanel", 1, true) ~= nil
    and betterUiSource:find("controlPanel = LAM:RegisterAddonPanel(panelId, panelData)", 1, true) ~= nil
    and betterUiSource:find("RegisterSettingsTabsLamCallbacks(controlPanel, pages)", 1, true) ~= nil
    and betterUiSource:find("LAM-PanelControlsCreated", 1, true) ~= nil,
    "tab creation waits for LAM-PanelControlsCreated with the actual LAM panel, matching S'rendarr's lifecycle")
assert_true(betterUiSource:find("CreateSettingsTabsControlNow", 1, true) ~= nil
    and betterUiSource:find("tabControl.__betterUiTabsPending = true", 1, true) ~= nil
    and betterUiSource:find("defer(function()", 1, true) ~= nil
    and betterUiSource:find("SETTINGS_TAB_CREATE_DELAY_MS", 1, true) ~= nil,
    "tab control creation is deferred until the LAM panel reports settled dimensions")
assert_true(betterUiSource:find("GetSettingsTabButtonPanelHeight", 1, true) ~= nil
    and betterUiSource:find("minHeight = function() return GetSettingsTabButtonPanelHeight(#pages, SETTINGS_TAB_DEFAULT_WIDTH) end", 1, true) ~= nil
    and betterUiSource:find("maxHeight = function() return GetSettingsTabButtonPanelHeight(#pages, SETTINGS_TAB_DEFAULT_WIDTH) end", 1, true) ~= nil
    and betterUiSource:find("maxHeight = 220", 1, true) == nil,
    "tab custom control reserves only the multi-row tab strip height")
assert_true(betterUiSource:find("container.panel = ResolveLamPanel(parent)", 1, true) ~= nil,
    "half-width paired setting containers preserve LAM panel metadata")
assert_true(betterUiSource:find("ConfigureLamPanelProxy", 1, true) == nil
    and betterUiSource:find("GetLamPanelWidth", 1, true) == nil,
    "tab layout avoids proxy width shims that truncate native LAM controls")
assert_true(betterUiSource:find("CreateSettingsSimulatedSubmenuHeader", 1, true) ~= nil
    and betterUiSource:find("AddSettingsLayoutEntry", 1, true) ~= nil
    and betterUiSource:find("CreateSettingsPageWidgets(parent, widgetData.controls, true, context, childStates)", 1, true) ~= nil
    and betterUiSource:find("CreateSettingsPageWidgets(widget, widgetData.controls, true)", 1, true) == nil,
    "submenu tab controls render S'rendarr-style flat sibling controls instead of native nested LAM submenus")
assert_true(betterUiSource:find("ApplySettingsDropdownGeometry", 1, true) ~= nil
    and betterUiSource:find("dropdown.m_containerWidth = width", 1, true) ~= nil
    and betterUiSource:find("combobox:SetDimensions(width, height)", 1, true) ~= nil,
    "tab dropdowns repair combobox and dropdown-list width after LAM creates them")
assert_true(betterUiSource:find("SETTINGS_SIMULATED_SUBMENU_TYPE = \"betterui_submenu\"", 1, true) ~= nil
    and betterUiSource:find("ReflowSettingsPageLayout", 1, true) ~= nil
    and betterUiSource:find("RefreshSettingsPanelScroll", 1, true) ~= nil
    and betterUiSource:find("SetControlHidden(control, not visible)", 1, true) ~= nil
    and betterUiSource:find("RefreshSettingsWidgetTree(layoutParent)", 1, true) ~= nil
    and betterUiSource:find("SETTINGS_SUBMENU_ARROW_DOWN_TEXTURE", 1, true) ~= nil
    and betterUiSource:find("SETTINGS_SUBMENU_ARROW_UP_TEXTURE", 1, true) ~= nil
    and betterUiSource:find("wm:CreateControl(nil, header, CT_TEXTURE)", 1, true) ~= nil
    and betterUiSource:find("RefreshSettingsSubmenuBlockBackground(entries, width)", 1, true) ~= nil
    and betterUiSource:find("disabled = widgetData.disabled", 1, true) ~= nil
    and betterUiSource:find("\t\tApplySettingsSubmenuGeometry(parent, widget)", 1, true) == nil,
    "tab submenus keep full-width flat layout with S'rendarr-style disclosure panels")
assert_true(betterUiSource:find("ApplySettingsEditboxGeometry", 1, true) ~= nil
    and betterUiSource:find("SETTINGS_EDITBOX_SINGLE_LINE_WIDTH = 96", 1, true) ~= nil
    and betterUiSource:find("SETTINGS_EDITBOX_VALUE_COLUMN_START = 405", 1, true) ~= nil
    and betterUiSource:find("container:SetAnchor(LEFT, widget, LEFT, editLeft, 0)", 1, true) ~= nil
    and betterUiSource:find("editbox:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -4, -2)", 1, true) ~= nil,
    "tab editboxes use compact value-column geometry with visible input text")
assert_true(betterUiSource:find("SETTINGS_SUBMENU_SIDE_EXTENSION", 1, true) ~= nil
    and betterUiSource:find("GetSettingsSubmenuVisualWidth(width)", 1, true) ~= nil
    and betterUiSource:find("SETTINGS_SUBMENU_ARROW_SIZE", 1, true) ~= nil,
    "tab submenu headers keep a S'rendarr-style wider header and larger arrow")
assert_true(betterUiSource:find("name = BETTERUI.name", 1, true) ~= nil
    and betterUiSource:find("displayName = BETTERUI.name", 1, true) ~= nil,
    "master settings panel registers with a plain BetterUI add-on list name")
local utilitiesSource = read_source("Modules/CIM/Core/Utilities.lua")
assert_true(betterUiSource:find("BETTERUI.RaiseNativeError", 1, true) ~= nil
    and betterUiSource:find("chatPrint(\"|c0066ff[BETTERUI]|r", 1, true) == nil
    and utilitiesSource:find("IsBuilogEnabled", 1, true) ~= nil
    and utilitiesSource:find("RaiseNativeError", 1, true) ~= nil
    and utilitiesSource:find("chatRouter", 1, true) == nil,
    "DebugError writes to builog or native errors without leaking to chat")
assert_true(betterUiSource:find("SI_BETTERUI_BUILOG_POPUPS", 1, true) == nil,
    "builog settings do not expose a popup toggle that can leak generated breadcrumbs")
assert_true(betterUiSource:find("CloneControlForModuleTab", 1, true) ~= nil
    and betterUiSource:find("CombineModuleDisabled", 1, true) ~= nil
    and betterUiSource:find("clone.disabledLabel = CombineModuleDisabled", 1, true) ~= nil,
    "module tabs clone settings with visible disabled-state wrappers and openable submenus")
assert_true(betterUiSource:find("tabControl.__betterUiTabsCreated = true", 1, true) ~= nil
    and betterUiSource:find("local buttonCreator = rawget(_G, \"LAMCreateControl\") and LAMCreateControl.button", 1, true) ~= nil
    and betterUiSource:find("tabControl.__betterUiTabButtons[index] = buttonControl", 1, true) ~= nil
    and betterUiSource:find("LayoutSettingsTabButtons(tabControl, width)", 1, true) ~= nil,
    "tab window creation uses LAM button controls and relayouts existing buttons on refresh")
assert_true(betterUiSource:find("for index = 1, #pages do\n\t\tEnsureSettingsTabPageCreated(tabControl, index)", 1, true) == nil
    and betterUiSource:find("SelectSettingsTabPage(tabControl, GetInitialSettingsTabIndex(pages))", 1, true) ~= nil,
    "tab window lazily creates selected pages while visible so LAM submenu/dropdown sizing can resolve")
assert_true(betterUiSource:find('{ name = "Writs", namespace = "Writs", dependsOnCIM = true }', 1, true) ~= nil,
    "Writs registry entry declares the CIM dependency")
assert_true(betterUiSource:find('{ moduleName = "Writs", nameStringId = "SI_BETTERUI_ENABLE_WRITS", tooltipStringId = "SI_BETTERUI_ENABLE_WRITS_TOOLTIP", updatesCIM = true }', 1, true) ~= nil,
    "Writs module toggle updates CIM state")
local elementDragSource = read_source("Modules/ResourceOrbFrames/Core/ElementDrag.lua")
assert_true(elementDragSource:find('"BETTERUI_Modules"', 1, true) ~= nil,
    "Resource Orbs settings refresh targets the unified tabbed BetterUI panel")
assert_true(elementDragSource:find('"BETTERUI_ResourceOrbFrames"', 1, true) ~= nil,
    "Resource Orbs settings refresh keeps the legacy panel fallback")
assert_true(elementDragSource:find("m_handleHosts", 1, true) ~= nil
    and elementDragSource:find("hostChanged", 1, true) ~= nil,
    "Resource Orbs drag handles reattach when rebuilt controls replace their host")

BETTERUI.Settings = {
    firstInstall = false,
    Modules = {
        ReturnContract = {
            existing = true,
        },
    },
}
local returnContractModule = {
    InitModule = function(options)
        assert_true(options.existing == true, "module init receives the live settings table before normalization")
        return {
            normalized = true,
        }
    end,
}
local returnContractResult = BETTERUI.ModuleOptions(returnContractModule, BETTERUI.Settings.Modules.ReturnContract, "ReturnContract")
assert_true(returnContractResult == returnContractModule, "module options returns the module namespace after successful init")
assert_true(BETTERUI.Settings.Modules.ReturnContract.normalized == true,
    "module options persists InitModule return tables back into live module settings")
assert_true(BETTERUI.Settings.Modules.ReturnContract.existing == nil,
    "module options replaces stale settings state when InitModule returns a canonical table")

BETTERUI.Settings = {
    firstInstall = false,
    Modules = {},
}
BETTERUI._initialized = false
local firstLoadSucceeded = BETTERUI.LoadModules()
local secondLoadSucceeded = BETTERUI.LoadModules()
assert_true(firstLoadSucceeded, "initial load returns success when all modules setup")
assert_true(secondLoadSucceeded, "repeat load short-circuits as successful once initialized")
assert_eq(runtimeSetupCalls, 0, "LoadModules assumes runtime setup already ran during initialize")
assert_eq(researchCalls, 1, "research cache warms once per bootstrap")
assert_eq(inventoryHookCalls, 1, "inventory pre-setup hook runs once")
assert_eq(inventoryActionHookCalls, 1, "inventory action hook runs once")
assert_eq(setupCounts.Companions, 1, "companions module setup runs once")
assert_eq(setupCounts.TradingHouse, 1, "trading house module setup runs once")
assert_eq(setupCounts.Nameplates, 1, "nameplates setup runs as a first-class standalone module")
assert_eq(ensurePatchCalls, 0, "companion patch helper is not queued by LoadModules directly")

BETTERUI._initialized = false
BETTERUI.Inventory._setupComplete = nil
BETTERUI.Companions._setupComplete = nil
BETTERUI.TradingHouse._setupComplete = nil
BETTERUI.Nameplates._setupComplete = nil
inGamepadPreferredMode = false
local gamepadCallback = registeredEvents["BetterUI_Gamepad"]
assert_true(type(gamepadCallback) == "function", "gamepad mode callback is registered")
gamepadCallback(nil, true)
assert_eq(setupCounts.Companions, 2, "gamepad mode switch reloads companions when bootstrap resets")
assert_eq(setupCounts.TradingHouse, 2, "gamepad mode switch reloads trading house when bootstrap resets")

print("\nTest: Nameplates no longer depends on GeneralInterface enablement")
runtimeSetupCalls = 0
ensureLifecycleRuntimeStateCalls = 0
researchCalls = 0
setupCounts = {}
inventoryHookCalls = 0
inventoryActionHookCalls = 0
enabledModules.GeneralInterface = false
enabledModules.Nameplates = true
setSavedVarsResults({
    useAccountWide = false,
    firstInstall = false,
    Modules = {},
}, {
    useAccountWide = false,
    firstInstall = false,
    Modules = {},
})
resetSetupState()
inGamepadPreferredMode = true
local standaloneNameplatesResult = BETTERUI.Initialize(EVENT_ADD_ON_LOADED, BETTERUI.name)
assert_true(standaloneNameplatesResult, "bootstrap succeeds when Nameplates runs without GeneralInterface")
assert_eq(setupCounts.GeneralInterface, nil, "general interface setup is skipped when disabled")
assert_eq(setupCounts.Nameplates, 1, "nameplates setup still runs when GeneralInterface is disabled")
enabledModules.GeneralInterface = true

print("\nTest: Keyboard initialize runs runtime setup on character settings before keyboard setup")
runtimeSetupCalls = 0
ensureLifecycleRuntimeStateCalls = 0
researchCalls = 0
setupCounts = {}
inventoryHookCalls = 0
inventoryActionHookCalls = 0
setSavedVarsResults({
    useAccountWide = false,
    firstInstall = false,
    Modules = {
        Tooltips = {
            showMarketPrice = true,
            m_enabled = true,
        },
        Inventory = {
            showMarketPrice = false,
        },
    },
}, {
    useAccountWide = false,
    firstInstall = false,
    Modules = {},
})
resetSetupState()
inGamepadPreferredMode = false
local keyboardBootstrapResult = BETTERUI.Initialize(EVENT_ADD_ON_LOADED, BETTERUI.name)
assert_true(keyboardBootstrapResult, "keyboard initialize succeeds with healthy modules")
assert_eq(runtimeSetupCalls, 1, "keyboard initialize runs runtime setup before keyboard-only setup")
assert_eq(ensureLifecycleRuntimeStateCalls, 1, "keyboard initialize ensures runtime lifecycle state")
assert_eq(BETTERUI.Settings, BETTERUI.SavedVars, "character settings remain the active bootstrap target")
assert_eq(BETTERUI.Settings.Modules.GeneralInterface.showMarketPrice, true,
    "keyboard initialize migrates Tooltips settings onto GeneralInterface")
assert_eq(BETTERUI.Settings.Modules.Inventory.showMarketPrice, nil,
    "keyboard initialize clears the legacy Inventory market-price key")
assert_eq(BETTERUI.Settings.Modules.Tooltips, nil,
    "keyboard initialize removes the legacy Tooltips module key")

print("\nTest: Gamepad initialize runs runtime setup on selected account-wide settings")
runtimeSetupCalls = 0
ensureLifecycleRuntimeStateCalls = 0
researchCalls = 0
setupCounts = {}
inventoryHookCalls = 0
inventoryActionHookCalls = 0
setSavedVarsResults({
    useAccountWide = true,
    firstInstall = false,
    Modules = {},
}, {
    useAccountWide = false,
    firstInstall = false,
    Modules = {
        Inventory = {
            showMarketPrice = false,
        },
    },
})
resetSetupState()
inGamepadPreferredMode = true
local gamepadBootstrapResult = BETTERUI.Initialize(EVENT_ADD_ON_LOADED, BETTERUI.name)
assert_true(gamepadBootstrapResult, "gamepad initialize succeeds with healthy modules")
assert_eq(BETTERUI.Settings, BETTERUI.GlobalVars, "account-wide selection is resolved before runtime setup runs")
assert_eq(runtimeSetupCalls, 1, "gamepad initialize runs runtime setup before module loading")
assert_eq(ensureLifecycleRuntimeStateCalls, 1, "gamepad initialize ensures runtime lifecycle state")
assert_eq(researchCalls, 1, "gamepad initialize still warms research during module loading")
assert_eq(BETTERUI.GlobalVars.Modules.GeneralInterface.showMarketPrice, false,
    "gamepad initialize migrates market-price visibility on the active account-wide settings")
assert_eq(BETTERUI.GlobalVars.Modules.Inventory.showMarketPrice, nil,
    "gamepad initialize clears the legacy account-wide Inventory market-price key")
assert_eq(setupCounts.Companions, 1, "gamepad initialize continues through the normal module-loading path")

print("\nTest: SavedVars failures are logged before defaults are used")
runtimeSetupCalls = 0
ensureLifecycleRuntimeStateCalls = 0
researchCalls = 0
setupCounts = {}
inventoryHookCalls = 0
inventoryActionHookCalls = 0
savedVarsFailures.character = "character saved vars exploded"
savedVarsFailures.accountWide = "account-wide saved vars exploded"
nextSavedVarsResult = nil
nextGlobalVarsResult = nil
BETTERUI.DefaultSettings = {
    firstInstall = false,
    useAccountWide = false,
    Modules = {},
}
resetSetupState()
inGamepadPreferredMode = false
local debugStart = #debugMessages
local fallbackBootstrapResult = BETTERUI.Initialize(EVENT_ADD_ON_LOADED, BETTERUI.name)
assert_true(fallbackBootstrapResult, "bootstrap continues when both SavedVars stores fall back to defaults")
assert_eq(runtimeSetupCalls, 1, "fallback bootstrap still runs runtime setup on the default settings table")
assert_eq(ensureLifecycleRuntimeStateCalls, 1, "fallback bootstrap still ensures runtime lifecycle state")

local characterFallbackLogCount = 0
local accountWideFallbackLogCount = 0
for i = debugStart + 1, #debugMessages do
    if debugMessages[i]:find("ZO_SavedVars.New failed, using defaults:", 1, true)
        and debugMessages[i]:find("character saved vars exploded", 1, true) then
        characterFallbackLogCount = characterFallbackLogCount + 1
    end
    if debugMessages[i]:find("ZO_SavedVars.NewAccountWide failed, using defaults:", 1, true)
        and debugMessages[i]:find("account-wide saved vars exploded", 1, true) then
        accountWideFallbackLogCount = accountWideFallbackLogCount + 1
    end
end
assert_eq(characterFallbackLogCount, 1, "character SavedVars failures are logged before falling back")
assert_eq(accountWideFallbackLogCount, 1, "account-wide SavedVars failures are logged before falling back")
savedVarsFailures.character = nil
savedVarsFailures.accountWide = nil
BETTERUI.DefaultSettings = {
    firstInstall = true,
    useAccountWide = false,
    Modules = {},
}

local originalBankingSetup = BETTERUI.Banking.Setup
BETTERUI._initialized = false
BETTERUI._sessionDisabledModules = nil
BETTERUI.Banking._setupComplete = nil
enabledModules.Banking = true
BETTERUI.Banking.Setup = function()
    error("banking setup boom")
end

local debugStart = #debugMessages
local failedLoadResult = BETTERUI.LoadModules()
BETTERUI.Banking.Setup = originalBankingSetup

assert_eq(failedLoadResult, false, "load returns false when any module setup fails")

assert_true(BETTERUI._sessionDisabledModules ~= nil and BETTERUI._sessionDisabledModules.Banking == true,
    "module setup failure session-disables the module")
assert_true(BETTERUI.Banking._setupComplete ~= true, "failed setup does not leave module marked active")

local recoveryLogCount = 0
for i = debugStart + 1, #debugMessages do
    if debugMessages[i]:find("[Recovery] Modules disabled after setup failure (load): Banking", 1, true) then
        recoveryLogCount = recoveryLogCount + 1
    end
end
assert_eq(recoveryLogCount, 1, "load setup failures are aggregated and reported once")

BETTERUI._initialized = false
BETTERUI._sessionDisabledModules = nil
BETTERUI.Banking._setupComplete = nil
enabledModules.Banking = true
BETTERUI.Banking.Setup = function()
    return false, "banking setup veto"
end

debugStart = #debugMessages
BETTERUI.LoadModules()
BETTERUI.Banking.Setup = originalBankingSetup

assert_true(BETTERUI._sessionDisabledModules ~= nil and BETTERUI._sessionDisabledModules.Banking == true,
    "explicit false setup return also session-disables the module")
assert_true(BETTERUI.Banking._setupComplete ~= true, "explicit false setup return does not mark module active")

recoveryLogCount = 0
local falseReturnLogCount = 0
for i = debugStart + 1, #debugMessages do
    if debugMessages[i]:find("[Recovery] Modules disabled after setup failure (load): Banking", 1, true) then
        recoveryLogCount = recoveryLogCount + 1
    end
    if debugMessages[i]:find("[Error] Setup() returned false for 'Banking': banking setup veto", 1, true) then
        falseReturnLogCount = falseReturnLogCount + 1
    end
end
assert_eq(recoveryLogCount, 1, "false-return setup failures are aggregated and reported once")
assert_eq(falseReturnLogCount, 1, "false-return setup failures log the returned detail once")

BETTERUI._initialized = false
BETTERUI._sessionDisabledModules = nil
BETTERUI.Banking._setupComplete = nil
enabledModules.Banking = true
inGamepadPreferredMode = false
BETTERUI.Banking.Setup = function()
    error("keyboard banking setup boom")
end

debugStart = #debugMessages
local keyboardInitializeResult = BETTERUI.Initialize(EVENT_ADD_ON_LOADED, BETTERUI.name)
BETTERUI.Banking.Setup = originalBankingSetup

assert_eq(keyboardInitializeResult, false, "keyboard initialize returns false when a module setup fails")
assert_true(BETTERUI._sessionDisabledModules ~= nil and BETTERUI._sessionDisabledModules.Banking == true,
    "keyboard setup failure session-disables the module")
assert_true(BETTERUI.Banking._setupComplete ~= true, "keyboard setup failure does not leave module marked active")

local keyboardRecoveryLogCount = 0
for i = debugStart + 1, #debugMessages do
    if debugMessages[i]:find("[Recovery] Modules disabled after setup failure (keyboard): Banking", 1, true) then
        keyboardRecoveryLogCount = keyboardRecoveryLogCount + 1
    end
end
assert_eq(keyboardRecoveryLogCount, 1, "keyboard setup failures are aggregated and reported once")

print("[GeneralInterface module + setup]")

local panelRegistration = nil
local inventoryHooks = {}
local sceneSuppressionStates = {}
local invalidatedBags = {}
local mailDeleteCalls = 0
local mailSkipCalls = 0
local lastChatHistoryLines = nil
local errorFrameStateChanges = {}
local storeTooltipControls = {}

BETTERUI.EventManager = eventManager
BETTERUI.PostHook = post_hook
EVENT_MANAGER = eventManager
BETTERUI.Settings = {
    Modules = {
        GeneralInterface = {
            chatHistory = 321,
            guildStoreErrorSuppress = true,
            removeDeleteDialog = false,
        },
        CIM = {
            enableTooltipEnhancements = true,
        },
    },
}

BETTERUI.GetModuleSettings = function(moduleName)
    return BETTERUI.Settings.Modules[moduleName]
end

BETTERUI.Init_ModulePanel = function(moduleName, moduleDesc)
    return {
        moduleName = moduleName,
        moduleDesc = moduleDesc,
    }
end

BETTERUI.CIM.Settings = {
    RegisterModulePanel = function(moduleId, panelData, optionsTable)
        panelRegistration = {
            moduleId = moduleId,
            panelData = panelData,
            optionsTable = optionsTable,
        }
    end,
}
BETTERUI.CIM.TryRegisterModulePanel = function(moduleNamespace, _, moduleId, moduleName)
    if type(moduleNamespace) ~= "table" then return false end
    local settings = moduleNamespace.Settings
    if type(settings) ~= "table" or type(settings.RegisterPanel) ~= "function" then
        return false
    end
    settings.RegisterPanel(moduleId, moduleName)
    return true
end

BETTERUI.CIM.TryCall = function(path)
    if path == "Defaults.ApplyModuleDefaults" then
        return false
    end
    return false
end

BETTERUI.GeneralInterface = {
    Tooltips = {
        InitializeRuntime = function()
            tooltipsRuntimeInitialized = (tooltipsRuntimeInitialized or 0) + 1
        end,
        InventoryHook = function(config)
            inventoryHooks[#inventoryHooks + 1] = config
        end,
        CreateInventoryHookConfig = function(control, tooltipType)
            return {
                tooltipControl = control,
                tooltipType = tooltipType,
            }
        end,
        SetGuildStoreErrorSuppressed = function(value)
            sceneSuppressionStates[#sceneSuppressionStates + 1] = value
        end,
    },
    InvalidateResearchableTraitCache = function(bagId)
        invalidatedBags[#invalidatedBags + 1] = bagId
    end,
}

BETTERUI.Nameplates = {
    GetSettingsOptions = function()
        return {
            { type = "checkbox", name = "Nameplates Enabled" },
        }
    end,
}

GAMEPAD_LEFT_TOOLTIP = "LEFT"
GAMEPAD_RIGHT_TOOLTIP = "RIGHT"
GAMEPAD_MOVABLE_TOOLTIP = "MOVABLE"

for _, tooltipType in ipairs({ GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }) do
    storeTooltipControls[tooltipType] = {
        LayoutStoreWindowItem = function() end,
        AddTopLinesToTopSection = function() end,
    }
end

GAMEPAD_TOOLTIPS = {
    GetTooltip = function(_, tooltipType)
        return storeTooltipControls[tooltipType]
    end,
}

ZO_MailInbox_Gamepad = {
    mainKeybindDescriptor = {},
    InitializeKeybindDescriptors = function() end,
}

MAIL_INBOX_GAMEPAD = {
    mainKeybindDescriptor = {
        { keybind = "UI_SHORTCUT_PRIMARY", callback = function() end },
        {
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                mailDeleteCalls = mailDeleteCalls + 1
            end,
        },
    },
    InitializeKeybindDescriptors = function() end,
    Delete = function()
        mailSkipCalls = mailSkipCalls + 1
    end,
}

SCENE_SHOWING = 11
SCENE_HIDDEN = 12
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 21
EVENT_INVENTORY_FULL_UPDATE = 22
EVENT_LUA_ERROR = 23

local registeredSceneCallback = nil
SCENE_MANAGER = {
    scenes = {
        gamepad_trading_house = {
            RegisterCallback = function(_, _, callback)
                registeredSceneCallback = callback
            end,
        },
    },
}

-- U50: chat buffers are reached through the chat systems' container/window objects.
KEYBOARD_CHAT_SYSTEM = {
    containers = {
        {
            windows = {
                {
                    buffer = {
                        SetMaxHistoryLines = function(_, value)
                            lastChatHistoryLines = value
                        end,
                    },
                },
            },
        },
    },
}
GAMEPAD_CHAT_SYSTEM = KEYBOARD_CHAT_SYSTEM

eventManager.RegisterForEvent = function(self, name, eventCode, callback)
    self.handlers[name] = { eventCode = eventCode, callback = callback }
    if name == "ErrorFrame" then
        errorFrameStateChanges[#errorFrameStateChanges + 1] = { action = "register", eventCode = eventCode }
    end
end

eventManager.UnregisterForEvent = function(self, name)
    self.handlers[name] = nil
    if name == "ErrorFrame" then
        errorFrameStateChanges[#errorFrameStateChanges + 1] = { action = "unregister" }
    end
end

dofile("Modules/GeneralInterface/Module.lua")
assert_true(BETTERUI.GeneralInterface.Nameplates == nil,
    "GeneralInterface module does not retain a legacy Nameplates compatibility alias")
assert_true(BETTERUI.GeneralInterface.GetNameplatesNamespace == nil,
    "GeneralInterface module no longer exports a Nameplates ownership resolver seam")

local defaultOptions = BETTERUI.GeneralInterface.InitModule({})
assert_eq(defaultOptions.chatHistory, 200, "GeneralInterface.InitModule backfills chat history")
assert_eq(defaultOptions.marketPricePriority, "mm_att_ttc", "GeneralInterface.InitModule backfills market priority")
assert_eq(defaultOptions.guildStoreErrorSuppress, true, "GeneralInterface.InitModule backfills guild store suppression")

BETTERUI.GeneralInterface.GetSettingsOptions = function()
    return {
        { type = "checkbox", name = "General Interface Option" },
    }
end

dofile("Modules/GeneralInterface/Setup.lua")
local setupInstallers = BETTERUI.GeneralInterface._SetupInstallers or {}
assert_true(type(setupInstallers.InitPanel) == "function",
    "GeneralInterface.Setup exports the panel installer helper")
assert_true(type(setupInstallers.InstallMailDeleteHook) == "function",
    "GeneralInterface.Setup exports the mail installer helper")
assert_true(type(setupInstallers.InstallInventoryTooltipHooks) == "function",
    "GeneralInterface.Setup exports the inventory-tooltip installer helper")
assert_true(type(setupInstallers.InstallStoreTooltipHooks) == "function",
    "GeneralInterface.Setup exports the store-tooltip installer helper")
assert_true(type(setupInstallers.InstallTopLineSuppressionHooks) == "function",
    "GeneralInterface.Setup exports the top-line suppression installer helper")
assert_true(type(setupInstallers.RegisterGuildStoreSuppression) == "function",
    "GeneralInterface.Setup exports the guild-store suppression installer helper")
assert_true(type(setupInstallers.RegisterTooltipCacheInvalidation) == "function",
    "GeneralInterface.Setup exports the tooltip-cache installer helper")
assert_true(type(setupInstallers.ApplyChatHistoryLimit) == "function",
    "GeneralInterface.Setup exports the chat-history installer helper")

setupInstallers.InitPanel("General", "General Interface")
assert_eq(panelRegistration.moduleId, "General", "Panel installer registers the General settings panel directly")

setupInstallers.InstallInventoryTooltipHooks(BETTERUI.GeneralInterface.Tooltips)
assert_eq(3, #inventoryHooks, "Inventory-tooltip installer wires all three gamepad tooltips")
inventoryHooks = {}

setupInstallers.InstallStoreTooltipHooks()
assert_true(storeTooltipControls[GAMEPAD_LEFT_TOOLTIP]._betteruiStoreLayoutHookInstalled == true,
    "Store-tooltip installer marks its hook installation")

setupInstallers.InstallTopLineSuppressionHooks()
assert_true(storeTooltipControls[GAMEPAD_LEFT_TOOLTIP]._betteruiTopLinesHookInstalled == true,
    "Top-line installer marks its hook installation")

registeredSceneCallback = nil
setupInstallers.RegisterGuildStoreSuppression(BETTERUI.GeneralInterface.Tooltips)
assert_true(registeredSceneCallback ~= nil, "Guild-store installer registers its scene callback")

setupInstallers.RegisterTooltipCacheInvalidation()
assert_true(eventManager.handlers["BETTERUI_Tooltips_InvSingle"] ~= nil,
    "Tooltip-cache installer registers the single-slot invalidation event")
assert_true(eventManager.handlers["BETTERUI_Tooltips_InvFull"] ~= nil,
    "Tooltip-cache installer registers the full-inventory invalidation event")

lastChatHistoryLines = nil
setupInstallers.ApplyChatHistoryLimit()
assert_eq(321, lastChatHistoryLines, "Chat-history installer reapplies the saved history limit")

BETTERUI.GeneralInterface.Setup()

assert_eq(panelRegistration.moduleId, "General", "GeneralInterface.Setup registers the General settings panel")
assert_true(type(panelRegistration.optionsTable[1]) == "table", "GeneralInterface.Setup builds an option table")
assert_eq(1, tooltipsRuntimeInitialized, "GeneralInterface.Setup initializes tooltip runtime behind the setup seam")
assert_eq(3, #inventoryHooks, "GeneralInterface.Setup installs inventory hooks for all three gamepad tooltips")
assert_true(registeredSceneCallback ~= nil, "GeneralInterface.Setup registers the trading-house scene callback")
assert_true(storeTooltipControls[GAMEPAD_LEFT_TOOLTIP]._betteruiStoreLayoutHookInstalled == true,
    "GeneralInterface.Setup installs store layout hooks")
assert_true(storeTooltipControls[GAMEPAD_LEFT_TOOLTIP]._betteruiTopLinesHookInstalled == true,
    "GeneralInterface.Setup installs native top-line suppression hooks")
assert_eq(lastChatHistoryLines, 321, "GeneralInterface.Setup reapplies the saved chat history limit")

local deleteDescriptor = MAIL_INBOX_GAMEPAD.mainKeybindDescriptor[2]
deleteDescriptor.callback()
assert_eq(mailDeleteCalls, 1, "Mail delete hook preserves the native confirmation flow by default")

BETTERUI.Settings.Modules.GeneralInterface.removeDeleteDialog = true
deleteDescriptor.callback()
assert_eq(mailSkipCalls, 1, "Mail delete hook can bypass confirmation when the setting is enabled")

registeredSceneCallback(nil, SCENE_SHOWING)
registeredSceneCallback(nil, SCENE_HIDDEN)
assert_eq(sceneSuppressionStates[1], true, "Guild-store scene showing suppresses error spam")
assert_eq(sceneSuppressionStates[2], false, "Guild-store scene hidden restores error spam")
-- The suppression flag is the only mechanism; BetterUI must never unregister
-- the game's native EVENT_LUA_ERROR handler (doing so killed error display
-- game-wide because re-registering without a callback is a no-op).
assert_eq(#errorFrameStateChanges, 0, "Guild-store suppression never touches the native error frame handler")

eventManager.handlers["BETTERUI_Tooltips_InvSingle"].callback(nil, 123)
eventManager.handlers["BETTERUI_Tooltips_InvFull"].callback(nil, 456)
assert_eq(invalidatedBags[1], 123, "Single-slot inventory updates invalidate the trait cache")
assert_eq(invalidatedBags[2], 456, "Full inventory updates invalidate the trait cache")

print("[Archetype contract validation]")
dofile("Modules/CIM/Core/Integration/Interfaces.lua")
local validateModule = BETTERUI.CIM.Interfaces.ValidateModule

local validSettingsOwnerModule = {
    ARCHETYPE = "settings-owner",
    ROOT_CONTRACT = {
        name = "ResourceOrbFrames",
        archetype = "settings-owner",
        init = true,
        setup = true,
    },
    InitModule = function(options) return options end,
    Setup = function() end,
    Settings = {
        RegisterPanel = function() end,
    },
}
local validSettingsOwner, validSettingsOwnerErr = validateModule(validSettingsOwnerModule, nil, "ResourceOrbFrames")
assert_true(validSettingsOwner and validSettingsOwnerErr == nil,
    "settings-owner contract passes when it exposes a settings registration surface")

local missingSettingsSurfaceModule = {
    ARCHETYPE = "settings-owner",
    ROOT_CONTRACT = {
        name = "ResourceOrbFrames",
        archetype = "settings-owner",
        init = true,
        setup = true,
    },
    InitModule = function(options) return options end,
    Setup = function() end,
}
local missingSettingsSurfaceValid = validateModule(missingSettingsSurfaceModule, nil, "ResourceOrbFrames")
assert_true(missingSettingsSurfaceValid == false,
    "settings-owner contract rejects modules that do not expose settings surfaces")

local invalidThinEntrypointModule = {
    ARCHETYPE = "thin-entrypoint",
    ROOT_CONTRACT = {
        name = "GeneralInterface",
        archetype = "thin-entrypoint",
        init = true,
        setup = false,
    },
    InitModule = function(options) return options end,
}
local invalidThinEntrypoint = validateModule(invalidThinEntrypointModule, nil, "GeneralInterface")
assert_true(invalidThinEntrypoint == false,
    "thin-entrypoint contract rejects modules that disable setup")

local unsupportedArchetypeModule = {
    ARCHETYPE = "experimental",
    ROOT_CONTRACT = {
        name = "GeneralInterface",
        archetype = "experimental",
        init = true,
        setup = true,
    },
    InitModule = function(options) return options end,
    Setup = function() end,
}
local unsupportedArchetypeValid = validateModule(unsupportedArchetypeModule, nil, "GeneralInterface")
assert_true(unsupportedArchetypeValid == false,
    "module validation rejects unsupported archetype values")

print("[ResourceOrbFrames element drag live settings]")
-- Reproduce the production bug where ElementDrag receives a snapshot getter
-- (BETTERUI.GetModuleSettings) while live settings live in GetModuleSettingsLive.
-- The drag layer must still persist offsets into the live table.
BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}
BETTERUI.ResourceOrbFrames.Utils = BETTERUI.ResourceOrbFrames.Utils or { Settings = {} }

local dragLiveSettings = {
    elementPositionsUnlocked = true,
    elementPositions = {
        castBar = { locked = false, offsetX = 0, offsetY = 0 },
    },
}
local function dragSnapshotGetter()
    return deepcopy(dragLiveSettings)
end
BETTERUI.ResourceOrbFrames.Utils.Settings.GetLive = function() return dragLiveSettings end

_G.WINDOW_MANAGER = {
    CreateControl = function(_, name, parent, _)
        local control = {
            name = name,
            parent = parent,
            handlers = {},
            _alpha = 1,
            _mouseEnabled = true,
        }
        control.SetDimensions = function() end
        control.SetAnchor = function() end
        control.SetDrawLayer = function() end
        control.SetDrawLevel = function() end
        control.SetCenterColor = function() end
        control.SetEdgeColor = function() end
        control.SetColor = function() end
        control.SetAlpha = function(self, a) self._alpha = a end
        control.SetMouseEnabled = function(self, b) self._mouseEnabled = b end
        control.SetHandler = function(self, eventName, fn) self.handlers[eventName] = fn end
        return control
    end,
}
_G.MOUSE_BUTTON_INDEX_LEFT = 1
_G.CT_BACKDROP = 1
_G.DL_OVERLAY = 1
local dragMouseX, dragMouseY = 100, 100
_G.GetUIMousePosition = function() return dragMouseX, dragMouseY end
_G.GetFrameTimeMilliseconds = function() return 0 end

dofile("Modules/ResourceOrbFrames/Core/ElementDrag.lua")
local Drag = BETTERUI.ResourceOrbFrames.Drag
local dragHost = WINDOW_MANAGER:CreateControl("DragHost", nil, CT_BACKDROP)
local dragApplyCalls = 0
local dragHandle = Drag.AttachDragHandle(dragHost, "castBar", dragSnapshotGetter, function() dragApplyCalls = dragApplyCalls + 1 end)
assert_true(dragHandle ~= nil, "drag handle attaches with mock controls")

dragMouseX, dragMouseY = 100, 100
dragHandle.handlers["OnMouseDown"](dragHandle, MOUSE_BUTTON_INDEX_LEFT)
dragMouseX, dragMouseY = 120, 130
dragHandle.handlers["OnUpdate"]()
local dragX, dragY = Drag.GetOffset("castBar", dragSnapshotGetter)
assert_eq(dragX, 20, "drag writes offsetX to live settings even when getter returns a clone")
assert_eq(dragY, 30, "drag writes offsetY to live settings even when getter returns a clone")
assert_eq(dragApplyCalls, 1, "drag applyCallback fires when offset changes")

dragMouseX, dragMouseY = 120, 130
dragHandle.handlers["OnMouseUp"](dragHandle, MOUSE_BUTTON_INDEX_LEFT)
dragX, dragY = Drag.GetOffset("castBar", dragSnapshotGetter)
assert_eq(dragX, 20, "mouse up preserves offsetX in live settings")
assert_eq(dragY, 30, "mouse up preserves offsetY in live settings")

Drag.ResetOffset("castBar", dragSnapshotGetter)
dragX, dragY = Drag.GetOffset("castBar", dragSnapshotGetter)
assert_eq(dragX, 0, "ResetOffset clears offsetX in live settings")
assert_eq(dragY, 0, "ResetOffset clears offsetY in live settings")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
