--[[
File: tools/tests/test_trading_house_trace_source.lua
Purpose: Source contract for Trading House operation trace correlation.
]]

local function read_file(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(string.format("failed to open %s: %s", path, tostring(err)))
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function count_occurrences(haystack, needle)
    local count = 0
    local start = 1
    while true do
        local match_start, match_end = haystack:find(needle, start, true)
        if not match_start then
            return count
        end
        count = count + 1
        start = match_end + 1
    end
end

local function assert_count(haystack, needle, expected, label)
    local actual = count_occurrences(haystack, needle)
    if actual ~= expected then
        error(string.format("%s\nExpected %d occurrence(s), found %d: %s", label, expected, actual, needle))
    end
end

print("test_trading_house_trace_source")

local th_class = read_file("Modules/TradingHouse/Core/TradingHouseClass.lua")
local flow = read_file("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
local browse = read_file("Modules/TradingHouse/Components/BrowseComponent.lua")
local sell = read_file("Modules/TradingHouse/Components/SellComponent.lua")
local listings = read_file("Modules/TradingHouse/Components/ListingsComponent.lua")

assert_contains(th_class, "TraceTH(L and L.CATEGORY.NAV, \"th.mode\", \"changed\"",
    "Trading House SetMode emits NAV/th.mode changed")
assert_contains(th_class, "old = oldMode",
    "Trading House mode changed payload carries old mode")
assert_contains(th_class, "[\"new\"] = mode",
    "Trading House mode changed payload carries new mode")
assert_contains(th_class, "trigger = \"SetMode\"",
    "Trading House mode changed payload names its trigger")

assert_contains(flow, "function TH.BeginPendingOperation(operation, event, data, emitRequested)",
    "runtime exposes a pending Trading House operation allocator")
assert_contains(flow, "if emitRequested ~= false then",
    "runtime can register pending operations without duplicating requested traces")
assert_contains(flow, "L.NewFlow(\"thOp\")",
    "Trading House operations allocate thOp flow IDs")
assert_contains(flow, "TH._pendingOperations[operation] = {",
    "Trading House operations are stored by operation type")
assert_contains(flow, "function TH.ClearPendingOperation(operation)",
    "runtime exposes pending operation cleanup")
assert_contains(flow, "local function ResolveTradingHouseResponseOperation(responseType)",
    "runtime maps response types back to operation types")
assert_contains(flow, "TRADING_HOUSE_RESULT_SEARCH_PENDING",
    "search responses are mapped for correlation")
assert_contains(flow, "TRADING_HOUSE_RESULT_PURCHASE_PENDING",
    "purchase responses are mapped for correlation")
assert_contains(flow, "TRADING_HOUSE_RESULT_POST_PENDING",
    "post responses are mapped for correlation")
assert_contains(flow, "TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING",
    "cancel responses are mapped for correlation")
assert_contains(flow, "opId = pending and pending.opId or \"untracked\"",
    "unmatched responses keep an explicit untracked opId")
assert_contains(flow, "TraceTHFlow(L and L.CATEGORY.ACTION, \"trading_house.response\", success and \"completed\" or \"failed\", payload)",
    "operation responses emit completed/failed ACTION events")
assert_contains(flow, "TraceTradingHouseOperationResponse(responseType, result, guildId, mode)",
    "runtime calls operation response correlation from OnTradingHouseResponse")
assert_contains(flow, "ResolveTradingHouseResultText(result)",
    "failed operation responses include cheap error text")
assert_contains(flow, "local function TracePendingOperationFailure(failureType, errorText)",
    "runtime has shared failure cleanup for pending operations")
assert_contains(flow, "local function TracePendingOperationTimeout(timeoutType)",
    "runtime has timeout cleanup for pending operations")
assert_contains(flow, "TracePendingOperationTimeout(\"responseTimeout\")",
    "response timeout clears all pending operations")
assert_contains(flow, "TracePendingOperationTimeout(\"operationTimeout\")",
    "operation timeout clears all pending operations")
assert_contains(flow, "TracePendingOperationFailure(\"error\", errorCode and tostring(errorCode) or \"tradingHouseError\")",
    "Trading House errors clear all pending operations")
assert_contains(flow, "fn = \"TradingHouse.TracePendingOperationFailure\"",
    "pending cleanup emits a traceable failure source")

assert_contains(browse, "TH.BeginPendingOperation and TH.BeginPendingOperation(\"search\", \"trading_house.search\"",
    "browse search starts a correlated Trading House operation")
assert_contains(browse, "deferred = true,\n        }, false) or nil",
    "deferred search registers its pending operation without emitting requested")
assert_contains(browse, "TraceBrowse(\"trading_house.search\", \"queued\"",
    "deferred search emits a canonical queued handoff")
assert_count(browse, "TraceBrowse(\"trading_house.search\", \"requested\"", 1,
    "browse search has exactly one explicit requested call site")
assert_count(browse, "\"deferred_requested\"", 0,
    "browse search no longer emits a request-like deferred phase")
assert_contains(browse, "pending.opId = TH.BeginPendingOperation(\"buy\", \"trading_house.buy\"",
    "browse buy confirm starts a correlated Trading House operation")
assert_contains(browse, "local opId = NewTradingHouseOpId()",
    "browse buy allocates a dialog correlation id without logging a server request")
assert_contains(browse, "thOperation = \"buy\"",
    "buy dialog state carries the pending operation name")
assert_contains(browse, "opId = opId",
    "browse traces carry the generated opId")
assert_contains(browse, "TH.ClearPendingOperation(\"search\")",
    "deferred search timeout clears the pending search operation")
assert_count(browse, "TraceBrowse(\"th.list\", \"end\"", 3,
    "browse list build emits bounded aggregate th.list end outcomes")
assert_contains(browse, "local renderedCount = 0",
    "browse list build tracks rendered rows once per rebuild")
assert_contains(browse, "renderedCount = renderedCount + 1",
    "browse list build increments the aggregate row counter when adding entries")
assert_contains(browse, "count = renderedCount",
    "browse th.list aggregate reports rendered count")

assert_contains(sell, "L.NewFlow(\"thOp\")",
    "sell list action allocates a dialog correlation id without logging a server request")
assert_contains(sell, "thOperation  = \"create_listing\"",
    "create-listing dialog data carries the pending operation name")
assert_contains(sell, "opId         = opId",
    "create-listing dialog data carries the generated opId")
assert_contains(flow, "TH.BeginPendingOperation(\"create_listing\", \"trading_house.create_listing\"",
    "runtime confirm path registers the create-listing pending operation")
assert_contains(flow, "}, false) or data.opId",
    "runtime confirm registration does not duplicate the requested trace")
assert_count(flow, "TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION, \"trading_house.create_listing\", \"requested\"", 1,
    "create-listing submit emits exactly one requested trace")
assert_count(sell, "TraceSell(\"th.list\", \"end\"", 1,
    "sell list build emits one aggregate th.list end outcome")
assert_contains(sell, "local renderedCount = 0",
    "sell list build tracks rendered rows once per rebuild")
assert_contains(sell, "renderedCount = renderedCount + 1",
    "sell list build increments the aggregate row counter when adding entries")
assert_contains(sell, "count = renderedCount",
    "sell th.list aggregate reports rendered count")

assert_contains(listings, "pending.opId = TH.BeginPendingOperation(\"cancel_listing\", \"trading_house.cancel_listing\"",
    "listing cancel confirm starts a correlated Trading House operation")
assert_contains(listings, "local opId = NewTradingHouseOpId()",
    "listing cancel allocates a dialog correlation id without logging a server request")
assert_contains(listings, "thOperation = \"cancel_listing\"",
    "cancel-listing dialog state carries the pending operation name")
assert_contains(listings, "opId = opId",
    "cancel-listing traces carry the generated opId")
assert_count(listings, "TraceListings(\"th.list\", \"end\"", 2,
    "listings list build emits bounded aggregate th.list end outcomes")
assert_contains(listings, "local renderedCount = 0",
    "listings list build tracks rendered rows once per rebuild")
assert_contains(listings, "renderedCount = renderedCount + 1",
    "listings list build increments the aggregate row counter when adding entries")
assert_contains(listings, "count = renderedCount",
    "listings th.list aggregate reports rendered count")

assert_count(flow, "\"request\"", 0,
    "runtime flow no longer emits the legacy request phase")
assert_count(browse, "\"request\"", 0,
    "browse component no longer emits the legacy request phase")
assert_count(listings, "\"request\"", 0,
    "listings component no longer emits the legacy request phase")

print("ok")
