--[[
File: tools/tests/test_writs_trace_source.lua
Purpose: Source contract for Writs state trace envelopes.
]]

local function read_file(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(string.format("failed to open %s: %s", path, tostring(err)))
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

local function count_occurrences(haystack, needle)
    local count = 0
    local start = 1
    while true do
        local match_start, match_end = haystack:find(needle, start, true)
        if not match_start then
            return count
        end
        count = count + 1
        start = match_end + 1
    end
end

local function assert_count(haystack, needle, expected, label)
    local actual = count_occurrences(haystack, needle)
    if actual ~= expected then
        error(string.format("%s\nExpected %d occurrence(s), found %d: %s", label, expected, actual, needle))
    end
end

local function block_between(content, start_marker, end_marker, label)
    local start_pos = content:find(start_marker, 1, true)
    if not start_pos then
        error(label .. "\nMissing start: " .. start_marker)
    end
    local end_pos = content:find(end_marker, start_pos + #start_marker, true)
    if not end_pos then
        error(label .. "\nMissing end: " .. end_marker)
    end
    return content:sub(start_pos, end_pos - 1)
end

print("test_writs_trace_source")

local core = read_file("Modules/Writs/Core/Writ.lua")
local module = read_file("Modules/Writs/Module.lua")

assert_contains(core, "function Writs.TraceWritState(trigger, craftType, data)",
    "Writ core exposes a state-envelope helper")
assert_contains(core, "TraceWrit(\"writs.state\", \"changed\", data, BETTERUI.Log and BETTERUI.Log.CATEGORY.STATE)",
    "Writ core state envelope uses STATE/writs.state changed")
assert_contains(core, "data.craftType = data.craftType or craftType",
    "Writ core state payload carries craftType")
assert_contains(core, "data.activeWritCount = data.activeWritCount or CountWritSnapshotEntries()",
    "Writ core state payload carries activeWritCount")
assert_contains(core, "data.panelVisible = IsWritPanelVisible()",
    "Writ core state payload carries panelVisible")
assert_contains(core, "data.completedCount = data.completedCount or CountCompletedWritObjectives()",
    "Writ core state payload carries completedCount")
assert_contains(core, "data.trigger = data.trigger or trigger",
    "Writ core state payload carries trigger")

local refresh = block_between(core,
    "function Writs.RefreshActiveWrits(context)",
    "--- Shows writ progress for the current crafting station.",
    "RefreshActiveWrits block")
assert_count(refresh, "TraceWritState(\"refresh_active_writs\"", 2,
    "RefreshActiveWrits emits state on success and error paths")

local show = block_between(core,
    "function Writs.ShowForCraftType(writType, context)",
    "--- Hides the writ panel.",
    "ShowForCraftType block")
assert_contains(show, "local normalizedCraftId = tonumber(context.craftId) or tonumber(writType) or writType",
    "ShowForCraftType coerces known craft type before RefreshActiveWrits")
assert_contains(show, "context.craftId = normalizedCraftId",
    "ShowForCraftType stores the normalized craft type before RefreshActiveWrits")
assert_contains(show, "writType = normalizedCraftId",
    "ShowForCraftType uses the normalized craft type for lookup and state payloads")
assert_contains(show, "local writEntry = Writs.List[writType]",
    "ShowForCraftType looks up active writs with the normalized craft type")
assert_count(show, "TraceWritState(\"show_for_craft_type\", writType", 4,
    "ShowForCraftType state payloads use the normalized craft type")
assert_count(show, "TraceWritState(\"show_for_craft_type\"", 4,
    "ShowForCraftType emits state for refresh error, no-active, render error, and shown paths")
assert_contains(show, "Writs.HidePanel()\n\t\tTraceWrit(\"writ.panel\", \"show_error\"",
    "ShowForCraftType hides stale panel UI before render-error tracing")
assert_contains(show, "panelVisible = false,\n\t\t\tresult = \"render_error\"",
    "ShowForCraftType render-error state reports the panel hidden")

local objectives = block_between(core,
    "function Writs.GetFormattedObjectives(questId)",
    "local function BuildActiveWritLookup()",
    "GetFormattedObjectives block")
assert_not_contains(objectives, "writs.state",
    "Writ state envelope must not be emitted per objective line")

assert_contains(module, "local function TraceWritState(trigger, craftType, data)",
    "Writ module exposes a state-envelope helper for event handlers")
assert_contains(module, "return Writs.TraceWritState(trigger, craftType, data)",
    "Writ module state envelope delegates to the shared Writ core helper")
assert_contains(module, "TraceWritState(\"station_closed\"",
    "OnCloseCraftStation emits station_closed state")
assert_contains(module, "TraceWritState(\"craft_completed_immediate\"",
    "OnCraftItem emits craft_completed_immediate state")

local close_station = block_between(module,
    "local function OnCloseCraftStation(_)",
    "local function ScheduleCraftCompletionRefresh(id, craftId)",
    "OnCloseCraftStation block")
assert_contains(close_station, "local previousCraftingType = currentCraftingType",
    "OnCloseCraftStation preserves craftType before clearing state")
assert_contains(close_station, "panelVisible = false",
    "OnCloseCraftStation marks the panel hidden")

local craft_item = block_between(module,
    "local function OnCraftItem(_, craftId)",
    "local function OnQuestJournalChanged(eventCode, questIndex)",
    "OnCraftItem block")
assert_contains(craft_item, "SafeExecuteWrits(\"Writs:OnCraftItem\", BETTERUI.Writs.ShowForCraftType",
    "OnCraftItem still performs the immediate refresh")
assert_contains(craft_item, "TraceWritState(\"craft_completed_immediate\", id",
    "OnCraftItem emits state after the immediate refresh")

print("ok")
