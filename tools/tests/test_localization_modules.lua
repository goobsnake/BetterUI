--[[
File: tools/tests/test_localization_modules.lua
Purpose: Smoke-test all BetterUI localization modules by loading them directly and
         validating shared string coverage.

Usage:
  lua tools/tests/test_localization_modules.lua
]]

if false then
    dofile("lang/en.lua")
    dofile("lang/de.lua")
    dofile("lang/es.lua")
    dofile("lang/fr.lua")
    dofile("lang/jp.lua")
    dofile("lang/ru.lua")
    dofile("lang/zh.lua")
end

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

local function loadLocale(path)
    local strings = {}
    local versions = {}

    function ZO_CreateStringId(id, value)
        strings[id] = value
    end

    function SafeAddString(id, value)
        strings[id] = value
    end

    function SafeAddVersion(id, version)
        versions[id] = version
    end

    dofile(path)
    return strings, versions
end

local locales = {
    { code = "en", path = "lang/en.lua" },
    { code = "de", path = "lang/de.lua" },
    { code = "es", path = "lang/es.lua" },
    { code = "fr", path = "lang/fr.lua" },
    { code = "jp", path = "lang/jp.lua" },
    { code = "ru", path = "lang/ru.lua" },
    { code = "zh", path = "lang/zh.lua" },
}

local requiredKeys = {
    "SI_BETTERUI_LABEL_CAST_BAR",
    "SI_BETTERUI_MARKET_PRICE",
    "SI_BETTERUI_FOOTER_GOLD",
    "SI_BETTERUI_MASTER_SETTINGS_TITLE",
}

for _, locale in ipairs(locales) do
    local strings, versions = loadLocale(locale.path)
    local count = 0
    for _ in pairs(strings) do
        count = count + 1
    end

    assert_true(count > 100, locale.code .. ": registers a broad localization surface")
    for _, key in ipairs(requiredKeys) do
        assert_true(type(strings[key]) == "string" and strings[key] ~= "", locale.code .. ": defines " .. key)
    end
    assert_true(strings.SI_BETTERUI_MARKET_PRICE:find("<<1>>", 1, true) ~= nil,
        locale.code .. ": market-price string preserves the first placeholder")
    assert_true(next(versions) == nil or type(next(versions)) == "string",
        locale.code .. ": optional version metadata loads without errors")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
