--[[
File: tools/tests/test_module_init_defaults_source.lua
Purpose: Guard the defaults-ownership cluster by keeping module InitModule entry
         points delegated to DefaultsRegistry instead of local fallback tables.
Usage:
  lua tools/tests/test_module_init_defaults_source.lua
]]

if false then
    dofile("Modules/Vendor/Module.lua")
    dofile("Modules/Writs/Module.lua")
end

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
    local handle, err = io.open(path, "r")
    assert_true(handle ~= nil, string.format("opens source file: %s (%s)", path, tostring(err)))
    if not handle then
        return ""
    end

    local content = handle:read("*a")
    handle:close()
    return content or ""
end

local moduleFiles = {
    {
        moduleName = "Banking",
        path = "Modules/Banking/Module.lua",
    },
    {
        moduleName = "Vendor",
        path = "Modules/Vendor/Module.lua",
    },
    {
        moduleName = "TradingHouse",
        path = "Modules/TradingHouse/Module.lua",
    },
    {
        moduleName = "Companions",
        path = "Modules/Companions/Module.lua",
    },
}

for _, moduleEntry in ipairs(moduleFiles) do
    local source = read_file(moduleEntry.path)
    local canonicalPattern = "BETTERUI%.Defaults%.GetModuleDefaults%(\"" .. moduleEntry.moduleName .. "\"%)"
    assert_true(source:find(canonicalPattern) ~= nil,
        moduleEntry.moduleName .. " InitModule delegates settings defaults to DefaultsRegistry")
    assert_true(source:find("local%s+fallbackDefaults%s*=%s*%{") == nil,
        moduleEntry.moduleName .. " Module.lua avoids inline fallback default tables")
end

local writsSource = read_file("Modules/Writs/Module.lua")
assert_true(writsSource:find('GetModuleDefaults%("Writs"%)') ~= nil,
    "Writs InitModule reads DefaultsRegistry module defaults")
assert_true(writsSource:find('ApplyModuleDefaults%("Writs",%s*m_options%)') ~= nil,
    "Writs InitModule applies DefaultsRegistry directly")
assert_true(writsSource:find('BETTERUI%.CIM%.InitModuleDefaults%("Writs"') == nil,
    "Writs InitModule avoids the CIM defaults helper")
assert_true(writsSource:find('RegisterModuleAccessors%("Writs"%)') == nil,
    "Writs root avoids CIM accessor registration")
assert_true(writsSource:find("local%s+fallbackDefaults%s*=%s*%{") == nil,
    "Writs Module.lua avoids inline fallback default tables")

local cimSource = read_file("Modules/CIM/Module.lua")
assert_true(cimSource:find('local%s+defaultsApi%s*=%s*BETTERUI%.Defaults') ~= nil,
    "CIM InitModule binds DefaultsRegistry directly")
assert_true(cimSource:find('ApplyModuleDefaults%("CIM",%s*m_options%)') ~= nil,
    "CIM InitModule uses Defaults.ApplyModuleDefaults directly")
assert_true(cimSource:find('BETTERUI%.CIM%.TryCall%("Defaults%.ApplyModuleDefaults"') == nil,
    "CIM InitModule avoids string-path defaults dispatch")
assert_true(cimSource:find('BETTERUI%.CIM%.TryResolve%("CIM%.Font%.SIZE_MIN"') == nil,
    "CIM InitModule reads font minimum directly")
assert_true(cimSource:find('BETTERUI%.CIM%.TryResolve%("CIM%.Font%.SIZE_MAX"') == nil,
    "CIM InitModule reads font maximum directly")

if failed > 0 then
    error(string.format("test_module_init_defaults_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_module_init_defaults_source.lua: %d passed", passed))
