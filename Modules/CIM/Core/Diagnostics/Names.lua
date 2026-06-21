--[[
File: Modules/CIM/Core/Diagnostics/Names.lua
Purpose: Cheap, defensive resolvers that turn pointers/indices/userdata into the
         human names a log line needs to be self-describing (control names, parent
         names, scene names, category/sort labels, item names, capped free text).

         Per the logging contract, a message must never carry a raw userdata/index/
         token as its primary identifier. These helpers are allocation-light and must
         only be called behind BETTERUI.Log.EnabledFor(...) (or on WARN/ERROR paths),
         so inert-when-off players pay nothing. Every accessor is pcall-guarded so a
         bad control/handle can never turn a log call into an error.

         ESO controls/scenes are Lua USERDATA (not tables) with __index method tables,
         so every "object" check accepts both "table" and "userdata", and method
         access itself is pcall-guarded (a hostile __index must not raise).
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local Names = {}
BETTERUI.CIM.Names = Names
BETTERUI.Names = Names

local function G(name) return rawget(_G, name) end

-- ESO controls/scenes are userdata; plain mock objects are tables. Accept both.
local function isObject(v)
    local t = type(v)
    return t == "table" or t == "userdata"
end

-- tostring that can never raise (a hostile __tostring must not break a log call).
local function safeTostring(v, fallback)
    local ok, s = pcall(tostring, v)
    if ok and type(s) == "string" then return s end
    return fallback or "<?>"
end
Names.SafeTostring = safeTostring

-- Guarded `obj:method()` for userdata/table: guards BOTH the __index lookup and the
-- call, returns the first result or nil. Never raises.
local function callMethod(obj, methodName)
    local okLookup, method = pcall(function() return obj[methodName] end)
    if not okLookup or type(method) ~= "function" then return nil end
    local okCall, result = pcall(method, obj)
    if okCall then return result end
    return nil
end

--- Resolve a control (or any object with :GetName) to a human name.
--- Strings pass through. Unnamed/unresolvable -> fallback.
---@param control any
---@param fallback string|nil
---@return string
function Names.Control(control, fallback)
    if type(control) == "string" and control ~= "" then return control end
    if isObject(control) then
        local name = callMethod(control, "GetName")
        if type(name) == "string" and name ~= "" then return name end
    end
    return fallback or "<unnamed>"
end

--- Nearest named parent of a control.
---@param control any
---@return string
function Names.Parent(control)
    if not isObject(control) then return "<none>" end
    local parent = callMethod(control, "GetParent")
    if parent ~= nil then return Names.Control(parent, "<anonymous>") end
    return "<none>"
end

--- Resolve a ZO_Scene (or scene name) to its name.
---@param scene any
---@return string
function Names.Scene(scene)
    if type(scene) == "string" and scene ~= "" then return scene end
    if isObject(scene) then
        local name = callMethod(scene, "GetName")
        if type(name) == "string" and name ~= "" then return name end
    end
    return "<unknown>"
end

--- Resolve a category INDEX to its display name from a list of entries shaped like
--- { name=... } / { displayName=... } / { text=... } / plain strings.
---@param categories table|nil
---@param index number|nil
---@param fallback string|nil
---@return string
function Names.Category(categories, index, fallback)
    if type(categories) == "table" and type(index) == "number" then
        local entry = categories[index]
        if type(entry) == "table" then
            local n = entry.name or entry.displayName or entry.text or entry.label
            if type(n) == "string" and n ~= "" then return n end
        elseif type(entry) == "string" and entry ~= "" then
            return entry
        end
    end
    return fallback or ("category[" .. safeTostring(index) .. "]")
end

--- Sort label: a key plus an optional direction (true=desc / false=asc, or a string).
---@param key any
---@param direction any|nil
---@return string
function Names.Sort(key, direction)
    local label = safeTostring(key)
    if direction ~= nil then
        local dir = direction
        if dir == true then dir = "desc" elseif dir == false then dir = "asc" end
        label = label .. " " .. safeTostring(dir)
    end
    return label
end

--- Item display name from bag/slot via the ESO API, with markup stripped when possible.
---@param bagId number|nil
---@param slotIndex number|nil
---@param fallback string|nil
---@return string
function Names.Item(bagId, slotIndex, fallback)
    local getName = G("GetItemName")
    if type(getName) == "function" and bagId ~= nil and slotIndex ~= nil then
        local ok, name = pcall(getName, bagId, slotIndex)
        if ok and type(name) == "string" and name ~= "" then
            local fmt = G("zo_strformat")
            if type(fmt) == "function" then
                local ok2, clean = pcall(fmt, "<<1>>", name)
                if ok2 and type(clean) == "string" and clean ~= "" then return clean end
            end
            return name
        end
    end
    return fallback or ("item[" .. safeTostring(bagId) .. ":" .. safeTostring(slotIndex) .. "]")
end

--- Flatten free text to a single greppable line (no newlines/tabs) and neutralize the
--- pipe -- '|' is the host log's field separator, so a raw pipe in a value (item names
--- with colour codes, free text) would break the line's parse contract. Never raises.
---@param text any
---@return string
function Names.FlattenText(text)
    local s = (safeTostring(text):gsub("[\r\n\t]+", " "))
    s = (s:gsub("|[cC]%x%x%x%x%x%x", "")) -- strip ESO colour-open codes (either case)
    s = (s:gsub("|[rR]", ""))             -- strip ESO colour-reset codes (either case)
    s = (s:gsub("|", "/"))             -- neutralize any remaining pipe (field separator)
    return s
end

--- Bounded preview of free text (e.g. search strings): flattened + capped.
--- Returns the preview and the original length so callers can log searchLen too.
---@param text any
---@param maxChars number|nil  default 32
---@return string preview, number length
function Names.PreviewText(text, maxChars)
    local flat = Names.FlattenText(text)
    local len = #flat
    maxChars = (type(maxChars) == "number" and maxChars > 0) and maxChars or 32
    if len > maxChars then flat = flat:sub(1, maxChars) .. "..." end
    return flat, len
end
