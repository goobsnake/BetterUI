-- Canonical banking search and header-focus behavior.

local EnsureKeybindGroupAdded = BETTERUI.Banking.EnsureKeybindGroupAdded

local function GetBankingSearchStickY()
    if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.GetY then
        local ok, value = pcall(
            DIRECTIONAL_INPUT.GetY,
            DIRECTIONAL_INPUT,
            ZO_DI_LEFT_STICK_NO_KEYBOARD
        )
        if ok then
            return value or 0
        end
    end
    if type(GetGamepadLeftStickY) == "function" then
        return GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
    end
    return 0
end

BETTERUI.Banking.Class.SEARCH_LIFECYCLE = {
    clear = "ClearSearchInput",
    exit = "ExitSearchMode",
    headerActive = "IsHeaderFocused",
    requestEnter = "RequestHeaderFocus",
    onEnter = "OnHeaderEntered",
}

function BETTERUI.Banking.Class:ClearSearchInput()
    self.searchQuery = ""
    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    if searchMixin and searchMixin.ClearSearchText then
        searchMixin.ClearSearchText(self)
    elseif self.ClearSearchText then
        self:ClearSearchText()
    end
end

function BETTERUI.Banking.Class:IsHeaderFocused()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        return self.textSearchHeaderFocus:IsActive()
    end
    return self._searchModeActive == true
end

function BETTERUI.Banking.Class:RequestHeaderFocus()
    if self.OnHeaderEntered then
        self:OnHeaderEntered()
    else
        self:EnterSearchMode()
    end
end

function BETTERUI.Banking.Class:EnsureSearchMovementController()
    if self._bankingSearchMovementController then
        return true
    end
    if not ZO_MovementController then
        return false
    end
    self._bankingSearchMovementController = ZO_MovementController:New(
        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL,
        nil,
        GetBankingSearchStickY
    )
    return true
end

function BETTERUI.Banking.Class:SetSearchDirectionalInputUpdate(enabled)
    local inputObject = self._bankingSearchDirectionalInputObject
    if inputObject and DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening
        and DIRECTIONAL_INPUT.Deactivate then
        local safety = 0
        while DIRECTIONAL_INPUT:IsListening(inputObject) and safety < 4 do
            DIRECTIONAL_INPUT:Deactivate(inputObject)
            safety = safety + 1
        end
    end
    if enabled ~= true then
        return false
    end
    if self.IsSceneShowing and not self:IsSceneShowing() then
        return false
    end
    if not self:EnsureSearchMovementController()
        or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Activate) then
        return false
    end

    local control = self.textSearchHeaderControl or self.control
    if not control then
        return false
    end
    if not inputObject then
        inputObject = { owner = self }
        function inputObject:UpdateDirectionalInput()
            if self.owner then
                self.owner:UpdateSearchDirectionalInput()
            end
        end
        self._bankingSearchDirectionalInputObject = inputObject
    end
    inputObject.owner = self
    DIRECTIONAL_INPUT:Activate(inputObject, control)
    return true
end

function BETTERUI.Banking.Class:UpdateSearchDirectionalInput()
    if not self._searchModeActive
        or (self.IsSceneShowing and not self:IsSceneShowing())
        or not self:EnsureSearchMovementController() then
        return false
    end

    local result = self._bankingSearchMovementController:CheckMovement()
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

function BETTERUI.Banking.Class:EnterSearchMode()
    if self.IsSceneShowing and not self:IsSceneShowing() then return false end
    if self._searchModeActive then return end
    self._searchModeActive = true
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SEARCH, "enter search") end

    if self.coreKeybinds then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.coreKeybinds)
    end
    if self.withdrawDepositKeybinds then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.withdrawDepositKeybinds)
    end

    if self.isInHeaderSortMode and self.ExitHeaderSortMode then
        self:ExitHeaderSortMode()
    end

    -- Match Inventory header focus: the item list remains visible but inactive,
    -- which applies the standard dimmed/out-of-focus presentation and prevents
    -- selection callbacks from stealing search ownership.
    if self.list and self.list.Deactivate
        and (not self.list.IsActive or self.list:IsActive()) then
        self.list:Deactivate()
    end
    self:SetSearchDirectionalInputUpdate(true)

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Activate and not self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Activate()
    end

    -- Header focus pushes its own keybind state. Install the search group only
    -- after that state is active so A/B/X cannot be stranded in the list state.
    if self.textSearchKeybindStripDescriptor then
        EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
    end

    -- The search focus pushes a new keybind state. Re-add the independent
    -- category carousel there so LB/RB continues to work during text entry.
    self:EnsureHeaderKeybindsActive()

    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(true)
    end
end

---Reassert search ownership after a list rebuild (for example, LB/RB category
---navigation). Committing a parametric list can reactivate it and displace the
---pushed search keybind state even though the edit box still owns focus.
---@return boolean maintained
function BETTERUI.Banking.Class:MaintainSearchFocusAfterListRefresh()
    if self.IsSceneShowing and not self:IsSceneShowing() then return false end
    if not self._searchModeActive then
        return false
    end

    if self.list and self.list.Deactivate
        and (not self.list.IsActive or self.list:IsActive()) then
        self.list:Deactivate()
    end
    if self.textSearchKeybindStripDescriptor then
        EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
    end
    self:EnsureHeaderKeybindsActive()
    return true
end

function BETTERUI.Banking.Class:ExitSearchMode()
    local listHadInput = self.list and self.list.IsActive and self.list:IsActive() == true
    local headerFocusActive = self.textSearchHeaderFocus
        and self.textSearchHeaderFocus.IsActive
        and self.textSearchHeaderFocus:IsActive() == true
    local wasSearchActive = self._searchModeActive == true or headerFocusActive == true
    if BETTERUI.Banking.Tasks and BETTERUI.Banking.Tasks.Cancel then
        BETTERUI.Banking.Tasks:Cancel("searchKeybindCleanup")
    end
    self._searchModeActive = false
    self:SetSearchDirectionalInputUpdate(false)
    self._searchKeybindCleanupToken = (self._searchKeybindCleanupToken or 0) + 1
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SEARCH, "exit search") end

    if self.textSearchKeybindStripDescriptor then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.textSearchKeybindStripDescriptor)
    end

    -- Deactivation pops the header's keybind state. Restore list-owned groups
    -- only after that pop so they land in the active scene state.
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate and self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Deactivate()
    end

    -- Deactivation pops the header keybind-state snapshot, which can restore a
    -- search descriptor captured before the first removal. Clear it again so
    -- its Back binding cannot compete with the core scene Back binding.
    if self.textSearchKeybindStripDescriptor then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.textSearchKeybindStripDescriptor)
    end

    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(false)
    end

    -- Scene teardown also calls this method after clearing the mode flag. In
    -- that state remove stale search ownership, but never re-add list keybinds.
    if self.IsSceneShowing and not self:IsSceneShowing() then
        self._searchRemovedKeybindGroups = nil
        return wasSearchActive
    end

    local restoredGroups = {}
    if self._searchRemovedKeybindGroups then
        for _, group in ipairs(self._searchRemovedKeybindGroups) do
            restoredGroups[group] = true
        end
        BETTERUI.Interface.RestoreKeybindGroups(self._searchRemovedKeybindGroups)
        self._searchRemovedKeybindGroups = nil
    end

    -- Fast exits can occur before deferred cleanup snapshots anything, even
    -- though EnterSearchMode already removed both canonical list groups.
    if self.withdrawDepositKeybinds and not restoredGroups[self.withdrawDepositKeybinds] then
        EnsureKeybindGroupAdded(self.withdrawDepositKeybinds)
    end
    if self.coreKeybinds and not restoredGroups[self.coreKeybinds] then
        EnsureKeybindGroupAdded(self.coreKeybinds)
    end

    if self.list and self.list.Activate
        and (not self.list.IsActive or not self.list:IsActive()) then
        self.list:Activate()
    end

    self:RefreshActiveKeybinds()

    self:EnsureHeaderKeybindsActive()
    self:UpdateActions()
    -- If list input was already active, a stale search descriptor consumed B.
    -- Report no active search ownership so the shared descriptor falls through
    -- to HandleSearchBackFallback and closes the guild-bank scene.
    return wasSearchActive and not listHadInput
end

function BETTERUI.Banking.Class:HandleSearchBackFallback()
    if self.CancelWithdrawDeposit then
        self:CancelWithdrawDeposit(self.list)
    end
end

function BETTERUI.Banking.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then return end

    -- Shared anchoring lives in CIM SearchManager (loaded before this module).
    BETTERUI.Interface.PositionSearchControl(self, {
        preset = "BANKING",
        fallbackY = 8,
    })
end

function BETTERUI.Banking.Class:OnSearchFocusLost()
    self:ExitSearchMode()
end

function BETTERUI.Banking.Class:OnHeaderEntered()
    if self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden()) then
        self:EnterSearchMode()

        self._searchKeybindCleanupToken = (self._searchKeybindCleanupToken or 0) + 1
        local cleanupToken = self._searchKeybindCleanupToken
        BETTERUI.Banking.Tasks:Schedule("searchKeybindCleanup", 20, function()
            if cleanupToken ~= self._searchKeybindCleanupToken
                or not self._searchModeActive
                or not KEYBIND_STRIP
                or (self.IsSceneShowing and not self:IsSceneShowing()) then
                return
            end

            -- Remove only this module's own keybind groups, snapshotting what
            -- was removed so ExitSearchMode restores exactly that.
            local owned = {}
            owned[#owned + 1] = self.coreKeybinds
            owned[#owned + 1] = self.withdrawDepositKeybinds
            owned[#owned + 1] = self.currencyKeybinds
            local removed = BETTERUI.Interface.RemoveOwnedKeybindGroups(
                owned, self.textSearchKeybindStripDescriptor)
            if self._searchRemovedKeybindGroups then
                -- Re-entry while search is still active: append instead of
                -- overwriting so the first snapshot is restored on exit.
                for _, group in ipairs(removed) do
                    self._searchRemovedKeybindGroups[#self._searchRemovedKeybindGroups + 1] = group
                end
            else
                self._searchRemovedKeybindGroups = removed
            end

            if self._searchModeActive and self.textSearchKeybindStripDescriptor then
                EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
                self:EnsureHeaderKeybindsActive()
            end
        end)
    end
end

---@param searchText string
function BETTERUI.Banking.Class:OnSearchTextChanged(searchText)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SEARCH, "search text changed", { query = searchText })
    end
    self.searchQuery = searchText
    if self.IsSceneShowing and not self:IsSceneShowing() then return end
    local previousPreserve = self._preserveSearchFocusDuringRefresh == true
    self._preserveSearchFocusDuringRefresh = true
    if self.SaveListPosition then
        self:SaveListPosition()
    end
    self:RefreshList()
    self._preserveSearchFocusDuringRefresh = previousPreserve or nil
end
