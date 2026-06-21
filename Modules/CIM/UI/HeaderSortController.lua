if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

local SORT_DIRECTION = {
    NONE = 0,
    ASCENDING = 1,
    DESCENDING = 2,
}

BETTERUI.CIM.UI.HeaderSortController = ZO_Object:Subclass()

function BETTERUI.CIM.UI.HeaderSortController:New(listControl, columns, onSortChangedCallback)
    local obj = ZO_Object.New(self)
    obj:Initialize(listControl, columns, onSortChangedCallback)
    return obj
end

function BETTERUI.CIM.UI.HeaderSortController:Initialize(listControl, columns, onSortChangedCallback)
    self.listControl = listControl
    self.columns = columns or {}
    self.onSortChangedCallback = onSortChangedCallback
    self.currentColumnIndex = 1
    self.isHeaderModeActive = false

    self.sortDirections = {}
    for i = 1, #self.columns do
        self.sortDirections[i] = SORT_DIRECTION.NONE
    end

    self.activeSortColumnIndex = nil
end

function BETTERUI.CIM.UI.HeaderSortController:EnterHeaderMode()
    if #self.columns == 0 then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "enter header mode no columns")
        end
        return false
    end

    self.isHeaderModeActive = true
    self.currentColumnIndex = self.activeSortColumnIndex or 1
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SORT, "enter header mode", { currentColumnIndex = self.currentColumnIndex })
    end
    self:UpdateVisuals()
    return true
end

function BETTERUI.CIM.UI.HeaderSortController:ExitHeaderMode()
    self.isHeaderModeActive = false
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SORT, "exit header mode")
    end
    self:UpdateVisuals()
end

function BETTERUI.CIM.UI.HeaderSortController:IsActive()
    return self.isHeaderModeActive
end

function BETTERUI.CIM.UI.HeaderSortController:NavigateLeft()
    if not self.isHeaderModeActive or #self.columns == 0 then
        return false
    end

    if self.currentColumnIndex > 1 then
        self.currentColumnIndex = self.currentColumnIndex - 1
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "sort navigate left", { currentColumnIndex = self.currentColumnIndex })
        end
        self:UpdateVisuals()
        return true
    end
    return false
end

function BETTERUI.CIM.UI.HeaderSortController:NavigateRight()
    if not self.isHeaderModeActive or #self.columns == 0 then
        return false
    end

    if self.currentColumnIndex < #self.columns then
        self.currentColumnIndex = self.currentColumnIndex + 1
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "sort navigate right", { currentColumnIndex = self.currentColumnIndex })
        end
        self:UpdateVisuals()
        return true
    end
    return false
end

function BETTERUI.CIM.UI.HeaderSortController:GetCurrentColumnIndex()
    return self.currentColumnIndex
end

function BETTERUI.CIM.UI.HeaderSortController:GetCurrentColumn()
    return self.columns[self.currentColumnIndex]
end

function BETTERUI.CIM.UI.HeaderSortController:ToggleSort()
    if #self.columns == 0 then
        return false
    end

    return self:ToggleSortForColumn(self.currentColumnIndex)
end

function BETTERUI.CIM.UI.HeaderSortController:ClearSort()
    if #self.columns == 0 then
        return false
    end

    local activeColumnIndex = self.activeSortColumnIndex
    local currentDirection = activeColumnIndex and self.sortDirections[activeColumnIndex]
    if currentDirection and currentDirection ~= SORT_DIRECTION.NONE then
        self.sortDirections[activeColumnIndex] = SORT_DIRECTION.NONE
        local clearedColumn = self.columns[activeColumnIndex]

        self.activeSortColumnIndex = nil

        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SORT, "clear sort", { columnIndex = activeColumnIndex, key = clearedColumn and clearedColumn.key })
        end

        self:UpdateVisuals()

        if self.onSortChangedCallback and clearedColumn then
            BETTERUI.CIM.SafeExecute("HeaderSortController:onSortChangedCallback", self.onSortChangedCallback, clearedColumn.key, SORT_DIRECTION.NONE, clearedColumn.sortFn)
        end
        return true
    end

    return false
end

function BETTERUI.CIM.UI.HeaderSortController:ToggleSortForColumn(columnIndex)
    if not columnIndex or columnIndex < 1 or columnIndex > #self.columns then
        return false
    end

    self.currentColumnIndex = columnIndex

    local currentDirection = self.sortDirections[columnIndex] or SORT_DIRECTION.NONE
    local column = self.columns[columnIndex]
    local startsDescending = column and column.defaultDirection == "descending"

    local newDirection
    if currentDirection == SORT_DIRECTION.NONE then
        if startsDescending then
            newDirection = SORT_DIRECTION.DESCENDING
        else
            newDirection = SORT_DIRECTION.ASCENDING
        end
    elseif currentDirection == SORT_DIRECTION.ASCENDING then
        if startsDescending then
            newDirection = SORT_DIRECTION.NONE
        else
            newDirection = SORT_DIRECTION.DESCENDING
        end
    else -- DESCENDING
        if startsDescending then
            newDirection = SORT_DIRECTION.ASCENDING
        else
            newDirection = SORT_DIRECTION.NONE
        end
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "toggle sort", { col = columnIndex, dir = newDirection })
    end

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

    local callbackColumn = self.columns[columnIndex]
    if not callbackColumn then return false end
    if self.onSortChangedCallback then
        BETTERUI.CIM.SafeExecute("HeaderSortController:onSortChangedCallback", self.onSortChangedCallback, callbackColumn.key, newDirection, callbackColumn.sortFn)
    end

    return true
end

function BETTERUI.CIM.UI.HeaderSortController:GetSortDirection(columnIndex)
    columnIndex = columnIndex or self.currentColumnIndex
    return self.sortDirections[columnIndex] or SORT_DIRECTION.NONE
end

function BETTERUI.CIM.UI.HeaderSortController:GetActiveSortColumn()
    if not self.activeSortColumnIndex then
        return nil, SORT_DIRECTION.NONE
    end
    return self.columns[self.activeSortColumnIndex], self.sortDirections[self.activeSortColumnIndex]
end

function BETTERUI.CIM.UI.HeaderSortController:HasActiveSort()
    local column, direction = self:GetActiveSortColumn()
    return column ~= nil and direction ~= nil and direction ~= SORT_DIRECTION.NONE
end

function BETTERUI.CIM.UI.HeaderSortController:UpdateVisuals()
    local logActive = BETTERUI.Log and BETTERUI.Log.IsActive()
    if logActive then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "update visuals", { columnCount = #self.columns, active = self.isHeaderModeActive, currentColumnIndex = self.currentColumnIndex })
    end
    for i, column in ipairs(self.columns) do
        if column.labelControl then
            local baseName = column.originalText or column.name or ""
            local direction = self.sortDirections[i]
            local isSelected = self.isHeaderModeActive and (i == self.currentColumnIndex)

            local displayText = baseName

            if isSelected then
                displayText = "[" .. displayText .. "]"
            end

            column.labelControl:SetText(displayText)

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

            if isSelected then
                column.labelControl:SetColor(0.77, 0.65, 0.30, 1) -- Gold
            else
                column.labelControl:SetColor(1, 1, 1, 1)          -- White
            end
        end
    end
end

function BETTERUI.CIM.UI.HeaderSortController:SetColumnLabel(columnIndex, labelControl)
    local column = self.columns[columnIndex]
    if not column then return end

    column.labelControl = labelControl

    local originalText = labelControl:GetText()
    if originalText and originalText ~= "" and not column.originalText then
        column.originalText = originalText
    end

    if not column.arrowTexture then
        local baseName = labelControl:GetName()
        local arrowName
        if baseName and baseName ~= "" then
            arrowName = baseName .. "Arrow"
        else
            arrowName = "BETTERUI_HeaderSortArrow_" .. columnIndex
        end
        -- CreateControl returns nil on a duplicate name (e.g. a rebuilt
        -- controller over the same persistent label controls), so reuse the
        -- existing control instead of recreating it.
        local arrow = WINDOW_MANAGER:GetControlByName(arrowName)
        if not arrow then
            arrow = WINDOW_MANAGER:CreateControl(arrowName, labelControl, CT_TEXTURE)
            arrow:SetDimensions(24, 24)
            arrow:SetAnchor(RIGHT, labelControl, LEFT, -4, 0)
            arrow:SetHidden(true)
        end
        column.arrowTexture = arrow
    end

    local controller = self
    labelControl:SetMouseEnabled(true)
    labelControl:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if not controller.isHeaderModeActive then
            controller:EnterHeaderMode()
        end
        controller.currentColumnIndex = columnIndex
        controller:ToggleSortForColumn(columnIndex)
        PlaySound(SOUNDS.MENU_BAR_CLICK)
    end)
end

function BETTERUI.CIM.UI.HeaderSortController:RefreshColumnLabels(headerContainer, columnNamePattern)
    if not headerContainer then return end

    -- Route through SetColumnLabel + UpdateVisuals so the arrow texture and
    -- selection styling stay the single source of truth (no text-markup arrows).
    for i in ipairs(self.columns) do
        local labelName = string.format(columnNamePattern, i)
        local labelControl = headerContainer:GetNamedChild(labelName)
        if labelControl then
            self:SetColumnLabel(i, labelControl)
        end
    end

    self:UpdateVisuals()
end

BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION = SORT_DIRECTION
