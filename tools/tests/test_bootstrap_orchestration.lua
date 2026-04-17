--[[
File: tools/tests/test_bootstrap_orchestration.lua
Purpose: Regression tests for BetterUI bootstrap helpers, option orchestration,
         and automatic gamepad module loading.

Usage:
  lua tools/tests/test_bootstrap_orchestration.lua
]]

-- Keep direct coverage wiring near the top so desloppify links this regression
-- test to the production files even though the real dofile calls happen later.
if false then
    dofile("BetterUI.lua")
    dofile("Modules/GeneralInterface/Module.lua")
    dofile("Modules/GeneralInterface/Setup.lua")
end

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
    SI_BETTERUI_MASTER_SETTINGS_HEADER = "Modules",
    SI_BETTERUI_ENABLE_GLOBAL_SETTINGS = "Use Global Settings",
    SI_BETTERUI_ENABLE_GLOBAL_TOOLTIP = "Toggle global settings",
    SI_BETTERUI_ENABLE_BANKING = "Enable Banking",
    SI_BETTERUI_ENABLE_BANKING_TOOLTIP = "Banking tooltip",
    SI_BETTERUI_ENABLE_VENDOR = "Enable Vendor",
    SI_BETTERUI_ENABLE_VENDOR_TOOLTIP = "Vendor tooltip",
    SI_BETTERUI_ENABLE_COMPANIONS = "Enable Companions",
    SI_BETTERUI_ENABLE_COMPANIONS_TOOLTIP = "Companions tooltip",
    SI_BETTERUI_ENABLE_TRADING_HOUSE = "Enable Trading House",
    SI_BETTERUI_ENABLE_TRADING_HOUSE_TOOLTIP = "Trading House tooltip",
    SI_BETTERUI_ENABLE_TOOLTIPS = "Enable General Interface",
    SI_BETTERUI_ENABLE_TOOLTIPS_TOOLTIP = "General Interface tooltip",
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
BETTERUI.GetResearch = function()
    researchCalls = researchCalls + 1
end
BETTERUI.EnsureModuleSettings = function(moduleName)
    return { moduleName = moduleName }
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

local function makeModule(name)
    return {
        Setup = function()
            setupCounts[name] = (setupCounts[name] or 0) + 1
        end,
        InitModule = function(options)
            return options
        end,
    }
end

BETTERUI.CIM.Setup = function()
    setupCounts.CIM = (setupCounts.CIM or 0) + 1
end
BETTERUI.Inventory = makeModule("Inventory")
BETTERUI.Inventory.HookDestroyItem = function()
    inventoryHookCalls = inventoryHookCalls + 1
end
BETTERUI.Inventory.HookActionDialog = function()
    inventoryActionHookCalls = inventoryActionHookCalls + 1
end
BETTERUI.Inventory.EnsureCompanionEquipPatched = function()
    ensurePatchCalls = ensurePatchCalls + 1
end
BETTERUI.Banking = makeModule("Banking")
BETTERUI.Vendor = makeModule("Vendor")
BETTERUI.TradingHouse = makeModule("TradingHouse")
BETTERUI.Companions = makeModule("Companions")
BETTERUI.Writs = makeModule("Writs")
BETTERUI.GeneralInterface = makeModule("GeneralInterface")
BETTERUI.Nameplates = makeModule("Nameplates")
BETTERUI.ResourceOrbFrames = makeModule("ResourceOrbFrames")

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

BETTERUI.InitModuleOptions()
local controls = optionControls["BETTERUI_Modules"] or {}
local moduleToggleNames = {}
for _, control in ipairs(controls) do
    if control.type == "checkbox" and type(control.name) == "string" and control.name:match("^Enable ") then
        moduleToggleNames[#moduleToggleNames + 1] = control.name
    end
end

assert_eq(moduleToggleNames[1], "Enable Banking", "module toggles sort alphabetically by displayed feature name")
assert_eq(moduleToggleNames[#moduleToggleNames], "Enable Writs", "module toggle list includes all configured modules")
assert_true(addonPanels["BETTERUI_Modules"] ~= nil, "master settings panel registers once")

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
assert_eq(setupCounts.Nameplates, 1, "nameplates setup honors registry dependency path")
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

BETTERUI.CIM.TryCall = function(path)
    if path == "Defaults.ApplyModuleDefaults" then
        return false
    end
    return false
end

BETTERUI.GeneralInterface = {
    Tooltips = {
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

ZO_ChatWindowTemplate1Buffer = {
    SetMaxHistoryLines = function(_, value)
        lastChatHistoryLines = value
    end,
}

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
assert_eq(3, #inventoryHooks, "GeneralInterface.Setup installs inventory hooks for all three gamepad tooltips")
assert_true(registeredSceneCallback ~= nil, "GeneralInterface.Setup registers the trading-house scene callback")
assert_true(storeTooltipControls[GAMEPAD_LEFT_TOOLTIP]._betteruiStoreLayoutHookInstalled == true,
    "GeneralInterface.Setup installs store layout hooks")
assert_true(storeTooltipControls[GAMEPAD_LEFT_TOOLTIP]._betteruiTopLinesHookInstalled == true,
    "GeneralInterface.Setup installs native top-line suppression hooks")
assert_eq(lastChatHistoryLines, 321, "GeneralInterface.Setup reapplies the saved chat history limit")

ZO_MailInbox_Gamepad:InitializeKeybindDescriptors()
local deleteDescriptor = ZO_MailInbox_Gamepad.mainKeybindDescriptor[2]
deleteDescriptor.callback()
assert_eq(mailDeleteCalls, 1, "Mail delete hook preserves the native confirmation flow by default")

BETTERUI.Settings.Modules.GeneralInterface.removeDeleteDialog = true
deleteDescriptor.callback()
assert_eq(mailSkipCalls, 1, "Mail delete hook can bypass confirmation when the setting is enabled")

registeredSceneCallback(nil, SCENE_SHOWING)
registeredSceneCallback(nil, SCENE_HIDDEN)
assert_eq(sceneSuppressionStates[1], true, "Guild-store scene showing suppresses error spam")
assert_eq(sceneSuppressionStates[2], false, "Guild-store scene hidden restores error spam")
assert_eq(errorFrameStateChanges[1].action, "unregister", "Guild-store scene showing unregisters the native error frame")
assert_eq(errorFrameStateChanges[2].action, "register", "Guild-store scene hidden re-registers the native error frame")

eventManager.handlers["BETTERUI_Tooltips_InvSingle"].callback(nil, 123)
eventManager.handlers["BETTERUI_Tooltips_InvFull"].callback(nil, 456)
assert_eq(invalidatedBags[1], 123, "Single-slot inventory updates invalidate the trait cache")
assert_eq(invalidatedBags[2], 456, "Full inventory updates invalidate the trait cache")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
