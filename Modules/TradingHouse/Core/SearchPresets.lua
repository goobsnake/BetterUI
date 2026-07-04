--[[
File: Modules/TradingHouse/Core/SearchPresets.lua
Purpose: Named search preset save/load system for the Trading House.

TH-001: Search presets for quick access to common guild store searches.

Uses ESO's native TRADING_HOUSE_SEARCH:CreateSearchTable() / LoadSearchTable()
to capture and restore filter state. Presets are stored in BetterUI saved variables.

USAGE:
    -- Save current search as a named preset:
    BETTERUI.TradingHouse.SearchPresets.SaveCurrent("My Preset")

    -- Load a named preset and execute search:
    BETTERUI.TradingHouse.SearchPresets.Load(presetIndex)
]]

local TH = BETTERUI.TradingHouse

TH.SearchPresets = {}
local Presets = TH.SearchPresets

local MODULE_NAME = "TradingHouse"
local PRESETS_KEY = "searchPresets"
local MAX_PRESETS = 20

-- Schema version stamped onto each saved preset. Presets carrying an API
-- version other than the running client's are treated as cross-version and
-- loaded defensively (see Presets.Load). Presets without a version field are
-- legacy entries saved before this guard existed and are still attempted.
local function CurrentSchemaVersion()
    return GetAPIVersion and GetAPIVersion() or nil
end

local function L(stringIdName)
    return GetString(rawget(_G, stringIdName) or stringIdName)
end

local TracePresets = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{ module = "TradingHouse", feature = "search-presets", category = BETTERUI.Log.CATEGORY.SEARCH }
    or function() end

-- PRESET STORAGE

local function CountPresets(presets)
    if type(presets) ~= "table" then
        return 0
    end
    return #presets
end

local function TracePresetState(event, phase, data)
    local L = BETTERUI.Log
    data = data or {}
    if data.presetCount == nil then
        data.presetCount = CountPresets(Presets.GetAll and Presets.GetAll() or nil)
    end
    if L and L.TraceEvent then
        local categories = L.CATEGORY or {}
        local levels = L.LEVEL or {}
        L.TraceEvent(categories.STATE or "STATE", event, phase, data, levels.INFO)
    else
        TracePresets(event, phase, data)
    end
end

local function GetLiveTradingHouseSettings()
    if type(BETTERUI.EnsureModuleSettings) == "function" then
        return BETTERUI.EnsureModuleSettings(MODULE_NAME)
    end

    BETTERUI.Settings = BETTERUI.Settings or {}
    BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
    if type(BETTERUI.Settings.Modules[MODULE_NAME]) ~= "table" then
        BETTERUI.Settings.Modules[MODULE_NAME] = {}
    end
    return BETTERUI.Settings.Modules[MODULE_NAME]
end

local function GetLivePresetList()
    local settings = GetLiveTradingHouseSettings()
    if type(settings[PRESETS_KEY]) ~= "table" then
        settings[PRESETS_KEY] = {}
    end
    return settings[PRESETS_KEY]
end

local function PersistPresetList(presets)
    if type(presets) ~= "table" then
        return false
    end

    local settings = GetLiveTradingHouseSettings()
    settings[PRESETS_KEY] = presets

    if type(TH.SetSetting) == "function" then
        return TH.SetSetting(PRESETS_KEY, presets) ~= false
    end
    if type(BETTERUI.SetSetting) == "function" then
        return BETTERUI.SetSetting(MODULE_NAME, PRESETS_KEY, presets) ~= false
    end
    return true
end

--- Gets the saved presets list from module settings.
---@return table[] presets Array of {name, searchTable, description} entries
function Presets.GetAll()
    return GetLivePresetList()
end

--- Saves the current search criteria as a named preset.
---@param name string Preset display name
---@return boolean success True if saved successfully
function Presets.SaveCurrent(name)
    TracePresets("trading_house.presets", "save_begin", { fn = "Presets.SaveCurrent", name = name })
    TracePresetState("trading_house.presets.save", "begin", { fn = "Presets.SaveCurrent", name = name })
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SEARCH, "search preset saved", { name = name })
    end
    if not name or name == "" then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", reason = "missingName" })
        TracePresetState("trading_house.presets.save", "skipped", { fn = "Presets.SaveCurrent", reason = "missingName" })
        return false
    end
    if not TRADING_HOUSE_SEARCH then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", reason = "missingSearch" })
        TracePresetState("trading_house.presets.save", "skipped", { fn = "Presets.SaveCurrent", name = name, reason = "missingSearch" })
        return false
    end
    if not TRADING_HOUSE_SEARCH.features then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", reason = "missingFeatures" })
        TracePresetState("trading_house.presets.save", "skipped", { fn = "Presets.SaveCurrent", name = name, reason = "missingFeatures" })
        BETTERUI.CIM.UserAlertText("TH:PresetUnavailable",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_UNAVAILABLE")) or "Search features are not available")
        return false
    end

    local searchTable = TRADING_HOUSE_SEARCH:CreateSearchTable()
    if not searchTable then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", reason = "missingSearchTable" })
        TracePresetState("trading_house.presets.save", "skipped", { fn = "Presets.SaveCurrent", name = name, reason = "missingSearchTable" })
        return false
    end

    local description = ""
    if TRADING_HOUSE_SEARCH.GenerateSearchTableShortDescription then
        description = TRADING_HOUSE_SEARCH:GenerateSearchTableShortDescription(searchTable) or ""
    end

    local presets = Presets.GetAll()
    if #presets >= MAX_PRESETS then
        table.remove(presets, 1)
    end

    table.insert(presets, {
        name = name,
        searchTable = searchTable,
        description = description,
        apiVersion = CurrentSchemaVersion(),
    })

    if not PersistPresetList(presets) then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", name = name, presetCount = #presets, reason = "persistFailed" })
        TracePresetState("trading_house.presets.save", "skipped", { fn = "Presets.SaveCurrent", name = name, presetCount = #presets, reason = "persistFailed" })
        return false
    end
    TracePresets("trading_house.presets", "saved", { fn = "Presets.SaveCurrent", name = name, presetCount = #presets, description = description, apiVersion = CurrentSchemaVersion() })
    TracePresetState("trading_house.presets.save", "end", { fn = "Presets.SaveCurrent", name = name, presetCount = #presets, description = description, apiVersion = CurrentSchemaVersion() })
    return true
end

--- Loads a preset by index, restoring search filters.
---@param index number Preset index (1-based)
---@return boolean success True if loaded successfully
function Presets.Load(index)
    TracePresets("trading_house.presets", "load_begin", { fn = "Presets.Load", index = index })
    TracePresetState("trading_house.presets.load", "begin", { fn = "Presets.Load", index = index })
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SEARCH, "search preset loaded", { index = index })
    end
    local presets = Presets.GetAll()
    local preset = presets[index]
    if not preset or not preset.searchTable then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, reason = "missingPresetOrSearchTable" })
        TracePresetState("trading_house.presets.load", "skipped", { fn = "Presets.Load", index = index, presetCount = #presets, reason = "missingPresetOrSearchTable" })
        return false
    end
    if not TRADING_HOUSE_SEARCH then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, presetName = preset.name, reason = "missingSearch" })
        TracePresetState("trading_house.presets.load", "skipped", { fn = "Presets.Load", index = index, presetName = preset.name, presetCount = #presets, reason = "missingSearch" })
        return false
    end
    if not TRADING_HOUSE_SEARCH.features then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, presetName = preset.name, reason = "missingFeatures" })
        TracePresetState("trading_house.presets.load", "skipped", { fn = "Presets.Load", index = index, presetName = preset.name, presetCount = #presets, reason = "missingFeatures" })
        BETTERUI.CIM.UserAlertText("TH:PresetUnavailable",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_UNAVAILABLE")) or "Search features are not available")
        return false
    end

    -- Validate the persisted table before handing it to the native loader. A
    -- cross-version or corrupt SavedVariables entry can error inside
    -- LoadSearchTable, so it must fail gracefully rather than crash the addon.
    if type(preset.searchTable) ~= "table" then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, presetName = preset.name, reason = "corruptSearchTable" })
        TracePresetState("trading_house.presets.load", "skipped", { fn = "Presets.Load", index = index, presetName = preset.name, presetCount = #presets, reason = "corruptSearchTable" })
        BETTERUI.CIM.UserAlertText("TH:PresetCorrupt",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_CORRUPT")) or "This preset could not be loaded")
        return false
    end

    -- Drop presets stamped with an incompatible schema. Legacy presets saved
    -- before versioning (apiVersion == nil) are treated as compatible and are
    -- still attempted under the SafeExecute guard below.
    local current = CurrentSchemaVersion()
    if preset.apiVersion ~= nil and current ~= nil and preset.apiVersion ~= current then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, presetName = preset.name, reason = "apiVersionMismatch", presetApiVersion = preset.apiVersion, currentApiVersion = current })
        TracePresetState("trading_house.presets.load", "skipped", { fn = "Presets.Load", index = index, presetName = preset.name, presetCount = #presets, reason = "apiVersionMismatch", presetApiVersion = preset.apiVersion, currentApiVersion = current })
        BETTERUI.CIM.UserAlertText("TH:PresetIncompatible",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_INCOMPATIBLE")) or "This preset is from a different game version")
        return false
    end

    -- LoadSearchTable is an external native call that can fail unpredictably on
    -- malformed input; wrap it so the failure is contained (tribal-knowledge
    -- "Error Handling Patterns").
    local ok = BETTERUI.CIM.SafeExecute(
        string.format("SearchPresets:Load:%s", tostring(preset.name)),
        function()
            TRADING_HOUSE_SEARCH:LoadSearchTable(preset.searchTable)
        end)
    if not ok then
        TracePresets("trading_house.presets", "load_failed", { fn = "Presets.Load", index = index, presetName = preset.name, reason = "safeExecuteFailed" })
        TracePresetState("trading_house.presets.load", "skipped", { fn = "Presets.Load", index = index, presetName = preset.name, presetCount = #presets, reason = "safeExecuteFailed" })
        BETTERUI.CIM.UserAlertText("TH:PresetCorrupt",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_CORRUPT")) or "This preset could not be loaded")
        return false
    end
    TracePresets("trading_house.presets", "loaded", { fn = "Presets.Load", index = index, presetName = preset.name, apiVersion = preset.apiVersion })
    TracePresetState("trading_house.presets.load", "end", { fn = "Presets.Load", index = index, presetName = preset.name, presetCount = #presets, apiVersion = preset.apiVersion })
    return true
end

--- Deletes a preset by index.
---@param index number Preset index (1-based)
---@return boolean success True if deleted
function Presets.Delete(index)
    local presets = Presets.GetAll()
    TracePresetState("trading_house.presets.delete", "begin", { fn = "Presets.Delete", index = index, presetCount = #presets })
    if not presets[index] then
        TracePresets("trading_house.presets", "delete_skipped", { fn = "Presets.Delete", index = index, reason = "missingPreset" })
        TracePresetState("trading_house.presets.delete", "skipped", { fn = "Presets.Delete", index = index, presetCount = #presets, reason = "missingPreset" })
        return false
    end
    local presetName = presets[index].name
    table.remove(presets, index)
    if not PersistPresetList(presets) then
        TracePresets("trading_house.presets", "delete_skipped", { fn = "Presets.Delete", index = index, presetName = presetName, presetCount = #presets, reason = "persistFailed" })
        TracePresetState("trading_house.presets.delete", "skipped", { fn = "Presets.Delete", index = index, presetName = presetName, presetCount = #presets, reason = "persistFailed" })
        return false
    end
    TracePresets("trading_house.presets", "deleted", { fn = "Presets.Delete", index = index, presetName = presetName, presetCount = #presets })
    TracePresetState("trading_house.presets.delete", "end", { fn = "Presets.Delete", index = index, presetName = presetName, presetCount = #presets })
    return true
end

-- DIALOGS

local SAVE_DIALOG_NAME = "BETTERUI_TH_SAVE_SEARCH_PRESET"
local LOAD_DIALOG_NAME = "BETTERUI_TH_LOAD_SEARCH_PRESET"

--- Registers and shows the save-preset dialog (text input for name).
function Presets.ShowSaveDialog()
    local Dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs
    local saveDialog = Dialogs and Dialogs.GetCurrentInfo and Dialogs.GetCurrentInfo(SAVE_DIALOG_NAME) or nil
    if not (saveDialog and saveDialog._betteruiTradingHouseSavePresetDialog) then
        local registered = Dialogs and Dialogs.RegisterWithPriorChain and Dialogs.RegisterWithPriorChain(SAVE_DIALOG_NAME, {
            _betteruiTradingHouseSavePresetDialog = true,
            canQueue = true,
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = L("SI_BETTERUI_TH_SAVE_PRESET_TITLE"),
            },
            parametricList = {
                {
                    template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                    templateData = {
                        setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                            if control.highlight then
                                control.highlight:SetHidden(not selected)
                            end
                            if control.editBoxControl then
                                control.editBoxControl:SetDefaultText(L("SI_BETTERUI_TH_PRESET_NAME_PLACEHOLDER"))
                            end
                        end,
                        textChangedCallback = function(control)
                            local dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                            if dialog and dialog.data then
                                dialog.data.presetName = control:GetText()
                            end
                        end,
                    },
                },
            },
            buttons = {
                {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog)
                        local data = dialog.data or {}
                        local name = data.presetName
                        TracePresets("trading_house.presets_dialog", "save_confirm", { fn = "Presets.ShowSaveDialog", name = name })
                        if name and name ~= "" then
                            if Presets.SaveCurrent(name) then
                                BETTERUI.CIM.UserAlertText("TH:PresetSaved",
                                    zo_strformat(L("SI_BETTERUI_TH_PRESET_SAVED"), name))
                            end
                        end
                    end,
                },
                {
                    text = SI_DIALOG_CANCEL,
                    callback = function()
                        TracePresets("trading_house.presets_dialog", "save_cancel", { fn = "Presets.ShowSaveDialog" })
                    end,
                },
            },
        })
        if not registered then
            TracePresets("trading_house.presets_dialog", "save_show_skipped", {
                fn = "Presets.ShowSaveDialog",
                reason = "registryRejected",
            })
            return
        end
    end

    TracePresets("trading_house.presets_dialog", "save_shown", { fn = "Presets.ShowSaveDialog" })
    ZO_Dialogs_ShowGamepadDialog(SAVE_DIALOG_NAME, {})
end

--- Registers and shows the load-preset dialog (list of saved presets).
function Presets.ShowLoadDialog()
    local Dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs
    local loadDialog = Dialogs and Dialogs.GetCurrentInfo and Dialogs.GetCurrentInfo(LOAD_DIALOG_NAME) or nil
    if not (loadDialog and loadDialog._betteruiTradingHouseLoadPresetDialog) then
        local registered = Dialogs and Dialogs.RegisterWithPriorChain and Dialogs.RegisterWithPriorChain(LOAD_DIALOG_NAME, {
            _betteruiTradingHouseLoadPresetDialog = true,
            canQueue = true,
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = L("SI_BETTERUI_TH_PRESETS_TITLE"),
            },
            setup = function(dialog)
                local presets = Presets.GetAll()
                dialog.info.parametricList = {}
                TracePresets("trading_house.presets_dialog", "load_setup", { fn = "Presets.ShowLoadDialog", presetCount = #presets })

                if #presets == 0 then
                    table.insert(dialog.info.parametricList, {
                        template = "ZO_GamepadMenuEntryTemplate",
                        text = L("SI_BETTERUI_TH_NO_SAVED_PRESETS"),
                        templateData = {
                            setup = function(control, data, selected)
                                control.label:SetText(L("SI_BETTERUI_TH_NO_SAVED_PRESETS"))
                            end,
                            isEmptyEntry = true,
                        },
                    })
                else
                    for i, preset in ipairs(presets) do
                        local label = preset.name
                        if preset.description and preset.description ~= "" then
                            label = label .. "  |cAAAAAA(" .. preset.description .. ")|r"
                        end
                        table.insert(dialog.info.parametricList, {
                            template = "ZO_GamepadMenuEntryTemplate",
                            text = label,
                            templateData = {
                                setup = function(control, data, selected)
                                    control.label:SetText(label)
                                end,
                                presetIndex = i,
                            },
                        })
                    end
                end

                dialog:setupFunc()
            end,
            buttons = {
                {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog)
                        local targetData = dialog.entryList and dialog.entryList:GetTargetData()
                        TracePresets("trading_house.presets_dialog", "load_confirm", { fn = "Presets.ShowLoadDialog", presetIndex = targetData and targetData.presetIndex or nil })
                        if targetData and targetData.presetIndex then
                            if Presets.Load(targetData.presetIndex) then
                                local preset = Presets.GetAll()[targetData.presetIndex]
                                local name = preset and preset.name or L("SI_BETTERUI_TH_PRESET_GENERIC")
                                BETTERUI.CIM.UserAlertText("TH:PresetLoaded",
                                    zo_strformat(L("SI_BETTERUI_TH_PRESET_LOADED"), name))
                                -- Execute search with loaded filters
                                if TH.BrowseComponent then
                                    TH.BrowseComponent.currentPage = 0
                                    TracePresets("trading_house.presets_dialog", "execute_search", { fn = "Presets.ShowLoadDialog", presetIndex = targetData.presetIndex, presetName = name })
                                    TH.BrowseComponent:ExecuteSearch()
                                end
                            end
                        end
                    end,
                },
                {
                    text = SI_DIALOG_CANCEL,
                    callback = function()
                        TracePresets("trading_house.presets_dialog", "load_cancel", { fn = "Presets.ShowLoadDialog" })
                    end,
                },
                {
                    text = L("SI_BETTERUI_TH_DELETE"),
                    keybind = "DIALOG_RESET",
                    callback = function(dialog)
                        local targetData = dialog.entryList and dialog.entryList:GetTargetData()
                        TracePresets("trading_house.presets_dialog", "delete_confirm", { fn = "Presets.ShowLoadDialog", presetIndex = targetData and targetData.presetIndex or nil })
                        if targetData and targetData.presetIndex then
                            local preset = Presets.GetAll()[targetData.presetIndex]
                            local name = preset and preset.name or L("SI_BETTERUI_TH_PRESET_GENERIC")
                            if Presets.Delete(targetData.presetIndex) then
                                BETTERUI.CIM.UserAlertText("TH:PresetDeleted",
                                    zo_strformat(L("SI_BETTERUI_TH_PRESET_DELETED"), name))
                            end
                        end
                    end,
                },
            },
        })
        if not registered then
            TracePresets("trading_house.presets_dialog", "load_show_skipped", {
                fn = "Presets.ShowLoadDialog",
                reason = "registryRejected",
            })
            return
        end
    end

    TracePresets("trading_house.presets_dialog", "load_shown", { fn = "Presets.ShowLoadDialog", presetCount = #Presets.GetAll() })
    ZO_Dialogs_ShowGamepadDialog(LOAD_DIALOG_NAME, {})
end
