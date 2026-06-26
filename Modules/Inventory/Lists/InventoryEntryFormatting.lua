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
--- @type table<string, number> Visual weight multipliers for inline status icons
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

--- Returns whether a BetterUI module instance currently owns a visible scene.
--- @param moduleRoot BetterUIModuleRoot|table|nil
--- @return boolean showing
local function IsModuleSceneShowing(moduleRoot)
    local instance = moduleRoot and moduleRoot.instance
    local isSceneShowing = instance and instance.IsSceneShowing
    if type(isSceneShowing) ~= "function" then
        return false
    end
    return instance:IsSceneShowing()
end

--- @return BetterUIListModuleName moduleName
local function GetActiveListModuleName()
    if BETTERUI.Utils.IsBankingSceneShowing() then
        return "Banking"
    end
    if IsModuleSceneShowing(BETTERUI.Vendor) then
        return "Vendor"
    end
    if IsModuleSceneShowing(BETTERUI.Companions) then
        return "Companions"
    end
    if IsModuleSceneShowing(BETTERUI.TradingHouse) then
        return "TradingHouse"
    end
    return "Inventory"
end

--- @param data BetterUIInventoryEntryLike|nil
--- @return BetterUIListModuleName moduleName
local function ResolveEntryModuleName(data)
    ---@type BetterUIInventoryEntryLike|nil
    local itemData = data and (data.dataSource or data) or nil
    local moduleName = (itemData and (itemData.listModuleName or itemData.moduleName))
        or (data and (data.listModuleName or data.moduleName))
    if type(moduleName) == "string" and moduleName ~= "" then
        return moduleName
    end
    return GetActiveListModuleName()
end

local GetModuleSettings = BETTERUI.GetModuleSettings

--- @return boolean show Whether market prices should be shown
local function ShouldShowMarketPrice()
    ---@type BetterUIGeneralInterfaceSettings
    local generalInterfaceSettings = GetModuleSettings("GeneralInterface")
    if generalInterfaceSettings.showMarketPrice ~= nil then
        return generalInterfaceSettings.showMarketPrice
    end

    return true
end

--- @param moduleName BetterUIListModuleName Module name for the active list surface
--- @return number fontSize
local function GetActiveNameFontSize(moduleName)
    ---@type BetterUIListModuleSettings
    local settings = GetModuleSettings(moduleName)
    if settings and settings.nameFontSize then
        return settings.nameFontSize
    end
    return BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE
end

--- @param fontSize number Current font size
--- @param weightMultiplier number|nil Icon weight multiplier
--- @return number iconSize Scaled and clamped icon size
local function GetScaledInlineIconSize(fontSize, weightMultiplier)
    local baseFontSize = BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE
    local ratio = fontSize / baseFontSize
    local scaled = math.floor((INLINE_STATUS_ICON_BASE_SIZE * ratio * (weightMultiplier or 1.0)) + 0.5)
    return zo_clamp(scaled, INLINE_STATUS_ICON_MIN_SIZE, INLINE_STATUS_ICON_MAX_SIZE)
end

--- @param texturePath string DDS texture path for the icon
--- @param iconSize number Size in pixels
--- @return string tag Inline texture tag string
local function BuildInlineIconTag(texturePath, iconSize)
    return "|t" .. iconSize .. ":" .. iconSize .. ":" .. texturePath .. "|t"
end

--- @param moduleSettings BetterUIListModuleSettings|nil Module settings table
--- @param key string Setting key
--- @param defaultValue boolean Default value if not set
--- @return boolean
local function GetIconToggleSetting(moduleSettings, key, defaultValue)
    if moduleSettings and moduleSettings[key] ~= nil then
        return moduleSettings[key]
    end
    return defaultValue
end

--- Sets up the label for a shared gamepad entry, including styling, icons, and colors.
--- @param label table UI label control
--- @param data BetterUIInventoryEntryData ZO_GamepadEntryData with dataSource
--- @param selected boolean Whether the entry is currently selected
function BETTERUI_SharedGamepadEntryLabelSetup(label, data, selected)
    if label then
        -- Determine active module context (Inventory vs Banking)
        local moduleName = ResolveEntryModuleName(data)
        ---@type BetterUIListModuleSettings
        local moduleSettings = GetModuleSettings(moduleName)
        local nameFontSize = GetActiveNameFontSize(moduleName)

        -- Determine which scene is active and use appropriate font settings
        local sharedItemSupport = BETTERUI.CIM and BETTERUI.CIM.SharedItemSupport
        local font = sharedItemSupport
            and sharedItemSupport.ResolveNameFontDescriptor(moduleName, "Inventory")
            or BETTERUI.Inventory.GetNameFontDescriptor()
        label:SetFont(font)

        if data.modifyTextType then
            label:SetModifyTextType(data.modifyTextType)
        end

        -- Early return for non-item entries (currency rows, headers)
        -- These don't have dataSource and would cause nil errors
        ---@type BetterUIInventoryRowData|nil
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

        local hasBagSlot = bagId ~= nil and slotIndex ~= nil
        local itemData = data.cached_itemLink or dS.cached_itemLink
        if not itemData and hasBagSlot then
            itemData = GetItemLink(bagId, slotIndex)
        end

        if not itemData or itemData == "" then
            label:SetText(labelTxt)
            local labelColor = data:GetNameColor(selected)
            if type(labelColor) == "function" then
                labelColor = labelColor(data)
            end
            label:SetColor(labelColor:UnpackRGBA())
            return
        end

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
            -- U50: there is no ITEMTYPE for loose books; motif books are the only
            -- inventory item type answerable via IsItemLinkBookKnown.
            local isBookType = (currentItemType == ITEMTYPE_RACIAL_STYLE_MOTIF)
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

        local isUnbound = data.cached_isUnbound
        if isUnbound == nil then
            isUnbound = hasBagSlot
                and not IsItemBound(bagId, slotIndex)
                and not data.stolen
                and data.quality ~= ITEM_QUALITY_TRASH
        end

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
---@param statusIndicator table Status indicator control
---@param equippedIcon table Equipped icon control
---@param data BetterUIInventoryEntryData ZO_GamepadEntryData with dataSource
---@return nil
function BETTERUI_IconSetup(statusIndicator, equippedIcon, data)
    local function ClearTexture(control)
        if not (control and control.SetTexture) then
            return
        end
        local ok = pcall(control.SetTexture, control, nil)
        if not ok then
            pcall(control.SetTexture, control, "")
        end
    end

    local function ClearStatusIndicator()
        if statusIndicator and statusIndicator.ClearIcons then
            statusIndicator:ClearIcons()
        end
        ClearTexture(statusIndicator)
        if statusIndicator and statusIndicator.SetHidden then
            statusIndicator:SetHidden(true)
        end
    end

    local function HideEquippedIcon()
        ClearTexture(equippedIcon)
        if equippedIcon and equippedIcon.SetHidden then
            equippedIcon:SetHidden(true)
        end
    end

    local function IsControlVisible(control)
        if control and control.IsHidden then
            local ok, hidden = pcall(control.IsHidden, control)
            if ok then
                return hidden == false
            end
        end
        return false
    end

    -- Guard against non-item entries (currency rows, headers)
    if not data or not data.dataSource then
        ClearStatusIndicator()
        HideEquippedIcon()
        return
    end

    local dataSource = data.dataSource
    local function IsQuestSlotType(slotType)
        return SLOT_TYPE_QUEST_ITEM ~= nil and slotType == SLOT_TYPE_QUEST_ITEM
    end

    local function IsQuestUniqueId(uniqueId)
        return type(uniqueId) == "string" and uniqueId:find("^quest:") ~= nil
    end

    local isQuestEntry = data.isQuestItem == true
        or dataSource.isQuestItem == true
        or dataSource.questIndex ~= nil
        or IsQuestSlotType(data.slotType)
        or IsQuestSlotType(dataSource.slotType)
        or IsQuestUniqueId(data.uniqueId)
        or IsQuestUniqueId(dataSource.uniqueId)
    local hasEquippedVisualState = data.isEquippedInCurrentCategory == true
        or data.isEquippedInAnotherCategory == true
        or data.equipSlot ~= nil
        or dataSource.equipSlot ~= nil
    local hadVisibleStatus = IsControlVisible(statusIndicator)
    local hadVisibleEquippedIcon = IsControlVisible(equippedIcon)
    local L = BETTERUI.Log
    local categories = (L and L.CATEGORY) or {}
    local levels = (L and L.LEVEL) or {}
    if isQuestEntry and hasEquippedVisualState then
        if not data._betteruiWarnedQuestEquipVisual and L and L.Warn then
            data._betteruiWarnedQuestEquipVisual = true
            dataSource._betteruiWarnedQuestEquipVisual = true
            L.Warn(categories.LIST, "quest item equipment icon suppressed", {
                item = L.DescribeItem and L.DescribeItem(data, "row") or nil,
                questIndex = dataSource.questIndex,
                current = data.isEquippedInCurrentCategory == true,
                other = data.isEquippedInAnotherCategory == true,
                equipSlot = data.equipSlot or dataSource.equipSlot,
            })
        end
    end
    if isQuestEntry and (hadVisibleStatus or hadVisibleEquippedIcon) then
        if not data._betteruiWarnedQuestRecycledVisual and L and L.Warn then
            data._betteruiWarnedQuestRecycledVisual = true
            dataSource._betteruiWarnedQuestRecycledVisual = true
            L.Warn(categories.LIST, "quest item recycled status icon suppressed", {
                item = L.DescribeItem and L.DescribeItem(data, "row") or nil,
                questIndex = dataSource.questIndex,
                statusVisibleBefore = hadVisibleStatus == true,
                equippedVisibleBefore = hadVisibleEquippedIcon == true,
            })
        end
    end
    if isQuestEntry then
        ClearStatusIndicator()
        HideEquippedIcon()
        if L and L.EnabledFor and L.EnabledFor(levels.TRACE, categories.LIST) and L.TraceEvent then
            L.TraceEvent(categories.LIST, "inventory.row.equip_icon", "state", {
                item = L.DescribeItem and L.DescribeItem(data, "row") or nil,
                shown = false,
                current = data.isEquippedInCurrentCategory == true,
                other = data.isEquippedInAnotherCategory == true,
                isNew = false,
                quest = true,
                statusSuppressed = true,
            }, levels.TRACE)
        end
        return
    end

    ClearStatusIndicator()

    local isItemNew
    if type(data.brandNew) == "function" then
        isItemNew = data.brandNew()
    else
        isItemNew = data.brandNew
    end

    if isItemNew and data.enabled and statusIndicator then
        statusIndicator:SetTexture(BETTERUI.CIM.CONST.ICONS.NEW_ITEM)
        statusIndicator:SetHidden(false)
    end

    local equipIconShown = false
    if data.isEquippedInCurrentCategory or data.isEquippedInAnotherCategory then
        local slotIndex = data.dataSource.slotIndex
        local equipType = data.dataSource.equipType
        if equippedIcon then
            if slotIndex == EQUIP_SLOT_BACKUP_MAIN or slotIndex == EQUIP_SLOT_BACKUP_OFF or slotIndex == EQUIP_SLOT_RING2 or slotIndex == EQUIP_SLOT_BACKUP_POISON then
                equippedIcon:SetTexture(BETTERUI.CIM.CONST.ICONS.EQUIP_BACKUP)
            else
                equippedIcon:SetTexture(BETTERUI.CIM.CONST.ICONS.EQUIP_MAIN)
            end
            if equipType == EQUIP_TYPE_INVALID then
                equippedIcon:SetTexture(BETTERUI.CIM.CONST.ICONS.EQUIP_SLOT)
            end
            equippedIcon:SetHidden(false)
            equipIconShown = true
        end
    else
        HideEquippedIcon()
    end
    if L and L.EnabledFor and L.EnabledFor(levels.TRACE, categories.LIST) and L.TraceEvent then
        L.TraceEvent(categories.LIST, "inventory.row.equip_icon", "state", {
            item = L.DescribeItem and L.DescribeItem(data, "row") or nil,
            shown = equipIconShown,
            current = data.isEquippedInCurrentCategory == true,
            other = data.isEquippedInAnotherCategory == true,
            isNew = isItemNew == true,
            quest = isQuestEntry == true,
        }, levels.TRACE)
    end
end

--- Sets up the main icon for a shared gamepad entry, including stacking counts and cooldown overlays.
--- Purpose: Renders the primary item icon.
---@param icon table Icon control element
---@param stackCountLabel table Stack count label control
---@param data BetterUIInventoryEntryData ZO_GamepadEntryData with icon, tinting, and desaturation data
---@param selected boolean Whether the entry is currently selected
---@return nil
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
---@param control table UI control with a .cooldown child
---@param data BetterUIInventoryEntryData Entry data containing cooldownRemaining, cooldownDuration, cooldownIcon
---@return nil
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
    ResolveEntryModuleName = ResolveEntryModuleName,
    GetModuleSettings = GetModuleSettings,
    ShouldShowMarketPrice = ShouldShowMarketPrice,
    GetActiveNameFontSize = GetActiveNameFontSize,
}
