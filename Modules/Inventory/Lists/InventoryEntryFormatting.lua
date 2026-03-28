--[[
File: Modules/Inventory/Lists/InventoryEntryFormatting.lua
Purpose: Entry formatting, label styling, icon setup, and cooldown rendering
         for inventory and banking list entries.
Extracted from: Modules/Inventory/Lists/InventoryList.lua

KEY RESPONSIBILITIES:
1.  Entry Label Formatting (BETTERUI_SharedGamepadEntryLabelSetup):
    *   Styles text based on item state (Locked, BoP, Bound, Enchanted, Set Gear).
    *   Adds inline iconography (Stolen, Guild Trader, Enchantment, etc.).
    *   Handles font scaling and coloring based on selection or item quality.

2.  Icon Setup (BETTERUI_SharedGamepadEntryIconSetup):
    *   Renders the primary item icon with desaturation and tinting.

3.  Status Indicators (BETTERUI_IconSetup):
    *   Manages the "New Item" status indicator and "Equipped" checkmarks.

4.  Cooldown Rendering (ApplyCooldown, BETTERUI_CooldownSetup):
    *   Draws cooldown timers on items (e.g. potions).
]]

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
    if BETTERUI.Utils.IsBankingSceneShowing() then
        return "Banking"
    end
    return "Inventory"
end

local GetModuleSettings = BETTERUI.GetModuleSettings

local function ShouldShowMarketPrice()
    local generalInterfaceSettings = GetModuleSettings("GeneralInterface")
    if generalInterfaceSettings.showMarketPrice ~= nil then
        return generalInterfaceSettings.showMarketPrice
    end

    -- Legacy fallback for pre-migration saved variables.
    local inventorySettings = GetModuleSettings("Inventory")
    if inventorySettings.showMarketPrice ~= nil then
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

local function GetScaledInlineIconSize(fontSize, weightMultiplier)
    local baseFontSize = BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE
    local ratio = fontSize / baseFontSize
    local scaled = math.floor((INLINE_STATUS_ICON_BASE_SIZE * ratio * (weightMultiplier or 1.0)) + 0.5)
    return zo_clamp(scaled, INLINE_STATUS_ICON_MIN_SIZE, INLINE_STATUS_ICON_MAX_SIZE)
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
--- Purpose: Formats the main text label for an inventory item.
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
--- Purpose: Visual feedback for item state.
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
        statusIndicator:SetTexture(BETTERUI.CIM.CONST.ICONS.NEW_ITEM)
        statusIndicator:SetHidden(false)
    end

    if data.isEquippedInCurrentCategory or data.isEquippedInAnotherCategory then
        local slotIndex = data.dataSource.slotIndex
        local equipType = data.dataSource.equipType
        if slotIndex == EQUIP_SLOT_BACKUP_MAIN or slotIndex == EQUIP_SLOT_BACKUP_OFF or slotIndex == EQUIP_SLOT_RING2 or slotIndex == EQUIP_SLOT_TRINKET2 or slotIndex == EQUIP_SLOT_BACKUP_POISON then
            equippedIcon:SetTexture(BETTERUI.CIM.CONST.ICONS.EQUIP_BACKUP)
        else
            equippedIcon:SetTexture(BETTERUI.CIM.CONST.ICONS.EQUIP_MAIN)
        end
        if equipType == EQUIP_TYPE_INVALID then
            equippedIcon:SetTexture(BETTERUI.CIM.CONST.ICONS.EQUIP_SLOT)
        end
        equippedIcon:SetHidden(false)
    else
        equippedIcon:SetHidden(true)
    end
end

--- Sets up the main icon for a shared gamepad entry, including stacking counts and cooldown overlays.
--- Purpose: Renders the primary item icon.
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
--- Cooldown display style presets.
local COOLDOWN_STYLE = {
    VERTICAL = {
        cooldownType = CD_TYPE_VERTICAL_REVEAL,
        timeType = CD_TIME_TYPE_TIME_UNTIL,
        useLeadingEdge = USE_LEADING_EDGE,
        alpha = 1,
        desaturation = 1,
        preservePreviousCooldown = PRESERVE_PREVIOUS_COOLDOWN,
    },
    RADIAL = {
        cooldownType = CD_TYPE_RADIAL,
        timeType = CD_TIME_TYPE_TIME_UNTIL,
        useLeadingEdge = DONT_USE_LEADING_EDGE,
        alpha = 0.85,
        desaturation = 0,
        preservePreviousCooldown = OVERWRITE_PREVIOUS_COOLDOWN,
    },
}

--- Applies a cooldown visual to a control using a style preset.
local function ApplyCooldown(control, remaining, duration, style)
    local inCooldownNow = remaining > 0 and duration > 0
    if inCooldownNow then
        local timeLeftOnPreviousCooldown = control.cooldown:GetTimeLeft()
        if not style.preservePreviousCooldown or timeLeftOnPreviousCooldown == 0 then
            control.cooldown:SetDesaturation(style.desaturation)
            control.cooldown:SetAlpha(style.alpha)
            control.cooldown:StartCooldown(remaining, duration, style.cooldownType, style.timeType, style.useLeadingEdge)
        end
    else
        control.cooldown:ResetCooldown()
    end
    control.cooldown:SetHidden(not inCooldownNow)
end

--- High-level setup for cooldown indicators on an item entry.
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
            ApplyCooldown(control, remaining, duration, COOLDOWN_STYLE.VERTICAL)
        else
            ApplyCooldown(control, remaining, duration, COOLDOWN_STYLE.RADIAL)
        end
    end
end

-- Re-export helper functions used by InventoryList.lua's OnSetup function.
-- These must be accessible as upvalues are file-scoped.
BETTERUI.Inventory._EntryFormatting = {
    GetActiveListModuleName = GetActiveListModuleName,
    GetModuleSettings = GetModuleSettings,
    ShouldShowMarketPrice = ShouldShowMarketPrice,
    GetActiveNameFontSize = GetActiveNameFontSize,
}
