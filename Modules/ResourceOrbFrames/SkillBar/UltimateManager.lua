--[[
File: Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua
Purpose: Manages the Ultimate meter updates and ready animations.
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local Utils = BETTERUI.ResourceOrbFrames.Utils
local FindControl = Utils.FindControl
local ClampTextSize = Utils.ClampTextSize
-- Hot-path accessor: live settings table by reference (no deep clone per
-- 100ms tick). Read-only by convention.
local GetLiveSettings = (Utils.Settings and Utils.Settings.GetLive) or Utils.GetSettings

local ULTIMATE_TEXT_SIZE_MIN = 12
local ULTIMATE_TEXT_SIZE_MAX = 30

-- Ultimate fill sprite sheet geometry (8x4 grid, 32 frames).
local CELLS_WIDE = 8
local CELLS_HIGH = 4
local TOTAL_FRAMES = 32

local function InstallTimelinePostHook(timeline, handlerName, hookFn, hookedField)
    if not timeline or timeline[hookedField] then return end

    local installed = false
    if type(ZO_PostHookHandler) == "function" then
        ZO_PostHookHandler(timeline, handlerName, hookFn)
        installed = true
    elseif type(timeline.SetHandler) == "function" then
        local previousHandler = timeline.GetHandler and timeline:GetHandler(handlerName) or nil
        timeline:SetHandler(handlerName, function(...)
            if type(previousHandler) == "function" then
                previousHandler(...)
            end
            hookFn(...)
        end)
        installed = true
    end

    if installed then
        timeline[hookedField] = true
    end
end

local function TraceUltimate(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "ultimate"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.ACTION or categories.STATE, event, phase, data)
end

local function ShouldTraceUltimate()
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return false end
    if type(L.EnabledFor) ~= "function" then return true end
    local categories = L.CATEGORY or {}
    local levels = L.LEVEL or {}
    local level = levels.DEBUG
    if type(level) ~= "number" then
        return type(L.IsActive) ~= "function" or L.IsActive()
    end
    return L.EnabledFor(level, categories.ACTION or categories.STATE)
end

local function TraceUltimateChanged(ultBtn, currentUltimate, abilityCost, frameIndex, ready, reason)
    if not ultBtn then return end
    if not ShouldTraceUltimate() then return end
    local stateKey = table.concat({
        tostring(abilityCost),
        tostring(frameIndex),
        tostring(ready == true),
        tostring(reason),
    }, ":")
    if ultBtn._betteruiUltimateChangedKey == stateKey then return end
    ultBtn._betteruiUltimateChangedKey = stateKey
    TraceUltimate("resource_orbs.ultimate", "changed", {
        fn = "UpdateFrontBarUltimateMeter",
        currentUltimate = currentUltimate,
        abilityCost = abilityCost,
        frameIndex = frameIndex,
        ready = ready == true,
        reason = reason,
    })
end

--- Maps a frame index onto the sprite sheet texture coordinates.
--- Hoisted to file scope so the 100ms meter tick does not allocate a closure
--- per call.
---@param texture table|nil Texture control
---@param frameIndex number Zero-based sprite frame index
---@param mirror boolean Whether to mirror the frame horizontally
local function SetSpriteFrame(texture, frameIndex, mirror)
    if not texture then return end
    local col = frameIndex % CELLS_WIDE
    local row = math.floor(frameIndex / CELLS_WIDE)
    local cellWidth = 1.0 / CELLS_WIDE
    local cellHeight = 1.0 / CELLS_HIGH
    local left = col * cellWidth
    local right = left + cellWidth
    local top = row * cellHeight
    local bottom = top + cellHeight

    if mirror then
        local temp = left
        left = right
        right = temp
    end
    texture:SetTextureCoords(left, right, top, bottom)
end


local function ApplyUltimateTextAnchor(ultimateButtonControl, ultimateTextControl)
    if not ultimateButtonControl or not ultimateTextControl then
        return
    end

    local offsetX = BETTERUI_ULTIMATE_NUMBER_TEXT_OFFSET_X or 0
    local offsetY = BETTERUI_ULTIMATE_NUMBER_TEXT_OFFSET_Y or -20
    local textHeight = BETTERUI_ULTIMATE_NUMBER_TEXT_HEIGHT or 32

    ultimateTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ultimateTextControl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    ultimateTextControl:SetDimensions(0, textHeight)
    ultimateTextControl:ClearAnchors()
    ultimateTextControl:SetAnchor(BOTTOM, ultimateButtonControl, BOTTOM, offsetX, offsetY)
end

---@param btn table Ultimate button control with readyBurst/readyLoop children
local function PlayUltimateReadyAnimations(btn)
    local readyBurst = btn.readyBurst
    local readyLoop = btn.readyLoop
    local glowAnim = btn.glowAnimation

    if not btn.readyBurstTimeline then
        btn.readyBurstTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ResourceOrbFrames_UltimateReadyBurst",
            readyBurst)
        btn.readyLoopTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ResourceOrbFrames_UltimateReadyLoop",
            readyLoop)

        -- Sound is handled in UpdateFrontBarUltimateMeter to ensure it plays only once per threshold crossing.
        -- No OnPlay hook is needed here.

        local function OnStop(timeline)
            if timeline:GetProgress() == 1.0 then
                if readyBurst then readyBurst:SetHidden(true) end
                btn.readyLoopTimeline:PlayFromStart()
                if readyLoop then readyLoop:SetHidden(false) end
            end
        end
        InstallTimelinePostHook(btn.readyBurstTimeline, "OnStop", OnStop, "_betteruiUltimateReadyBurstStopHooked")
    end

    local isBursting = btn.readyBurstTimeline:IsPlaying()
    local isLooping = btn.readyLoopTimeline:IsPlaying()

    if not isBursting and not isLooping then
        if readyBurst then readyBurst:SetHidden(false) end
        btn.readyBurstTimeline:PlayFromStart()
        -- The loop animation is chained from the burst's OnStop handler.

        -- Also play glow animation
        if glowAnim then
            glowAnim:PingPong(0, 1, 500 * (1 / 3), 1) -- Bounce duration approx 167ms
        end
        TraceUltimate("resource_orbs.ultimate_meter", "ready_animation_started", {
            fn = "PlayUltimateReadyAnimations",
            hasBurst = readyBurst ~= nil,
            hasLoop = readyLoop ~= nil,
            hasGlow = glowAnim ~= nil,
        })
    end
end

---@param btn table Ultimate button control
local function StopUltimateReadyAnimations(btn)
    if btn.readyBurstTimeline then
        btn.readyBurstTimeline:Stop()
        btn.readyLoopTimeline:Stop()
    end
    if btn.readyBurst then btn.readyBurst:SetHidden(true) end
    if btn.readyLoop then btn.readyLoop:SetHidden(true) end
    if btn.glowAnimation then btn.glowAnimation:Stop() end
    if btn.glow then btn.glow:SetAlpha(0) end
end

--- Updates the ultimate fill sprites and triggers ready animations.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateFrontBarUltimateMeter(rootFrame)
    local frontBarCfg = GetLiveSettings().customFrontBar
    if not frontBarCfg or not frontBarCfg.m_enabled then return end

    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end

    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local fillLeft = ultBtn.fillLeft
        local fillRight = ultBtn.fillRight
        if not fillLeft or not fillRight then
            fillLeft = ultBtn:GetNamedChild("FillAnimationLeft")
            fillRight = ultBtn:GetNamedChild("FillAnimationRight")
            ultBtn.fillLeft = fillLeft
            ultBtn.fillRight = fillRight
        end
        if fillLeft and fillRight then
            local slotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
            local abilityCost = GetSlotAbilityCost(slotIndex, COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE, GetActiveHotbarCategory())
            local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE) or 0

            if abilityCost and abilityCost > 0 then
                local fillPercent = math.min(1, currentUltimate / abilityCost)
                local frameIndex = math.floor(fillPercent * (TOTAL_FRAMES - 1))
                if abilityCost ~= ultBtn.appliedUltimateCost or frameIndex ~= ultBtn.appliedFrameIndex then
                    ultBtn.appliedUltimateCost = abilityCost
                    ultBtn.appliedFrameIndex = frameIndex
                    SetSpriteFrame(fillLeft, frameIndex, false)
                    SetSpriteFrame(fillRight, frameIndex, true)
                end
                if ultBtn.appliedFillHidden ~= false then
                    ultBtn.appliedFillHidden = false
                    fillLeft:SetHidden(false)
                    fillRight:SetHidden(false)
                end

                -- Handle Ultimate Ready Animation
                local readyState = currentUltimate >= abilityCost
                TraceUltimateChanged(ultBtn, currentUltimate, abilityCost, frameIndex, readyState, "meter")
                if currentUltimate >= abilityCost then
                    if not ultBtn.isUltimateReady then
                        ultBtn.isUltimateReady = true
                        PlayUltimateReadyAnimations(ultBtn)
                        PlaySound(SOUNDS.ABILITY_ULTIMATE_READY)
                        TraceUltimate("resource_orbs.ultimate_meter", "ready", {
                            fn = "UpdateFrontBarUltimateMeter",
                            currentUltimate = currentUltimate,
                            abilityCost = abilityCost,
                            frameIndex = frameIndex,
                            sound = "ABILITY_ULTIMATE_READY",
                        })
                    end
                else
                    if ultBtn.isUltimateReady then
                        ultBtn.isUltimateReady = false
                        StopUltimateReadyAnimations(ultBtn)
                    end
                end
                -- Preflight before building the dedup key so the per-100ms
                -- table.concat only runs while tracing is active (TRACE-002B).
                if ShouldTraceUltimate() then
                local traceKey = table.concat({
                    tostring(currentUltimate),
                    tostring(abilityCost),
                    tostring(frameIndex),
                    tostring(readyState),
                }, ":")
                if ultBtn._betteruiUltimateMeterTraceKey ~= traceKey then
                    ultBtn._betteruiUltimateMeterTraceKey = traceKey
                    TraceUltimate("resource_orbs.ultimate_meter", readyState and "updated_ready" or "updated", {
                        fn = "UpdateFrontBarUltimateMeter",
                        currentUltimate = currentUltimate,
                        abilityCost = abilityCost,
                        frameIndex = frameIndex,
                        fillPercent = fillPercent,
                        ready = readyState,
                    })
                end
                end
            else
                if ultBtn.appliedFillHidden ~= true then
                    ultBtn.appliedFillHidden = true
                    fillLeft:SetHidden(true)
                    fillRight:SetHidden(true)
                end
                if ultBtn.isUltimateReady then
                    ultBtn.isUltimateReady = false
                    StopUltimateReadyAnimations(ultBtn)
                end
                ultBtn.appliedUltimateCost = nil
                ultBtn.appliedFrameIndex = nil
                if ultBtn._betteruiUltimateMeterTraceKey ~= "hidden:noCost" then
                    ultBtn._betteruiUltimateMeterTraceKey = "hidden:noCost"
                    TraceUltimateChanged(ultBtn, GetUnitPower("player", POWERTYPE_ULTIMATE) or 0, abilityCost, nil, false,
                        "missingAbilityCost")
                    TraceUltimate("resource_orbs.ultimate_meter", "not_ready", {
                        fn = "UpdateFrontBarUltimateMeter",
                        reason = "missingAbilityCost",
                        currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE) or 0,
                        abilityCost = abilityCost,
                    })
                end
            end
        end
    end
end

--- Applies static ultimate number styling (anchor, font, color).
--- Cheap when nothing changed: re-applies only when the style-affecting
--- settings values differ from the last applied ones (keeps the 100ms tick
--- from re-anchoring and re-fonting every pass).
---@param ultBtn table Ultimate button control
---@param countText table Ultimate number label control
---@param settings table Module settings (live table)
local function ApplyUltimateNumberStyle(ultBtn, countText, settings)
    local textSize = ClampTextSize(settings.ultimateTextSize, ULTIMATE_TEXT_SIZE_MIN, ULTIMATE_TEXT_SIZE_MAX, 27)
    local color = settings.ultimateTextColor or { 1, 1, 1, 1 }
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    if countText.appliedTextSize == textSize and countText.appliedTextR == r
        and countText.appliedTextG == g and countText.appliedTextB == b
        and countText.appliedTextA == a then
        return
    end
    countText.appliedTextSize = textSize
    countText.appliedTextR, countText.appliedTextG, countText.appliedTextB, countText.appliedTextA = r, g, b, a

    ApplyUltimateTextAnchor(ultBtn, countText)
    -- Standardize font string format
    countText:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", textSize))
    countText:SetColor(r, g, b, a)
end

--- Updates the ultimate count text label.
---@param rootFrame table Root ResourceOrbFrames control
local function UpdateFrontBarUltimateNumber(rootFrame)
    local settings = GetLiveSettings()
    local frontBarContainer = FindControl(rootFrame, 'FrontBarContainer')
    if not frontBarContainer then return end
    local ultBtn = FindControl(frontBarContainer, 'UltimateButton')
    if ultBtn then
        local countText = ultBtn:GetNamedChild("UltimateText")
        if countText then
            if settings.showUltimateNumber then
                local currentUltimate = GetUnitPower("player", POWERTYPE_ULTIMATE) or 0
                local ultimateStr = tostring(currentUltimate)
                if countText.appliedText ~= ultimateStr then
                    countText.appliedText = ultimateStr
                    countText:SetText(ultimateStr)
                    TraceUltimate("resource_orbs.ultimate_number", "updated", {
                        fn = "UpdateFrontBarUltimateNumber",
                        currentUltimate = currentUltimate,
                        text = ultimateStr,
                        visible = true,
                    })
                end
                if countText.appliedHidden ~= false then
                    countText.appliedHidden = false
                    countText:SetHidden(false)
                end
                ApplyUltimateNumberStyle(ultBtn, countText, settings)
            else
                if countText.appliedHidden ~= true then
                    countText.appliedHidden = true
                    countText:SetHidden(true)
                    TraceUltimate("resource_orbs.ultimate_number", "hidden", {
                        fn = "UpdateFrontBarUltimateNumber",
                        reason = "settingDisabled",
                    })
                end
            end
        end
    end
end

-- MODULE EXPORTS
SkillBar.PlayUltimateReadyAnimations = PlayUltimateReadyAnimations
SkillBar.StopUltimateReadyAnimations = StopUltimateReadyAnimations
SkillBar.UpdateFrontBarUltimateMeter = UpdateFrontBarUltimateMeter
SkillBar.UpdateFrontBarUltimateNumber = UpdateFrontBarUltimateNumber
