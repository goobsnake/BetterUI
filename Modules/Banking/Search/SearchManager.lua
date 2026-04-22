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

    if self.coreKeybinds then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
    end
    if self.withdrawDepositKeybinds then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
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
    self._searchModeActive = false

    if self.textSearchKeybindStripDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
    end

    if self.coreKeybinds then
        EnsureKeybindGroupAdded(self.coreKeybinds)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
    end

    self:RefreshActiveKeybinds()

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate and self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Deactivate()
    end

    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(false)
    end

    self:EnsureHeaderKeybindsActive()
    self:UpdateActions()
end

function BETTERUI.Banking.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then return end

    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.headerGeneric or self.header
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        titleContainer = anchorTarget:GetNamedChild("TitleContainer") or anchorTarget:GetNamedChild("Header")
    end

    local parentForAnchor = titleContainer or anchorTarget
    if parentForAnchor then
        local searchConst = BETTERUI.CIM.SearchBar.GetConstants("BANKING")
        local xOffset = searchConst.X_OFFSET
        local yOffset = searchConst.Y_OFFSET
        local rightInset = searchConst.RIGHT_INSET
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, 8)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0, 8)
    end

    self.textSearchHeaderControl:SetHidden(false)
end

function BETTERUI.Banking.Class:OnSearchFocusLost()
    self:ExitSearchMode()
end

function BETTERUI.Banking.Class:OnHeaderEntered()
    if self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden()) then
        self:EnterSearchMode()

        BETTERUI.Banking.Tasks:Schedule("searchKeybindCleanup", 20, function()
            if not self._searchModeActive or not KEYBIND_STRIP then return end

            local keybindGroups = KEYBIND_STRIP.keybindButtonGroups
            if keybindGroups then
                for i = #keybindGroups, 1, -1 do
                    local group = keybindGroups[i]
                    if group and group ~= self.textSearchKeybindStripDescriptor then
                        KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                    end
                end
            end

            if self._searchModeActive and self.textSearchKeybindStripDescriptor then
                EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
            end
        end)
    end
end

---@param searchText string
function BETTERUI.Banking.Class:OnSearchTextChanged(searchText)
    self.searchQuery = searchText
    self:RefreshList()
end
