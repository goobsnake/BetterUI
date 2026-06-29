--[[
File: tools/tests/test_settings_panel_registration.lua
Purpose: Regression tests for centralized settings panel registration helpers.
Usage: lua tools/tests/test_settings_panel_registration.lua
]]

local registeredPanels = {}
local registeredOptions = {}
local debugMessages = {}
local passed = 0
local failed = 0

LibAddonMenu2 = {
    RegisterAddonPanel = function(_, panelId, panelData)
        registeredPanels[#registeredPanels + 1] = {
            id = panelId,
            data = panelData,
        }
    end,
    RegisterOptionControls = function(_, panelId, optionsData)
        registeredOptions[#registeredOptions + 1] = {
            id = panelId,
            data = optionsData,
        }
    end,
}

function zo_strlower(value)
    return string.lower(value)
end

BETTERUI = {
    CIM = {
        Settings = {},
    },
}

function BETTERUI.Debug(message)
    debugMessages[#debugMessages + 1] = message
end

-- The settings registration helpers route their diagnostics through
-- BETTERUI.Log.Warn (the unified logger), not BETTERUI.Debug. Capture those warns
-- so the registration-trace assertions below observe them. Mirrors the production
-- seam in Modules/CIM/Core/Settings/SettingsAccessor.lua (TryRegisterModulePanel /
-- RegisterModulePanelWithLogging).
-- Warn captures into debugMessages (the registration-trace assertions watch it);
-- every other level method no-ops, and CATEGORY.<X> resolves to "X", so the stub
-- tracks the live Log surface without the tests needing to enumerate it.
BETTERUI.Log = setmetatable({
    CATEGORY = setmetatable({}, { __index = function(_, key) return key end }),
    Warn = function(_category, message)
        debugMessages[#debugMessages + 1] = message
    end,
}, { __index = function() return function() end end })

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

print("\n=== Settings Panel Registration Tests ===\n")

dofile("Modules/CIM/Core/Settings/SettingsFactory.lua")
dofile("Modules/CIM/Core/Settings/SettingsAccessor.lua")

local options = {
    { type = "submenu", name = "Zulu", controls = {} },
    { type = "submenu", name = "Alpha", controls = {} },
}

BETTERUI.CIM.Settings.RegisterModulePanel("General", { name = "General Interface" }, options)

assert_equal(0, #registeredPanels, "register helper captures module panels instead of registering standalone LAM panels")
assert_equal(0, #registeredOptions, "register helper defers module options to the master panel")
local capturedPanels = BETTERUI.CIM.Settings.GetRegisteredModulePanels()
assert_equal("BETTERUI_General", capturedPanels[1].panelId, "register helper prefixes panel id")
assert_equal("Alpha", capturedPanels[1].optionsData[1].name, "top-level submenu order is centralized before capture")
assert_equal("Zulu", capturedPanels[1].optionsData[2].name, "later submenu remains after alphabetical sort")

local seamRegisterCalls = 0
local lifecycleModule = {
    Settings = {
        RegisterPanel = function(mId, moduleName)
            seamRegisterCalls = seamRegisterCalls + 1
            BETTERUI.CIM.Settings.RegisterModulePanel(mId, { name = moduleName }, {})
        end,
    },
}

assert_equal(true, BETTERUI.CIM.TryRegisterModulePanel(lifecycleModule, "LifecycleModule", "Lifecycle", "Lifecycle"),
    "lifecycle-safe helper returns true when panel seam succeeds")
assert_equal(true, BETTERUI.CIM.TryRegisterModulePanel(lifecycleModule, "LifecycleModule", "Lifecycle", "Lifecycle"),
    "lifecycle-safe helper is idempotent for repeated setup calls")
assert_equal(1, seamRegisterCalls, "settings seam is invoked only once for repeated setup calls")
capturedPanels = BETTERUI.CIM.Settings.GetRegisteredModulePanels()
assert_equal("BETTERUI_Lifecycle", capturedPanels[2].panelId,
    "lifecycle-safe helper routes through normalized module-panel capture")
assert_equal(true, lifecycleModule._panelRegistered, "lifecycle-safe helper marks panel registration state")

local missingSeamOk, missingSeamReason = BETTERUI.CIM.TryRegisterModulePanel({}, "MissingSeamModule", "Missing", "Missing")
assert_equal(false, missingSeamOk, "lifecycle-safe helper returns false when module settings seam is unavailable")
assert_equal("missing_register_panel", missingSeamReason,
    "lifecycle-safe helper surfaces a machine-readable reason when module settings seam is unavailable")
assert_equal(1, #debugMessages, "missing seam emits a single debug trace")

local brokenSeamModule = {
    Settings = {
        RegisterPanel = function()
            error("boom")
        end,
    },
}
local brokenOk, brokenReason = BETTERUI.CIM.TryRegisterModulePanel(brokenSeamModule, "BrokenModule", "Broken", "Broken")
assert_equal(false, brokenOk, "lifecycle-safe helper returns false when panel registration throws")
assert_equal("register_panel_failed", brokenReason,
    "lifecycle-safe helper surfaces a machine-readable reason when registration throws")
assert_equal(2, #debugMessages, "thrown registration adds a second debug trace")

local explicitFailureModule = {
    Settings = {
        RegisterPanel = function()
            return false, "lam_unavailable"
        end,
    },
}
local explicitFailureOk, explicitFailureReason = BETTERUI.CIM.TryRegisterModulePanel(explicitFailureModule, "ExplicitFailureModule",
    "ExplicitFailure", "Explicit Failure")
assert_equal(false, explicitFailureOk, "lifecycle-safe helper propagates explicit seam failures")
assert_equal("lam_unavailable", explicitFailureReason,
    "lifecycle-safe helper preserves explicit machine-readable seam failure reasons")
assert_equal(nil, explicitFailureModule._panelRegistered,
    "lifecycle-safe helper does not mark module state as registered when seam returns false")
assert_equal(3, #debugMessages, "explicit seam rejection emits a debug trace")

local loggedModule = {
    Settings = {
        RegisterPanel = function(mId, moduleName)
            BETTERUI.CIM.Settings.RegisterModulePanel(mId, { name = moduleName }, {})
        end,
    },
}
local loggedOk, loggedReason = BETTERUI.CIM.RegisterModulePanelWithLogging(loggedModule, "LoggedModule", "Logged", "Logged")
assert_equal(true, loggedOk, "logging helper returns success from the underlying registration helper")
assert_equal(nil, loggedReason, "logging helper reports no reason on success")
assert_equal(nil, loggedModule._panelRegistrationReason, "logging helper tracks a nil reason on success")
assert_equal(false, loggedModule._panelRegistrationDeferred, "logging helper marks successful registration as not deferred")
assert_equal(3, #debugMessages, "successful logging helper registration emits no extra debug trace")

local deferredModule = {}
local deferredOk, deferredReason = BETTERUI.CIM.RegisterModulePanelWithLogging(deferredModule, "DeferredModule", "Deferred", "Deferred")
assert_equal(false, deferredOk, "logging helper propagates missing seam failures")
assert_equal("missing_register_panel", deferredReason, "logging helper surfaces the deferred registration reason")
assert_equal("missing_register_panel", deferredModule._panelRegistrationReason,
    "logging helper tracks the deferred registration reason on the module namespace")
assert_equal(true, deferredModule._panelRegistrationDeferred, "logging helper marks missing seams as deferred")
assert_equal(4, #debugMessages, "deferred seams emit only the underlying helper debug trace")

local failingLoggedModule = {
    Settings = {
        RegisterPanel = function()
            return false, "lam_unavailable"
        end,
    },
}
local failingLoggedOk, failingLoggedReason = BETTERUI.CIM.RegisterModulePanelWithLogging(failingLoggedModule,
    "FailingLoggedModule", "FailingLogged", "Failing Logged")
assert_equal(false, failingLoggedOk, "logging helper propagates explicit seam failures")
assert_equal("lam_unavailable", failingLoggedReason, "logging helper preserves explicit seam failure reasons")
assert_equal("lam_unavailable", failingLoggedModule._panelRegistrationReason,
    "logging helper tracks explicit failure reasons on the module namespace")
assert_equal(false, failingLoggedModule._panelRegistrationDeferred,
    "logging helper does not mark explicit failures as deferred")
assert_equal(6, #debugMessages, "explicit seam failures add the standardized registration report trace")
assert_equal("[FailingLoggedModule] Settings panel registration reported: lam_unavailable",
    debugMessages[#debugMessages], "logging helper standardizes the non-deferred failure report format")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
