--[[
File: tools/tests/test_batch_lifecycle_source.lua
Purpose: Source contract for aggregate batch lifecycle trace envelopes.
]]

local function read_file(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(string.format("failed to open %s: %s", path, tostring(err)))
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function count_occurrences(haystack, needle)
    local count = 0
    local start = 1
    while true do
        local match_start, match_end = haystack:find(needle, start, true)
        if not match_start then
            return count
        end
        count = count + 1
        start = match_end + 1
    end
end

local function assert_count(haystack, needle, expected, label)
    local actual = count_occurrences(haystack, needle)
    if actual ~= expected then
        error(string.format("%s\nExpected %d occurrence(s), found %d: %s", label, expected, actual, needle))
    end
end

print("test_batch_lifecycle_source")

local vendor = read_file("Modules/Vendor/Core/VendorBatchRuntime.lua")
local mixin = read_file("Modules/CIM/Core/Batching/MultiSelectMixin.lua")
local banking = read_file("Modules/Banking/Core/MultiSelectActions.lua")

assert_contains(vendor, "local function NewVendorBatchId()",
    "vendor batch runtime defines a lifecycle id helper")
assert_contains(vendor, "L.NewFlow(\"batch\")",
    "vendor batch runtime allocates batch flow ids")
assert_contains(vendor, "batchId = NewVendorBatchId()",
    "vendor runner stores a shared batch id")
assert_contains(vendor, "TraceVendorBatch(\"vendor.batch\", \"begin\"",
    "vendor runner emits aggregate begin envelope")
assert_contains(vendor, "TraceVendorBatch(\"vendor.batch\", \"step\"",
    "vendor runner emits aggregate step envelope")
assert_contains(vendor, "TraceVendorBatch(\"vendor.batch\", self.stopReason and \"abort\" or \"end\"",
    "vendor runner emits aggregate end or abort envelope")
assert_contains(vendor, "batchId = self.batchId",
    "vendor aggregate envelopes carry the shared batch id")
assert_count(vendor, "TraceVendorBatch(\"vendor.batch\", \"begin\"", 1,
    "vendor runner emits exactly one aggregate begin call site")
assert_count(vendor, "TraceVendorBatch(\"vendor.batch\", \"step\"", 1,
    "vendor runner emits exactly one aggregate step call site")
assert_count(vendor, "TraceVendorBatch(\"vendor.batch\", self.stopReason and \"abort\" or \"end\"", 1,
    "vendor runner emits exactly one aggregate terminal call site")
assert_contains(vendor, "stepIndex = self.index",
    "vendor aggregate step envelope carries stepIndex")
assert_contains(vendor, "totalSteps = self.totalItems",
    "vendor aggregate envelopes carry totalSteps")
assert_contains(vendor, "abortReason = self.stopReason",
    "vendor terminal envelope carries abortReason")
assert_contains(vendor, "stepReason = stepResult.reason",
    "vendor step envelope carries step-level reason")

assert_contains(mixin, "local function NewBatchLifecycleId()",
    "CIM batch mixin defines a lifecycle id helper")
assert_contains(mixin, "L.NewFlow(\"batch\")",
    "CIM batch mixin allocates batch flow ids")
assert_contains(mixin, "local lifecycleEvent = lifecycleOptions and lifecycleOptions.eventName or \"cim.batch\"",
    "CIM batch mixin supports caller lifecycle event metadata")
assert_contains(mixin, "TraceBatchLifecycle(lifecycleEvent, \"begin\"",
    "CIM batch mixin emits aggregate begin envelope")
assert_contains(mixin, "TraceBatchLifecycle(lifecycleEvent, \"step\"",
    "CIM batch mixin emits aggregate step envelope")
assert_contains(mixin, "TraceBatchLifecycle(lifecycleEvent, stopReason and \"abort\" or \"end\"",
    "CIM batch mixin emits aggregate end or abort envelope")
assert_contains(mixin, "batchId = batchId",
    "CIM aggregate envelopes carry the shared batch id")
assert_count(mixin, "TraceBatchLifecycle(lifecycleEvent, \"begin\"", 1,
    "CIM batch mixin emits exactly one aggregate begin call site")
assert_count(mixin, "TraceBatchLifecycle(lifecycleEvent, \"step\"", 1,
    "CIM batch mixin emits exactly one aggregate step call site")
assert_count(mixin, "TraceBatchLifecycle(lifecycleEvent, stopReason and \"abort\" or \"end\"", 1,
    "CIM batch mixin emits exactly one aggregate terminal call site")
assert_contains(mixin, "stepIndex = index",
    "CIM aggregate step envelope carries stepIndex")
assert_contains(mixin, "totalSteps = totalItems",
    "CIM aggregate envelopes carry totalSteps")
assert_contains(mixin, "abortReason = stopReason",
    "CIM terminal envelope carries abortReason")
assert_contains(mixin, "stepReason = stepReason",
    "CIM step envelope carries step-level reason")

assert_contains(banking, "eventName = \"bank.batch\"",
    "banking transfer batches request the bank.batch lifecycle event")
assert_contains(banking, "module = \"Banking\"",
    "banking transfer batches identify the Banking module")
assert_contains(banking, "options = BANK_TRANSFER_BATCH_OPTIONS",
    "banking transfer flow passes lifecycle-enabled batch options")

print("ok")
