--[[
File: tools/tests/test_selection_highlight.lua
Purpose: Regression tests for selection highlight diagnostics.
Usage:
  lua tools/tests/test_selection_highlight.lua
]]

local passed = 0
local failed = 0
local traceEvents = {}

local function assert_equal(expected, actual, label)
    if expected == actual then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_not_nil(value, label)
    if value ~= nil then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. label .. " -- got nil")
    end
end

BETTERUI = {
    CIM = {},
    Log = {
        CATEGORY = { LIST = "LIST" },
        LEVEL = { TRACE = "TRACE" },
        TraceEvent = function(category, event, phase, data, level)
            traceEvents[#traceEvents + 1] = {
                category = category,
                event = event,
                phase = phase,
                data = data,
                level = level,
            }
        end,
        DescribeItem = function(data)
            local source = data and data.dataSource or data
            return source and (source.name or source.uniqueId) or nil
        end,
    },
}

dofile("Modules/CIM/UI/SelectionHighlight.lua")

local function CreateRowControl()
    local bar = {
        hidden = true,
        SetHidden = function(self, hidden)
            self.hidden = hidden
        end,
        IsHidden = function(self)
            return self.hidden
        end,
    }
    return {
        bar = bar,
        GetName = function()
            return "QuestRow1"
        end,
        GetNamedChild = function(_, name)
            if name == "SelectionBar" then
                return bar
            end
            return nil
        end,
    }
end

local data = {
    uniqueId = "quest:42:1",
    dataSource = {
        name = "Quest Relic",
        questIndex = 42,
    },
}

local control = CreateRowControl()
BETTERUI.CIM.SelectionHighlight.Setup(control, true, data)
local event = traceEvents[#traceEvents]
assert_not_nil(event, "selection highlight emits an applied diagnostic")
assert_equal("inventory.row.selection_highlight", event.event, "selection highlight diagnostic uses canonical event name")
assert_equal("applied", event.phase, "selection highlight diagnostic records applied phase")
assert_equal(true, event.data.selected, "selection highlight diagnostic records selected state")
assert_equal(false, event.data.barHidden, "selection highlight diagnostic records visible bar state")
assert_equal(true, event.data.quest, "selection highlight diagnostic identifies quest rows")
assert_equal("Quest Relic", event.data.item, "selection highlight diagnostic carries row identity")

BETTERUI.CIM.SelectionHighlight.Setup(control, false, data)
event = traceEvents[#traceEvents]
assert_equal(false, event.data.selected, "selection highlight diagnostic records deselected state")
assert_equal(true, event.data.barHidden, "selection highlight diagnostic records hidden bar state")

print(string.format("test_selection_highlight.lua: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
