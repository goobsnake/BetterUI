--[[
File: tools/tests/test_companions_runtime_source.lua
Purpose: Guards the Companions root/runtime split so Module.lua stays focused on
         lifecycle wiring while runtime scene/event orchestration lives in the
         core runtime helper.
Usage:
  lua tools/tests/test_companions_runtime_source.lua
]]

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

print("test_companions_runtime_source")

local moduleSource = read_file("Modules/Companions/Module.lua")
local runtimeSource = read_file("Modules/Companions/Core/CompanionsRuntime.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(runtimeSource, "function Companions.CreateScene(instance)",
    "Companions runtime helper owns scene creation")
assert_contains(runtimeSource, "function Companions.RegisterSceneLifecycle(instance)",
    "Companions runtime helper owns scene lifecycle registration")
assert_contains(runtimeSource, "function Companions.RegisterEvents(eventManager)",
    "Companions runtime helper owns event registration")
assert_contains(runtimeSource, "function BETTERUI.Companions.Class:TryEquipItem(inventorySlot)",
    "Companions class runtime helper owns TryEquipItem")
assert_contains(runtimeSource, "function Companions.BuildCoreKeybinds(instance)",
    "Companions runtime helper owns keybind construction")

assert_not_contains(moduleSource, "local function CreateCompanionScene(",
    "Companions Module.lua no longer defines scene creation directly")
assert_not_contains(moduleSource, "local function RegisterCompanionSceneLifecycle(",
    "Companions Module.lua no longer defines scene lifecycle directly")
assert_not_contains(moduleSource, "local function RegisterCompanionEvents(",
    "Companions Module.lua no longer defines event registration directly")
assert_not_contains(moduleSource, "function BETTERUI.Companions.Class:TryEquipItem(inventorySlot)",
    "Companions Module.lua no longer defines TryEquipItem directly")
assert_contains(moduleSource, "Companions.CreateScene(Companions.instance)",
    "Companions Module.lua delegates scene creation to the runtime helper")
assert_contains(moduleSource, "Companions.RegisterSceneLifecycle(Companions.instance)",
    "Companions Module.lua delegates scene lifecycle to the runtime helper")
assert_contains(moduleSource, "Companions.RegisterEvents(EVENT_MANAGER)",
    "Companions Module.lua delegates event registration to the runtime helper")
assert_contains(manifestSource, "Modules\\Companions\\Core\\CompanionsRuntime.lua",
    "Addon manifest loads the new Companions runtime helper")

print("  OK")
