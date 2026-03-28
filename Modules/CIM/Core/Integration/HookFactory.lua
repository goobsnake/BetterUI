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

-- PUBLIC HOOK API

function BETTERUI.PreHook(control, method, fn)
    createHookInternal(control, method, fn, "before")
end

function BETTERUI.PostHook(control, method, fn)
    createHookInternal(control, method, fn, "after")
end

function BETTERUI.ReplaceHook(control, method, fn)
    createHookInternal(control, method, fn, "replace")
end
