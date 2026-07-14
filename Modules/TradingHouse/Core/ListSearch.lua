-- Trading House list text search and Inventory-style focus ownership.

local TH = BETTERUI.TradingHouse
TH.ListSearch = TH.ListSearch or {}

local ListSearch = TH.ListSearch
local Class = TH.Class
local Interface = BETTERUI.Interface

local function NormalizeQuery(value)
    local query = tostring(value or "")
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    if type(zo_strlower) == "function" then
        return zo_strlower(query)
    end
    return string.lower(query)
end

function ListSearch.FilterRows(instance, rows)
    local query = NormalizeQuery(instance and instance.searchQuery)
    if query == "" then
        return rows
    end

    local filtered = {}
    for _, row in ipairs(rows or {}) do
        local name = NormalizeQuery(row and (row.name or row.itemName or row.displayName))
        if name:find(query, 1, true) then
            filtered[#filtered + 1] = row
        end
    end
    return filtered
end

function ListSearch.UpdateNoItemText(instance)
    if not (instance and instance.list and instance.list.SetNoItemText and GetString) then
        return
    end
    local stringId
    if NormalizeQuery(instance.searchQuery) ~= "" then
        stringId = rawget(_G, "SI_BETTERUI_SEARCH_NO_RESULTS")
    end
    stringId = stringId or rawget(_G, "SI_BETTERUI_EMPTY_LIST")
        or rawget(_G, "SI_GAMEPAD_INVENTORY_EMPTY")
    if stringId then
        instance.list:SetNoItemText(GetString(stringId))
    end
end

Class.SEARCH_LIFECYCLE = {
    accept = "AcceptSearchAndReturnToList",
    clear = "ClearSearchInput",
    exit = "ExitSearchMode",
    headerActive = "IsHeaderFocused",
    requestEnter = "RequestHeaderFocus",
    onEnter = "OnHeaderEntered",
}

local function GetSearchStickY()
    if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.GetY then
        local ok, value = pcall(
            DIRECTIONAL_INPUT.GetY,
            DIRECTIONAL_INPUT,
            ZO_DI_LEFT_STICK_NO_KEYBOARD
        )
        if ok then return value or 0 end
    end
    if type(GetGamepadLeftStickY) == "function" then
        return GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
    end
    return 0
end

local function EnsureGroup(group)
    if group and Interface and Interface.EnsureKeybindGroupAdded then
        Interface.EnsureKeybindGroupAdded(group)
    end
end

local function RemoveGroup(group)
    if group and Interface and Interface.RemoveKeybindGroupIfPresent then
        Interface.RemoveKeybindGroupIfPresent(group)
    end
end

function Class:IsHeaderFocused()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        return self.textSearchHeaderFocus:IsActive()
    end
    return self._searchModeActive == true
end

function Class:RequestHeaderFocus()
    self:OnHeaderEntered()
end

function Class:EnsureListSearchMovementController()
    if self._listSearchMovementController then return true end
    if not ZO_MovementController then return false end
    self._listSearchMovementController = ZO_MovementController:New(
        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL,
        nil,
        GetSearchStickY
    )
    return true
end

function Class:SetListSearchDirectionalInputUpdate(enabled)
    local inputObject = self._listSearchDirectionalInputObject
    if inputObject and DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening
        and DIRECTIONAL_INPUT.Deactivate then
        local safety = 0
        while DIRECTIONAL_INPUT:IsListening(inputObject) and safety < 4 do
            DIRECTIONAL_INPUT:Deactivate(inputObject)
            safety = safety + 1
        end
    end
    if enabled ~= true or not self:EnsureListSearchMovementController()
        or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Activate) then
        return false
    end

    local control = self.textSearchHeaderControl or self.control
    if not control then return false end
    if not inputObject then
        inputObject = { owner = self }
        function inputObject:UpdateDirectionalInput()
            if self.owner then self.owner:UpdateListSearchDirectionalInput() end
        end
        self._listSearchDirectionalInputObject = inputObject
    end
    inputObject.owner = self
    DIRECTIONAL_INPUT:Activate(inputObject, control)
    return true
end

function Class:UpdateListSearchDirectionalInput()
    if not self._searchModeActive
        or (self.IsSceneShowing and not self:IsSceneShowing())
        or not self:EnsureListSearchMovementController() then
        return false
    end

    local result = self._listSearchMovementController:CheckMovement()
    if result == MOVEMENT_CONTROLLER_MOVE_NEXT then
        if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Consume then
            DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK, ZO_DI_LEFT_STICK_NO_KEYBOARD)
        end
        self:ExitSearchMode()
        return true
    elseif result == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then
        if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Consume then
            DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK, ZO_DI_LEFT_STICK_NO_KEYBOARD)
        end
        return true
    end
    return false
end

function Class:EnsureHeaderKeybindsActive()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    EnsureGroup(tabBar and tabBar.keybindStripDescriptor)
end

function Class:EnterSearchMode()
    if self._searchModeActive then return end
    if not (self.textSearchHeaderControl and self.textSearchHeaderFocus)
        or self.textSearchHeaderControl:IsHidden() then
        return
    end

    self._searchModeActive = true
    RemoveGroup(self.coreKeybinds)
    if self.list and self.list.Deactivate
        and (not self.list.IsActive or self.list:IsActive()) then
        self.list:Deactivate()
    end
    self:SetListSearchDirectionalInputUpdate(true)
    if self.textSearchHeaderFocus.Activate
        and (not self.textSearchHeaderFocus.IsActive
            or not self.textSearchHeaderFocus:IsActive()) then
        self.textSearchHeaderFocus:Activate()
    end
    RemoveGroup(self.coreKeybinds)
    EnsureGroup(self.textSearchKeybindStripDescriptor)
    self:EnsureHeaderKeybindsActive()
    if self.SetTextSearchFocused then self:SetTextSearchFocused(true) end
end

function Class:MaintainListSearchFocus()
    if not self._searchModeActive then return false end
    if self.list and self.list.Deactivate
        and (not self.list.IsActive or self.list:IsActive()) then
        self.list:Deactivate()
    end
    RemoveGroup(self.coreKeybinds)
    EnsureGroup(self.textSearchKeybindStripDescriptor)
    self:EnsureHeaderKeybindsActive()
    return true
end

function Class:ExitSearchMode()
    local headerActive = self.textSearchHeaderFocus
        and self.textSearchHeaderFocus.IsActive
        and self.textSearchHeaderFocus:IsActive() == true
    local wasActive = self._searchModeActive == true or headerActive

    self._searchModeActive = false
    self:SetListSearchDirectionalInputUpdate(false)
    RemoveGroup(self.textSearchKeybindStripDescriptor)
    if headerActive and self.textSearchHeaderFocus.Deactivate then
        self.textSearchHeaderFocus:Deactivate()
    end
    RemoveGroup(self.textSearchKeybindStripDescriptor)
    if self.SetTextSearchFocused then self:SetTextSearchFocused(false) end

    if self.IsSceneShowing and not self:IsSceneShowing() then
        return wasActive
    end
    if self.list and self.list.Activate
        and (not self.list.IsActive or not self.list:IsActive()) then
        self.list:Activate()
    end
    self:EnsureHeaderKeybindsActive()
    EnsureGroup(self.coreKeybinds)
    if Interface and Interface.UpdateKeybindGroup and self.coreKeybinds then
        Interface.UpdateKeybindGroup(self.coreKeybinds)
    end
    return wasActive
end

function Class:AcceptSearchAndReturnToList()
    return self:ExitSearchMode()
end

function Class:OnSearchFocusLost()
    self:ExitSearchMode()
end

function Class:OnHeaderEntered()
    self:EnterSearchMode()
end

function Class:ClearSearchInput()
    self.searchQuery = ""
    if Interface and Interface.SearchMixin and Interface.SearchMixin.ClearSearchText then
        Interface.SearchMixin.ClearSearchText(self)
    end
end

function Class:ResetListSearch()
    self.searchQuery = ""
    self._searchModeActive = false
    self:SetListSearchDirectionalInputUpdate(false)
    RemoveGroup(self.textSearchKeybindStripDescriptor)
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive
        and self.textSearchHeaderFocus:IsActive()
        and self.textSearchHeaderFocus.Deactivate then
        self.textSearchHeaderFocus:Deactivate()
    end
    if self.SetTextSearchFocused then self:SetTextSearchFocused(false) end
    if Interface and Interface.SearchMixin and Interface.SearchMixin.ClearSearchText then
        Interface.SearchMixin.ClearSearchText(self)
    end
end

function Class:OnListSearchTextChanged(searchText)
    self.searchQuery = searchText or ""
    self:RefreshList()
    self:MaintainListSearchFocus()
end

function Class:PositionListSearchControl()
    if not (self.textSearchHeaderControl and Interface and Interface.PositionSearchControl) then
        return
    end
    Interface.PositionSearchControl(self, {
        preset = "INVENTORY",
        fallbackY = 1,
        linkHeaderFocus = true,
    })
end

function Class:HandleSearchBackFallback()
    if SCENE_MANAGER and SCENE_MANAGER.HideCurrentScene then
        SCENE_MANAGER:HideCurrentScene()
    end
end

function Class:InitializeListSearch()
    self.searchQuery = ""
    self.textSearchKeybindStripDescriptor = Interface.CreateSearchKeybindDescriptor(self)
    if self.AddSearch then
        self:AddSearch(self.textSearchKeybindStripDescriptor, function(searchText)
            self:OnListSearchTextChanged(searchText)
        end)
    end
    self:PositionListSearchControl()

    local handlers = Interface and Interface.SearchMixin
    local options = {
        isSceneShowing = function()
            return self.IsSceneShowing and self:IsSceneShowing() or false
        end,
        enterHeaderFn = function(window) window:RequestHeaderFocus() end,
        onExitFocus = function(window) window:OnSearchFocusLost() end,
        onAcceptSearch = function(window) return window:AcceptSearchAndReturnToList() end,
    }
    if self.SetupEditBoxHandlers then
        self:SetupEditBoxHandlers(options)
    elseif handlers and handlers.SetupEditBoxHandlers then
        handlers.SetupEditBoxHandlers(self, options)
    end

    if self.list then
        self.list.owner = self
        local lists = BETTERUI.CIM and BETTERUI.CIM.Lists
        if lists and lists.WrapMovePreviousToHeader then
            lists.WrapMovePreviousToHeader(self.list, function()
                self:RequestHeaderFocus()
            end)
        end
    end
end
