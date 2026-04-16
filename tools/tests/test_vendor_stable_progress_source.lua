--[[
File: tools/tests/test_vendor_stable_progress_source.lua
Purpose: Source-level regression checks for stable training progress bars.
]]

local passed = 0
local failed = 0

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
    if string.find(haystack, needle, 1, true) then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- missing %s", label, needle))
    end
end

print("[Vendor stable progress source integration]")

local vendorLua = read_file("Modules/Vendor/Vendor.lua")
local rowSetupLua = read_file("Modules/Vendor/Core/VendorRowSetup.lua")
local templatesXml = read_file("Modules/CIM/Templates/SharedTemplates.xml")

assert_contains(templatesXml, "BETTERUI_GamepadStableTrainingEntryTemplate", "stable training template is defined")
assert_contains(templatesXml, "$(parent)TrainingProgressBackdrop", "stable training template adds a progress backdrop")
assert_contains(templatesXml, "$(parent)TrainingProgress", "stable training template adds a progress bar")

assert_contains(vendorLua, "progressCurrent", "stable training rows include progress current data")
assert_contains(vendorLua, "progressMax", "stable training rows include progress max data")
assert_contains(vendorLua, "BETTERUI_GamepadStableTrainingEntryTemplate", "stable training rows use the dedicated template")

assert_contains(rowSetupLua, "TrainingProgress", "vendor row setup looks up the training progress control")
assert_contains(rowSetupLua, "SetMinMax", "vendor row setup configures the training progress range")
assert_contains(rowSetupLua, "SetValue", "vendor row setup configures the training progress value")
assert_contains(rowSetupLua, "trainingProgressBackdrop", "vendor row setup manages the training progress backdrop")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end