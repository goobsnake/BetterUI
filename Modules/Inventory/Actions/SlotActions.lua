--[[
File: Modules/Inventory/Actions/SlotActions.lua
Purpose: Manages the "Action Controller" for inventory slots, determining
         what happens when the user presses the Primary Action key (usually 'A').
]]


---

local INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU = false


-- Registry for external addon slot actions
local m_customActions = {}

--- Registers a custom slot action from an external addon.
--- Actions appear in the Y-menu when the visibility function returns true.
---
---@param id string Unique action identifier
---@param config table Action config with name, callback, and optional visibilityFunction/options
---@return boolean success Whether the action was registered
function BETTERUI.Inventory.RegisterSlotAction(id, config)
    if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "Custom slot action registered", {id = id, name = config and config.name}) end
    if not id or not config or not config.name or not config.callback then
        BETTERUI.Debug("RegisterSlotAction: missing required id, name, or callback")
        return false
    end
    m_customActions[id] = config
    return true
end

--- Unregisters a previously registered custom slot action.
---@param id string Action identifier to unregister
---@return nil
function BETTERUI.Inventory.UnregisterSlotAction(id)
    m_customActions[id] = nil
end

BETTERUI.Inventory.SlotActions = ZO_ItemSlotActionsController:Subclass()

--- Inserts a primary action at the front of the slot actions table.
--- Override of the standard AddSlotAction to force an action to be Primary (A Button).
---
--- Sets the default "A" button behavior for a slot.
--- Inserts the action into index 1 of the action table.
--- Updates `_betterui_primaryOverride` for direct invocation.
--- Adds to Context Menu if applicable.
---
local function BETTERUI_AddSlotPrimary(self, actionStringId, actionCallback, actionType, _visibilityFunction, options)
    local actionName = actionStringId
    local visibilityFunction = function()
        return not IsUnitDead("player")
    end

    -- Set the primary override so the A button callback uses this directly
    self._betterui_primaryOverride = actionCallback
    self._betterui_primaryName = actionName

    -- The following line inserts a row into the FIRST slotAction table, which corresponds to ACTION_KEY
    table.insert(self.m_slotActions, 1, { actionName, actionCallback, actionType, visibilityFunction, options })
    self.m_hasActions = true

    if (self.m_contextMenuMode and (not options or options ~= "silent") and (not visibilityFunction or visibilityFunction())) then
        AddMenuItem(actionName, actionCallback)
    end
end

--- Attempts to unequip an item from the specified inventory slot.
local function PreserveSelectionForAction(inventorySlot)
    if not GAMEPAD_INVENTORY or not inventorySlot then
        return
    end

    local slotData = inventorySlot.dataSource or inventorySlot
    local uid = slotData.uniqueId
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.ACTION, "Preserving selection index and UID", {uid = uid}) end
    if uid then
        GAMEPAD_INVENTORY._preserveUniqueId = uid
    end
    if GAMEPAD_INVENTORY.itemList and GAMEPAD_INVENTORY.itemList.selectedIndex then
        GAMEPAD_INVENTORY._preserveIndex = GAMEPAD_INVENTORY.itemList.selectedIndex
    end
end

local function GetProtectionPolicy()
    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before inventory junk/destroy policy checks")
    return policy
end

local function RequireProtectionPolicyMethod(methodName)
    local policy = GetProtectionPolicy()
    local method = policy and policy[methodName] or nil
    assert(type(method) == "function",
        string.format("BetterUI: CIM.ProtectionPolicy.%s must load before inventory junk/destroy policy checks", tostring(methodName)))
    return method
end

local function CanMarkSlotAsJunkWithPolicy(inventorySlot)
    if not inventorySlot or not CanItemBeMarkedAsJunk then
        return false
    end

    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then
        return false
    end
    if IsItemJunk and IsItemJunk(bag, slot) then
        return false
    end
    return RequireProtectionPolicyMethod("CanJunkItem")(bag, slot) == true
end

local function CanMarkSlotAsJunk(inventorySlot)
    return CanMarkSlotAsJunkWithPolicy(inventorySlot)
end

local function IsSlotMarkedAsJunk(inventorySlot)
    if not inventorySlot or not IsItemJunk then
        return false
    end
    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then
        return false
    end
    return IsItemJunk(bag, slot) == true
end

local function CanUnmarkSlotAsJunk(inventorySlot)
    if not IsSlotMarkedAsJunk(inventorySlot) then
        return false
    end

    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then
        return false
    end

    return RequireProtectionPolicyMethod("CanUnjunkItem")(bag, slot) == true
end

local function TryUnequipItem(inventorySlot)
    if not inventorySlot then return end

    PreserveSelectionForAction(inventorySlot)

    local equipSlot = ZO_Inventory_GetSlotIndex(inventorySlot)
    if equipSlot then UnequipItem(equipSlot) end
end

--- Attempts to use the item in the specified slot.
local function TryUseItem(inventorySlot)
    if not inventorySlot then return end

    PreserveSelectionForAction(inventorySlot)

    BETTERUI.CIM.TryUseItem(inventorySlot)
end

local function BeginInventoryActionFlow(kind, message, data)
    local L = BETTERUI.Log
    if L and L.IsActive and L.IsActive() and L.FlowBegin then
        return L.FlowBegin(kind, L.CATEGORY.ACTION, message, data)
    end
    return nil
end

local function EndInventoryActionFlow(flow, message, data)
    local L = BETTERUI.Log
    if flow and L and L.FlowEnd then
        L.FlowEnd(flow, L.CATEGORY.ACTION, message, data)
    end
end

local function GetSlotItemLink(bag, slot)
    if not (bag and slot and type(GetItemLink) == "function") then
        return nil
    end
    local ok, link = pcall(GetItemLink, bag, slot, LINK_STYLE_BRACKETS)
    if ok and type(link) == "string" and link ~= "" then
        return link
    end
    return nil
end

local function SlotActionData(bag, slot, extra)
    local data = extra or {}
    data.bag = bag
    data.slot = slot
    data.item = GetSlotItemLink(bag, slot)
    return data
end

local function SafeResolveBagAndSlot(slotData)
    if type(ZO_Inventory_GetBagAndIndex) ~= "function" then return nil, nil end
    local ok, bag, slot = pcall(ZO_Inventory_GetBagAndIndex, slotData)
    if ok then
        return bag, slot
    end
    return nil, nil
end

local function ResolveCurrentInventoryActionTarget()
    local inv = rawget(_G, "GAMEPAD_INVENTORY")
    if not (inv and BETTERUI.Inventory and BETTERUI.Inventory.Utils) then return nil end
    local safeGet = BETTERUI.Inventory.Utils.SafeGetTargetData
    if type(safeGet) ~= "function" then return nil end
    local CONST = BETTERUI.Inventory.CONST
    if inv.actionMode == CONST.ITEM_LIST_ACTION_MODE then
        return safeGet(inv.itemList)
    elseif inv.actionMode == CONST.CRAFT_BAG_ACTION_MODE then
        return safeGet(inv.craftBagList)
    elseif inv.actionMode == CONST.CATEGORY_ITEM_ACTION_MODE then
        local categoryData = safeGet(inv.categoryList)
        if categoryData and inv.GenerateItemSlotData then
            local ok, generated = pcall(function()
                return inv:GenerateItemSlotData(categoryData)
            end)
            if ok then return generated end
        end
    end
    return nil
end

local function LogPrimaryActionInvoked(actionName, selectedAction, hasNamedOverride)
    local L = BETTERUI.Log
    if not (L and L.Info) then return end
    local target = ResolveCurrentInventoryActionTarget()
    local bag, slot = SafeResolveBagAndSlot(target)
    L.Info(L.CATEGORY.ACTION, "inventory primary action invoked", SlotActionData(bag, slot, {
        action = actionName,
        selectedAction = selectedAction == true,
        override = hasNamedOverride == true,
    }))
    if L.TraceEvent then
        L.TraceEvent(L.CATEGORY.ACTION, "inventory.primary_action", "invoked", SlotActionData(bag, slot, {
            action = actionName,
            selectedAction = selectedAction == true,
            override = hasNamedOverride == true,
            target = L.DescribeItem and L.DescribeItem(target, "target") or nil,
        }), L.LEVEL.INFO)
    end
end

local ACTION_KEY = 1

local function CountSlotActions(slotActions)
    return slotActions and slotActions.m_slotActions and #slotActions.m_slotActions or 0
end

local function DescribeSlotActions(slotActions, limit)
    if not (slotActions and slotActions.m_slotActions) then return nil end
    local actions = {}
    local count = math.min(#slotActions.m_slotActions, limit or 12)
    for i = 1, count do
        local actionEntry = slotActions.m_slotActions[i]
        actions[#actions + 1] = tostring(actionEntry and actionEntry[ACTION_KEY] or "<unknown>")
    end
    if #slotActions.m_slotActions > count then
        actions[#actions + 1] = "..."
    end
    return table.concat(actions, "|")
end

local function TraceSlotActions(event, phase, inventorySlot, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    local bag, slot = SafeResolveBagAndSlot(inventorySlot)
    data = data or {}
    if not data.target and L.DescribeItem and inventorySlot then
        data.target = L.DescribeItem(inventorySlot.dataSource or inventorySlot, "target")
    end
    L.TraceEvent(L.CATEGORY.ACTION, event, phase, SlotActionData(bag, slot, data), L.LEVEL.INFO)
end

local function TryMarkAsJunk(inventorySlot)
    if not CanMarkSlotAsJunk(inventorySlot) then
        return
    end
    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then
        return
    end

    PreserveSelectionForAction(inventorySlot)
    local flow = BeginInventoryActionFlow("inventoryJunk", "inventory junk mark requested", SlotActionData(bag, slot, {
        junk = true,
    }))
    SetItemIsJunk(bag, slot, true)
    local invalidated = false
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.InvalidateSlotDataCache then
        GAMEPAD_INVENTORY:InvalidateSlotDataCache()
        invalidated = true
    end
    EndInventoryActionFlow(flow, "inventory junk mark cache invalidated; waiting for inventory update", SlotActionData(bag, slot, {
        junk = true,
        invalidated = invalidated,
        refresh = "inventoryUpdate",
    }))
end

local function TryUnmarkAsJunk(inventorySlot)
    if not CanUnmarkSlotAsJunk(inventorySlot) then
        return
    end
    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then
        return
    end

    PreserveSelectionForAction(inventorySlot)
    local flow = BeginInventoryActionFlow("inventoryJunk", "inventory junk unmark requested", SlotActionData(bag, slot, {
        junk = false,
    }))
    SetItemIsJunk(bag, slot, false)
    local invalidated = false
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.InvalidateSlotDataCache then
        GAMEPAD_INVENTORY:InvalidateSlotDataCache()
        invalidated = true
    end
    EndInventoryActionFlow(flow, "inventory junk unmark cache invalidated; waiting for inventory update", SlotActionData(bag, slot, {
        junk = false,
        invalidated = invalidated,
        refresh = "inventoryUpdate",
    }))
end

local function RequireDestroyPolicyAuthorizer()
    local inventory = BETTERUI and BETTERUI.Inventory or nil
    local canDestroyItemWithPolicy = inventory and inventory.CanDestroyItemWithPolicy or nil
    assert(type(canDestroyItemWithPolicy) == "function",
        "BetterUI: Inventory.CanDestroyItemWithPolicy must load before inventory slot destroy actions")
    return canDestroyItemWithPolicy
end

local function CanDestroySlotWithPolicy(inventorySlot, bag, slot)
    return RequireDestroyPolicyAuthorizer()(bag, slot, inventorySlot and inventorySlot.slotType) == true
end

local function TryDestroyPrimaryAction(inventorySlot)
    if not inventorySlot then
        return
    end

    PreserveSelectionForAction(inventorySlot)
    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then
        TraceSlotActions("inventory.destroy", "blocked", inventorySlot, {
            source = "primary_action",
            reason = "invalidSlot",
        })
        return
    end
    local slotType = inventorySlot and inventorySlot.slotType
    local quickDestroy = BETTERUI.GetSetting and BETTERUI.GetSetting("Inventory", "quickDestroy", false) == true
    TraceSlotActions("inventory.destroy", "primary_selected", inventorySlot, {
        source = "primary_action",
        quickDestroy = quickDestroy,
        hasNativeInitiate = ZO_InventorySlot_InitiateDestroyItem ~= nil,
        slotType = slotType,
    })
    if not CanDestroySlotWithPolicy(inventorySlot, bag, slot) then
        TraceSlotActions("inventory.destroy", "blocked", inventorySlot, {
            source = "primary_action",
            reason = "protectionPolicy",
            quickDestroy = quickDestroy,
            slotType = slotType,
        })
        return
    end

    if ZO_InventorySlot_InitiateDestroyItem then
        TraceSlotActions("inventory.destroy", "native_initiate", inventorySlot, {
            source = "primary_action",
            quickDestroy = quickDestroy,
            slotType = slotType,
        })
        ZO_InventorySlot_InitiateDestroyItem(inventorySlot)
        return
    end

    if quickDestroy then
        TraceSlotActions("inventory.destroy", "quick_requested", inventorySlot, {
            source = "primary_action_fallback",
            slotType = slotType,
        })
        BETTERUI.Inventory.TryDestroyItem(bag, slot, true, false, slotType)
    else
        local expectedSlotIdentity = BETTERUI.Inventory.Utils.CaptureSlotIdentity(bag, slot, inventorySlot)
        TraceSlotActions("inventory.destroy", "confirm_dialog_request", inventorySlot, {
            source = "primary_action_fallback",
            slotType = slotType,
            expectedSlotIdentity = expectedSlotIdentity,
            dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
        })
        local shownDialog = ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
            {
                bagId = bag,
                slotIndex = slot,
                slotType = slotType,
                itemLink = GetItemLink(bag, slot),
                expectedSlotIdentity = expectedSlotIdentity,
            }, nil, true, true)
        TraceSlotActions("inventory.destroy", "confirm_dialog_show", inventorySlot, {
            source = "primary_action_fallback",
            slotType = slotType,
            expectedSlotIdentity = expectedSlotIdentity,
            dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
            showReturnedDialog = shownDialog ~= nil,
            showingAfter = ZO_Dialogs_IsShowing and ZO_Dialogs_IsShowing("BETTERUI_CONFIRM_DESTROY_DIALOG") == true or nil,
        })
    end
end

--- Handles banking actions (Deposit/Withdraw) for an item.
local function TryBankItem(inventorySlot)
    if not inventorySlot then return end
    BETTERUI.CIM.TryBankItem(inventorySlot)
end

--- Attempts to move an item between the Backpack and the Craft Bag.
local function TryMoveToInventoryOrCraftBag(inventorySlot, targetBag)
    if not inventorySlot then return end
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, targetBag)
end

--- Checks if an item can be moved to the Craft Bag.
local function CanItemMoveToCraftBag(inventorySlot)
    if not inventorySlot then return false end
    return BETTERUI.CIM.CanItemMoveToCraftBag(inventorySlot)
end

--- Checks if the inventory slot represents an item currently inside the Craft Bag.
local function IsSlotInCraftBag(inventorySlot)
    if not inventorySlot then return false end
    return BETTERUI.CIM.IsSlotInCraftBag(inventorySlot)
end

-- Extracted from Initialize to reduce function nesting depth and improve readability.

local function GetActionString(actionId)
    return GetString(actionId)
end

local function IsPrimaryAction(actionName, actionStringId)
    return actionName == GetActionString(actionStringId)
end

--- Table of action string IDs that should trigger a primary action replacement.
local PRIMARY_ACTION_REPLACEMENTS = {}

local function AddPrimaryActionReplacement(actionId)
    if actionId then
        PRIMARY_ACTION_REPLACEMENTS[actionId] = true
    end
end

AddPrimaryActionReplacement(SI_ITEM_ACTION_USE)
AddPrimaryActionReplacement(SI_ITEM_ACTION_EQUIP)
AddPrimaryActionReplacement(SI_ITEM_ACTION_UNEQUIP)
AddPrimaryActionReplacement(SI_ITEM_ACTION_BANK_WITHDRAW)
AddPrimaryActionReplacement(SI_ITEM_ACTION_BANK_DEPOSIT)
AddPrimaryActionReplacement(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG)
AddPrimaryActionReplacement(SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG)
AddPrimaryActionReplacement(SI_ITEM_ACTION_SHOW_MAP)
AddPrimaryActionReplacement(SI_ITEM_ACTION_START_SKILL_RESPEC)
AddPrimaryActionReplacement(SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC)
AddPrimaryActionReplacement(SI_ITEM_ACTION_PLACE_FURNITURE)
AddPrimaryActionReplacement(SI_ITEM_ACTION_LINK_TO_CHAT)
AddPrimaryActionReplacement(SI_ITEM_ACTION_MARK_AS_JUNK)
AddPrimaryActionReplacement(SI_ITEM_ACTION_UNMARK_AS_JUNK)
AddPrimaryActionReplacement(SI_ITEM_ACTION_DESTROY)

local primaryActionReplacementLookup = nil

local function ShouldReplacePrimaryAction(primaryAction)
    -- Deferred build: populate name-based lookup on first call so GetString()
    -- runs after the engine has fully loaded localized strings.
    if not primaryActionReplacementLookup then
        local lookup = {}
        for actionId in pairs(PRIMARY_ACTION_REPLACEMENTS) do
            local name = GetActionString(actionId)
            if name then lookup[name] = true end
        end
        primaryActionReplacementLookup = lookup
    end
    return primaryActionReplacementLookup[primaryAction] == true
    -- Note: Split stack is intentionally NOT included so it remains
    -- available in the Y (actions) list.
end

local VISIBILITY_FUNCTION = 4

local function LogVisibilityFailure(actionName, err)
    if BETTERUI and type(BETTERUI.Debug) == "function" then
        BETTERUI.Debug(string.format("[Inventory] visibility check failed for %s: %s", tostring(actionName), tostring(err)))
    end
end

local function ExecuteVisibilityFunction(actionName, visibilityFunction)
    local context = "SlotActions.visibility:" .. tostring(actionName)
    local cim = BETTERUI and BETTERUI.CIM
    local safeExecute = cim and cim.SafeExecute
    if type(safeExecute) == "function" then
        local ok, visible = safeExecute(context, visibilityFunction)
        return ok and visible == true
    end

    local ok, visible = xpcall(visibilityFunction, function(err)
        LogVisibilityFailure(actionName, err)
        return err
    end)
    return ok and visible == true
end

BETTERUI.Inventory.SlotActionsVisibilityHelpers = {
    ExecuteVisibilityFunction = ExecuteVisibilityFunction,
    LogVisibilityFailure = LogVisibilityFailure,
}

local function IsActionEntryVisible(actionEntry)
    local visibilityFunction = actionEntry and actionEntry[VISIBILITY_FUNCTION]
    if not visibilityFunction then
        return true
    end
    return ExecuteVisibilityFunction(actionEntry and actionEntry[ACTION_KEY], visibilityFunction)
end

local function ResolvePreferredPrimaryAction(slotActions, primaryAction, inventorySlot)
    if not primaryAction then
        return nil
    end
    if not IsPrimaryAction(primaryAction, SI_ITEM_ACTION_LINK_TO_CHAT) then
        return primaryAction
    end

    if CanUnmarkSlotAsJunk(inventorySlot) then
        return GetActionString(SI_ITEM_ACTION_UNMARK_AS_JUNK)
    end
    if CanMarkSlotAsJunk(inventorySlot) then
        return GetActionString(SI_ITEM_ACTION_MARK_AS_JUNK)
    end

    -- Destroy is intentionally NOT auto-promoted to the implicit primary (A button)
    -- action; it stays in the Y-menu where it always routes through the confirm
    -- dialog flow. Promoting it here made a destructive action the default press.
    if slotActions and slotActions.m_slotActions then
        local linkToChatName = GetActionString(SI_ITEM_ACTION_LINK_TO_CHAT)
        local destroyActionName = GetActionString(SI_ITEM_ACTION_DESTROY)
        for i = 1, #slotActions.m_slotActions do
            local actionEntry = slotActions.m_slotActions[i]
            local discoveredActionName = actionEntry and actionEntry[ACTION_KEY]
            if discoveredActionName
                and discoveredActionName ~= linkToChatName
                and discoveredActionName ~= destroyActionName
                and IsActionEntryVisible(actionEntry) then
                return discoveredActionName
            end
        end
    end

    return nil
end

local function RemoveSlotActionByName(slotActions, actionName)
    if not slotActions or not actionName or not slotActions.m_slotActions then
        return false
    end
    for i = 1, #slotActions.m_slotActions do
        local actionEntry = slotActions.m_slotActions[i]
        if actionEntry and actionEntry[ACTION_KEY] == actionName then
            table.remove(slotActions.m_slotActions, i)
            return true
        end
    end
    return false
end

--- Sets up the primary action for a slot based on its action name.
--- Routes specific actions (Equip, Bank, etc.) to their specialized handlers.
local function SetupPrimaryAction(actionsList, actionName, inventorySlot)
    local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
        SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
        SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
    if IsPrimaryAction(actionName, SI_ITEM_ACTION_LINK_TO_CHAT) and isCompanionSceneShowing then
        return
    end

    if IsPrimaryAction(actionName, SI_ITEM_ACTION_USE) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_USE, function(...) TryUseItem(inventorySlot) end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_EQUIP) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_EQUIP,
            function(...) GAMEPAD_INVENTORY:TryEquipItem(inventorySlot, ZO_Dialogs_IsShowingDialog()) end,
            inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_UNEQUIP) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_UNEQUIP, function(...) TryUnequipItem(inventorySlot) end,
            inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_BANK_WITHDRAW) or IsPrimaryAction(actionName, SI_ITEM_ACTION_BANK_DEPOSIT) then
        BETTERUI.CIM.SetupSecureAction(actionsList,
            actionName == GetActionString(SI_ITEM_ACTION_BANK_WITHDRAW) and SI_ITEM_ACTION_BANK_WITHDRAW or
            SI_ITEM_ACTION_BANK_DEPOSIT,
            function(...) TryBankItem(inventorySlot) end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG,
            function(...)
                local invokeInventoryDialog = BETTERUI.Inventory and BETTERUI.Inventory.InvokeDialog
                if not (invokeInventoryDialog and invokeInventoryDialog("TryRetrieveWithQuantity", inventorySlot)) then
                    TryMoveToInventoryOrCraftBag(inventorySlot, BAG_BACKPACK)
                end
            end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_SHOW_MAP) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_SHOW_MAP, function(...) TryUseItem(inventorySlot) end,
            inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_START_SKILL_RESPEC) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_START_SKILL_RESPEC, function(...) TryUseItem(inventorySlot) end,
            inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC,
            function(...) TryUseItem(inventorySlot) end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_PLACE_FURNITURE) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_PLACE_FURNITURE, function(...)
            if inventorySlot then
                local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
                if bag and slot then
                    ZO_TryPlaceFurnitureFromInventorySlot(bag, slot)
                end
            end
        end, inventorySlot)
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_MARK_AS_JUNK) then
        actionsList:AddSlotPrimaryAction(actionName, function(...)
            TryMarkAsJunk(inventorySlot)
        end, "primary", nil, { visibleWhenDead = false })
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_UNMARK_AS_JUNK) then
        actionsList:AddSlotPrimaryAction(actionName, function(...)
            TryUnmarkAsJunk(inventorySlot)
        end, "primary", nil, { visibleWhenDead = false })
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_DESTROY) then
        actionsList:AddSlotPrimaryAction(actionName, function(...)
            TryDestroyPrimaryAction(inventorySlot)
        end, "primary", nil, { visibleWhenDead = false })
    elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_LINK_TO_CHAT) then
        BETTERUI.CIM.SetupSecureAction(actionsList, SI_ITEM_ACTION_LINK_TO_CHAT, function(...)
            if inventorySlot then
                local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
                if bag and slot then
                    local itemLink = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
                    if itemLink and itemLink ~= "" then
                        ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink))
                    end
                end
            end
        end, inventorySlot)
    end
end

--- Injects custom registered actions from external addons into the slot actions list.
local function InjectCustomActions(slotActions, inventorySlot)
    local SafeExecute = BETTERUI.CIM.SafeExecute
    for actionId, customAction in pairs(m_customActions) do
        local actionCtx = "SlotActions.custom:" .. tostring(actionId)
        local visible = true
        if customAction.visibilityFunction then
            local ok, result = SafeExecute(actionCtx .. ".visibility", customAction.visibilityFunction, inventorySlot)
            visible = ok and result
        end
        if visible then
            local name = customAction.name
            if type(name) == "function" then
                local ok, result = SafeExecute(actionCtx .. ".name", name, inventorySlot)
                name = ok and result or nil
            end
            if name then
                slotActions:AddSlotAction(
                    name,
                    function()
                        SafeExecute(actionCtx .. ".callback", customAction.callback, inventorySlot)
                    end,
                    "secondary",
                    customAction.visibilityFunction and function()
                        local ok, result = SafeExecute(actionCtx .. ".visibility", customAction.visibilityFunction, inventorySlot)
                        return ok and result
                    end or nil,
                    customAction.options
                )
            end
        end
    end
end


--- Action discovery and selection for the primary (A button) command.
---
--- 1. Clears previous actions.
--- 2. Discovers slot actions from the engine.
--- 3. Secures "Open Skills" callback.
--- 4. Resolves primary action (Use vs Stow vs Equip vs Bank).
--- 5. Injects custom addon actions.
--- 6. Deduplicates the action list.
---
---@param inventorySlot table Inventory slot data to discover actions for
---@return nil
function BETTERUI.Inventory.SlotActions:ActivatePrimaryCommand(inventorySlot)
    local slotActions = self.slotActions
    TraceSlotActions("inventory.slot_actions", "activate_start", inventorySlot, {
        hadSlot = inventorySlot ~= nil,
    })
    slotActions:Clear()
    slotActions:SetInventorySlot(inventorySlot)
    slotActions._betterui_primaryOverride = nil
    slotActions._betterui_primaryName = nil
    self.selectedAction = nil

    if not inventorySlot then
        TraceSlotActions("inventory.slot_actions", "activate_skipped", nil, {
            reason = "missingInventorySlot",
        })
        self.actionName = nil
        return
    end

    TraceSlotActions("inventory.slot_actions", "discover_before", inventorySlot, {
        actionCount = CountSlotActions(slotActions),
    })
    ZO_InventorySlot_DiscoverSlotActionsFromActionList(inventorySlot, slotActions)
    TraceSlotActions("inventory.slot_actions", "discover_after", inventorySlot, {
        actionCount = CountSlotActions(slotActions),
        actions = DescribeSlotActions(slotActions),
    })

    -- 1. Secure "Open Skills" callback
    BETTERUI.CIM.SecureOpenSkills(slotActions, inventorySlot)

    local discoveredPrimaryAction = slotActions:GetPrimaryActionName()
    local primaryAction = discoveredPrimaryAction
    local fallbackPrimaryAction = nil
    local canUseItem = false

    if not primaryAction and #slotActions.m_slotActions > 0 then
        fallbackPrimaryAction = slotActions.m_slotActions[1][1]
        primaryAction = fallbackPrimaryAction
    end

    primaryAction = ResolvePreferredPrimaryAction(slotActions, primaryAction, inventorySlot)
    TraceSlotActions("inventory.slot_actions", "primary_resolved", inventorySlot, {
        discoveredPrimary = discoveredPrimaryAction,
        fallbackPrimary = fallbackPrimaryAction,
        resolvedPrimary = primaryAction,
        replacement = primaryAction and ShouldReplacePrimaryAction(primaryAction) == true,
        actionCount = CountSlotActions(slotActions),
        actions = DescribeSlotActions(slotActions),
    })

    -- Handle primary action replacement logic
    if primaryAction and ShouldReplacePrimaryAction(primaryAction) then
        local removedByName = RemoveSlotActionByName(slotActions, primaryAction)
        local removedFallback = false
        if not removedByName and #slotActions.m_slotActions > 0 then
            table.remove(slotActions.m_slotActions, 1)
            removedFallback = true
        end
        TraceSlotActions("inventory.slot_actions", "primary_removed", inventorySlot, {
            primary = primaryAction,
            removedByName = removedByName == true,
            removedFallback = removedFallback == true,
            actionCount = CountSlotActions(slotActions),
            actions = DescribeSlotActions(slotActions),
        })

        if not IsSlotInCraftBag(inventorySlot) and CanItemMoveToCraftBag(inventorySlot) and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_USE) then
            canUseItem = true
            for i = #slotActions.m_slotActions, 1, -1 do
                if slotActions.m_slotActions[i][1] == GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) then
                    table.remove(slotActions.m_slotActions, i)
                    TraceSlotActions("inventory.slot_actions", "secondary_removed", inventorySlot, {
                        action = GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG),
                        reason = "craftBagUsePrimary",
                        actionCount = CountSlotActions(slotActions),
                        actions = DescribeSlotActions(slotActions),
                    })
                    break
                end
            end
        end
    elseif not primaryAction then
        TraceSlotActions("inventory.slot_actions", "primary_missing", inventorySlot, {
            actionCount = CountSlotActions(slotActions),
            actions = DescribeSlotActions(slotActions),
        })
        self.actionName = nil
        slotActions._betterui_primaryOverride = nil
        slotActions._betterui_primaryName = nil
        return
    end

    -- Split Stack Override
    if primaryAction and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_SPLIT_STACK) then
        slotActions._betterui_primaryName = primaryAction
        slotActions._betterui_primaryOverride = function()
            if ZO_InventorySlot_TrySplitStack then
                TraceSlotActions("inventory.split_stack", "primary_override_dispatch", inventorySlot, {
                    source = "slot_primary_override",
                    action = primaryAction,
                })
                ZO_InventorySlot_TrySplitStack(inventorySlot)
            else
                TraceSlotActions("inventory.split_stack", "primary_override_blocked", inventorySlot, {
                    source = "slot_primary_override",
                    action = primaryAction,
                    reason = "missingTrySplitStack",
                })
            end
        end
        TraceSlotActions("inventory.slot_actions", "override_set", inventorySlot, {
            action = primaryAction,
            override = "splitStack",
        })
    else
        slotActions._betterui_primaryOverride = nil
    end

    -- 2. Resolve Craft Bag vs Inventory State (Stow vs Retrieve)
    self.actionName = BETTERUI.CIM.ResolveCraftBagState(slotActions, inventorySlot, primaryAction, canUseItem)
    if BETTERUI.Log and BETTERUI.Log.Debug then
        local bag, slot = SafeResolveBagAndSlot(inventorySlot)
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "inventory primary action resolved", SlotActionData(bag, slot, {
            primary = primaryAction,
            action = self.actionName,
            replacement = primaryAction and ShouldReplacePrimaryAction(primaryAction) == true,
        }))
    end
    TraceSlotActions("inventory.slot_actions", "action_resolved", inventorySlot, {
        primary = primaryAction,
        action = self.actionName,
        canUseItem = canUseItem == true,
        replacement = primaryAction and ShouldReplacePrimaryAction(primaryAction) == true,
    })

    -- 3. Setup secure actions based on action type
    if primaryAction and ShouldReplacePrimaryAction(primaryAction) then
        SetupPrimaryAction(slotActions, primaryAction, inventorySlot)
        TraceSlotActions("inventory.slot_actions", "primary_setup", inventorySlot, {
            primary = primaryAction,
            action = self.actionName,
            override = type(slotActions._betterui_primaryOverride) == "function",
            overrideName = slotActions._betterui_primaryName,
            actionCount = CountSlotActions(slotActions),
            actions = DescribeSlotActions(slotActions),
        })
    end

    -- 4. Inject custom registered actions from external addons
    TraceSlotActions("inventory.slot_actions", "custom_before", inventorySlot, {
        actionCount = CountSlotActions(slotActions),
        actions = DescribeSlotActions(slotActions),
    })
    InjectCustomActions(slotActions, inventorySlot)
    TraceSlotActions("inventory.slot_actions", "custom_after", inventorySlot, {
        actionCount = CountSlotActions(slotActions),
        actions = DescribeSlotActions(slotActions),
    })

    -- 5. Deduplicate Action List
    BETTERUI.CIM.DeduplicateActions(slotActions)
    TraceSlotActions("inventory.slot_actions", "finalized", inventorySlot, {
        primary = primaryAction,
        action = self.actionName,
        override = type(slotActions._betterui_primaryOverride) == "function",
        overrideName = slotActions._betterui_primaryName,
        actionCount = CountSlotActions(slotActions),
        actions = DescribeSlotActions(slotActions),
    })
end

--- Initializes the slot actions controller, defining how actions are prioritized and executed.
---
--- Sets up the ZO_InventorySlotActions instance, hooks the primary action mechanism,
--- and wires keybind commands for the A button and optional mouse-over binds.
---
---@param alignmentOverride number|nil Keybind strip alignment override
---@param additionalMouseOverbinds table|nil Additional mouse-over keybind names
---@param useKeybindStrip boolean|nil Whether to use keybind strip (default: true)
---@return nil
function BETTERUI.Inventory.SlotActions:Initialize(alignmentOverride, additionalMouseOverbinds, useKeybindStrip)
    self.alignment = KEYBIND_STRIP_ALIGN_RIGHT

    local slotActions = ZO_InventorySlotActions:New(INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU)
    slotActions.AddSlotPrimaryAction = BETTERUI_AddSlotPrimary

    self.slotActions = slotActions
    self.useKeybindStrip = useKeybindStrip == nil and true or useKeybindStrip

    local selfRef = self
    local primaryCommand = {
        alignment = alignmentOverride,
        name = function()
            local n = nil
            if selfRef.selectedAction then
                n = slotActions:GetRawActionName(selfRef.selectedAction)
            end
            if not n then
                n = selfRef.actionName
            end
            if (not n or n == "") and slotActions._betterui_primaryName and slotActions._betterui_primaryName ~= "" then
                n = slotActions._betterui_primaryName
            end
            return n or ""
        end,
        keybind = "UI_SHORTCUT_PRIMARY",
        order = 500,
        callback = function()
            local inventory = GAMEPAD_INVENTORY
            local inventoryMultiSelectActive = inventory and inventory.multiSelectManager
                and inventory.multiSelectManager.IsActive and inventory.multiSelectManager:IsActive()
            local craftBagMultiSelectActive = inventory and inventory.craftBagMultiSelectManager
                and inventory.craftBagMultiSelectManager.IsActive and inventory.craftBagMultiSelectManager:IsActive()
            if inventoryMultiSelectActive or craftBagMultiSelectActive then
                TraceSlotActions("inventory.primary_action", "skipped", ResolveCurrentInventoryActionTarget(), {
                    reason = "multiSelectActive",
                    inventoryMultiSelect = inventoryMultiSelectActive == true,
                    craftBagMultiSelect = craftBagMultiSelectActive == true,
                })
                return
            end

            if selfRef.selectedAction then
                local rawActionName = slotActions:GetRawActionName(selfRef.selectedAction)
                TraceSlotActions("inventory.primary_action", "dispatch_before", ResolveCurrentInventoryActionTarget(), {
                    route = "selectedAction",
                    action = rawActionName,
                })
                LogPrimaryActionInvoked(rawActionName, true, false)
                selfRef:DoSelectedAction()
                TraceSlotActions("inventory.primary_action", "dispatch_after", ResolveCurrentInventoryActionTarget(), {
                    route = "selectedAction",
                    action = rawActionName,
                })
            else
                local hasNamedOverride = type(slotActions._betterui_primaryOverride) == "function"
                    and type(slotActions._betterui_primaryName) == "string"
                    and slotActions._betterui_primaryName ~= ""
                local actionName = selfRef.actionName or slotActions._betterui_primaryName
                local route = hasNamedOverride and "namedOverride" or "enginePrimary"
                TraceSlotActions("inventory.primary_action", "dispatch_before", ResolveCurrentInventoryActionTarget(), {
                    route = route,
                    action = actionName,
                    override = hasNamedOverride == true,
                })
                LogPrimaryActionInvoked(actionName, false, hasNamedOverride)
                if hasNamedOverride then
                    slotActions._betterui_primaryOverride()
                else
                    slotActions:DoPrimaryAction()
                end
                TraceSlotActions("inventory.primary_action", "dispatch_after", ResolveCurrentInventoryActionTarget(), {
                    route = route,
                    action = actionName,
                    override = hasNamedOverride == true,
                })
            end
        end,
        visible = function()
            return slotActions:CheckPrimaryActionVisibility() or selfRef:HasSelectedAction()
        end,
    }

    local function PrimaryCommandHasBind()
        if selfRef.actionName == GetActionString(SI_ITEM_ACTION_LINK_TO_CHAT) then
            return false
        end
        return (selfRef.actionName ~= nil) or selfRef:HasSelectedAction()
    end

    self:AddSubCommand(primaryCommand, PrimaryCommandHasBind, function(inventorySlot)
        selfRef:ActivatePrimaryCommand(inventorySlot)
    end)

    if additionalMouseOverbinds then
        for i = 1, #additionalMouseOverbinds do
            local mouseOverCommand = {
                alignment = alignmentOverride,
                name = function()
                    return slotActions:GetKeybindActionName(i) or ""
                end,
                keybind = additionalMouseOverbinds[i],
                callback = function() slotActions:DoKeybindAction(i) end,
                visible = function()
                    return slotActions:CheckKeybindActionVisibility(i)
                end,
            }
            self:AddSubCommand(mouseOverCommand, function()
                return slotActions:GetKeybindActionName(i) ~= nil
            end)
        end
    end
end

--- Returns the underlying ZO_InventorySlotActions object.
--- Required for the Y-actions dialog to iterate through available actions.
---@return table slotActions The ZO_InventorySlotActions instance
function BETTERUI.Inventory.SlotActions:GetSlotActions()
    return self.slotActions
end
