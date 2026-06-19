--[[
File: tools/tests/test_savedvars_validation.lua
Purpose: Regression tests for hardened SavedVars loading (SEC-H2). Verifies that
         nil/malformed (non-table) saved data is normalized into a safe settings
         table so addon init can never fault on it, and that the schema-version
         migration gate stamps the current SAVED_VARS_SCHEMA_VERSION.

Usage:
  lua tools/tests/test_savedvars_validation.lua
]]

-- This suite executes the live BetterUI.lua bootstrap root directly so the
-- production load/normalize/migrate path is the thing under test.

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

-- ---------------------------------------------------------------------------
-- Minimal ESO global surface needed to load BetterUI.lua and run Initialize.
-- ---------------------------------------------------------------------------

local eventManager = { handlers = {} }
function eventManager:RegisterForEvent(name, eventCode, callback)
    self.handlers[name] = { eventCode = eventCode, callback = callback }
end
function eventManager:UnregisterForEvent(name)
    self.handlers[name] = nil
end

function GetEventManager()
    return eventManager
end

-- BetterUI.lua caches GetWindowManager() at load; a permissive stub keeps the
-- bootstrap loadable without pulling in the real UI surface.
function GetWindowManager()
    return setmetatable({}, { __index = function() return function() end end })
end

function GetString(value)
    return tostring(value)
end

-- Gamepad-preferred so Initialize's module-setup branch routes through the stubbed
-- BETTERUI.LoadModules() instead of the keyboard-mode file-local that pulls in real
-- modules; this keeps the SavedVars load/normalize/migrate path the thing under test.
local inGamepadPreferredMode = true
function IsInGamepadPreferredMode()
    return inGamepadPreferredMode
end

EVENT_ADD_ON_LOADED = 1
EVENT_GAMEPAD_PREFERRED_MODE_CHANGED = 2
EVENT_PLAYER_ACTIVATED = 3

-- Controllable SavedVars stub. The third positional arg the loader receives is
-- the live SAVED_VARS_SCHEMA_VERSION constant, so capturing it lets the tests
-- assert the migration stamp matches without reaching into the file local.
local nextCharacterResult = nil
local nextAccountResult = nil
local capturedSchemaVersion = nil

ZO_SavedVars = {
    New = function(_, _, version, _, _)
        capturedSchemaVersion = version
        return nextCharacterResult
    end,
    NewAccountWide = function(_, _, version, _, _)
        capturedSchemaVersion = version
        return nextAccountResult
    end,
}

BETTERUI = nil

dofile("BetterUI.lua")

-- Neutralize downstream init that depends on modules not loaded here. The
-- SavedVars load + normalize + migrate path runs unmodified; everything after
-- it is stubbed so a single addon-loaded event exercises only the load path.
local debugMessages = {}
BETTERUI.Debug = function(message)
    debugMessages[#debugMessages + 1] = tostring(message)
end
BETTERUI.DebugError = function(message)
    debugMessages[#debugMessages + 1] = tostring(message)
end
BETTERUI.GetModuleEnabled = function() return false end
BETTERUI.SetSetting = function() end
BETTERUI.UpdateCIMState = function() end
BETTERUI.InitModuleOptions = function() end
BETTERUI.LoadModules = function() return true end
-- InitializeRegisteredModuleSettings() walks MODULE_REGISTRY and calls these per
-- module; stub them so the registered-settings pass is inert (the modules they would
-- reach are not loaded in this isolated bootstrap).
BETTERUI.EnsureModuleSettings = function() return {} end
BETTERUI.ModuleOptions = function() return true end

local SCHEMA_VERSION_KEY = "_schemaVersion"

local function runInitialize(characterResult, accountResult)
    nextCharacterResult = characterResult
    nextAccountResult = accountResult
    BETTERUI.SavedVars = nil
    BETTERUI.GlobalVars = nil
    BETTERUI.Settings = nil
    BETTERUI._initialized = false
    -- pcall so a fault in the hardened path is reported as a failed assertion
    -- rather than aborting the whole suite.
    return pcall(BETTERUI.Initialize, EVENT_ADD_ON_LOADED, BETTERUI.name)
end

print("[SavedVars validation + migration gate]")

-- ---------------------------------------------------------------------------
-- 1. Loader returns nil for both stores: init must not fault and must end up
--    with safe, version-stamped tables carrying a Modules sub-table.
-- ---------------------------------------------------------------------------
local nilOk = runInitialize(nil, nil)
assert_true(nilOk, "init does not error when both SavedVars loaders return nil")
assert_true(type(BETTERUI.SavedVars) == "table", "nil character SavedVars normalized to a table")
assert_true(type(BETTERUI.GlobalVars) == "table", "nil account-wide SavedVars normalized to a table")
assert_true(type(BETTERUI.SavedVars.Modules) == "table", "normalized character table has a Modules sub-table")
assert_true(type(BETTERUI.GlobalVars.Modules) == "table", "normalized account-wide table has a Modules sub-table")
-- Downstream index sites from Initialize must read cleanly off the safe table.
assert_eq(BETTERUI.SavedVars.useAccountWide, false, "useAccountWide is readable on the normalized table")
assert_eq(BETTERUI.Settings, BETTERUI.SavedVars, "character store is selected when useAccountWide is false")
assert_eq(BETTERUI.SavedVars[SCHEMA_VERSION_KEY], capturedSchemaVersion,
    "migration gate stamps the current schema version on the character store")
assert_eq(BETTERUI.GlobalVars[SCHEMA_VERSION_KEY], capturedSchemaVersion,
    "migration gate stamps the current schema version on the account-wide store")
-- firstInstall comes from DefaultSettings (true) and Initialize must clear it
-- without faulting on the substituted defaults table.
assert_eq(BETTERUI.Settings.firstInstall, false, "first-install path runs and clears firstInstall on defaults")

-- ---------------------------------------------------------------------------
-- 2. Loader returns malformed non-table values (corrupt saved data): same
--    safety guarantees as the nil case.
-- ---------------------------------------------------------------------------
local malformedOk = runInitialize("corrupt-string", 42)
assert_true(malformedOk, "init does not error when loaders return malformed non-table values")
assert_true(type(BETTERUI.SavedVars) == "table", "malformed character SavedVars replaced with a safe table")
assert_true(type(BETTERUI.GlobalVars) == "table", "malformed account-wide SavedVars replaced with a safe table")
assert_true(type(BETTERUI.SavedVars.Modules) == "table", "malformed character data still yields a Modules sub-table")
assert_eq(BETTERUI.SavedVars[SCHEMA_VERSION_KEY], capturedSchemaVersion,
    "migration stamp applied even when raw saved data was malformed")

-- ---------------------------------------------------------------------------
-- 3. Pre-migration table (no schema stamp, missing Modules, account-wide
--    selected): migration backfills defaults, preserves user keys, and the
--    account-wide store becomes the active settings target without faulting.
-- ---------------------------------------------------------------------------
local staleCharacter = { useAccountWide = true, firstInstall = false, userKept = "keep-me" }
local staleAccount = { firstInstall = false } -- no Modules, no schema stamp
local staleOk = runInitialize(staleCharacter, staleAccount)
assert_true(staleOk, "init does not error on pre-migration saved tables")
assert_eq(BETTERUI.Settings, BETTERUI.GlobalVars, "account-wide store is selected when useAccountWide is true")
assert_true(type(BETTERUI.GlobalVars.Modules) == "table", "migration creates the missing Modules sub-table")
assert_eq(BETTERUI.SavedVars.userKept, "keep-me", "migration default-merge preserves existing user keys")
assert_eq(BETTERUI.SavedVars[SCHEMA_VERSION_KEY], capturedSchemaVersion,
    "migration stamps the schema version on a previously unstamped character store")
assert_eq(BETTERUI.GlobalVars[SCHEMA_VERSION_KEY], capturedSchemaVersion,
    "migration stamps the schema version on a previously unstamped account-wide store")

-- ---------------------------------------------------------------------------
-- 4. Already-current table: the gate short-circuits and leaves data untouched
--    (no spurious default-merge over current user state).
-- ---------------------------------------------------------------------------
local current = {
    useAccountWide = false,
    firstInstall = false,
    Modules = { Banking = { m_enabled = true } },
}
current[SCHEMA_VERSION_KEY] = capturedSchemaVersion
local currentOk = runInitialize(current, { useAccountWide = false, firstInstall = false, Modules = {} })
assert_true(currentOk, "init does not error on an already-current saved table")
assert_eq(BETTERUI.SavedVars.Modules.Banking.m_enabled, true,
    "current-version data is left intact by the migration gate")
assert_eq(BETTERUI.SavedVars[SCHEMA_VERSION_KEY], capturedSchemaVersion,
    "current-version stamp is preserved")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
