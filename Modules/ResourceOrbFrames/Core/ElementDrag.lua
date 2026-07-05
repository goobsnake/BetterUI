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
local m_handleLabels = {}
local m_handleFills = {}
-- ESO cannot destroy controls and CreateControl returns nil for duplicate
-- names, so detached handles are pooled by name for safe re-attachment.
local m_handleControlPool = {}
local HANDLE_SIZE = 64
local HANDLE_MATCH_MIN_WIDTH = 40
local HANDLE_MATCH_MIN_HEIGHT = 32
local HANDLE_MATCH_MAX_WIDTH = 560
local HANDLE_MATCH_MAX_HEIGHT = 220
local HANDLE_LABEL_HEIGHT = 26
local HANDLE_ICON_DRAW_LEVEL = 512
local HANDLE_ARROW_MIN_SIZE = 14
local HANDLE_ARROW_MAX_SIZE = 44
local HANDLE_ARROW_SCALE = 0.35
local HANDLE_ARROW_SLIM = 0.7
local HANDLE_ARROW_EDGE_INSET = 2
local HANDLE_ARROW_SHADOW_OFFSET = 2
local HANDLE_ARROW_SHADOW_ALPHA = 0.6
local HANDLE_ARROW_SHADOW_DRAW_LEVEL = 513
local HANDLE_ARROW_ALPHA = 1
local HANDLE_ARROW_FACE_DRAW_LEVEL = 514
-- Native gold ESO arrow art. The housing precision icons carry baked-in
-- per-axis colors; the earlier "invisible arrows" were the GuiRoot
-- render-list bug, not these textures.
local HANDLE_ICON_TEXTURES = {
    { key = "Left", texture = "EsoUI/Art/Buttons/leftArrow_up.dds", x = -1, y = 0 },
    { key = "Right", texture = "EsoUI/Art/Buttons/rightArrow_up.dds", x = 1, y = 0 },
    { key = "Up", texture = "EsoUI/Art/Buttons/scrollbox_upArrow_up.dds", x = 0, y = -1 },
    { key = "Down", texture = "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds", x = 0, y = 1 },
}
local DRAG_THRESHOLD = 2
local DRAG_REFRESH_INTERVAL_MS = 75
local OFFSET_MIN = -600
local OFFSET_MAX = 600
local SETTINGS_PANEL_IDS = {
    "BETTERUI_Modules",
    "BETTERUI_ResourceOrbFrames",
}
-- Box labels resolve through lang strings with short English fallbacks
-- sized to fit their boxes.
local ELEMENT_LABELS = {
    leftOrb = { stringId = "SI_BETTERUI_MOVER_LABEL_LEFT_ORB", fallback = "Left Orb" },
    rightOrb = { stringId = "SI_BETTERUI_MOVER_LABEL_RIGHT_ORB", fallback = "Right Orb" },
    skillBars = { stringId = "SI_BETTERUI_MOVER_LABEL_SKILL_BARS", fallback = "Skill Bars" },
    xpBar = { stringId = "SI_BETTERUI_MOVER_LABEL_XP_BAR", fallback = "XP Bar" },
    mountBar = { stringId = "SI_BETTERUI_MOVER_LABEL_MOUNT_STAMINA", fallback = "Mnt Stam" },
    castBar = { stringId = "SI_BETTERUI_MOVER_LABEL_CAST_BAR", fallback = "Cast Bar" },
    quickslot = { stringId = "SI_BETTERUI_MOVER_LABEL_QUICKSLOT", fallback = "Quickslot" },
    companionUltimate = { stringId = "SI_BETTERUI_MOVER_LABEL_COMPANION_ULTIMATE", fallback = "Comp. Ult" },
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

-- The health orb host is padded by ornament art, so its box borrows the
-- resource orb's footprint to keep the twin orb handles identical.
local ELEMENT_DIMENSION_TWINS = { leftOrb = "rightOrb" }

-- Optional per-element span controls (options.spanControls at attach): the
-- box covers the union rect of these controls instead of just the host,
-- e.g. the skill bars box runs from the first skill icon to the ultimate.
local m_handleSpans = {}

local function GetSpanRect(controls)
    local left, top, right, bottom
    for _, spanControl in ipairs(controls or {}) do
        -- Hidden span members (e.g. a hidden secondary skill bar) must not
        -- stretch the box; only currently-present controls count.
        local hiddenOk, isHidden = pcall(function()
            return type(spanControl.IsHidden) == "function" and spanControl:IsHidden() == true
        end)
        local width, height = GetControlDimensions(spanControl)
        local centerX, centerY = GetControlCenter(spanControl)
        if not (hiddenOk and isHidden)
            and width and height and centerX and centerY and width > 0 and height > 0 then
            local l, t = centerX - width / 2, centerY - height / 2
            local r, b = centerX + width / 2, centerY + height / 2
            if not left or l < left then left = l end
            if not top or t < top then top = t end
            if not right or r > right then right = r end
            if not bottom or b > bottom then bottom = b end
        end
    end
    if not left then return nil end
    return left, top, right, bottom
end

-- Handles mirror the represented element's footprint; the clamps keep tiny
-- buttons grabbable and wide bars from flooding the HUD. Hosts with no rect
-- yet fall back to a default square.
local function GetHandleDimensions(hostControl, elemKey)
    local width, height
    local spanLeft, spanTop, spanRight, spanBottom = GetSpanRect(elemKey and m_handleSpans[elemKey])
    if spanLeft then
        width, height = spanRight - spanLeft, spanBottom - spanTop
    else
        local twinKey = elemKey and ELEMENT_DIMENSION_TWINS[elemKey]
        local twinHost = twinKey and m_handleHosts[twinKey]
        if twinHost then
            hostControl = twinHost
        end
        width, height = GetControlDimensions(hostControl)
    end
    width = tonumber(width) or 0
    height = tonumber(height) or 0
    if width <= 0 or height <= 0 then
        return HANDLE_SIZE, HANDLE_SIZE
    end
    width = ClampNumber(width, HANDLE_MATCH_MIN_WIDTH, HANDLE_MATCH_MAX_WIDTH, HANDLE_SIZE)
    height = ClampNumber(height, HANDLE_MATCH_MIN_HEIGHT, HANDLE_MATCH_MAX_HEIGHT, HANDLE_SIZE)
    local round = zo_round or function(v) return math.floor(v + 0.5) end
    return round(width), round(height)
end

local function SetTextureGuarded(textureControl, texturePath)
    if not textureControl or not textureControl.SetTexture then return false end
    return pcall(textureControl.SetTexture, textureControl, texturePath)
end

local function HumanizeElementKey(elemKey)
    local label = tostring(elemKey or "HUD Element")
    label = label:gsub("(%l)(%u)", "%1 %2")
    label = label:gsub("^%l", string.upper)
    return label
end

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

local function ResolveHandleLabel(elemKey, options)
    if options and type(options.label) == "string" and options.label ~= "" then
        return options.label
    end
    local entry = ELEMENT_LABELS[elemKey]
    if entry then
        return ResolveMoverLabel(entry.stringId, entry.fallback)
    end
    return HumanizeElementKey(elemKey)
end

local function EnsureHandleIcon(handle)
    if not handle then return nil end
    if m_handleIcons[handle] then return m_handleIcons[handle] end

    local handleName = GetControlName(handle) or "BetterUI_DragHandle"
    local icon = WINDOW_MANAGER:CreateControl(handleName .. "MoveIcon", handle, CT_CONTROL)
    if icon.SetMouseEnabled then icon:SetMouseEnabled(false) end
    if icon.SetDrawLayer then icon:SetDrawLayer(DL_OVERLAY) end
    if icon.SetDrawTier and DT_HIGH then icon:SetDrawTier(DT_HIGH) end
    if icon.SetDrawLevel then icon:SetDrawLevel(HANDLE_ICON_DRAW_LEVEL) end

    local data = { control = icon, parts = {} }
    for _, def in ipairs(HANDLE_ICON_TEXTURES) do
        local shadow = WINDOW_MANAGER:CreateControl(handleName .. "MoveIconShadow" .. def.key, icon, CT_TEXTURE)
        SetTextureGuarded(shadow, def.texture)
        if shadow.SetMouseEnabled then shadow:SetMouseEnabled(false) end
        if shadow.SetDrawLayer then shadow:SetDrawLayer(DL_OVERLAY) end
        if shadow.SetDrawTier and DT_HIGH then shadow:SetDrawTier(DT_HIGH) end
        if shadow.SetDrawLevel then shadow:SetDrawLevel(HANDLE_ARROW_SHADOW_DRAW_LEVEL) end
        data.parts[#data.parts + 1] = { control = shadow, x = def.x, y = def.y, shadow = true }

        local face = WINDOW_MANAGER:CreateControl(handleName .. "MoveIcon" .. def.key, icon, CT_TEXTURE)
        SetTextureGuarded(face, def.texture)
        if face.SetMouseEnabled then face:SetMouseEnabled(false) end
        if face.SetDrawLayer then face:SetDrawLayer(DL_OVERLAY) end
        if face.SetDrawTier and DT_HIGH then face:SetDrawTier(DT_HIGH) end
        if face.SetDrawLevel then face:SetDrawLevel(HANDLE_ARROW_FACE_DRAW_LEVEL) end
        data.parts[#data.parts + 1] = { control = face, x = def.x, y = def.y, shadow = false }
    end
    m_handleIcons[handle] = data
    return data
end

-- Each arrow hugs the box edge it points at (left arrow on the left edge,
-- up arrow on the top edge, ...) instead of clustering at the center, and
-- is slimmed along its pointing axis so opposing pairs read as chevrons.
local function ConfigureIconPart(parent, part, sideSize, vertSize, insets, hidden)
    local control = part and part.control
    if not control then return end
    local point = CENTER
    local offsetX, offsetY = 0, 0
    local width, height
    if (part.x or 0) < 0 then
        point = rawget(_G, "LEFT") or CENTER
        offsetX = insets.side
        width, height = math.floor(sideSize * HANDLE_ARROW_SLIM + 0.5), sideSize
    elseif (part.x or 0) > 0 then
        point = rawget(_G, "RIGHT") or CENTER
        offsetX = -insets.side
        width, height = math.floor(sideSize * HANDLE_ARROW_SLIM + 0.5), sideSize
    elseif (part.y or 0) < 0 then
        point = rawget(_G, "TOP") or CENTER
        offsetY = insets.top
        width, height = vertSize, math.floor(vertSize * HANDLE_ARROW_SLIM + 0.5)
    else
        point = rawget(_G, "BOTTOM") or CENTER
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

local function UpdateHandleIconVisual(handle, locked)
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
    local hidden = locked == true

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
    if not handle then return nil end
    if m_handleLabels[handle] then return m_handleLabels[handle] end
    if not (WINDOW_MANAGER and CT_LABEL) then return nil end

    local handleName = GetControlName(handle) or "BetterUI_DragHandle"
    local label = WINDOW_MANAGER:CreateControl(handleName .. "Label", handle, CT_LABEL)
    if label.SetMouseEnabled then label:SetMouseEnabled(false) end
    if label.SetFont then label:SetFont("$(BOLD_FONT)|16|soft-shadow-thin") end
    if label.SetHorizontalAlignment and TEXT_ALIGN_CENTER then label:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    if label.SetVerticalAlignment and TEXT_ALIGN_CENTER then label:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
    if label.SetColor then label:SetColor(0.85, 0.95, 1, 1) end
    if label.SetDrawLayer then label:SetDrawLayer(DL_OVERLAY) end
    if label.SetDrawTier and DT_HIGH then label:SetDrawTier(DT_HIGH) end
    if label.SetDrawLevel then label:SetDrawLevel(515) end
    m_handleLabels[handle] = label
    return label
end

local function UpdateHandleLabelVisual(handle, locked)
    local label = EnsureHandleLabel(handle)
    if not label then return end
    local width = (GetControlDimensions(handle))
    width = tonumber(width) or HANDLE_SIZE
    if label.SetText then label:SetText(handle._betteruiResourceOrbDragLabel or "HUD Element") end
    if label.SetHidden then label:SetHidden(locked == true) end
    if label.SetDimensions then label:SetDimensions(math.max(width - 12, 120), HANDLE_LABEL_HEIGHT) end
    if label.ClearAnchors then label:ClearAnchors() end
    if label.SetAnchor then
        -- Centered so the four edge arrows surround the element name.
        label:SetAnchor(CENTER, handle, CENTER, 0, 0)
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

local function IsControlHidden(control)
    if control and type(control.IsHidden) == "function" then
        local ok, hidden = pcall(control.IsHidden, control)
        if ok then return hidden == true end
    end
    return false
end

local function GetResolvableControlCenter(control)
    if control and type(control.GetCenter) == "function" then
        local ok, x, y = pcall(control.GetCenter, control)
        if ok and type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
            return x, y
        end
    end
    return nil
end

local function AnchorHandle(handle, hostControl, elemKey)
    if not (handle and handle.SetAnchor) then return end
    local guiRoot = rawget(_G, "GuiRoot")
    -- Hidden hosts keep their layout rect, so the handle can hold the element's
    -- real position; only a host with no resolvable rect (never laid out or
    -- missing) falls back to screen center so the box stays grabbable.
    local relativeTo = hostControl
    if not hostControl or (IsControlHidden(hostControl) and not GetResolvableControlCenter(hostControl)) then
        relativeTo = guiRoot or hostControl
    end
    if not relativeTo then return end
    -- Span-derived boxes recenter on the union rect of their span controls.
    local offsetX, offsetY = 0, 0
    local spanLeft, spanTop, spanRight, spanBottom = GetSpanRect(elemKey and m_handleSpans[elemKey])
    if spanLeft then
        local relCenterX, relCenterY = GetControlCenter(relativeTo)
        if relCenterX and relCenterY then
            offsetX = (spanLeft + spanRight) / 2 - relCenterX
            offsetY = (spanTop + spanBottom) / 2 - relCenterY
        end
    end
    if handle.ClearAnchors then handle:ClearAnchors() end
    handle:SetAnchor(CENTER, relativeTo, CENTER, offsetX, offsetY)
end

local m_handleLayer = nil

-- ESO only renders top-level windows and their descendants; a plain control
-- parented straight to GuiRoot never enters the render list, which is why
-- GuiRoot-rooted handles had perfect state but drew nothing. All handles
-- live under one dedicated always-shown top-level window instead.
local function EnsureHandleLayer()
    if m_handleLayer then return m_handleLayer end
    if not (WINDOW_MANAGER and type(WINDOW_MANAGER.CreateTopLevelWindow) == "function") then
        return nil
    end
    local layer = WINDOW_MANAGER:CreateTopLevelWindow("BetterUI_OrbMoverLayer")
    if not layer then return nil end
    if layer.SetMouseEnabled then layer:SetMouseEnabled(false) end
    if layer.SetHidden then layer:SetHidden(false) end
    if layer.SetDrawLayer then layer:SetDrawLayer(DL_OVERLAY) end
    if layer.SetDrawTier and DT_HIGH then layer:SetDrawTier(DT_HIGH) end
    if layer.SetDimensions then layer:SetDimensions(1, 1) end
    if layer.SetAnchor and CENTER then
        layer:SetAnchor(CENTER, rawget(_G, "GuiRoot"), CENTER, 0, 0)
    end
    m_handleLayer = layer
    return layer
end

-- The box body is drawn with untextured CT_TEXTURE rects: ZOS renders those
-- as solid color fills (housing editor translation indicators do the same),
-- while a Lua-created CT_BACKDROP renders nothing without texture files —
-- which is why the previous backdrop-based box never appeared in game.
local function EnsureHandleFill(handle)
    if not handle then return nil end
    if m_handleFills[handle] then return m_handleFills[handle] end
    local topLeft = rawget(_G, "TOPLEFT")
    local bottomRight = rawget(_G, "BOTTOMRIGHT")
    if not (WINDOW_MANAGER and CT_TEXTURE and topLeft and bottomRight) then return nil end
    local handleName = GetControlName(handle) or "BetterUI_DragHandle"

    local function CreatePart(suffix, level, r, g, b, a, inset)
        local part = WINDOW_MANAGER:CreateControl(handleName .. suffix, handle, CT_TEXTURE)
        if not part then return nil end
        if part.SetMouseEnabled then part:SetMouseEnabled(false) end
        if part.SetAnchor then
            part:SetAnchor(topLeft, handle, topLeft, -inset, -inset)
            part:SetAnchor(bottomRight, handle, bottomRight, inset, inset)
        end
        if part.SetDrawLayer then part:SetDrawLayer(DL_OVERLAY) end
        if part.SetDrawTier and DT_HIGH then part:SetDrawTier(DT_HIGH) end
        if part.SetDrawLevel then part:SetDrawLevel(level) end
        if part.SetColor then part:SetColor(r, g, b, a) end
        return part
    end

    local data = {
        border = CreatePart("BorderFill", 510, 0.78, 0.88, 1, 0.55, 2),
        fill = CreatePart("Fill", 511, 0.72, 0.82, 0.95, 0.10, 0),
    }
    m_handleFills[handle] = data
    return data
end

local function SetHandleVisual(handle, locked)
    if not handle then return end
    local fills = EnsureHandleFill(handle)
    if fills then
        if fills.border and fills.border.SetHidden then fills.border:SetHidden(locked == true) end
        if fills.fill and fills.fill.SetHidden then fills.fill:SetHidden(locked == true) end
    end
    local alpha = locked and 0 or 0.15
    local hasBackdropColor = handle.SetCenterColor or handle.SetEdgeColor
    -- Backdrop alpha stays faint without dimming the child move icon.
    if handle.SetCenterColor then
        handle:SetCenterColor(0.15, 0.45, 1, alpha)
    end
    if handle.SetEdgeColor then
        handle:SetEdgeColor(0.35, 0.70, 1, locked and 0 or 0.85)
    end
    if handle.SetHidden then
        handle:SetHidden(false)
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
    UpdateHandleLabelVisual(handle, locked)
end

local function AreElementPositionsUnlocked(settings)
    return settings and settings.elementPositionsUnlocked == true
end

-- Engine-side render snapshot so interface.log shows what actually drew,
-- independent of what the visual setters were asked to do.
local function TraceHandleVisualState(elemKey, handle, locked, origin)
    if not handle then return end
    local width, height = GetControlDimensions(handle)
    local centerX, centerY = GetControlCenter(handle)
    TraceDrag("resource_orbs.element_drag_handle", "visual_state", {
        elemKey = elemKey,
        origin = origin,
        locked = locked == true,
        width = width,
        height = height,
        centerX = centerX,
        centerY = centerY,
        hidden = CallControl(handle, "IsHidden"),
        alpha = CallControl(handle, "GetAlpha"),
        drawTier = CallControl(handle, "GetDrawTier"),
        drawLevel = CallControl(handle, "GetDrawLevel"),
        parent = GetControlName(CallControl(handle, "GetParent")),
    })
end

local function RefreshAllHandleVisuals(unlocked)
    local locked = unlocked ~= true
    for elemKey, handle in pairs(m_handles) do
        -- Hosts may have been laid out after attach; keep the box matched
        -- to the element's current footprint on every lock refresh.
        if handle.SetDimensions then
            handle:SetDimensions(GetHandleDimensions(m_handleHosts[elemKey], elemKey))
        end
        AnchorHandle(handle, m_handleHosts[elemKey], elemKey)
        SetHandleVisual(handle, locked)
        TraceHandleVisualState(elemKey, handle, locked, "global_lock_refresh")
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

function Drag.AttachDragHandle(hostControl, elemKey, settingsGetter, applyCallback, options)
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
    local handleParent = EnsureHandleLayer() or rawget(_G, "GuiRoot") or hostControl
    local handle = m_handleControlPool[handleName]
    if handle then
        if handle.SetParent then handle:SetParent(handleParent) end
    else
        handle = WINDOW_MANAGER:CreateControl(handleName, handleParent, CT_BACKDROP)
        if handle then m_handleControlPool[handleName] = handle end
    end
    if not handle then
        TraceDrag("resource_orbs.element_drag_handle", "attach_failed", {
            elemKey = elemKey,
            reason = "createControlFailed",
        })
        return nil
    end
    handle._betteruiResourceOrbDragLabel = ResolveHandleLabel(elemKey, options)
    m_handleSpans[elemKey] = options and options.spanControls or nil
    handle:SetDimensions(GetHandleDimensions(hostControl, elemKey))
    AnchorHandle(handle, hostControl, elemKey)
    handle:SetDrawLayer(DL_OVERLAY)
    if handle.SetDrawTier and DT_HIGH then handle:SetDrawTier(DT_HIGH) end
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
    TraceHandleVisualState(elemKey, handle, locked, "attach")
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
    -- m_handleIcons/m_handleLabels stay cached: the pooled control and its
    -- named children survive detach and are revived verbatim on re-attach.
    m_handles[elemKey] = nil
    m_handleHosts[elemKey] = nil
    m_handleSpans[elemKey] = nil
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
