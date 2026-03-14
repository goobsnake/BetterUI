--[[
File: Modules/Quickslot/Module.lua
Purpose: Quickslot management hub scaffold for BetterUI (INV-002).
         Foundation for radial/list hybrid quickslot UI with loadout support.
]]

BETTERUI.Quickslot = BETTERUI.Quickslot or {}

function BETTERUI.Quickslot.Setup()
    -- Placeholder: Will intercept gamepad quickslot scene
    BETTERUI.Quickslot.initialized = true
end

function BETTERUI.Quickslot.IsInitialized()
    return BETTERUI.Quickslot.initialized == true
end
