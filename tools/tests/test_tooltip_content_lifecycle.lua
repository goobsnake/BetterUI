--[[
File: tools/tests/test_tooltip_content_lifecycle.lua
Purpose: Regression coverage for the tooltip content-lifecycle clear detector.

  Live builog evidence (vendor.sell, GAMEPAD_LEFT_TOOLTIP) showed a storm of
  "WARN GENERAL event=general_interface.tooltip_content phase=detected
   action=cleared appendedBy=ApplyTooltipEquippedStockLayout clearedBy=ClearLines
   section=equipped-stock ageMs=4-194" records.

  With enhancements OFF, every vendor selection re-lays the tooltip (native
  ClearLines then re-append of the SAME item). Commit 9fd32a5 preserved the
  stock item-data across those clears (preserveStockLayoutState) but the
  content-lifecycle marker was still consumed and flagged, so the routine
  re-layout cycle kept emitting immediate strip-after-append WARNs.

  Fix: TraceTooltipContentCleared is preserve-aware. A preserving clear keeps the
  lifecycle marker and downgrades to a TRACE "preserved" record; genuine
  (non-preserving) immediate clears still emit the WARN.

Usage:
  lua tools/tests/test_tooltip_content_lifecycle.lua
]]

local testsPassed, testsFailed = 0, 0
local function assertEqual(expected, actual, message)
    if expected == actual then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

-- Controllable game clock consumed by the module via GetGameTimeMilliseconds.
local clockMs = 1000
function GetGameTimeMilliseconds() return clockMs end

-- Capturing tracer: MakeTracer is bound at module load, so BETTERUI.Log must
-- exist (with a real MakeTracer) BEFORE the dofile below.
local captured = {}
local function clearCaptured()
    for i = #captured, 1, -1 do captured[i] = nil end
end
local function anyRecord(pred)
    for _, record in ipairs(captured) do
        if pred(record) then return true end
    end
    return false
end

CT_LABEL = 1

local settings = { CIM = { enableTooltipEnhancements = false, tooltipSize = 24 } }

BETTERUI = {
    CIM = {
        SafeExecute = function(_, fn, ...)
            return pcall(fn, ...)
        end,
        SharedItemSupport = {
            CleanupEnhancedTooltip = function() end,
            UpdateTooltipEquippedText = function() end,
        },
    },
    Log = {
        CATEGORY = { GENERAL = "GENERAL", LIFECYCLE = "LIFECYCLE" },
        LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
        IsActive = function() return true end,
        Trace = function() end,
        MakeTracer = function(_)
            return function(event, phase, data, _, level)
                captured[#captured + 1] = { event = event, phase = phase, data = data, level = level }
            end
        end,
    },
}

function BETTERUI.GetSetting(moduleName, key, fallback)
    local moduleSettings = settings[moduleName]
    if moduleSettings and moduleSettings[key] ~= nil then
        return moduleSettings[key]
    end
    return fallback
end

function ZO_PreHook(control, methodName, callback)
    local original = control[methodName]
    control[methodName] = function(self, ...)
        local blocked = callback(self, ...)
        if blocked then return end
        return original(self, ...)
    end
end

function ZO_PostHook(control, methodName, callback)
    local original = control[methodName]
    control[methodName] = function(self, ...)
        local unpackFn = table.unpack or unpack
        local results = { original(self, ...) }
        callback(self, ...)
        return unpackFn(results)
    end
end

-- zo_callLater fires synchronously so the scheduled equipped refresh runs inline.
function zo_callLater(callback, _)
    callback()
    return 1
end

local function newLabel()
    return {
        GetType = function() return CT_LABEL end,
        IsHidden = function() return false end,
        SetFont = function() end,
        GetText = function() return "" end,
        GetNumChildren = function() return 0 end,
        GetChild = function() return nil end,
    }
end

local function newTooltip(children)
    return {
        _children = children,
        IsHidden = function() return false end,
        GetNumChildren = function(self) return #self._children end,
        GetChild = function(self, i) return self._children[i] end,
        LayoutItem = function() end,
        ClearLines = function() end,
    }
end

print("test_tooltip_content_lifecycle")

dofile("Modules/GeneralInterface/Tooltips/Tooltips.lua")

local Tooltips = BETTERUI.GeneralInterface.Tooltips
local helpers = Tooltips._InventoryHookHelpers
local orch = Tooltips.InventoryHookOrchestrator

-- --- Case 1: enhancements OFF -> stock re-layout clear must be preserved -----
print("\nTest: preserving stock clear does not emit an immediate strip-after-append WARN")
settings.CIM.enableTooltipEnhancements = false
local stockState = helpers.CreateInventoryHookState()
local stockTip = newTooltip({ newLabel(), newLabel() })
orch.InstallClearLinesHook(stockTip, stockState, "LEFT")
orch.InstallItemLayoutHooks(stockTip, "LayoutItem", stockState, "LEFT", function(link) return link end)

clockMs = 1000
stockTip:LayoutItem("item:sell")
assertEqual(true, stockTip._betteruiTooltipContentLifecycle ~= nil,
    "Stock layout marks appended tooltip content")
assertEqual("equipped-stock", stockTip._betteruiTooltipContentLifecycle
    and stockTip._betteruiTooltipContentLifecycle.section,
    "Stock layout marks the equipped-stock section")

clearCaptured()
clockMs = 1005 -- native ClearLines 5ms later (well under the 200ms immediate window)
stockTip:ClearLines()

assertEqual(false, anyRecord(function(r) return r.phase == "detected" end),
    "Preserving stock clear emits no immediate strip-after-append WARN")
assertEqual(true, anyRecord(function(r)
        return r.data and r.data.action == "preserved" and r.data.section == "equipped-stock"
    end),
    "Preserving stock clear emits a 'preserved' content record")
assertEqual(true, stockTip._betteruiTooltipContentLifecycle ~= nil,
    "Preserving stock clear keeps the content lifecycle marker for the next re-append")

-- --- Case 2: genuine immediate clear still WARNs (fix stays scoped) ----------
print("\nTest: a genuine (non-preserving) immediate clear still emits the WARN")
settings.CIM.enableTooltipEnhancements = true
local enhState = helpers.CreateInventoryHookState()
local enhTip = newTooltip({ newLabel() })
orch.InstallClearLinesHook(enhTip, enhState, "RIGHT")
orch.InstallItemLayoutHooks(enhTip, "LayoutItem", enhState, "RIGHT", function(link) return link end)

clockMs = 2000
enhTip:LayoutItem("item:enh")
assertEqual(true, enhTip._betteruiTooltipContentLifecycle ~= nil,
    "Enhanced layout marks appended tooltip content")

clearCaptured()
clockMs = 2005
-- A real non-preserving clear is a non-item layout/cleanup path. Item layouts,
-- stock or enhanced, intentionally preserve displayed-item metadata across
-- native ClearLines so repeated layout refreshes do not look like content loss.
enhState.pendingItemLink = nil
enhTip._betterui_itemLink = nil
enhTip:ClearLines()

assertEqual(true, anyRecord(function(r) return r.phase == "detected" end),
    "Enhanced (non-preserving) immediate clear still emits the strip-after-append WARN")
assertEqual(nil, enhTip._betteruiTooltipContentLifecycle,
    "Genuine content clear consumes the lifecycle marker")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
