--[[
File: tools/tests/test_list_refresh_manager.lua
Purpose: Unit coverage for ListRefreshManager refresh coalescing trace context.
Usage:   lua tools/tests/test_list_refresh_manager.lua
]]

BETTERUI = {
    CIM = {
        CONST = { TIMING = { CATEGORY_REFRESH_COALESCE_MS = 10 } },
        Lists = {},
    },
}

ZO_Object = {}
function ZO_Object:Subclass()
    local cls = {}
    cls.__index = cls
    setmetatable(cls, { __index = self })
    return cls
end
function ZO_Object.New(cls)
    return setmetatable({}, cls)
end

local laters = {}
function zo_callLater(fn, ms)
    laters[#laters + 1] = { fn = fn, ms = ms, cancelled = false }
    return #laters
end
function zo_removeCallLater(id)
    if laters[id] then laters[id].cancelled = true end
end

local logEvents = {}
local debugLoggingEnabled = true
local selectionDescriptionProbes = 0
BETTERUI.Log = {
    CATEGORY = { LIST = "LIST" },
    LEVEL = { DEBUG = "DEBUG" },
    EnabledFor = function(level, category)
        return debugLoggingEnabled and level == "DEBUG" and category == "LIST"
    end,
    IsActive = function() return true end,
    Trace = function(category, message, data)
        table.insert(logEvents, { kind = "Trace", category = category, message = message, data = data })
    end,
    TraceEvent = function(category, event, phase, data)
        table.insert(logEvents, { kind = "TraceEvent", category = category, event = event, phase = phase, data = data })
    end,
    DescribeListSelection = function(_, phase)
        selectionDescriptionProbes = selectionDescriptionProbes + 1
        return { phase = phase, selectedIndex = 1 }
    end,
}

dofile("Modules/CIM/Lists/ListRefreshManager.lua")

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

local function findTraceEvent(phase)
    for _, entry in ipairs(logEvents) do
        if entry.kind == "TraceEvent" and entry.event == "list.refresh" and entry.phase == phase then
            return entry
        end
    end
    return nil
end

local function findLastTraceEvent(phase)
    local found = nil
    for _, entry in ipairs(logEvents) do
        if entry.kind == "TraceEvent" and entry.event == "list.refresh" and entry.phase == phase then
            found = entry
        end
    end
    return found
end

local function countTraceEvents(phase)
    local count = 0
    for _, entry in ipairs(logEvents) do
        if entry.kind == "TraceEvent" and entry.event == "list.refresh" and entry.phase == phase then
            count = count + 1
        end
    end
    return count
end

print("\n=== ListRefreshManager Tests ===\n")

local numItemsProbes = 0
local list = {
    count = 3,
    selectedIndex = 1,
    GetNumItems = function(self)
        numItemsProbes = numItemsProbes + 1
        return self.count
    end,
    GetSelectedIndex = function(self) return self.selectedIndex end,
    GetSelectedData = function() return { uniqueId = "item-1" } end,
    GetDataForDataIndex = function(_, index) return { uniqueId = index == 1 and "item-1" or "other" } end,
    SetSelectedIndex = function(self, index) self.selectedIndex = index end,
}

local manager = BETTERUI.CIM.Lists.ListRefreshManager:New({ coalesceDelay = 25 })
local refreshCount = 0
manager:QueueRefresh(list, function()
    refreshCount = refreshCount + 1
    list.count = 4
end, true, { flow = "flow#1", source = "test", reason = "first" })
manager:QueueRefresh(list, function()
    refreshCount = refreshCount + 1
    list.count = 5
end, true, { flow = "flow#2", source = "test", reason = "second" })
manager:QueueRefresh(list, function()
    refreshCount = refreshCount + 1
    list.count = 6
end, true, { flow = "flow#3", source = "test", reason = "third" })

check(#laters == 3, "QueueRefresh schedules replacement callbacks for multiple coalesced calls")
check(laters[1].cancelled == true and laters[2].cancelled == true,
    "QueueRefresh cancels both stale callbacks")

local firstQueued = findTraceEvent("queued")
local lastQueued = findLastTraceEvent("queued")
local firstSaved = findTraceEvent("saved")
local lastSaved = findLastTraceEvent("saved")
check(firstQueued and firstQueued.data and firstQueued.data.coalesced == false,
    "first queued refresh is not marked coalesced")
check(lastQueued and lastQueued.data and lastQueued.data.flow == "flow#3",
    "last queued refresh keeps the latest flow")
check(lastQueued and lastQueued.data and lastQueued.data.coalesced == true
    and lastQueued.data.coalescedCount == 2,
    "coalesced queued refresh records the coalesced count")
check(firstSaved and firstSaved.data and firstSaved.data.flow == "flow#1"
    and firstSaved.data.coalesced == false,
    "first saved refresh position keeps the initial flow context")
check(lastSaved and lastSaved.data and lastSaved.data.flow == "flow#3"
    and lastSaved.data.reason == "third"
    and lastSaved.data.coalesced == true
    and lastSaved.data.coalescedCount == 2,
    "coalesced saved refresh position keeps the latest flow context")

laters[3].fn()
check(refreshCount == 1, "only the latest refresh function runs")
local restored = findTraceEvent("restore_end")
check(restored and restored.data and restored.data.flow == "flow#3"
    and restored.data.reason == "third"
    and restored.data.coalesced == true
    and restored.data.coalescedCount == 2,
    "restore_end refresh carries the latest queued flow context")
local executed = findTraceEvent("executed")
check(executed and executed.data and executed.data.flow == "flow#3",
    "executed refresh carries the latest queued flow")
check(executed and executed.data and executed.data.coalesced == true
    and executed.data.coalescedCount == 2,
    "executed refresh carries the coalesced count")
check(countTraceEvents("queued") == 3 and countTraceEvents("saved") == 3
    and countTraceEvents("restore_end") == 1 and countTraceEvents("executed") == 1,
    "LIST/DEBUG logging retains canonical queued/saved/restore_end/executed events")
check(numItemsProbes == 7, "LIST/DEBUG logging performs expected item-count probes")
check(selectionDescriptionProbes == 8,
    "LIST/DEBUG logging performs expected selection-description probes")

laters = {}
logEvents = {}
list.count = 3
list.selectedIndex = 1
manager = BETTERUI.CIM.Lists.ListRefreshManager:New({ coalesceDelay = 25 })
refreshCount = 0
manager:QueueRefresh(list, function()
    refreshCount = refreshCount + 1
end, true, { flow = "flow#preserved", source = "test", reason = "first", token = "token#1" })
manager:QueueRefresh(list, function()
    refreshCount = refreshCount + 1
end, true)
laters[2].fn()
lastQueued = findLastTraceEvent("queued")
executed = findTraceEvent("executed")
check(refreshCount == 1, "coalesced refresh without trace context still runs once")
check(lastQueued and lastQueued.data and lastQueued.data.flow == "flow#preserved"
    and lastQueued.data.source == "test"
    and lastQueued.data.reason == "first"
    and lastQueued.data.token == "token#1",
    "flowless coalesced queue preserves pending queued trace context")
check(executed and executed.data and executed.data.flow == "flow#preserved"
    and executed.data.source == "test"
    and executed.data.reason == "first"
    and executed.data.token == "token#1",
    "flowless coalesced queue preserves pending executed trace context")
check(executed and executed.data and executed.data.coalesced == true
    and executed.data.coalescedCount == 1,
    "flow-preserving coalesced refresh still records coalescing")

laters = {}
logEvents = {}
list.count = 3
list.selectedIndex = 1
numItemsProbes = 0
selectionDescriptionProbes = 0
debugLoggingEnabled = false
manager = BETTERUI.CIM.Lists.ListRefreshManager:New({ coalesceDelay = 25 })
refreshCount = 0
for i = 1, 3 do
    manager:QueueRefresh(list, function()
        refreshCount = refreshCount + 1
        list.count = 4
    end, true, { flow = "flow#disabled-" .. tostring(i), source = "test", reason = "coalesced" })
end
check(numItemsProbes == 0, "logging-disabled queued calls avoid item-count probes")
check(selectionDescriptionProbes == 0,
    "logging-disabled queued calls avoid selection-description probes")
laters[3].fn()
check(refreshCount == 1, "logging-disabled coalesced refresh still executes once")
check(numItemsProbes == 2,
    "logging-disabled execution retains only behavioral restore item-count probes")
check(selectionDescriptionProbes == 0,
    "logging-disabled execution avoids all selection-description probes")

laters = {}
list.count = 3
list.selectedIndex = 1
numItemsProbes = 0
BETTERUI.Log.EnabledFor = nil
manager = BETTERUI.CIM.Lists.ListRefreshManager:New({ coalesceDelay = 25 })
refreshCount = 0
manager:QueueRefresh(list, function() refreshCount = refreshCount + 1 end, true)
laters[1].fn()
check(refreshCount == 1, "log stubs without EnabledFor remain behaviorally compatible")
check(numItemsProbes == 2,
    "log stubs without EnabledFor retain only behavioral restore item-count probes")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
