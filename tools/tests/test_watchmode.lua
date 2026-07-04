--[[
File: tools/tests/test_watchmode.lua
Purpose: Unit tests for WatchMode.lua — the watch-preset enrichment layer.
         Uses a fake BETTERUI.Log + fake SCENE_MANAGER/zo_callLater so the module is
         exercised in isolation.
Usage:   lua tools/tests/test_watchmode.lua
]]

BETTERUI = { CIM = {} }

-- Fake Names (resolves a {name=..} mock scene; userdata path covered by test_names).
BETTERUI.CIM.Names = {
    Scene = function(s)
        if type(s) == "table" and s.name then return s.name end
        return "<unknown>"
    end,
}
BETTERUI.Names = BETTERUI.CIM.Names

-- Fake SCENE_MANAGER returning a current scene.
local fakeScene = { name = "gamepad_banking" }
SCENE_MANAGER = { GetCurrentScene = function() return fakeScene end }

-- Fake zo_callLater: capture callbacks, do NOT auto-run (avoids infinite heartbeat).
local laters = {}
function zo_callLater(fn, ms) laters[#laters + 1] = { fn = fn, ms = ms }; return #laters end
function GetUnitName(unitTag) return unitTag == "player" and "Private Hero" or "" end
function GetUnitZone(unitTag) return unitTag == "player" and "Private Zone" or "" end
function GetNumAddOns() return 2 end
function GetAddOnInfo(index)
    if index == 1 then return "BetterUI", "BetterUI", "Author", "", true end
    if index == 2 then return "TradeSecrets", "TradeSecrets", "Author", "", true end
    return nil
end

KEYBIND_STRIP = {
    GetOrderedNarratableKeybindButtonInfo = function()
        return {
            { keybindName = "A", name = "Acquire", enabled = true },
            { keybindName = "B", name = "Back", enabled = false },
        }
    end,
}

-- Fake Log capturing emitted records + the registered context provider.
local cap = { lines = {}, provider = nil, lastAction = nil, mutes = {} }
local privacyMode = false
BETTERUI.Log = {
    SCHEMA = 1,
    EVENT_SCHEMA = 1,
    LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
    CATEGORY = { STATE = "STATE", GENERAL = "GENERAL", LIST = "LIST", SEARCH = "SEARCH", SORT = "SORT", BATCH = "BATCH", FOOTER = "FOOTER", KEYBIND = "KEYBIND" },
    SetContextProvider = function(fn) cap.provider = fn end,
    GetContextProvider = function() return cap.provider end,
    GetLastAction = function() return cap.lastAction end,
    SetLastAction = function(m, f) cap.lastAction = { message = m, flow = f } end,
    GetSessionId = function() return "abcd1234" end,
    GetPrivacyMode = function() return privacyMode end,
    EnabledFor = function() return true end,
    SetCategoryEnabled = function(cat, on) cap.mutes[cat] = not on end,
    Info = function(cat, msg, data) cap.lines[#cap.lines + 1] = { lvl = "INFO", cat = cat, msg = msg, data = data } end,
    Debug = function(cat, msg, data) cap.lines[#cap.lines + 1] = { lvl = "DEBUG", cat = cat, msg = msg, data = data } end,
}

dofile("Modules/CIM/Core/Diagnostics/WatchMode.lua")
local Watch = BETTERUI.CIM.WatchMode
Watch.RegisterViewScene("banking", "gamepad_banking")
Watch.RegisterViewScene("inventory", "gamepad_inventory_root")

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== WatchMode Tests ===\n")

-- Activate: registers a context provider, emits a preamble, schedules a snapshot.
Watch.Activate()
check(cap.provider ~= nil, "Activate registers a Log context provider")
check(#cap.lines >= 1, "Activate emits a startup preamble record")
check(cap.lines[1].cat == "STATE", "preamble is a STATE record")
check(cap.lines[1].data and cap.lines[1].data.schema == 1, "preamble carries line schema")
check(cap.lines[1].data and cap.lines[1].data.eventSchema == 1, "preamble carries event schema")
check(cap.lines[1].data and cap.lines[1].data.player == "Private Hero" and cap.lines[1].data.zone == "Private Zone",
    "preamble carries player and zone while privacy is off")
check(cap.lines[2] and cap.lines[2].data and cap.lines[2].data.count == 2
    and cap.lines[2].data.names == "BetterUI,TradeSecrets",
    "active-addon preamble carries count and names while privacy is off")
check(#laters == 1, "Activate schedules a snapshot heartbeat via zo_callLater")
check(Watch.IsActive() == true, "IsActive true after Activate")
check(type(Watch.RegisterViewScene) == "function", "WatchMode exposes a view/scene registry")
check(type(Watch.ClearView) == "function", "WatchMode exposes prefix-scoped view clearing")
check(cap.mutes["LIST"] ~= true and cap.mutes["SEARCH"] ~= true and cap.mutes["SORT"] ~= true
    and cap.mutes["BATCH"] ~= true and cap.mutes["FOOTER"] ~= true and cap.mutes["KEYBIND"] ~= true,
    "Activate keeps replay-critical categories unmuted by default")

Watch.Deactivate()
privacyMode = true
cap.lines = {}; cap.provider = nil; cap.lastAction = nil; laters = {}
Watch.Activate()
check(cap.lines[1].data and cap.lines[1].data.player == nil and cap.lines[1].data.zone == nil,
    "privacy preamble omits player and zone")
check(cap.lines[2] and cap.lines[2].data and cap.lines[2].data.count == 2 and cap.lines[2].data.names == nil,
    "privacy active-addon preamble emits count only")
cap.lastAction = { message = string.rep("x", 80), flow = "privacy#1" }
local privateSuffix = cap.provider(2, "GENERAL")
check(privateSuffix:find('lastAction="' .. string.rep("x", 48) .. '"', 1, true) ~= nil
    and privateSuffix:find(string.rep("x", 49), 1, true) == nil,
    "privacy context suffix truncates lastAction to 48 chars")
local beforePrivateSnapshot = #cap.lines
Watch.Snapshot()
local privateSnap = cap.lines[#cap.lines]
check(#cap.lines > beforePrivateSnapshot and privateSnap.data and privateSnap.data.lastAction == string.rep("x", 48),
    "privacy snapshot truncates lastAction to 48 chars")
Watch.Deactivate()
privacyMode = false
cap.lines = {}; cap.provider = nil; cap.lastAction = nil; laters = {}
Watch.Activate()
cap.lastAction = { message = string.rep("y", 80), flow = "public#1" }
local cappedSuffix = cap.provider(2, "GENERAL")
check(cappedSuffix:find('lastAction="' .. string.rep("y", 48) .. '"', 1, true) ~= nil
    and cappedSuffix:find(string.rep("y", 49), 1, true) == nil,
    "context suffix truncates lastAction to 48 chars even when privacy is off")
local beforeCappedSnapshot = #cap.lines
Watch.Snapshot()
local cappedSnap = cap.lines[#cap.lines]
check(#cap.lines > beforeCappedSnapshot and cappedSnap.data and cappedSnap.data.lastAction == string.rep("y", 48),
    "snapshot truncates lastAction to 48 chars even when privacy is off")

-- Context suffix carries scene + flow + lastAction.
cap.lastAction = { message = "pressed A", flow = "deposit#1" }
local suffix = cap.provider(2, "GENERAL")
check(suffix:find("scene=gamepad_banking", 1, true) ~= nil, "suffix carries scene")
check(suffix:find("flow=deposit#1", 1, true) ~= nil, "suffix carries flow")
check(suffix:find('lastAction="pressed A"', 1, true) ~= nil, "suffix carries quoted lastAction")

-- SetView injects view=, clears on nil.
Watch.SetView("DepositTab")
check(cap.provider(2, "GENERAL"):find("view=DepositTab", 1, true) ~= nil, "SetView injects view=")
Watch.SetView(nil)
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil, "SetView(nil) clears view")

Watch.SetView("banking.withdraw")
check(cap.provider(2, "GENERAL"):find("view=banking.withdraw", 1, true) ~= nil,
    "banking view is emitted in the banking scene")
Watch.RegisterViewScene("banking", "BETTERUI_GUILD_BANKING")
fakeScene = { name = "BETTERUI_GUILD_BANKING" }
Watch.SetView("banking.deposit")
check(cap.provider(2, "GENERAL"):find("view=banking.deposit", 1, true) ~= nil,
    "banking view is emitted in the guild banking scene")
fakeScene = { name = "gamepad_banking" }
Watch.SetView("banking.withdraw")
check(cap.provider(2, "GENERAL"):find("view=banking.withdraw", 1, true) ~= nil,
    "banking view still matches the original banking scene after a second registration")
fakeScene = { name = "hud" }
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil,
    "banking view is suppressed outside the banking scene")
fakeScene = { name = "gamepad_banking" }
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil,
    "suppressed banking view is discarded")

Watch.SetView("inventory.items")
fakeScene = { name = "gamepad_inventory_root" }
check(cap.provider(2, "GENERAL"):find("view=inventory.items", 1, true) ~= nil,
    "inventory view is emitted in the inventory scene")
fakeScene = { name = "gamepad_banking" }
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil,
    "inventory view is suppressed outside the inventory scene")
fakeScene = { name = "gamepad_banking" }

Watch.SetView("vendor.sell")
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil,
    "unknown namespaced views are suppressed instead of leaking across scenes")

Watch.RegisterViewScene("vendor", "BETTERUI_VENDOR")
Watch.SetView("vendor.sell")
fakeScene = { name = "BETTERUI_VENDOR" }
check(cap.provider(2, "GENERAL"):find("view=vendor.sell", 1, true) ~= nil,
    "registered vendor view is emitted in its scene")
Watch.ClearView("companions")
check(cap.provider(2, "GENERAL"):find("view=vendor.sell", 1, true) ~= nil,
    "clearing a different prefix does not clear the active vendor view")
Watch.ClearView("vendor")
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil,
    "clearing the matching prefix clears the active vendor view")
Watch.SetView("vendor.sell")
fakeScene = { name = "hud" }
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil,
    "registered vendor view is suppressed outside its scene")
fakeScene = { name = "BETTERUI_VENDOR" }
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil,
    "suppressed registered view is discarded")

Watch.SetView("banking.deposit")
fakeScene = { name = "gamepad_banking" }
check(cap.provider(2, "GENERAL"):find("view=banking.deposit", 1, true) ~= nil,
    "banking view is restored before deactivate coverage")

-- Snapshot registry: registered provider value appears in the STATE snapshot.
Watch.RegisterSnapshotProvider("bankSlots", function() return 42 end)
cap.lastAction = { message = "withdraw item", flow = "bankTransfer#1" }
local before = #cap.lines
Watch.Snapshot()
check(#cap.lines > before, "Snapshot emits a record")
local snap = cap.lines[#cap.lines]
check(snap.cat == "STATE" and snap.msg == "snapshot", "Snapshot is a STATE 'snapshot' record")
check(snap.data and snap.data.bankSlots == 42, "Snapshot includes registered provider data")
check(snap.data and snap.data.scene == "gamepad_banking", "Snapshot includes current scene")
check(snap.data and snap.data.flow == "bankTransfer#1" and snap.data.lastAction == "withdraw item",
    "Snapshot includes current flow + lastAction")
check(snap.data and snap.data.keybinds and snap.data.keybinds:find("A:Acquire:e1", 1, true) ~= nil
    and snap.data.keybinds:find("B:Back:e0", 1, true) ~= nil,
    "Snapshot includes visible keybind strip narration state")
check(Watch.DescribeActiveKeybinds():find("A:Acquire:e1", 1, true) ~= nil,
    "DescribeActiveKeybinds exposes visible keybind strip state")

-- A provider that errors is pcall-guarded (does not break the snapshot).
Watch.RegisterSnapshotProvider("boom", function() error("nope") end)
local okCall = pcall(Watch.Snapshot)
check(okCall, "Snapshot survives an erroring provider")

-- KeybindPresent: the shared snapshot helper backing every module's `keybind*`
-- digest field. Returns a 1/0 numeric and is call-time safe when Interface is absent.
check(Watch.KeybindPresent(nil) == 0, "KeybindPresent returns 0 when no keybind interface is loaded")
BETTERUI.Interface = { HasKeybindGroup = function(d) return d ~= nil end }
check(Watch.KeybindPresent({}) == 1, "KeybindPresent returns 1 when the descriptor is a registered group")
check(Watch.KeybindPresent(nil) == 0, "KeybindPresent returns 0 when HasKeybindGroup reports absent")
BETTERUI.Interface = nil

-- Curated auto-mute applies via SetCategoryEnabled when active.
Watch.SetMutedCategories({ "PERF" })
check(cap.mutes["PERF"] == true, "SetMutedCategories mutes the category while active")

-- Idempotent re-Activate re-asserts the provider + mutes (ApplyPreset('watch') clears
-- the provider/categoryDisabled first), and does NOT schedule a second heartbeat.
local latersBefore = #laters
cap.provider = nil          -- simulate provider clear
cap.mutes["PERF"] = false   -- simulate categoryDisabled reset by ApplyPreset
Watch.Activate()
check(cap.provider ~= nil, "re-Activate re-registers the context provider")
check(cap.mutes["PERF"] == true, "re-Activate re-applies mutes after a preset reset")
check(#laters == latersBefore, "re-Activate does not schedule a second heartbeat")

-- Heartbeat: the scheduled callback emits a snapshot and reschedules itself while active.
local linesBefore = #cap.lines
laters[#laters].fn()
check(#cap.lines > linesBefore, "heartbeat callback emits a snapshot")
check(#laters == latersBefore + 1, "heartbeat reschedules itself while active")

-- Deactivate clears the provider + restores mutes + view; the heartbeat then self-stops.
Watch.Deactivate()
check(cap.provider == nil, "Deactivate clears the context provider")
check(cap.mutes["PERF"] == false, "Deactivate restores muted category")
check(Watch.IsActive() == false, "IsActive false after Deactivate")
Watch.Activate()
fakeScene = { name = "gamepad_banking" }
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil,
    "Deactivate clears the previous view before a later Activate")
Watch.Deactivate()
local latersAfterDeact = #laters
laters[#laters].fn() -- run the pending heartbeat tick after Deactivate
check(#laters == latersAfterDeact, "heartbeat does not reschedule after Deactivate")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
