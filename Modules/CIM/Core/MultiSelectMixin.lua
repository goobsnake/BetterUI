--[[
File: Modules/CIM/Core/MultiSelectMixin.lua
Purpose: Shared multi-select mixin applied to any module class (Banking, Inventory, etc.).
         Provides batch throttling, selection mode lifecycle, and common batch operations
         (lock/unlock/junk) without code duplication.

Usage:
    BETTERUI.CIM.MultiSelectMixin.Apply(self, {
        getList        = function(s) return s.list end,
        refreshList    = function(s) s:RefreshList() end,
        refreshKeybinds = function(s) KEYBIND_STRIP:UpdateKeybindButtonGroup(s.coreKeybinds) end,
    })

Author: BetterUI Team
Last Modified: 2026-02-09
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.MultiSelectMixin = {}

local Mixin = BETTERUI.CIM.MultiSelectMixin

local DEFAULT_BATCH_THROTTLE_TIERS = {
    { MIN_ITEMS = 50, DELAY_MS = 125, SHOW_PROGRESS = true },
    { MIN_ITEMS = 10, DELAY_MS = 100, SHOW_PROGRESS = true },
    { MIN_ITEMS = 0,  DELAY_MS = 75, SHOW_PROGRESS = false },
}

local TIMING = BETTERUI.CIM.CONST.TIMING or {}
local BATCH_THROTTLE_TIERS = TIMING.BATCH_ACTION_THROTTLE_TIERS or DEFAULT_BATCH_THROTTLE_TIERS
local BATCH_ETA_THRESHOLD = TIMING.BATCH_ETA_THRESHOLD or 50
local DEFAULT_SERVER_COOLDOWN_EVERY = 25
local DEFAULT_SERVER_COOLDOWN_MS = 1100
local DEFAULT_SERVER_MIN_DELAY_MS = 125
local DEFAULT_SERVER_MAX_DELAY_MS = 325
local DEFAULT_SERVER_ACK_TIMEOUT_MS = 1800
local DEFAULT_SERVER_CHUNK_COST_UNITS = 36
local DEFAULT_SERVER_CHUNK_PAUSE_MS = 950
local DEFAULT_SERVER_ADAPTIVE_DELAY = true
local DEFAULT_SERVER_ADAPTIVE_THRESHOLD = 8
local DEFAULT_SERVER_ADAPTIVE_STEP_MS = 16
local DEFAULT_SERVER_JITTER_MS = 18
local DEFAULT_SERVER_POST_BATCH_COOLDOWN_BASE_MS = 3000
local DEFAULT_SERVER_POST_BATCH_COOLDOWN_THRESHOLD = 50
local DEFAULT_SERVER_POST_BATCH_COOLDOWN_PER_COST_MS = 35
local DEFAULT_SERVER_POST_BATCH_COOLDOWN_MAX_MS = 9000
local DEFAULT_SERVER_RATE_WINDOW_MS = 60000
local DEFAULT_SERVER_RATE_MAX_ACTIONS = 125
local SERVER_COOLDOWN_EVERY = TIMING.BATCH_SERVER_COOLDOWN_EVERY or DEFAULT_SERVER_COOLDOWN_EVERY
local SERVER_COOLDOWN_MS = TIMING.BATCH_SERVER_COOLDOWN_MS or DEFAULT_SERVER_COOLDOWN_MS
local SERVER_MIN_DELAY_MS = TIMING.BATCH_SERVER_MIN_DELAY_MS or DEFAULT_SERVER_MIN_DELAY_MS
local SERVER_MAX_DELAY_MS = TIMING.BATCH_SERVER_MAX_DELAY_MS or DEFAULT_SERVER_MAX_DELAY_MS
local SERVER_ACK_TIMEOUT_MS = TIMING.BATCH_SERVER_ACK_TIMEOUT_MS or DEFAULT_SERVER_ACK_TIMEOUT_MS
local SERVER_CHUNK_COST_UNITS = TIMING.BATCH_SERVER_CHUNK_COST_UNITS or DEFAULT_SERVER_CHUNK_COST_UNITS
local SERVER_CHUNK_PAUSE_MS = TIMING.BATCH_SERVER_CHUNK_PAUSE_MS or DEFAULT_SERVER_CHUNK_PAUSE_MS
local SERVER_AWAIT_INVENTORY_ACK = TIMING.BATCH_SERVER_AWAIT_INVENTORY_ACK
if SERVER_AWAIT_INVENTORY_ACK == nil then
    SERVER_AWAIT_INVENTORY_ACK = true
end
local SERVER_ADAPTIVE_DELAY = TIMING.BATCH_SERVER_ADAPTIVE_DELAY
if SERVER_ADAPTIVE_DELAY == nil then
    SERVER_ADAPTIVE_DELAY = DEFAULT_SERVER_ADAPTIVE_DELAY
end
local SERVER_ADAPTIVE_THRESHOLD = TIMING.BATCH_SERVER_ADAPTIVE_THRESHOLD or DEFAULT_SERVER_ADAPTIVE_THRESHOLD
local SERVER_ADAPTIVE_STEP_MS = TIMING.BATCH_SERVER_ADAPTIVE_STEP_MS or DEFAULT_SERVER_ADAPTIVE_STEP_MS
local SERVER_JITTER_MS = TIMING.BATCH_SERVER_JITTER_MS or DEFAULT_SERVER_JITTER_MS
local SERVER_POST_BATCH_COOLDOWN_BASE_MS = TIMING.BATCH_SERVER_POST_BATCH_COOLDOWN_BASE_MS
    or DEFAULT_SERVER_POST_BATCH_COOLDOWN_BASE_MS
local SERVER_POST_BATCH_COOLDOWN_THRESHOLD = TIMING.BATCH_SERVER_POST_BATCH_COOLDOWN_THRESHOLD
    or DEFAULT_SERVER_POST_BATCH_COOLDOWN_THRESHOLD
local SERVER_POST_BATCH_COOLDOWN_PER_COST_MS = TIMING.BATCH_SERVER_POST_BATCH_COOLDOWN_PER_COST_MS
    or DEFAULT_SERVER_POST_BATCH_COOLDOWN_PER_COST_MS
local SERVER_POST_BATCH_COOLDOWN_MAX_MS = TIMING.BATCH_SERVER_POST_BATCH_COOLDOWN_MAX_MS
    or DEFAULT_SERVER_POST_BATCH_COOLDOWN_MAX_MS
local SERVER_RATE_WINDOW_MS = TIMING.BATCH_SERVER_RATE_WINDOW_MS or DEFAULT_SERVER_RATE_WINDOW_MS
local SERVER_RATE_MAX_ACTIONS = TIMING.BATCH_SERVER_RATE_MAX_ACTIONS or DEFAULT_SERVER_RATE_MAX_ACTIONS
local DEFAULT_ACTION_COST_UNITS = 1
local SERVER_BATCH_RECOVERY_STATE = {
    cooldownUntilMs = 0,
    serverActionTimes = {},
}

local function ResolveTierByItemCount(totalItems, tiers, fallback)
    for i = 1, #tiers do
        local tier = tiers[i]
        local minItems = tier.MIN_ITEMS or 0
        if totalItems >= minItems then
            return tier
        end
    end
    return fallback
end

local function ResolveBatchThrottleProfile(totalItems)
    return ResolveTierByItemCount(
        totalItems,
        BATCH_THROTTLE_TIERS,
        DEFAULT_BATCH_THROTTLE_TIERS[#DEFAULT_BATCH_THROTTLE_TIERS]
    )
end

local function ResolveBooleanOption(value, fallback)
    if value == nil then
        return fallback
    end
    return value == true
end

local function ResolvePositiveIntOption(value, fallback)
    local resolved = tonumber(value)
    if not resolved then
        return fallback
    end
    return zo_max(0, zo_ceil(resolved))
end

local function ResolveSignedJitter(maxAbsMs)
    if maxAbsMs <= 0 then
        return 0
    end
    if zo_random then
        return zo_random(-maxAbsMs, maxAbsMs)
    end
    return math.random(-maxAbsMs, maxAbsMs)
end

local function GetNowMs()
    if GetGameTimeMilliseconds then
        return GetGameTimeMilliseconds()
    end

    if GetFrameTimeMilliseconds then
        return GetFrameTimeMilliseconds()
    end

    if GetFrameTimeSeconds then
        return zo_floor(GetFrameTimeSeconds() * 1000)
    end

    return 0
end

local function PruneServerActionHistory(nowMs, windowMs)
    local history = SERVER_BATCH_RECOVERY_STATE.serverActionTimes
    if not history then
        history = {}
        SERVER_BATCH_RECOVERY_STATE.serverActionTimes = history
    end

    -- Defend against timer rollover/reset (e.g., long session wraparound).
    local newest = history[#history]
    if newest and nowMs < newest then
        history = {}
        SERVER_BATCH_RECOVERY_STATE.serverActionTimes = history
        return history
    end

    local cutoff = nowMs - windowMs
    while history[1] and history[1] <= cutoff do
        table.remove(history, 1)
    end

    return history
end

local function RecordServerAction(nowMs, windowMs)
    local history = PruneServerActionHistory(nowMs, windowMs)
    history[#history + 1] = nowMs
end

local function ComputeServerActionDelayMs(nowMs, windowMs, maxActions)
    if windowMs <= 0 or maxActions <= 0 then
        return 0
    end

    local history = PruneServerActionHistory(nowMs, windowMs)
    if #history < maxActions then
        return 0
    end

    local anchorIndex = #history - maxActions + 1
    local anchorTime = history[anchorIndex] or history[1]
    if not anchorTime then
        return 0
    end

    return zo_max((anchorTime + windowMs) - nowMs, 0)
end

local function IsBatchSceneShowing(self)
    if self and self._msConfig and self._msConfig.isSceneShowing then
        return self._msConfig.isSceneShowing(self) == true
    end

    if self and self.IsSceneShowing then
        return self:IsSceneShowing() == true
    end

    return true
end

local function ResolveSceneExitLabel(self, batchOptions)
    if batchOptions and type(batchOptions.sceneExitLabel) == "string" and batchOptions.sceneExitLabel ~= "" then
        return batchOptions.sceneExitLabel
    end

    if self and self._msConfig and type(self._msConfig.getSceneExitLabel) == "function" then
        local configLabel = self._msConfig.getSceneExitLabel(self)
        if type(configLabel) == "string" and configLabel ~= "" then
            return configLabel
        end
    end

    if GetString and SI_BETTERUI_SCENE_INVENTORY then
        local fallbackLabel = GetString(SI_BETTERUI_SCENE_INVENTORY)
        if type(fallbackLabel) == "string" and fallbackLabel ~= "" then
            return fallbackLabel
        end
    end

    return "Scene"
end

local function BuildSlotKey(bagId, slotIndex)
    return tostring(bagId) .. ":" .. tostring(slotIndex)
end

local function HasItemAtSlot(bagId, slotIndex)
    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
    return (stackCount or 0) > 0
end

local function NormalizeBatchItems(items)
    local normalized = {}
    local seen = {}

    for _, itemData in ipairs(items) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex

        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local slotKey = BuildSlotKey(bagId, slotIndex)
            if not seen[slotKey] then
                seen[slotKey] = true
                normalized[#normalized + 1] = itemData
            end
        end
    end

    return normalized
end

local function EstimateBatchDurationSeconds(totalItems, delayMs, cooldownEvery, cooldownMs, totalCostUnits, chunkCostUnits, chunkPauseMs, initialDelayMs)
    local itemCount = zo_max(totalItems, 0)
    local estimateMs = itemCount * zo_max(delayMs or 0, 0)
    local cooldownUnits = zo_max(totalCostUnits or itemCount, 0)
    if itemCount > 1 and cooldownEvery and cooldownEvery > 0 and cooldownMs and cooldownMs > 0 then
        local cooldownCount = zo_floor(zo_max(cooldownUnits - 1, 0) / cooldownEvery)
        estimateMs = estimateMs + (cooldownCount * cooldownMs)
    end
    if itemCount > 1 and chunkCostUnits and chunkCostUnits > 0 and chunkPauseMs and chunkPauseMs > 0 then
        local chunkCount = zo_floor(zo_max(cooldownUnits - 1, 0) / chunkCostUnits)
        estimateMs = estimateMs + (chunkCount * chunkPauseMs)
    end
    estimateMs = estimateMs + zo_max(initialDelayMs or 0, 0)
    return estimateMs / 1000
end

local function FormatEstimatedBatchDuration(estimatedSeconds)
    local roundedSeconds = zo_max(1, zo_ceil(estimatedSeconds or 0))
    if roundedSeconds < 60 then
        return zo_strformat(GetString(SI_BETTERUI_BATCH_DURATION_SECONDS), roundedSeconds)
    end

    local minutes = zo_floor(roundedSeconds / 60)
    local seconds = roundedSeconds - (minutes * 60)
    return zo_strformat(GetString(SI_BETTERUI_BATCH_DURATION_MINUTES_SECONDS), minutes, seconds)
end

local BATCH_ANNOUNCE_BG_HORIZONTAL_PADDING = 260
local BATCH_ANNOUNCE_BG_VERTICAL_PADDING = 40
local BATCH_ANNOUNCE_BG_MIN_WIDTH = 560
local BATCH_ANNOUNCE_BG_MIN_HEIGHT = 116
local BATCH_ANNOUNCE_BG_SCREEN_MARGIN = 60
local BATCH_ANNOUNCE_BG_BASE_TEXTURE = "EsoUI/Art/Windows/Gamepad/panelBG_focus_512.dds"
local BATCH_ANNOUNCE_BG_BASE_ALPHA = 0.62
local BATCH_ANNOUNCE_BG_FRAME_CENTER_TEXTURE = "EsoUI/Art/Tooltips/Gamepad/gp_toolTip_center_16.dds"
local BATCH_ANNOUNCE_BG_FRAME_EDGE_TEXTURE = "EsoUI/Art/Tooltips/Gamepad/gp_toolTip_edge_16.dds"
local BATCH_ANNOUNCE_BG_FRAME_EDGE_WIDTH = 128
local BATCH_ANNOUNCE_BG_FRAME_EDGE_HEIGHT = 16
local BATCH_ANNOUNCE_BG_FRAME_INSET = 10
local BATCH_ANNOUNCE_BG_FRAME_CENTER_ALPHA = 0.30
local BATCH_ANNOUNCE_BG_FRAME_EDGE_ALPHA = 0.90
local BATCH_ANNOUNCE_BG_CALLOUT_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/gp_edgeFill.dds"
local BATCH_ANNOUNCE_BG_CALLOUT_HORIZONTAL_INSET = 14
local BATCH_ANNOUNCE_BG_CALLOUT_VERTICAL_INSET = 14
local BATCH_ANNOUNCE_BG_CALLOUT_VERTICAL_SHIFT = -2
local BATCH_ANNOUNCE_BG_CALLOUT_COLOR_R = 0.12
local BATCH_ANNOUNCE_BG_CALLOUT_COLOR_G = 0.12
local BATCH_ANNOUNCE_BG_CALLOUT_COLOR_B = 0.12
local BATCH_ANNOUNCE_BG_CALLOUT_ALPHA = 0.96
local BATCH_ANNOUNCE_TEXT_COLOR_HEX = "C4A54D"
local BATCH_ANNOUNCE_SECONDARY_LINE_SPACING = 12
local BATCH_DYNAMIC_LAYOUT_REFRESH_MS = 250
local BATCH_STATUS_OVERLAY_NAME = "BETTERUI_CIM_BatchStatusOverlay"
local BATCH_STATUS_OVERLAY_VERTICAL_OFFSET = -185
local BATCH_STATUS_OVERLAY_MAIN_FONT = "ZoFontCenterScreenAnnounceLarge"
local BATCH_STATUS_OVERLAY_SECONDARY_FONT = "ZoFontCenterScreenAnnounceSmall"
local BATCH_STATUS_OVERLAY_MAIN_FALLBACK_HEIGHT = 56
local BATCH_STATUS_OVERLAY_SECONDARY_FALLBACK_HEIGHT = 34
local BATCH_STATUS_OVERLAY_TWO_LINE_EXTRA_PADDING = 12
local BATCH_STATUS_OVERLAY_TWO_LINE_TOP_OFFSET = BATCH_ANNOUNCE_BG_VERTICAL_PADDING - 2
local BATCH_STATUS_OVERLAY_MIN_TWO_LINE_HEIGHT = (BATCH_ANNOUNCE_BG_VERTICAL_PADDING * 2)
    + BATCH_STATUS_OVERLAY_MAIN_FALLBACK_HEIGHT
    + BATCH_ANNOUNCE_SECONDARY_LINE_SPACING
    + BATCH_STATUS_OVERLAY_SECONDARY_FALLBACK_HEIGHT
    + BATCH_STATUS_OVERLAY_TWO_LINE_EXTRA_PADDING
local BATCH_STATUS_DIALOG_CLOSE_POLL_MS = 25
local BATCH_STATUS_DIALOG_CLOSE_MAX_WAIT_MS = 1800
local BATCH_STATUS_DIALOG_SETTLE_MS = 160
local BATCH_ACTION_DIALOG_NAMES = {
    "BETTERUI_BATCH_ACTIONS_DIALOG",
    "BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG",
    "BETTERUI_BANKING_BATCH_ACTIONS_DIALOG",
}

local BATCH_STATUS_OVERLAY = {
    control = nil,
    background = nil,
    calloutBand = nil,
    frame = nil,
    mainLabel = nil,
    secondaryLabel = nil,
    updateToken = 0,
    hideToken = 0,
    lockedWidth = nil,
    lockedHeight = nil,
}

local function IsAnyBatchActionDialogShowing()
    if ZO_Dialogs_IsShowing then
        for i = 1, #BATCH_ACTION_DIALOG_NAMES do
            if ZO_Dialogs_IsShowing(BATCH_ACTION_DIALOG_NAMES[i]) then
                return true
            end
        end
    end

    -- During gamepad hide transitions the dialog can still be on-screen while
    -- no longer being reported as actively "showing" by name.
    if GetControl then
        local gamepadDialog = GetControl("ZO_DialogGamepad1")
        if gamepadDialog and gamepadDialog.IsHidden and not gamepadDialog:IsHidden() then
            -- Any visible gamepad dialog should block batch overlay startup.
            -- Batch actions are launched from a gamepad dialog, so this avoids
            -- one-frame overlaps caused by name/state transition timing.
            return true
        end
    end

    return false
end

local function EnsureBatchAnnouncementFrame(backgroundContainer)
    if not backgroundContainer then
        return nil
    end

    if backgroundContainer._betteruiBatchAnnounceFrame then
        return backgroundContainer._betteruiBatchAnnounceFrame
    end

    if not WINDOW_MANAGER then
        return nil
    end

    if not CT_BACKDROP then
        return nil
    end

    local frame = WINDOW_MANAGER:CreateControl(nil, backgroundContainer, CT_BACKDROP)
    if not frame then
        return nil
    end

    frame:SetCenterTexture(BATCH_ANNOUNCE_BG_FRAME_CENTER_TEXTURE)
    frame:SetEdgeTexture(
        BATCH_ANNOUNCE_BG_FRAME_EDGE_TEXTURE,
        BATCH_ANNOUNCE_BG_FRAME_EDGE_WIDTH,
        BATCH_ANNOUNCE_BG_FRAME_EDGE_HEIGHT
    )
    frame:SetInsets(
        BATCH_ANNOUNCE_BG_FRAME_INSET,
        BATCH_ANNOUNCE_BG_FRAME_INSET,
        -BATCH_ANNOUNCE_BG_FRAME_INSET,
        -BATCH_ANNOUNCE_BG_FRAME_INSET
    )

    if frame.SetDrawLayer then
        frame:SetDrawLayer(DL_OVERLAY)
    end

    backgroundContainer._betteruiBatchAnnounceFrame = frame
    return frame
end

local function EnsureBatchAnnouncementCalloutBand(backgroundContainer)
    if not backgroundContainer then
        return nil
    end

    if backgroundContainer._betteruiBatchAnnounceCalloutBand then
        return backgroundContainer._betteruiBatchAnnounceCalloutBand
    end

    if not WINDOW_MANAGER then
        return nil
    end

    local calloutBand = WINDOW_MANAGER:CreateControl(nil, backgroundContainer, CT_CONTROL)
    if not calloutBand then
        return nil
    end

    local fillTexture = WINDOW_MANAGER:CreateControl(nil, calloutBand, CT_TEXTURE)
    if not fillTexture then
        return nil
    end

    fillTexture:SetTexture(BATCH_ANNOUNCE_BG_CALLOUT_TEXTURE)
    fillTexture:ClearAnchors()
    fillTexture:SetAnchorFill(calloutBand)

    if calloutBand.SetDrawLayer then
        calloutBand:SetDrawLayer(DL_OVERLAY)
    end

    calloutBand._betteruiFillTexture = fillTexture
    backgroundContainer._betteruiBatchAnnounceCalloutBand = calloutBand
    return calloutBand
end

local function GetAnnouncementLabelBounds(label, minimumWidth)
    if not label then
        return 0, 0
    end

    local textWidth = label:GetTextWidth() or 0
    if textWidth <= 0 then
        local text = (label.GetText and label:GetText()) or ""
        local charCount = zo_strlen(text)
        textWidth = zo_max(charCount * 26, minimumWidth or 0)
    end

    local textHeight = label:GetTextHeight() or 0
    if textHeight <= 0 then
        textHeight = label:GetHeight() or 0
    end

    return textWidth, textHeight
end

local function ResolveBatchStatusTextValue(value)
    if type(value) == "function" then
        local ok, resolved = pcall(value)
        if not ok or resolved == nil then
            return ""
        end
        return tostring(resolved)
    end

    if value == nil then
        return ""
    end

    return tostring(value)
end

local function ResolveBatchAbortBindingMarkup()
    if not ZO_Keybindings_GetHighestPriorityBindingStringFromAction then
        return "Y"
    end

    local bindingMarkup = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
        "UI_SHORTCUT_TERTIARY",
        KEYBIND_TEXT_OPTIONS_FULL_NAME,
        KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP
    )
    if bindingMarkup and bindingMarkup ~= "" then
        return bindingMarkup
    end

    local fallbackBinding = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(
        "UI_SHORTCUT_TERTIARY",
        KEYBIND_TEXT_OPTIONS_FULL_NAME,
        KEYBIND_TEXTURE_OPTIONS_NONE
    )
    if fallbackBinding and fallbackBinding ~= "" then
        return fallbackBinding
    end

    return "Y"
end

local function EnsureBatchStatusOverlay()
    local overlay = BATCH_STATUS_OVERLAY
    if overlay.control then
        return overlay
    end

    if not (WINDOW_MANAGER and GuiRoot and CT_CONTROL and CT_TEXTURE and CT_LABEL) then
        return nil
    end

    local control = WINDOW_MANAGER:CreateTopLevelWindow(BATCH_STATUS_OVERLAY_NAME)
    if not control then
        return nil
    end

    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawTier(DT_HIGH)
    control:SetMouseEnabled(false)
    control:SetMovable(false)
    control:SetClampedToScreen(true)
    if control.SetClipsChildren then
        control:SetClipsChildren(true)
    end
    control:SetHidden(true)
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, 0, BATCH_STATUS_OVERLAY_VERTICAL_OFFSET)

    local background = WINDOW_MANAGER:CreateControl(BATCH_STATUS_OVERLAY_NAME .. "BG", control, CT_TEXTURE)
    background:ClearAnchors()
    background:SetAnchorFill(control)
    background:SetTexture(BATCH_ANNOUNCE_BG_BASE_TEXTURE)
    background:SetColor(1, 1, 1, BATCH_ANNOUNCE_BG_BASE_ALPHA)

    local mainLabel = WINDOW_MANAGER:CreateControl(BATCH_STATUS_OVERLAY_NAME .. "MainText", control, CT_LABEL)
    mainLabel:SetFont(BATCH_STATUS_OVERLAY_MAIN_FONT)
    mainLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    mainLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    mainLabel:SetColor(1, 1, 1, 1)

    local secondaryLabel = WINDOW_MANAGER:CreateControl(BATCH_STATUS_OVERLAY_NAME .. "SecondaryText", control, CT_LABEL)
    secondaryLabel:SetFont(BATCH_STATUS_OVERLAY_SECONDARY_FONT)
    secondaryLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    secondaryLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    secondaryLabel:SetColor(1, 1, 1, 1)
    secondaryLabel:SetHidden(true)

    overlay.control = control
    overlay.background = background
    overlay.mainLabel = mainLabel
    overlay.secondaryLabel = secondaryLabel
    overlay.calloutBand = EnsureBatchAnnouncementCalloutBand(control)
    overlay.frame = EnsureBatchAnnouncementFrame(control)
    return overlay
end

local function ApplyBatchStatusOverlayLayout(overlay, hasSecondaryText)
    if not (overlay and overlay.control and overlay.mainLabel) then
        return
    end

    local control = overlay.control
    local background = overlay.background
    local mainLabel = overlay.mainLabel
    local secondaryLabel = overlay.secondaryLabel

    local guiWidth = (GuiRoot and GuiRoot:GetWidth()) or 1920
    local maxWidth = zo_max(guiWidth - (BATCH_ANNOUNCE_BG_SCREEN_MARGIN * 2), BATCH_ANNOUNCE_BG_MIN_WIDTH)
    local innerMaxWidth = zo_max(maxWidth - BATCH_ANNOUNCE_BG_HORIZONTAL_PADDING, 0)
    mainLabel:SetWidth(innerMaxWidth)
    if secondaryLabel then
        secondaryLabel:SetWidth(innerMaxWidth)
    end

    local mainWidth, mainHeight = GetAnnouncementLabelBounds(mainLabel, 0)
    local secondaryWidth = 0
    local secondaryHeight = 0
    if hasSecondaryText and secondaryLabel then
        secondaryWidth, secondaryHeight = GetAnnouncementLabelBounds(secondaryLabel, 0)
    end
    if mainHeight <= 0 then
        mainHeight = BATCH_STATUS_OVERLAY_MAIN_FALLBACK_HEIGHT
    end
    if hasSecondaryText then
        secondaryHeight = zo_max(secondaryHeight, BATCH_STATUS_OVERLAY_SECONDARY_FALLBACK_HEIGHT)
    end

    local textWidth = zo_max(mainWidth, secondaryWidth)
    local width = zo_clamp(textWidth + BATCH_ANNOUNCE_BG_HORIZONTAL_PADDING, BATCH_ANNOUNCE_BG_MIN_WIDTH, maxWidth)
    local innerWidth = zo_max(width - BATCH_ANNOUNCE_BG_HORIZONTAL_PADDING, 0)

    mainLabel:SetWidth(innerWidth)
    if secondaryLabel then
        secondaryLabel:SetWidth(innerWidth)
    end

    mainLabel:SetHeight(mainHeight)
    local secondarySpacing = 0
    if secondaryHeight > 0 then
        secondarySpacing = BATCH_ANNOUNCE_SECONDARY_LINE_SPACING
    end
    local textHeight = mainHeight + secondaryHeight + secondarySpacing

    local minHeight = BATCH_ANNOUNCE_BG_MIN_HEIGHT
    if hasSecondaryText then
        minHeight = zo_max(minHeight, BATCH_STATUS_OVERLAY_MIN_TWO_LINE_HEIGHT)
    end
    local height = zo_max(textHeight + (BATCH_ANNOUNCE_BG_VERTICAL_PADDING * 2), minHeight)

    -- Keep a stable footprint while visible to avoid noticeable start->processing box jumps.
    if control.IsHidden and control:IsHidden() then
        overlay.lockedWidth = nil
        overlay.lockedHeight = nil
    end
    overlay.lockedWidth = zo_max(overlay.lockedWidth or 0, width)
    overlay.lockedHeight = zo_max(overlay.lockedHeight or 0, height)
    width = overlay.lockedWidth
    height = overlay.lockedHeight

    innerWidth = zo_max(width - BATCH_ANNOUNCE_BG_HORIZONTAL_PADDING, 0)
    mainLabel:SetWidth(innerWidth)
    if secondaryLabel then
        secondaryLabel:SetWidth(innerWidth)
    end

    control:SetDimensions(width, height)

    if background then
        background:ClearAnchors()
        background:SetAnchorFill(control)
        background:SetTexture(BATCH_ANNOUNCE_BG_BASE_TEXTURE)
        background:SetColor(1, 1, 1, BATCH_ANNOUNCE_BG_BASE_ALPHA)
    end

    mainLabel:ClearAnchors()
    if hasSecondaryText and secondaryLabel then
        mainLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
        mainLabel:SetAnchor(TOP, control, TOP, 0, BATCH_STATUS_OVERLAY_TWO_LINE_TOP_OFFSET)
    else
        mainLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        mainLabel:SetAnchor(CENTER, control, CENTER, 0, 0)
    end

    if hasSecondaryText and secondaryLabel then
        secondaryLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
        secondaryLabel:SetHeight(secondaryHeight)
        secondaryLabel:ClearAnchors()
        secondaryLabel:SetAnchor(TOP, mainLabel, BOTTOM, 0, BATCH_ANNOUNCE_SECONDARY_LINE_SPACING)
    elseif secondaryLabel then
        secondaryLabel:SetHeight(0)
        secondaryLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end

    local calloutBand = overlay.calloutBand
    if calloutBand then
        calloutBand:ClearAnchors()
        calloutBand:SetAnchor(
            TOPLEFT,
            control,
            TOPLEFT,
            BATCH_ANNOUNCE_BG_CALLOUT_HORIZONTAL_INSET,
            BATCH_ANNOUNCE_BG_CALLOUT_VERTICAL_INSET + BATCH_ANNOUNCE_BG_CALLOUT_VERTICAL_SHIFT
        )
        calloutBand:SetAnchor(
            BOTTOMRIGHT,
            control,
            BOTTOMRIGHT,
            -BATCH_ANNOUNCE_BG_CALLOUT_HORIZONTAL_INSET,
            -BATCH_ANNOUNCE_BG_CALLOUT_VERTICAL_INSET + BATCH_ANNOUNCE_BG_CALLOUT_VERTICAL_SHIFT
        )
        calloutBand._betteruiFillTexture:SetColor(
            BATCH_ANNOUNCE_BG_CALLOUT_COLOR_R,
            BATCH_ANNOUNCE_BG_CALLOUT_COLOR_G,
            BATCH_ANNOUNCE_BG_CALLOUT_COLOR_B,
            BATCH_ANNOUNCE_BG_CALLOUT_ALPHA
        )
        calloutBand:SetHidden(false)
    end

    local frame = overlay.frame
    if frame then
        frame:ClearAnchors()
        frame:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        frame:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
        frame:SetCenterColor(1, 1, 1, BATCH_ANNOUNCE_BG_FRAME_CENTER_ALPHA)
        frame:SetEdgeColor(1, 1, 1, BATCH_ANNOUNCE_BG_FRAME_EDGE_ALPHA)
        frame:SetHidden(false)
    end
end

local function ShowBatchStatusOverlay(displayName, bodyText, secondaryText)
    local overlay = EnsureBatchStatusOverlay()
    if not overlay then
        return
    end

    overlay.hideToken = overlay.hideToken + 1
    overlay.updateToken = overlay.updateToken + 1
    local updateToken = overlay.updateToken
    local suppressRetryCount = 8

    local hasDynamicText = type(bodyText) == "function" or type(secondaryText) == "function"
    local expectsSecondary = secondaryText ~= nil and secondaryText ~= ""
    if type(secondaryText) == "function" then
        expectsSecondary = true
    end
    local lastResolvedSecondaryText = ""
    local firstRenderPending = true

    local function UpdateOverlayText()
        if overlay.updateToken ~= updateToken then
            return
        end

        if IsAnyBatchActionDialogShowing() then
            overlay.control:SetHidden(true)
            firstRenderPending = true
            if hasDynamicText or suppressRetryCount > 0 then
                suppressRetryCount = zo_max(suppressRetryCount - 1, 0)
                zo_callLater(UpdateOverlayText, BATCH_DYNAMIC_LAYOUT_REFRESH_MS)
            end
            return
        end

        local resolvedBodyText = ResolveBatchStatusTextValue(bodyText)
        local resolvedSecondaryText = ResolveBatchStatusTextValue(secondaryText)
        if expectsSecondary then
            if resolvedSecondaryText == "" then
                resolvedSecondaryText = (lastResolvedSecondaryText ~= "" and lastResolvedSecondaryText) or " "
            else
                lastResolvedSecondaryText = resolvedSecondaryText
            end
        end

        if firstRenderPending then
            overlay.control:SetHidden(true)
        end

        local mainText = zo_strformat("<<1>>: <<2>>", displayName or "", resolvedBodyText)
        overlay.mainLabel:SetText(string.format("|c%s%s|r", BATCH_ANNOUNCE_TEXT_COLOR_HEX, mainText))

        local hasSecondary = expectsSecondary or resolvedSecondaryText ~= ""
        overlay.mainLabel:SetHidden(true)
        overlay.secondaryLabel:SetHidden(true)

        if hasSecondary then
            overlay.secondaryLabel:SetText(string.format("|c%s%s|r", BATCH_ANNOUNCE_TEXT_COLOR_HEX, resolvedSecondaryText))
        else
            overlay.secondaryLabel:SetText("")
        end

        ApplyBatchStatusOverlayLayout(overlay, hasSecondary)
        if hasSecondary then
            overlay.secondaryLabel:SetHidden(false)
        else
            overlay.secondaryLabel:SetHidden(true)
        end
        overlay.mainLabel:SetHidden(false)
        overlay.control:SetHidden(false)
        firstRenderPending = false

        if hasDynamicText then
            zo_callLater(UpdateOverlayText, BATCH_DYNAMIC_LAYOUT_REFRESH_MS)
        end
    end

    UpdateOverlayText()
end

local function HideBatchStatusOverlay(delayMs)
    local overlay = BATCH_STATUS_OVERLAY
    if not overlay.control then
        return
    end

    overlay.updateToken = overlay.updateToken + 1
    overlay.hideToken = overlay.hideToken + 1
    local hideToken = overlay.hideToken
    local delay = zo_max(0, tonumber(delayMs) or 0)

    local function HideNow()
        if overlay.hideToken ~= hideToken then
            return
        end
        overlay.lockedWidth = nil
        overlay.lockedHeight = nil
        overlay.control:SetHidden(true)
    end

    if delay > 0 then
        zo_callLater(HideNow, delay)
    else
        HideNow()
    end
end

-------------------------------------------------------------------------------------------------
-- MIXIN APPLICATION
-------------------------------------------------------------------------------------------------

--- Applies the multi-select mixin to a module class instance.
--- The config table provides module-specific hooks so the shared logic
--- can interact with each module's list, keybinds, and refresh mechanisms.
--- @param target table The module class instance (e.g., Banking or Inventory instance)
--- @param config table Module-specific callbacks:
---   getList(self)          -> returns the active parametric scroll list
---   refreshList(self)      -> refreshes the list (visuals + data)
---   refreshKeybinds(self)  -> refreshes keybind strip visibility/labels
---   isSceneShowing(self)   -> optional scene visibility check for auto-abort on scene exit
---   getSceneExitLabel(self)-> optional scene label used in scene-exit abort messaging
function Mixin.Apply(target, config)
    target._msConfig = config
end

-------------------------------------------------------------------------------------------------
-- SELECTION MODE LIFECYCLE
-------------------------------------------------------------------------------------------------

--- Enters multi-selection mode.
--- Sets state, notifies manager, auto-selects the currently focused item,
--- and refreshes visuals.
function Mixin.EnterSelectionMode(self)
    if self.isInSelectionMode then return end
    if not self.multiSelectManager then return end

    self.isInSelectionMode = true
    self.multiSelectManager:EnterSelectionMode()

    -- Auto-select the currently focused item
    local list = self._msConfig.getList(self)
    local target = nil
    if list then
        if list.GetSelectedData then
            target = list:GetSelectedData()
        else
            target = list.selectedData
        end
    end
    if target then
        self.multiSelectManager:ToggleSelection(target)
    end

    -- Update visuals
    self._msConfig.refreshKeybinds(self)
    self._msConfig.refreshList(self)
end

--- Exits multi-selection mode.
--- Clears state, notifies manager, and refreshes visuals.
function Mixin.ExitSelectionMode(self)
    if self.isBatchProcessing then
        Mixin.RequestBatchAbort(self)
        return
    end

    if not self.isInSelectionMode then return end

    self.isInSelectionMode = false
    self.hadSelections = nil
    self.selectedCount = 0
    if self.multiSelectManager then
        self.multiSelectManager:ExitSelectionMode()
    end

    if IsBatchSceneShowing(self) then
        -- Update visuals only while the owning scene is active.
        self._msConfig.refreshKeybinds(self)
        self._msConfig.refreshList(self)
    end
end

--- Called when the selection count changes.
--- Tracks hadSelections for auto-exit logic: when the user deselects the
--- last item (count reaches 0 after having selected at least one), the
--- mode exits automatically. The hadSelections guard prevents exiting on
--- initial entry when MultiSelectManager fires callback(0) before the
--- first ToggleSelection.
--- @param selectedCount number The number of currently selected items
function Mixin.OnSelectionCountChanged(self, selectedCount)
    if self.isInSelectionMode and selectedCount > 0 then
        self.selectedCount = selectedCount
        self.hadSelections = true
    else
        self.selectedCount = 0
    end

    -- Auto-exit when last item is deselected
    if self.isInSelectionMode and selectedCount == 0 and self.hadSelections then
        self.hadSelections = nil
        self:ExitSelectionMode()
        return
    end

    -- Refresh keybinds to update Y-button batch actions visibility
    if IsBatchSceneShowing(self) then
        self._msConfig.refreshKeybinds(self)
    end
end

--- Gets whether selection mode is currently active.
--- @return boolean isActive
function Mixin.IsInSelectionMode(self)
    return self.isInSelectionMode or false
end

--- Checks if batch processing is currently in progress.
--- Used by refresh functions to skip updates during batch operations.
--- @return boolean True if batch processing is active
function Mixin.IsBatchProcessing(self)
    return self.isBatchProcessing == true
end

--- Gets whether a batch can still be aborted.
--- @return boolean canAbort
function Mixin.CanAbortBatch(self)
    return self.isBatchProcessing == true and self.batchAbortRequested ~= true
end

--- Requests abort for an in-flight batch operation.
--- The currently executing item (if any) is allowed to complete, then processing stops.
--- @return boolean requested True when abort was accepted
function Mixin.RequestBatchAbort(self)
    if not Mixin.CanAbortBatch(self) then
        return false
    end

    self.batchAbortRequested = true
    if type(self._msBatchWakeHandler) == "function" then
        self._msBatchWakeHandler()
    end

    if IsBatchSceneShowing(self) and self._msConfig and self._msConfig.refreshKeybinds then
        self._msConfig.refreshKeybinds(self)
    end

    return true
end

-------------------------------------------------------------------------------------------------
-- THROTTLED BATCH PROCESSING
-------------------------------------------------------------------------------------------------

--- Processes items with staggered delays to prevent rate-limiting.
--- Suppresses list/keybind refreshes during processing to prevent flickering.
--- @param items table Array of items to process
--- @param actionFn fun(bagId: number, slotIndex: number, itemData: table): boolean|string? Per-item function return:
---   false => stop with "bagFull" (or generic capacity stop)
---   "queued" => operation was submitted to server; enable stricter pacing gates
---   "reason" => stop with that reason
---   true/nil => continue
--- @param onComplete fun()? Optional callback when all items processed
--- @param actionName string? Name of the action for progress notifications
--- @param batchOptions table? Optional controls:
---   serverBound (boolean): apply server pacing/backpressure controls
---   suppressUiUpdates (boolean): expose `self.batchSuppressUiUpdates` for module callbacks
---   sceneExitLabel (string): explicit label used when scene-exit abort happens
---   costPerItem (number): cooldown/chunk cost units consumed per processed item
---   cooldownEvery (number): override cooldown cadence units
---   cooldownMs (number): override cooldown pause duration
---   minServerDelayMs (number): minimum base delay between server-bound item actions
---   maxServerDelayMs (number): maximum adaptive base delay between server-bound item actions
---   awaitInventoryAck (boolean): wait for SHARED_INVENTORY update callback (or timeout) for queued actions
---   ackTimeoutMs (number): fallback wait time when an ack callback does not arrive
---   chunkCostUnits (number): add chunk pause when accumulated cost crosses this boundary
---   chunkPauseMs (number): pause added each time a chunk boundary is crossed
---   adaptiveDelay (boolean): increase delay for sustained queued server calls
---   adaptiveThreshold (number): queued streak before adaptive delay starts increasing
---   adaptiveStepMs (number): per-item delay increase after threshold
---   jitterMs (number): random +/- jitter applied to base server delay
---   skipInterBatchCooldown (boolean): bypass shared cooldown carried from recent heavy batches
---   postBatchCooldownBaseMs (number): base cooldown applied after a server-bound batch
---   postBatchCooldownThreshold (number): cost threshold before extra post-batch cooldown applies
---   postBatchCooldownPerCostMs (number): extra cooldown per cost unit over threshold
---   postBatchCooldownMaxMs (number): cap for computed post-batch cooldown
---   enforceRateWindow (boolean): enable rolling cap for server-bound actions
---   rateLimitWindowMs (number): rolling time window size for action cap
---   rateLimitMaxActions (number): max queued server actions allowed in rolling window
---   countTowardRateOnSuccess (boolean): when true, any successful server-bound item counts toward rolling cap
function Mixin.ProcessBatchThrottled(self, items, actionFn, onComplete, actionName, batchOptions)
    items = NormalizeBatchItems(items or {})
    local totalItems = #items
    if totalItems == 0 then
        if onComplete then onComplete() end
        return
    end
    if self.isBatchProcessing then
        return
    end

    local index = 0
    local processedCount = 0
    local processedCost = 0
    local stopReason = nil
    local throttleProfile = ResolveBatchThrottleProfile(totalItems)
    local batchDelayMs = throttleProfile.DELAY_MS or 75
    local showProgress = throttleProfile.SHOW_PROGRESS == true
    local showEta = totalItems >= BATCH_ETA_THRESHOLD
    local options = batchOptions or {}
    local isServerBound = options.serverBound == true
    if isServerBound then
        showProgress = true
    end
    local suppressUiUpdates = options.suppressUiUpdates == true
    local sceneExitLabel = ResolveSceneExitLabel(self, options)
    local requestedCost = tonumber(options.costPerItem)
    local actionCost = DEFAULT_ACTION_COST_UNITS
    if requestedCost and requestedCost > 0 then
        actionCost = zo_max(DEFAULT_ACTION_COST_UNITS, zo_ceil(requestedCost))
    end
    local totalCostUnits = totalItems * actionCost
    local cooldownEvery = 0
    local cooldownMs = 0
    local minServerDelayMs = 0
    local maxServerDelayMs = 0
    local awaitInventoryAck = false
    local ackTimeoutMs = 0
    local chunkCostUnits = 0
    local chunkPauseMs = 0
    local adaptiveDelay = false
    local adaptiveThreshold = 0
    local adaptiveStepMs = 0
    local jitterMs = 0
    local skipInterBatchCooldown = false
    local postBatchCooldownBaseMs = 0
    local postBatchCooldownThreshold = 0
    local postBatchCooldownPerCostMs = 0
    local postBatchCooldownMaxMs = 0
    local enforceRateWindow = false
    local rateLimitWindowMs = 0
    local rateLimitMaxActions = 0
    local countTowardRateOnSuccess = false
    local startupDelayMs = 0
    local nextCooldownAt = nil
    local nextChunkAt = nil

    if isServerBound then
        cooldownEvery = ResolvePositiveIntOption(options.cooldownEvery, SERVER_COOLDOWN_EVERY)
        cooldownMs = ResolvePositiveIntOption(options.cooldownMs, SERVER_COOLDOWN_MS)
        minServerDelayMs = ResolvePositiveIntOption(options.minServerDelayMs, SERVER_MIN_DELAY_MS)
        maxServerDelayMs = ResolvePositiveIntOption(options.maxServerDelayMs, SERVER_MAX_DELAY_MS)
        maxServerDelayMs = zo_max(maxServerDelayMs, minServerDelayMs)
        awaitInventoryAck = ResolveBooleanOption(options.awaitInventoryAck, SERVER_AWAIT_INVENTORY_ACK)
        ackTimeoutMs = ResolvePositiveIntOption(options.ackTimeoutMs, SERVER_ACK_TIMEOUT_MS)
        chunkCostUnits = ResolvePositiveIntOption(options.chunkCostUnits, SERVER_CHUNK_COST_UNITS)
        chunkPauseMs = ResolvePositiveIntOption(options.chunkPauseMs, SERVER_CHUNK_PAUSE_MS)
        adaptiveDelay = ResolveBooleanOption(options.adaptiveDelay, SERVER_ADAPTIVE_DELAY)
        adaptiveThreshold = ResolvePositiveIntOption(options.adaptiveThreshold, SERVER_ADAPTIVE_THRESHOLD)
        adaptiveStepMs = ResolvePositiveIntOption(options.adaptiveStepMs, SERVER_ADAPTIVE_STEP_MS)
        jitterMs = ResolvePositiveIntOption(options.jitterMs, SERVER_JITTER_MS)
        skipInterBatchCooldown = ResolveBooleanOption(options.skipInterBatchCooldown, false)
        postBatchCooldownBaseMs = ResolvePositiveIntOption(
            options.postBatchCooldownBaseMs,
            SERVER_POST_BATCH_COOLDOWN_BASE_MS
        )
        postBatchCooldownThreshold = ResolvePositiveIntOption(
            options.postBatchCooldownThreshold,
            SERVER_POST_BATCH_COOLDOWN_THRESHOLD
        )
        postBatchCooldownPerCostMs = ResolvePositiveIntOption(
            options.postBatchCooldownPerCostMs,
            SERVER_POST_BATCH_COOLDOWN_PER_COST_MS
        )
        postBatchCooldownMaxMs = ResolvePositiveIntOption(
            options.postBatchCooldownMaxMs,
            SERVER_POST_BATCH_COOLDOWN_MAX_MS
        )
        enforceRateWindow = ResolveBooleanOption(options.enforceRateWindow, true)
        rateLimitWindowMs = ResolvePositiveIntOption(options.rateLimitWindowMs, SERVER_RATE_WINDOW_MS)
        rateLimitMaxActions = ResolvePositiveIntOption(options.rateLimitMaxActions, SERVER_RATE_MAX_ACTIONS)
        countTowardRateOnSuccess = ResolveBooleanOption(options.countTowardRateOnSuccess, true)

        if not SHARED_INVENTORY then
            awaitInventoryAck = false
        end

        if cooldownEvery > 0 then
            nextCooldownAt = cooldownEvery
        end
        if chunkCostUnits > 0 then
            nextChunkAt = chunkCostUnits
        end

        if not skipInterBatchCooldown then
            startupDelayMs = zo_max((SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs or 0) - GetNowMs(), 0)
        end

        if enforceRateWindow and rateLimitWindowMs > 0 and rateLimitMaxActions > 0 then
            startupDelayMs = zo_max(
                startupDelayMs,
                ComputeServerActionDelayMs(GetNowMs(), rateLimitWindowMs, rateLimitMaxActions)
            )
        else
            enforceRateWindow = false
        end
    end

    local effectiveDelayMs = zo_max(0, batchDelayMs)
    local self_ref = self
    local announceAfterCooldown = false
    local consecutiveQueuedActions = 0
    local waitToken = 0
    local processNext
    local stillProcessingAnnouncementActive = false
    local stillProcessingWaitUntilMs = 0
    local awaitingInventoryAckForAction = false
    local ackReceivedForAction = false
    local waitingForInventoryAck = false
    local expectedAckBagId = nil
    local expectedAckSlotIndex = nil
    local inventoryAckCallbacksRegistered = false
    local inventoryAckSingleSlotCallback = nil
    local inventoryAckFullCallback = nil

    local function StopStillProcessingLayoutPulse()
        local overlay = BATCH_STATUS_OVERLAY
        overlay.updateToken = overlay.updateToken + 1
    end

    local function ClearQueuedStillProcessingAnnouncements()
        stillProcessingAnnouncementActive = false
        StopStillProcessingLayoutPulse()
    end

    local function ClearPendingContinuation()
        waitToken = waitToken + 1
        self_ref._msBatchWakeHandler = nil
    end

    local function ResetInventoryAckState()
        awaitingInventoryAckForAction = false
        ackReceivedForAction = false
        waitingForInventoryAck = false
        expectedAckBagId = nil
        expectedAckSlotIndex = nil
    end

    local function UnregisterInventoryAckCallbacks()
        if not inventoryAckCallbacksRegistered then
            inventoryAckSingleSlotCallback = nil
            inventoryAckFullCallback = nil
            return
        end

        if SHARED_INVENTORY then
            SHARED_INVENTORY:UnregisterCallback("SingleSlotInventoryUpdate", inventoryAckSingleSlotCallback)
            SHARED_INVENTORY:UnregisterCallback("FullInventoryUpdate", inventoryAckFullCallback)
        end

        inventoryAckCallbacksRegistered = false
        inventoryAckSingleSlotCallback = nil
        inventoryAckFullCallback = nil
    end

    local function ScheduleContinuation(delayMs, callback)
        local resumeFn = callback or processNext
        ClearPendingContinuation()
        local token = waitToken

        local function Continue()
            if token ~= waitToken then
                return
            end
            ClearPendingContinuation()
            resumeFn()
        end

        self_ref._msBatchWakeHandler = Continue
        zo_callLater(Continue, zo_max(0, delayMs))
    end

    local function HandleInventoryAck(updatedBagId, updatedSlotIndex)
        if not awaitingInventoryAckForAction then
            return
        end

        if expectedAckBagId ~= nil then
            if updatedBagId ~= nil and updatedBagId ~= expectedAckBagId then
                return
            end

            if updatedBagId ~= nil
                and expectedAckSlotIndex ~= nil
                and updatedSlotIndex ~= nil
                and updatedSlotIndex ~= expectedAckSlotIndex
            then
                return
            end
        end

        ackReceivedForAction = true
        if waitingForInventoryAck and type(self_ref._msBatchWakeHandler) == "function" then
            self_ref._msBatchWakeHandler()
        end
    end

    local function ExtractAckBagAndSlot(...)
        local bagId = nil
        local slotIndex = nil
        local argCount = select("#", ...)

        for i = 1, argCount do
            local value = select(i, ...)
            if type(value) == "number" then
                if bagId == nil then
                    bagId = value
                else
                    slotIndex = value
                    break
                end
            end
        end

        -- Guard against event-code style leading numbers; treat as unknown and fallback to timeout/full update.
        if bagId ~= nil and (bagId < 0 or bagId > 10000) then
            bagId = nil
            slotIndex = nil
        end

        if slotIndex ~= nil and (slotIndex < 0 or slotIndex > 10000) then
            slotIndex = nil
        end

        return bagId, slotIndex
    end

    local function RegisterInventoryAckCallbacks()
        if not awaitInventoryAck or inventoryAckCallbacksRegistered or not SHARED_INVENTORY then
            return
        end

        inventoryAckSingleSlotCallback = function(...)
            local updatedBagId, updatedSlotIndex = ExtractAckBagAndSlot(...)
            HandleInventoryAck(updatedBagId, updatedSlotIndex)
        end
        inventoryAckFullCallback = function()
            HandleInventoryAck(nil, nil)
        end

        SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", inventoryAckSingleSlotCallback)
        SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", inventoryAckFullCallback)
        inventoryAckCallbacksRegistered = true
    end

    -- Defensive cleanup in case any prior still-processing messages remain queued.
    ClearQueuedStillProcessingAnnouncements()
    -- Ensure any lingering completion overlay from a prior batch is removed
    -- before the next processing overlay is rendered.
    HideBatchStatusOverlay()
    RegisterInventoryAckCallbacks()

    -- Set batch processing flag to suppress refreshes
    self.isBatchProcessing = true
    self.batchAbortRequested = false
    self.batchSuppressUiUpdates = suppressUiUpdates and true or nil

    local displayName = actionName or GetString(SI_BETTERUI_BATCH_ACTIONS)

    if self._msConfig and self._msConfig.refreshKeybinds then
        self._msConfig.refreshKeybinds(self)
    end
    local estimatedDurationMs = nil
    local batchStartedAtMs = GetNowMs()
    local countdownPausedTotalMs = 0
    local countdownPauseStartedAtMs = nil
    if showProgress and showEta then
        local estimatedSeconds = EstimateBatchDurationSeconds(
            totalItems,
            effectiveDelayMs,
            cooldownEvery,
            cooldownMs,
            totalCostUnits,
            chunkCostUnits,
            chunkPauseMs,
            startupDelayMs
        )
        estimatedDurationMs = zo_max(1000, zo_ceil((estimatedSeconds or 0) * 1000))
    end

    local function finishBatch()
        ClearPendingContinuation()
        ResetInventoryAckState()
        UnregisterInventoryAckCallbacks()

        -- Clear batch processing flag first so normal keybind labels restore
        self_ref.isBatchProcessing = false

        if IsBatchSceneShowing(self_ref) and self_ref._msConfig and self_ref._msConfig.refreshKeybinds then
            self_ref._msConfig.refreshKeybinds(self_ref)
        end

        -- Remove stale queued/active progress notices so completion/abort text is authoritative.
        ClearQueuedStillProcessingAnnouncements()

        -- Show completion notification
        if showProgress or stopReason then
            local completeText
            if stopReason == "bagFull" then
                completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_BAG_FULL), processedCount, totalItems)
            elseif stopReason == "sceneExit" then
                completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_ABORTED_SCENE_EXIT), sceneExitLabel, processedCount, totalItems)
            elseif stopReason == "aborted" then
                completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_ABORTED_COMPLETE), processedCount, totalItems)
            else
                completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_COMPLETE), totalItems)
            end
            ShowBatchStatusOverlay(displayName, completeText)
            HideBatchStatusOverlay((stopReason and 4000) or 2000)
        else
            HideBatchStatusOverlay()
        end

        if isServerBound and processedCost > 0 then
            local nowMs = GetNowMs()
            local postBatchCooldownMs = 0
            local threshold = zo_max(postBatchCooldownThreshold, 0)
            if threshold == 0 or processedCost >= threshold then
                local extraCostUnits = zo_max(processedCost - threshold, 0)
                postBatchCooldownMs = postBatchCooldownBaseMs + (extraCostUnits * postBatchCooldownPerCostMs)
                postBatchCooldownMs = zo_clamp(postBatchCooldownMs, 0, postBatchCooldownMaxMs)
            end

            if postBatchCooldownMs > 0 then
                SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs =
                    zo_max(SERVER_BATCH_RECOVERY_STATE.cooldownUntilMs or 0, nowMs + postBatchCooldownMs)
            end
        end

        self_ref.batchAbortRequested = nil
        self_ref.batchSuppressUiUpdates = nil
        self_ref._msBatchWakeHandler = nil
        stillProcessingWaitUntilMs = 0
        stillProcessingAnnouncementActive = false
        StopStillProcessingLayoutPulse()

        if onComplete then onComplete(stopReason) end
    end

    local function ResolveStillProcessingWaitMs(nowMs, waitMs)
        local resolvedNowMs = nowMs or GetNowMs()
        if waitMs and waitMs > 0 then
            stillProcessingWaitUntilMs = zo_max(stillProcessingWaitUntilMs, resolvedNowMs + waitMs)
        end

        local remainingWaitMs = zo_max(stillProcessingWaitUntilMs - resolvedNowMs, 0)
        if remainingWaitMs > 0 then
            if countdownPauseStartedAtMs == nil then
                countdownPauseStartedAtMs = resolvedNowMs
            end
        elseif countdownPauseStartedAtMs ~= nil then
            countdownPausedTotalMs = countdownPausedTotalMs + zo_max(resolvedNowMs - countdownPauseStartedAtMs, 0)
            countdownPauseStartedAtMs = nil
        end

        return remainingWaitMs
    end

    local function ComputeRemainingDeterministicPauseMs()
        local remainingPauseMs = 0

        if cooldownMs > 0 and cooldownEvery > 0 and nextCooldownAt and nextCooldownAt <= totalCostUnits then
            local remainingCooldownCount = zo_floor((totalCostUnits - nextCooldownAt) / cooldownEvery) + 1
            remainingPauseMs = remainingPauseMs + zo_max(remainingCooldownCount, 0) * cooldownMs
        end

        if chunkPauseMs > 0 and chunkCostUnits > 0 and nextChunkAt and nextChunkAt <= totalCostUnits then
            local remainingChunkCount = zo_floor((totalCostUnits - nextChunkAt) / chunkCostUnits) + 1
            remainingPauseMs = remainingPauseMs + zo_max(remainingChunkCount, 0) * chunkPauseMs
        end

        return remainingPauseMs
    end

    local function BuildStillProcessingMainText()
        local nowMs = GetNowMs()
        local remainingWaitMs = ResolveStillProcessingWaitMs(nowMs, nil)
        if estimatedDurationMs and estimatedDurationMs > 0 then
            local pausedMs = countdownPausedTotalMs
            if remainingWaitMs > 0 and countdownPauseStartedAtMs ~= nil then
                pausedMs = pausedMs + zo_max(nowMs - countdownPauseStartedAtMs, 0)
            end
            local elapsedMs = zo_max(nowMs - batchStartedAtMs - pausedMs, 0)
            local remainingItems = zo_max(totalItems - processedCount, 0)
            local remainingMs = zo_max(estimatedDurationMs - elapsedMs, 0)
            local remainingPauseBudgetMs = ComputeRemainingDeterministicPauseMs() + remainingWaitMs

            if remainingItems > 0 and processedCount > 0 and elapsedMs > 0 then
                local avgActiveMsPerItem = elapsedMs / processedCount
                local observedRemainingMs = (avgActiveMsPerItem * remainingItems) + remainingPauseBudgetMs
                remainingMs = zo_max(remainingMs, observedRemainingMs)
            else
                remainingMs = remainingMs + remainingPauseBudgetMs
            end

            local remainingLabel = FormatEstimatedBatchDuration(remainingMs / 1000)
            return string.format("Processing (%d/%d) ~%s", processedCount, totalItems, remainingLabel)
        end

        return string.format("Processing (%d/%d)", processedCount, totalItems)
    end

    local function BuildStillProcessingSecondaryText()
        local remainingWaitMs = ResolveStillProcessingWaitMs(GetNowMs(), nil)
        if remainingWaitMs > 0 then
            local waitSeconds = zo_max(1, zo_ceil(remainingWaitMs / 1000))
            return string.format("Continuing in %ds to prevent message rate limit logoff", waitSeconds)
        end
        return string.format("Please Wait - Press %s to abort", ResolveBatchAbortBindingMarkup())
    end

    local function ShowStillProcessingAnnouncement(waitMs, forceRecreate)
        if not showProgress then
            return
        end

        if waitMs and waitMs > 0 then
            ResolveStillProcessingWaitMs(GetNowMs(), waitMs)
        end

        if stillProcessingAnnouncementActive and not forceRecreate then
            return
        end

        if forceRecreate then
            ClearQueuedStillProcessingAnnouncements()
        end

        ShowBatchStatusOverlay(displayName, BuildStillProcessingMainText, BuildStillProcessingSecondaryText)
        stillProcessingAnnouncementActive = true
    end

    processNext = function()
        if not IsBatchSceneShowing(self_ref) then
            stopReason = "sceneExit"
            finishBatch()
            return
        end

        if self_ref.batchAbortRequested then
            stopReason = "aborted"
            finishBatch()
            return
        end

        if announceAfterCooldown then
            announceAfterCooldown = false
            ShowStillProcessingAnnouncement()
        end

        if isServerBound and enforceRateWindow then
            local rateWindowDelayMs = ComputeServerActionDelayMs(GetNowMs(), rateLimitWindowMs, rateLimitMaxActions)
            if rateWindowDelayMs > 0 then
                ShowStillProcessingAnnouncement(rateWindowDelayMs)
                ScheduleContinuation(rateWindowDelayMs, processNext)
                return
            end
        end

        index = index + 1

        if index > totalItems then
            finishBatch()
            return
        end

        local itemData = items[index]
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex
        local actionQueued = false

        if bagId and slotIndex then
            local result = actionFn(bagId, slotIndex, itemData)
            if result == false then
                stopReason = "bagFull"
            elseif type(result) == "string" and result ~= "" and result ~= "queued" then
                stopReason = result
            else
                processedCount = processedCount + 1
                processedCost = processedCost + actionCost
                actionQueued = (result == "queued")
                if actionQueued then
                    consecutiveQueuedActions = consecutiveQueuedActions + 1
                else
                    consecutiveQueuedActions = 0
                end

                if isServerBound and enforceRateWindow and (actionQueued or countTowardRateOnSuccess) then
                    RecordServerAction(GetNowMs(), rateLimitWindowMs)
                end
            end
        else
            consecutiveQueuedActions = 0
        end

        if stopReason then
            finishBatch()
            return
        end

        local baseDelayMs = effectiveDelayMs
        if isServerBound then
            baseDelayMs = zo_max(baseDelayMs, minServerDelayMs)

            if adaptiveDelay and actionQueued and adaptiveStepMs > 0 and maxServerDelayMs > minServerDelayMs then
                local queuedOverThreshold = zo_max(consecutiveQueuedActions - adaptiveThreshold, 0)
                if queuedOverThreshold > 0 then
                    local adaptiveBonus = zo_min(queuedOverThreshold * adaptiveStepMs, maxServerDelayMs - minServerDelayMs)
                    baseDelayMs = zo_min(maxServerDelayMs, baseDelayMs + adaptiveBonus)
                end
            end

            if jitterMs > 0 then
                local jitterOffset = ResolveSignedJitter(jitterMs)
                baseDelayMs = zo_clamp(baseDelayMs + jitterOffset, minServerDelayMs, maxServerDelayMs)
            else
                baseDelayMs = zo_clamp(baseDelayMs, minServerDelayMs, maxServerDelayMs)
            end
        end

        local nextDelayMs = baseDelayMs
        if processedCount < totalItems
            and cooldownMs > 0
            and nextCooldownAt
            and processedCost >= nextCooldownAt
        then
            nextDelayMs = nextDelayMs + cooldownMs
            announceAfterCooldown = true
            while nextCooldownAt and processedCost >= nextCooldownAt do
                nextCooldownAt = nextCooldownAt + cooldownEvery
            end
        end

        if processedCount < totalItems
            and chunkPauseMs > 0
            and nextChunkAt
            and processedCost >= nextChunkAt
        then
            nextDelayMs = nextDelayMs + chunkPauseMs
            announceAfterCooldown = true
            while nextChunkAt and processedCost >= nextChunkAt do
                nextChunkAt = nextChunkAt + chunkCostUnits
            end
        end

        local shouldAwaitAck = awaitInventoryAck and actionQueued
        if shouldAwaitAck then
            awaitingInventoryAckForAction = true
            ackReceivedForAction = false
            waitingForInventoryAck = false
            expectedAckBagId = bagId
            expectedAckSlotIndex = slotIndex
        else
            ResetInventoryAckState()
        end

        ScheduleContinuation(nextDelayMs, function()
            if self_ref.batchAbortRequested or not IsBatchSceneShowing(self_ref) then
                ResetInventoryAckState()
                processNext()
                return
            end

            if shouldAwaitAck and not ackReceivedForAction then
                waitingForInventoryAck = true
                ScheduleContinuation(ackTimeoutMs, function()
                    ResetInventoryAckState()
                    processNext()
                end)
                return
            end

            ResetInventoryAckState()
            processNext()
        end)
    end

    local function StartBatchAfterDialogDismiss(remainingWaitMs, settleDelayMs)
        if not self_ref.isBatchProcessing then
            return
        end

        if self_ref.batchAbortRequested then
            stopReason = "aborted"
            finishBatch()
            return
        end

        if not IsBatchSceneShowing(self_ref) then
            stopReason = "sceneExit"
            finishBatch()
            return
        end

        local dialogShowing = IsAnyBatchActionDialogShowing()
        if dialogShowing and remainingWaitMs > 0 then
            zo_callLater(function()
                StartBatchAfterDialogDismiss(
                    zo_max(remainingWaitMs - BATCH_STATUS_DIALOG_CLOSE_POLL_MS, 0),
                    settleDelayMs
                )
            end, BATCH_STATUS_DIALOG_CLOSE_POLL_MS)
            return
        end
        if (not dialogShowing) and (settleDelayMs or 0) > 0 then
            zo_callLater(function()
                StartBatchAfterDialogDismiss(remainingWaitMs, 0)
            end, settleDelayMs)
            return
        end

        ShowStillProcessingAnnouncement(startupDelayMs, true)

        if startupDelayMs > 0 then
            ScheduleContinuation(startupDelayMs, processNext)
        else
            processNext()
        end
    end

    StartBatchAfterDialogDismiss(BATCH_STATUS_DIALOG_CLOSE_MAX_WAIT_MS, BATCH_STATUS_DIALOG_SETTLE_MS)
end

-------------------------------------------------------------------------------------------------
-- COMMON BATCH OPERATIONS
-- Each operation pre-filters selected items to valid candidates, then uses
-- ProcessBatchThrottled. The completion callback exits selection mode and
-- refreshes the list.
-------------------------------------------------------------------------------------------------

--- Helper: extract bagId/slotIndex from item data (handles dataSource wrapper).
local function ExtractSlot(itemData)
    local rawData = itemData.dataSource or itemData
    return rawData.bagId or itemData.bagId, rawData.slotIndex or itemData.slotIndex
end

local LOCK_TOGGLE_BATCH_OPTIONS = {
    serverBound = true,
    awaitInventoryAck = false,
    minServerDelayMs = 140,
    maxServerDelayMs = 240,
    cooldownEvery = 22,
    cooldownMs = 1200,
    chunkCostUnits = 45,
    chunkPauseMs = 900,
    adaptiveDelay = false,
    jitterMs = 14,
}

local JUNK_TOGGLE_BATCH_OPTIONS = LOCK_TOGGLE_BATCH_OPTIONS

--- Performs batch lock on all selected items (throttled).
function Mixin.BatchLock(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and HasItemAtSlot(bagId, slotIndex)
            and CanItemBePlayerLocked(bagId, slotIndex)
            and not IsItemPlayerLocked(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if not CanItemBePlayerLocked(bagId, slotIndex) or IsItemPlayerLocked(bagId, slotIndex) then
            return true
        end

        SetItemIsPlayerLocked(bagId, slotIndex, true)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_MARK_AS_LOCKED), LOCK_TOGGLE_BATCH_OPTIONS)
end

--- Performs batch unlock on all selected items (throttled).
function Mixin.BatchUnlock(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and HasItemAtSlot(bagId, slotIndex)
            and IsItemPlayerLocked(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if not IsItemPlayerLocked(bagId, slotIndex) then
            return true
        end

        SetItemIsPlayerLocked(bagId, slotIndex, false)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED), LOCK_TOGGLE_BATCH_OPTIONS)
end

--- Performs batch mark-as-junk on all selected items (throttled).
function Mixin.BatchMarkAsJunk(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex then
            if HasItemAtSlot(bagId, slotIndex)
                and CanItemBeMarkedAsJunk(bagId, slotIndex)
                and not IsItemPlayerLocked(bagId, slotIndex)
                and not IsItemJunk(bagId, slotIndex)
            then
                table.insert(items, itemData)
            end
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if not CanItemBeMarkedAsJunk(bagId, slotIndex)
            or IsItemPlayerLocked(bagId, slotIndex)
            or IsItemJunk(bagId, slotIndex)
        then
            return true
        end

        SetItemIsJunk(bagId, slotIndex, true)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_MARK_AS_JUNK), JUNK_TOGGLE_BATCH_OPTIONS)
end

--- Performs batch unmark-as-junk on all selected items (throttled).
function Mixin.BatchUnmarkAsJunk(self)
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and HasItemAtSlot(bagId, slotIndex)
            and IsItemJunk(bagId, slotIndex)
            and not IsItemPlayerLocked(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if IsItemPlayerLocked(bagId, slotIndex) or not IsItemJunk(bagId, slotIndex) then
            return true
        end

        SetItemIsJunk(bagId, slotIndex, false)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK), JUNK_TOGGLE_BATCH_OPTIONS)
end

-------------------------------------------------------------------------------------------------
-- ITEM ANALYSIS
-- Shared analysis logic used by ShowBatchActionsMenu in each module.
-------------------------------------------------------------------------------------------------

--- Analyzes selected items and returns counts for each applicable batch action.
--- Modules call this to build their batch actions dialog entries.
--- @param selectedItems table Array of selected item data
--- @return table counts { lockedCount, unlockedCount, canLockCount, canMarkJunkCount, canUnmarkJunkCount }
function Mixin.AnalyzeSelectedItems(selectedItems)
    local counts = {
        lockedCount = 0,
        unlockedCount = 0,
        canLockCount = 0,
        canMarkJunkCount = 0,
        canUnmarkJunkCount = 0,
    }

    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local isLocked = IsItemPlayerLocked(bagId, slotIndex)
            local canBeLocked = CanItemBePlayerLocked(bagId, slotIndex)

            if isLocked then
                counts.lockedCount = counts.lockedCount + 1
            else
                counts.unlockedCount = counts.unlockedCount + 1
            end

            if canBeLocked and not isLocked then
                counts.canLockCount = counts.canLockCount + 1
            end

            local isJunk = IsItemJunk(bagId, slotIndex)
            local canBeJunked = CanItemBeMarkedAsJunk(bagId, slotIndex)
            if canBeJunked and not isLocked then
                if isJunk then
                    counts.canUnmarkJunkCount = counts.canUnmarkJunkCount + 1
                else
                    counts.canMarkJunkCount = counts.canMarkJunkCount + 1
                end
            end
        end
    end

    return counts
end

-------------------------------------------------------------------------------------------------
-- DIALOG HELPERS
-- Shared helpers to build batch actions dialog entries consistently.
-------------------------------------------------------------------------------------------------

--- Creates a single parametric dialog entry for a batch action.
--- @param label string The display label (e.g., "Lock (5)")
--- @param callback function The action callback
--- @return table entry The parametric list entry
function Mixin.CreateDialogEntry(label, callback)
    local entry = ZO_GamepadEntryData:New(label)
    entry:SetIconTintOnSelection(true)
    entry.setup = ZO_SharedGamepadEntry_OnSetup
    entry.callback = callback
    return {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = entry,
    }
end

--- Appends the standard shared batch action entries (Lock, Unlock, Mark Junk, Unmark Junk)
--- to a parametric list based on the analysis counts.
--- Modules call this after adding their own module-specific entries.
--- @param parametricList table The list to append entries to
--- @param counts table From AnalyzeSelectedItems
--- @param self table The module instance (for batch method callbacks)
function Mixin.AppendCommonBatchEntries(parametricList, counts, self)
    if counts.canLockCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_MARK_AS_LOCKED), counts.canLockCount)
        table.insert(parametricList, Mixin.CreateDialogEntry(label, function() self:BatchLock() end))
    end

    if counts.lockedCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED), counts.lockedCount)
        table.insert(parametricList, Mixin.CreateDialogEntry(label, function() self:BatchUnlock() end))
    end

    if counts.canMarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_MARK_AS_JUNK), counts.canMarkJunkCount)
        table.insert(parametricList, Mixin.CreateDialogEntry(label, function() self:BatchMarkAsJunk() end))
    end

    if counts.canUnmarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK), counts.canUnmarkJunkCount)
        table.insert(parametricList, Mixin.CreateDialogEntry(label, function() self:BatchUnmarkAsJunk() end))
    end
end
