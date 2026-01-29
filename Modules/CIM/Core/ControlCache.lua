--[[
File: Modules/CIM/Core/ControlCache.lua
Purpose: Provides reusable control caching pattern to avoid repeated GetNamedChild lookups.
         Repeated GetNamedChild calls are a performance concern in UI-heavy modules.
         This utility caches child references at initialization time for efficient access.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ControlCache = {}

--[[
Function: BETTERUI.CIM.ControlCache.Create
Description: Creates a cached child control resolver for a parent control.
Rationale: Avoids repeated GetNamedChild lookups in hot paths (frame updates, cooldown loops).
Mechanism: Returns a closure that caches lookups in a local table.
References: Called during module initialization (e.g., FrontBarManager.CacheControls)
param: parent (control) - The parent UI control
return: function - A function(childName) that returns cached child controls
]]
--- @param parent Control The parent UI control
--- @return fun(childName: string): Control|nil getCachedChild A caching resolver function
function BETTERUI.CIM.ControlCache.Create(parent)
    local cache = {}
    return function(childName)
        if not cache[childName] then
            cache[childName] = parent:GetNamedChild(childName)
        end
        return cache[childName]
    end
end

--[[
Function: BETTERUI.CIM.ControlCache.CacheChildren
Description: Caches multiple named children at once into a lookup table.
Rationale: Bulk caching during initialization is more efficient than on-demand caching.
Mechanism: Iterates through childNames array and populates cache table.
References: Called during module initialization
param: parent (control) - The parent UI control
param: childNames (table) - Array of child control names to cache
return: table - A table mapping child names to cached control references
]]
--- @param parent Control The parent UI control
--- @param childNames string[] Array of child control names to cache
--- @return table<string, Control> cache A table mapping child names to controls
function BETTERUI.CIM.ControlCache.CacheChildren(parent, childNames)
    local cache = {}
    for _, name in ipairs(childNames) do
        cache[name] = parent:GetNamedChild(name)
    end
    return cache
end

--[[
Function: BETTERUI.CIM.ControlCache.CacheButtonChildren
Description: Caches common child controls for a skill bar button.
Rationale: Skill bar buttons have a predictable set of children (Icon, Cooldown, etc.)
Mechanism: Creates a cache table with all standard button children.
References: FrontBarManager, BackBarManager, UltimateManager
param: button (control) - The button control
return: table - A table with cached references to common button children
]]
--- @param button Control The button control
--- @return table<string, Control> children A table with cached button children
function BETTERUI.CIM.ControlCache.CacheButtonChildren(button)
    if not button then return {} end
    return {
        Icon = button:GetNamedChild("Icon"),
        ActivationHighlight = button:GetNamedChild("ActivationHighlight"),
        UnusableOverlay = button:GetNamedChild("UnusableOverlay"),
        ButtonText = button:GetNamedChild("ButtonText"),
        Cooldown = button:GetNamedChild("Cooldown"),
        CooldownEdge = button:GetNamedChild("CooldownEdge"),
        CooldownOverlay = button:GetNamedChild("CooldownOverlay"),
        TimerText = button:GetNamedChild("TimerText"),
        CooldownText = button:GetNamedChild("CooldownText"),
        StackCountText = button:GetNamedChild("StackCountText"),
        FlipCard = button:GetNamedChild("FlipCard"),
        CountText = button:GetNamedChild("CountText"),
        LeftKeybind = button:GetNamedChild("LeftKeybind"),
        RightKeybind = button:GetNamedChild("RightKeybind"),
        Backdrop = button:GetNamedChild("Backdrop"),
        Border = button:GetNamedChild("Border"),
        ReadyBurst = button:GetNamedChild("ReadyBurst"),
        ReadyLoop = button:GetNamedChild("ReadyLoop"),
        Glow = button:GetNamedChild("Glow"),
    }
end
