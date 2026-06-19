--[[
File: Modules/CIM/UI/HeaderSortKeybinds.lua
Purpose: Keybind factory for HeaderSortController.
         Extracted from HeaderSortController.lua to stay under 600 lines.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

-- Deferred reference: resolved on first use rather than at parse time,
-- removing the hard dependency on load order between Controller and Keybinds.
local SORT_DIRECTION

local function EnsureControllerReady()
    if SORT_DIRECTION then return true end
    local controller = BETTERUI.CIM.UI.HeaderSortController
    if not controller then return false end
    SORT_DIRECTION = controller.SORT_DIRECTION
    return SORT_DIRECTION ~= nil
end

-- SORT FUNCTION HELPERS

---@return fun(left: table, right: table): boolean|nil
function BETTERUI.CIM.UI.HeaderSortController:GetSortComparator()
    if not EnsureControllerReady() then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SORT, "getSortComparatorNotReady")
        end
        return nil
    end

    local column, direction = self:GetActiveSortColumn()
    if not column or direction == SORT_DIRECTION.NONE then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "getSortComparatorNone")
        end
        return nil
    end

    local baseSortFn = column.sortFn
    if not baseSortFn then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SORT, "getSortComparatorNoFn", { key = column.key })
        end
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

-- KEYBIND FACTORY

---@param exitCallback fun()
---@param navigateUpCallback fun()?
---@return table
function BETTERUI.CIM.UI.HeaderSortController:CreateKeybindDescriptor(exitCallback, navigateUpCallback)
    -- Resolve the deferred SORT_DIRECTION reference now so the X-button
    -- visible() closure below never indexes a nil table.
    local ready = EnsureControllerReady()
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "createHeaderSortKeybindDescriptor", { ready = ready, columnCount = #self.columns })
    end

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
            name = GetString(rawget(_G, "SI_BETTERUI_CLEAR_SORT")),
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                -- Resolve the deferred SORT_DIRECTION reference before indexing it;
                -- this callback can fire before the controller finishes loading.
                if not EnsureControllerReady() then return false end
                return controller:HasActiveSort()
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
        -- Stick-direction keybinds (UI_SHORTCUT_LEFT_STICK_*) do not work in
        -- header sort mode because DIRECTIONAL_INPUT routes stick input to the game
        -- world when no list is actively consuming it. B button is the reliable exit.
    }
end
