--[[
File: Modules/CIM/Core/Diagnostics/Log.lua
Purpose: Unified BetterUI logging facade. Routes leveled, categorized records to
         pluggable sinks. Default routing sends EVERYTHING to the file sink
         (Interface.log) and nothing to chat/popup -- i.e. suppressed-by-default,
         surfaceable on demand via /builog.

Design:
  - Levels: TRACE < DEBUG < INFO < WARN < ERROR.
  - Categories gate instrumentation noise (SCENE/LIST/NAV/...); WARN/ERROR always pass.
  - Sinks: file (Interface.log via InterfaceLog), chat (colored d()). Per-level on/off.
  - Popup surfacing is the global InterfaceLog suppression toggle (errors + file writes
    pop only when popups are enabled); see /builog popups.
  - The logger is INERT unless logging is active (InterfaceLog or CIM.Debug enabled), so
    normal players incur zero cost and see no behavior change.
  - BETTERUI.Debug / DebugError / CIM.Debug.Log become thin wrappers over this, and
    SafeExecute routes caught errors through Log.Error("SAFE", ...).
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local Log = {}
BETTERUI.Log = Log
BETTERUI.CIM.Log = Log

Log.LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 }
local LEVEL_NAME = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }

-- Canonical categories (callers may pass any string; these are the documented set).
Log.CATEGORY = {
    SCENE = "SCENE", LIST = "LIST", NAV = "NAV", KEYBIND = "KEYBIND", FOOTER = "FOOTER",
    CATEGORY = "CATEGORY", SEARCH = "SEARCH", SORT = "SORT", BATCH = "BATCH",
    ACTION = "ACTION", LIFECYCLE = "LIFECYCLE", SAFE = "SAFE", SETTINGS = "SETTINGS",
    GENERAL = "GENERAL",
}

-- Configuration -------------------------------------------------------------
local minLevel = Log.LEVEL.TRACE

-- Per-level sink masks. Default: file ON, chat OFF (popup is the global suppression toggle).
local function defaultMask() return { file = true, chat = false } end
local sinks = {}
for i = 1, #LEVEL_NAME do sinks[i] = defaultMask() end

-- Categories switched off here drop TRACE/DEBUG records; WARN/ERROR ignore this gate.
local categoryDisabled = {}

local function G(name) return rawget(_G, name) end

-- The logger only does work when the user has opted into logging.
local function isActive()
    local cim = BETTERUI.CIM
    if not cim then return false end
    local il = cim.InterfaceLog
    if il and il.IsEnabled and il.IsEnabled() then return true end
    local dbg = cim.Debug
    if dbg and dbg.IsEnabled and dbg.IsEnabled() then return true end
    return false
end

-- Sinks ---------------------------------------------------------------------
local function sinkFile(line)
    local il = BETTERUI.CIM and BETTERUI.CIM.InterfaceLog
    if il and il.WriteRaw then return il.WriteRaw(line) end
    if il and il.Write then return il.Write(line) end
end

local function sinkChat(category, text)
    local chat = G("d")
    if type(chat) == "function" then
        chat(string.format("|c0066ff[BUI:%s]|r %s", category, text))
    end
end

-- High-density value summary (#7): compact shape, never a full table/array dump.
---@param value any
---@return string
function Log.Summarize(value)
    local t = type(value)
    if t == "table" then
        local len = #value
        local keyCount = 0
        for _ in pairs(value) do keyCount = keyCount + 1 end
        if len > 0 and len == keyCount then
            return string.format("[%d]", len)
        end
        local keys = {}
        for k in pairs(value) do
            keys[#keys + 1] = tostring(k)
            if #keys >= 5 then break end
        end
        return string.format("{%d:%s%s}", keyCount, table.concat(keys, ","), keyCount > 5 and ",.." or "")
    elseif t == "string" then
        if #value > 80 then return '"' .. value:sub(1, 80) .. '..."' end
        return '"' .. value .. '"'
    elseif t == "userdata" then
        local getName = value.GetName
        if type(getName) == "function" then
            local ok, name = pcall(getName, value)
            if ok and name and name ~= "" then return "<ctrl:" .. tostring(name) .. ">" end
        end
        return "<userdata>"
    end
    return tostring(value)
end

-- Core emit -----------------------------------------------------------------
local function emit(level, category, message, data)
    if not isActive() then return end
    if level < minLevel then return end
    category = category or Log.CATEGORY.GENERAL
    if level <= Log.LEVEL.DEBUG and categoryDisabled[category] then return end

    local clock = G("GetGameTimeMilliseconds")
    local ts = type(clock) == "function" and clock() or 0
    local text = tostring(message)
    if data ~= nil then text = text .. " " .. Log.Summarize(data) end

    local mask = sinks[level]
    if mask.file then
        sinkFile(string.format("[BUI] %d %s %s | %s", ts, LEVEL_NAME[level], category, text))
    end
    if mask.chat then
        sinkChat(category, text)
    end
end

---@param level number  one of Log.LEVEL
---@param category string
---@param message any
---@param data any|nil   optional structured value, summarized via Log.Summarize
function Log.Write(level, category, message, data) emit(level, category, message, data) end
function Log.Trace(category, message, data) emit(Log.LEVEL.TRACE, category, message, data) end
function Log.Debug(category, message, data) emit(Log.LEVEL.DEBUG, category, message, data) end
function Log.Info(category, message, data)  emit(Log.LEVEL.INFO,  category, message, data) end
function Log.Warn(category, message, data)  emit(Log.LEVEL.WARN,  category, message, data) end
function Log.Error(category, message, data) emit(Log.LEVEL.ERROR, category, message, data) end

-- Configuration API ---------------------------------------------------------
function Log.SetMinLevel(level)
    if type(level) == "number" and LEVEL_NAME[level] then minLevel = level end
end

function Log.GetMinLevel() return minLevel end

---@param level number
---@param sinkName string "file" | "chat"
---@param on boolean
function Log.SetSink(level, sinkName, on)
    if sinks[level] and (sinkName == "file" or sinkName == "chat") then
        sinks[level][sinkName] = on and true or false
    end
end

---@param level number
---@param sinkName string
---@return boolean
function Log.GetSink(level, sinkName)
    return sinks[level] and sinks[level][sinkName] == true or false
end

---@param category string
---@param on boolean
function Log.SetCategoryEnabled(category, on)
    categoryDisabled[category] = (on and nil) or true
end

---@param category string
---@return boolean
function Log.IsCategoryEnabled(category)
    return not categoryDisabled[category]
end

--- Resolve a level number from a name like "warn" (case-insensitive). nil if unknown.
---@param name string
---@return number|nil
function Log.LevelFromName(name)
    if type(name) ~= "string" then return nil end
    return Log.LEVEL[name:upper()]
end

--- Whether logging is currently active (the user enabled InterfaceLog or debug).
--- Cheap gate for HOT paths: check this before building an expensive log payload
--- so normal players (logging off) pay nothing, e.g.
---   if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(cat, msg, heavy()) end
---@return boolean
function Log.IsActive() return isActive() end
