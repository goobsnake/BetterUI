--[[
File: tools/lint/lint_log_messages.lua
Purpose: Static convention check for the logging message contract. Flags TERSE log
         messages -- a string literal that is a single identifier token (camelCase /
         snake_case, no spaces, e.g. "enterSearch", "savePosition") -- which read as
         function names rather than self-describing events. Self-describing messages
         carry a space (a phrase) or a structured separator (": ", " -> ", " | ").

         The message contract (docs/reference/logging-observability-strategy.md):
           <area>: <what happened> [-> <named value>]
         e.g. "category change started -> index 3", not "startCategoryChange".

Usage:
  lua tools/lint/lint_log_messages.lua <file.lua> [<file.lua> ...]
  # from repo root, scan all module sources:
  lua tools/lint/lint_log_messages.lua $(find Modules -name '*.lua')

Exit code: 0 = clean, 1 = terse messages found (CI-friendly).

A literal that is genuinely a fine short message (rare) can be allow-listed in ALLOW.
]]

-- Messages that are intentionally short + acceptable (state verbs, etc.).
local ALLOW = {
    showing = true, shown = true, hiding = true, hidden = true,
}

-- Log.<Level>(<category>, "<message>"  -- capture the message literal (2nd positional).
-- Levels that take (category, message, ...): Trace/Debug/Info/Warn/Error.
local CALL = '[Ll]og%.[TDIWE][a-z]+%s*%(%s*[%w_%.]+%s*,%s*"([^"]*)"'

-- A "terse" message: a single identifier token (letters/digits/underscore), no space,
-- no sentence punctuation. "enterSearch" matches; "filter list by 'x'" does not.
local function isTerse(msg)
    if msg == "" then return false end
    if ALLOW[msg] then return false end
    if msg:find("%s") then return false end          -- has a space -> a phrase
    if msg:find("[:|>]") then return false end        -- structured separator
    return msg:match("^[%a_][%w_]*$") ~= nil          -- a bare identifier token
end

local files = {}
for i = 1, #arg do files[#files + 1] = arg[i] end
if #files == 0 then
    -- No args: default to scanning all module sources (so CI / the test harness can run
    -- it with no arguments). Falls back to a usage error if the shell scan is unavailable.
    local ok, pipe = pcall(io.popen, "find Modules -name '*.lua' 2>/dev/null")
    if ok and pipe then
        for p in pipe:lines() do files[#files + 1] = p end
        pipe:close()
    end
end
if #files == 0 then
    io.stderr:write("usage: lua tools/lint/lint_log_messages.lua <file.lua> [...]\n")
    os.exit(2)
end

local total = 0
local byDir = {}
local function dirOf(path)
    local d = path:match("^Modules/([^/]+)") or path:match("([^/]+)/[^/]+$") or path
    return d
end
for _, path in ipairs(files) do
    local fh = io.open(path, "r")
    if fh then
        local lineNo = 0
        for line in fh:lines() do
            lineNo = lineNo + 1
            for msg in line:gmatch(CALL) do
                if isTerse(msg) then
                    total = total + 1
                    byDir[dirOf(path)] = (byDir[dirOf(path)] or 0) + 1
                    print(string.format("%s:%d: terse log message %q -- make it self-describing", path, lineNo, msg))
                end
            end
        end
        fh:close()
    end
end

if total > 0 then
    local dirs = {}
    for d in pairs(byDir) do dirs[#dirs + 1] = d end
    table.sort(dirs, function(a, b) return byDir[a] > byDir[b] end)
    print("\n-- per top-level module dir --")
    for _, d in ipairs(dirs) do print(string.format("  %4d  %s", byDir[d], d)) end
end

if total > 0 then
    print(string.format("\n%d terse log message(s) found. Messages should be self-describing phrases.", total))
    os.exit(1)
else
    print("OK: no terse log messages found.")
    os.exit(0)
end
