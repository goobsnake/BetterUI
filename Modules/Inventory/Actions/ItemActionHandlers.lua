if not BETTERUI.Inventory then BETTERUI.Inventory = {} end
if not BETTERUI.Inventory.ActionHandlers then BETTERUI.Inventory.ActionHandlers = {} end

local ActionHandlers = BETTERUI.Inventory.ActionHandlers
local actionDialogRestoreSequence = 0

local function RequireDestroyPolicyAuthorizer()
    local inventory = BETTERUI and BETTERUI.Inventory or nil
    local canDestroyItemWithPolicy = inventory and inventory.CanDestroyItemWithPolicy or nil
    if type(canDestroyItemWithPolicy) == "function" then
        return canDestroyItemWithPolicy
    end

    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before inventory action-handler destroy checks")
    local canDestroyItem = policy.CanDestroyItem
    assert(type(canDestroyItem) == "function",
        "BetterUI: CIM.ProtectionPolicy.CanDestroyItem must load before inventory action-handler destroy checks")
    return canDestroyItem
end

local function GetProtectionPolicy()
    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before inventory action-handler junk checks")
    return policy
end

local function RequireProtectionPolicyMethod(methodName)
    local policy = GetProtectionPolicy()
    local method = policy and policy[methodName] or nil
    assert(type(method) == "function",
        string.format("BetterUI: CIM.ProtectionPolicy.%s must load before inventory action-handler junk checks", tostring(methodName)))
    return method
end

local function CanJunkWithPolicy(target)
    if not target or not target.bagId or not target.slotIndex then
        return false
    end
    return RequireProtectionPolicyMethod("CanJunkItem")(target.bagId, target.slotIndex) == true
end

local function CanUnjunkWithPolicy(target)
    if not target or not target.bagId or not target.slotIndex then
        return false
    end
    return RequireProtectionPolicyMethod("CanUnjunkItem")(target.bagId, target.slotIndex) == true
end

local function BeginInventoryDialogFlow(kind, message, data)
    local L = BETTERUI.Log
    if L and L.IsActive and L.IsActive() and L.FlowBegin then
        return L.FlowBegin(kind, L.CATEGORY.ACTION, message, data)
    end
    return nil
end

local function EndInventoryDialogFlow(flow, message, data)
    local L = BETTERUI.Log
    if flow and L and L.FlowEnd then
        L.FlowEnd(flow, L.CATEGORY.ACTION, message, data)
    end
end

local function GetTargetItemName(target)
    if not (target and target.bagId and target.slotIndex and type(GetItemName) == "function") then
        return nil
    end
    local ok, name = pcall(GetItemName, target.bagId, target.slotIndex)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

local function AddTargetFields(data, target)
    data = data or {}
    if target then
        data.bag = target.bagId
        data.slot = target.slotIndex
        data.item = GetTargetItemName(target)
    end
    return data
end

local questActionFilterWarnings = {}

local function IsQuestActionTarget(target, caller)
    if type(target) ~= "table" then
        return false
    end

    local dataSource = target.dataSource or target
    if type(dataSource) ~= "table" then
        return false
    end

    local function IsQuestUniqueId(uniqueId)
        return type(uniqueId) == "string" and uniqueId:find("^quest:") ~= nil
    end

    if target.isQuestItem == true
        or dataSource.isQuestItem == true
        or dataSource.questIndex ~= nil
        or (SLOT_TYPE_QUEST_ITEM ~= nil and target.slotType == SLOT_TYPE_QUEST_ITEM)
        or (SLOT_TYPE_QUEST_ITEM ~= nil and dataSource.slotType == SLOT_TYPE_QUEST_ITEM)
        or IsQuestUniqueId(target.uniqueId)
        or IsQuestUniqueId(dataSource.uniqueId) then
        return true
    end

    if type(ZO_InventoryUtils_DoesNewItemMatchFilterType) ~= "function" or ITEMFILTERTYPE_QUEST == nil then
        return false
    end

    local ok, matches = pcall(ZO_InventoryUtils_DoesNewItemMatchFilterType, target, ITEMFILTERTYPE_QUEST)
    if ok then
        return matches == true
    end

    local warningKey = table.concat({ tostring(caller or "unknown"), tostring(matches) }, "|")
    if not questActionFilterWarnings[warningKey] and BETTERUI.Log and BETTERUI.Log.Warn then
        questActionFilterWarnings[warningKey] = true
        local L = BETTERUI.Log
        local categories = L.CATEGORY or {}
        L.Warn(categories.ACTION, "inventory quest action filter failed", {
            fn = caller or "ItemActionHandlers.IsQuestActionTarget",
            error = tostring(matches),
            item = L.DescribeItem and L.DescribeItem(dataSource, "target") or nil,
        })
    end

    return false
end

local function ResolveActionText(row)
    if not row then return nil end
    if type(row.GetText) == "function" then
        local ok, text = pcall(function() return row:GetText() end)
        if ok and text ~= nil then return text end
    end
    return row.text or row.name or row.actionName
end

local function LogActionDialogRestore(message, data, warn)
    local L = BETTERUI.Log
    if not L then return end
    if L.TraceEvent then
        local phase = "state"
        if message and message:find("complete", 1, true) then
            phase = "complete"
        elseif message and message:find("waiting", 1, true) then
            phase = "waiting"
        elseif message and message:find("skipped", 1, true) then
            phase = "skipped"
        elseif message and message:find("abandoned", 1, true) then
            phase = "abandoned"
        end
        L.TraceEvent(L.CATEGORY.STATE, "inventory.action_dialog.restore", phase, data, warn and L.LEVEL.WARN or L.LEVEL.INFO)
    end
    if warn and L.Warn then
        L.Warn(L.CATEGORY.STATE, message, data)
    elseif L.Debug then
        L.Debug(L.CATEGORY.STATE, message, data)
    end
end

local function TraceInventoryActionDialog(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    L.TraceEvent(L.CATEGORY.ACTION, event, phase, data)
end

local function BuildDestroyTracePayloadFromTarget(targetData, data)
    data = data or {}
    local bag, slot
    if targetData and type(ZO_Inventory_GetBagAndIndex) == "function" then
        local ok, resolvedBag, resolvedSlot = pcall(ZO_Inventory_GetBagAndIndex, targetData)
        if ok then
            bag, slot = resolvedBag, resolvedSlot
        end
    end
    local ds = targetData and (targetData.dataSource or targetData) or nil
    data.bagId = data.bagId or bag
    data.slotIndex = data.slotIndex or slot
    data.slotType = data.slotType or (ds and ds.slotType) or (targetData and targetData.slotType)
    data.dialogName = data.dialogName or ZO_GAMEPAD_INVENTORY_ACTION_DIALOG
    if BETTERUI.Log and BETTERUI.Log.DescribeItem and targetData and not data.target then
        data.target = BETTERUI.Log.DescribeItem(targetData, "target")
    end
    return data, bag, slot, data.slotType
end

local function TraceInventoryDestroyAction(phase, targetData, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    local payload = BuildDestroyTracePayloadFromTarget(targetData, data)
    payload.feature = payload.feature or "destroy"
    L.TraceEvent(L.CATEGORY.ACTION, "inventory.destroy", phase, payload, L.LEVEL.INFO)
end

local function TraceInventoryConfirmBranch(phase, branch, targetData, data)
    data = BuildDestroyTracePayloadFromTarget(targetData, data or {})
    data.branch = branch
    data.feature = data.feature or "action-dialog-confirm"
    TraceInventoryActionDialog("inventory.action_dialog.confirm_branch", phase, data)
end

local function ToggleJunkState(self, isJunk, target, expectedSlotIdentity)
    if self and self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        TraceInventoryActionDialog("inventory.junk_toggle", "skipped", {
            reason = "craftBagMode",
            requestedJunk = isJunk == true,
        })
        return
    end
    -- Prefer the target captured when the dialog entry was built: in category
    -- mode the dialog target differs from the itemList selection.
    target = target or BETTERUI.Inventory.Utils.SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
    if not target then
        TraceInventoryActionDialog("inventory.junk_toggle", "skipped", {
            reason = "missingTarget",
            requestedJunk = isJunk == true,
        })
        return
    end

    -- Slot identity gate (mirrors destroy/equip): the action dialog can stay
    -- open across inventory updates, so cancel instead of junk-toggling a slot
    -- that no longer holds the item the entry was built for.
    if expectedSlotIdentity
        and BETTERUI.Inventory.Utils.IsSlotIdentityCurrent(expectedSlotIdentity, target.bagId, target.slotIndex) ~= true then
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "inventory junk toggle cancelled stale slot", {
                bag = target.bagId,
                slot = target.slotIndex,
                junk = isJunk == true,
            })
        end
        TraceInventoryActionDialog("inventory.junk_toggle", "blocked", AddTargetFields({
            reason = "staleSlot",
            requestedJunk = isJunk == true,
            expectedSlotIdentity = expectedSlotIdentity,
        }, target))
        BETTERUI.CIM.UserNotify("ItemActionHandlers:JunkStaleSlot",
            GetString(rawget(_G, "SI_BETTERUI_ITEM_CHANGED_CANCELLED")))
        return
    end

    local canToggleJunk
    if isJunk then
        canToggleJunk = CanJunkWithPolicy(target)
    else
        canToggleJunk = CanUnjunkWithPolicy(target)
    end
    if not canToggleJunk then
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "inventory junk toggle denied", {
                bag = target.bagId,
                slot = target.slotIndex,
                junk = isJunk == true,
            })
        end
        TraceInventoryActionDialog("inventory.junk_toggle", "blocked", AddTargetFields({
            reason = "protectionPolicy",
            requestedJunk = isJunk == true,
        }, target))
        return
    end

    TraceInventoryActionDialog("inventory.junk_toggle", "before", AddTargetFields({
        requestedJunk = isJunk == true,
        expectedSlotIdentity = expectedSlotIdentity,
    }, target))
    local flow = BeginInventoryDialogFlow("inventoryJunk", "inventory dialog junk toggle requested", AddTargetFields({
        junk = isJunk == true,
    }, target))
    SetItemIsJunk(target.bagId, target.slotIndex, isJunk)

    if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
    end
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.InvalidateSlotDataCache then
        GAMEPAD_INVENTORY:InvalidateSlotDataCache()
    end
    EndInventoryDialogFlow(flow, "inventory dialog junk toggle cache invalidated; waiting for inventory update", AddTargetFields({
        junk = isJunk == true,
        refresh = "inventoryUpdate",
    }, target))
    TraceInventoryActionDialog("inventory.junk_toggle", "after", AddTargetFields({
        requestedJunk = isJunk == true,
        refresh = "inventoryUpdate",
        releasedDialog = true,
    }, target))
    -- PB-002: Do NOT perform keybind/list restoration synchronously here. The
    -- gamepad action dialog wraps its lifetime in KEYBIND_STRIP:PushKeybindGroupState()
    -- (on show) / PopKeybindGroupState() (on hide). This handler runs while the
    -- dialog's pushed state is still the top state, so any RefreshItemActions /
    -- RefreshKeybinds / SetActiveKeybinds / EnsureHeaderKeybindsActive call here
    -- mutates the pushed (top) keybind state and corrupts the snapshot that Pop
    -- restores -- which silently drops the ethereal LB/RB carousel keybind group
    -- (BETTERUI_TabBarScrollList.keybindStripDescriptor) after the dialog closes.
    -- The deferred OnFinish -> RestoreInventoryAfterDialog path (which runs AFTER
    -- Pop) is the correct place for keybind/list restoration, so we rely on it.
end

local function ResolveCurrentTarget(self)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "Resolving target for item action", {mode = self.actionMode}) end
    local actionMode = self.actionMode
    if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        return self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
    elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        return self.craftBagList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
    elseif actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
        local catData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
        return catData and self:GenerateItemSlotData(catData)
    end
    return nil
end

local function CanDestroyTargetData(targetData)
    if not targetData then
        return false
    end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(targetData)
    if not bagId or not slotIndex then
        return false
    end

    local ds = targetData.dataSource or targetData
    local slotType = ds and ds.slotType or targetData.slotType
    if BETTERUI.Inventory and BETTERUI.Inventory.CanDestroyItemWithPolicy then
        return BETTERUI.Inventory.CanDestroyItemWithPolicy(bagId, slotIndex, slotType)
    end

    return RequireDestroyPolicyAuthorizer()(bagId, slotIndex, slotType) == true
end

function ActionHandlers.OnSetup(self, dialog, data)
    if not self.scene:IsShowing() then return end

    dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
        self.itemActions:SetSelectedAction(selectedData and selectedData.action)
    end)

    local parametricList = dialog.info.parametricList
    ZO_ClearNumericallyIndexedTable(parametricList)

    local target = ResolveCurrentTarget(self)
    TraceInventoryActionDialog("inventory.action_dialog.handler", "setup_before", {
        actionMode = self.actionMode,
        target = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(target, "target") or nil,
        selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(self:GetCurrentList(), "selection") or nil,
    })

    if self.itemActions and self.itemActions.SetInventorySlot and target then
        if target and not target.slotType then
            target.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
        end
        self.itemActions:SetInventorySlot(target)
    end

    if self.itemActions and self.itemActions.slotActions and target then
        local innerSlotActions = self.itemActions.slotActions
        innerSlotActions:Clear()
        innerSlotActions:SetInventorySlot(target)
        if not target.slotType then target.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM end
        ZO_InventorySlot_DiscoverSlotActionsFromActionList(target, innerSlotActions)
    end

    self:RefreshItemActions()

    local titleText = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND"))
    local markAsJunkName = GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
    local unmarkAsJunkName = GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK)
    local betterMarkAsJunkName = GetString(SI_BETTERUI_ACTION_MARK_AS_JUNK)
    local betterUnmarkAsJunkName = GetString(SI_BETTERUI_ACTION_UNMARK_AS_JUNK)
    local showJunkToggleEntry = false
    local junkToggleEntryText = nil
    local junkToggleEntryCallback = nil
    local headerData = { titleText = titleText }
    ZO_GamepadGenericHeader_RefreshData(dialog.header, headerData)

    local isLocked = target and target.bagId and target.slotIndex
        and BETTERUI.CIM.ProtectionPolicy.IsItemPlayerLocked(target.bagId, target.slotIndex)
        or false
    local canMarkJunk = target and CanJunkWithPolicy(target)

    local isQuestItem = false
    if target then
        isQuestItem = IsQuestActionTarget(target, "ItemActionHandlers.OnSetup")
    end

    local canDestroyTarget = target and CanDestroyTargetData(target) or false

    if not isQuestItem then
        local isJunk = false
        if target and target.bagId and target.slotIndex and IsItemJunk then
            isJunk = IsItemJunk(target.bagId, target.slotIndex) == true
        end

        -- Capture the slot identity alongside the target so the deferred
        -- toggle can be cancelled if the slot changes while the dialog is up
        -- (mirrors destroy/equip).
        local expectedSlotIdentity = target and target.bagId and target.slotIndex
            and BETTERUI.Inventory.Utils.CaptureSlotIdentity(target.bagId, target.slotIndex, target)
            or nil

        if isJunk then
            showJunkToggleEntry = true
            junkToggleEntryText = betterUnmarkAsJunkName
            junkToggleEntryCallback = function() ToggleJunkState(self, false, target, expectedSlotIdentity) end
        elseif not isLocked and canMarkJunk then
            showJunkToggleEntry = true
            junkToggleEntryText = betterMarkAsJunkName
            junkToggleEntryCallback = function() ToggleJunkState(self, true, target, expectedSlotIdentity) end
        end
    end

    do
        local actions = self.itemActions:GetSlotActions()
        local numActions = actions:GetNumSlotActions()
        for i = 1, numActions do
            local action = actions:GetSlotAction(i)
            local actionName = actions:GetRawActionName(action)
            if actionName == GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_LOCKED"))
                or actionName == GetString(rawget(_G, "SI_ITEM_ACTION_UNMARK_AS_LOCKED")) then
                for j, slotAction in ipairs(actions.m_slotActions) do
                    if slotAction and slotAction[1] == actionName then
                        local origCallback = slotAction[2]
                        slotAction[2] = function(...)
                            if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                            end
                            if origCallback then origCallback(...) end
                        end
                        break
                    end
                end
            end
        end
    end

    local actions = self.itemActions:GetSlotActions()
    local numActions = actions:GetNumSlotActions()
    for i = 1, numActions do
        local action = actions:GetSlotAction(i)
        local actionName = actions:GetRawActionName(action)

        local hideDestroy = BETTERUI.Utils.IsBankingSceneShowing() or (target and not canDestroyTarget)
        local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
        local hideMarkJunk = false
        do
            local t = (self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE)
                and (self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList))
                or nil
            if t and actionName == GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_JUNK")) then
                hideMarkJunk = not CanJunkWithPolicy(t)
            end
        end

        local isStowOrRetrieve = (actionName == GetString(rawget(_G, "SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG")))
            or (actionName == GetString(rawget(_G, "SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG")))
        local isConvertStyle = (actionName == GetString(rawget(_G, "SI_ITEM_ACTION_CONVERT_TO_IMPERIAL_STYLE")))
            or (actionName == GetString(rawget(_G, "SI_ITEM_ACTION_CONVERT_TO_MORAG_TONG_STYLE")))
        local isJunkToggleAction = actionName == markAsJunkName
            or actionName == unmarkAsJunkName
            or actionName == betterMarkAsJunkName
            or actionName == betterUnmarkAsJunkName

        if not (hideDestroy and isDestroy)
            and not hideMarkJunk
            and not isJunkToggleAction
            and not isStowOrRetrieve
            and not isConvertStyle then
            local entryData = ZO_GamepadEntryData:New(actionName)
            entryData:SetIconTintOnSelection(true)
            entryData.action = action
            entryData.setup = ZO_SharedGamepadEntry_OnSetup
            table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
        end
    end

    if showJunkToggleEntry and junkToggleEntryText and junkToggleEntryCallback then
        local junkToggleEntry = ZO_GamepadEntryData:New(junkToggleEntryText)
        junkToggleEntry:SetIconTintOnSelection(true)
        junkToggleEntry.isJunkToggleAction = true
        junkToggleEntry.junkToggleCallback = junkToggleEntryCallback
        junkToggleEntry.setup = ZO_SharedGamepadEntry_OnSetup
        table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = junkToggleEntry })
    end

    if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        local itemTarget = self.itemList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
        if itemTarget and itemTarget.bagId and itemTarget.slotIndex then
            local stackCount = GetSlotStackSize(itemTarget.bagId, itemTarget.slotIndex) or 1
            local canStow = BETTERUI.CIM.CanItemMoveToCraftBag(itemTarget)
            if canStow and stackCount > 1 then
                local e = ZO_GamepadEntryData:New(GetString(rawget(_G, "SI_BETTERUI_STOW_STACK")))
                e:SetIconTintOnSelection(true)
                e.isStowStackAction = true
                e.itemTarget = itemTarget
                e.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, 1, { template = "ZO_GamepadItemEntryTemplate", entryData = e })
            end
        end
    end

    if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        local craftBagTarget = self.craftBagList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
        if craftBagTarget and craftBagTarget.bagId and craftBagTarget.slotIndex then
            local stackCount = GetSlotStackSize(craftBagTarget.bagId, craftBagTarget.slotIndex) or 1
            if stackCount > 1 then
                local e = ZO_GamepadEntryData:New(GetString(rawget(_G, "SI_BETTERUI_RETRIEVE_STACK")))
                e:SetIconTintOnSelection(true)
                e.isRetrieveStackAction = true
                e.itemTarget = craftBagTarget
                e.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, 1, { template = "ZO_GamepadItemEntryTemplate", entryData = e })
            end
        end
    end

    local showSortEntry = false
    local currentList = nil
    local sortContext = nil
    if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
        currentList = self.itemList
        sortContext = self
        showSortEntry = true
    elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
        currentList = self.craftBagList
        sortContext = self
        showSortEntry = true
    elseif BETTERUI.Utils.IsBankingSceneShowing() then
        local getBankingSortContext = BETTERUI.Banking and BETTERUI.Banking.GetSortEntryContext or nil
        local bankingSortContext = type(getBankingSortContext) == "function" and getBankingSortContext() or nil
        if bankingSortContext then
            currentList = bankingSortContext.list
            sortContext = bankingSortContext.sortContext
            showSortEntry = true
        end
    end

    if showSortEntry and sortContext and sortContext.EnterHeaderSortMode
        and currentList and not currentList:IsEmpty() then
        local sortEntry = ZO_GamepadEntryData:New(GetString(rawget(_G, "SI_BETTERUI_HEADER_SORT")))
        sortEntry:SetIconTintOnSelection(true)
        sortEntry.isSortAction = true
        sortEntry.sortContext = sortContext
        sortEntry.setup = ZO_SharedGamepadEntry_OnSetup
        table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = sortEntry })
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "inventory dialog sort entry added", {
                fn = "ItemActionHandlers.OnSetup",
                actionMode = self.actionMode,
                headerSort = sortContext.isInHeaderSortMode == true,
                listItems = currentList.GetNumItems and currentList:GetNumItems() or nil,
                main = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(sortContext.mainKeybindStripDescriptor, "main") or nil,
            })
        end
    end

    local getHelpName = GetString(rawget(_G, "SI_ITEM_ACTION_REPORT_ITEM"))
    local getHelpIndex = nil
    for i, entry in ipairs(parametricList) do
        if entry.entryData and entry.entryData.GetText and entry.entryData:GetText() == getHelpName then
            getHelpIndex = i
            break
        end
    end
    if getHelpIndex and getHelpIndex < #parametricList then
        local getHelpEntry = table.remove(parametricList, getHelpIndex)
        table.insert(parametricList, getHelpEntry)
    end

    dialog:setupFunc()
    TraceInventoryActionDialog("inventory.action_dialog.handler", "setup_after", {
        actionMode = self.actionMode,
        entryCount = #parametricList,
        selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
    })
end

function ActionHandlers.OnFinish(self, dialog)
    local closeCause = dialog and dialog._betteruiCloseCause or "dismissed"
    local waitLogged = false
    local function RestoreInventoryAfterDialog()
        if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
            if not waitLogged then
                waitLogged = true
                LogActionDialogRestore("inventory dialog finish restore waiting", {
                    actionMode = self.actionMode,
                    closeCause = closeCause,
                    reason = "dialogShowing",
                    dialogsShowing = true,
                    pendingHeaderSort = self._pendingHeaderSortFromDialog == true,
                })
            end
            return false
        end

        local pendingHeaderSort = self._pendingHeaderSortFromDialog == true
        local sceneShowing = (self.scene and self.scene:IsShowing())
            or (BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.IsInventorySceneShowing and
                BETTERUI.CIM.Utils.IsInventorySceneShowing())
        if not sceneShowing then
            LogActionDialogRestore("inventory dialog finish restore skipped", {
                actionMode = self.actionMode,
                closeCause = closeCause,
                reason = "sceneHidden",
                pendingHeaderSort = pendingHeaderSort,
            })
            return true
        end

        if self.isInCraftBagSelectionMode and self.RefreshCraftBagList then
            self:RefreshCraftBagList()
        elseif self.isInSelectionMode and self.RefreshItemList then
            self:RefreshItemList()
        end

        if not self.isInHeaderSortMode and not pendingHeaderSort then
            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
        end

        if self.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE and not pendingHeaderSort then
            local currentList = self:GetCurrentList()
            if currentList then
                local targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(currentList)
                if currentList == self.categoryList then
                    targetData = self:GenerateItemSlotData(targetData)
                end
                self:SetSelectedItemUniqueId(targetData)
            end
            self:RefreshCategoryList()
        elseif not pendingHeaderSort then
            self:RefreshItemActions()
        end

        if not self.isInHeaderSortMode and not pendingHeaderSort then
            self:RefreshKeybinds()
        end

        -- Dialogs deactivate the header tab bar; reactivate it so LB/RB keep
        -- paging the category carousel after any action-dialog flow.
        if self.EnsureHeaderKeybindsActive and not self.isInHeaderSortMode and not pendingHeaderSort then
            self:EnsureHeaderKeybindsActive()
        end
        LogActionDialogRestore("inventory dialog finish restore complete", {
            actionMode = self.actionMode,
            closeCause = closeCause,
            headerSort = self.isInHeaderSortMode == true,
            pendingHeaderSort = pendingHeaderSort,
            skippedKeybindRestore = pendingHeaderSort,
            main = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or nil,
        })
        return true
    end

    if RestoreInventoryAfterDialog() then
        return
    end

    local retriesRemaining = 120
    actionDialogRestoreSequence = actionDialogRestoreSequence + 1
    local retryTaskName = "actionDialogFinishRestore_" ..
        tostring((GetGameTimeMilliseconds and GetGameTimeMilliseconds()) or 0) ..
        "_" .. tostring(actionDialogRestoreSequence)
    local function RetryRestore()
        if RestoreInventoryAfterDialog() then
            return
        end
        retriesRemaining = retriesRemaining - 1
        if retriesRemaining <= 0 then
            LogActionDialogRestore("inventory dialog finish restore abandoned", {
                actionMode = self.actionMode,
                closeCause = closeCause,
                reason = "retry_exhausted",
                pendingHeaderSort = self._pendingHeaderSortFromDialog == true,
                retryTaskName = retryTaskName,
            }, true)
            return
        end
        if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Schedule then
            BETTERUI.Inventory.Tasks:Schedule(retryTaskName, 50, RetryRestore)
        else
            zo_callLater(RetryRestore, 50)
        end
    end

    RetryRestore()
end

function ActionHandlers.OnConfirm(self, dialog)
    if not (self.scene and self.scene:IsShowing()) then return end

    local currentList = self:GetCurrentList()
    if currentList and currentList.selectedIndex then
        local targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(currentList)
        if targetData then
            targetData.savedIndex = currentList.selectedIndex
            self.currentlySelectedData = targetData
        end
    end

    local selectedRow = dialog.entryList and BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
    local confirmedTarget = dialog and dialog.data and dialog.data.target or ResolveCurrentTarget(self)
    TraceInventoryActionDialog("inventory.action_dialog.handler", "confirm", {
        actionMode = self.actionMode,
        action = selectedRow and ResolveActionText(selectedRow) or nil,
        sort = selectedRow and selectedRow.isSortAction == true,
        junk = selectedRow and selectedRow.isJunkToggleAction == true,
        stow = selectedRow and selectedRow.isStowStackAction == true,
        retrieve = selectedRow and selectedRow.isRetrieveStackAction == true,
        target = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(confirmedTarget, "target") or nil,
        selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
    })
    if selectedRow and BETTERUI.Log and BETTERUI.Log.Info then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "inventory dialog action confirmed", AddTargetFields({
            action = ResolveActionText(selectedRow),
            sort = selectedRow.isSortAction == true,
            junk = selectedRow.isJunkToggleAction == true,
            stow = selectedRow.isStowStackAction == true,
            retrieve = selectedRow.isRetrieveStackAction == true,
        }, confirmedTarget))
    end

    if selectedRow and selectedRow.isSortAction then
        local sortContext = selectedRow.sortContext or self
        self._pendingHeaderSortFromDialog = true
        if sortContext then
            sortContext._pendingHeaderSortFromDialog = true
        end
        TraceInventoryActionDialog("inventory.action_dialog.sort", "release_dialog", {
            actionMode = self.actionMode,
            pendingHeaderSort = true,
            selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
        })
        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "inventory dialog sort confirmed", {
                fn = "ItemActionHandlers.OnConfirm",
                actionMode = self.actionMode,
                headerSort = sortContext and sortContext.isInHeaderSortMode == true,
                main = BETTERUI.Log.DescribeKeybindDescriptor and sortContext and BETTERUI.Log.DescribeKeybindDescriptor(sortContext.mainKeybindStripDescriptor, "main") or nil,
            })
        end
        if sortContext and sortContext.EnterHeaderSortMode then
            -- Defer until the action dialog has fully released its keybind state. Calling
            -- EnterHeaderSortMode synchronously here applies the header-sort keybind swap to the
            -- dialog's (about-to-pop) keybind state, so the sort keybinds are discarded when the
            -- dialog closes and the strip falls back to the inventory keybinds.
            local attempts = 60
            local function EnterSortWhenDialogClosed()
                attempts = attempts - 1
                if attempts > 0 and ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
                    TraceInventoryActionDialog("inventory.action_dialog.sort", "waiting_for_close", {
                        attempts = attempts,
                        headerSort = sortContext and sortContext.isInHeaderSortMode == true,
                        pendingHeaderSort = sortContext and sortContext._pendingHeaderSortFromDialog == true,
                        main = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptor and sortContext and BETTERUI.Log.DescribeKeybindDescriptor(sortContext.mainKeybindStripDescriptor, "main") or nil,
                    })
                    if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Schedule then
                        BETTERUI.Inventory.Tasks:Schedule("enterHeaderSortAfterDialog", 10, EnterSortWhenDialogClosed)
                        return
                    elseif type(zo_callLater) == "function" then
                        zo_callLater(EnterSortWhenDialogClosed, 10)
                        return
                    end
                    if sortContext then
                        sortContext._pendingHeaderSortFromDialog = nil
                    end
                    if sortContext ~= self then
                        self._pendingHeaderSortFromDialog = nil
                    end
                    TraceInventoryActionDialog("inventory.action_dialog.sort", "enter_skipped", {
                        reason = "missingScheduler",
                        attemptsRemaining = attempts,
                        headerSort = sortContext and sortContext.isInHeaderSortMode == true,
                        pendingHeaderSort = false,
                    })
                    return
                end
                local entered = sortContext:EnterHeaderSortMode()
                if sortContext then
                    sortContext._pendingHeaderSortFromDialog = nil
                end
                if sortContext ~= self then
                    self._pendingHeaderSortFromDialog = nil
                end
                TraceInventoryActionDialog("inventory.action_dialog.sort", "enter_attempted", {
                    entered = entered == true,
                    attemptsRemaining = attempts,
                    headerSort = sortContext and sortContext.isInHeaderSortMode == true,
                    pendingHeaderSort = false,
                    main = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptor and sortContext and BETTERUI.Log.DescribeKeybindDescriptor(sortContext.mainKeybindStripDescriptor, "main") or nil,
                })
            end
            EnterSortWhenDialogClosed()
        else
            if sortContext then
                sortContext._pendingHeaderSortFromDialog = nil
            end
            if sortContext ~= self then
                self._pendingHeaderSortFromDialog = nil
            end
            TraceInventoryActionDialog("inventory.action_dialog.sort", "enter_skipped", {
                reason = "missingSortContext",
                pendingHeaderSort = false,
            })
        end
        return
    end

    if selectedRow and selectedRow.isStowStackAction then
        local itemTarget = selectedRow.itemTarget
        TraceInventoryActionDialog("inventory.action_dialog.confirm_branch", "before", {
            branch = "stow_stack",
            target = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(itemTarget, "target") or nil,
        })
        local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        if itemTarget then
            BETTERUI.Inventory.InvokeDialog("StowFullStack", itemTarget)
        end
        TraceInventoryActionDialog("inventory.action_dialog.confirm_branch", "after", {
            branch = "stow_stack",
            invoked = itemTarget ~= nil,
            releaseReturned = released ~= nil,
            target = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(itemTarget, "target") or nil,
        })
        return
    end

    if selectedRow and selectedRow.isRetrieveStackAction then
        local itemTarget = selectedRow.itemTarget
        TraceInventoryActionDialog("inventory.action_dialog.confirm_branch", "before", {
            branch = "retrieve_stack",
            target = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(itemTarget, "target") or nil,
        })
        local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        if itemTarget then
            BETTERUI.Inventory.InvokeDialog("RetrieveFullStack", itemTarget)
        end
        TraceInventoryActionDialog("inventory.action_dialog.confirm_branch", "after", {
            branch = "retrieve_stack",
            invoked = itemTarget ~= nil,
            releaseReturned = released ~= nil,
            target = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(itemTarget, "target") or nil,
        })
        return
    end

    if selectedRow and selectedRow.isJunkToggleAction then
        TraceInventoryActionDialog("inventory.action_dialog.confirm_branch", "before", {
            branch = "junk_toggle",
            target = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(confirmedTarget, "target") or nil,
        })
        local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        if selectedRow.junkToggleCallback then
            selectedRow.junkToggleCallback()
        end
        TraceInventoryActionDialog("inventory.action_dialog.confirm_branch", "after", {
            branch = "junk_toggle",
            invoked = selectedRow.junkToggleCallback ~= nil,
            releaseReturned = released ~= nil,
        })
        return
    end

    if selectedRow and selectedRow.isBetterUIDestroy then
        local targetData
        if dialog and dialog.data and dialog.data.target then
            targetData = dialog.data.target
        elseif dialog.entryList and dialog.entryList.GetTargetData then
            targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
        else
            targetData = ResolveCurrentTarget(self)
        end
        if not targetData then
            TraceInventoryDestroyAction("blocked", nil, {
                source = "managed",
                reason = "missingTarget",
                actionMode = self.actionMode,
            })
            return
        end
        local okSlot, bag, slot = pcall(ZO_Inventory_GetBagAndIndex, targetData)
        if not okSlot or not bag or not slot then
            TraceInventoryDestroyAction("blocked", targetData, {
                source = "managed",
                reason = "invalidSlot",
                actionMode = self.actionMode,
                error = okSlot and nil or tostring(bag),
            })
            return
        end
        if bag and slot then
            local quick = BETTERUI.GetSetting("Inventory", "quickDestroy", false) == true
            TraceInventoryDestroyAction("action_dialog_selected", targetData, {
                source = "managed",
                quickDestroy = quick,
            })
            if not CanDestroyTargetData(targetData) then
                TraceInventoryDestroyAction("blocked", targetData, {
                    source = "managed",
                    reason = "protectionPolicy",
                    quickDestroy = quick,
                })
                return
            end
            local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local ds = targetData.dataSource or targetData
            local slotType = ds and ds.slotType or targetData.slotType
            local link = GetItemLink(bag, slot)
            TraceInventoryDestroyAction("action_dialog_released", targetData, {
                source = "managed",
                quickDestroy = quick,
                releaseReturned = released ~= nil,
            })
            if quick then
                TraceInventoryDestroyAction("quick_requested", targetData, {
                    source = "managed",
                    slotType = slotType,
                })
                BETTERUI.Inventory.TryDestroyItem(bag, slot, true, false, slotType)
            else
                local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bag, slot, targetData)
                TraceInventoryDestroyAction("confirm_dialog_request", targetData, {
                    source = "managed",
                    slotType = slotType,
                    itemLink = link,
                    expectedSlotIdentity = expectedSlotIdentity,
                    dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
                })
                local shownDialog = ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
                    {
                        bagId = bag,
                        slotIndex = slot,
                        slotType = slotType,
                        itemLink = link,
                        expectedSlotIdentity = expectedSlotIdentity,
                    }, nil, true, true)
                TraceInventoryDestroyAction("confirm_dialog_show", targetData, {
                    source = "managed",
                    slotType = slotType,
                    itemLink = link,
                    expectedSlotIdentity = expectedSlotIdentity,
                    dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
                    showReturnedDialog = shownDialog ~= nil,
                    showingAfter = ZO_Dialogs_IsShowing and ZO_Dialogs_IsShowing("BETTERUI_CONFIRM_DESTROY_DIALOG") == true or nil,
                })
            end
        end
        return
    end

    local selectedActionName = selectedRow and selectedRow.text or nil

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_SPLIT_STACK")) then
        local targetData = ResolveCurrentTarget(self)
        if targetData and ZO_InventorySlot_TrySplitStack then
            local payload = BuildDestroyTracePayloadFromTarget(targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
            })
            payload.feature = "splitStack"
            TraceInventoryActionDialog("inventory.split_stack", "requested", payload)
            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            ZO_InventorySlot_TrySplitStack(targetData)
            payload.actionDialogReleased = true
            TraceInventoryActionDialog("inventory.split_stack", "dispatched", payload)
        else
            TraceInventoryActionDialog("inventory.split_stack", "blocked", {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                reason = not targetData and "missingTarget" or "missingTrySplitStack",
            })
        end
        return
    end

    if selectedActionName == GetString(SI_ITEM_ACTION_DESTROY) then
        local targetData = ResolveCurrentTarget(self)
        if not targetData then
            TraceInventoryDestroyAction("blocked", nil, {
                source = "native_action_name",
                reason = "missingTarget",
                actionMode = self.actionMode,
            })
            return
        end
        local okSlot, bag, slot = pcall(ZO_Inventory_GetBagAndIndex, targetData)
        if not okSlot or not bag or not slot then
            TraceInventoryDestroyAction("blocked", targetData, {
                source = "native_action_name",
                reason = "invalidSlot",
                actionMode = self.actionMode,
                error = okSlot and nil or tostring(bag),
            })
            return
        end
        if bag and slot then
            local quick = BETTERUI.GetSetting("Inventory", "quickDestroy", false) == true
            TraceInventoryDestroyAction("action_dialog_selected", targetData, {
                source = "native_action_name",
                quickDestroy = quick,
            })
            if not CanDestroyTargetData(targetData) then
                TraceInventoryDestroyAction("blocked", targetData, {
                    source = "native_action_name",
                    reason = "protectionPolicy",
                    quickDestroy = quick,
                })
                return
            end
            local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local ds = targetData.dataSource or targetData
            local slotType = ds and ds.slotType or targetData.slotType
            local link = GetItemLink(bag, slot)
            TraceInventoryDestroyAction("action_dialog_released", targetData, {
                source = "native_action_name",
                quickDestroy = quick,
                releaseReturned = released ~= nil,
            })
            if quick then
                TraceInventoryDestroyAction("quick_requested", targetData, {
                    source = "native_action_name",
                    slotType = slotType,
                })
                BETTERUI.Inventory.TryDestroyItem(bag, slot, true, false, slotType)
            else
                local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bag, slot, targetData)
                TraceInventoryDestroyAction("confirm_dialog_request", targetData, {
                    source = "native_action_name",
                    slotType = slotType,
                    itemLink = link,
                    expectedSlotIdentity = expectedSlotIdentity,
                    dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
                })
                local shownDialog = ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
                    {
                        bagId = bag,
                        slotIndex = slot,
                        slotType = slotType,
                        itemLink = link,
                        expectedSlotIdentity = expectedSlotIdentity,
                    }, nil, true, true)
                TraceInventoryDestroyAction("confirm_dialog_show", targetData, {
                    source = "native_action_name",
                    slotType = slotType,
                    itemLink = link,
                    expectedSlotIdentity = expectedSlotIdentity,
                    dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
                    showReturnedDialog = shownDialog ~= nil,
                    showingAfter = ZO_Dialogs_IsShowing and ZO_Dialogs_IsShowing("BETTERUI_CONFIRM_DESTROY_DIALOG") == true or nil,
                })
            end
        end
        return
    end

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")) then
        local isCompanionScene = SCENE_MANAGER and SCENE_MANAGER.scenes
            and SCENE_MANAGER.scenes["companionEquipmentGamepad"]
            and SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
        if isCompanionScene then
            TraceInventoryConfirmBranch("skipped", "link_to_chat", nil, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                reason = "companionScene",
            })
            return
        end
        local targetData = ResolveCurrentTarget(self)
        TraceInventoryConfirmBranch("before", "link_to_chat", targetData, {
            source = "action_dialog",
            selectedActionName = selectedActionName,
        })
        local okSlot, bag, slot = pcall(ZO_Inventory_GetBagAndIndex, targetData)
        if not okSlot or not bag or not slot then
            TraceInventoryConfirmBranch("blocked", "link_to_chat", targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                reason = okSlot and "missingSlot" or "slotLookupFailed",
                error = okSlot and nil or tostring(bag),
            })
            return
        end
        if bag and slot then
            local itemLink = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
            if itemLink and itemLink ~= "" then
                ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink))
                TraceInventoryConfirmBranch("after", "link_to_chat", targetData, {
                    source = "action_dialog",
                    selectedActionName = selectedActionName,
                    itemLink = itemLink,
                    inserted = true,
                })
            else
                TraceInventoryConfirmBranch("blocked", "link_to_chat", targetData, {
                    source = "action_dialog",
                    selectedActionName = selectedActionName,
                    reason = "missingItemLink",
                })
            end
        end
        return
    end

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_EQUIP")) then
        local targetData = ResolveCurrentTarget(self)
        TraceInventoryConfirmBranch("before", "equip", targetData, {
            source = "action_dialog",
            selectedActionName = selectedActionName,
        })
        if targetData and targetData.dataSource then
            local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            self:TryEquipItem(targetData, true)
            TraceInventoryConfirmBranch("after", "equip", targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                actionDialogReleased = true,
                releaseReturned = released ~= nil,
                dispatched = true,
            })
        else
            TraceInventoryConfirmBranch("blocked", "equip", targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                reason = targetData and "missingDataSource" or "missingTarget",
            })
        end
        return
    end

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_USE"))
        or selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_SHOW_MAP"))
        or selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_SKILL_RESPEC"))
        or selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC")) then
        local targetData = ResolveCurrentTarget(self)
        TraceInventoryConfirmBranch("before", "use_or_special", targetData, {
            source = "action_dialog",
            selectedActionName = selectedActionName,
        })
        if targetData then
            local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local ds = targetData.dataSource or targetData
            local isQuestItem = IsQuestActionTarget(targetData, "ItemActionHandlers.OnConfirm")
            if isQuestItem and ds.toolIndex then
                UseQuestTool(ds.questIndex, ds.toolIndex)
                TraceInventoryConfirmBranch("after", "use_or_special", targetData, {
                    source = "action_dialog",
                    selectedActionName = selectedActionName,
                    questDispatch = "tool",
                    questIndex = ds.questIndex,
                    toolIndex = ds.toolIndex,
                    actionDialogReleased = true,
                    releaseReturned = released ~= nil,
                })
            elseif isQuestItem and ds.stepIndex and ds.conditionIndex then
                UseQuestItem(ds.questIndex, ds.stepIndex, ds.conditionIndex)
                TraceInventoryConfirmBranch("after", "use_or_special", targetData, {
                    source = "action_dialog",
                    selectedActionName = selectedActionName,
                    questDispatch = "condition",
                    questIndex = ds.questIndex,
                    stepIndex = ds.stepIndex,
                    conditionIndex = ds.conditionIndex,
                    actionDialogReleased = true,
                    releaseReturned = released ~= nil,
                })
            else
                local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
                if bag and slot then
                    local secureOk = CallSecureProtected("UseItem", bag, slot)
                    if not secureOk then
                        local failedStringId = rawget(_G, "SI_BETTERUI_SECURE_ACTION_FAILED")
                        BETTERUI.CIM.UserNotify("ItemActionHandlers:UseItem",
                            (failedStringId and GetString(failedStringId))
                            or "The action could not be completed.")
                    end
                    TraceInventoryConfirmBranch(secureOk and "after" or "blocked", "use_or_special", targetData, {
                        source = "action_dialog",
                        selectedActionName = selectedActionName,
                        actionDialogReleased = true,
                        releaseReturned = released ~= nil,
                        secureProtectedCall = "UseItem",
                        secureOk = secureOk == true,
                        reason = secureOk and nil or "secureUseFailed",
                    })
                else
                    TraceInventoryConfirmBranch("blocked", "use_or_special", targetData, {
                        source = "action_dialog",
                        selectedActionName = selectedActionName,
                        actionDialogReleased = true,
                        releaseReturned = released ~= nil,
                        reason = "missingSlot",
                    })
                end
            end
        else
            TraceInventoryConfirmBranch("blocked", "use_or_special", targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                reason = "missingTarget",
            })
        end
        return
    end

    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_PLACE_FURNITURE")) then
        local targetData = ResolveCurrentTarget(self)
        TraceInventoryConfirmBranch("before", "place_furniture", targetData, {
            source = "action_dialog",
            selectedActionName = selectedActionName,
        })
        if targetData then
            local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local ds = targetData.dataSource or targetData
            local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
            if bag and slot and ZO_CanPlaceItemInCurrentHouse(bag, slot) then
                ZO_TryPlaceFurnitureFromInventorySlot(bag, slot)
                TraceInventoryConfirmBranch("after", "place_furniture", targetData, {
                    source = "action_dialog",
                    selectedActionName = selectedActionName,
                    actionDialogReleased = true,
                    releaseReturned = released ~= nil,
                    canPlace = true,
                    dispatched = true,
                })
            else
                TraceInventoryConfirmBranch("blocked", "place_furniture", targetData, {
                    source = "action_dialog",
                    selectedActionName = selectedActionName,
                    actionDialogReleased = true,
                    releaseReturned = released ~= nil,
                    canPlace = bag and slot and ZO_CanPlaceItemInCurrentHouse(bag, slot) == true or false,
                    reason = not (bag and slot) and "missingSlot" or "cannotPlaceInCurrentHouse",
                })
            end
        else
            TraceInventoryConfirmBranch("blocked", "place_furniture", targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                reason = "missingTarget",
            })
        end
        return
    end

    -- "Show in Quest Journal" (SI_ITEM_ACTION_SHOW_QUEST / native "link_to_quest"). The native
    -- slot-action callback closes over the discovered inventorySlot and runs
    --   SYSTEMS:GetObject("questJournal"):OpenQuestJournalToQuest(inventorySlot.questIndex).
    -- In BetterUI's list that closure does NOT carry a valid questIndex (it lives on our row's
    -- dataSource), so the generic DoAction fallback below resolves OpenQuestJournalToQuest(nil)
    -- and silently no-ops. Dispatch it explicitly from our own data, mirroring the USE branch.
    if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_SHOW_QUEST")) then
        local targetData = ResolveCurrentTarget(self)
        TraceInventoryConfirmBranch("before", "show_quest", targetData, {
            source = "action_dialog",
            selectedActionName = selectedActionName,
        })
        if targetData then
            local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
            local ds = targetData.dataSource or targetData
            local questJournal = SYSTEMS and SYSTEMS.GetObject and SYSTEMS:GetObject("questJournal")
            if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "show quest in journal",
                {questIndex = ds.questIndex, hasJournal = questJournal ~= nil}) end
            if questJournal and questJournal.OpenQuestJournalToQuest and ds.questIndex then
                questJournal:OpenQuestJournalToQuest(ds.questIndex)
                TraceInventoryConfirmBranch("after", "show_quest", targetData, {
                    source = "action_dialog",
                    selectedActionName = selectedActionName,
                    actionDialogReleased = true,
                    releaseReturned = released ~= nil,
                    questIndex = ds.questIndex,
                    hasJournal = true,
                    dispatched = true,
                })
            else
                TraceInventoryConfirmBranch("blocked", "show_quest", targetData, {
                    source = "action_dialog",
                    selectedActionName = selectedActionName,
                    actionDialogReleased = true,
                    releaseReturned = released ~= nil,
                    questIndex = ds.questIndex,
                    hasJournal = questJournal ~= nil,
                    reason = not questJournal and "missingJournal" or "missingQuestIndex",
                })
            end
        else
            TraceInventoryConfirmBranch("blocked", "show_quest", targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                reason = "missingTarget",
            })
        end
        return
    end

    if selectedRow and selectedRow.action then
        local targetData = ResolveCurrentTarget(self)
        TraceInventoryConfirmBranch("before", "native_action", targetData, {
            source = "action_dialog",
            selectedActionName = selectedActionName,
            action = selectedRow.action,
        })
        local slotActions = self.itemActions and self.itemActions:GetSlotActions()
        if slotActions then
            slotActions:DoAction(selectedRow.action)
            TraceInventoryConfirmBranch("after", "native_action", targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                action = selectedRow.action,
                dispatched = true,
            })
        else
            TraceInventoryConfirmBranch("blocked", "native_action", targetData, {
                source = "action_dialog",
                selectedActionName = selectedActionName,
                action = selectedRow.action,
                reason = "missingSlotActions",
            })
        end
    end
end
