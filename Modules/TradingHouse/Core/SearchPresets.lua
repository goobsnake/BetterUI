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

local function L(stringIdName)
    return GetString(rawget(_G, stringIdName) or stringIdName)
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
    if not name or name == "" then return false end
    if not TRADING_HOUSE_SEARCH then return false end
    if not TRADING_HOUSE_SEARCH.features then
        BETTERUI.CIM.UserAlertText("TH:PresetUnavailable",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_UNAVAILABLE")) or "Search features are not available")
        return false
    end

    local searchTable = TRADING_HOUSE_SEARCH:CreateSearchTable()
    if not searchTable then return false end

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
    })

    TH.SetSetting("searchPresets", presets)
    return true
end

--- Loads a preset by index, restoring search filters.
---@param index number Preset index (1-based)
---@return boolean success True if loaded successfully
function Presets.Load(index)
    local presets = Presets.GetAll()
    local preset = presets[index]
    if not preset or not preset.searchTable then return false end
    if not TRADING_HOUSE_SEARCH then return false end
    if not TRADING_HOUSE_SEARCH.features then
        BETTERUI.CIM.UserAlertText("TH:PresetUnavailable",
            GetString(rawget(_G, "SI_BETTERUI_TH_PRESET_UNAVAILABLE")) or "Search features are not available")
        return false
    end

    TRADING_HOUSE_SEARCH:LoadSearchTable(preset.searchTable)
    return true
end

--- Deletes a preset by index.
---@param index number Preset index (1-based)
---@return boolean success True if deleted
function Presets.Delete(index)
    local presets = Presets.GetAll()
    if not presets[index] then return false end
    table.remove(presets, index)
    TH.SetSetting("searchPresets", presets)
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
                            control.highlight:SetHidden(not selected)
                            control.editBoxControl:SetDefaultText(L("SI_BETTERUI_TH_PRESET_NAME_PLACEHOLDER"))
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
                },
            },
        })
    end

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
                        if targetData and targetData.presetIndex then
                            if Presets.Load(targetData.presetIndex) then
                                local preset = Presets.GetAll()[targetData.presetIndex]
                                local name = preset and preset.name or L("SI_BETTERUI_TH_PRESET_GENERIC")
                                BETTERUI.CIM.UserAlertText("TH:PresetLoaded",
                                    zo_strformat(L("SI_BETTERUI_TH_PRESET_LOADED"), name))
                                -- Execute search with loaded filters
                                if TH.BrowseComponent then
                                    TH.BrowseComponent.currentPage = 0
                                    TH.BrowseComponent:ExecuteSearch()
                                end
                            end
                        end
                    end,
                },
                {
                    text = SI_DIALOG_CANCEL,
                },
                {
                    text = L("SI_BETTERUI_TH_DELETE"),
                    callback = function(dialog)
                        local targetData = dialog.entryList and dialog.entryList:GetTargetData()
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

    ZO_Dialogs_ShowGamepadDialog(LOAD_DIALOG_NAME, {})
end
