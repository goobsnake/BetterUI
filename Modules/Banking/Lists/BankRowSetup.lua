--[[
File: Modules/Banking/Lists/BankRowSetup.lua
Purpose: Configures banking row templates, currency row rendering, and selection handling.
         Split from BankListManager.lua to keep list management isolated from row setup logic.
]]

-- SHARED ROW CONSTANTS
BETTERUI.Banking.CURRENCY_ROW_TEMPLATE = "BETTERUI_BankCurrencySelectorTemplate"

local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW

local GOLD_TRANSFER_AMOUNT_COLOR = ZO_ColorDef:New("FFBF00")
local CURRENCY_ACTION_SELECTED_COLOR = ZO_ColorDef:New("FFBF00")
local CURRENCY_ACTION_FONT_SIZE_BONUS = 3
local CURRENCY_ICON_PULSE_DURATION_MS = 675
local CURRENCY_ICON_PULSE_MIN_ALPHA = 0.20
local CURRENCY_ICON_PULSE_MAX_SCALE = 1.28
local CURRENCY_LABEL_PULSE_MIN_ALPHA = 0.66
local CURRENCY_LABEL_PULSE_MAX_SCALE = 1.03

-- ROW SETUP HELPERS

function BETTERUI.Banking.Class.SetupLabelListing(control, data)
    control:GetNamedChild("Label"):SetText(data.label)
    control:GetNamedChild("Label"):SetFont(BETTERUI.Banking.GetNameFontDescriptor())
end

local function GetCurrencyActionFontDescriptor()
    local moduleSettings = BETTERUI.GetModuleSettings("Banking")
    local defaults = BETTERUI.CIM.Font.DEFAULTS
    local fontPath = (moduleSettings and moduleSettings.nameFont) or defaults.nameFont
    local fontSize = BETTERUI.CIM.Font.GetSizeValue((moduleSettings and moduleSettings.nameFontSize)
        or defaults.nameFontSize)
    local fontStyle = (moduleSettings and moduleSettings.nameFontStyle) or defaults.nameFontStyle

    return BETTERUI.CIM.Font.BuildDescriptor(fontPath, fontSize + CURRENCY_ACTION_FONT_SIZE_BONUS, fontStyle)
end

local function GetCurrencyTransferMax(self, currencyType)
    local fromLocation
    local toLocation
    local GuildBank = BETTERUI.Banking.GuildBank
    local isGuildBank = GuildBank and GuildBank.IsGuildBankMode()
    if self.currentMode == LIST_WITHDRAW then
        fromLocation = isGuildBank and CURRENCY_LOCATION_GUILD_BANK or CURRENCY_LOCATION_BANK
        toLocation = CURRENCY_LOCATION_CHARACTER
    else
        fromLocation = CURRENCY_LOCATION_CHARACTER
        toLocation = isGuildBank and CURRENCY_LOCATION_GUILD_BANK or CURRENCY_LOCATION_BANK
    end

    if GetMaxCurrencyTransfer then
        return GetMaxCurrencyTransfer(currencyType, fromLocation, toLocation) or 0
    end

    local fromAmount = GetCurrencyAmount(currencyType, fromLocation) or 0
    local toAmount = GetCurrencyAmount(currencyType, toLocation) or 0
    local toMax = GetMaxPossibleCurrency(currencyType, toLocation) or 0
    local remainingCapacity = zo_max(toMax - toAmount, 0)
    return zo_min(fromAmount, remainingCapacity)
end

local function GetCurrencyTransferEntryLabel(modeText, currencyLabel, currencyType, transferMax)
    local formatOptions
    if currencyType == CURT_MONEY then
        formatOptions = { color = GOLD_TRANSFER_AMOUNT_COLOR }
    end

    local amountText = ZO_Currency_FormatGamepad(
        currencyType,
        transferMax or 0,
        ZO_CURRENCY_FORMAT_AMOUNT_ICON,
        formatOptions
    ) or tostring(transferMax or 0)

    return string.format("%s %s (%s)", modeText, currencyLabel, amountText)
end

function BETTERUI.Banking.BuildCurrencyTransferEntryData(self, currencyType, modeText, labelByCurrency)
    local currencyLabel = labelByCurrency[currencyType]
        or (GetCurrencyName and GetCurrencyName(currencyType, true, false))
        or tostring(currencyType)
    local transferMax = GetCurrencyTransferMax(self, currencyType)
    local iconPath = ZO_Currency_GetGamepadCurrencyIcon and ZO_Currency_GetGamepadCurrencyIcon(currencyType)
        or BETTERUI.Banking.CONST.CURRENCY_TEXTURES[currencyType]

    local rowLabel = GetCurrencyTransferEntryLabel(modeText, currencyLabel, currencyType, transferMax)
    local entryData = ZO_GamepadEntryData:New(rowLabel, iconPath)
    entryData:SetFontScaleOnSelection(false)
    entryData:SetNameColors(CURRENCY_ACTION_SELECTED_COLOR, ZO_GAMEPAD_UNSELECTED_COLOR)
    entryData:SetDisabledNameColors(ZO_GAMEPAD_DISABLED_SELECTED_COLOR, ZO_GAMEPAD_DISABLED_UNSELECTED_COLOR)
    entryData:SetIconTint(CURRENCY_ACTION_SELECTED_COLOR, ZO_GAMEPAD_UNSELECTED_COLOR)
    entryData:SetDisabledIconTint(ZO_GAMEPAD_DISABLED_SELECTED_COLOR, ZO_GAMEPAD_DISABLED_UNSELECTED_COLOR)
    entryData:SetEnabled(transferMax > 0)
    entryData.currencyType = currencyType
    entryData.isCurrenciesMenuEntry = true
    entryData.transferMax = transferMax
    entryData.keybindLabel = zo_strformat("<<1>> <<2>>", modeText, currencyLabel)
    return entryData
end

local function EnsureCurrencyPulseTimeline(control, icon, label)
    if not icon and not label then
        return nil
    end

    if control._betteruiCurrencyPulseTimeline then
        return control._betteruiCurrencyPulseTimeline
    end

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    if icon then
        local fadeOut = timeline:InsertAnimation(ANIMATION_ALPHA, icon, 0)
        fadeOut:SetDuration(CURRENCY_ICON_PULSE_DURATION_MS)
        fadeOut:SetAlphaValues(1, CURRENCY_ICON_PULSE_MIN_ALPHA)
        fadeOut:SetEasingFunction(ZO_EaseInOutQuadratic)

        local fadeIn = timeline:InsertAnimation(ANIMATION_ALPHA, icon, CURRENCY_ICON_PULSE_DURATION_MS)
        fadeIn:SetDuration(CURRENCY_ICON_PULSE_DURATION_MS)
        fadeIn:SetAlphaValues(CURRENCY_ICON_PULSE_MIN_ALPHA, 1)
        fadeIn:SetEasingFunction(ZO_EaseInOutQuadratic)

        local scaleUp = timeline:InsertAnimation(ANIMATION_SCALE, icon, 0)
        scaleUp:SetDuration(CURRENCY_ICON_PULSE_DURATION_MS)
        scaleUp:SetScaleValues(1, CURRENCY_ICON_PULSE_MAX_SCALE)
        scaleUp:SetEasingFunction(ZO_EaseInOutQuadratic)

        local scaleDown = timeline:InsertAnimation(ANIMATION_SCALE, icon, CURRENCY_ICON_PULSE_DURATION_MS)
        scaleDown:SetDuration(CURRENCY_ICON_PULSE_DURATION_MS)
        scaleDown:SetScaleValues(CURRENCY_ICON_PULSE_MAX_SCALE, 1)
        scaleDown:SetEasingFunction(ZO_EaseInOutQuadratic)
    end

    if label then
        local fadeOut = timeline:InsertAnimation(ANIMATION_ALPHA, label, 0)
        fadeOut:SetDuration(CURRENCY_ICON_PULSE_DURATION_MS)
        fadeOut:SetAlphaValues(1, CURRENCY_LABEL_PULSE_MIN_ALPHA)
        fadeOut:SetEasingFunction(ZO_EaseInOutQuadratic)

        local fadeIn = timeline:InsertAnimation(ANIMATION_ALPHA, label, CURRENCY_ICON_PULSE_DURATION_MS)
        fadeIn:SetDuration(CURRENCY_ICON_PULSE_DURATION_MS)
        fadeIn:SetAlphaValues(CURRENCY_LABEL_PULSE_MIN_ALPHA, 1)
        fadeIn:SetEasingFunction(ZO_EaseInOutQuadratic)

        local scaleUp = timeline:InsertAnimation(ANIMATION_SCALE, label, 0)
        scaleUp:SetDuration(CURRENCY_ICON_PULSE_DURATION_MS)
        scaleUp:SetScaleValues(1, CURRENCY_LABEL_PULSE_MAX_SCALE)
        scaleUp:SetEasingFunction(ZO_EaseInOutQuadratic)

        local scaleDown = timeline:InsertAnimation(ANIMATION_SCALE, label, CURRENCY_ICON_PULSE_DURATION_MS)
        scaleDown:SetDuration(CURRENCY_ICON_PULSE_DURATION_MS)
        scaleDown:SetScaleValues(CURRENCY_LABEL_PULSE_MAX_SCALE, 1)
        scaleDown:SetEasingFunction(ZO_EaseInOutQuadratic)
    end

    timeline:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
    control._betteruiCurrencyPulseTimeline = timeline
    return timeline
end

function BETTERUI.Banking.Class.SetupCurrencyTransferEntry(control, data, selected, selectedDuringRebuild, enabled,
                                                           activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)

    local label = control.label or control:GetNamedChild("Label")
    if label then
        label:SetFont(GetCurrencyActionFontDescriptor())
    end

    local icon = control.icon or control:GetNamedChild("Icon")
    local timeline = EnsureCurrencyPulseTimeline(control, icon, label)
    if not timeline then
        return
    end

    if selected and data and data.enabled then
        if not timeline:IsPlaying() then
            timeline:PlayFromStart()
        end
        return
    end

    if timeline:IsPlaying() then
        timeline:Stop()
    end
    if icon then
        icon:SetAlpha(1)
        icon:SetScale(1)
    end
    if label then
        label:SetAlpha(1)
        label:SetScale(1)
    end
end

-- SELECTION CHANGE HELPERS

local function UpdateKeybindsForSelection(self, isCurrencyRow)
    if self.isInHeaderSortMode then
        return
    end

    local selectionModeActive = self.multiSelectManager and self.multiSelectManager:IsActive()
    if selectionModeActive then
        isCurrencyRow = false
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

local function ResolveSelectedSlotData(selectedData)
    if not selectedData then
        return nil
    end
    return selectedData.dataSource or selectedData
end

local function ResolveSelectedItemLink(selectedData, bagId, slotIndex)
    local itemLink = nil

    if bagId ~= nil and slotIndex ~= nil then
        itemLink = GetItemLink(bagId, slotIndex)
    end

    if (itemLink == nil or itemLink == "") and selectedData then
        itemLink = selectedData.cached_itemLink or selectedData.itemLink
        local rawData = selectedData.dataSource
        if (itemLink == nil or itemLink == "") and rawData then
            itemLink = rawData.cached_itemLink or rawData.itemLink
        end
    end

    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end
    return itemLink
end

local function HandleItemRowSelection(selectedData)
    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_RIGHT_TOOLTIP)

    local data = ResolveSelectedSlotData(selectedData)
    local bagId = data and data.bagId or nil
    local slotIndex = data and data.slotIndex or nil
    local itemLink = ResolveSelectedItemLink(selectedData, bagId, slotIndex)

    if bagId ~= nil and slotIndex ~= nil then
        local didLayout = GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, bagId, slotIndex)
        if not didLayout and itemLink and GAMEPAD_TOOLTIPS.LayoutItem then
            GAMEPAD_TOOLTIPS:LayoutItem(GAMEPAD_LEFT_TOOLTIP, itemLink)
        end
    elseif itemLink and GAMEPAD_TOOLTIPS.LayoutItem then
        GAMEPAD_TOOLTIPS:LayoutItem(GAMEPAD_LEFT_TOOLTIP, itemLink)
    else
        if BETTERUI.CIM.SharedItemSupport and BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip then
            BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
        end
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        return
    end

    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    if tooltip then
        tooltip._betterui_bagId = bagId
        tooltip._betterui_slotIndex = slotIndex
        tooltip._betterui_itemLink = itemLink
    end

    BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)
    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_LEFT_TOOLTIP)
    if container and container._betterUiComparison then
        container._betterUiComparison:SetHidden(true)
    end

    -- INV-001: Stat comparison for banking items
    if BETTERUI.CIM.SharedItemSupport.IsItemComparisonEnabled()
        and bagId ~= nil and slotIndex ~= nil and itemLink then
        local result = BETTERUI.CIM.SharedItemSupport.CompareItem(itemLink, bagId, slotIndex)
        BETTERUI.CIM.SharedItemSupport.ShowComparisonOnTooltip(container, result)
    else
        BETTERUI.CIM.SharedItemSupport.ShowComparisonOnTooltip(container, nil)
    end
end

local function HandleCurrencyRowSelection(self)
    UpdateKeybindsForSelection(self, true)
    BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
    self:RefreshCurrencyTooltip()
end

-- SELECTION + TEMPLATE REGISTRATION

function BETTERUI.Banking.Class.OnItemSelectedChange(self, list, selectedData)
    local getTransferTargetBag = BETTERUI.Banking.GetTransferTargetBag
    local transferTargetBankBag = type(getTransferTargetBag) == "function" and getTransferTargetBag() or BAG_BANK
    if not BETTERUI.Utils.IsBankingSceneShowing() then
        return
    end

    if not selectedData then
        UpdateKeybindsForSelection(self, false)
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_RIGHT_TOOLTIP)
        BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
        self:UpdateActions()
        return
    end

    local activeCategory = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    local GuildBank = BETTERUI.Banking.GuildBank
    local isGuildBankOrPersonalBank = (transferTargetBankBag == BAG_BANK) or (GuildBank and GuildBank.IsGuildBankMode())
    if isGuildBankOrPersonalBank then
        local isCurrencyRow = ZO_GamepadBanking
            and ZO_GamepadBanking.IsEntryDataCurrencyRelated
            and ZO_GamepadBanking.IsEntryDataCurrencyRelated(selectedData)
            and activeCategory
            and activeCategory.key == "all"

        if isCurrencyRow then
            HandleCurrencyRowSelection(self)
        else
            UpdateKeybindsForSelection(self, false)
            HandleItemRowSelection(selectedData)
        end
    else
        UpdateKeybindsForSelection(self, false)
        HandleItemRowSelection(selectedData)
        self:RefreshCurrencyTooltip()
    end

    self:UpdateActions()
end

function BETTERUI.Banking.Class.SetupItemList(list)
    list:AddDataTemplate(
        BETTERUI.Banking.CURRENCY_ROW_TEMPLATE,
        BETTERUI.Banking.Class.SetupCurrencyTransferEntry,
        ZO_GamepadMenuEntryTemplateParametricListFunction
    )
    list:AddDataTemplate("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, BETTERUI.CIM.MenuEntryTemplateEquality)
    list:AddDataTemplateWithHeader("BETTERUI_GamepadItemSubEntryTemplate", BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, BETTERUI.CIM.MenuEntryTemplateEquality,
        "ZO_GamepadMenuEntryHeaderTemplate")
end
