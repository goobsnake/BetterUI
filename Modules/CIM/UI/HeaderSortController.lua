--[[
File: Modules/CIM/UI/HeaderSortController.lua
Purpose: Manages column header navigation and sorting for parametric lists.
         Enables gamepad users to navigate to column headers and toggle sort direction.
Author: BetterUI Team
Last Modified: 2026-01-30

KEY RESPONSIBILITIES:
    * Manages header navigation mode state
    * Tracks current column selection and sort direction per column
    * Provides visual feedback through arrow indicators (▲/▼)
    * Handles D-pad navigation within header row
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

-------------------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------------------

local SORT_DIRECTION = {
    NONE = 0,
    ASCENDING = 1,
    DESCENDING = 2,
}

-- Sort arrow indicators using ESO inline texture markup
-- Format: |tWidth:Height:TexturePath|t
local SORT_ARROW = {
    [SORT_DIRECTION.NONE] = "",
    [SORT_DIRECTION.ASCENDING] = "|t20:20:EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds|t ",
    [SORT_DIRECTION.DESCENDING] = "|t20:20:EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds|t ",
}

-------------------------------------------------------------------------------------------------
-- CLASS DEFINITION
-------------------------------------------------------------------------------------------------

---@class HeaderSortController
---@field columns table[] Array of column definitions {name, key, sortFn, labelControl}
---@field currentColumnIndex number Currently selected column (1-indexed)
---@field sortDirections table<number, number> Sort direction per column index
---@field isHeaderModeActive boolean True when user is navigating header row
---@field listControl table Reference to the parametric list control
---@field onSortChangedCallback function Callback when sort changes
BETTERUI.CIM.UI.HeaderSortController = ZO_Object:Subclass()

--[[
Function: HeaderSortController:New
Description: Creates a new HeaderSortController instance.
param: listControl (table) - The parametric scroll list control.
param: columns (table[]) - Array of column definitions: {name="NAME", key="name", sortFn=BETTERUI.CIM.SortByName}
param: onSortChangedCallback (function) - Called when sort changes: function(columnKey, direction)
return: HeaderSortController - New instance.
]]
--- @param listControl table The parametric scroll list control
--- @param columns table[] Array of column definitions
--- @param onSortChangedCallback function Callback when sort changes
--- @return table instance New HeaderSortController instance
function BETTERUI.CIM.UI.HeaderSortController:New(listControl, columns, onSortChangedCallback)
    local obj = ZO_Object.New(self)
    obj:Initialize(listControl, columns, onSortChangedCallback)
    return obj
end

--[[
Function: HeaderSortController:Initialize
Description: Initializes the controller state.
]]
function BETTERUI.CIM.UI.HeaderSortController:Initialize(listControl, columns, onSortChangedCallback)
    self.listControl = listControl
    self.columns = columns or {}
    self.onSortChangedCallback = onSortChangedCallback
    self.currentColumnIndex = 1
    self.isHeaderModeActive = false

    -- Initialize sort directions for each column (default: NONE)
    self.sortDirections = {}
    for i = 1, #self.columns do
        self.sortDirections[i] = SORT_DIRECTION.NONE
    end

    -- Track which column is the primary sort (only one can be active)
    self.activeSortColumnIndex = nil
end

-------------------------------------------------------------------------------------------------
-- STATE MANAGEMENT
-------------------------------------------------------------------------------------------------

--[[
Function: HeaderSortController:EnterHeaderMode
Description: Enters header navigation mode.
return: boolean - True if successfully entered header mode.
]]
--- @return boolean success True if successfully entered header mode
function BETTERUI.CIM.UI.HeaderSortController:EnterHeaderMode()
    if #self.columns == 0 then
        return false
    end

    self.isHeaderModeActive = true
    self.currentColumnIndex = self.activeSortColumnIndex or 1
    self:UpdateVisuals()
    return true
end

--[[
Function: HeaderSortController:ExitHeaderMode
Description: Exits header navigation mode.
]]
function BETTERUI.CIM.UI.HeaderSortController:ExitHeaderMode()
    self.isHeaderModeActive = false
    self:UpdateVisuals()
end

--[[
Function: HeaderSortController:IsActive
Description: Returns whether header mode is currently active.
return: boolean - True if in header navigation mode.
]]
--- @return boolean isActive True if in header navigation mode
function BETTERUI.CIM.UI.HeaderSortController:IsActive()
    return self.isHeaderModeActive
end

-------------------------------------------------------------------------------------------------
-- NAVIGATION
-------------------------------------------------------------------------------------------------

--[[
Function: HeaderSortController:NavigateLeft
Description: Moves selection to the previous column.
return: boolean - True if navigation occurred.
]]
--- @return boolean moved True if navigation occurred
function BETTERUI.CIM.UI.HeaderSortController:NavigateLeft()
    if not self.isHeaderModeActive or #self.columns == 0 then
        return false
    end

    if self.currentColumnIndex > 1 then
        self.currentColumnIndex = self.currentColumnIndex - 1
        self:UpdateVisuals()
        return true
    end
    return false
end

--[[
Function: HeaderSortController:NavigateRight
Description: Moves selection to the next column.
return: boolean - True if navigation occurred.
]]
--- @return boolean moved True if navigation occurred
function BETTERUI.CIM.UI.HeaderSortController:NavigateRight()
    if not self.isHeaderModeActive or #self.columns == 0 then
        return false
    end

    if self.currentColumnIndex < #self.columns then
        self.currentColumnIndex = self.currentColumnIndex + 1
        self:UpdateVisuals()
        return true
    end
    return false
end

--[[
Function: HeaderSortController:GetCurrentColumnIndex
Description: Returns the currently selected column index.
return: number - Current column index (1-indexed).
]]
--- @return number index Current column index (1-indexed)
function BETTERUI.CIM.UI.HeaderSortController:GetCurrentColumnIndex()
    return self.currentColumnIndex
end

--[[
Function: HeaderSortController:GetCurrentColumn
Description: Returns the currently selected column definition.
return: table|nil - Column definition or nil if none selected.
]]
--- @return table|nil column Current column definition or nil
function BETTERUI.CIM.UI.HeaderSortController:GetCurrentColumn()
    return self.columns[self.currentColumnIndex]
end

-------------------------------------------------------------------------------------------------
-- SORTING
-------------------------------------------------------------------------------------------------

--[[
Function: HeaderSortController:ToggleSort
Description: Toggles sort direction for the current column.
             Cycles: NONE → ASCENDING → DESCENDING → NONE
             Clears sort on other columns when a new column is sorted.
return: boolean - True if sort was toggled.
]]
--- @return boolean toggled True if sort was toggled
function BETTERUI.CIM.UI.HeaderSortController:ToggleSort()
    if #self.columns == 0 then
        return false
    end

    return self:ToggleSortForColumn(self.currentColumnIndex)
end

--[[
Function: HeaderSortController:ClearSort
Description: Clears the sort direction for the current column.
return: boolean - True if sort was cleared.
]]
--- @return boolean cleared True if sort was cleared
function BETTERUI.CIM.UI.HeaderSortController:ClearSort()
    if #self.columns == 0 then
        return false
    end

    local currentDirection = self.sortDirections[self.currentColumnIndex]
    if currentDirection ~= SORT_DIRECTION.NONE then
        self.sortDirections[self.currentColumnIndex] = SORT_DIRECTION.NONE
        local clearedColumn = self.columns[self.currentColumnIndex]

        if self.activeSortColumnIndex == self.currentColumnIndex then
            self.activeSortColumnIndex = nil
        end

        self:UpdateVisuals()

        if self.onSortChangedCallback and clearedColumn then
            self.onSortChangedCallback(clearedColumn.key, SORT_DIRECTION.NONE, clearedColumn.sortFn)
        end
        return true
    end

    return false
end

--[[
Function: HeaderSortController:ToggleSortForColumn
Description: Toggles sort direction for a specific column (used by mouse clicks).
             Cycles: NONE → ASCENDING → DESCENDING → NONE
param: columnIndex (number) - The column to toggle.
return: boolean - True if sort was toggled.
]]
--- @param columnIndex number Column index to toggle
--- @return boolean toggled True if sort was toggled
function BETTERUI.CIM.UI.HeaderSortController:ToggleSortForColumn(columnIndex)
    if not columnIndex or columnIndex < 1 or columnIndex > #self.columns then
        return false
    end

    -- Update current column index for focus tracking (even when not in header mode)
    self.currentColumnIndex = columnIndex

    local currentDirection = self.sortDirections[columnIndex] or SORT_DIRECTION.NONE
    local column = self.columns[columnIndex]
    local startsDescending = column and column.defaultDirection == "descending"

    -- Cycle through directions
    -- Normal columns: NONE → ASCENDING → DESCENDING → NONE
    -- Descending-default columns: NONE → DESCENDING → ASCENDING → NONE
    local newDirection
    if currentDirection == SORT_DIRECTION.NONE then
        -- Start with column's default direction
        if startsDescending then
            newDirection = SORT_DIRECTION.DESCENDING
        else
            newDirection = SORT_DIRECTION.ASCENDING
        end
    elseif currentDirection == SORT_DIRECTION.ASCENDING then
        -- ASC goes to DESC for normal, goes to NONE for descending-default
        if startsDescending then
            newDirection = SORT_DIRECTION.NONE
        else
            newDirection = SORT_DIRECTION.DESCENDING
        end
    else -- DESCENDING
        -- DESC goes to NONE for normal, goes to ASC for descending-default
        if startsDescending then
            newDirection = SORT_DIRECTION.ASCENDING
        else
            newDirection = SORT_DIRECTION.NONE
        end
    end

    -- Clear other columns if we're setting a direction
    if newDirection ~= SORT_DIRECTION.NONE then
        for i = 1, #self.columns do
            if i ~= columnIndex then
                self.sortDirections[i] = SORT_DIRECTION.NONE
            end
        end
        self.activeSortColumnIndex = columnIndex
    else
        self.activeSortColumnIndex = nil
    end

    self.sortDirections[columnIndex] = newDirection
    self:UpdateVisuals()

    -- Notify callback
    if self.onSortChangedCallback then
        local column = self.columns[columnIndex]
        self.onSortChangedCallback(column.key, newDirection, column.sortFn)
    end

    return true
end

--[[
Function: HeaderSortController:GetSortDirection
Description: Returns the sort direction for a column.
param: columnIndex (number) - Column index (1-indexed). If nil, uses current column.
return: number - Sort direction constant (NONE, ASCENDING, DESCENDING).
]]
--- @param columnIndex number|nil Column index (1-indexed), nil for current
--- @return number direction Sort direction constant
function BETTERUI.CIM.UI.HeaderSortController:GetSortDirection(columnIndex)
    columnIndex = columnIndex or self.currentColumnIndex
    return self.sortDirections[columnIndex] or SORT_DIRECTION.NONE
end

--[[
Function: HeaderSortController:GetActiveSortColumn
Description: Returns the currently active sort column and direction.
return: table|nil, number - Column definition and direction, or nil if no sort active.
]]
--- @return table|nil column Active sort column definition
--- @return number direction Sort direction
function BETTERUI.CIM.UI.HeaderSortController:GetActiveSortColumn()
    if not self.activeSortColumnIndex then
        return nil, SORT_DIRECTION.NONE
    end
    return self.columns[self.activeSortColumnIndex], self.sortDirections[self.activeSortColumnIndex]
end

-------------------------------------------------------------------------------------------------
-- VISUAL UPDATES
-------------------------------------------------------------------------------------------------

--[[
Function: HeaderSortController:UpdateVisuals
Description: Updates column header visual indicators (highlights and arrows).
             Call this after any state change.
]]
function BETTERUI.CIM.UI.HeaderSortController:UpdateVisuals()
    for i, column in ipairs(self.columns) do
        if column.labelControl then
            -- Use cached originalText (localized) if available, otherwise fall back to column.name
            local baseName = column.originalText or column.name
            local direction = self.sortDirections[i]
            local isSelected = self.isHeaderModeActive and (i == self.currentColumnIndex)

            -- Build display text (no arrow in text - arrows are separate textures)
            local displayText = baseName

            -- Add bracket highlight for selected column in header mode
            if isSelected then
                displayText = "[" .. displayText .. "]"
            end

            column.labelControl:SetText(displayText)

            -- Update arrow texture visibility and image
            if column.arrowTexture then
                if direction == SORT_DIRECTION.ASCENDING then
                    column.arrowTexture:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds")
                    column.arrowTexture:SetHidden(false)
                elseif direction == SORT_DIRECTION.DESCENDING then
                    column.arrowTexture:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds")
                    column.arrowTexture:SetHidden(false)
                else
                    column.arrowTexture:SetHidden(true)
                end
            end

            -- Optional: Change color for selected column
            if isSelected then
                column.labelControl:SetColor(0.77, 0.65, 0.30, 1) -- Gold
            else
                column.labelControl:SetColor(1, 1, 1, 1)          -- White
            end
        end
    end
end

--[[
Function: HeaderSortController:SetColumnLabel
Description: Associates a label control with a column, creates an arrow texture,
             and registers mouse click handler for interactive sorting.
param: columnIndex (number) - Column index (1-indexed).
param: labelControl (table) - The label control to update.
]]
--- @param columnIndex number Column index (1-indexed)
--- @param labelControl table The label control to update
function BETTERUI.CIM.UI.HeaderSortController:SetColumnLabel(columnIndex, labelControl)
    if self.columns[columnIndex] then
        self.columns[columnIndex].labelControl = labelControl

        -- Cache the original localized text from the label for proper display
        -- The column.name field is just an identifier like "NAME", not the localized text
        local originalText = labelControl:GetText()
        if originalText and originalText ~= "" then
            self.columns[columnIndex].originalText = originalText
        end

        -- Create arrow texture control if it doesn't exist
        if not self.columns[columnIndex].arrowTexture then
            -- Safety check: labelControl might not have a name if created dynamically
            local baseName = labelControl:GetName()
            local arrowName
            if baseName and baseName ~= "" then
                arrowName = baseName .. "Arrow"
            else
                -- Generate unique name based on column index
                arrowName = "BETTERUI_HeaderSortArrow_" .. columnIndex
            end
            -- Parent to the label itself so it moves with the column
            local arrow = WINDOW_MANAGER:CreateControl(arrowName, labelControl, CT_TEXTURE)
            arrow:SetDimensions(24, 24)
            -- Position arrow to the LEFT of the label text, vertically centered
            arrow:SetAnchor(RIGHT, labelControl, LEFT, -4, 0)
            arrow:SetHidden(true)
            self.columns[columnIndex].arrowTexture = arrow
        end

        -- Register mouse click handler for interactive sorting
        local controller = self
        labelControl:SetMouseEnabled(true)
        labelControl:SetHandler("OnMouseUp", function(control, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                -- Enter header mode if not active, select this column, and toggle sort
                if not controller.isHeaderModeActive then
                    controller:EnterHeaderMode()
                end
                controller.currentColumnIndex = columnIndex
                controller:ToggleSortForColumn(columnIndex)
                PlaySound(SOUNDS.MENU_BAR_CLICK)
            end
        end)
    end
end

--[[
Function: HeaderSortController:RefreshColumnLabels
Description: Finds and caches column label controls from a header container.
param: headerContainer (table) - The header control containing column labels.
param: columnNamePattern (string) - Pattern to find column labels, e.g., "Column%dLabel".
]]
--- @param headerContainer table The header control containing column labels
--- @param columnNamePattern string Pattern to find column labels
function BETTERUI.CIM.UI.HeaderSortController:RefreshColumnLabels(headerContainer, columnNamePattern)
    if not headerContainer then return end

    for i, column in ipairs(self.columns) do
        local labelName = string.format(columnNamePattern, i)
        local labelControl = headerContainer:GetNamedChild(labelName)
        if labelControl then
            self.columns[i].labelControl = labelControl
            -- Set initial text
            labelControl:SetText(column.name .. (SORT_ARROW[self.sortDirections[i]] or ""))
        end
    end
end

-------------------------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------------------------

-- Export sort direction constants for external use (keybind factory in HeaderSortKeybinds.lua reads this)
BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION = SORT_DIRECTION
-- GetSortComparator and CreateKeybindDescriptor live in HeaderSortKeybinds.lua (loaded after this file)
