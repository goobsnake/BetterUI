--[[
File: tools/tests/test_trading_house_components_source.lua
Purpose: Source-level regression checks for TradingHouse components and core seams.

Usage:
  lua tools/tests/test_trading_house_components_source.lua
]]

if false then
    dofile("Modules/TradingHouse/Components/BrowseComponent.lua")
    dofile("Modules/TradingHouse/Components/ListingsComponent.lua")
    dofile("Modules/TradingHouse/Components/SellComponent.lua")
    dofile("Modules/TradingHouse/Core/TradingHouseClass.lua")
    dofile("Modules/TradingHouse/Core/TradingHouseRowSetup.lua")
end

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local browseSource = read_file("Modules/TradingHouse/Components/BrowseComponent.lua")
assert_true(browseSource:find("TH%.BrowseComponent = %{%}") ~= nil,
    "BrowseComponent initializes the browse component table")
assert_true(browseSource:find("function Browse:Activate%(thInstance%)") ~= nil,
    "BrowseComponent exposes Activate")
assert_true(browseSource:find("function Browse:Deactivate%(thInstance%)") ~= nil,
    "BrowseComponent exposes Deactivate")
assert_true(browseSource:find("function Browse:GetPrimaryActionName%(%)") ~= nil,
    "BrowseComponent exposes GetPrimaryActionName")
assert_true(browseSource:find("function Browse:IsPrimaryActionEnabled%(thInstance%)") ~= nil,
    "BrowseComponent exposes IsPrimaryActionEnabled")
assert_true(browseSource:find("function Browse:OnPrimaryAction%(thInstance%)") ~= nil,
    "BrowseComponent exposes OnPrimaryAction")
assert_true(browseSource:find("function Browse:ExecuteSearch%(useLastExecutedSearchFilters%)") ~= nil,
    "BrowseComponent exposes ExecuteSearch with the page-flip filter-reuse parameter")
assert_true(browseSource:find("TRADING_HOUSE_SEARCH:ApplyFilters%(IS_PERFORMING_SEARCH%)") ~= nil,
    "BrowseComponent applies the pending filter state before dispatching a search")
assert_true(browseSource:find("function Browse:NextPage%(thInstance%)") ~= nil,
    "BrowseComponent exposes NextPage")
assert_true(browseSource:find("function Browse:PrevPage%(thInstance%)") ~= nil,
    "BrowseComponent exposes PrevPage")
assert_true(browseSource:find("function Browse:OnSearchResultsReceived%(thInstance%)") ~= nil,
    "BrowseComponent exposes OnSearchResultsReceived")
assert_true(browseSource:find("function Browse:BuildList%(thInstance%)") ~= nil,
    "BrowseComponent exposes BuildList")

local listingsSource = read_file("Modules/TradingHouse/Components/ListingsComponent.lua")
assert_true(listingsSource:find("TH%.ListingsComponent = %{%}") ~= nil,
    "ListingsComponent initializes the listings component table")
assert_true(listingsSource:find("function Listings:Activate%(thInstance%)") ~= nil,
    "ListingsComponent exposes Activate")
assert_true(listingsSource:find("function Listings:Deactivate%(thInstance%)") ~= nil,
    "ListingsComponent exposes Deactivate")
assert_true(listingsSource:find("function Listings:GetPrimaryActionName%(%)") ~= nil,
    "ListingsComponent exposes GetPrimaryActionName")
assert_true(listingsSource:find("function Listings:IsPrimaryActionEnabled%(thInstance%)") ~= nil,
    "ListingsComponent exposes IsPrimaryActionEnabled")
assert_true(listingsSource:find("function Listings:OnPrimaryAction%(thInstance%)") ~= nil,
    "ListingsComponent exposes OnPrimaryAction")
assert_true(listingsSource:find("function Listings:BuildList%(thInstance%)") ~= nil,
    "ListingsComponent exposes BuildList")

local sellSource = read_file("Modules/TradingHouse/Components/SellComponent.lua")
assert_true(sellSource:find("TH%.SellComponent = %{%}") ~= nil,
    "SellComponent initializes the sell component table")
assert_true(sellSource:find("function Sell:Activate%(thInstance%)") ~= nil,
    "SellComponent exposes Activate")
assert_true(sellSource:find("function Sell:Deactivate%(thInstance%)") ~= nil,
    "SellComponent exposes Deactivate")
assert_true(sellSource:find("function Sell:GetPrimaryActionName%(%)") ~= nil,
    "SellComponent exposes GetPrimaryActionName")
assert_true(sellSource:find("function Sell:IsPrimaryActionEnabled%(thInstance%)") ~= nil,
    "SellComponent exposes IsPrimaryActionEnabled")
assert_true(sellSource:find("function Sell:OnPrimaryAction%(thInstance%)") ~= nil,
    "SellComponent exposes OnPrimaryAction")
assert_true(sellSource:find("function Sell:BuildList%(thInstance%)") ~= nil,
    "SellComponent exposes BuildList")

local classSource = read_file("Modules/TradingHouse/Core/TradingHouseClass.lua")
assert_true(classSource:find("if not BETTERUI%.TradingHouse then BETTERUI%.TradingHouse = %{%} end") ~= nil,
    "TradingHouseClass initializes the TradingHouse namespace")
assert_true(classSource:find("BETTERUI%.TradingHouse%.MODE = %{%s*") ~= nil,
    "TradingHouseClass defines the TradingHouse mode constants")
assert_true(classSource:find("BETTERUI%.TradingHouse%.EnsureTaskManager = EnsureTradingHouseTaskManager") ~= nil,
    "TradingHouseClass exports EnsureTaskManager")
assert_true(classSource:find("BETTERUI%.TradingHouse%.Tasks = BETTERUI%.TradingHouse%.Tasks or TradingHouseDeferredTask%.CreateLazyManagerProxy") ~= nil,
    "TradingHouseClass exports the lazy task manager proxy")
assert_true(classSource:find("BETTERUI%.TradingHouse%.Class = BETTERUI%.CIM%.GenericWindow:Subclass%(%)") ~= nil,
    "TradingHouseClass defines the class subclass")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:New%(%.%.%.%)") ~= nil,
    "TradingHouseClass exposes New")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:IsSceneShowing%(%)") ~= nil,
    "TradingHouseClass exposes IsSceneShowing")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:GetCurrentMode%(%)") ~= nil,
    "TradingHouseClass exposes GetCurrentMode")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:SetMode%(mode%)") ~= nil,
    "TradingHouseClass exposes SetMode")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:GetActiveComponent%(%)") ~= nil,
    "TradingHouseClass exposes GetActiveComponent")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:RegisterComponent%(mode, component%)") ~= nil,
    "TradingHouseClass exposes RegisterComponent")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:RefreshList%(%)") ~= nil,
    "TradingHouseClass exposes RefreshList")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:SuppressListUpdates%(%)") == nil,
    "TradingHouseClass no longer exposes the dead SuppressListUpdates method")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:FlushListUpdates%(%)") == nil,
    "TradingHouseClass no longer exposes the dead FlushListUpdates method")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:CanAfford%(cost, currencyType%)") ~= nil,
    "TradingHouseClass exposes CanAfford")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:HasInventorySpace%(%)") ~= nil,
    "TradingHouseClass exposes HasInventorySpace")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:GetCurrentGuildName%(%)") ~= nil,
    "TradingHouseClass exposes GetCurrentGuildName")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:InitTHFooter%(%)") ~= nil,
    "TradingHouseClass exposes InitTHFooter")
assert_true(classSource:find("function BETTERUI%.TradingHouse%.Class:RefreshTHFooter%(%)") ~= nil,
    "TradingHouseClass exposes RefreshTHFooter")

local rowSetupSource = read_file("Modules/TradingHouse/Core/TradingHouseRowSetup.lua")
assert_true(rowSetupSource:find("function BETTERUI%.TradingHouse%.THEntrySetup%(control, data, selected, reselectingDuringRebuild, enabled, active%)") ~= nil,
    "TradingHouseRowSetup exposes THEntrySetup")
assert_true(rowSetupSource:find("BETTERUI%.CIM%.SharedItemSupport%.ResolveColumnFontDescriptor%(%\"TradingHouse%\", %\"Inventory%\"%)") ~= nil,
    "TradingHouseRowSetup resolves shared item support fonts")
assert_true(rowSetupSource:find("statText = TH%.FormatUnitPrice%(ds%.purchasePrice or 0, ds%.stackCount or 1%)") ~= nil,
    "TradingHouseRowSetup formats unit prices through the TradingHouse helper")
assert_true(rowSetupSource:find("ds%.listingPrice") == nil,
    "TradingHouseRowSetup no longer references dead ds.listingPrice")

if failed > 0 then
    error(string.format("test_trading_house_components_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_trading_house_components_source.lua: %d passed", passed))
