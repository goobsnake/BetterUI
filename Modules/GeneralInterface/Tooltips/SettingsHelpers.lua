--[[
    BetterUI Tooltip Settings Helpers
    Description: Utility and reset functions for General Interface tooltip settings.
    Split from Settings.lua for maintainability.
    Last Modified: 2026-03-14
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local SettingsApi = BETTERUI.CIM and BETTERUI.CIM.Settings
assert(SettingsApi and SettingsApi.GetSettingDefault and SettingsApi.ResetModuleSettingsByGroup,
    "BetterUI: CIM.Settings metadata helpers must load before GeneralInterface tooltip settings helpers")

--- Applies tooltip visual settings from the current configuration.
local function ApplyTooltipVisualSettings()
    if BETTERUI.Inventory and type(BETTERUI.Inventory.ApplyTooltipStyles) == "function" then
        BETTERUI.Inventory.ApplyTooltipStyles()
    end
end

--- Cleans up tooltip enhancement artifacts from all tooltip controls.
local function CleanupTooltipEnhancementArtifacts()
    if not (BETTERUI.Inventory and BETTERUI.Inventory.CleanupEnhancedTooltip) then return end
    BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
    BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
    BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_MOVABLE_TOOLTIP)
end

--- Refreshes the inventory and banking lists if their scenes are showing.
local function RefreshInventoryAndBankingLists()
    local inventoryWindow = GAMEPAD_INVENTORY
    local inventorySceneShowing = true
    if BETTERUI.CIM.Utils and type(BETTERUI.CIM.Utils.IsInventorySceneShowing) == "function" then
        inventorySceneShowing = BETTERUI.CIM.Utils.IsInventorySceneShowing()
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
    if BETTERUI.CIM.Utils and type(BETTERUI.CIM.Utils.IsBankingSceneShowing) == "function" then
        bankingSceneShowing = BETTERUI.CIM.Utils.IsBankingSceneShowing()
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

--- Builds a tooltip string indicating addon dependencies.
local function BuildAddonDependencyTooltip(baseStringId, addonGlobals, requireAny)
    local baseText = GetString(baseStringId)
    if type(addonGlobals) ~= "table" or #addonGlobals == 0 then
        return baseText
    end

    local addonDisplayNames = {
        ArkadiusTradeTools = "Arkadius Trade Tools",
        MasterMerchant = "Master Merchant",
        TamrielTradeCentre = "Tamriel Trade Centre",
    }

    local availableCount = 0
    for _, addonGlobal in ipairs(addonGlobals) do
        if _G[addonGlobal] ~= nil then
            availableCount = availableCount + 1
        end
    end

    local shouldShowReason
    if requireAny then
        shouldShowReason = availableCount == 0
    else
        shouldShowReason = availableCount < #addonGlobals
    end

    if not shouldShowReason then
        return baseText
    end

    local addonListParts = {}
    for _, addonGlobal in ipairs(addonGlobals) do
        addonListParts[#addonListParts + 1] = addonDisplayNames[addonGlobal] or addonGlobal
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
    SettingsApi.ResetModuleSettingsByGroup("GeneralInterface", "general")
    SettingsApi.ResetModuleSettingsByGroup("CIM", "generalInterfaceGeneral")

    local generalInterfaceSettings = GetModuleSettings("GeneralInterface")
    if ZO_ChatWindowTemplate1Buffer ~= nil then
        ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(
            (generalInterfaceSettings and generalInterfaceSettings.chatHistory) or 200
        )
    end
end

--- Resets the market integration settings to defaults.
local function ResetMarketIntegrationSettings()
    SettingsApi.ResetModuleSettingsByGroup("GeneralInterface", "marketIntegration")

    RefreshInventoryAndBankingLists()
end

--- Resets the enhanced tooltip settings to defaults.
local function ResetEnhancedTooltipSettings()
    SettingsApi.ResetModuleSettingsByGroup("GeneralInterface", "enhancedTooltips")
    SettingsApi.ResetModuleSettingsByGroup("CIM", "enhancedTooltips")

    local cimSettings = GetModuleSettings("CIM")
    if cimSettings and cimSettings.enableTooltipEnhancements == true then
        ApplyTooltipVisualSettings()
    else
        CleanupTooltipEnhancementArtifacts()
    end
    RefreshInventoryAndBankingLists()
end

-- SHARED HELPERS EXPORT
-- These locals are exported to global namespace so Settings.lua can access them.

BETTERUI.GeneralInterface._SettingsHelpers = {
    ApplyTooltipVisualSettings = ApplyTooltipVisualSettings,
    CleanupTooltipEnhancementArtifacts = CleanupTooltipEnhancementArtifacts,
    RefreshInventoryAndBankingLists = RefreshInventoryAndBankingLists,
    GetMetadataDefault = GetMetadataDefault,
    BuildAddonDependencyTooltip = BuildAddonDependencyTooltip,
    GetModuleSettings = GetModuleSettings,
    EnsureModuleSettings = EnsureModuleSettings,
    IsCIMEnabled = IsCIMEnabled,
    ParseIntegerInput = ParseIntegerInput,
    ResetGeneralInterfaceGeneralSettings = ResetGeneralInterfaceGeneralSettings,
    ResetMarketIntegrationSettings = ResetMarketIntegrationSettings,
    ResetEnhancedTooltipSettings = ResetEnhancedTooltipSettings,
}
