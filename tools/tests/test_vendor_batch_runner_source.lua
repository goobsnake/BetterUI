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

local vendorSource = read_file("Modules/Vendor/Vendor.lua")
local batchRuntimeSource = read_file("Modules/Vendor/Core/VendorBatchRuntime.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(vendorSource, "local function GetVendorBatchRuntime()",
    "Vendor runtime resolves the batch runtime collaborator through an explicit seam")
assert_contains(vendorSource, 'return ResolveVendorRuntimeDependency("BatchRuntime", "batch runtime")',
    "Vendor runtime requires the batch runtime collaborator")
assert_contains(vendorSource, "function Vendor.ExecuteBatchAction(mode, itemData)",
    "Vendor exposes the batch-action facade for component callers")
assert_contains(vendorSource, "GetVendorBatchRuntime().ExecuteBatchAction(mode, itemData)",
    "Vendor batch-action facade delegates execution to the collaborator")
assert_contains(vendorSource, "local function ResolveVendorBatchActionName(mode)",
    "Vendor keeps a helper seam for action-name resolution delegation")
assert_contains(vendorSource, "return GetVendorBatchRuntime().ResolveBatchActionName(mode)",
    "Vendor action-name helper delegates to the collaborator")
assert_contains(vendorSource, "local function ResolveVendorBatchDelayPolicy(totalItems)",
    "Vendor keeps a helper seam for delay-policy delegation")
assert_contains(vendorSource, "return GetVendorBatchRuntime().ResolveBatchDelayPolicy(totalItems)",
    "Vendor delay-policy helper delegates to the collaborator")
assert_contains(vendorSource, "local function CreateVendorBatchRunner(mode, items, onComplete)",
    "Vendor keeps a helper seam for explicit runner delegation")
assert_contains(vendorSource, "return GetVendorBatchRuntime().CreateBatchRunner(mode, items, onComplete)",
    "Vendor runner helper delegates to the collaborator")
assert_contains(vendorSource, "GetVendorBatchRuntime().ExecuteBatchThrottled(mode, items, onComplete)",
    "Vendor.ExecuteBatchThrottled delegates to the collaborator")
assert_contains(vendorSource, "GetVendorBatchRuntime().RequestBatchAbort()",
    "Vendor.RequestBatchAbort delegates to the collaborator")

assert_contains(batchRuntimeSource, "function BatchRuntime.ResolveBatchActionName(mode)",
    "Batch runtime owns action-name resolution")
assert_contains(batchRuntimeSource, "function BatchRuntime.ResolveBatchDelayPolicy(totalItems)",
    "Batch runtime owns delay-policy resolution")
assert_contains(batchRuntimeSource, "function BatchRuntime.CreateBatchRunner(mode, items, onComplete)",
    "Batch runtime owns explicit runner construction")
assert_contains(batchRuntimeSource, "function runner:Start()",
    "Batch runtime runner exposes a named start phase")
assert_contains(batchRuntimeSource, "function runner:Step()",
    "Batch runtime runner exposes a named step phase")
assert_contains(batchRuntimeSource, "function runner:Finish()",
    "Batch runtime runner exposes a named finish phase")
assert_contains(batchRuntimeSource, "local runner = BatchRuntime.CreateBatchRunner(mode, items, onComplete)",
    "Batch runtime executes throttled work via the explicit runner object")

assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorBatchRuntime.lua",
    "Vendor manifest loads the batch runtime collaborator")

print("  OK")
