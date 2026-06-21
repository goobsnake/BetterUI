-- Core Banking class definition and shared runtime state.

BETTERUI.Banking.LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW or 1
BETTERUI.Banking.LIST_DEPOSIT = BETTERUI.Banking.LIST_DEPOSIT or 2

BETTERUI.Banking.RuntimeState = BETTERUI.Banking.RuntimeState or {}
BETTERUI.Banking.RuntimeState.lastUsedBank = BETTERUI.Banking.RuntimeState.lastUsedBank or BAG_BANK
BETTERUI.Banking.RuntimeState.currentUsedBank = BETTERUI.Banking.RuntimeState.currentUsedBank or BAG_BANK
BETTERUI.Banking.RuntimeState.lastOpenedBankBag = BETTERUI.Banking.RuntimeState.lastOpenedBankBag or BAG_BANK
BETTERUI.Banking.RuntimeState.guildBank = BETTERUI.Banking.RuntimeState.guildBank or {}
BETTERUI.Banking.Transfer = type(BETTERUI.Banking.Transfer) == "table" and BETTERUI.Banking.Transfer or {}
local ResolveBankBag
local DefaultGetTransferService

---@param guildBankRuntimeState BetterUIBankingGuildBankRuntimeState|table|nil
---@return BetterUIBankingGuildBankRuntimeState
local function EnsureGuildBankRuntimeState(guildBankRuntimeState)
    guildBankRuntimeState = type(guildBankRuntimeState) == "table" and guildBankRuntimeState or {}
    if guildBankRuntimeState.isLoading == nil then
        guildBankRuntimeState.isLoading = false
    end
    return guildBankRuntimeState
end

BETTERUI.Banking.RuntimeState.guildBank = EnsureGuildBankRuntimeState(BETTERUI.Banking.RuntimeState.guildBank)

---@class BetterUIBankingTransferServiceResolveOptions
---@field createIfMissing boolean|nil

---@return BetterUIBankingTransferService|nil
local function TryInjectedTransferServiceGetter()
    local banking = BETTERUI.Banking
    local getTransferService = banking and rawget(banking, "GetTransferService") or nil
    if type(getTransferService) ~= "function" or getTransferService == DefaultGetTransferService then
        return nil
    end

    local transferService = getTransferService()
    if type(transferService) == "table" then
        return transferService
    end
    return nil
end

---@param options BetterUIBankingTransferServiceResolveOptions|nil
---@return BetterUIBankingTransferService|nil
function BETTERUI.Banking.ResolveTransferService(options)
    options = options or {}
    local createIfMissing = options.createIfMissing == true
    local injectedTransferService = TryInjectedTransferServiceGetter()
    if injectedTransferService then
        return injectedTransferService
    end

    local transferService = BETTERUI.Banking and BETTERUI.Banking.Transfer or nil
    if type(transferService) == "table" then
        return transferService
    end

    if not createIfMissing then
        return nil
    end

    transferService = {}
    BETTERUI.Banking.Transfer = transferService
    return transferService
end

---@return BetterUIBankingTransferService
function BETTERUI.Banking.EnsureTransferService()
    local transferService = BETTERUI.Banking.ResolveTransferService({ createIfMissing = true })
    if type(transferService) ~= "table" then
        transferService = {}
        BETTERUI.Banking.Transfer = transferService
    end
    return transferService
end

---@return BetterUIBankingTransferService|nil
DefaultGetTransferService = function()
    local injectedTransferService = TryInjectedTransferServiceGetter()
    if injectedTransferService then
        return injectedTransferService
    end
    return BETTERUI.Banking.ResolveTransferService({ createIfMissing = false })
end

BETTERUI.Banking.GetTransferService = DefaultGetTransferService

---@param requiredMethods string[]|nil
---@param options BetterUIBankingTransferServiceResolveOptions|nil
---@return BetterUIBankingTransferService|nil transferService
---@return string|nil reason
function BETTERUI.Banking.RequireTransferService(requiredMethods, options)
    local transferService = BETTERUI.Banking.ResolveTransferService(options)
    if type(transferService) ~= "table" then
        return nil, "transfer_service_unavailable"
    end

    if type(requiredMethods) == "table" then
        for _, methodName in ipairs(requiredMethods) do
            if type(transferService[methodName]) ~= "function" then
                return nil, string.format("transfer_service_missing_%s", tostring(methodName))
            end
        end
    end

    return transferService
end

---@param alignment integer
---@return table|nil
function BETTERUI.Banking.CreateItemActions(alignment)
    local slotActionsClass = BETTERUI.Inventory and BETTERUI.Inventory.SlotActions or nil
    if slotActionsClass and slotActionsClass.New then
        return slotActionsClass:New(alignment)
    end

    if ZO_ItemSlotActionsController and ZO_ItemSlotActionsController.New then
        return ZO_ItemSlotActionsController:New(alignment)
    end

    return nil
end

---@param bagId BagId
---@param slotIndex SlotIndex
---@return nil
function BETTERUI.Banking.ClearItemNewStatus(bagId, slotIndex)
    if bagId == nil or slotIndex == nil then
        return
    end

    local clearItemNewStatus = BETTERUI.CIM and BETTERUI.CIM.ClearItemNewStatus or nil
    if type(clearItemNewStatus) == "function" then
        clearItemNewStatus(bagId, slotIndex)
        return
    end

    if SHARED_INVENTORY and SHARED_INVENTORY.ClearNewStatus then
        local safeExecute = BETTERUI.CIM and BETTERUI.CIM.SafeExecute or nil
        if type(safeExecute) == "function" then
            safeExecute(
                "Banking.ClearItemNewStatus",
                SHARED_INVENTORY.ClearNewStatus,
                SHARED_INVENTORY,
                bagId,
                slotIndex
            )
        else
            SHARED_INVENTORY:ClearNewStatus(bagId, slotIndex)
        end
    end
end

---@return BetterUIBankingRuntimeState
function BETTERUI.Banking.GetMutableRuntimeState()
    return BETTERUI.Banking.RuntimeState
end

---@return table
function BETTERUI.Banking.GetMutableGuildBankRuntimeState()
    local runtimeState = BETTERUI.Banking.GetMutableRuntimeState()
    runtimeState.guildBank = EnsureGuildBankRuntimeState(runtimeState.guildBank)
    return runtimeState.guildBank
end

---@return BagId
function BETTERUI.Banking.GetCurrentUsedBank()
    return ResolveBankBag(BETTERUI.Banking.GetMutableRuntimeState().currentUsedBank)
end

---@return BagId
function BETTERUI.Banking.GetLastUsedBank()
    return ResolveBankBag(BETTERUI.Banking.GetMutableRuntimeState().lastUsedBank)
end

---@param bankBagId BagId|nil
---@return nil
function BETTERUI.Banking.SetLastOpenedBankBag(bankBagId)
    if bankBagId == nil then
        return
    end
    BETTERUI.Banking.GetMutableRuntimeState().lastOpenedBankBag = ResolveBankBag(bankBagId)
end

---@param currentUsedBank BagId|nil
---@param lastUsedBank BagId|nil
---@return nil
function BETTERUI.Banking.SetRuntimeBankBags(currentUsedBank, lastUsedBank)
    local runtimeState = BETTERUI.Banking.GetMutableRuntimeState()
    if currentUsedBank ~= nil then
        runtimeState.currentUsedBank = ResolveBankBag(currentUsedBank)
    end
    if lastUsedBank ~= nil then
        runtimeState.lastUsedBank = ResolveBankBag(lastUsedBank)
    end
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
ResolveBankBag = function(bankBagId)
    if bankBagId == nil or bankBagId == 0 then
        return BAG_BANK
    end
    return bankBagId
end

---@type BetterUIBankingTransferKind
BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK = BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK or "main-bank"
---@type BetterUIBankingTransferKind
BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK = BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK or "house-bank"
---@type BetterUIBankingTransferKind
BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK = BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK or "guild-bank"

---@return number
local function ResolveTransferSourceBag()
    local runtimeState = BETTERUI.Banking.GetMutableRuntimeState()
    if GetBankingBag then
        local bankingBag = ResolveBankBag(GetBankingBag())
        if bankingBag == BAG_BANK then
            local openedBankBag = runtimeState.lastOpenedBankBag
            if IsBankOpen and IsBankOpen() and IsHousingStorageBag(openedBankBag) then
                return openedBankBag
            end
            return BAG_BANK
        end
        return bankingBag
    end
    return ResolveBankBag(runtimeState.currentUsedBank)
end

---@param sourceBag number
---@return number
local function ResolveTransferTargetBag(sourceBag)
    if sourceBag == BAG_GUILDBANK or IsHousingStorageBag(sourceBag) then
        return sourceBag
    end
    -- Resolve the banking bag at call time; runtime state can be stale between
    -- bank-open and OnSceneShowing.
    if GetBankingBag then
        return ResolveBankBag(GetBankingBag())
    end
    return ResolveBankBag(BETTERUI.Banking.GetMutableRuntimeState().currentUsedBank)
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

---@return BetterUIBankingTransferKind
local function ResolveTransferKind(sourceBag)
    if sourceBag == BAG_GUILDBANK or IsGuildBankSceneShowing() then
        return BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
    end
    if sourceBag == BAG_BANK then
        return BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
    end
    return BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK
end

---@return BetterUIBankingTransferContext
local function BuildTransferContextSnapshot()
    local sourceBag = ResolveTransferSourceBag()
    local targetBag = ResolveTransferTargetBag(sourceBag)
    local kind = ResolveTransferKind(sourceBag)
    local isGuildBank = kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
    local isSourceFurnitureVault = sourceBag ~= nil and IsFurnitureVault and IsFurnitureVault(sourceBag) or false
    local isTargetFurnitureVault = targetBag ~= nil and IsFurnitureVault and IsFurnitureVault(targetBag) or false

    return {
        kind = kind,
        interactionBag = sourceBag,
        depositTargetBag = targetBag,
        withdrawSourceBags = ResolveWithdrawSourceBags(targetBag, isGuildBank),
        sourceIsFurnitureVault = isSourceFurnitureVault,
        targetIsFurnitureVault = isTargetFurnitureVault,
    }
end

-- Retained alias: tests assert this accessor's contract (test_banking_transfer.lua,
-- test_banking_contracts.lua).
function BETTERUI.Banking.GetTransferState()
    return BETTERUI.Banking.ReadTransferContextSnapshot()
end

---@return BetterUIBankingTransferContext
function BETTERUI.Banking.ReadTransferContextSnapshot()
    return BuildTransferContextSnapshot()
end

---@return boolean
function BETTERUI.Banking.IsGuildBankTransfer()
    return BETTERUI.Banking.ReadTransferContextSnapshot().kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
end

---@return BagId
function BETTERUI.Banking.GetActiveDepositBag()
    return BETTERUI.Banking.ReadTransferContextSnapshot().depositTargetBag
end

---@param entryData table|nil
---@return table|nil rawData
function BETTERUI.Banking.UnwrapListEntry(entryData)
    if not entryData then
        return nil
    end
    return entryData.dataSource or entryData
end

---@param entryData table|nil
---@return BagId|nil bagId
---@return SlotIndex|nil slotIndex
---@return table|nil rawData
function BETTERUI.Banking.ResolveListEntrySlot(entryData)
    local rawData = BETTERUI.Banking.UnwrapListEntry(entryData)
    if not rawData then
        return nil, nil, nil
    end
    local bagId = rawData.bagId
    local slotIndex = rawData.slotIndex
    if bagId == nil or slotIndex == nil then
        return nil, nil, rawData
    end
    return bagId, slotIndex, rawData
end

---@param entryData table|nil
---@return boolean
function BETTERUI.Banking.IsActionableTransferEntry(entryData)
    if not entryData then
        return false
    end

    if ZO_GamepadBanking and ZO_GamepadBanking.IsEntryDataCurrencyRelated and
        ZO_GamepadBanking.IsEntryDataCurrencyRelated(entryData) then
        return false
    end

    local bagId, slotIndex = BETTERUI.Banking.ResolveListEntrySlot(entryData)
    if bagId == nil or slotIndex == nil then
        return false
    end

    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
    return stackCount > 0
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
---@field RuntimeState BetterUIBankingRuntimeState Shared mutable Banking runtime state
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

---@return string|nil
function BETTERUI.Banking.Class:GetCurrentCategoryKey()
    local categories = self.bankCategories
    if not categories or #categories == 0 then
        return nil
    end
    local index = self.currentCategoryIndex or 1
    if index > #categories then
        return nil
    end
    local category = categories[index]
    return category and category.key or nil
end

---@param preferredCategoryKey string|nil
---@return integer
function BETTERUI.Banking.Class:ResolveCategoryIndex(preferredCategoryKey)
    if not self.bankCategories or #self.bankCategories == 0 then
        return 1
    end
    if preferredCategoryKey then
        for i, category in ipairs(self.bankCategories) do
            if category.key == preferredCategoryKey then
                return i
            end
        end
    end
    return 1
end

---@param options table|nil
---@return nil
function BETTERUI.Banking.Class:RefreshCategoryView(options)
    options = options or {}
    local preferredCategoryKey = options.preferredCategoryKey
    local refreshKeybinds = options.refreshKeybinds == true

    self.bankCategories = self:ComputeVisibleBankCategories()
    if not self.bankCategories or #self.bankCategories == 0 then
        self.currentCategoryIndex = 1
        self:RefreshList()
        if refreshKeybinds and self.RefreshActiveKeybinds then
            self:RefreshActiveKeybinds()
        end
        return
    end

    self.currentCategoryIndex = zo_clamp(
        self:ResolveCategoryIndex(preferredCategoryKey),
        1,
        #self.bankCategories
    )

    local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
    state.suppressHeaderCallback = true
    self:RebuildHeaderCategories()
    state.suppressHeaderCallback = false
    self:RefreshList()
    if refreshKeybinds and self.RefreshActiveKeybinds then
        self:RefreshActiveKeybinds()
    end
end

---@param options table|nil
---@return nil
function BETTERUI.Banking.Class:RefreshTransferView(options)
    options = options or {}
    local preferredCategoryKey = options.preferredCategoryKey
    if preferredCategoryKey == nil and self.GetCurrentCategoryKey then
        preferredCategoryKey = self:GetCurrentCategoryKey()
    end

    if self.RefreshCategoryView then
        self:RefreshCategoryView({
            preferredCategoryKey = preferredCategoryKey,
            refreshKeybinds = options.refreshKeybinds == true,
        })
    else
        self:RefreshList()
        if options.refreshKeybinds == true and self.RefreshActiveKeybinds then
            self:RefreshActiveKeybinds()
        end
    end
end

---@param window BETTERUI.Banking.Class|table|nil
---@param options table|nil
---@return nil
function BETTERUI.Banking.RefreshWindowView(window, options)
    if not window then
        return
    end

    options = options or {}
    local preferredCategoryKey = options.preferredCategoryKey
    if preferredCategoryKey == nil then
        if window.GetCurrentCategoryKey then
            preferredCategoryKey = window:GetCurrentCategoryKey()
        elseif window.bankCategories and window.currentCategoryIndex and window.currentCategoryIndex <= #window.bankCategories then
            local currentCategory = window.bankCategories[window.currentCategoryIndex]
            preferredCategoryKey = currentCategory and currentCategory.key or nil
        end
    end

    if window.RefreshTransferView then
        window:RefreshTransferView({
            preferredCategoryKey = preferredCategoryKey,
        })
        return
    end

    if window.RefreshCategoryView then
        window:RefreshCategoryView({
            preferredCategoryKey = preferredCategoryKey,
            refreshKeybinds = options.refreshKeybinds == true,
        })
        return
    end

    if window.ComputeVisibleBankCategories and window.RebuildHeaderCategories then
        window.bankCategories = window:ComputeVisibleBankCategories()
        if not window.bankCategories or #window.bankCategories == 0 then
            window.currentCategoryIndex = 1
            if window.RefreshList then
                window:RefreshList()
            end
        else
            local desiredCategoryIndex = 1
            if preferredCategoryKey then
                for i, category in ipairs(window.bankCategories) do
                    if category.key == preferredCategoryKey then
                        desiredCategoryIndex = i
                        break
                    end
                end
            end
            window.currentCategoryIndex = zo_clamp(desiredCategoryIndex, 1, #window.bankCategories)
            local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(window)
            state.suppressHeaderCallback = true
            window:RebuildHeaderCategories()
            state.suppressHeaderCallback = false
            if window.RefreshList then
                window:RefreshList()
            end
        end
    elseif window.RefreshList then
        window:RefreshList()
    end

    if options.refreshKeybinds == true and window.RefreshActiveKeybinds then
        window:RefreshActiveKeybinds()
    end
end

---@param suppressed boolean
---@return nil
function BETTERUI.Banking.Class:SetListUpdatesSuppressed(suppressed)
    self._suppressListUpdates = suppressed == true
end

---@return boolean
function BETTERUI.Banking.Class:AreListUpdatesSuppressed()
    return self._suppressListUpdates == true
end

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

-- Stat sort values resolve through the shared default
-- (BETTERUI.CIM.SortManager.GetStatSortValue).

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

--- Creates a sort comparator for a column via the shared CIM factory,
--- wiring banking-specific value getters. Banking uses no stable tie-breaker:
--- ties compare equal, preserving the pre-sort row order from table.sort.
---@param sortKey string The data field to sort by
---@param ascending boolean Whether to sort ascending
---@return fun(left: table, right: table): boolean comparator
local function CreateColumnSortComparator(sortKey, ascending)
    return BETTERUI.CIM.SortManager.CreateColumnSortComparator(sortKey, ascending, {
        getTraitValue = GetTraitSortValue,
        getValueValue = GetValueSortValue,
    })
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
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "enter selection mode")
    end
    -- Lazy-initialize manager on first use
    self:InitializeMultiSelectManager()

    local target = self.list and self.list.GetSelectedData and self.list:GetSelectedData() or nil
    if not target or (ZO_GamepadBanking and ZO_GamepadBanking.IsEntryDataCurrencyRelated
            and ZO_GamepadBanking.IsEntryDataCurrencyRelated(target)) then
        return
    end

    self:SaveListPosition()
    MultiSelectMixin.EnterSelectionMode(self)
end

--- Exits multi-select mode.
function BETTERUI.Banking.Class:ExitSelectionMode()
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "exit selection mode")
    end
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
