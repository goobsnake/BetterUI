--[[
File: Modules/CIM/Core/HookFactory.lua
Purpose: Hook utilities for extending or replacing UI methods.
         Provides PreHook, PostHook, and ReplaceHook patterns.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-- ============================================================================
-- HOOK FACTORY (Internal)
-- ============================================================================

--[[
Function: createHookInternal (local)
Description: Creates method hooks with configurable execution position.
Rationale: Consolidates PostHook and Hook into single pattern.
Mechanism: Wraps original method with new function, controlling execution order.
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

-- ============================================================================
-- PUBLIC HOOK API
-- ============================================================================

--[[
Function: BETTERUI.PreHook
Description: Hooks a method to run BEFORE the original method.
Rationale: Pre-processing or conditional abort.
Mechanism: If hook returns true, original method is NOT called.
param: control (table) - The UI control or object.
param: method (string) - The name of the method to hook.
param: fn (function) - The function to execute before the original.
]]
--- @param control table|nil The UI control or object
--- @param method string The name of the method to hook
--- @param fn function The function to execute before the original (return true to abort)
function BETTERUI.PreHook(control, method, fn)
    createHookInternal(control, method, fn, "before")
end

--[[
Function: BETTERUI.PostHook
Description: Hooks a method to run AFTER the original method.
Rationale: Safe method extension.
Mechanism: Replaces the method on the control with a wrapper that calls Original -> New.
param: control (table) - The UI control or object.
param: method (string) - The name of the method to hook.
param: fn (function) - The function to execute after the original.
]]
--- @param control table|nil The UI control or object
--- @param method string The name of the method to hook
--- @param fn function The function to execute after the original
function BETTERUI.PostHook(control, method, fn)
    createHookInternal(control, method, fn, "after")
end

--[[
Function: BETTERUI.ReplaceHook
Description: Hooks a method to REPLACE the original method entirely.
Rationale: Full method replacement.
Mechanism: Original method is NOT called; only the new function runs.
param: control (table) - The UI control.
param: method (string) - The method name.
param: fn (function) - The replacement function.
]]
--- @param control table|nil The UI control
--- @param method string The method name
--- @param fn function The replacement function
function BETTERUI.ReplaceHook(control, method, fn)
    createHookInternal(control, method, fn, "replace")
end
