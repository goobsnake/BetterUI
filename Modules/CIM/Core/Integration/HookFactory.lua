--[[
File: Modules/CIM/Core/Integration/HookFactory.lua
Purpose: Hook utilities for extending or replacing UI methods.
         Provides PreHook, PostHook, and ReplaceHook patterns.
]]

-- HOOK FACTORY (Internal)

--[[
Function: createHookInternal (local)
Creates method hooks with configurable execution position.
References: Used by BETTERUI.PreHook, BETTERUI.PostHook, BETTERUI.ReplaceHook
]]
local function createHookInternal(control, method, fn, position)
    if control == nil or method == nil or fn == nil then return end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "hookCreated", { position = position, method = method, type = type(control) }) end

    if position == "before" then
        -- Use native pre-hooking to avoid direct method replacement taint.
        ZO_PreHook(control, method, fn)
    elseif position == "after" then
        -- SecurePostHook only accepts table targets; many UI controls are userdata.
        if type(control) == "table" then
            SecurePostHook(control, method, fn)
        else
            ZO_PostHook(control, method, fn)
        end
    elseif position == "replace" then
        -- Full replacement is intentionally explicit and should be used sparingly.
        control[method] = function(self, ...)
            return fn(self, ...)
        end
    end
end

-- PUBLIC HOOK API

--- Hooks a method to execute fn BEFORE the original. fn returning true aborts original.
--- @param control table The object to hook
--- @param method string Method name to hook
--- @param fn fun(self: table, ...): boolean|nil Hook function
function BETTERUI.PreHook(control, method, fn)
    createHookInternal(control, method, fn, "before")
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "hookRegistered", { position = "before", method = method }) end
end

--- Hooks a method to execute fn AFTER the original.
--- @param control table The object to hook
--- @param method string Method name to hook
--- @param fn fun(self: table, ...) Hook function
function BETTERUI.PostHook(control, method, fn)
    createHookInternal(control, method, fn, "after")
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "hookRegistered", { position = "after", method = method }) end
end

--- Replaces a method entirely with fn.
--- @param control table The object to hook
--- @param method string Method name to replace
--- @param fn fun(self: table, ...) Replacement function
function BETTERUI.ReplaceHook(control, method, fn)
    createHookInternal(control, method, fn, "replace")
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "hookRegistered", { position = "replace", method = method }) end
end
