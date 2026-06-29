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
local AddOwnershipPayload

local function EnsureControllerReady()
    if SORT_DIRECTION then return true end
    local controller = BETTERUI.CIM.UI.HeaderSortController
    if not controller then return false end
    SORT_DIRECTION = controller.SORT_DIRECTION
    return SORT_DIRECTION ~= nil
end

local function TraceHeaderSortKeybind(controller, action, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.action = action
    data.columnIndex = controller and controller.currentColumnIndex
    data.columnCount = controller and controller.columns and #controller.columns or 0
    local currentColumn = controller and controller.columns and controller.columns[controller.currentColumnIndex] or nil
    data.currentColumnKey = currentColumn and currentColumn.key
    data.currentColumnName = currentColumn and (currentColumn.originalText or currentColumn.name) or nil
    if controller and controller._headerSortKeybindDescriptor and L.DescribeKeybindDescriptor then
        data.headerKeybinds = L.DescribeKeybindDescriptor(controller._headerSortKeybindDescriptor, "header")
    end
    if controller and controller.GetActiveSortColumn then
        local ok, column, direction = pcall(function() return controller:GetActiveSortColumn() end)
        if ok then
            data.sortColumn = column and column.key
            data.direction = direction
        end
    end
    if AddOwnershipPayload then
        AddOwnershipPayload(controller, data)
    end
    L.TraceEvent(L.CATEGORY.SORT, "sort.header_keybind", phase, data)
end

local function IsKeybindGroupPresent(descriptor)
    local hasGroup = BETTERUI.Interface and BETTERUI.Interface.HasKeybindGroup
    return type(hasGroup) == "function" and hasGroup(descriptor) == true
end

local function IsHeaderSortKeybindPresent(controller)
    return IsKeybindGroupPresent(controller and controller._headerSortKeybindDescriptor)
end

local function RemoveKeybindGroupIfPresent(descriptor)
    local removeGroup = BETTERUI.Interface and BETTERUI.Interface.RemoveKeybindGroupIfPresent
    if type(removeGroup) ~= "function" then return false end
    local ok, removed = pcall(removeGroup, descriptor)
    return ok and removed == true
end

local function EnsureKeybindGroupAdded(descriptor)
    local ensure = BETTERUI.Interface and BETTERUI.Interface.EnsureKeybindGroupAdded or nil
    if type(ensure) == "function" then
        local ok, added = pcall(ensure, descriptor)
        return ok and added == true, ok and nil or tostring(added)
    end
    return false, "missingKeybindHelper"
end

function AddOwnershipPayload(controller, data)
    data = data or {}
    local integration = controller and controller._headerSortIntegration or nil
    local owner = integration and integration.owner or nil
    local mainDescriptor = integration and integration.keybinds and integration.keybinds.mainDescriptor or nil
    data.integrationActive = integration and integration.isActive == true or false
    data.ownerHeaderSort = owner and owner.isInHeaderSortMode == true or false
    data.stripHasHeader = IsHeaderSortKeybindPresent(controller)
    data.stripHasMain = IsKeybindGroupPresent(mainDescriptor)
    data.listSuspended = integration and integration.reactivateListAfterHeaderSort == true or false
    return data
end

local function EnsureHeaderSortOwnership(controller, action)
    local integration = controller and controller._headerSortIntegration or nil
    local descriptor = controller and controller._headerSortKeybindDescriptor or nil
    local before = AddOwnershipPayload(controller, {})

    if not (integration and integration.isActive == true) then
        return {
            neededRepair = false,
            repaired = false,
            ensureOk = true,
            before = before,
            after = before,
        }
    end

    local neededRepair = before.stripHasHeader ~= true or before.stripHasMain == true
    local removedOwnerGroups = 0
    local keybinds = integration.keybinds or {}

    if RemoveKeybindGroupIfPresent(keybinds.mainDescriptor) then
        removedOwnerGroups = removedOwnerGroups + 1
    end
    for _, ownedDescriptor in ipairs(keybinds.ownedDescriptors or {}) do
        if RemoveKeybindGroupIfPresent(ownedDescriptor) then
            removedOwnerGroups = removedOwnerGroups + 1
        end
    end

    local ensureOk, ensureError = EnsureKeybindGroupAdded(descriptor)
    local after = AddOwnershipPayload(controller, {})
    local repaired = neededRepair and after.stripHasHeader == true and after.stripHasMain ~= true

    if neededRepair and BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SORT,
            repaired and "header sort keybind ownership repaired" or "header sort keybind ownership lost", {
                action = action,
                ensureOk = ensureOk,
                ensureError = ensureError,
                removedOwnerGroups = removedOwnerGroups,
                beforeStripHasHeader = before.stripHasHeader,
                beforeStripHasMain = before.stripHasMain,
                afterStripHasHeader = after.stripHasHeader,
                afterStripHasMain = after.stripHasMain,
                integrationActive = after.integrationActive,
                ownerHeaderSort = after.ownerHeaderSort,
                listSuspended = after.listSuspended,
            })
    end

    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.SORT, "sort.header_keybind_ownership",
            neededRepair and (repaired and "repaired" or "repair_failed") or "verified", {
                action = action,
                ensureOk = ensureOk,
                ensureError = ensureError,
                removedOwnerGroups = removedOwnerGroups,
                beforeStripHasHeader = before.stripHasHeader,
                beforeStripHasMain = before.stripHasMain,
                afterStripHasHeader = after.stripHasHeader,
                afterStripHasMain = after.stripHasMain,
                integrationActive = after.integrationActive,
                ownerHeaderSort = after.ownerHeaderSort,
                listSuspended = after.listSuspended,
            })
    end

    return {
        neededRepair = neededRepair,
        repaired = repaired,
        ensureOk = ensureOk,
        ensureError = ensureError,
        removedOwnerGroups = removedOwnerGroups,
        before = before,
        after = after,
    }
end

local function RefreshHeaderSortKeybinds(controller, action)
    local descriptor = controller and controller._headerSortKeybindDescriptor
    local refreshPath = "none"
    local refreshOk = false
    local refreshError = nil

    local updateCurrent = BETTERUI.Interface and BETTERUI.Interface.UpdateCurrentKeybindGroups
    if type(updateCurrent) == "function" then
        refreshPath = "current"
        local ok, updated = pcall(updateCurrent)
        refreshOk = ok and updated == true
        refreshError = ok and nil or tostring(updated)
    end

    local updateGroup = BETTERUI.Interface and BETTERUI.Interface.UpdateKeybindGroup
    if not refreshOk and descriptor and type(updateGroup) == "function" then
        refreshPath = refreshPath == "none" and "descriptor" or "descriptorFallback"
        local ok, updated = pcall(updateGroup, descriptor)
        refreshOk = ok and updated == true
        refreshError = ok and nil or tostring(updated)
    end

    if refreshPath == "none" then
        refreshError = "missingKeybindRefresh"
    end

    local repair = EnsureHeaderSortOwnership(controller, action)
    local ownership = AddOwnershipPayload(controller, {
        refreshPath = refreshPath,
        refreshOk = refreshOk,
        refreshError = refreshError,
        ownershipRepairNeeded = repair and repair.neededRepair == true or false,
        ownershipRepaired = repair and repair.repaired == true or false,
        ownershipEnsureOk = repair and repair.ensureOk == true or false,
        ownershipEnsureError = repair and repair.ensureError or nil,
        removedOwnerGroups = repair and repair.removedOwnerGroups or 0,
    })
    TraceHeaderSortKeybind(controller, action, "refresh", ownership)

    local ownershipLost = ownership.integrationActive == true and ownership.stripHasHeader ~= true
    local ownerMainReappeared = ownership.integrationActive == true and ownership.stripHasMain == true
    if (ownershipLost or ownerMainReappeared) and not (repair and repair.neededRepair == true)
        and BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SORT, "header sort keybind ownership lost", {
            action = action,
            refreshPath = refreshPath,
            refreshOk = refreshOk,
            refreshError = refreshError,
            reason = ownershipLost and "missingHeaderKeybind" or "ownerMainKeybindActive",
            stripHasHeader = ownership.stripHasHeader,
            stripHasMain = ownership.stripHasMain,
            integrationActive = ownership.integrationActive,
            ownerHeaderSort = ownership.ownerHeaderSort,
            listSuspended = ownership.listSuspended,
        })
    elseif not refreshOk and BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SORT, "header sort keybind refresh failed", {
            action = action,
            refreshPath = refreshPath,
            refreshError = refreshError,
            stripHasHeader = ownership.stripHasHeader,
            stripHasMain = ownership.stripHasMain,
            integrationActive = ownership.integrationActive,
            ownerHeaderSort = ownership.ownerHeaderSort,
            listSuspended = ownership.listSuspended,
        })
    end
    return refreshOk, refreshPath
end

-- SORT FUNCTION HELPERS

---@return fun(left: table, right: table): boolean|nil
function BETTERUI.CIM.UI.HeaderSortController:GetSortComparator()
    if not EnsureControllerReady() then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SORT, "get sort comparator not ready")
        end
        return nil
    end

    local column, direction = self:GetActiveSortColumn()
    if not column or direction == SORT_DIRECTION.NONE then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "get sort comparator none")
        end
        return nil
    end

    local baseSortFn = column.sortFn
    if not baseSortFn then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SORT, "get sort comparator no fn", { key = column.key })
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
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "create header sort keybind descriptor", { ready = ready, columnCount = #self.columns })
    end

    local controller = self

    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- A button: Toggle sort direction
        {
            name = GetString(rawget(_G, "SI_BETTERUI_HEADER_SORT")),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                TraceHeaderSortKeybind(controller, "primary", "start")
                local result = controller:ToggleSort()
                PlaySound(SOUNDS.DEFAULT_CLICK)
                local refreshOk, refreshPath = RefreshHeaderSortKeybinds(controller, "primary")
                TraceHeaderSortKeybind(controller, "primary", "end", { handled = result ~= false, refreshOk = refreshOk, refreshPath = refreshPath })
            end,
        },
        -- B button: Exit header mode
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                TraceHeaderSortKeybind(controller, "back", "start")
                if type(exitCallback) ~= "function" then
                    TraceHeaderSortKeybind(controller, "back", "end", {
                        handled = false,
                        reason = "missingCallback",
                    })
                    return nil
                end
                local r1, r2, r3 = exitCallback()
                TraceHeaderSortKeybind(controller, "back", "end", { handled = true })
                return r1, r2, r3
            end,
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
                TraceHeaderSortKeybind(controller, "clear", "start")
                local handled = false
                local reason = nil
                local refreshOk = nil
                local refreshPath = nil
                local cleared, clearReason = controller:ClearSort()
                if cleared then
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    refreshOk, refreshPath = RefreshHeaderSortKeybinds(controller, "clear")
                    handled = true
                else
                    reason = clearReason or controller._lastClearSortReason
                end
                TraceHeaderSortKeybind(controller, "clear", "end", { handled = handled, reason = reason, refreshOk = refreshOk, refreshPath = refreshPath })
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
                TraceHeaderSortKeybind(controller, "left", "start")
                local handled = false
                local refreshOk = nil
                local refreshPath = nil
                if controller:NavigateLeft() then
                    PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
                    refreshOk, refreshPath = RefreshHeaderSortKeybinds(controller, "left")
                    handled = true
                end
                TraceHeaderSortKeybind(controller, "left", "end", { handled = handled, refreshOk = refreshOk, refreshPath = refreshPath })
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
                TraceHeaderSortKeybind(controller, "right", "start")
                local handled = false
                local refreshOk = nil
                local refreshPath = nil
                if controller:NavigateRight() then
                    PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
                    refreshOk, refreshPath = RefreshHeaderSortKeybinds(controller, "right")
                    handled = true
                end
                TraceHeaderSortKeybind(controller, "right", "end", { handled = handled, refreshOk = refreshOk, refreshPath = refreshPath })
            end,
        },
        -- Y button: Already in header mode, show current state (no-op)
        -- This prevents Y from being "lost" when main keybinds are removed
        {
            name = GetString(rawget(_G, "SI_BETTERUI_HEADER_SORT")),
            keybind = "UI_SHORTCUT_TERTIARY",
            ethereal = true, -- Hidden since A already shows "Sort"
            callback = function()
                TraceHeaderSortKeybind(controller, "tertiary", "start", { handled = true, reason = "alreadyInHeaderMode" })
                TraceHeaderSortKeybind(controller, "tertiary", "end", { handled = true, reason = "alreadyInHeaderMode" })
                -- Already in header mode, no action needed
                -- This captures the Y press to prevent it from falling through
            end,
        },
        -- Stick-direction keybinds (UI_SHORTCUT_LEFT_STICK_*) do not work in
        -- header sort mode because DIRECTIONAL_INPUT routes stick input to the game
        -- world when no list is actively consuming it. B button is the reliable exit.
    }
end
