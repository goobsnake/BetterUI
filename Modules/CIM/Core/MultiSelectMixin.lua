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

local BATCH_THROTTLE_TIERS = BETTERUI.CIM.CONST.TIMING.BATCH_ACTION_THROTTLE_TIERS or DEFAULT_BATCH_THROTTLE_TIERS
local BATCH_ETA_THRESHOLD = BETTERUI.CIM.CONST.TIMING.BATCH_ETA_THRESHOLD or 50
local DEFAULT_SERVER_COOLDOWN_EVERY = 25
local DEFAULT_SERVER_COOLDOWN_MS = 1100
local SERVER_COOLDOWN_EVERY = BETTERUI.CIM.CONST.TIMING.BATCH_SERVER_COOLDOWN_EVERY or DEFAULT_SERVER_COOLDOWN_EVERY
local SERVER_COOLDOWN_MS = BETTERUI.CIM.CONST.TIMING.BATCH_SERVER_COOLDOWN_MS or DEFAULT_SERVER_COOLDOWN_MS

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

local function EstimateBatchDurationSeconds(totalItems, delayMs, cooldownEvery, cooldownMs)
    local estimateMs = zo_max(totalItems, 0) * zo_max(delayMs or 0, 0)
    if totalItems > 1 and cooldownEvery and cooldownEvery > 0 and cooldownMs and cooldownMs > 0 then
        local cooldownCount = zo_floor((totalItems - 1) / cooldownEvery)
        estimateMs = estimateMs + (cooldownCount * cooldownMs)
    end
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
local BATCH_ANNOUNCE_BG_VERTICAL_OFFSET = 2
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
local BATCH_STILL_PROCESSING_CSA_TYPE = 970001

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

local function FindMostRecentLargeTextControl(csa)
    if not csa or type(csa.activeLines) ~= "table" then
        return nil
    end

    -- Avoid ESO-local CSA line-type constants (not globally visible to addons).
    for _, lineTable in pairs(csa.activeLines) do
        if type(lineTable) == "table" then
            for i = #lineTable, 1, -1 do
                local line = lineTable[i]
                if line and line.largeText then
                    return line.largeText
                end
            end
        end
    end

    return nil
end

local function ApplyBatchAnnouncementBackgroundLayout(_messageParams)
    local csa = CENTER_SCREEN_ANNOUNCE
    if not csa then return end

    local backgroundContainer = csa.backgroundContainer
    if not backgroundContainer then return end

    local background = backgroundContainer:GetNamedChild("BG")
    if not background then return end

    local largeText = FindMostRecentLargeTextControl(csa)
    if not largeText then return end

    local textWidth = largeText:GetTextWidth() or 0
    if textWidth <= 0 then
        local text = (largeText.GetText and largeText:GetText()) or ""
        local charCount = zo_strlen(text)
        -- Conservative fallback avoids inheriting the label's broad container width.
        textWidth = zo_max(charCount * 26, BATCH_ANNOUNCE_BG_MIN_WIDTH - BATCH_ANNOUNCE_BG_HORIZONTAL_PADDING)
    end

    local textHeight = largeText:GetTextHeight() or 0
    if textHeight <= 0 then
        textHeight = largeText:GetHeight() or 64
    end

    local guiWidth = (GuiRoot and GuiRoot:GetWidth()) or 1920
    local maxWidth = zo_max(guiWidth - (BATCH_ANNOUNCE_BG_SCREEN_MARGIN * 2), BATCH_ANNOUNCE_BG_MIN_WIDTH)

    local width = zo_clamp(textWidth + BATCH_ANNOUNCE_BG_HORIZONTAL_PADDING, BATCH_ANNOUNCE_BG_MIN_WIDTH, maxWidth)
    local height = zo_max(textHeight + (BATCH_ANNOUNCE_BG_VERTICAL_PADDING * 2), BATCH_ANNOUNCE_BG_MIN_HEIGHT)
    local halfWidth = width * 0.5
    local halfHeight = height * 0.5

    -- Keep to two anchors (ESO control limit) and size explicitly to text bounds.
    background:ClearAnchors()
    background:SetAnchor(TOPLEFT, largeText, CENTER, -halfWidth, -halfHeight + BATCH_ANNOUNCE_BG_VERTICAL_OFFSET)
    background:SetAnchor(TOPRIGHT, largeText, CENTER, halfWidth, -halfHeight + BATCH_ANNOUNCE_BG_VERTICAL_OFFSET)
    background:SetHeight(height)
    background:SetTexture(BATCH_ANNOUNCE_BG_BASE_TEXTURE)
    background:SetColor(1, 1, 1, BATCH_ANNOUNCE_BG_BASE_ALPHA)

    local calloutBand = EnsureBatchAnnouncementCalloutBand(backgroundContainer)
    if calloutBand then
        calloutBand:ClearAnchors()
        calloutBand:SetAnchor(
            TOPLEFT,
            background,
            TOPLEFT,
            BATCH_ANNOUNCE_BG_CALLOUT_HORIZONTAL_INSET,
            BATCH_ANNOUNCE_BG_CALLOUT_VERTICAL_INSET + BATCH_ANNOUNCE_BG_CALLOUT_VERTICAL_SHIFT
        )
        calloutBand:SetAnchor(
            BOTTOMRIGHT,
            background,
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

    local frame = EnsureBatchAnnouncementFrame(backgroundContainer)
    if frame then
        frame:ClearAnchors()
        frame:SetAnchor(TOPLEFT, background, TOPLEFT, 0, 0)
        frame:SetAnchor(BOTTOMRIGHT, background, BOTTOMRIGHT, 0, 0)
        frame:SetCenterColor(1, 1, 1, BATCH_ANNOUNCE_BG_FRAME_CENTER_ALPHA)
        frame:SetEdgeColor(1, 1, 1, BATCH_ANNOUNCE_BG_FRAME_EDGE_ALPHA)
        frame:SetHidden(false)
    end
end

local function SetBatchAnnouncementText(messageParams, displayName, bodyText)
    local mainText = zo_strformat("<<1>>: <<2>>", displayName, bodyText)
    local coloredMainText = string.format("|c%s%s|r", BATCH_ANNOUNCE_TEXT_COLOR_HEX, mainText)
    messageParams:SetText(coloredMainText, nil)
    messageParams:MarkShowBackground()
    messageParams:SetOnDisplayCallback(ApplyBatchAnnouncementBackgroundLayout)
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
--- @param actionFn fun(bagId: number, slotIndex: number, itemData: table): boolean? Per-item function; return false to stop early
--- @param onComplete fun()? Optional callback when all items processed
--- @param actionName string? Name of the action for progress notifications
--- @param batchOptions table? Optional controls:
---   serverBound (boolean): apply fixed server cooldown pacing
---   suppressUiUpdates (boolean): expose `self.batchSuppressUiUpdates` for module callbacks
---   sceneExitLabel (string): explicit label used when scene-exit abort happens
function Mixin.ProcessBatchThrottled(self, items, actionFn, onComplete, actionName, batchOptions)
    items = NormalizeBatchItems(items or {})
    local totalItems = #items
    if totalItems == 0 then
        if onComplete then onComplete() end
        return
    end

    local index = 0
    local processedCount = 0
    local stopReason = nil
    local throttleProfile = ResolveBatchThrottleProfile(totalItems)
    local batchDelayMs = throttleProfile.DELAY_MS or 75
    local showProgress = throttleProfile.SHOW_PROGRESS == true
    local showEta = totalItems >= BATCH_ETA_THRESHOLD
    local options = batchOptions or {}
    local isServerBound = options.serverBound == true
    local suppressUiUpdates = options.suppressUiUpdates == true
    local sceneExitLabel = ResolveSceneExitLabel(self, options)
    local cooldownEvery = 0
    local cooldownMs = 0

    if isServerBound then
        cooldownEvery = SERVER_COOLDOWN_EVERY
        cooldownMs = SERVER_COOLDOWN_MS
    end

    local effectiveDelayMs = zo_max(0, batchDelayMs)
    local self_ref = self
    local announceAfterCooldown = false
    local function ClearQueuedStillProcessingAnnouncements()
        local csa = CENTER_SCREEN_ANNOUNCE
        if csa and csa.RemoveAllCSAsOfAnnounceType then
            csa:RemoveAllCSAsOfAnnounceType(BATCH_STILL_PROCESSING_CSA_TYPE)
        end
    end

    -- Defensive cleanup in case any prior still-processing messages remain queued.
    ClearQueuedStillProcessingAnnouncements()

    -- Set batch processing flag to suppress refreshes
    self.isBatchProcessing = true
    self.batchAbortRequested = false
    self.batchRemainingCount = totalItems
    self.batchTotalCount = totalItems
    self.batchProcessedCount = 0
    self.batchSuppressUiUpdates = suppressUiUpdates and true or nil

    local displayName = actionName or GetString(SI_BETTERUI_BATCH_ACTIONS)
    self.batchActionName = displayName

    if self._msConfig and self._msConfig.refreshKeybinds then
        self._msConfig.refreshKeybinds(self)
    end

    -- Show start notification for large batches
    if showProgress then
        local bodyText
        if showEta then
            local estimatedSeconds = EstimateBatchDurationSeconds(totalItems, effectiveDelayMs, cooldownEvery, cooldownMs)
            bodyText = zo_strformat(
                GetString(SI_BETTERUI_BATCH_PROCESSING_START_ETA),
                totalItems,
                FormatEstimatedBatchDuration(estimatedSeconds)
            )
        else
            bodyText = zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_START), totalItems)
        end

        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
        SetBatchAnnouncementText(messageParams, displayName, bodyText)
        messageParams:SetLifespanMS(3000)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end

    local function finishBatch()
        -- Clear batch processing flag first so normal keybind labels restore
        self_ref.isBatchProcessing = false

        local remainingCount = zo_max(totalItems - processedCount, 0)
        self_ref.batchProcessedCount = processedCount
        self_ref.batchRemainingCount = remainingCount

        if IsBatchSceneShowing(self_ref) and self_ref._msConfig and self_ref._msConfig.refreshKeybinds then
            self_ref._msConfig.refreshKeybinds(self_ref)
        end

        -- Remove stale queued/active progress notices so completion/abort text is authoritative.
        ClearQueuedStillProcessingAnnouncements()

        -- Show completion notification
        if showProgress or stopReason then
            local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
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
            SetBatchAnnouncementText(messageParams, displayName, completeText)
            messageParams:SetLifespanMS((stopReason and 4000) or 2000)
            CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
        end

        self_ref.batchAbortRequested = nil
        self_ref.batchRemainingCount = nil
        self_ref.batchTotalCount = nil
        self_ref.batchProcessedCount = nil
        self_ref.batchActionName = nil
        self_ref.batchSuppressUiUpdates = nil

        if onComplete then onComplete(stopReason) end
    end

    local function ShowStillProcessingAnnouncement()
        if not showProgress then
            return
        end

        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
        messageParams:SetCSAType(BATCH_STILL_PROCESSING_CSA_TYPE)
        local stillText = zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_STILL), processedCount, totalItems)
        SetBatchAnnouncementText(messageParams, displayName, stillText)
        messageParams:SetLifespanMS(1800)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end

    local function processNext()
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

        index = index + 1

        if index > totalItems then
            finishBatch()
            return
        end

        local itemData = items[index]
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex

        if bagId and slotIndex then
            local result = actionFn(bagId, slotIndex, itemData)
            if result == false then
                stopReason = "bagFull"
            else
                processedCount = processedCount + 1
            end
        end

        self_ref.batchProcessedCount = processedCount
        self_ref.batchRemainingCount = zo_max(totalItems - processedCount, 0)

        if stopReason then
            finishBatch()
            return
        end

        local nextDelayMs = effectiveDelayMs
        if processedCount < totalItems
            and processedCount > 0
            and cooldownEvery > 0
            and cooldownMs > 0
            and (processedCount % cooldownEvery) == 0
        then
            nextDelayMs = nextDelayMs + cooldownMs
            announceAfterCooldown = true
        end

        zo_callLater(processNext, nextDelayMs)
    end

    processNext()
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
        return true
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_MARK_AS_LOCKED), {
        serverBound = true,
    })
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
        return true
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED), {
        serverBound = true,
    })
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
        return true
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_MARK_AS_JUNK), {
        serverBound = true,
    })
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
        return true
    end, function()
        self:ExitSelectionMode()
    end, GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK), {
        serverBound = true,
    })
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
