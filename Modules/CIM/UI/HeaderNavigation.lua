BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.HeaderNavigation = BETTERUI.CIM.HeaderNavigation or {}

local NavState = BETTERUI.CIM.NavigationState

---@param instance table
---@return table
function BETTERUI.CIM.HeaderNavigation.GetOrCreateState(instance)
    if not instance._navState then
        instance._navState = NavState.Create()
    end
    return instance._navState
end

---@param instance table
---@param delta integer
---@param options {categories: table[], getCurrentIndex: fun(): integer, tabBar: table?, setCurrentIndex: fun(idx: integer)?, onRefresh: fun()?}
---@return nil
function BETTERUI.CIM.HeaderNavigation.CycleCategory(instance, delta, options)
    if not options.categories or #options.categories < 2 then return end

    local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(instance)
    local count = #options.categories
    local currentIdx = options.getCurrentIndex() or 1
    local newIdx = BETTERUI.CIM.Utils.WrapValue(currentIdx + delta, count)

    local L = BETTERUI.Log
    if L and L.EnabledFor and L.EnabledFor(L.LEVEL.TRACE, L.CATEGORY.CATEGORY) then
        local N = BETTERUI.CIM and BETTERUI.CIM.Names
        local nm = (N and type(N.Category) == "function" and N.Category(options.categories, newIdx))
            or ("index " .. tostring(newIdx))
        local dir = (delta or 0) >= 0 and "next" or "prev"
        L.Trace(L.CATEGORY.CATEGORY,
            "cycle category " .. dir .. " to '" .. nm .. "' (index " .. tostring(currentIdx) .. " -> " .. tostring(newIdx) .. ")",
            { category = nm, delta = delta, prevIdx = currentIdx, newIdx = newIdx })
    end

    -- Save position for current category BEFORE switching
    if instance.SaveListPosition then
        instance:SaveListPosition()
    end

    -- Flag to prevent onSelectedChanged from saving again
    NavState.StartCycling(state)

    -- Drive selection via tabBar if available
    if options.tabBar then
        options.tabBar:SetSelectedIndex(newIdx, true, true)
    else
        -- Manual update
        options.setCurrentIndex(newIdx)
        if options.onRefresh then
            options.onRefresh()
        end
    end

    NavState.StopCycling(state)
end

---@param options {delay: integer?, onSave: fun(instance: table)?, sceneCheck: fun(): boolean?, onApply: fun(instance: table, pendingCategoryIndex: integer)?}
---@return fun(instance: table, list: table, selectedData: table)
function BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler(options)
    local delay = options.delay or BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS

    return function(instance, list, selectedData)
        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(instance)

        -- Skip during mode toggle or header suppression
        if NavState.ShouldSuppressCallback(state) then return end

        -- Save position BEFORE switching (unless CycleCategory already did)
        if not NavState.IsCycling(state) and options.onSave then
            BETTERUI.CIM.SafeExecute("HeaderNavigation:onSave", options.onSave, instance)
        end

        -- Capture pending index - don't update immediately to prevent corruption
        local pendingCategoryIndex = list.selectedIndex or 1

        local prevIdx = instance.currentCategoryIndex or 1
        local delta = pendingCategoryIndex - prevIdx
        local L = BETTERUI.Log
        if L and L.EnabledFor and L.EnabledFor(L.LEVEL.TRACE, L.CATEGORY.CATEGORY) then
            local nm = (type(selectedData) == "table" and (selectedData.text or selectedData.name))
                or ("index " .. tostring(pendingCategoryIndex))
            L.Trace(L.CATEGORY.CATEGORY,
                "category selected -> '" .. tostring(nm) .. "' (index " .. tostring(prevIdx) .. " -> " .. tostring(pendingCategoryIndex) .. ")",
                { category = nm, delta = delta, prevIdx = prevIdx, newIdx = pendingCategoryIndex })
        end

        -- Start coalesced change using NavigationState
        local token = NavState.StartCategoryChange(state, pendingCategoryIndex)

        -- Cancel any previously-scheduled apply so rapid category cycling does not
        -- leak timers and a superseded apply cannot fire against a stale instance.
        if state._pendingApplyCallId then
            zo_removeCallLater(state._pendingApplyCallId)
            state._pendingApplyCallId = nil
        end

        state._pendingApplyCallId = zo_callLater(function()
            state._pendingApplyCallId = nil

            -- Check if scene is still visible
            if options.sceneCheck and not options.sceneCheck() then
                NavState.CancelCategoryChange(state, token)
                return
            end

            -- Finish change if token is still valid
            if not NavState.FinishCategoryChange(state, token) then
                return -- Stale callback
            end

            if options.onApply then
                BETTERUI.CIM.SafeExecute("HeaderNavigation:onApply", options.onApply, instance, pendingCategoryIndex)
            end
        end, delay)
    end
end

--- Cancels any pending coalesced category-change timer for an instance.
--- Call from scene teardown/cleanup so a deferred onApply cannot run against a
--- torn-down instance after the scene has hidden.
---@param instance table
---@return nil
function BETTERUI.CIM.HeaderNavigation.CancelPending(instance)
    local state = instance and instance._navState
    if state and state._pendingApplyCallId then
        zo_removeCallLater(state._pendingApplyCallId)
        state._pendingApplyCallId = nil
    end
end
