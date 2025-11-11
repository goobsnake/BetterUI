local _

local LIST_WITHDRAW = 1
local LIST_DEPOSIT  = 2
local lastUsedBank = 0
local currentUsedBank = 0
local esoSubscriber

-- Stage 1: Minimal banking categories for reduced scrolling
-- Mirrors Inventory's high-level categories; restricted to Furnishings in Furniture Vault
local BANK_CATEGORY_DEFS = {
    { key = "all",        name = SI_BETTERUI_INV_ITEM_ALL,        filterType = nil },
    { key = "weapons",    name = SI_BETTERUI_INV_ITEM_WEAPONS,    filterType = ITEMFILTERTYPE_WEAPONS },
    { key = "apparel",    name = SI_BETTERUI_INV_ITEM_APPAREL,    filterType = ITEMFILTERTYPE_ARMOR },
    { key = "jewelry",    name = SI_BETTERUI_INV_ITEM_JEWELRY,    filterType = ITEMFILTERTYPE_JEWELRY },
    { key = "consumable", name = SI_BETTERUI_INV_ITEM_CONSUMABLE, filterType = ITEMFILTERTYPE_CONSUMABLE },
    { key = "materials",  name = SI_BETTERUI_INV_ITEM_MATERIALS,  filterType = ITEMFILTERTYPE_CRAFTING },
    { key = "furnishing", name = SI_BETTERUI_INV_ITEM_FURNISHING, filterType = ITEMFILTERTYPE_FURNISHING },
    { key = "misc",       name = SI_BETTERUI_INV_ITEM_MISC,       filterType = ITEMFILTERTYPE_MISCELLANEOUS },
    -- Additional inventory-parity categories (only shown if items exist)
    -- Companion items exist only on newer APIs; guard with presence check when building
    { key = "companion",  name = SI_ITEMFILTERTYPE_COMPANION,      filterType = ITEMFILTERTYPE_COMPANION, optional = true },
    -- Junk is not a filterType; handled specially in DoesItemMatchBankCategory
    { key = "junk",       name = SI_BETTERUI_INV_ITEM_JUNK,       filterType = nil, special = "junk" },
}

-- Icon mapping for header display (reuse inventory category icons)
local BANK_CATEGORY_ICONS = {
    all        = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
    weapons    = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds",
    apparel    = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds",
    jewelry    = "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds",
    consumable = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds",
    materials  = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds",
    furnishing = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds",
    misc       = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds",
    companion  = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds",
    junk       = "esoui/art/inventory/inventory_tabicon_junk_up.dds",
}

local EnsureKeybindGroupAdded = BETTERUI.Interface.EnsureKeybindGroupAdded
local CreateSearchKeybindDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor

-- Build the full set of bank categories (unfiltered). Furniture vault is restricted to Furnishing.
--- Build the full list of bank categories.
--- If in a furniture vault, restrict to All + Furnishing; otherwise mirror inventory categories (plus optional companion).
local function BuildAllBankCategories(isFurnitureVault)
    -- Always include 'All Items' to ensure a non-empty tab bar and a safe default,
    -- even for special bank types (e.g., house storage/furniture vault).
    if isFurnitureVault then
        return {
            { key = "all",        name = GetString(SI_BETTERUI_INV_ITEM_ALL),        filterType = nil },
            { key = "furnishing", name = GetString(SI_BETTERUI_INV_ITEM_FURNISHING), filterType = ITEMFILTERTYPE_FURNISHING },
        }
    end
    local out = {}
    for i = 1, #BANK_CATEGORY_DEFS do
        local def = BANK_CATEGORY_DEFS[i]
        -- Skip optional categories if the filter type constant isn't available in this API
        if not def.optional or (def.optional and def.filterType ~= nil) then
            local name
            if type(def.name) == "number" then
                name = GetString(def.name)
            else
                name = tostring(def.name)
            end
            out[#out+1] = { key = def.key, name = name, filterType = def.filterType, special = def.special }
        end
    end
    return out
end

--- Return true if itemData belongs to the given bank category (filter type or special junk)
local function DoesItemMatchBankCategory(itemData, category)
    if not category or category.key == "all" then
        return true
    end
    if category.special == "junk" then
        return itemData.isJunk == true
    end
    if category.filterType then
        return ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, category.filterType)
    end
    return true
end

local function GetCategoryTypeFromWeaponType(bagId, slotIndex)
    local weaponType = GetItemWeaponType(bagId, slotIndex)
    if weaponType == WEAPONTYPE_AXE or weaponType == WEAPONTYPE_HAMMER or weaponType == WEAPONTYPE_SWORD or weaponType == WEAPONTYPE_DAGGER then
        return GAMEPAD_WEAPON_CATEGORY_ONE_HANDED_MELEE
    elseif weaponType == WEAPONTYPE_TWO_HANDED_SWORD or weaponType == WEAPONTYPE_TWO_HANDED_AXE or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER then
        return GAMEPAD_WEAPON_CATEGORY_TWO_HANDED_MELEE
    elseif weaponType == WEAPONTYPE_FIRE_STAFF or weaponType == WEAPONTYPE_FROST_STAFF or weaponType == WEAPONTYPE_LIGHTNING_STAFF then
        return GAMEPAD_WEAPON_CATEGORY_DESTRUCTION_STAFF
    elseif weaponType == WEAPONTYPE_HEALING_STAFF then
        return GAMEPAD_WEAPON_CATEGORY_RESTORATION_STAFF
    elseif weaponType == WEAPONTYPE_BOW then
        return GAMEPAD_WEAPON_CATEGORY_TWO_HANDED_BOW
    elseif weaponType ~= WEAPONTYPE_NONE then
        return GAMEPAD_WEAPON_CATEGORY_UNCATEGORIZED
    end
end

local function GetBestItemCategoryDescription(itemData)

    local isItemStolen = IsItemStolen(itemData.bagId, itemData.slotIndex)

    if isItemStolen then
        return 'Stolen'
    end

    if itemData.equipType == EQUIP_TYPE_INVALID then
        return GetString("SI_ITEMTYPE", itemData.itemType)
    end
    local categoryType = GetCategoryTypeFromWeaponType(itemData.bagId, itemData.slotIndex)
    if categoryType ==  GAMEPAD_WEAPON_CATEGORY_UNCATEGORIZED then
        local weaponType = GetItemWeaponType(itemData.bagId, itemData.slotIndex)
        return GetString("SI_WEAPONTYPE", weaponType)
    elseif categoryType then
        return GetString("SI_GAMEPADWEAPONCATEGORY", categoryType)
    end
    local armorType = GetItemArmorType(itemData.bagId, itemData.slotIndex)
    local itemLink = GetItemLink(itemData.bagId,itemData.slotIndex)
    if armorType ~= ARMORTYPE_NONE then
        return GetString("SI_ARMORTYPE", armorType).." "..GetString("SI_EQUIPTYPE",GetItemLinkEquipType(itemLink))
    end
    local fullDesc = GetString("SI_ITEMTYPE", itemData.itemType)
	
	-- Stops types like "Poison" displaying "Poison" twice
	if( fullDesc ~= GetString("SI_EQUIPTYPE",GetItemLinkEquipType(itemLink))) then
		fullDesc = fullDesc.." "..GetString("SI_EQUIPTYPE",GetItemLinkEquipType(itemLink))
	end
	
	return fullDesc
end

-- Compute which categories have at least one item for the current mode and bank context.
--- Compute the subset of categories that actually contain items for the current bank mode.
--- Always keeps All visible so currencies render; excludes stolen items from banking lists.
local function ComputeVisibleBankCategories(self)
    local isFurnitureVault = IsFurnitureVault(GetBankingBag())
    local allCategories = BuildAllBankCategories(isFurnitureVault)
    -- Always include 'all' explicitly so currency rows can appear even if no items
    local visibility = {}
    for _, c in ipairs(allCategories) do visibility[c.key] = false end
    visibility["all"] = true

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
    -- Mark visibility by scanning once
    for i = 1, #data do
        local itemData = data[i]
        -- Ensure isJunk is available on itemData (comes from SHARED_INVENTORY)
        for _, cat in ipairs(allCategories) do
            if cat.key ~= "all" then
                if DoesItemMatchBankCategory(itemData, cat) then
                    visibility[cat.key] = true
                end
            end
        end
    end

    -- Build the final ordered list with only visible categories
    local out = {}
    for _, cat in ipairs(allCategories) do
        if visibility[cat.key] then
            out[#out+1] = cat
        end
    end
    -- If furniture vault, ensure only furnishing remains (already handled in BuildAllBankCategories)
    return out
end

local function SetupLabelListing(control, data)
    control:GetNamedChild("Label"):SetText(data.label)
    if BETTERUI.Settings.Modules["CIM"].skinSize == "Medium" then
        control:GetNamedChild("Label"):SetFont("ZoFontGamepadCondensed34")
    elseif BETTERUI.Settings.Modules["CIM"].skinSize == "Large" then
        control:GetNamedChild("Label"):SetFont("ZoFontGamepad36")
    end 
end

BETTERUI.Banking.Class = BETTERUI.Interface.Window:Subclass()

function BETTERUI.Banking.Class:New(...)
	return BETTERUI.Interface.Window.New(self, ...)
end

function BETTERUI.Banking.Class:CurrentUsedBank()
    if(IsHouseBankBag(GetBankingBag()) == false) then
        currentUsedBank = BAG_BANK
    elseif (IsHouseBankBag(GetBankingBag()) == true) then
        currentUsedBank = GetBankingBag()
    else
        currentUsedBank = BAG_BANK
    end
end

function BETTERUI.Banking.Class:LastUsedBank()
   if(IsHouseBankBag(GetBankingBag()) == false) then
        lastUsedBank = BAG_BANK
    elseif (IsHouseBankBag(GetBankingBag()) == true) then
        lastUsedBank = GetBankingBag()
    else
        lastUsedBank = BAG_BANK
    end
end

function BETTERUI.Banking.Class:RefreshFooter()

    if(currentUsedBank == BAG_BANK) then
        --IsBankOpen()
        self.footer.footer:GetNamedChild("DepositButtonSpaceLabel"):SetText(zo_strformat("|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t <<1>>",zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
        self.footer.footer:GetNamedChild("WithdrawButtonSpaceLabel"):SetText(zo_strformat("|t24:24:/esoui/art/icons/mapkey/mapkey_bank.dds|t <<1>>",zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK), GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))
    else
        self.footer.footer:GetNamedChild("DepositButtonSpaceLabel"):SetText(zo_strformat("|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t <<1>>",zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
        self.footer.footer:GetNamedChild("WithdrawButtonSpaceLabel"):SetText(zo_strformat("|t24:24:/esoui/art/icons/mapkey/mapkey_bank.dds|t <<1>>",zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(currentUsedBank), GetBagUseableSize(currentUsedBank))))
    end

    if((self.currentMode == LIST_WITHDRAW) and (currentUsedBank == BAG_BANK)) then
        self.footerFragment.control:GetNamedChild("Data1Value"):SetText(BETTERUI.DisplayNumber(GetBankedCurrencyAmount(CURT_MONEY)))
        self.footerFragment.control:GetNamedChild("Data2Value"):SetText(BETTERUI.DisplayNumber(GetBankedCurrencyAmount(CURT_TELVAR_STONES)))
    else
        self.footerFragment.control:GetNamedChild("Data1Value"):SetText(BETTERUI.DisplayNumber(GetCarriedCurrencyAmount(CURT_MONEY)))
        self.footerFragment.control:GetNamedChild("Data2Value"):SetText(BETTERUI.DisplayNumber(GetCarriedCurrencyAmount(CURT_TELVAR_STONES)))
    end
end

function BETTERUI.Banking.Class:RefreshList()
    -- If we're in the middle of a tab selection animation, skip interim refreshes
    if self._suppressListUpdates then return end
    -- Temporarily deactivate to avoid parametric scroll list update races while rebuilding
    local wasActive = self.list:IsActive()
    if wasActive then
        self.list:Deactivate()
    end
    -- reset any transient state if needed (none currently)
    
    self.list:Clear()

    -- Update the header title with current category
    if self.UpdateHeaderTitle then
        self:UpdateHeaderTitle()
    end

    -- We have to add 2 rows to the list, one for Withdraw/Deposit GOLD and one for Withdraw/Deposit TEL-VAR
    local wdString = self.currentMode == LIST_WITHDRAW and GetString(SI_BETTERUI_BANKING_WITHDRAW) or GetString(SI_BETTERUI_BANKING_DEPOSIT)
    wdString = zo_strformat("<<Z:1>>", wdString)
    -- Header tab bar now shows category; no extra list header row needed
    -- Only show currency transfer rows when on the All Items category
    local activeCategoryForHeader = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    if(currentUsedBank == BAG_BANK) then
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
                local label = labelByCurrency[currencyType] or (GetCurrencyName and GetCurrencyName(currencyType, true, false)) or tostring(currencyType)
                self.list:AddEntry("BETTERUI_HeaderRow_Template", {label = "|cFFFFFF"..wdString.." ".. tostring(label) .."|r", currencyType = currencyType})
            end
        end
    else
        if(self.currentMode == LIST_WITHDRAW) then
            if(GetNumBagUsedSlots(currentUsedBank) == 0) then
                self.list:AddEntry("BETTERUI_HeaderRow_Template", {label="|cFFFFFFHOUSE BANK IS EMPTY!|r"})
            else
                self.list:AddEntry("BETTERUI_HeaderRow_Template", {label="|cFFFFFFHOUSE BANK|r"})
            end
        else
            if(GetNumBagUsedSlots(BAG_BACKPACK) == 0) then
                self.list:AddEntry("BETTERUI_HeaderRow_Template", {label="|cFFFFFFPLAYER BAG IS EMPTY!|r"})
            else
                self.list:AddEntry("BETTERUI_HeaderRow_Template", {label="|cFFFFFFPLAYER BAG|r"})
            end
        end        
    end
    local checking_bags = {}
    local slotType
    if(self.currentMode == LIST_WITHDRAW) then
        if(currentUsedBank == BAG_BANK) then
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
    local GetBestItemCategoryDescription = GetBestItemCategoryDescription
    local FindActionSlotMatchingItem = FindActionSlotMatchingItem
    local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
    -- Localize item/link related APIs and recipe/book checks to avoid global lookups
    local GetItemLink = GetItemLink
    local GetItemLinkItemType = GetItemLinkItemType
    local GetItemLinkSetInfo = GetItemLinkSetInfo
    local GetItemLinkEnchantInfo = GetItemLinkEnchantInfo
    local IsItemLinkRecipeKnown = IsItemLinkRecipeKnown
    local IsItemLinkBookKnown = IsItemLinkBookKnown
    local IsItemBound = IsItemBound
    local activeCategory = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    local showJunkCategory = (activeCategory and activeCategory.key == "junk") or false
    for i = 1, #filteredDataTable  do
        local itemData = filteredDataTable[i]
        if activeCategory and not DoesItemMatchBankCategory(itemData, activeCategory) then
            -- skip items not in the selected category
        else
        --use custom categories
        local customCategory, matched, catName, catPriority = BETTERUI.GetCustomCategory(itemData)
        if customCategory and not matched then
            itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
            itemData.bestItemCategoryName = AC_UNGROUPED_NAME
            itemData.sortPriorityName = string.format("%03d%s", 999 , catName) 
        else
            if customCategory then
                itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = catName
                itemData.sortPriorityName = string.format("%03d%s", 100 - catPriority , catName) 
            else
                itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = itemData.bestItemTypeName
                itemData.sortPriorityName = itemData.bestItemCategoryName
            end
        end
        
        itemData.isEquippedInCurrentCategory = slotIndex and true or nil

        -- Cache expensive/commonly used item link information so downstream
        -- rendering (shared code in InventoryList) can rely on these fields
        -- being present (fixes motif/recipe known/unknown display in bank).
        -- Only compute when missing to reduce work during rapid refreshes/scrolling.
        if not itemData.cached_itemLink then
            local itemLink = GetItemLink(itemData.bagId, itemData.slotIndex)
            itemData.cached_itemLink = itemLink
            itemData.cached_itemType = itemLink and GetItemLinkItemType(itemLink) or nil
            itemData.cached_setItem = itemLink and GetItemLinkSetInfo(itemLink, false) or nil
            itemData.cached_hasEnchantment = itemLink and GetItemLinkEnchantInfo(itemLink) or nil
            itemData.cached_isRecipeAndUnknown = (itemData.cached_itemType == ITEMTYPE_RECIPE) and not (itemLink and IsItemLinkRecipeKnown(itemLink))
            itemData.cached_isBookKnown = itemLink and IsItemLinkBookKnown(itemLink) or nil
            itemData.cached_isUnbound = not IsItemBound(itemData.bagId, itemData.slotIndex) and not itemData.stolen and itemData.quality ~= ITEM_QUALITY_TRASH
        end

        table.insert(tempDataTable, itemData)
        ZO_InventorySlot_SetType(itemData, slotType)
        end
    end
    filteredDataTable = tempDataTable

    -- Apply text search filtering after item/category metadata has been computed so names/categories are accurate
    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        local q = tostring(self.searchQuery):lower()
        local activeCategory = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
        local matches = {}

        
        for i = 1, #filteredDataTable do
            local it = filteredDataTable[i]
            -- If an active non-all category is selected, skip items that do not belong to it
            if not activeCategory or activeCategory.key == "all" or DoesItemMatchBankCategory(it, activeCategory) then
                local name = tostring(it.name or "")
                local lname = name:lower()
                -- Only match against the item name (mirror Inventory behavior)
                if string.find(lname, q, 1, true) then
                    table.insert(matches, it)
                end
            end
        end

        
        filteredDataTable = matches
    end

    table.sort(filteredDataTable, BETTERUI_GamepadInventory_DefaultItemSortComparator)

    local currentBestCategoryName

    local GetItemCooldownInfo = GetItemCooldownInfo
    local ZO_GamepadEntryData = ZO_GamepadEntryData
    for i, itemData in ipairs(filteredDataTable) do

        local data = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
        data.InitializeInventoryVisualData = BETTERUI.Inventory.Class.InitializeInventoryVisualData
        data:InitializeInventoryVisualData(itemData)

        local remaining, duration
  
    remaining, duration = GetItemCooldownInfo(itemData.bagId, itemData.slotIndex)
      
        if remaining > 0 and duration > 0 then
            data:SetCooldown(remaining, duration)
        end

        data.bestItemCategoryName = itemData.bestItemCategoryName
        data.bestGamepadItemCategoryName = itemData.bestItemCategoryName
        data.isEquippedInCurrentCategory = itemData.isEquippedInCurrentCategory
        data.isEquippedInAnotherCategory = itemData.isEquippedInAnotherCategory
        data.isJunk = itemData.isJunk

    if (not data.isJunk and not showJunkCategory) or (data.isJunk and showJunkCategory) then
         
            if data.bestGamepadItemCategoryName ~= currentBestCategoryName then
                currentBestCategoryName = data.bestGamepadItemCategoryName
                data:SetHeader(currentBestCategoryName)
                if((AutoCategory) and ((GetNumBagUsedSlots(currentUsedBank) ~= 0) or (GetNumBagUsedSlots(BAG_BACKPACK) ~= 0))) then
                    self.list:AddEntryWithHeader("BETTERUI_GamepadItemSubEntryTemplate", data)
                else
                    self.list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", data)
                end
            else
                self.list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", data)
            end
        end
    end

    self.list:Commit()
    -- If list becomes empty, deactivate to avoid parametric list moving errors
    local entryCount = (self.list and self.list.dataList and #self.list.dataList) or 0
    if entryCount == 0 then
        self.list:Deactivate()
    elseif not self:IsHeaderActive() then
        -- Keep the list active only when the search header is not focused
        self.list:Activate()
    else
        self.list:Deactivate()
    end
    self:ReturnToSaved()
    self:UpdateActions()
    self:RefreshFooter()
    -- Ensure keybind visibility reflects current (possibly empty) list state immediately
    if KEYBIND_STRIP then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)
    end
end

function BETTERUI.Banking.Class:RefreshCurrencyTooltip()
	if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() and self:GetList().selectedData.label ~= nil then 
        GAMEPAD_TOOLTIPS:LayoutBankCurrencies(GAMEPAD_LEFT_TOOLTIP, ZO_BANKABLE_CURRENCIES)
	end
end

local function OnItemSelectedChange(self, list, selectedData)
    -- Check if we are on the "Deposit/withdraw" gold/telvar row

	if not SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
		return
	end
    if not selectedData then
        -- No selection (empty list). Default to item keybinds and clear tooltip.
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        self:UpdateActions()
        return
    end
    -- Only treat currency header rows when the active category is All Items
    local activeCategoryForHeader = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    if(currentUsedBank == BAG_BANK) then
        if(selectedData.label ~= nil and activeCategoryForHeader and activeCategoryForHeader.key == "all") then
            -- Yes! We are, so add the "withdraw/deposit gold/telvar" keybinds here
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.currencyKeybinds)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.currencyKeybinds)

            --GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
    		self:RefreshCurrencyTooltip()
        else
            -- We are not, add the "withdraw/deposit" keybinds here
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)

            if selectedData.bagId and selectedData.slotIndex then
                GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedData.bagId, selectedData.slotIndex)
            else
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            end
        end
    else
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)
        if selectedData.bagId and selectedData.slotIndex then
            GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedData.bagId, selectedData.slotIndex)
        else
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        end
        self:RefreshCurrencyTooltip()
    end
	self:UpdateActions()
end


local function SetupItemList(list)
    list:AddDataTemplate("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality)
    list:AddDataTemplateWithHeader("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality, "ZO_GamepadMenuEntryHeaderTemplate")
end

function BETTERUI.Banking.Class:Initialize(tlw_name, scene_name)
	BETTERUI.Interface.Window.Initialize(self, tlw_name, scene_name)

	self:InitializeKeybind()
    self:InitializeList()
    self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
	self.itemActions:SetUseKeybindStrip(false) 
    self:InitializeActionsDialog()
	
	local function CallbackSplitStackFinished()
		--refresh list
		if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
        
			SHARED_INVENTORY:PerformFullUpdateOnBagCache(currentUsedBank)
            self:RefreshList()
			self:ReturnToSaved()
		end
	end
	CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED", CallbackSplitStackFinished)
	
    self.list.maxOffset = 30
    self.list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * 0.75, GAMEPAD_HEADER_SELECTED_PADDING * 0.75)
	self.list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * 0.75)    

    -- Setup data templates of the lists
	SetupItemList(self.list)
    self:AddTemplate("BETTERUI_HeaderRow_Template",SetupLabelListing)

    self.currentMode = LIST_WITHDRAW
    self.lastPositions = { [LIST_WITHDRAW] = 1, [LIST_DEPOSIT] = 1 }
    -- Per-category selection persistence (shared across modes in a session)
    self.lastPositionsByCategory = {}

    -- Initialize categories (Stage 1)
    self:CurrentUsedBank()
    self.bankCategories = ComputeVisibleBankCategories(self)
    self.currentCategoryIndex = 1

    -- Base header title (used as fallback); header title will show selected category like inventory
    self.headerBaseTitle = "Advanced Banking"

    -- Initialize the banking header with a tab bar similar to inventory
    self.headerGeneric = self.header:GetNamedChild("Header") or self.header
    BETTERUI.GenericHeader.Initialize(self.headerGeneric, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
    self:RebuildHeaderCategories()

    -- Add gamepad text search support; callback updates searchQuery and refreshes the list
    -- Uses the AddSearch helper added to BETTERUI.Interface.Window
    -- Provide a dedicated keybind group for the text-search header so that when
    -- the search is focused we can temporarily replace the main banking keybinds.
    self.textSearchKeybindStripDescriptor = CreateSearchKeybindDescriptor(self)

    if self.AddSearch then
        -- Register search. Pass our descriptor so AddSearch can wire keybinds appropriately.
        self:AddSearch(self.textSearchKeybindStripDescriptor, function(editOrText)
            -- Normalize the OnTextChanged argument: engine passes the editBox control, others may pass a string.
            local query = ""
            if type(editOrText) == "string" then
                query = editOrText
            elseif editOrText and type(editOrText) == "table" and editOrText.GetText then
                query = editOrText:GetText() or ""
            elseif editOrText and type(editOrText) == "userdata" then
                local ok, txt = pcall(function() return editOrText:GetText() end)
                if ok and txt then
                    query = txt
                else
                    query = tostring(editOrText)
                end
            else
                query = tostring(editOrText or "")
            end

            self.searchQuery = query or ""
            -- When search changes, reset selection to top and refresh
            self:SaveListPosition()
            self:RefreshList()
        end)
        -- Position the search control appropriately beneath the header/title
        if self.PositionSearchControl then
            self:PositionSearchControl()
        end
    end

    -- Hook into the actual edit box to detect focus and text changes so we can swap keybinds
    -- matching Inventory behavior (Clear-only while focused).
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus:GetEditBox() then
        local editBox = self.textSearchHeaderFocus:GetEditBox()
        local origOnFocusGained = editBox:GetHandler("OnFocusGained")
        local origOnFocusLost = editBox:GetHandler("OnFocusLost")
        local origOnTextChanged = editBox:GetHandler("OnTextChanged")
        local origOnKeyDown = editBox:GetHandler("OnKeyDown")

        editBox:SetHandler("OnFocusGained", function(eb)
            if origOnFocusGained then origOnFocusGained(eb) end
            if self.RequestEnterHeader then
                self:RequestEnterHeader()
            else
                self:EnterSearchMode()
            end
        end)

        editBox:SetHandler("OnFocusLost", function(eb)
            if origOnFocusLost then origOnFocusLost(eb) end
            local hasText = self.searchQuery and tostring(self.searchQuery) ~= ""
            if hasText then
                self:ExitSearchFocus(true)
            else
                self:ExitSearchFocus()
            end
        end)

        editBox:SetHandler("OnTextChanged", function(eb)
            if origOnTextChanged then pcall(function() origOnTextChanged(eb) end) end
            local txt = ""
            local ok, t = pcall(function() return eb:GetText() end)
            if ok and t then txt = t end
            self.searchQuery = txt or ""
            -- Refresh list immediately on text change
            pcall(function() self:SaveListPosition() end)
            pcall(function() self:RefreshList() end)
        end)

        editBox:SetHandler("OnKeyDown", function(eb, key, ctrl, alt, shift, command)
            if origOnKeyDown then
                local handled = origOnKeyDown(eb, key, ctrl, alt, shift, command)
                if handled then
                    return handled
                end
            end

            if command == "UI_SHORTCUT_DOWN" then
                self:ExitSearchFocus(true)
                return true
            end
        end)
    end

    -- EnsureHeaderKeybindsActive is defined on the class below; keep calls here

    self.selectedDataCallback = OnItemSelectedChange

    -- this is essentially a way to encapsulate a function which allows us to override "selectedDataCallback" but still keep some logic code
    local function SelectionChangedCallback(list, selectedData)
        if self._searchModeActive and self.list and self.list.IsActive and self.list:IsActive() then
            local hasText = self.searchQuery and tostring(self.searchQuery) ~= ""
            if hasText then
                self:ExitSearchFocus(true)
            else
                self:ExitSearchFocus()
            end
            return
        end

        local selectedControl = list:GetSelectedControl()
        if self.selectedDataCallback then
            self:selectedDataCallback(selectedControl, selectedData)
        end
        if selectedControl and selectedControl.bagId then
            SHARED_INVENTORY:ClearNewStatus(selectedControl.bagId, selectedControl.slotIndex)
            self:GetParametricList():RefreshList()
        end
    end

    -- these are event handlers which are specific to the banking interface. Handling the events this way encapsulates the banking interface
    -- these local functions are essentially just router functions to other functions within this class. it is done in this way to allow for
    -- us to access this classes' members (through "self")

    local function UpdateSingle_Handler(eventId, bagId, slotId, isNewItem, itemSound)
        -- If a coalesced refresh is in progress, skip intermediate updates to avoid UI stutter
        if self._suppressListUpdates then
            self.isDirty = true
            return
        end
        self:UpdateSingleItem(bagId, slotId)
        -- Categories can become empty/non-empty as items move; rebuild the header list
        -- Capture the current category KEY before recomputing categories
        local prevCategoryKey = nil
        if self.bankCategories and self.currentCategoryIndex and self.currentCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[self.currentCategoryIndex]
            if prevCat then
                prevCategoryKey = prevCat.key
            end
        end
        self.bankCategories = ComputeVisibleBankCategories(self)
        -- Check if the captured category key still exists in the new list
        if prevCategoryKey then
            local categoryStillExists = false
            for i, cat in ipairs(self.bankCategories) do
                if cat.key == prevCategoryKey then
                    categoryStillExists = true
                    break
                end
            end
            if not categoryStillExists then
                -- Category became empty, force to All Items
                self.currentCategoryIndex = 1
            end
        end
        -- Suppress callback during rebuild when category has changed
        self._suppressHeaderCallback = true
        self:RebuildHeaderCategories()
        self._suppressHeaderCallback = false
    self:RefreshList()
    self:RefreshActiveKeybinds()
    end

    local function UpdateCurrency_Handler()
        -- Only update UI/keybinds when the banking scene is actually visible
        if not (SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing()) then
            return
        end
        self:RefreshFooter()
        if KEYBIND_STRIP then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
        end
        self:RefreshCurrencyTooltip()
    end

    local function OnEffectivelyShown()
        self:CurrentUsedBank()
        -- Rebuild categories on show in case bank type changed
        self.bankCategories = ComputeVisibleBankCategories(self)
        -- Always default to "All Items" and first row on first open of the scene
        self.currentCategoryIndex = 1
        self.lastPositions[self.currentMode] = 1
        self:RebuildHeaderCategories()
        -- Force header to All Items (index 1) on scene open without animation
        if self.headerGeneric and self.headerGeneric.tabBar then
            self.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(1, true, false)
        end
        if self.isDirty then
            self:RefreshList()
        else
            self:RefreshActiveKeybinds()
        end
        self.list:Activate()
        -- Ensure our keybind groups and header tab bar are active on first show
        self:AddKeybinds()

		if wykkydsToolbar then
			wykkydsToolbar:SetHidden(true)
		end

        self.control:RegisterForEvent(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, UpdateSingle_Handler)
        self:RefreshList()
    end

    local function OnEffectivelyHidden()
        self:LastUsedBank()
        self:CancelWithdrawDeposit(self.list)
        self.list:Deactivate()
        self.selector:Deactivate()
        self.confirmationMode = false
        self:DeactivateSearchDirectionalInput()
        -- Release focus from header tab bar and clear any update suppression flags
        if self.headerGeneric and self.headerGeneric.tabBar then
            self.headerGeneric.tabBar:Deactivate()
        end
        self._suppressListUpdates = false
        self._suppressListUpdatesToken = nil

        KEYBIND_STRIP:RemoveAllKeyButtonGroups()
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)

		if wykkydsToolbar then
			wykkydsToolbar:SetHidden(false)
		end

        self.control:UnregisterForEvent(EVENT_INVENTORY_FULL_UPDATE)
        self.control:UnregisterForEvent(EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        
        -- Reset category positions when leaving the bank so next visit starts fresh
        self.lastPositionsByCategory = {}
	end

    local selectorContainer = self.control:GetNamedChild("Container"):GetNamedChild("InputContainer")
    self.selector = ZO_CurrencySelector_Gamepad:New(selectorContainer:GetNamedChild("Selector"))
	self.selector:SetClampValues(true)
	self.selectorCurrency = selectorContainer:GetNamedChild("CurrencyTexture")

    self.list:SetOnSelectedDataChangedCallback(SelectionChangedCallback)

    -- Monkeypatch MovePrevious to allow moving "up" from the top of the list into the header.
    -- Some list implementations return false when there is no previous entry; intercept
    -- that case and programmatically enter the header (focus the search control).
    if self.list and self.list.MovePrevious then
        local _origMovePrevious = self.list.MovePrevious
        self.list.MovePrevious = function(list, allowWrapping, suppressFailSound)
            local ok = false
            -- call original implementation in protected call
            local status, res = pcall(function() return _origMovePrevious(list, allowWrapping, suppressFailSound) end)
            if status then ok = res end
            if not ok then
                -- No previous entry; attempt to focus header/search like Inventory does
                pcall(function()
                    if self.textSearchHeaderControl and not self.textSearchHeaderControl:IsHidden() then
                        if self.OnEnterHeader then
                            self:OnEnterHeader()
                        elseif BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.SetTextSearchFocused then
                            BETTERUI.Interface.Window.SetTextSearchFocused(self, true)
                        else
                            if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.Activate then
                                self.headerGeneric.tabBar:Activate()
                            end
                        end
                    end
                end)
                return true
            end
            return ok
        end
    end

    self.control:SetHandler("OnEffectivelyShown", OnEffectivelyShown)
    self.control:SetHandler("OnEffectivelyHidden", OnEffectivelyHidden)

    -- Always-running event listeners, these don't add much overhead
    self.control:RegisterForEvent(EVENT_CARRIED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    self.control:RegisterForEvent(EVENT_BANKED_CURRENCY_UPDATE, UpdateCurrency_Handler)
end

-- Calling this function will add keybinds to the strip, likely using the primary key
-- The primary key will conflict with the category keybind descriptor if added
function BETTERUI.Banking.Class:RefreshItemActions()
    local targetData = self:GetList().selectedData
    --self:SetSelectedInventoryData(targetData) instead:
    self.itemActions:SetInventorySlot(targetData)
end


 

function BETTERUI.Banking.Class:InitializeActionsDialog()
	local function ActionDialogSetup(dialog)
		if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
	
            
			dialog.entryList:SetOnSelectedDataChangedCallback(  function(list, selectedData)
			self.itemActions:SetSelectedAction(selectedData and selectedData.action)
			end)

			local parametricList = dialog.info.parametricList
			ZO_ClearNumericallyIndexedTable(parametricList)

			self:RefreshItemActions()

			local actions = self.itemActions:GetSlotActions()
			local numActions = actions:GetNumSlotActions()

                for i = 1, numActions do
				local action = actions:GetSlotAction(i)
				local actionName = actions:GetRawActionName(action)

                -- Hide Destroy/Delete in deposit mode (banker and house bank)
                local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY)) or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
                if not (self.currentMode == LIST_DEPOSIT and isDestroy) then
                    local entryData = ZO_GamepadEntryData:New(actionName)
                    entryData:SetIconTintOnSelection(true)
                    entryData.action = action
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup

                    local listItem =
                    {
                        template = "ZO_GamepadItemEntryTemplate",
                        entryData = entryData,
                    }
                    table.insert(parametricList, listItem)
                end
			end

			dialog:setupFunc()
		end
	end

        local function ActionDialogFinish() 
		if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            
			-- make sure to wipe out the keybinds added by actions
			self:AddKeybinds()
			--restore the selected inventory item
		
			self:RefreshItemActions()
			
            -- refresh so keybinds react to newly selected item

			self:RefreshList()
            
        end
	end
	local function ActionDialogButtonConfirm(dialog)
		if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            
            local selectedAction = self.itemActions and self.itemActions.selectedAction or nil
            if not selectedAction then return end
            local selectedName = ZO_InventorySlotActions:GetRawActionName(selectedAction)
            if selectedName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
                -- Link to chat
                local targetData = self:GetList().selectedData
                local itemLink
                local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                if bag and slot then
                    itemLink = GetItemLink(bag, slot)
                end
                if itemLink then
                    ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
                end
            else
                self.itemActions:DoSelectedAction()
            end
		end
	end
	CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", ActionDialogSetup)
	CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", ActionDialogFinish)
	CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", ActionDialogButtonConfirm)
end


-- Find first empty slot in a bag
local function FindEmptySlotInBag(bagId)
    return FindFirstEmptySlotInBag(bagId)
end

local function FindEmptySlotInBank()
    if(IsHouseBankBag(GetBankingBag()) == false) then
        local emptySlotIndexBank = FindEmptySlotInBag(BAG_BANK)
        local emptySlotIndexSubscriber = FindEmptySlotInBag(BAG_SUBSCRIBER_BANK)
        if emptySlotIndexBank ~= nil then
            return BAG_BANK, emptySlotIndexBank
        elseif esoSubscriber and emptySlotIndexSubscriber ~= nil then
            return BAG_SUBSCRIBER_BANK, emptySlotIndexSubscriber
        else
            return nil
        end
    else
        local emptySlotIndex = FindEmptySlotInBag(currentUsedBank)
        if emptySlotIndex ~= nil then
            return currentUsedBank, emptySlotIndex
        else
            return currentUsedBank, nil
        end
    end
end

function BETTERUI.Banking.Class:ActivateSpinner()
    self.spinner:SetHidden(false)
    self.spinner:Activate()
    if(self:GetList() ~= nil) then
        self:GetList():Deactivate()
        -- Only manipulate keybinds if our banking scene is visible
        if SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            KEYBIND_STRIP:RemoveAllKeyButtonGroups()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.spinnerKeybindStripDescriptor)
        end
    end
end

function BETTERUI.Banking.Class:DeactivateSpinner()
    self.spinner:SetValue(1)
    self.spinner:SetHidden(true)
    self.spinner:Deactivate()
    if(self:GetList() ~= nil) then
        self:GetList():Activate()
        -- Only restore keybinds/header when the banking scene is visible
        if SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            KEYBIND_STRIP:RemoveAllKeyButtonGroups()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
            self:EnsureHeaderKeybindsActive()
        end
    end
end

function BETTERUI.Banking.Class:MoveItem(list, quantity)
    local selectedData = list and list:GetSelectedData() or nil
    if not selectedData or not selectedData.bagId or not selectedData.slotIndex then
        -- Nothing to move (empty list, header row, or currency row)
        return
    end
    local fromBag, fromBagIndex = ZO_Inventory_GetBagAndIndex(selectedData)
    local stackCount = GetSlotStackSize(fromBag, fromBagIndex)
    local fromBagItemLink = GetItemLink(fromBag, fromBagIndex)
    local toBag
    local toBagEmptyIndex
    local toBagIndex
    local toBagItemLink
    local toBagStackCount
    local toBagStackCountMax
    local isToBagItemStackable
	local inSpinner = false
	if quantity ~= nil then
		--in spinner
		inSpinner = true
	else 
		--not in spinner
		if(stackCount > 1) then
			-- display the spinner
			self:UpdateSpinnerConfirmation(true, self.list)
			self:SetSpinnerValue(list:GetSelectedData().stackCount, list:GetSelectedData().stackCount)
			return
		else
		--since stackcount = 1
		quantity = 1
		end
	end
	 
	if self.currentMode == LIST_WITHDRAW then
		--we are withdrawing item from bank/subscriber bank bag
		toBag = BAG_BACKPACK
		toBagEmptyIndex = FindEmptySlotInBag(toBag)
	else
		--we are depositing item to bank/subscriber bank bag
		toBag, toBagEmptyIndex = FindEmptySlotInBank()
	end

    local function beginCoalescedRefresh(delayMs)
        -- Suppress intermediate refreshes and perform a single rebuild after item move settles
        self._moveCoalesceToken = (self._moveCoalesceToken or 0) + 1
        local myToken = self._moveCoalesceToken
        self._suppressListUpdates = true
        -- Capture the current category KEY before the delayed refresh (categories will change)
        local prevCategoryKey = nil
        if self.bankCategories and self.currentCategoryIndex and self.currentCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[self.currentCategoryIndex]
            if prevCat then
                prevCategoryKey = prevCat.key
            end
        end
        zo_callLater(function()
            if myToken ~= self._moveCoalesceToken then return end
            self._suppressListUpdates = false
            -- Recompute categories and refresh once
            self.bankCategories = ComputeVisibleBankCategories(self)
            -- Check if the captured category key still exists in the new list
            if prevCategoryKey then
                local categoryStillExists = false
                for i, cat in ipairs(self.bankCategories) do
                    if cat.key == prevCategoryKey then
                        categoryStillExists = true
                        break
                    end
                end
                if not categoryStillExists then
                    -- Category became empty, force to All Items
                    self.currentCategoryIndex = 1
                end
            end
            -- Suppress callback during rebuild when category has changed
            self._suppressHeaderCallback = true
            self:RebuildHeaderCategories()
            self._suppressHeaderCallback = false
            self:RefreshList()
        end, delayMs or 100)
    end

    if toBagEmptyIndex ~= nil then
        --good to move
    CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagEmptyIndex, quantity)
    beginCoalescedRefresh(100)
       if inSpinner then
           self:UpdateSpinnerConfirmation(false, self.list)
       end
    -- Accomodates full banks with stackable item slots available   
    else
        if toBag ~= nil then
            local errorStringId = (toBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
             -- Get bag size
            local bagSize = GetBagSize(toBag)
            -- Iterate through BAG
            for i = 0, bagSize - 1 do
                local currentItemLink = GetItemLink(toBag, i)
                -- Matches items from origin bag to destination bag
                if currentItemLink == fromBagItemLink then
                    toBagItemLink = currentItemLink
                    isToBagItemStackable = IsItemLinkStackable(toBagItemLink)
                    -- Confirms item matched is stackable
                    if isToBagItemStackable then
                        toBagStackCount, toBagStackCountMax = GetSlotStackSize(toBag, i)
                        if toBagStackCount < toBagStackCountMax then
                            toBagIndex = i
                        end
                    end                    
                end
            end
            if toBagIndex then
                --good to move item that already has a non-full stack in the destination bag
                CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagIndex, quantity)
                beginCoalescedRefresh(100)
                if inSpinner then
                    self:UpdateSpinnerConfirmation(false, self.list)
                end
            else 
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
                if inSpinner then
                    self:UpdateSpinnerConfirmation(false, self.list)
                end
            end
        else
            local banks = {BAG_BANK, BAG_SUBSCRIBER_BANK}
            for bankBags = 1, 2 do
                local bank = banks[bankBags]
                -- Get bag size
                local bagSize = GetBagSize(bank)
                -- Iterate through BAG
                for i = 0, bagSize - 1 do
                    local currentItemLink = GetItemLink(bank, i)
                    -- Matches items from origin bag to destination bag
                    if currentItemLink == fromBagItemLink then
                        toBagItemLink = currentItemLink
                        isToBagItemStackable = IsItemLinkStackable(toBagItemLink)
                        -- Confirms item matched is stackable
                        if isToBagItemStackable then
                            toBagStackCount, toBagStackCountMax = GetSlotStackSize(bank, i)
                            if toBagStackCount < toBagStackCountMax then
                                toBagIndex = i
                                toBag = bank
                            end
                        end                    
                    end
                end
            end
            if toBagIndex and toBag then
                CallSecureProtected("RequestMoveItem", fromBag, fromBagIndex, toBag, toBagIndex, quantity)
                beginCoalescedRefresh(100)
                if inSpinner then
                    self:UpdateSpinnerConfirmation(false, self.list)
                end
            else 
                local errorStringId = (toBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
                if inSpinner then
                    self:UpdateSpinnerConfirmation(false, self.list)
                end
            end
        end
    end
end

function BETTERUI.Banking.Class:CancelWithdrawDeposit(list)
    local DEACTIVATE_SPINNER = false
    if self.confirmationMode then
        self:UpdateSpinnerConfirmation(DEACTIVATE_SPINNER, list)
    else
        SCENE_MANAGER:HideCurrentScene()
    end
end

function BETTERUI.Banking.Class:DisplaySelector(currencyType)
    local currency_max

    if(self.currentMode == LIST_DEPOSIT) then
        currency_max = GetCarriedCurrencyAmount(currencyType)
    else
        currency_max = GetBankedCurrencyAmount(currencyType)
    end

    -- Does the player actually have anything that can be transferred?
    if(currency_max ~= 0) then
        self.selector:SetMaxValue(currency_max)
        self.selector:SetClampValues(0, currency_max)
        self.selector.control:GetParent():SetHidden(false)
	
		local CURRENCY_TYPE_TO_TEXTURE =
		{
			[CURT_MONEY] = "EsoUI/Art/currency/gamepad/gp_gold.dds",
			[CURT_TELVAR_STONES] = "EsoUI/Art/currency/gamepad/gp_telvar.dds",
			[CURT_ALLIANCE_POINTS] = "esoui/art/currency/gamepad/gp_alliancepoints.dds",
			[CURT_WRIT_VOUCHERS] = "EsoUI/Art/currency/gamepad/gp_writvoucher.dds",
		}
	
		self.selectorCurrency:SetTexture(CURRENCY_TYPE_TO_TEXTURE[currencyType])
	
        self.selector:Activate()
        self.list:Deactivate()

        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.currencySelectorKeybinds)
    else
        -- No, display an alert
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, "Not enough funds available for transfer.")
    end
end

function BETTERUI.Banking.Class:HideSelector()
    self.selector.control:GetParent():SetHidden(true)
    self.selector:Deactivate()
    self.list:Activate()

    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencySelectorKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.currencyKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
end

function BETTERUI.Banking.Class:CreateListTriggerKeybindDescriptors(list)
    local leftTrigger = {
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        ethereal = true,
        callback = function()
            local list = self.list
            if not list:IsEmpty() then
                list:SetSelectedIndex(list.selectedIndex-tonumber(BETTERUI.Settings.Modules["CIM"].triggerSpeed))
            end
        end
    }
    local rightTrigger = {
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        ethereal = true,
        callback = function()
			local list = self.list
            if not list:IsEmpty() then
                list:SetSelectedIndex(list.selectedIndex+tonumber(BETTERUI.Settings.Modules["CIM"].triggerSpeed))
            end
        end,
    }
    return leftTrigger, rightTrigger
end

function BETTERUI.Banking.Class:UpdateActions()
    local targetData = self:GetList() and self:GetList().selectedData or nil
    if not targetData then
        self.itemActions:SetInventorySlot(nil)
        return
    end
    -- since SetInventorySlot also adds/removes keybinds, the order which we call these 2 functions is important
    -- based on whether we are looking at an item or a faux-item
    if ZO_GamepadBanking.IsEntryDataCurrencyRelated(targetData) then
        
        self.itemActions:SetInventorySlot(nil)
    else
        
        self.itemActions:SetInventorySlot(targetData)
    end
end

function BETTERUI.Banking.Class:AddKeybinds()
	KEYBIND_STRIP:RemoveAllKeyButtonGroups()
	KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
	KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
	self:UpdateActions()
    self:EnsureHeaderKeybindsActive()
end

function BETTERUI.Banking.Class:RemoveKeybinds()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
end

function BETTERUI.Banking.Class:ShowActions()
    self:RemoveKeybinds()

    local function OnActionsFinishedCallback()
        self:AddKeybinds()
    end

    local dialogData = 
    {
        targetData = self:GetList().selectedData,
        finishedCallback = OnActionsFinishedCallback,
        itemActions = self.itemActions,
    }

    ZO_Dialogs_ShowPlatformDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, dialogData)
end

function BETTERUI.Banking.Class:InitializeKeybind()
	if not BETTERUI.Settings.Modules["Banking"].m_enabled then
		return
	end
	
    self.coreKeybinds = {
                alignment = KEYBIND_STRIP_ALIGN_LEFT,
		        {
		            name = GetString(SI_BETTERUI_BANKING_TOGGLE_LIST),
		            keybind = "UI_SHORTCUT_SECONDARY",
		            callback = function()
		                self:ToggleList(self.currentMode == LIST_DEPOSIT)
		            end,
		            visible = function()
		                return true
		            end,
		            enabled = true,
		        },

                -- Support QUATERNARY as a quick Clear Search key when the header search control is visible.
                {
                    name = function()
                        return GetString(SI_BETTERUI_CLEAR_SEARCH) or GetString(SI_GAMEPAD_SELECT_OPTION) or "Clear"
                    end,
                    alignment = KEYBIND_STRIP_ALIGN_LEFT,
                    keybind = "UI_SHORTCUT_QUATERNARY",
                    disabledDuringSceneHiding = true,
                    visible = function()
                        return self.textSearchHeaderControl ~= nil and not self.textSearchHeaderControl:IsHidden()
                    end,
                    callback = function()
                        if not (self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden())) then return end
                        -- Use centralized helper to clear the search and restore keybinds
                        if self.ClearTextSearch then
                            self:ClearTextSearch()
                        end
                        -- After clearing search, restore the standard banking keybinds
                        pcall(function()
                            if self.textSearchKeybindStripDescriptor then
                                KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
                            end
                        end)
                        pcall(function()
                            if self.coreKeybinds then
                                KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
                                pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds) end)
                            end
                        end)
                        pcall(function()
                            if self.withdrawDepositKeybinds then
                                KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
                                pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds) end)
                            end
                        end)
                    end,
                },
               {
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            name = function()
                local cost = GetNextBankUpgradePrice()
                local text
                if GetCarriedCurrencyAmount(CURT_MONEY) >= cost then
                    text = zo_strformat(SI_BANK_UPGRADE_TEXT, ZO_CurrencyControl_FormatCurrency(cost), ZO_GAMEPAD_GOLD_ICON_FORMAT_24)
                else
                    text = zo_strformat(SI_BANK_UPGRADE_TEXT, ZO_ERROR_COLOR:Colorize(ZO_CurrencyControl_FormatCurrency(cost)), ZO_GAMEPAD_GOLD_ICON_FORMAT_24)
                end
                return text or ""
            end,
            visible = function()
                return IsBankUpgradeAvailable()
            end,
            enabled = function()
                return GetCarriedCurrencyAmount(CURT_MONEY) >= GetNextBankUpgradePrice()
            end,
            callback = function()
                if GetNextBankUpgradePrice() > GetCarriedCurrencyAmount(CURT_MONEY) then
                    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(SI_BUY_BANK_SPACE_CANNOT_AFFORD))
                else
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.mainKeybindStripDescriptor)
                    DisplayBankUpgrade()
                end
            end
        },
{
            name = GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND),
            keybind = "UI_SHORTCUT_TERTIARY",
            order = 1000,
            visible = function()
                return self.selectedItemUniqueId ~= nil or self:GetList().selectedData ~= nil
            end,

            callback = function()
				self:SaveListPosition()
                self:ShowActions()
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = GetString(SI_ITEM_ACTION_STACK_ALL),
            keybind = "UI_SHORTCUT_LEFT_STICK",
            order = 1500,
            disabledDuringSceneHiding = true,
            visible = function()
                return self.list and not self.list:IsEmpty()
            end,
            callback = function()				
                if(self.currentMode == LIST_WITHDRAW) then
                    if(currentUsedBank == BAG_BANK) then
                        StackBag(BAG_BANK)
                        StackBag(BAG_SUBSCRIBER_BANK)
                    else
                        StackBag(currentUsedBank)
                    end
                else
                    StackBag(BAG_BACKPACK)
                end
            end,
        },
	}
    self.withdrawDepositKeybinds = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
                {
                    name = function()
                        local n = (self.currentMode == LIST_WITHDRAW) and GetString(SI_BETTERUI_BANKING_WITHDRAW) or GetString(SI_BETTERUI_BANKING_DEPOSIT)
                        return n or ""
                    end,
                    keybind = "UI_SHORTCUT_PRIMARY",
                    callback = function()
                        self:SaveListPosition()
                        self:MoveItem(self.list)
                    end,
                    visible = function()
                        return self.list and not self.list:IsEmpty() and self.list:GetSelectedData() ~= nil and self.list:GetSelectedData().bagId ~= nil
                    end,
                    enabled = function()
                        return self.list and not self.list:IsEmpty() and self.list:GetSelectedData() ~= nil and self.list:GetSelectedData().bagId ~= nil
                    end,
                },
    }

    self.currencySelectorKeybinds =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_BETTERUI_CONFIRM_AMOUNT),
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return true
            end,
            callback = function()
                local amount = self.selector:GetValue()
				local currencyType = self:GetList().selectedData.currencyType
                if(self.currentMode == LIST_WITHDRAW) then
                    WithdrawCurrencyFromBank(currencyType, amount)
                else
                    DepositCurrencyIntoBank(currencyType, amount)
                end
                self:HideSelector()
                self:RefreshFooter()
				KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)

            end,
        }
    }

    self.currencyKeybinds = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
                {
                    name = function()
                        local lbl = nil
                        local list = self:GetList()
                        if list and list.selectedData then
                            lbl = list.selectedData.label
                        end
                        return lbl or ""
                    end,
                    keybind = "UI_SHORTCUT_PRIMARY",
                    callback = function()
                        self:SaveListPosition()
                        self:DisplaySelector(self:GetList().selectedData.currencyType)
                    end,
                    visible = function()
                        return true
                    end,
                    enabled = true,
                },
    }


	ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.coreKeybinds, GAME_NAVIGATION_TYPE_BUTTON) -- "Back"
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.currencySelectorKeybinds, GAME_NAVIGATION_TYPE_BUTTON, function() self:HideSelector() end)

    -- removed unused self.triggerSpinnerBinds placeholder
    local leftTrigger, rightTrigger = self:CreateListTriggerKeybindDescriptors(self.list)
    table.insert(self.coreKeybinds, leftTrigger)
    table.insert(self.coreKeybinds, rightTrigger)


	self.spinnerKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_BETTERUI_CONFIRM),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
            	self:SaveListPosition()
		        self:MoveItem(self.list, self.spinner:GetValue())
            end,
            visible = function()
                return true
            end,
            enabled = true,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.spinnerKeybindStripDescriptor,
                                                    GAME_NAVIGATION_TYPE_BUTTON,
                                                    function()
                                                        local list = self.list
                                                        self:CancelWithdrawDeposit(list)
                                                        KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
                                                    end)
end

function BETTERUI.Banking.Class:SaveListPosition()
    -- Able to return to the current position again!
    self.lastPositions[self.currentMode] = self.list.selectedIndex
    -- Save per-category position for current category (shared across modes during session)
    if self.bankCategories and #self.bankCategories > 0 then
        local cat = self.bankCategories[self.currentCategoryIndex or 1]
        if cat then
            self.lastPositionsByCategory[cat.key] = self.list.selectedIndex
        end
    end
end

function BETTERUI.Banking.Class:ReturnToSaved()
    self:CurrentUsedBank()
    -- If there are no entries, avoid selecting index 1 (which would error)
    local totalEntries = (self.list and self.list.dataList and #self.list.dataList) or 0
    if totalEntries == 0 then
        -- Default to item keybinds and clear tooltip
        if KEYBIND_STRIP then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)
        end
        if GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        end
        return
    end
    -- Skip restoration logic if we just toggled modes - category is already set correctly
    if self._justToggledMode then
        self.list:SetSelectedIndexWithoutAnimation(1, true, false)
        return
    end
    local lastPosition = self.lastPositions[self.currentMode]
    -- Prefer per-category saved index when available (shared across modes in session)
    if self.bankCategories and #self.bankCategories > 0 then
        local cat = self.bankCategories[self.currentCategoryIndex or 1]
        if cat then
            if self.lastPositionsByCategory and self.lastPositionsByCategory[cat.key] then
                lastPosition = self.lastPositionsByCategory[cat.key]
            end
        end
    end
    -- Default and clamp to valid range to avoid nil or OOB indices
    lastPosition = zo_clamp(tonumber(lastPosition) or 1, 1, totalEntries)
    if(self.currentMode == LIST_WITHDRAW) then
        if(lastUsedBank ~= currentUsedBank) then
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
            self.currentMode = LIST_DEPOSIT
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
			self.currentMode = LIST_WITHDRAW
            self:LastUsedBank()
            self:RefreshList()
        else
            self.list:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
        end
    else
        if(lastUsedBank ~= currentUsedBank) then
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
            self:LastUsedBank()
            self.currentMode = LIST_WITHDRAW
            self:ToggleList(self.currentMode == LIST_WITHDRAW)
        else
            self.list:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
        end
    end
end

-- Go through and get the item which has been passed to us through the event
function BETTERUI.Banking.Class:UpdateSingleItem(bagId, slotIndex)
    -- Rebuild the list from the shared inventory cache rather than mutating
    -- the parametric list internals while it's animating/moving.
    self:RefreshList()
end

-- This is the final function for the Event "EVENT_INVENTORY_SINGLE_SLOT_UPDATE".
function BETTERUI.Banking.Class:RemoveItemStack(itemIndex)
        -- Avoid directly mutating the parametric list while it may be moving; just refresh.
        self:RefreshList()
end

function BETTERUI.Banking.Class:ToggleList(toWithdraw)
	self:SaveListPosition()

    -- Capture the category KEY from CURRENT mode before switching
    local prevCategoryKey = nil
    local prevCategoryIndex = self.currentCategoryIndex or 1
    if self.bankCategories and prevCategoryIndex <= #self.bankCategories then
        local prevCat = self.bankCategories[prevCategoryIndex]
        if prevCat then
            prevCategoryKey = prevCat.key
        end
    end

	self.currentMode = toWithdraw and LIST_WITHDRAW or LIST_DEPOSIT
    -- Rebuild categories for the NEW mode
    self.bankCategories = ComputeVisibleBankCategories(self)
    
    -- Try to find the same category key in the new mode; if not found, default to All Items (index 1)
    local newCategoryIndex = 1  -- Default to All Items
    local categoryFound = false
    if prevCategoryKey then
        for i, cat in ipairs(self.bankCategories) do
            if cat.key == prevCategoryKey then
                newCategoryIndex = i
                categoryFound = true
                break
            end
        end
    end
    -- If category doesn't exist in new mode, ensure we default to All Items
    if not categoryFound then
        newCategoryIndex = 1
    end
    -- Clamp the index to valid range BEFORE setting it
    self.currentCategoryIndex = zo_clamp(newCategoryIndex, 1, #self.bankCategories)
    
    -- Reset list position to first item in the new mode
    self.lastPositions[self.currentMode] = 1
    -- Flag that we just toggled so RebuildHeaderCategories uses animation-free selection
    self._justToggledMode = true
    self:RebuildHeaderCategories()
    self._justToggledMode = false
	local footer = self.footer:GetNamedChild("Footer")
	if(self.currentMode == LIST_WITHDRAW) then
		footer:GetNamedChild("SelectBg"):SetTextureRotation(0)

		footer:GetNamedChild("DepositButtonLabel"):SetColor(0.26,0.26,0.26,1)
		footer:GetNamedChild("WithdrawButtonLabel"):SetColor(1,1,1,1)
	else
		footer:GetNamedChild("SelectBg"):SetTextureRotation(3.1415)

		footer:GetNamedChild("DepositButtonLabel"):SetColor(1,1,1,1)
		footer:GetNamedChild("WithdrawButtonLabel"):SetColor(0.26,0.26,0.26,1)
	end
	KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
	--KEYBIND_STRIP:UpdateKeybindButtonGroup(self.spinnerKeybindStripDescriptor)
	self:RefreshList()
end

-- Stage 1: Category cycling via shoulder buttons
function BETTERUI.Banking.Class:CycleCategory(delta)
    if not (self.bankCategories and #self.bankCategories > 1) then return end
    local count = #self.bankCategories
    local idx = (self.currentCategoryIndex or 1) + delta
    if idx < 1 then idx = count end
    if idx > count then idx = 1 end
    self:SaveListPosition()
    -- Drive selection via header tabbar; onSelectedChanged will handle refresh
    if self.headerGeneric and self.headerGeneric.tabBar then
        self.headerGeneric.tabBar:SetSelectedIndex(idx, true, true)
    else
        self.currentCategoryIndex = idx
        self:RefreshList()
    end
end

-- Update only the header title text with current category
function BETTERUI.Banking.Class:UpdateHeaderTitle()
    local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    if cat and cat.name then
        -- Match inventory: use default title color (white), no custom color tags
        self:SetTitle(zo_strformat("<<1>>", cat.name))
    else
        self:SetTitle(self.headerBaseTitle or "Advanced Banking")
    end
    -- Reposition the search control so it sits under the header/title (above the list)
    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
end

-- Centralized helper to clear the text search UI and internal state.
function BETTERUI.Banking.Class:ClearTextSearch()
    self.searchQuery = ""
    if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.ClearSearchText then
        pcall(function() BETTERUI.Interface.Window.ClearSearchText(self) end)
    elseif self.ClearSearchText then
        pcall(function() self:ClearSearchText() end)
    end
end

function BETTERUI.Banking.Class:IsHeaderActive()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        local ok, active = pcall(function() return self.textSearchHeaderFocus:IsActive() end)
        if ok then
            return active
        end
    end
    return self._searchModeActive == true
end

function BETTERUI.Banking.Class:RequestEnterHeader()
    if self.OnEnterHeader then
        self:OnEnterHeader()
    else
        self:EnterSearchMode()
    end
end

function BETTERUI.Banking.Class:RequestLeaveHeader()
    if self.OnLeaveHeader then
        self:OnLeaveHeader()
    else
        self:LeaveSearchMode()
    end
end

function BETTERUI.Banking.Class:RefreshActiveKeybinds()
    if not (self.selectedDataCallback and self.list) then return end
    local selectedControl = nil
    if self.list.GetSelectedControl then
        selectedControl = self.list:GetSelectedControl()
    end
    local selectedData = nil
    if self.list.GetSelectedData then
        selectedData = self.list:GetSelectedData()
    end
    self:selectedDataCallback(selectedControl, selectedData)
end

function BETTERUI.Banking.Class:EnterSearchMode()
    if self._searchModeActive then return end
    self._searchModeActive = true

    pcall(function()
        if self.coreKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
        end
        if self.withdrawDepositKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
        end
    end)

    if self.textSearchKeybindStripDescriptor then
        pcall(function() EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor) end)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Activate then
        if not self.textSearchHeaderFocus:IsActive() then
            pcall(function() self.textSearchHeaderFocus:Activate() end)
        end
    end

    if self.SetTextSearchFocused then
        pcall(function() self:SetTextSearchFocused(true) end)
    end

    self:ActivateSearchDirectionalInput()
end

function BETTERUI.Banking.Class:LeaveSearchMode()
    if not self._searchModeActive then return end
    self._searchModeActive = false

    pcall(function()
        if self.textSearchKeybindStripDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
        end
    end)

    pcall(function()
        if self.coreKeybinds then
            EnsureKeybindGroupAdded(self.coreKeybinds)
        end
        if self.withdrawDepositKeybinds then
            EnsureKeybindGroupAdded(self.withdrawDepositKeybinds)
        end
    end)

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate then
        if self.textSearchHeaderFocus:IsActive() then
            pcall(function() self.textSearchHeaderFocus:Deactivate() end)
        end
    end

    if self.SetTextSearchFocused then
        pcall(function() self:SetTextSearchFocused(false) end)
    end

    pcall(function() self:EnsureHeaderKeybindsActive() end)

    if self.list and not self.list:IsActive() then
        pcall(function() self.list:Activate() end)
    end

    pcall(function() self:RefreshActiveKeybinds() end)

    self:DeactivateSearchDirectionalInput()
end

function BETTERUI.Banking.Class:ExitSearchFocus(selectTopResult)
    if self:IsHeaderActive() then
        self:RequestLeaveHeader()
    else
        self:LeaveSearchMode()
    end

    if selectTopResult then
        local list = self.list
        if list and list.SetSelectedIndexWithoutAnimation then
            local count = 0
            if list.GetNumItems then
                count = list:GetNumItems()
            elseif list.GetNumEntries then
                count = list:GetNumEntries()
            elseif list.dataList then
                count = #list.dataList
            end
            if count > 0 then
                pcall(function() list:SetSelectedIndexWithoutAnimation(1, true, false) end)
            end
        end
    end
end

-- Position the text search control directly beneath the header/title so it appears
-- above the list rows (currency/withdraw/deposit). Keeps the search visible for all categories.
function BETTERUI.Banking.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then return end
    -- Clear existing anchors then attach below the visible header area
    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.headerGeneric or self.header
    -- Try to anchor under the header's TitleContainer if present, otherwise under the header itself
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        titleContainer = anchorTarget:GetNamedChild("TitleContainer") or anchorTarget:GetNamedChild("Header")
    end
    local parentForAnchor = titleContainer or anchorTarget
    if parentForAnchor then
        -- Adjust these values here to tweak the search control's position and size
        -- xOffset: horizontal offset from the header's left edge (moves control right)
        -- yOffset: vertical offset from the header's bottom (positive moves down)
        -- rightInset: inset applied to the right anchor (negative moves left)
        local cfg = {
            xOffset = 48,
            yOffset = 8,
            rightInset = -8,
        }
        local yOffset = (cfg and cfg.yOffset)
        local xOffset = (cfg and cfg.xOffset)
        local rightInset = (cfg and cfg.rightInset)
        -- Anchor left with an X offset, and inset the right anchor slightly so control width remains reasonable
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        -- Fallback: anchor to header control bottom
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, 8)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0, 8)
    end
    self.textSearchHeaderControl:SetHidden(false)
end

-- Override header-enter lifecycle to auto-focus the text search when header is entered.
function BETTERUI.Banking.Class:OnEnterHeader()
    if self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden()) then
        self:EnterSearchMode()

        -- Call base implementation if present
        if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.OnEnterHeader then
            pcall(function() BETTERUI.Interface.Window.OnEnterHeader(self) end)
        end

        -- Ensure only the Clear keybind group remains visible shortly after entering header
        zo_callLater(function()
            if not self._searchModeActive then return end
            if not KEYBIND_STRIP then return end

            pcall(function()
                local keybindGroups = KEYBIND_STRIP.keybindButtonGroups
                if keybindGroups then
                    for i = #keybindGroups, 1, -1 do
                        local group = keybindGroups[i]
                        if group and group ~= self.textSearchKeybindStripDescriptor then
                            KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                        end
                    end
                end
            end)

            if not self._searchModeActive then return end

            if self.textSearchKeybindStripDescriptor then
                pcall(function()
                    EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
                end)
            end
        end, 20)
    else
        -- Fallback to base behavior if no text search available
        if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.OnEnterHeader then
            pcall(function() BETTERUI.Interface.Window.OnEnterHeader(self) end)
        end
    end
end

function BETTERUI.Banking.Class:OnLeaveHeader()
    self:LeaveSearchMode()

    if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.OnLeaveHeader then
        pcall(function() BETTERUI.Interface.Window.OnLeaveHeader(self) end)
    end
end

-- Ensure the header tab bar's LB/RB keybinds are active (idempotent)
function BETTERUI.Banking.Class:EnsureHeaderKeybindsActive()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if tabBar and tabBar.keybindStripDescriptor then
        tabBar:Activate()
    end
end

function BETTERUI.Banking.Class:EnsureSearchDirectionalHandler()
    if self._searchDirectionalHandler then
        return self._searchDirectionalHandler
    end
    if not DIRECTIONAL_INPUT then return nil end

    local handler = {}
    handler.owner = self
    handler.movementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_VERTICAL)
    function handler:UpdateDirectionalInput()
        local owner = self.owner
        if not owner or not owner._searchModeActive then return end
        if not owner:IsHeaderActive() then return end
        local result = self.movementController:CheckMovement()
        if result == MOVEMENT_CONTROLLER_MOVE_NEXT then
            owner:ExitSearchFocus(true)
        end
    end

    self._searchDirectionalHandler = handler
    return handler
end

function BETTERUI.Banking.Class:ActivateSearchDirectionalInput()
    local handler = self:EnsureSearchDirectionalHandler()
    if not handler or self._searchDirectionalActive then return end
    if handler.movementController and handler.movementController.Reset then
        handler.movementController:Reset()
    end
    self._searchDirectionalActive = true
    DIRECTIONAL_INPUT:Activate(handler)
end

function BETTERUI.Banking.Class:DeactivateSearchDirectionalInput()
    if not self._searchDirectionalActive or not self._searchDirectionalHandler then return end
    self._searchDirectionalActive = false
    DIRECTIONAL_INPUT:Deactivate(self._searchDirectionalHandler)
    if self._searchDirectionalHandler.movementController and self._searchDirectionalHandler.movementController.Reset then
        self._searchDirectionalHandler.movementController:Reset()
    end
end

-- Build/refresh the header tab bar entries for banking categories
function BETTERUI.Banking.Class:RebuildHeaderCategories()
    if not (self.header and self.bankCategories) then return end
    -- Prepare header data and entries
    self.bankHeaderData = self.bankHeaderData or {}
    self.bankHeaderData.titleText = function()
        local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
        return (cat and cat.name) or GetString(SI_BETTERUI_INV_ITEM_ALL)
    end
    self.bankHeaderData.tabBarData = { parent = self }
    self.bankHeaderData.onSelectedChanged = function(list, selectedData)
        -- Skip callback during mode toggle to prevent override
        if self._justToggledMode then
            return
        end
        -- Skip callback during rebuild to prevent override after category removal
        if self._suppressHeaderCallback then
            return
        end
        -- Coalesce rapid tab changes: only refresh once after navigation settles
        self.currentCategoryIndex = list.selectedIndex or 1
        self._categoryChangeToken = (self._categoryChangeToken or 0) + 1
        local myToken = self._categoryChangeToken
        -- Assert suppression tied to this token
        self._suppressListUpdatesToken = myToken
        self._suppressListUpdates = true
        -- Wait a short moment; if more changes occur, older timers abort via token check
        zo_callLater(function()
            -- If the banking scene is no longer visible, drop this refresh to avoid
            -- re-activating controls or keybinds while hidden
            if not (SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing()) then
                -- clear suppression for safety
                if self._suppressListUpdatesToken == myToken then
                    self._suppressListUpdates = false
                    self._suppressListUpdatesToken = nil
                end
                return
            end
            if myToken ~= self._categoryChangeToken then
                -- A newer selection occurred; let the latest timer handle refresh/suppression
                return
            end
            -- We're the latest change; clear suppression and refresh once
            if self._suppressListUpdates and self._suppressListUpdatesToken == myToken then
                self._suppressListUpdates = false
                self._suppressListUpdatesToken = nil
            end
            self:UpdateHeaderTitle()
            self:RefreshList()
        end, 100) -- ~6 frames; avoids loading intermediate categories during wrap
    end

    -- Ensure tabbar exists then clear and repopulate
    if not self.headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(self.headerGeneric, self.bankHeaderData, false)
    end
    if self.headerGeneric.tabBar then
        self.headerGeneric.tabBar:Clear()
    end
    for i = 1, #self.bankCategories do
        local cat = self.bankCategories[i]
        local icon = BANK_CATEGORY_ICONS[cat.key] or BANK_CATEGORY_ICONS.all
        local entryData = ZO_GamepadEntryData:New(cat.name, icon)
        entryData.filterType = cat.filterType -- influences icon tint like inventory
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(self.headerGeneric, entryData)
    end
    BETTERUI.GenericHeader.Refresh(self.headerGeneric, self.bankHeaderData, false)
    -- Select the current category in the header
    if self.headerGeneric.tabBar then
        local idx = zo_clamp(self.currentCategoryIndex or 1, 1, #self.bankCategories)
        -- During mode toggle, use animation-free selection to avoid callback interference
        if self._justToggledMode then
            self.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(idx, true, false)
        else
            -- Suppress callback during rebuild to prevent it overriding our selection
            self._suppressHeaderCallback = true
            self.headerGeneric.tabBar:SetSelectedIndex(idx, true, true)
            self._suppressHeaderCallback = false
        end
    end
    -- Update title to match
    self:UpdateHeaderTitle()
    self:EnsureHeaderKeybindsActive()
    -- Ensure the header's focus control includes the search control when present so
    -- vertical navigation can move into the header/search like Inventory. Prefer the
    -- module's generic header target when available (self.headerGeneric) to match
    -- where the tabBar and focusable controls were initialized.
    if ZO_GamepadGenericHeader_SetHeaderFocusControl and self.textSearchHeaderControl then
        pcall(function()
            local headerTarget = nil
            if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.control then
                headerTarget = self.headerGeneric.tabBar.control
            elseif self.headerGeneric then
                headerTarget = self.headerGeneric
            else
                headerTarget = self.header
            end
            ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
        end)
    end
end

function BETTERUI.Banking.Init()
    BETTERUI.Banking.Window = BETTERUI.Banking.Class:New("BETTERUI_TestWindow", BETTERUI_TEST_SCENE)
    BETTERUI.Banking.Window:SetTitle("|c0066FFAdvanced Banking|r")
    -- Initialize header with categories & selection immediately
    BETTERUI.Banking.Window:RebuildHeaderCategories()


    -- Set the column headings up, maybe put them into a table?
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_NAME),87)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_TYPE),637)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_TRAIT),897)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_STAT),1067)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_VALUE),1187)

    BETTERUI.Banking.Window:RefreshList()

    SCENE_MANAGER.scenes['gamepad_banking'] = SCENE_MANAGER.scenes['BETTERUI_BANKING']

    esoSubscriber = IsESOPlusSubscriber()
end
