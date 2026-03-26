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
Creates method hooks with configurable execution position.
References: Used by BETTERUI.PreHook, BETTERUI.PostHook, BETTERUI.ReplaceHook
]]
local function createHookInternal(control, method, fn, position)
    if control == nil then return end
    local originalMethod = control[method]

    if position == "before" then
        control[method] = function(self, ...)
            local result = fn(self, ...)
            if result ~= true then -- Allow pre-hook to abort by returning true
                return originalMethod(self, ...)
            end
        end
    elseif position == "after" then
        control[method] = function(self, ...)
            originalMethod(self, ...)
            fn(self, ...)
        end
    elseif position == "replace" then
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
Hooks a method to run BEFORE the original method.
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
Hooks a method to run AFTER the original method.
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
Hooks a method to REPLACE the original method entirely.
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
