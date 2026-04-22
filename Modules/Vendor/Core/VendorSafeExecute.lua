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
    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute then
        return BETTERUI.CIM.SafeExecute(context, fn, ...)
    end

    if type(fn) ~= "function" then
        if BETTERUI and BETTERUI.Debug then
            BETTERUI.Debug(string.format("[Error] %s: No function provided", tostring(context)))
        end
        return false, "No function provided"
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
