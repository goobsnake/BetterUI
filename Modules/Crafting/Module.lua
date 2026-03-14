--[[
File: Modules/Crafting/Module.lua
Purpose: Crafting station UI enhancement scaffold for BetterUI (CFT-001).
         Foundation for research-aware, value-aware crafting guidance.
]]

BETTERUI.Crafting = BETTERUI.Crafting or {}

function BETTERUI.Crafting.Setup()
    -- Placeholder: Will enhance gamepad crafting station UI
    BETTERUI.Crafting.initialized = true
end

function BETTERUI.Crafting.IsInitialized()
    return BETTERUI.Crafting.initialized == true
end
