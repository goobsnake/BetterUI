--[[
File: tools/tests/test_controlutils.lua
Purpose: Unit tests for ControlUtils.FindControl — self-describing miss/resolved logs.
Usage:   lua tools/tests/test_controlutils.lua
]]

BETTERUI = { CIM = {} }

-- Names stub (resolves a {name=..} mock control; userdata path covered by test_names).
BETTERUI.CIM.Names = {
    Control = function(c, fb)
        if type(c) == "table" and c.name then return c.name end
        return fb or "<unnamed>"
    end,
}

-- DebugInfo stub: returns a fixed src + records the extraSkip patterns it was handed.
local capturedExtraSkip = nil
BETTERUI.CIM.DebugInfo = {
    CaptureCallerFrame = function(_level, extraSkip)
        capturedExtraSkip = extraSkip
        return "Modules/CIM/Bank.lua:21:setupFooter"
    end,
}

-- Log stub capturing Warn/Trace.
local cap = { warns = {}, traces = {} }
BETTERUI.Log = {
    CATEGORY = { CONTROL = "CONTROL" },
    IsActive = function() return true end,
    Warn = function(cat, msg, data) cap.warns[#cap.warns + 1] = { cat = cat, msg = msg, data = data } end,
    Trace = function(cat, msg, data) cap.traces[#cap.traces + 1] = { cat = cat, msg = msg, data = data } end,
}

dofile("Modules/CIM/Core/Window/ControlUtils.lua")
local CU = BETTERUI.ControlUtils

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

local function mockControl(name, children, parent)
    local c = { name = name, _children = children or {}, _parent = parent }
    function c:GetName() return self.name end
    function c:GetNamedChild(n) return self._children[n] end
    function c:GetParent() return self._parent end
    return c
end

print("\n=== ControlUtils Tests ===\n")

-- Resolve via direct child -> self-describing TRACE.
local childCtrl = mockControl("BUI_ChildList")
local parent = mockControl("BUI_Bank", { ChildList = childCtrl })
local got = CU.FindControl(parent, "ChildList", "BankSetup")
check(got == childCtrl, "FindControl resolves a direct child")
local tr = cap.traces[#cap.traces]
check(tr.data.via == "child" and tr.data.control == "ChildList", "resolved trace records via=child + control name")
check(tr.data.parent == "BUI_Bank", "resolved trace names the parent")
check(tr.data.caller == "BankSetup", "resolved trace carries the caller label")

-- Cache hit is silent.
local tracesBefore = #cap.traces
CU.FindControl(parent, "ChildList", "BankSetup")
check(#cap.traces == tracesBefore, "cache hit does not re-log")

-- Resolve via ancestor-global name.
_G["BUI_BankInfoBar"] = mockControl("BUI_BankInfoBar")
local bar = CU.FindControl(parent, "InfoBar", "BankSetup")
check(bar == _G["BUI_BankInfoBar"], "FindControl resolves via ancestor-global name")
check(cap.traces[#cap.traces].data.via == "ancestorGlobal", "resolved trace records via=ancestorGlobal")

-- Miss -> self-describing WARN naming control + parent + caller + src.
CU.FindControl(parent, "Missing", "FooterSetup")
check(#cap.warns == 1, "miss warns once")
local w = cap.warns[1]
check(w.cat == "CONTROL", "miss is a CONTROL-category warn")
check(w.msg:find("Missing", 1, true) ~= nil and w.msg:find("BUI_Bank", 1, true) ~= nil,
    "miss message names the control + parent (survives payload-off)")
check(w.data.control == "Missing" and w.data.parent == "BUI_Bank", "miss payload names control + parent")
check(w.data.caller == "FooterSetup", "miss payload carries the caller label")
check(w.data.src == "Modules/CIM/Bank.lua:21:setupFooter", "miss payload carries the captured src")
check(type(capturedExtraSkip) == "table" and tostring(capturedExtraSkip[1]):find("ControlUtils") ~= nil,
    "CaptureCallerFrame is given a ControlUtils extra-skip pattern")

-- Miss dedupe: same key only warns once per cache generation.
CU.FindControl(parent, "Missing", "FooterSetup")
check(#cap.warns == 1, "repeated miss does not re-warn (deduped per key)")

-- Optional miss -> nil, no WARN.
local warnsBeforeOptional = #cap.warns
local optional = CU.FindOptionalControl(parent, "OptionalAdornment", "SkinSetup")
check(optional == nil, "FindOptionalControl returns nil for a missing optional control")
check(#cap.warns == warnsBeforeOptional, "FindOptionalControl miss does not warn")

-- InvalidateControlCache clears the dedupe so a new layout re-reports.
CU.InvalidateControlCache()
CU.FindControl(parent, "Missing", "FooterSetup")
check(#cap.warns == 2, "InvalidateControlCache lets a miss re-warn")

-- nil parent miss still names the control.
CU.FindControl(nil, "Orphan", "X")
check(cap.warns[#cap.warns].data.control == "Orphan" and cap.warns[#cap.warns].data.parent == "<no-parent>",
    "nil-parent miss names the control + <no-parent>")

-- Direct global fallback (_G[name]) path resolves + reports via=global.
_G["StandaloneCtrl"] = mockControl("StandaloneCtrl")
local sa = CU.FindControl(parent, "StandaloneCtrl", "X")
check(sa == _G["StandaloneCtrl"], "FindControl resolves via direct global fallback")
check(cap.traces[#cap.traces].data.via == "global", "resolved trace records via=global")

-- caller=nil normalizes to <unspecified> so unlabeled calls are still self-describing.
CU.FindControl(parent, "MissingNoCaller")
check(cap.warns[#cap.warns].data.caller == "<unspecified>", "miss normalizes nil caller to <unspecified>")

-- A partial Log table (no Warn) must not raise from the miss path.
local realLog = BETTERUI.Log
BETTERUI.Log = { CATEGORY = { CONTROL = "CONTROL" }, IsActive = function() return false end }
check(pcall(CU.FindControl, parent, "MissingPartialLog", "X"), "miss does not raise when Log.Warn is absent")
BETTERUI.Log = realLog

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
