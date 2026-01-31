--[[
File: tools/tests/run_all_tests.lua
Purpose: Test runner that discovers and executes all test_*.lua files.
         Returns non-zero exit code if any test fails.

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
    local path = info.source:match("@(.*/)")
    if not path then
        -- Windows path
        path = info.source:match("@(.*\\)")
    end
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

print("\n" .. string.rep("=", 60))
print("  BetterUI Test Runner")
print(string.rep("=", 60) .. "\n")

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

print("Found " .. #testFiles .. " test file(s):\n")
for _, file in ipairs(testFiles) do
    print("  - " .. file)
end
print("")

-- Run each test file
local failedTests = {}
local passedCount = 0

for _, file in ipairs(testFiles) do
    print(string.rep("-", 60))
    print("Running: " .. file)
    print(string.rep("-", 60))

    local fullPath = scriptDir .. file
    local cmd = 'lua "' .. fullPath .. '"'
    local exitCode = os.execute(cmd)

    -- Handle different Lua versions
    local success = false
    if type(exitCode) == "number" then
        success = (exitCode == 0)
    elseif type(exitCode) == "boolean" then
        success = exitCode
    else
        -- Lua 5.1 on Windows returns nil on failure
        success = (exitCode ~= nil)
    end

    if success then
        passedCount = passedCount + 1
    else
        table.insert(failedTests, file)
    end
    print("")
end

-- ============================================================================
-- SUMMARY
-- ============================================================================

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
    for _, file in ipairs(failedTests) do
        print("  ✗ " .. file)
    end
    print("")
    os.exit(1)
else
    print("All test files passed!")
    print("")
    os.exit(0)
end
