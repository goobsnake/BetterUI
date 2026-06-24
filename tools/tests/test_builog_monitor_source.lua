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

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== builog monitor source contract ===\n")

local monitor = readFile("tools/builog-monitor/monitor.sh") or ""

check(monitor:find("dropped=", 1, true) ~= nil,
    "monitor scans dropped=N fields")
check(monitor:find("sum += a[2]", 1, true) ~= nil,
    "monitor sums dropped=N values")
check(monitor:find("dropped=[0-9][0-9]*", 1, true) ~= nil,
    "monitor uses a POSIX awk-compatible numeric dropped=N matcher")
check(monitor:find("grep -c 'reason=rate_limit'", 1, true) == nil,
    "monitor no longer counts drop-summary lines as dropped records")
check(monitor:find("rate_limit dropped-records", 1, true) ~= nil,
    "totals label reports dropped records")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
