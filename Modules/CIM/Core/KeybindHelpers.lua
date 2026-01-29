--[[
File: Modules/CIM/Core/KeybindHelpers.lua
Purpose: Keybind utility functions shared across BetterUI modules.
Author: BetterUI Team
Last Modified: 2026-01-26


]]

BETTERUI.Interface = BETTERUI.Interface or {}

--[[
Function: BETTERUI.Interface.EnsureKeybindGroupAdded
Description: Safely registers a keybind group without causing duplicates.
Rationale: Prevent errors when adding same keybind descriptor multiple times.
Mechanism: Iterates existing groups; if found, updates it. If not, adds it.
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
