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
function BETTERUI.Inventory.RegisterSlotAction(id, config)
    if not id or not config or not config.name or not config.callback then
        BETTERUI.Debug("RegisterSlotAction: missing required id, name, or callback")
        return false
    end
    m_customActions[id] = config
    return true
end

--- Unregisters a previously registered custom slot action.
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
local function TryUnequipItem(inventorySlot)
    if not inventorySlot then return end

    -- POSITION PRESERVATION: Save uniqueId/index at action START before callbacks corrupt data
    if GAMEPAD_INVENTORY then
        local slotData = inventorySlot.dataSource or inventorySlot
        local uid = slotData.uniqueId
        if uid then
            GAMEPAD_INVENTORY._preserveUniqueId = uid
        end
        if GAMEPAD_INVENTORY.itemList and GAMEPAD_INVENTORY.itemList.selectedIndex then
            GAMEPAD_INVENTORY._preserveIndex = GAMEPAD_INVENTORY.itemList.selectedIndex
        end
    end

    local equipSlot = ZO_Inventory_GetSlotIndex(inventorySlot)
    if equipSlot then UnequipItem(equipSlot) end
end

--- Attempts to use the item in the specified slot.
local function TryUseItem(inventorySlot)
    if not inventorySlot then return end

    -- POSITION PRESERVATION: Save uniqueId/index at action START before callbacks corrupt data
    if GAMEPAD_INVENTORY then
        local slotData = inventorySlot.dataSource or inventorySlot
        local uid = slotData.uniqueId
        if uid then
            GAMEPAD_INVENTORY._preserveUniqueId = uid
        end
        if GAMEPAD_INVENTORY.itemList and GAMEPAD_INVENTORY.itemList.selectedIndex then
            GAMEPAD_INVENTORY._preserveIndex = GAMEPAD_INVENTORY.itemList.selectedIndex
        end
    end

    BETTERUI.CIM.TryUseItem(inventorySlot)
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
}

local function ShouldReplacePrimaryAction(primaryAction)
    -- Deferred build: populate name-based lookup on first call so GetString()
    -- runs after the engine has fully loaded localized strings.
    if not ShouldReplacePrimaryAction._lookup then
        local lookup = {}
        for actionId in pairs(PRIMARY_ACTION_REPLACEMENTS) do
            local name = GetActionString(actionId)
            if name then lookup[name] = true end
        end
        ShouldReplacePrimaryAction._lookup = lookup
    end
    return ShouldReplacePrimaryAction._lookup[primaryAction] == true
    -- Note: Split stack is intentionally NOT included so it remains
    -- available in the Y (actions) list.
end

--- Sets up the primary action for a slot based on its action name.
--- Routes specific actions (Equip, Bank, etc.) to their specialized handlers.
local function SetupPrimaryAction(actionsList, actionName, inventorySlot)
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
                if not BETTERUI.CIM.TryCall("Inventory.Dialogs.TryRetrieveWithQuantity", inventorySlot) then
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
    end

    local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
        SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
        SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
    if actionName == GetActionString(SI_ITEM_ACTION_LINK_TO_CHAT) and isCompanionSceneShowing then
        return
    end
end

--- Injects custom registered actions from external addons into the slot actions list.
local function InjectCustomActions(slotActions, inventorySlot)
    for actionId, customAction in pairs(m_customActions) do
        local visible = true
        if customAction.visibilityFunction then
            local ok, result = pcall(customAction.visibilityFunction, inventorySlot)
            visible = ok and result
        end
        if visible then
            local name = customAction.name
            if type(name) == "function" then
                local ok, result = pcall(name, inventorySlot)
                name = ok and result or nil
            end
            if name then
                slotActions:AddSlotAction(
                    name,
                    function()
                        local ok, err = pcall(customAction.callback, inventorySlot)
                        if not ok then
                            BETTERUI.Debug("Custom action '" .. tostring(actionId) .. "' error: " .. tostring(err))
                        end
                    end,
                    "secondary",
                    customAction.visibilityFunction and function()
                        local ok, result = pcall(customAction.visibilityFunction, inventorySlot)
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
function BETTERUI.Inventory.SlotActions:ActivatePrimaryCommand(inventorySlot)
    local slotActions = self.slotActions
    slotActions:Clear()
    slotActions:SetInventorySlot(inventorySlot)
    self.selectedAction = nil

    if not inventorySlot then
        self.actionName = nil
        return
    end

    ZO_InventorySlot_DiscoverSlotActionsFromActionList(inventorySlot, slotActions)

    -- 1. Secure "Open Skills" callback
    BETTERUI.CIM.SecureOpenSkills(slotActions, inventorySlot)

    local primaryAction = slotActions:GetPrimaryActionName()
    local canUseItem = false

    if not primaryAction and #slotActions.m_slotActions > 0 then
        primaryAction = slotActions.m_slotActions[1][1]
    end

    -- Handle primary action replacement logic
    if primaryAction and ShouldReplacePrimaryAction(primaryAction) then
        table.remove(slotActions.m_slotActions, 1)

        if not IsSlotInCraftBag(inventorySlot) and CanItemMoveToCraftBag(inventorySlot) and IsPrimaryAction(primaryAction, SI_ITEM_ACTION_USE) then
            canUseItem = true
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

    -- Split Stack Override
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
    self.actionName = BETTERUI.CIM.ResolveCraftBagState(slotActions, inventorySlot, primaryAction, canUseItem)

    -- 3. Setup secure actions based on action type
    if primaryAction and ShouldReplacePrimaryAction(primaryAction) then
        SetupPrimaryAction(slotActions, primaryAction, inventorySlot)
    end

    -- 4. Inject custom registered actions from external addons
    InjectCustomActions(slotActions, inventorySlot)

    -- 5. Deduplicate Action List
    BETTERUI.CIM.DeduplicateActions(slotActions)
end

--- Initializes the slot actions controller, defining how actions are prioritized and executed.
---
--- Sets up the ZO_InventorySlotActions instance, hooks the primary action mechanism,
--- and wires keybind commands for the A button and optional mouse-over binds.
---
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
            return n or selfRef.actionName or ""
        end,
        keybind = "UI_SHORTCUT_PRIMARY",
        order = 500,
        callback = function()
            if selfRef.selectedAction then
                selfRef:DoSelectedAction()
            elseif slotActions._betterui_primaryOverride then
                slotActions._betterui_primaryOverride()
            else
                slotActions:DoPrimaryAction()
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
function BETTERUI.Inventory.SlotActions:GetSlotActions()
    return self.slotActions
end
