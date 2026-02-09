--[[
File: Modules/Banking/Core/MultiSelectActions.lua
Purpose: Multi-select batch operations for the Banking module.
         Provides batch withdraw/deposit, lock/unlock, junk actions, and
         the batch actions dialog with throttled processing.
Author: BetterUI Team
Last Modified: 2026-02-09

Mirrors the Inventory multi-select pattern but adapted for Banking's
dual-mode (Withdraw/Deposit) architecture.
]]

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

-- Use centralized constants from CIM
local BATCH_THROTTLE_DELAY_MS = BETTERUI.CIM.CONST.TIMING.BATCH_ACTION_DELAY_MS
local BATCH_PROGRESS_THRESHOLD = BETTERUI.CIM.CONST.TIMING.BATCH_PROGRESS_THRESHOLD

-------------------------------------------------------------------------------------------------
-- THROTTLED BATCH PROCESSING
-------------------------------------------------------------------------------------------------

--- Processes items with staggered delays to prevent rate-limiting.
--- Suppresses list/keybind refreshes during processing to prevent flickering.
--- @param items table Array of items to process
--- @param actionFn fun(bagId: number, slotIndex: number, itemData: table): boolean? Function per item, returns false to stop
--- @param onComplete fun()? Optional callback when all items processed
--- @param actionName string? Name of the action for notifications
function BETTERUI.Banking.Class:ProcessBatchThrottled(items, actionFn, onComplete, actionName)
    local index = 0
    local totalItems = #items
    local processedCount = 0
    local stoppedEarly = false
    local showProgress = totalItems >= BATCH_PROGRESS_THRESHOLD
    local self_ref = self

    -- Set batch processing flag to suppress refreshes
    self.isBatchProcessing = true

    -- Get display name for notifications
    local displayName = actionName or GetString(SI_BETTERUI_BATCH_ACTIONS)

    -- Show start notification for large batches
    if showProgress then
        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
        messageParams:SetText(displayName,
            zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_START), totalItems))
        messageParams:SetLifespanMS(3000)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end

    local function processNext()
        index = index + 1

        -- Check if we've completed all items or stopped early
        if index > totalItems or stoppedEarly then
            -- Clear batch processing flag
            self_ref.isBatchProcessing = false

            -- Show completion notification
            if showProgress or stoppedEarly then
                local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
                local completeText
                if stoppedEarly then
                    completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_BAG_FULL), processedCount, totalItems)
                else
                    completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_COMPLETE), totalItems)
                end
                messageParams:SetText(displayName, completeText)
                messageParams:SetLifespanMS(stoppedEarly and 4000 or 2000)
                CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
            end

            -- Call completion handler
            if onComplete then onComplete() end
            return
        end

        local itemData = items[index]
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex

        if bagId and slotIndex then
            -- actionFn returns false to signal "stop processing" (e.g., bag full)
            local result = actionFn(bagId, slotIndex, itemData)
            if result == false then
                stoppedEarly = true
            else
                processedCount = processedCount + 1
            end
        end

        -- Schedule next item with delay
        zo_callLater(processNext, BATCH_THROTTLE_DELAY_MS)
    end

    -- Start processing
    processNext()
end

-------------------------------------------------------------------------------------------------
-- BATCH OPERATIONS
-------------------------------------------------------------------------------------------------

--- Performs batch withdraw/deposit on all selected items (throttled).
--- Moves items between bank and backpack based on current mode.
function BETTERUI.Banking.Class:BatchTransfer()
    if not self.multiSelectManager then return end
    local items = self.multiSelectManager:GetSelectedItems()
    if not items or #items == 0 then return end

    local isWithdraw = (self.currentMode == LIST_WITHDRAW)
    local actionName = isWithdraw
        and GetString(SI_BETTERUI_BANKING_WITHDRAW)
        or GetString(SI_BETTERUI_BANKING_DEPOSIT)

    self:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
        local rawData = itemData.dataSource or itemData
        local stackCount = rawData.stackCount or itemData.stackCount or 1

        if isWithdraw then
            -- Withdraw: move from bank to backpack
            if not DoesBagHaveSpaceFor(BAG_BACKPACK, bagId, slotIndex) then
                -- Check for stackable slot before giving up
                local itemLink = GetItemLink(bagId, slotIndex)
                local stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(BAG_BACKPACK, itemLink)
                if not stackSlot then
                    return false -- Bag full, stop processing
                end
            end
            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, nil, stackCount)
        else
            -- Deposit: move from backpack to bank
            -- Try main bank first, then subscriber bank
            local targetBag, targetSlot
            local currentUsedBank = BETTERUI.Banking.currentUsedBank
            if currentUsedBank == BAG_BANK then
                targetSlot = FindFirstEmptySlotInBag(BAG_BANK)
                if targetSlot then
                    targetBag = BAG_BANK
                elseif IsESOPlusSubscriber() then
                    targetSlot = FindFirstEmptySlotInBag(BAG_SUBSCRIBER_BANK)
                    if targetSlot then
                        targetBag = BAG_SUBSCRIBER_BANK
                    end
                end
            else
                targetSlot = FindFirstEmptySlotInBag(currentUsedBank)
                if targetSlot then
                    targetBag = currentUsedBank
                end
            end

            if not targetBag then
                -- Try finding a stackable slot
                local itemLink = GetItemLink(bagId, slotIndex)
                if currentUsedBank == BAG_BANK then
                    local stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(BAG_BANK, itemLink)
                    if stackSlot then
                        targetBag = BAG_BANK
                    else
                        stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(BAG_SUBSCRIBER_BANK, itemLink)
                        if stackSlot then
                            targetBag = BAG_SUBSCRIBER_BANK
                        end
                    end
                else
                    local stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(currentUsedBank, itemLink)
                    if stackSlot then
                        targetBag = currentUsedBank
                    end
                end
                if not targetBag then
                    return false -- Bank full, stop processing
                end
            end

            CallSecureProtected("RequestMoveItem", bagId, slotIndex, targetBag, nil, stackCount)
        end
        return true
    end, function()
        self:ExitSelectionMode()
    end, actionName)
end

--- Performs batch lock on all selected items (throttled).
--- Pre-filters to only include items that CAN be locked AND are not already locked.
function BETTERUI.Banking.Class:BatchLock()
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    -- Pre-filter to only lockable, unlocked items
    local items = {}
    for _, itemData in ipairs(allItems) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex
        if bagId and slotIndex then
            if CanItemBePlayerLocked(bagId, slotIndex) and not IsItemPlayerLocked(bagId, slotIndex) then
                table.insert(items, itemData)
            end
        end
    end

    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsPlayerLocked(bagId, slotIndex, true)
        return true
    end, function()
        self:ExitSelectionMode()
        self:RefreshList()
    end, GetString(SI_ITEM_ACTION_MARK_AS_LOCKED))
end

--- Performs batch unlock on all selected items (throttled).
--- Pre-filters to only include items that are currently locked.
function BETTERUI.Banking.Class:BatchUnlock()
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()

    -- Pre-filter to only locked items
    local items = {}
    for _, itemData in ipairs(allItems) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex
        if bagId and slotIndex and IsItemPlayerLocked(bagId, slotIndex) then
            table.insert(items, itemData)
        end
    end

    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsPlayerLocked(bagId, slotIndex, false)
        return true
    end, function()
        self:ExitSelectionMode()
        self:RefreshList()
    end, GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED))
end

--- Performs batch mark-as-junk on all selected items (throttled).
--- Only applicable in Deposit mode (backpack items). Pre-filters to valid candidates.
function BETTERUI.Banking.Class:BatchMarkAsJunk()
    if not self.multiSelectManager then return end
    if self.currentMode ~= LIST_DEPOSIT then return end -- Junk only for backpack items

    local allItems = self.multiSelectManager:GetSelectedItems()

    -- Pre-filter to only junkable, unlocked, non-junk items
    local items = {}
    for _, itemData in ipairs(allItems) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex
        if bagId and slotIndex then
            local canBeJunked = CanItemBeMarkedAsJunk(bagId, slotIndex)
            local isLocked = IsItemPlayerLocked(bagId, slotIndex)
            local isJunk = IsItemJunk(bagId, slotIndex)
            if canBeJunked and not isLocked and not isJunk then
                table.insert(items, itemData)
            end
        end
    end

    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsJunk(bagId, slotIndex, true)
        return true
    end, function()
        self:ExitSelectionMode()
        self:RefreshList()
    end, GetString(SI_ITEM_ACTION_MARK_AS_JUNK))
end

--- Performs batch unmark-as-junk on all selected items (throttled).
--- Only applicable in Deposit mode (backpack items). Pre-filters to valid candidates.
function BETTERUI.Banking.Class:BatchUnmarkAsJunk()
    if not self.multiSelectManager then return end
    if self.currentMode ~= LIST_DEPOSIT then return end -- Junk only for backpack items

    local allItems = self.multiSelectManager:GetSelectedItems()

    -- Pre-filter to only junk items that are unlocked
    local items = {}
    for _, itemData in ipairs(allItems) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex
        if bagId and slotIndex then
            local isLocked = IsItemPlayerLocked(bagId, slotIndex)
            local isJunk = IsItemJunk(bagId, slotIndex)
            if isJunk and not isLocked then
                table.insert(items, itemData)
            end
        end
    end

    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsJunk(bagId, slotIndex, false)
        return true
    end, function()
        self:ExitSelectionMode()
        self:RefreshList()
    end, GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK))
end

--- Selects all items in the current list.
--- Reopens the batch actions dialog to reflect the updated selection.
function BETTERUI.Banking.Class:SelectAllItems()
    if not self.multiSelectManager then return end

    self.multiSelectManager:SelectAll(self.list)

    -- Close current dialog first, then defer refresh to allow UI update
    ZO_Dialogs_ReleaseDialog("BETTERUI_BANKING_BATCH_ACTIONS_DIALOG")
    zo_callLater(function()
        -- Refresh the list to show selection highlights
        self:RefreshList()
        -- Refresh keybinds to update count display
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
        -- Reopen with updated selection
        self:ShowBatchActionsMenu()
    end, 50)
end

-------------------------------------------------------------------------------------------------
-- BATCH ACTIONS DIALOG
-------------------------------------------------------------------------------------------------

--- Shows the batch actions menu for multi-selected items.
--- Displays context-appropriate batch operations based on selected items' states
--- and the current banking mode (Withdraw vs Deposit).
function BETTERUI.Banking.Class:ShowBatchActionsMenu()
    if not self.multiSelectManager or not self.multiSelectManager:IsActive() then
        return
    end

    local selectedItems = self.multiSelectManager:GetSelectedItems()
    local selectedCount = #selectedItems

    if selectedCount == 0 then
        return
    end

    -- Analyze selected items to determine which actions are applicable
    local lockedCount = 0
    local unlockedCount = 0
    local canLockCount = 0
    local canMarkJunkCount = 0   -- Only for deposit mode (backpack items)
    local canUnmarkJunkCount = 0 -- Only for deposit mode (backpack items)
    local isDepositMode = (self.currentMode == LIST_DEPOSIT)

    for _, itemData in ipairs(selectedItems) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex

        if bagId and slotIndex then
            -- Check lock status and lockability
            local isLocked = IsItemPlayerLocked(bagId, slotIndex)
            local canBeLocked = CanItemBePlayerLocked(bagId, slotIndex)

            if isLocked then
                lockedCount = lockedCount + 1
            else
                unlockedCount = unlockedCount + 1
            end

            if canBeLocked and not isLocked then
                canLockCount = canLockCount + 1
            end

            -- Junk status only for deposit mode (backpack items can be junked)
            if isDepositMode then
                local isJunk = IsItemJunk(bagId, slotIndex)
                local canBeJunked = CanItemBeMarkedAsJunk(bagId, slotIndex)

                if canBeJunked and not isLocked then
                    if isJunk then
                        canUnmarkJunkCount = canUnmarkJunkCount + 1
                    else
                        canMarkJunkCount = canMarkJunkCount + 1
                    end
                end
            end
        end
    end

    -- Build batch actions dialog
    local dialogName = "BETTERUI_BANKING_BATCH_ACTIONS_DIALOG"

    -- Create dialog if it doesn't exist
    if not ESO_Dialogs[dialogName] then
        ESO_Dialogs[dialogName] = {
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = function(dialog)
                    local count = dialog and dialog.data and dialog.data.selectedCount or 0
                    return zo_strformat(GetString(SI_BETTERUI_SELECTED_COUNT), count)
                end,
            },
            mainText = {
                text = GetString(SI_BETTERUI_BATCH_ACTIONS_DESC),
            },
            setup = function(dialog)
                dialog:setupFunc()
            end,
            parametricList = {},
            buttons = {
                {
                    keybind = "DIALOG_PRIMARY",
                    text = GetString(SI_GAMEPAD_SELECT_OPTION),
                    callback = function(dialog)
                        local selected = dialog.entryList and dialog.entryList:GetTargetData()
                        if selected and selected.callback then
                            selected.callback()
                        end
                    end,
                },
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = GetString(SI_GAMEPAD_BACK_OPTION),
                    callback = function()
                        -- Refresh keybinds after dialog closes
                        zo_callLater(function()
                            if BETTERUI.Banking.Window then
                                KEYBIND_STRIP:UpdateKeybindButtonGroup(
                                    BETTERUI.Banking.Window.coreKeybinds)
                            end
                        end, 50)
                    end,
                },
            },
        }
    end

    -- Build the parametric list with applicable batch actions
    local parametricList = {}

    -- Select All (always at top)
    local selectAllEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_SELECT_ALL))
    selectAllEntry:SetIconTintOnSelection(true)
    selectAllEntry.setup = ZO_SharedGamepadEntry_OnSetup
    selectAllEntry.callback = function()
        self:SelectAllItems()
    end
    table.insert(parametricList, {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = selectAllEntry,
    })

    -- Withdraw/Deposit All (primary banking action) - show count
    local transferName = isDepositMode
        and GetString(SI_BETTERUI_BANKING_DEPOSIT)
        or GetString(SI_BETTERUI_BANKING_WITHDRAW)
    local transferLabel = zo_strformat("<<1>> (<<2>>)", transferName, selectedCount)
    local transferEntry = ZO_GamepadEntryData:New(transferLabel)
    transferEntry:SetIconTintOnSelection(true)
    transferEntry.setup = ZO_SharedGamepadEntry_OnSetup
    transferEntry.callback = function()
        self:BatchTransfer()
    end
    table.insert(parametricList, {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = transferEntry,
    })

    -- Lock (only if lockable unlocked items exist)
    if canLockCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_MARK_AS_LOCKED), canLockCount)
        local lockEntry = ZO_GamepadEntryData:New(label)
        lockEntry:SetIconTintOnSelection(true)
        lockEntry.setup = ZO_SharedGamepadEntry_OnSetup
        lockEntry.callback = function()
            self:BatchLock()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = lockEntry,
        })
    end

    -- Unlock (only if locked items exist)
    if lockedCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED), lockedCount)
        local unlockEntry = ZO_GamepadEntryData:New(label)
        unlockEntry:SetIconTintOnSelection(true)
        unlockEntry.setup = ZO_SharedGamepadEntry_OnSetup
        unlockEntry.callback = function()
            self:BatchUnlock()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = unlockEntry,
        })
    end

    -- Mark as Junk (deposit mode only, unlocked non-junk items)
    if isDepositMode and canMarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_MARK_AS_JUNK), canMarkJunkCount)
        local junkEntry = ZO_GamepadEntryData:New(label)
        junkEntry:SetIconTintOnSelection(true)
        junkEntry.setup = ZO_SharedGamepadEntry_OnSetup
        junkEntry.callback = function()
            self:BatchMarkAsJunk()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = junkEntry,
        })
    end

    -- Unmark as Junk (deposit mode only, junk items)
    if isDepositMode and canUnmarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK), canUnmarkJunkCount)
        local unjunkEntry = ZO_GamepadEntryData:New(label)
        unjunkEntry:SetIconTintOnSelection(true)
        unjunkEntry.setup = ZO_SharedGamepadEntry_OnSetup
        unjunkEntry.callback = function()
            self:BatchUnmarkAsJunk()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = unjunkEntry,
        })
    end

    -- Deselect All (always at bottom)
    local deselectLabel = zo_strformat("<<1>> (<<2>>)", GetString(SI_BETTERUI_DESELECT_ALL), selectedCount)
    local deselectEntry = ZO_GamepadEntryData:New(deselectLabel)
    deselectEntry:SetIconTintOnSelection(true)
    deselectEntry.setup = ZO_SharedGamepadEntry_OnSetup
    deselectEntry.callback = function()
        -- Release dialog first, then defer exit to allow UI update
        ZO_Dialogs_ReleaseDialog("BETTERUI_BANKING_BATCH_ACTIONS_DIALOG")
        zo_callLater(function()
            self:ExitSelectionMode()
        end, 50)
    end
    table.insert(parametricList, {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = deselectEntry,
    })

    ESO_Dialogs[dialogName].parametricList = parametricList

    -- Pass selectedCount in dialog data so title function uses fresh value
    ZO_Dialogs_ShowGamepadDialog(dialogName, { selectedCount = selectedCount })
end
