-- Modules/Inventory/Core/InventoryMultiSelect.lua
-- Multi-select lifecycle, batch action menus, and craftbag selection mode.
-- Extracted from InventoryClass.lua for maintainability.

local Class = BETTERUI.Inventory.Class
local MultiSelectMixin = BETTERUI.CIM.MultiSelectMixin

-- Module-level dialog info references; created once and mutated before each show call.
local _batchDialogInfo = nil
local _craftBagDialogInfo = nil
local TraceInventoryBatch
local ResolveDialogEntryLabel

-- Shared frame template for both batch dialogs (title, buttons, and gamepadInfo are identical).
local function BuildBatchDialogTemplate()
    return {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title = {
            text = function(dialog)
                local count = dialog and dialog.data and dialog.data.selectedCount or 0
                return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_SELECTED_COUNT")), count)
            end,
        },
        mainText = {
            text = GetString(rawget(_G, "SI_BETTERUI_BATCH_ACTIONS_DESC")),
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        parametricList = {},
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
                callback = function(dialog)
                    local selected = dialog.entryList and
                        BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
                    if selected and selected.callback then
                        TraceInventoryBatch("action_selected", {
                            dialogName = dialog and dialog.data and dialog.data.dialogName,
                            action = ResolveDialogEntryLabel(selected),
                        })
                        selected.callback()
                    else
                        TraceInventoryBatch("action_skipped", {
                            dialogName = dialog and dialog.data and dialog.data.dialogName,
                            reason = "missingCallback",
                            action = ResolveDialogEntryLabel(selected),
                        })
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
                callback = function()
                    zo_callLater(function()
                        if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshKeybinds then
                            GAMEPAD_INVENTORY:RefreshKeybinds()
                        end
                    end, 50)
                end,
            },
        },
    }
end

local function IsInventoryBatchTraceActive()
    return BETTERUI.Log and BETTERUI.Log.IsActive and BETTERUI.Log.IsActive()
end

TraceInventoryBatch = function(phase, data)
    if not IsInventoryBatchTraceActive() then
        return
    end
    data = data or {}
    data.phase = phase
    BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.BATCH, "inventory batch menu", data)
end

local function NormalizeTraceValue(value)
    if value == nil then
        return nil
    end
    local normalize = BETTERUI.Inventory.Utils and BETTERUI.Inventory.Utils.NormalizeIdentityValue
    if normalize then
        return normalize(value)
    end
    return tostring(value)
end

local function DescribeSelectionItem(itemData, index)
    local rawData = itemData and (itemData.dataSource or itemData) or nil
    if not rawData then
        return nil
    end
    local bagId = rawData.bagId or itemData.bagId
    local slotIndex = rawData.slotIndex or itemData.slotIndex
    local stackCount
    if bagId and slotIndex and GetSlotStackSize then
        stackCount = GetSlotStackSize(bagId, slotIndex)
    end
    return {
        index = index,
        bagId = bagId,
        slotIndex = slotIndex,
        name = rawData.name or itemData.name,
        uniqueId = NormalizeTraceValue(rawData.uniqueId or itemData.uniqueId),
        stackCount = stackCount,
        selected = rawData.selected == true or itemData.selected == true,
    }
end

local function BuildSelectionSample(selectedItems, maxItems)
    if not IsInventoryBatchTraceActive() then
        return nil
    end
    local sample = {}
    local limit = math.min(#selectedItems, maxItems or 10)
    for i = 1, limit do
        sample[#sample + 1] = DescribeSelectionItem(selectedItems[i], i)
    end
    return sample
end

ResolveDialogEntryLabel = function(entry)
    local data = entry and (entry.entryData or entry) or nil
    if not data then
        return nil
    end
    if type(data.GetText) == "function" then
        local ok, label = pcall(data.GetText, data)
        if ok then
            return label
        end
    end
    return data.text or data.name or data.label
end

local function BuildDialogEntryLabels(parametricList)
    if not IsInventoryBatchTraceActive() then
        return nil
    end
    local labels = {}
    for index, entry in ipairs(parametricList or {}) do
        labels[#labels + 1] = {
            index = index,
            label = ResolveDialogEntryLabel(entry),
            hasCallback = entry and entry.entryData and type(entry.entryData.callback) == "function"
                or type(entry and entry.callback) == "function",
        }
    end
    return labels
end

-- MULTI-SELECT MODE (delegates to CIM.MultiSelectMixin)
-- The mixin is applied during InitializeKeybindStrip (InventoryKeybinds.lua).

-- Canonical pure delegate binding point for inventory selection lifecycle.
MultiSelectMixin.BindDelegates(Class, {
    "EnterSelectionMode",
    "ExitSelectionMode",
    "OnSelectionCountChanged",
    "IsInSelectionMode",
})

--- Shows the batch actions menu for multi-selected items.
---@return nil
function Class:ShowBatchActionsMenu()
    if not self.multiSelectManager or not self.multiSelectManager:IsActive() then
        TraceInventoryBatch("show_skipped", { dialogName = "BETTERUI_BATCH_ACTIONS_DIALOG", reason = "inactive" })
        return
    end

    local selectedItems = self.multiSelectManager:GetSelectedItems()
    local selectedCount = #selectedItems
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.BATCH, "Opening batch actions menu", {selectedCount = selectedCount}) end
    TraceInventoryBatch("show_request", {
        dialogName = "BETTERUI_BATCH_ACTIONS_DIALOG",
        selectedCount = selectedCount,
        selected = BuildSelectionSample(selectedItems, 10),
    })
    if selectedCount == 0 then
        TraceInventoryBatch("show_skipped", { dialogName = "BETTERUI_BATCH_ACTIONS_DIALOG", reason = "emptySelection" })
        return
    end

    -- Analyze selected items using shared mixin (lock/unlock/junk counts)
    local counts = MultiSelectMixin.AnalyzeSelectedItems(selectedItems)

    -- Inventory-specific: count stow/destroy-eligible items
    local canStowCount = 0
    local canDestroyCount = 0
    -- Resolve CanDestroyInventoryItem from the class (set by InventoryBatchOps)
    local canDestroyFn = BETTERUI.Inventory.CanDestroyInventoryItem
    local protectionPolicy = BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy
    for _, itemData in ipairs(selectedItems) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex
        if bagId and slotIndex then
            local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
            local canStow = stackCount > 0
                and protectionPolicy
                and protectionPolicy.CanStowToCraftBag
                and protectionPolicy.CanStowToCraftBag(bagId, slotIndex)
            if canStow then
                canStowCount = canStowCount + 1
            end
        end
        if canDestroyFn and canDestroyFn(itemData) then
            canDestroyCount = canDestroyCount + 1
        end
    end

    -- Build batch actions dialog (registered once through the central dialog seam)
    local dialogName = "BETTERUI_BATCH_ACTIONS_DIALOG"
    if not _batchDialogInfo then
        _batchDialogInfo = BuildBatchDialogTemplate()
        BETTERUI.CIM.Dialogs.Register(dialogName, _batchDialogInfo)
    end

    local parametricList = {}

    -- Select All (always first)
    table.insert(parametricList, MultiSelectMixin.CreateDialogEntry(
        BETTERUI.CIM.Keybinds.GetSelectAllLabel(),
        function() self:SelectAllItems() end
    ))

    -- Common batch entries from mixin (Lock, Unlock, Mark/Unmark Junk)
    MultiSelectMixin.AppendCommonBatchEntries(parametricList, counts, self)

    -- Destroy (only if setting enabled AND destroyable items exist) - Inventory-specific
    local batchDestroyEnabled = BETTERUI.Inventory.GetSetting("enableBatchDestroy") == true
    if batchDestroyEnabled and canDestroyCount > 0 then
        table.insert(parametricList, MultiSelectMixin.CreateDialogEntry(
            zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_ITEM_ACTION_DESTROY")), canDestroyCount),
            function() self:BatchDestroy() end
        ))
    end

    -- Stow (only if craftbag-eligible items exist) - Inventory-specific
    if canStowCount > 0 then
        table.insert(parametricList, MultiSelectMixin.CreateDialogEntry(
            zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG")), canStowCount),
            function() self:BatchStow() end
        ))
    end

    -- Deselect All (always last)
    table.insert(parametricList, MultiSelectMixin.CreateDialogEntry(
        BETTERUI.CIM.Keybinds.GetDeselectAllLabel(selectedCount),
        function()
            ZO_Dialogs_ReleaseDialog("BETTERUI_BATCH_ACTIONS_DIALOG")
            zo_callLater(function() self:ExitSelectionMode() end, 50)
        end
    ))

    _batchDialogInfo.parametricList = parametricList
    TraceInventoryBatch("show_dialog", {
        dialogName = dialogName,
        selectedCount = selectedCount,
        counts = counts,
        canDestroyCount = canDestroyCount,
        canStowCount = canStowCount,
        batchDestroyEnabled = batchDestroyEnabled == true,
        actions = BuildDialogEntryLabels(parametricList),
        selected = BuildSelectionSample(selectedItems, 10),
    })
    BETTERUI.CIM.Dialogs.Show(dialogName, { selectedCount = selectedCount, dialogName = dialogName })
end

-- CRAFTBAG MULTI-SELECT MODE

--- Called when craft bag selection count changes.
function Class:OnCraftBagSelectionCountChanged(selectedCount)
    if self.isInCraftBagSelectionMode and selectedCount > 0 then
        self.craftBagSelectedCount = selectedCount
        self.hadCraftBagSelections = true
    else
        self.craftBagSelectedCount = 0
    end

    if self.isInCraftBagSelectionMode and selectedCount == 0 and self.hadCraftBagSelections then
        self.hadCraftBagSelections = nil
        self:ExitCraftBagSelectionMode()
        return
    end

    if not self.isInHeaderSortMode and BETTERUI.Utils.IsInventorySceneShowing() then
        self:RefreshKeybinds()
    end
end

--- Enters selection mode for the craft bag.
function Class:EnterCraftBagSelectionMode()
    if self.isInCraftBagSelectionMode then return end
    if not self.craftBagMultiSelectManager then return end

    self.isInCraftBagSelectionMode = true
    self.craftBagMultiSelectManager:EnterSelectionMode()

    local target = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
    if target then
        self.craftBagMultiSelectManager:ToggleSelection(target)
    end

    if not self.isInHeaderSortMode then
        self:RefreshKeybinds()
    end
    self:RefreshCraftBagList()
end

--- Exits selection mode for the craft bag.
function Class:ExitCraftBagSelectionMode()
    if not self.isInCraftBagSelectionMode then return end

    self.isInCraftBagSelectionMode = false
    if self.craftBagMultiSelectManager then
        self.craftBagMultiSelectManager:ExitSelectionMode()
    end

    if BETTERUI.Utils.IsInventorySceneShowing() then
        if not self.isInHeaderSortMode then
            self:RefreshKeybinds()
        end
        self:RefreshCraftBagList()
    end
end

--- Shows the batch actions menu for multi-selected craftbag items.
function Class:ShowCraftBagBatchActionsMenu()
    if not self.craftBagMultiSelectManager or not self.craftBagMultiSelectManager:IsActive() then
        TraceInventoryBatch("show_skipped", { dialogName = "BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG", reason = "inactive" })
        return
    end

    local selectedItems = self.craftBagMultiSelectManager:GetSelectedItems()
    local selectedCount = #selectedItems
    TraceInventoryBatch("show_request", {
        dialogName = "BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG",
        selectedCount = selectedCount,
        selected = BuildSelectionSample(selectedItems, 10),
    })
    if selectedCount == 0 then
        TraceInventoryBatch("show_skipped", { dialogName = "BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG", reason = "emptySelection" })
        return
    end

    local dialogName = "BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG"
    if not _craftBagDialogInfo then
        _craftBagDialogInfo = BuildBatchDialogTemplate()
        BETTERUI.CIM.Dialogs.Register(dialogName, _craftBagDialogInfo)
    end

    local parametricList = {}

    -- Select All
    local selectAllEntry = ZO_GamepadEntryData:New(BETTERUI.CIM.Keybinds.GetSelectAllLabel())
    selectAllEntry:SetIconTintOnSelection(true)
    selectAllEntry.setup = ZO_SharedGamepadEntry_OnSetup
    selectAllEntry.callback = function()
        self:SelectAllCraftBagItems()
    end
    table.insert(parametricList, {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = selectAllEntry,
    })

    -- Retrieve
    local retrieveLabel = zo_strformat("<<1>> (<<2>>)", GetString(rawget(_G, "SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG")), selectedCount)
    local retrieveEntry = ZO_GamepadEntryData:New(retrieveLabel)
    retrieveEntry:SetIconTintOnSelection(true)
    retrieveEntry.setup = ZO_SharedGamepadEntry_OnSetup
    retrieveEntry.callback = function()
        self:BatchRetrieve()
    end
    table.insert(parametricList, {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = retrieveEntry,
    })

    -- Deselect All
    local deselectLabel = BETTERUI.CIM.Keybinds.GetDeselectAllLabel(selectedCount)
    local deselectEntry = ZO_GamepadEntryData:New(deselectLabel)
    deselectEntry:SetIconTintOnSelection(true)
    deselectEntry.setup = ZO_SharedGamepadEntry_OnSetup
    deselectEntry.callback = function()
        ZO_Dialogs_ReleaseDialog("BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG")
        zo_callLater(function()
            self:ExitCraftBagSelectionMode()
        end, 50)
    end
    table.insert(parametricList, {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = deselectEntry,
    })

    _craftBagDialogInfo.parametricList = parametricList
    TraceInventoryBatch("show_dialog", {
        dialogName = dialogName,
        selectedCount = selectedCount,
        actions = BuildDialogEntryLabels(parametricList),
        selected = BuildSelectionSample(selectedItems, 10),
    })
    BETTERUI.CIM.Dialogs.Show(dialogName, { selectedCount = selectedCount, dialogName = dialogName })
end

--- Selects all items in the current craftbag category.
function Class:SelectAllCraftBagItems()
    if not self.craftBagMultiSelectManager then return end

    self.craftBagMultiSelectManager:SelectAll(self.craftBagList)
    self:RefreshCraftBagList()
    self:RefreshKeybinds()

    ZO_Dialogs_ReleaseDialog("BETTERUI_CRAFTBAG_BATCH_ACTIONS_DIALOG")
    zo_callLater(function()
        self:ShowCraftBagBatchActionsMenu()
    end, 100)
end

--- Selects all items in the current item list category.
function Class:SelectAllItems()
    if not self.multiSelectManager then return end

    local currentList = self:GetCurrentList()
    if not currentList then return end

    self.multiSelectManager:SelectAll(currentList)

    ZO_Dialogs_ReleaseDialog("BETTERUI_BATCH_ACTIONS_DIALOG")
    zo_callLater(function()
        self:RefreshItemList()
        self:RefreshKeybinds()
        self:ShowBatchActionsMenu()
    end, 50)
end
