--[[
File: Modules/Inventory/Actions/SlotActions.lua
Purpose: Manages the "Action Controller" for inventory slots, determining
         what happens when the user presses the Primary Action key (usually 'A').
Author: BetterUI Team
Last Modified: 2026-01-28
]]

local ACTION_KEY = 1
local VISIBILITY_FUNCTION = 4
local INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU = false

BETTERUI.Inventory.SlotActions = ZO_ItemSlotActionsController:Subclass()

local function BETTERUI_AddSlotPrimary(self, actionStringId, actionCallback, actionType, visibilityFunction, options)
    local actionName = actionStringId
    visibilityFunction = function()
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

local function PreserveSelectionForAction(inventorySlot)
    if not GAMEPAD_INVENTORY or not inventorySlot then return end

    local slotData = inventorySlot.dataSource or inventorySlot
    local uid = slotData.uniqueId
    if uid then
        GAMEPAD_INVENTORY._preserveUniqueId = uid
    end
    if GAMEPAD_INVENTORY.itemList and GAMEPAD_INVENTORY.itemList.selectedIndex then
        GAMEPAD_INVENTORY._preserveIndex = GAMEPAD_INVENTORY.itemList.selectedIndex
    end
end

local function CanMarkSlotAsJunk(inventorySlot)
    if not inventorySlot or not CanItemBeMarkedAsJunk then return false end

    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then return false end
    if bag == BAG_VIRTUAL then return false end
    if IsItemPlayerLocked and IsItemPlayerLocked(bag, slot) then return false end
    if not CanItemBeMarkedAsJunk(bag, slot) then return false end

    local companionJunkEnabled = BETTERUI
        and BETTERUI.Settings
        and BETTERUI.Settings.Modules
        and BETTERUI.Settings.Modules["Inventory"]
        and BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
    local actorCategory = GetItemActorCategory and GetItemActorCategory(bag, slot)
    if not companionJunkEnabled and actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        return false
    end
    return true
end

local function IsSlotMarkedAsJunk(inventorySlot)
    if not inventorySlot or not IsItemJunk then return false end
    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then return false end
    return IsItemJunk(bag, slot) == true
end

local function TryUnequipItem(inventorySlot)
    if not inventorySlot then return end

    PreserveSelectionForAction(inventorySlot)

    local equipSlot = ZO_Inventory_GetSlotIndex(inventorySlot)
    if equipSlot then UnequipItem(equipSlot) end
end

local function TryUseItem(inventorySlot)
    if not inventorySlot then return end

    PreserveSelectionForAction(inventorySlot)

    BETTERUI.CIM.TryUseItem(inventorySlot)
end

local function TryMarkAsJunk(inventorySlot)
    if not CanMarkSlotAsJunk(inventorySlot) then return end
    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then return end

    PreserveSelectionForAction(inventorySlot)
    SetItemIsJunk(bag, slot, true)
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.InvalidateSlotDataCache then
        GAMEPAD_INVENTORY:InvalidateSlotDataCache()
    end
end

local function TryUnmarkAsJunk(inventorySlot)
    if not IsSlotMarkedAsJunk(inventorySlot) then return end
    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then return end

    PreserveSelectionForAction(inventorySlot)
    SetItemIsJunk(bag, slot, false)
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.InvalidateSlotDataCache then
        GAMEPAD_INVENTORY:InvalidateSlotDataCache()
    end
end

local function TryDestroyPrimaryAction(inventorySlot)
    if not inventorySlot then return end
    PreserveSelectionForAction(inventorySlot)

    if ZO_InventorySlot_InitiateDestroyItem then
        ZO_InventorySlot_InitiateDestroyItem(inventorySlot)
        return
    end

    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bag or not slot then return end

    local quickDestroy = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
        and BETTERUI.Settings.Modules["Inventory"]
        and BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
    if quickDestroy then
        BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
    else
        ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
            { bagId = bag, slotIndex = slot, itemLink = GetItemLink(bag, slot) }, nil, true, true)
    end
end

local function TryBankItem(inventorySlot)
    if not inventorySlot then return end
    BETTERUI.CIM.TryBankItem(inventorySlot)
end

local function TryMoveToInventoryorCraftBag(inventorySlot, targetBag)
    if not inventorySlot then return end
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, targetBag)
end

local function CanItemMoveToCraftBag(inventorySlot)
    if not inventorySlot then return false end
    return BETTERUI.CIM.CanItemMoveToCraftBag(inventorySlot)
end

local function IsSlotInCraftBag(inventorySlot)
    if not inventorySlot then return false end
    return BETTERUI.CIM.IsSlotInCraftBag(inventorySlot)
end

--- Initializes the slot actions controller, defining how actions are prioritized and executed.
---
--- Purpose: **Core Logic for 'A' Button**. Determines what the Primary Action is.
--- Mechanics:
--- 1. Creates `ZO_InventorySlotActions` instance.
--- 2. Hooks `AddSlotPrimaryAction`.
--- 3. Defines `PrimaryCommand`:
---    - The "A" button keybind.
---    - calls `PrimaryCommandActivate`.
--- 4. Defines `PrimaryCommandActivate` (Inner Function):
---    - Discovers actions from engine.
---    - Overrides "Open Skills" to be secure.
---    - Prioritizes "Stow" vs "Use" vs "Equip".
---    - Manages "Split Stack" override.
---    - Configures `slotActions` with the chosen primary.
---
--- @param alignmentOverride any Override for the keybind strip alignment.
--- @param additionalMouseOverbinds table List of additional keybinds for mouse-over actions.
--- @param useKeybindStrip boolean Whether to display the keybind strip (default: true).
function BETTERUI.Inventory.SlotActions:Initialize(alignmentOverride, additionalMouseOverbinds, useKeybindStrip)
    self.alignment = KEYBIND_STRIP_ALIGN_RIGHT

    local slotActions = ZO_InventorySlotActions:New(INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU)
    slotActions.AddSlotPrimaryAction =
        BETTERUI_AddSlotPrimary -- Add a new function which allows us to neatly add our own slots *with context* of the original!!

    self.slotActions = slotActions
    self.useKeybindStrip = useKeybindStrip == nil and true or useKeybindStrip

    local primaryCommand =
    {
        alignment = alignmentOverride,
        name = function()
            local n = nil
            if (self.selectedAction) then
                n = slotActions:GetRawActionName(self.selectedAction)
            end
            if not n then
                n = self.actionName
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
            local inventoryMultiSelectActive = inventory and inventory.multiSelectManager and inventory.multiSelectManager.IsActive
                and inventory.multiSelectManager:IsActive()
            local craftBagMultiSelectActive = inventory and inventory.craftBagMultiSelectManager
                and inventory.craftBagMultiSelectManager.IsActive and inventory.craftBagMultiSelectManager:IsActive()
            if inventoryMultiSelectActive or craftBagMultiSelectActive then
                return
            end

            if self.selectedAction then
                self:DoSelectedAction()
            else
                local hasNamedOverride = type(slotActions._betterui_primaryOverride) == "function"
                    and type(slotActions._betterui_primaryName) == "string"
                    and slotActions._betterui_primaryName ~= ""
                if hasNamedOverride then
                    slotActions._betterui_primaryOverride()
                else
                    slotActions:DoPrimaryAction()
                end
            end
        end,
        visible = function()
            return slotActions:CheckPrimaryActionVisibility() or self:HasSelectedAction()
        end,
    }

    local function GetActionString(actionId)
        return GetString(actionId)
    end

    local function IsPrimaryAction(actionName, actionStringId)
        return actionName == GetActionString(actionStringId)
    end

    --- Table of action string IDs that should trigger a primary action replacement.
    --- Rationale: Data-driven approach is faster and easier to maintain than if-chains.
    local PRIMARY_ACTION_REPLACEMENTS = {
        [SI_ITEM_ACTION_USE] = true,
        [SI_ITEM_ACTION_EQUIP] = true,
        [SI_ITEM_ACTION_UNEQUIP] = true,
        [SI_ITEM_ACTION_BANK_WITHDRAW] = true,
        [SI_ITEM_ACTION_BANK_DEPOSIT] = true,
        [SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG] = true,
        [SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG] = true,
        [SI_ITEM_ACTION_SHOW_MAP] = true,
        [SI_ITEM_ACTION_START_SKILL_RESPEC] = true,
        [SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC] = true,
        [SI_ITEM_ACTION_PLACE_FURNITURE] = true,
        [SI_ITEM_ACTION_LINK_TO_CHAT] = true,
        [SI_ITEM_ACTION_MARK_AS_JUNK] = true,
        [SI_ITEM_ACTION_UNMARK_AS_JUNK] = true,
        [SI_ITEM_ACTION_DESTROY] = true,
    }
    if SI_ITEM_ACTION_DELETE then
        PRIMARY_ACTION_REPLACEMENTS[SI_ITEM_ACTION_DELETE] = true
    end

    -- Build a name-based lookup table for O(1) access
    local ACTION_REPLACEMENT_LOOKUP = {}
    for actionId, _ in pairs(PRIMARY_ACTION_REPLACEMENTS) do
        local name = GetActionString(actionId)
        if name then
            ACTION_REPLACEMENT_LOOKUP[name] = true
        end
    end

    local function ShouldReplacePrimaryAction(primaryAction)
        return ACTION_REPLACEMENT_LOOKUP[primaryAction] == true
        -- Note: Split stack is intentionally NOT included here so it remains
        -- available in the Y (actions) list. We still wire it up as a
        -- primary action below so A can invoke the split dialog when needed.
    end

    local function IsActionEntryVisible(actionEntry)
        local visibilityFunction = actionEntry and actionEntry[VISIBILITY_FUNCTION]
        if not visibilityFunction then return true end
        local ok, visible = pcall(visibilityFunction)
        return ok and visible == true
    end

    local function HasVisibleActionByName(slotActions, actionName)
        if not slotActions or not actionName or not slotActions.m_slotActions then
            return false
        end
        for i = 1, #slotActions.m_slotActions do
            local actionEntry = slotActions.m_slotActions[i]
            if actionEntry and actionEntry[ACTION_KEY] == actionName and IsActionEntryVisible(actionEntry) then
                return true
            end
        end
        return false
    end

    local function ResolvePreferredPrimaryAction(slotActions, primaryAction, inventorySlot)
        if not primaryAction then return nil end
        if not IsPrimaryAction(primaryAction, SI_ITEM_ACTION_LINK_TO_CHAT) then return primaryAction end

        -- Never expose "Link to Chat" as the A-button primary action.
        -- Prefer Mark as Junk; if not junkable, prefer Destroy.
        if IsSlotMarkedAsJunk(inventorySlot) then
            return GetActionString(SI_ITEM_ACTION_UNMARK_AS_JUNK)
        end
        if CanMarkSlotAsJunk(inventorySlot) then
            return GetActionString(SI_ITEM_ACTION_MARK_AS_JUNK)
        end

        local destroyActionName = GetActionString(SI_ITEM_ACTION_DESTROY)
        if destroyActionName and HasVisibleActionByName(slotActions, destroyActionName) then
            return destroyActionName
        end
        if SI_ITEM_ACTION_DELETE then
            local deleteActionName = GetActionString(SI_ITEM_ACTION_DELETE)
            if deleteActionName and HasVisibleActionByName(slotActions, deleteActionName) then
                return deleteActionName
            end
        end

        -- Fall back to any visible non-chat action discovered by the engine.
        if slotActions and slotActions.m_slotActions then
            local linkToChatName = GetActionString(SI_ITEM_ACTION_LINK_TO_CHAT)
            for i = 1, #slotActions.m_slotActions do
                local actionEntry = slotActions.m_slotActions[i]
                local discoveredActionName = actionEntry and actionEntry[ACTION_KEY]
                if discoveredActionName and discoveredActionName ~= linkToChatName and IsActionEntryVisible(actionEntry) then return discoveredActionName end
            end
        end

        return nil
    end

    local function RemoveSlotActionByName(slotActions, actionName)
        if not slotActions or not actionName or not slotActions.m_slotActions then return false end
        for i = 1, #slotActions.m_slotActions do
            local actionEntry = slotActions.m_slotActions[i]
            if actionEntry and actionEntry[ACTION_KEY] == actionName then
                table.remove(slotActions.m_slotActions, i)
                return true
            end
        end
        return false
    end

    --- Wraps an action in a secure call if necessary (primarily for USE actions).
    --- Rationale: Delegates to CIM.SetupSecureAction for shared implementation.
    --- @param slotActions table The slot actions object.
    --- @param actionStringId number The action string ID.
    --- @param callback function The callback to execute.
    --- @param inventorySlot table The inventory slot data.
    local function SetupSecureAction(slotActions, actionStringId, callback, inventorySlot)
        BETTERUI.CIM.SetupSecureAction(slotActions, actionStringId, callback, inventorySlot)
    end

    --- Configures actions related to the Craft Bag (Stow/Retrieve).
    --- Rationale: Delegates to CIM.HandleCraftBagActions for shared implementation.
    --- @param slotActions table The slot actions object.
    --- @param inventorySlot table The inventory slot data.
    --- @param canUseItem boolean Whether the item is also usable (adds USE as a secondary action).
    local function HandleCraftBagActions(slotActions, inventorySlot, canUseItem)
        BETTERUI.CIM.HandleCraftBagActions(slotActions, inventorySlot, canUseItem)
    end

    --- Sets up the primary action for a slot based on its action name.
    --- Purpose: Routes specific actions (Equip, Bank, etc.) to their specialized handlers.
    --- @param slotActions table The slot actions object.
    --- @param actionName string The localized name of the action.
    --- @param inventorySlot table The inventory slot data.
    local function SetupPrimaryAction(slotActions, actionName, inventorySlot)
        if IsPrimaryAction(actionName, SI_ITEM_ACTION_USE) then
            SetupSecureAction(slotActions, SI_ITEM_ACTION_USE, function(...) TryUseItem(inventorySlot) end, inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_PLACE_FURNITURE) then
            SetupSecureAction(slotActions, SI_ITEM_ACTION_PLACE_FURNITURE, function(...)
                if inventorySlot then
                    local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
                    if bag and slot then
                        ZO_TryPlaceFurnitureFromInventorySlot(bag, slot)
                    end
                end
            end, inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_MARK_AS_JUNK) then
            slotActions:AddSlotPrimaryAction(actionName, function(...) TryMarkAsJunk(inventorySlot) end, "primary", nil,
                { visibleWhenDead = false })
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_UNMARK_AS_JUNK) then
            slotActions:AddSlotPrimaryAction(actionName, function(...) TryUnmarkAsJunk(inventorySlot) end, "primary", nil,
                { visibleWhenDead = false })
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_EQUIP) then
            SetupSecureAction(slotActions, SI_ITEM_ACTION_EQUIP,
                function(...) GAMEPAD_INVENTORY:TryEquipItem(inventorySlot, ZO_Dialogs_IsShowingDialog()) end,
                inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_UNEQUIP) then
            SetupSecureAction(slotActions, SI_ITEM_ACTION_UNEQUIP, function(...) TryUnequipItem(inventorySlot) end,
                inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_BANK_WITHDRAW) or IsPrimaryAction(actionName, SI_ITEM_ACTION_BANK_DEPOSIT) then
            SetupSecureAction(slotActions,
                actionName == GetActionString(SI_ITEM_ACTION_BANK_WITHDRAW) and SI_ITEM_ACTION_BANK_WITHDRAW or
                SI_ITEM_ACTION_BANK_DEPOSIT,
                function(...) TryBankItem(inventorySlot) end, inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG) then
            -- Retrieve: Use quantity dialog for stacked items
            SetupSecureAction(slotActions, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG,
                function(...)
                    if BETTERUI.Inventory.Dialogs and BETTERUI.Inventory.Dialogs.TryRetrieveWithQuantity then
                        BETTERUI.Inventory.Dialogs.TryRetrieveWithQuantity(inventorySlot)
                    else
                        TryMoveToInventoryorCraftBag(inventorySlot, BAG_BACKPACK)
                    end
                end, inventorySlot)
            -- NOTE: Split Stack is NOT added here because it's handled by _betterui_primaryOverride
            -- in PrimaryCommandActivate. Adding it here would cause double invocation.
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_SHOW_MAP) then
            SetupSecureAction(slotActions, SI_ITEM_ACTION_SHOW_MAP, function(...) TryUseItem(inventorySlot) end,
                inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_START_SKILL_RESPEC) then
            SetupSecureAction(slotActions, SI_ITEM_ACTION_START_SKILL_RESPEC, function(...) TryUseItem(inventorySlot) end,
                inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC) then
            SetupSecureAction(slotActions, SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC,
                function(...) TryUseItem(inventorySlot) end, inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_DESTROY)
            or (SI_ITEM_ACTION_DELETE and IsPrimaryAction(actionName, SI_ITEM_ACTION_DELETE)) then
            slotActions:AddSlotPrimaryAction(actionName, function(...) TryDestroyPrimaryAction(inventorySlot) end, "primary",
                nil, { visibleWhenDead = false })
        end
    end

    local function PrimaryCommandHasBind()
        local inventory = GAMEPAD_INVENTORY
        local inventoryMultiSelectActive = inventory and inventory.multiSelectManager and inventory.multiSelectManager.IsActive
            and inventory.multiSelectManager:IsActive()
        local craftBagMultiSelectActive = inventory and inventory.craftBagMultiSelectManager
            and inventory.craftBagMultiSelectManager.IsActive and inventory.craftBagMultiSelectManager:IsActive()
        if inventoryMultiSelectActive or craftBagMultiSelectActive then
            return false
        end

        -- Avoid showing the primary (A) bind when the primary action is "Link to Chat",
        -- because the X button already exposes this action in the inventory UI and
        -- duplicating it on A is redundant and confusing.
        if self.actionName == GetActionString(SI_ITEM_ACTION_LINK_TO_CHAT) then
            return false
        end
        return (self.actionName ~= nil) or self:HasSelectedAction()
    end

    --[[
        Function: SecureOpenSkills
        Description: Wraps the "Open Skills" action callback in a secure call.
        Rationale: Delegates to CIM.SecureOpenSkills for shared implementation.
        param: slotActions (table) - The slot actions object
        param: inventorySlot (table) - The inventory slot data
        ]]
    local function SecureOpenSkills(slotActions, inventorySlot)
        BETTERUI.CIM.SecureOpenSkills(slotActions, inventorySlot)
    end

    --[[
        Function: ResolveCraftBagState
        Description: Determines the correct primary action based on Craft Bag context.
        Rationale: Delegates to CIM.ResolveCraftBagState for shared implementation.
        param: slotActions (table) - The slot actions object
        param: inventorySlot (table) - The inventory slot data
        param: primaryAction (string) - The current primary action name
        param: canUseItem (boolean) - Whether the item is also usable
        return: string - The resolved action name for display
        ]]
    local function ResolveCraftBagState(slotActions, inventorySlot, primaryAction, canUseItem)
        return BETTERUI.CIM.ResolveCraftBagState(slotActions, inventorySlot, primaryAction, canUseItem)
    end

    --[[
        Function: DeduplicateActions
        Description: Removes duplicate entries from the slot actions list.
        Rationale: Delegates to CIM.DeduplicateActions for shared implementation.
        param: slotActions (table) - The slot actions object to deduplicate
        ]]
    local function DeduplicateActions(slotActions)
        BETTERUI.CIM.DeduplicateActions(slotActions)
    end

    --- The main logic invoked when the primary action (A button) is potentially triggered.
    ---
    --- Purpose: **Action Discovery and Selection**.
    --- Mechanics:
    --- 1. Clears previous actions.
    --- 2. Calls `ZO_InventorySlot_DiscoverSlotActionsFromActionList`.
    --- 3. Fixes "Open Skills" to be secure.
    --- 4. **Decides Primary**:
    ---    - Use vs Stow: Prefers Stow if eligible.
    ---    - Bank Deposit/Withdraw.
    ---    - Craft Bag Retrieve/Stow.
    --- 5. Configures `slotActions` with the decision.
    --- 6. Deduplicates actions in the list.
    ---
    --- @param inventorySlot table The inventory slot data.
    local function PrimaryCommandActivate(inventorySlot)
        slotActions:Clear()
        slotActions:SetInventorySlot(inventorySlot)
        slotActions._betterui_primaryOverride = nil
        slotActions._betterui_primaryName = nil
        self.selectedAction = nil -- Do not call the update function, just clear the selected action

        if not inventorySlot then
            self.actionName = nil
            return
        end

        ZO_InventorySlot_DiscoverSlotActionsFromActionList(inventorySlot, slotActions)

        -- 1. Secure "Open Skills" callback
        SecureOpenSkills(slotActions, inventorySlot)

        local primaryAction = slotActions:GetPrimaryActionName()
        local canUseItem = false

        -- If no primary action was identified by the engine, use the first discovered action
        if not primaryAction and #slotActions.m_slotActions > 0 then
            primaryAction = slotActions.m_slotActions[1][1]
        end

        primaryAction = ResolvePreferredPrimaryAction(slotActions, primaryAction, inventorySlot)

        -- Handle primary action replacement logic
        if primaryAction and ShouldReplacePrimaryAction(primaryAction) then
            if not RemoveSlotActionByName(slotActions, primaryAction) and #slotActions.m_slotActions > 0 then
                table.remove(slotActions.m_slotActions, 1)
            end

            -- Only apply Stow logic for items NOT already in the craft bag
            if not IsSlotInCraftBag(inventorySlot) and CanItemMoveToCraftBag(inventorySlot) and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_USE) then
                canUseItem = true
                -- Remove craft bag action from secondary actions
                for i = #slotActions.m_slotActions, 1, -1 do
                    if slotActions.m_slotActions[i][1] == GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG) then
                        table.remove(slotActions.m_slotActions, i)
                        break
                    end
                end
            end
        elseif not primaryAction then
            self.actionName = nil
            slotActions._betterui_primaryOverride = nil
            slotActions._betterui_primaryName = nil
            return
        end

        -- Split Stack Override - simply calls split stack, debounce is handled by hook in Module.lua
        if primaryAction and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_SPLIT_STACK) then
            slotActions._betterui_primaryName = primaryAction
            slotActions._betterui_primaryOverride = function()
                if ZO_InventorySlot_TrySplitStack then
                    ZO_InventorySlot_TrySplitStack(inventorySlot)
                end
            end
        else
            slotActions._betterui_primaryOverride = nil
        end

        -- 2. Resolve Craft Bag vs Inventory State (Stow vs Retrieve)
        self.actionName = ResolveCraftBagState(slotActions, inventorySlot, primaryAction, canUseItem)

        -- 3. Setup secure actions based on action type
        if primaryAction then
            if IsPrimaryAction(primaryAction, SI_ITEM_ACTION_USE) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_EQUIP) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_UNEQUIP) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_BANK_WITHDRAW) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_BANK_DEPOSIT) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_SHOW_MAP) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_START_SKILL_RESPEC) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_PLACE_FURNITURE) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_MARK_AS_JUNK) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_UNMARK_AS_JUNK) or
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_DESTROY) or
                (SI_ITEM_ACTION_DELETE and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_DELETE)) then
                SetupPrimaryAction(slotActions, primaryAction, inventorySlot)
            end
            -- NOTE: Split Stack is NOT handled here - _betterui_primaryOverride above already sets it up
        end

        -- 4. Deduplicate Action List
        DeduplicateActions(slotActions)
    end

    self:AddSubCommand(primaryCommand, PrimaryCommandHasBind, PrimaryCommandActivate)

    if additionalMouseOverbinds then
        local mouseOverCommand, mouseOverCommandIsVisible
        for i = 1, #additionalMouseOverbinds do
            mouseOverCommand =
            {
                alignment = alignmentOverride,
                name = function()
                    local n = slotActions:GetKeybindActionName(i)
                    return n or ""
                end,
                keybind = additionalMouseOverbinds[i],
                callback = function() slotActions:DoKeybindAction(i) end,
                visible = function()
                    return slotActions:CheckKeybindActionVisibility(i)
                end,
            }

            mouseOverCommandIsVisible = function()
                return slotActions:GetKeybindActionName(i) ~= nil
            end

            self:AddSubCommand(mouseOverCommand, mouseOverCommandIsVisible)
        end
    end
end

--- Returns the underlying ZO_InventorySlotActions object.
--- Purpose: Required for the Y-actions dialog to iterate through available actions.
--- @return table The inner slotActions object containing the discovered actions.
function BETTERUI.Inventory.SlotActions:GetSlotActions()
    return self.slotActions
end
