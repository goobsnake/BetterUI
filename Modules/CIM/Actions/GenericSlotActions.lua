--[[
Purpose: Shared slot action helpers for Inventory and Banking modules.
         Provides item action implementations (use, bank, craft bag stow/retrieve)
         and common action-list utilities (deduplication, secure wrapping).
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

local function GetProtectionPolicy()
    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before CIM generic-slot policy checks")
    return policy
end

local function ResolvePolicyDeny(denyKey)
    local policy = GetProtectionPolicy()
    local denyTable = policy and policy.DENY
    local denyValue = denyTable and denyTable[denyKey] or nil
    assert(type(denyValue) == "string",
        string.format("BetterUI: CIM.ProtectionPolicy.DENY.%s must be defined", tostring(denyKey)))
    return denyValue
end

local function CanStowToCraftBagWithPolicy(bagId, slotIndex)
    local policy = GetProtectionPolicy()
    local canStowToCraftBag = policy and policy.CanStowToCraftBag or nil
    assert(type(canStowToCraftBag) == "function",
        "BetterUI: CIM.ProtectionPolicy.CanStowToCraftBag must load before craft-bag transfer checks")
    return canStowToCraftBag(bagId, slotIndex)
end

--- Securely picks up a stack and places it in the target bag/slot.
--- Checks both protected calls; drops a held item if placement fails.
---@return boolean ok
---@return string|nil reason denial reason on failure
local function SecurePickupAndPlace(bag, index, stackSize, targetBag, destinationSlot)
    if not CallSecureProtected("PickupInventoryItem", bag, index, stackSize) then
        return false, "pickup_failed"
    end
    if not CallSecureProtected("PlaceInInventory", targetBag, destinationSlot) then
        -- Don't leave the picked-up item stuck on the cursor
        if ClearCursor then
            ClearCursor()
        end
        return false, "place_failed"
    end
    return true
end

-- SHARED ITEM ACTION HELPERS
-- These functions provide common item action implementations used by
-- Inventory and Banking modules. They handle secure API calls.

--- @param inventorySlot BetterUISlotActionEntryLike|nil the slot data table (may have .dataSource wrapper)
--- @return boolean ok true if the item was used
--- @return string|nil reason denial reason on failure
function BETTERUI.CIM.TryUseItem(inventorySlot)
    if not inventorySlot then
        return false, "no_slot"
    end
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    if slotType == SLOT_TYPE_QUEST_ITEM then
        -- UseQuestTool and UseQuestItem are NOT protected functions - call them directly
        -- (this matches how the base game's TryUseQuestItem works in inventoryslot.lua:420)
        -- Do NOT hide the scene manually — ESO's engine handles the scene transition
        -- (e.g., opening book reader, world map) and keeps inventory on the scene stack
        -- so WasSceneOnStack returns true on re-entry, preserving category/position
        if inventorySlot.toolIndex then
            UseQuestTool(inventorySlot.questIndex, inventorySlot.toolIndex)
            return true
        elseif inventorySlot.conditionIndex then
            UseQuestItem(inventorySlot.questIndex, inventorySlot.stepIndex, inventorySlot.conditionIndex)
            return true
        end
        return false, "no_quest_action"
    else
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        local usable, onlyFromActionSlot = IsItemUsable(bag, index)
        if usable and not onlyFromActionSlot then
            if not CallSecureProtected("UseItem", bag, index) then
                return false, "use_failed"
            end
            return true
        end
        return false, "not_usable"
    end
end

--- @param inventorySlot BetterUISlotActionEntryLike|nil the slot data table
--- @return boolean ok true if the item was transferred
--- @return string|nil reason denial reason on failure
function BETTERUI.CIM.TryBankItem(inventorySlot)
    local banking = BETTERUI.Banking
    local tryTransferInventorySlot = banking and banking.TryTransferInventorySlot or nil
    if type(tryTransferInventorySlot) ~= "function" then
        return false, "banking_transfer_unavailable"
    end
    return tryTransferInventorySlot(inventorySlot)
end

--- @param inventorySlot BetterUISlotActionEntryLike|nil the slot data table
--- @param targetBag number destination bag constant (BAG_VIRTUAL, BAG_BACKPACK, etc.)
--- @param quantity number|nil optional quantity override (defaults to full stack)
--- @return boolean ok true if the item was moved
--- @return string|nil reason denial reason on failure
function BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, targetBag, quantity)
    if not inventorySlot then
        return false, "no_slot"
    end
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag then return false, "no_slot" end

    -- Maximum items that can be transferred in a single operation (ESO game limit)
    local MAX_STACK_TRANSFER = 200

    local stackSize, maxStackSize = GetSlotStackSize(bag, index)
    if not stackSize or stackSize <= 0 then
        return false, ResolvePolicyDeny("NO_ITEM")
    end
    if maxStackSize and stackSize >= maxStackSize then
        stackSize = maxStackSize
    end
    if quantity and quantity > 0 then
        if zo_clamp then
            stackSize = zo_clamp(quantity, 1, stackSize)
        else
            stackSize = math.max(1, math.min(quantity, stackSize))
        end
    end
    -- Cap at max transfer limit
    if stackSize > MAX_STACK_TRANSFER then
        stackSize = MAX_STACK_TRANSFER
    end

    if targetBag == BAG_VIRTUAL then
        local canStow, denyReason = CanStowToCraftBagWithPolicy(bag, index)
        if not canStow then
            if BETTERUI.Log then
                BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.ACTION, "craftbag move denied", { reason = denyReason })
            end
            return false, denyReason
        end
    end

    if targetBag ~= BAG_VIRTUAL then
        if DoesBagHaveSpaceFor(targetBag, bag, index) then
            local destinationSlot = BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(bag, index, targetBag)
            if destinationSlot == nil then
                BETTERUI.CIM.UserNotify("TryMoveToCraftBag:NoSlot", SI_INVENTORY_ERROR_INVENTORY_FULL)
                return false, "inventory_full"
            end
            return SecurePickupAndPlace(bag, index, stackSize, targetBag, destinationSlot)
        else
            BETTERUI.CIM.UserNotify("TryMoveToCraftBag:Full", SI_INVENTORY_ERROR_INVENTORY_FULL)
            return false, "inventory_full"
        end
    else
        return SecurePickupAndPlace(bag, index, stackSize, targetBag, 0)
    end
end

---@param inventorySlot BetterUISlotActionEntryLike|nil Inventory slot data with bagId/slotIndex
---@return boolean canMove true if item can transfer to craft bag
function BETTERUI.CIM.CanItemMoveToCraftBag(inventorySlot)
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not index then
        return false
    end
    local canStow = CanStowToCraftBagWithPolicy(bag, index)
    return canStow == true
end

-- SHARED ACTION SETUP HELPERS
-- These functions provide shared action setup logic that was previously
-- duplicated in Inventory/Actions/SlotActions.lua.

---@param slotActions table Action list builder
---@param actionStringId number ESO string constant (e.g. SI_ITEM_ACTION_USE)
---@param callback function Fallback action callback
---@param inventorySlot BetterUISlotActionEntryLike|nil Inventory slot data
function BETTERUI.CIM.SetupSecureAction(slotActions, actionStringId, callback, inventorySlot)
    local actionName = GetString(actionStringId)
    if actionStringId == SI_ITEM_ACTION_USE then
        -- Create a wrapper that calls the secure protected function
        local secureCallback = function()
            BETTERUI.CIM.TryUseItem(inventorySlot)
        end
        slotActions:AddSlotPrimaryAction(actionName, secureCallback, "primary", nil, { visibleWhenDead = false })
    else
        slotActions:AddSlotPrimaryAction(actionName, callback, "primary", nil, { visibleWhenDead = false })
    end
end

---@param slotActions table Action list builder
---@param inventorySlot BetterUISlotActionEntryLike|nil Inventory slot data
---@param canUseItem boolean Whether the item is usable
function BETTERUI.CIM.HandleCraftBagActions(slotActions, inventorySlot, canUseItem)
    local stowCallback = function()
        -- Use quantity dialog for stacked items
        if not BETTERUI.CIM.InvokeInventoryDialog("TryStowWithQuantity", inventorySlot) then
            BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, BAG_VIRTUAL)
        end
    end

    if canUseItem then
        BETTERUI.CIM.SetupSecureAction(slotActions, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG, stowCallback, inventorySlot)
        -- USE as secondary action - also need to be secure
        slotActions:AddSlotAction(SI_ITEM_ACTION_USE, function()
            BETTERUI.CIM.TryUseItem(inventorySlot)
        end, "secondary", nil, { visibleWhenDead = false })
    else
        BETTERUI.CIM.SetupSecureAction(slotActions, SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG, stowCallback, inventorySlot)
    end
end

--- Wraps "Open Skills" callback in CallSecureProtected to prevent tainting errors.
---@param slotActions table
---@param inventorySlot BetterUISlotActionEntryLike|nil
function BETTERUI.CIM.SecureOpenSkills(slotActions, inventorySlot)
    local INDEX_ACTION_CALLBACK = 2
    for i, action in ipairs(slotActions.m_slotActions) do
        local actionName = action[1]
        -- Use localized string constant to match on non-English clients
        if actionName == GetString(rawget(_G, "SI_ITEM_ACTION_START_SKILL_RESPEC")) then
            local wrappedCallback = function()
                if inventorySlot then
                    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
                    return CallSecureProtected("UseItem", bag, index)
                end
            end
            action[INDEX_ACTION_CALLBACK] = wrappedCallback
        end
    end
end

---@param slotActions table Action list with m_slotActions array
function BETTERUI.CIM.DeduplicateActions(slotActions)
    local seen = {}
    for i = #slotActions.m_slotActions, 1, -1 do
        local entry = slotActions.m_slotActions[i]
        local name = entry and entry[1]
        if name and seen[name] then
            table.remove(slotActions.m_slotActions, i)
        else
            if name then
                seen[name] = true
            end
        end
    end
end

function BETTERUI.CIM.IsSlotInCraftBag(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    return slotType == SLOT_TYPE_CRAFT_BAG_ITEM
end

function BETTERUI.CIM.ResolveCraftBagState(slotActions, inventorySlot, primaryAction, canUseItem)
    local retrieveActionName = GetString(rawget(_G, "SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG"))
    local stowActionName = GetString(rawget(_G, "SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG"))
    local actionName = primaryAction or stowActionName
    local isInCraftBag = BETTERUI.CIM.IsSlotInCraftBag(inventorySlot)

    if isInCraftBag then
        -- CRAFT BAG VIEW: Remove "Stow" from actions entirely, keep "Retrieve" as primary
        for i = #slotActions.m_slotActions, 1, -1 do
            if slotActions.m_slotActions[i][1] == stowActionName then
                table.remove(slotActions.m_slotActions, i)
            end
        end
        -- Ensure Retrieve is primary action for craft bag items
        actionName = retrieveActionName
    elseif BETTERUI.CIM.CanItemMoveToCraftBag(inventorySlot) then
        -- INVENTORY VIEW: Force "Stow" as primary for eligible items
        -- Remove any existing craft-bag entries to avoid duplicates
        for i = #slotActions.m_slotActions, 1, -1 do
            if slotActions.m_slotActions[i][1] == stowActionName then
                table.remove(slotActions.m_slotActions, i)
            end
        end

        -- Use the helper to add the primary craft-bag action
        BETTERUI.CIM.HandleCraftBagActions(slotActions, inventorySlot, canUseItem)

        -- We forced Stow to be primary; clear any prior split-stack override
        slotActions._betterui_primaryOverride = nil

        -- Ensure the displayed action name is "Stow"
        actionName = stowActionName
    end
    return actionName
end
