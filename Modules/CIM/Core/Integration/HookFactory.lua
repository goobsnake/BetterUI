--[[
File: Modules/CIM/Core/HookFactory.lua
Purpose: Hook utilities for extending or replacing UI methods.
         Provides PreHook, PostHook, and ReplaceHook patterns.
]]

-- ============================================================================
-- HOOK FACTORY (Internal)
-- ============================================================================

--[[
Function: createHookInternal (local)
Creates method hooks with configurable execution position.
References: Used by BETTERUI.PreHook, BETTERUI.PostHook, BETTERUI.ReplaceHook
]]
--- @param control table UI object to hook
--- @param method string Method name to hook
--- @param fn function Hook callback
--- @param position string "before"|"after"|"replace" execution order
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

--- @param control table|nil The UI control or object
--- @param method string The name of the method to hook
--- @param fn function The function to execute before the original (return true to abort)
function BETTERUI.PreHook(control, method, fn)
    createHookInternal(control, method, fn, "before")
end

--- @param control table|nil The UI control or object
--- @param method string The name of the method to hook
--- @param fn function The function to execute after the original
function BETTERUI.PostHook(control, method, fn)
    createHookInternal(control, method, fn, "after")
end

--- @param control table|nil The UI control
--- @param method string The method name
--- @param fn function The replacement function
function BETTERUI.ReplaceHook(control, method, fn)
    createHookInternal(control, method, fn, "replace")
end
