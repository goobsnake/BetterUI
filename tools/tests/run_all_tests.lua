--[[
File: tools/tests/run_all_tests.lua
Purpose: Test runner that discovers and executes all test_*.lua files.
         Returns non-zero exit code if any test fails.
Last Modified: 2026-02-03

Usage:
  lua tools/tests/run_all_tests.lua
]]

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local TEST_PATTERN = "test_.*%.lua$"

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get the directory of this script
local function getScriptDir()
    local info = debug.getinfo(1, "S")
    local path = info.source:match("@(.*[/\\])")
    if not path then
        -- Running from tools/tests directory
        path = "./"
    end
    return path
end

-- List files matching pattern in directory
local function listFiles(dir, pattern)
    local files = {}

    -- Try Windows dir command
    local handle = io.popen('dir /b "' .. dir .. '" 2>nul')
    if handle then
        for file in handle:lines() do
            if file:match(pattern) then
                table.insert(files, file)
            end
        end
        handle:close()
    end

    -- If empty, try Unix ls
    if #files == 0 then
        handle = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
        if handle then
            for file in handle:lines() do
                if file:match(pattern) then
                    table.insert(files, file)
                end
            end
            handle:close()
        end
    end

    return files
end

-- ============================================================================
-- MAIN TEST RUNNER
-- ============================================================================

print("")
print(string.rep("=", 60))
print("  BetterUI Test Runner")
print(string.rep("=", 60))
print("")

local scriptDir = getScriptDir()
local testFiles = listFiles(scriptDir, TEST_PATTERN)

-- Filter out this runner script
local filteredFiles = {}
for _, file in ipairs(testFiles) do
    if file ~= "run_all_tests.lua" then
        table.insert(filteredFiles, file)
    end
end
testFiles = filteredFiles

-- Sort for consistent ordering
table.sort(testFiles)

if #testFiles == 0 then
    print("No test files found!")
    os.exit(1)
end

print("Found " .. #testFiles .. " test file(s):")
print("")

-- Run each test file and capture output
local failedTests = {}
local passedCount = 0

for _, file in ipairs(testFiles) do
    io.write("  Running: " .. file .. " ... ")
    io.flush()

    local fullPath = scriptDir .. file
    -- Capture output to prevent interleaving
    local cmd = 'lua "' .. fullPath .. '" 2>&1'
    local handle = io.popen(cmd)
    local output = handle and handle:read("*a") or ""
    local closeResult = handle and handle:close()

    -- Determine success from output and close result
    local success = false
    if type(closeResult) == "boolean" then
        success = closeResult
    elseif type(closeResult) == "number" then
        success = (closeResult == 0)
    else
        -- Check output for failure indicators
        success = not output:match("FAILED") and not output:match("Failed:")
    end

    -- Also check for "All tests passed" as positive indicator
    if output:match("All tests passed") then
        success = true
    end

    if success then
        passedCount = passedCount + 1
        print("PASS")
    else
        table.insert(failedTests, { file = file, output = output })
        print("FAIL")
    end
end

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("")
print(string.rep("=", 60))
print("  FINAL SUMMARY")
print(string.rep("=", 60))
print("")
print(string.format("  Total Test Files: %d", #testFiles))
print(string.format("  Passed:           %d", passedCount))
print(string.format("  Failed:           %d", #failedTests))
print("")

if #failedTests > 0 then
    print("Failed tests:")
    for _, failure in ipairs(failedTests) do
        print("  [X] " .. failure.file)
        -- Show truncated output for debugging
        local lines = {}
        for line in failure.output:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        -- Show last 10 lines of output
        local start = math.max(1, #lines - 10)
        for i = start, #lines do
            print("      " .. lines[i])
        end
    end
    print("")
    os.exit(1)
else
    print("[OK] All test files passed!")
    print("")
    os.exit(0)
end
