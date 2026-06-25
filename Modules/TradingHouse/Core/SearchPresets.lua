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

local function TracePresets(event, phase, data)
    local log = BETTERUI and BETTERUI.Log
    if not (log and log.TraceEvent) then return end
    data = data or {}
    data.module = "TradingHouse"
    data.feature = "search-presets"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if log.SetLastAction then
        log.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = log.CATEGORY or {}
    log.TraceEvent(categories.SEARCH or categories.ACTION, event, phase, data)
end

-- PRESET STORAGE

--- Gets the saved presets list from module settings.
---@return table[] presets Array of {name, searchTable, description} entries
function Presets.GetAll()
    local saved = TH.GetSetting("searchPresets")
    if type(saved) ~= "table" then
        saved = {}
        TH.SetSetting("searchPresets", saved)
    end
    return saved
end

--- Saves the current search criteria as a named preset.
---@param name string Preset display name
---@return boolean success True if saved successfully
function Presets.SaveCurrent(name)
    TracePresets("trading_house.presets", "save_begin", { fn = "Presets.SaveCurrent", name = name })
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SEARCH, "search preset saved", { name = name })
    end
    if not name or name == "" then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", reason = "missingName" })
        return false
    end
    if not TRADING_HOUSE_SEARCH then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", reason = "missingSearch" })
        return false
    end
    if not TRADING_HOUSE_SEARCH.features then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", reason = "missingFeatures" })
        BETTERUI.CIM.UserAlertText("TH:PresetUnavailable",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_UNAVAILABLE")) or "Search features are not available")
        return false
    end

    local searchTable = TRADING_HOUSE_SEARCH:CreateSearchTable()
    if not searchTable then
        TracePresets("trading_house.presets", "save_skipped", { fn = "Presets.SaveCurrent", reason = "missingSearchTable" })
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

    TH.SetSetting("searchPresets", presets)
    TracePresets("trading_house.presets", "saved", { fn = "Presets.SaveCurrent", name = name, presetCount = #presets, description = description, apiVersion = CurrentSchemaVersion() })
    return true
end

--- Loads a preset by index, restoring search filters.
---@param index number Preset index (1-based)
---@return boolean success True if loaded successfully
function Presets.Load(index)
    TracePresets("trading_house.presets", "load_begin", { fn = "Presets.Load", index = index })
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SEARCH, "search preset loaded", { index = index })
    end
    local presets = Presets.GetAll()
    local preset = presets[index]
    if not preset or not preset.searchTable then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, reason = "missingPresetOrSearchTable" })
        return false
    end
    if not TRADING_HOUSE_SEARCH then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, presetName = preset.name, reason = "missingSearch" })
        return false
    end
    if not TRADING_HOUSE_SEARCH.features then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, presetName = preset.name, reason = "missingFeatures" })
        BETTERUI.CIM.UserAlertText("TH:PresetUnavailable",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_UNAVAILABLE")) or "Search features are not available")
        return false
    end

    -- Validate the persisted table before handing it to the native loader. A
    -- cross-version or corrupt SavedVariables entry can error inside
    -- LoadSearchTable, so it must fail gracefully rather than crash the addon.
    if type(preset.searchTable) ~= "table" then
        TracePresets("trading_house.presets", "load_skipped", { fn = "Presets.Load", index = index, presetName = preset.name, reason = "corruptSearchTable" })
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
        BETTERUI.CIM.UserAlertText("TH:PresetCorrupt",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_CORRUPT")) or "This preset could not be loaded")
        return false
    end
    TracePresets("trading_house.presets", "loaded", { fn = "Presets.Load", index = index, presetName = preset.name, apiVersion = preset.apiVersion })
    return true
end

--- Deletes a preset by index.
---@param index number Preset index (1-based)
---@return boolean success True if deleted
function Presets.Delete(index)
    local presets = Presets.GetAll()
    if not presets[index] then
        TracePresets("trading_house.presets", "delete_skipped", { fn = "Presets.Delete", index = index, reason = "missingPreset" })
        return false
    end
    local presetName = presets[index].name
    table.remove(presets, index)
    TH.SetSetting("searchPresets", presets)
    TracePresets("trading_house.presets", "deleted", { fn = "Presets.Delete", index = index, presetName = presetName, presetCount = #presets })
    return true
end

-- DIALOGS

local SAVE_DIALOG_NAME = "BETTERUI_TH_SAVE_SEARCH_PRESET"
local LOAD_DIALOG_NAME = "BETTERUI_TH_LOAD_SEARCH_PRESET"

--- Registers and shows the save-preset dialog (text input for name).
function Presets.ShowSaveDialog()
    if not (ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered(SAVE_DIALOG_NAME)) then
        ZO_Dialogs_RegisterCustomDialog(SAVE_DIALOG_NAME, {
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
    end

    TracePresets("trading_house.presets_dialog", "save_shown", { fn = "Presets.ShowSaveDialog" })
    ZO_Dialogs_ShowGamepadDialog(SAVE_DIALOG_NAME, {})
end

--- Registers and shows the load-preset dialog (list of saved presets).
function Presets.ShowLoadDialog()
    if not (ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered(LOAD_DIALOG_NAME)) then
        ZO_Dialogs_RegisterCustomDialog(LOAD_DIALOG_NAME, {
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
    end

    TracePresets("trading_house.presets_dialog", "load_shown", { fn = "Presets.ShowLoadDialog", presetCount = #Presets.GetAll() })
    ZO_Dialogs_ShowGamepadDialog(LOAD_DIALOG_NAME, {})
end
