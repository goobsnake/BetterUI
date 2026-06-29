--[[
File: Modules/ResourceOrbFrames/Core/ElementDrag.lua
Purpose: Drag-to-move system for ResourceOrbFrames UI elements.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Drag then BETTERUI.ResourceOrbFrames.Drag = {} end

local Drag = BETTERUI.ResourceOrbFrames.Drag

local m_handles = {}
local m_handleHosts = {}
local HANDLE_SIZE = 80
local DRAG_THRESHOLD = 2
local DRAG_REFRESH_INTERVAL_MS = 75
local OFFSET_MIN = -600
local OFFSET_MAX = 600
local SETTINGS_PANEL_IDS = {
    "BETTERUI_Modules",
    "BETTERUI_ResourceOrbFrames",
}

local function TraceDrag(event, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = data.module or "ResourceOrbFrames"
    data.feature = data.feature or "element-drag"
    data.fn = data.fn or "ElementDrag"
    data["function"] = data["function"] or data.fn
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.STATE or categories.GENERAL, event, phase, data)
end

local function GetControlName(control)
    if not control then return nil end
    if type(control) ~= "table" and type(control) ~= "userdata" then return tostring(control) end
    local okGetName, getName = pcall(function() return control.GetName end)
    if okGetName and type(getName) == "function" then
        local ok, name = pcall(getName, control)
        if ok and name ~= nil then return tostring(name) end
    end
    return nil
end

local function ClampOffset(value)
    if type(BETTERUI.ClampInteger) == "function" then
        return BETTERUI.ClampInteger(value, OFFSET_MIN, OFFSET_MAX, 0)
    end
    value = tonumber(value) or 0
    if value < OFFSET_MIN then return OFFSET_MIN end
    if value > OFFSET_MAX then return OFFSET_MAX end
    return zo_round and zo_round(value) or math.floor(value + 0.5)
end

local function GetTimeMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return GetFrameTimeMilliseconds()
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end
    return 0
end

local function GetMouseXY()
    if GetUIMousePosition then
        return GetUIMousePosition()
    end
    return 0, 0
end

local function SetHandleVisual(handle, locked)
    if not handle then return end
    local alpha = locked and 0 or 0.15
    if handle.SetCenterColor then
        handle:SetCenterColor(1, 1, 1, 1)
    end
    if handle.SetEdgeColor then
        handle:SetEdgeColor(1, 1, 1, 1)
    end
    if handle.SetColor then
        handle:SetColor(1, 1, 1, 1)
    end
    if handle.SetAlpha then
        handle:SetAlpha(alpha)
    elseif handle.SetColor then
        handle:SetColor(1, 1, 1, alpha)
    end
    if handle.SetMouseEnabled then
        handle:SetMouseEnabled(not locked)
    end
end

local function GetBetterUISettingsPanel()
    for _, panelId in ipairs(SETTINGS_PANEL_IDS) do
        local panel = rawget(_G, panelId)
        if panel then return panel, panelId end
    end

    local lam = rawget(_G, "LibAddonMenu2") or rawget(_G, "LibAddonMenu")
    if type(lam) == "table" then
        local panels = rawget(lam, "panels") or rawget(lam, "addonPanels")
        if type(panels) == "table" then
            for _, panelId in ipairs(SETTINGS_PANEL_IDS) do
                if panels[panelId] then
                    return panels[panelId], panelId
                end
            end
        end
    end

    local panel = lam and lam.currentAddonPanel or nil
    if panel and panel.GetName then
        local ok, name = pcall(panel.GetName, panel)
        if ok then
            for _, panelId in ipairs(SETTINGS_PANEL_IDS) do
                if name == panelId then
                    return panel, panelId
                end
            end
        end
    end
    return nil
end

local function CallPanelMethod(panel, methodName)
    if not panel then return false end
    local okMethod, method = pcall(function() return panel[methodName] end)
    if not okMethod or type(method) ~= "function" then return false end
    local ok = pcall(method, panel)
    return ok == true
end

local function RefreshLAMControl(control)
    if not control then return false end
    local refreshed = false
    for _, methodName in ipairs({ "UpdateValue", "UpdateDisabled" }) do
        local okMethod, method = pcall(function() return control[methodName] end)
        if okMethod and type(method) == "function" then
            local ok = pcall(method, control)
            refreshed = ok or refreshed
        end
    end
    return refreshed
end

local function RefreshPanelControls(panel)
    if not panel then return false end
    local refreshed = false

    local controlLists = {}
    if type(panel) == "table" then
        controlLists[#controlLists + 1] = rawget(panel, "controlsToRefresh")
        controlLists[#controlLists + 1] = rawget(panel, "controls")
    end
    for _, controls in ipairs(controlLists) do
        if type(controls) == "table" then
            for _, control in pairs(controls) do
                refreshed = RefreshLAMControl(control) or refreshed
            end
        end
    end

    local okCount, childCount = pcall(function()
        return panel.GetNumChildren and panel:GetNumChildren() or 0
    end)
    if okCount and type(childCount) == "number" then
        for i = 1, childCount do
            local okChild, child = pcall(function() return panel:GetChild(i) end)
            if okChild and child then
                refreshed = RefreshLAMControl(child) or refreshed
            end
        end
    end

    return refreshed
end

local function RefreshSettingsPanel()
    local panel, resolvedPanelId = GetBetterUISettingsPanel()
    local lam = rawget(_G, "LibAddonMenu2") or rawget(_G, "LibAddonMenu")
    local requestedRefresh = false

    TraceDrag("resource_orbs.settings_panel", "refresh_attempt", {
        requestedRefresh = requestedRefresh == true,
        hasPanel = panel ~= nil,
        hasLam = type(lam) == "table",
        panelId = resolvedPanelId,
    })

    if type(lam) == "table" and type(lam.RefreshPanel) == "function" then
        if panel then
            local okPanel = pcall(lam.RefreshPanel, lam, panel)
            requestedRefresh = okPanel or requestedRefresh
            TraceDrag("resource_orbs.settings_panel", okPanel and "refresh_attempt_success" or "refresh_attempt_failed", {
                method = "LibAddonMenu.RefreshPanel(panel)",
                hasPanel = true,
                panelId = resolvedPanelId,
            })
        end
        for _, panelId in ipairs(SETTINGS_PANEL_IDS) do
            local okId = pcall(lam.RefreshPanel, lam, panelId)
            requestedRefresh = okId or requestedRefresh
            TraceDrag("resource_orbs.settings_panel", okId and "refresh_attempt_success" or "refresh_attempt_failed", {
                method = "LibAddonMenu.RefreshPanel(id)",
                panelId = panelId,
            })
        end
    end

    local util = lam and lam.util
    if panel and util and type(util.RequestRefreshIfNeeded) == "function" then
        local okRequest = pcall(util.RequestRefreshIfNeeded, panel)
        requestedRefresh = okRequest or requestedRefresh
        TraceDrag("resource_orbs.settings_panel", okRequest and "refresh_attempt_success" or "refresh_attempt_failed", {
            method = "LibAddonMenu.util.RequestRefreshIfNeeded",
            hasPanel = true,
            panelId = resolvedPanelId,
        })
    end

    local controlsRefreshed = CallPanelMethod(panel, "RefreshControls") or RefreshPanelControls(panel)
    TraceDrag("resource_orbs.settings_panel", controlsRefreshed and "refresh_attempt_success" or "refresh_attempt_failed", {
        method = "RefreshControls",
        hasPanel = panel ~= nil,
        panelId = resolvedPanelId,
    })
    if controlsRefreshed then
        TraceDrag("resource_orbs.settings_panel", "refresh_result", {
            hasPanel = panel ~= nil,
            panelId = resolvedPanelId,
            requestedRefresh = requestedRefresh == true,
            controlsRefreshed = true,
            callbacksFired = false,
            result = true,
        })
        return true
    end

    if CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks then
        local callbackTarget = panel or resolvedPanelId or SETTINGS_PANEL_IDS[1]
        local ok = pcall(CALLBACK_MANAGER.FireCallbacks, CALLBACK_MANAGER, "LAM-RefreshPanel", callbackTarget)
        TraceDrag("resource_orbs.settings_panel", ok and "refresh_attempt_success" or "refresh_attempt_failed", {
            method = "CALLBACK_MANAGER.FireCallbacks",
            callback = "LAM-RefreshPanel",
            hasPanel = panel ~= nil,
            panelId = resolvedPanelId,
        })
        local result = ok == true or requestedRefresh
        TraceDrag("resource_orbs.settings_panel", "refresh_result", {
            hasPanel = panel ~= nil,
            panelId = resolvedPanelId,
            requestedRefresh = requestedRefresh == true,
            controlsRefreshed = false,
            callbacksFired = ok == true,
            result = result == true,
        })
        return result
    end

    TraceDrag("resource_orbs.settings_panel", "refresh_result", {
        hasPanel = panel ~= nil,
        panelId = resolvedPanelId,
        requestedRefresh = requestedRefresh == true,
        controlsRefreshed = false,
        callbacksFired = false,
        result = requestedRefresh == true,
    })
    return requestedRefresh
end

local function RefreshSettingsPanelThrottled(dragState, force)
    if force then
        dragState.lastRefreshMs = GetTimeMs()
        TraceDrag("resource_orbs.settings_panel", "refresh_requested", {
            force = true,
        })
        RefreshSettingsPanel()
        return
    end

    local nowMs = GetTimeMs()
    if not dragState.lastRefreshMs or nowMs - dragState.lastRefreshMs >= DRAG_REFRESH_INTERVAL_MS then
        dragState.lastRefreshMs = nowMs
        TraceDrag("resource_orbs.settings_panel", "refresh_requested", {
            force = false,
        })
        RefreshSettingsPanel()
    else
        TraceDrag("resource_orbs.settings_panel", "refresh_skipped", {
            reason = "throttled",
            elapsedMs = nowMs - dragState.lastRefreshMs,
        })
    end
end

local function ApplyDragOffset(elemKey, settingsGetter, dragState, dx, dy, applyCallback, forceRefresh)
    local s = settingsGetter and settingsGetter()
    local ep = s and s.elementPositions and s.elementPositions[elemKey]
    if not ep then
        TraceDrag("resource_orbs.element_drag", "delta_skipped", {
            elemKey = elemKey,
            reason = "missingElementPosition",
        })
        return false
    end

    local nextX = ClampOffset((dragState.baseOffX or 0) + dx)
    local nextY = ClampOffset((dragState.baseOffY or 0) + dy)
    local changed = ep.offsetX ~= nextX or ep.offsetY ~= nextY
    if changed then
        ep.offsetX = nextX
        ep.offsetY = nextY
        TraceDrag("resource_orbs.element_drag", "delta_applied", { elemKey = elemKey, nextX = nextX, nextY = nextY, changed = true })
        if applyCallback then applyCallback() end
    end
    if changed or forceRefresh then
        RefreshSettingsPanelThrottled(dragState, forceRefresh)
    end
    return changed
end

function Drag.AttachDragHandle(hostControl, elemKey, settingsGetter, applyCallback)
    if not hostControl or not elemKey then
        TraceDrag("resource_orbs.element_drag_handle", "attach_skipped", {
            elemKey = elemKey,
            reason = hostControl and "missingElementKey" or "missingHostControl",
        })
        return nil
    end
    if m_handles[elemKey] then
        if m_handleHosts[elemKey] == hostControl then
            TraceDrag("resource_orbs.element_drag_handle", "attach_skipped", {
                elemKey = elemKey,
                reason = "alreadyAttached",
            })
            return m_handles[elemKey]
        end
        TraceDrag("resource_orbs.element_drag_handle", "reattach", {
            elemKey = elemKey,
            reason = "hostChanged",
            previousHost = GetControlName(m_handleHosts[elemKey]),
            nextHost = GetControlName(hostControl),
        })
        Drag.DetachDragHandle(elemKey)
    end

    TraceDrag("resource_orbs.element_drag_handle", "attach_begin", {
        elemKey = elemKey,
    })
    local handleName = "BetterUI_DragHandle_" .. elemKey
    local handle = WINDOW_MANAGER:CreateControl(handleName, hostControl, CT_BACKDROP)
    handle:SetDimensions(HANDLE_SIZE, HANDLE_SIZE)
    handle:SetAnchor(CENTER, hostControl, CENTER, 0, 0)
    handle:SetDrawLayer(DL_OVERLAY)
    handle:SetDrawLevel(510)

    local s = settingsGetter and settingsGetter()
    local locked = true
    if s and s.elementPositions and s.elementPositions[elemKey] then
        locked = s.elementPositions[elemKey].locked ~= false
    end
    SetHandleVisual(handle, locked)

    local dragState = {}

    handle:SetHandler("OnMouseDown", function(self, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local settings = settingsGetter and settingsGetter()
        if not settings then
            TraceDrag("resource_orbs.element_drag", "start_skipped", {
                elemKey = elemKey,
                reason = "missingSettings",
            })
            return
        end
        local ep = settings.elementPositions and settings.elementPositions[elemKey]
        if not ep or ep.locked ~= false then
            TraceDrag("resource_orbs.element_drag", "start_skipped", {
                elemKey = elemKey,
                reason = ep and "locked" or "missingElementPosition",
            })
            return
        end
        local mx, my = GetMouseXY()
        dragState.dragging = true
        dragState.startX = mx
        dragState.startY = my
        dragState.baseOffX = ep.offsetX or 0
        dragState.baseOffY = ep.offsetY or 0
        dragState.lastDx = 0
        dragState.lastDy = 0
        dragState.lastRefreshMs = nil
        TraceDrag("resource_orbs.element_drag", "start", { elemKey = elemKey, baseOffX = dragState.baseOffX, baseOffY = dragState.baseOffY })
        self:SetHandler("OnUpdate", function()
            if not dragState.dragging then return end
            local cx, cy = GetMouseXY()
            local dx = cx - dragState.startX
            local dy = cy - dragState.startY
            if math.abs(dx - dragState.lastDx) >= DRAG_THRESHOLD or math.abs(dy - dragState.lastDy) >= DRAG_THRESHOLD then
                dragState.lastDx = dx
                dragState.lastDy = dy
                ApplyDragOffset(elemKey, settingsGetter, dragState, dx, dy, applyCallback, false)
            end
        end)
    end)

    handle:SetHandler("OnMouseUp", function(self, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if dragState.dragging then
            local mx, my = GetMouseXY()
            ApplyDragOffset(elemKey, settingsGetter, dragState,
                mx - (dragState.startX or mx), my - (dragState.startY or my), applyCallback, true)
            local settings = settingsGetter and settingsGetter()
            local ep = settings and settings.elementPositions and settings.elementPositions[elemKey]
            TraceDrag("resource_orbs.element_drag", "end", { elemKey = elemKey, offsetX = ep and ep.offsetX or nil, offsetY = ep and ep.offsetY or nil })
        else
            TraceDrag("resource_orbs.element_drag", "click_refresh", {
                elemKey = elemKey,
            })
            RefreshSettingsPanel()
        end
        dragState.dragging = false
        self:SetHandler("OnUpdate", nil)
    end)

    m_handles[elemKey] = handle
    m_handleHosts[elemKey] = hostControl
    TraceDrag("resource_orbs.element_drag_handle", "attached", { elemKey = elemKey, hostControl = GetControlName(hostControl) })
    return handle
end

function Drag.DetachDragHandle(elemKey)
    local handle = elemKey and m_handles[elemKey] or nil
    if not handle then
        TraceDrag("resource_orbs.element_drag_handle", "detach_skipped", {
            elemKey = elemKey,
            reason = "missingHandle",
        })
        return false
    end
    if handle.SetHandler then
        handle:SetHandler("OnUpdate", nil)
        handle:SetHandler("OnMouseDown", nil)
        handle:SetHandler("OnMouseUp", nil)
    end
    if handle.SetMouseEnabled then
        handle:SetMouseEnabled(false)
    end
    if handle.SetHidden then
        handle:SetHidden(true)
    end
    m_handles[elemKey] = nil
    m_handleHosts[elemKey] = nil
    TraceDrag("resource_orbs.element_drag_handle", "detached", {
        elemKey = elemKey,
    })
    return true
end

function Drag.SetElementLocked(elemKey, locked, settingsGetter)
    local s = settingsGetter and settingsGetter()
    local changed = false
    if s and s.elementPositions and s.elementPositions[elemKey] then
        changed = s.elementPositions[elemKey].locked ~= locked
        s.elementPositions[elemKey].locked = locked
    end
    SetHandleVisual(m_handles[elemKey], locked)
    TraceDrag("resource_orbs.element_lock", "toggled", { elemKey = elemKey, locked = locked == true, changed = changed == true, hasHandle = m_handles[elemKey] ~= nil })
end

function Drag.GetOffset(elemKey, settingsGetter)
    local s = settingsGetter and settingsGetter()
    if s and s.elementPositions and s.elementPositions[elemKey] then
        return s.elementPositions[elemKey].offsetX or 0, s.elementPositions[elemKey].offsetY or 0
    end
    return 0, 0
end

function Drag.ResetOffset(elemKey, settingsGetter, applyCallback)
    local s = settingsGetter and settingsGetter()
    local ep = s and s.elementPositions and s.elementPositions[elemKey]
    if not ep then
        TraceDrag("resource_orbs.element_position", "reset_skipped", {
            elemKey = elemKey,
            reason = "missingElementPosition",
        })
        return
    end

    TraceDrag("resource_orbs.element_position", "reset", { elemKey = elemKey })
    ep.offsetX = 0
    ep.offsetY = 0
    if applyCallback then applyCallback() end
    RefreshSettingsPanel()
    TraceDrag("resource_orbs.element_position", "reset_end", {
        elemKey = elemKey,
        offsetX = 0,
        offsetY = 0,
    })
end

function Drag.GetHandle(elemKey)
    return m_handles[elemKey]
end

Drag.RefreshSettingsPanel = RefreshSettingsPanel
