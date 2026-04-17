--[[
File: tools/tests/test_companions_class_source.lua
Purpose: Source-level regression checks for the companion base-class seams.

Usage:
  lua tools/tests/test_companions_class_source.lua
]]

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local source = read_file("Modules/Companions/Core/CompanionsClass.lua")

assert_true(source:find("BETTERUI%.Companions%.EnsureTaskManager = EnsureCompanionsTaskManager") ~= nil,
    "CompanionsClass exposes the shared task-manager installer")
assert_true(source:find("BETTERUI%.Companions%.Tasks = BETTERUI%.Companions%.Tasks or CompanionsDeferredTask%.CreateLazyManagerProxy%(EnsureCompanionsTaskManager%)") ~= nil,
    "CompanionsClass defines the lazy companion task proxy")
assert_true(source:find("BETTERUI%.Companions%.Class = BETTERUI%.CIM%.GenericWindow:Subclass%(%)") ~= nil,
    "CompanionsClass subclasses the shared CIM generic window")
assert_true(source:find("BETTERUI%.Companions%.Class%.SEARCH_LIFECYCLE = %{%s*") ~= nil,
    "CompanionsClass defines the shared search lifecycle contract")
assert_true(source:find("function BETTERUI%.Companions%.Class:IsSceneShowing%(%)") ~= nil,
    "CompanionsClass exposes IsSceneShowing")
assert_true(source:find("function BETTERUI%.Companions%.Class:EnterSearchMode%(%)") ~= nil,
    "CompanionsClass exposes EnterSearchMode")
assert_true(source:find("function BETTERUI%.Companions%.Class:ExitSearchMode%(%)") ~= nil,
    "CompanionsClass exposes ExitSearchMode")
assert_true(source:find("function BETTERUI%.Companions%.Class:RequestHeaderFocus%(%)") ~= nil,
    "CompanionsClass exposes RequestHeaderFocus")
assert_true(source:find("function BETTERUI%.Companions%.Class:OnHeaderEntered%(%)") ~= nil,
    "CompanionsClass exposes OnHeaderEntered")
assert_true(source:find("function BETTERUI%.Companions%.Class:RefreshCompanionFooter%(%)") ~= nil,
    "CompanionsClass exposes RefreshCompanionFooter")

if failed > 0 then
    error(string.format("test_companions_class_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_companions_class_source.lua: %d passed", passed))
