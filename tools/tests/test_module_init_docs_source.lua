--[[
File: tools/tests/test_module_init_docs_source.lua
Purpose: Guards module init documentation so entry files keep only local
         contract notes instead of repeated framework boilerplate.

Usage:
  lua tools/tests/test_module_init_docs_source.lua
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

print("test_module_init_docs_source")

local repeatedNeedles = {
    "It is called by BETTERUI.ModuleOptions() via pcall with only m_options.",
    "Standard InitModule Signature (consistent across all modules):",
    "Wrapper Function (caller in BetterUI.lua):",
}

local repeatedPaths = {
    "Modules/Banking/Module.lua",
    "Modules/Companions/Module.lua",
    "Modules/Inventory/Module.lua",
    "Modules/TradingHouse/Module.lua",
    "Modules/Vendor/Module.lua",
    "Modules/Writs/Module.lua",
}

for _, path in ipairs(repeatedPaths) do
    local source = read_file(path)
    for _, needle in ipairs(repeatedNeedles) do
        assert_not_contains(source, needle, path .. " drops shared InitModule boilerplate")
    end
end

local defaultsSource = read_file("Modules/ResourceOrbFrames/Settings/Defaults.lua")
assert_not_contains(defaultsSource, "It is called by BETTERUI.ModuleOptions() via pcall with only m_options.",
    "ResourceOrbFrames defaults helper no longer documents itself as the public ModuleOptions hook")
assert_contains(defaultsSource, "Delegated defaults helper for ResourceOrbFrames.InitModule.",
    "ResourceOrbFrames defaults helper documents delegated ownership")

print("  OK")
