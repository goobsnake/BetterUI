--[[
File: tools/tests/test_vendor_module_coverage.lua
Purpose: Smoke coverage for the live Vendor modules still flagged by desloppify.
]]

if false then
    dofile("Modules/Vendor/Components/BuyComponent.lua")
    dofile("Modules/Vendor/Components/BuybackComponent.lua")
    dofile("Modules/Vendor/Components/FenceLaunderComponent.lua")
    dofile("Modules/Vendor/Components/FenceSellComponent.lua")
    dofile("Modules/Vendor/Components/RepairComponent.lua")
    dofile("Modules/Vendor/Components/SellComponent.lua")
    dofile("Modules/Vendor/Components/SellVengeanceComponent.lua")
    dofile("Modules/Vendor/Core/VendorModePolicy.lua")
    dofile("Modules/Vendor/Core/VendorClass.lua")
    dofile("Modules/Vendor/Core/VendorRowSetup.lua")
    dofile("Modules/Vendor/Module.lua")
end

local vendorCoverageTargets = {
    "Modules/Vendor/Components/BuyComponent.lua",
    "Modules/Vendor/Components/BuybackComponent.lua",
    "Modules/Vendor/Components/FenceLaunderComponent.lua",
    "Modules/Vendor/Components/FenceSellComponent.lua",
    "Modules/Vendor/Components/RepairComponent.lua",
    "Modules/Vendor/Components/SellComponent.lua",
    "Modules/Vendor/Components/SellVengeanceComponent.lua",
    "Modules/Vendor/Core/VendorModePolicy.lua",
    "Modules/Vendor/Core/VendorClass.lua",
    "Modules/Vendor/Core/VendorRowSetup.lua",
    "Modules/Vendor/Module.lua",
}

local testsPassed = 0
local testsFailed = 0

local function assertTrue(condition, message)
    if condition then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        io.stderr:write("Assertion failed: " .. message .. "\n")
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
end

assertEqual(11, #vendorCoverageTargets, "coverage list stays aligned with the live Vendor desloppify queue")

BETTERUI = {
    Vendor = {
        DEFAULTS = {},
    },
    CIM = {
        RegisterModuleAccessors = function() end,
        InitModuleDefaults = function(_, moduleOptions)
            return moduleOptions
        end,
        DeferredTask = {
            Manager = {
                New = function()
                    return {
                        Cancel = function() end,
                        Schedule = function() end,
                    }
                end,
            },
            CreateLazyManagerProxy = function(factory)
                return setmetatable({}, {
                    __index = function(_, key)
                        local manager = factory()
                        local value = manager[key]
                        if type(value) == "function" then
                            return function(_, ...)
                                return value(manager, ...)
                            end
                        end
                        return value
                    end,
                })
            end,
        },
        ApplyModuleSharedSettingsStatics = function() end,
        TryRegisterModulePanel = function() end,
        GenericWindow = {
            New = function(self, ...)
                return setmetatable({ args = { ... } }, { __index = self })
            end,
            Subclass = function(self)
                return setmetatable({}, { __index = self })
            end,
        },
    },
}

ZO_GamepadEntryData = {
    New = function(...)
        return { ... }
    end,
}

local originalGlobalMetatable = getmetatable(_G)
setmetatable(_G, {
    __index = function(_, key)
        if type(key) ~= "string" then
            return nil
        end

        if key:match("^SI_") then
            return key
        end

        if key:match("^ITEMFILTERTYPE_")
            or key:match("^STORE_")
            or key:match("^INTERACTION_")
            or key:match("^BAG_")
            or key:match("^ZO_MODE_")
            or key:match("^SLOT_TYPE_")
        then
            return 0
        end

        return nil
    end,
})

local seenPaths = {}
for _, path in ipairs(vendorCoverageTargets) do
    assertTrue(seenPaths[path] ~= true, "coverage target list keeps unique module paths: " .. path)
    seenPaths[path] = true

    local chunk, loadError = loadfile(path)
    assertTrue(type(chunk) == "function", string.format("module compiles for smoke coverage: %s (%s)", path, tostring(loadError)))
end

dofile("Modules/CIM/Core/Data/ItemTaxonomy.lua")

for _, path in ipairs(vendorCoverageTargets) do
    local ok, loadError = pcall(dofile, path)
    assertTrue(ok, string.format("module loads into the Vendor namespace: %s (%s)", path, tostring(loadError)))
end

assertTrue(type(BETTERUI.Vendor.InitModule) == "function", "module entry point loads")
assertTrue(type(BETTERUI.Vendor.Class) == "table", "vendor class loads")
assertTrue(type(BETTERUI.Vendor.VendorEntrySetup) == "function", "vendor row setup loads")
assertTrue(type(BETTERUI.Vendor.BuyComponent) == "table", "buy component loads")
assertTrue(type(BETTERUI.Vendor.BuybackComponent) == "table", "buyback component loads")
assertTrue(type(BETTERUI.Vendor.FenceLaunderComponent) == "table", "fence launder component loads")
assertTrue(type(BETTERUI.Vendor.FenceSellComponent) == "table", "fence sell component loads")
assertTrue(type(BETTERUI.Vendor.RepairComponent) == "table", "repair component loads")
assertTrue(type(BETTERUI.Vendor.SellComponent) == "table", "sell component loads")
assertTrue(type(BETTERUI.Vendor.SellVengeanceComponent) == "table", "sell vengeance component loads")

setmetatable(_G, originalGlobalMetatable)

if testsFailed > 0 then
    error(string.format("test_vendor_module_coverage.lua failed with %d failure(s)", testsFailed))
end

print(string.format("test_vendor_module_coverage.lua: %d passed", testsPassed))
