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

--------------------------------------------------------------------------------
-- HEADER SORT MODE
--------------------------------------------------------------------------------
-- Column definitions for header sort navigation (matches Inventory)
-- Each column has a name (for display), key (internal), sortKey, and optional defaultDirection
local BANKING_SORT_COLUMNS = {
    { name = "NAME",  key = "name",  sortKey = "name" },
    { name = "TYPE",  key = "type",  sortKey = "bestGamepadItemCategoryName" },
    { name = "TRAIT", key = "trait", sortKey = "trait" },                                                       -- Special handling for alphabetical sort
    { name = "STAT",  key = "stat",  sortKey = "stat" },                                                        -- Special handling for mixed alpha/numeric
    { name = "VALUE", key = "value", sortKey = "value",                      defaultDirection = "descending" }, -- Market price, default high-to-low
}

--- Helper: Get trait display name for sorting (alphabetical with blanks last)
--- Returns uppercase trait name for consistent sorting
--- @param data table Item data
--- @return string|nil Trait name (uppercase) or nil if no trait
local function GetTraitSortValue(data)
    if not data then return nil end

    -- Check for dataSource (ZO_GamepadEntryData wraps item data)
    local itemData = data.dataSource or data

    -- Use cached trait name if available and not blank
    local cachedTrait = itemData.cached_traitName or data.cached_traitName
    if cachedTrait and cachedTrait ~= "-" and cachedTrait ~= "" then
        return cachedTrait:upper() -- Normalize to uppercase
    end

    -- Try to get trait type from stored data first
    local traitType = itemData.traitType or itemData.traitInformation or data.traitType

    -- If no cached traitType, get it directly from the API using bagId/slotIndex
    if not traitType or traitType == 0 then
        local bagId = itemData.bagId or data.bagId
        local slotIndex = itemData.slotIndex or data.slotIndex
        if bagId and slotIndex and GetItemTrait then
            traitType = GetItemTrait(bagId, slotIndex)
        end
    end

    -- Convert trait type to name
    if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE and traitType ~= 0 then
        local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
        if traitName and traitName ~= "" then
            local result = traitName:upper() -- Normalize to uppercase
            itemData.cached_traitName = result
            return result
        end
    end

    return nil -- Return nil for blanks (sorted last)
end

--- Helper: Get stat sort value (alphabetical first, then numeric, blanks last)
--- Returns: sortPriority (1=alpha, 2=numeric, 3=blank), sortValue
--- @param data table Item data
--- @return number priority Sort priority (1=alpha, 2=numeric, 3=blank)
--- @return string|number value Value to compare within priority
local function GetStatSortValue(data)
    if not data then return 3, "" end

    local statValue = data.statValue
    if statValue == nil or statValue == "" or statValue == 0 or statValue == "-" then
        return 3, "" -- Blank - lowest priority
    end

    -- Convert to string for analysis
    local statStr = tostring(statValue)

    -- Check if purely numeric
    local numVal = tonumber(statStr)
    if numVal then
        return 2, numVal -- Numeric - medium priority
    end

    -- Check if starts with letter (alphabetical)
    if statStr:match("^%a") then
        return 1, statStr:upper() -- Alphabetical - highest priority
    end

    -- Special characters
    return 2.5, statStr -- After numeric, before blank
end

--- Helper: Get value sort value (market price first, then vendor price)
--- @param data table Item data
--- @return number price Best available price
local function GetValueSortValue(data)
    if not data then return 0 end

    local itemData = data.dataSource or data

    if itemData.cached_marketPrice then
        return itemData.cached_marketPrice
    end

    -- Try to get market price first
    if BETTERUI.GetMarketPrice then
        local itemLink = itemData.itemLink or itemData.cached_itemLink or
        (itemData.bagId and itemData.slotIndex and GetItemLink(itemData.bagId, itemData.slotIndex))
        if itemLink then
            local marketPrice = BETTERUI.GetMarketPrice(itemLink, itemData.stackCount or 1)
            if marketPrice and marketPrice > 0 then
                itemData.cached_marketPrice = marketPrice
                return marketPrice
            end
        end
    end

    -- Fall back to vendor price
    local vendorPrice = itemData.stackSellPrice or 0
    itemData.cached_marketPrice = vendorPrice
    return vendorPrice
end

--- Creates sort comparator for a column with the specified direction
--- Handles special cases: TRAIT (alphabetical, blanks last), STAT (alpha/numeric/blank),
--- VALUE (market price priority)
--- @param sortKey string The key to sort by
--- @param ascending boolean True for ascending, false for descending
local function CreateColumnSortComparator(sortKey, ascending)
    -- TRAIT: Alphabetical with blanks after "z"
    if sortKey == "trait" then
        return function(left, right)
            local leftVal = GetTraitSortValue(left)
            local rightVal = GetTraitSortValue(right)

            -- Blanks (nil) always sort last regardless of direction
            if leftVal == nil and rightVal == nil then return false end
            if leftVal == nil then return false end -- left is blank, goes after right
            if rightVal == nil then return true end -- right is blank, left goes first

            -- Alphabetical comparison
            local leftUpper = tostring(leftVal):upper()
            local rightUpper = tostring(rightVal):upper()
            if ascending then
                return leftUpper < rightUpper
            else
                return leftUpper > rightUpper
            end
        end
    end

    -- STAT: Alphabetical first, then numeric by value, special chars, blanks last
    if sortKey == "stat" then
        return function(left, right)
            local leftPrio, leftVal = GetStatSortValue(left)
            local rightPrio, rightVal = GetStatSortValue(right)

            -- Blanks (priority 3) always sort last regardless of direction
            if leftPrio == 3 and rightPrio == 3 then return false end
            if leftPrio == 3 then return false end -- left is blank, goes after right
            if rightPrio == 3 then return true end -- right is blank, left goes first

            -- Different priorities: sort by priority (alpha < numeric < special)
            if leftPrio ~= rightPrio then
                if ascending then
                    return leftPrio < rightPrio
                else
                    return leftPrio > rightPrio
                end
            end

            -- Same priority: compare values
            if ascending then
                return leftVal < rightVal
            else
                return leftVal > rightVal
            end
        end
    end

    -- VALUE: Market price first, then vendor price
    -- Descending: highest first, 0 last
    -- Ascending: 0 first (lowest), then lowest to highest
    if sortKey == "value" then
        return function(left, right)
            local leftVal = GetValueSortValue(left)
            local rightVal = GetValueSortValue(right)

            -- Handle zero values based on sort direction
            if ascending then
                -- Ascending: 0 comes first (lowest value)
                if leftVal == 0 and rightVal == 0 then return false end
                if leftVal == 0 then return true end   -- left is 0, goes before right
                if rightVal == 0 then return false end -- right is 0, left goes after right
            else
                -- Descending: 0 comes last (after highest values)
                if leftVal == 0 and rightVal == 0 then return false end
                if leftVal == 0 then return false end -- left is 0, goes after right
                if rightVal == 0 then return true end -- right is 0, left goes first
            end

            if ascending then
                return leftVal < rightVal
            else
                return leftVal > rightVal
            end
        end
    end

    -- Default comparator for NAME, TYPE, and other columns
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

    -- Note: Column labels are linked separately via LinkColumnLabels() after AddColumn() calls
end

--- Links column header labels to the sort controller for visual feedback
--- Must be called AFTER AddColumn() populates self.header.columns
function BETTERUI.Banking.Class:LinkColumnLabels()
    if not self.headerSortController then return end
    if not self.header or not self.header.columns then return end
    if not self.headerSortController.SetColumnLabel then return end

    -- header.columns is populated by AddColumn() with the actual label controls
    for i, labelControl in ipairs(self.header.columns) do
        if labelControl then
            self.headerSortController:SetColumnLabel(i, labelControl)
        end
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

    -- Store sort comparator in instance variable (NOT on list)
    -- This ensures currency rows at the top are not affected by sorting
    if direction == SORT_DIRECTION.NONE then
        -- Reset to default sort
        self.itemSortComparator = nil
    else
        local ascending = (direction == SORT_DIRECTION.ASCENDING)
        self.itemSortComparator = CreateColumnSortComparator(column.sortKey, ascending)
    end

    -- Save current selection before refreshing
    local selectedData = self.list:GetSelectedData()
    local savedUniqueId = selectedData and selectedData.uniqueId

    -- Refresh the list to apply new sort
    self:RefreshList()

    -- Restore selection by finding the item with the same uniqueId
    if savedUniqueId then
        local dataList = self.list.dataList
        for i, entry in ipairs(dataList or {}) do
            if entry.uniqueId == savedUniqueId then
                self.list:SetSelectedIndexWithoutAnimation(i)
                break
            end
        end
    end
    -- NOTE: Keybinds are protected by UpdateActions guard which skips
    -- itemActions:SetInventorySlot() when isInHeaderSortMode is true
end

--- Enters header sort navigation mode.
--- Called when user presses D-pad Up at the first item in the list.
-- NOTE: EnterHeaderSortMode and ExitHeaderSortMode are injected by CIM mixin.
-- See InitializeHeaderSortController where ApplyMixin is called.


--------------------------------------------------------------------------------
-- MULTI-SELECT MODE (delegates to CIM.MultiSelectMixin)
--------------------------------------------------------------------------------

--- Initializes the multi-select manager and applies the shared mixin.
function BETTERUI.Banking.Class:InitializeMultiSelectManager()
    if self.multiSelectManager then return end

    self.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(
        self.list,
        function(selectedCount)
            self:OnSelectionCountChanged(selectedCount)
        end
    )

    -- Apply the shared mixin with Banking-specific hooks
    local MSMixin = BETTERUI.CIM.MultiSelectMixin
    MSMixin.Apply(self, {
        getList = function(s) return s.list end,
        refreshList = function(s) s:RefreshList() end,
        isSceneShowing = function(s) return s:IsSceneShowing() end,
        getSceneExitLabel = function()
            return GetString(SI_BETTERUI_SCENE_BANKING)
        end,
        refreshKeybinds = function(s)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(s.coreKeybinds)
            if s.withdrawDepositKeybinds then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(s.withdrawDepositKeybinds)
            end
        end,
    })
end

-- Delegate lifecycle and batch methods to the shared mixin.
-- Banking-specific operations (BatchTransfer, ShowBatchActionsMenu) remain
-- in MultiSelectActions.lua.
local MSMixin = BETTERUI.CIM.MultiSelectMixin

function BETTERUI.Banking.Class:EnterSelectionMode()
    -- Lazy-initialize manager on first use
    self:InitializeMultiSelectManager()

    local target = self.list and self.list.GetSelectedData and self.list:GetSelectedData() or nil
    if not target or ZO_GamepadBanking.IsEntryDataCurrencyRelated(target) then
        return
    end

    self:SaveListPosition()
    MSMixin.EnterSelectionMode(self)
end

function BETTERUI.Banking.Class:ExitSelectionMode()
    MSMixin.ExitSelectionMode(self)
end

function BETTERUI.Banking.Class:OnSelectionCountChanged(selectedCount)
    MSMixin.OnSelectionCountChanged(self, selectedCount)
end

function BETTERUI.Banking.Class:IsInSelectionMode()
    return MSMixin.IsInSelectionMode(self)
end

function BETTERUI.Banking.Class:IsBatchProcessing()
    return MSMixin.IsBatchProcessing(self)
end

function BETTERUI.Banking.Class:CanAbortBatch()
    return MSMixin.CanAbortBatch(self)
end

function BETTERUI.Banking.Class:RequestBatchAbort()
    return MSMixin.RequestBatchAbort(self)
end

function BETTERUI.Banking.Class:ProcessBatchThrottled(items, actionFn, onComplete, actionName, batchOptions)
    MSMixin.ProcessBatchThrottled(self, items, actionFn, onComplete, actionName, batchOptions)
end

function BETTERUI.Banking.Class:BatchLock()
    MSMixin.BatchLock(self)
end

function BETTERUI.Banking.Class:BatchUnlock()
    MSMixin.BatchUnlock(self)
end

function BETTERUI.Banking.Class:BatchMarkAsJunk()
    MSMixin.BatchMarkAsJunk(self)
end

function BETTERUI.Banking.Class:BatchUnmarkAsJunk()
    MSMixin.BatchUnmarkAsJunk(self)
end
