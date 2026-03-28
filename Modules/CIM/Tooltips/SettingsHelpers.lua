--[[
    BetterUI Tooltip Settings Helpers
    Description: Utility and reset functions for General Interface tooltip settings.
    Split from Settings.lua for maintainability.
    Last Modified: 2026-03-14
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

--- Applies tooltip visual settings from the current configuration.
local function ApplyTooltipVisualSettings()
    BETTERUI.CIM.TryCall("Inventory.ApplyTooltipStyles")
end

--- Cleans up tooltip enhancement artifacts from all tooltip controls.
local function CleanupTooltipEnhancementArtifacts()
    if not (BETTERUI.Inventory and BETTERUI.Inventory.CleanupEnhancedTooltip) then return end
    BETTERUI.CIM.TryCall("Inventory.CleanupEnhancedTooltip", GAMEPAD_LEFT_TOOLTIP)
    BETTERUI.CIM.TryCall("Inventory.CleanupEnhancedTooltip", GAMEPAD_RIGHT_TOOLTIP)
    BETTERUI.CIM.TryCall("Inventory.CleanupEnhancedTooltip", GAMEPAD_MOVABLE_TOOLTIP)
end

--- Refreshes the inventory and banking lists if their scenes are showing.
local function RefreshInventoryAndBankingLists()
    local inventoryWindow = GAMEPAD_INVENTORY
    local inventorySceneShowing = true
    if BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.IsInventorySceneShowing then
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
    if BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.IsBankingSceneShowing then
        bankingSceneShowing = BETTERUI.CIM.Utils.IsBankingSceneShowing()
    end

    if bankingSceneShowing and bankingWindow and bankingWindow.RefreshList then
        bankingWindow:RefreshList()
    end
end

--- Gets the default value for a setting from metadata.
local function GetMetadataDefault(moduleName, settingKey, fallback)
    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.GetSettingDefault then
        return BETTERUI.CIM.Settings.GetSettingDefault(moduleName, settingKey, fallback)
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
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("GeneralInterface", "general")
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("CIM", "generalInterfaceGeneral")
    else
        local generalInterfaceSettings = EnsureModuleSettings("GeneralInterface")
        local cimSettings = EnsureModuleSettings("CIM")
        if generalInterfaceSettings then
            generalInterfaceSettings.chatHistory = 200
            generalInterfaceSettings.removeDeleteDialog = false
        end
        if cimSettings then
            cimSettings.rhScrollSpeed = 50
        end
    end

    local generalInterfaceSettings = GetModuleSettings("GeneralInterface")
    if ZO_ChatWindowTemplate1Buffer ~= nil then
        ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(
            (generalInterfaceSettings and generalInterfaceSettings.chatHistory) or 200
        )
    end
end

--- Resets the market integration settings to defaults.
local function ResetMarketIntegrationSettings()
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("GeneralInterface", "marketIntegration")
    else
        local generalInterfaceSettings = EnsureModuleSettings("GeneralInterface")
        if generalInterfaceSettings then
            generalInterfaceSettings.showMarketPrice =
                GetMetadataDefault("GeneralInterface", "showMarketPrice", true)
            generalInterfaceSettings.marketPricePriority =
                GetMetadataDefault("GeneralInterface", "marketPricePriority", "mm_att_ttc")
            generalInterfaceSettings.guildStoreErrorSuppress =
                GetMetadataDefault("GeneralInterface", "guildStoreErrorSuppress", true)
            generalInterfaceSettings.attIntegration =
                GetMetadataDefault("GeneralInterface", "attIntegration", true)
            generalInterfaceSettings.mmIntegration =
                GetMetadataDefault("GeneralInterface", "mmIntegration", true)
            generalInterfaceSettings.ttcIntegration =
                GetMetadataDefault("GeneralInterface", "ttcIntegration", true)
        end
    end

    RefreshInventoryAndBankingLists()
end

--- Resets the enhanced tooltip settings to defaults.
local function ResetEnhancedTooltipSettings()
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("GeneralInterface", "enhancedTooltips")
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("CIM", "enhancedTooltips")
    else
        local generalInterfaceSettings = EnsureModuleSettings("GeneralInterface")
        local cimSettings = EnsureModuleSettings("CIM")
        if generalInterfaceSettings then
            generalInterfaceSettings.showStyleTrait =
                GetMetadataDefault("GeneralInterface", "showStyleTrait", true)
            generalInterfaceSettings.showKnowledgeStatus =
                GetMetadataDefault("GeneralInterface", "showKnowledgeStatus", true)
        end
        if cimSettings then
            cimSettings.enableTooltipEnhancements =
                GetMetadataDefault("CIM", "enableTooltipEnhancements", true)
            cimSettings.tooltipSize =
                GetMetadataDefault("CIM", "tooltipSize", 24)
        end
    end

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
