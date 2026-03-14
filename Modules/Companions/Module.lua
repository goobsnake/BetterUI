--[[
File: Modules/Companions/Module.lua
Purpose: Companion equipment management scaffold for BetterUI (INV-004).
         Foundation for companion gear comparison and slot views.
]]

BETTERUI.Companions = BETTERUI.Companions or {}

function BETTERUI.Companions.Setup()
    -- Placeholder: Will provide companion equipment workspace
    BETTERUI.Companions.initialized = true
end

function BETTERUI.Companions.IsInitialized()
    return BETTERUI.Companions.initialized == true
end
