--[[
File: Modules/CIM/Core/Window/ControlCache.lua
Purpose: Provides reusable control caching pattern to avoid repeated GetNamedChild lookups.
         Repeated GetNamedChild calls are a performance concern in UI-heavy modules.
         This utility caches child references at initialization time for efficient access.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ControlCache = {}

--- Creates a lazy-caching child control lookup closure.
--- @param parent table The parent UI control
--- @return fun(childName: string): table|nil cacheLookup Cached GetNamedChild lookup
function BETTERUI.CIM.ControlCache.Create(parent)
    local cache = {}
    return function(childName)
        if not cache[childName] then
            cache[childName] = parent:GetNamedChild(childName)
            if cache[childName] == nil and BETTERUI.Log then
                BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, "controlCacheMiss", { childName = childName, hit = false })
            end
        end
        return cache[childName]
    end
end

--- Eagerly caches a list of child controls by name.
--- @param parent table The parent UI control
--- @param childNames string[] Array of child control names to cache
--- @return table<string, table|nil> cache Map of name to control
function BETTERUI.CIM.ControlCache.CacheChildren(parent, childNames)
    local cache = {}
    local nilCount = 0
    for _, name in ipairs(childNames) do
        cache[name] = parent:GetNamedChild(name)
        if cache[name] == nil then nilCount = nilCount + 1 end
    end
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.GENERAL, "cacheChildren", { count = #childNames, nilCount = nilCount }) end
    return cache
end

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
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.GENERAL, "cacheButtonChildren", { nilCount = nilCount }) end
    return cache
end
