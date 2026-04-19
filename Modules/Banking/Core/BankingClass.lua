--[[
File: Modules/Banking/Core/BankingClass.lua
Purpose: Core class definition and module-scope state for the Banking module.
         Establishes the Banking class skeleton and shared constants.

This file is part of the Banking module decomposition. It contains:
1. Module-scope constants (LIST_WITHDRAW, LIST_DEPOSIT, bank state)
2. Shared references from CIM module
3. Class definition extending BETTERUI.Interface.Window
4. Constructor (New) method

Other Banking files extend this class with additional functionality.
]]

-- MODULE-SCOPE CONSTANTS
-- These constants are shared across all Banking module files via BETTERUI.Banking namespace.

-- List mode constants for tracking Withdraw vs Deposit state
BETTERUI.Banking.LIST_WITHDRAW                 = 1
BETTERUI.Banking.LIST_DEPOSIT                  = 2

-- Module-scope state tracking (accessed via BETTERUI.Banking namespace)
BETTERUI.Banking.lastUsedBank                  = BAG_BANK
BETTERUI.Banking.currentUsedBank               = BAG_BANK
BETTERUI.Banking.lastOpenedBankBag             = BAG_BANK
BETTERUI.Banking.esoSubscriber                 = nil

local function IsHousingStorageBag(bankBagId)
    if not bankBagId then
        return false
    end

    if IsFurnitureVault and IsFurnitureVault(bankBagId) then
        return true
    end

    if IsHouseBankBag and IsHouseBankBag(bankBagId) then
        return true
    end

    return false
end

local function IsGuildBankSceneShowing()
    local guildBankScene = BETTERUI_GUILD_BANKING_SCENE
    if not guildBankScene then
        return false
    end
    if guildBankScene.IsShowing then
        return guildBankScene:IsShowing() == true
    end
    return guildBankScene.isShowing == true
end

--- Normalizes a banking bag value to BetterUI's explicit banking contract.
---@param bankBagId number|nil
---@return number
local function ResolveBankBag(bankBagId)
    if bankBagId == nil or bankBagId == 0 then
        return BAG_BANK
    end
    return bankBagId
end

---@class BetterUIBankingTransferContext
---@field sourceBag number Active source bag for transfer and withdraw flows
---@field targetBag number Active destination bag for deposit and list updates
---@field withdrawSourceBags number[] Normalized source bags for withdraw-list operations
---@field isMainBank boolean True when the active source bag is the personal bank
---@field isSourceMainBank boolean True when source bag is BAG_BANK
---@field isSourceHouseBank boolean True when source bag is a house bank storage bag (including furniture vault)
---@field isSourceFurnitureVault boolean True when source bag is a furniture vault
---@field isSourceGuildBank boolean True when source bag is BAG_GUILDBANK
---@field isGuildBank boolean True when guild-bank mode is active
---@field isGuildBankSceneShowing boolean True when guild-bank scene visibility drives context before bag updates
---@field isTargetMainBank boolean True when the target bag is BAG_BANK
---@field isTargetHouseBank boolean True when target bag is a house bank storage bag (including furniture vault)
---@field isTargetFurnitureVault boolean True when target bag is a furniture vault
---@field isTargetGuildBank boolean True when target bag is BAG_GUILDBANK

--- Returns the active banking transfer context so callers do not reinterpret bag helpers.
---@return BetterUIBankingTransferContext context
function BETTERUI.Banking.GetActiveTransferContext()
    local sourceBag
    if GetBankingBag then
        local bankingBag = ResolveBankBag(GetBankingBag())
        if bankingBag == BAG_BANK then
            local openedBankBag = BETTERUI.Banking.lastOpenedBankBag
            if IsBankOpen and IsBankOpen() and IsHousingStorageBag(openedBankBag) then
                sourceBag = openedBankBag
            else
                sourceBag = BAG_BANK
            end
        elseif IsHousingStorageBag(bankingBag) then
            sourceBag = bankingBag
        else
            sourceBag = bankingBag
        end
    else
        sourceBag = ResolveBankBag(BETTERUI.Banking.currentUsedBank)
    end

    local targetBag
    if sourceBag == BAG_GUILDBANK or IsHousingStorageBag(sourceBag) then
        targetBag = sourceBag
    else
        targetBag = ResolveBankBag(BETTERUI.Banking.currentUsedBank)
    end

    local isGuildBankSceneShowing = IsGuildBankSceneShowing()
    local isGuildBank = sourceBag == BAG_GUILDBANK or isGuildBankSceneShowing
    local withdrawSourceBags
    if isGuildBank then
        withdrawSourceBags = { BAG_GUILDBANK }
    elseif targetBag == BAG_BANK then
        withdrawSourceBags = { BAG_BANK, BAG_SUBSCRIBER_BANK }
    else
        withdrawSourceBags = { targetBag }
    end
    local isSourceFurnitureVault = sourceBag ~= nil and IsFurnitureVault and IsFurnitureVault(sourceBag)
    local isSourceHouseBank = sourceBag ~= nil and IsHouseBankBag and IsHouseBankBag(sourceBag)
    local isTargetFurnitureVault = targetBag ~= nil and IsFurnitureVault and IsFurnitureVault(targetBag)
    local isTargetHouseBank = targetBag ~= nil and IsHouseBankBag and IsHouseBankBag(targetBag)

    return {
        sourceBag = sourceBag,
        targetBag = targetBag,
        withdrawSourceBags = withdrawSourceBags,
        isMainBank = sourceBag == BAG_BANK,
        isSourceMainBank = sourceBag == BAG_BANK,
        isSourceHouseBank = isSourceHouseBank,
        isSourceFurnitureVault = isSourceFurnitureVault,
        isSourceGuildBank = isGuildBank,
        isTargetMainBank = targetBag == BAG_BANK,
        isTargetHouseBank = isTargetHouseBank,
        isTargetFurnitureVault = isTargetFurnitureVault,
        isTargetGuildBank = targetBag == BAG_GUILDBANK,
        isGuildBank = isGuildBank,
        isGuildBankSceneShowing = isGuildBankSceneShowing,
    }
end

--- Returns the active transfer source bag.
---@return number sourceBag
function BETTERUI.Banking.GetTransferSourceBankBag()
    local transferContext = BETTERUI.Banking.GetActiveTransferContext()
    return transferContext and transferContext.sourceBag or BAG_BANK
end

--- Returns the active transfer destination bag.
---@return number targetBag
function BETTERUI.Banking.GetTransferDestinationBankBag()
    local transferContext = BETTERUI.Banking.GetActiveTransferContext()
    return transferContext and transferContext.targetBag or BAG_BANK
end

--- Returns the normalized withdraw source-bag list.
---@return number[] withdrawSourceBags
function BETTERUI.Banking.GetTransferWithdrawSourceBags()
    local transferContext = BETTERUI.Banking.GetActiveTransferContext()
    local withdrawSourceBags = transferContext and transferContext.withdrawSourceBags or nil
    if type(withdrawSourceBags) == "table" and #withdrawSourceBags > 0 then
        return withdrawSourceBags
    end
    return { BAG_BANK, BAG_SUBSCRIBER_BANK }
end

--- Returns whether guild-bank transfer mode is active.
---@return boolean isGuildBank
function BETTERUI.Banking.IsGuildBankTransferMode()
    local transferContext = BETTERUI.Banking.GetActiveTransferContext()
    return transferContext and transferContext.isGuildBank == true or false
end

--- Returns whether the transfer source resolves to the main bank.
---@return boolean isMainBank
function BETTERUI.Banking.IsMainBankTransferSource()
    local transferContext = BETTERUI.Banking.GetActiveTransferContext()
    return transferContext and transferContext.isSourceMainBank == true or false
end

--- Returns whether the transfer destination resolves to the main bank.
---@return boolean isMainBank
function BETTERUI.Banking.IsMainBankTransferTarget()
    local transferContext = BETTERUI.Banking.GetActiveTransferContext()
    return transferContext and transferContext.isTargetMainBank == true or false
end

--- Returns whether the transfer source resolves to a house bank bag.
---@return boolean isHouseBank
function BETTERUI.Banking.IsHouseBankTransferSource()
    local transferContext = BETTERUI.Banking.GetActiveTransferContext()
    return transferContext and transferContext.isSourceHouseBank == true or false
end

--- Returns whether the transfer source resolves to furniture vault storage.
---@return boolean isFurnitureVault
function BETTERUI.Banking.IsFurnitureVaultTransferSource()
    local transferContext = BETTERUI.Banking.GetActiveTransferContext()
    return transferContext and transferContext.isSourceFurnitureVault == true or false
end

--- Resolves the shared transfer support table from the canonical Banking seam.
---@return table|nil transferSupport
function BETTERUI.Banking.ResolveTransferSupport()
    local transferSupport = BETTERUI.Banking.transferSupport
    if type(transferSupport) == "table" then
        return transferSupport
    end

    local getTransferSupport = BETTERUI.Banking.GetTransferSupport
    if type(getTransferSupport) ~= "function" then
        return nil
    end

    transferSupport = getTransferSupport()
    if type(transferSupport) ~= "table" then
        return nil
    end

    return transferSupport
end

-- Module-specific TaskManager for managed deferred tasks (Phase 1.1)
-- Using module-specific instance prevents ID collisions with other modules
local BankingDeferredTask = assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask,
    "BetterUI: CIM.DeferredTask must load before Banking/Core/BankingClass")
local function EnsureBankingTaskManager()
    if not BETTERUI.Banking._taskManager then
        BETTERUI.Banking._taskManager = BankingDeferredTask.CreateManager()
    end
    return BETTERUI.Banking._taskManager
end
BETTERUI.Banking.EnsureTaskManager             = EnsureBankingTaskManager
BETTERUI.Banking.Tasks                         = BETTERUI.Banking.Tasks or BankingDeferredTask.CreateLazyManagerProxy(EnsureBankingTaskManager)
local CompareNils = BETTERUI.CIM.Utils.CompareNils

-- SHARED CATEGORY REFERENCES
-- Use centralized category definitions from CIM module to eliminate duplication.
-- These were previously defined locally as BANK_CATEGORY_DEFS and BANK_CATEGORY_ICONS.
-- See: Modules/CIM/Core/Data/ItemTaxonomy.lua for the source definitions.
assert(BETTERUI.CIM and BETTERUI.CIM.ItemTaxonomy, "BetterUI: CIM.ItemTaxonomy must load before Banking/Core/BankingClass")
assert(BETTERUI.CIM and BETTERUI.CIM.GenericWindow, "BetterUI: CIM.GenericWindow must load before Banking/Core/BankingClass")
BETTERUI.Banking.CATEGORY_DEFS                 = BETTERUI.CIM.ItemTaxonomy.BANK_CATEGORY_DEFS

-- Reference to shared interface utilities
BETTERUI.Banking.EnsureKeybindGroupAdded       = BETTERUI.Interface.EnsureKeybindGroupAdded
BETTERUI.Banking.CreateSearchKeybindDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor

-- CLASS DEFINITION

---@class BETTERUI.Banking.Class : BETTERUI.CIM.GenericWindow
---@field LIST_WITHDRAW number List mode constant for withdraw view
---@field LIST_DEPOSIT number List mode constant for deposit view
---@field lastUsedBank number Last bank bag ID used
---@field currentUsedBank number Currently active bank bag ID
---@field esoSubscriber boolean|nil Whether player has ESO+ subscription
---@field Tasks DeferredTaskManager Module-specific deferred task manager
---@field CATEGORY_DEFS table Category definitions from BETTERUI.CIM.ItemTaxonomy
---@field headerSortController table|nil Header sort controller instance
---@field horizontalMovementController table|nil Movement controller for L/R navigation
---@field multiSelectManager table|nil Multi-select manager instance
---@field itemSortComparator function|nil Active sort comparator for item rows
---@field unifiedFooterController table|nil Unified footer controller instance
---@field coreKeybinds BetterUIKeybindDescriptorGroup|nil Primary banking navigation keybinds
---@field withdrawDepositKeybinds BetterUIKeybindDescriptorGroup|nil Item-transfer keybinds
---@field currencySelectorKeybinds BetterUIKeybindDescriptorGroup|nil Currency amount selector keybinds
---@field currencyKeybinds BetterUIKeybindDescriptorGroup|nil Currency row interaction keybinds
---@field textSearchKeybindStripDescriptor BetterUIKeybindDescriptorGroup|nil Active search keybind group
BETTERUI.Banking.Class = BETTERUI.CIM.GenericWindow:Subclass()

function BETTERUI.Banking.Class:New(...)
    return BETTERUI.CIM.GenericWindow.New(self, ...)
end

function BETTERUI.Banking.Class:IsSceneShowing()
    return BETTERUI.Utils.IsBankingSceneShowing()
end

--[[
Function: BETTERUI.Banking.Class:SetupUnifiedFooter
Description: Configures the unified footer for BANKING mode.
]]
--- Configures the unified footer for BANKING mode.
function BETTERUI.Banking.Class:SetupUnifiedFooter()
    -- Look for the footer controller in our control hierarchy
    local footerContainer = self.control and self.control.container and
        self.control.container:GetNamedChild("FooterContainer")
    if footerContainer and footerContainer.unifiedFooter then
        self.unifiedFooterController = footerContainer.unifiedFooter
        self.unifiedFooterController:SetMode(BETTERUI.CIM.UnifiedFooter.MODE.BANKING)
    end
end

-- HEADER SORT MODE
-- Column definitions for header sort navigation (matches Inventory)
-- Each column has a name (for display), key (internal), sortKey, and optional defaultDirection
---@type BetterUIHeaderSortColumnDef[]
local BANKING_SORT_COLUMNS = {
    { name = "NAME",  key = "name",  sortKey = "name" },
    { name = "TYPE",  key = "type",  sortKey = "bestGamepadItemCategoryName" },
    { name = "TRAIT", key = "trait", sortKey = "trait" },                                                       -- Special handling for alphabetical sort
    { name = "STAT",  key = "stat",  sortKey = "stat" },                                                        -- Special handling for mixed alpha/numeric
    { name = "VALUE", key = "value", sortKey = "value",                      defaultDirection = "descending" }, -- Market price, default high-to-low
}

--- Helper: Get trait display name for sorting (alphabetical with blanks last)
--- Returns uppercase trait name for consistent sorting
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
local function GetValueSortValue(data)
    if not data then return 0 end

    local itemData = data.dataSource or data

    if itemData.cached_marketPrice then
        return itemData.cached_marketPrice
    end

    -- Try to get market price first
    local marketIntegration = BETTERUI.CIM and BETTERUI.CIM.MarketIntegration
    if marketIntegration and type(marketIntegration.GetMarketPrice) == "function" then
        local itemLink = itemData.itemLink or itemData.cached_itemLink or
        (itemData.bagId and itemData.slotIndex and GetItemLink(itemData.bagId, itemData.slotIndex))
        if itemLink then
            local marketPrice = marketIntegration.GetMarketPrice(itemLink, itemData.stackCount or 1)
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
local function CreateColumnSortComparator(sortKey, ascending)
    -- TRAIT: Alphabetical with blanks after "z"
    if sortKey == "trait" then
        return function(left, right)
            local leftVal = GetTraitSortValue(left)
            local rightVal = GetTraitSortValue(right)

            -- Blanks (nil) always sort last regardless of direction
            local nilResult = CompareNils(leftVal, rightVal, true)
            if nilResult ~= nil then return nilResult end

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
        local nilResult = CompareNils(leftVal, rightVal, ascending)
        if nilResult ~= nil then return nilResult end

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

--- Initializes the header sort controller for this banking instance.
---@param instance BETTERUI.Banking.Class
---@return BetterUIHeaderSortInstallOptions
local function BuildBankingHeaderSortInstallOptions(instance)
    return {
        list = instance.list,
        columns = BANKING_SORT_COLUMNS,
        callbacks = {
            onSortChanged = function(columnKey, direction)
                instance:OnHeaderSortChanged(columnKey, direction)
            end,
        },
        controllerContract = {
            field = "headerSortController",
        },
        keybinds = {
            mainDescriptor = instance.coreKeybinds,
        },
        navigation = {
            suspendTabBar = true,
        },
    }
end

function BETTERUI.Banking.Class:InitializeHeaderSortController()
    local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration
    if not (HeaderSortIntegration and HeaderSortIntegration.Install) then
        return
    end

    if not self.horizontalMovementController then
        self.horizontalMovementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)
    end

    if not self._headerSortIntegration then
        HeaderSortIntegration.Install(self, BuildBankingHeaderSortInstallOptions(self))
    end

    self.headerSortController = HeaderSortIntegration.EnsureController(self._headerSortIntegration)
end

--- Links column header labels to the sort controller for visual feedback.
--- Must be called AFTER AddColumn() populates self.header.columns.
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
    -- Keybinds are protected by UpdateActions guard which skips
    -- itemActions:SetInventorySlot() when isInHeaderSortMode is true
end

--- Enters header sort navigation mode.
--- Called when user presses D-pad Up at the first item in the list.
-- EnterHeaderSortMode and ExitHeaderSortMode are injected by CIM mixin.
-- See InitializeHeaderSortController where ApplyMixin is called.


-- MULTI-SELECT MODE (delegates to CIM.MultiSelectMixin)

--- Initializes the multi-select manager and applies the shared mixin.
function BETTERUI.Banking.Class:InitializeMultiSelectManager()
    if not self.multiSelectManager then
        self.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(
            self.list,
            function(selectedCount)
                self:OnSelectionCountChanged(selectedCount)
            end
        )
    end

    -- Apply the shared mixin with Banking-specific hooks
    local MultiSelectMixin = BETTERUI.CIM.MultiSelectMixin
    MultiSelectMixin.Apply(self, {
        getList = function(s) return s.list end,
        refreshList = function(s) s:RefreshList() end,
        isSceneShowing = function(s) return s:IsSceneShowing() end,
        getSceneExitLabel = function()
            return GetString(rawget(_G, "SI_BETTERUI_SCENE_BANKING"))
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
local MultiSelectMixin = BETTERUI.CIM.MultiSelectMixin

--- Enters multi-select mode.
function BETTERUI.Banking.Class:EnterSelectionMode()
    -- Lazy-initialize manager on first use
    self:InitializeMultiSelectManager()

    local target = self.list and self.list.GetSelectedData and self.list:GetSelectedData() or nil
    if not target or ZO_GamepadBanking.IsEntryDataCurrencyRelated(target) then
        return
    end

    self:SaveListPosition()
    MultiSelectMixin.EnterSelectionMode(self)
end

--- Exits multi-select mode.
function BETTERUI.Banking.Class:ExitSelectionMode()
    local shouldRefreshJunkCategories = self._pendingJunkCategoryRefresh == true
    self._pendingJunkCategoryRefresh = nil
    MultiSelectMixin.ExitSelectionMode(self)
    if shouldRefreshJunkCategories and self.RequestJunkCategoryRefresh then
        self:RequestJunkCategoryRefresh(160)
    end
end

-- Canonical pure delegate binding point for banking multi-select surface.
MultiSelectMixin.BindDelegates(BETTERUI.Banking.Class, {
    "OnSelectionCountChanged",
    "IsInSelectionMode",
    "IsBatchProcessing",
    "CanAbortBatch",
    "RequestBatchAbort",
    "ProcessBatchThrottled",
    "BatchLock",
    "BatchUnlock",
})

--- Marks all selected items as junk.
function BETTERUI.Banking.Class:BatchMarkAsJunk()
    if self.IsFurnitureVaultContext and self:IsFurnitureVaultContext() then
        return
    end
    self._pendingJunkCategoryRefresh = true
    MultiSelectMixin.BatchMarkAsJunk(self)
    if not self:IsBatchProcessing() then
        self._pendingJunkCategoryRefresh = nil
    end
end

--- Unmarks all selected items as junk.
function BETTERUI.Banking.Class:BatchUnmarkAsJunk()
    if self.IsFurnitureVaultContext and self:IsFurnitureVaultContext() then
        return
    end
    self._pendingJunkCategoryRefresh = true
    MultiSelectMixin.BatchUnmarkAsJunk(self)
    if not self:IsBatchProcessing() then
        self._pendingJunkCategoryRefresh = nil
    end
end
