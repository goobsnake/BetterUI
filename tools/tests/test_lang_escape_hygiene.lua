--[[
File: tools/tests/test_lang_escape_hygiene.lua
Purpose: Guard lang/*.lua against escape syntax ESO's Lua 5.1 runtime cannot
         parse (regression: an external localization writer emitted Lua 5.3
         \u{XXXX} escapes, Lua 5.2 \xNN escapes, and double-escaped \\ddd
         sequences, plus Latin-1 bytes instead of UTF-8).
         Scans the files as raw text so the verdict does not depend on the
         host interpreter's own escape support (host Lua 5.3+ would happily
         load syntax the game rejects).

Usage:
  lua tools/tests/test_lang_escape_hygiene.lua
]]

local passed, failed = 0, 0

local function fail(msg)
    failed = failed + 1
    print("  FAIL: " .. msg)
end

local function check(ok, msg)
    if ok then
        passed = passed + 1
    else
        fail(msg)
    end
end

-- Escapes valid in ESO's Lua 5.1 string literals: \a \b \f \n \r \t \v
-- \" \' \\ \<actual newline> and decimal \ddd (handled separately).
local VALID_SINGLE = {
    a = true, b = true, f = true, n = true, r = true, t = true, v = true,
    ["\""] = true, ["'"] = true, ["\n"] = true, ["\r"] = true,
}

local function lineOf(text, offset)
    local _, count = text:sub(1, offset):gsub("\n", "")
    return count + 1
end

-- Returns the number of escape problems found (0 = clean).
local function scanEscapes(code, text)
    local problems = 0
    local i = 1
    while true do
        local s = text:find("\\", i, true)
        if not s then
            break
        end
        local c = text:sub(s + 1, s + 1)
        local where = code .. ".lua:" .. lineOf(text, s)
        if c == "" then
            fail(where .. ": dangling backslash at end of file")
            problems = problems + 1
        elseif c == "u" then
            fail(where .. ": Lua 5.3 \\u{...} escape (ESO Lua 5.1 cannot parse it; use raw UTF-8)")
            problems = problems + 1
        elseif c == "x" then
            fail(where .. ": Lua 5.2 \\x hex escape (ESO Lua 5.1 cannot parse it; use raw UTF-8)")
            problems = problems + 1
        elseif c == "\\" then
            if text:sub(s + 2, s + 2):match("%d") then
                fail(where .. ": double-escaped \\\\ddd sequence (localization-writer corruption)")
                problems = problems + 1
            end
        elseif not c:match("%d") and not VALID_SINGLE[c] then
            fail(where .. ": escape \\" .. c .. " is not valid in ESO Lua 5.1")
            problems = problems + 1
        end
        i = s + 2
    end
    return problems
end

-- Returns byte offset of the first invalid UTF-8 sequence, or nil if clean.
-- Catches Latin-1 bytes (e.g. a lone 0xFC for "ü") that render as garbage.
local function utf8ErrorOffset(text)
    local i, n = 1, #text
    while i <= n do
        local b = text:byte(i)
        local extra
        if b < 0x80 then
            extra = 0
        elseif b >= 0xC2 and b <= 0xDF then
            extra = 1
        elseif b >= 0xE0 and b <= 0xEF then
            extra = 2
        elseif b >= 0xF0 and b <= 0xF4 then
            extra = 3
        else
            return i
        end
        for k = 1, extra do
            local cb = text:byte(i + k)
            if not cb or cb < 0x80 or cb > 0xBF then
                return i
            end
        end
        i = i + 1 + extra
    end
    return nil
end

local function hasNonAscii(text)
    return text:find("[\128-\255]") ~= nil
end

local locales = { "en", "de", "es", "fr", "jp", "ru", "zh" }

for _, code in ipairs(locales) do
    local path = "lang/" .. code .. ".lua"
    local handle = io.open(path, "rb")
    check(handle ~= nil, code .. ": " .. path .. " is readable")
    if handle then
        local text = handle:read("*a")
        handle:close()

        check(scanEscapes(code, text) == 0, code .. ": only ESO Lua 5.1-safe escapes")

        local badOffset = utf8ErrorOffset(text)
        check(badOffset == nil, code .. ": valid UTF-8"
            .. (badOffset and (" (first bad byte at " .. code .. ".lua:" .. lineOf(text, badOffset) .. ")") or ""))

        if code ~= "en" then
            check(hasNonAscii(text), code .. ": contains raw UTF-8 translations "
                .. "(an ASCII-only file means translations were escaped or stripped)")
        end
    end
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
