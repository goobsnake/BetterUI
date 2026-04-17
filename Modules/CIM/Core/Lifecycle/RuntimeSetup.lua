--[[
File: Modules/CIM/Core/RuntimeSetup.lua
Purpose: Consolidates early-initialization logic for BetterUI.
         Applies runtime API patches and runs settings migrations.

         This file exists to keep BetterUI.lua clean and focused on module loading.
         Runtime guards and settings migrations are isolated here.

Mechanics:
    1. ApplyAPIPatches(): Installs targeted runtime guards without replacing engine globals.
    2. RunSettingsMigrations(): Migrates legacy settings keys to current standards.
    3. EnsureLifecycleRuntimeState(): Creates shared runtime-owned lifecycle state.
    4. Apply(): Main entry point called once from BetterUI.Initialize().

Migration History:
    See MIGRATIONS section below for detailed migration documentation.

]]

-- NAMESPACE SETUP

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.RuntimeSetup = {}

local RuntimeSetup = BETTERUI.CIM.RuntimeSetup


-- Track whether patches have been applied (prevents double-application)
local patchesApplied = false
local tamrielTomesSelectionGuardInstalled = false
local TAMRIEL_TOMES_GUARD_RETRY_EVENT = "BETTERUI_RuntimeSetup_TamrielTomesGuardRetry"

local function EnsureSharedTaskManager()
    local deferredTask = BETTERUI.CIM and BETTERUI.CIM.DeferredTask
    if type(deferredTask) ~= "table" then
        return BETTERUI.CIM and BETTERUI.CIM.Tasks or nil
    end

    if type(deferredTask.EnsureSharedManager) == "function" then
        return deferredTask.EnsureSharedManager()
    end

    local managerClass = deferredTask.Manager
    if not BETTERUI.CIM.Tasks and managerClass and type(managerClass.New) == "function" then
        BETTERUI.CIM.Tasks = managerClass:New()
    end

    return BETTERUI.CIM.Tasks
end

local function EnsureLifecycleRuntimeState()
    EnsureSharedTaskManager()

    local eventRegistry = BETTERUI.CIM and BETTERUI.CIM.EventRegistry
    if eventRegistry and type(eventRegistry.EnsureRuntimeState) == "function" then
        eventRegistry.EnsureRuntimeState()
    end
end

-- MIGRATIONS
--[[
MIGRATION DOCUMENTATION

Saved Variables Version History:
    BETTERUI doesn't use an explicit version number in saved vars. Instead,
    migrations are triggered by detecting legacy keys/structures.

Migration 1: Tooltips → GeneralInterface Rename
    Trigger: settings.Modules["Tooltips"] ~= nil
    Version: Since v3.03
    Description:
        The "Tooltips" module was renamed to "GeneralInterface" for consistency.
        This migration copies settings from the old key to the new key.
    Legacy Path: @deprecated Migration 1 is transitional; Tooltips key is nil'd after migration
    Action: Copy settings.Modules["Tooltips"] to settings.Modules["GeneralInterface"]

Migration 2: enabled → m_enabled Standardization
    Trigger: modSettings.enabled ~= nil and modSettings.m_enabled == nil
    Version: Since v2.8
    Description:
        Standardizes the enabled flag key from "enabled" to "m_enabled" across
        all modules. The "m_" prefix namespace-avoides conflicts with subtables.
    Legacy Path: @deprecated Legacy "enabled" key is nil'd after migration
    Action: modSettings.m_enabled = modSettings.enabled; modSettings.enabled = nil

Migration 3: Inventory.showMarketPrice → GeneralInterface.showMarketPrice
    Trigger: generalInterfaceSettings.showMarketPrice == nil and inventorySettings.showMarketPrice ~= nil
    Version: Since v3.04
    Description:
        The market price row toggle setting moved from Inventory module to
        GeneralInterface for better architectural alignment.
    Legacy Path: @deprecated Inventory.showMarketPrice is nil'd after migration
    Action: Copy value to GeneralInterface, remove from Inventory

Migration 4: marketPricePriority Default Initialization
    Trigger: generalInterfaceSettings.marketPricePriority == nil
    Version: Since v3.05
    Description:
        New configurable market source priority setting. Initializes default
        priority order for market price display (mm_att_ttc = Master Merchant,
        Arkadius Trade Tools, Tamriel Trade Centre).
    Action: generalInterfaceSettings.marketPricePriority = "mm_att_ttc"

Migration 5: GeneralInterface Module Existence Guarantee
    Trigger: settings.Modules["GeneralInterface"] == nil
    Version: Since v3.03
    Description:
        Ensures GeneralInterface module settings exist even if Migration 1
        didn't run (new users or corrupted saved vars).
    Action: settings.Modules["GeneralInterface"] = {}

    Migration 6: Western-only Fonts → Localized Font
        Trigger: !isEnglish and modSettings.nameFont in westernOnlyFonts
        Version: Since v3.06 (Centralized)
        Description:
            Migrates hardcoded Western-only font paths to localized aliases
            ($(GAMEPAD_MEDIUM_FONT)) for non-English users to support
            CJK and Russian characters.
        Action: modSettings.nameFont = "$(GAMEPAD_MEDIUM_FONT)"

    Migration 7: EventTickets → TradeBars Currency Rename
        Trigger: modSettings.showCurrencyEventTickets ~= nil
        Version: Since v3.07
        Description:
            Renames "Event Tickets" to "Trade Bars" in settings to match
            ZOS terminology updates.
        Action: modSettings.showCurrencyTradeBars = modSettings.showCurrencyEventTickets

HOW TO ADD NEW MIGRATIONS:
    1. Add migration logic to RunSettingsMigrations() below
    2. Document the migration in this header comment
    3. Include trigger condition, version, description, and action
    4. Mark legacy paths with @deprecated where applicable
]]

-- API PATCHES

--- Applies runtime safety guards without replacing ESO global functions.
---
--- Purpose: Runtime setup should avoid overriding shared engine APIs to reduce taint risk.
--- Mechanics:
--- 1. Reserved for compatibility guards that DO NOT replace engine globals.
--- 2. Installs targeted prehooks where needed (e.g., Tamriel Tomes selection guard).
---
--- References: Called by RuntimeSetup.Apply().
local function ApplyAPIPatches()
    if patchesApplied then return end

    -- IMPORTANT:
    -- Do not override global ESO functions (including formatting helpers or keybind/chat APIs).
    -- Global monkeypatches can taint gamepad keybind execution paths and cause protected
    -- function access failures in native callbacks.

    -- Guard against selecting non-reward placeholder rows in Tamriel Tomes grid navigation.
    -- Some category jumps can surface placeholder rows as selectedData, which then crashes
    -- keybind visibility callbacks that expect reward-data methods.
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

-- SETTINGS MIGRATIONS

--- Migrates legacy settings keys to current standards.
---
--- Purpose: Ensures old SavedVariables are upgraded seamlessly.
--- Mechanics:
--- 1. Renames "Tooltips" module to "GeneralInterface" (if present).
--- 2. Standardizes "enabled" key to "m_enabled" across all modules.
--- 3. Moves market-price row toggle from Inventory -> GeneralInterface.
--- 4. Ensures market source priority setting exists.
---
local function RunSettingsMigrations(settings)
    if not settings or not settings.Modules then return end

    -- Phase: migration-1-tooltips-rename
    -- Migration 1: Rename "Tooltips" to "GeneralInterface" for consistency
    -- Applied since v3.03; all modules now reference GeneralInterface directly.
    --- @deprecated Legacy "Tooltips" module key is transitional; removed after migration
    if settings.Modules["Tooltips"] ~= nil then
        if settings.Modules["GeneralInterface"] == nil then
            settings.Modules["GeneralInterface"] = settings.Modules["Tooltips"]
        end
        -- Migration complete: nil the stale key so SavedVars stay clean.
        settings.Modules["Tooltips"] = nil
    end

    -- Phase: migration-5-guarantee-generalinterface
    -- Migration 5: Ensure GeneralInterface module settings exist for existing users (if migration didn't run)
    if settings.Modules["GeneralInterface"] == nil then
        settings.Modules["GeneralInterface"] = {}
    end

    -- Phase: migration-2-enabled-standardization
    -- Migration 2: Standardize 'enabled' to 'm_enabled'
    -- Migration 6: Western-only fonts migration
    -- Migration 7: Currency rename (EventTickets -> TradeBars)
    --- @deprecated Legacy "enabled" key is transitional; replaced by "m_enabled" since v2.8
    local currentLang = GetCVar("language.2") or "en"
    local isEnglish = (currentLang == "en")
    local westernOnlyFonts = {
        ["EsoUI/Common/Fonts/FTN57.otf"] = true,
        ["EsoUI/Common/Fonts/FTN47.otf"] = true,
        ["EsoUI/Common/Fonts/FTN87.otf"] = true,
        ["EsoUI/Common/Fonts/Univers57.otf"] = true,
        ["EsoUI/Common/Fonts/Univers67.otf"] = true,
        ["EsoUI/Common/Fonts/ProseAntiquePSMT.otf"] = true,
        ["EsoUI/Common/Fonts/Handwritten_Bold.otf"] = true,
        ["EsoUI/Common/Fonts/TrajanPro-Regular.otf"] = true,
        ["EsoUI/Common/Fonts/Skyrim_Handwritten.otf"] = true,
        ["EsoUI/Common/Fonts/consola.otf"] = true,
    }

    for modName, modSettings in pairs(settings.Modules) do
        if type(modSettings) == "table" then
            -- M2: Enabled standardization
            if modSettings.enabled ~= nil and modSettings.m_enabled == nil then
                modSettings.m_enabled = modSettings.enabled
                modSettings.enabled = nil
            end

            -- M5: Legacy Font/Size/Style migrations
            if modSettings.font and modSettings.nameFont == nil then
                modSettings.nameFont = modSettings.font
                modSettings.columnFont = modSettings.font
            end
            if modSettings.skinSize and modSettings.nameFontSize == nil then
                modSettings.nameFontSize = modSettings.skinSize
                modSettings.columnFontSize = modSettings.skinSize
            end
            if modSettings.fontStyle and modSettings.nameFontStyle == nil then
                local oldStyle = modSettings.fontStyle
                if type(oldStyle) == "number" then
                    local styleMap = {
                        [0] = "",
                        [1] = "outline",
                        [2] = "thick-outline",
                        [3] = "shadow",
                        [4] = "soft-shadow-thick",
                        [5] = "soft-shadow-thin"
                    }
                    modSettings.nameFontStyle = styleMap[oldStyle] or ""
                else
                    modSettings.nameFontStyle = oldStyle
                end
                modSettings.columnFontStyle = modSettings.nameFontStyle
            end

            -- M6: Western-only fonts (Localized support)
            if not isEnglish then
                if modSettings.nameFont and westernOnlyFonts[modSettings.nameFont] then
                    modSettings.nameFont = "$(GAMEPAD_MEDIUM_FONT)"
                end
                if modSettings.columnFont and westernOnlyFonts[modSettings.columnFont] then
                    modSettings.columnFont = "$(GAMEPAD_MEDIUM_FONT)"
                end
            end

            -- M7: Currency rename (Tickets -> TradeBars)
            if modSettings.showCurrencyEventTickets ~= nil then
                modSettings.showCurrencyTradeBars = modSettings.showCurrencyEventTickets
                modSettings.showCurrencyEventTickets = nil
            end
            if modSettings.orderCurrencyEventTickets ~= nil then
                modSettings.orderCurrencyTradeBars = modSettings.orderCurrencyEventTickets
                modSettings.orderCurrencyEventTickets = nil
            end
            if type(modSettings.currencyOrder) == "string" then
                modSettings.currencyOrder = string.gsub(modSettings.currencyOrder, "tickets", "tradebars")
            end
        end
    end

    -- Phase: migration-3-marketprice-move
    -- Migration 3: Move market-price row toggle from Inventory -> GeneralInterface
    --- @deprecated Inventory.showMarketPrice is transitional; moved to GeneralInterface since v3.04
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

    -- Phase: migration-4-marketpricepriority-init
    -- Migration 4: Ensure market source priority setting exists (new configurable order control)
    do
        local generalInterfaceSettings = settings.Modules["GeneralInterface"]
        if type(generalInterfaceSettings) == "table" and generalInterfaceSettings.marketPricePriority == nil then
            generalInterfaceSettings.marketPricePriority = "mm_att_ttc"
        end
    end
end

-- PUBLIC API

--- Main entry point for early-initialization logic.
---
--- Purpose: Applies runtime API patches and runs settings migrations.
--- Mechanics:
--- 1. Ensures shared lifecycle runtime state exists.
--- 2. Applies API patches (once).
--- 3. Runs settings migrations on the provided settings table.
---
function RuntimeSetup.Apply(settings)
    EnsureLifecycleRuntimeState()
    ApplyAPIPatches()
    RunSettingsMigrations(settings)
end

-- Export for testing/debugging
RuntimeSetup.EnsureSharedTaskManager = EnsureSharedTaskManager
RuntimeSetup.EnsureLifecycleRuntimeState = EnsureLifecycleRuntimeState
RuntimeSetup.ApplyAPIPatches = ApplyAPIPatches
RuntimeSetup.RunSettingsMigrations = RunSettingsMigrations
