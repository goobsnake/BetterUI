--[[
File: tools/tests/test_trading_house_browse_filters.lua
Purpose: Unit tests for Trading House browse filter pure helpers (TRC-003).
Usage:
  lua tools/tests/test_trading_house_browse_filters.lua
]]

BETTERUI = {
    TradingHouse = {},
    CIM = {},
    Log = nil,
}

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

local function assert_not_nil(value, label)
    assert_eq(value ~= nil, true, label)
end

-- ENGINE / FRAMEWORK STUBS ---------------------------------------------------

function BETTERUI.CIM.UserAlertText(id, text)
    -- no-op for tests
end

TRADING_HOUSE_FILTER_TYPE_PRICE = 1
TRADING_HOUSE_FILTER_TYPE_NAME_HASH = 2
TRADING_HOUSE_FILTER_TYPE_LEVEL = 3
TRADING_HOUSE_FILTER_TYPE_CHAMPION_POINTS = 4
TRADING_HOUSE_FILTER_TYPE_QUALITY = 5

MIN_TRADING_HOUSE_POST_PRICE = 1
MAX_PLAYER_CURRENCY = 999999999

function zo_clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

function GetString(stringId)
    return tostring(stringId)
end

function rawget(t, k)
    return t[k]
end

function GetMaxLevel()
    return 50
end

function GetChampionPointsPlayerProgressionCap()
    return 3600
end

local matchResults = {}
local maxExactTerms = 5
function GetNumMatchTradingHouseItemNamesResults(taskId)
    local results = matchResults[taskId]
    return results and #results or 0
end
function GetMatchTradingHouseItemNamesResult(taskId, index)
    local results = matchResults[taskId]
    local entry = results and results[index]
    if entry then
        return entry.name, entry.hash
    end
    return nil, nil
end
function GetMaxTradingHouseFilterExactTerms(filterType)
    return maxExactTerms
end

local appliedFilters = {}
local mockSearch = {
    SetFilterRange = function(self, filterType, min, max)
        table.insert(appliedFilters, { type = "range", filterType = filterType, min = min, max = max })
    end,
    SetFilter = function(self, filterType, values)
        table.insert(appliedFilters, { type = "exact", filterType = filterType, values = values })
    end,
}

local appliedEngineFilters = {}
function SetTradingHouseFilter(filterType, ...)
    table.insert(appliedEngineFilters, { filterType = filterType, values = { ... } })
end
function SetTradingHouseFilterRange(filterType, min, max)
    table.insert(appliedEngineFilters, { filterType = filterType, min = min, max = max })
end

local function resetState()
    appliedFilters = {}
    appliedEngineFilters = {}
    matchResults = {}
end

-- LOAD PRODUCTION SOURCE -----------------------------------------------------

dofile("Modules/TradingHouse/Core/BrowseFilters.lua")
local Filters = BETTERUI.TradingHouse.BrowseFilters

-- TESTS ----------------------------------------------------------------------

print("[BuildPriceRangeFilter]")
resetState()
local f = Filters.BuildPriceRangeFilter(100, 500)
assert_true(f.valid, "Valid range is valid")
assert_eq(f.min, 100, "Min preserved")
assert_eq(f.max, 500, "Max preserved")
assert_eq(f.filterType, TRADING_HOUSE_FILTER_TYPE_PRICE, "Uses price filter type")

f = Filters.BuildPriceRangeFilter(500, 100)
assert_eq(f.min, 100, "Swapped min")
assert_eq(f.max, 500, "Swapped max")

f = Filters.BuildPriceRangeFilter(nil, 500)
assert_true(f.valid, "Max-only range is valid")
assert_eq(f.min, nil, "Nil min stays nil")
assert_eq(f.max, 500, "Max-only max preserved")

f = Filters.BuildPriceRangeFilter(-10, 0)
assert_eq(f.valid, false, "Non-positive bounds are invalid")

f = Filters.BuildPriceRangeFilter(0, MAX_PLAYER_CURRENCY + 1000)
assert_eq(f.max, MAX_PLAYER_CURRENCY, "Max clamped to engine ceiling")

print("[NormalizeLevelFilter]")
resetState()
local minLevel, maxLevel, isCP = Filters.NormalizeLevelFilter(10, 40, false)
assert_eq(minLevel, 10, "Normal min preserved")
assert_eq(maxLevel, 40, "Normal max preserved")
assert_eq(isCP, false, "Normal flag preserved")

minLevel, maxLevel, isCP = Filters.NormalizeLevelFilter(60, 5, false)
assert_eq(minLevel, 5, "Swapped normal min")
assert_eq(maxLevel, 50, "Clamped normal max to GetMaxLevel")

minLevel, maxLevel, isCP = Filters.NormalizeLevelFilter(-10, 4000, true)
assert_eq(minLevel, 0, "CP min clamped to 0")
assert_eq(maxLevel, 3600, "CP max clamped to cap")
assert_eq(isCP, true, "CP flag preserved")

minLevel, maxLevel, isCP = Filters.NormalizeLevelFilter(nil, nil, false)
assert_eq(minLevel, 0, "Nil normal min defaults to 0")
assert_eq(maxLevel, 50, "Nil normal max defaults to GetMaxLevel")

print("[ApplyFilterTable]")
resetState()
Filters.ApplyFilterTable(mockSearch, { filterType = TRADING_HOUSE_FILTER_TYPE_PRICE, min = 100, max = 200 })
assert_eq(#appliedFilters, 1, "Range filter applied via search object")
assert_eq(appliedFilters[1].type, "range", "Range path used")
assert_eq(appliedFilters[1].min, 100, "Range min forwarded")

Filters.ApplyFilterTable(mockSearch, { filterType = TRADING_HOUSE_FILTER_TYPE_NAME_HASH, values = { 1, 2, 3 } })
assert_eq(#appliedFilters, 2, "Multi-value filter applied via search object")
assert_eq(appliedFilters[2].type, "exact", "Exact path used")
assert_eq(#appliedFilters[2].values, 3, "All hashes forwarded")

-- Force fallback to engine API by passing no search object.
Filters.ApplyFilterTable(nil, { filterType = TRADING_HOUSE_FILTER_TYPE_LEVEL, min = 10, max = 20 })
assert_eq(#appliedEngineFilters, 1, "Range filter applied via engine fallback")
assert_eq(appliedEngineFilters[1].filterType, TRADING_HOUSE_FILTER_TYPE_LEVEL, "Engine filter type forwarded")

print("[SetBrowseFilterSpec + ApplyPendingFilters]")
resetState()

local nameTextSet = nil
local priceRangeSet = nil
local qualityChoice = nil
local categoryChoice = nil

GAMEPAD_TRADING_HOUSE_BROWSE = {
    features = {
        nameSearchFeature = {
            SetSearchText = function(self, text) nameTextSet = text end,
            ResetSearch = function(self) self.resetCount = (self.resetCount or 0) + 1 end,
        },
        priceRangeFeature = {
            SetPriceRange = function(self, min, max) priceRangeSet = { min = min, max = max } end,
            ResetSearch = function(self) self.resetCount = (self.resetCount or 0) + 1 end,
        },
        qualityFeature = {
            SelectChoice = function(self, index) qualityChoice = index end,
            ResetSearch = function(self) self.resetCount = (self.resetCount or 0) + 1 end,
        },
        searchCategoryFeature = {
            SelectChoice = function(self, index) categoryChoice = index end,
            ResetSearch = function(self) self.resetCount = (self.resetCount or 0) + 1 end,
        },
    }
}
TRADING_HOUSE_SEARCH = mockSearch

local ok = Filters.SetBrowseFilterSpec({
    nameText = "rubedite",
    priceMin = 1000,
    priceMax = 5000,
    qualityIndex = 3,
    categoryIndex = 2,
    levelMin = 10,
    levelMax = 40,
    isChampionRank = false,
})
assert_true(ok, "SetBrowseFilterSpec succeeds when features are present")
assert_eq(nameTextSet, "rubedite", "Name text passed to native feature")
assert_not_nil(priceRangeSet, "Price range passed to native feature")
assert_eq(qualityChoice, 3, "Quality choice passed to native feature")
assert_eq(categoryChoice, 2, "Category choice passed to native feature")

local methodFeatures = GAMEPAD_TRADING_HOUSE_BROWSE.features
GAMEPAD_TRADING_HOUSE_BROWSE = {
    GetFeatures = function() return methodFeatures end,
}
nameTextSet = nil
assert_true(Filters.SetBrowseFilterSpec({ nameText = "ancestor silk" }),
    "GetFeatures method exposes native browse features")
assert_eq(nameTextSet, "ancestor silk", "GetFeatures result drives native name filter")

Filters.pendingSpec = { levelMin = 10, levelMax = 20 }
local associatedResetFeatures = nil
TRADING_HOUSE_SEARCH.AssociateWithSearchFeatures = function(_, features)
    associatedResetFeatures = features
end
assert_true(Filters.ResetSearch(), "ResetSearch clears every native browse feature")
assert_eq(Filters.pendingSpec, nil, "ResetSearch clears BetterUI-only pending filters")
assert_eq(methodFeatures.nameSearchFeature.resetCount, 1, "ResetSearch clears the persistent name field")
assert_eq(methodFeatures.searchCategoryFeature.resetCount, 1, "ResetSearch clears the selected category")
assert_eq(methodFeatures.qualityFeature.resetCount, 1, "ResetSearch clears the selected quality")
assert_eq(methodFeatures.priceRangeFeature.resetCount, 1, "ResetSearch clears the selected price range")
assert_eq(associatedResetFeatures, methodFeatures,
    "ResetSearch re-associates the exact edited feature set with TRADING_HOUSE_SEARCH")
Filters.SetBrowseFilterSpec({
    levelMin = 10,
    levelMax = 40,
    isChampionRank = false,
})

GAMEPAD_TRADING_HOUSE_BROWSE = nil
local createdFeatureKeys = {}
local associatedFeatures = nil
ZO_TradingHouse_CreateGamepadFeature = function(key)
    createdFeatureKeys[#createdFeatureKeys + 1] = key
    return { ResetSearch = function() end }
end
TRADING_HOUSE_SEARCH.AssociateWithSearchFeatures = function(_, features)
    associatedFeatures = features
end
local standaloneFeatures = Filters._GetBrowseFeatures()
assert_not_nil(standaloneFeatures, "standalone native feature set is created")
assert_eq(#createdFeatureKeys, 4, "all four ESOUI gamepad browse features are created")
assert_eq(associatedFeatures, standaloneFeatures,
    "standalone features are associated with TRADING_HOUSE_SEARCH")

Filters.ApplyPendingFilters(TRADING_HOUSE_SEARCH)
assert_eq(#appliedFilters, 1, "Pending level filter applied directly")
assert_eq(appliedFilters[1].filterType, TRADING_HOUSE_FILTER_TYPE_LEVEL, "Pending level filter uses LEVEL type")
assert_eq(appliedFilters[1].min, 10, "Pending level min applied")
assert_eq(appliedFilters[1].max, 40, "Pending level max applied")

resetState()
Filters.SetBrowseFilterSpec({
    levelMin = 100,
    levelMax = 200,
    isChampionRank = true,
})
Filters.ApplyPendingFilters(TRADING_HOUSE_SEARCH)
assert_eq(appliedFilters[1].filterType, TRADING_HOUSE_FILTER_TYPE_CHAMPION_POINTS, "CP flag switches filter type")

print("[Native hierarchy and input lifecycle source contract]")
local sourceFile = assert(io.open("Modules/TradingHouse/Core/BrowseFilterDialog.lua", "r"))
local filterSource = sourceFile:read("*a")
sourceFile:close()
assert_true(filterSource:find("CaptureNativeFeatureEntries", 1, true) ~= nil,
    "filter dialog captures native progressive feature rows")
assert_true(filterSource:find("features.searchCategoryFeature", 1, true) ~= nil,
    "category feature drives contextual child filters")
assert_true(filterSource:find("ZO_GAMEPAD_COMBO_BOX_HIGHLIGHTED_FONT", 1, true) ~= nil,
    "focused dropdown uses the native highlighted font")
assert_true(filterSource:find("ZO_GAMEPAD_COMBO_BOX_FONT", 1, true) ~= nil,
    "unfocused dropdown uses the native normal font")
assert_true(filterSource:find("finishedCallback = function(dialog)", 1, true) ~= nil,
    "filter dialog has unconditional input cleanup")
assert_true(filterSource:find("_activeDropdown", 1, true) ~= nil,
    "active dropdown ownership is tracked across dialog close")
assert_true(filterSource:find("_ownedDropdowns", 1, true) ~= nil,
    "all dialog dropdown controls remain owned until close")
assert_true(filterSource:find("dropdown.HideDropdown", 1, true) ~= nil,
    "dialog close hides the shared gamepad dropdown control")
assert_true(filterSource:find('keybind = "DIALOG_RESET"', 1, true) ~= nil,
    "filter reset uses the generic gamepad dialog reset binding")
assert_true(filterSource:find('keybind = "UI_SHORTCUT_RIGHT_STICK"', 1, true) == nil,
    "filter dialog does not bypass generic dialog keybind routing")
assert_true(filterSource:find("RestoreTradingHouseFocus", 1, true) ~= nil,
    "dialog close restores the owning Trading House scene focus")
assert_true(filterSource:find("instance:UpdateTabHeader()", 1, true) ~= nil,
    "dialog close rebuilds the Trading House header carousel")
assert_true(filterSource:find("instance.list.Activate", 1, true) ~= nil,
    "dialog close reactivates the results list")

local runtimeFile = assert(io.open("Modules/TradingHouse/Core/TradingHouseRuntime.lua", "r"))
local runtimeSource = runtimeFile:read("*a")
runtimeFile:close()
assert_true(runtimeSource:find('action = "changeGuild"', 1, true) ~= nil,
    "ordinary Y retains native change-guild behavior")
assert_true(runtimeSource:find(
    'TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_QUINARY", { action = "editFilters" })',
    1, true) ~= nil,
    "Quinary owns the edit-filters action")
assert_true(runtimeSource:find("handlesKeyUp = true", 1, true) == nil,
    "Guild and Edit Filters use independent descriptors without hold multiplexing")
assert_true(runtimeSource:find('keybind = "UI_SHORTCUT_LEFT_STICK"', 1, true) ~= nil,
    "left stick switches to one inactive Trading House list")
assert_true(runtimeSource:find('keybind = "UI_SHORTCUT_RIGHT_STICK"', 1, true) ~= nil,
    "right stick switches to the other inactive Trading House list")
assert_true(runtimeSource:find('keybind = "UI_SHORTCUT_RIGHT_TRIGGER"', 1, true) ~= nil,
    "next-page action retains native right-trigger assignment")
assert_true(runtimeSource:find('keybind = "UI_SHORTCUT_LEFT_TRIGGER"', 1, true) ~= nil,
    "previous-page action retains native left-trigger assignment")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
