--[[
File: Modules/CIM/Core/RuntimeSetup.lua
Purpose: Consolidates early-initialization logic for BetterUI.
         Applies runtime API patches and runs settings migrations.

         This file exists to keep BetterUI.lua clean and focused on module loading.
         All "dirty but necessary" workarounds for ESO API issues are isolated here.

Mechanics:
    1. ApplyAPIPatches(): Wraps ESO global functions (zo_iconFormat, etc.) to handle nil paths.
    2. RunSettingsMigrations(): Migrates legacy settings keys to current standards.
    3. Apply(): Main entry point called once from BetterUI.Initialize().

Migration History:
    See MIGRATIONS section below for detailed migration documentation.

]]

-- NAMESPACE SETUP

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.RuntimeSetup = {}

local RuntimeSetup = BETTERUI.CIM.RuntimeSetup
local SafeExecute = BETTERUI.CIM.SafeExecute

-- Track whether patches have been applied (prevents double-application)
local patchesApplied = false

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

--- Wraps ESO global icon/text formatting functions to handle nil paths gracefully.
---
--- Purpose: Provides stability for ESO API calls that may receive nil paths.
--- Mechanics:
--- 1. Checks if each function exists.
--- 2. Stores original reference.
--- 3. Replaces with a wrapper that nil-checks the path and uses SafeExecute for safety.
--- 4. Also patches ZO_KeybindStrip:HandleDuplicateAddKeybind to recover from descriptor errors.
---
--- References: Called by RuntimeSetup.Apply().
--- These wrappers intentionally use BETTERUI.CIM.SafeExecute for ESO API stability.
local function ApplyAPIPatches()
    if patchesApplied then return end

    -- Phase: icon-patch
    -- Patch 1: Wrap global icon/text formatting helpers to handle nil paths gracefully.
    -- Helper: wraps a (path, width, height) icon function with nil-path guard + SafeExecute.
    local function PatchIconFn(globalName)
        local orig = _G[globalName]
        if type(orig) ~= "function" then return end
        _G[globalName] = function(path, width, height)
            if path == nil then path = "" end
            local ok, res = SafeExecute("RuntimeSetup:PatchIconFn:" .. globalName, orig, path, width, height)
            return ok and res or ""
        end
    end

    -- Phase: icon-text-patch
    -- Helper: wraps a (path, width, height, text, ...) icon-text function with nil-path guard + SafeExecute.
    local function PatchIconTextFn(globalName)
        local orig = _G[globalName]
        if type(orig) ~= "function" then return end
        _G[globalName] = function(path, width, height, text, ...)
            if path == nil then path = "" end
            local ok, res = SafeExecute("RuntimeSetup:PatchIconTextFn:" .. globalName, orig, path, width, height, text, ...)
            return ok and res or tostring(text or "")
        end
    end

    -- Apply icon-format patches (simple 3-param: path, width, height → "")
    PatchIconFn("zo_iconFormat")
    PatchIconFn("zo_iconFormatInheritColor")

    -- Apply icon-text-format patches (multi-param: path, width, height, text, ... → text)
    PatchIconTextFn("zo_iconTextFormat")
    PatchIconTextFn("zo_iconTextFormatAlignedRight")
    PatchIconTextFn("zo_iconTextFormatNoSpace")
    PatchIconTextFn("zo_iconTextFormatNoSpaceAlignedRight")

    -- Phase: keybind-recovery
    -- Patch 2: Wrap ZO_KeybindStrip:HandleDuplicateAddKeybind to safely evaluate descriptor names.
    -- The original function calls GetKeybindDescriptorDebugIdentifier on descriptors, which can
    -- call formatting helpers (like zo_iconFormat) with nil paths. We wrap this to silently
    -- handle any errors. On error, we attempt to remove the conflicting descriptor so the
    -- new one can be registered, restoring keybind strip functionality.
    if ZO_KeybindStrip and type(ZO_KeybindStrip.HandleDuplicateAddKeybind) == "function" then
        local _orig_HandleDuplicate = ZO_KeybindStrip.HandleDuplicateAddKeybind
        ZO_KeybindStrip.HandleDuplicateAddKeybind = function(self, existingButtonOrEtherealDescriptor,
                                                             keybindButtonDescriptor, state, stateIndex, currentSceneName)
            local ok, res = SafeExecute(
                "RuntimeSetup:HandleDuplicateAddKeybind",
                _orig_HandleDuplicate,
                self,
                existingButtonOrEtherealDescriptor,
                keybindButtonDescriptor,
                state,
                stateIndex,
                currentSceneName
            )
            -- If the call succeeded, return normally
            if ok then return res end

            -- Phase: keybind-recovery-remove
            -- If the call failed, attempt a safe recovery by removing the conflicting descriptor
            -- so the new keybind can be registered. This ensures LB/RB navigation is restored
            -- even when duplicate handling errors occur.
            SafeExecute("RuntimeSetup:HandleDuplicateRecoveryRemove", function()
                if existingButtonOrEtherealDescriptor then
                    local descriptor = existingButtonOrEtherealDescriptor
                    -- If it's a button control, extract the descriptor
                    if type(descriptor) == "userdata" and descriptor.keybindButtonDescriptor then
                        descriptor = descriptor.keybindButtonDescriptor
                    end
                    -- Attempt removal
                    if descriptor and self.RemoveKeybindButton then
                        self:RemoveKeybindButton(descriptor, stateIndex)
                    end
                end
            end)

            -- Phase: keybind-recovery-deferred-readd
            -- Schedule a deferred re-add of the new keybind to handle timing edge cases where
            -- removal and re-add happen too quickly in the same frame. This is especially important
            -- during scene transitions (like search enter/exit) where multiple duplicate keybind
            -- errors may occur in quick succession. Use zo_callLater with a 0ms delay to defer
            -- until the next frame cycle, ensuring the removal has settled.
            SafeExecute("RuntimeSetup:HandleDuplicateDeferredReAdd", function()
                if zo_callLater and type(zo_callLater) == "function" then
                    zo_callLater(function()
                        SafeExecute("RuntimeSetup:HandleDuplicateDeferredReAddCallLater", function()
                            -- Only re-add if not already present
                            if self and self.HasKeybindButton then
                                local present = self:HasKeybindButton(keybindButtonDescriptor, stateIndex)
                                if not present then
                                    self:AddKeybindButton(keybindButtonDescriptor, stateIndex)
                                    -- Force update keybind strip layout to ensure buttons are visible
                                    if self.UpdateAnchors then
                                        self:UpdateAnchors()
                                    end
                                end
                            end
                        end)
                    end, 0)
                end
            end)

            -- Do not log to chat/debug as per user requirement. The keybind strip will
            -- continue, and duplicate handling was attempted (even if it failed gracefully).
        end
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
--- 1. Applies API patches (once).
--- 2. Runs settings migrations on the provided settings table.
---
function RuntimeSetup.Apply(settings)
    ApplyAPIPatches()
    RunSettingsMigrations(settings)
end

-- Export for testing/debugging
RuntimeSetup.ApplyAPIPatches = ApplyAPIPatches
RuntimeSetup.RunSettingsMigrations = RunSettingsMigrations
