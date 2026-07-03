-- Shared gamepad text-search helpers.

BETTERUI.Interface = BETTERUI.Interface or {}

---@alias BetterUIKeybindDescriptor table
---@alias BetterUIKeybindDescriptorGroup BetterUIKeybindDescriptor[]

---@class BetterUISearchContext
---@field SEARCH_LIFECYCLE table<string, string>|nil
---@field searchQuery string|nil
---@field textSearchHeaderControl table|nil
---@field textSearchHeaderFocus table|nil
---@field textSearchKeybindStripDescriptor BetterUIKeybindDescriptorGroup|nil
---@field header table|nil
---@field headerGeneric table|nil
---@field movementController table|nil
---@field headerFocus table|nil
---@field _searchHeaderActive boolean|nil
---@field _searchModeActive boolean|nil
---@field GetHeaderNarration fun(self: BetterUISearchContext): table?|nil
---@field GetList fun(self: BetterUISearchContext): table?|nil
---@field GetCurrentList fun(self: BetterUISearchContext): table?|nil
---@field ClearSearchInput fun(self: BetterUISearchContext)|nil
---@field ExitSearchMode fun(self: BetterUISearchContext)|nil
---@field IsHeaderFocused fun(self: BetterUISearchContext): boolean|nil
---@field RequestHeaderFocus fun(self: BetterUISearchContext)|nil
---@field OnHeaderEntered fun(self: BetterUISearchContext)|nil

-- LOCAL HELPERS

local function InvokePreviousMouseHandler(handler, control, ...)
    if type(handler) ~= "function" then
        return nil
    end

    local ok, result = pcall(handler, control, ...)
    if not ok then
        if BETTERUI.Log and BETTERUI.Log.Warn then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SEARCH, "previous search mouse handler failed", {
                error = tostring(result),
            })
        end
        return nil
    end
    return result
end

local function ChainSearchMouseHandler(control, focusHandler)
    if not (control and control.SetHandler) then
        return
    end
    if control._betteruiSearchMouseUpHandlerInstalled then
        return
    end

    local previousHandler = control.GetHandler and control:GetHandler("OnMouseUp") or nil
    control._betteruiSearchMouseUpHandlerInstalled = true
    control:SetHandler("OnMouseUp", function(mouseControl, ...)
        local previousResult = InvokePreviousMouseHandler(previousHandler, mouseControl, ...)
        if previousResult == true then
            return true
        end
        if focusHandler and focusHandler.SetFocused then
            focusHandler:SetFocused(true)
        end
        return previousResult
    end)
end

--- Makes the search control and its children interactive for mouse users.
local function PatchMouseInteractivity(searchControl, focusHandler)
    if searchControl.SetMouseEnabled then
        searchControl:SetMouseEnabled(true)
    end
    ChainSearchMouseHandler(searchControl, focusHandler)

    -- Use centralized child name list for search box components
    local childCandidates = BETTERUI.CIM.CONST.SEARCH_CHILD_NAMES
    for _, name in ipairs(childCandidates) do
        if searchControl.GetNamedChild then
            local child = searchControl:GetNamedChild(name)
            if child then
                if child.SetMouseEnabled then child:SetMouseEnabled(true) end
                ChainSearchMouseHandler(child, focusHandler)
                -- enlarge icon/texture children if possible
                if child.SetDimensions then
                    child:SetDimensions(28, 28)
                end
            end
        end
    end
end

--- Registers narration logic for the search header and selected list items.
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
            selectedItemNarrationFunction = function()
                local narrations = {}
                local currentList = window:GetList()
                if currentList and currentList.selectedData then
                    local data = currentList.selectedData

                    if data.name then
                        ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(data.name))
                    end

                    if data.quality and GetString then
                        local qualityString = GetString("SI_ITEMQUALITY", data.quality)
                        if qualityString and qualityString ~= "" then
                            ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(qualityString))
                        end
                    end

                    if data.stackCount and data.stackCount > 1 then
                        local stackFormat = GetString(rawget(_G, "SI_BETTERUI_NARRATION_STACK_COUNT_FORMAT")) or "Stack of <<1>>"
                        local stackText = zo_strformat(stackFormat, data.stackCount)
                        ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(stackText))
                    end

                    if data.bestItemCategoryName then
                        ZO_AppendNarration(narrations,
                            SCREEN_NARRATION_MANAGER:CreateNarratableObject(data.bestItemCategoryName))
                    end

                    if data.isEquippedInCurrentCategory then
                        local equippedText = GetString(rawget(_G, "SI_BETTERUI_NARRATION_EQUIPPED")) or "Equipped"
                        ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(equippedText))
                    end

                    if data.isJunk then
                        local junkText = GetString(rawget(_G, "SI_BETTERUI_NARRATION_JUNK")) or "Marked as junk"
                        ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(junkText))
                    end
                end
                return narrations
            end,
        }
        SCREEN_NARRATION_MANAGER:RegisterTextSearchHeader(focusHandler, textSearchHeaderNarrationInfo)
    end
end

-- PUBLIC API

--- Creates keybind descriptors for text search functionality.
---@param context BetterUISearchContext
---@return BetterUIKeybindDescriptorGroup
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
                return GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION"))
            end,
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = "UI_SHORTCUT_PRIMARY",
            disabledDuringSceneHiding = true,
            visible = function()
                return HasVisibleSearchControl()
            end,
            callback = function()
                BETTERUI.Interface.SearchMixin.CallSearchLifecycle(context, "exit")
            end,
        },
        {
            name = function()
                local hasText = context and context.searchQuery and tostring(context.searchQuery) ~= ""
                if hasText then
                    return GetString(rawget(_G, "SI_BETTERUI_CLEAR_SEARCH")) or GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION"))
                end
                return GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION"))
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
                    BETTERUI.Interface.SearchMixin.CallSearchLifecycle(context, "clear")
                else
                    BETTERUI.Interface.SearchMixin.CallSearchLifecycle(context, "exit")
                end
            end,
        },
        {
            name = function()
                return GetString(rawget(_G, "SI_BETTERUI_KEYBIND_DOWN")) or "Down"
            end,
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = "UI_SHORTCUT_DOWN",
            disabledDuringSceneHiding = true,
            visible = function()
                return HasVisibleSearchControl()
            end,
            callback = function()
                BETTERUI.Interface.SearchMixin.CallSearchLifecycle(context, "exit")
            end,
        },
    }
end

---@class BetterUISearchAnchorOptions
---@field preset string|nil Search-bar constants preset (default "BANKING")
---@field headerOnly boolean|nil Anchor to screen.header only instead of preferring screen.headerGeneric
---@field titleChildNames string[]|nil Named children probed for the title container (default TitleContainer/Header)
---@field safeExecuteContext string|nil When set, wraps child probes in BETTERUI.CIM.SafeExecute with this context
---@field fallbackY number|nil Fixed Y offset when no anchor parent is found (default Y_OFFSET)
---@field fallbackUseRightInset boolean|nil Apply RIGHT_INSET to the fallback TOPRIGHT anchor instead of 0
---@field linkHeaderFocus boolean|nil Register the control via ZO_GamepadGenericHeader_SetHeaderFocusControl

--- Positions a screen's text search control beneath its header title.
--- Shared by the Banking, Companions, Inventory, and Vendor screens; the
--- per-module anchoring differences are expressed through options.
---@param screen BetterUISearchContext
---@param options BetterUISearchAnchorOptions|nil
function BETTERUI.Interface.PositionSearchControl(screen, options)
    local searchControl = screen.textSearchHeaderControl
    if not searchControl then return end
    options = options or {}

    searchControl:ClearAnchors()

    local anchorTarget
    if options.headerOnly then
        anchorTarget = screen.header
    else
        anchorTarget = screen.headerGeneric or screen.header
    end

    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        local candidates = options.titleChildNames or { "TitleContainer", "Header" }
        for _, name in ipairs(candidates) do
            local child
            if options.safeExecuteContext then
                local ok, result = BETTERUI.CIM.SafeExecute(options.safeExecuteContext, function()
                    return anchorTarget:GetNamedChild(name)
                end)
                if ok then
                    child = result
                end
            else
                child = anchorTarget:GetNamedChild(name)
            end
            if child then
                titleContainer = child
                break
            end
        end
    end

    local parentForAnchor = titleContainer or anchorTarget
    local searchConst = BETTERUI.CIM.SearchBar and BETTERUI.CIM.SearchBar.GetConstants
        and BETTERUI.CIM.SearchBar.GetConstants(options.preset or "BANKING")
    local xOffset = (searchConst and searchConst.X_OFFSET) or 55
    local yOffset = (searchConst and searchConst.Y_OFFSET) or 15
    local rightInset = (searchConst and searchConst.RIGHT_INSET) or -8

    if parentForAnchor then
        searchControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        searchControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        local fallbackY = options.fallbackY or yOffset
        local fallbackRightX = (options.fallbackUseRightInset and rightInset) or 0
        searchControl:SetAnchor(TOPLEFT, screen.header, BOTTOMLEFT, 0, fallbackY)
        searchControl:SetAnchor(TOPRIGHT, screen.header, BOTTOMRIGHT, fallbackRightX, fallbackY)
    end

    searchControl:SetHidden(false)

    -- Optionally link the search control as the gamepad header focus target.
    if options.linkHeaderFocus and ZO_GamepadGenericHeader_SetHeaderFocusControl then
        local headerTarget
        if screen.headerGeneric and screen.headerGeneric.tabBar and screen.headerGeneric.tabBar.control then
            headerTarget = screen.headerGeneric.tabBar.control
        else
            headerTarget = screen.headerGeneric or screen.header
        end
        if headerTarget then
            ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, searchControl)
        end
    end
end

-- SEARCH MIXIN
-- These methods are applied to BETTERUI.Interface.Window by WindowClass.lua

BETTERUI.Interface.SearchMixin = {}

local SEARCH_LIFECYCLE_CANONICAL_METHODS = {
    clear = "ClearSearchInput",
    exit = "ExitSearchMode",
    headerActive = "IsHeaderFocused",
    requestEnter = "RequestHeaderFocus",
    onEnter = "OnHeaderEntered",
}

--- Resolves a search lifecycle method from the canonical contract.
---@param self BetterUISearchContext
---@param action string
---@return function|nil method
---@return string|nil methodName
function BETTERUI.Interface.SearchMixin.GetSearchLifecycleMethod(self, action)
    if not self or not action then
        return nil, nil
    end

    local lifecycle = self.SEARCH_LIFECYCLE
    local methodName = SEARCH_LIFECYCLE_CANONICAL_METHODS[action]
    if type(lifecycle) == "table" and type(lifecycle[action]) == "string" then
        methodName = lifecycle[action]
    end

    if methodName and type(self[methodName]) == "function" then
        return self[methodName], methodName
    end

    return nil, methodName
end

--- Invokes a search lifecycle action when implemented on the receiver.
---@param self BetterUISearchContext
---@param action string
---@param ... any
---@return any
function BETTERUI.Interface.SearchMixin.CallSearchLifecycle(self, action, ...)
    local method = BETTERUI.Interface.SearchMixin.GetSearchLifecycleMethod(self, action)
    if method then
        return method(self, ...)
    end
    return nil
end

--- Checks whether the canonical search/header lifecycle is already active.
---@param self BetterUISearchContext
---@return boolean
function BETTERUI.Interface.SearchMixin.IsSearchLifecycleHeaderActive(self)
    local method = BETTERUI.Interface.SearchMixin.GetSearchLifecycleMethod(self, "headerActive")
    if method then
        return method(self) == true
    end
    return self and self._searchHeaderActive == true or false
end

--- Normalizes any search callback payload into a string.
---@param payload any
---@return string
local function NormalizeSearchCallbackText(payload)
    if payload == nil then
        return ""
    end

    if type(payload) == "string" then
        return payload
    end

    if (type(payload) == "table" or type(payload) == "userdata") and payload.GetText then
        local ok, text = pcall(payload.GetText, payload)
        if ok then
            if text ~= nil then
                return tostring(text)
            end
        else
            if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SEARCH, "GetText failed") end
        end
    end

    return tostring(payload)
end

--- Integrates text search capability into the window.
---@param self BetterUISearchContext
---@param textSearchKeybindStripDescriptor BetterUIKeybindDescriptorGroup
---@param onTextSearchTextChangedCallback fun(text: string)?
function BETTERUI.Interface.SearchMixin.AddSearch(self, textSearchKeybindStripDescriptor, onTextSearchTextChangedCallback)
    -- Create the header editbox control from the common virtual template
    if not self.header then return end
    self.textSearchKeybindStripDescriptor = textSearchKeybindStripDescriptor
    self.textSearchHeaderControl = CreateControlFromVirtual("$(parent)SearchContainer", self.header,
        "ZO_Gamepad_TextSearch_HeaderEditbox")
    local callback = onTextSearchTextChangedCallback and function(payload)
        onTextSearchTextChangedCallback(NormalizeSearchCallbackText(payload))
    end or nil
    -- ZO_TextSearch_Header_Gamepad is provided by the engine's common gamepad libraries
    if ZO_TextSearch_Header_Gamepad then
        self.textSearchHeaderFocus = ZO_TextSearch_Header_Gamepad:New(self.textSearchHeaderControl,
            callback)
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
            local headerTarget
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

--- Sets focus state of the search entry.
---@param self BetterUISearchContext
---@param isFocused boolean
function BETTERUI.Interface.SearchMixin.SetTextSearchFocused(self, isFocused)
    if self.textSearchHeaderFocus and self.headerFocus then
        self.textSearchHeaderFocus:SetFocused(isFocused)
        -- Bring search control to front so it's visible and not layered behind header elements
        if self.textSearchHeaderControl and self.textSearchHeaderControl.BringWindowToFront then
            self.textSearchHeaderControl:BringWindowToFront()
        end
    end
end

--- Gets the currently active list.
---@param self BetterUISearchContext
---@return table?
function BETTERUI.Interface.SearchMixin.GetActiveList(self)
    -- Use type check instead of pcall to avoid hiding real errors
    -- If GetCurrentList exists and is callable, use it; otherwise fallback
    if type(self.GetCurrentList) == "function" then
        return self:GetCurrentList()
    end
    return self.list
end

--- Checks if search header is currently active.
---@param self BetterUISearchContext
---@return boolean
function BETTERUI.Interface.SearchMixin.IsSearchHeaderActive(self)
    return self._searchHeaderActive == true
end

--- Clears the current search query.
---@param self BetterUISearchContext
function BETTERUI.Interface.SearchMixin.ClearSearchText(self)
    if self.textSearchHeaderFocus then
        self.textSearchHeaderFocus:ClearText()
    end
end

-- SEARCH FOCUS HANDLERS MIXIN
-- Consolidated edit box handlers previously duplicated in Banking.lua and InventoryClass.lua

--- Sets up focus, text change, and navigation handlers for the search edit box.
---@param self BetterUISearchContext
---@param options {isSceneShowing: fun(): boolean, onTextChanged: fun(self: BetterUISearchContext, text: string)?, onExitFocus: fun(self: BetterUISearchContext)?, enterHeaderFn: fun(self: BetterUISearchContext)?}?
function BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(self, options)
    if not self.textSearchHeaderFocus then return end
    local editBox = self.textSearchHeaderFocus:GetEditBox()
    if not editBox then return end

    options = options or {}
    local state = editBox._betteruiSearchEditBoxHandlerState
    if not state then
        state = {
            origOnFocusGained = editBox:GetHandler("OnFocusGained"),
            origOnFocusLost = editBox:GetHandler("OnFocusLost"),
            origOnTextChanged = editBox:GetHandler("OnTextChanged"),
            origOnKeyDown = editBox:GetHandler("OnKeyDown"),
            origOnShortcut = editBox:GetHandler("OnShortcut"),
        }
        editBox._betteruiSearchEditBoxHandlerState = state
    end

    state.owner = self
    state.isSceneShowing = options.isSceneShowing or function() return true end
    state.onTextChanged = options.onTextChanged
    state.onExitFocus = options.onExitFocus or function(owner)
        BETTERUI.Interface.SearchMixin.CallSearchLifecycle(owner, "exit")
    end
    state.enterHeaderFn = options.enterHeaderFn

    if state.handlersInstalled then return end
    state.handlersInstalled = true

    -- OnFocusGained: Request header mode if needed
    editBox:SetHandler("OnFocusGained", function(eb)
        local handlerState = eb._betteruiSearchEditBoxHandlerState or state
        local owner = handlerState.owner
        if handlerState.origOnFocusGained then handlerState.origOnFocusGained(eb) end
        if not owner or not handlerState.isSceneShowing() then return end
        if handlerState.enterHeaderFn then
            handlerState.enterHeaderFn(owner)
        elseif not BETTERUI.Interface.SearchMixin.IsSearchLifecycleHeaderActive(owner) then
            BETTERUI.Interface.SearchMixin.CallSearchLifecycle(owner, "requestEnter")
        end
    end)

    -- OnFocusLost: Exit search focus
    editBox:SetHandler("OnFocusLost", function(eb)
        local handlerState = eb._betteruiSearchEditBoxHandlerState or state
        local owner = handlerState.owner
        if handlerState.origOnFocusLost then handlerState.origOnFocusLost(eb) end
        if not owner or not handlerState.isSceneShowing() then return end
        handlerState.onExitFocus(owner)
    end)

    -- OnTextChanged: Update search query and optionally refresh
    editBox:SetHandler("OnTextChanged", function(eb)
        local handlerState = eb._betteruiSearchEditBoxHandlerState or state
        local owner = handlerState.owner
        if handlerState.origOnTextChanged then handlerState.origOnTextChanged(eb) end
        if not owner or not handlerState.isSceneShowing() then return end

        local txt = eb:GetText() or ""
        owner.searchQuery = txt

        local list = BETTERUI.Interface.SearchMixin.GetActiveList(owner)
        local n = list and type(list.GetNumItems) == "function" and list:GetNumItems() or 0
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SEARCH, "search text changed", { textLen = #txt, numItems = n }) end

        if handlerState.onTextChanged then
            handlerState.onTextChanged(owner, txt)
        end
    end)

    -- OnKeyDown: Handle D-pad Down to exit search
    editBox:SetHandler("OnKeyDown", function(eb, key, ctrl, alt, shift, command)
        local handlerState = eb._betteruiSearchEditBoxHandlerState or state
        local owner = handlerState.owner
        if handlerState.origOnKeyDown then
            local handled = handlerState.origOnKeyDown(eb, key, ctrl, alt, shift, command)
            if handled then return handled end
        end
        if not owner or not handlerState.isSceneShowing() then return end

        if command == "UI_SHORTCUT_DOWN" then
            handlerState.onExitFocus(owner)
            return true
        end
    end)

    -- OnShortcut: Handle UI shortcuts (e.g., gamepad equivalents)
    if state.origOnShortcut then
        editBox:SetHandler("OnShortcut", function(eb, shortcut)
            local handlerState = eb._betteruiSearchEditBoxHandlerState or state
            local owner = handlerState.owner
            local handled = handlerState.origOnShortcut(eb, shortcut)
            if handled then return handled end
            if not owner or not handlerState.isSceneShowing() then return end

            if shortcut == "UI_SHORTCUT_DOWN" then
                handlerState.onExitFocus(owner)
                return true
            end
        end)
    end
end
