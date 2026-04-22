--[[
File: Modules/Vendor/Core/VendorSafeExecute.lua
Purpose: Provide the shared safe-execution helper used across vendor runtime
         surfaces so subsystem entrypoints do not duplicate fallback logic.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor

local unpackCompat = table.unpack or unpack

local function PackResults(...)
    return {
        n = select("#", ...),
        ...
    }
end

function Vendor.ExecuteSafely(context, fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end

    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute then
        return BETTERUI.CIM.SafeExecute(context, fn, ...)
    end

    local results = PackResults(pcall(fn, ...))
    local ok = results[1]
    if not ok then
        local err = results[2]
        local userNotify = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.UserNotify
        if type(userNotify) == "function" then
            pcall(userNotify, context, tostring(err))
        end
        return false, err
    end

    return true, unpackCompat(results, 2, results.n)
end
