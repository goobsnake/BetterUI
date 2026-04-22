--[[
File: Modules/Banking/Lists/BankListManager.lua
Purpose: Manages banking list categories, filtering, sorting, and refresh logic.
         Row setup/rendering lives in BankRowSetup.lua.
]]

-- SHARED CONSTANTS & STATE
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local BANK_CATEGORY_DEFS = BETTERUI.CIM.ItemTaxonomy.BANK_CATEGORY_DEFS

-- HELPER FUNCTIONS

local function BuildAllBankCategories(isFurnitureVault)
    if isFurnitureVault then
        return {
            { key = "furnishing", name = GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_FURNISHING")), filterType = ITEMFILTERTYPE_FURNISHING, iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds" },
            { key = "junk",       name = GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_JUNK")),       filterType = nil,                       special = "junk",                                furnitureVaultJunk = true, iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds" },
        }
    end

    local out = {}
    for i = 1, #BANK_CATEGORY_DEFS do
        local def = BANK_CATEGORY_DEFS[i]
        if not def.optional or (def.optional and def.filterType ~= nil) then
            out[#out + 1] = {
                key = def.key,
                name = GetString(def.nameStringId),
                filterType = def.filterType,
                special = def.special,
                iconFile = def.iconFile,
            }
        end
    end
    return out
end

local function GetWithdrawStorageLabel(isSourceFurnitureVault, isEmpty)
    if isSourceFurnitureVault then
        local furnitureVaultName = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_STACK_COUNT_BAG_FURNITURE_VAULT"))
        if isEmpty then
            return GetString(rawget(_G, "SI_BETTERUI_BANK_FURNITURE_VAULT_EMPTY"))
        end
        return furnitureVaultName
    end

    if isEmpty then
        return GetString(rawget(_G, "SI_BETTERUI_BANK_HOUSE_EMPTY"))
    end

    return GetString(rawget(_G, "SI_BETTERUI_BANK_HOUSE"))
end

local function DoesItemMatchBankCategory(itemData, category)
    if category and category.furnitureVaultJunk then
        local isJunk = itemData and itemData.isJunk == true
        if not isJunk then
            return false
        end

        if ZO_InventoryUtils_DoesNewItemMatchFilterType then
            return ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, ITEMFILTERTYPE_FURNISHING)
        end

        if itemData and itemData.filterData then
            for _, filterData in ipairs(itemData.filterData) do
                if filterData == ITEMFILTERTYPE_FURNISHING then
                    return true
                end
            end
        end
        return false
    end

    return BETTERUI.CIM.SharedItemSupport.DoesItemMatchCategory(itemData, category)
end

local GetBestItemCategoryDescription = BETTERUI.CIM.SharedItemSupport.GetBestItemCategoryDescription

local function ResolveBagsAndSlotType(self)
    local isWithdraw = (self.currentMode == LIST_WITHDRAW)

    -- Deposit always reads from backpack
    if not isWithdraw then
        return { BAG_BACKPACK }, SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
    end

    local withdrawSourceBags = BETTERUI.Banking.GetTransferWithdrawSourceBags()
    if type(withdrawSourceBags) == "table" and #withdrawSourceBags > 0 then
        local slotType = BETTERUI.Banking.IsGuildBankTransferMode() and SLOT_TYPE_GUILD_BANK_ITEM
            or SLOT_TYPE_BANK_ITEM
        return withdrawSourceBags, slotType
    end

    local sourceBag = BETTERUI.Banking.GetTransferSourceBag()
    if sourceBag ~= nil then
        return { sourceBag }, SLOT_TYPE_BANK_ITEM
    end

    return { BAG_BANK, BAG_SUBSCRIBER_BANK }, SLOT_TYPE_BANK_ITEM
end

-- Expose helpers for use by CategoryManager (loads later)
BETTERUI.Banking.BuildAllBankCategories = BuildAllBankCategories
BETTERUI.Banking.ResolveBagsAndSlotType = ResolveBagsAndSlotType

-- LIST MANAGEMENT
-- Note: ComputeVisibleBankCategories is defined in CategoryManager.lua (loads after this file)

--- Refreshes the banking list contents.
function BETTERUI.Banking.Class:RefreshList()
    if not self.list then
        return
    end

    local transferSourceBankBag = BETTERUI.Banking.GetTransferSourceBag()
    local isGuildBankActive = BETTERUI.Banking.IsGuildBankTransferMode()
    local isSourceMainBank = BETTERUI.Banking.IsMainBankTransferSource()
    local isSourceFurnitureVault = BETTERUI.Banking.IsTransferSourceFurnitureVault()
    if self._suppressListUpdates or self.isBatchProcessing then
        return
    end

    local wasActive = self.list:IsActive()
    if wasActive then
        self.list:Deactivate()
    end

    self.list:Clear()

    if self.UpdateHeaderTitle then
        self:UpdateHeaderTitle()
    end

    local modeText = self.currentMode == LIST_WITHDRAW and GetString(rawget(_G, "SI_BETTERUI_BANKING_WITHDRAW"))
        or GetString(rawget(_G, "SI_BETTERUI_BANKING_DEPOSIT"))
    modeText = zo_strformat("<<Z:1>>", modeText)

    local activeCategory = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil

    if isSourceMainBank or isGuildBankActive then
        if not activeCategory or activeCategory.key == "all" then
            local labelByCurrency = {
                [CURT_MONEY] = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_GOLD")),
                [CURT_TELVAR_STONES] = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_TEL_VAR")),
                [CURT_ALLIANCE_POINTS] = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_ALLIANCE_POINT")),
                [CURT_WRIT_VOUCHERS] = GetString(rawget(_G, "SI_BETTERUI_CURRENCY_WRIT_VOUCHER")),
            }

            -- Guild bank only supports gold
            local bankableList
            if isGuildBankActive then
                bankableList = { CURT_MONEY }
            else
                bankableList = {}
                if type(ZO_BANKABLE_CURRENCIES) == "table" then
                    if rawget(ZO_BANKABLE_CURRENCIES, 1) ~= nil then
                        bankableList = ZO_BANKABLE_CURRENCIES
                    else
                        for _, value in pairs(ZO_BANKABLE_CURRENCIES) do
                            bankableList[#bankableList + 1] = value
                        end
                    end
                end
                if #bankableList == 0 then
                    bankableList = { CURT_MONEY, CURT_TELVAR_STONES, CURT_ALLIANCE_POINTS, CURT_WRIT_VOUCHERS }
                end
            end

            for _, currencyType in ipairs(bankableList) do
                local entryData = BETTERUI.Banking.BuildCurrencyTransferEntryData(self, currencyType, modeText,
                    labelByCurrency)
                self.list:AddEntry(BETTERUI.Banking.CURRENCY_ROW_TEMPLATE, entryData)
            end
        end
    elseif self.currentMode == LIST_WITHDRAW then
        local isStorageEmpty = (GetNumBagUsedSlots(transferSourceBankBag) == 0)
        self.list:AddEntry("BETTERUI_HeaderRow_Template",
            { label = "|cFFFFFF" .. GetWithdrawStorageLabel(isSourceFurnitureVault, isStorageEmpty) .. "|r" })
    else
        if GetNumBagUsedSlots(BAG_BACKPACK) == 0 then
            self.list:AddEntry("BETTERUI_HeaderRow_Template",
                { label = "|cFFFFFF" .. GetString(rawget(_G, "SI_BETTERUI_BANK_PLAYER_EMPTY")) .. "|r" })
        else
            self.list:AddEntry("BETTERUI_HeaderRow_Template",
                { label = "|cFFFFFF" .. GetString(rawget(_G, "SI_BETTERUI_BANK_PLAYER")) .. "|r" })
        end
    end

    local checkingBags, slotType = ResolveBagsAndSlotType(self)

    local GuildBankMode = isGuildBankActive
    local function IsNotStolenItem(itemData)
        if itemData.stolen then return false end
        -- Guild bank deposit filter: reject bound and BOP-tradeable items
        if GuildBankMode and self.currentMode ~= LIST_WITHDRAW then
            if IsItemBound and IsItemBound(itemData.bagId, itemData.slotIndex) then
                return false
            end
            if IsItemBoPAndTradeable and IsItemBoPAndTradeable(itemData.bagId, itemData.slotIndex) then
                return false
            end
            if itemData.isPlayerLocked then
                return false
            end
        end
        return true
    end

    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(IsNotStolenItem, unpack(checkingBags))
    local tempDataTable = {}

    local zoStrformat = zo_strformat
    local inventorySlotSetType = ZO_InventorySlot_SetType
    local getItemLink = GetItemLink
    local getItemLinkItemType = GetItemLinkItemType
    local getItemLinkSetInfo = GetItemLinkSetInfo
    local getItemLinkEnchantInfo = GetItemLinkEnchantInfo
    local isItemLinkRecipeKnown = IsItemLinkRecipeKnown
    local isItemLinkBookKnown = IsItemLinkBookKnown
    local isItemBound = IsItemBound
    local showJunkCategory = (activeCategory and activeCategory.key == "junk") or false
    local autoCategoryIntegration = BETTERUI.CIM and BETTERUI.CIM.AutoCategoryIntegration

    for i = 1, #filteredDataTable do
        local itemData = filteredDataTable[i]
        if not activeCategory or DoesItemMatchBankCategory(itemData, activeCategory) then
            local customCategory, matched, categoryName, categoryPriority
            if autoCategoryIntegration and type(autoCategoryIntegration.GetCustomCategory) == "function" then
                customCategory, matched, categoryName, categoryPriority = autoCategoryIntegration.GetCustomCategory(itemData)
            end
            if customCategory and not matched then
                itemData.bestItemTypeName = zoStrformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = AC_UNGROUPED_NAME
                itemData.sortPriorityName = string.format("%03d%s", 999, categoryName)
            elseif customCategory then
                itemData.bestItemTypeName = zoStrformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = categoryName
                itemData.sortPriorityName = string.format("%03d%s", 100 - categoryPriority, categoryName)
            else
                itemData.bestItemTypeName = zoStrformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = itemData.bestItemTypeName
                itemData.sortPriorityName = itemData.bestItemCategoryName
            end

            itemData.isEquippedInCurrentCategory = nil

            if not itemData.cached_itemLink then
                local itemLink = getItemLink(itemData.bagId, itemData.slotIndex)
                itemData.cached_itemLink = itemLink
                itemData.cached_itemType = itemLink and getItemLinkItemType(itemLink) or nil
                itemData.cached_setItem = itemLink and getItemLinkSetInfo(itemLink, false) or nil
                itemData.cached_hasEnchantment = itemLink and getItemLinkEnchantInfo(itemLink) or nil
                itemData.cached_isRecipeAndUnknown = (itemData.cached_itemType == ITEMTYPE_RECIPE)
                    and not (itemLink and isItemLinkRecipeKnown(itemLink))
                itemData.cached_isBookKnown = itemLink and isItemLinkBookKnown(itemLink) or nil
                itemData.cached_isUnbound = not isItemBound(itemData.bagId, itemData.slotIndex)
                    and not itemData.stolen
                    and itemData.quality ~= ITEM_QUALITY_TRASH
            end

            tempDataTable[#tempDataTable + 1] = itemData
            inventorySlotSetType(itemData, slotType)
        end
    end
    filteredDataTable = tempDataTable

    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        local query = tostring(self.searchQuery):lower()
        local matches = {}

        for i = 1, #filteredDataTable do
            local itemData = filteredDataTable[i]
            if not activeCategory or activeCategory.key == "all" or DoesItemMatchBankCategory(itemData, activeCategory) then
                local lowerName = itemData.cachedLowerName
                if not lowerName then
                    lowerName = tostring(itemData.name or ""):lower()
                    itemData.cachedLowerName = lowerName
                end
                if string.find(lowerName, query, 1, true) then
                    matches[#matches + 1] = itemData
                end
            end
        end

        filteredDataTable = matches
    end

    table.sort(filteredDataTable, self.itemSortComparator or BETTERUI.CIM.Utils.DefaultSortComparator)

    local currentBestCategoryName
    local useHeaders = AutoCategory
        and ((GetNumBagUsedSlots(transferSourceBankBag) ~= 0) or (GetNumBagUsedSlots(BAG_BACKPACK) ~= 0))

    for _, itemData in ipairs(filteredDataTable) do
        local entryData = BETTERUI.CIM.CreateItemEntryData(itemData, {
            visualDataInit = BETTERUI.CIM.InitializeSharedItemVisualData
        })

        if entryData and ((not entryData.isJunk and not showJunkCategory) or (entryData.isJunk and showJunkCategory)) then
            currentBestCategoryName = BETTERUI.CIM.AddItemEntryToList(
                self.list,
                entryData,
                currentBestCategoryName,
                useHeaders
            )
        end
    end

    if self.searchQuery and self.searchQuery ~= "" then
        self.list:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_SEARCH_NO_RESULTS")))
    else
        self.list:SetNoItemText(GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_EMPTY")))
    end

    self.list:Commit()

    local entryCount = (self.list and self.list.dataList and #self.list.dataList) or 0
    if entryCount == 0 then
        self.list:Deactivate()
    elseif BETTERUI.Utils.IsBankingSceneShowing() then
        self.list:Activate()
    end

    self:ReturnToSaved()
    self:UpdateActions()
    self:RefreshFooter()
end
