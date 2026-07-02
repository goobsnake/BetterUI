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
BETTERUI.Log = {
    CATEGORY = { LIST = "LIST" },
    IsActive = function() return true end,
    Trace = function(category, message, data)
        table.insert(logEvents, { kind = "Trace", category = category, message = message, data = data })
    end,
    TraceEvent = function(category, event, phase, data)
        table.insert(logEvents, { kind = "TraceEvent", category = category, event = event, phase = phase, data = data })
    end,
    DescribeListSelection = function(_, phase)
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

print("\n=== ListRefreshManager Tests ===\n")

local list = {
    count = 3,
    selectedIndex = 1,
    GetNumItems = function(self) return self.count end,
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

check(#laters == 2, "QueueRefresh schedules a replacement callback when coalescing")
check(laters[1].cancelled == true, "QueueRefresh cancels the stale callback")

local firstQueued = findTraceEvent("queued")
local lastQueued = findLastTraceEvent("queued")
local firstSaved = findTraceEvent("saved")
local lastSaved = findLastTraceEvent("saved")
check(firstQueued and firstQueued.data and firstQueued.data.coalesced == false,
    "first queued refresh is not marked coalesced")
check(lastQueued and lastQueued.data and lastQueued.data.flow == "flow#2",
    "last queued refresh keeps the latest flow")
check(lastQueued and lastQueued.data and lastQueued.data.coalesced == true
    and lastQueued.data.coalescedCount == 1,
    "coalesced queued refresh records the coalesced count")
check(firstSaved and firstSaved.data and firstSaved.data.flow == "flow#1"
    and firstSaved.data.coalesced == false,
    "first saved refresh position keeps the initial flow context")
check(lastSaved and lastSaved.data and lastSaved.data.flow == "flow#2"
    and lastSaved.data.reason == "second"
    and lastSaved.data.coalesced == true
    and lastSaved.data.coalescedCount == 1,
    "coalesced saved refresh position keeps the latest flow context")

laters[2].fn()
check(refreshCount == 1, "only the latest refresh function runs")
local restored = findTraceEvent("restore_end")
check(restored and restored.data and restored.data.flow == "flow#2"
    and restored.data.reason == "second"
    and restored.data.coalesced == true
    and restored.data.coalescedCount == 1,
    "restore_end refresh carries the latest queued flow context")
local executed = findTraceEvent("executed")
check(executed and executed.data and executed.data.flow == "flow#2",
    "executed refresh carries the latest queued flow")
check(executed and executed.data and executed.data.coalesced == true
    and executed.data.coalescedCount == 1,
    "executed refresh carries the coalesced count")

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

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
