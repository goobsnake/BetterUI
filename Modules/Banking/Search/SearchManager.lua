-- Canonical banking search and header-focus behavior.

local EnsureKeybindGroupAdded = BETTERUI.Banking.EnsureKeybindGroupAdded

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

function BETTERUI.Banking.Class:EnterSearchMode()
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

    if self.textSearchKeybindStripDescriptor then
        EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Activate and not self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Activate()
    end

    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(true)
    end
end

function BETTERUI.Banking.Class:ExitSearchMode()
    if not self._searchModeActive then return end
    if BETTERUI.Banking.Tasks and BETTERUI.Banking.Tasks.Cancel then
        BETTERUI.Banking.Tasks:Cancel("searchKeybindCleanup")
    end
    self._searchModeActive = false
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

    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(false)
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

    self:RefreshActiveKeybinds()

    self:EnsureHeaderKeybindsActive()
    self:UpdateActions()
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
    self:RefreshList()
end
