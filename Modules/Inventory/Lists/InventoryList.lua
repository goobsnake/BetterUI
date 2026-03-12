--[[
File: Modules/Inventory/Lists/InventoryList.lua
Purpose: Handles the customized setup and display of inventory list entries.
         Works with the main Inventory class to render individual items.
Last Modified: 2026-01-26

KEY RESPONSIBILITIES:
1.  Entry Formatting (BETTERUI_SharedGamepadEntryLabelSetup):
    *   Styles text based on item state (Locked, BoP, Bound, Enchanted, Set Gear).
    *   Adds iconography (Stolen, Guild Trader, Enchantment, etc.) directly into the label.
    *   Handles font scaling and coloring based on selection or item quality.

2.  Item Setup (BETTERUI_SharedGamepadEntry_OnSetup):
    *   The main "render" function called for every row in the inventory.
    *   Populates columns: Item Type, Trait, Stat (Damage/Armor/Recipe), and Value.
    *   Optimizes performance by using cached values (cached_itemLink, etc.) from the main inventory loop.
    *   Handles dynamic icon sizing based on user font settings.

3.  Visual Indicators:
    *   BETTERUI_IconSetup: Manages the "New Item" status indicator and "Equipped" checkmarks.
    *   BETTERUI_Cooldown: Draws cooldown timers on items (e.g. potions).

4.  List Class (BETTERUI.Inventory.List):
    *   A subclass of ZO_GamepadInventoryList tailored for BetterUI.
    *   Uses BETTERUI_VerticalParametricScrollList for the actual scrolling mechanic.
    *   Handles list refreshes, data binding, and trigger keybinds.
]]



-- Default template for inventory list entries
local DEFAULT_TEMPLATE = "BETTERUI_GamepadItemSubEntryTemplate"

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
    return ZO_TableOrderingFunction(left, right, "bestGamepadItemCategoryName", DEFAULT_GAMEPAD_ITEM_SORT,
        ZO_SORT_ORDER_UP)
end

-- Inline status icon tuning for item labels.
-- These icons are embedded in text and therefore need visual-weight compensation.
local INLINE_STATUS_ICON_BASE_SIZE = BETTERUI.Inventory.CONST.ICON_SIZE_SMALL
local INLINE_STATUS_ICON_MIN_SIZE = 12
local INLINE_STATUS_ICON_MAX_SIZE = 32
local INLINE_STATUS_ICON_WEIGHT = {
    LOCKED = 1.1,
    BOP = 1.05,
    STOLEN = 1.0,
    UNBOUND = 1.2,
    ENCHANTED = 1.0,
    SET_ITEM = 1.0,
    RESEARCHABLE_TRAIT = 1.0,
    RECIPE_UNKNOWN = 1.0,
    BOOK_UNKNOWN = 1.0,
}

local function GetActiveListModuleName()
    if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
        return "Banking"
    end
    return "Inventory"
end

local function GetModuleSettings(moduleName)
    local modules = BETTERUI.Settings and BETTERUI.Settings.Modules
    if not modules then
        return nil
    end
    return modules[moduleName]
end

local function ShouldShowMarketPrice()
    local modules = BETTERUI.Settings and BETTERUI.Settings.Modules
    if not modules then
        return true
    end

    local generalInterfaceSettings = modules["GeneralInterface"]
    if generalInterfaceSettings and generalInterfaceSettings.showMarketPrice ~= nil then
        return generalInterfaceSettings.showMarketPrice
    end

    -- Legacy fallback for pre-migration saved variables.
    local inventorySettings = modules["Inventory"]
    if inventorySettings and inventorySettings.showMarketPrice ~= nil then
        return inventorySettings.showMarketPrice
    end

    return true
end

local function GetActiveNameFontSize(moduleName)
    local settings = GetModuleSettings(moduleName)
    if settings and settings.nameFontSize then
        return settings.nameFontSize
    end
    return BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function GetScaledInlineIconSize(fontSize, weightMultiplier)
    local baseFontSize = BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE
    local ratio = fontSize / baseFontSize
    local scaled = math.floor((INLINE_STATUS_ICON_BASE_SIZE * ratio * (weightMultiplier or 1.0)) + 0.5)
    return Clamp(scaled, INLINE_STATUS_ICON_MIN_SIZE, INLINE_STATUS_ICON_MAX_SIZE)
end

local function BuildInlineIconTag(texturePath, iconSize)
    return "|t" .. iconSize .. ":" .. iconSize .. ":" .. texturePath .. "|t"
end

local function GetIconToggleSetting(moduleSettings, key, defaultValue)
    if moduleSettings and moduleSettings[key] ~= nil then
        return moduleSettings[key]
    end
    return defaultValue
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
        -- Determine active module context (Inventory vs Banking)
        local moduleName = GetActiveListModuleName()
        local moduleSettings = GetModuleSettings(moduleName)
        local nameFontSize = GetActiveNameFontSize(moduleName)

        -- Determine which scene is active and use appropriate font settings
        local font
        if moduleName == "Banking" and BETTERUI.Banking and BETTERUI.Banking.GetNameFontDescriptor then
            font = BETTERUI.Banking.GetNameFontDescriptor()
        else
            font = BETTERUI.Inventory.GetNameFontDescriptor()
        end
        label:SetFont(font)

        if data.modifyTextType then
            label:SetModifyTextType(data.modifyTextType)
        end

        -- Early return for non-item entries (currency rows, headers)
        -- These don't have dataSource and would cause nil errors
        local dS = data.dataSource
        if not dS then
            -- Simple setup for currency/label entries
            label:SetText(data.text or data.label or "")
            local labelColor = data.labelColor or ZO_GAMEPAD_UNSELECTED_COLOR
            label:SetColor(labelColor:UnpackRGBA())
            return
        end

        local bagId = dS.bagId
        local slotIndex = dS.slotIndex
        local isLocked = dS.isPlayerLocked
        local isBoPTradeable = dS.isBoPTradeable

        local labelTxt = ""
        local lockIconSize = GetScaledInlineIconSize(nameFontSize, INLINE_STATUS_ICON_WEIGHT.LOCKED)
        local bopIconSize = GetScaledInlineIconSize(nameFontSize, INLINE_STATUS_ICON_WEIGHT.BOP)
        local stolenIconSize = GetScaledInlineIconSize(nameFontSize, INLINE_STATUS_ICON_WEIGHT.STOLEN)
        local unboundIconSize = GetScaledInlineIconSize(nameFontSize, INLINE_STATUS_ICON_WEIGHT.UNBOUND)
        local enchantedIconSize = GetScaledInlineIconSize(nameFontSize, INLINE_STATUS_ICON_WEIGHT.ENCHANTED)
        local setItemIconSize = GetScaledInlineIconSize(nameFontSize, INLINE_STATUS_ICON_WEIGHT.SET_ITEM)
        local researchableTraitIconSize = GetScaledInlineIconSize(nameFontSize,
            INLINE_STATUS_ICON_WEIGHT.RESEARCHABLE_TRAIT)
        local unknownRecipeIconSize = GetScaledInlineIconSize(nameFontSize, INLINE_STATUS_ICON_WEIGHT.RECIPE_UNKNOWN)
        local unknownBookIconSize = GetScaledInlineIconSize(nameFontSize, INLINE_STATUS_ICON_WEIGHT.BOOK_UNKNOWN)

        if isLocked then
            labelTxt = labelTxt .. BuildInlineIconTag(ZO_GAMEPAD_LOCKED_ICON_32, lockIconSize)
        end
        if isBoPTradeable then
            labelTxt = labelTxt .. BuildInlineIconTag(ZO_TRADE_BOP_ICON, bopIconSize)
        end

        labelTxt = labelTxt .. (data.text or data.name or "")

        if (data.stackCount > 1) then
            labelTxt = labelTxt .. zo_strformat(" |cFFFFFF(<<1>>)|r", data.stackCount)
        end

        local itemData = data.cached_itemLink or GetItemLink(bagId, slotIndex)

        local setItem = data.cached_setItem or GetItemLinkSetInfo(itemData, false)
        local hasEnchantment = data.cached_hasEnchantment or GetItemLinkEnchantInfo(itemData)

        local currentItemType = data.cached_itemType or GetItemLinkItemType(itemData)
        local isRecipeAndUnknown = data.cached_isRecipeAndUnknown
        if isRecipeAndUnknown == nil then
            isRecipeAndUnknown = (currentItemType == ITEMTYPE_RECIPE) and not IsItemLinkRecipeKnown(itemData)
            data.cached_isRecipeAndUnknown = isRecipeAndUnknown
            dS.cached_isRecipeAndUnknown = isRecipeAndUnknown
        end

        local isBookAndUnknown = data.cached_isBookAndUnknown
        if isBookAndUnknown == nil then
            local isBookType = (currentItemType == ITEMTYPE_BOOK or currentItemType == ITEMTYPE_LOREBOOK)
            if isBookType then
                local isBookKnown = data.cached_isBookKnown
                if isBookKnown == nil then
                    isBookKnown = IsItemLinkBookKnown(itemData)
                    data.cached_isBookKnown = isBookKnown
                    dS.cached_isBookKnown = isBookKnown
                end
                isBookAndUnknown = not isBookKnown
            else
                isBookAndUnknown = false
            end
            data.cached_isBookAndUnknown = isBookAndUnknown
            dS.cached_isBookAndUnknown = isBookAndUnknown
        end

        local isResearchableTrait = data.cached_isTraitResearchable
        if isResearchableTrait == nil then
            if type(CanItemLinkBeTraitResearched) == "function" then
                isResearchableTrait = CanItemLinkBeTraitResearched(itemData) == true
            else
                isResearchableTrait = false
            end
            data.cached_isTraitResearchable = isResearchableTrait
            dS.cached_isTraitResearchable = isResearchableTrait
        end

        local isUnbound = data.cached_isUnbound or
            (not IsItemBound(bagId, slotIndex) and not data.stolen and data.quality ~= ITEM_QUALITY_TRASH)

        if data.stolen then
            labelTxt = labelTxt .. " " .. BuildInlineIconTag(BETTERUI.CIM.CONST.ICONS.STOLEN, stolenIconSize)
        end
        if isUnbound and GetIconToggleSetting(moduleSettings, "showIconUnboundItem", true) then
            labelTxt = labelTxt .. " " .. BuildInlineIconTag(BETTERUI.CIM.CONST.ICONS.UNBOUND, unboundIconSize)
        end
        if hasEnchantment and GetIconToggleSetting(moduleSettings, "showIconEnchantment", true) then
            labelTxt = labelTxt .. " " .. BuildInlineIconTag(BETTERUI.CIM.CONST.ICONS.ENCHANTED, enchantedIconSize)
        end
        if setItem and GetIconToggleSetting(moduleSettings, "showIconSetGear", true) then
            labelTxt = labelTxt .. " " .. BuildInlineIconTag(BETTERUI.CIM.CONST.ICONS.SET_ITEM, setItemIconSize)
        end
        if isResearchableTrait and GetIconToggleSetting(moduleSettings, "showIconResearchableTrait", true) then
            labelTxt = labelTxt .. " " ..
                BuildInlineIconTag(BETTERUI.CIM.CONST.ICONS.RESEARCHABLE_TRAIT, researchableTraitIconSize)
        end
        if isRecipeAndUnknown and GetIconToggleSetting(moduleSettings, "showIconUnknownRecipe", true) then
            labelTxt = labelTxt .. " " .. BuildInlineIconTag(BETTERUI.CIM.CONST.ICONS.RECIPE_UNKNOWN, unknownRecipeIconSize)
        end
        if isBookAndUnknown and GetIconToggleSetting(moduleSettings, "showIconUnknownBook", true) then
            labelTxt = labelTxt .. " " .. BuildInlineIconTag(BETTERUI.CIM.CONST.ICONS.BOOK_UNKNOWN, unknownBookIconSize)
        end

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
    -- Guard against non-item entries (currency rows, headers)
    if not data or not data.dataSource then
        if statusIndicator then statusIndicator:ClearIcons() end
        if equippedIcon then equippedIcon:SetHidden(true) end
        return
    end

    statusIndicator:ClearIcons()

    local isItemNew
    if type(data.brandNew) == "function" then
        isItemNew = data.brandNew()
    else
        isItemNew = data.brandNew
    end

    if isItemNew and data.enabled then
        statusIndicator:SetTexture(BETTERUI.CONST.ICONS.NEW_ITEM)
        statusIndicator:SetHidden(false)
    end

    if data.isEquippedInCurrentCategory or data.isEquippedInAnotherCategory then
        local slotIndex = data.dataSource.slotIndex
        local equipType = data.dataSource.equipType
        if slotIndex == EQUIP_SLOT_BACKUP_MAIN or slotIndex == EQUIP_SLOT_BACKUP_OFF or slotIndex == EQUIP_SLOT_RING2 or slotIndex == EQUIP_SLOT_TRINKET2 or slotIndex == EQUIP_SLOT_BACKUP_POISON then
            equippedIcon:SetTexture(BETTERUI.CONST.ICONS.EQUIP_BACKUP)
        else
            equippedIcon:SetTexture(BETTERUI.CONST.ICONS.EQUIP_MAIN)
        end
        if equipType == EQUIP_TYPE_INVALID then
            equippedIcon:SetTexture(BETTERUI.CONST.ICONS.EQUIP_SLOT)
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
        -- Guard against non-item entries (currency rows, headers) that don't have item methods
        if not data.GetNumIcons then
            icon:ClearIcons()
            return
        end

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
function BETTERUI_Cooldown(control, remaining, duration, cooldownType, timeType, useLeadingEdge, alpha, desaturation,
                           preservePreviousCooldown)
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
            BETTERUI_Cooldown(control, remaining, duration, CD_TYPE_VERTICAL_REVEAL, CD_TIME_TYPE_TIME_UNTIL,
                USE_LEADING_EDGE, 1, 1, PRESERVE_PREVIOUS_COOLDOWN)
        else
            BETTERUI_Cooldown(control, remaining, duration, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL,
                DONT_USE_LEADING_EDGE, 0.85, 0, OVERWRITE_PREVIOUS_COOLDOWN)
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
--- 6. **Sizing**: Dynamically scales icons based on the active module's `nameFontSize`.
---
--- @param control table The UI control for the row.
--- @param data table The data item to display.
--- @param selected boolean True if the row is selected.
--- @param reselectingDuringRebuild boolean True if preserving selection during a list rebuild.
--- @param enabled boolean True if the row is enabled.
--- @param active boolean True if the row is active.
function BETTERUI_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    BETTERUI_SharedGamepadEntryLabelSetup(control.label, data, selected)
    local moduleName = GetActiveListModuleName()

    -- Use cached values for performance
    local bagId = data.bagId or (data.dataSource and data.dataSource.bagId)
    local slotIndex = data.slotIndex or (data.dataSource and data.dataSource.slotIndex)

    -- Early return for non-item entries (currency rows, headers)
    -- These have .label but no bagId/slotIndex for item data
    if not bagId and not slotIndex then
        return
    end

    local itemLink = data.cached_itemLink or (bagId and slotIndex and GetItemLink(bagId, slotIndex))
    local itemType = data.cached_itemType or (itemLink and GetItemLinkItemType(itemLink))

    -- Determine which scene is active and use appropriate column font settings
    local columnFont
    if moduleName == "Banking" and BETTERUI.Banking and BETTERUI.Banking.GetColumnFontDescriptor then
        columnFont = BETTERUI.Banking.GetColumnFontDescriptor()
    else
        columnFont = BETTERUI.Inventory.GetColumnFontDescriptor()
    end

    local itemTypeControl = control:GetNamedChild("ItemType")
    local traitControl = control:GetNamedChild("Trait")
    local statControl = control:GetNamedChild("Stat")
    local valueControl = control:GetNamedChild("Value")
    if not itemTypeControl or not traitControl or not statControl or not valueControl then return end

    -- Apply column font
    itemTypeControl:SetFont(columnFont)
    traitControl:SetFont(columnFont)
    statControl:SetFont(columnFont)
    valueControl:SetFont(columnFont)

    -- Set item type
    itemTypeControl:SetText(string.upper(data.bestItemTypeName))

    -- Set trait information
    local traitName = data.cached_traitName
    if not traitName then
        local traitType = GetItemTrait(bagId, slotIndex)
        if traitType ~= ITEM_TRAIT_TYPE_NONE then
            traitName = string.upper(GetString("SI_ITEMTRAITTYPE", traitType))
        else
            traitName = "-"
        end
    end
    traitControl:SetText(traitName)

    -- Set stat information based on item type
    local statText
    if itemType == ITEMTYPE_RECIPE then
        local isUnknown = data.cached_isRecipeAndUnknown
        if isUnknown == nil then
            isUnknown = not IsItemLinkRecipeKnown(itemLink)
        end
        statText = isUnknown and GetString(SI_BETTERUI_INV_RECIPE_UNKNOWN) or
            GetString(SI_BETTERUI_INV_RECIPE_KNOWN)
    elseif data.cached_isBook or itemType == ITEMTYPE_BOOK or itemType == ITEMTYPE_LOREBOOK or itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        local isKnown = data.cached_isBookKnown
        if isKnown == nil then
            isKnown = IsItemLinkBookKnown(itemLink)
        end
        statText = isKnown and GetString(SI_BETTERUI_INV_RECIPE_KNOWN) or
            GetString(SI_BETTERUI_INV_RECIPE_UNKNOWN)
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
    if ShouldShowMarketPrice() and
        (BETTERUI.CIM.Utils.IsBankingSceneShowing() or BETTERUI.CIM.Utils.IsInventorySceneShowing()) then
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

    -- Hide original highlight - we use our custom gradient selection bar instead
    if control.highlight then
        control.highlight:SetHidden(true)
    end

    -- Apply gradient selection bar
    BETTERUI.CIM.SelectionHighlight.Setup(control, selected)


    -- Show selection indicator for multi-selected items
    local selectionIndicator = control:GetNamedChild("SelectionIndicator")
    local selectionBar = control:GetNamedChild("SelectionBar")
    local isMultiSelected = false

    -- Check with MultiSelectManager if available
    local multiSelectManager = BETTERUI.CIM.MultiSelectManager
    if multiSelectManager and multiSelectManager.GetActiveInstance then
        local manager = multiSelectManager.GetActiveInstance()
        if manager and manager:IsActive() then
            isMultiSelected = manager:IsSelected(data)
        end
    end

    -- Handle selection indicator (checkmark)
    if selectionIndicator then
        selectionIndicator:SetHidden(not isMultiSelected)
        if isMultiSelected then
            -- Color the checkmark green for visibility
            selectionIndicator:SetColor(0.2, 0.9, 0.2, 1)
        end
    end

    -- Handle SelectionBar color based on multi-select state
    -- CRITICAL: Must reset color when NOT multi-selected to handle control recycling.
    -- Controls are pooled and reused - the green color would persist on recycled controls otherwise.
    if selectionBar then
        if isMultiSelected then
            selectionBar:SetHidden(false)
            selectionBar:SetColor(0.2, 0.8, 0.3, 0.6) -- Green tint for multi-selected
        elseif selected then
            -- Reset to default gold color for focused non-multi-selected items
            -- Default gold from XML: #C4A64D = (196/255, 166/255, 77/255) ≈ (0.77, 0.65, 0.30)
            selectionBar:SetColor(0.77, 0.65, 0.30, 0.45)
        end
        -- Note: When not selected and not multi-selected, SelectionHighlight.Setup already hides the bar
    end

    BETTERUI_CooldownSetup(control, data)
    BETTERUI_IconSetup(control:GetNamedChild("StatusIndicator"), control:GetNamedChild("EquippedMain"), data)

    -- Adjust icon dimensions based on active scene/module name font size setting
    local iconControl = control:GetNamedChild("Icon")
    local equipIconControl = control:GetNamedChild("EquippedMain")
    local fontSize = GetActiveNameFontSize(moduleName)



    -- Calculate icon dimensions based on font size (scales proportionally from default of 24px = 34px icon)
    local iconSize = math.floor(BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_SIZE *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) +
        0.5)
    -- Calculate equip icon dimensions (scales proportionally with font size)
    local equipIconWidth = math.floor(BETTERUI.Inventory.CONST.EQUIP_ICON_BASE_WIDTH *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) + 0.5)
    local equipIconHeight = math.floor(BETTERUI.Inventory.CONST.EQUIP_ICON_BASE_HEIGHT *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) + 0.5)
    local iconOffset = math.floor(BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_OFFSET +
        (fontSize - BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) *
        BETTERUI.Inventory.CONST.LIST_ENTRY_ICON_OFFSET_FACTOR + 0.5) -- Adjust offset as font grows

    iconControl:SetDimensions(iconSize, iconSize)
    iconControl:ClearAnchors()
    iconControl:SetAnchor(CENTER, control:GetNamedChild("Label"), LEFT, iconOffset, 0)
    equipIconControl:SetDimensions(equipIconWidth, equipIconHeight)
end

--- SHARED HELPER FUNCTIONS
--- Note: GetCategoryTypeFromWeaponType and GetBestItemCategoryDescription have been
--- consolidated into CIM/CategoryDefinitions.lua to eliminate code duplication
--- between Banking and Inventory modules.
local GetCategoryTypeFromWeaponType = BETTERUI.Inventory.Categories.GetCategoryTypeFromWeaponType

--- Determines the best display category for an item (e.g., "One-Handed", "Heavy Armor").
---
--- Purpose: Helper for sorting and categorization logic.
--- Note: Uses shared implementation from CIM/CategoryDefinitions.lua
---
--- @param itemData table The item data.
--- @return string The localized category description.
function GetBestItemCategoryDescription(itemData)
    return BETTERUI.Inventory.Categories.GetBestItemCategoryDescription(itemData)
end

-- Class: BETTERUI.Inventory.List (extends ZO_GamepadInventoryList)
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
function BETTERUI.Inventory.List:Initialize(control, inventoryType, slotType, selectedDataCallback, entrySetupCallback,
                                            categorizationFunction, sortFunction, useTriggers, template,
                                            templateSetupFunction)
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
    self.list:AddDataTemplate(self.template, templateSetupFunction or VendorEntryTemplateSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction)
    self.list:AddDataTemplateWithHeader("ZO_GamepadItemSubEntryTemplate", ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality, "ZO_GamepadMenuEntryHeaderTemplate")

    -- Use BetterUI custom trigger keybinds with Inventory-specific speed and enabled getters
    local leftTrigger, rightTrigger = BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(
        self.list, nil, function()
            return BETTERUI.Inventory.GetSetting("triggerSpeed")
        end, function()
            return BETTERUI.Inventory.GetSetting("useTriggersForSkip")
        end
    )
    self.triggerKeybinds = { leftTrigger, rightTrigger }

    -- Initialize scroll indicator on the list's internal control
    -- offsetX=5, offsetTopY=-8 (above list top), offsetBottomY=-10 (above footer top)
    -- Note: List BOTTOMRIGHT is anchored 10px below FooterContainerFooter's top,
    -- so offsetBottomY=-10 aligns the container bottom with the footer's top edge.
    local listScrollControl = self.list and self.list.control
    if listScrollControl then
        BETTERUI.CIM.ScrollIndicator.Initialize(listScrollControl, 5, -8, -10, self.list)
    end

    local function SelectionChangedCallback(list, selectedData)
        if self.selectedDataCallback then
            self.selectedDataCallback(list, selectedData)
        end
        if selectedData then
            GAMEPAD_INVENTORY:PrepareNextClearNewStatus(selectedData)
            self:GetParametricList():RefreshVisible()
            -- Update scroll indicator position
            -- Use targetSelectedIndex (the intended final position) rather than GetSelectedIndex()
            -- (the animated intermediate) to prevent the thumb from stopping short of the bottom
            local listCtrl = self.list and self.list.control
            if listCtrl then
                local currentIndex = list.targetSelectedIndex or list:GetSelectedIndex() or 1
                local totalItems = list:GetNumEntries() or 0
                local visibleItems = 15 -- Approximate visible items in inventory list
                BETTERUI.CIM.ScrollIndicator.Update(listCtrl, currentIndex, totalItems, visibleItems)
            end
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
    local categorizationFunction = self.categorizationFunction or
        BETTERUI.Inventory.Categories.GetBestItemCategoryDescription
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

    -- Update scroll indicator after list refresh
    -- Use targetSelectedIndex for the intended position rather than animated intermediate
    local listCtrl = self.list and self.list.control
    if listCtrl then
        local currentIndex = self.list.targetSelectedIndex or self.list:GetSelectedIndex() or 1
        local totalItems = self.list:GetNumEntries() or 0
        local visibleItems = 15 -- Approximate visible items in inventory list
        BETTERUI.CIM.ScrollIndicator.Update(listCtrl, currentIndex, totalItems, visibleItems)
    end
end
