--[[
File: tools/tests/test_import_time_runtime_bindings.lua
Purpose: Guards that high-gravity module roots do not hard-require shared
         runtime collaborators at import time.
Usage:
  lua tools/tests/test_import_time_runtime_bindings.lua
]]

local function assert_true(value, label)
    if not value then
        error(label)
    end
end

local function load_vendor_root_without_runtime_collaborators()
    BETTERUI = {
        Vendor = {
            Class = {},
            MODE = {
                BUY = 1,
                SELL = 2,
                REPAIR = 3,
                BUYBACK = 4,
                FENCE_SELL = 5,
                FENCE_LAUNDER = 6,
                STABLE = 7,
                SELL_VENGEANCE = 8,
            },
        },
        CIM = {},
    }

    local ok, err = pcall(dofile, "Modules/Vendor/Vendor.lua")
    assert_true(ok, "Vendor root loads before vendor runtime collaborators are populated: " .. tostring(err))
end

local function load_resource_orbframes_root_without_deferred_task()
    BETTERUI = {
        ResourceOrbFrames = {
            Utils = {
                Settings = {
                    Get = function()
                        return {}
                    end,
                    GetCustomFrontBar = function()
                        return nil
                    end,
                },
                Controls = {
                    Find = function()
                        return nil
                    end,
                },
            },
        },
        CIM = {
            Debug = { FLAGS = {} },
            CONST = { TIMING = {} },
        },
    }

    local ok, err = pcall(dofile, "Modules/ResourceOrbFrames/ResourceOrbFrames.lua")
    assert_true(ok, "ResourceOrbFrames root loads before CIM.DeferredTask is populated: " .. tostring(err))
end

load_vendor_root_without_runtime_collaborators()
load_resource_orbframes_root_without_deferred_task()

print("test_import_time_runtime_bindings.lua: PASS")
