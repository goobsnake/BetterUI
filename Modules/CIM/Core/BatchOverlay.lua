--[[
File: Modules/CIM/Core/BatchOverlay.lua
Purpose: Batch status overlay UI for multi-select operations.
         Creates, lays out, shows, and hides the on-screen progress indicator
         during throttled batch processing.

Extracted from: MultiSelectMixin.lua (overlay concern)
Author: BetterUI Team
Last Modified: 2026-03-14
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.BatchOverlay = BETTERUI.CIM.BatchOverlay or {}

local BatchOverlay = BETTERUI.CIM.BatchOverlay

-------------------------------------------------------------------------------------------------
-- OVERLAY CONSTANTS
-------------------------------------------------------------------------------------------------

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

local BATCH_ACTION_DIALOG_NAMES = {
    "BETTERUI_BATCH_ACTIONS_DIALOG",
    "BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG",
    "BETTERUI_BANKING_BATCH_ACTIONS_DIALOG",
}

-------------------------------------------------------------------------------------------------
-- OVERLAY STATE
-------------------------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------------------------
-- DIALOG CHECK
-------------------------------------------------------------------------------------------------

--- Checks if any batch action dialog is currently showing.
--- @return boolean
function BatchOverlay.IsAnyBatchActionDialogShowing()
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

-------------------------------------------------------------------------------------------------
-- OVERLAY CONSTRUCTION HELPERS
-------------------------------------------------------------------------------------------------

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
        -- Phase: resolve-status-text
        local ok, resolved = BETTERUI.CIM.SafeExecute("BatchOverlay:ResolveStatusText", value)
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

-------------------------------------------------------------------------------------------------
-- OVERLAY CREATION
-------------------------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------------------------
-- OVERLAY LAYOUT
-------------------------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------------------------

--- Shows the batch status overlay with the given text content.
--- @param displayName string Action display name
--- @param bodyText string|function Static or dynamic body text
--- @param secondaryText string|function|nil Static or dynamic secondary line
function BatchOverlay.Show(displayName, bodyText, secondaryText)
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

        if BatchOverlay.IsAnyBatchActionDialogShowing() then
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

--- Hides the batch status overlay, optionally with a delay.
--- @param delayMs number|nil Delay in ms before hiding; 0 or nil hides immediately
function BatchOverlay.Hide(delayMs)
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

--- Cancels any active dynamic text update loop without hiding the overlay.
function BatchOverlay.StopLayoutPulse()
    local overlay = BATCH_STATUS_OVERLAY
    overlay.updateToken = overlay.updateToken + 1
end
