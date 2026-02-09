--[[
File: Modules/CIM/RuntimeSetup.lua
Purpose: Consolidates early-initialization logic for BetterUI.
         Applies runtime API patches and runs settings migrations.

         This file exists to keep BetterUI.lua clean and focused on module loading.
         All "dirty but necessary" workarounds for ESO API issues are isolated here.

Mechanics:
    1. ApplyAPIPatches(): Wraps ESO global functions (zo_iconFormat, etc.) to handle nil paths.
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

-- ============================================================================
-- API PATCHES
-- ============================================================================

--[[
Function: ApplyAPIPatches
Description: Wraps ESO global icon/text formatting functions to handle nil paths gracefully.
Rationale: ESO's zo_iconFormat and related functions crash when passed nil paths.
           This commonly occurs during skill purchases, keybind strip updates, and UI transitions.
           These pcall wrappers are INTENTIONAL for ESO API stability.
Mechanism:
    1. Checks if each function exists.
    2. Stores original reference.
    3. Replaces with a wrapper that nil-checks the path and uses pcall for safety.
    4. Also patches ZO_KeybindStrip:HandleDuplicateAddKeybind to recover from descriptor errors.
References: Called by RuntimeSetup.Apply().
-- AUDITED(pcall): These pcall wrappers are intentional for ESO API stability.
]]
local function ApplyAPIPatches()
    if patchesApplied then return end

    -- TODO(refactor): Extract common icon patching pattern into helper function - 6 nearly identical blocks follow
    -- Patch 1: Wrap global icon/text formatting helpers to handle nil paths gracefully.
    if type(zo_iconFormat) == "function" then
        local _orig_zo_iconFormat = zo_iconFormat
        zo_iconFormat = function(path, width, height)
            if path == nil then path = "" end
            local ok, res = pcall(function()
                return _orig_zo_iconFormat(path, width, height)
            end)
            return ok and res or ""
        end
    end

    if type(zo_iconFormatInheritColor) == "function" then
        local _orig_zo_iconFormatInheritColor = zo_iconFormatInheritColor
        zo_iconFormatInheritColor = function(path, width, height)
            if path == nil then path = "" end
            local ok, res = pcall(function()
                return _orig_zo_iconFormatInheritColor(path, width, height)
            end)
            return ok and res or ""
        end
    end

    if type(zo_iconTextFormat) == "function" then
        local _orig_zo_iconTextFormat = zo_iconTextFormat
        zo_iconTextFormat = function(path, width, height, text, inheritColor, noGrammar)
            if path == nil then path = "" end
            local ok, res = pcall(function()
                return _orig_zo_iconTextFormat(path, width, height, text, inheritColor, noGrammar)
            end)
            return ok and res or tostring(text or "")
        end
    end

    if type(zo_iconTextFormatAlignedRight) == "function" then
        local _orig_zo_iconTextFormatAlignedRight = zo_iconTextFormatAlignedRight
        zo_iconTextFormatAlignedRight = function(path, width, height, text, inheritColor, noGrammar)
            if path == nil then path = "" end
            local ok, res = pcall(function()
                return _orig_zo_iconTextFormatAlignedRight(path, width, height, text, inheritColor, noGrammar)
            end)
            return ok and res or tostring(text or "")
        end
    end

    if type(zo_iconTextFormatNoSpace) == "function" then
        local _orig_zo_iconTextFormatNoSpace = zo_iconTextFormatNoSpace
        zo_iconTextFormatNoSpace = function(path, width, height, text, inheritColor)
            if path == nil then path = "" end
            local ok, res = pcall(function()
                return _orig_zo_iconTextFormatNoSpace(path, width, height, text, inheritColor)
            end)
            return ok and res or tostring(text or "")
        end
    end

    if type(zo_iconTextFormatNoSpaceAlignedRight) == "function" then
        local _orig_zo_iconTextFormatNoSpaceAlignedRight = zo_iconTextFormatNoSpaceAlignedRight
        zo_iconTextFormatNoSpaceAlignedRight = function(path, width, height, text, inheritColor, noGrammar)
            if path == nil then path = "" end
            local ok, res = pcall(function()
                return _orig_zo_iconTextFormatNoSpaceAlignedRight(path, width, height, text, inheritColor, noGrammar)
            end)
            return ok and res or tostring(text or "")
        end
    end

    -- Patch 2: Wrap ZO_KeybindStrip:HandleDuplicateAddKeybind to safely evaluate descriptor names.
    -- The original function calls GetKeybindDescriptorDebugIdentifier on descriptors, which can
    -- call formatting helpers (like zo_iconFormat) with nil paths. We wrap this to silently
    -- handle any errors. On error, we attempt to remove the conflicting descriptor so the
    -- new one can be registered, restoring keybind strip functionality.
    if ZO_KeybindStrip and type(ZO_KeybindStrip.HandleDuplicateAddKeybind) == "function" then
        local _orig_HandleDuplicate = ZO_KeybindStrip.HandleDuplicateAddKeybind
        ZO_KeybindStrip.HandleDuplicateAddKeybind = function(self, existingButtonOrEtherealDescriptor,
                                                             keybindButtonDescriptor, state, stateIndex, currentSceneName)
            local ok, res = pcall(function()
                return _orig_HandleDuplicate(self, existingButtonOrEtherealDescriptor, keybindButtonDescriptor, state,
                    stateIndex, currentSceneName)
            end)
            -- If the call succeeded, return normally
            if ok then return res end

            -- If the call failed, attempt a safe recovery by removing the conflicting descriptor
            -- so the new keybind can be registered. This ensures LB/RB navigation is restored
            -- even when duplicate handling errors occur.
            pcall(function()
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

            -- Schedule a deferred re-add of the new keybind to handle timing edge cases where
            -- removal and re-add happen too quickly in the same frame. This is especially important
            -- during scene transitions (like search enter/exit) where multiple duplicate keybind
            -- errors may occur in quick succession. Use zo_callLater with a 0ms delay to defer
            -- until the next frame cycle, ensuring the removal has settled.
            pcall(function()
                if zo_callLater and type(zo_callLater) == "function" then
                    zo_callLater(function()
                        pcall(function()
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
