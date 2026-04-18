--[[
File: Modules/Vendor/Core/VendorSafeExecute.lua
Purpose: Provide the shared safe-execution helper used across vendor runtime
         surfaces so subsystem entrypoints do not duplicate fallback logic.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor

function Vendor.ExecuteSafely(context, fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end

    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute then
        return BETTERUI.CIM.SafeExecute(context, fn, ...)
    end

    local ok, result = pcall(fn, ...)
    if not ok then
        assert(BETTERUI and BETTERUI.CIM and BETTERUI.CIM.UserNotify,
            "Vendor fallback error handling requires BETTERUI.CIM.UserNotify")
        BETTERUI.CIM.UserNotify(context, tostring(result))
    end
    return ok, result
end
