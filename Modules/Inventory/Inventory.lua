-- shadowcep: Patched for compatibility with ESO Update 34 (from fix by CinderDarkfire)
local _

local BLOCK_TABBAR_CALLBACK = true
ZO_GAMEPAD_INVENTORY_SCENE_NAME = "gamepad_inventory_root"

-------------------------------------------------------------------------------------------------------------------------------------------------------
--
--    BetterUI Inventory Class - Main Inventory Implementation
--    This file contains the core inventory functionality, including item management, equip logic, and UI interactions
--
-------------------------------------------------------------------------------------------------------------------------------------------------------

BETTERUI.Inventory.Class = ZO_GamepadInventory:Subclass()

local CATEGORY_ITEM_ACTION_MODE = 1
local ITEM_LIST_ACTION_MODE = 2
local CRAFT_BAG_ACTION_MODE = 3

local DIALOG_QUEUE_WORKAROUND_TIMEOUT_DURATION = 300

local INVENTORY_LEFT_TOOL_TIP_REFRESH_DELAY_MS = 300

local INVENTORY_CATEGORY_LIST = "categoryList"
local INVENTORY_ITEM_LIST = "itemList"
local INVENTORY_CRAFT_BAG_LIST = "craftBagList"

BETTERUI_EQUIP_SLOT_DIALOG = "BETTERUI_EQUIP_SLOT_PROMPT"

local function EnsureKeybindGroupAdded(descriptor)
    if not descriptor or not KEYBIND_STRIP then return end
    local groups = KEYBIND_STRIP.keybindButtonGroups or {}
    for _, group in ipairs(groups) do
        if group == descriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
            return
        end
    end
    KEYBIND_STRIP:AddKeybindButtonGroup(descriptor)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
end

-- local function copied (and slightly edited for unequipped items!) from "inventoryutils_gamepad.lua"
local function BETTERUI_GetEquipSlotForEquipType(equipType)
    -- Prefer the slot corresponding to the currently intended bar (primary/backup)
    -- for combat-related equipment (weapons/poison). For armor/jewelry, primary/backup is irrelevant.
    local wantPrimary = true
    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.isPrimaryWeapon ~= nil then
        wantPrimary = GAMEPAD_INVENTORY.isPrimaryWeapon
    end

    local lastMatchingSlot = nil
    for _, testSlot in ZO_Character_EnumerateOrderedEquipSlots() do
        local locked = IsLockedWeaponSlot(testSlot)
        local isCorrectSlot = ZO_Character_DoesEquipSlotUseEquipType(testSlot, equipType)
        if not locked and isCorrectSlot then
            local isActive = IsActiveCombatRelatedEquipmentSlot(testSlot)
            -- For weapon-like equip types, honor intended bar; otherwise return first match
            if equipType == EQUIP_TYPE_MAIN_HAND or equipType == EQUIP_TYPE_OFF_HAND or equipType == EQUIP_TYPE_TWO_HAND or equipType == EQUIP_TYPE_POISON then
                if wantPrimary and isActive then
                    return testSlot
                elseif not wantPrimary and not isActive then
                    return testSlot
                end
                -- Keep a fallback in case we don't find the exact active/inactive match (edge cases)
                lastMatchingSlot = testSlot
            else
                return testSlot
            end
        end
    end
    return lastMatchingSlot
end

function BETTERUI.Inventory.UpdateTooltipEquippedText(tooltipType, equipSlot)
    ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText(tooltipType, equipSlot)
    local isHidden, highestPriorityVisualLayerThatIsShowing = WouldEquipmentBeHidden(equipSlot or EQUIP_SLOT_NONE, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    local equipSlotText = ""
    local equipSlotTextHidden = ""
    local equippedHeader = GetString(SI_GAMEPAD_EQUIPPED_ITEM_HEADER)

    if equipSlot == EQUIP_SLOT_MAIN_HAND then
        equipSlotText = GetString(SI_GAMEPAD_EQUIPPED_MAIN_HAND_ITEM_HEADER)
    elseif equipSlot == EQUIP_SLOT_BACKUP_MAIN then
        equipSlotText = GetString(SI_GAMEPAD_EQUIPPED_BACKUP_MAIN_ITEM_HEADER)
    elseif equipSlot == EQUIP_SLOT_OFF_HAND then
        equipSlotText = GetString(SI_GAMEPAD_EQUIPPED_OFF_HAND_ITEM_HEADER)
    elseif equipSlot == EQUIP_SLOT_BACKUP_OFF then
        equipSlotText = GetString(SI_GAMEPAD_EQUIPPED_BACKUP_OFF_ITEM_HEADER)
    end
     
    if isHidden and equipSlotText ~= "" then
        equipSlotTextHidden = "(Hidden)"
        GAMEPAD_TOOLTIPS:SetStatusLabelText(tooltipType, zo_strformat("<<1>>: ", equippedHeader), zo_strformat("<<1>> <<2>>", equipSlotText, equipSlotTextHidden))
    elseif isHidden then
        equipSlotTextHidden = "Hidden by Collection"
        GAMEPAD_TOOLTIPS:SetStatusLabelText(tooltipType, zo_strformat("<<1>> - <<2>>", equippedHeader, equipSlotTextHidden))
    elseif not isHidden and equipSlotText ~= "" then
        GAMEPAD_TOOLTIPS:SetStatusLabelText(tooltipType, zo_strformat("<<1>>: ", equippedHeader), zo_strformat("<<1>>", equipSlotText))
    else
        GAMEPAD_TOOLTIPS:SetStatusLabelText(tooltipType, GetString(SI_GAMEPAD_EQUIPPED_ITEM_HEADER), equipSlotText)
    end
end

-- The below functions are included from ZO_GamepadInventory.lua
local function MenuEntryTemplateEquality(left, right)
    return left.uniqueId == right.uniqueId
end 


local function SetupItemList(list)
    list:AddDataTemplate("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality)
	list:AddDataTemplateWithHeader("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality, "ZO_GamepadMenuEntryHeaderTemplate")
end

local function SetupCraftBagList(buiList)
    buiList.list:AddDataTemplate("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality)
	buiList.list:AddDataTemplateWithHeader("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality, "ZO_GamepadMenuEntryHeaderTemplate")
end
local function SetupCategoryList(list)
    list:AddDataTemplate("BETTERUI_GamepadItemEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

-- NOTE: The old helper BETTERUI_InventoryUtils_MatchWeapons was removed as it's unused.

local function WrapValue(newValue, maxValue)
    if(newValue < 1) then return maxValue end
    if(newValue > maxValue) then return 1 end
    return newValue
end

function BETTERUI.Inventory.Class:ToSavedPosition()
    local lastPosition
    if self.categoryList.selectedData ~= nil then
        if not self.categoryList:GetTargetData().onClickDirection then
            self:SwitchActiveList(INVENTORY_ITEM_LIST)
			self:RefreshItemList()
        else
            self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
            self:RefreshCraftBagList()
        end
    end

    if self:GetCurrentList() == self.itemList then
        lastPosition = self.categoryPositions[self.categoryList.selectedIndex]
    else
        lastPosition = self.categoryCraftPositions[self.categoryList.selectedIndex]
    end

    if lastPosition ~= nil and self._currentList.dataList ~= nil then
        lastPosition = (#self._currentList.dataList > lastPosition) and lastPosition or #self._currentList.dataList

        if lastPosition ~= nil and #self._currentList.dataList > 0 then
            self._currentList:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
            
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            if self.callLaterLeftToolTip ~= nil then
                EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
            end
            
            local callLaterId = zo_callLater(function() self:UpdateItemLeftTooltip(self._currentList.selectedData) end, INVENTORY_LEFT_TOOL_TIP_REFRESH_DELAY_MS)
            self.callLaterLeftToolTip = "CallLaterFunction"..callLaterId
        else
            -- No entries in the current list; avoid forcing a selection on an empty list.
            -- Let the caller handle switching back to the category view if appropriate.
            -- No entries in the current list. Previously we deactivated the list which
            -- left the UI dimmed/out-of-focus when the player quickly switched
            -- categories while a text filter was active. Instead of deactivating
            -- the current list, switch focus back to the category list so the
            -- header/tab stays active and keybinds remain correct.
            if GAMEPAD_TOOLTIPS then GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP) end
            -- Ensure we land back on the category view (this will also refresh header/keybinds)
            if self.SwitchActiveList then
                pcall(function() self:SwitchActiveList(INVENTORY_CATEGORY_LIST) end)
            end
            return
        end
    end
end

function BETTERUI_TabBar_OnTabNext(parent, successful)
    if(successful) then
        if not parent.categoryList or not parent.categoryList.dataList or #parent.categoryList.dataList == 0 then
            return
        end
        parent:SaveListPosition()

        parent.categoryList.targetSelectedIndex = WrapValue(parent.categoryList.targetSelectedIndex + 1, #parent.categoryList.dataList)
        parent.categoryList.selectedIndex = parent.categoryList.targetSelectedIndex
        parent.categoryList.selectedData = parent.categoryList.dataList[parent.categoryList.selectedIndex]
        parent.categoryList.defaultSelectedIndex = parent.categoryList.selectedIndex

		BETTERUI.GenericHeader.SetTitleText(parent.header, parent.categoryList.selectedData.text)

        parent:ToSavedPosition()
    end
end
function BETTERUI_TabBar_OnTabPrev(parent, successful)
    if(successful) then
        if not parent.categoryList or not parent.categoryList.dataList or #parent.categoryList.dataList == 0 then
            return
        end
        parent:SaveListPosition()

        parent.categoryList.targetSelectedIndex = WrapValue(parent.categoryList.targetSelectedIndex - 1, #parent.categoryList.dataList)
        parent.categoryList.selectedIndex = parent.categoryList.targetSelectedIndex
        parent.categoryList.selectedData = parent.categoryList.dataList[parent.categoryList.selectedIndex]
        parent.categoryList.defaultSelectedIndex = parent.categoryList.selectedIndex

        --parent:RefreshItemList()
		BETTERUI.GenericHeader.SetTitleText(parent.header, parent.categoryList.selectedData.text)

        parent:ToSavedPosition()
    end
end

function BETTERUI.Inventory.Class:SaveListPosition()
    -- Guard against nil lists/indices (can happen during scene hide/teardown)
    if not self.categoryList or not self.categoryList.selectedIndex then return end
    if not self._currentList or not self._currentList.selectedIndex then return end

    if self:GetCurrentList() == self.itemList then
        self.categoryPositions[self.categoryList.selectedIndex] = self._currentList.selectedIndex
    else
        self.categoryCraftPositions[self.categoryList.selectedIndex] = self._currentList.selectedIndex
    end 
end

--- Build the category list UI and wire up selection/target callbacks
--- Responds to category selection by switching between item and craft bag lists
function BETTERUI.Inventory.Class:InitializeCategoryList()

    self.categoryList = self:AddList("Category", SetupCategoryList)
    self.categoryList:SetNoItemText(GetString(SI_GAMEPAD_INVENTORY_EMPTY))

    -- Match the tooltip to the selected data because it looks nicer
    local function OnSelectedCategoryChanged(list, selectedData)
	    if selectedData ~= nil and self.scene:IsShowing() then
		    self:UpdateCategoryLeftTooltip(selectedData)
		
		    if selectedData.onClickDirection then
			    self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
		    else
			    self:SwitchActiveList(INVENTORY_ITEM_LIST)
		    end
	    end
    end

    self.categoryList:SetOnSelectedDataChangedCallback(OnSelectedCategoryChanged)

    --Match the functionality to the target data
    local function OnTargetCategoryChanged(list, targetData)
        if targetData then
                self.selectedEquipSlot = targetData.equipSlot
                self:SetSelectedItemUniqueId(self:GenerateItemSlotData(targetData))
                self.selectedItemFilterType = targetData.filterType
        else
            self:SetSelectedItemUniqueId(nil)
        end

        self.currentlySelectedData = targetData
    end

    self.categoryList:SetOnTargetDataChangedCallback(OnTargetCategoryChanged)

    -- Note: Previously this code attempted to hide the search whenever the
    -- category list activated in order to prevent the search from being
    -- highlighted. That approach caused navigation/confusion in some flows.
    -- We removed the hide/wrap behavior and now rely on header-enter handling
    -- to focus the search when appropriate.
end

local function GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)
    return function(itemData)
        if nonEquipableFilterType then

            return ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, nonEquipableFilterType) or
				(itemData.equipType == EQUIP_TYPE_POISON and nonEquipableFilterType == ITEMFILTERTYPE_WEAPONS) -- will fix soon, patched to allow Poison in "Weapons"
        else
			-- for "All"
            return true
        end

        return ZO_InventoryUtils_DoesNewItemMatchSupplies(itemData)
    end
end

function BETTERUI.Inventory.Class:IsItemListEmpty(filteredEquipSlot, nonEquipableFilterType)
    local baseComparator = GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)
    local function comparatorExcludingJunk(itemData)
        return baseComparator(itemData) and not itemData.isJunk
    end
    return SHARED_INVENTORY:IsFilteredSlotDataEmpty(comparatorExcludingJunk, BAG_BACKPACK, BAG_WORN)
end

-- Robust check for any junk in the backpack using the shared inventory cache,
-- with a direct IsItemJunk fallback as a safety net.
local function HasAnyJunkInBackpack()
    -- Prefer shared inventory cache, which we explicitly refresh after junk toggles.
    if SHARED_INVENTORY and SHARED_INVENTORY.GenerateFullSlotData then
        local function IsJunkSlot(slotData)
            return slotData and slotData.isJunk == true and slotData.bagId == BAG_BACKPACK
        end
        local junkSlots = SHARED_INVENTORY:GenerateFullSlotData(IsJunkSlot, BAG_BACKPACK)
        if type(junkSlots) == "table" and #junkSlots > 0 then
            return true
        end
    end

    -- Fallback to direct bag scan if needed (should be rare).
    local size = GetBagSize(BAG_BACKPACK) or 0
    for slotIndex = 0, size - 1 do
        if IsItemJunk(BAG_BACKPACK, slotIndex) then
            return true
        end
    end
    return false
end

--- Attempt to equip an item, handling different equip types and bind-on-equip protection
--- @param inventorySlot table: The inventory slot data containing item information
--- @param isCallingFromActionDialog boolean: Whether this is called from an action dialog
--- Attempt to equip an item in gamepad inventory, handling bind-on-equip, bar/hand choices
--- inventorySlot: parametric entry for the selected item
--- isCallingFromActionDialog: true when invoked from the Y actions dialog (defers dialogs slightly)
function BETTERUI.Inventory.Class:TryEquipItem(inventorySlot, isCallingFromActionDialog)
    local equipType = inventorySlot.dataSource.equipType
    local bagId = inventorySlot.dataSource.bagId
    local slotIndex = inventorySlot.dataSource.slotIndex

    -- Check if item is bound and handle bind-on-equip protection
    local bound = IsItemBound(bagId, slotIndex)
    local equipItemLink = GetItemLink(bagId, slotIndex)
    local bindType = GetItemLinkBindType(equipItemLink)

    local function showBindOnEquipDialog(callback)
        if not bound and bindType == BIND_TYPE_ON_EQUIP and BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection then
            local function promptForBindOnEquip()
                ZO_Dialogs_ShowPlatformDialog("CONFIRM_EQUIP_BOE", {callback = callback}, {mainTextParams = {equipItemLink}})
            end
            if isCallingFromActionDialog then
                zo_callLater(promptForBindOnEquip, DIALOG_QUEUE_WORKAROUND_TIMEOUT_DURATION)
            else
                promptForBindOnEquip()
            end
        else
            callback()
        end
    end

    -- Determine equip action based on item type
    local function performEquipAction(mainSlot, isPrimary)
        -- isPrimary indicates which weapon bar to target (true = primary/front bar, false = backup/back bar)
        local targetPrimary = (isPrimary ~= false)
        if equipType == EQUIP_TYPE_ONE_HAND then
            if mainSlot then
                CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, targetPrimary and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN, 1)
            else
                CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, targetPrimary and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF, 1)
            end
        elseif equipType == EQUIP_TYPE_MAIN_HAND or equipType == EQUIP_TYPE_TWO_HAND then
            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, targetPrimary and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN, 1)
        elseif equipType == EQUIP_TYPE_OFF_HAND then
            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, targetPrimary and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF, 1)
        elseif equipType == EQUIP_TYPE_POISON then
            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, targetPrimary and EQUIP_SLOT_POISON or EQUIP_SLOT_BACKUP_POISON, 1)
        elseif equipType == EQUIP_TYPE_RING then
            if mainSlot then
                CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, EQUIP_SLOT_RING1, 1)
            else
                CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, EQUIP_SLOT_RING2, 1)
            end
        end
    end

    -- Handle different equip types
    if equipType == EQUIP_TYPE_COSTUME then
        -- Costumes equip directly
        showBindOnEquipDialog(function()
            CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, EQUIP_SLOT_COSTUME, 1)
        end)
    elseif equipType == EQUIP_TYPE_ONE_HAND or equipType == EQUIP_TYPE_RING
        or equipType == EQUIP_TYPE_MAIN_HAND or equipType == EQUIP_TYPE_TWO_HAND
        or equipType == EQUIP_TYPE_OFF_HAND or equipType == EQUIP_TYPE_POISON then
        -- Weapons and rings: prompt to choose bar (primary/backup) and, if applicable, hand
        local function showEquipDialog()
            ZO_Dialogs_ShowDialog(BETTERUI_EQUIP_SLOT_DIALOG, {inventorySlot, self.isPrimaryWeapon}, {mainTextParams = {GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN)}}, true)
        end

        if isCallingFromActionDialog then
            zo_callLater(showEquipDialog, DIALOG_QUEUE_WORKAROUND_TIMEOUT_DURATION)
        else
            showEquipDialog()
        end
    else
        -- Items that equip directly (weapons, armor, etc.)
        local armorType = GetItemArmorType(bagId, slotIndex)
        if armorType ~= ARMORTYPE_NONE or equipType == EQUIP_TYPE_NECK then
            showBindOnEquipDialog(function()
                CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_WORN, BETTERUI_GetEquipSlotForEquipType(equipType), 1)
            end)
        else
            -- Fallback direct equip (should not be hit for weapon-like types now)
            showBindOnEquipDialog(function()
                performEquipAction(true, self.isPrimaryWeapon)
            end)
        end
    end
end

function BETTERUI.Inventory.Class:NewCategoryItem(filterType, iconFile, FilterFunct)
    if FilterFunct == nil then
        FilterFunct = ZO_InventoryUtils_DoesNewItemMatchFilterType
    end

    local isListEmpty = self:IsItemListEmpty(nil, filterType)
    if not isListEmpty then
        local name
        if filterType == nil then
            name = GetString(SI_BETTERUI_INV_ITEM_ALL)
        else
            name = GetString("SI_ITEMFILTERTYPE", filterType)
        end

        local hasAnyNewItems = SHARED_INVENTORY:AreAnyItemsNew(FilterFunct, filterType, BAG_BACKPACK)
        local data = ZO_GamepadEntryData:New(name, iconFile, nil, nil, hasAnyNewItems)
        data.filterType = filterType
        data:SetIconTintOnSelection(true)
        self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
        BETTERUI.GenericHeader.AddToList(self.header, data)
        if not self.populatedCategoryPos then self.categoryPositions[#self.categoryPositions+1] = 1 end
    end
end

--- Rebuild category tabs based on current list (backpack vs craft bag) and item presence
--- Ensures All Items is always present; includes Stolen/Junk when items exist
function BETTERUI.Inventory.Class:RefreshCategoryList()

	local function IsStolenAndNotJunk()
		local usedBagSize = GetNumBagUsedSlots(BAG_BACKPACK)

		for i = 1, usedBagSize do
			local isStolen = IsItemStolen(BAG_BACKPACK, i)
			local isJunk = IsItemJunk(BAG_BACKPACK, i)
			if isStolen and not isJunk then
				return true
			end
		end
		return false
	end
	
	-- Store the current selected index before clearing so we can restore it
	local previousSelectedIndex = self.categoryList.selectedIndex
	
    self.categoryList:Clear()
    self.header.tabBar:Clear()

	local currentList = self:GetCurrentList()

	if currentList == self.craftBagList then
	    do
	        local name = "Crafting Bag"
	        local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_all.dds"
	        local data = ZO_GamepadEntryData:New(name, iconFile)
	        data.onClickDirection = "CRAFTBAG"
	        data:SetIconTintOnSelection(true)

			if not HasCraftBagAccess() then
				data.enabled = false
			end

	        self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
	        BETTERUI.GenericHeader.AddToList(self.header, data)
	        if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
	    end

		do
	        local name = "Alchemy"
	        local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_alchemy.dds"
	        local data = ZO_GamepadEntryData:New(name, iconFile)
	        data.onClickDirection = "CRAFTBAG"
	        data:SetIconTintOnSelection(true)

			data.filterType = ITEMFILTERTYPE_ALCHEMY

			if not HasCraftBagAccess() then
				data.enabled = false
			end

	        self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
	        BETTERUI.GenericHeader.AddToList(self.header, data)
	        if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
	    end

		do
			local name = "Blacksmithing"
			local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_blacksmithing.dds"
			local data = ZO_GamepadEntryData:New(name, iconFile)
			data.onClickDirection = "CRAFTBAG"
			data:SetIconTintOnSelection(true)

			data.filterType = ITEMFILTERTYPE_BLACKSMITHING

			if not HasCraftBagAccess() then
				data.enabled = false
			end

			self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
			BETTERUI.GenericHeader.AddToList(self.header, data)
			if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
		end

	    do
			local name = "Clothing"
			local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_clothing.dds"
			local data = ZO_GamepadEntryData:New(name, iconFile)
			data:SetIconTintOnSelection(true)
			data.onClickDirection = "CRAFTBAG"

			data.filterType = ITEMFILTERTYPE_CLOTHING

			if not HasCraftBagAccess() then
				data.enabled = false
			end

			self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
			BETTERUI.GenericHeader.AddToList(self.header, data)
			if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
		end

		do
	        local name = "Enchanting"
	        local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_enchanting.dds"
	        local data = ZO_GamepadEntryData:New(name, iconFile)
	        data.onClickDirection = "CRAFTBAG"
	        data:SetIconTintOnSelection(true)

			data.filterType = ITEMFILTERTYPE_ENCHANTING

			if not HasCraftBagAccess() then
				data.enabled = false
			end

	        self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
	        BETTERUI.GenericHeader.AddToList(self.header, data)
	        if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
	    end

		do
			local name = "Jewelry Crafting"
			local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_tabicon_craftbag_jewelrycrafting.dds"
			local data = ZO_GamepadEntryData:New(name, iconFile)
			data:SetIconTintOnSelection(true)
			data.onClickDirection = "CRAFTBAG"

			data.filterType = ITEMFILTERTYPE_JEWELRYCRAFTING

			if not HasCraftBagAccess() then
				data.enabled = false
			end

			self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
			BETTERUI.GenericHeader.AddToList(self.header, data)
			if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
		end

		do
	        local name = "Provisioning/Fishing"
	        local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_provisioning.dds"
	        local data = ZO_GamepadEntryData:New(name, iconFile)
	        data.onClickDirection = "CRAFTBAG"
	        data:SetIconTintOnSelection(true)

			data.filterType = ITEMFILTERTYPE_PROVISIONING

			if not HasCraftBagAccess() then
				data.enabled = false
			end

	        self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
	        BETTERUI.GenericHeader.AddToList(self.header, data)
	        if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
	    end

		do
			local name = "Woodworking"
			local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_woodworking.dds"
			local data = ZO_GamepadEntryData:New(name, iconFile)
			data:SetIconTintOnSelection(true)
			data.onClickDirection = "CRAFTBAG"

			data.filterType = ITEMFILTERTYPE_WOODWORKING

			if not HasCraftBagAccess() then
				data.enabled = false
			end

			self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
			BETTERUI.GenericHeader.AddToList(self.header, data)
			if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
		end

		do
			local name = "Style Material"
			local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_stylematerial.dds"
			local data = ZO_GamepadEntryData:New(name, iconFile)
			data:SetIconTintOnSelection(true)
			data.onClickDirection = "CRAFTBAG"

			data.filterType = ITEMFILTERTYPE_STYLE_MATERIALS

			if not HasCraftBagAccess() then
				data.enabled = false
			end

			self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
			BETTERUI.GenericHeader.AddToList(self.header, data)
			if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
		end

		do
			local name = "Trait Gems"
			local iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_itemtrait.dds"
			local data = ZO_GamepadEntryData:New(name, iconFile)
			data:SetIconTintOnSelection(true)
			data.onClickDirection = "CRAFTBAG"

			data.filterType = ITEMFILTERTYPE_TRAIT_ITEMS

			if not HasCraftBagAccess() then
				data.enabled = false
			end

			self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
			BETTERUI.GenericHeader.AddToList(self.header, data)
			if not self.populatedCraftPos then self.categoryCraftPositions[#self.categoryCraftPositions+1] = 1 end
		end

		self.populatedCraftPos = true
	else

		self:NewCategoryItem(nil, "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds")

        do
            local usedBagSize = GetNumBagUsedSlots(BAG_WORN)
            if usedBagSize > 0 then
                local name = GetString(SI_BETTERUI_INV_ITEM_EQUIPPED)
                local iconFile = "esoui/art/inventory/gamepad/gp_inventory_icon_equipped.dds"
                local hasAnyNewItems = SHARED_INVENTORY:AreAnyItemsNew(function() return true end, nil, BAG_WORN)
                local data = ZO_GamepadEntryData:New(name, iconFile, nil, nil, hasAnyNewItems)
                data.showEquipped = true
                data:SetIconTintOnSelection(true)
                self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
                BETTERUI.GenericHeader.AddToList(self.header, data)
                if not self.populatedCategoryPos then self.categoryPositions[#self.categoryPositions+1] = 1 end
            end
        end

	    self:NewCategoryItem(ITEMFILTERTYPE_WEAPONS, "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds")

	    self:NewCategoryItem(ITEMFILTERTYPE_ARMOR, "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds")

	    self:NewCategoryItem(ITEMFILTERTYPE_JEWELRY, "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds")

		self:NewCategoryItem(ITEMFILTERTYPE_CONSUMABLE, "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds")

	    self:NewCategoryItem(ITEMFILTERTYPE_CRAFTING, "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds")

		self:NewCategoryItem(ITEMFILTERTYPE_FURNISHING, "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds")

        self:NewCategoryItem(ITEMFILTERTYPE_COMPANION, "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds")

	    self:NewCategoryItem(ITEMFILTERTYPE_MISCELLANEOUS, "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds")

	    self:NewCategoryItem(ITEMFILTERTYPE_QUICKSLOT, "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds")

        do
			local questCache = SHARED_INVENTORY:GenerateFullQuestCache()
			if next(questCache) then
				local name = GetString(SI_GAMEPAD_INVENTORY_QUEST_ITEMS)
				local iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quest.dds"
				local data = ZO_GamepadEntryData:New(name, iconFile)
				data.filterType = ITEMFILTERTYPE_QUEST
				data:SetIconTintOnSelection(true)
				self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
				BETTERUI.GenericHeader.AddToList(self.header, data)
				if not self.populatedCategoryPos then self.categoryPositions[#self.categoryPositions+1] = 1 end
			end
		end

        do
			if IsStolenAndNotJunk() then
                local isListEmpty = self:IsItemListEmpty(nil, nil)
                if not isListEmpty then
                    local name = GetString(SI_BETTERUI_INV_ITEM_STOLEN)
                    local iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_stolenitem.dds"
                    local hasAnyNewItems = SHARED_INVENTORY:AreAnyItemsNew(function() return true end, nil, BAG_BACKPACK)
                    local data = ZO_GamepadEntryData:New(name, iconFile, nil, nil, hasAnyNewItems)
                    data.showStolen = true
                    data:SetIconTintOnSelection(true)
                    self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
                    BETTERUI.GenericHeader.AddToList(self.header, data)
                    if not self.populatedCategoryPos then self.categoryPositions[#self.categoryPositions+1] = 1 end
                end
            end
        end

        do
            if HasAnyJunkInBackpack() then
                local isListEmpty = self:IsItemListEmpty(nil, nil)
                if not isListEmpty then
                    local name = GetString(SI_BETTERUI_INV_ITEM_JUNK)
                    local iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds"
                    local hasAnyNewItems = SHARED_INVENTORY:AreAnyItemsNew(function() return true end, nil, BAG_BACKPACK)
                    local data = ZO_GamepadEntryData:New(name, iconFile, nil, nil, hasAnyNewItems)
                    data.showJunk = true
                    data:SetIconTintOnSelection(true)
                    self.categoryList:AddEntry("BETTERUI_GamepadItemEntryTemplate", data)
                    BETTERUI.GenericHeader.AddToList(self.header, data)
                    if not self.populatedCategoryPos then self.categoryPositions[#self.categoryPositions+1] = 1 end
                end
            end
        end

		self.populatedCategoryPos = true
	end
	
	-- Restore the previously selected category, or default to the first item if the index is out of bounds
	if previousSelectedIndex and previousSelectedIndex > 0 and previousSelectedIndex <= #self.categoryList.dataList then
		self.categoryList:SetSelectedIndexWithoutAnimation(previousSelectedIndex, true, false)
		self.header.tabBar:SetSelectedIndexWithoutAnimation(previousSelectedIndex, true, false)
	elseif #self.categoryList.dataList > 0 then
		self.categoryList:SetSelectedIndexWithoutAnimation(1, true, false)
		self.header.tabBar:SetSelectedIndexWithoutAnimation(1, true, false)
	end

    self.categoryList:Commit()
    self.header.tabBar:Commit()
end

--- Initialize the gamepad header with tab bar and currency rows used by the inventory
function BETTERUI.Inventory.Class:InitializeHeader()
    local function UpdateTitleText()
		return GetString(self:GetCurrentList() == self.craftBagList and SI_BETTERUI_INV_ACTION_CB or SI_BETTERUI_INV_ACTION_INV)
    end

    local tabBarEntries = {
        {
            text = GetString(SI_GAMEPAD_INVENTORY_CATEGORY_HEADER),
            callback = function()
                self:SwitchActiveList(INVENTORY_CATEGORY_LIST)
            end,
        },
        {
            text = GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER),
            callback = function()
                self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
            end,
        },
    }

    self.categoryHeaderData = {
		titleText = UpdateTitleText,
        tabBarEntries = tabBarEntries,
        tabBarData = { parent = self, onNext = BETTERUI_TabBar_OnTabNext, onPrev = BETTERUI_TabBar_OnTabPrev }
    }

    -- Header data will be built dynamically in RefreshHeader based on settings
    self.craftBagHeaderData = nil
    self.itemListHeaderData = nil

	BETTERUI.GenericHeader.Initialize(self.header, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
	BETTERUI.GenericHeader.SetEquipText(self.header, self.isPrimaryWeapon)
	BETTERUI.GenericHeader.SetBackupEquipText(self.header, self.isPrimaryWeapon)

	BETTERUI.GenericHeader.Refresh(self.header, self.categoryHeaderData, ZO_GAMEPAD_HEADER_TABBAR_CREATE)

	BETTERUI.GenericFooter.Initialize(self)
    

end

function BETTERUI.Inventory.Class:InitializeInventoryVisualData(itemData)
    self.uniqueId = itemData.uniqueId   --need this on self so that it can be used for a compare by EqualityFunction in ParametricScrollList,
	self.bestItemCategoryName = itemData.bestItemCategoryName
    self:SetDataSource(itemData)        --SharedInventory modifies the dataSource's uniqueId before the GamepadEntryData is rebuilt,
	self.dataSource.requiredChampionPoints = GetItemRequiredChampionPoints(itemData.bagId, itemData.slotIndex)
    self:AddIcon(itemData.icon)         --so by copying it over, we can still have access to the old one during the Equality check
    if not itemData.questIndex then
        self:SetNameColors(self:GetColorsBasedOnQuality(self.quality))  --quest items are only white
    end
    self.cooldownIcon = itemData.icon or itemData.iconFile

    self:SetFontScaleOnSelection(false)    --item entries don't grow on selection
end

function BETTERUI.Inventory.Class:RefreshCraftBagList()
	-- we need to pass in our current filterType, as refreshing the craft bag list is distinct from the item list's methods (only slightly)
    self.craftBagList:RefreshList(self.categoryList:GetTargetData().filterType, self.searchQuery)
end


--- Build and sort the item list for the selected category, setting headers and cached fields
function BETTERUI.Inventory.Class:RefreshItemList()
    self.itemList:Clear()
    if self.categoryList:IsEmpty() then return end

    local function IsStolenItem(itemData)
        return itemData.stolen
    end

    local targetCategoryData = self.categoryList:GetTargetData()
    local filteredEquipSlot = targetCategoryData.equipSlot
    local nonEquipableFilterType = targetCategoryData.filterType
    local showJunkCategory = (self.categoryList:GetTargetData().showJunk ~= nil)
    local showEquippedCategory = (self.categoryList:GetTargetData().showEquipped ~= nil)
    local showStolenCategory = (self.categoryList:GetTargetData().showStolen ~= nil)
    local filteredDataTable

    local isQuestItem = nonEquipableFilterType == ITEMFILTERTYPE_QUEST
    --special case for quest items
    if isQuestItem then
        filteredDataTable = {}
        local questCache = SHARED_INVENTORY:GenerateFullQuestCache()
        for _, questItems in pairs(questCache) do
            for _, questItem in pairs(questItems) do
                ZO_InventorySlot_SetType(questItem, SLOT_TYPE_QUEST_ITEM)
                table.insert(filteredDataTable, questItem)
            end
        end
    else
        local comparator = GetItemDataFilterComparator(filteredEquipSlot, nonEquipableFilterType)

        if showEquippedCategory then
            filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(comparator, BAG_WORN)
        elseif showStolenCategory then
			filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(IsStolenItem, BAG_BACKPACK)
        else
            filteredDataTable = SHARED_INVENTORY:GenerateFullSlotData(comparator, BAG_BACKPACK, BAG_WORN)
        end
        -- Process items and set up categories in a single pass
        -- Localize frequently used globals for performance inside tight loop
        local GetItemLink = GetItemLink
        local GetItemLinkItemType = GetItemLinkItemType
        local GetItemLinkSetInfo = GetItemLinkSetInfo
        local GetItemLinkEnchantInfo = GetItemLinkEnchantInfo
        local IsItemLinkRecipeKnown = IsItemLinkRecipeKnown
        local IsItemLinkBookKnown = IsItemLinkBookKnown
        local IsItemBound = IsItemBound
        local ZO_InventorySlot_SetType = ZO_InventorySlot_SetType
        local zo_strformat = zo_strformat
        local GetBestItemCategoryDescription = GetBestItemCategoryDescription
        local WouldEquipmentBeHidden = WouldEquipmentBeHidden
        local FindActionSlotMatchingItem = FindActionSlotMatchingItem
        for i = 1, #filteredDataTable do
            local itemData = filteredDataTable[i]

            -- Set up custom categories
            local customCategory, matched, catName, catPriority = BETTERUI.GetCustomCategory(itemData)
            if customCategory and not matched then
                itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = AC_UNGROUPED_NAME
                itemData.sortPriorityName = string.format("%03d%s", 999, catName)
            elseif customCategory then
                itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = catName
                itemData.sortPriorityName = string.format("%03d%s", 100 - catPriority, catName)
            else
                itemData.bestItemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))
                itemData.bestItemCategoryName = itemData.bestItemTypeName
                itemData.sortPriorityName = itemData.bestItemCategoryName
            end

            -- Handle equipped item status
            if itemData.bagId == BAG_WORN then
                itemData.isEquippedInCurrentCategory = (itemData.slotIndex == filteredEquipSlot)
                itemData.isEquippedInAnotherCategory = (itemData.slotIndex ~= filteredEquipSlot)
                itemData.isHiddenByWardrobe = WouldEquipmentBeHidden(itemData.slotIndex or EQUIP_SLOT_NONE, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
            else
                -- Check quickslot assignment
                local slotIndex = FindActionSlotMatchingItem(itemData.bagId, itemData.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                itemData.isEquippedInCurrentCategory = slotIndex and true or nil
            end

            ZO_InventorySlot_SetType(itemData, SLOT_TYPE_GAMEPAD_INVENTORY_ITEM)
            
            -- Cache expensive API calls for performance
            itemData.cached_itemLink = GetItemLink(itemData.bagId, itemData.slotIndex)
            itemData.cached_itemType = GetItemLinkItemType(itemData.cached_itemLink)
            itemData.cached_setItem = GetItemLinkSetInfo(itemData.cached_itemLink, false)
            itemData.cached_hasEnchantment = GetItemLinkEnchantInfo(itemData.cached_itemLink)
            itemData.cached_isRecipeAndUnknown = (itemData.cached_itemType == ITEMTYPE_RECIPE) and not IsItemLinkRecipeKnown(itemData.cached_itemLink)
            itemData.cached_isBookKnown = IsItemLinkBookKnown(itemData.cached_itemLink)
            itemData.cached_isUnbound = not IsItemBound(itemData.bagId, itemData.slotIndex) and not itemData.stolen and itemData.quality ~= ITEM_QUALITY_TRASH
        end
    end

	local GetItemCooldownInfo = GetItemCooldownInfo
	local GetQuestToolCooldownInfo = GetQuestToolCooldownInfo
	local GetQuestItemCooldownInfo = GetQuestItemCooldownInfo
	local ipairs = ipairs
	local ZO_GamepadEntryData = ZO_GamepadEntryData
	local ZO_InventoryUtils_DoesNewItemMatchFilterType = ZO_InventoryUtils_DoesNewItemMatchFilterType

    -- Apply text search filtering after item/category metadata has been computed so names/categories are accurate.
    -- For consistency with the craft-bag, restrict inventory filtering to item name only so
    -- short queries don't match category/type strings like "(Alchemy)" unintentionally.
    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        local q = tostring(self.searchQuery):lower()
        local matches = {}
        for i = 1, #filteredDataTable do
            local it = filteredDataTable[i]
            local name = tostring(it.name or "")
            local lname = name:lower()
            if string.find(lname, q, 1, true) then
                table.insert(matches, it)
            end
        end
        filteredDataTable = matches
    end

    table.sort(filteredDataTable, BETTERUI_GamepadInventory_DefaultItemSortComparator)

    local currentBestCategoryName

    for i, itemData in ipairs(filteredDataTable) do
        -- Ensure name and icon are available, with fallbacks for missing data
        local itemName = itemData.name
        local itemIcon = itemData.iconFile or itemData.icon
        
        -- Skip invalid items with missing critical data
        if itemName and itemIcon then
            local data = ZO_GamepadEntryData:New(itemName, itemIcon)
			data.InitializeInventoryVisualData = BETTERUI.Inventory.Class.InitializeInventoryVisualData
            data:InitializeInventoryVisualData(itemData)

            local remaining, duration
            if isQuestItem then
                if itemData.toolIndex then
                    remaining, duration = GetQuestToolCooldownInfo(itemData.questIndex, itemData.toolIndex)
                elseif itemData.stepIndex and itemData.conditionIndex then
                    remaining, duration = GetQuestItemCooldownInfo(itemData.questIndex, itemData.stepIndex, itemData.conditionIndex)
                end
            else
                remaining, duration = GetItemCooldownInfo(itemData.bagId, itemData.slotIndex)
            end

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
					if AutoCategory then
						self.itemList:AddEntryWithHeader("BETTERUI_GamepadItemSubEntryTemplate", data)
					else
						self.itemList:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", data)
					end
				else
					self.itemList:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", data)
				end
            end
        end
    end

    self.itemList:Commit()
    self:RefreshCategoryList()
    
end


function BETTERUI.Inventory.Class:LayoutCraftBagTooltip()
    local title
    local description
    if HasCraftBagAccess() then
        title = GetString(SI_ESO_PLUS_STATUS_UNLOCKED)
        description = GetString(SI_CRAFT_BAG_STATUS_ESO_PLUS_UNLOCKED_DESCRIPTION)
    else
        title =  GetString(SI_ESO_PLUS_STATUS_LOCKED)
        description = GetString(SI_CRAFT_BAG_STATUS_LOCKED_DESCRIPTION)
    end

    GAMEPAD_TOOLTIPS:LayoutTitleAndMultiSectionDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP, title, description)
end


function BETTERUI.Inventory.Class:SwitchInfo()
	self.switchInfo = not self.switchInfo
	if self.actionMode == ITEM_LIST_ACTION_MODE then
		self:UpdateItemLeftTooltip(self.itemList.selectedData)
	end
end


function BETTERUI.Inventory.Class:UpdateItemLeftTooltip(selectedData)
    -- Guard: selectedData may be a category/header entry without bag/slot fields.
    -- Avoid calling inventory helper functions on non-item rows which expect item tables.
    if not selectedData or (not selectedData.bagId and not selectedData.questIndex and not selectedData.toolIndex and not selectedData.dataSource) then
        -- Clear tooltips when there's no valid item selected
        if GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(GAMEPAD_RIGHT_TOOLTIP)
        end
        return
    end

    if selectedData then
        GAMEPAD_TOOLTIPS:ResetScrollTooltipToTop(GAMEPAD_RIGHT_TOOLTIP)
        if ZO_InventoryUtils_DoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_QUEST) then
            if selectedData.toolIndex then
                GAMEPAD_TOOLTIPS:LayoutQuestItem(GAMEPAD_LEFT_TOOLTIP, GetQuestToolQuestItemId(selectedData.questIndex, selectedData.toolIndex))
            else
                GAMEPAD_TOOLTIPS:LayoutQuestItem(GAMEPAD_LEFT_TOOLTIP, GetQuestConditionQuestItemId(selectedData.questIndex, selectedData.stepIndex, selectedData.conditionIndex))
            end
        else
        	local showRightTooltip = false
        	if ZO_InventoryUtils_DoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_WEAPONS) or
        		ZO_InventoryUtils_DoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_ARMOR) or
        			ZO_InventoryUtils_DoesNewItemMatchFilterType(selectedData, ITEMFILTERTYPE_JEWELRY) then
        		if self.switchInfo then
        			showRightTooltip = true        			
        		end
		    end

			if not showRightTooltip then
				GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, selectedData.bagId, selectedData.slotIndex)
			else
				if selectedData.bagId ~= nil and selectedData.slotIndex ~= nil then
					self:UpdateRightTooltip(selectedData)
				end
    		end 
        end
        if selectedData.isEquippedInCurrentCategory or selectedData.isEquippedInAnotherCategory or selectedData.equipSlot then
            local slotIndex = selectedData.bagId == BAG_WORN and selectedData.slotIndex or nil --equipped quickslottables slotIndex is not the same as slot index's in BAG_WORN
        	BETTERUI.Inventory.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, slotIndex)
        else
            GAMEPAD_TOOLTIPS:ClearStatusLabel(GAMEPAD_LEFT_TOOLTIP)
        end
    end
end

function BETTERUI.Inventory.Class:UpdateRightTooltip(selectedData)
    local selectedItemData = selectedData
    --
	local selectedEquipSlot

	if self:GetCurrentList() == self.itemList then
		if (selectedItemData ~= nil and selectedItemData.dataSource ~= nil) then
			selectedEquipSlot = BETTERUI_GetEquipSlotForEquipType(selectedItemData.dataSource.equipType)
		end
	else
		selectedEquipSlot = 0
	end

    --

    if selectedItemData ~= nil then
		GAMEPAD_TOOLTIPS:LayoutItemStatComparison(GAMEPAD_LEFT_TOOLTIP, selectedItemData.bagId, selectedItemData.slotIndex, selectedEquipSlot)
		GAMEPAD_TOOLTIPS:SetStatusLabelText(GAMEPAD_LEFT_TOOLTIP, GetString(SI_GAMEPAD_INVENTORY_ITEM_COMPARE_TOOLTIP_TITLE))
    elseif GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, BAG_WORN, selectedEquipSlot) then
    	BETTERUI.Inventory.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, selectedEquipSlot)
    end

	if selectedItemData ~= nil and selectedItemData.dataSource ~= nil and selectedData ~= nil then
		if selectedData.dataSource and selectedItemData.dataSource.equipType == 0 then
			GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
		end
	end
end


function BETTERUI.Inventory.Class:InitializeItemList()
    self.itemList = self:AddList("Items", SetupItemList, BETTERUI_VerticalParametricScrollList)

    self.itemList:SetSortFunction(BETTERUI_GamepadInventory_DefaultItemSortComparator)

    self.itemList:SetOnSelectedDataChangedCallback(function(list, selectedData)
	    if selectedData ~= nil and self.scene:IsShowing() then
		    self.currentlySelectedData = selectedData

		    self:SetSelectedInventoryData(selectedData)
			self:UpdateItemLeftTooltip(selectedData)

			if self.callLaterLeftToolTip ~= nil then
				EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
			end
		
			local callLaterId = zo_callLater(function() self:UpdateItemLeftTooltip(selectedData) end, INVENTORY_LEFT_TOOL_TIP_REFRESH_DELAY_MS)
			self.callLaterLeftToolTip = "CallLaterFunction"..callLaterId
			
        self:PrepareNextClearNewStatus(selectedData)
        self:RefreshKeybinds()
	    end
    end)

    self.itemList.maxOffset = 30
    self.itemList:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * 0.75, GAMEPAD_HEADER_SELECTED_PADDING * 0.75)
	self.itemList:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * 0.75)    

end

function BETTERUI.Inventory.Class:InitializeCraftBagList()
    local function OnSelectedDataCallback(list, selectedData)
	    if selectedData ~= nil and self.scene:IsShowing() then
		    self.currentlySelectedData = selectedData
		    self:UpdateItemLeftTooltip(selectedData)
		
		    --self:SetSelectedInventoryData(selectedData)
		    local currentList = self:GetCurrentList()
		    if currentList == self.craftBagList or ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
			    self:SetSelectedInventoryData(selectedData)
			    self.craftBagList:RefreshVisible()
		    end
		    self:RefreshKeybinds()
	    end
    end

    self.craftBagList = self:AddList("CraftBag", SetupCraftBagList, BETTERUI.Inventory.CraftList, BAG_VIRTUAL, SLOT_TYPE_CRAFT_BAG_ITEM, OnSelectedDataCallback, nil, nil, nil, false, "BETTERUI_GamepadItemSubEntryTemplate")
    self.craftBagList:SetNoItemText(GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_EMPTY))
    self.craftBagList:SetAlignToScreenCenter(true, 30)

	self.craftBagList:SetSortFunction(BETTERUI_CraftList_DefaultItemSortComparator)

end

function BETTERUI.Inventory.Class:InitializeItemActions()
    self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
end

function BETTERUI.Inventory.Class:InitializeActionsDialog()

    local function ActionDialogSetup(dialog, data)
		if self.scene:IsShowing() then 
                -- If invoked for quickslot assignment, render the wheel options inside this proven parametric dialog
                if data and data.quickslotAssign and data.target then
                    -- Title provided via dialog's dynamic title function; avoid overriding here
                    local parametricList = dialog.info.parametricList
                    ZO_ClearNumericallyIndexedTable(parametricList)

                    local target = data.target
                    local hasUnassign = false
                    local assignedIndex = nil
                    if FindActionSlotMatchingItem then
                        assignedIndex = FindActionSlotMatchingItem(target.bagId, target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                        if assignedIndex then
                            hasUnassign = true
                            -- Ensure the Remove row text is visible; icon not required
                            local removeText = GetString(SI_ITEM_ACTION_REMOVE)
                            if not removeText or removeText == "" then removeText = "Remove" end
                            local unassignEntry = ZO_GamepadEntryData:New(removeText)
                            unassignEntry:SetIconTintOnSelection(true)
                            local normalColor = ZO_NORMAL_TEXT or ZO_ColorDef:New(1,1,1,1)
                            local selectedColor = ZO_SELECTED_TEXT or ZO_ColorDef:New(1,1,1,1)
                            if unassignEntry.SetNameColors then
                                unassignEntry:SetNameColors(normalColor, selectedColor)
                            end
                            unassignEntry.isUnassign = true
                            unassignEntry.setup = ZO_SharedGamepadEntry_OnSetup
                            table.insert(parametricList, { template = "ZO_GamepadMenuEntryTemplate", entryData = unassignEntry })
                        end
                    end

                    local function slotLabel(idx)
                        if idx == 4 then return "North"
                        elseif idx == 5 then return "Northwest"
                        elseif idx == 6 then return "West"
                        elseif idx == 7 then return "Southwest"
                        elseif idx == 8 then return "South"
                        elseif idx == 1 then return "Southeast"
                        elseif idx == 2 then return "East"
                        elseif idx == 3 then return "Northeast" end
                        return tostring(idx)
                    end

                    -- Clockwise ordering starting at North: N, NE, E, SE, S, SW, W, NW
                    local orderedSlots = {4, 3, 2, 1, 8, 7, 6, 5}
                    for _, slotIndex in ipairs(orderedSlots) do
                        local icon = GetSlotTexture and GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
                        local lower = type(icon) == "string" and icon:lower() or nil
                        -- Prefer a clearly visible empty-slot texture when the quickslot is unassigned
                        if not icon or icon == "" or (lower and string.find(lower, "quickslot_empty", 1, true)) then
                            -- Use a known-good icon that exists in this UI: the gamepad quickslot category icon
                            icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
                        end
                        local entryData = ZO_GamepadEntryData:New(slotLabel(slotIndex), icon)
                        if entryData.AddIcon and icon then
                            entryData:AddIcon(icon)
                        end
                        -- Flash all non-current slots; keep the currently assigned slot steady
                        local isCurrent = assignedIndex ~= nil and (slotIndex == assignedIndex)
                        local shouldFlash = not isCurrent
                        entryData.alphaChangeOnSelection = shouldFlash
                        entryData.showBarEvenWhenUnselected = shouldFlash
                        entryData:SetIconTintOnSelection(shouldFlash)
                        entryData.slotIndex = slotIndex
                        entryData.setup = ZO_SharedGamepadEntry_OnSetup
                        local templateName = isCurrent and "ZO_GamepadMenuEntryTemplate" or "ZO_GamepadItemEntryTemplate"
                        table.insert(parametricList, { template = templateName, entryData = entryData })
                    end

                    dialog.quickslotTarget = target
                    dialog:setupFunc()
                    if dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                        local offset = hasUnassign and 1 or 0
                        if assignedIndex then
                            -- Map the quickslot index to its position in the ordered list
                            local indexMap = {}
                            for pos, idx in ipairs(orderedSlots) do indexMap[idx] = pos end
                            local listPos = (indexMap[assignedIndex] or 1) + offset
                            dialog.entryList:SetSelectedIndexWithoutAnimation(listPos, true, false)
                        else
                            dialog.entryList:SetSelectedIndexWithoutAnimation(hasUnassign and 2 or 1, true, false)
                        end
                    end
                    return
                end

                -- Default actions list setup
                -- Title provided via dialog's dynamic title function; avoid overriding here
                dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
                    self.itemActions:SetSelectedAction(selectedData and selectedData.action)
                end)

                local function MarkAsJunk()
                    -- Silent junk toggle: skip craft bag and locked errors messaging
                    if self.actionMode == CRAFT_BAG_ACTION_MODE then return end
                    local target = GAMEPAD_INVENTORY.itemList:GetTargetData()
                    if not target then return end
                    if IsItemPlayerLocked(target.bagId, target.slotIndex) then return end
                    -- Close the actions dialog to restore header/keybind focus
                    if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                    end
                    SetItemIsJunk(target.bagId, target.slotIndex, true)
                    -- Refresh immediately to restore UI/keybind state (avoid leaving stale focus)
                    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
                        GAMEPAD_INVENTORY:RefreshItemList()
                    end
                    if self and self.RefreshItemActions then pcall(function() self:RefreshItemActions() end) end
                    if self and self.RefreshKeybinds then pcall(function() self:RefreshKeybinds() end) end
                    -- Ensure the main keybind descriptor becomes active after toggling junk
                    pcall(function()
                        if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
                            pcall(function() self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end)
                            zo_callLater(function()
                                pcall(function() if self.SetActiveKeybinds then self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end end)
                            end, 40)
                        end
                    end)
                end
                -- Note: Lock/unlock callbacks are wrapped later (engine-provided entries are preserved)
                -- so we no longer inject or maintain synthetic lock/unlock helper functions here.
                local function UnmarkAsJunk()
                    local target = GAMEPAD_INVENTORY.itemList:GetTargetData()
                    -- Close the actions dialog to restore header/keybind focus
                    if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                    end
                    SetItemIsJunk(target.bagId, target.slotIndex, false)
                    -- Refresh immediately to restore UI/keybind state (avoid leaving stale focus)
                    if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
                        GAMEPAD_INVENTORY:RefreshItemList()
                    end
                    if self and self.RefreshItemActions then pcall(function() self:RefreshItemActions() end) end
                    if self and self.RefreshKeybinds then pcall(function() self:RefreshKeybinds() end) end
                    -- Ensure the main keybind descriptor becomes active after toggling junk
                    pcall(function()
                        if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
                            pcall(function() self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end)
                            zo_callLater(function()
                                pcall(function() if self.SetActiveKeybinds then self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end end)
                            end, 40)
                        end
                    end)
                end

                local parametricList = dialog.info.parametricList
                ZO_ClearNumericallyIndexedTable(parametricList)

                -- Removed injected "Assign Quickslot" action from Y menu per request

                self:RefreshItemActions()

                do
                    local target = (self.actionMode == ITEM_LIST_ACTION_MODE) and (self.itemList and self.itemList:GetTargetData()) or nil
                    local isLocked = false
                    if target and target.bagId and target.slotIndex then
                        isLocked = IsItemPlayerLocked(target.bagId, target.slotIndex)
                    end
                    if(self.categoryList:GetTargetData().showJunk ~= nil) then
                        -- Unmark should remain available even if locked
                        self.itemActions.slotActions.m_slotActions[#self.itemActions.slotActions.m_slotActions+1] = {GetString(SI_BETTERUI_ACTION_UNMARK_AS_JUNK), UnmarkAsJunk, "secondary"}
                    else
                        -- Hide Mark as Junk when the item is locked
                        if not isLocked then
                            self.itemActions.slotActions.m_slotActions[#self.itemActions.slotActions.m_slotActions+1] = {GetString(SI_BETTERUI_ACTION_MARK_AS_JUNK), MarkAsJunk, "secondary"}
                        end
                    end
                    -- Ensure engine-provided Lock/Unlock callbacks release the dialog first.
                    -- We do this by wrapping the discovered slot action callbacks rather than injecting synthetic entries.
                    -- This preserves the engine entries (so they remain visible) while ensuring the dialog is released
                    -- before the original behavior runs (which fixes header/keybind/tab focus issues).
                    do
                        local actions = self.itemActions:GetSlotActions()
                        local numActions = actions:GetNumSlotActions()
                        for i = 1, numActions do
                            local action = actions:GetSlotAction(i)
                            local actionName = actions:GetRawActionName(action)
                            if actionName == GetString(SI_ITEM_ACTION_MARK_AS_LOCKED) or actionName == GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED) then
                                -- Find the corresponding entry inside the backing m_slotActions table and wrap its callback
                                for j, slotAction in ipairs(actions.m_slotActions) do
                                    if slotAction and slotAction[1] == actionName then
                                        local origCallback = slotAction[2]
                                        slotAction[2] = function(...)
                                            if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                                                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                                            end
                                            -- Call original callback in protected context if it exists
                                            if origCallback then
                                                origCallback(...)
                                            end
                                            -- Immediately refresh item list and actions to restore UI/keybind state
                                            if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
                                                GAMEPAD_INVENTORY:RefreshItemList()
                                            end
                                            if self and self.RefreshItemActions then
                                                pcall(function() self:RefreshItemActions() end)
                                            end
                                            if self and self.RefreshKeybinds then
                                                pcall(function() self:RefreshKeybinds() end)
                                            end
                                            -- Ensure the main keybind descriptor is active after lock/unlock flows
                                            pcall(function()
                                                if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
                                                    pcall(function() self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end)
                                                    zo_callLater(function()
                                                        pcall(function() if self.SetActiveKeybinds then self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end end)
                                                    end, 40)
                                                end
                                            end)
                                        end
                                        -- Only wrap the first matching entry (there should typically be one)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                local actions = self.itemActions:GetSlotActions()
                local numActions = actions:GetNumSlotActions()

                for i = 1, numActions do
                    local action = actions:GetSlotAction(i)
                    local actionName = actions:GetRawActionName(action)

                    -- In banking scenes (standard or house), hide Destroy/Delete entirely
                    local hideDestroy = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing()
                    local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY)) or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
                    -- Hide Mark as Junk for locked items
                    local hideMarkJunk = false
                    do
                        local target = (self.actionMode == ITEM_LIST_ACTION_MODE) and (self.itemList and self.itemList:GetTargetData()) or nil
                        if target and target.bagId and target.slotIndex and actionName == GetString(SI_ITEM_ACTION_MARK_AS_JUNK) then
                            hideMarkJunk = IsItemPlayerLocked(target.bagId, target.slotIndex)
                        end
                    end
                    if not (hideDestroy and isDestroy) and not hideMarkJunk then
                        local entryData = ZO_GamepadEntryData:New(actionName)
                        -- Ensure consistent selection visuals for action rows
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
		if self.scene:IsShowing() then 
			-- make sure to wipe out the keybinds added by 
    		self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
		 
			--restore the selected inventory item
			if self.actionMode == CATEGORY_ITEM_ACTION_MODE then
				--if we refresh item actions we will get a keybind conflict
				local currentList = self:GetCurrentList()
				if currentList then
					local targetData = currentList:GetTargetData()
					if currentList == self.categoryList then
						targetData = self:GenerateItemSlotData(targetData)
					end
					self:SetSelectedItemUniqueId(targetData)
				end
			else
				self:RefreshItemActions()
			end
			--refresh so keybinds react to newly selected item
			self:RefreshKeybinds()

			self:OnUpdate()
			if self.actionMode == CATEGORY_ITEM_ACTION_MODE then
				self:RefreshCategoryList()
			end
		end
	end
	
        local function ActionDialogButtonConfirm(dialog)
		if self.scene:IsShowing() then 
            -- Handle embedded quickslot assignment mode
            if dialog and dialog.data and dialog.data.quickslotAssign and dialog.entryList then
                local target = dialog.data.target or dialog.quickslotTarget
                if target then
                    local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                    local selected = dialog.entryList:GetTargetData()
                    if selected and selected.isUnassign then
                        local assigned = FindActionSlotMatchingItem and FindActionSlotMatchingItem(target.bagId, target.slotIndex, quickslot_wheel)
                        if assigned then
                            CallSecureProtected('ClearSlot', assigned, quickslot_wheel)
                            if SOUNDS and PlaySound then PlaySound(SOUNDS.GAMEPAD_MENU_BACK) end
                        end
                    else
                        local wheelSlotIndex = (selected and selected.slotIndex) or 4
                        CallSecureProtected('SelectSlotItem', target.bagId, target.slotIndex, wheelSlotIndex, quickslot_wheel)
                        if SOUNDS and PlaySound then PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD) end
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                    zo_callLater(function() if GAMEPAD_INVENTORY then GAMEPAD_INVENTORY:RefreshItemList() end end, 150)
                end
                return
            end

            -- Removed legacy custom quickslot picker entry handling
            -- Check for BetterUI synthetic Destroy entry first
            local selectedRow = dialog.entryList and dialog.entryList:GetTargetData()
            if selectedRow and selectedRow.isBetterUIDestroy then
                local targetData
                local actionMode = self.actionMode
                if actionMode == ITEM_LIST_ACTION_MODE then
                    targetData = self.itemList:GetTargetData()
                elseif actionMode == CRAFT_BAG_ACTION_MODE then
                    targetData = self.craftBagList:GetTargetData()
                else 
                    targetData = self:GenerateItemSlotData(self.categoryList:GetTargetData())
                end
                local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                if bag and slot then
                    ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                    local link = GetItemLink(bag, slot)
                    ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG", { bagId = bag, slotIndex = slot, itemLink = link }, nil, true, true)
                end
                return
            end

            local selectedActionName = ZO_InventorySlotActions:GetRawActionName(self.itemActions.selectedAction)
            -- Intercept engine Destroy/Delete here to show our confirm dialog
            if (selectedActionName == GetString(SI_ITEM_ACTION_DESTROY)) or (SI_ITEM_ACTION_DELETE and selectedActionName == GetString(SI_ITEM_ACTION_DELETE)) then
                local targetData
                local actionMode = self.actionMode
                if actionMode == ITEM_LIST_ACTION_MODE then
                    targetData = self.itemList:GetTargetData()
                elseif actionMode == CRAFT_BAG_ACTION_MODE then
                    targetData = self.craftBagList:GetTargetData()
                else
                    targetData = self:GenerateItemSlotData(self.categoryList:GetTargetData())
                end
                local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                if bag and slot then
                    ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                    local link = GetItemLink(bag, slot)
                    -- Quick destroy: if enabled, bypass confirmation and junk gating
                    local quick = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Inventory"] and BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
                    if quick then
                        BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
                    else
                        ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG", { bagId = bag, slotIndex = slot, itemLink = link }, nil, true, true)
                    end
                end
                return
            end
            if (selectedActionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT)) then
				local targetData
			    local actionMode = self.actionMode
			    if actionMode == ITEM_LIST_ACTION_MODE then
			        targetData = self.itemList:GetTargetData()
			    elseif actionMode == CRAFT_BAG_ACTION_MODE then
			        targetData = self.craftBagList:GetTargetData()
			    else 
			        targetData = self:GenerateItemSlotData(self.categoryList:GetTargetData())
			    end
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

-- Quickslot assignment dialog allowing the user to choose a wheel slot (1..8)
function BETTERUI.Inventory.Class:InitializeQuickslotAssignDialog()
    local SLOT_LABELS = {
        [1] = "Southeast",
        [2] = "East",
        [3] = "Northeast",
        [4] = "North",
        [5] = "Northwest",
        [6] = "West",
        [7] = "Southwest",
        [8] = "South",
    }

    ZO_Dialogs_RegisterCustomDialog("BETTERUI_QUICKSLOT_ASSIGN_DIALOG",
    {
        blockDirectionalInput = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            allowRightStickPassThrough = true,
        },
        title = {
            text = function(dialog)
                return GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN)
            end,
        },
        setup = function(dialog, data)
            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            -- If this item is currently assigned, add an Unassign action as the first row (avoids needing a tertiary button)
            local hasUnassign = false
            local assignedIndexForUnassign = nil
            if data and data.target and FindActionSlotMatchingItem then
                assignedIndexForUnassign = FindActionSlotMatchingItem(data.target.bagId, data.target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                if assignedIndexForUnassign then
                    hasUnassign = true
                    local entryData = ZO_GamepadEntryData:New(GetString(SI_ITEM_ACTION_REMOVE))
                    entryData:SetIconTintOnSelection(true)
                    entryData.isUnassign = true
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup
                    table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
                end
            end

            for slotIndex = 1, 8 do
                local icon
                if GetSlotTexture then
                    icon = GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                end
                if not icon or icon == "" then
                    icon = "/esoui/art/quickslots/quickslot_empty.dds"
                end

                local entryData = ZO_GamepadEntryData:New(SLOT_LABELS[slotIndex] or tostring(slotIndex), icon)
                entryData:SetIconTintOnSelection(true)
                entryData.slotIndex = slotIndex
                entryData.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, { template = "ZO_GamepadItemEntryTemplate", entryData = entryData })
            end

            dialog:setupFunc()
            -- Preselect currently assigned slot index if this item is already on the wheel
            if data and data.target and FindActionSlotMatchingItem then
                local assignedIndex = FindActionSlotMatchingItem(data.target.bagId, data.target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                if assignedIndex and dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                    local offset = hasUnassign and 1 or 0
                    dialog.entryList:SetSelectedIndexWithoutAnimation(math.max(1, math.min(8 + offset, assignedIndex + offset)), true, false)
                elseif dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                    dialog.entryList:SetSelectedIndexWithoutAnimation(hasUnassign and 2 or 1, true, false)
                end
            end
        end,
        mainText = {
            text = function(dialog)
                if dialog and dialog.data and dialog.data.target then
                    local t = dialog.data.target
                    local name = GetItemName(t.bagId, t.slotIndex)
                    if name and name ~= "" then
                        return zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                    end
                end
                return GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN)
            end,
        },
        parametricList = {},
        buttons = {
            { keybind = "DIALOG_NEGATIVE", text = GetString(SI_DIALOG_CANCEL) },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    local target = dialog.data and dialog.data.target
                    if target and target.bagId and target.slotIndex then
                        local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                        local selected = dialog.entryList and dialog.entryList.GetTargetData and dialog.entryList:GetTargetData()
                        if selected and selected.isUnassign then
                            local assigned = FindActionSlotMatchingItem(target.bagId, target.slotIndex, quickslot_wheel)
                            if assigned then
                                CallSecureProtected('ClearSlot', assigned, quickslot_wheel)
                                if SOUNDS and PlaySound then PlaySound(SOUNDS.GAMEPAD_MENU_BACK) end
                            end
                        else
                            local wheelSlotIndex = selected and selected.slotIndex or 4 -- fallback to North (4)
                            CallSecureProtected('SelectSlotItem', target.bagId, target.slotIndex, wheelSlotIndex, quickslot_wheel)
                            if SOUNDS and PlaySound then PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD) end
                        end
                        ZO_Dialogs_ReleaseDialogOnButtonPress('BETTERUI_QUICKSLOT_ASSIGN_DIALOG')
                        zo_callLater(function() if GAMEPAD_INVENTORY then GAMEPAD_INVENTORY:RefreshItemList() end end, 150)
                    end
                end,
            },
        },
    })
end

function BETTERUI.Inventory.Class:ShowQuickslotAssignDialog(bagId, slotIndex)
    -- Open the standard Actions dialog in embedded quickslot mode (matches the Y-button prompt UX)
    local data = { quickslotAssign = true, target = { bagId = bagId, slotIndex = slotIndex } }
    if ZO_Dialogs_IsShowing(BETTERUI_EQUIP_SLOT_DIALOG) then
        ZO_Dialogs_ReleaseDialog(BETTERUI_EQUIP_SLOT_DIALOG)
    end
    zo_callLater(function()
        ZO_Dialogs_ShowDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, data, nil, true, true)
        -- As a fallback, if the embedded dialog still doesn't appear, show our custom parametric dialog
        zo_callLater(function()
            if not ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                ZO_Dialogs_ShowDialog("BETTERUI_QUICKSLOT_ASSIGN_DIALOG", { target = { bagId = bagId, slotIndex = slotIndex } }, nil, true, true)
            end
        end, 220)
    end, 120)
end

-- If force is true, skip Junk gating (used by BetterUI confirmation)
-- Returns true if an item was destroyed, false otherwise (no messaging)
function BETTERUI.Inventory.TryDestroyItem(bagId, slotIndex, force)
    if not bagId or not slotIndex then return false end
    -- Allow destruction if explicitly confirmed or the item is junk
    if force or IsItemJunk(bagId, slotIndex) then
        -- Direct engine destroy path (matches the original working hook behavior)
        SetCursorItemSoundsEnabled(false)
        DestroyItem(bagId, slotIndex)
        -- Proactively refresh inventory caches to reflect removal
        if SHARED_INVENTORY and SHARED_INVENTORY.PerformFullUpdateOnBagCache then
            pcall(function() SHARED_INVENTORY:PerformFullUpdateOnBagCache(bagId) end)
        end
        -- UI refreshes (safe if scene present)
        zo_callLater(function()
            if GAMEPAD_INVENTORY then
                if GAMEPAD_INVENTORY.RefreshItemList then GAMEPAD_INVENTORY:RefreshItemList() end
                if GAMEPAD_INVENTORY.RefreshCategoryList then GAMEPAD_INVENTORY:RefreshCategoryList() end
                if GAMEPAD_INVENTORY.RefreshHeader then GAMEPAD_INVENTORY:RefreshHeader(BLOCK_TABBAR_CALLBACK) end
            end
        end, 80)
        return true
    end
    return false
end

-- Re-implement hook to bypass engine path that uses private PickupInventoryItem
function BETTERUI.Inventory.HookDestroyItem()
    ZO_InventorySlot_InitiateDestroyItem = function(inventorySlot)
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        local force = false
        if BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Inventory"] then
            force = BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
        end
        return BETTERUI.Inventory.TryDestroyItem(bag, index, force)
    end
end

function BETTERUI.Inventory.HookActionDialog()
	local function ActionsDialogSetup(dialog, data)
        dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
                                                                data.itemActions:SetSelectedAction(selectedData and selectedData.action)
                                                            end)
        local parametricList = dialog.info.parametricList
        ZO_ClearNumericallyIndexedTable(parametricList)

        dialog.itemActions = data.itemActions
        local actions = data.itemActions:GetSlotActions()
        local numActions = actions:GetNumSlotActions()

        for i = 1, numActions do
            local action = actions:GetSlotAction(i)
            local actionName = actions:GetRawActionName(action)

            local entryData = ZO_GamepadEntryData:New(actionName)
            entryData:SetIconTintOnSelection(true)
            entryData.setup = ZO_SharedGamepadEntry_OnSetup
            -- Intercept Destroy/Delete to route through BetterUI confirm dialog
            local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY)) or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
            local inBankScene = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing()
            if not (isDestroy and inBankScene) then
                if isDestroy then
                    entryData.isBetterUIDestroy = true
                    entryData.action = nil -- prevent engine destroy from being selected/executed
                else
                    entryData.action = action
                end

                local listItem =
                {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = entryData,
                }
                table.insert(parametricList, listItem)
            end
        end

        dialog.finishedCallback = data.finishedCallback

        dialog:setupFunc()
    end

    ZO_Dialogs_RegisterCustomDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG,
    {
        blockDirectionalInput = true,
        canQueue = true,
        setup = function(dialog, data) 
            -- Always handle our embedded quickslot mode here for robustness
            if data and data.quickslotAssign and data.target then
                -- Title provided via dialog's dynamic title function; avoid overriding here
                local parametricList = dialog.info.parametricList
                ZO_ClearNumericallyIndexedTable(parametricList)

                local target = data.target
                local hasUnassign = false
                local assignedIndex = nil
                if FindActionSlotMatchingItem then
                    assignedIndex = FindActionSlotMatchingItem(target.bagId, target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                    if assignedIndex then
                        hasUnassign = true
                        local removeText = GetString(SI_ITEM_ACTION_REMOVE)
                        if not removeText or removeText == "" then removeText = "Remove" end
                        local unassignEntry = ZO_GamepadEntryData:New(removeText)
                        unassignEntry:SetIconTintOnSelection(true)
                        -- Ensure text is visible on dark background
                        local normalColor = ZO_NORMAL_TEXT or ZO_ColorDef:New(1,1,1,1)
                        local selectedColor = ZO_SELECTED_TEXT or ZO_ColorDef:New(1,1,1,1)
                        if unassignEntry.SetNameColors then
                            unassignEntry:SetNameColors(normalColor, selectedColor)
                        end
                        unassignEntry.isUnassign = true
                        unassignEntry.setup = ZO_SharedGamepadEntry_OnSetup
                        table.insert(parametricList, { template = "ZO_GamepadMenuEntryTemplate", entryData = unassignEntry })
                    end
                end

                local function slotLabel(idx)
                    if idx == 4 then return "North"
                    elseif idx == 5 then return "Northwest"
                    elseif idx == 6 then return "West"
                    elseif idx == 7 then return "Southwest"
                    elseif idx == 8 then return "South"
                    elseif idx == 1 then return "Southeast"
                    elseif idx == 2 then return "East"
                    elseif idx == 3 then return "Northeast" end
                    return tostring(idx)
                end

                -- Clockwise ordering starting at North: N, NE, E, SE, S, SW, W, NW
                local orderedSlots = {4, 3, 2, 1, 8, 7, 6, 5}
                for _, slotIndex in ipairs(orderedSlots) do
                    local icon = GetSlotTexture and GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
                    local lower = type(icon) == "string" and icon:lower() or nil
                    if not icon or icon == "" or (lower and string.find(lower, "quickslot_empty", 1, true)) then
                        icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
                    end
                    local entryData = ZO_GamepadEntryData:New(slotLabel(slotIndex), icon)
                    if entryData.AddIcon and icon then
                        entryData:AddIcon(icon)
                    end
                    -- Flash all non-current slots; keep the currently assigned slot steady
                    local isCurrent = assignedIndex ~= nil and (slotIndex == assignedIndex)
                    local shouldFlash = not isCurrent
                    entryData.alphaChangeOnSelection = shouldFlash
                    entryData.showBarEvenWhenUnselected = shouldFlash
                    entryData:SetIconTintOnSelection(shouldFlash)
                    entryData.slotIndex = slotIndex
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup
                    local templateName = isCurrent and "ZO_GamepadMenuEntryTemplate" or "ZO_GamepadItemEntryTemplate"
                    table.insert(parametricList, { template = templateName, entryData = entryData })
                end

                dialog.quickslotTarget = target
                dialog:setupFunc()
                if dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                    local offset = hasUnassign and 1 or 0
                    if assignedIndex then
                        local indexMap = {}
                        for pos, idx in ipairs(orderedSlots) do indexMap[idx] = pos end
                        local listPos = (indexMap[assignedIndex] or 1) + offset
                        dialog.entryList:SetSelectedIndexWithoutAnimation(listPos, true, false)
                    else
                        dialog.entryList:SetSelectedIndexWithoutAnimation(hasUnassign and 2 or 1, true, false)
                    end
                end
                return
            end

            -- Normal BetterUI override path when enabled/visible
            -- Title provided via dialog's dynamic title function; avoid overriding here
            if (BETTERUI.Settings.Modules["Inventory"].m_enabled and SCENE_MANAGER.scenes['gamepad_inventory_root']:IsShowing() ) or
               (BETTERUI.Settings.Modules["Banking"].m_enabled and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() ) then
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_SETUP", dialog, data)
                return
            end
            -- Original function
            ActionsDialogSetup(dialog, data) 
        end,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title =
        {
            text = function(dialog)
                if dialog and dialog.data and dialog.data.quickslotAssign then
                    return "Assign Quickslots"
                end
                return GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND)
            end,
        },
        parametricList = {}, --we'll generate the entries on setup
        finishedCallback =  function(dialog)
            if (BETTERUI.Settings.Modules["Inventory"].m_enabled and SCENE_MANAGER.scenes['gamepad_inventory_root']:IsShowing() ) or
               (BETTERUI.Settings.Modules["Banking"].m_enabled and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() ) then
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_FINISH", dialog)
                return
            end
            --original function
            dialog.itemActions = nil
            if dialog.finishedCallback then
                dialog.finishedCallback()
            end
            dialog.finishedCallback = nil
        end,

        buttons =
        {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)  
                    -- Handle embedded quickslot mode regardless of BetterUI override gating
                    if dialog and dialog.data and dialog.data.quickslotAssign and dialog.entryList then
                        local target = dialog.data.target or dialog.quickslotTarget
                        if target then
                            local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                            local selected = dialog.entryList:GetTargetData()
                            if selected and selected.isUnassign then
                                local assigned = FindActionSlotMatchingItem and FindActionSlotMatchingItem(target.bagId, target.slotIndex, quickslot_wheel)
                                if assigned then
                                    CallSecureProtected('ClearSlot', assigned, quickslot_wheel)
                                    if SOUNDS and PlaySound then PlaySound(SOUNDS.GAMEPAD_MENU_BACK) end
                                end
                            else
                                local wheelSlotIndex = (selected and selected.slotIndex) or 4
                                CallSecureProtected('SelectSlotItem', target.bagId, target.slotIndex, wheelSlotIndex, quickslot_wheel)
                                if SOUNDS and PlaySound then PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD) end
                            end
                            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                            zo_callLater(function() if GAMEPAD_INVENTORY then GAMEPAD_INVENTORY:RefreshItemList() end end, 150)
                        end
                        return
                    end
                    if (BETTERUI.Settings.Modules["Inventory"].m_enabled and SCENE_MANAGER.scenes['gamepad_inventory_root']:IsShowing() ) or
                       (BETTERUI.Settings.Modules["Banking"].m_enabled and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() ) then
                        CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", dialog)
                        return
                    end
                    -- Handle BetterUI synthetic Destroy and Link to Chat explicitly even outside BetterUI override
                    if ZO_InventorySlotActions and self and self.itemActions and self.itemActions.selectedAction then
                        -- Check if the selected row is a BetterUI Destroy entry
                        local selectedRow = dialog.entryList and dialog.entryList:GetTargetData()
                        if selectedRow and selectedRow.isBetterUIDestroy then
                            local targetData
                            local actionMode = self.actionMode
                            if actionMode == ITEM_LIST_ACTION_MODE then
                                targetData = self.itemList:GetTargetData()
                            elseif actionMode == CRAFT_BAG_ACTION_MODE then
                                targetData = self.craftBagList:GetTargetData()
                            else 
                                targetData = self:GenerateItemSlotData(self.categoryList:GetTargetData())
                            end
                            local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                            if bag and slot then
                                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                                local itemLink = GetItemLink(bag, slot)
                                local quick = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Inventory"] and BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
                                if quick then
                                    BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
                                else
                                    ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG", { bagId = bag, slotIndex = slot, itemLink = itemLink }, nil, true, true)
                                end
                            end
                            return
                        end
                        local selectedActionName = ZO_InventorySlotActions:GetRawActionName(self.itemActions.selectedAction)
                        if selectedActionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
                            local targetData
                            local actionMode = self.actionMode
                            if actionMode == ITEM_LIST_ACTION_MODE then
                                targetData = self.itemList:GetTargetData()
                            elseif actionMode == CRAFT_BAG_ACTION_MODE then
                                targetData = self.craftBagList:GetTargetData()
                            else 
                                targetData = self:GenerateItemSlotData(self.categoryList:GetTargetData())
                            end
                            local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                            if bag and slot then
                                local itemLink = GetItemLink(bag, slot)
                                if itemLink then
                                    ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
                                end
                            end
                            return
                        end
                    end
                    --original function
                    dialog.itemActions:DoSelectedAction()
                end,
            },
        },
    })

end

-- override of ZO_Gamepad_ParametricList_Screen:OnStateChanged
function BETTERUI.Inventory.Class:OnStateChanged(oldState, newState)
    if newState == SCENE_SHOWING then
        self:PerformDeferredInitialize()
        BETTERUI.CIM.SetTooltipWidth(BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH)
        
        --figure out which list to land on
        local listToActivate = self.previousListType or INVENTORY_CATEGORY_LIST
        -- We normally do not want to enter the gamepad inventory on the item list
        -- the exception is if we are coming back to the inventory, like from looting a container
        if listToActivate == INVENTORY_ITEM_LIST and not SCENE_MANAGER:WasSceneOnStack(ZO_GAMEPAD_INVENTORY_SCENE_NAME) then
            listToActivate = INVENTORY_CATEGORY_LIST
        end

        -- switching the active list will handle activating/refreshing header, keybinds, etc.
        self:SwitchActiveList(listToActivate)

        self:ActivateHeader()

        if wykkydsToolbar then
            wykkydsToolbar:SetHidden(true)
        end

        ZO_InventorySlot_SetUpdateCallback(function() self:RefreshItemActions() end)
        -- search is handled via hold callbacks on X/Y; no separate A-based keybind group required
    elseif newState == SCENE_HIDING then
        ZO_InventorySlot_SetUpdateCallback(nil)
        self:Deactivate()
        self:DeactivateHeader()

        if wykkydsToolbar then
            wykkydsToolbar:SetHidden(false)
		end

        if self.callLaterLeftToolTip ~= nil then
            EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
            self.callLaterLeftToolTip = nil
        end
        -- search hold behavior is part of main keybind descriptors; nothing to remove here
    elseif newState == SCENE_HIDDEN then
        self:SwitchActiveList(nil)
        BETTERUI.CIM.SetTooltipWidth(BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH)

        self.listWaitingOnDestroyRequest = nil
        self:TryClearNewStatusOnHidden()

        self:ClearActiveKeybinds()
        ZO_SavePlayerConsoleProfile()

        if wykkydsToolbar then
            wykkydsToolbar:SetHidden(false)
		end

		if self.callLaterLeftToolTip ~= nil then
			EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
			self.callLaterLeftToolTip = nil
		end
        -- Clear persistent search when leaving the inventory scene so it does
        -- not persist when the player backs out and later re-enters the scene.
        -- Use centralized helper to clear persistent search state when leaving scene
        if self.ClearTextSearch then
            self:ClearTextSearch()
        end
        -- nothing to remove for search hold behavior here
    end
end

function BETTERUI.Inventory.Class:InitializeEquipSlotDialog()
    local dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.BASIC)
     
    local function ReleaseDialog(data, mainSlot)
        local equipType = data[1].dataSource.equipType
	
		local bound = IsItemBound(data[1].dataSource.bagId, data[1].dataSource.slotIndex)
		local equipItemLink = GetItemLink(data[1].dataSource.bagId, data[1].dataSource.slotIndex)
		local bindType = GetItemLinkBindType(equipItemLink)
	
		local equipItemCallback = function()
			if equipType == EQUIP_TYPE_ONE_HAND then
				if(mainSlot) then
					CallSecureProtected("RequestMoveItem",data[1].dataSource.bagId, data[1].dataSource.slotIndex, BAG_WORN, data[2] and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN, 1)
				else
					CallSecureProtected("RequestMoveItem",data[1].dataSource.bagId, data[1].dataSource.slotIndex, BAG_WORN, data[2] and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF, 1)
				end
			elseif equipType == EQUIP_TYPE_MAIN_HAND or 
			       equipType == EQUIP_TYPE_TWO_HAND then
				CallSecureProtected("RequestMoveItem",data[1].dataSource.bagId, data[1].dataSource.slotIndex, BAG_WORN, data[2] and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN, 1)
			elseif equipType == EQUIP_TYPE_OFF_HAND then
				CallSecureProtected("RequestMoveItem",data[1].dataSource.bagId, data[1].dataSource.slotIndex, BAG_WORN, data[2] and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF, 1)
			elseif equipType == EQUIP_TYPE_POISON then
				CallSecureProtected("RequestMoveItem",data[1].dataSource.bagId, data[1].dataSource.slotIndex, BAG_WORN, data[2] and EQUIP_SLOT_POISON or EQUIP_SLOT_BACKUP_POISON, 1)
			elseif equipType == EQUIP_TYPE_RING then
				if(mainSlot) then
					CallSecureProtected("RequestMoveItem",data[1].dataSource.bagId, data[1].dataSource.slotIndex, BAG_WORN, EQUIP_SLOT_RING1, 1)
				else
					CallSecureProtected("RequestMoveItem",data[1].dataSource.bagId, data[1].dataSource.slotIndex, BAG_WORN, EQUIP_SLOT_RING2, 1)
				end
			end
		end
	
		ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_EQUIP_SLOT_DIALOG)
	
		if not bound and bindType == BIND_TYPE_ON_EQUIP and BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection then
			zo_callLater(function() ZO_Dialogs_ShowPlatformDialog("CONFIRM_EQUIP_BOE", {callback=equipItemCallback}, {mainTextParams={equipItemLink}}) end, DIALOG_QUEUE_WORKAROUND_TIMEOUT_DURATION)
		else
			equipItemCallback()
		end
    end
    local function GetDialogSwitchButtonText(isPrimary)
        return GetString(SI_BETTERUI_INV_SWITCH_EQUIPSLOT)
    end

    local function GetDialogMainText(dialog) 
		local equipType = dialog.data[1].dataSource.equipType
		local itemName = GetItemName(dialog.data[1].dataSource.bagId, dialog.data[1].dataSource.slotIndex)
		local itemLink = GetItemLink(dialog.data[1].dataSource.bagId, dialog.data[1].dataSource.slotIndex)
		local itemQuality = GetItemLinkFunctionalQuality(itemLink)
		local itemColor = GetItemQualityColor(itemQuality)
		itemName = itemColor:Colorize(itemName)
	        local str = ""
		local weaponChoice = GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN)
		if not dialog.data[2] then
			weaponChoice = GetString(SI_BETTERUI_INV_EQUIPSLOT_BACKUP)
		end
		if equipType == EQUIP_TYPE_ONE_HAND then
			--choose Main/Off hand, Primary/Secondary weapon
			str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_ONE_HAND_WEAPON), itemName, weaponChoice ) 
		elseif equipType == EQUIP_TYPE_MAIN_HAND or
			equipType == EQUIP_TYPE_OFF_HAND or
			equipType == EQUIP_TYPE_TWO_HAND or
			equipType == EQUIP_TYPE_POISON then
			--choose Primary/Secondary weapon
			str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_OTHER_WEAPON), itemName, weaponChoice ) 
		elseif equipType == EQUIP_TYPE_RING then
			--choose which rint slot          
			str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_RING), itemName) 
		end 
		return str
	end

    ZO_Dialogs_RegisterCustomDialog(BETTERUI_EQUIP_SLOT_DIALOG,
    {
        blockDialogReleaseOnPress = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
            allowRightStickPassThrough = true,
        },
        setup = function()
            dialog.setupFunc(dialog)
        end,
        title =
        {
            text = GetString(SI_BETTERUI_INV_EQUIPSLOT_TITLE),
        },
        mainText =
        {
            text = function(dialog) 
            	return GetDialogMainText(dialog)
            end,
        },
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = function(dialog)
                	local equipType = dialog.data[1].dataSource.equipType
			    	if equipType == EQUIP_TYPE_ONE_HAND then
			    		--choose Main/Off hand, Primary/Secondary weapon
			    		return GetString(SI_BETTERUI_INV_EQUIP_PROMPT_MAIN)
			    	elseif equipType == EQUIP_TYPE_MAIN_HAND or
			    		equipType == EQUIP_TYPE_OFF_HAND or
			    		equipType == EQUIP_TYPE_TWO_HAND or
			    		equipType == EQUIP_TYPE_POISON then
			    		--choose Primary/Secondary weapon
			    		return GetString(SI_BETTERUI_INV_EQUIP)
			    	elseif equipType == EQUIP_TYPE_RING then
			    		--choose which ring slot
			    		return GetString(SI_BETTERUI_INV_FIRST_SLOT)
			    	end 
			    	return ""
                end,
                callback = function()
                    ReleaseDialog(dialog.data, true)
                end,
            },
            {
                keybind = "DIALOG_SECONDARY",
				text = function(dialog)
                	local equipType = dialog.data[1].dataSource.equipType
					if equipType == EQUIP_TYPE_ONE_HAND then
						--choose Main/Off hand, Primary/Secondary weapon
						return GetString(SI_BETTERUI_INV_EQUIP_PROMPT_BACKUP)
					elseif equipType == EQUIP_TYPE_MAIN_HAND or
						equipType == EQUIP_TYPE_OFF_HAND or
						equipType == EQUIP_TYPE_TWO_HAND or
						equipType == EQUIP_TYPE_POISON then
						--choose Primary/Secondary weapon
						return ""
					elseif equipType == EQUIP_TYPE_RING then
						--choose which rint slot
						return GetString(SI_BETTERUI_INV_SECOND_SLOT)
					end 
	                return ""
	            end,
	            visible = function(dialog)
                	local equipType = dialog.data[1].dataSource.equipType
					if equipType == EQUIP_TYPE_ONE_HAND or
						equipType == EQUIP_TYPE_RING then
							return true
					end
					return false
	            end,
                callback = function(dialog)
                    ReleaseDialog(dialog.data, false)
                end,
            },
            {
                keybind = "DIALOG_TERTIARY",
                text = function(dialog)
                	return GetDialogSwitchButtonText(dialog.data[2])
               	end,
	            visible = function(dialog)
                	local equipType = dialog.data[1].dataSource.equipType
	            	return equipType ~= EQUIP_TYPE_RING				
	            end,
                callback = function(dialog)
                	--switch weapon
                	dialog.data[2] = not dialog.data[2]

                	--update inventory window's header
                	GAMEPAD_INVENTORY.isPrimaryWeapon = dialog.data[2]
                	
                	GAMEPAD_INVENTORY:RefreshHeader()

                	--update dialog
                    ZO_GenericGamepadDialog_RefreshText(dialog, dialog.headerData.titleText, GetDialogMainText(dialog), warningText)
                	ZO_GenericGamepadDialog_RefreshKeybinds(dialog)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
				alignment = KEYBIND_STRIP_ALIGN_RIGHT,
                text = SI_DIALOG_CANCEL,
                callback = function()
					ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_EQUIP_SLOT_DIALOG)
                end,
            },
        }
    })
end

function BETTERUI.Inventory.Class:OnUpdate(currentFrameTimeSeconds)
	--if no currentFrameTimeSeconds a manual update was called from outside the update loop.
	if not currentFrameTimeSeconds or (self.nextUpdateTimeSeconds and (currentFrameTimeSeconds >= self.nextUpdateTimeSeconds)) then
	    self.nextUpdateTimeSeconds = nil

	    if self.actionMode == ITEM_LIST_ACTION_MODE then
	        self:RefreshItemList()
	        -- it's possible we removed the last item from this list
	        -- so we want to switch back to the category list
	        if self.itemList:IsEmpty() then
	            self:SwitchActiveList(INVENTORY_CATEGORY_LIST)
	        else
	            -- don't refresh item actions if we are switching back to the category view
	            -- otherwise we get keybindstrip errors (Item actions will try to add an "A" keybind
	            -- and we already have an "A" keybind)
	            
	            self:RefreshItemActions()
	        end
	    elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
	        self:RefreshCraftBagList()
	        self:RefreshItemActions()
	    else -- CATEGORY_ITEM_ACTION_MODE
	        self:UpdateCategoryLeftTooltip(self.categoryList:GetTargetData())
	    end
	end
end

function BETTERUI.Inventory.Class:OnDeferredInitialize()
    local SAVED_VAR_DEFAULTS =
    {
        useStatComparisonTooltip = true,
    }
    self.savedVars = ZO_SavedVars:NewAccountWide("ZO_Ingame_SavedVariables", 2, "GamepadInventory", SAVED_VAR_DEFAULTS)
    self.switchInfo = false

    self:SetListsUseTriggerKeybinds(true)

    self.categoryPositions = {}
	self.categoryCraftPositions = {}
    self.populatedCategoryPos = false
	self.populatedCraftPos = false
    self.isPrimaryWeapon = true

    self:InitializeCategoryList()
    self:InitializeHeader()
    self:InitializeCraftBagList()

	self:InitializeItemList()

    self:InitializeKeybindStrip()

    self:InitializeConfirmDestroyDialog()
	self:InitializeEquipSlotDialog()

    self:InitializeItemActions()
    self:InitializeActionsDialog()
    self:InitializeQuickslotAssignDialog()

    local function RefreshHeader()
        if not self.control:IsHidden() then
            self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
        end
    end

    local function RefreshSelectedData()
        if not self.control:IsHidden() then
            self:SetSelectedInventoryData(self.currentlySelectedData)
        end
    end

    self:RefreshCategoryList()

    self:SetSelectedItemUniqueId(self:GenerateItemSlotData(self.categoryList:GetTargetData()))
    self:RefreshHeader()
    self:ActivateHeader()

    self.control:RegisterForEvent(EVENT_MONEY_UPDATE, RefreshHeader)
    self.control:RegisterForEvent(EVENT_ALLIANCE_POINT_UPDATE, RefreshHeader)
    self.control:RegisterForEvent(EVENT_TELVAR_STONE_UPDATE, RefreshHeader)
    if EVENT_CURRENCY_UPDATE then
        self.control:RegisterForEvent(EVENT_CURRENCY_UPDATE, RefreshHeader)
    end
    self.control:RegisterForEvent(EVENT_PLAYER_DEAD, RefreshSelectedData)
    self.control:RegisterForEvent(EVENT_PLAYER_REINCARNATED, RefreshSelectedData)

     local function OnInventoryUpdated(bagId)
        self:MarkDirty()
        -- Debounce heavy updates to the next frame to batch rapid changes
        if GetFrameTimeSeconds then
            self.nextUpdateTimeSeconds = GetFrameTimeSeconds() + 0.05
        else
            self.nextUpdateTimeSeconds = nil
        end

        local currentList = self:GetCurrentList()
        if self.scene:IsShowing() then
            -- If an action dialog is open, keep the immediate update for correctness
            if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                self:OnUpdate() -- immediate to keep dialog/keybinds consistent
            else
                if currentList == self.itemList then
                    self:RefreshKeybinds()
                end
                RefreshSelectedData()
                self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
                -- Coalesce a category refresh so new tabs (Junk/Stolen) appear promptly
                if not self._pendingCategoryListRefresh then
                    self._pendingCategoryListRefresh = true
                    zo_callLater(function()
                        self._pendingCategoryListRefresh = false
                        if self.scene:IsShowing() then
                            self:RefreshCategoryList()
                        end
                    end, 80)
                end
            end
        end
    end

    SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", OnInventoryUpdated)
    SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", OnInventoryUpdated)

    SHARED_INVENTORY:RegisterCallback("FullQuestUpdate", OnInventoryUpdated)
    SHARED_INVENTORY:RegisterCallback("SingleQuestUpdate", OnInventoryUpdated)

end

    -- Ensure keybinds (including the Clear Search prompt) are updated once
    -- deferred initialization finishes. Some UI elements become visible only
    -- after a short delay; refreshing keybinds here prevents the Clear Search
    -- button from not appearing until the player scrolls the list.
    zo_callLater(function()
        pcall(function()
            if self.RefreshKeybinds then
                self:RefreshKeybinds()
            elseif self.mainKeybindStripDescriptor then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
                -- Ensure the main group is active on initial load to prevent missing shoulder navigation.
                pcall(function() if self.SetActiveKeybinds then self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end end)
                zo_callLater(function()
                    pcall(function() if self.SetActiveKeybinds then self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end end)
                end, 40)
            end
        end)
    end, 60)

function BETTERUI.Inventory.Class:Initialize(control)
    GAMEPAD_INVENTORY_ROOT_SCENE = ZO_Scene:New(ZO_GAMEPAD_INVENTORY_SCENE_NAME, SCENE_MANAGER)
    BETTERUI_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_CREATE, false, GAMEPAD_INVENTORY_ROOT_SCENE)

    self:InitializeSplitStackDialog()
	
	local function CallbackSplitStackFinished()
		--refresh list
		if self.scene:IsShowing() then
			
			self:ToSavedPosition()
		end
	end
	CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED", CallbackSplitStackFinished)

    -- Use base UI destroy lifecycle; no custom cancel handler required

    -- Guard update loop so we only process while the inventory scene is visible.
    -- Prevents nil access inside RefreshItemActions when the scene is hidden but
    -- the control still ticks (reported by a user; mirrors ESO base patterns).
    local function OnUpdate(updateControl, currentFrameTimeSeconds)
        if self.scene and self.scene:IsShowing() then
            self:OnUpdate(currentFrameTimeSeconds)
        end
    end

    self.trySetClearNewFlagCallback =   function(callId)
	    self:TrySetClearNewFlag(callId)
    end
    
    local function RefreshVisualLayer()
        if self.scene:IsShowing() then
            self:OnUpdate()
            if self.actionMode == CATEGORY_ITEM_ACTION_MODE then
                self:RefreshCategoryList()
                self:SwitchActiveList(INVENTORY_ITEM_LIST)
            end
        end
    end

    -- Do not intercept base destroy cancel events to avoid input blockage
    control:RegisterForEvent(EVENT_VISUAL_LAYER_CHANGED, RefreshVisualLayer)
    control:SetHandler("OnUpdate", OnUpdate)

    -- Add gamepad text search support using the shared helper (from BETTERUI.Interface.Window)
    if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.AddSearch then
        -- Provide a dedicated keybind group for the text-search header. When the
        -- header is active the parametric screen will swap to this group so the
        -- only visible button is the Clear action (B).
        -- Store the descriptor on self immediately so callbacks can reference it.
        self.textSearchKeybindStripDescriptor = {
            {
                name = function()
                    return GetString(SI_GAMEPAD_SELECT_OPTION)
                end,
                alignment = KEYBIND_STRIP_ALIGN_LEFT,
                keybind = "UI_SHORTCUT_PRIMARY",
                disabledDuringSceneHiding = true,
                visible = function()
                    return self.textSearchHeaderControl ~= nil and not self.textSearchHeaderControl:IsHidden()
                end,
                callback = function()
                    self:ExitSearchFocus(true)
                end,
            },
            {
                name = function()
                    local hasText = self.searchQuery and tostring(self.searchQuery) ~= ""
                    if hasText then
                        return GetString(SI_BETTERUI_CLEAR_SEARCH) or "Clear"
                    end
                    return GetString(SI_GAMEPAD_BACK_OPTION)
                end,
                alignment = KEYBIND_STRIP_ALIGN_RIGHT,
                keybind = "UI_SHORTCUT_NEGATIVE",
                disabledDuringSceneHiding = true,
                visible = function()
                    return self.textSearchHeaderControl ~= nil and not self.textSearchHeaderControl:IsHidden()
                end,
                callback = function()
                    local hasText = self.searchQuery and tostring(self.searchQuery) ~= ""
                    if hasText then
                        if self.ClearTextSearch then
                            self:ClearTextSearch()
                        end
                    else
                        self:ExitSearchFocus()
                    end
                end,
            },
            {
                name = function()
                    return GetString(SI_GAMEPAD_SCRIPTS_KEYBIND_DOWN) or "Down"
                end,
                alignment = KEYBIND_STRIP_ALIGN_LEFT,
                keybind = "UI_SHORTCUT_DOWN",
                disabledDuringSceneHiding = true,
                visible = function()
                    return self.textSearchHeaderControl ~= nil and not self.textSearchHeaderControl:IsHidden()
                end,
                callback = function()
                    self:ExitSearchFocus(true)
                end,
            },
        }

        BETTERUI.Interface.Window.AddSearch(self, self.textSearchKeybindStripDescriptor, function(editOrText)
            -- Normalize the OnTextChanged argument like Banking does
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
            -- When search changes, reset selection to top and refresh the active list
            self:SaveListPosition()
            -- If craft bag is currently active, refresh craft bag list so filtering is immediate
            if self:GetCurrentList() == self.craftBagList then
                self:RefreshCraftBagList()
            else
                self:RefreshItemList()
            end
        end)
        if self.PositionSearchControl then
            self:PositionSearchControl()
        end
        -- Hook into the actual edit box to detect when it gains/loses keyboard focus.
        -- This is more reliable than the FocusActivated callback which tracks the
        -- ZO_TextSearch_Header_Gamepad object's activation state, not keyboard focus.
        if self.textSearchHeaderFocus and self.textSearchHeaderFocus:GetEditBox() then
            local editBox = self.textSearchHeaderFocus:GetEditBox()
            local origOnFocusGained = editBox:GetHandler("OnFocusGained")
            local origOnFocusLost = editBox:GetHandler("OnFocusLost")
            local origOnTextChanged = editBox:GetHandler("OnTextChanged")
            local origOnKeyDown = editBox:GetHandler("OnKeyDown")
            
            editBox:SetHandler("OnFocusGained", function(eb)
                -- Fire original handler if any
                if origOnFocusGained then origOnFocusGained(eb) end
                if not self:IsHeaderActive() then
                    self:RequestEnterHeader()
                end
            end)
            
            editBox:SetHandler("OnFocusLost", function(eb)
                -- Fire original handler if any
                if origOnFocusLost then origOnFocusLost(eb) end
                if self:IsHeaderActive() then
                    self:RequestLeaveHeader()
                end
            end)

            -- Targeted OnTextChanged handler: perform a local immediate craft-bag refresh
            -- when the engine's text-search manager will not run its background search
            -- (for example, single-character queries). This avoids editing engine
            -- files while allowing craft-bag filtering to feel instant for short queries.
            editBox:SetHandler("OnTextChanged", function(eb)
                -- Preserve original handler behavior first
                if origOnTextChanged then pcall(function() origOnTextChanged(eb) end) end

                local txt = ""
                local ok, t = pcall(function() return eb:GetText() end)
                if ok and t then txt = t end

                -- Mirror AddSearch normalization
                self.searchQuery = txt or ""

                -- Only force a local refresh for the craft-bag when the engine
                -- will not perform background filtering (to avoid doubling work).
                local willEngineFilter = false
                if ZO_TextSearchManager and ZO_TextSearchManager.CanFilterByText then
                    -- Use the raw text to decide (avoids needing the engine search context)
                    willEngineFilter = ZO_TextSearchManager.CanFilterByText(self.searchQuery)
                end

                if self:GetCurrentList() == self.craftBagList and not willEngineFilter then
                    pcall(function() self:SaveListPosition() end)
                    pcall(function() self:RefreshCraftBagList() end)
                end
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
        -- NOTE: search is now invoked via holding X/Y (see holdDown/holdUp callbacks on X/Y descriptors below).
    end

    -- After Initialize completes the search control and descriptors should exist.
    -- Force a short delayed refresh of the main keybind group so visibility
    -- predicates (like the Clear Search QUATERNARY) get evaluated with the
    -- newly-created `textSearchHeaderControl`. This fixes the case where the
    -- clear prompt didn't appear until the list was interacted with.
    zo_callLater(function()
        pcall(function()
            if self.RefreshKeybinds then
                self:RefreshKeybinds()
            elseif self.mainKeybindStripDescriptor then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
            end
        end)
    end, 40)
end


function BETTERUI.Inventory.Class:RefreshHeader(blockCallback)
    local currentList = self:GetCurrentList()

    local function HeaderGoldText()
        return BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_MONEY))
    end
    local function HeaderAPText()
        return BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_ALLIANCE_POINTS))
    end
    local function HeaderTelVarText()
        return BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_TELVAR_STONES))
    end

    local function BuildHeaderData(listRef, useAbbrev)
        -- Category list uses prebuilt header with tab bar
        if listRef == self.categoryList then
            return self.categoryHeaderData
        end

        local invSettings = BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Inventory"] or {}
        local data = { titleText = function() return GetString(self:GetCurrentList() == self.craftBagList and SI_BETTERUI_INV_ACTION_CB or SI_BETTERUI_INV_ACTION_INV) end }
        local slot = 1
        local function add(headerText, valueFunc)
            if slot == 1 then data.data1HeaderText, data.data1Text = headerText, valueFunc
            elseif slot == 2 then data.data2HeaderText, data.data2Text = headerText, valueFunc
            elseif slot == 3 then data.data3HeaderText, data.data3Text = headerText, valueFunc
            elseif slot == 4 then data.data4HeaderText, data.data4Text = headerText, valueFunc end
            slot = slot + 1
        end

        local goldFunc = useAbbrev and HeaderGoldText or UpdateGold
        local apFunc = useAbbrev and HeaderAPText or UpdateAlliancePoints
        local tvFunc = useAbbrev and HeaderTelVarText or UpdateTelvarStones

        if invSettings.showCurrencyGold ~= false then
            add(GetString(SI_GAMEPAD_INVENTORY_AVAILABLE_FUNDS), goldFunc)
        end
        if listRef ~= self.craftBagList then
            if invSettings.showCurrencyAlliancePoints ~= false then
                add(GetString(SI_GAMEPAD_INVENTORY_ALLIANCE_POINTS), apFunc)
            end
            if invSettings.showCurrencyTelVar ~= false then
                add(GetString(SI_GAMEPAD_INVENTORY_TELVAR_STONES), tvFunc)
            end
            add(GetString(SI_GAMEPAD_INVENTORY_CAPACITY), UpdateCapacityString)
        end
        return data
    end

    local headerData = BuildHeaderData(currentList, true) -- use abbreviated values by default

    BETTERUI.GenericHeader.Refresh(self.header, headerData, blockCallback)

    -- Ensure the header's focus control includes the search control when present.
    -- We no longer try to hide or remove the search from header focus here; instead
    -- the header-enter lifecycle will programmatically focus the search when the
    -- user actually enters the header. This avoids navigation surprises while
    -- browsing categories but still allows the user to navigate to the search.
    if ZO_GamepadGenericHeader_SetHeaderFocusControl and self.textSearchHeaderControl then
        pcall(function() ZO_GamepadGenericHeader_SetHeaderFocusControl(self.header, self.textSearchHeaderControl) end)
    end

	
	BETTERUI.GenericHeader.SetEquipText(self.header, self.isPrimaryWeapon)
	BETTERUI.GenericHeader.SetBackupEquipText(self.header, self.isPrimaryWeapon)
	BETTERUI.GenericHeader.SetEquippedIcons(self.header, GetEquippedItemInfo(EQUIP_SLOT_MAIN_HAND), GetEquippedItemInfo(EQUIP_SLOT_OFF_HAND), GetEquippedItemInfo(EQUIP_SLOT_POISON))
	BETTERUI.GenericHeader.SetBackupEquippedIcons(self.header, GetEquippedItemInfo(EQUIP_SLOT_BACKUP_MAIN), GetEquippedItemInfo(EQUIP_SLOT_BACKUP_OFF), GetEquippedItemInfo(EQUIP_SLOT_BACKUP_POISON))

    self:RefreshCategoryList()
    BETTERUI.GenericFooter.Refresh(self)
    -- Reposition the search control so it sits under the header/title (above the list)
    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
end

function BETTERUI.Inventory.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then return end
    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.header
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        local candidates = { "TitleContainer", "Header", "HeaderContainer", "HeaderTitle", "HeaderBar", "ContainerHeader" }
        for _, name in ipairs(candidates) do
            local ok, c = pcall(function() return anchorTarget:GetNamedChild(name) end)
            if ok and c then
                titleContainer = c
                break
            end
        end
        if not titleContainer then
            local ok, h = pcall(function() return anchorTarget:GetNamedChild("Header") end)
            if ok and h and h.GetNamedChild then
                local ok2, tc = pcall(function() return h:GetNamedChild("TitleContainer") end)
                if ok2 and tc then titleContainer = tc end
            end
        end
    end
    local parentForAnchor = titleContainer or anchorTarget
    if parentForAnchor then
        -- Adjust these values here to tweak the search control's position and size
        -- xOffset: horizontal offset from the header's left edge (moves control right)
        -- yOffset: vertical offset from the header's bottom (positive moves down)
        -- rightInset: inset applied to the right anchor (negative moves left)
        local cfg = {
            xOffset = 51,
            yOffset = 1,
            rightInset = -4,
        }
        local yOffset = (cfg and cfg.yOffset)
        local xOffset = (cfg and cfg.xOffset)
        local rightInset = (cfg and cfg.rightInset)
        -- TOPLEFT uses xOffset, TOPRIGHT uses rightInset so the control width is constrained
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, 8)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0, 8)
    end
    self.textSearchHeaderControl:SetHidden(false)
end

-- Centralized helper to clear the text search UI and internal state.
-- Consolidates repeated checks/calls to the shared BetterUI helper or
-- the local ClearSearchText method.
function BETTERUI.Inventory.Class:ClearTextSearch()
    -- Ensure internal state is cleared
    self.searchQuery = ""
    -- Prefer shared helper if available
    if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.ClearSearchText then
        pcall(function() BETTERUI.Interface.Window.ClearSearchText(self) end)
    elseif self.ClearSearchText then
        pcall(function() self:ClearSearchText() end)
    end
end

function BETTERUI.Inventory:RefreshFooter()
    BETTERUI.GenericFooter.Refresh(self.footer)
end

function BETTERUI.Inventory.Class:Select()
    if not self.categoryList:GetTargetData().onClickDirection then
        self:SwitchActiveList(INVENTORY_ITEM_LIST)
    else
        self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
    end
end

function BETTERUI.Inventory.Class:Switch()
    if self:GetCurrentList() == self.craftBagList then
        self:SwitchActiveList(INVENTORY_ITEM_LIST)
    else
        self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
		
    end
end

function BETTERUI.Inventory.Class:SwitchActiveList(listDescriptor)
	if listDescriptor == self.currentListType then return end

	self.previousListType = self.currentListType
	self.currentListType = listDescriptor

	if self.previousListType == INVENTORY_ITEM_LIST or self.previousListType == INVENTORY_CATEGORY_LIST then
		self.listWaitingOnDestroyRequest = nil
		self:TryClearNewStatusOnHidden()
		ZO_SavePlayerConsoleProfile()
    else
        self.listWaitingOnDestroyRequest = nil
        self:TryClearNewStatusOnHidden()
        ZO_SavePlayerConsoleProfile()
	end

	GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
	GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)

	if listDescriptor == INVENTORY_CATEGORY_LIST then
        listDescriptor = INVENTORY_ITEM_LIST
    elseif listDescriptor ~= INVENTORY_ITEM_LIST and listDescriptor ~= INVENTORY_CATEGORY_LIST then
        listDescriptor = INVENTORY_CRAFT_BAG_LIST
    end
    if self.scene:IsShowing() then

    	if listDescriptor == INVENTORY_ITEM_LIST then
    		self:SetCurrentList(self.itemList)
    		self:SetActiveKeybinds(self.mainKeybindStripDescriptor)

    		self:RefreshCategoryList()
    		self:RefreshItemList()

    		self:SetSelectedItemUniqueId(self.itemList:GetTargetData())
    		self.actionMode = ITEM_LIST_ACTION_MODE
    		self:RefreshItemActions()

	    	self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
	    	self:UpdateItemLeftTooltip(self.itemList.selectedData)

			
		elseif listDescriptor == INVENTORY_CRAFT_BAG_LIST then  
			self:SetCurrentList(self.craftBagList)
			self:SetActiveKeybinds(self.mainKeybindStripDescriptor)

			self:RefreshCategoryList()
			self:RefreshCraftBagList()

			self:SetSelectedItemUniqueId(self.craftBagList:GetTargetData())
			self.actionMode = CRAFT_BAG_ACTION_MODE
			self:RefreshItemActions()
			self:RefreshHeader()
			self:LayoutCraftBagTooltip(GAMEPAD_LEFT_TOOLTIP)

			
		end 
		self:RefreshKeybinds()
	else
		self.actionMode = nil
	end
end

function BETTERUI.Inventory.Class:ActivateHeader()
    ZO_GamepadGenericHeader_Activate(self.header)
    self.header.tabBar:SetSelectedIndexWithoutAnimation(self.categoryList.selectedIndex, true, false)
end

-- Override header-enter lifecycle to auto-focus the text search when the header is entered.
function BETTERUI.Inventory.Class:OnEnterHeader()
    if ZO_GamepadInventory and ZO_GamepadInventory.OnEnterHeader then
        ZO_GamepadInventory.OnEnterHeader(self)
    else
        ZO_Gamepad_ParametricList_Screen.OnEnterHeader(self)
    end

    if self.textSearchHeaderControl and not self.textSearchHeaderControl:IsHidden() then
        if self.textSearchHeaderFocus and not self.textSearchHeaderFocus:IsActive() then
            self.textSearchHeaderFocus:Activate()
        end
        if self.SetTextSearchFocused then
            self:SetTextSearchFocused(true)
        end
    end
end

function BETTERUI.Inventory.Class:OnLeaveHeader()
    if ZO_GamepadInventory and ZO_GamepadInventory.OnLeaveHeader then
        ZO_GamepadInventory.OnLeaveHeader(self)
    else
        ZO_Gamepad_ParametricList_Screen.OnLeaveHeader(self)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Deactivate()
    end
end

function BETTERUI.Inventory.Class:ExitSearchFocus(selectTopResult)
    if self:IsHeaderActive() then
        self:RequestLeaveHeader()
    end

    if not selectTopResult then
        return
    end

    if self.searchQuery and tostring(self.searchQuery) ~= "" then
        local currentList = self:GetCurrentList()
        if currentList and currentList.SetSelectedIndexWithoutAnimation then
            local count = 0
            if currentList.GetNumItems then
                count = currentList:GetNumItems()
            elseif currentList.GetNumEntries then
                count = currentList:GetNumEntries()
            elseif currentList.dataList then
                count = #currentList.dataList
            end
            if count > 0 then
                pcall(function() currentList:SetSelectedIndexWithoutAnimation(1, true, false) end)
            end
        end
    end
end

function BETTERUI.Inventory.Class:AddList(name, callbackParam, listClass, ...)

    local listContainer = CreateControlFromVirtual("$(parent)"..name, self.control.container, "BETTERUI_Gamepad_ParametricList_Screen_ListContainer")
    local list = self.CreateAndSetupList(self, listContainer.list, callbackParam, listClass, ...)
	list.alignToScreenCenterExpectedEntryHalfHeight = 15
    self.lists[name] = list

    local CREATE_HIDDEN = true
    self:CreateListFragment(name, CREATE_HIDDEN)
    return list
end

function BETTERUI.Inventory.Class:BETTERUI_IsSlotLocked(inventorySlot)
    if (not inventorySlot) then
	    return false
	end
	
    local slot = PLAYER_INVENTORY:SlotForInventoryControl(inventorySlot)
    if slot then
        return slot.locked
    end
end

--------------
-- Keybinds --
--------------
function BETTERUI.Inventory.Class:InitializeKeybindStrip()
    -- Helper used by X-button name/callback to decide if an item is quickslottable
    local function IsQuickslottable(sd)
        if not sd or not sd.bagId or not sd.slotIndex then return false end
        local bag, slot = sd.bagId, sd.slotIndex
        -- Already assigned is always eligible
        if FindActionSlotMatchingItem and FindActionSlotMatchingItem(bag, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
            return true
        end
        -- Exclude quest items explicitly
        if ZO_InventoryUtils_DoesNewItemMatchFilterType and ZO_InventoryUtils_DoesNewItemMatchFilterType(sd, ITEMFILTERTYPE_QUEST) then
            return false
        end
        -- Prefer the UI's own quickslot filter (captures true quickslottables reliably)
        if ZO_InventoryUtils_DoesNewItemMatchFilterType and ZO_InventoryUtils_DoesNewItemMatchFilterType(sd, ITEMFILTERTYPE_QUICKSLOT) then
            return true
        end
        -- Engine validation as a secondary check
        if IsValidItemForSlot and IsValidItemForSlot(bag, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
            return true
        end
        return false
    end

    self.mainKeybindStripDescriptor = {
            -- Primary (A) reserved for item primary actions (equip/use/etc.).
		--X Button for Quick Action
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                local n = ""
                if self.actionMode == ITEM_LIST_ACTION_MODE then
                    --bag mode
                    local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(self.itemList.selectedData, ITEMFILTERTYPE_QUEST)
                    local target = self.itemList.selectedData
                    local ft = (target and target.bagId and target.slotIndex) and GetItemFilterTypeInfo(target.bagId, target.slotIndex) or nil
                    if IsQuickslottable(target) then
                        --assign
                        n = GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN)
                    elseif not isQuestItem and (ft == ITEMFILTERTYPE_WEAPONS or ft == ITEMFILTERTYPE_ARMOR or ft == ITEMFILTERTYPE_JEWELRY) then
                        --switch compare
                        n = GetString(SI_BETTERUI_INV_SWITCH_INFO)
                    else
                        n = GetString(SI_ITEM_ACTION_LINK_TO_CHAT)
                    end
                elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
                    --craftbag mode
                    n = GetString(SI_ITEM_ACTION_LINK_TO_CHAT)
                else
                    n = ""
                end
                return n or ""
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            -- (no hold callbacks here; tap behavior preserved)
            visible = function()
                if self.actionMode == ITEM_LIST_ACTION_MODE then
                    if self.itemList.selectedData then
                        local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(self.itemList.selectedData, ITEMFILTERTYPE_QUEST)
                        return not isQuestItem
                    end
                    return false
                elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
                    return true
                end
            end,
            callback = function()
            	if self.actionMode == ITEM_LIST_ACTION_MODE then
            		--bag mode
                    local target = self.itemList.selectedData
                    local ft = (target and target.bagId and target.slotIndex) and GetItemFilterTypeInfo(target.bagId, target.slotIndex) or nil
                    if IsQuickslottable(target) then
                        -- Open BetterUI quickslot assignment dialog to let user pick the wheel slot visually
                        self:ShowQuickslotAssignDialog(target.bagId, target.slotIndex)
					else
                        -- If it's gear categories, toggle compare; otherwise link to chat
                        if not ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST) and (ft == ITEMFILTERTYPE_WEAPONS or ft == ITEMFILTERTYPE_ARMOR or ft == ITEMFILTERTYPE_JEWELRY) then
                            self:SwitchInfo()
                        else
                            local itemLink = GetItemLink(target.bagId, target.slotIndex)
                            if itemLink then
                                ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
                            end
                        end
            		end 
            	elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
            		--craftbag mode
            		local targetData = self.craftBagList:GetTargetData()
					local itemLink
					local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
					if bag and slot then
						itemLink = GetItemLink(bag, slot)
					end
					if itemLink then
						ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
					end
            	end
            end,
		},
		--Y Button for Actions
        {
            name = GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND),
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = "UI_SHORTCUT_TERTIARY",
            -- (no hold callbacks here; tap behavior preserved)
            order = 1000,
            visible = function()
            	if self.actionMode == ITEM_LIST_ACTION_MODE then
               		return self.selectedItemUniqueId ~= nil or self.itemList:GetTargetData() ~= nil
            	elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
            		return self.selectedItemUniqueId ~= nil
            	end 
            end,

            callback = function()
				self:SaveListPosition()
                self:ShowActions()
            end,
        },
        --L Stick for Stacking Items
        {
        	name = GetString(SI_ITEM_ACTION_STACK_ALL),
        	alignment = KEYBIND_STRIP_ALIGN_LEFT,
        	keybind = "UI_SHORTCUT_LEFT_STICK",
        	disabledDuringSceneHiding = true,
        	visible = function()
        		return self.actionMode == ITEM_LIST_ACTION_MODE
        	end,
        	callback = function()
        		StackBag(BAG_BACKPACK)
        	end,
        },
        --R Stick for Switching Bags
        {
            name = function()
                local s = zo_strformat(GetString(SI_BETTERUI_INV_ACTION_TO_TEMPLATE), GetString(self:GetCurrentList() == self.craftBagList and SI_BETTERUI_INV_ACTION_INV or SI_BETTERUI_INV_ACTION_CB))
                return s or ""
            end,
        	alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            disabledDuringSceneHiding = true,
            callback = function()
                self:Switch()
            end,
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
                return self.textSearchHeaderControl ~= nil
            end,
            callback = function()
                if not (self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden())) then return end
                -- Use centralized helper to clear the search and restore keybinds
                if self.ClearTextSearch then
                    self:ClearTextSearch()
                end
                -- After clearing search, restore the standard inventory keybinds
                pcall(function()
                    if self.textSearchKeybindStripDescriptor then
                        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
                    end
                end)
                pcall(function()
                    if self.mainKeybindStripDescriptor then
                        KEYBIND_STRIP:AddKeybindButtonGroup(self.mainKeybindStripDescriptor)
                        pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor) end)
                        -- Make sure the main group is active so LB/RB navigation remains available.
                        pcall(function() if self.SetActiveKeybinds then self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end end)
                        -- Re-assert after a short delay in case other delayed handlers run.
                        zo_callLater(function()
                            pcall(function() if self.SetActiveKeybinds then self:SetActiveKeybinds(self.mainKeybindStripDescriptor) end end)
                        end, 40)
                    end
                end)
            end,
        },
        -- Removed NEGATIVE hold descriptor - using QUATERNARY only per settings
	}

	ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
  
end

local function BETTERUI_TryPlaceInventoryItemInEmptySlot(targetBag)
	local emptySlotIndex, bagId
	if targetBag == BAG_BANK or targetBag == BAG_SUBSCRIBER_BANK then
		--should find both in bank and subscriber bank
		emptySlotIndex = FindFirstEmptySlotInBag(BAG_BANK)
		if emptySlotIndex ~= nil then
			bagId = BAG_BANK
		else
			emptySlotIndex = FindFirstEmptySlotInBag(BAG_SUBSCRIBER_BANK)
			if emptySlotIndex ~= nil then
				bagId = BAG_SUBSCRIBER_BANK
			end
		end
	else
		--just find the bag 
    	emptySlotIndex = FindFirstEmptySlotInBag(targetBag)
    	if emptySlotIndex ~= nil then
    		bagId = targetBag
    	end
    end

    if bagId ~= nil then
        CallSecureProtected("PlaceInInventory", bagId, emptySlotIndex)
    else
        local errorStringId = (targetBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or SI_INVENTORY_ERROR_BANK_FULL
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
    end
end

function BETTERUI.Inventory.Class:InitializeSplitStackDialog()
    ZO_Dialogs_RegisterCustomDialog(ZO_GAMEPAD_SPLIT_STACK_DIALOG,
    {
        blockDirectionalInput = true,

        canQueue = true,

        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
        },

        setup = function(dialog, data)
            dialog:setupFunc()
        end,

        title =
        {
            text = SI_GAMEPAD_INVENTORY_SPLIT_STACK_TITLE,
        },

        mainText =
        {
            text = SI_GAMEPAD_INVENTORY_SPLIT_STACK_PROMPT,
        },

        OnSliderValueChanged =  function(dialog, sliderControl, value)
                                    dialog.sliderValue1:SetText(dialog.data.stackSize - value)
                                    dialog.sliderValue2:SetText(value)
                                end,

        buttons =
        {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    local dialogData = dialog.data
                    local quantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)
                    CallSecureProtected("PickupInventoryItem",dialogData.bagId, dialogData.slotIndex, quantity)                    
                    BETTERUI_TryPlaceInventoryItemInEmptySlot(dialogData.bagId)
					CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED")
                end,
            },
        }
    })
end

-- Simple confirmation dialog for destroying an item (entire stack)
function BETTERUI.Inventory.Class:InitializeConfirmDestroyDialog()
    ZO_Dialogs_RegisterCustomDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
    {
        blockDirectionalInput = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
            allowRightStickPassThrough = true,
        },
        title = {
            text = function(dialog)
                return GetString(SI_DESTROY_ITEM_PROMPT_TITLE) or "Destroy Item"
            end,
        },
        mainText = {
            text = function(dialog)
                local link = dialog and dialog.data and dialog.data.itemLink
                if link and link ~= "" then
                    return zo_strformat("Are you sure you want to destroy <<1>>? This cannot be undone.", link)
                end
                return "Are you sure you want to destroy this item? This cannot be undone."
            end,
        },
        buttons = {
            { keybind = "DIALOG_NEGATIVE", text = GetString(SI_DIALOG_CANCEL) },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    local d = dialog and dialog.data
                    if d and d.bagId and d.slotIndex then
                        -- Force destruction on explicit user confirmation
                        local destroyed = BETTERUI.Inventory.TryDestroyItem(d.bagId, d.slotIndex, true)
                        -- Refresh lists shortly after to reflect removal
                        if destroyed then
                            zo_callLater(function()
                                if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
                                    GAMEPAD_INVENTORY:RefreshItemList()
                                end
                            end, 120)
                        end
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_CONFIRM_DESTROY_DIALOG")
                end,
            },
        },
    })
end
