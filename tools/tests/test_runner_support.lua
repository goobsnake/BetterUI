--[[
File: tools/tests/test_runner_support.lua
Purpose: Regression tests for shared runner-support helpers used by
         tools/tests/run_all_tests.lua.
Usage:
  lua tools/tests/test_runner_support.lua
]]

if false then
    dofile("tools/tests/lib/TestRunnerSupport.lua")
end

local RunnerSupport = dofile("tools/tests/lib/TestRunnerSupport.lua")

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

print("[RunnerSupport]")

assert_eq(RunnerSupport.HasFailureOutput("lua: boom\nstack traceback:\n"), true,
    "runner support flags Lua stack traces as failures")
assert_eq(RunnerSupport.HasFailureOutput("FAILED: one test failed"), true,
    "runner support flags FAILED markers as failures")
assert_eq(RunnerSupport.HasFailureOutput("  FAIL: one assertion failed"), true,
    "runner support flags explicit FAIL assertion lines as failures")
assert_eq(RunnerSupport.HasFailureOutput("Passed: 10\nFailed: 0\n"), false,
    "runner support ignores zero-failure summary lines")
assert_eq(RunnerSupport.HasFailureOutput("Passed: 10\nFailed: 2\n"), true,
    "runner support flags non-zero failure summary lines")
assert_eq(RunnerSupport.HasFailureOutput("[OK] All test files passed!\n"), false,
    "runner support keeps clean success output green")

assert_eq(RunnerSupport.NormalizeCommandSuccess(true), true,
    "runner support treats boolean true as success")
assert_eq(RunnerSupport.NormalizeCommandSuccess(false), false,
    "runner support treats boolean false as failure")
assert_eq(RunnerSupport.NormalizeCommandSuccess(0), true,
    "runner support treats numeric zero as success")
assert_eq(RunnerSupport.NormalizeCommandSuccess(1), false,
    "runner support treats non-zero numeric results as failure")
assert_eq(RunnerSupport.NormalizeCommandSuccess(true, "exit", 0), true,
    "runner support treats exit status zero as success")
assert_eq(RunnerSupport.NormalizeCommandSuccess(nil, "exit", 1), false,
    "runner support treats non-zero exit status as failure")
assert_eq(RunnerSupport.NormalizeCommandSuccess(true, "signal", 9), false,
    "runner support treats signal termination as failure")

assert_eq(RunnerSupport.DidTestPass("All tests passed!\n", true), true,
    "runner support accepts clean success output")
assert_eq(RunnerSupport.DidTestPass("All tests passed!\nlua: boom\nstack traceback:\n", true), false,
    "runner support rejects crash output even if success text is present")
assert_eq(RunnerSupport.DidTestPass("FAILED: one test failed", true), false,
    "runner support rejects FAILED output regardless of command status")
assert_eq(RunnerSupport.DidTestPass("All tests passed!\n", nil, "exit", 1), false,
    "runner support rejects non-zero exit status even with success text")

if failed > 0 then
    error(string.format("test_runner_support.lua failed with %d failure(s)", failed))
end

print(string.format("test_runner_support.lua: %d passed", passed))
