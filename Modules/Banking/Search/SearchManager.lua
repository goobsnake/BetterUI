--[[
File: Modules/Banking/Search/SearchManager.lua
Purpose: Manages text search functionality in the banking module.
         Extracted from Banking.lua.
Author: BetterUI Team
Last Modified: 2026-01-24
]]

local _

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS
-------------------------------------------------------------------------------------------------
-- Import EnsureKeybindGroupAdded for use in local scope
local EnsureKeybindGroupAdded = BETTERUI.Banking.EnsureKeybindGroupAdded

--[[
Function: BETTERUI.Banking.Class:ClearTextSearch
Description: Clears the text search input and resets the query.
]]
function BETTERUI.Banking.Class:ClearTextSearch()
    self.searchQuery = ""
    if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.ClearSearchText then
        pcall(function() BETTERUI.Interface.Window.ClearSearchText(self) end)
    elseif self.ClearSearchText then
        pcall(function() self:ClearSearchText() end)
    end
end

--[[
Function: BETTERUI.Banking.Class:IsHeaderActive
Description: Checks if the header (or search field) is currently focused.
return: boolean - True if header or search is active.
]]
function BETTERUI.Banking.Class:IsHeaderActive()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        local ok, active = pcall(function() return self.textSearchHeaderFocus:IsActive() end)
        if ok then
            return active
        end
    end
    return self._searchModeActive == true
end

--[[
Function: BETTERUI.Banking.Class:RequestEnterHeader
Description: Requests focus for the header/search control.
]]
function BETTERUI.Banking.Class:RequestEnterHeader()
    if self.OnEnterHeader then
        self:OnEnterHeader()
    else
        self:EnterSearchMode()
    end
end

--[[
Function: BETTERUI.Banking.Class:EnterSearchMode
Description: Enters text search mode, showing the search field and updating keybinds.
]]
function BETTERUI.Banking.Class:EnterSearchMode()
    if self._searchModeActive then return end
    self._searchModeActive = true


    pcall(function()
        if self.coreKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
        end
        if self.withdrawDepositKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
        end
    end)

    if self.textSearchKeybindStripDescriptor then
        pcall(function() EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor) end)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Activate then
        if not self.textSearchHeaderFocus:IsActive() then
            pcall(function() self.textSearchHeaderFocus:Activate() end)
        end
    end

    if self.SetTextSearchFocused then
        pcall(function() self:SetTextSearchFocused(true) end)
    end
end

--[[
Function: BETTERUI.Banking.Class:LeaveSearchMode
Description: Exits text search mode, hiding the search field and restoring standard keybinds.
]]
function BETTERUI.Banking.Class:LeaveSearchMode()
    if not self._searchModeActive then return end
    self._searchModeActive = false
    -- LeaveSearchMode: restore keybinds and header focus. No debug logging in production.
    pcall(function()
        if self.textSearchKeybindStripDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
        end
    end)

    -- Add back core keybinds and ensure coreKeybinds group is added
    pcall(function()
        if self.coreKeybinds then
            EnsureKeybindGroupAdded(self.coreKeybinds)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
        end
    end)

    -- Call RefreshActiveKeybinds to determine and add the correct withdraw/deposit keybinds
    -- based on current selection (currency rows get currencyKeybinds, items get withdrawDepositKeybinds)
    pcall(function()
        self:RefreshActiveKeybinds()
    end)

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate then
        if self.textSearchHeaderFocus:IsActive() then
            pcall(function() self.textSearchHeaderFocus:Deactivate() end)
        end
    end

    if self.SetTextSearchFocused then
        pcall(function() self:SetTextSearchFocused(false) end)
    end

    pcall(function() self:EnsureHeaderKeybindsActive() end)

    pcall(function() self:UpdateActions() end)

    -- No extra teardown required; leaving search mode handles restoring keybinds/list focus.
end

--[[
Function: BETTERUI.Banking.Class:PositionSearchControl
Description: Positions the search control beneath the header title.
Rationale: Ensures the search bar is visible and correctly aligned with the list.
]]
function BETTERUI.Banking.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then return end
    -- Clear existing anchors then attach below the visible header area
    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.headerGeneric or self.header
    -- Try to anchor under the header's TitleContainer if present, otherwise under the header itself
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        titleContainer = anchorTarget:GetNamedChild("TitleContainer") or anchorTarget:GetNamedChild("Header")
    end
    local parentForAnchor = titleContainer or anchorTarget
    if parentForAnchor then
        -- Search bar position configured in BetterUI.CONST.lua
        local xOffset = BETTERUI_BANK_SEARCH_X_OFFSET
        local yOffset = BETTERUI_BANK_SEARCH_Y_OFFSET
        local rightInset = BETTERUI_BANK_SEARCH_RIGHT_INSET
        -- Anchor left with an X offset, and inset the right anchor slightly so control width remains reasonable
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        -- Fallback: anchor to header control bottom
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, 8)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0, 8)
    end
    self.textSearchHeaderControl:SetHidden(false)
end

--[[
Function: BETTERUI.Banking.Class:ExitSearchFocus
Description: Callback when search focus is lost.
]]
function BETTERUI.Banking.Class:ExitSearchFocus()
    self:LeaveSearchMode()
end

--[[
Function: BETTERUI.Banking.Class:OnEnterHeader
Description: Callback when the header is entered (navigating up from list).
Rationale: Auto-focuses the search field if appropriate.
]]
function BETTERUI.Banking.Class:OnEnterHeader()
    if self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden()) then
        self:EnterSearchMode()

        -- Call base implementation if present
        if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.OnEnterHeader then
            pcall(function() BETTERUI.Interface.Window.OnEnterHeader(self) end)
        end

        -- Ensure only the Clear keybind group remains visible shortly after entering header
        zo_callLater(function()
            if not self._searchModeActive then return end
            if not KEYBIND_STRIP then return end

            pcall(function()
                local keybindGroups = KEYBIND_STRIP.keybindButtonGroups
                if keybindGroups then
                    for i = #keybindGroups, 1, -1 do
                        local group = keybindGroups[i]
                        if group and group ~= self.textSearchKeybindStripDescriptor then
                            KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                        end
                    end
                end
            end)

            if not self._searchModeActive then return end

            if self.textSearchKeybindStripDescriptor then
                pcall(function()
                    EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
                end)
            end
        end, 20)
    else
        -- Fallback to base behavior if no text search available
        if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.OnEnterHeader then
            pcall(function() BETTERUI.Interface.Window.OnEnterHeader(self) end)
        end
    end
end
