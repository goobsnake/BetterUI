--[[
File: Modules/CIM/Core/KeybindHelpers.lua
Purpose: Keybind utility functions shared across BetterUI modules.
Author: BetterUI Team
Last Modified: 2026-01-26


]]

BETTERUI.Interface = BETTERUI.Interface or {}

--[[
Function: BETTERUI.Interface.EnsureKeybindGroupAdded
Safely registers a keybind group without causing duplicates.
param: descriptor (table) - The keybind descriptor to add.
]]
--- @param descriptor table The keybind descriptor to add
function BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor)
    if not descriptor or not KEYBIND_STRIP then return end
    local groups = KEYBIND_STRIP.keybindButtonGroups or {}
    for _, group in ipairs(groups) do
        if group == descriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
            return
        end
    end
    KEYBIND_STRIP:AddKeybindButtonGroup(descriptor)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
end
