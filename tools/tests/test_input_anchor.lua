--[[
File: tools/tests/test_input_anchor.lua
Purpose: Unit tests for the shared builog input-anchor keybind wrapper.

Usage:
  lua tools/tests/test_input_anchor.lua
]]

local passed, failed = 0, 0

local function check(condition, message)
    if condition then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
    end
end

local traceEvents = {}
local lastAction = nil
local infoEnabled = true
local traceEnabled = false
local gamepadMode = false
local bindingCalls = 0

BETTERUI = { CIM = { Keybinds = {} } }
BETTERUI.Log = {
    LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
    CATEGORY = { KEYBIND = "KEYBIND" },
    EnabledFor = function(level, category)
        if category ~= "KEYBIND" then return false end
        if level == 3 then return infoEnabled end
        if level == 1 then return traceEnabled end
        return false
    end,
    SetLastAction = function(action)
        lastAction = action
    end,
    TraceEvent = function(category, event, phase, data, level)
        traceEvents[#traceEvents + 1] = {
            category = category,
            event = event,
            phase = phase,
            data = data,
            level = level,
        }
    end,
}

function IsInGamepadPreferredMode()
    return gamepadMode
end

function ZO_Keybindings_GetHighestPriorityBindingStringFromAction(action)
    bindingCalls = bindingCalls + 1
    return "binding:" .. tostring(action)
end

dofile("Modules/CIM/Keybinds/InputAnchor.lua")

local InputAnchor = BETTERUI.CIM.Keybinds.InputAnchor

print("\n=== InputAnchor Tests ===\n")

check(type(InputAnchor) == "table", "InputAnchor is registered under BETTERUI.CIM.Keybinds")
check(type(InputAnchor.Wrap) == "function", "InputAnchor exposes Wrap")
check(type(InputAnchor.WrapGroup) == "function", "InputAnchor exposes WrapGroup")

local callbackCalls = 0
local enabledCalls = 0
local nameCalls = 0
local visibleCalls = 0
gamepadMode = true
infoEnabled = true
traceEnabled = false
traceEvents = {}
lastAction = nil
bindingCalls = 0

local entry = {
    keybind = "UI_SHORTCUT_PRIMARY",
    name = function()
        nameCalls = nameCalls + 1
        error("name resolver must not run")
    end,
    visible = function()
        visibleCalls = visibleCalls + 1
        error("visible resolver must not run")
    end,
    enabled = function()
        enabledCalls = enabledCalls + 1
        return false
    end,
    callback = function(a, b)
        callbackCalls = callbackCalls + 1
        return "ok", a, b
    end,
}

check(InputAnchor.Wrap(entry, { module = "Inventory", action = "primary" }) == entry,
    "Wrap returns the original descriptor entry")
local r1, r2, r3 = entry.callback("alpha", "beta")
check(callbackCalls == 1 and r1 == "ok" and r2 == "alpha" and r3 == "beta",
    "wrapped callback invokes original exactly once and preserves returns")
check(#traceEvents == 1, "wrapped callback emits one input anchor record")
local event = traceEvents[1]
check(event.category == "KEYBIND" and event.event == "input.keybind" and event.phase == "fired" and event.level == 3,
    "input anchor emits INFO KEYBIND input.keybind fired")
check(event.data and event.data.module == "Inventory" and event.data.action == "primary",
    "input anchor carries module and action")
check(event.data and event.data.keybind == "UI_SHORTCUT_PRIMARY" and event.data.gamepad == true,
    "input anchor carries keybind and live gamepad mode")
check(event.data and event.data.enabled == false and enabledCalls == 1,
    "input anchor captures cheap enabled state")
check(lastAction == "Inventory.primary", "input anchor sets the last action token")
check(nameCalls == 0 and visibleCalls == 0, "input anchor does not evaluate name or visible resolvers")
check(bindingCalls == 0 and event.data.binding == nil, "binding lookup is skipped when TRACE is disabled")

traceEnabled = true
traceEvents = {}
entry.callback()
check(bindingCalls == 1 and traceEvents[1].data.binding == "binding:UI_SHORTCUT_PRIMARY",
    "binding lookup is pcall-guarded and included only when TRACE is enabled")

local offEnabledCalls = 0
local offCallbackCalls = 0
infoEnabled = false
traceEnabled = true
traceEvents = {}
lastAction = nil
local offEntry = {
    keybind = "UI_SHORTCUT_SECONDARY",
    enabled = function()
        offEnabledCalls = offEnabledCalls + 1
        return true
    end,
    callback = function()
        offCallbackCalls = offCallbackCalls + 1
        return "off-ok"
    end,
}
InputAnchor.Wrap(offEntry, { module = "Banking", action = "toggle" })
check(offEntry.callback() == "off-ok" and offCallbackCalls == 1,
    "logging-off path still runs the callback")
check(#traceEvents == 0 and lastAction == nil and offEnabledCalls == 0,
    "logging-off path emits nothing and builds no enabled payload")

infoEnabled = true
traceEnabled = false
local errorCalls = 0
local errorEntry = {
    keybind = "UI_SHORTCUT_TERTIARY",
    callback = function()
        errorCalls = errorCalls + 1
        error("callback boom")
    end,
}
InputAnchor.Wrap(errorEntry, { module = "Vendor", action = "actions" })
local ok, err = pcall(errorEntry.callback)
check(ok == false and tostring(err):find("callback boom", 1, true) ~= nil and errorCalls == 1,
    "wrapped callback propagates original errors unchanged")

local doubleCalls = 0
local doubleEntry = {
    keybind = "UI_SHORTCUT_QUINARY",
    callback = function()
        doubleCalls = doubleCalls + 1
    end,
}
InputAnchor.Wrap(doubleEntry, { module = "Inventory", action = "multi_select" })
InputAnchor.Wrap(doubleEntry, { module = "Inventory", action = "multi_select" })
doubleEntry.callback()
check(doubleCalls == 1, "wrapping an entry twice does not double-call the original callback")

local groupNameCalls = 0
traceEvents = {}
local group = {
    alignment = "left",
    {
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        name = function()
            groupNameCalls = groupNameCalls + 1
            error("group name resolver must not run")
        end,
        callback = function() return "group-ok" end,
    },
}
check(InputAnchor.WrapGroup(group, "Companions") == group, "WrapGroup returns the original descriptor group")
check(group[1].callback() == "group-ok", "WrapGroup wraps numeric descriptor entries")
check(traceEvents[1] and traceEvents[1].data.action == "UI_SHORTCUT_RIGHT_STICK",
    "WrapGroup falls back to the keybind token when name is a resolver")
check(groupNameCalls == 0, "WrapGroup does not evaluate name resolvers")

print(string.format("\nInputAnchor tests: %d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
