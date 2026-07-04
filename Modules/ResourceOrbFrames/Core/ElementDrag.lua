--[[
File: Modules/ResourceOrbFrames/Core/ElementDrag.lua
Purpose: Drag-to-move system for ResourceOrbFrames UI elements.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.Drag then BETTERUI.ResourceOrbFrames.Drag = {} end

local Drag = BETTERUI.ResourceOrbFrames.Drag
local ResourceOrbFrames = BETTERUI.ResourceOrbFrames
local UtilsSettings = ResourceOrbFrames and ResourceOrbFrames.Utils and ResourceOrbFrames.Utils.Settings

--- Returns a live settings accessor when the module exposes one.
--- Element drag writes must mutate persisted settings, not a snapshot clone.
local function ResolveLiveSettingsGetter(settingsGetter)
    if UtilsSettings and type(UtilsSettings.GetLive) == "function" then
        return function() return UtilsSettings.GetLive() end
    end
    return settingsGetter
end

local m_handles = {}
local m_handleHosts = {}
local m_handleIcons = {}
local HANDLE_SIZE = 110
local HANDLE_MIN_SIZE = 96
local HANDLE_OVERLAP_MIN_SIZE = 80
local HANDLE_OVERLAP_PADDING = 4
local HANDLE_ICON_SCALE = 0.6
local HANDLE_ICON_MIN_SIZE = 46
local HANDLE_ICON_MAX_SIZE = 64
local HANDLE_ARROW_MIN_SIZE = 18
local HANDLE_ARROW_MAX_SIZE = 28
local HANDLE_ARROW_SCALE = 0.42
local HANDLE_ARROW_OFFSET_SCALE = 0.24
local HANDLE_ARROW_ALPHA = 0.88
local HANDLE_ICON_TEXTURES = {
    { key = "Left", texture = "EsoUI/Art/Housing/housing_precisionControlIcon_left.dds", x = -1, y = 0 },
    { key = "Right", texture = "EsoUI/Art/Housing/housing_precisionControlIcon_right.dds", x = 1, y = 0 },
    { key = "Up", texture = "EsoUI/Art/Housing/housing_precisionControlIcon_up.dds", x = 0, y = -1 },
    { key = "Down", texture = "EsoUI/Art/Housing/housing_precisionControlIcon_down.dds", x = 0, y = 1 },
}
local DRAG_THRESHOLD = 2
local DRAG_REFRESH_INTERVAL_MS = 75
local OFFSET_MIN = -600
local OFFSET_MAX = 600
local SETTINGS_PANEL_IDS = {
    "BETTERUI_Modules",
    "BETTERUI_ResourceOrbFrames",
}

-- Shared element-drag tracer (BUI-CONS-002), defined once on ROF Utils.
local TraceDrag = ResourceOrbFrames.Utils and ResourceOrbFrames.Utils.TraceDrag or function() end

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

local function CallControl(control, methodName)
    if not control then return nil, nil end
    local okMethod, method = pcall(function() return control[methodName] end)
    if not okMethod or type(method) ~= "function" then return nil, nil end
    local ok, a, b = pcall(method, control)
    if ok then return a, b end
    return nil, nil
end

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then return fallback end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function GetControlDimensions(control)
    local width, height = CallControl(control, "GetDimensions")
    if not width then width = CallControl(control, "GetWidth") end
    if not height then height = CallControl(control, "GetHeight") end
    return tonumber(width), tonumber(height)
end

local function GetControlCenter(control)
    local centerX, centerY = CallControl(control, "GetCenter")
    centerX, centerY = tonumber(centerX), tonumber(centerY)
    if centerX and centerY then return centerX, centerY end

    local left = tonumber(CallControl(control, "GetLeft"))
    local top = tonumber(CallControl(control, "GetTop"))
    local width, height = GetControlDimensions(control)
    if left and top and width and height then
        return left + width / 2, top + height / 2
    end
    return nil, nil
end

local function GetElementSizedHandleSize(hostControl)
    local width, height = GetControlDimensions(hostControl)
    if width and height and width > 0 and height > 0 then
        return math.min(width, height)
    end
    return nil
end

local function WouldOverlapExistingHandle(hostControl, size)
    local centerX, centerY = GetControlCenter(hostControl)
    if not centerX or not centerY then return false end
    for elemKey, existingHost in pairs(m_handleHosts) do
        local otherCenterX, otherCenterY = GetControlCenter(existingHost)
        local otherWidth, otherHeight = GetControlDimensions(m_handles[elemKey])
        if otherCenterX and otherCenterY and otherWidth and otherHeight then
            local overlapsX = math.abs(centerX - otherCenterX) < ((size + otherWidth) / 2) + HANDLE_OVERLAP_PADDING
            local overlapsY = math.abs(centerY - otherCenterY) < ((size + otherHeight) / 2) + HANDLE_OVERLAP_PADDING
            if overlapsX and overlapsY then return true end
        end
    end
    return false
end

local function GetHandleSize(hostControl)
    local elementSize = GetElementSizedHandleSize(hostControl)
    local size = elementSize and ClampNumber(elementSize, HANDLE_MIN_SIZE, HANDLE_SIZE, HANDLE_SIZE) or HANDLE_SIZE
    if elementSize and WouldOverlapExistingHandle(hostControl, size) then
        -- Host-sized fallback keeps adjacent orb handles from merging into one large hit box.
        size = ClampNumber(elementSize, HANDLE_OVERLAP_MIN_SIZE, HANDLE_SIZE, size)
    end
    return zo_round and zo_round(size) or math.floor(size + 0.5)
end

local function SetTextureGuarded(textureControl, texturePath)
    if not textureControl or not textureControl.SetTexture then return false end
    return pcall(textureControl.SetTexture, textureControl, texturePath)
end

local function EnsureHandleIcon(handle)
    if not handle then return nil end
    if m_handleIcons[handle] then return m_handleIcons[handle] end

    local handleName = GetControlName(handle) or "BetterUI_DragHandle"
    local icon = WINDOW_MANAGER:CreateControl(handleName .. "MoveIcon", handle, CT_CONTROL)
    if icon.SetMouseEnabled then icon:SetMouseEnabled(false) end
    if icon.SetDrawLayer then icon:SetDrawLayer(DL_OVERLAY) end
    if icon.SetDrawLevel then icon:SetDrawLevel(512) end

    local data = { control = icon, parts = {} }
    for _, def in ipairs(HANDLE_ICON_TEXTURES) do
        local texture = WINDOW_MANAGER:CreateControl(handleName .. "MoveIcon" .. def.key, icon, CT_TEXTURE)
        SetTextureGuarded(texture, def.texture)
        if texture.SetMouseEnabled then texture:SetMouseEnabled(false) end
        if texture.SetDrawLayer then texture:SetDrawLayer(DL_OVERLAY) end
        if texture.SetDrawLevel then texture:SetDrawLevel(513) end
        data.parts[#data.parts + 1] = { control = texture, x = def.x, y = def.y }
    end
    m_handleIcons[handle] = data
    return data
end

local function ConfigureIconPart(parent, part, size, offset, hidden)
    local control = part and part.control
    if not control then return end
    if control.SetDimensions then control:SetDimensions(size, size) end
    if control.ClearAnchors then control:ClearAnchors() end
    if control.SetAnchor then control:SetAnchor(CENTER, parent, CENTER, (part.x or 0) * offset, (part.y or 0) * offset) end
    if control.SetColor then control:SetColor(0, 0, 0, hidden and 0 or HANDLE_ARROW_ALPHA) end
    if control.SetHidden then control:SetHidden(hidden) end
end

local function UpdateHandleIconVisual(handle, locked)
    local data = EnsureHandleIcon(handle)
    if not data or not data.control then return end

    local handleWidth, handleHeight = GetControlDimensions(handle)
    local handleSize = math.min(handleWidth or HANDLE_SIZE, handleHeight or HANDLE_SIZE)
    local iconSize = ClampNumber(handleSize * HANDLE_ICON_SCALE, HANDLE_ICON_MIN_SIZE, HANDLE_ICON_MAX_SIZE, HANDLE_ICON_MAX_SIZE)
    local arrowSize = ClampNumber(iconSize * HANDLE_ARROW_SCALE, HANDLE_ARROW_MIN_SIZE, HANDLE_ARROW_MAX_SIZE, HANDLE_ARROW_MAX_SIZE)
    local hidden = locked == true

    if data.control.SetDimensions then data.control:SetDimensions(iconSize, iconSize) end
    if data.control.ClearAnchors then data.control:ClearAnchors() end
    if data.control.SetAnchor then data.control:SetAnchor(CENTER, handle, CENTER, 0, 0) end
    if data.control.SetHidden then data.control:SetHidden(hidden) end
    if data.control.SetAlpha then data.control:SetAlpha(hidden and 0 or 1) end

    for _, part in ipairs(data.parts) do
        ConfigureIconPart(data.control, part, arrowSize, iconSize * HANDLE_ARROW_OFFSET_SCALE, hidden)
    end
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
    local hasBackdropColor = handle.SetCenterColor or handle.SetEdgeColor
    -- Backdrop alpha stays faint without dimming the child move icon.
    if handle.SetCenterColor then
        handle:SetCenterColor(1, 1, 1, alpha)
    end
    if handle.SetEdgeColor then
        handle:SetEdgeColor(1, 1, 1, alpha)
    end
    if handle.SetColor then
        handle:SetColor(1, 1, 1, hasBackdropColor and 1 or alpha)
    end
    if handle.SetAlpha then
        handle:SetAlpha(hasBackdropColor and (locked and 0 or 1) or alpha)
    end
    if handle.SetMouseEnabled then
        handle:SetMouseEnabled(not locked)
    end
    UpdateHandleIconVisual(handle, locked)
end

local function AreElementPositionsUnlocked(settings)
    return settings and settings.elementPositionsUnlocked == true
end

local function RefreshAllHandleVisuals(unlocked)
    local locked = unlocked ~= true
    for _, handle in pairs(m_handles) do
        SetHandleVisual(handle, locked)
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
    local liveSettingsGetter = ResolveLiveSettingsGetter(settingsGetter)
    local s = liveSettingsGetter and liveSettingsGetter()
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
    local handleSize = GetHandleSize(hostControl)
    handle:SetDimensions(handleSize, handleSize)
    handle:SetAnchor(CENTER, hostControl, CENTER, 0, 0)
    handle:SetDrawLayer(DL_OVERLAY)
    handle:SetDrawLevel(510)

    local liveSettingsGetter = ResolveLiveSettingsGetter(settingsGetter)
    local s = liveSettingsGetter and liveSettingsGetter()
    local locked = not AreElementPositionsUnlocked(s)
    SetHandleVisual(handle, locked)

    local dragState = {}

    handle:SetHandler("OnMouseDown", function(self, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local liveSettingsGetter = ResolveLiveSettingsGetter(settingsGetter)
        local settings = liveSettingsGetter and liveSettingsGetter()
        if not settings then
            TraceDrag("resource_orbs.element_drag", "start_skipped", {
                elemKey = elemKey,
                reason = "missingSettings",
            })
            return
        end
        local ep = settings.elementPositions and settings.elementPositions[elemKey]
        if not ep or not AreElementPositionsUnlocked(settings) then
            TraceDrag("resource_orbs.element_drag", "start_skipped", {
                elemKey = elemKey,
                reason = ep and "globalLock" or "missingElementPosition",
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
            local liveSettingsGetter = ResolveLiveSettingsGetter(settingsGetter)
            local settings = liveSettingsGetter and liveSettingsGetter()
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
    m_handleIcons[handle] = nil
    m_handles[elemKey] = nil
    m_handleHosts[elemKey] = nil
    TraceDrag("resource_orbs.element_drag_handle", "detached", {
        elemKey = elemKey,
    })
    return true
end

function Drag.SetAllElementsUnlocked(unlocked, settingsGetter)
    local liveSettingsGetter = ResolveLiveSettingsGetter(settingsGetter)
    local s = liveSettingsGetter and liveSettingsGetter()
    local previous = s and s.elementPositionsUnlocked == true
    if s then
        s.elementPositionsUnlocked = unlocked == true
    end
    RefreshAllHandleVisuals(unlocked == true)
    TraceDrag("resource_orbs.element_global_lock", "toggled", {
        unlocked = unlocked == true,
        previousUnlocked = previous == true,
        handleCount = (function()
            local count = 0
            for _ in pairs(m_handles) do count = count + 1 end
            return count
        end)(),
        hasSettings = s ~= nil,
    })
end

-- Drag.SetElementLocked and Drag.GetOffset were removed as production-dead
-- (BUI-CLEAN-002). The global lock (SetAllElementsUnlocked) is the only lock path,
-- and offsets are read straight from settings.elementPositions where needed.

function Drag.ResetOffset(elemKey, settingsGetter, applyCallback)
    local liveSettingsGetter = ResolveLiveSettingsGetter(settingsGetter)
    local s = liveSettingsGetter and liveSettingsGetter()
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
