BETTERUI.Nameplates = BETTERUI.Nameplates or {}
local Nameplates = BETTERUI.Nameplates

local Positioning = {}
Nameplates.Positioning = Positioning

-- Wide enough to reach either screen edge from any default position.
local OFFSET_MIN = -1500
local OFFSET_MAX = 1500
-- Mirrors the Resource Orb Frames scale slider range.
local SCALE_MIN = 0.75
local SCALE_MAX = 1.75

local function ClampScale(value)
    local numeric = tonumber(value)
    if numeric == nil then return 1 end
    if numeric < SCALE_MIN then return SCALE_MIN end
    if numeric > SCALE_MAX then return SCALE_MAX end
    return numeric
end
local HANDLE_SIZE = 64
local HANDLE_DRAW_LEVEL = 520
local PLACEHOLDER_WIDTH = 170
local PLACEHOLDER_HEIGHT = 64
local HANDLE_MATCH_MIN_WIDTH = 100
local HANDLE_MATCH_MIN_HEIGHT = 40
local HANDLE_MATCH_MAX_WIDTH = 560
local HANDLE_MATCH_MAX_HEIGHT = 200
local HANDLE_LABEL_HEIGHT = 26
local HANDLE_ICON_DRAW_LEVEL = 521
local HANDLE_ARROW_MIN_SIZE = 14
local HANDLE_ARROW_MAX_SIZE = 44
local HANDLE_ARROW_SCALE = 0.35
local HANDLE_ARROW_SLIM = 0.7
local HANDLE_ARROW_EDGE_INSET = 2
local HANDLE_ARROW_SHADOW_OFFSET = 2
local HANDLE_ARROW_SHADOW_ALPHA = 0.6
local HANDLE_ARROW_SHADOW_DRAW_LEVEL = 522
local HANDLE_ARROW_ALPHA = 1
local HANDLE_ARROW_FACE_DRAW_LEVEL = 523
-- Native gold ESO arrow art. The housing precision icons carry baked-in
-- per-axis colors; the earlier "invisible arrows" were the GuiRoot
-- render-list bug, not these textures.
local HANDLE_ICON_TEXTURES = {
    { key = "Left", texture = "EsoUI/Art/Buttons/leftArrow_up.dds", x = -1, y = 0 },
    { key = "Right", texture = "EsoUI/Art/Buttons/rightArrow_up.dds", x = 1, y = 0 },
    { key = "Up", texture = "EsoUI/Art/Buttons/scrollbox_upArrow_up.dds", x = 0, y = -1 },
    { key = "Down", texture = "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds", x = 0, y = 1 },
}

local ResolveTargetBarControl
local ResolvePlayerInteractControl
local GetTargetApplyAnchors

local function IsGamepadPreferred()
    local fn = rawget(_G, "IsInGamepadPreferredMode")
    if type(fn) ~= "function" then
        return false
    end
    local ok, result = pcall(fn)
    return ok and result == true
end

-- Box labels resolve through lang strings with English fallbacks; lang
-- files load before module code, so resolution at build time is safe.
local function ResolveMoverLabel(stringIdName, fallback)
    local stringId = rawget(_G, stringIdName)
    local getString = rawget(_G, "GetString")
    if stringId ~= nil and type(getString) == "function" then
        local ok, value = pcall(getString, stringId)
        if ok and value ~= nil and value ~= "" then
            return value
        end
    end
    return fallback
end

local DESCRIPTORS = {
    compass = {
        enabledKey = "moveCompassFrame",
        xKey = "compassFrameOffsetX",
        yKey = "compassFrameOffsetY",
        scaleKey = "compassFrameScale",
        label = ResolveMoverLabel("SI_BETTERUI_MOVER_LABEL_COMPASS", "Compass"),
        -- Never SetScale the compass frame or the pin strip: the C compass
        -- control lays pins out with unscaled math and sprays them across
        -- the screen. ZOS sizes the compass through dimensions instead (the
        -- gamepad template is just a taller frame, and CompassFrame's boss
        -- bar branch resizes via SetHeight), so the scale slider resizes
        -- ZO_CompassFrame and the strip, pin container, and border textures
        -- all follow through their vanilla anchors.
        applyScale = function(scale)
            local frame = rawget(_G, "ZO_CompassFrame")
            if not (frame and frame.GetWidth and frame.GetHeight and frame.SetDimensions) then return end
            local okWidth, width = pcall(frame.GetWidth, frame)
            local okHeight, height = pcall(frame.GetHeight, frame)
            if not (okWidth and okHeight and type(width) == "number" and type(height) == "number"
                and width > 0 and height > 0) then
                return
            end
            -- Track base (vanilla) dims per axis: whenever the current size
            -- differs from what we last applied, ZOS re-asserted that axis
            -- (screen resize -> UpdateWidth, template swap -> height), so
            -- adopt it as the new base. Per-axis adoption keeps a ZOS width
            -- reassert from polluting the base height with a scaled value,
            -- which would compound scale on every refresh tick.
            local base = frame._betteruiCompassBaseDims
            local applied = frame._betteruiCompassAppliedDims
            if not (base and applied) then
                base = { w = width, h = height }
            else
                base = { w = base.w, h = base.h }
                if math.abs(width - applied.w) > 0.5 then base.w = width end
                if math.abs(height - applied.h) > 0.5 then base.h = height end
            end
            frame._betteruiCompassBaseDims = base
            local targetW = base.w * scale
            local targetH = base.h * scale
            if math.abs(width - targetW) <= 0.5 and math.abs(height - targetH) <= 0.5 then
                frame._betteruiCompassAppliedDims = { w = width, h = height }
                return
            end
            local resized = pcall(function()
                frame:SetDimensions(targetW, targetH)
                -- End caps carry fixed template heights; resize them the
                -- same way ZOS's boss-bar branch does.
                local left = frame.GetNamedChild and frame:GetNamedChild("Left")
                local right = frame.GetNamedChild and frame:GetNamedChild("Right")
                if left and left.SetHeight then left:SetHeight(targetH) end
                if right and right.SetHeight then right:SetHeight(targetH) end
            end)
            if resized then
                frame._betteruiCompassAppliedDims = { w = targetW, h = targetH }
            end
        end,
        controls = { "ZO_CompassFrame" },
        placeholderWidth = 140,
        fallback = function()
            return {
                point = rawget(_G, "TOP"),
                relativeTo = rawget(_G, "GuiRoot"),
                relativePoint = rawget(_G, "TOP"),
                offsetX = 0,
                offsetY = IsGamepadPreferred() and 58 or 40,
            }
        end,
    },
    targetBar = {
        enabledKey = "moveTargetBar",
        xKey = "targetBarOffsetX",
        yKey = "targetBarOffsetY",
        scaleKey = "targetBarScale",
        label = ResolveMoverLabel("SI_BETTERUI_MOVER_LABEL_TARGET_BAR", "Target/NPC Bar"),
        controls = { "ZO_TargetUnitFramereticleover" },
        placeholderWidth = 190,
        resolveControls = function()
            return {
                { name = "ZO_TargetUnitFramereticleover", control = ResolveTargetBarControl and ResolveTargetBarControl() or nil },
            }
        end,
        getApplyAnchors = function(control, controlName, descriptor, anchors)
            return GetTargetApplyAnchors and GetTargetApplyAnchors(control, controlName, descriptor, anchors) or anchors
        end,
        fallback = function()
            return {
                point = rawget(_G, "TOP"),
                relativeTo = rawget(_G, "GuiRoot"),
                relativePoint = rawget(_G, "TOP"),
                offsetX = 0,
                offsetY = 88,
            }
        end,
    },
    playerInteract = {
        enabledKey = "movePlayerInteract",
        xKey = "playerInteractOffsetX",
        yKey = "playerInteractOffsetY",
        scaleKey = "playerInteractScale",
        label = ResolveMoverLabel("SI_BETTERUI_MOVER_LABEL_PLAYER_INTERACT", "Player Interact"),
        controls = { "ZO_PlayerToPlayerAreaPromptContainer" },
        placeholderWidth = 190,
        resolveControls = function()
            return {
                { name = "ZO_PlayerToPlayerAreaPromptContainer", control = ResolvePlayerInteractControl and ResolvePlayerInteractControl() or nil },
            }
        end,
        fallback = function()
            return {
                point = rawget(_G, "BOTTOM"),
                relativeTo = rawget(_G, "GuiRoot"),
                relativePoint = rawget(_G, "BOTTOM"),
                offsetX = 0,
                offsetY = -285,
            }
        end,
    },
    questTracker = {
        enabledKey = "moveQuestTracker",
        xKey = "questTrackerOffsetX",
        yKey = "questTrackerOffsetY",
        scaleKey = "questTrackerScale",
        label = ResolveMoverLabel("SI_BETTERUI_MOVER_LABEL_QUEST_TRACKER", "Quest Tracker"),
        controls = { "ZO_FocusedQuestTrackerPanel" },
        placeholderWidth = 190,
        fallback = function()
            return {
                point = rawget(_G, "TOPRIGHT"),
                relativeTo = rawget(_G, "GuiRoot"),
                relativePoint = rawget(_G, "TOPRIGHT"),
                offsetX = -40,
                offsetY = 140,
            }
        end,
    },
    groupFrames = {
        enabledKey = "moveGroupFrames",
        xKey = "groupFramesOffsetX",
        yKey = "groupFramesOffsetY",
        scaleKey = "groupFramesScale",
        label = ResolveMoverLabel("SI_BETTERUI_MOVER_LABEL_GROUP_FRAMES", "Comp. & Group"),
        -- The companion unit frame anchors to ZO_SmallGroupAnchorFrame, so
        -- this mover carries the companion and group frames together.
        controls = { "ZO_SmallGroupAnchorFrame", "ZO_LargeGroupAnchorFrame" },
        placeholderWidth = 190,
        fallback = function()
            return {
                point = rawget(_G, "TOPLEFT"),
                relativeTo = rawget(_G, "GuiRoot"),
                relativePoint = rawget(_G, "TOPLEFT"),
                offsetX = 40,
                offsetY = 160,
            }
        end,
    },
}

local function EnsureDescriptorDefaults()
    Nameplates.DEFAULTS = Nameplates.DEFAULTS or {}
    local defaults = Nameplates.DEFAULTS
    if defaults.nameplatePositionsUnlocked == nil then
        defaults.nameplatePositionsUnlocked = false
    end
    for _, descriptor in pairs(DESCRIPTORS) do
        if defaults[descriptor.enabledKey] == nil then defaults[descriptor.enabledKey] = false end
        if defaults[descriptor.xKey] == nil then defaults[descriptor.xKey] = 0 end
        if defaults[descriptor.yKey] == nil then defaults[descriptor.yKey] = 0 end
        if descriptor.scaleKey and defaults[descriptor.scaleKey] == nil then defaults[descriptor.scaleKey] = 1 end
    end
    return defaults
end

EnsureDescriptorDefaults()

local handles = {}
local handleIcons = {}
local handleFills = {}
local dragStates = {}
local lastKnownHandleAnchors = {}
local refreshDriver = nil
local SetHandleState

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

local function TracePositioning(phase, data, level)
    data = data or {}
    data.fn = data.fn or "Nameplates.Positioning"
    data["function"] = data["function"] or data.fn
    tracePositioningBase("nameplates.positioning", phase, data, nil, level)
end

local function DescribeControl(control, label)
    local L = BETTERUI and BETTERUI.Log
    if L and type(L.DescribeControl) == "function" then
        return L.DescribeControl(control, label)
    end
    local prefix = label and (tostring(label) .. ":") or ""
    if control == nil then return prefix .. "nil" end
    local ok, name = pcall(function()
        if control.GetName then return control:GetName() end
        return nil
    end)
    return prefix .. ((ok and name and name ~= "") and tostring(name) or "<" .. type(control) .. ">")
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

local function IsPositioningEnabled(settings)
    return settings ~= nil
end

local function ArePositionsUnlocked(settings)
    return settings and settings.nameplatePositionsUnlocked == true
end

local function GetSetting(settings, key)
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    local defaults = EnsureDescriptorDefaults()
    if defaults and defaults[key] ~= nil then
        return defaults[key]
    end
    return nil
end

local function SafeFunctionCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function SafeMethodCall(object, methodName, ...)
    if not object then
        return nil
    end
    local method = object[methodName]
    if type(method) ~= "function" then
        return nil
    end
    local ok, result = pcall(method, object, ...)
    if ok then return result end
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

local function RoundSize(size)
    return zo_round and zo_round(size) or math.floor(size + 0.5)
end

local function GetControlDimensions(control)
    local width, height = CallControl(control, "GetDimensions")
    if not width then width = CallControl(control, "GetWidth") end
    if not height then height = CallControl(control, "GetHeight") end
    return tonumber(width), tonumber(height)
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

local function GetHandleVisualDimensions(descriptor, placeholder, hostControl)
    -- Match the represented element's footprint whenever the host has a
    -- usable rect (hidden hosts keep theirs); the clamps keep thin strips
    -- grabbable and wide bars from flooding the screen. Hosts with no rect
    -- fall back to the descriptor placeholder size.
    local width, height = GetControlDimensions(hostControl)
    width = tonumber(width) or 0
    height = tonumber(height) or 0
    if width > 0 and height > 0 then
        -- GetDimensions ignores control scale; match the rendered footprint.
        local okScale, hostScale = pcall(function() return hostControl:GetScale() end)
        if okScale and type(hostScale) == "number" and hostScale > 0 then
            width = width * hostScale
            height = height * hostScale
        end
        width = ClampNumber(width, HANDLE_MATCH_MIN_WIDTH, HANDLE_MATCH_MAX_WIDTH, HANDLE_MATCH_MIN_WIDTH)
        height = ClampNumber(height, HANDLE_MATCH_MIN_HEIGHT, HANDLE_MATCH_MAX_HEIGHT, HANDLE_MATCH_MIN_HEIGHT)
    else
        width = descriptor and descriptor.placeholderWidth or PLACEHOLDER_WIDTH
        height = descriptor and descriptor.placeholderHeight or PLACEHOLDER_HEIGHT
    end
    return RoundSize(width), RoundSize(height)
end

local function ResolveControl(name)
    local control = rawget(_G, name)
    if control then
        return control
    end
    return nil
end

ResolveTargetBarControl = function()
    local unitFrames = rawget(_G, "ZO_UnitFrames")
    local frameObject = SafeMethodCall(unitFrames, "GetFrame", "reticleover")
    if frameObject then
        if frameObject.frame then
            return frameObject.frame
        end
        local primary = SafeMethodCall(frameObject, "GetPrimaryControl")
        if primary then return primary end
    end

    local getter = rawget(_G, "ZO_UnitFrames_GetUnitFrame")
    local unitFrame = SafeFunctionCall(getter, "reticleover")
    if unitFrame then
        local primary = SafeMethodCall(unitFrame, "GetPrimaryControl")
        if primary then return primary end
        if unitFrame.frame then return unitFrame.frame end
    end

    return rawget(_G, "ZO_TargetUnitFramereticleover")
end

ResolvePlayerInteractControl = function()
    local playerToPlayer = rawget(_G, "PLAYER_TO_PLAYER")
    if playerToPlayer then
        if playerToPlayer.container then return playerToPlayer.container end
        local playerToPlayerControl = playerToPlayer.control
        local promptContainer = SafeMethodCall(playerToPlayerControl, "GetNamedChild", "PromptContainer")
        if promptContainer then return promptContainer end
    end
    local control = rawget(_G, "ZO_PlayerToPlayerAreaPromptContainer")
    if control then return control end
    local area = rawget(_G, "ZO_PlayerToPlayerArea")
    return SafeMethodCall(area, "GetNamedChild", "PromptContainer")
end

local function GetFallbackAnchor(controlName, descriptor)
    if not (descriptor and type(descriptor.fallback) == "function") then
        return nil
    end
    local ok, fallback = pcall(descriptor.fallback, controlName)
    if ok and type(fallback) == "table" then
        return fallback
    end
    return nil
end

local function CopyAnchor(anchor)
    if type(anchor) ~= "table" then
        return nil
    end
    return {
        point = anchor.point,
        relativeTo = anchor.relativeTo,
        relativePoint = anchor.relativePoint,
        offsetX = tonumber(anchor.offsetX) or 0,
        offsetY = tonumber(anchor.offsetY) or 0,
    }
end

local function CopyAnchors(anchors)
    local copy = {}
    for _, anchor in ipairs(anchors or {}) do
        local cloned = CopyAnchor(anchor)
        if cloned then copy[#copy + 1] = cloned end
    end
    return copy
end

local function ReadControlAnchors(control, controlName, descriptor)
    local anchors = {}
    if control and type(control.GetNumAnchors) == "function" and type(control.GetAnchor) == "function" then
        local okCount, count = pcall(function() return control:GetNumAnchors() end)
        if okCount and type(count) == "number" then
            for i = 0, count - 1 do
                -- GetAnchor returns isValidAnchor FIRST (zo_anchor.lua:82); binding
                -- point to that boolean shifted every field and crashed SetAnchor.
                local ok, isValid, point, relativeTo, relativePoint, offsetX, offsetY = pcall(function()
                    return control:GetAnchor(i)
                end)
                if ok and isValid == true and point ~= nil then
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

    if #anchors == 0 then
        local fallback = GetFallbackAnchor(controlName, descriptor)
        if fallback then
            anchors[#anchors + 1] = fallback
        end
    end
    return anchors
end

local function GetRootTopAnchorFromControl(control, sourceAnchor)
    local guiRoot = rawget(_G, "GuiRoot")
    if not (control and guiRoot
        and type(control.GetLeft) == "function"
        and type(control.GetTop) == "function"
        and type(control.GetWidth) == "function"
        and type(guiRoot.GetLeft) == "function"
        and type(guiRoot.GetTop) == "function"
        and type(guiRoot.GetWidth) == "function") then
        return nil
    end

    local relativeOffsetX = 0
    local relativeOffsetY = 0
    local relativeTo = sourceAnchor and sourceAnchor.relativeTo
    if relativeTo and relativeTo._betteruiNameplatePositionApplied then
        relativeOffsetX = tonumber(relativeTo._betteruiNameplateAppliedOffsetX) or 0
        relativeOffsetY = tonumber(relativeTo._betteruiNameplateAppliedOffsetY) or 0
    end

    local ok, offsetX, offsetY = pcall(function()
        local rootLeft = guiRoot:GetLeft()
        local rootTop = guiRoot:GetTop()
        local rootWidth = guiRoot:GetWidth()
        local left = control:GetLeft()
        local top = control:GetTop()
        local width = control:GetWidth()
        return (left + (width / 2)) - (rootLeft + (rootWidth / 2)) - relativeOffsetX, top - rootTop - relativeOffsetY
    end)
    if ok and offsetX ~= nil and offsetY ~= nil then
        return {
            point = rawget(_G, "TOP"),
            relativeTo = guiRoot,
            relativePoint = rawget(_G, "TOP"),
            offsetX = tonumber(offsetX) or 0,
            offsetY = tonumber(offsetY) or 0,
        }
    end
    return nil
end

GetTargetApplyAnchors = function(control, controlName, descriptor, anchors)
    -- ESOUI gamepad anchors reticleover to the compass; root anchoring keeps this mover independent.
    local rootAnchor = GetRootTopAnchorFromControl(control, anchors and anchors[1])
    if rootAnchor then
        return { rootAnchor }
    end
    local fallback = GetFallbackAnchor(controlName, descriptor)
    if fallback then
        return { CopyAnchor(fallback) }
    end
    return anchors
end

local function GetApplyBaseAnchors(control, controlName, descriptor, anchors)
    if control and control._betteruiNameplatePositionApplied and control._betteruiNameplateAppliedBaseAnchors then
        return control._betteruiNameplateAppliedBaseAnchors
    end
    if descriptor and type(descriptor.getApplyAnchors) == "function" then
        local ok, transformed = pcall(descriptor.getApplyAnchors, control, controlName, descriptor, anchors)
        if ok and type(transformed) == "table" and #transformed > 0 then
            return CopyAnchors(transformed)
        end
    end
    return anchors
end

local function AnchorsMatch(actual, base, offsetX, offsetY)
    if not actual or not base or #actual ~= #base then
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
            local appliedBase = control._betteruiNameplateAppliedBaseAnchors
            if control._betteruiNameplatePositionApplied and AnchorsMatch(liveAnchors, appliedBase, expectedOffsetX, expectedOffsetY) then
                return cached
            end
            control._betteruiNameplateOriginalAnchors = liveAnchors
            control._betteruiNameplateAppliedBaseAnchors = nil
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
    local applyAnchors = GetApplyBaseAnchors(control, controlName, descriptor, anchors)
    if not applyAnchors or #applyAnchors == 0 then
        return false
    end
    if control._betteruiNameplatePositionApplied
        and AnchorsMatch(ReadControlAnchors(control, controlName, descriptor), applyAnchors, offsetX, offsetY) then
        return false
    end

    control:ClearAnchors()
    for _, anchor in ipairs(applyAnchors) do
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
    control._betteruiNameplateAppliedBaseAnchors = CopyAnchors(applyAnchors)
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
    control._betteruiNameplateAppliedBaseAnchors = nil
    return true
end

local function GetControlParent(control)
    if not (control and type(control.GetParent) == "function") then
        return nil
    end
    local ok, parent = pcall(control.GetParent, control)
    if ok then return parent end
    return nil
end

local function GetExpectedRoot(controlName, descriptor)
    local fallback = GetFallbackAnchor(controlName, descriptor)
    return fallback and fallback.relativeTo or nil
end

local function GetEffectiveAnchorParent(control, controlName, descriptor)
    if not control then
        return nil
    end
    local anchors = ReadControlAnchors(control, controlName, descriptor)
    for _, anchor in ipairs(anchors or {}) do
        if anchor.relativeTo ~= nil then
            return anchor.relativeTo
        end
    end
    return nil
end

local function TraceAnchorChain(control, controlName, descriptor, action)
    local L = BETTERUI and BETTERUI.Log
    if not (L and type(L.IsActive) == "function" and L.IsActive() == true and type(L.TraceEvent) == "function") then
        return
    end

    local expectedRoot = GetExpectedRoot(controlName, descriptor)
    local parent = GetControlParent(control)
    local effectiveAnchorParent = GetEffectiveAnchorParent(control, controlName, descriptor)
    local anchorParentMatches = expectedRoot == nil or effectiveAnchorParent == expectedRoot
    local parentMatches = expectedRoot == nil or parent == expectedRoot or anchorParentMatches
    local level = parentMatches and (L.LEVEL and L.LEVEL.TRACE) or (L.LEVEL and L.LEVEL.WARN)
    if not level then
        return
    end

    L.TraceEvent(L.CATEGORY.STATE, "nameplates.anchor_chain", parentMatches and "snapshot" or "detected", {
        fn = "Nameplates.Positioning.TraceAnchorChain",
        action = action,
        controlName = controlName,
        control = DescribeControl(control, "control"),
        parent = DescribeControl(parent, "parent"),
        expectedRoot = DescribeControl(expectedRoot, "expectedRoot"),
        effectiveAnchorParent = DescribeControl(effectiveAnchorParent, "anchorParent"),
        anchorParentMatches = anchorParentMatches,
        parentMatches = parentMatches,
    }, level)
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

local function SetTextureGuarded(textureControl, texturePath)
    if not textureControl then return false end
    local okMethod, setTexture = pcall(function() return textureControl.SetTexture end)
    if not okMethod or type(setTexture) ~= "function" then return false end
    return pcall(setTexture, textureControl, texturePath)
end

local function EnsureHandleIcon(handle)
    if not handle then return nil end
    if handleIcons[handle] then return handleIcons[handle] end

    local windowManager = rawget(_G, "WINDOW_MANAGER")
    local controlType = rawget(_G, "CT_CONTROL")
    local textureType = rawget(_G, "CT_TEXTURE")
    if not (windowManager and type(windowManager.CreateControl) == "function" and controlType and textureType) then
        return nil
    end

    local handleName = GetControlName(handle) or "BetterUI_NameplatePosition_DragHandle"
    local okIcon, icon = pcall(function()
        return windowManager:CreateControl(handleName .. "MoveIcon", handle, controlType)
    end)
    if not (okIcon and icon) then
        return nil
    end

    if icon.SetMouseEnabled then icon:SetMouseEnabled(false) end
    if icon.SetDrawLayer then icon:SetDrawLayer(rawget(_G, "DL_OVERLAY")) end
    if icon.SetDrawTier and rawget(_G, "DT_HIGH") then icon:SetDrawTier(rawget(_G, "DT_HIGH")) end
    if icon.SetDrawLevel then icon:SetDrawLevel(HANDLE_ICON_DRAW_LEVEL) end

    local data = { control = icon, parts = {} }
    for _, def in ipairs(HANDLE_ICON_TEXTURES) do
        local okShadow, shadow = pcall(function()
            return windowManager:CreateControl(handleName .. "MoveIconShadow" .. def.key, icon, textureType)
        end)
        if okShadow and shadow then
            SetTextureGuarded(shadow, def.texture)
            if shadow.SetMouseEnabled then shadow:SetMouseEnabled(false) end
            if shadow.SetDrawLayer then shadow:SetDrawLayer(rawget(_G, "DL_OVERLAY")) end
            if shadow.SetDrawTier and rawget(_G, "DT_HIGH") then shadow:SetDrawTier(rawget(_G, "DT_HIGH")) end
            if shadow.SetDrawLevel then shadow:SetDrawLevel(HANDLE_ARROW_SHADOW_DRAW_LEVEL) end
            data.parts[#data.parts + 1] = { control = shadow, x = def.x, y = def.y, shadow = true }
        end

        local okFace, face = pcall(function()
            return windowManager:CreateControl(handleName .. "MoveIcon" .. def.key, icon, textureType)
        end)
        if okFace and face then
            SetTextureGuarded(face, def.texture)
            if face.SetMouseEnabled then face:SetMouseEnabled(false) end
            if face.SetDrawLayer then face:SetDrawLayer(rawget(_G, "DL_OVERLAY")) end
            if face.SetDrawTier and rawget(_G, "DT_HIGH") then face:SetDrawTier(rawget(_G, "DT_HIGH")) end
            if face.SetDrawLevel then face:SetDrawLevel(HANDLE_ARROW_FACE_DRAW_LEVEL) end
            data.parts[#data.parts + 1] = { control = face, x = def.x, y = def.y, shadow = false }
        end
    end

    handleIcons[handle] = data
    return data
end

-- Each arrow hugs the box edge it points at (left arrow on the left edge,
-- up arrow on the top edge, ...) instead of clustering at the center, and
-- is slimmed along its pointing axis so opposing pairs read as chevrons.
local function ConfigureIconPart(parent, part, sideSize, vertSize, insets, hidden)
    local control = part and part.control
    if not control then return end
    local center = rawget(_G, "CENTER")
    local point = center
    local offsetX, offsetY = 0, 0
    local width, height
    if (part.x or 0) < 0 then
        point = rawget(_G, "LEFT") or center
        offsetX = insets.side
        width, height = math.floor(sideSize * HANDLE_ARROW_SLIM + 0.5), sideSize
    elseif (part.x or 0) > 0 then
        point = rawget(_G, "RIGHT") or center
        offsetX = -insets.side
        width, height = math.floor(sideSize * HANDLE_ARROW_SLIM + 0.5), sideSize
    elseif (part.y or 0) < 0 then
        point = rawget(_G, "TOP") or center
        offsetY = insets.top
        width, height = vertSize, math.floor(vertSize * HANDLE_ARROW_SLIM + 0.5)
    else
        point = rawget(_G, "BOTTOM") or center
        offsetY = -insets.bottom
        width, height = vertSize, math.floor(vertSize * HANDLE_ARROW_SLIM + 0.5)
    end
    if control.SetDimensions then control:SetDimensions(width, height) end
    if control.ClearAnchors then control:ClearAnchors() end
    if control.SetAnchor and point then
        local shadowOffset = part.shadow and HANDLE_ARROW_SHADOW_OFFSET or 0
        control:SetAnchor(point, parent, point, offsetX + shadowOffset, offsetY + shadowOffset)
    end
    if control.SetColor then
        if part.shadow then
            control:SetColor(0, 0, 0, hidden and 0 or HANDLE_ARROW_SHADOW_ALPHA)
        else
            control:SetColor(0.98, 0.78, 0.24, hidden and 0 or HANDLE_ARROW_ALPHA)
        end
    end
    if control.SetHidden then control:SetHidden(hidden) end
end

local function UpdateHandleIconVisual(handle, visible)
    local data = EnsureHandleIcon(handle)
    if not data or not data.control then return end

    local handleWidth, handleHeight = GetControlDimensions(handle)
    handleWidth = tonumber(handleWidth) or HANDLE_SIZE
    handleHeight = tonumber(handleHeight) or HANDLE_SIZE
    local minDim = math.min(handleWidth, handleHeight)
    local base = ClampNumber(minDim * HANDLE_ARROW_SCALE, HANDLE_ARROW_MIN_SIZE, HANDLE_ARROW_MAX_SIZE, HANDLE_ARROW_MAX_SIZE)
    -- Per-axis caps: each opposing pair (slimmed along its pointing axis)
    -- must fit its axis with a center gap so arrows never merge.
    local sideSize = math.max(math.min(base, math.floor((handleWidth - 12) / (2 * HANDLE_ARROW_SLIM)), handleHeight - 4), 8)
    local vertSize = math.max(math.min(base, math.floor((handleHeight - 12) / (2 * HANDLE_ARROW_SLIM)), handleWidth - 4), 8)
    local hidden = visible ~= true

    -- The icon container spans the whole box so each arrow can hug its edge.
    local topLeft = rawget(_G, "TOPLEFT")
    local bottomRight = rawget(_G, "BOTTOMRIGHT")
    if data.control.ClearAnchors then data.control:ClearAnchors() end
    if data.control.SetAnchor and topLeft and bottomRight then
        data.control:SetAnchor(topLeft, handle, topLeft, 0, 0)
        data.control:SetAnchor(bottomRight, handle, bottomRight, 0, 0)
    end
    if data.control.SetHidden then data.control:SetHidden(hidden) end
    if data.control.SetAlpha then data.control:SetAlpha(hidden and 0 or 1) end

    local insets = {
        side = HANDLE_ARROW_EDGE_INSET,
        top = HANDLE_ARROW_EDGE_INSET,
        bottom = HANDLE_ARROW_EDGE_INSET,
    }
    for _, part in ipairs(data.parts) do
        ConfigureIconPart(data.control, part, sideSize, vertSize, insets, hidden)
    end
end

local function EnsureHandleLabel(handle)
    if not (handle and rawget(_G, "WINDOW_MANAGER") and rawget(_G, "CT_LABEL")) then
        return nil
    end
    if handle._betteruiNameplateLabel then
        return handle._betteruiNameplateLabel
    end
    local okName, handleName = pcall(function()
        if handle.GetName then return handle:GetName() end
        return "BetterUI_NameplatePosition_Label"
    end)
    local labelName = ((okName and handleName) or "BetterUI_NameplatePosition_Label") .. "Label"
    local ok, label = pcall(function()
        return WINDOW_MANAGER:CreateControl(labelName, handle, rawget(_G, "CT_LABEL"))
    end)
    if not (ok and label) then
        return nil
    end
    handle._betteruiNameplateLabel = label
    if label.SetFont then label:SetFont("$(BOLD_FONT)|16|soft-shadow-thin") end
    if label.SetHorizontalAlignment and rawget(_G, "TEXT_ALIGN_CENTER") then label:SetHorizontalAlignment(rawget(_G, "TEXT_ALIGN_CENTER")) end
    if label.SetVerticalAlignment and rawget(_G, "TEXT_ALIGN_CENTER") then label:SetVerticalAlignment(rawget(_G, "TEXT_ALIGN_CENTER")) end
    if label.SetColor then label:SetColor(0.85, 0.95, 1, 1) end
    if label.SetDrawLayer then label:SetDrawLayer(rawget(_G, "DL_OVERLAY")) end
    if label.SetDrawTier and rawget(_G, "DT_HIGH") then label:SetDrawTier(rawget(_G, "DT_HIGH")) end
    if label.SetDrawLevel then label:SetDrawLevel(HANDLE_ARROW_FACE_DRAW_LEVEL + 1) end
    return label
end

-- The box body is drawn with untextured CT_TEXTURE rects: ZOS renders those
-- as solid color fills (housing editor translation indicators do the same),
-- while a Lua-created CT_BACKDROP renders nothing without texture files —
-- which is why the previous backdrop-based box never appeared in game.
local function EnsureHandleFill(handle)
    if not handle then
        return nil
    end
    if handleFills[handle] then
        return handleFills[handle]
    end
    local windowManager = rawget(_G, "WINDOW_MANAGER")
    local textureType = rawget(_G, "CT_TEXTURE")
    local topLeft = rawget(_G, "TOPLEFT")
    local bottomRight = rawget(_G, "BOTTOMRIGHT")
    if not (windowManager and type(windowManager.CreateControl) == "function" and textureType and topLeft and bottomRight) then
        return nil
    end
    local handleName = GetControlName(handle) or "BetterUI_NameplatePosition_DragHandle"

    local function CreatePart(suffix, level, r, g, b, a, inset)
        local ok, part = pcall(function()
            return windowManager:CreateControl(handleName .. suffix, handle, textureType)
        end)
        if not (ok and part) then return nil end
        if part.SetMouseEnabled then part:SetMouseEnabled(false) end
        if part.SetAnchor then
            part:SetAnchor(topLeft, handle, topLeft, -inset, -inset)
            part:SetAnchor(bottomRight, handle, bottomRight, inset, inset)
        end
        if part.SetDrawLayer then part:SetDrawLayer(rawget(_G, "DL_OVERLAY")) end
        if part.SetDrawTier and rawget(_G, "DT_HIGH") then part:SetDrawTier(rawget(_G, "DT_HIGH")) end
        if part.SetDrawLevel then part:SetDrawLevel(level) end
        if part.SetColor then part:SetColor(r, g, b, a) end
        return part
    end

    local data = {
        border = CreatePart("BorderFill", HANDLE_DRAW_LEVEL - 1, 0.78, 0.88, 1, 0.55, 2),
        fill = CreatePart("Fill", HANDLE_DRAW_LEVEL, 0.72, 0.82, 0.95, 0.10, 0),
    }
    handleFills[handle] = data
    return data
end

local function ConfigureHandleVisual(handle, descriptor, visible, placeholder, hostControl)
    if not handle then
        return
    end
    local fills = EnsureHandleFill(handle)
    if fills then
        if fills.border and fills.border.SetHidden then fills.border:SetHidden(visible ~= true) end
        if fills.fill and fills.fill.SetHidden then fills.fill:SetHidden(visible ~= true) end
    end
    local width, height = GetHandleVisualDimensions(descriptor, placeholder, hostControl)
    if handle.SetDimensions then handle:SetDimensions(width, height) end
    if handle.SetDrawLayer then handle:SetDrawLayer(rawget(_G, "DL_OVERLAY")) end
    if handle.SetDrawTier and rawget(_G, "DT_HIGH") then handle:SetDrawTier(rawget(_G, "DT_HIGH")) end
    if handle.SetDrawLevel then handle:SetDrawLevel(HANDLE_DRAW_LEVEL) end
    local isVisible = visible == true
    local centerAlpha = isVisible and (placeholder and 0.28 or 0.20) or 0
    local edgeAlpha = isVisible and 0.95 or 0
    if handle.SetMouseEnabled then handle:SetMouseEnabled(isVisible) end
    if handle.SetHidden then handle:SetHidden(false) end
    if handle.SetAlpha then handle:SetAlpha(isVisible and 1 or 0) end
    if handle.SetCenterColor then handle:SetCenterColor(0.15, 0.45, 1, centerAlpha) end
    if handle.SetEdgeColor then handle:SetEdgeColor(0.35, 0.70, 1, edgeAlpha) end
    UpdateHandleIconVisual(handle, isVisible)

    local label = EnsureHandleLabel(handle)
    if label then
        if label.SetText then label:SetText(descriptor.label or "HUD Element") end
        if label.SetHidden then label:SetHidden(not isVisible) end
        if label.SetDimensions then label:SetDimensions(math.max(width - 12, 100), HANDLE_LABEL_HEIGHT) end
        if label.ClearAnchors then label:ClearAnchors() end
        if label.SetAnchor then
            -- Centered so the four edge arrows surround the element name.
            local center = rawget(_G, "CENTER")
            if center then label:SetAnchor(center, handle, center, 0, 0) end
        end
    end
end

local function RefreshHandleOnUpdate(key, descriptor, handle)
    local dragState = dragStates[key]
    if dragState and dragState.dragging then
        local currentX, currentY = GetMousePosition()
        local dx = currentX - dragState.startX
        local dy = currentY - dragState.startY
        if math.abs(dx - dragState.lastX) >= 2 or math.abs(dy - dragState.lastY) >= 2 then
            dragState.lastX = dx
            dragState.lastY = dy
            ApplyDragDelta(key, descriptor, dragState, dx, dy, false)
        end
        return
    end

    local now = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds() or 0
    if now ~= 0 and now < (handle._betteruiNameplateNextRefresh or 0) then
        return
    end
    if now ~= 0 then
        handle._betteruiNameplateNextRefresh = now + 250
    end
    if SetHandleState then
        SetHandleState(key, descriptor, GetSettings())
    end
end

local handleLayer = nil

-- ESO only renders top-level windows and their descendants; a plain control
-- parented straight to GuiRoot never enters the render list, which is why
-- GuiRoot-rooted handles had perfect state but drew nothing. All handles
-- live under one dedicated always-shown top-level window instead.
local function EnsureHandleLayer()
    if handleLayer then return handleLayer end
    local windowManager = rawget(_G, "WINDOW_MANAGER")
    if not (windowManager and type(windowManager.CreateTopLevelWindow) == "function") then
        return nil
    end
    local ok, layer = pcall(function()
        return windowManager:CreateTopLevelWindow("BetterUI_NameplateMoverLayer")
    end)
    if not (ok and layer) then return nil end
    if layer.SetMouseEnabled then layer:SetMouseEnabled(false) end
    if layer.SetHidden then layer:SetHidden(false) end
    if layer.SetDrawLayer then layer:SetDrawLayer(rawget(_G, "DL_OVERLAY")) end
    if layer.SetDrawTier and rawget(_G, "DT_HIGH") then layer:SetDrawTier(rawget(_G, "DT_HIGH")) end
    if layer.SetDimensions then layer:SetDimensions(1, 1) end
    local center = rawget(_G, "CENTER")
    if layer.SetAnchor and center then
        layer:SetAnchor(center, rawget(_G, "GuiRoot"), center, 0, 0)
    end
    handleLayer = layer
    return layer
end

local function EnsureHandle(key, descriptor, hostControl)
    local parent = EnsureHandleLayer() or rawget(_G, "GuiRoot") or hostControl
    local windowManager = rawget(_G, "WINDOW_MANAGER")
    if not (parent and windowManager and type(windowManager.CreateControl) == "function" and rawget(_G, "CT_BACKDROP")) then
        return nil
    end

    local handle = handles[key]
    if not handle then
        local ok, created = pcall(function()
            return windowManager:CreateControl("BetterUI_NameplatePosition_" .. key, parent, rawget(_G, "CT_BACKDROP"))
        end)
        if not (ok and created) then
            return nil
        end
        handle = created
        handles[key] = handle
    elseif handle._betteruiNameplateHost ~= parent and handle.SetParent then
        handle:SetParent(parent)
    end

    handle._betteruiNameplateHost = parent
    if not handle._betteruiNameplateHandlersInstalled and handle.SetHandler then
        handle:SetHandler("OnMouseDown", function(self, button)
            if button ~= (rawget(_G, "MOUSE_BUTTON_INDEX_LEFT") or 1) then return end
            local settings = EnsureSettings()
            if not (IsPositioningEnabled(settings) and GetSetting(settings, descriptor.enabledKey) == true and ArePositionsUnlocked(settings)) then
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
            if SetHandleState then
                SetHandleState(key, descriptor, EnsureSettings() or GetSettings())
            end
        end)

        handle:SetHandler("OnUpdate", function(self)
            RefreshHandleOnUpdate(key, descriptor, self)
        end)
        handle._betteruiNameplateHandlersInstalled = true
    end

    return handle
end

local function ResolveDescriptorControls(descriptor)
    local entries = {}
    if descriptor and type(descriptor.resolveControls) == "function" then
        local ok, resolved = pcall(descriptor.resolveControls)
        if ok and type(resolved) == "table" then
            for _, item in ipairs(resolved) do
                if type(item) == "table" then
                    entries[#entries + 1] = { name = item.name or item.controlName or item[1], control = item.control or item[2] }
                elseif type(item) == "string" then
                    entries[#entries + 1] = { name = item, control = ResolveControl(item) }
                end
            end
        end
    end
    if #entries == 0 then
        for _, controlName in ipairs(descriptor.controls or {}) do
            entries[#entries + 1] = { name = controlName, control = ResolveControl(controlName) }
        end
    end
    return entries
end

local function IsControlVisible(control)
    if not control then
        return false
    end
    if type(control.IsHidden) == "function" then
        local ok, hidden = pcall(control.IsHidden, control)
        if ok then
            return hidden ~= true
        end
    end
    return true
end

local function FindPrimaryControl(descriptor, entries)
    entries = entries or ResolveDescriptorControls(descriptor)
    local fallbackEntry = nil
    for _, entry in ipairs(entries) do
        local control = entry.control
        if control and not fallbackEntry then
            fallbackEntry = entry
        end
        if IsControlVisible(control) then
            return control, entry, true, entries
        end
    end
    if fallbackEntry then
        return fallbackEntry.control, fallbackEntry, false, entries
    end
    return nil, entries[1], false, entries
end

local function AnchorHandleToLiveControl(handle, hostControl)
    if not (handle and hostControl and handle.SetAnchor) then
        return
    end
    if handle.ClearAnchors then handle:ClearAnchors() end
    handle:SetAnchor(rawget(_G, "CENTER"), hostControl, rawget(_G, "CENTER"), 0, 0)
end

local function GetPlaceholderBaseAnchor(key, descriptor, entry)
    local controlName = (entry and entry.name) or (descriptor.controls and descriptor.controls[1])
    local control = entry and entry.control
    if control then
        local anchors = CaptureAnchors(control, controlName, descriptor)
        local applyAnchors = GetApplyBaseAnchors(control, controlName, descriptor, anchors)
        if applyAnchors and applyAnchors[1] then
            lastKnownHandleAnchors[key] = CopyAnchor(applyAnchors[1])
            return applyAnchors[1]
        end
    end
    if lastKnownHandleAnchors[key] then
        return lastKnownHandleAnchors[key]
    end
    return GetFallbackAnchor(controlName, descriptor)
end

local function AnchorHandleToPlaceholder(key, descriptor, entry, settings, handle)
    if not (handle and handle.SetAnchor) then
        return
    end
    local anchor = GetPlaceholderBaseAnchor(key, descriptor, entry) or {}
    local guiRoot = rawget(_G, "GuiRoot")
    local point = anchor.point or rawget(_G, "CENTER")
    local relativeTo = anchor.relativeTo or guiRoot
    local relativePoint = anchor.relativePoint or point
    local offsetX = (anchor.offsetX or 0) + ClampOffset(GetSetting(settings, descriptor.xKey))
    local offsetY = (anchor.offsetY or 0) + ClampOffset(GetSetting(settings, descriptor.yKey))
    if handle.ClearAnchors then handle:ClearAnchors() end
    handle:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
end

-- Engine-side render snapshot (once per visibility flip) so interface.log
-- shows what the engine actually drew for each mover handle.
local function TraceHandleVisualSnapshot(key, handle, visible)
    if not handle or handle._betteruiNameplateVisibleTraced == (visible == true) then
        return
    end
    handle._betteruiNameplateVisibleTraced = visible == true
    local width, height = GetControlDimensions(handle)
    local okCenter, centerX, centerY = pcall(function()
        if type(handle.GetCenter) ~= "function" then return nil end
        return handle:GetCenter()
    end)
    TracePositioning("handle_visual", {
        key = key,
        visible = visible == true,
        width = width,
        height = height,
        centerX = okCenter and centerX or nil,
        centerY = okCenter and centerY or nil,
        hidden = SafeMethodCall(handle, "IsHidden"),
        alpha = SafeMethodCall(handle, "GetAlpha"),
        parent = SafeMethodCall(SafeMethodCall(handle, "GetParent"), "GetName"),
    })
end

SetHandleState = function(key, descriptor, settings, entries)
    settings = settings or GetSettings()
    local hostControl, hostEntry, liveVisible, resolvedEntries = FindPrimaryControl(descriptor, entries)
    local visible = IsPositioningEnabled(settings)
        and GetSetting(settings, descriptor.enabledKey) == true
        and ArePositionsUnlocked(settings)
    local useLiveHost = false
    if not visible and not handles[key] then
        return
    end
    local handle = EnsureHandle(key, descriptor, useLiveHost and hostControl or nil)
    local placeholder = visible and not useLiveHost
    -- hostControl flows through even in placeholder mode so the box can
    -- match the represented element's dimensions (hidden hosts keep a rect).
    ConfigureHandleVisual(handle, descriptor, visible, placeholder, hostControl)
    if not (handle and visible) then
        TraceHandleVisualSnapshot(key, handle, visible)
        return
    end
    if useLiveHost then
        AnchorHandleToLiveControl(handle, hostControl)
    else
        AnchorHandleToPlaceholder(key, descriptor, hostEntry or (resolvedEntries and resolvedEntries[1]), settings, handle)
    end
    TraceHandleVisualSnapshot(key, handle, visible)
end

local function EnsureRefreshDriver()
    if refreshDriver then
        return
    end
    local windowManager = rawget(_G, "WINDOW_MANAGER")
    local guiRoot = rawget(_G, "GuiRoot")
    if not (windowManager and guiRoot and type(windowManager.CreateControl) == "function" and rawget(_G, "CT_CONTROL")) then
        return
    end
    local ok, control = pcall(function()
        return windowManager:CreateControl("BetterUI_NameplatePositionRefresh", guiRoot, rawget(_G, "CT_CONTROL"))
    end)
    if not (ok and control and control.SetHandler) then
        return
    end
    refreshDriver = control
    control:SetHandler("OnUpdate", function(self)
        local now = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds() or 0
        if now ~= 0 and now < (self._betteruiNameplateNextRefresh or 0) then
            return
        end
        if now ~= 0 then
            self._betteruiNameplateNextRefresh = now + 250
        end
        local settings = GetSettings()
        if not ArePositionsUnlocked(settings) then
            return
        end
        if Positioning.ApplyCurrentSettings then
            Positioning.ApplyCurrentSettings(settings)
        end
    end)
end

local function ApplyDescriptor(key, descriptor, settings)
    local enabled = IsPositioningEnabled(settings) and GetSetting(settings, descriptor.enabledKey) == true
    local offsetX = ClampOffset(GetSetting(settings, descriptor.xKey))
    local offsetY = ClampOffset(GetSetting(settings, descriptor.yKey))
    local scale = ClampScale(GetSetting(settings, descriptor.scaleKey))
    local applied = 0
    local restored = 0
    local entries = ResolveDescriptorControls(descriptor)
    for _, entry in ipairs(entries) do
        local controlName = entry.name or (descriptor.controls and descriptor.controls[1])
        local control = entry.control
        if enabled then
            if SetAnchorsWithOffset(control, controlName, descriptor, offsetX, offsetY) then
                applied = applied + 1
                TraceAnchorChain(control, controlName, descriptor, "applied")
            end
        elseif RestoreAnchors(control, controlName, descriptor) then
            restored = restored + 1
            TraceAnchorChain(control, controlName, descriptor, "restored")
        end
        -- Scale rides the same enable gate; disabled elements return to the
        -- game's default scale. Skip no-op writes to avoid per-tick churn.
        -- Descriptors with a custom applyScale own scaling entirely: the
        -- compass frame must never be SetScale'd on top of being resized.
        if control and descriptor.scaleKey and not descriptor.applyScale and type(control.SetScale) == "function" then
            local targetScale = enabled and scale or 1
            local okCurrent, currentScale = pcall(control.GetScale, control)
            if not okCurrent or type(currentScale) ~= "number" or math.abs(currentScale - targetScale) > 0.001 then
                pcall(control.SetScale, control, targetScale)
            end
        end
    end
    if descriptor.applyScale then
        pcall(descriptor.applyScale, enabled and scale or 1)
    end
    SetHandleState(key, descriptor, settings, entries)
    if applied > 0 or restored > 0 then
        TracePositioning(enabled and "applied" or "restored", {
            key = key,
            enabled = enabled,
            offsetX = offsetX,
            offsetY = offsetY,
            scale = scale,
            applied = applied,
            restored = restored,
            unlocked = ArePositionsUnlocked(settings),
        })
    end
end

-- The Golden Pursuits tracker has no mover of its own. In vanilla the HUD
-- trackers form one anchor stack (quest container -> zone story -> Golden
-- Pursuits), so they already follow the quest tracker vertically; only an
-- ANCHOR_CONSTRAINS_X secondary anchor pins their X to the screen edge.
-- While the quest mover is on, re-apply each tracker's own primary anchor
-- WITHOUT that secondary so the stack follows the moved quest panel
-- horizontally too. Never anchor these trackers to the quest panel itself:
-- the panel sits upstream of them in the stack, so that closes an anchor
-- cycle and the engine drops the quest panel from layout entirely.
local CHAINED_TRACKER_GLOBALS = { "ZONE_STORY_TRACKER", "PROMOTIONAL_EVENT_TRACKER" }

local function IsChainedTracker(tracker)
    if not tracker then return false end
    for _, globalName in ipairs(CHAINED_TRACKER_GLOBALS) do
        if tracker == rawget(_G, globalName) then
            return true
        end
    end
    return false
end

local function ApplyPrimaryOnlyAnchor(tracker)
    local control = tracker and tracker.control
    if not (control and control.ClearAnchors and type(tracker.GetPrimaryAnchor) == "function") then
        return false
    end
    local okPrimary, primary = pcall(tracker.GetPrimaryAnchor, tracker)
    if not (okPrimary and primary and type(primary.AddToControl) == "function") then
        return false
    end
    local reanchored = pcall(function()
        control:ClearAnchors()
        primary:AddToControl(control)
    end)
    return reanchored
end

local function ChainGoldenPursuitsToQuestTracker(settings)
    settings = settings or GetSettings()
    local quest = DESCRIPTORS.questTracker
    if not (settings and quest) then return end
    local chained = IsPositioningEnabled(settings) and GetSetting(settings, quest.enabledKey) == true
    for _, globalName in ipairs(CHAINED_TRACKER_GLOBALS) do
        local tracker = rawget(_G, globalName)
        local control = tracker and tracker.control
        if control then
            if chained then
                if ApplyPrimaryOnlyAnchor(tracker) then
                    control._betteruiChainedToQuest = true
                end
            elseif control._betteruiChainedToQuest then
                control._betteruiChainedToQuest = nil
                -- Hand anchor ownership back to ZOS once the quest mover
                -- turns off.
                if type(tracker.RefreshAnchors) == "function" then
                    pcall(tracker.RefreshAnchors, tracker)
                end
            end
        end
    end
end

-- The chained trackers (ZO_HUDTracker_Base subclasses) re-assert their
-- screen-edge anchors on every activity update and platform style swap;
-- strip the X pin again right after so they keep following the moved
-- quest panel.
local goldenPursuitsHookInstalled = false
local goldenPursuitsReapplying = false
local function EnsureGoldenPursuitsHook()
    if goldenPursuitsHookInstalled then
        return
    end
    local base = rawget(_G, "ZO_HUDTracker_Base")
    local securePostHook = rawget(_G, "SecurePostHook")
    if not (base and type(securePostHook) == "function") then
        return
    end
    goldenPursuitsHookInstalled = true
    securePostHook(base, "RefreshAnchors", function(tracker)
        if goldenPursuitsReapplying then
            return
        end
        if not IsChainedTracker(tracker) then
            return
        end
        local settings = GetSettings()
        if not settings then
            return
        end
        goldenPursuitsReapplying = true
        pcall(ChainGoldenPursuitsToQuestTracker, settings)
        goldenPursuitsReapplying = false
    end)
end

function Positioning.ApplyCurrentSettings(settings)
    EnsureDescriptorDefaults()
    EnsureRefreshDriver()
    EnsureGoldenPursuitsHook()
    settings = settings or GetSettings()
    for key, descriptor in pairs(DESCRIPTORS) do
        ApplyDescriptor(key, descriptor, settings)
    end
    ChainGoldenPursuitsToQuestTracker(settings)
end

function Positioning.ResetOffsets(settings)
    settings = settings or EnsureSettings()
    if not settings then
        TracePositioning("reset_skipped", { reason = "missingSettings" })
        return false
    end
    settings.nameplatePositionsUnlocked = false
    for _, descriptor in pairs(DESCRIPTORS) do
        settings[descriptor.enabledKey] = false
        settings[descriptor.xKey] = 0
        settings[descriptor.yKey] = 0
        if descriptor.scaleKey then settings[descriptor.scaleKey] = 1 end
    end
    Positioning.ApplyCurrentSettings(settings)
    RefreshSettingsPanel()
    TracePositioning("reset", { unlocked = false })
    return true
end

-- Resets one element's offsets and scale without touching its Move toggle
-- or any other element.
function Positioning.ResetElementOffsets(elementKey)
    local descriptor = DESCRIPTORS[elementKey]
    local settings = EnsureSettings()
    if not (descriptor and settings) then
        TracePositioning("element_reset_skipped", { key = elementKey })
        return false
    end
    settings[descriptor.xKey] = 0
    settings[descriptor.yKey] = 0
    if descriptor.scaleKey then settings[descriptor.scaleKey] = 1 end
    ApplyDescriptor(elementKey, descriptor, settings)
    ChainGoldenPursuitsToQuestTracker(settings)
    RefreshSettingsPanel()
    TracePositioning("element_reset", { key = elementKey })
    return true
end

function Positioning.GetDefaults()
    local defaults = EnsureDescriptorDefaults()
    local clone = {
        nameplatePositionsUnlocked = defaults.nameplatePositionsUnlocked,
    }
    for _, descriptor in pairs(DESCRIPTORS) do
        clone[descriptor.enabledKey] = defaults[descriptor.enabledKey]
        clone[descriptor.xKey] = defaults[descriptor.xKey]
        clone[descriptor.yKey] = defaults[descriptor.yKey]
        if descriptor.scaleKey then clone[descriptor.scaleKey] = defaults[descriptor.scaleKey] end
    end
    return clone
end

function Positioning.IsPositionControlDisabled(elementKey)
    local settings = GetSettings()
    local descriptor = DESCRIPTORS[elementKey]
    if not descriptor then return true end
    -- These HUD movers are exposed from the General tab. The Nameplates module
    -- owns their legacy storage, but the Enhanced Nameplates font toggle should
    -- not gate manual positioning controls.
    local moduleEnabled = IsPositioningEnabled(settings)
    local elementEnabled = GetSetting(settings, descriptor.enabledKey) == true
    local unlocked = ArePositionsUnlocked(settings)
    local disabled = not (moduleEnabled and elementEnabled)
    if disabled then
        local L = BETTERUI and BETTERUI.Log
        local traceLevel = L and L.LEVEL and L.LEVEL.TRACE
        TracePositioning("blocked", {
            fn = "Nameplates.Positioning.IsPositionControlDisabled",
            elementKey = elementKey,
            enabledKey = descriptor.enabledKey,
            moduleEnabled = moduleEnabled,
            elementEnabled = elementEnabled,
            unlocked = unlocked,
            disabled = disabled,
        }, traceLevel)
    end
    return disabled
end
