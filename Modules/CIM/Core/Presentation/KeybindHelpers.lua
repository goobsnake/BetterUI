--[[
File: Modules/CIM/Core/Presentation/KeybindHelpers.lua
Purpose: Keybind utility functions shared across BetterUI modules.


]]

BETTERUI.Interface = BETTERUI.Interface or {}

local function GetKeybindStrip()
    return rawget(_G, "KEYBIND_STRIP")
end

local function TraceKeybindHelper(event, data)
    if BETTERUI.Log and BETTERUI.Log.Trace then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, event, data or {})
    end
end

local function WarnKeybindHelper(event, data)
    if BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.KEYBIND, event, data or {})
    end
end

local function InvokeKeybindStrip(methodName, ...)
    local strip = GetKeybindStrip()
    local method = strip and strip[methodName]
    if type(method) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(method, strip, ...)
    if not ok then
        WarnKeybindHelper("keybind strip call failed", {
            fn = "KeybindHelpers." .. tostring(methodName),
            error = tostring(result),
        })
        return false, nil
    end
    return true, result
end

---@param descriptor table?
---@return boolean present
function BETTERUI.Interface.HasKeybindGroup(descriptor)
    if not descriptor then return false end
    local ok, present = InvokeKeybindStrip("HasKeybindButtonGroup", descriptor)
    return ok and present == true
end

---@param descriptor table?
---@return boolean updated
function BETTERUI.Interface.UpdateKeybindGroup(descriptor)
    if not descriptor then return false end
    local ok, updated = InvokeKeybindStrip("UpdateKeybindButtonGroup", descriptor)
    return ok and updated ~= false
end

---@return boolean updated
function BETTERUI.Interface.UpdateCurrentKeybindGroups()
    local ok, updated = InvokeKeybindStrip("UpdateCurrentKeybindButtonGroups")
    return ok and updated ~= false
end

local needsReviewKeybindEnsuring = false

local function EnsureNeedsReviewKeybindGroup(origin)
    if needsReviewKeybindEnsuring then return end
    local commands = BETTERUI.CIM and BETTERUI.CIM.BuilogCommands or nil
    local ensure = commands and commands.EnsureNeedsReviewKeybindGroup or nil
    if type(ensure) ~= "function" then return end
    needsReviewKeybindEnsuring = true
    local ok, ensured, reason = pcall(ensure, origin)
    needsReviewKeybindEnsuring = false
    if not ok then
        WarnKeybindHelper("needs-review keybind ensure failed", {
            fn = "KeybindHelpers.EnsureNeedsReviewKeybindGroup",
            error = tostring(ensured),
        })
    elseif ensured ~= true then
        TraceKeybindHelper("needs-review keybind ensure skipped", {
            fn = "KeybindHelpers.EnsureNeedsReviewKeybindGroup",
            reason = reason,
        })
    end
end

---@param descriptor table?
---@return boolean addedOrUpdated
function BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor)
    if not descriptor then return false end
    if BETTERUI.Interface.HasKeybindGroup(descriptor) then
        BETTERUI.Interface.UpdateKeybindGroup(descriptor)
        EnsureNeedsReviewKeybindGroup("existing-group")
        return true
    end

    local ok, added = InvokeKeybindStrip("AddKeybindButtonGroup", descriptor)
    if ok and added ~= false then
        BETTERUI.Interface.UpdateKeybindGroup(descriptor)
        EnsureNeedsReviewKeybindGroup("add-group")
        return true
    end

    TraceKeybindHelper("keybind group add skipped", {
        fn = "KeybindHelpers.EnsureKeybindGroupAdded",
        hasDescriptor = descriptor ~= nil,
    })
    return false
end

---@param descriptor table?
---@return boolean removed
function BETTERUI.Interface.RemoveKeybindGroupIfPresent(descriptor)
    if not descriptor then return false end
    local strip = GetKeybindStrip()
    if strip and type(strip.HasKeybindButtonGroup) == "function"
        and not BETTERUI.Interface.HasKeybindGroup(descriptor) then
        return false
    end

    local ok, removed = InvokeKeybindStrip("RemoveKeybindButtonGroup", descriptor)
    return ok and removed ~= false
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
    if not ownedGroups then return removed end
    for _, group in ipairs(ownedGroups) do
        if group and group ~= keepDescriptor and BETTERUI.Interface.RemoveKeybindGroupIfPresent(group) then
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
