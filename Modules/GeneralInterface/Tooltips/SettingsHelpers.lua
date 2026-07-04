--[[
    BetterUI Tooltip Settings Helpers
    Description: Utility and reset functions for General Interface tooltip settings.
    Split from Settings.lua for maintainability.
    Last Modified: 2026-03-14
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local SettingsApi = BETTERUI.CIM and BETTERUI.CIM.Settings
local OptionalAddons = BETTERUI.CIM and BETTERUI.CIM.OptionalAddons
assert(SettingsApi and SettingsApi.GetSettingDefault and SettingsApi.ResetModuleSettingsByGroup,
    "BetterUI: CIM.Settings metadata helpers must load before GeneralInterface tooltip settings helpers")

-- Canonical GeneralInterface settings tracer (BUI-CONS-002 / BUI-CONS-003).
-- Single definition owned by SettingsHelpers and consumed by Settings.lua so the
-- two former copies collapse to one. Scene comes from the shared CIM util instead
-- of a local reimplementation. Callers may override `feature` via the data table.
local function TraceGeneralSetting(settingName, phase, data)
    local L = BETTERUI and BETTERUI.Log or nil
    if not L or type(L.TraceEvent) ~= "function" then return end
    local payload = data or {}
    payload.module = "GeneralInterface"
    payload.feature = payload.feature or "settings"
    payload.setting = settingName
    local utils = BETTERUI.CIM and BETTERUI.CIM.Utils
    payload.scene = utils and utils.GetCurrentSceneName and utils.GetCurrentSceneName() or nil
    payload.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if type(L.SetLastAction) == "function" then
        L.SetLastAction("GeneralInterface.settings." .. tostring(settingName))
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.SETTING or categories.GENERAL, "general_interface.setting", phase, payload)
end

--- Applies tooltip visual settings from the current configuration.
local function ApplyTooltipVisualSettings()
    if BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.ApplyTooltipStyles) == "function" then
        BETTERUI.CIM.SharedItemSupport.ApplyTooltipStyles()
    end
end

--- Cleans up tooltip enhancement artifacts from all tooltip controls.
local function CleanupTooltipEnhancementArtifacts()
    if not (BETTERUI.CIM.SharedItemSupport and BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip) then return end
    BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
    BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
    BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_MOVABLE_TOOLTIP)
end

--- Restores the stock ZO_TOOLTIP_STYLES entries overridden by tooltip enhancements.
local function RestoreTooltipVisualSettings()
    if BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.RestoreTooltipStyles) == "function" then
        BETTERUI.CIM.SharedItemSupport.RestoreTooltipStyles()
    end
end

--- Refreshes the inventory and banking lists if their scenes are showing.
local function RefreshInventoryAndBankingLists()
    local sharedUtils = BETTERUI.CIM and BETTERUI.CIM.Utils or nil
    local isInventorySceneShowing = sharedUtils and (sharedUtils.IsInventorySceneShowing
        or function()
            local isSceneShowing = sharedUtils.IsSceneShowing
            if type(isSceneShowing) == "function" then
                return isSceneShowing("gamepad_inventory_root")
            end
            return true
        end)
    local isBankingSceneShowing = sharedUtils and (sharedUtils.IsBankingSceneShowing
        or function()
            local isAnySceneShowing = sharedUtils.IsAnySceneShowing
            if type(isAnySceneShowing) == "function" then
                return isAnySceneShowing({ "gamepad_banking" })
            end
            return true
        end)

    local inventoryWindow = GAMEPAD_INVENTORY
    local inventorySceneShowing = true
    if type(isInventorySceneShowing) == "function" then
        inventorySceneShowing = isInventorySceneShowing()
    end

    if inventorySceneShowing
        and inventoryWindow
        and inventoryWindow.RefreshItemList
        and inventoryWindow.itemList
        and inventoryWindow.categoryList then
        inventoryWindow:RefreshItemList()
    end

    local bankingWindow = BETTERUI.Banking and BETTERUI.Banking.Window
    local bankingSceneShowing = true
    if type(isBankingSceneShowing) == "function" then
        bankingSceneShowing = isBankingSceneShowing()
    end

    if bankingSceneShowing and bankingWindow and bankingWindow.RefreshList then
        bankingWindow:RefreshList()
    end
end

--- Gets the default value for a setting from metadata.
local function GetMetadataDefault(moduleName, settingKey, fallback)
    local result = SettingsApi.GetSettingDefault(moduleName, settingKey, fallback)
    if result ~= nil then
        return result
    end
    return fallback
end

--- Returns addon dependency globals declared in settings metadata for a setting.
local function GetSettingDependencyAddons(moduleName, settingKey)
    if type(SettingsApi.GetSettingDependencyAddons) == "function" then
        return SettingsApi.GetSettingDependencyAddons(moduleName, settingKey)
    end
    return nil
end

--- Checks whether a global addon object exists.
local function IsAddonGlobalLoaded(addonGlobal)
    if OptionalAddons
        and type(OptionalAddons.ResolveKey) == "function"
        and type(OptionalAddons.IsLoaded) == "function"
        and OptionalAddons.ResolveKey(addonGlobal) ~= nil
    then
        return OptionalAddons.IsLoaded(addonGlobal)
    end
    return type(addonGlobal) == "string" and _G[addonGlobal] ~= nil
end

--- Returns whether any addon from the list is currently loaded.
local function IsAnyAddonDependencyLoaded(addonGlobals)
    if type(addonGlobals) ~= "table" then
        return false
    end

    for _, addonGlobal in ipairs(addonGlobals) do
        if IsAddonGlobalLoaded(addonGlobal) then
            return true
        end
    end
    return false
end

--- Returns whether all addons from the list are currently loaded.
local function AreAllAddonDependenciesLoaded(addonGlobals)
    if type(addonGlobals) ~= "table" or #addonGlobals == 0 then
        return true
    end

    for _, addonGlobal in ipairs(addonGlobals) do
        if not IsAddonGlobalLoaded(addonGlobal) then
            return false
        end
    end
    return true
end

--- Builds a tooltip string indicating addon dependencies.
local function BuildAddonDependencyTooltip(baseStringId, addonGlobals, requireAny)
    local baseText = GetString(baseStringId)
    if type(addonGlobals) ~= "table" or #addonGlobals == 0 then
        return baseText
    end

    local shouldShowReason
    if requireAny then
        shouldShowReason = not IsAnyAddonDependencyLoaded(addonGlobals)
    else
        shouldShowReason = not AreAllAddonDependenciesLoaded(addonGlobals)
    end

    if not shouldShowReason then
        return baseText
    end

    local addonListParts = {}
    for _, addonGlobal in ipairs(addonGlobals) do
        local displayName = OptionalAddons and OptionalAddons.GetDisplayNameForGlobal
            and OptionalAddons.GetDisplayNameForGlobal(addonGlobal)
            or OptionalAddons and OptionalAddons.GetDisplayName
            and OptionalAddons.GetDisplayName(addonGlobal)
            or addonGlobal
        addonListParts[#addonListParts + 1] = displayName
    end
    local addonList = table.concat(addonListParts, ", ")
    local reason = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP")), addonList)
    return baseText .. "\n\n" .. reason
end

local GetModuleSettings = BETTERUI.GetModuleSettings
local EnsureModuleSettings = BETTERUI.EnsureModuleSettings

--- Checks if the CIM module is enabled.
local function IsCIMEnabled()
    local cimSettings = GetModuleSettings("CIM")
    return cimSettings and cimSettings.m_enabled == true
end

--- Parses and validates an integer input with optional range clamping.
local function ParseIntegerInput(value, fallback, minValue, maxValue)
    local textValue = tostring(value or "")
    textValue = textValue:gsub("^%s+", "")
    textValue = textValue:gsub("%s+$", "")
    if textValue == "" or not textValue:match("^%-?%d+$") then
        return fallback
    end

    local parsedValue = tonumber(textValue)
    if parsedValue == nil then
        return fallback
    end

    if minValue and parsedValue < minValue then
        parsedValue = minValue
    end
    if maxValue and parsedValue > maxValue then
        parsedValue = maxValue
    end
    return parsedValue
end

--- Resets the general settings for the GeneralInterface module.
local function ResetGeneralInterfaceGeneralSettings()
    TraceGeneralSetting("general", "reset_begin", { fn = "ResetGeneralInterfaceGeneralSettings" })
    SettingsApi.ResetModuleSettingsByGroup("GeneralInterface", "general")
    SettingsApi.ResetModuleSettingsByGroup("CIM", "generalInterfaceGeneral")

    local generalInterfaceSettings = GetModuleSettings("GeneralInterface")
    local generalInterface = BETTERUI.GeneralInterface
    if generalInterface and generalInterface.ApplyChatHistoryLimit then
        generalInterface.ApplyChatHistoryLimit(
            (generalInterfaceSettings and generalInterfaceSettings.chatHistory) or 200
        )
    end
    TraceGeneralSetting("general", "reset_end", { fn = "ResetGeneralInterfaceGeneralSettings", chatHistory = generalInterfaceSettings and generalInterfaceSettings.chatHistory })
end

--- Resets the market integration settings to defaults.
local function ResetMarketIntegrationSettings()
    TraceGeneralSetting("marketIntegration", "reset_begin", { fn = "ResetMarketIntegrationSettings" })
    SettingsApi.ResetModuleSettingsByGroup("GeneralInterface", "marketIntegration")

    RefreshInventoryAndBankingLists()
    TraceGeneralSetting("marketIntegration", "reset_end", { fn = "ResetMarketIntegrationSettings" })
end

--- Resets the enhanced tooltip settings to defaults.
local function ResetEnhancedTooltipSettings()
    TraceGeneralSetting("enhancedTooltips", "reset_begin", { fn = "ResetEnhancedTooltipSettings" })
    SettingsApi.ResetModuleSettingsByGroup("GeneralInterface", "enhancedTooltips")
    SettingsApi.ResetModuleSettingsByGroup("CIM", "enhancedTooltips")

    local cimSettings = GetModuleSettings("CIM")
    if cimSettings and cimSettings.enableTooltipEnhancements == true then
        ApplyTooltipVisualSettings()
    else
        RestoreTooltipVisualSettings()
        CleanupTooltipEnhancementArtifacts()
        if BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText) == "function" then
            BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)
            BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_RIGHT_TOOLTIP, nil)
            BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_MOVABLE_TOOLTIP, nil)
        end
    end
    RefreshInventoryAndBankingLists()
    TraceGeneralSetting("enhancedTooltips", "reset_end", { fn = "ResetEnhancedTooltipSettings", enhancementsEnabled = cimSettings and cimSettings.enableTooltipEnhancements == true, relayoutRequested = BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText) == "function" or false })
end

-- SHARED HELPERS EXPORT
-- These locals are exported to global namespace so Settings.lua can access them.

BETTERUI.GeneralInterface._SettingsHelpers = {
    TraceGeneralSetting = TraceGeneralSetting,
    ApplyTooltipVisualSettings = ApplyTooltipVisualSettings,
    RestoreTooltipVisualSettings = RestoreTooltipVisualSettings,
    CleanupTooltipEnhancementArtifacts = CleanupTooltipEnhancementArtifacts,
    RefreshInventoryAndBankingLists = RefreshInventoryAndBankingLists,
    GetMetadataDefault = GetMetadataDefault,
    GetSettingDependencyAddons = GetSettingDependencyAddons,
    IsAddonGlobalLoaded = IsAddonGlobalLoaded,
    IsAnyAddonDependencyLoaded = IsAnyAddonDependencyLoaded,
    AreAllAddonDependenciesLoaded = AreAllAddonDependenciesLoaded,
    BuildAddonDependencyTooltip = BuildAddonDependencyTooltip,
    GetModuleSettings = GetModuleSettings,
    EnsureModuleSettings = EnsureModuleSettings,
    IsCIMEnabled = IsCIMEnabled,
    ParseIntegerInput = ParseIntegerInput,
    ResetGeneralInterfaceGeneralSettings = ResetGeneralInterfaceGeneralSettings,
    ResetMarketIntegrationSettings = ResetMarketIntegrationSettings,
    ResetEnhancedTooltipSettings = ResetEnhancedTooltipSettings,
}
