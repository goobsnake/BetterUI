--[[
File: tools/tests/test_update_betterui_source.lua
Purpose: Source contract for incremental BetterUI deployment on Linux.
Usage:   lua tools/tests/test_update_betterui_source.lua
]]

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local passed, failed = 0, 0
local function check(condition, message)
    if condition then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
    end
end

print("\n=== BetterUI updater source contract ===\n")

local common = readFile("tools/Update_BetterUI_Common.ps1") or ""
local live = readFile("tools/Update_BetterUI.ps1") or ""
local pts = readFile("tools/Update_BetterUI_PTS.ps1") or ""
local docs = readFile("tools/README.md") or ""

check(common:find("Get%-Command rsync") ~= nil,
    "Linux deployment requires the rsync executable")
check(common:find("%-%-delete%-delay") ~= nil
    and common:find("%-%-delete%-excluded") ~= nil,
    "rsync removes only stale destination paths after transfer")
check(common:find("%-%-delay%-updates") ~= nil
    and common:find("%-%-omit%-dir%-times") ~= nil
    and common:find("%-%-modify%-window=1") ~= nil,
    "rsync uses CIFS-friendly incremental update flags")
check(common:find("& rm %-rf", 1) == nil,
    "Linux deployment no longer removes the target wholesale with rm -rf")
check(common:find("& cp %-%-", 1) == nil
    and common:find("& mkdir %-p", 1) == nil,
    "Windows fallback avoids unreachable native-command branches")
check(common:find("@rsyncArgs", 1, true) ~= nil,
    "rsync receives an argument array so paths with spaces stay intact")
check(common:find("function Get-BetterUIRelativePath", 1, true) ~= nil
    and common:find("[System.IO.Path]::GetRelativePath", 1, true) == nil,
    "relative-path handling remains compatible with Windows PowerShell 5.1")
check(common:find("Refusing to synchronize a filesystem root", 1, true) ~= nil
    and common:find("Source and target directories must be different", 1, true) ~= nil
    and common:find("symbolic-link targets", 1, true) ~= nil,
    "destructive synchronization validates the target boundary")
check(common:find("[switch]$DryRun", 1, true) ~= nil
    and common:find("--dry-run", 1, true) ~= nil,
    "shared deployment supports a non-mutating dry run")
check(live:find("[switch]$DryRun", 1, true) ~= nil
    and live:find("-DryRun:$DryRun", 1, true) ~= nil
    and pts:find("[switch]$DryRun", 1, true) ~= nil
    and pts:find("-DryRun:$DryRun", 1, true) ~= nil,
    "Live and PTS wrappers propagate dry-run mode")
check(docs:lower():find("incremental", 1, true) ~= nil
    and docs:find("-DryRun", 1, true) ~= nil,
    "deployment documentation describes incremental sync and dry-run usage")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
