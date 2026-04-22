-- Core Banking class definition and shared runtime state.

BETTERUI.Banking.LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW or 1
BETTERUI.Banking.LIST_DEPOSIT = BETTERUI.Banking.LIST_DEPOSIT or 2

BETTERUI.Banking.RuntimeState = BETTERUI.Banking.RuntimeState or {}
BETTERUI.Banking.RuntimeState.lastUsedBank = BETTERUI.Banking.RuntimeState.lastUsedBank or BAG_BANK
BETTERUI.Banking.RuntimeState.currentUsedBank = BETTERUI.Banking.RuntimeState.currentUsedBank or BAG_BANK
BETTERUI.Banking.RuntimeState.lastOpenedBankBag = BETTERUI.Banking.RuntimeState.lastOpenedBankBag or BAG_BANK
BETTERUI.Banking.RuntimeState.guildBank = BETTERUI.Banking.RuntimeState.guildBank or {}
if BETTERUI.Banking.RuntimeState.guildBank.isLoading == nil then
    BETTERUI.Banking.RuntimeState.guildBank.isLoading = false
end
BETTERUI.Banking.Transfer = type(BETTERUI.Banking.Transfer) == "table" and BETTERUI.Banking.Transfer or {}
local ResolveBankBag
local DefaultGetTransferService

---@class BetterUIBankingTransferServiceResolveOptions
---@field createIfMissing boolean|nil

---@param options BetterUIBankingTransferServiceResolveOptions|nil
---@return BetterUIBankingTransferService|nil
function BETTERUI.Banking.ResolveTransferService(options)
    options = options or {}
    local createIfMissing = options.createIfMissing == true
    local getTransferService = BETTERUI.Banking and BETTERUI.Banking.GetTransferService or nil
    if type(getTransferService) == "function" and getTransferService ~= DefaultGetTransferService then
        local transferService = getTransferService()
        if type(transferService) == "table" then
            return transferService
        end
    end

    local transferService = BETTERUI.Banking and BETTERUI.Banking.Transfer or nil
    if type(transferService) == "table" then
        return transferService
    end

    if createIfMissing then
        transferService = {}
        BETTERUI.Banking.Transfer = transferService
        return transferService
    end

    return nil
end

---@return BetterUIBankingTransferService
DefaultGetTransferService = function()
    return BETTERUI.Banking.ResolveTransferService({ createIfMissing = true }) or {}
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
    local createItemActions = BETTERUI.CIM and BETTERUI.CIM.CreateItemActions or nil
    if type(createItemActions) == "function" then
        return createItemActions(alignment)
    end

    local inventory = BETTERUI.Inventory
    local slotActions = inventory and inventory.SlotActions or nil
    if slotActions and slotActions.New then
        return slotActions:New(alignment)
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

    local tracker = BETTERUI.Inventory and BETTERUI.Inventory.NewItemTracker or nil
    if tracker and tracker.ClearImmediate then
        tracker.ClearImmediate(bagId, slotIndex)
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

---@return BetterUIBankingRuntimeState
function BETTERUI.Banking.GetRuntimeState()
    return BETTERUI.Banking.GetMutableRuntimeState()
end

---@return table
function BETTERUI.Banking.GetMutableGuildBankRuntimeState()
    local runtimeState = BETTERUI.Banking.GetMutableRuntimeState()
    runtimeState.guildBank = runtimeState.guildBank or {}
    if runtimeState.guildBank.isLoading == nil then
        runtimeState.guildBank.isLoading = false
    end
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

---@return BagId|nil
function BETTERUI.Banking.GetLastOpenedBankBag()
    return BETTERUI.Banking.GetMutableRuntimeState().lastOpenedBankBag
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
    local runtimeState = BETTERUI.Banking.GetMutableRuntimeState()
    if sourceBag == BAG_GUILDBANK or IsHousingStorageBag(sourceBag) then
        return sourceBag
    end
    return ResolveBankBag(runtimeState.currentUsedBank)
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

function BETTERUI.Banking.GetTransferState()
    return BuildTransferContextSnapshot()
end

---@return BetterUIBankingTransferContext
function BETTERUI.Banking.GetTransferContextSnapshot()
    return BuildTransferContextSnapshot()
end

---@return BetterUIBankingTransferContext
function BETTERUI.Banking.ReadTransferContextSnapshot()
    local banking = BETTERUI.Banking
    local readers = {
        banking and banking.GetTransferContextSnapshot or nil,
        banking and banking.GetTransferState or nil,
        banking and banking.GetTransferContext or nil,
    }

    for _, reader in ipairs(readers) do
        if type(reader) == "function" then
            local transferContext = reader()
            if type(transferContext) == "table" then
                return transferContext
            end
        end
    end

    return {
        kind = BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK,
        interactionBag = BAG_BANK,
        depositTargetBag = BAG_BANK,
        withdrawSourceBags = { BAG_BANK, BAG_SUBSCRIBER_BANK },
        sourceIsFurnitureVault = false,
        targetIsFurnitureVault = false,
    }
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
