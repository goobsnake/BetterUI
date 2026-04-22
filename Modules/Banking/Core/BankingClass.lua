-- Core Banking class definition and shared runtime state.

BETTERUI.Banking.LIST_WITHDRAW                 = 1
BETTERUI.Banking.LIST_DEPOSIT                  = 2

local BankingRuntimeState = BETTERUI.Banking.RuntimeState or {
    lastUsedBank = BAG_BANK,
    currentUsedBank = BAG_BANK,
    lastOpenedBankBag = BAG_BANK,
    esoSubscriber = nil,
}
BETTERUI.Banking.RuntimeState = BankingRuntimeState
BETTERUI.Banking.lastUsedBank = BankingRuntimeState.lastUsedBank
BETTERUI.Banking.currentUsedBank = BankingRuntimeState.currentUsedBank
BETTERUI.Banking.lastOpenedBankBag = BankingRuntimeState.lastOpenedBankBag
BETTERUI.Banking.esoSubscriber = BankingRuntimeState.esoSubscriber

local function ReadBankingRuntimeStateField(fieldName)
    local directValue = rawget(BETTERUI.Banking, fieldName)
    if directValue ~= nil then
        return directValue
    end
    return BankingRuntimeState[fieldName]
end

local function UpdateBankingRuntimeStateField(fieldName, fieldValue)
    BankingRuntimeState[fieldName] = fieldValue
    BETTERUI.Banking[fieldName] = fieldValue
end

function BETTERUI.Banking.SetCurrentUsedBank(bankBag)
    UpdateBankingRuntimeStateField("currentUsedBank", bankBag)
end

function BETTERUI.Banking.GetCurrentUsedBank()
    return ReadBankingRuntimeStateField("currentUsedBank")
end

function BETTERUI.Banking.SetLastUsedBank(bankBag)
    UpdateBankingRuntimeStateField("lastUsedBank", bankBag)
end

function BETTERUI.Banking.GetLastUsedBank()
    return ReadBankingRuntimeStateField("lastUsedBank")
end

function BETTERUI.Banking.SetLastOpenedBankBag(bankBag)
    UpdateBankingRuntimeStateField("lastOpenedBankBag", bankBag)
end

function BETTERUI.Banking.GetLastOpenedBankBag()
    return ReadBankingRuntimeStateField("lastOpenedBankBag")
end

function BETTERUI.Banking.GetEsoSubscriber()
    return ReadBankingRuntimeStateField("esoSubscriber")
end

function BETTERUI.Banking.SetEsoSubscriber(isSubscriber)
    UpdateBankingRuntimeStateField("esoSubscriber", isSubscriber)
end

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

---@return number
local function ResolveTransferSourceBag()
    if GetBankingBag then
        local bankingBag = ResolveBankBag(GetBankingBag())
        if bankingBag == BAG_BANK then
            local openedBankBag = BETTERUI.Banking.GetLastOpenedBankBag()
            if IsBankOpen and IsBankOpen() and IsHousingStorageBag(openedBankBag) then
                return openedBankBag
            end
            return BAG_BANK
        end
        return bankingBag
    end
    return ResolveBankBag(BETTERUI.Banking.GetCurrentUsedBank())
end

---@param sourceBag number
---@return number
local function ResolveTransferTargetBag(sourceBag)
    if sourceBag == BAG_GUILDBANK or IsHousingStorageBag(sourceBag) then
        return sourceBag
    end
    return ResolveBankBag(BETTERUI.Banking.GetCurrentUsedBank())
end

---@param targetBag number
---@param isGuildBank boolean
---@return number[]
local function ResolveWithdrawSourceBags(targetBag, isGuildBank)
    if isGuildBank then
        return { BAG_GUILDBANK }
    end
    if targetBag == BAG_BANK then
        return { BAG_BANK, BAG_SUBSCRIBER_BANK }
    end
    return { targetBag }
end

---@return BetterUIBankingTransferContext context
local function ResolveTransferContext()
    local sourceBag = ResolveTransferSourceBag()
    local targetBag = ResolveTransferTargetBag(sourceBag)
    local isGuildBankSceneShowing = IsGuildBankSceneShowing()
    local isGuildBank = sourceBag == BAG_GUILDBANK or isGuildBankSceneShowing
    local isSourceFurnitureVault = sourceBag ~= nil and IsFurnitureVault and IsFurnitureVault(sourceBag)
    local isSourceHouseBank = sourceBag ~= nil and IsHouseBankBag and IsHouseBankBag(sourceBag)
    local isTargetFurnitureVault = targetBag ~= nil and IsFurnitureVault and IsFurnitureVault(targetBag)
    local isTargetHouseBank = targetBag ~= nil and IsHouseBankBag and IsHouseBankBag(targetBag)

    return {
        sourceBag = sourceBag,
        targetBag = targetBag,
        withdrawSourceBags = ResolveWithdrawSourceBags(targetBag, isGuildBank),
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

function BETTERUI.Banking.GetActiveTransferContext()
    return ResolveTransferContext()
end

function BETTERUI.Banking.GetTransferSourceBag()
    return ResolveTransferSourceBag()
end

function BETTERUI.Banking.GetTransferTargetBag()
    return ResolveTransferTargetBag(ResolveTransferSourceBag())
end

function BETTERUI.Banking.GetTransferWithdrawSourceBags()
    local targetBag = BETTERUI.Banking.GetTransferTargetBag()
    return ResolveWithdrawSourceBags(targetBag, BETTERUI.Banking.IsGuildBankTransferMode())
end

function BETTERUI.Banking.IsGuildBankTransferMode()
    local sourceBag = ResolveTransferSourceBag()
    return sourceBag == BAG_GUILDBANK or IsGuildBankSceneShowing()
end

function BETTERUI.Banking.IsMainBankTransferSource()
    return BETTERUI.Banking.GetTransferSourceBag() == BAG_BANK
end

function BETTERUI.Banking.IsMainBankTransferTarget()
    return BETTERUI.Banking.GetTransferTargetBag() == BAG_BANK
end

function BETTERUI.Banking.IsHouseBankTransferSource()
    local sourceBag = BETTERUI.Banking.GetTransferSourceBag()
    return sourceBag ~= nil and IsHouseBankBag and IsHouseBankBag(sourceBag) or false
end

function BETTERUI.Banking.IsHouseBankTransferTarget()
    local targetBag = BETTERUI.Banking.GetTransferTargetBag()
    return targetBag ~= nil and IsHouseBankBag and IsHouseBankBag(targetBag) or false
end

function BETTERUI.Banking.IsTransferSourceFurnitureVault()
    local sourceBag = BETTERUI.Banking.GetTransferSourceBag()
    return sourceBag ~= nil and IsFurnitureVault and IsFurnitureVault(sourceBag) or false
end

function BETTERUI.Banking.IsTransferTargetFurnitureVault()
    local targetBag = BETTERUI.Banking.GetTransferTargetBag()
    return targetBag ~= nil and IsFurnitureVault and IsFurnitureVault(targetBag) or false
end

---@param source string
---@return table transferSupport
function BETTERUI.Banking.RequireTransferSupport(source)
    local transferSupport = BETTERUI.Banking.transferSupport
    if type(transferSupport) ~= "table" then
        local getTransferSupport = BETTERUI.Banking.GetTransferSupport
        if type(getTransferSupport) == "function" then
            transferSupport = getTransferSupport()
        end
    end
    assert(type(transferSupport) == "table",
        "BetterUI: Banking transfer support must load before " .. tostring(source))
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
