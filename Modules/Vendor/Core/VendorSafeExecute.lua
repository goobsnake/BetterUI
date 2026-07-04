--[[
File: Modules/Vendor/Core/VendorSafeExecute.lua
Purpose: Provide the shared safe-execution helper used across vendor runtime
         surfaces so subsystem entrypoints do not duplicate fallback logic.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor

-- BUI-CONS-004: BETTERUI.CIM.SafeExecute is defined unconditionally
-- (Modules/CIM/Core/Diagnostics/SafeExecute.lua) and every vendor runtime path
-- runs after CIM loads, so the former pcall/notify fallback body was
-- unreachable. ExecuteSafely is now a thin delegator to the CIM safe executor;
-- VendorClass asserts Vendor.ExecuteSafely at load, so vendor callers still fail
-- closed if this helper is ever missing.
function Vendor.ExecuteSafely(context, fn, ...)
    return BETTERUI.CIM.SafeExecute(context, fn, ...)
end
