--[[
File: Modules/CIM/Core/DebugCommands.lua
Purpose: Slash command registration for BetterUI developer debug tools.
         Extracted from DeveloperDebug.lua to keep files under the 600-line limit.
         DISABLED BY DEFAULT - Commands check IsEnabled internally.

Extracted from: DeveloperDebug.lua (command registration concern)
]]

local Debug = BETTERUI.CIM.Debug

-- ============================================================================
-- DIAGNOSTIC INSPECTOR FUNCTIONS
-- ============================================================================

--[[
Function: InspectDirectionalInput
Diagnoses DIRECTIONAL_INPUT stack issues.
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

        if obj.list then
            objType = "ScrollList"
        elseif obj.tabBar then
            objType = "Screen/Header"
        elseif obj.movementController then
            objType = "MovementController"
        elseif obj.digits then
            objType = "CurrencySelector"
        end

        local isBetterUI = controlName and controlName:find("BETTERUI")

        d(string.format("  |c888888[%d]|r %s - Control: %s %s",
            i,
            objType,
            controlName,
            isBetterUI and "|cffcc00(BETTERUI)|r" or ""))
    end

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

local function InspectScenes()
    if not SCENE_MANAGER or not SCENE_MANAGER.scenes then
        d("[BetterUI Debug] SCENE_MANAGER not available")
        return
    end

    d("|c00ccff[BetterUI Debug]|r Scene States:")

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

    local current = SCENE_MANAGER:GetCurrentScene()
    if current then
        d(string.format("  |cffff00Current:|r %s", current:GetName()))
    end
end

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

local function InspectList(listName)
    d("|c00ccff[BetterUI Debug]|r List Inspector:")

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

local function InspectEvents()
    d("|c00ccff[BetterUI Debug]|r Event Registration:")

    if Debug.IsEnabled and BETTERUI.CIM.EventRegistry and BETTERUI.CIM.EventRegistry.GetRegisteredEvents then
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

local function InspectMemory()
    d("|c00ccff[BetterUI Debug]|r Memory & Cache Diagnostics:")

    d("|cffcc00[Event Registry]|r")
    if BETTERUI.CIM.EventRegistry and BETTERUI.CIM.EventRegistry.GetRegisteredEvents then
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

    d("|cffcc00[Deferred Tasks]|r")
    if BETTERUI.CIM.Tasks then
        local pending = 0
        if BETTERUI.CIM.Tasks._tasks then
            for _ in pairs(BETTERUI.CIM.Tasks._tasks) do
                pending = pending + 1
            end
        end
        d(string.format("  Pending tasks: %d", pending))
    else
        d("  DeferredTask not available")
    end

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

    local memKB = collectgarbage("count")
    d("|cffcc00[Lua Memory]|r")
    d(string.format("  Approximate usage: %.1f KB", memKB))
end

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

    if BETTERUI.Settings.FeatureFlags then
        d("  |cffcc00Feature Flags:|r")
        for flag, state in pairs(BETTERUI.Settings.FeatureFlags) do
            local stateStr = state and "|c00ff00ON|r" or "|cff0000OFF|r"
            d(string.format("    %s: %s", flag, stateStr))
        end
    end
end

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

function Debug.RegisterCommands()
    SLASH_COMMANDS["/buidebug"] = function(args)
        if not Debug.IsEnabled() then
            d(
                "|cff6600[BetterUI]|r Debug mode is disabled. Enable 'Debug Logging' in BetterUI settings or set BETTERUI_DEBUG = true")
            return
        end
        InspectDirectionalInput()
    end

    SLASH_COMMANDS["/buiscene"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectScenes()
    end

    SLASH_COMMANDS["/buikeybinds"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectKeybinds()
    end

    SLASH_COMMANDS["/builist"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectList(args)
    end

    SLASH_COMMANDS["/buievents"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectEvents()
    end

    SLASH_COMMANDS["/buisettings"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        DumpSettings()
    end

    SLASH_COMMANDS["/buicontrol"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectControl(args)
    end

    SLASH_COMMANDS["/buiprofile"] = function(args)
        if not Debug.IsEnabled() then
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

    SLASH_COMMANDS["/buiflag"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end

        local flag, value = args:match("^(%S+)%s*(.*)$")
        if not flag then
            d("|c00ccff[BetterUI]|r Debug Flags:")
            for name, state in pairs(Debug.FLAGS) do
                local stateStr = state and "|c00ff00ON|r" or "|cff0000OFF|r"
                d(string.format("  %s: %s", name, stateStr))
            end
            d("Usage: /buiflag <flagName> [on|off]")
            return
        end

        flag = flag:upper()
        if Debug.FLAGS[flag] == nil then
            d(string.format("|cff0000[BetterUI]|r Unknown flag: %s", flag))
            return
        end

        if value == "on" or value == "true" or value == "1" then
            Debug.SetFlag(flag, true)
        elseif value == "off" or value == "false" or value == "0" then
            Debug.SetFlag(flag, false)
        else
            Debug.SetFlag(flag, not Debug.FLAGS[flag])
        end
    end

    SLASH_COMMANDS["/buimemory"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end
        InspectMemory()
    end

    SLASH_COMMANDS["/buibatch"] = function(args)
        if not Debug.IsEnabled() then
            d("|cff6600[BetterUI]|r Debug mode is disabled.")
            return
        end

        d("|c00ccff[BetterUI Debug]|r Last Batch Summary:")
        local sources = {
            { name = "Inventory", ref = BETTERUI.Inventory and BETTERUI.Inventory.Window },
            { name = "Banking",   ref = BETTERUI.Banking and BETTERUI.Banking.Window },
        }
        local found = false
        for _, src in ipairs(sources) do
            local summary = src.ref and src.ref.lastBatchSummary
            if summary then
                found = true
                d(string.format("  |cffcc00%s:|r %s", src.name, summary.action or "unknown"))
                d(string.format("    Items: %d/%d  Cost: %d", summary.processed or 0, summary.totalItems or 0, summary.cost or 0))
                d(string.format("    Elapsed: %.0fms  Avg: %.0fms/item", summary.elapsedMs or 0, summary.avgDelayMs or 0))
                d(string.format("    Token: %d  Abort: %s", summary.pipelineToken or 0, tostring(summary.abortReason or "none")))
            end
        end
        if not found then
            d("  No batch has been executed this session.")
        end
    end

    SLASH_COMMANDS["/buihelp"] = function(args)
        d("|c00ccff[BetterUI Debug Commands]|r")
        d("  /buidebug - Inspect DIRECTIONAL_INPUT stack")
        d("  /buiscene - List scene states")
        d("  /buikeybinds - List keybind strip")
        d("  /builist - Inspect list states")
        d("  /buievents - List registered events")
        d("  /buisettings - Dump current settings")
        d("  /buimemory - Memory and cache diagnostics")
        d("  /buibatch - Last batch operation diagnostics")
        d("  /buicontrol <name> - Inspect a control")
        d("  /buiprofile [start|stop|report|reset] - Performance profiler")
        d("  /buiflag [flag] [on|off] - Toggle debug flags")
        d("  /buihelp - Show this help")
    end
end

-- Register commands immediately (they check IsEnabled internally)
Debug.RegisterCommands()
