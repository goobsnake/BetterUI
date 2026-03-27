--[[
File: Modules/CIM/UI/HeaderSortKeybinds.lua
Purpose: Keybind factory for HeaderSortController.
         Extracted from HeaderSortController.lua to stay under 600 lines.
Author: BetterUI Team
Last Modified: 2026-03-14
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

-- Strict Load Guard: Only proceed if HeaderSort is enabled and the controller class exists.
-- Soft-disables module for this session if prerequisites are not met, avoiding hard crash.
local function IsHeaderSortPrerequisiteMet()
    if not BETTERUI.GetModuleEnabled("HeaderSort") then return false end
    if not BETTERUI.CIM.UI.HeaderSortController then return false end
    return true
end

if not IsHeaderSortPrerequisiteMet() then
    BETTERUI.SetModuleEnabled("HeaderSort", false)
    return
end

-- Reference sort direction constants from the controller class
local SORT_DIRECTION = BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION

-------------------------------------------------------------------------------------------------
-- SORT FUNCTION HELPERS
-------------------------------------------------------------------------------------------------

--[[
Function: HeaderSortController:GetSortComparator
Description: Returns a comparator function for the active sort column.
             Respects ascending/descending direction.
return: function|nil - Comparator function or nil if no sort active.
]]
--- @return function|nil comparator Sort comparator function or nil
function BETTERUI.CIM.UI.HeaderSortController:GetSortComparator()
    local column, direction = self:GetActiveSortColumn()
    if not column or direction == SORT_DIRECTION.NONE then
        return nil
    end

    local baseSortFn = column.sortFn
    if not baseSortFn then
        return nil
    end

    -- For descending, invert the comparator
    if direction == SORT_DIRECTION.DESCENDING then
        return function(left, right)
            return baseSortFn(right, left)
        end
    end

    return baseSortFn
end

-------------------------------------------------------------------------------------------------
-- KEYBIND FACTORY
-------------------------------------------------------------------------------------------------

--[[
Function: HeaderSortController:CreateKeybindDescriptor
Description: Creates a keybind descriptor for header sort mode.
              Includes A to toggle sort, B to exit, LB/RB for column navigation, and hidden Down/Up for D-pad exit/search.
             Centralizes keybind creation to avoid duplication in Inventory/Banking.
param: exitCallback (function) - Called when user presses B or Down to exit header mode.
param: navigateUpCallback (function, optional) - Called when user presses Up to navigate to search.
return: table - Keybind descriptor for KEYBIND_STRIP:AddKeybindButtonGroup
]]
--- @param exitCallback function Called when exiting header mode
--- @param navigateUpCallback function|nil Called when navigating up to search box
--- @return table keybindDescriptor
function BETTERUI.CIM.UI.HeaderSortController:CreateKeybindDescriptor(exitCallback, navigateUpCallback)
    local controller = self

    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- A button: Toggle sort direction
        {
            name = GetString(rawget(_G, "SI_BETTERUI_HEADER_SORT")),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                controller:ToggleSort()
                PlaySound(SOUNDS.DEFAULT_CLICK)
                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
            end,
        },
        -- B button: Exit header mode
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = exitCallback,
        },
        -- X button: Clear sort
        {
            ---@diagnostic disable-next-line: undefined-global
            name = GetString(rawget(_G, "SI_BETTERUI_CLEAR_SORT")),
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                local currentDirection = controller.sortDirections[controller.currentColumnIndex]
                return currentDirection and currentDirection ~= SORT_DIRECTION.NONE
            end,
            callback = function()
                if controller:ClearSort() then
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- LB: Navigate to previous column (visible on keybind strip)
        -- Shows the previous column name for discoverability
        {
            order = 40,
            name = function()
                local idx = controller.currentColumnIndex
                if idx > 1 then
                    local col = controller.columns[idx - 1]
                    return col and (col.originalText or col.name) or ""
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            visible = function()
                return controller.currentColumnIndex > 1
            end,
            callback = function()
                if controller:NavigateLeft() then
                    PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- RB: Navigate to next column (visible on keybind strip)
        -- Shows the next column name for discoverability
        {
            order = 50,
            name = function()
                local idx = controller.currentColumnIndex
                if idx < #controller.columns then
                    local col = controller.columns[idx + 1]
                    return col and (col.originalText or col.name) or ""
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            visible = function()
                return controller.currentColumnIndex < #controller.columns
            end,
            callback = function()
                if controller:NavigateRight() then
                    PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- Y button: Already in header mode, show current state (no-op)
        -- This prevents Y from being "lost" when main keybinds are removed
        {
            name = GetString(rawget(_G, "SI_BETTERUI_HEADER_SORT")),
            keybind = "UI_SHORTCUT_QUINARY",
            ethereal = true, -- Hidden since A already shows "Sort"
            callback = function()
                -- Already in header mode, no action needed
                -- This captures the Y press to prevent it from falling through
            end,
        },
        -- NOTE: Stick-direction keybinds (UI_SHORTCUT_LEFT_STICK_*) do not work in
        -- header sort mode because DIRECTIONAL_INPUT routes stick input to the game
        -- world when no list is actively consuming it. B button is the reliable exit.
    }
end
