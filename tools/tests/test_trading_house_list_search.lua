-- Regression coverage for Trading House per-list text search.

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function read_file(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local value = handle:read("*a")
    handle:close()
    return value
end

local sourcePath = "Modules/TradingHouse/Core/ListSearch.lua"
local source = read_file(sourcePath)
assert_eq(type(source), "string", "Trading House list-search module exists")

if source then
    local ensuredGroups = {}
    local removedGroups = {}
    local clearTextCount = 0
    local positionCount = 0
    local wrappedTopExit = nil

    BETTERUI = {
        TradingHouse = { Class = {} },
        Interface = {
            EnsureKeybindGroupAdded = function(group)
                ensuredGroups[#ensuredGroups + 1] = group
                return true
            end,
            RemoveKeybindGroupIfPresent = function(group)
                removedGroups[#removedGroups + 1] = group
                return true
            end,
            UpdateKeybindGroup = function() return true end,
            CreateSearchKeybindDescriptor = function() return { id = "search" } end,
            PositionSearchControl = function()
                positionCount = positionCount + 1
            end,
            SearchMixin = {
                ClearSearchText = function()
                    clearTextCount = clearTextCount + 1
                end,
            },
        },
        CIM = {
            Lists = {
                WrapMovePreviousToHeader = function(list, callback)
                    list._betteruiMovePreviousWrapperInstalled = true
                    wrappedTopExit = callback
                    return true
                end,
            },
        },
    }

    MOVEMENT_CONTROLLER_DIRECTION_VERTICAL = 1
    MOVEMENT_CONTROLLER_MOVE_NEXT = 1
    MOVEMENT_CONTROLLER_MOVE_PREVIOUS = -1
    ZO_DI_LEFT_STICK = 1
    ZO_DI_LEFT_STICK_NO_KEYBOARD = 2
    GAMEPAD_INCLUDE_DEADZONE = 1

    ZO_MovementController = {
        New = function()
            return {
                CheckMovement = function() return 0 end,
            }
        end,
    }

    DIRECTIONAL_INPUT = {
        listening = {},
        Activate = function(self, object)
            self.listening[object] = true
        end,
        Deactivate = function(self, object)
            self.listening[object] = nil
        end,
        IsListening = function(self, object)
            return self.listening[object] == true
        end,
        Consume = function() end,
        GetY = function() return 0 end,
    }

    dofile(sourcePath)

    local TH = BETTERUI.TradingHouse
    local rows = {
        { name = "Iron Sword" },
        { name = "Maple Bow" },
        { name = "Glyph 100%" },
    }

    local unchanged = TH.ListSearch.FilterRows({ searchQuery = "" }, rows)
    assert_eq(unchanged, rows, "empty search preserves the category-filtered row table")

    local filtered = TH.ListSearch.FilterRows({ searchQuery = "SwOrD" }, rows)
    assert_eq(#filtered, 1, "search filters rows case-insensitively")
    assert_eq(filtered[1].name, "Iron Sword", "search keeps the matching row")

    filtered = TH.ListSearch.FilterRows({ searchQuery = "100%" }, rows)
    assert_eq(#filtered, 1, "search treats Lua pattern characters literally")
    assert_eq(filtered[1].name, "Glyph 100%", "literal search returns the expected item")

    local coreGroup = { id = "core" }
    local carouselGroup = { id = "carousel" }
    local searchGroup = { id = "search" }
    local list = {
        active = true,
        IsActive = function(self) return self.active end,
        Activate = function(self) self.active = true end,
        Deactivate = function(self) self.active = false end,
        MovePrevious = function() return false end,
    }
    local focus = {
        active = false,
        IsActive = function(self) return self.active end,
        Activate = function(self) self.active = true end,
        Deactivate = function(self) self.active = false end,
        SetFocused = function() end,
    }
    local instance = setmetatable({
        list = list,
        coreKeybinds = coreGroup,
        textSearchKeybindStripDescriptor = searchGroup,
        textSearchHeaderFocus = focus,
        textSearchHeaderControl = { IsHidden = function() return false end },
        headerGeneric = { tabBar = { keybindStripDescriptor = carouselGroup } },
        sceneShowing = true,
        searchQuery = "old",
        refreshCount = 0,
    }, { __index = TH.Class })

    function instance:IsSceneShowing() return self.sceneShowing end
    function instance:SetTextSearchFocused() end
    function instance:AddSearch(group, callback)
        self.textSearchKeybindStripDescriptor = group
        self.searchCallback = callback
    end
    function instance:SetupEditBoxHandlers(options)
        self.searchHandlerOptions = options
    end
    function instance:RefreshList()
        self.refreshCount = self.refreshCount + 1
    end

    instance:InitializeListSearch()
    assert_eq(instance.list.owner, instance, "search initialization links mouse-wheel transitions to the scene")
    assert_eq(type(wrappedTopExit), "function", "search initialization wraps joystick-up at the list top")
    assert_eq(type(instance.searchCallback), "function", "search initialization wires text changes")
    assert_eq(type(instance.searchHandlerOptions), "table", "search initialization wires edit-box focus handlers")
    assert_eq(positionCount, 1, "search initialization positions the shared search control")

    instance:EnterSearchMode()
    assert_eq(instance._searchModeActive, true, "enter search records active focus ownership")
    assert_eq(list.active, false, "enter search dims and deactivates the item list")
    assert_eq(focus.active, true, "enter search activates the text-search focus")
    assert_eq(ensuredGroups[#ensuredGroups], carouselGroup, "LB/RB category carousel remains active in search focus")

    instance:ExitSearchMode()
    assert_eq(instance._searchModeActive, false, "exit search releases focus ownership")
    assert_eq(list.active, true, "exit search restores item-list input")
    assert_eq(focus.active, false, "exit search deactivates text-search focus")
    assert_eq(ensuredGroups[#ensuredGroups], coreGroup, "exit search restores scene keybinds")

    instance.searchQuery = "persisted"
    instance:ResetListSearch()
    assert_eq(instance.searchQuery, "", "scene reset clears the list-search query")
    assert_eq(clearTextCount > 0, true, "scene reset clears the visible search edit box")
end

local manifest = read_file("BetterUI.txt") or ""
assert_eq(manifest:find("Modules\\TradingHouse\\Core\\ListSearch.lua", 1, true) ~= nil,
    true, "manifest loads Trading House list search")

for _, componentPath in ipairs({
    "Modules/TradingHouse/Components/BrowseComponent.lua",
    "Modules/TradingHouse/Components/SellComponent.lua",
    "Modules/TradingHouse/Components/ListingsComponent.lua",
}) do
    local componentSource = read_file(componentPath) or ""
    assert_eq(componentSource:find("TH.ListSearch.FilterRows(thInstance, rows)", 1, true) ~= nil,
        true, componentPath .. " applies text search after category filtering")
end

local runtimeSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntime.lua") or ""
local _, lifecycleResetCount = runtimeSource:gsub("screen:ResetListSearch%(", "")
assert_eq(lifecycleResetCount >= 2, true, "scene show/hide lifecycle resets search persistence")

print(string.format("Trading House list-search tests: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
