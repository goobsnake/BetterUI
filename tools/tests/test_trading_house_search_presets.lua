--[[
File: tools/tests/test_trading_house_search_presets.lua
Purpose: Unit tests for Trading House search preset save/load/delete and dialog wiring.
Usage:
  lua tools/tests/test_trading_house_search_presets.lua
]]

BETTERUI = {
    TradingHouse = {},
    CIM = {
        Dialogs = {
            ShowForOwner = function(_, name, data)
                ZO_Dialogs_ShowGamepadDialog(name, data)
                return true
            end,
        },
    },
}

local settings = {}
local alerts = {}
local registeredDialogs = {}
local shownDialogs = {}

local stringValues = {
    SI_BETTERUI_TH_SAVE_PRESET_TITLE = "Save Search Preset",
    SI_BETTERUI_TH_PRESET_NAME_PLACEHOLDER = "Enter preset name...",
    SI_BETTERUI_TH_PRESET_SAVED = "Search preset '<<1>>' saved",
    SI_BETTERUI_TH_PRESETS_TITLE = "Search Presets",
    SI_BETTERUI_TH_NO_SAVED_PRESETS = "No saved presets",
    SI_BETTERUI_TH_PRESET_GENERIC = "preset",
    SI_BETTERUI_TH_PRESET_LOADED = "Loaded preset '<<1>>'",
    SI_BETTERUI_TH_PRESET_DELETED = "Deleted preset '<<1>>'",
    SI_BETTERUI_TH_DELETE = "Delete",
}

function BETTERUI.TradingHouse.GetSetting(key)
    return settings[key]
end

function BETTERUI.TradingHouse.SetSetting(key, value)
    settings[key] = value
end

-- SearchPresets mutates the LIVE module-settings table (GetSetting returns
-- detached clones at runtime); hand it the same table the stubs use.
function BETTERUI.EnsureModuleSettings(moduleName)
    return settings
end

function BETTERUI.CIM.UserAlertText(id, text)
    alerts[#alerts + 1] = { id = id, text = text }
end

-- Mirror the production SafeExecute contract (Modules/CIM/Core/Diagnostics/
-- SafeExecute.lua): pcall the function and return (ok, result) so a throwing
-- native LoadSearchTable is contained rather than propagated.
function BETTERUI.CIM.SafeExecute(context, fn, ...)
    if type(fn) ~= "function" then
        return false, "No function provided"
    end
    return pcall(fn, ...)
end

local apiVersion = 101044
function GetAPIVersion()
    return apiVersion
end

BETTERUI.TradingHouse.BrowseComponent = {
    currentPage = 0,
    executeSearchCount = 0,
    ExecuteSearch = function(self)
        self.executeSearchCount = self.executeSearchCount + 1
    end,
}

TRADING_HOUSE_SEARCH = {
    createCount = 0,
    loadedSearchTable = nil,
    CreateSearchTable = function(self)
        self.createCount = self.createCount + 1
        return {
            query = "sword",
            quality = 3,
            createCount = self.createCount,
        }
    end,
    GenerateSearchTableShortDescription = function(self, searchTable)
        return "Weapons"
    end,
    throwOnLoad = false,
    LoadSearchTable = function(self, searchTable)
        if self.throwOnLoad then
            error("native LoadSearchTable rejected malformed table")
        end
        self.loadedSearchTable = searchTable
    end,
}

GAMEPAD_DIALOGS = {
    PARAMETRIC = 1,
}

SI_DIALOG_CONFIRM = "Confirm"
SI_DIALOG_CANCEL = "Cancel"

function GetString(stringId)
    return stringValues[stringId] or tostring(stringId)
end

function zo_strformat(formatString, ...)
    local formatted = tostring(formatString or "")
    local argCount = select("#", ...)
    for i = 1, argCount do
        local value = tostring(select(i, ...))
        formatted = formatted:gsub("<<" .. tostring(i) .. ">>", value)
    end
    return formatted
end

function ZO_Dialogs_IsDialogRegistered(name)
    return registeredDialogs[name] ~= nil
end

function ZO_Dialogs_RegisterCustomDialog(name, info)
    registeredDialogs[name] = info
end

function BETTERUI.CIM.Dialogs.GetCurrentInfo(name)
    return registeredDialogs[name]
end

function BETTERUI.CIM.Dialogs.Register(name, info)
    registeredDialogs[name] = info
    return true
end

-- Mirrors CIM.Dialogs.RegisterWithPriorChain (BUI-CONS-007): register with
-- prior-setup chaining; the harness only needs registration + return contract.
function BETTERUI.CIM.Dialogs.RegisterWithPriorChain(name, info)
    local prior = registeredDialogs[name]
    if prior and prior.setup and info and info.setup then
        local priorSetup = prior.setup
        local ownSetup = info.setup
        info.setup = function(...)
            priorSetup(...)
            return ownSetup(...)
        end
    end
    registeredDialogs[name] = info
    return true, prior
end

function ZO_Dialogs_ShowGamepadDialog(name, data)
    shownDialogs[#shownDialogs + 1] = { name = name, data = data }
end

local function resetState()
    settings = {}
    alerts = {}
    registeredDialogs = {}
    shownDialogs = {}
    TRADING_HOUSE_SEARCH.createCount = 0
    TRADING_HOUSE_SEARCH.loadedSearchTable = nil
    TRADING_HOUSE_SEARCH.features = nil
    TRADING_HOUSE_SEARCH.throwOnLoad = false
    apiVersion = 101044
    BETTERUI.TradingHouse.BrowseComponent.currentPage = 5
    BETTERUI.TradingHouse.BrowseComponent.executeSearchCount = 0
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
    assert_eq(value == true, true, label)
end

local function assert_not_nil(value, label)
    assert_eq(value ~= nil, true, label)
end

dofile("Modules/TradingHouse/Core/SearchPresets.lua")
local Presets = BETTERUI.TradingHouse.SearchPresets

print("[SearchPresets.GetAll]")
resetState()
local presets = Presets.GetAll()
assert_eq(type(presets), "table", "GetAll initializes a table")
assert_eq(#presets, 0, "GetAll starts empty")
print("[SearchPresets.SaveCurrent]")
assert_eq(Presets.SaveCurrent(""), false, "SaveCurrent rejects empty names")
assert_eq(Presets.SaveCurrent("NoFeatures"), false, "SaveCurrent fails gracefully when search features are not associated")
assert_eq(#alerts, 1, "SaveCurrent alerts when search features are unavailable")

-- Associate features so the remaining save/load tests can run normally.
TRADING_HOUSE_SEARCH.features = {}

assert_true(Presets.SaveCurrent("My Preset"), "SaveCurrent stores valid preset")
presets = Presets.GetAll()
assert_eq(#presets, 1, "SaveCurrent inserts one preset")
assert_eq(presets[1].name, "My Preset", "Saved preset has correct name")
assert_eq(presets[1].description, "Weapons", "Saved preset stores generated description")

for i = 1, 25 do
    Presets.SaveCurrent("Preset " .. tostring(i))
end
presets = Presets.GetAll()
assert_eq(#presets, 20, "SaveCurrent enforces max preset count")
assert_eq(presets[1].name, "Preset 6", "Oldest presets are removed at cap")

print("[SearchPresets.Load/Delete]")
resetState()
settings.searchPresets = {
    { name = "A", searchTable = { query = "axe" }, description = "Axe" },
    { name = "B", searchTable = { query = "bow" }, description = "Bow" },
}
assert_eq(Presets.Load(2), false, "Load fails gracefully when search features are not associated")
assert_eq(#alerts, 1, "Load alerts when search features are unavailable")

TRADING_HOUSE_SEARCH.features = {}

assert_true(Presets.Load(2), "Load succeeds for valid index")
assert_eq(TRADING_HOUSE_SEARCH.loadedSearchTable.query, "bow", "Load passes selected search table")
assert_eq(Presets.Delete(1), true, "Delete succeeds for valid index")
assert_eq(#Presets.GetAll(), 1, "Delete removes one preset")
assert_eq(Presets.GetAll()[1].name, "B", "Delete removes selected entry")

print("[SearchPresets.SaveCurrent stamps schema version]")
resetState()
TRADING_HOUSE_SEARCH.features = {}
assert_true(Presets.SaveCurrent("Versioned"), "SaveCurrent stores valid preset")
assert_eq(Presets.GetAll()[1].apiVersion, 101044, "SaveCurrent stamps the running API version")

print("[SearchPresets.Load robustness]")
-- A corrupt SavedVariables entry whose searchTable is not a table must fail
-- gracefully (no crash) instead of being handed to the native loader.
resetState()
TRADING_HOUSE_SEARCH.features = {}
settings.searchPresets = {
    { name = "Corrupt", searchTable = "not-a-table", description = "bad" },
}
assert_eq(Presets.Load(1), false, "Load rejects a non-table searchTable")
assert_eq(TRADING_HOUSE_SEARCH.loadedSearchTable, nil, "Corrupt preset is never passed to LoadSearchTable")
assert_true(#alerts >= 1, "Load alerts when a preset is corrupt")

-- A preset stamped with an incompatible API version is dropped before load.
resetState()
TRADING_HOUSE_SEARCH.features = {}
settings.searchPresets = {
    { name = "OldVer", searchTable = { query = "ring" }, description = "old", apiVersion = 100000 },
}
assert_eq(Presets.Load(1), false, "Load drops a preset from an incompatible API version")
assert_eq(TRADING_HOUSE_SEARCH.loadedSearchTable, nil, "Incompatible preset is never passed to LoadSearchTable")

-- Legacy presets saved before versioning (no apiVersion) are still attempted.
resetState()
TRADING_HOUSE_SEARCH.features = {}
settings.searchPresets = {
    { name = "Legacy", searchTable = { query = "staff" }, description = "legacy" },
}
assert_true(Presets.Load(1), "Load attempts a legacy (unversioned) preset")
assert_eq(TRADING_HOUSE_SEARCH.loadedSearchTable.query, "staff", "Legacy preset is loaded under SafeExecute")

-- A native LoadSearchTable that errors on a malformed table is contained by
-- SafeExecute: Load returns false rather than propagating the error.
resetState()
TRADING_HOUSE_SEARCH.features = {}
TRADING_HOUSE_SEARCH.throwOnLoad = true
settings.searchPresets = {
    { name = "Throws", searchTable = { query = "mace" }, description = "throws", apiVersion = 101044 },
}
local okCall = pcall(function()
    return Presets.Load(1)
end)
assert_true(okCall, "Load does not propagate a throwing native LoadSearchTable")
assert_eq(Presets.Load(1), false, "Load returns false when native LoadSearchTable errors")

print("[SearchPresets.ShowSaveDialog]")
resetState()
TRADING_HOUSE_SEARCH.features = {}
Presets.ShowSaveDialog()
local saveDialog = registeredDialogs["BETTERUI_TH_SAVE_SEARCH_PRESET"]
assert_not_nil(saveDialog, "Save dialog is registered")
assert_eq(saveDialog.title.text, "Save Search Preset", "Save dialog uses localized title")
assert_eq(saveDialog.parametricList[1].template, "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
    "Save dialog uses valid gamepad text-field template")
assert_eq(shownDialogs[#shownDialogs].name, "BETTERUI_TH_SAVE_SEARCH_PRESET", "Save dialog is shown")

saveDialog.buttons[1].callback({ data = { presetName = "Alpha" } })
assert_eq(#alerts, 1, "Save dialog confirm shows success alert")
assert_true(alerts[1].text:find("Alpha", 1, true) ~= nil, "Save alert includes preset name")
print("[SearchPresets.ShowLoadDialog]")
resetState()
TRADING_HOUSE_SEARCH.features = {}
Presets.ShowLoadDialog()
local loadDialog = registeredDialogs["BETTERUI_TH_LOAD_SEARCH_PRESET"]
assert_not_nil(loadDialog, "Load dialog is registered")
assert_eq(loadDialog.title.text, "Search Presets", "Load dialog uses localized title")
assert_eq(shownDialogs[#shownDialogs].name, "BETTERUI_TH_LOAD_SEARCH_PRESET", "Load dialog is shown")

local emptyDialogInstance = {
    info = {},
    setupFunc = function() end,
}
loadDialog.setup(emptyDialogInstance)
assert_eq(#emptyDialogInstance.info.parametricList, 1, "Load dialog shows one empty-state row when no presets")
assert_eq(emptyDialogInstance.info.parametricList[1].text, "No saved presets", "Empty-state text is localized")

settings.searchPresets = {
    { name = "Tank", searchTable = { query = "shield" }, description = "Defensive" },
}
local populatedDialogInstance = {
    info = {},
    setupFunc = function() end,
}
loadDialog.setup(populatedDialogInstance)
assert_eq(#populatedDialogInstance.info.parametricList, 1, "Load dialog lists available presets")
assert_true(populatedDialogInstance.info.parametricList[1].text:find("Tank", 1, true) ~= nil,
    "Preset list row includes preset name")

local selectDialog = {
    entryList = {
        GetTargetData = function()
            return { presetIndex = 1 }
        end,
    },
}
loadDialog.buttons[1].callback(selectDialog)
assert_eq(TRADING_HOUSE_SEARCH.loadedSearchTable.query, "shield", "Load callback restores selected preset")
assert_eq(BETTERUI.TradingHouse.BrowseComponent.currentPage, 0, "Load callback resets browse page")
assert_eq(BETTERUI.TradingHouse.BrowseComponent.executeSearchCount, 1, "Load callback executes browse search")

loadDialog.buttons[3].callback(selectDialog)
assert_eq(#Presets.GetAll(), 0, "Delete callback removes selected preset")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
