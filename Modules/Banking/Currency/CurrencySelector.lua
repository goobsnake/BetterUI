--[[
---@module "Modules.Banking.Currency.CurrencySelector"
File: Modules/Banking/Currency/CurrencySelector.lua
Purpose: Handles banking currency tooltip display and currency selector transfer flow.
Author: BetterUI Team
]]

BETTERUI.Banking.CurrencySelector = BETTERUI.Banking.CurrencySelector or {}
local CurrencySelector = BETTERUI.Banking.CurrencySelector

local BANK_UPGRADE_DETAILS_TOP_SPACING = 290

local function BuildBankUpgradeDetailsLines()
    local BANK_CAPACITY_ICON_TEXTURE = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"
    local BANK_CAPACITY_ICON_SIZE = "90%"

    if GetBankingBag() ~= BAG_BANK then
        return nil
    end

    local currentUnlock = GetCurrentBankUpgrade and GetCurrentBankUpgrade() or 0
    local maxUnlock = GetMaxBankUpgrade and GetMaxBankUpgrade() or currentUnlock
    local upgradesRemaining = zo_max((maxUnlock or 0) - (currentUnlock or 0), 0)
    local slotsPerUpgrade = NUM_BANK_SLOTS_PER_UPGRADE or 0
    local slotMultiplier = (IsESOPlusSubscriber and IsESOPlusSubscriber()) and 2 or 1
    local slotsRemaining = upgradesRemaining * slotsPerUpgrade * slotMultiplier

    local primaryBankSize = GetBagUseableSize(BAG_BANK) or GetBagSize(BAG_BANK) or 0
    local subscriberBankSize = GetBagUseableSize(BAG_SUBSCRIBER_BANK) or GetBagSize(BAG_SUBSCRIBER_BANK) or 0
    local currentBankSize = primaryBankSize + subscriberBankSize
    local maxPurchasableSize = currentBankSize + slotsRemaining
    local canPurchaseUpgrade = IsBankUpgradeAvailable and IsBankUpgradeAvailable()

    local details = { rows = {} }
    local bankCapacityText = zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, currentBankSize, maxPurchasableSize)
    local bankCapacityValue = zo_iconTextFormatNoSpaceAlignedRight(
        BANK_CAPACITY_ICON_TEXTURE,
        BANK_CAPACITY_ICON_SIZE,
        BANK_CAPACITY_ICON_SIZE,
        bankCapacityText,
        false,
        true
    )
    details.rows[#details.rows + 1] = {
        stat = GetString(rawget(_G, "SI_GAMEPAD_BANK_BANK_CAPACITY_LABEL")),
        value = bankCapacityValue,
    }

    if canPurchaseUpgrade then
        local cost = GetNextBankUpgradePrice and GetNextBankUpgradePrice() or 0
        local costText = ZO_Currency_FormatGamepad(CURT_MONEY, cost, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
        details.rows[#details.rows + 1] = {
            stat = GetString(rawget(_G, "SI_PROMPT_TITLE_BUY_BANK_SPACE")),
            value = costText,
        }
    end

    return details
end

local function LayoutBankUpgradeDetailsTooltip(tooltip, details)
    if not tooltip or not details or not details.rows or #details.rows == 0 then
        return
    end

    local detailsMainSection = tooltip:AcquireSection(tooltip:GetStyle("bankCurrencyMainSection"))
    local detailsSection = tooltip:AcquireSection(tooltip:GetStyle("bankCurrencySection"))
    local function AddDetailsStatValuePair(statText, valueText)
        local statValuePair = detailsSection:AcquireStatValuePair(tooltip:GetStyle("currencyStatValuePair"))
        statValuePair:SetStat(statText, tooltip:GetStyle("currencyStatValuePairStat"))
        statValuePair:SetValue(valueText or "", tooltip:GetStyle("currencyStatValuePairValue"))
        detailsSection:AddStatValuePair(statValuePair)
    end

    for i = 1, #details.rows do
        local row = details.rows[i]
        AddDetailsStatValuePair(row.stat, row.value)
    end

    detailsMainSection:SetNextSpacing(BANK_UPGRADE_DETAILS_TOP_SPACING)
    detailsMainSection:AddSection(detailsSection)
    tooltip:AddSection(detailsMainSection)
end

function CurrencySelector.RefreshCurrencyTooltip(self)
    if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
    local list = self:GetList()
    if not list or not list.selectedData or not list.selectedData.currencyType then return end

    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_RIGHT_TOOLTIP)

    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        GAMEPAD_TOOLTIPS:LayoutBankCurrencies(GAMEPAD_LEFT_TOOLTIP, { CURT_MONEY })

        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        if not tooltip then return end
        tooltip:ClearLines()

        local guildId = GetSelectedGuildBankId and GetSelectedGuildBankId() or 0
        local guildName = (guildId > 0) and GetGuildName(guildId) or GetString(rawget(_G, "SI_TRADING_HOUSE_GUILD_LABEL"))

        local guildBankGold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_GUILD_BANK) or 0
        local carriedGold = GetCarriedCurrencyAmount(CURT_MONEY) or 0

        local function FmtGold(amount)
            return ZO_Currency_FormatGamepad(CURT_MONEY, amount, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
                or tostring(amount)
        end

        local mainSection = tooltip:AcquireSection(tooltip:GetStyle("bankCurrencyMainSection"))
        local guildSection = tooltip:AcquireSection(tooltip:GetStyle("bankCurrencySection"))

        local function AddToGuild(statText, valueText)
            local pair = guildSection:AcquireStatValuePair(tooltip:GetStyle("currencyStatValuePair"))
            pair:SetStat(statText, tooltip:GetStyle("currencyStatValuePairStat"))
            pair:SetValue(valueText or "", tooltip:GetStyle("currencyStatValuePairValue"))
            guildSection:AddStatValuePair(pair)
        end

        AddToGuild(GetString(rawget(_G, "SI_TRADING_HOUSE_GUILD_LABEL")), guildName)
        local usedSlots = GetNumBagUsedSlots(BAG_GUILDBANK) or 0
        local totalSlots = GetBagUseableSize(BAG_GUILDBANK) or 0
        AddToGuild(GetString(rawget(_G, "SI_GAMEPAD_BANK_BANK_CAPACITY_LABEL")),
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, usedSlots, totalSlots))
        mainSection:AddSection(guildSection)

        mainSection:SetNextSpacing(48)

        local goldSection = tooltip:AcquireSection(tooltip:GetStyle("bankCurrencySection"))
        local function AddToGold(statText, valueText)
            local pair = goldSection:AcquireStatValuePair(tooltip:GetStyle("currencyStatValuePair"))
            pair:SetStat(statText, tooltip:GetStyle("currencyStatValuePairStat"))
            pair:SetValue(valueText or "", tooltip:GetStyle("currencyStatValuePairValue"))
            goldSection:AddStatValuePair(pair)
        end
        local goldName = GetCurrencyName(CURT_MONEY, true, false) or "Gold"
        AddToGold("Banked " .. goldName, FmtGold(guildBankGold))
        AddToGold("Carried " .. goldName, FmtGold(carriedGold))
        mainSection:AddSection(goldSection)

        tooltip:AddSection(mainSection)
    else
        GAMEPAD_TOOLTIPS:LayoutBankCurrencies(GAMEPAD_LEFT_TOOLTIP, ZO_BANKABLE_CURRENCIES)
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        LayoutBankUpgradeDetailsTooltip(tooltip, BuildBankUpgradeDetailsLines())
    end
end

function BETTERUI.Banking.Class:RefreshCurrencyTooltip()
    CurrencySelector.RefreshCurrencyTooltip(self)
end

function BETTERUI.Banking.Class:TransferSelectedCurrency(currencyType, amount)
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        if self.currentMode == BETTERUI.Banking.LIST_WITHDRAW then
            TransferCurrency(currencyType, amount, CURRENCY_LOCATION_GUILD_BANK, CURRENCY_LOCATION_CHARACTER)
        else
            TransferCurrency(currencyType, amount, CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_GUILD_BANK)
        end
    else
        if self.currentMode == BETTERUI.Banking.LIST_WITHDRAW then
            WithdrawCurrencyFromBank(currencyType, amount)
        else
            DepositCurrencyIntoBank(currencyType, amount)
        end
    end
end

function BETTERUI.Banking.Class:DisplaySelector(currencyType)
    local currency_max
    local GuildBank = BETTERUI.Banking.GuildBank
    local isGuildBank = GuildBank and GuildBank.IsGuildBankMode()

    if GetMaxCurrencyTransfer then
        local fromLocation
        local toLocation
        if self.currentMode == BETTERUI.Banking.LIST_DEPOSIT then
            fromLocation = CURRENCY_LOCATION_CHARACTER
            toLocation = isGuildBank and CURRENCY_LOCATION_GUILD_BANK or CURRENCY_LOCATION_BANK
        else
            fromLocation = isGuildBank and CURRENCY_LOCATION_GUILD_BANK or CURRENCY_LOCATION_BANK
            toLocation = CURRENCY_LOCATION_CHARACTER
        end
        currency_max = GetMaxCurrencyTransfer(currencyType, fromLocation, toLocation) or 0
    elseif self.currentMode == BETTERUI.Banking.LIST_DEPOSIT then
        currency_max = GetCarriedCurrencyAmount(currencyType) or 0
    else
        currency_max = GetBankedCurrencyAmount(currencyType) or 0
    end

    if currency_max > 0 then
        self.selector:SetMaxValue(currency_max)
        self.selector:SetClampValues(0, currency_max)
        self.selector.control:GetParent():SetHidden(false)

        self.selectorCurrency:SetTexture(BETTERUI.Banking.CONST.CURRENCY_TEXTURES[currencyType])

        self.selector:Activate()
        self.list:Deactivate()

        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.currencySelectorKeybinds)
    else
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(rawget(_G, "SI_BETTERUI_BANK_NO_FUNDS")))
    end
end

function BETTERUI.Banking.Class:HideSelector()
    self.selector.control:GetParent():SetHidden(true)
    self.selector:Deactivate()
    self.list:Activate()

    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencySelectorKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.currencyKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
end
