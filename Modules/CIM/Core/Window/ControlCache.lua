--[[
File: Modules/CIM/Core/Window/ControlCache.lua
Purpose: Provides reusable control caching pattern to avoid repeated GetNamedChild lookups.
         Repeated GetNamedChild calls are a performance concern in UI-heavy modules.
         This utility caches child references at initialization time for efficient access.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ControlCache = {}

-- BUI-CLEAN-002: the generic Create (lazy lookup closure) and CacheChildren
-- (eager name-list cache) exports were removed as production-dead; the button
-- cache below is the live surface (ControlUtils + skill-bar consumers).

--- Caches all standard button child controls (Icon, Cooldown, StackCount, etc.).
--- @param button table|nil The button control to cache children for
--- @return table<string, table|nil> cache Map of child name to control
function BETTERUI.CIM.ControlCache.CacheButtonChildren(button)
    if not button then return {} end
    local nilCount = 0
    local cache = {
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
    for _, ctrl in pairs(cache) do
        if ctrl == nil then nilCount = nilCount + 1 end
    end
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.GENERAL, "cache button children", { nilCount = nilCount }) end
    return cache
end
