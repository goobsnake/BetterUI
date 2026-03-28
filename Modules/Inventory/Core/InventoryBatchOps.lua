-- Modules/Inventory/Core/InventoryBatchOps.lua
-- Batch operations: retrieve, stow, deposit, destroy, and related dialogs.
-- Extracted from InventoryClass.lua for maintainability.

local Class = BETTERUI.Inventory.Class
local MultiSelectMixin = BETTERUI.CIM.MultiSelectMixin
local BLOCK_TABBAR_CALLBACK = true

local FURNITURE_VAULT_BAG_ID = BAG_FURNITURE_VAULT

--------------------------------------------------------------------------------
-- SLOT HELPERS
--------------------------------------------------------------------------------

local ExtractSlot = BETTERUI.CIM.BatchActions.ExtractSlot
local HasItemAtSlot = BETTERUI.CIM.BatchActions.HasItemAtSlot

--- @param itemData table
--- @param bagId number
--- @param slotIndex number
--- @return number|nil stackCount
local function ResolveStackCount(itemData, bagId, slotIndex)
    local rawData = itemData.dataSource or itemData
    local requestedStack = rawData.stackCount or itemData.stackCount or 1
    local liveStack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
    if liveStack <= 0 then
        return nil
    end
    return zo_clamp(requestedStack, 1, liveStack)
end

--- @param bagId number
--- @param slotIndex number
--- @param targetBankBag number
--- @return boolean isSupported
local function IsInventoryDepositSupported(bagId, slotIndex, targetBankBag)
    if not BETTERUI.CIM.ProtectionPolicy.CanTransferItem(bagId, slotIndex, targetBankBag) then
        return false
    end
    if targetBankBag == FURNITURE_VAULT_BAG_ID
        and not BETTERUI.CIM.ProtectionPolicy.CanDepositToFurnitureVault(bagId, slotIndex) then
        return false
    end
    return true
end

--- @param bagId number
--- @param slotIndex number
--- @return number|nil targetBag
local function ResolveInventoryDepositTargetBag(bagId, slotIndex)
    local targetBankBag = (BETTERUI.Banking and BETTERUI.Banking.currentUsedBank) or BAG_BANK
    if targetBankBag == BAG_BANK then
        if DoesBagHaveSpaceFor(BAG_BANK, bagId, slotIndex) then
            return BAG_BANK
        end
        if IsESOPlusSubscriber() and DoesBagHaveSpaceFor(BAG_SUBSCRIBER_BANK, bagId, slotIndex) then
            return BAG_SUBSCRIBER_BANK
        end
        return nil
    end
    if DoesBagHaveSpaceFor(targetBankBag, bagId, slotIndex) then
        return targetBankBag
    end
    return nil
end

--------------------------------------------------------------------------------
-- DESTROY ELIGIBILITY
--------------------------------------------------------------------------------

--- @param itemData table
--- @return boolean canDestroy
local function CanDestroyInventoryItem(itemData)
    if not itemData then
        return false
    end
    local rawData = itemData.dataSource or itemData
    local bagId = rawData.bagId or itemData.bagId
    local slotIndex = rawData.slotIndex or itemData.slotIndex
    local slotType = rawData.slotType or itemData.slotType
    return BETTERUI.CIM.ProtectionPolicy.CanDestroyItem(bagId, slotIndex, slotType)
end

-- Expose to other modules (e.g., InventoryMultiSelect needs it)
BETTERUI.Inventory.CanDestroyInventoryItem = CanDestroyInventoryItem

--------------------------------------------------------------------------------
-- BATCH OPTION PRESETS
--------------------------------------------------------------------------------

local CRAFT_BAG_RETRIEVE_BATCH_OPTIONS = {
    serverBound = true,
    suppressUiUpdates = true,
    costPerItem = 2,
    awaitInventoryAck = true,
    minServerDelayMs = 150,
    maxServerDelayMs = 340,
    cooldownEvery = 18,
    cooldownMs = 1250,
    chunkCostUnits = 30,
    chunkPauseMs = 1050,
    adaptiveDelay = true,
    adaptiveThreshold = 6,
    adaptiveStepMs = 18,
    jitterMs = 20,
}

local CRAFT_BAG_STOW_BATCH_OPTIONS = {
    serverBound = true,
    costPerItem = 2,
    awaitInventoryAck = true,
    minServerDelayMs = 145,
    maxServerDelayMs = 330,
    cooldownEvery = 18,
    cooldownMs = 1200,
    chunkCostUnits = 30,
    chunkPauseMs = 1000,
    adaptiveDelay = true,
    adaptiveThreshold = 6,
    adaptiveStepMs = 16,
    jitterMs = 20,
}

local BANK_DEPOSIT_BATCH_OPTIONS = {
    serverBound = true,
    awaitInventoryAck = true,
    minServerDelayMs = 145,
    maxServerDelayMs = 330,
    cooldownEvery = 18,
    cooldownMs = 1200,
    chunkCostUnits = 32,
    chunkPauseMs = 1000,
    adaptiveDelay = true,
    adaptiveThreshold = 6,
    adaptiveStepMs = 16,
    jitterMs = 18,
}

local DESTROY_BATCH_OPTIONS = {
    serverBound = true,
    suppressUiUpdates = true,
    awaitInventoryAck = true,
    minServerDelayMs = 165,
    maxServerDelayMs = 360,
    cooldownEvery = 14,
    cooldownMs = 1400,
    chunkCostUnits = 24,
    chunkPauseMs = 1150,
    adaptiveDelay = true,
    adaptiveThreshold = 5,
    adaptiveStepMs = 20,
    jitterMs = 20,
}

--------------------------------------------------------------------------------
-- THROTTLED BATCH PROCESSING (delegates to CIM.MultiSelectMixin)
--------------------------------------------------------------------------------

--- Checks if a batch operation is currently processing.
--- @return boolean isProcessing True if batch processing is active
function Class:IsBatchProcessing()
    return MultiSelectMixin.IsBatchProcessing(self)
end

--- Checks if the current batch can be aborted.
--- @return boolean canAbort True if batch can be aborted
function Class:CanAbortBatch()
    return MultiSelectMixin.CanAbortBatch(self)
end

--- Requests abort of the current batch operation.
--- @return boolean requested True if abort was requested
function Class:RequestBatchAbort()
    return MultiSelectMixin.RequestBatchAbort(self)
end

--- Processes a batch of items with throttling.
--- @param items table The items to process
--- @param actionFn function The action function to apply to each item
--- @param onComplete function|nil Callback when batch completes
--- @param actionName string Name of the action for progress display
--- @param batchOptions table Options for batch processing
function Class:ProcessBatchThrottled(items, actionFn, onComplete, actionName, batchOptions)
    MultiSelectMixin.ProcessBatchThrottled(self, items, actionFn, onComplete, actionName, batchOptions)
end

--------------------------------------------------------------------------------
-- BATCH INVENTORY ACTIONS
--------------------------------------------------------------------------------

--- Performs batch retrieve on all selected craftbag items (throttled).
function Class:BatchRetrieve()
    if not self.craftBagMultiSelectManager then return end
    local selectedItems = self.craftBagMultiSelectManager:GetSelectedItems()
    if not selectedItems or #selectedItems == 0 then return end

    local items = {}
    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            items[#items + 1] = itemData
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
        if not HasItemAtSlot(bagId, slotIndex) then
            return true
        end
        if not DoesBagHaveSpaceFor(BAG_BACKPACK, bagId, slotIndex) then
            return false
        end
        local stackSize = ResolveStackCount(itemData, bagId, slotIndex)
        if not stackSize then return true end
        local targetSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, BAG_BACKPACK)
        if targetSlot == nil then return false end
        CallSecureProtected("PickupInventoryItem", bagId, slotIndex, stackSize)
        CallSecureProtected("PlaceInInventory", BAG_BACKPACK, targetSlot)
        return "queued"
    end, function()
        self:ExitCraftBagSelectionMode()
    end, GetString(rawget(_G, "SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG")), CRAFT_BAG_RETRIEVE_BATCH_OPTIONS)
end

--- Performs batch stow on all selected inventory items (throttled).
function Class:BatchStow()
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()
    if not allItems or #allItems == 0 then return end

    local items = {}
    for _, itemData in ipairs(allItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex
            and HasItemAtSlot(bagId, slotIndex)
            and BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag(bagId, slotIndex)
        then
            table.insert(items, itemData)
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
        if not HasItemAtSlot(bagId, slotIndex) then return true end
        if not BETTERUI.CIM.ProtectionPolicy.CanStowToCraftBag(bagId, slotIndex) then
            return true
        end
        local stackSize = ResolveStackCount(itemData, bagId, slotIndex)
        if not stackSize then return true end
        CallSecureProtected("PickupInventoryItem", bagId, slotIndex, stackSize)
        CallSecureProtected("PlaceInInventory", BAG_VIRTUAL, 0)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, GetString(rawget(_G, "SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG")), CRAFT_BAG_STOW_BATCH_OPTIONS)
end

--- Performs batch deposit on all selected items (throttled).
function Class:BatchDeposit()
    if not self.multiSelectManager then return end
    local selectedItems = self.multiSelectManager:GetSelectedItems()
    if not selectedItems or #selectedItems == 0 then return end

    local items = {}
    for _, itemData in ipairs(selectedItems) do
        local bagId, slotIndex = ExtractSlot(itemData)
        if bagId and slotIndex and HasItemAtSlot(bagId, slotIndex) then
            local targetBankBag = (BETTERUI.Banking and BETTERUI.Banking.currentUsedBank) or BAG_BANK
            if IsInventoryDepositSupported(bagId, slotIndex, targetBankBag) then
                items[#items + 1] = itemData
            end
        end
    end
    if #items == 0 then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
        if not HasItemAtSlot(bagId, slotIndex) then return true end
        local targetBankBag = (BETTERUI.Banking and BETTERUI.Banking.currentUsedBank) or BAG_BANK
        if not IsInventoryDepositSupported(bagId, slotIndex, targetBankBag) then return true end
        local destinationBag = ResolveInventoryDepositTargetBag(bagId, slotIndex)
        if not destinationBag then return false end
        local stackCount = ResolveStackCount(itemData, bagId, slotIndex)
        if not stackCount then return true end
        local destinationSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bagId, slotIndex, destinationBag)
        if destinationSlot == nil then return false end
        CallSecureProtected("RequestMoveItem", bagId, slotIndex, destinationBag, destinationSlot, stackCount)
        return "queued"
    end, function()
        self:ExitSelectionMode()
    end, "Depositing", BANK_DEPOSIT_BATCH_OPTIONS)
end

-- Common batch operations delegate to CIM.MultiSelectMixin
--- Performs batch lock on all selected items.
function Class:BatchLock()
    MultiSelectMixin.BatchLock(self)
end

--- Performs batch unlock on all selected items.
function Class:BatchUnlock()
    MultiSelectMixin.BatchUnlock(self)
end

--- Performs batch mark as junk on all selected items.
function Class:BatchMarkAsJunk()
    MultiSelectMixin.BatchMarkAsJunk(self)
end

--- Performs batch unmark as junk on all selected items.
function Class:BatchUnmarkAsJunk()
    MultiSelectMixin.BatchUnmarkAsJunk(self)
end

--- Performs batch destroy on all selected items (with confirmation).
function Class:BatchDestroy()
    if not self.multiSelectManager then return end
    local allItems = self.multiSelectManager:GetSelectedItems()
    if #allItems == 0 then return end

    local itemsToDestroy = {}
    for _, itemData in ipairs(allItems) do
        if CanDestroyInventoryItem(itemData) then
            local rawData = itemData.dataSource or itemData
            table.insert(itemsToDestroy, {
                bagId = rawData.bagId or itemData.bagId,
                slotIndex = rawData.slotIndex or itemData.slotIndex,
                slotType = rawData.slotType or itemData.slotType,
            })
        end
    end

    if #itemsToDestroy == 0 then return end

    ZO_Dialogs_ShowGamepadDialog("BETTERUI_BATCH_DESTROY_DIALOG", {
        itemCount = #itemsToDestroy,
        itemsToDestroy = itemsToDestroy,
        inventoryInstance = self,
    })
end

--------------------------------------------------------------------------------
-- BATCH DIALOGS
--------------------------------------------------------------------------------

--- Initializes the batch destroy confirmation dialog.
function Class:InitializeBatchDestroyDialog()
    BETTERUI.CIM.Dialogs.Register("BETTERUI_BATCH_DESTROY_DIALOG", {
        blockDirectionalInput = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
            allowRightStickPassThrough = true,
        },
        title = {
            text = function(dialog)
                return GetString(rawget(_G, "SI_DESTROY_ITEM_PROMPT_TITLE")) or "Destroy Items"
            end,
        },
        mainText = {
            text = function(dialog)
                local count = dialog and dialog.data and dialog.data.itemCount or 0
                return zo_strformat("Are you sure you want to destroy <<1>> selected items? This cannot be undone.",
                    count)
            end,
        },
        buttons = {
            { keybind = "DIALOG_NEGATIVE", text = GetString(rawget(_G, "SI_DIALOG_CANCEL")) },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
                callback = function(dialog)
                    local d = dialog and dialog.data
                    if d and d.itemsToDestroy and d.inventoryInstance then
                        local items = d.itemsToDestroy
                        local inventoryInstance = d.inventoryInstance

                        inventoryInstance:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
                            if not CanDestroyInventoryItem(itemData) then
                                return true
                            end
                            local destroyed = BETTERUI.Inventory.TryDestroyItem(bagId, slotIndex, true, true)
                            if not destroyed then
                                return "aborted"
                            end
                            return "queued"
                        end, function()
                            inventoryInstance:ExitSelectionMode()
                            if BETTERUI.CIM.Utils.IsInventorySceneShowing() then
                                inventoryInstance:RefreshHeader(BLOCK_TABBAR_CALLBACK)
                            end
                        end, GetString(rawget(_G, "SI_ITEM_ACTION_DESTROY")), DESTROY_BATCH_OPTIONS)
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_BATCH_DESTROY_DIALOG")
                end,
            },
        },
    })

    -- Register progress dialog for batch operations
    BETTERUI.CIM.Dialogs.Register("BETTERUI_BATCH_PROGRESS_DIALOG", {
        blockDirectionalInput = true,
        canQueue = false,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
            allowRightStickPassThrough = false,
        },
        title = {
            text = function(dialog)
                local d = dialog and dialog.data
                local actionName = d and d.actionName or "Processing"
                return actionName
            end,
        },
        mainText = {
            text = function(dialog)
                local d = dialog and dialog.data
                local current = d and d.current or 0
                local total = d and d.total or 0
                return zo_strformat("<<1>> of <<2>> items...\n\nProcessing slowly to prevent spam logout.\nPlease wait!",
                    current, total)
            end,
        },
        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_DIALOG_CANCEL")),
                callback = function(dialog)
                    ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_BATCH_PROGRESS_DIALOG")
                end,
            },
        },
    })
end
