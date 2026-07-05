--[[
File: tools/tests/test_settings_surface_source.lua
Purpose: Source-level audit for settings surface defaults, reset coverage, and
         localization references.

Usage:
  lua tools/tests/test_settings_surface_source.lua
]]

local passed, failed = 0, 0

local function readFile(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function check(condition, label)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. label)
    end
end

local function assertContains(haystack, needle, label)
    check(haystack:find(needle, 1, true) ~= nil, label .. " (missing " .. needle .. ")")
end

local function assertNotContains(haystack, needle, label)
    check(haystack:find(needle, 1, true) == nil, label .. " (unexpected " .. needle .. ")")
end

local function loadLocale(path)
    local strings = {}

    function ZO_CreateStringId(id, value)
        strings[id] = value
    end

    function SafeAddString(id, value)
        strings[id] = value
    end

    function SafeAddVersion()
    end

    dofile(path)
    return strings
end

local function addSourceFile(files, seen, path)
    path = path:gsub("\\", "/")
    if path:match("%.lua$") and not path:match("^lang/") and not seen[path] then
        files[#files + 1] = path
        seen[path] = true
    end
end

local function isConcreteStringId(id)
    return id:sub(-1) ~= "_"
end

print("test_settings_surface_source")

local manifest = readFile("BetterUI.txt")
local sourceFiles = {}
local seenSourceFiles = {}
for line in manifest:gmatch("[^\r\n]+") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    addSourceFile(sourceFiles, seenSourceFiles, line)
end
addSourceFile(sourceFiles, seenSourceFiles, "BetterUI.lua")

local referencedStringIds = {}
local referencedFrom = {}
for _, path in ipairs(sourceFiles) do
    local ok, source = pcall(readFile, path)
    if ok then
        for id in source:gmatch("SI_BETTERUI_[A-Z0-9_]+") do
            if isConcreteStringId(id) then
                referencedStringIds[id] = true
                referencedFrom[id] = referencedFrom[id] or path
            end
        end
    end
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

for _, locale in ipairs(locales) do
    local strings = loadLocale(locale.path)
    for id in pairs(referencedStringIds) do
        local value = strings[id]
        check(type(value) == "string" and value ~= "",
            string.format("%s defines referenced string %s from %s", locale.code, id, referencedFrom[id] or "unknown"))
    end

    assertContains(strings.SI_BETTERUI_BUILOG_SETTINGS_HEADER or "", "Builog (Debug)",
        locale.code .. " keeps the Builog settings header debug qualifier")
    assertNotContains((strings.SI_BETTERUI_ENHANCED_TOOLTIPS_DESC or ""):lower(), "market",
        locale.code .. " Enhanced Tooltips description does not claim market integration ownership")
end

local defaultsRegistry = readFile("Modules/CIM/Core/Settings/DefaultsRegistry.lua")
local settingsResetTests = readFile("tools/tests/test_settings_reset.lua")
local settingsMetadata = readFile("Modules/CIM/Core/Settings/SettingsMetadata.lua")
local generalSettings = readFile("Modules/GeneralInterface/Tooltips/Settings.lua")
local bootstrap = readFile("BetterUI.lua")

local builogDefaultKeys = {
    "interfaceLogEnabled = false",
    "interfaceLogPreset = \"\"",
    "interfaceLogMinLevel = \"\"",
    "interfaceLogScreenshotAutoMode = \"off\"",
    "interfaceLogChat = false",
    "interfaceLogSuppressPopups = true",
    "interfaceLogPrivacy = false",
}

for _, needle in ipairs(builogDefaultKeys) do
    assertContains(defaultsRegistry, needle, "Builog persisted setting has a CIM default: " .. needle)
    assertContains(settingsResetTests, needle, "Settings reset tests assert Builog default: " .. needle)
end

assertContains(settingsMetadata, "tooltipStringId = SI_BETTERUI_REMOVE_DELETE_WARNING",
    "Mail delete confirmation metadata has hover text")
assertContains(generalSettings, "tooltip = GetString(rawget(_G, \"SI_BETTERUI_REMOVE_DELETE_WARNING\"))",
    "Mail delete confirmation control exposes hover text")

local builogPanelStart = assert(bootstrap:find("local function AppendBuilogSettingsPanel", 1, true))
local builogPanelEnd = assert(bootstrap:find("function BETTERUI.InitModuleOptions", builogPanelStart, true))
local builogPanel = bootstrap:sub(builogPanelStart, builogPanelEnd)
local function controlBlock(source, firstMarker, nextMarker)
    local blockStart = assert(source:find(firstMarker, 1, true))
    local blockEnd = assert(source:find(nextMarker, blockStart, true))
    return source:sub(blockStart, blockEnd)
end
local builogPresetControl = controlBlock(builogPanel, "SI_BETTERUI_BUILOG_PRESET", "SI_BETTERUI_BUILOG_MIN_LEVEL")
local builogMinLevelControl = controlBlock(builogPanel, "SI_BETTERUI_BUILOG_MIN_LEVEL", "SI_BETTERUI_BUILOG_SCREENSHOT_AUTO")
local builogScreenshotControl = controlBlock(builogPanel, "SI_BETTERUI_BUILOG_SCREENSHOT_AUTO", "type = \"description\"")
assertContains(builogPanel, "default = false", "Builog enabled setting has explicit LAM default")
assertContains(builogPresetControl, "default = \"off\"", "Builog preset setting has explicit LAM reset default")
assertContains(builogMinLevelControl, "default = \"trace\"", "Builog minimum level setting matches logger fallback default")
assertContains(builogScreenshotControl, "default = \"off\"", "Builog screenshot auto setting has explicit LAM default")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
