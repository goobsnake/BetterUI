--[[
File: Modules/CIM/Core/Presentation/KeybindHelpers.lua
Purpose: Keybind utility functions shared across BetterUI modules.


]]

BETTERUI.Interface = BETTERUI.Interface or {}

---@param descriptor table?
function BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor)
    if not descriptor or not KEYBIND_STRIP then return end
    if KEYBIND_STRIP:HasKeybindButtonGroup(descriptor) then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
        return
    end
    KEYBIND_STRIP:AddKeybindButtonGroup(descriptor)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
end

--- Removes only the caller-owned keybind groups from the strip, skipping
--- keepDescriptor. Returns the descriptors actually removed so the caller can
--- later restore exactly those via RestoreKeybindGroups. Never touches groups
--- owned by the native UI or other addons.
---@param ownedGroups table? array of keybind group descriptors owned by the calling module
---@param keepDescriptor table? descriptor that must stay on the strip
---@return table removed descriptors actually removed, in removal order
function BETTERUI.Interface.RemoveOwnedKeybindGroups(ownedGroups, keepDescriptor)
    local removed = {}
    if not ownedGroups or not KEYBIND_STRIP then return removed end
    for _, group in ipairs(ownedGroups) do
        if group and group ~= keepDescriptor and KEYBIND_STRIP:HasKeybindButtonGroup(group) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
            removed[#removed + 1] = group
        end
    end
    return removed
end

--- Re-adds keybind groups previously removed by RemoveOwnedKeybindGroups.
---@param removedGroups table? array of keybind group descriptors to restore
function BETTERUI.Interface.RestoreKeybindGroups(removedGroups)
    if not removedGroups then return end
    for _, group in ipairs(removedGroups) do
        BETTERUI.Interface.EnsureKeybindGroupAdded(group)
    end
end
