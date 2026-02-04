--[[
File: Modules/Banking/Lists/BankListManager.lua
Purpose: Manages the banking list, including filtering, sorting, and category logic.
         Extracted from Banking.lua to separate list management from core logic.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS & STATE
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW      = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT       = BETTERUI.Banking.LIST_DEPOSIT

local BANK_CATEGORY_DEFS = BETTERUI.Banking.CATEGORY_DEFS

-------------------------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------------------------

--[[
Function: BuildAllBankCategories
Description: Builds the full list of bank categories.
]]
local function BuildAllBankCategories(isFurnitureVault)
    if isFurnitureVault then
        return {
            { key = "all",        name = GetString(SI_BETTERUI_INV_ITEM_ALL),        filterType = nil,                       iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds" },
            { key = "furnishing", name = GetString(SI_BETTERUI_INV_ITEM_FURNISHING), filterType = ITEMFILTERTYPE_FURNISHING, iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds" },
        }
    end
    local out = {}
    for i = 1, #BANK_CATEGORY_DEFS do
        local def = BANK_CATEGORY_DEFS[i]
        if not def.optional or (def.optional and def.filterType ~= nil) then
            local name = GetString(def.nameStringId)
            out[#out + 1] = {
                key = def.key,
                name = name,
                filterType = def.filterType,
                special = def.special,
                iconFile =
                    def.iconFile
            }
        end
    end
    return out
end

--[[
Function: DoesItemMatchBankCategory
Description: Wrapper for the shared category matching function.
]]
local function DoesItemMatchBankCategory(itemData, category)
    return BETTERUI.Inventory.Categories.DoesItemMatchCategory(itemData, category)
end

--[[
Shared Helper Functions
Note: GetCategoryTypeFromWeaponType and GetBestItemCategoryDescription have been
consolidated into CIM/CategoryDefinitions.lua to eliminate code duplication
between Banking and Inventory modules.
]]
local GetCategoryTypeFromWeaponType = BETTERUI.Inventory.Categories.GetCategoryTypeFromWeaponType
local GetBestItemCategoryDescription = BETTERUI.Inventory.Categories.GetBestItemCategoryDescription



-------------------------------------------------------------------------------------------------
-- EXTERNAL FUNCTIONS (Attached to Class)
-------------------------------------------------------------------------------------------------

--[[
Function: SetupLabelListing
Description: Template setup for simple label rows (e.g. headers or currency).
]]
function BETTERUI.Banking.Class.SetupLabelListing(control, data)
    control:GetNamedChild("Label"):SetText(data.label)
    -- Use Banking module's custom font descriptor for Name column
    local font = BETTERUI.Banking.GetNameFontDescriptor()
    control:GetNamedChild("Label"):SetFont(font)
end

--[[
Function: ComputeVisibleBankCategories
Description: Compute the subset of categories that actually contain items for the current bank mode.
]]
function BETTERUI.Banking.Class.ComputeVisibleBankCategories(self)
    -- Access shared state via namespace since we lack local context
    local currentUsedBank = BETTERUI.Banking.currentUsedBank

    local isFurnitureVault = IsFurnitureVault(GetBankingBag())
    local allCategories = BuildAllBankCategories(isFurnitureVault)
    -- Always include 'all' explicitly so currency rows can appear even if no items
    local visibility = {}
    local itemCounts = {} -- Track item count per category for badge display
    for _, c in ipairs(allCategories) do
        visibility[c.key] = false
        itemCounts[c.key] = 0
    end
    visibility["all"] = true

    -- TODO(refactor): Extract bag setup logic to shared helper - duplicated at line 227
    -- Determine which bags to scan based on mode
    local bags = {}
    local slotType
    if self.currentMode == LIST_WITHDRAW then
        if currentUsedBank == BAG_BANK then
            bags = { BAG_BANK, BAG_SUBSCRIBER_BANK }
        else
            bags = { currentUsedBank }
        end
        slotType = SLOT_TYPE_BANK_ITEM
    else
        bags = { BAG_BACKPACK }
        slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
    end

    -- Exclude stolen items from banking list per existing behavior
    local function IsNotStolenItem(itemData)
        return not itemData.stolen
    end
    local data = SHARED_INVENTORY:GenerateFullSlotData(IsNotStolenItem, unpack(bags))

    -- Count items per category (full scan for accurate counts)
    local totalItems = 0
    for i = 1, #data do
        local itemData = data[i]
        totalItems = totalItems + 1
        for _, cat in ipairs(allCategories) do
            if cat.key ~= "all" then
                if DoesItemMatchBankCategory(itemData, cat) then
                    visibility[cat.key] = true
                    itemCounts[cat.key] = itemCounts[cat.key] + 1
                end
            end
        end
    end
    -- "All" category shows total item count
    itemCounts["all"] = totalItems

    -- Build the final ordered list with only visible categories
    local out = {}
    for _, cat in ipairs(allCategories) do
        if visibility[cat.key] then
            cat.itemCount = itemCounts[cat.key] -- Attach count for header display
            out[#out + 1] = cat
        end
    end
    return out
end

--[[
Function: BETTERUI.Banking.Class:RefreshList
Description: Refreshes the banking list contents.
]]
function BETTERUI.Banking.Class:RefreshList()
    local currentUsedBank = BETTERUI.Banking.currentUsedBank

    -- If we're in the middle of a tab selection animation, skip interim refreshes
    if self._suppressListUpdates then return end
    -- Temporarily deactivate to avoid parametric scroll list update races while rebuilding
    local wasActive = self.list:IsActive()
    if wasActive then
        self.list:Deactivate()
    end

    self.list:Clear()

    -- Update the header title with current category
    if self.UpdateHeaderTitle then
        self:UpdateHeaderTitle()
    end

    -- We have to add 2 rows to the list, one for Withdraw/Deposit GOLD and one for Withdraw/Deposit TEL-VAR
    local wdString = self.currentMode == LIST_WITHDRAW and GetString(SI_BETTERUI_BANKING_WITHDRAW) or
        GetString(SI_BETTERUI_BANKING_DEPOSIT)
    wdString = zo_strformat("<<Z:1>>", wdString)

    local activeCategoryForHeader = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    if (currentUsedBank == BAG_BANK) then
        if not activeCategoryForHeader or activeCategoryForHeader.key == "all" then
            -- Build currency transfer rows dynamically; guard older APIs without ZO_BANKABLE_CURRENCIES
            local labelByCurrency = {
                [CURT_MONEY] = GetString(SI_BETTERUI_CURRENCY_GOLD),
                [CURT_TELVAR_STONES] = GetString(SI_BETTERUI_CURRENCY_TEL_VAR),
                [CURT_ALLIANCE_POINTS] = GetString(SI_BETTERUI_CURRENCY_ALLIANCE_POINT),
                [CURT_WRIT_VOUCHERS] = GetString(SI_BETTERUI_CURRENCY_WRIT_VOUCHER),
            }
            local bankableList = {}
            if type(ZO_BANKABLE_CURRENCIES) == "table" then
                -- Prefer array-style if available
                if (rawget(ZO_BANKABLE_CURRENCIES, 1) ~= nil) then
                    bankableList = ZO_BANKABLE_CURRENCIES
                else
                    for _, v in pairs(ZO_BANKABLE_CURRENCIES) do table.insert(bankableList, v) end
                end
            end
            if #bankableList == 0 then
                bankableList = { CURT_MONEY, CURT_TELVAR_STONES, CURT_ALLIANCE_POINTS, CURT_WRIT_VOUCHERS }
            end
            for _, currencyType in ipairs(bankableList) do
                local label = labelByCurrency[currencyType] or
                    (GetCurrencyName and GetCurrencyName(currencyType, true, false)) or tostring(currencyType)
                self.list:AddEntry("BETTERUI_HeaderRow_Template",
                    { label = "|cFFFFFF" .. wdString .. " " .. tostring(label) .. "|r", currencyType = currencyType })
            end
        end
    else
        if (self.currentMode == LIST_WITHDRAW) then
            if (GetNumBagUsedSlots(currentUsedBank) == 0) then
                self.list:AddEntry("BETTERUI_HeaderRow_Template",
                    { label = "|cFFFFFF" .. GetString(SI_BETTERUI_BANK_HOUSE_EMPTY) .. "|r" })
            else
                self.list:AddEntry("BETTERUI_HeaderRow_Template",
                    { label = "|cFFFFFF" .. GetString(SI_BETTERUI_BANK_HOUSE) .. "|r" })
            end
        else
            if (GetNumBagUsedSlots(BAG_BACKPACK) == 0) then
                self.list:AddEntry("BETTERUI_HeaderRow_Template",
                    { label = "|cFFFFFF" .. GetString(SI_BETTERUI_BANK_PLAYER_EMPTY) .. "|r" })
            else
                self.list:AddEntry("BETTERUI_HeaderRow_Template",
                    { label = "|cFFFFFF" .. GetString(SI_BETTERUI_BANK_PLAYER) .. "|r" })
            end
        end
    end
    local checking_bags = {}
    local slotType
    if (self.currentMode == LIST_WITHDRAW) then
        if (currentUsedBank == BAG_BANK) then
            checking_bags[1] = BAG_BANK
            checking_bags[2] = BAG_SUBSCRIBER_BANK
            slotType = SLOT_TYPE_BANK_ITEM
        else
            checking_bags[1] = currentUsedBank
            slotType = SLOT_TYPE_BANK_ITEM
        end
    else
        checking_bags[1] = BAG_BACKPACK
        slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
    end

    local function IsNotStolenItem(itemData)
        local isNotStolen = not itemData.stolen
        return isNotStolen
    end

    --excludes stolen items
    local filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(IsNotStolenItem, unpack(checking_bags))

    local tempDataTable = {}
    -- Localize globals used in the loop for performance
    local zo_strformat = zo_strformat
    local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
    local GetItemLink = GetItemLink
    local GetItemLinkItemType = GetItemLinkItemType
    local GetItemLinkSetInfo = GetItemLinkSetInfo
    local GetItemLinkEnchantInfo = GetItemLinkEnchantInfo
    local IsItemLinkRecipeKnown = IsItemLinkRecipeKnown
    local IsItemLinkBookKnown = IsItemLinkBookKnown
    local IsItemBound = IsItemBound
    local activeCategory = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    local showJunkCategory = (activeCategory and activeCategory.key == "junk") or false
    for i = 1, #filteredDataTable do
        local itemData = filteredDataTable[i]
        if activeCategory and not DoesItemMatchBankCategory(itemData, activeCategory) then
            -- skip items not in the selected category
        else
            --use custom categories
            local customCategory, matched, catName, catPriority = BETTERUI.GetCustomCategory(itemData)
            if customCategory and not matched then
                itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = AC_UNGROUPED_NAME
                itemData.sortPriorityName = string.format("%03d%s", 999, catName)
            else
                if customCategory then
                    itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER,
                        GetBestItemCategoryDescription(itemData))
                    itemData.bestItemCategoryName = catName
                    itemData.sortPriorityName = string.format("%03d%s", 100 - catPriority, catName)
                else
                    itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER,
                        GetBestItemCategoryDescription(itemData))
                    itemData.bestItemCategoryName = itemData.bestItemTypeName
                    itemData.sortPriorityName = itemData.bestItemCategoryName
                end
            end

            -- Bank items are never "equipped" since they're in storage, not on character
            -- (Unlike Inventory where BAG_WORN items can be equipped)
            itemData.isEquippedInCurrentCategory = nil

            -- Cache expensive/commonly used item link information
            if not itemData.cached_itemLink then
                local itemLink = GetItemLink(itemData.bagId, itemData.slotIndex)
                itemData.cached_itemLink = itemLink
                itemData.cached_itemType = itemLink and GetItemLinkItemType(itemLink) or nil
                itemData.cached_setItem = itemLink and GetItemLinkSetInfo(itemLink, false) or nil
                itemData.cached_hasEnchantment = itemLink and GetItemLinkEnchantInfo(itemLink) or nil
                itemData.cached_isRecipeAndUnknown = (itemData.cached_itemType == ITEMTYPE_RECIPE) and
                    not (itemLink and IsItemLinkRecipeKnown(itemLink))
                itemData.cached_isBookKnown = itemLink and IsItemLinkBookKnown(itemLink) or nil
                itemData.cached_isUnbound = not IsItemBound(itemData.bagId, itemData.slotIndex) and not itemData.stolen and
                    itemData.quality ~= ITEM_QUALITY_TRASH
            end

            tempDataTable[#tempDataTable + 1] = itemData
            ZO_InventorySlot_SetType(itemData, slotType)
        end
    end
    filteredDataTable = tempDataTable

    -- Apply text search filtering
    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        local q = tostring(self.searchQuery):lower()
        local matches = {}

        for i = 1, #filteredDataTable do
            local it = filteredDataTable[i]
            -- If an active non-all category is selected, skip items that do not belong to it
            if not activeCategory or activeCategory.key == "all" or DoesItemMatchBankCategory(it, activeCategory) then
                -- Use cached lowercase name if available, otherwise compute and cache it
                local lname = it.cachedLowerName
                if not lname then
                    lname = tostring(it.name or ""):lower()
                    it.cachedLowerName = lname
                end
                if string.find(lname, q, 1, true) then
                    matches[#matches + 1] = it
                end
            end
        end

        filteredDataTable = matches
    end

    -- Use itemSortComparator if set (for column header sorting), otherwise use default
    -- This only applies to items, NOT currency rows which are added before this loop
    local sortFn = self.itemSortComparator or BETTERUI.Inventory.DefaultSortComparator
    table.sort(filteredDataTable, sortFn)

    local currentBestCategoryName

    -- Use AutoCategory headers if plugin is present and bags have items
    local useHeaders = AutoCategory and
        ((GetNumBagUsedSlots(currentUsedBank) ~= 0) or (GetNumBagUsedSlots(BAG_BACKPACK) ~= 0))

    for i, itemData in ipairs(filteredDataTable) do
        -- Create Entry using shared CIM factory
        local data = BETTERUI.CIM.CreateItemEntryData(itemData, {
            visualDataInit = BETTERUI.Inventory.Class.InitializeInventoryVisualData
        })

        if data then
            if (not data.isJunk and not showJunkCategory) or (data.isJunk and showJunkCategory) then
                currentBestCategoryName = BETTERUI.CIM.AddItemEntryToList(
                    self.list,
                    data,
                    currentBestCategoryName,
                    useHeaders
                )
            end
        end
    end

    self.list:Commit()
    -- If list becomes empty, deactivate to avoid parametric list moving errors
    local entryCount = (self.list and self.list.dataList and #self.list.dataList) or 0
    if entryCount == 0 then
        self.list:Deactivate()
    elseif BETTERUI.CIM.Utils.IsBankingSceneShowing() then
        -- IMPORTANT: Only activate when scene is showing to prevent premature
        -- DIRECTIONAL_INPUT registration during addon load (fixes joystick lock-up)
        self.list:Activate()
    end
    self:ReturnToSaved()
    self:UpdateActions()
    self:RefreshFooter()
end

--[[
Function: OnItemSelectedChange
Description: Callback when list selection changes.
Rationale: Manages keybind swapping and tooltip updates based on selection type.
Mechanism: Delegates to helpers for currency rows, item rows, and keybind updates.
References: Called by list selection change callback.
]]

--------------------------------------------------------------------------------
-- SELECTION CHANGE HELPERS
--------------------------------------------------------------------------------

--[[
Function: UpdateKeybindsForSelection
Description: Updates keybind button groups based on whether a currency or item row is selected.
Rationale: Extracted from OnItemSelectedChange to eliminate 4x repetition of keybind update pattern.
param: self (table) - The Banking class instance.
param: isCurrencyRow (boolean) - True if currency row is selected.
]]
local function UpdateKeybindsForSelection(self, isCurrencyRow)
    -- Skip keybind updates when in header sort mode - header has its own keybinds
    if self.isInHeaderSortMode then
        return
    end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
    if isCurrencyRow then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.currencyKeybinds)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.currencyKeybinds)
    else
        KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)
    end
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
end

--[[
Function: HandleItemRowSelection
Description: Handles tooltip layout for item rows.
Rationale: Extracted from OnItemSelectedChange to improve readability.
param: selectedData (table) - The selected item data.
]]
local function HandleItemRowSelection(selectedData)
    if selectedData.bagId and selectedData.slotIndex then
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedData.bagId, selectedData.slotIndex)
        -- Apply BetterUI tooltip enhancements (price info, trait info, etc.)
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        if tooltip then
            tooltip._betterui_bagId = selectedData.bagId
            tooltip._betterui_slotIndex = selectedData.slotIndex
            tooltip._betterui_itemLink = GetItemLink(selectedData.bagId, selectedData.slotIndex)
        end
        BETTERUI.Inventory.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)
    else
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    end
end

--[[
Function: HandleCurrencyRowSelection
Description: Handles keybinds and tooltip for currency header rows.
Rationale: Extracted from OnItemSelectedChange to reduce nesting.
param: self (table) - The Banking class instance.
]]
local function HandleCurrencyRowSelection(self)
    UpdateKeybindsForSelection(self, true)
    BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
    self:RefreshCurrencyTooltip()
end

--------------------------------------------------------------------------------
-- MAIN SELECTION CHANGE HANDLER
--------------------------------------------------------------------------------

function BETTERUI.Banking.Class.OnItemSelectedChange(self, list, selectedData)
    -- Check if we are on the "Deposit/withdraw" gold/telvar row
    local currentUsedBank = BETTERUI.Banking.currentUsedBank

    if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then
        return
    end

    -- Handle empty selection
    if not selectedData then
        UpdateKeybindsForSelection(self, false)
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
        self:UpdateActions()
        return
    end

    -- Only treat currency header rows when the active category is All Items
    local activeCategoryForHeader = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil

    if currentUsedBank == BAG_BANK then
        local isCurrencyRow = selectedData.label ~= nil
            and activeCategoryForHeader
            and activeCategoryForHeader.key == "all"

        if isCurrencyRow then
            HandleCurrencyRowSelection(self)
        else
            UpdateKeybindsForSelection(self, false)
            HandleItemRowSelection(selectedData)
        end
    else
        -- Non-bank bags (guild bank, house bank, etc.)
        UpdateKeybindsForSelection(self, false)
        HandleItemRowSelection(selectedData)
        self:RefreshCurrencyTooltip()
    end

    self:UpdateActions()
end

function BETTERUI.Banking.Class.SetupItemList(list)
    list:AddDataTemplate("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, BETTERUI.CIM.MenuEntryTemplateEquality)
    list:AddDataTemplateWithHeader("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, BETTERUI.CIM.MenuEntryTemplateEquality,
        "ZO_GamepadMenuEntryHeaderTemplate")
end
