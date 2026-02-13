--[[
File: Modules/CIM/Core/DeveloperDebug.lua
Purpose: Consolidated developer debug module for BetterUI.
         Provides diagnostic commands, debug flags, and development utilities.
         DISABLED BY DEFAULT - Enable via DEBUG_LOGGING feature flag or BETTERUI_DEBUG global.
Author: BetterUI Team
Last Modified: 2026-02-08
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Debug = {}

-- Set to true during development to expose developer-only settings in LAM.
-- This is intentionally false for normal users.
BETTERUI.CIM.Debug.SHOW_DEVELOPER_SETTINGS = false

-- ============================================================================
-- DEBUG FLAGS
-- ============================================================================

--[[
Table: BETTERUI.CIM.Debug.FLAGS
Description: Sub-flags for specific debug features.
Rationale: Allows granular control over which debug visualizations are active.
Used By: ResourceOrbFrames, Inventory, Banking modules.
]]
BETTERUI.CIM.Debug.FLAGS = {
    SHIELD_OVERLAY = false,    -- Show shield overlay ring for visual debugging
    DIRECTIONAL_INPUT = false, -- Verbose DIRECTIONAL_INPUT logging
    SCENE_TRANSITIONS = false, -- Log scene state changes
    LIST_OPERATIONS = false,   -- Log list activation/deactivation
    CALLBACK_TRACING = false,  -- Log SafeExecuteCallback lifecycle
}

-- ============================================================================
-- CORE API
-- ============================================================================

--[[
Function: BETTERUI.CIM.Debug.IsEnabled
Description: Checks if debug mode is enabled.
Rationale: Single point of control for all debug features.
Mechanism: Checks FeatureFlags.DEBUG_LOGGING OR global BETTERUI_DEBUG.
References: Called by all debug utilities before executing.
]]
--- @return boolean enabled True if debug mode is active
function BETTERUI.CIM.Debug.IsEnabled()
    -- Check global flag first (backward compatibility)
    if BETTERUI_DEBUG then
        return true
    end

    -- Check FeatureFlags system
    if BETTERUI.CIM.FeatureFlags and BETTERUI.CIM.FeatureFlags.IsEnabled then
        return BETTERUI.CIM.FeatureFlags.IsEnabled("DEBUG_LOGGING")
    end

    return false
end

--- Returns whether developer-only settings should be visible in LAM.
--- Developers can enable this by setting SHOW_DEVELOPER_SETTINGS = true above.
--- @return boolean show True when developer settings should be shown
function BETTERUI.CIM.Debug.ShouldShowDeveloperSettings()
    if BETTERUI_DEBUG then
        return true
    end
    return BETTERUI.CIM.Debug.SHOW_DEVELOPER_SETTINGS == true
end

--[[
Function: BETTERUI.CIM.Debug.Log
Description: Conditional debug logging that respects debug mode state.
Rationale: Wrapper for BETTERUI.Debug that only outputs when debug is enabled.
Mechanism: Checks IsEnabled before printing.
References: Used throughout codebase for development logging.
]]
--- @param message string The message to log
--- @param category? string Optional category prefix (e.g., "Scene", "List")
function BETTERUI.CIM.Debug.Log(message, category)
    if not BETTERUI.CIM.Debug.IsEnabled() then return end

    local prefix = category and string.format("[%s] ", category) or ""
    BETTERUI.Debug(prefix .. message)
end

--[[
Function: BETTERUI.CIM.Debug.SetFlag
Description: Sets a debug sub-flag.
Rationale: Runtime toggling of specific debug features.
]]
--- @param flagName string The flag name from FLAGS table
--- @param enabled boolean The new state
function BETTERUI.CIM.Debug.SetFlag(flagName, enabled)
    if BETTERUI.CIM.Debug.FLAGS[flagName] ~= nil then
        BETTERUI.CIM.Debug.FLAGS[flagName] = enabled
        BETTERUI.CIM.Debug.Log(string.format("Flag %s set to %s", flagName, tostring(enabled)), "Debug")
    end
end

-- ============================================================================
-- DIAGNOSTIC COMMANDS
-- ============================================================================

--[[
Function: InspectDirectionalInput
Description: Diagnoses DIRECTIONAL_INPUT stack issues.
Rationale: Critical for debugging joystick lock-up problems.
Mechanism: Lists all registered input objects and their associated controls.
References: Migrated from BetterUI.lua /buidebug command.
]]
local function InspectDirectionalInput()
    if not DIRECTIONAL_INPUT then
        d("[BetterUI Debug] DIRECTIONAL_INPUT not available")
        return
    end

    local inputObjects = DIRECTIONAL_INPUT.inputObjects or {}
    local inputControls = DIRECTIONAL_INPUT.inputControls or {}

    d("|c00ccff[BetterUI Debug]|r DIRECTIONAL_INPUT - " .. #inputObjects .. " objects registered:")
    for i, obj in ipairs(inputObjects) do
        local control = inputControls[i]
        local controlName = control and control:GetName() or "nil"
        local objType = "unknown"

        -- Identify object type
        if obj.list then
            objType = "ScrollList"
        elseif obj.tabBar then
            objType = "Screen/Header"
        elseif obj.movementController then
            objType = "MovementController"
        elseif obj.digits then
            objType = "CurrencySelector"
        end

        -- Check if it's a BetterUI object
        local isBetterUI = controlName and controlName:find("BETTERUI")

        d(string.format("  |c888888[%d]|r %s - Control: %s %s",
            i,
            objType,
            controlName,
            isBetterUI and "|cffcc00(BETTERUI)|r" or ""))
    end

    -- Input device consumed state
    d("|c00ccff[BetterUI Debug]|r Input device consumed state:")
    local deviceNames = {
        [1] = "LEFT_STICK",
        [2] = "RIGHT_STICK",
        [3] = "DPAD",
        [4] = "LEFT_STICK_NO_KB",
        [5] = "RIGHT_STICK_NO_KB"
    }
    for device = 1, 5 do
        local consumed = DIRECTIONAL_INPUT.inputDeviceConsumed[device]
        local deviceName = deviceNames[device] or "UNKNOWN"
        d(string.format("  %s: %s", deviceName, consumed and "|cff0000CONSUMED|r" or "|c00ff00available|r"))
    end
end

--[[
Function: InspectScenes
Description: Lists all known scenes and their current states.
Rationale: Essential for debugging scene transition issues.
]]
local function InspectScenes()
    if not SCENE_MANAGER or not SCENE_MANAGER.scenes then
        d("[BetterUI Debug] SCENE_MANAGER not available")
        return
    end

    d("|c00ccff[BetterUI Debug]|r Scene States:")

    -- BetterUI-relevant scenes
    local relevantScenes = {
        "gamepad_inventory_root",
        "gamepad_banking",
        "gamepad_store",
        "gamepad_crafting",
        "gamepad_loot",
        "gamepad_stats_root",
        "gamepad_companion_root",
    }

    for _, sceneName in ipairs(relevantScenes) do
        local scene = SCENE_MANAGER.scenes[sceneName]
        if scene then
            local state = scene:GetState()
            local stateColor = (state == SCENE_SHOWN or state == SCENE_SHOWING) and "|c00ff00" or "|c888888"
            d(string.format("  %s: %s%s|r", sceneName, stateColor, state or "nil"))
        end
    end

    -- Current scene
    local current = SCENE_MANAGER:GetCurrentScene()
    if current then
        d(string.format("  |cffff00Current:|r %s", current:GetName()))
    end
end

--[[
Function: InspectKeybinds
Description: Lists keybinds on the current strip.
Rationale: Helps debug keybind conflicts and Y-menu issues.
]]
local function InspectKeybinds()
    if not KEYBIND_STRIP then
        d("[BetterUI Debug] KEYBIND_STRIP not available")
        return
    end

    d("|c00ccff[BetterUI Debug]|r Keybind Strip:")

    local keybinds = KEYBIND_STRIP.keybinds
    if not keybinds then
        d("  No keybinds registered")
        return
    end

    local count = 0
    for keybind, descriptor in pairs(keybinds) do
        count = count + 1
        local name = descriptor.name
        if type(name) == "function" then
            name = name()
        end
        d(string.format("  |c888888[%s]|r %s", tostring(keybind), tostring(name or "unnamed")))
    end
    d(string.format("  Total: %d keybinds", count))
end

--[[
Function: InspectList
Description: Shows current list state (selection, count, activation).
Rationale: Critical for debugging inventory/banking list issues.
]]
local function InspectList(listName)
    d("|c00ccff[BetterUI Debug]|r List Inspector:")

    -- Try to find BetterUI lists
    local lists = {
        { name = "Inventory", ref = BETTERUI.Inventory and BETTERUI.Inventory.Window and BETTERUI.Inventory.Window.currentList },
        { name = "Banking",   ref = BETTERUI.Banking and BETTERUI.Banking.Window and BETTERUI.Banking.Window.currentList },
    }

    for _, listInfo in ipairs(lists) do
        if listInfo.ref then
            local list = listInfo.ref
            local targetData = list.GetTargetData and list:GetTargetData()
            local selectedIndex = list.GetSelectedIndex and list:GetSelectedIndex() or "N/A"
            local numItems = list.GetNumItems and list:GetNumItems() or "N/A"
            local isActive = list.IsActive and list:IsActive() or "N/A"

            d(string.format("  |cffcc00%s List:|r", listInfo.name))
            d(string.format("    Selected Index: %s", tostring(selectedIndex)))
            d(string.format("    Item Count: %s", tostring(numItems)))
            d(string.format("    Active: %s", tostring(isActive)))
            if targetData then
                d(string.format("    Target Name: %s", tostring(targetData.name or "nil")))
            end
        end
    end
end

--[[
Function: InspectEvents
Description: Lists BetterUI-registered events.
Rationale: Debug event registration issues.
]]
local function InspectEvents()
    d("|c00ccff[BetterUI Debug]|r Event Registration:")

    if BETTERUI.CIM and BETTERUI.CIM.EventRegistry and BETTERUI.CIM.EventRegistry.GetRegisteredEvents then
        local events = BETTERUI.CIM.EventRegistry.GetRegisteredEvents()
        if events then
            for moduleName, moduleEvents in pairs(events) do
                d(string.format("  |cffcc00%s:|r %d events", moduleName, #moduleEvents))
            end
        end
    else
        d("  EventRegistry not available")
    end
end

--[[
Function: InspectMemory
Description: Shows memory and cache diagnostics.
Rationale: Helps identify memory leaks and cache bloat.
]]
local function InspectMemory()
    d("|c00ccff[BetterUI Debug]|r Memory & Cache Diagnostics:")

    -- Event registration counts
    d("|cffcc00[Event Registry]|r")
    if BETTERUI.CIM and BETTERUI.CIM.EventRegistry and BETTERUI.CIM.EventRegistry.GetRegisteredEvents then
        local events = BETTERUI.CIM.EventRegistry.GetRegisteredEvents()
        if events then
            local totalEvents = 0
            for moduleName, moduleEvents in pairs(events) do
                local count = #moduleEvents
                totalEvents = totalEvents + count
                d(string.format("  %s: %d events", moduleName, count))
            end
            d(string.format("  |c888888Total:|r %d", totalEvents))
        else
            d("  No registrations tracked")
        end
    else
        d("  EventRegistry not available")
    end

    -- Deferred task counts
    d("|cffcc00[Deferred Tasks]|r")
    if BETTERUI.CIM and BETTERUI.CIM.Tasks then
        local pending = 0
        -- TODO(bug): Field name mismatch - DeferredTask.lua defines _tasks, not _scheduled; this always reads nil so pending count is always 0
        if BETTERUI.CIM.Tasks._scheduled then
            for _ in pairs(BETTERUI.CIM.Tasks._scheduled) do
                pending = pending + 1
            end
        end
        d(string.format("  Pending tasks: %d", pending))
    else
        d("  DeferredTask not available")
    end

    -- Profiler stats if enabled
    d("|cffcc00[Performance Profiler]|r")
    if BETTERUI.CIM.Profiler and BETTERUI.CIM.Profiler.IsEnabled and BETTERUI.CIM.Profiler.IsEnabled() then
        local timings = BETTERUI.CIM.Profiler.GetTimings and BETTERUI.CIM.Profiler.GetTimings() or {}
        local counters = BETTERUI.CIM.Profiler.GetCounters and BETTERUI.CIM.Profiler.GetCounters() or {}
        local timingCount, counterCount = 0, 0
        for _ in pairs(timings) do timingCount = timingCount + 1 end
        for _ in pairs(counters) do counterCount = counterCount + 1 end
        d(string.format("  Tracked operations: %d", timingCount))
        d(string.format("  Tracked counters: %d", counterCount))
    else
        d("  Profiler disabled")
    end

    -- Lua memory usage (approximate)
    local memKB = collectgarbage("count")
    d("|cffcc00[Lua Memory]|r")
    d(string.format("  Approximate usage: %.1f KB", memKB))
end

--[[
Function: DumpSettings
Description: Outputs current module settings.
Rationale: Useful for support and bug reports.
]]
local function DumpSettings()
    d("|c00ccff[BetterUI Debug]|r Settings Dump:")

    if not BETTERUI.Settings or not BETTERUI.Settings.Modules then
        d("  Settings not available")
        return
    end

    for moduleName, settings in pairs(BETTERUI.Settings.Modules) do
        local enabled = settings.m_enabled and "|c00ff00ON|r" or "|cff0000OFF|r"
        d(string.format("  %s: %s", moduleName, enabled))
    end

    -- Feature flags
    if BETTERUI.Settings.FeatureFlags then
        d("  |cffcc00Feature Flags:|r")
        for flag, state in pairs(BETTERUI.Settings.FeatureFlags) do
            local stateStr = state and "|c00ff00ON|r" or "|cff0000OFF|r"
            d(string.format("    %s: %s", flag, stateStr))
        end
    end
end

--[[
Function: InspectControl
Description: Shows details about a named control.
Rationale: Debug UI layout and visibility issues.
]]
--- @param controlName string The control name to inspect
local function InspectControl(controlName)
    if not controlName or controlName == "" then
        d("[BetterUI Debug] Usage: /buicontrol <controlName>")
        return
    end

    local control = GetControl(controlName)
    if not control then
        d(string.format("[BetterUI Debug] Control '%s' not found", controlName))
        return
    end

    d(string.format("|c00ccff[BetterUI Debug]|r Control: %s", controlName))
    d(string.format("  Hidden: %s", tostring(control:IsHidden())))
    d(string.format("  Alpha: %.2f", control:GetAlpha()))

    local left, top, right, bottom = control:GetScreenRect()
    if left then
        d(string.format("  Rect: L=%.0f T=%.0f R=%.0f B=%.0f", left, top, right, bottom))
        d(string.format("  Size: %.0f x %.0f", right - left, bottom - top))
    end

    local parent = control:GetParent()
    if parent then
        d(string.format("  Parent: %s", parent:GetName() or "unnamed"))
    end

    local numChildren = control:GetNumChildren()
    if numChildren > 0 then
        d(string.format("  Children: %d", numChildren))
    end
end

-- ============================================================================
-- SLASH COMMAND REGISTRATION
-- ============================================================================

--[[
Function: BETTERUI.CIM.Debug.RegisterCommands
Description: Registers all debug slash commands.
Rationale: Commands only registered when debug mode is confirmed active.
Mechanism: Called during addon initialization if debug is enabled.
]]
function BETTERUI.CIM.Debug.RegisterCommands()
    -- Main debug command (DIRECTIONAL_INPUT inspector)
    SLASH_COMMANDS["/buidebug"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d(
                "|cff6600[BetterUI]|r Debug mode is disabled. Enable 'Debug Logging' in BetterUI settings or set BETTERUI_DEBUG = true")
            return
        end
        InspectDirectionalInput()
    end

    -- Scene inspector
    SLASH_COMMANDS["/buiscene"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectScenes()
    end

    -- Keybind inspector
    SLASH_COMMANDS["/buikeybinds"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectKeybinds()
    end

    -- List inspector
    SLASH_COMMANDS["/builist"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectList(args)
    end

    -- Event inspector
    SLASH_COMMANDS["/buievents"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectEvents()
    end

    -- Settings dump
    SLASH_COMMANDS["/buisettings"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        DumpSettings()
    end

    -- Control inspector
    SLASH_COMMANDS["/buicontrol"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectControl(args)
    end

    -- Profiler commands
    SLASH_COMMANDS["/buiprofile"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end

        if args == "start" then
            if BETTERUI.CIM.Profiler then
                BETTERUI.CIM.Profiler.Enable(true)
                d("|c00ccff[BetterUI]|r Profiler started")
            end
        elseif args == "stop" then
            if BETTERUI.CIM.Profiler then
                BETTERUI.CIM.Profiler.Enable(false)
                d("|c00ccff[BetterUI]|r Profiler stopped")
            end
        elseif args == "report" then
            if BETTERUI.CIM.Profiler then
                BETTERUI.CIM.Profiler.Report()
            end
        elseif args == "reset" then
            if BETTERUI.CIM.Profiler then
                BETTERUI.CIM.Profiler.Reset()
                d("|c00ccff[BetterUI]|r Profiler reset")
            end
        else
            d("|c00ccff[BetterUI]|r Usage: /buiprofile [start|stop|report|reset]")
        end
    end

    -- Flag toggle
    SLASH_COMMANDS["/buiflag"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end

        local flag, value = args:match("^(%S+)%s*(.*)$")
        if not flag then
            d("|c00ccff[BetterUI]|r Debug Flags:")
            for name, state in pairs(BETTERUI.CIM.Debug.FLAGS) do
                local stateStr = state and "|c00ff00ON|r" or "|cff0000OFF|r"
                d(string.format("  %s: %s", name, stateStr))
            end
            d("Usage: /buiflag <flagName> [on|off]")
            return
        end

        flag = flag:upper()
        if BETTERUI.CIM.Debug.FLAGS[flag] == nil then
            d(string.format("|cff0000[BetterUI]|r Unknown flag: %s", flag))
            return
        end

        if value == "on" or value == "true" or value == "1" then
            BETTERUI.CIM.Debug.SetFlag(flag, true)
        elseif value == "off" or value == "false" or value == "0" then
            BETTERUI.CIM.Debug.SetFlag(flag, false)
        else
            -- Toggle
            BETTERUI.CIM.Debug.SetFlag(flag, not BETTERUI.CIM.Debug.FLAGS[flag])
        end
    end

    -- Memory/cache inspector
    SLASH_COMMANDS["/buimemory"] = function(args)
        if not BETTERUI.CIM.Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectMemory()
    end

    -- Help command
    SLASH_COMMANDS["/buihelp"] = function(args)
        d("|c00ccff[BetterUI Debug Commands]|r")
        d("  /buidebug - Inspect DIRECTIONAL_INPUT stack")
        d("  /buiscene - List scene states")
        d("  /buikeybinds - List keybind strip")
        d("  /builist - Inspect list states")
        d("  /buievents - List registered events")
        d("  /buisettings - Dump current settings")
        d("  /buimemory - Memory and cache diagnostics")
        d("  /buicontrol <name> - Inspect a control")
        d("  /buiprofile [start|stop|report|reset] - Performance profiler")
        d("  /buiflag [flag] [on|off] - Toggle debug flags")
        d("  /buihelp - Show this help")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Register commands immediately (they check IsEnabled internally)
BETTERUI.CIM.Debug.RegisterCommands()

-- Backward compatibility: Support BETTERUI_SHIELD_DEBUG global
-- TODO(refactor): Migrate BETTERUI_SHIELD_DEBUG to FeatureFlags system
-- This allows existing code to work without changes
if BETTERUI_SHIELD_DEBUG then
    BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY = true
end
