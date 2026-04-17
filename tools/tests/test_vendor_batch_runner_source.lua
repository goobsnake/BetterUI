--[[
File: tools/tests/test_vendor_batch_runner_source.lua
Purpose: Guards the explicit runner structure for Vendor.ExecuteBatchThrottled.

Usage:
  lua tools/tests/test_vendor_batch_runner_source.lua
]]

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function assert_contains(haystack, needle, message)
    if not haystack:find(needle, 1, true) then
        error(message .. "\nMissing: " .. needle)
    end
end

print("test_vendor_batch_runner_source")

local source = read_file("Modules/Vendor/Vendor.lua")

assert_contains(source, "local function ResolveVendorBatchActionName(mode)",
    "Vendor batch runner extracts action-name resolution")
assert_contains(source, "local function ResolveVendorBatchDelayPolicy(totalItems)",
    "Vendor batch runner extracts delay-policy resolution")
assert_contains(source, "local function CreateVendorBatchRunner(mode, items, onComplete)",
    "Vendor batch runner uses an explicit runner table")
assert_contains(source, "function runner:Start()",
    "Vendor batch runner exposes a named start phase")
assert_contains(source, "function runner:Step()",
    "Vendor batch runner exposes a named step phase")
assert_contains(source, "function runner:Finish()",
    "Vendor batch runner exposes a named finish phase")
assert_contains(source, "local runner = CreateVendorBatchRunner(mode, items, onComplete)",
    "Vendor.ExecuteBatchThrottled delegates to the explicit runner object")

print("  OK")
