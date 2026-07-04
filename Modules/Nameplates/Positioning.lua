BETTERUI.Nameplates = BETTERUI.Nameplates or {}
local Nameplates = BETTERUI.Nameplates

local Positioning = {}
Nameplates.Positioning = Positioning

local OFFSET_MIN = -600
local OFFSET_MAX = 600
local HANDLE_SIZE = 42

local DESCRIPTORS = {
    compass = {
        enabledKey = "moveCompassFrame",
        xKey = "compassFrameOffsetX",
        yKey = "compassFrameOffsetY",
        controls = { "ZO_CompassFrame" },
        fallback = function()
            return {
                point = rawget(_G, "TOP"),
                relativeTo = rawget(_G, "GuiRoot"),
                relativePoint = rawget(_G, "TOP"),
                offsetX = 0,
                offsetY = (type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode()) and 58 or 40,
            }
        end,
    },
    reticle = {
        enabledKey = "moveReticlePrompt",
        xKey = "reticlePromptOffsetX",
        yKey = "reticlePromptOffsetY",
        controls = { "ZO_ReticleContainerInteract", "ZO_ReticleContainerNonInteract" },
        fallback = function(controlName)
            local container = rawget(_G, "ZO_ReticleContainer")
            return {
                point = rawget(_G, "LEFT"),
                relativeTo = container,
                relativePoint = rawget(_G, "CENTER"),
                offsetX = 45,
                offsetY = controlName == "ZO_ReticleContainerInteract" and 40 or 0,
            }
        end,
    },
}

local handles = {}
local dragStates = {}

-- Positioning tracer keeps its fn/function payload and STATE-first category; the
-- shared MakeTracer base owns the guard + module/feature. It emits no
-- scene/gamepad/last-action, so those includes stay off (BUI-CONS-002).
local tracePositioningBase = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{
        module = "Nameplates",
        feature = "positioning",
        category = (BETTERUI.Log.CATEGORY or {}).STATE or (BETTERUI.Log.CATEGORY or {}).SETTINGS or "STATE",
        includeScene = false,
        includeGamepad = false,
        setLastAction = false,
    }
    or function() end

local function TracePositioning(phase, data)
    data = data or {}
    data.fn = data.fn or "Nameplates.Positioning"
    data["function"] = data["function"] or data.fn
    tracePositioningBase("nameplates.positioning", phase, data)
end

local function ClampOffset(value)
    local clampInteger = BETTERUI and BETTERUI.ClampInteger
    if type(clampInteger) == "function" then
        return clampInteger(value, OFFSET_MIN, OFFSET_MAX, 0)
    end
    local numeric = tonumber(value) or 0
    numeric = math.floor(numeric + 0.5)
    if numeric < OFFSET_MIN then return OFFSET_MIN end
    if numeric > OFFSET_MAX then return OFFSET_MAX end
    return numeric
end

local function EnsureSettings()
    if type(BETTERUI.EnsureModuleSettings) == "function" then
        return BETTERUI.EnsureModuleSettings("Nameplates")
    end
    if type(BETTERUI.GetModuleSettingsLive) == "function" then
        return BETTERUI.GetModuleSettingsLive("Nameplates")
    end
    if type(BETTERUI.GetModuleSettings) == "function" then
        return BETTERUI.GetModuleSettings("Nameplates")
    end
    return nil
end

local function GetSettings()
    if type(BETTERUI.GetModuleSettings) == "function" then
        return BETTERUI.GetModuleSettings("Nameplates")
    end
    return nil
end

local function IsModuleEnabled(settings)
    return settings and settings.m_enabled == true
end

local function ArePositionsUnlocked(settings)
    return settings and settings.nameplatePositionsUnlocked == true
end

local function GetSetting(settings, key)
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    local defaults = Nameplates.DEFAULTS
    if defaults and defaults[key] ~= nil then
        return defaults[key]
    end
    return nil
end

local function ResolveControl(name)
    local control = rawget(_G, name)
    if control then
        return control
    end
    local container = rawget(_G, "ZO_ReticleContainer")
    if container and type(container.GetNamedChild) == "function" then
        if name == "ZO_ReticleContainerInteract" then
            return container:GetNamedChild("Interact")
        elseif name == "ZO_ReticleContainerNonInteract" then
            return container:GetNamedChild("NonInteract")
        end
    end
    return nil
end

local function ReadControlAnchors(control, controlName, descriptor)
    local anchors = {}
    if type(control.GetNumAnchors) == "function" and type(control.GetAnchor) == "function" then
        local okCount, count = pcall(function() return control:GetNumAnchors() end)
        if okCount and type(count) == "number" then
            for i = 0, count - 1 do
                local ok, point, relativeTo, relativePoint, offsetX, offsetY = pcall(function()
                    return control:GetAnchor(i)
                end)
                if ok and point ~= nil then
                    anchors[#anchors + 1] = {
                        point = point,
                        relativeTo = relativeTo,
                        relativePoint = relativePoint,
                        offsetX = tonumber(offsetX) or 0,
                        offsetY = tonumber(offsetY) or 0,
                    }
                end
            end
        end
    end

    if #anchors == 0 and type(descriptor.fallback) == "function" then
        anchors[#anchors + 1] = descriptor.fallback(controlName)
    end
    return anchors
end

local function AnchorsMatch(actual, base, offsetX, offsetY)
    if #actual ~= #base then
        return false
    end
    for index, anchor in ipairs(base) do
        local actualAnchor = actual[index]
        if not actualAnchor then
            return false
        end
        if actualAnchor.point ~= anchor.point
            or actualAnchor.relativeTo ~= anchor.relativeTo
            or actualAnchor.relativePoint ~= anchor.relativePoint
            or (actualAnchor.offsetX or 0) ~= ((anchor.offsetX or 0) + offsetX)
            or (actualAnchor.offsetY or 0) ~= ((anchor.offsetY or 0) + offsetY) then
            return false
        end
    end
    return true
end

local function CaptureAnchors(control, controlName, descriptor)
    if not control then
        return nil
    end

    local cached = control._betteruiNameplateOriginalAnchors
    local liveAnchors = ReadControlAnchors(control, controlName, descriptor)
    if cached and #cached > 0 then
        local expectedOffsetX = control._betteruiNameplatePositionApplied and (control._betteruiNameplateAppliedOffsetX or 0) or 0
        local expectedOffsetY = control._betteruiNameplatePositionApplied and (control._betteruiNameplateAppliedOffsetY or 0) or 0
        if #liveAnchors > 0 and not AnchorsMatch(liveAnchors, cached, expectedOffsetX, expectedOffsetY) then
            control._betteruiNameplateOriginalAnchors = liveAnchors
            return liveAnchors
        end
        return cached
    end

    control._betteruiNameplateOriginalAnchors = liveAnchors
    return liveAnchors
end

local function SetAnchorsWithOffset(control, controlName, descriptor, offsetX, offsetY)
    if not (control and type(control.ClearAnchors) == "function" and type(control.SetAnchor) == "function") then
        return false
    end

    local anchors = CaptureAnchors(control, controlName, descriptor)
    if not anchors or #anchors == 0 then
        return false
    end

    control:ClearAnchors()
    for _, anchor in ipairs(anchors) do
        control:SetAnchor(
            anchor.point,
            anchor.relativeTo,
            anchor.relativePoint,
            (anchor.offsetX or 0) + offsetX,
            (anchor.offsetY or 0) + offsetY
        )
    end
    control._betteruiNameplatePositionApplied = true
    control._betteruiNameplateAppliedOffsetX = offsetX
    control._betteruiNameplateAppliedOffsetY = offsetY
    return true
end

local function RestoreAnchors(control, controlName, descriptor)
    if not (control and control._betteruiNameplatePositionApplied) then
        return false
    end
    if not (type(control.ClearAnchors) == "function" and type(control.SetAnchor) == "function") then
        return false
    end
    local anchors = CaptureAnchors(control, controlName, descriptor)
    if not anchors or #anchors == 0 then
        return false
    end
    control:ClearAnchors()
    for _, anchor in ipairs(anchors) do
        control:SetAnchor(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.offsetX or 0, anchor.offsetY or 0)
    end
    control._betteruiNameplatePositionApplied = false
    control._betteruiNameplateAppliedOffsetX = nil
    control._betteruiNameplateAppliedOffsetY = nil
    return true
end

local function GetMousePosition()
    if type(GetUIMousePosition) == "function" then
        return GetUIMousePosition()
    end
    return 0, 0
end

local function RefreshSettingsPanel()
    -- BETTERUI has no LAM panel (BETTERUI.settingsPanel is never assigned anywhere),
    -- so the former LAM-RefreshPanel fallback was dead (BUI-CONS-004).
    local settingsApi = BETTERUI.CIM and BETTERUI.CIM.Settings
    if settingsApi and type(settingsApi.RefreshPanel) == "function" then
        settingsApi.RefreshPanel()
    end
end

local function ApplyDragDelta(key, descriptor, dragState, dx, dy, forceRefresh)
    local settings = EnsureSettings()
    if not (settings and ArePositionsUnlocked(settings)) then
        return false
    end
    local nextX = ClampOffset((dragState.baseX or 0) + dx)
    local nextY = ClampOffset((dragState.baseY or 0) + dy)
    local changed = settings[descriptor.xKey] ~= nextX or settings[descriptor.yKey] ~= nextY
    if changed then
        settings[descriptor.xKey] = nextX
        settings[descriptor.yKey] = nextY
        Positioning.ApplyCurrentSettings(settings)
    end
    if changed or forceRefresh then
        RefreshSettingsPanel()
    end
    TracePositioning(changed and "drag_applied" or "drag_unchanged", {
        key = key,
        offsetX = nextX,
        offsetY = nextY,
    })
    return changed
end

local function ConfigureHandleVisual(handle, visible)
    if not handle then
        return
    end
    if handle.SetDimensions then handle:SetDimensions(HANDLE_SIZE, HANDLE_SIZE) end
    if handle.SetDrawLayer then handle:SetDrawLayer(rawget(_G, "DL_OVERLAY")) end
    if handle.SetDrawLevel then handle:SetDrawLevel(520) end
    if handle.SetMouseEnabled then handle:SetMouseEnabled(visible == true) end
    if handle.SetHidden then handle:SetHidden(visible ~= true) end
    if handle.SetCenterColor then handle:SetCenterColor(0.15, 0.45, 1, 0.20) end
    if handle.SetEdgeColor then handle:SetEdgeColor(0.35, 0.70, 1, 0.95) end
end

local function EnsureHandle(key, descriptor, hostControl)
    if not (hostControl and rawget(_G, "WINDOW_MANAGER") and WINDOW_MANAGER.CreateControl) then
        return nil
    end

    local handle = handles[key]
    if not handle then
        handle = WINDOW_MANAGER:CreateControl("BetterUI_NameplatePosition_" .. key, hostControl, rawget(_G, "CT_BACKDROP"))
        handles[key] = handle
    elseif handle._betteruiNameplateHost ~= hostControl and handle.SetParent then
        handle:SetParent(hostControl)
    end

    handle._betteruiNameplateHost = hostControl
    if handle.SetAnchor then
        if handle.ClearAnchors then handle:ClearAnchors() end
        handle:SetAnchor(rawget(_G, "CENTER"), hostControl, rawget(_G, "CENTER"), 0, 0)
    end

    handle:SetHandler("OnMouseDown", function(self, button)
        if button ~= (rawget(_G, "MOUSE_BUTTON_INDEX_LEFT") or 1) then return end
        local settings = EnsureSettings()
        if not (IsModuleEnabled(settings) and GetSetting(settings, descriptor.enabledKey) == true and ArePositionsUnlocked(settings)) then
            TracePositioning("drag_skipped", { key = key, reason = "lockedOrDisabled" })
            return
        end
        local mouseX, mouseY = GetMousePosition()
        local dragState = {
            dragging = true,
            startX = mouseX,
            startY = mouseY,
            baseX = ClampOffset(GetSetting(settings, descriptor.xKey)),
            baseY = ClampOffset(GetSetting(settings, descriptor.yKey)),
            lastX = 0,
            lastY = 0,
        }
        dragStates[key] = dragState
        TracePositioning("drag_start", { key = key, baseX = dragState.baseX, baseY = dragState.baseY })
        self:SetHandler("OnUpdate", function()
            if not dragState.dragging then return end
            local currentX, currentY = GetMousePosition()
            local dx = currentX - dragState.startX
            local dy = currentY - dragState.startY
            if math.abs(dx - dragState.lastX) >= 2 or math.abs(dy - dragState.lastY) >= 2 then
                dragState.lastX = dx
                dragState.lastY = dy
                ApplyDragDelta(key, descriptor, dragState, dx, dy, false)
            end
        end)
    end)

    handle:SetHandler("OnMouseUp", function(self, button)
        if button ~= (rawget(_G, "MOUSE_BUTTON_INDEX_LEFT") or 1) then return end
        local dragState = dragStates[key]
        if dragState and dragState.dragging then
            local mouseX, mouseY = GetMousePosition()
            ApplyDragDelta(key, descriptor, dragState, mouseX - dragState.startX, mouseY - dragState.startY, true)
            TracePositioning("drag_end", { key = key })
        end
        dragStates[key] = nil
        self:SetHandler("OnUpdate", nil)
    end)

    return handle
end

local function FindPrimaryControl(descriptor)
    local fallback = nil
    for _, controlName in ipairs(descriptor.controls) do
        local control = ResolveControl(controlName)
        if control and not fallback then
            fallback = control
        end
        if control and type(control.IsHidden) == "function" and not control:IsHidden() then
            return control
        end
    end
    return fallback
end

local function SetHandleState(key, descriptor, settings)
    local hostControl = FindPrimaryControl(descriptor)
    local visible = IsModuleEnabled(settings)
        and GetSetting(settings, descriptor.enabledKey) == true
        and ArePositionsUnlocked(settings)
        and hostControl ~= nil
    local handle = EnsureHandle(key, descriptor, hostControl)
    ConfigureHandleVisual(handle, visible)
end

local function ApplyDescriptor(key, descriptor, settings)
    local enabled = IsModuleEnabled(settings) and GetSetting(settings, descriptor.enabledKey) == true
    local offsetX = ClampOffset(GetSetting(settings, descriptor.xKey))
    local offsetY = ClampOffset(GetSetting(settings, descriptor.yKey))
    local applied = 0
    local restored = 0
    for _, controlName in ipairs(descriptor.controls) do
        local control = ResolveControl(controlName)
        if enabled then
            if SetAnchorsWithOffset(control, controlName, descriptor, offsetX, offsetY) then
                applied = applied + 1
            end
        elseif RestoreAnchors(control, controlName, descriptor) then
            restored = restored + 1
        end
    end
    SetHandleState(key, descriptor, settings)
    TracePositioning(enabled and "applied" or "restored", {
        key = key,
        enabled = enabled,
        offsetX = offsetX,
        offsetY = offsetY,
        applied = applied,
        restored = restored,
        unlocked = ArePositionsUnlocked(settings),
    })
end

function Positioning.ApplyCurrentSettings(settings)
    settings = settings or GetSettings()
    for key, descriptor in pairs(DESCRIPTORS) do
        ApplyDescriptor(key, descriptor, settings)
    end
end

function Positioning.ResetOffsets(settings)
    settings = settings or EnsureSettings()
    if not settings then
        TracePositioning("reset_skipped", { reason = "missingSettings" })
        return false
    end
    settings.nameplatePositionsUnlocked = false
    settings.moveCompassFrame = false
    settings.compassFrameOffsetX = 0
    settings.compassFrameOffsetY = 0
    settings.moveReticlePrompt = false
    settings.reticlePromptOffsetX = 0
    settings.reticlePromptOffsetY = 0
    Positioning.ApplyCurrentSettings(settings)
    RefreshSettingsPanel()
    TracePositioning("reset", { unlocked = false })
    return true
end

function Positioning.GetDefaults()
    local defaults = Nameplates.DEFAULTS or {}
    local clone = {
        nameplatePositionsUnlocked = defaults.nameplatePositionsUnlocked,
    }
    for _, descriptor in pairs(DESCRIPTORS) do
        clone[descriptor.enabledKey] = defaults[descriptor.enabledKey]
        clone[descriptor.xKey] = defaults[descriptor.xKey]
        clone[descriptor.yKey] = defaults[descriptor.yKey]
    end
    return clone
end

function Positioning.IsPositionControlDisabled(elementKey)
    local settings = GetSettings()
    local descriptor = DESCRIPTORS[elementKey]
    if not descriptor then return true end
    return not (IsModuleEnabled(settings)
        and GetSetting(settings, descriptor.enabledKey) == true
        and ArePositionsUnlocked(settings))
end

