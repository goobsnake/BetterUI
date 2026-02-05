--[[
File: Modules/CIM/Core/SearchManager.lua
Purpose: Text search functionality for gamepad windows.
Author: BetterUI Team
Last Modified: 2026-01-26


Contains:
  - CreateSearchKeybindDescriptor function
  - Local helpers for mouse interactivity and narration
  - SearchMixin table applied to Window class by WindowClass.lua
]]

BETTERUI.Interface = BETTERUI.Interface or {}

-------------------------------------------------------------------------------------------------
-- LOCAL HELPERS
-------------------------------------------------------------------------------------------------

--[[
Function: PatchMouseInteractivity (Local Helper)
Description: Makes the search control and its children interactive for mouse users.
]]
local function PatchMouseInteractivity(searchControl, focusHandler)
    if searchControl.SetMouseEnabled then
        searchControl:SetMouseEnabled(true)
    end
    searchControl:SetHandler("OnMouseUp", function()
        if focusHandler and focusHandler.SetFocused then
            focusHandler:SetFocused(true)
        end
    end)

    -- Use centralized child name list for search box components
    local childCandidates = BETTERUI.CIM.CONST.SEARCH_CHILD_NAMES
    for _, name in ipairs(childCandidates) do
        if searchControl.GetNamedChild then
            local child = searchControl:GetNamedChild(name)
            if child then
                if child.SetMouseEnabled then child:SetMouseEnabled(true) end
                if child.SetHandler then
                    child:SetHandler("OnMouseUp", function()
                        if focusHandler and focusHandler.SetFocused then
                            focusHandler:SetFocused(true)
                        end
                    end)
                end
                -- enlarge icon/texture children if possible
                if child.SetDimensions then
                    child:SetDimensions(28, 28)
                end
            end
        end
    end
end

--[[
Function: RegisterNarrationHandler (Local Helper)
Description: Registers narration logic for the search header and list items.
             Enhanced to provide accessibility for item selection and actions.
]]
local function RegisterNarrationHandler(window, focusHandler)
    if SCREEN_NARRATION_MANAGER and focusHandler then
        local textSearchHeaderNarrationInfo =
        {
            headerNarrationFunction = function()
                if window.GetHeaderNarration then
                    return window:GetHeaderNarration()
                end
                return nil
            end,
            resultsNarrationFunction = function()
                local narrations = {}
                local currentList = window:GetList()
                if currentList and currentList.IsEmpty and currentList:IsEmpty() then
                    local noItemText = ""
                    if currentList.GetNoItemText then
                        noItemText = currentList:GetNoItemText()
                    end
                    ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(noItemText))
                end
                return narrations
            end,
            -- Enhanced: Add selected item narration for list items
            selectedItemNarrationFunction = function()
                local narrations = {}
                local currentList = window:GetList()
                if currentList and currentList.selectedData then
                    local data = currentList.selectedData

                    -- Narrate item name
                    if data.name then
                        ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(data.name))
                    end

                    -- Narrate quality if available
                    if data.quality and GetString then
                        local qualityString = GetString("SI_ITEMQUALITY", data.quality)
                        if qualityString and qualityString ~= "" then
                            ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(qualityString))
                        end
                    end

                    -- Narrate stack count for stacked items
                    if data.stackCount and data.stackCount > 1 then
                        local stackText = zo_strformat("Stack of <<1>>", data.stackCount)
                        ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(stackText))
                    end

                    -- Narrate category
                    if data.bestItemCategoryName then
                        ZO_AppendNarration(narrations,
                            SCREEN_NARRATION_MANAGER:CreateNarratableObject(data.bestItemCategoryName))
                    end

                    -- Narrate equipped status
                    if data.isEquippedInCurrentCategory then
                        ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject("Equipped"))
                    end

                    -- Narrate junk status
                    if data.isJunk then
                        ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject("Marked as junk"))
                    end
                end
                return narrations
            end,
        }
        SCREEN_NARRATION_MANAGER:RegisterTextSearchHeader(focusHandler, textSearchHeaderNarrationInfo)
    end
end

-------------------------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.Interface.CreateSearchKeybindDescriptor
Description: Creates keybind descriptors for text search functionality.
Rationale: Standardizes search navigation (Select, Back, Down) across modules.
Mechanism: Returns a table of keybind definitions with visibility callbacks tied to the search context.
param: context (table) - The search context object (must have textSearchHeaderControl, searchQuery, etc.).
return: table - Array of keybind descriptors.
]]
function BETTERUI.Interface.CreateSearchKeybindDescriptor(context)
    local function HasVisibleSearchControl()
        if not context or not context.textSearchHeaderControl then return false end
        return not context.textSearchHeaderControl:IsHidden()
    end

    local function HasSearchText()
        if not context then return false end
        local text = context.searchQuery
        return text ~= nil and tostring(text) ~= ""
    end

    return {
        {
            name = function()
                return GetString(SI_GAMEPAD_SELECT_OPTION)
            end,
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = "UI_SHORTCUT_PRIMARY",
            disabledDuringSceneHiding = true,
            visible = function()
                return HasVisibleSearchControl()
            end,
            callback = function()
                if context and context.ExitSearchFocus then
                    context:ExitSearchFocus()
                end
            end,
        },
        {
            name = function()
                local hasText = context and context.searchQuery and tostring(context.searchQuery) ~= ""
                if hasText then
                    return GetString(SI_BETTERUI_CLEAR_SEARCH) or GetString(SI_GAMEPAD_SELECT_OPTION)
                end
                return GetString(SI_GAMEPAD_BACK_OPTION)
            end,
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            keybind = "UI_SHORTCUT_NEGATIVE",
            disabledDuringSceneHiding = true,
            visible = function()
                return HasVisibleSearchControl()
            end,
            callback = function()
                local hasText = HasSearchText()
                if hasText then
                    if context and context.ClearTextSearch then
                        context:ClearTextSearch()
                    end
                else
                    if context and context.ExitSearchFocus then
                        context:ExitSearchFocus()
                    end
                end
            end,
        },
        {
            name = function()
                return GetString(SI_GAMEPAD_SCRIPTS_KEYBIND_DOWN) or "Down"
            end,
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = "UI_SHORTCUT_DOWN",
            disabledDuringSceneHiding = true,
            visible = function()
                return HasVisibleSearchControl()
            end,
            callback = function()
                if context and context.ExitSearchFocus then
                    context:ExitSearchFocus()
                end
            end,
        },
    }
end

-------------------------------------------------------------------------------------------------
-- SEARCH MIXIN
-- These methods are applied to BETTERUI.Interface.Window by WindowClass.lua
-------------------------------------------------------------------------------------------------

BETTERUI.Interface.SearchMixin = {}

--[[
Function: SearchMixin.AddSearch
Description: Integrates text search capability into the window.
Rationale: Allows users to filter lists by text input (items, banks, etc.).
Mechanism:
  1. Creates a header editbox control using 'ZO_Gamepad_TextSearch_HeaderEditbox'.
  2. Wraps it in `ZO_TextSearch_Header_Gamepad` for logic handling.
  3. Registers keybinds and focus management.
  4. Patches the control to be mouse-interactive using `PatchMouseInteractivity`.
  5. Registers with SCREEN_NARRATION_MANAGER using `RegisterNarrationHandler`.
param: textSearchKeybindStripDescriptor (table) - Keybinds for the search state.
param: onTextSearchTextChangedCallback (function) - Callback when search text changes.
]]
function BETTERUI.Interface.SearchMixin.AddSearch(self, textSearchKeybindStripDescriptor, onTextSearchTextChangedCallback)
    -- Create the header editbox control from the common virtual template
    if not self.header then return end
    self.textSearchKeybindStripDescriptor = textSearchKeybindStripDescriptor
    self.textSearchHeaderControl = CreateControlFromVirtual("$(parent)SearchContainer", self.header,
        "ZO_Gamepad_TextSearch_HeaderEditbox")
    -- ZO_TextSearch_Header_Gamepad is provided by the engine's common gamepad libraries
    if ZO_TextSearch_Header_Gamepad then
        self.textSearchHeaderFocus = ZO_TextSearch_Header_Gamepad:New(self.textSearchHeaderControl,
            onTextSearchTextChangedCallback)
        -- Keep the callback so callers can recreate the control under GuiRoot if needed
        self.textSearchCallback = onTextSearchTextChangedCallback
        -- Treat this as the header focus control for the window
        if not self.headerFocus then
            self.headerFocus = self.textSearchHeaderFocus
            -- movement controller not required here, but keep a placeholder
            if not self.movementController then
                if ZO_MovementController then
                    self.movementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_VERTICAL)
                end
            end
        end

        if ZO_GamepadGenericHeader_SetHeaderFocusControl then
            -- Try the most specific focusable target first (the tabBar control
            -- created by BETTERUI_TabBarScrollList), then the generic header
            -- control, then the root header control. This covers modules that
            -- initialize the header/tabbar on different child controls.
            local headerTarget = nil
            if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.control then
                headerTarget = self.headerGeneric.tabBar.control
            elseif self.headerGeneric then
                headerTarget = self.headerGeneric
            else
                headerTarget = self.header
            end
            ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
        end

        -- Make the search control slightly larger and mouse-interactive so PC users can click it
        PatchMouseInteractivity(self.textSearchHeaderControl, self.textSearchHeaderFocus)

        -- Register for narration if available
        RegisterNarrationHandler(self, self.textSearchHeaderFocus)
    end
end

--[[
Function: SearchMixin.IsTextSearchEntryHidden
Description: Checks if the search entry field is hidden.
return: boolean - True if hidden or not initialized, False otherwise.
]]
function BETTERUI.Interface.SearchMixin.IsTextSearchEntryHidden(self)
    if self.textSearchHeaderControl then
        return self.textSearchHeaderControl:IsHidden()
    end
    return true
end

--[[
Function: SearchMixin.SetTextSearchEntryHidden
Description: Sets the visibility of the search entry field.
param: isHidden (boolean) - True to hide, False to show.
]]
function BETTERUI.Interface.SearchMixin.SetTextSearchEntryHidden(self, isHidden)
    if self.textSearchHeaderControl then
        self.textSearchHeaderControl:SetHidden(isHidden)
    end
end

--[[
Function: SearchMixin.SetTextSearchFocused
Description: Sets focus state of the search entry.
Rationale: Used to programmatically focus the search box.
Mechanism: Sets focus and brings window to front to ensure it honors input.
param: isFocused (boolean) - True to focus, False to unfocus.
]]
function BETTERUI.Interface.SearchMixin.SetTextSearchFocused(self, isFocused)
    if self.textSearchHeaderFocus and self.headerFocus then
        self.textSearchHeaderFocus:SetFocused(isFocused)
        -- Bring search control to front so it's visible and not layered behind header elements
        if self.textSearchHeaderControl and self.textSearchHeaderControl.BringWindowToFront then
            self.textSearchHeaderControl:BringWindowToFront()
        end
    end
end

--[[
Function: SearchMixin.GetActiveList
Description: Gets the currently active list.
Rationale: Helper to retrieve the list that should currently receive input.
Mechanism: Checks if GetCurrentList method exists via type check, then calls it safely.
           Falls back to self.list if method doesn't exist.
return: table - The active list control.
]]
function BETTERUI.Interface.SearchMixin.GetActiveList(self)
    -- Use type check instead of pcall to avoid hiding real errors
    -- If GetCurrentList exists and is callable, use it; otherwise fallback
    if type(self.GetCurrentList) == "function" then
        return self:GetCurrentList()
    end
    return self.list
end

--[[
Function: SearchMixin.ActivateSearchHeader
Description: Activates the search header mode.
Rationale: Switches context from list navigation to search input.
Mechanism: Sets internal flag `_searchHeaderActive` and activates the focus object.
]]
function BETTERUI.Interface.SearchMixin.ActivateSearchHeader(self)
    if self.textSearchHeaderFocus and not self._searchHeaderActive then
        self._searchHeaderActive = true
        self.textSearchHeaderFocus:Activate()
        -- Call BringWindowToFront if available (optional method, use guard clause)
        if self.textSearchHeaderControl and self.textSearchHeaderControl.BringWindowToFront then
            self.textSearchHeaderControl:BringWindowToFront()
        end
    end
end

--[[
Function: SearchMixin.DeactivateSearchHeader
Description: Deactivates the search header mode.
Rationale: Switches context back to list navigation.
]]
function BETTERUI.Interface.SearchMixin.DeactivateSearchHeader(self)
    if self.textSearchHeaderFocus and self._searchHeaderActive then
        self._searchHeaderActive = false
        self.textSearchHeaderFocus:Deactivate()
    end
end

--[[
Function: SearchMixin.IsSearchHeaderActive
Description: Checks if search header is currently active.
return: boolean - True if active.
]]
function BETTERUI.Interface.SearchMixin.IsSearchHeaderActive(self)
    return self._searchHeaderActive == true
end

--[[
Function: SearchMixin.ClearSearchText
Description: Clears the current search query.
]]
function BETTERUI.Interface.SearchMixin.ClearSearchText(self)
    if self.textSearchHeaderFocus then
        self.textSearchHeaderFocus:ClearText()
    end
end

--[[
Function: SearchMixin.IsSearchFocused
Description: Checks if the search box has input focus.
return: boolean - True if focused.
]]
function BETTERUI.Interface.SearchMixin.IsSearchFocused(self)
    return self.textSearchHeaderFocus and self.textSearchHeaderFocus:HasFocus()
end

-------------------------------------------------------------------------------------------------
-- SEARCH FOCUS HANDLERS MIXIN
-- Consolidated edit box handlers previously duplicated in Banking.lua and InventoryClass.lua
-------------------------------------------------------------------------------------------------

--[[
Function: SearchMixin.SetupEditBoxHandlers
Description: Sets up focus, text change, and navigation handlers for the search edit box.
Rationale: Consolidates ~50 lines of duplicate code from Banking.lua and InventoryClass.lua.
Mechanism:
  1. Wraps existing handlers to preserve original behavior.
  2. Adds scene guards to prevent processing when scene is hidden.
  3. Handles D-pad/stick navigation to exit search on Down press.
param: options (table) - Configuration options:
  - isSceneShowing (function): Returns true if the window's scene is showing
  - onTextChanged (function|nil): Custom callback when search text changes
  - onExitFocus (function|nil): Custom callback when exiting search focus
  - enterHeaderFn (function|nil): Called when focus should enter header mode
]]
function BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(self, options)
    if not self.textSearchHeaderFocus then return end
    local editBox = self.textSearchHeaderFocus:GetEditBox()
    if not editBox then return end

    options = options or {}
    local isSceneShowing = options.isSceneShowing or function() return true end
    local onTextChanged = options.onTextChanged
    local onExitFocus = options.onExitFocus or function(_) self:ExitSearchFocus() end
    local enterHeaderFn = options.enterHeaderFn

    -- Preserve original handlers
    local origOnFocusGained = editBox:GetHandler("OnFocusGained")
    local origOnFocusLost = editBox:GetHandler("OnFocusLost")
    local origOnTextChanged = editBox:GetHandler("OnTextChanged")
    local origOnKeyDown = editBox:GetHandler("OnKeyDown")
    local origOnShortcut = editBox:GetHandler("OnShortcut")

    -- OnFocusGained: Request header mode if needed
    editBox:SetHandler("OnFocusGained", function(eb)
        if origOnFocusGained then origOnFocusGained(eb) end
        if not isSceneShowing() then return end
        if enterHeaderFn then
            enterHeaderFn(self)
        elseif self.IsHeaderActive and self.RequestEnterHeader then
            if not self:IsHeaderActive() then self:RequestEnterHeader() end
        end
    end)

    -- OnFocusLost: Exit search focus
    editBox:SetHandler("OnFocusLost", function(eb)
        if origOnFocusLost then origOnFocusLost(eb) end
        if not isSceneShowing() then return end
        onExitFocus(self)
    end)

    -- OnTextChanged: Update search query and optionally refresh
    editBox:SetHandler("OnTextChanged", function(eb)
        if origOnTextChanged then origOnTextChanged(eb) end
        if not isSceneShowing() then return end

        local txt = eb:GetText() or ""
        self.searchQuery = txt

        if onTextChanged then
            onTextChanged(self, txt)
        end
    end)

    -- OnKeyDown: Handle D-pad Down to exit search
    editBox:SetHandler("OnKeyDown", function(eb, key, ctrl, alt, shift, command)
        if origOnKeyDown then
            local handled = origOnKeyDown(eb, key, ctrl, alt, shift, command)
            if handled then return handled end
        end
        if not isSceneShowing() then return end

        if command == "UI_SHORTCUT_DOWN" then
            onExitFocus(self)
            return true
        end
    end)

    -- OnShortcut: Handle UI shortcuts (e.g., gamepad equivalents)
    if origOnShortcut then
        editBox:SetHandler("OnShortcut", function(eb, shortcut)
            local handled = origOnShortcut(eb, shortcut)
            if handled then return handled end
            if not isSceneShowing() then return end

            if shortcut == "UI_SHORTCUT_DOWN" then
                onExitFocus(self)
                return true
            end
        end)
    end
end
