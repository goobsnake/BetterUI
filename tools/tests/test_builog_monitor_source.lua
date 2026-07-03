--[[
File: tools/tests/test_builog_monitor_source.lua
Purpose: Source contract for the host builog monitor parser. The monitor reports
         the number of records dropped by InterfaceLog rate limiting, not merely
         the number of drop-summary lines seen in the sample window.
Usage:   lua tools/tests/test_builog_monitor_source.lua
]]

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function writeFile(path, content)
    local handle = io.open(path, "w")
    if not handle then return false end
    handle:write(content)
    handle:close()
    return true
end

local function shellQuote(path)
    return '"' .. tostring(path):gsub('"', '\\"') .. '"'
end

local function commandSucceeded(commandOk, statusCode)
    return commandOk == true or commandOk == 0 or statusCode == 0
end

local function runCommand(command)
    local outputPath = os.tmpname()
    local commandOk, _, statusCode = os.execute(command .. " > " .. shellQuote(outputPath) .. " 2>&1")
    local output = readFile(outputPath) or ""
    os.remove(outputPath)
    return output, commandSucceeded(commandOk, statusCode)
end

local function runDigestFixture(args)
    local fixturePath = os.tmpname()
    local fixture = table.concat({
        "2026-07-02T06:00:00Z |cff0000Lua Error: [BUI] 100 sid=a1b2c3d4 seq=1 INFO STATE | event=session phase=preamble schema=1 preset=inspect|r",
        "stack traceback:",
        "2026-07-02T06:00:02Z |cff0000Lua Error: [BUI] 120 sid=a1b2c3d4 seq=3 INFO TRANSFER | event=bank.transfer phase=confirmed flow=bankTransfer#1 opId=deposit#1|r",
        "2026-07-02T06:00:01Z |cff0000Lua Error: [BUI] 110 sid=a1b2c3d4 seq=2 DEBUG KEYBIND | event=input.keybind phase=fired flow=bankTransfer#1 key=E module=Banking|r",
        "2026-07-02T06:00:03Z |cff0000Lua Error: [BUI] 130 sid=a1b2c3d4 seq=4 DEBUG KEYBIND | event=input.keybind phase=fired flow=stuck#1 key=R module=Inventory|r",
        "2026-07-02T06:00:04Z |cff0000Lua Error: [BUI] 140 sid=a1b2c3d4 seq=5 WARN STATE | event=anomaly phase=detected flow=stuck#1 kind=flow key=stuck#1|r",
        "2026-07-02T06:00:05Z |cff0000Lua Error: [BUI] 150 sid=a1b2c3d4 seq=6 WARN LOG | dropped=3 reason=rate_limit|r",
        "2026-07-02T06:00:06Z |cff0000Lua Error: [BUI] 160 sid=a1b2c3d4 seq=7 INFO SCREENSHOT | event=screenshot phase=saved flow=bankTransfer#1 id=shot#1 requested=true correlation=\"fifo\" filename=Screenshot_20260702_060006.png|r",
        "2026-07-02T06:00:07Z |cff0000Lua Error: [BUI] 170 sid=a1b2c3d4 seq=8 INFO STATE | event=session phase=report scheduled=9 dropped=3 suppressed=0 pending=0 errorCount=1 retainedErrors=1 anomalyDetected=1 anomalyResolved=0 unresolvedFlows=1 screenshots=1|r",
        "2026-07-02T06:00:07Z |cff0000Lua Error: [BUI] 175 sid=a1b2c3d4 seq=10 DEBUG STATE | event=session phase=heartbeat|r",
        "2026-07-02T06:00:08Z Lua Error: real addon failure",
        "",
    }, "\n")
    if not writeFile(fixturePath, fixture) then return "", false end
    local output, ok = runCommand("bash tools/builog-monitor/monitor.sh digest " .. tostring(args or "") .. " " .. shellQuote(fixturePath))
    os.remove(fixturePath)
    return output, ok
end

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== builog monitor source contract ===\n")

local monitor = readFile("tools/builog-monitor/monitor.sh") or ""
local skill = readFile("tools/builog-monitor/SKILL.md") or ""

check(monitor:find("dropped=", 1, true) ~= nil,
    "monitor scans dropped=N fields")
check(monitor:find("sum += a[2]", 1, true) ~= nil,
    "monitor sums dropped=N values")
check(monitor:find("dropped=[0-9][0-9]*", 1, true) ~= nil,
    "monitor uses a POSIX awk-compatible numeric dropped=N matcher")
check(monitor:find("/reason=rate_limit/ || /reason=priority_rate_limit/", 1, true) ~= nil,
    "monitor sums normal and priority rate-limit summaries")
check(monitor:find("reason=priority_rate_limit", 1, true) ~= nil,
    "monitor counts priority rate-limit summaries as dropped records")
check(monitor:find("grep -c 'reason=rate_limit'", 1, true) == nil,
    "monitor no longer counts drop-summary lines as dropped records")
check(monitor:find("rate_limit dropped-records", 1, true) ~= nil,
    "totals label reports dropped records")
check(monitor:find("status: clean", 1, true) ~= nil
    and monitor:find("status: NOT CLEAN", 1, true) ~= nil,
    "monitor emits an explicit clean/not-clean footer based on final totals")
check(monitor:find("0 non-BUI errors + 0 parse violations", 1, true) == nil,
    "monitor no longer prints a static clean sentence after nonzero totals")
check(monitor:find("BUILOG_SCREENSHOT_DIR", 1, true) ~= nil
    and monitor:find("resolve_screenshot_request", 1, true) ~= nil,
    "monitor accepts/derives a screenshot directory")
check(monitor:find("/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/Screenshots", 1, true) ~= nil
    and monitor:find("smb://goobers/elder%20scrolls%20online/live/Screenshots", 1, true) ~= nil,
    "monitor documents the exact local and remote screenshot defaults")
check(skill:find("gio mount 'smb://goobers/elder%20scrolls%20online'", 1, true) ~= nil
    and skill:find("live/Screenshots", 1, true) ~= nil
    and skill:find('BUILOG_SCREENSHOT_DIR="$SCREENSHOTS"', 1, true) ~= nil,
    "skill documents remote screenshot mount discovery alongside interface.log")
check(monitor:find("LOG_REQUEST", 1, true) ~= nil
    and monitor:find("REMOTE_SCREENSHOT_DIR", 1, true) ~= nil,
    "monitor falls back to the remote screenshot folder for remote log requests")
check(monitor:find("/Logs/interface.log", 1, true) ~= nil
    and skill:find("live\\Logs\\interface.log", 1, true) ~= nil
    and skill:find("live/Logs/interface.log", 1, true) ~= nil,
    "monitor and skill document the lowercase interface.log host path")
check(monitor:find(" SCREENSHOT | ", 1, true) ~= nil
    and monitor:find("screenshot markers", 1, true) ~= nil,
    "monitor surfaces BUI screenshot markers")
check(monitor:find("screenshot files (latest 5 by mtime)", 1, true) ~= nil
    and monitor:find("find \"$dir\"", 1, true) ~= nil
    and monitor:find("stat -f", 1, true) ~= nil
    and monitor:find("list_recent_screenshots", 1, true) ~= nil,
    "monitor lists recent screenshot files for marker correlation")
check(monitor:find("run_digest", 1, true) ~= nil
    and monitor:find("digest [--since <ISO>] [--last <n-lines>] [--jsonl]", 1, true) ~= nil
    and monitor:find("session reports:", 1, true) ~= nil
    and monitor:find("droppedRecords", 1, true) ~= nil,
    "monitor implements the digest subcommand, session-report section, and drop totals")
check(monitor:find("iso_ts_re", 1, true) ~= nil
    and monitor:find("ts < since", 1, true) ~= nil
    and monitor:find("line < since", 1, true) == nil,
    "monitor validates digest --since and filters on parsed timestamps")

local digestOutput, digestOk = runDigestFixture("--last 200")
check(digestOk, "monitor digest runs successfully against a fixture log")
check(digestOutput:find("=== builog digest ===", 1, true) ~= nil
    and digestOutput:find("timelines:", 1, true) ~= nil
    and digestOutput:find("bankTransfer#1", 1, true) ~= nil
    and digestOutput:find("outcome=", 1, true) ~= nil
    and digestOutput:find("stuck#1", 1, true) ~= nil
    and digestOutput:find("UNRESOLVED", 1, true) ~= nil,
    "digest groups flow timelines and flags unresolved flows")
local seq2 = digestOutput:find("seq=2 DEBUG KEYBIND", 1, true)
local seq3 = digestOutput:find("seq=3 INFO TRANSFER", 1, true)
check(seq2 ~= nil and seq3 ~= nil and seq2 < seq3,
    "digest orders out-of-order fixture records by sid and numeric seq")
check(digestOutput:find("anomalies:", 1, true) ~= nil
    and digestOutput:find("WARN/ERROR records:", 1, true) ~= nil
    and digestOutput:find("real Lua errors:", 1, true) ~= nil
    and digestOutput:find("real addon failure", 1, true) ~= nil,
    "digest surfaces anomalies, WARN/ERROR records, and real Lua errors")
check(digestOutput:find("drop summaries:", 1, true) ~= nil
    and digestOutput:find("droppedRecords=3", 1, true) ~= nil
    and digestOutput:find("screenshot markers:", 1, true) ~= nil
    and digestOutput:find("session preamble info:", 1, true) ~= nil
    and digestOutput:find("session reports:", 1, true) ~= nil,
    "digest includes drop, screenshot, preamble, and report sections")
check(digestOutput:find("sequence gaps:", 1, true) ~= nil
    and digestOutput:find("sid=a1b2c3d4 missing=9 beforeSeq=10", 1, true) ~= nil,
    "digest reports missing BUI sequence ranges")

local sinceOutput, sinceOk = runDigestFixture("--since 2026-07-02T06:00:05Z --last 200")
check(sinceOk, "monitor digest --since runs successfully against a fixture log")
check(sinceOutput:find("seq=6 WARN LOG", 1, true) ~= nil
    and sinceOutput:find("droppedRecords=3", 1, true) ~= nil
    and sinceOutput:find("seq=2 DEBUG KEYBIND", 1, true) == nil
    and sinceOutput:find("seq=3 INFO TRANSFER", 1, true) == nil,
    "digest --since filters records by parsed ISO timestamp")

local badSinceOutput, badSinceOk = runDigestFixture("--since not-an-iso")
check(not badSinceOk
    and badSinceOutput:find("digest --since must be an ISO-8601 timestamp", 1, true) ~= nil,
    "digest --since rejects malformed timestamps before parsing")

local jsonlOutput, jsonlOk = runDigestFixture("--last 200 --jsonl")
check(jsonlOk, "monitor digest JSONL mode runs successfully against a fixture log")
check(jsonlOutput:find('"event":"input.keybind"', 1, true) ~= nil
    and jsonlOutput:find('"kv":{', 1, true) ~= nil
    and jsonlOutput:find('"flow":"bankTransfer#1"', 1, true) ~= nil
    and jsonlOutput:find('"context":"flow=bankTransfer#1', 1, true) ~= nil,
    "digest JSONL emits one machine-readable object per parsed BUI record")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
