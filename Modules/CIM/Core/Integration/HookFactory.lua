--[[
File: Modules/CIM/Core/HookFactory.lua
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
            fn(self, ...)
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
end

--- Hooks a method to execute fn AFTER the original.
--- @param control table The object to hook
--- @param method string Method name to hook
--- @param fn fun(self: table, ...) Hook function
function BETTERUI.PostHook(control, method, fn)
    createHookInternal(control, method, fn, "after")
end

--- Replaces a method entirely with fn.
--- @param control table The object to hook
--- @param method string Method name to replace
--- @param fn fun(self: table, ...) Replacement function
function BETTERUI.ReplaceHook(control, method, fn)
    createHookInternal(control, method, fn, "replace")
end
