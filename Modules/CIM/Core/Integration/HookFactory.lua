--[[
File: Modules/CIM/Core/Integration/HookFactory.lua
Purpose: Hook utilities for extending UI methods without owning method slots.
         Provides PreHook and PostHook only.
]]

-- HOOK FACTORY (Internal)

--[[
Function: createHookInternal (local)
Creates method hooks with configurable execution position.
References: Used by BETTERUI.PreHook, BETTERUI.PostHook
]]
local function createHookInternal(control, method, fn, position)
    if control == nil or method == nil or fn == nil then return end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "hook created", { position = position, method = method, type = type(control) }) end

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
    end
end

-- PUBLIC HOOK API

--- Hooks a method to execute fn BEFORE the original. fn returning true aborts original.
--- @param control table The object to hook
--- @param method string Method name to hook
--- @param fn fun(self: table, ...): boolean|nil Hook function
function BETTERUI.PreHook(control, method, fn)
    createHookInternal(control, method, fn, "before")
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "hook registered", { position = "before", method = method }) end
end

--- Hooks a method to execute fn AFTER the original.
--- @param control table The object to hook
--- @param method string Method name to hook
--- @param fn fun(self: table, ...) Hook function
function BETTERUI.PostHook(control, method, fn)
    createHookInternal(control, method, fn, "after")
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "hook registered", { position = "after", method = method }) end
end
