--[[
File: tools/tests/test_log_parse_contract.lua
Purpose: Golden parse-fixture test -- locks the on-disk `[BUI]` line format to the host
         tail/parse contract in docs/reference/logging-host-tail-parse.md. The live log is
         the ONLY handoff, so if the emitted line shape drifts from the documented ERE a
         host/AI tailer silently loses records -- this test fails first. Loads production
         Log.lua + Names.lua via dofile so it tracks the live format, never a copy.
Usage:   lua tools/tests/test_log_parse_contract.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS (mirror test_log.lua -- capture the raw line the file sink emits)
-- ============================================================================
local fileLines = {}
local ilEnabled = true

BETTERUI = { CIM = {} }
BETTERUI.CIM.InterfaceLog = {
    IsEnabled = function() return ilEnabled end,
    WriteRaw = function(line) fileLines[#fileLines + 1] = line; return true end,
    SetEnabled = function(value)
        ilEnabled = value and true or false
        if BETTERUI.Log and BETTERUI.Log.InvalidateActive then BETTERUI.Log.InvalidateActive() end
    end,
    SetBudget = function() end,
    GetStats = function() return { dropped = 0 } end,
}

function GetGameTimeMilliseconds() return 100 end
function GetTimeStamp() return 305419896 end -- stable sid input (-> hex sid)
function zo_strformat(_, s) return s end     -- Names.Item dependency (unused here)

dofile("Modules/CIM/Core/Diagnostics/Log.lua")
dofile("Modules/CIM/Core/Diagnostics/Names.lua")
local Log = BETTERUI.Log
local Names = BETTERUI.CIM.Names

-- ============================================================================
-- HOST PARSE CONTRACT -- the Lua-pattern equivalent of the documented POSIX ERE:
--   \[BUI\] ([0-9]+) sid=([0-9a-f]+) seq=([0-9]+) ([A-Z]+) ([A-Z]+) \| (.*)$
-- (docs/reference/logging-host-tail-parse.md). Keep these two in lockstep.
-- ============================================================================
local LINE_PAT = "^%[BUI%] (%d+) sid=([0-9a-f]+) seq=(%d+) (%u+) (%u+) | (.*)$"

local function parse(line)
    local ms, sid, seq, level, cat, event = (line or ""):match(LINE_PAT)
    if not ms then return nil end
    return { ms = ms, sid = sid, seq = tonumber(seq), level = level, cat = cat, event = event }
end

-- ============================================================================
-- HARNESS
-- ============================================================================
local tests_passed, tests_failed = 0, 0
local function check(cond, message)
    if cond then tests_passed = tests_passed + 1; print("  [OK] " .. message)
    else tests_failed = tests_failed + 1; print("  [X] " .. message) end
end

print("\n=== Log parse-contract (golden) Tests ===\n")

-- Route every level to the file sink so each can be captured + parsed.
Log.ApplyPreset("trace")

-- 1. A normal record parses into all six fields.
fileLines = {}
Log.Info(Log.CATEGORY.LIST, "refresh")
local p = parse(fileLines[1])
check(p ~= nil, "normal line matches the host ERE")
check(p and p.level == "INFO" and p.cat == "LIST", "level + category extracted")
check(p and p.event == "refresh", "event is the message after ' | '")
check(p and tonumber(p.ms) == 100 and p.sid:match("^%x+$") ~= nil, "gameMs numeric, sid hex")

-- 2. record-style payload renders its VALUES inside the event field.
fileLines = {}
Log.Info(Log.CATEGORY.LIST, "refresh", { count = 7, name = "bag" })
p = parse(fileLines[1])
check(p ~= nil and p.event:find("count=7", 1, true) ~= nil, "payload k=v rides in the event field")

-- 3. watch-style context suffix stays parseable (it is part of the greedy event tail).
fileLines = {}
Log.SetContextProvider(function() return 'scene=hud lastAction="open bag"' end)
Log.Info(Log.CATEGORY.LIST, "refresh")
Log.SetContextProvider(nil)
p = parse(fileLines[1])
check(p ~= nil, "watch line with a context suffix still matches")
check(p and p.event:find("scene=hud", 1, true) ~= nil
    and p.event:find('lastAction="open bag"', 1, true) ~= nil,
    "scene + quoted lastAction survive in the event")

-- 4. seq is monotonic across records (the host orders by seq, not the 1s-resolution ts).
fileLines = {}
Log.Info(Log.CATEGORY.GENERAL, "a")
Log.Info(Log.CATEGORY.GENERAL, "b")
local p1, p2 = parse(fileLines[1]), parse(fileLines[2])
check(p1 and p2 and p2.seq == p1.seq + 1, "seq increments by one per record")

-- 5. Meta-line fixture (InterfaceLog.FormatLine shape): startup/header lines carry an
--    explicit INFO LOG level/category so a strict tailer keeps them instead of dropping.
p = parse("[BUI] 100 sid=12345678 seq=42 INFO LOG | watch session started -- schema=...")
check(p ~= nil and p.level == "INFO" and p.cat == "LOG", "meta-line parses as INFO LOG")

-- 6. drop-summary fixture: the documented coverage-gap marker parses as WARN LOG.
p = parse("[BUI] 100 sid=12345678 seq=99 WARN LOG | dropped=12 reason=rate_limit")
check(p ~= nil and p.level == "WARN" and p.event:find("dropped=12", 1, true) ~= nil,
    "drop-summary marker parses (WARN LOG dropped=n)")

-- 7. Engine-wrapped on-disk form: apply the host strip recipe (anchor on [BUI], drop |r).
local wrapped = '2026-06-20T12:00:00.000Z |cff0000Lua Error: '
    .. '[BUI] 100 sid=12345678 seq=3 INFO STATE | snapshot scene=hud|r'
local inner = (wrapped:match("(%[BUI%].*)") or ""):gsub("|r%s*$", "")
p = parse(inner)
check(p ~= nil and p.level == "INFO" and p.cat == "STATE", "engine-wrapped line parses after the strip recipe")
check(p and p.event == "snapshot scene=hud", "trailing |r stripped from the event")

-- 8. FlattenText neutralizes the field separator: no bare '|' (nor tab/newline) in a value.
local flat = Names.FlattenText("|cFF0000Gold|r Bar | x\ttab\nline")
check(flat:find("|", 1, true) == nil, "FlattenText strips/neutralizes every pipe")
check(flat:find("[\t\n]") == nil, "FlattenText collapses tabs/newlines")

-- 9. Summarize neutralizes '|' in string payload VALUES so a value can't forge a field
--    boundary, and the neutralization carries all the way into a rendered line's event.
check(Log.Summarize("a | b | c"):find("|", 1, true) == nil, "Summarize neutralizes `|` in string values")
fileLines = {}
Log.Info(Log.CATEGORY.LIST, "x", { url = "a|b" })
p = parse(fileLines[1])
check(p ~= nil and select(2, p.event:gsub("|", "")) == 0, "no bare `|` survives in a rendered payload value")

-- ============================================================================
-- SUMMARY
-- ============================================================================
print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
if tests_failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
