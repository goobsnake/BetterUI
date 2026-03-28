--[[
File: Modules/Banking/Search/SearchManager.lua
Purpose: Canonical search/header focus boundary for BETTERUI.Banking.Class.
         All banking search interactions should route through this module.
]]

-- SHARED CONSTANTS
local EnsureKeybindGroupAdded = BETTERUI.Banking.EnsureKeybindGroupAdded

--- Clears the text search input and resets the query.
function BETTERUI.Banking.Class:ClearSearchInput()
    self.searchQuery = ""
    if not BETTERUI.CIM.TryCall("Interface.Window.ClearSearchText", self) then
        if self.ClearSearchText then
            self:ClearSearchText()
        end
    end
end

--- Backwards-compatible alias.
function BETTERUI.Banking.Class:ClearTextSearch()
    self:ClearSearchInput()
end

--- Checks whether the header/search control is currently focused.
function BETTERUI.Banking.Class:IsHeaderFocused()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        return self.textSearchHeaderFocus:IsActive()
    end
    return self._searchModeActive == true
end

--- Backwards-compatible alias.
function BETTERUI.Banking.Class:IsHeaderActive()
    return self:IsHeaderFocused()
end

--- Requests focus for the search/header control.
function BETTERUI.Banking.Class:RequestHeaderFocus()
    if self.OnHeaderEntered then
        self:OnHeaderEntered()
    else
        self:EnterSearchMode()
    end
end

--- Backwards-compatible alias.
function BETTERUI.Banking.Class:RequestEnterHeader()
    self:RequestHeaderFocus()
end

--- Enters text search mode.
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

--- Exits text search mode and restores standard keybinds.
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

--- Backwards-compatible alias.
function BETTERUI.Banking.Class:LeaveSearchMode()
    self:ExitSearchMode()
end

--- Positions the search control beneath the header title.
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
        local xOffset = BETTERUI.Banking.CONST.SEARCH.X_OFFSET
        local yOffset = BETTERUI.Banking.CONST.SEARCH.Y_OFFSET
        local rightInset = BETTERUI.Banking.CONST.SEARCH.RIGHT_INSET
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, 8)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0, 8)
    end

    self.textSearchHeaderControl:SetHidden(false)
end

--- Callback when search focus is lost.
function BETTERUI.Banking.Class:OnSearchFocusLost()
    self:ExitSearchMode()
end

--- Backwards-compatible alias.
function BETTERUI.Banking.Class:ExitSearchFocus()
    self:OnSearchFocusLost()
end

--- Callback when the header is entered (navigating up from list).
function BETTERUI.Banking.Class:OnHeaderEntered()
    if self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden()) then
        self:EnterSearchMode()

        if BETTERUI.CIM.TryResolve("Interface.Window.OnEnterHeader") then
            BETTERUI.Interface.Window.OnEnterHeader(self)
        end

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
    else
        BETTERUI.CIM.TryCall("Interface.Window.OnEnterHeader", self)
    end
end

--- Backwards-compatible alias.
function BETTERUI.Banking.Class:OnEnterHeader()
    self:OnHeaderEntered()
end

--- Handles search text updates.
function BETTERUI.Banking.Class:OnSearchTextChanged(editBox)
    if not (editBox and editBox.GetText) then return end
    self.searchQuery = editBox:GetText()
    self:RefreshList()
end
