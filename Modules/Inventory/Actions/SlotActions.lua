--[[
File: Modules/Inventory/Actions/SlotActions.lua
Purpose: Manages the "Action Controller" for inventory slots, determining
         what happens when the user presses the Primary Action key (usually 'A').
Author: BetterUI Team
Last Modified: 2026-01-28
]]

--------------------------------------------------------------------------------
-- KEY RESPONSIBILITIES:
--
-- 1.  **Primary Action Resolution**:
--     *   Determines the most appropriate action for an item (Equip, Use, Bank, Stow).
--     *   Logic is in `PrimaryCommandActivate` and `Initialize`.
--
-- 2.  **Secure Execution**:
--     *   Many inventory actions (Use, Equip, Bank) are "Protected" in ESO.
--     *   This file ensures these are called via `CallSecureProtected` to prevent
--         tainting the execution environment, which would block the action.
--     *   Special handling for `PutInInventory` vs `PlaceInTransfer`.
--
-- 3.  **Craft Bag & Banking Integration**:
--     *   Handles "Stow" (Inventory -> Craft Bag) and "Retrieve" (Craft Bag -> Inventory).
--     *   Handles Bank Deposit/Withdraw logic including checking for bag space.
--
-- 4.  **Action Menu Integration**:
--     *   Provides the data source for the "Y" button context menu (`HookActionDialog` in Inventory.lua consumes this).
--
-- ARCHITECTURE: PrimaryCommandActivate logic has been split into focused helper functions:
--   - HandleCraftBagActions: Manages Stow/Retrieve with optional USE as secondary
--   - SetupPrimaryAction: Routes specific actions to specialized handlers
--   - SecureOpenSkills: Wraps "Open Skills" in secure call
--   - ResolveCraftBagState: Determines Stow vs Retrieve based on context
--   - DeduplicateActions: Removes duplicate entries from action list
--
-- FUTURE: Add support for custom actions from other addons
--------------------------------------------------------------------------------

local ACTION_KEY = 1
local VISIBILITY_FUNCTION = 4
local OPTION_ARG = 5

local INVENTORY_SLOT_ACTIONS_USE_CONTEXT_MENU = true
local INVENTORY_SLOT_ACTIONS_PREVENT_CONTEXT_MENU = false

BETTERUI.Inventory.SlotActions = ZO_ItemSlotActionsController:Subclass()

--- Inserts a primary action at the front of the slot actions table.
--- Override of the standard AddSlotAction to force an action to be Primary (A Button).
---
--- Purpose: Sets the default "A" button behavior for a slot.
--- Mechanics:
--- - Inserts the action into index 1 of the action table.
--- - Updates `_betterui_primaryOverride` for direct invocation.
--- - Adds to Context Menu if applicable.
---
--- @param self table The SlotActions instance.
--- @param actionStringId number|string The string ID or name of the action.
--- @param actionCallback function The function to execute when the action is triggered.
--- @param actionType string The type of action (e.g., "primary").
--- @param visibilityFunction function Optional function to determine if the action is visible.
--- @param options any Optional configuration options.
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

--- Attempts to unequip an item from the specified inventory slot.
--- @param inventorySlot table The inventory slot data.
local function TryUnequipItem(inventorySlot)
    local equipSlot = ZO_Inventory_GetSlotIndex(inventorySlot)
    UnequipItem(equipSlot)
end

--- Attempts to use the item in the specified slot.
--- Rationale: Delegates to CIM.TryUseItem for shared implementation.
--- @param inventorySlot table The inventory slot data.
local function TryUseItem(inventorySlot)
    BETTERUI.CIM.TryUseItem(inventorySlot)
end

--- Handles banking actions (Deposit/Withdraw) for an item.
--- Rationale: Delegates to CIM.TryBankItem for shared implementation.
--- @param inventorySlot table The inventory slot data.
local function TryBankItem(inventorySlot)
    BETTERUI.CIM.TryBankItem(inventorySlot)
end

--- Attempts to move an item between the Backpack and the Craft Bag.
--- Rationale: Delegates to CIM.TryMoveToCraftBag for shared implementation.
--- @param inventorySlot table The inventory slot data.
--- @param targetBag number The ID of the destination bag (BAG_BACKPACK or BAG_VIRTUAL).
local function TryMoveToInventoryorCraftBag(inventorySlot, targetBag)
    BETTERUI.CIM.TryMoveToCraftBag(inventorySlot, targetBag)
end

--- Checks if an item can be moved to the Craft Bag.
--- Rationale: Delegates to CIM.CanItemMoveToCraftBag for shared implementation.
--- @param inventorySlot table The inventory slot data.
--- @return boolean True if the item is eligible for the Craft Bag.
local function CanItemMoveToCraftBag(inventorySlot)
    return BETTERUI.CIM.CanItemMoveToCraftBag(inventorySlot)
end

--- Checks if the inventory slot represents an item currently inside the Craft Bag.
--- Rationale: Delegates to CIM.IsSlotInCraftBag for shared implementation.
--- @param inventorySlot table The inventory slot data.
--- @return boolean True if the item is in the Craft Bag.
local function IsSlotInCraftBag(inventorySlot)
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
            return n or ""
        end,
        keybind = "UI_SHORTCUT_PRIMARY",
        order = 500,
        callback = function()
            if self.selectedAction then
                self:DoSelectedAction()
            else
                if slotActions._betterui_primaryOverride then
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
    }

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
            SetupSecureAction(slotActions, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG,
                function(...) TryMoveToInventoryorCraftBag(inventorySlot, BAG_BACKPACK) end, inventorySlot)
        elseif IsPrimaryAction(actionName, SI_ITEM_ACTION_SPLIT_STACK) then
            -- Wire Split Stack as a primary action so A can open the split dialog while
            -- leaving the action present in the Y actions list.
            slotActions:AddSlotPrimaryAction(GetActionString(SI_ITEM_ACTION_SPLIT_STACK), function()
                if ZO_InventorySlot_TrySplitStack then
                    ZO_InventorySlot_TrySplitStack(inventorySlot)
                end
            end, "primary", nil, { visibleWhenDead = false })
        end

        local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
            SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
            SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
        if actionName == GetActionString(SI_ITEM_ACTION_LINK_TO_CHAT) and isCompanionSceneShowing then
            -- Do not add Link to Chat action when in companion equipment scene to avoid insecure chat submits
            return
        end
    end

    local function PrimaryCommandHasBind()
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

        -- Handle primary action replacement logic
        if primaryAction and ShouldReplacePrimaryAction(primaryAction) then
            table.remove(slotActions.m_slotActions, 1)

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
            return
        end

        -- Split Stack Override logic
        if primaryAction and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_SPLIT_STACK) then
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
                IsPrimaryAction(primaryAction, SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG) then
                SetupPrimaryAction(slotActions, primaryAction, inventorySlot)
            end

            if IsPrimaryAction(primaryAction, SI_ITEM_ACTION_SPLIT_STACK) then
                local isStowAction = self.actionName == GetActionString(SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG)
                if not isStowAction then
                    SetupPrimaryAction(slotActions, primaryAction, inventorySlot)
                end
            end
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
