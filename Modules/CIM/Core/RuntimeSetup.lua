--[[
File: Modules/CIM/RuntimeSetup.lua
Purpose: Consolidates early-initialization logic for BetterUI.
         Applies runtime safety guards and runs settings migrations.

         This file exists to keep BetterUI.lua clean and focused on module loading.
         All "dirty but necessary" workarounds for ESO API issues are isolated here.

Mechanics:
    1. ApplyAPIPatches(): Applies non-invasive runtime safety guards.
    2. RunSettingsMigrations(): Migrates legacy settings keys to current standards.
    3. Apply(): Main entry point called once from BetterUI.Initialize().

Author: BetterUI Team
Last Modified: 2026-01-24
]]

-- ============================================================================
-- NAMESPACE SETUP
-- ============================================================================

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.RuntimeSetup = {}

local RuntimeSetup = BETTERUI.CIM.RuntimeSetup

-- Track whether patches have been applied (prevents double-application)
local patchesApplied = false
local tamrielTomesSelectionGuardInstalled = false
local TAMRIEL_TOMES_GUARD_RETRY_EVENT = "BETTERUI_RuntimeSetup_TamrielTomesGuardRetry"

-- ============================================================================
-- API PATCHES
-- ============================================================================

--[[
Function: ApplyAPIPatches
Description: Applies runtime safety guards without replacing ESO global functions.
Rationale: Global monkeypatches can taint secure gamepad/chat call paths.
           Runtime setup should avoid overriding shared engine APIs.
Mechanism:
    1. Reserved for runtime compatibility guards that DO NOT replace engine globals.
    2. Global monkeypatches are intentionally avoided to reduce secure-call taint risk.
References: Called by RuntimeSetup.Apply().
]]
local function ApplyAPIPatches()
    if patchesApplied then return end

    -- IMPORTANT:
    -- Do not override global ESO functions (including formatting helpers or keybind/chat APIs).
    -- Global monkeypatches can taint gamepad keybind execution paths and cause protected chat
    -- send failures (private SendChatMessage access) in native chat callbacks.

    -- Guard against selecting non-reward placeholder rows in Tamriel Tomes grid navigation.
    -- Some category jumps can surface {} margin/divider rows as selectedData, which then
    -- crashes keybind visibility callbacks that expect ZO_TamrielTomesRewardData methods.
    local function TryInstallTamrielTomesSelectionGuard()
        if tamrielTomesSelectionGuardInstalled then
            return true
        end
        if type(ZO_PreHook) ~= "function" or not ZO_TamrielTomesScreen_Shared then
            return false
        end

        ZO_PreHook(ZO_TamrielTomesScreen_Shared, "SetSelectedTamrielTomesRewardData", function(self, newData)
            if newData == nil then
                return false
            end

            local isValidRewardData = type(newData) == "table"
                and type(newData.CanClaimReward) == "function"
                and type(newData.CanPreviewReward) == "function"
                and type(newData.GetRewardData) == "function"

            if isValidRewardData then
                return false
            end

            -- Recover by asking the grid to auto-select a valid selectable entry.
            if self and self.gridList and self.gridList.RefreshSelection then
                zo_callLater(function()
                    if self and self.gridList and self.gridList.RefreshSelection then
                        self.gridList:RefreshSelection(true, true)
                    end
                end, 0)
            end

            return true
        end)

        tamrielTomesSelectionGuardInstalled = true
        return true
    end

    if not TryInstallTamrielTomesSelectionGuard() and EVENT_MANAGER then
        EVENT_MANAGER:RegisterForEvent(TAMRIEL_TOMES_GUARD_RETRY_EVENT, EVENT_PLAYER_ACTIVATED, function()
            if TryInstallTamrielTomesSelectionGuard() then
                EVENT_MANAGER:UnregisterForEvent(TAMRIEL_TOMES_GUARD_RETRY_EVENT, EVENT_PLAYER_ACTIVATED)
            end
        end)
    end

    patchesApplied = true
end

-- ============================================================================
-- SETTINGS MIGRATIONS
-- ============================================================================

--[[
Function: RunSettingsMigrations
Description: Migrates legacy settings keys to current standards.
Rationale: As BetterUI evolves, settings keys are renamed for consistency.
           This function ensures old SavedVariables are upgraded seamlessly.
Mechanism:
    1. Renames "Tooltips" module to "GeneralInterface" (if present).
    2. Standardizes "enabled" key to "m_enabled" across all modules.
References: Called by RuntimeSetup.Apply().
param: settings (table) - The BETTERUI.Settings table to migrate.
]]
local function RunSettingsMigrations(settings)
    if not settings or not settings.Modules then return end

    -- Migration 1: Rename "Tooltips" to "GeneralInterface" for consistency
    if settings.Modules["Tooltips"] ~= nil then
        if settings.Modules["GeneralInterface"] == nil then
            settings.Modules["GeneralInterface"] = settings.Modules["Tooltips"]
        end
        -- Keep 'Tooltips' key in settings pointing to same table to avoid breaking older modules
        -- until they are all updated, then we can nil it out.
        -- For now, redirecting the reference is safest.
        settings.Modules["Tooltips"] = settings.Modules["GeneralInterface"]
    end

    -- Ensure GeneralInterface module settings exist for existing users (if migration didn't run)
    if settings.Modules["GeneralInterface"] == nil then
        settings.Modules["GeneralInterface"] = {}
    end

    -- Migration 2: Standardize 'enabled' to 'm_enabled'
    for modName, modSettings in pairs(settings.Modules) do
        if type(modSettings) == "table" and modSettings.enabled ~= nil and modSettings.m_enabled == nil then
            modSettings.m_enabled = modSettings.enabled
            modSettings.enabled = nil
        end
    end

    -- Migration 3: Move market-price row toggle from Inventory -> GeneralInterface
    do
        local generalInterfaceSettings = settings.Modules["GeneralInterface"]
        local inventorySettings = settings.Modules["Inventory"]

        if type(generalInterfaceSettings) == "table" and generalInterfaceSettings.showMarketPrice == nil then
            if type(inventorySettings) == "table" and inventorySettings.showMarketPrice ~= nil then
                generalInterfaceSettings.showMarketPrice = inventorySettings.showMarketPrice
            else
                generalInterfaceSettings.showMarketPrice = true
            end
        end

        -- Remove legacy key after migration to avoid split ownership.
        if type(inventorySettings) == "table" then
            inventorySettings.showMarketPrice = nil
        end
    end

    -- Migration 4: Ensure market source priority setting exists (new configurable order control)
    do
        local generalInterfaceSettings = settings.Modules["GeneralInterface"]
        if type(generalInterfaceSettings) == "table" and generalInterfaceSettings.marketPricePriority == nil then
            generalInterfaceSettings.marketPricePriority = "mm_att_ttc"
        end
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--[[
Function: RuntimeSetup.Apply
Description: Main entry point for early-initialization logic.
Rationale: Consolidates patches and migrations into a single call from BetterUI.Initialize.
Mechanism:
    1. Applies API patches (once).
    2. Runs settings migrations on the provided settings table.
References: Called from BetterUI.lua:Initialize after SavedVars are loaded.
param: settings (table) - The BETTERUI.Settings table to migrate.
]]
function RuntimeSetup.Apply(settings)
    ApplyAPIPatches()
    RunSettingsMigrations(settings)
end

-- Export for testing/debugging
RuntimeSetup.ApplyAPIPatches = ApplyAPIPatches
RuntimeSetup.RunSettingsMigrations = RunSettingsMigrations
