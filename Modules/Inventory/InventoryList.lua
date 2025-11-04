-------------------------------------------------------------------------------------------------------------------------------------------------------
--
--    BetterUI Inventory List - UI Entry Setup and List Management
--    This file contains functions for setting up inventory list entries, handling item display, and managing list operations
--
-------------------------------------------------------------------------------------------------------------------------------------------------------

local TEXTURE_EQUIP_ICON = "BetterUI/Modules/CIM/Images/inv_equip.dds"
local TEXTURE_EQUIP_BACKUP_ICON = "BetterUI/Modules/CIM/Images/inv_equip_backup.dds"
local TEXTURE_EQUIP_SLOT_ICON = "BetterUI/Modules/CIM/Images/inv_equip_quickslot.dds"
local NEW_ICON_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_new.dds"

local USE_SHORT_CURRENCY_FORMAT = true
 
local DEFAULT_GAMEPAD_ITEM_SORT =
{
    bestGamepadItemCategoryName = { tiebreaker = "name" },
    name = { tiebreaker = "requiredLevel" },
    requiredLevel = { tiebreaker = "requiredChampionPoints", isNumeric = true },
    requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
    iconFile = { tiebreaker = "uniqueId" },
    uniqueId = { isId64 = true },
}

--- Default item sort comparator for gamepad inventory
--- @param left table: Left item data
--- @param right table: Right item data
--- @return boolean: True if left should come before right
function BETTERUI_Inventory_DefaultItemSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "bestGamepadItemCategoryName", DEFAULT_GAMEPAD_ITEM_SORT, ZO_SORT_ORDER_UP)
end




--- Sets up the label for a shared gamepad entry with icons and formatting
--- @param label table: The label control
--- @param data table: The entry data
--- @param selected boolean: Whether the entry is selected
function BETTERUI_SharedGamepadEntryLabelSetup(label, data, selected)

    if label then
    	local font = "ZoFontGamepad27"
		if BETTERUI.Settings.Modules["CIM"].skinSize == "Medium" then
            font = "ZoFontGamepad36"
        elseif BETTERUI.Settings.Modules["CIM"].skinSize == "Large" then
            font = "ZoFontGamepad42"
		end
		label:SetFont(font)
		
        if data.modifyTextType then
            label:SetModifyTextType(data.modifyTextType)
        end

        local dS = data.dataSource
        local bagId = dS.bagId
        local slotIndex = dS.slotIndex
        local isLocked = dS.isPlayerLocked
        local isBoPTradeable = dS.isBoPTradeable

        local labelTxt = ""

        if isLocked then labelTxt = labelTxt.."|t24:24:"..ZO_GAMEPAD_LOCKED_ICON_32.."|t" end
        if isBoPTradeable then labelTxt = labelTxt.."|t24:24:"..ZO_TRADE_BOP_ICON.."|t" end

        labelTxt = labelTxt .. data.text

        if(data.stackCount > 1) then
           labelTxt = labelTxt..zo_strformat(" |cFFFFFF(<<1>>)|r",data.stackCount)
        end

        local itemData = data.cached_itemLink or GetItemLink(bagId, slotIndex)

        local setItem = data.cached_setItem or GetItemLinkSetInfo(itemData, false)
        local hasEnchantment = data.cached_hasEnchantment or GetItemLinkEnchantInfo(itemData)

        local currentItemType = data.cached_itemType or GetItemLinkItemType(itemData)
        local isRecipeAndUnknown = data.cached_isRecipeAndUnknown or ((currentItemType == ITEMTYPE_RECIPE) and not IsItemLinkRecipeKnown(itemData))

		local isUnbound = data.cached_isUnbound or (not IsItemBound(bagId, slotIndex) and not data.stolen and data.quality ~= ITEM_QUALITY_TRASH)

        if data.stolen then labelTxt = labelTxt.." |t16:16:/BetterUI/Modules/CIM/Images/inv_stolen.dds|t" end
		if isUnbound and BETTERUI.Settings.Modules["Inventory"].showIconUnboundItem then labelTxt = labelTxt.." |t16:16:/esoui/art/guild/gamepad/gp_ownership_icon_guildtrader.dds|t" end
        if hasEnchantment and BETTERUI.Settings.Modules["Inventory"].showIconEnchantment then labelTxt = labelTxt.." |t16:16:/BetterUI/Modules/CIM/Images/inv_enchanted.dds|t" end
        if setItem and BETTERUI.Settings.Modules["Inventory"].showIconSetGear then labelTxt = labelTxt.." |t16:16:/BetterUI/Modules/CIM/Images/inv_setitem.dds|t" end
        if isRecipeAndUnknown then labelTxt = labelTxt.." |t16:16:/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_provisioning.dds|t" end

        label:SetText(labelTxt)

        local labelColor = data:GetNameColor(selected)
        if type(labelColor) == "function" then
            labelColor = labelColor(data)
        end
        label:SetColor(labelColor:UnpackRGBA())

        if ZO_ItemSlot_SetupTextUsableAndLockedColor then
            ZO_ItemSlot_SetupTextUsableAndLockedColor(label, data.meetsUsageRequirements)
        end
    end
end

--- Sets up icons for equipped and new item status
--- @param statusIndicator table: The status indicator control
--- @param equippedIcon table: The equipped icon control
--- @param data table: The entry data
function BETTERUI_IconSetup(statusIndicator, equippedIcon, data)

    statusIndicator:ClearIcons()

    local isItemNew
    if type(data.brandNew) == "function" then
        isItemNew = data.brandNew()
    else
        isItemNew = data.brandNew
    end

    if isItemNew and data.enabled then
        statusIndicator:AddIcon(NEW_ICON_TEXTURE)
        statusIndicator:SetHidden(false)
    end

    if data.isEquippedInCurrentCategory or data.isEquippedInAnotherCategory then
        local slotIndex = data.dataSource.slotIndex
        local equipType = data.dataSource.equipType
        if slotIndex == EQUIP_SLOT_BACKUP_MAIN or slotIndex == EQUIP_SLOT_BACKUP_OFF or slotIndex == EQUIP_SLOT_RING2 or slotIndex == EQUIP_SLOT_TRINKET2 or slotIndex == EQUIP_SLOT_BACKUP_POISON then
            equippedIcon:SetTexture(TEXTURE_EQUIP_BACKUP_ICON)
        else
            equippedIcon:SetTexture(TEXTURE_EQUIP_ICON)
        end
        if equipType == EQUIP_TYPE_INVALID then
            equippedIcon:SetTexture(TEXTURE_EQUIP_SLOT_ICON)
        end
        equippedIcon:SetHidden(false)
    else
        equippedIcon:SetHidden(true)
    end
end

--- Sets up the icon for a shared gamepad entry
--- @param icon table: The icon control
--- @param stackCountLabel table: The stack count label
--- @param data table: The entry data
--- @param selected boolean: Whether the entry is selected
function BETTERUI_SharedGamepadEntryIconSetup(icon, stackCountLabel, data, selected)
    if icon then
        if data.iconUpdateFn then
            data.iconUpdateFn()
        end

        local numIcons = data:GetNumIcons()
        icon:SetMaxAlpha(data.maxIconAlpha)
        icon:ClearIcons()
        if numIcons > 0 then
            for i = 1, numIcons do
                local iconTexture = data:GetIcon(i, selected)
                icon:AddIcon(iconTexture)
            end
            icon:Show()
            if data.iconDesaturation then
                icon:SetDesaturation(data.iconDesaturation)
            end
            local r, g, b = 1, 1, 1
            if data.enabled then
                if selected and data.selectedIconTint then
                    r, g, b = data.selectedIconTint:UnpackRGBA()
                elseif (not selected) and data.unselectedIconTint then
                    r, g, b = data.unselectedIconTint:UnpackRGBA()
                end
            else
                if selected and data.selectedIconDisabledTint then
                    r, g, b = data.selectedIconDisabledTint:UnpackRGBA()
                elseif (not selected) and data.unselectedIconDisabledTint then
                    r, g, b = data.unselectedIconDisabledTint:UnpackRGBA()
                end
            end
            if data.meetsUsageRequirement == false then
                icon:SetColor(r, 0, 0, icon:GetControlAlpha())
            else
                icon:SetColor(r, g, b, icon:GetControlAlpha())
            end
        end
    end
end

--- Sets up cooldown display on a control
--- @param control table: The control to apply cooldown to
--- @param remaining number: Remaining cooldown time
--- @param duration number: Total cooldown duration
--- @param cooldownType number: Type of cooldown display
--- @param timeType number: Type of time display
--- @param useLeadingEdge boolean: Whether to use leading edge
--- @param alpha number: Alpha value
--- @param desaturation number: Desaturation value
--- @param preservePreviousCooldown boolean: Whether to preserve previous cooldown
function BETTERUI_Cooldown(control, remaining, duration, cooldownType, timeType, useLeadingEdge, alpha, desaturation, preservePreviousCooldown)
    local inCooldownNow = remaining > 0 and duration > 0
    if inCooldownNow then
        local timeLeftOnPreviousCooldown = control.cooldown:GetTimeLeft()
        if not preservePreviousCooldown or timeLeftOnPreviousCooldown == 0 then
            control.cooldown:SetDesaturation(desaturation)
            control.cooldown:SetAlpha(alpha)
            control.cooldown:StartCooldown(remaining, duration, cooldownType, timeType, useLeadingEdge)
        end
    else
        control.cooldown:ResetCooldown()
    end
    control.cooldown:SetHidden(not inCooldownNow)
end

--- Sets up cooldown for a control based on data
--- @param control table: The control
--- @param data table: The data containing cooldown info
function BETTERUI_CooldownSetup(control, data)
    local GAMEPAD_DEFAULT_COOLDOWN_TEXTURE = "EsoUI/Art/Mounts/timer_icon.dds"
    if control.cooldown then
        local currentTime = GetFrameTimeMilliseconds()
        local timeOffset = currentTime - (data.timeCooldownRecorded or 0)
        local remaining = (data.cooldownRemaining or 0) - timeOffset
        local duration = (data.cooldownDuration or 0)
        control.inCooldown = (remaining > 0) and (duration > 0)
        control.cooldown:SetTexture(data.cooldownIcon or GAMEPAD_DEFAULT_COOLDOWN_TEXTURE)

        if data.cooldownIcon then
            control.cooldown:SetFillColor(ZO_SELECTED_TEXT:UnpackRGBA())
            control.cooldown:SetVerticalCooldownLeadingEdgeHeight(4)
            BETTERUI_Cooldown(control, remaining, duration, CD_TYPE_VERTICAL_REVEAL, CD_TIME_TYPE_TIME_UNTIL, USE_LEADING_EDGE, 1, 1, PRESERVE_PREVIOUS_COOLDOWN)
        else
            BETTERUI_Cooldown(control, remaining, duration, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, DONT_USE_LEADING_EDGE, 0.85, 0, OVERWRITE_PREVIOUS_COOLDOWN)
        end
    end
end

--- Set up a gamepad inventory entry with all visual elements and data
--- This is a performance-critical function called for every item in the inventory list
--- @param control table: The UI control for the entry
--- @param data table: The item data to display
--- @param selected boolean: Whether this entry is currently selected
--- @param reselectingDuringRebuild boolean: Whether this is a reselection during rebuild
--- @param enabled boolean: Whether the entry is enabled
--- @param active boolean: Whether the entry is active
function BETTERUI_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    BETTERUI_SharedGamepadEntryLabelSetup(control.label, data, selected)

    -- Use cached values for performance
    local bagId = data.bagId or (data.dataSource and data.dataSource.bagId)
    local slotIndex = data.slotIndex or (data.dataSource and data.dataSource.slotIndex)

    local itemLink = data.cached_itemLink or (bagId and slotIndex and GetItemLink(bagId, slotIndex))
    local itemType = data.cached_itemType or (itemLink and GetItemLinkItemType(itemLink))
    local skinSize = BETTERUI.Settings.Modules["CIM"].skinSize

    -- Set font sizes based on skin size (cached to avoid repeated calculations)
    local itemTypeFont, traitFont, statFont, valueFont
    if skinSize == "Medium" then
        itemTypeFont = "ZoFontGamepadCondensed34"
        traitFont = "ZoFontGamepadCondensed34"
        statFont = "ZoFontGamepadCondensed34"
        valueFont = "ZoFontGamepadCondensed34"
    elseif skinSize == "Large" then
        itemTypeFont = "ZoFontGamepad36"
        traitFont = "ZoFontGamepad36"
        statFont = "ZoFontGamepad36"
        valueFont = "ZoFontGamepad36"
    else
        itemTypeFont = "ZoFontGamepad27"
        traitFont = "ZoFontGamepad27"
        statFont = "ZoFontGamepad27"
        valueFont = "ZoFontGamepad27"
    end

    local itemTypeControl = control:GetNamedChild("ItemType")
    local traitControl = control:GetNamedChild("Trait")
    local statControl = control:GetNamedChild("Stat")
    local valueControl = control:GetNamedChild("Value")

    itemTypeControl:SetFont(itemTypeFont)
    traitControl:SetFont(traitFont)
    statControl:SetFont(statFont)
    valueControl:SetFont(valueFont)

    -- Set item type
    itemTypeControl:SetText(string.upper(data.bestItemTypeName))

    -- Set trait information
    local traitType = (bagId and slotIndex) and GetItemTrait(bagId, slotIndex) or ITEM_TRAIT_TYPE_NONE
    traitControl:SetText(traitType == ITEM_TRAIT_TYPE_NONE and "-" or string.upper(GetString("SI_ITEMTRAITTYPE", traitType)))

    -- Set stat information based on item type
    local statText
    if itemType == ITEMTYPE_RECIPE then
        statText = data.cached_isRecipeAndUnknown and GetString(SI_BETTERUI_INV_RECIPE_UNKNOWN) or GetString(SI_BETTERUI_INV_RECIPE_KNOWN)
    elseif IsItemLinkBook(itemLink) then
        statText = data.cached_isBookKnown and GetString(SI_BETTERUI_INV_RECIPE_KNOWN) or GetString(SI_BETTERUI_INV_RECIPE_UNKNOWN)
    else
        local statValue = data.dataSource and data.dataSource.statValue
        if statValue == nil then
            statText = "-"
        else
            statText = (statValue == 0) and "-" or statValue
        end
    end
    statControl:SetText(statText)

    -- Handle market price display
    if BETTERUI.Settings.Modules["Inventory"].showMarketPrice and
       (SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() or SCENE_MANAGER.scenes['gamepad_inventory_root']:IsShowing()) then

        local marketPrice, isAverage = BETTERUI.GetMarketPrice(itemLink, data.stackCount)
        if marketPrice and marketPrice > 0 then
            valueControl:SetColor(isAverage and 1 or 1, isAverage and 0.5 or 0.75, isAverage and 0.5 or 0, 1)
            valueControl:SetText(ZO_CurrencyControl_FormatCurrency(math.floor(marketPrice), USE_SHORT_CURRENCY_FORMAT))
        else
            valueControl:SetColor(1, 1, 1, 1)
            valueControl:SetText(data.stackSellPrice)
        end
    else
        valueControl:SetColor(1, 1, 1, 1)
        valueControl:SetText(ZO_CurrencyControl_FormatCurrency(data.stackSellPrice, USE_SHORT_CURRENCY_FORMAT))
    end

    -- Setup remaining UI elements
    BETTERUI_SharedGamepadEntryIconSetup(control.icon, control.stackCountLabel, data, selected)

    if control.highlight then
        if selected and data.highlight then
            control.highlight:SetTexture(data.highlight)
        end
        control.highlight:SetHidden(not selected or not data.highlight)
    end

    BETTERUI_CooldownSetup(control, data)
    BETTERUI_IconSetup(control:GetNamedChild("StatusIndicator"), control:GetNamedChild("EquippedMain"), data)

    -- Adjust icon dimensions based on skin size
    local iconControl = control:GetNamedChild("Icon")
    local equipIconControl = control:GetNamedChild("EquippedMain")

    if skinSize == "Medium" then
        iconControl:SetDimensions(42, 42)
        iconControl:ClearAnchors()
        iconControl:SetAnchor(CENTER, control:GetNamedChild("Label"), LEFT, -38, 0)
        equipIconControl:SetDimensions(34, 28)
    elseif skinSize == "Large" then
        iconControl:SetDimensions(48, 48)
        iconControl:ClearAnchors()
        iconControl:SetAnchor(CENTER, control:GetNamedChild("Label"), LEFT, -32, 0)
        equipIconControl:SetDimensions(36, 30)
    end
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

function GetBestItemCategoryDescription(itemData)

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

BETTERUI.Inventory.List = ZO_GamepadInventoryList:Subclass()

function BETTERUI.Inventory.List:New(...)
    local object = ZO_GamepadInventoryList.New(self, ...)
    return object
end

function BETTERUI.Inventory.List:Initialize(control, inventoryType, slotType, selectedDataCallback, entrySetupCallback, categorizationFunction, sortFunction, useTriggers, template, templateSetupFunction)
    self.control = control
    self.selectedDataCallback = selectedDataCallback
    self.entrySetupCallback = entrySetupCallback
    self.categorizationFunction = categorizationFunction
    self.sortFunction = BETTERUI_Inventory_DefaultItemSortComparator
    self.dataBySlotIndex = {}
    self.isDirty = true
    self.useTriggers = (useTriggers ~= false) -- nil => true
    self.template = template or DEFAULT_TEMPLATE
	
    if type(inventoryType) == "table" then
        self.inventoryTypes = inventoryType
    else
        self.inventoryTypes = { inventoryType }
    end
	
	local function VendorEntryTemplateSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
        ZO_Inventory_BindSlot(data, slotType, data.slotIndex, data.bagId)
        BETTERUI_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    end

    self.list = BETTERUI_VerticalParametricScrollList:New(self.control)
    self.list:AddDataTemplate(self.template, templateSetupFunction or VendorEntryTemplateSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)	
	self.list:AddDataTemplateWithHeader("ZO_GamepadItemSubEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality, "ZO_GamepadMenuEntryHeaderTemplate")

    -- generate the trigger keybinds so we can add/remove them later when necessary
    self.triggerKeybinds = {}
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.triggerKeybinds, self.list)

    local function SelectionChangedCallback(list, selectedData)
        if self.selectedDataCallback then
            self.selectedDataCallback(list, selectedData)
        end
        if selectedData then
            GAMEPAD_INVENTORY:PrepareNextClearNewStatus(selectedData)
            self:GetParametricList():RefreshVisible()
        end
    end

    local function OnEffectivelyShown()
        if self.isDirty then
            self:RefreshList()
        elseif self.selectedDataCallback then
            self.selectedDataCallback(self.list, self.list:GetTargetData())
        end
        self:Activate()
    end

    local function OnEffectivelyHidden()
        GAMEPAD_INVENTORY:TryClearNewStatusOnHidden()
        self:Deactivate()
    end

    local function OnInventoryUpdated(bagId)
        if bagId == self.inventoryType then
            self:RefreshList()
        end
    end

    local function OnSingleSlotInventoryUpdate(bagId, slotIndex)
        if bagId == self.inventoryType then
            local entry = self.dataBySlotIndex[slotIndex]
            if entry then
                local itemData = SHARED_INVENTORY:GenerateSingleSlotData(self.inventoryType, slotIndex)
                if itemData then
                    itemData.bestGamepadItemCategoryName = GetBestItemCategoryDescription(itemData)
					if self.inventoryType ~= BAG_VIRTUAL then -- virtual items don't have any champion points associated with them
						itemData.requiredChampionPoints = GetItemLinkRequiredChampionPoints(itemData)
					end
                    self:SetupItemEntry(entry, itemData)
                    self.list:RefreshVisible()
                else -- The item was removed.
                    self:RefreshList()
                end
            else -- The item is new.
                self:RefreshList()
            end
        end
    end

    self:SetOnSelectedDataChangedCallback(SelectionChangedCallback)

    self.control:SetHandler("OnEffectivelyShown", OnEffectivelyShown)
    self.control:SetHandler("OnEffectivelyHidden", OnEffectivelyHidden)

    SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", OnInventoryUpdated)
    SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", OnSingleSlotInventoryUpdate)
end

function BETTERUI.Inventory.List:AddSlotDataToTable(slotsTable, inventoryType, slotIndex)
    local itemFilterFunction = self.itemFilterFunction
    local categorizationFunction = self.categorizationFunction or ZO_InventoryUtils_Gamepad_GetBestItemCategoryDescription
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(inventoryType, slotIndex)
    if slotData then
        if (not itemFilterFunction) or itemFilterFunction(slotData) then
            -- itemData is shared in several places and can write their own value of bestItemCategoryName.
            -- We'll use bestGamepadItemCategoryName instead so there are no conflicts.
            slotData.bestGamepadItemCategoryName = categorizationFunction(slotData)

            table.insert(slotsTable, slotData)
        end
    end
end

-- this function is a VERY basic generic refresh, with no form of sorting or specific interface information
-- if you want to use BETTERUI.Inventory.List, it will be very useful if you OVERWRITE THIS METHOD!
function BETTERUI.Inventory.List:RefreshList()
    if self.control:IsHidden() then
        self.isDirty = true
        return
    end
    self.isDirty = false

    self.list:Clear()
    self.dataBySlotIndex = {}

    local slots = self:GenerateSlotTable()
    local currentBestCategoryName
    for i, itemData in ipairs(slots) do
        local entry = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
		self:SetupItemEntry(entry, itemData)
         if itemData.bestGamepadItemCategoryName ~= currentBestCategoryName then
            currentBestCategoryName = itemData.bestGamepadItemCategoryName
            entry:SetHeader(currentBestCategoryName)

            self.list:AddEntryWithHeader(ZO_GamepadItemSubEntryTemplate, entry)
        else
            self.list:AddEntry(self.template, entry)
        end

        self.dataBySlotIndex[itemData.slotIndex] = entry
    end

    self.list:Commit()
end
