--[[
File: Modules/Collections/Module.lua
Purpose: Collections/outfit browser scaffold for BetterUI (COL-001).
         Foundation for filtering, favorites, and progress clarity.
]]

BETTERUI.Collections = BETTERUI.Collections or {}

function BETTERUI.Collections.Setup()
    -- Placeholder: Will enhance gamepad collections browser
    BETTERUI.Collections.initialized = true
end

function BETTERUI.Collections.IsInitialized()
    return BETTERUI.Collections.initialized == true
end
