--------------------------------------------------------------------------------
-- BetterUI Inventory List Module
--
-- This file handles the customized setup and display of inventory list entries.
-- It works in conjunction with the main Inventory class to render individual items.
--
-- KEY RESPONSIBILITIES:
--
-- 1.  **Entry Formatting (`BETTERUI_SharedGamepadEntryLabelSetup`)**:
--     *   Styles text based on item state (Locked, BoP, Bound, Enchanted, Set Gear).
--     *   Adds iconography (Stolen, Guild Trader, Enchantment, etc.) directly into the label.
--     *   Handles font scaling and coloring based on selection or item quality.
--
-- 2.  **Item Setup (`BETTERUI_SharedGamepadEntry_OnSetup`)**:
--     *   The main "render" function called for every row in the inventory.
--     *   Populates columns: Item Type, Trait, Stat (Damage/Armor/Recipe), and Value.
--     *   Optimizes performance by using cached values (`cached_itemLink`, etc.) from the main inventory loop.
--     *   Handles dynamic icon sizing based on user font settings.
--
-- 3.  **Visual Indicators**:
--     *   `BETTERUI_IconSetup`: Manages the "New Item" status indicator and "Equipped" checkmarks.
--     *   `BETTERUI_Cooldown`: Draws cooldown timers on items (e.g. potions).
--
-- 4.  **List Class (`BETTERUI.Inventory.List`)**:
--     *   A subclass of `ZO_GamepadInventoryList` tailored for BetterUI.
--     *   Uses `BETTERUI_VerticalParametricScrollList` for the actual scrolling mechanic.
--     *   Handles list refreshes, data binding, and trigger keybinds.
--
-- TODO(optimization): BETTERUI_SharedGamepadEntry_OnSetup is called per-row per-frame during scrolling.
--                     Consider caching more computed values to reduce GetItemLink/GetItemTrait calls.
-- TODO(cleanup): Icon path constants at top should use a centralized icon registry
--------------------------------------------------------------------------------

local TEXTURE_EQUIP_ICON = "BetterUI/Modules/CIM/Images/inv_equip.dds"
local TEXTURE_EQUIP_BACKUP_ICON = "BetterUI/Modules/CIM/Images/inv_equip_backup.dds"
local TEXTURE_EQUIP_SLOT_ICON = "BetterUI/Modules/CIM/Images/inv_equip_quickslot.dds"
local NEW_ICON_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_new.dds"


 
local DEFAULT_GAMEPAD_ITEM_SORT =
{
    bestGamepadItemCategoryName = { tiebreaker = "name" },
    name = { tiebreaker = "requiredLevel" },
    requiredLevel = { tiebreaker = "requiredChampionPoints", isNumeric = true },
    requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
    iconFile = { tiebreaker = "uniqueId" },
    uniqueId = { isId64 = true },
}

--- Default item sort comparator for gamepad inventory.
---
--- Purpose: Sorts items based on Best Category Name -> Name -> Level -> Champion Points -> Icon -> ID.
--- Mechanics: Uses `ZO_TableOrderingFunction` with `DEFAULT_GAMEPAD_ITEM_SORT`.
---
--- @param left table: Left item data
--- @param right table: Right item data
--- @return boolean: True if left should come before right
function BETTERUI_Inventory_DefaultItemSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "bestGamepadItemCategoryName", DEFAULT_GAMEPAD_ITEM_SORT, ZO_SORT_ORDER_UP)
end




--- Sets up the label for a shared gamepad entry, including styling, icons, and colors.
---
--- Purpose: Formats the main text label for an inventory item.
--- Mechanics:
--- 1. **Fonts**: Selects font based on scene (Banking vs Inventory).
--- 2. **Status Icons**: Prepends icons for Locked, BoP, Stolen, Guild Trader, Enchanted, Set Item, Unknown Recipe.
--- 3. **Text**: Appends Stack Count.
--- 4. **Color**: Sets text color based on item quality or selection state.
---
--- @param label table The label control.
--- @param data table The data for the entry.
--- @param selected boolean True if the entry is selected.
function BETTERUI_SharedGamepadEntryLabelSetup(label, data, selected)

    if label then
    	-- Determine which scene is active and use appropriate font settings
    	local font
    	if SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
    		font = BETTERUI.Banking.GetNameFontDescriptor()
    	else
    		font = BETTERUI.Inventory.GetNameFontDescriptor()
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

--- Configures the status indicator (New icon) and equipped icon for an entry.
---
--- Purpose: Visual feedback for item state.
--- Mechanics:
--- - Checks `data.brandNew` to show "New" icon.
--- - Checks `data.isEquippedInCurrentCategory` / `dataSource.equipSlot` to show Equipped icons.
--- - Distinguishes between Main Hand, Backup Hand, and Quickslots.
---
--- @param statusIndicator table The control for the status indicator (New item icon).
--- @param equippedIcon table The control for the equipped icon (Main, Backup, Quickslot).
--- @param data table The data for the entry.
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

--- Sets up the main icon for a shared gamepad entry, including stacking counts and cooldown overlays.
---
--- Purpose: Renders the primary item icon.
--- Mechanics:
--- - Sets Texture from `data:GetIcon`.
--- - Handles Desaturation/Coloring (Red if unusable).
--- - Applies selection tinting.
---
--- @param icon table The icon control.
--- @param stackCountLabel table The label for the stack count.
--- @param data table The data for the entry.
--- @param selected boolean True if the entry is selected.
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

--- Applies a visual cooldown effect to a control.
---
--- Purpose: Renders the radial or vertical swipe for cooldowns.
--- Mechanics: Wraps `control.cooldown:StartCooldown`.
---
--- @param control table The control to apply the cooldown to.
--- @param remaining number The remaining time in milliseconds.
--- @param duration number The total duration in milliseconds.
--- @param cooldownType number The visual type of the cooldown (e.g., radial, vertical).
--- @param timeType number The time type (e.g., time until).
--- @param useLeadingEdge boolean Whether to show a leading edge visual.
--- @param alpha number The transparency of the cooldown overlay.
--- @param desaturation number The desaturation level.
--- @param preservePreviousCooldown boolean Whether to keep the existing cooldown if active.
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

--- High-level setup for cooldown indicators on an item entry.
--- @param control table The control (usually the row control).
--- @param data table The data containing cooldown information.
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

--- Configures a shared gamepad inventory entry (row).
---
--- Purpose: **The Main Render Function**. Populates all displayed data for a row.
--- Mechanics:
--- 1. **Label**: Calls `BETTERUI_SharedGamepadEntryLabelSetup`.
--- 2. **Cache**: Uses cached `itemLink`, `itemType` to reduce API overhead.
--- 3. **Columns**: Populates Item Type, Trait, Stat (Damage/Armor/Known), and Value.
--- 4. **Market Price**: Fetches MasterMerchant/TTC price if enabled.
--- 5. **Icons**: Calls `BETTERUI_SharedGamepadEntryIconSetup`.
--- 6. **Sizing**: Dynamically scales icons based on `invSettings.nameFontSize`.
---
--- @param control table The UI control for the row.
--- @param data table The data item to display.
--- @param selected boolean True if the row is selected.
--- @param reselectingDuringRebuild boolean True if preserving selection during a list rebuild.
--- @param enabled boolean True if the row is enabled.
--- @param active boolean True if the row is active.
function BETTERUI_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    BETTERUI_SharedGamepadEntryLabelSetup(control.label, data, selected)

    -- Use cached values for performance
    local bagId = data.bagId or (data.dataSource and data.dataSource.bagId)
    local slotIndex = data.slotIndex or (data.dataSource and data.dataSource.slotIndex)

    local itemLink = data.cached_itemLink or (bagId and slotIndex and GetItemLink(bagId, slotIndex))
    local itemType = data.cached_itemType or (itemLink and GetItemLinkItemType(itemLink))
    
    -- Determine which scene is active and use appropriate column font settings
    local columnFont
    if SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
    	columnFont = BETTERUI.Banking.GetColumnFontDescriptor()
    else
    	columnFont = BETTERUI.Inventory.GetColumnFontDescriptor()
    end

    local itemTypeControl = control:GetNamedChild("ItemType")
    local traitControl = control:GetNamedChild("Trait")
    local statControl = control:GetNamedChild("Stat")
    local valueControl = control:GetNamedChild("Value")

    -- Apply column font
    itemTypeControl:SetFont(columnFont)
    traitControl:SetFont(columnFont)
    statControl:SetFont(columnFont)
    valueControl:SetFont(columnFont)

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
            valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(math.floor(marketPrice)))
        else
            valueControl:SetColor(1, 1, 1, 1)
            valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(data.stackSellPrice))
        end
    else
        valueControl:SetColor(1, 1, 1, 1)
        valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(data.stackSellPrice))
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

    -- Adjust icon dimensions based on inventory font size setting
    local iconControl = control:GetNamedChild("Icon")
    local equipIconControl = control:GetNamedChild("EquippedMain")
    local invSettings = BETTERUI.Settings.Modules["Inventory"]
    local fontSize = invSettings and invSettings.nameFontSize or 24
    
    -- Handle legacy string values (for backwards compatibility)
    if type(fontSize) == "string" then
        local legacyMap = { Small = 20, Default = 24, Medium = 28, Large = 32, XLarge = 36 }
        fontSize = legacyMap[fontSize] or 24
    end
    
    -- Calculate icon dimensions based on font size (scales proportionally from default of 24px = 34px icon)
    local baseIconSize = 34
    local baseFontSize = 24
    local iconSize = math.floor(baseIconSize * (fontSize / baseFontSize) + 0.5)
    local equipIconWidth = math.floor(28 * (fontSize / baseFontSize) + 0.5)
    local equipIconHeight = math.floor(24 * (fontSize / baseFontSize) + 0.5)
    local iconOffset = math.floor(-42 + (fontSize - baseFontSize) * 0.4 + 0.5)  -- Adjust offset as font grows
    
    iconControl:SetDimensions(iconSize, iconSize)
    iconControl:ClearAnchors()
    iconControl:SetAnchor(CENTER, control:GetNamedChild("Label"), LEFT, iconOffset, 0)
    equipIconControl:SetDimensions(equipIconWidth, equipIconHeight)
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

--- Determines the best display category for an item (e.g., "One-Handed", "Heavy Armor").
---
--- Purpose: Helper for sorting and categorization logic.
--- Mechanics:
--- - Checks for Stolen, InvalidEquip, Weapons, Armor.
--- - Combines Item Type + Equip Type (e.g. "Poison" vs "Alchemical Poison").
---
--- @param itemData table The item data.
--- @return string The localized category description.
function GetBestItemCategoryDescription(itemData)

    local isItemStolen = IsItemStolen(itemData.bagId, itemData.slotIndex)

    if isItemStolen then
        return GetString(SI_BETTERUI_STOLEN)
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

--- @class BETTERUI.Inventory.List : ZO_GamepadInventoryList
BETTERUI.Inventory.List = ZO_GamepadInventoryList:Subclass()

function BETTERUI.Inventory.List:New(...)
    local object = ZO_GamepadInventoryList.New(self, ...)
    return object
end

--- Initializes the inventory list.
---
--- Purpose: Sets up the parametric scroll list, data templates, and update callbacks.
--- Mechanics:
--- - Creates `BETTERUI_VerticalParametricScrollList`.
--- - Registers `VendorEntryTemplateSetup` (wraps `BETTERUI_SharedGamepadEntry_OnSetup`).
--- - Connects to `SHARED_INVENTORY` for real-time updates.
---
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

--- Populates the slot table with item data from the inventory.
---
--- Purpose: Filters and accepts items for the list.
--- Mechanics:
--- - Iterates inventory slots via `SHARED_INVENTORY:GenerateSingleSlotData`.
--- - Applies `itemFilterFunction`.
--- - Calcualtes `bestGamepadItemCategoryName` for headers.
---
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

--- Refreshes the inventory list.
---
--- Purpose: Rebuilds the visual list from source data.
--- Mechanics:
--- 1. Clears current list.
--- 2. Generates new Slot Table (`AddSlotDataToTable`).
--- 3. Creates `ZO_GamepadEntryData` wrappers.
--- 4. Adds entries to the Parametric List (with Headers where applicable).
--- 5. Commits (renders) the list.
---
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
