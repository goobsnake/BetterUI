if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

local SORT_DIRECTION = {
    NONE = 0,
    ASCENDING = 1,
    DESCENDING = 2,
}

BETTERUI.CIM.UI.HeaderSortController = ZO_Object:Subclass()

local function DescribeColumn(column, index)
    if type(column) ~= "table" then return tostring(index) .. ":nil" end
    return tostring(index) .. ":" .. tostring(column.key or column.name or "?")
end

local function DescribeColumns(columns)
    if type(columns) ~= "table" then return nil end
    local parts = {}
    for i = 1, #columns do
        if i > 6 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = DescribeColumn(columns[i], i)
    end
    return table.concat(parts, "|")
end

local function AddColumnPayload(self, data)
    data = data or {}
    data.columnIndex = self and self.currentColumnIndex or nil
    data.columnCount = self and self.columns and #self.columns or 0
    data.headerActive = self and self.isHeaderModeActive == true
    local currentColumn = self and self.columns and self.columns[self.currentColumnIndex] or nil
    data.columnKey = currentColumn and currentColumn.key or nil
    data.columnName = currentColumn and (currentColumn.originalText or currentColumn.name) or nil
    if self and self.GetActiveSortColumn then
        local ok, column, direction = pcall(function() return self:GetActiveSortColumn() end)
        if ok then
            data.activeColumnKey = column and column.key or nil
            data.activeDirection = direction
        end
    end
    return data
end

local function TraceHeaderSortController(self, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    L.TraceEvent(L.CATEGORY.SORT, "sort.header_controller", phase, AddColumnPayload(self, data or {}))
end

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
    TraceHeaderSortController(self, "initialized", {
        columns = DescribeColumns(self.columns),
        hasSortCallback = type(self.onSortChangedCallback) == "function",
    })
end

function BETTERUI.CIM.UI.HeaderSortController:EnterHeaderMode()
    if #self.columns == 0 then
        TraceHeaderSortController(self, "enter_skipped", { reason = "noColumns" })
        return false
    end

    self.isHeaderModeActive = true
    self.currentColumnIndex = self.activeSortColumnIndex or 1
    TraceHeaderSortController(self, "entered", { reason = self.activeSortColumnIndex and "activeSort" or "firstColumn" })
    self:UpdateVisuals()
    return true
end

function BETTERUI.CIM.UI.HeaderSortController:ExitHeaderMode()
    local wasActive = self.isHeaderModeActive == true
    self.isHeaderModeActive = false
    TraceHeaderSortController(self, "exited", { wasActive = wasActive })
    self:UpdateVisuals()
end

function BETTERUI.CIM.UI.HeaderSortController:IsActive()
    return self.isHeaderModeActive
end

function BETTERUI.CIM.UI.HeaderSortController:NavigateLeft()
    if not self.isHeaderModeActive or #self.columns == 0 then
        TraceHeaderSortController(self, "navigate_left_skipped", { reason = self.isHeaderModeActive and "noColumns" or "inactive" })
        return false
    end

    if self.currentColumnIndex > 1 then
        local previousIndex = self.currentColumnIndex
        self.currentColumnIndex = self.currentColumnIndex - 1
        TraceHeaderSortController(self, "navigate_left", { previousColumnIndex = previousIndex })
        self:UpdateVisuals()
        return true
    end
    TraceHeaderSortController(self, "navigate_left_skipped", { reason = "firstColumn" })
    return false
end

function BETTERUI.CIM.UI.HeaderSortController:NavigateRight()
    if not self.isHeaderModeActive or #self.columns == 0 then
        TraceHeaderSortController(self, "navigate_right_skipped", { reason = self.isHeaderModeActive and "noColumns" or "inactive" })
        return false
    end

    if self.currentColumnIndex < #self.columns then
        local previousIndex = self.currentColumnIndex
        self.currentColumnIndex = self.currentColumnIndex + 1
        TraceHeaderSortController(self, "navigate_right", { previousColumnIndex = previousIndex })
        self:UpdateVisuals()
        return true
    end
    TraceHeaderSortController(self, "navigate_right_skipped", { reason = "lastColumn" })
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
        TraceHeaderSortController(self, "toggle_skipped", { reason = "noColumns" })
        return false
    end

    return self:ToggleSortForColumn(self.currentColumnIndex)
end

function BETTERUI.CIM.UI.HeaderSortController:ClearSort()
    if #self.columns == 0 then
        self._lastClearSortReason = "noColumns"
        TraceHeaderSortController(self, "clear_sort_skipped", { reason = "noColumns" })
        return false, "noColumns"
    end

    local activeColumnIndex = self.activeSortColumnIndex
    local currentDirection = activeColumnIndex and self.sortDirections[activeColumnIndex]
    if currentDirection and currentDirection ~= SORT_DIRECTION.NONE then
        self._lastClearSortReason = nil
        self.sortDirections[activeColumnIndex] = SORT_DIRECTION.NONE
        local clearedColumn = self.columns[activeColumnIndex]

        self.activeSortColumnIndex = nil

        TraceHeaderSortController(self, "clear_sort", {
            clearedColumnIndex = activeColumnIndex,
            clearedColumnKey = clearedColumn and clearedColumn.key,
            oldDirection = currentDirection,
        })

        self:UpdateVisuals()

        if self.onSortChangedCallback and clearedColumn then
            TraceHeaderSortController(self, "callback_before", {
                action = "clear",
                callbackColumnKey = clearedColumn.key,
                callbackDirection = SORT_DIRECTION.NONE,
                hasSortFn = clearedColumn.sortFn ~= nil,
            })
            local callbackOk, callbackResult = BETTERUI.CIM.SafeExecute("HeaderSortController:onSortChangedCallback", self.onSortChangedCallback, clearedColumn.key, SORT_DIRECTION.NONE, clearedColumn.sortFn)
            TraceHeaderSortController(self, "callback_after", {
                action = "clear",
                callbackColumnKey = clearedColumn.key,
                callbackDirection = SORT_DIRECTION.NONE,
                hasSortFn = clearedColumn.sortFn ~= nil,
                callbackOk = callbackOk == true,
                callbackError = callbackOk and nil or tostring(callbackResult),
            })
        else
            TraceHeaderSortController(self, "callback_skipped", {
                action = "clear",
                reason = clearedColumn and "missingCallback" or "missingColumn",
            })
        end
        return true
    end

    self._lastClearSortReason = "noActiveSort"
    TraceHeaderSortController(self, "clear_sort_skipped", { reason = "noActiveSort" })
    return false, "noActiveSort"
end

function BETTERUI.CIM.UI.HeaderSortController:ToggleSortForColumn(columnIndex)
    if not columnIndex or columnIndex < 1 or columnIndex > #self.columns then
        TraceHeaderSortController(self, "toggle_skipped", { reason = "invalidColumn", requestedColumnIndex = columnIndex })
        return false
    end

    self.currentColumnIndex = columnIndex

    local currentDirection = self.sortDirections[columnIndex] or SORT_DIRECTION.NONE
    local oldDirection = currentDirection
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

    TraceHeaderSortController(self, "toggle_sort", {
        targetColumnIndex = columnIndex,
        targetColumnKey = column and column.key,
        targetColumnName = column and (column.originalText or column.name),
        oldDirection = oldDirection,
        newDirection = newDirection,
        startsDescending = startsDescending == true,
    })

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
        TraceHeaderSortController(self, "callback_before", {
            action = "toggle",
            callbackColumnKey = callbackColumn.key,
            callbackDirection = newDirection,
            hasSortFn = callbackColumn.sortFn ~= nil,
        })
        local callbackOk, callbackResult = BETTERUI.CIM.SafeExecute("HeaderSortController:onSortChangedCallback", self.onSortChangedCallback, callbackColumn.key, newDirection, callbackColumn.sortFn)
        TraceHeaderSortController(self, "callback_after", {
            action = "toggle",
            callbackColumnKey = callbackColumn.key,
            callbackDirection = newDirection,
            hasSortFn = callbackColumn.sortFn ~= nil,
            callbackOk = callbackOk == true,
            callbackError = callbackOk and nil or tostring(callbackResult),
        })
    else
        TraceHeaderSortController(self, "callback_skipped", {
            action = "toggle",
            reason = "missingCallback",
            callbackColumnKey = callbackColumn.key,
            callbackDirection = newDirection,
            hasSortFn = callbackColumn.sortFn ~= nil,
        })
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
    TraceHeaderSortController(self, "visuals_update", {
        columns = DescribeColumns(self.columns),
    })
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
    if not column then
        TraceHeaderSortController(self, "label_bind_skipped", { reason = "missingColumn", requestedColumnIndex = columnIndex })
        return
    end

    column.labelControl = labelControl

    local originalText = labelControl:GetText()
    if originalText and originalText ~= "" and not column.originalText then
        column.originalText = originalText
    end

    local arrowName
    if not column.arrowTexture then
        local baseName = labelControl:GetName()
        if baseName and baseName ~= "" then
            arrowName = baseName .. "Arrow"
        else
            arrowName = "BETTERUI_HeaderSortArrow_" .. columnIndex
        end
        -- CreateControl returns nil on a duplicate name (e.g. a rebuilt
        -- controller over the same persistent label controls), so reuse only
        -- controls still parented to this label; stale arrows from a prior
        -- scene/control tree get a local fallback name instead.
        local baseArrowName = arrowName
        local arrow = WINDOW_MANAGER:GetControlByName(arrowName)
        if arrow and arrow.GetParent then
            local okParent, parent = pcall(function() return arrow:GetParent() end)
            if okParent and parent ~= labelControl then
                TraceHeaderSortController(self, "arrow_reuse_rejected", {
                    targetColumnIndex = columnIndex,
                    arrowName = arrowName,
                })
                arrow = nil
                local suffix = 1
                while suffix <= 20 do
                    local candidateName = baseArrowName .. "Local" .. tostring(suffix)
                    local candidate = WINDOW_MANAGER:GetControlByName(candidateName)
                    if not candidate then
                        arrowName = candidateName
                        break
                    end
                    local okCandidateParent, candidateParent = candidate.GetParent and pcall(function() return candidate:GetParent() end)
                    if okCandidateParent and candidateParent == labelControl then
                        arrowName = candidateName
                        arrow = candidate
                        break
                    end
                    suffix = suffix + 1
                end
            end
        end
        if not arrow then
            arrow = WINDOW_MANAGER:CreateControl(arrowName, labelControl, CT_TEXTURE)
            if arrow then
                arrow:SetDimensions(24, 24)
                arrow:SetAnchor(RIGHT, labelControl, LEFT, -4, 0)
                arrow:SetHidden(true)
            end
        end
        column.arrowTexture = arrow
    end
    if not arrowName and column.arrowTexture and column.arrowTexture.GetName then
        local okArrowName, existingArrowName = pcall(function() return column.arrowTexture:GetName() end)
        if okArrowName and existingArrowName and existingArrowName ~= "" then
            arrowName = existingArrowName
        end
    end

    TraceHeaderSortController(self, "label_bound", {
        targetColumnIndex = columnIndex,
        targetColumnKey = column.key,
        label = column.originalText or column.name,
        arrow = arrowName,
        arrowCreated = column.arrowTexture ~= nil,
    })

    labelControl._betteruiHeaderSortController = self
    labelControl._betteruiHeaderSortColumnIndex = columnIndex
    labelControl:SetMouseEnabled(true)

    local function OnHeaderSortMouseUp(control, button)
        local controller = control and control._betteruiHeaderSortController
        local activeColumnIndex = control and control._betteruiHeaderSortColumnIndex
        if not (controller and activeColumnIndex) then return end

        TraceHeaderSortController(controller, "mouse_sort_start", {
            targetColumnIndex = activeColumnIndex,
            button = button,
        })
        if button ~= MOUSE_BUTTON_INDEX_LEFT then
            TraceHeaderSortController(controller, "mouse_sort_skipped", {
                targetColumnIndex = activeColumnIndex,
                reason = "nonLeftButton",
                button = button,
            })
            return
        end
        local entered = true
        if not controller.isHeaderModeActive then
            entered = controller:EnterHeaderMode() ~= false
        end
        controller.currentColumnIndex = activeColumnIndex
        local handled = controller:ToggleSortForColumn(activeColumnIndex) ~= false
        PlaySound(SOUNDS.MENU_BAR_CLICK)
        TraceHeaderSortController(controller, "mouse_sort_end", {
            targetColumnIndex = activeColumnIndex,
            entered = entered,
            handled = handled,
        })
    end

    if not labelControl._betteruiHeaderSortMouseUpHooked then
        labelControl._betteruiHeaderSortMouseUpHooked = true
        if ZO_PostHookHandler then
            ZO_PostHookHandler(labelControl, "OnMouseUp", OnHeaderSortMouseUp)
        else
            local previousHandler = labelControl.GetHandler and labelControl:GetHandler("OnMouseUp") or nil
            labelControl:SetHandler("OnMouseUp", function(control, ...)
                local returns = previousHandler and { previousHandler(control, ...) } or nil
                OnHeaderSortMouseUp(control, ...)
                if returns then return unpack(returns) end
            end)
        end
    end
    self:UpdateVisuals()
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
