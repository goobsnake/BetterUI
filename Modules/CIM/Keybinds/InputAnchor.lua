--[[
File: Modules/CIM/Keybinds/InputAnchor.lua
Purpose: Shared input-anchor wrapper for user-fired keybind descriptor callbacks.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Keybinds then BETTERUI.CIM.Keybinds = {} end

local InputAnchor = {}
BETTERUI.CIM.Keybinds.InputAnchor = InputAnchor

local WRAPPED = "_betteruiInputAnchorWrapped"
local ORIGINAL = "_betteruiInputAnchorOriginalCallback"

local function normalizeToken(value, fallback)
    local text = tostring(value or fallback or "keybind")
    text = text:gsub("%s+", "_")
    text = text:gsub("[^%w_%.:%-]", "_")
    text = text:gsub("_+", "_")
    text = text:gsub("^_+", ""):gsub("_+$", "")
    if text == "" then return fallback or "keybind" end
    return text
end

local function resolveModule(options)
    return normalizeToken(options and options.module, "module")
end

local function resolveAction(entry, options)
    if options and options.action ~= nil then
        return normalizeToken(options.action, "keybind")
    end
    if entry and entry.keybind ~= nil then
        return normalizeToken(entry.keybind, "keybind")
    end
    if entry and type(entry.name) == "string" then
        return normalizeToken(entry.name, "keybind")
    end
    return "keybind"
end

local function getLog()
    return BETTERUI and BETTERUI.Log or nil
end

local function enabledFor(L, level)
    return L and type(L.EnabledFor) == "function"
        and L.CATEGORY and L.CATEGORY.KEYBIND
        and L.LEVEL and level
        and L.EnabledFor(level, L.CATEGORY.KEYBIND) == true
end

local function callBoolean(fn)
    local ok, value = pcall(fn)
    if ok then return value == true end
    return nil
end

local function resolveEnabled(entry)
    if not entry then return nil end
    local enabled = entry.enabled
    if type(enabled) == "boolean" then return enabled end
    if type(enabled) == "function" then return callBoolean(enabled) end
    return nil
end

local function resolveGamepad()
    local fn = rawget(_G, "IsInGamepadPreferredMode")
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn)
    if ok then return value == true end
    return nil
end

local function resolveBinding(keybind)
    local fn = rawget(_G, "ZO_Keybindings_GetHighestPriorityBindingStringFromAction")
    if type(fn) ~= "function" or keybind == nil then return nil end
    local ok, value = pcall(fn, keybind)
    if ok and value ~= nil then return tostring(value) end
    return nil
end

local function emitAnchor(entry, moduleName, actionName)
    local L = getLog()
    local infoLevel = L and L.LEVEL and L.LEVEL.INFO
    if not enabledFor(L, infoLevel) then return end

    local keybind = entry and entry.keybind or nil
    local payload = {
        module = moduleName,
        action = actionName,
        keybind = keybind,
        gamepad = resolveGamepad(),
    }
    local enabled = resolveEnabled(entry)
    if enabled ~= nil then payload.enabled = enabled end

    local traceLevel = L.LEVEL and L.LEVEL.TRACE
    if enabledFor(L, traceLevel) then
        payload.binding = resolveBinding(keybind)
    end

    if type(L.SetLastAction) == "function" then
        pcall(L.SetLastAction, moduleName .. "." .. actionName)
    end
    if type(L.TraceEvent) == "function" then
        pcall(L.TraceEvent, L.CATEGORY.KEYBIND, "input.keybind", "fired", payload, infoLevel)
    end
end

---@param descriptorEntry table
---@param options table|nil
---@return table descriptorEntry
function InputAnchor.Wrap(descriptorEntry, options)
    if type(descriptorEntry) ~= "table" then return descriptorEntry end
    if descriptorEntry[WRAPPED] == true then return descriptorEntry end
    local callback = descriptorEntry.callback
    if type(callback) ~= "function" then return descriptorEntry end

    local moduleName = resolveModule(options)
    local actionName = resolveAction(descriptorEntry, options)
    descriptorEntry[ORIGINAL] = callback
    descriptorEntry[WRAPPED] = true
    descriptorEntry.callback = function(...)
        emitAnchor(descriptorEntry, moduleName, actionName)
        return callback(...)
    end
    return descriptorEntry
end

---@param descriptor table
---@param moduleName string
---@return table descriptor
function InputAnchor.WrapGroup(descriptor, moduleName)
    if type(descriptor) ~= "table" then return descriptor end
    for _, entry in ipairs(descriptor) do
        if type(entry) == "table" then
            InputAnchor.Wrap(entry, { module = moduleName })
        end
    end
    return descriptor
end
