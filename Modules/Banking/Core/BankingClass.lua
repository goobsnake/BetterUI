--[[
File: Modules/Banking/Core/BankingClass.lua
Purpose: Core class definition and module-scope state for the Banking module.
         Establishes the Banking class skeleton and shared constants.
Author: BetterUI Team
Last Modified: 2026-01-26

This file is part of the Banking module decomposition. It contains:
1. Module-scope constants (LIST_WITHDRAW, LIST_DEPOSIT, bank state)
2. Shared references from CIM module
3. Class definition extending BETTERUI.Interface.Window
4. Constructor (New) method

Other Banking files extend this class with additional functionality.
]]

-------------------------------------------------------------------------------------------------
-- MODULE-SCOPE CONSTANTS
-------------------------------------------------------------------------------------------------
-- These constants are shared across all Banking module files via BETTERUI.Banking namespace.

-- List mode constants for tracking Withdraw vs Deposit state
BETTERUI.Banking.LIST_WITHDRAW                 = 1
BETTERUI.Banking.LIST_DEPOSIT                  = 2

-- Module-scope state tracking (accessed via BETTERUI.Banking namespace)
BETTERUI.Banking.lastUsedBank                  = 0
BETTERUI.Banking.currentUsedBank               = 0
BETTERUI.Banking.esoSubscriber                 = nil

-- Module-specific TaskManager for managed deferred tasks (Phase 1.1)
-- Using module-specific instance prevents ID collisions with other modules
BETTERUI.Banking.Tasks                         = BETTERUI.CIM.DeferredTask.Manager:New()

-------------------------------------------------------------------------------------------------
-- SHARED CATEGORY REFERENCES
-------------------------------------------------------------------------------------------------
-- Use centralized category definitions from CIM module to eliminate duplication.
-- These were previously defined locally as BANK_CATEGORY_DEFS and BANK_CATEGORY_ICONS.
-- See: Modules/CIM/CategoryDefinitions.lua for the source definitions.
-------------------------------------------------------------------------------------------------
BETTERUI.Banking.CATEGORY_DEFS                 = BETTERUI.Inventory.Categories.Bank

-- Reference to shared interface utilities
BETTERUI.Banking.EnsureKeybindGroupAdded       = BETTERUI.Interface.EnsureKeybindGroupAdded
BETTERUI.Banking.CreateSearchKeybindDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor

-------------------------------------------------------------------------------------------------
-- CLASS DEFINITION
-------------------------------------------------------------------------------------------------

--[[
Class: BETTERUI.Banking.Class
Description: Main class for the Banking module window.
Rationale: Subclasses BETTERUI.CIM.GenericWindow to provide a custom banking experience.
Mechanism: Inherits from GenericWindow base class to leverage shared header, footer, and list functionality.
]]
BETTERUI.Banking.Class = BETTERUI.CIM.GenericWindow:Subclass()

--[[
Function: BETTERUI.Banking.Class:New
Description: Creates a new instance of the Banking window class.
Rationale: Constructor for the Banking module.
Mechanism: Inherits from BETTERUI.CIM.GenericWindow.
param: ... (any) - Arguments passed to the parent constructor.
return: table - The new Banking Class instance.
]]
--- @param ... any Arguments passed to the parent constructor
--- @return table instance The new Banking Class instance
function BETTERUI.Banking.Class:New(...)
    return BETTERUI.CIM.GenericWindow.New(self, ...)
end

--[[
Function: BETTERUI.Banking.Class:IsSceneShowing
Description: Checks if the banking scene is currently showing.
Rationale: Delegates to CIM utility for consistent scene checks across all modules.
return: boolean - True if the banking scene is currently showing.
]]
--- @return boolean showing True if the banking scene is showing
function BETTERUI.Banking.Class:IsSceneShowing()
    return BETTERUI.CIM.Utils.IsBankingSceneShowing()
end

--[[
Function: BETTERUI.Banking.Class:SetupUnifiedFooter
Description: Configures the unified footer for BANKING mode.
Rationale: Ensures consistent footer mode when Banking scene shows.
Mechanism: Finds the UnifiedFooterController and sets BANKING mode.
]]
function BETTERUI.Banking.Class:SetupUnifiedFooter()
    -- Look for the footer controller in our control hierarchy
    local footerContainer = self.control and self.control.container and
        self.control.container:GetNamedChild("FooterContainer")
    if footerContainer and footerContainer.unifiedFooter then
        self.unifiedFooterController = footerContainer.unifiedFooter
        self.unifiedFooterController:SetMode(BETTERUI.CIM.UnifiedFooter.MODE.BANKING)
    end
end

--[[
Function: BETTERUI.Banking.Class:RefreshFooter
Description: Refreshes the footer display.
Rationale: Overrides GenericWindow placeholder to use UnifiedFooter.
]]
function BETTERUI.Banking.Class:RefreshFooter()
    if self.unifiedFooterController then
        self.unifiedFooterController:Refresh()
    else
        -- Fallback to legacy GenericFooter if unified footer not available
        if BETTERUI.GenericFooter and BETTERUI.GenericFooter.Refresh then
            BETTERUI.GenericFooter:Refresh()
        end
    end
end

--------------------------------------------------------------------------------
-- HEADER SORT MODE
--------------------------------------------------------------------------------

-- Column definitions for header sort navigation (matches Inventory)
-- Each column has a name (for display), key (internal), and sort key for item data
local BANKING_SORT_COLUMNS = {
    { name = "NAME",  key = "name",  sortKey = "name" },
    { name = "TYPE",  key = "type",  sortKey = "bestGamepadItemCategoryName" },
    { name = "TRAIT", key = "trait", sortKey = "traitType" },
    { name = "STAT",  key = "stat",  sortKey = "statValue" },
    { name = "VALUE", key = "value", sortKey = "stackSellPrice" },
}

--- Creates sort comparator for a column with the specified direction
--- @param sortKey string The key to sort by
--- @param ascending boolean True for ascending, false for descending
local function CreateColumnSortComparator(sortKey, ascending)
    return function(left, right)
        local leftVal = left[sortKey]
        local rightVal = right[sortKey]

        -- Handle nil values
        if leftVal == nil and rightVal == nil then return false end
        if leftVal == nil then return not ascending end
        if rightVal == nil then return ascending end

        -- String comparison for text columns
        if type(leftVal) == "string" and type(rightVal) == "string" then
            if ascending then
                return leftVal < rightVal
            else
                return leftVal > rightVal
            end
        end

        -- Numeric comparison
        if ascending then
            return leftVal < rightVal
        else
            return leftVal > rightVal
        end
    end
end

--- Initializes the header sort controller for this banking instance
function BETTERUI.Banking.Class:InitializeHeaderSortController()
    if self.headerSortController then return end

    local controllerClass = BETTERUI.CIM.UI.HeaderSortController
    if not controllerClass then return end

    -- Create controller with column definitions and sort callback
    self.headerSortController = controllerClass:New(
        self.list,
        BANKING_SORT_COLUMNS,
        function(columnKey, direction, sortFn)
            self:OnHeaderSortChanged(columnKey, direction)
        end
    )

    -- Initialize horizontal movement controller for L/R navigation
    self.horizontalMovementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)

    -- Apply CIM mixin to inject EnterHeaderSortMode and ExitHeaderSortMode methods
    local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration
    if HeaderSortIntegration and HeaderSortIntegration.ApplyMixin then
        HeaderSortIntegration.ApplyMixin(self, {
            list = self.list,
            keybindDescriptor = self.coreKeybinds,
            headerControllerFn = function() return self.headerSortController end,
            initControllerFn = function() self:InitializeHeaderSortController() end,
        })
    end
end

--- Called when sort direction changes on a column
--- @param columnKey string The column key that changed
--- @param direction number Sort direction constant
function BETTERUI.Banking.Class:OnHeaderSortChanged(columnKey, direction)
    local SORT_DIRECTION = BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION

    -- Find the column definition
    local column = nil
    for _, col in ipairs(BANKING_SORT_COLUMNS) do
        if col.key == columnKey then
            column = col
            break
        end
    end

    if not column then return end

    -- Update the list sort function
    if direction == SORT_DIRECTION.NONE then
        -- Reset to default sort (use Inventory default for consistency)
        self.list:SetSortFunction(BETTERUI.Banking.DefaultSortComparator or BETTERUI_Inventory_DefaultItemSortComparator)
    else
        local ascending = (direction == SORT_DIRECTION.ASCENDING)
        self.list:SetSortFunction(CreateColumnSortComparator(column.sortKey, ascending))
    end

    -- Refresh the list to apply new sort
    self:RefreshList()
end

--- Enters header sort navigation mode.
--- Called when user presses D-pad Up at the first item in the list.
-- NOTE: EnterHeaderSortMode and ExitHeaderSortMode are injected by CIM mixin.
-- See InitializeHeaderSortController where ApplyMixin is called.


--------------------------------------------------------------------------------
-- MULTI-SELECT MODE (Mirrors Inventory implementation)
--------------------------------------------------------------------------------

--- Initializes the multi-select manager.
function BETTERUI.Banking.Class:InitializeMultiSelectManager()
    if self.multiSelectManager then return end

    self.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(
        self.list,
        function(selectedCount)
            self:OnSelectionCountChanged(selectedCount)
        end
    )
end

--- Enters multi-selection mode.
function BETTERUI.Banking.Class:EnterSelectionMode()
    if self.isInSelectionMode then return end

    -- Initialize manager if needed
    self:InitializeMultiSelectManager()
    if not self.multiSelectManager then return end

    self.isInSelectionMode = true
    self.multiSelectManager:EnterSelectionMode()

    -- Select the current item automatically
    local target = self.list and self.list.selectedData
    if target then
        self.multiSelectManager:ToggleSelection(target)
    end

    -- Update keybinds for selection mode
    if self.RefreshKeybinds then
        self:RefreshKeybinds()
    end

    -- Refresh list to show selection visuals
    if self.RefreshList then
        self:RefreshList()
    end
end

--- Exits multi-selection mode.
function BETTERUI.Banking.Class:ExitSelectionMode()
    if not self.isInSelectionMode then return end

    self.isInSelectionMode = false
    if self.multiSelectManager then
        self.multiSelectManager:ExitSelectionMode()
    end

    -- Update keybinds to normal mode
    if self.RefreshKeybinds then
        self:RefreshKeybinds()
    end

    -- Refresh list to remove selection visuals
    if self.RefreshList then
        self:RefreshList()
    end
end

--- Called when the selection count changes.
--- @param selectedCount number The number of currently selected items
function BETTERUI.Banking.Class:OnSelectionCountChanged(selectedCount)
    if self.isInSelectionMode and selectedCount > 0 then
        self.selectedCount = selectedCount
    else
        self.selectedCount = 0
    end

    -- Refresh keybinds to update Y-button batch actions visibility
    if self.RefreshKeybinds then
        self:RefreshKeybinds()
    end
end

--- Gets whether selection mode is currently active.
--- @return boolean isActive
function BETTERUI.Banking.Class:IsInSelectionMode()
    return self.isInSelectionMode or false
end

--- Performs batch withdraw on all selected items.
function BETTERUI.Banking.Class:BatchWithdraw()
    if not self.multiSelectManager then return end

    local items = self.multiSelectManager:GetSelectedItems()
    for _, itemData in ipairs(items) do
        if itemData.bagId and itemData.slotIndex then
            -- Request transfer to backpack
            CallSecureProtected("RequestMoveItem", itemData.bagId, itemData.slotIndex, BAG_BACKPACK, nil,
                itemData.stackCount or 1)
        end
    end

    -- Exit selection mode after batch action
    self:ExitSelectionMode()
end
