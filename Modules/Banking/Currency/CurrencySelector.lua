--[[
---@module "Modules.Banking.Currency.CurrencySelector"
File: Modules/Banking/Currency/CurrencySelector.lua
Purpose: Handles banking currency tooltip display and currency selector transfer flow.
]]

BETTERUI.Banking.CurrencySelector = BETTERUI.Banking.CurrencySelector or {}
local CurrencySelector = BETTERUI.Banking.CurrencySelector

local BANK_UPGRADE_DETAILS_TOP_SPACING = -20

---@param self BETTERUI.Banking.Class
---@return table
local function GetSelectorState(self)
    self._currencySelectorState = self._currencySelectorState or {}
    return self._currencySelectorState
end

local function RemoveKeybindGroupIfPresent(descriptor)
    local removeGroup = BETTERUI.Interface and BETTERUI.Interface.RemoveKeybindGroupIfPresent
    if type(removeGroup) == "function" then
        return removeGroup(descriptor)
    end
    return false
end

local function EnsureKeybindGroupAdded(descriptor)
    local ensureGroup = BETTERUI.Interface and BETTERUI.Interface.EnsureKeybindGroupAdded
    if type(ensureGroup) == "function" then
        return ensureGroup(descriptor)
    end
    return false
end

---@return {rows: {stat: string, value: string}[]}? details Bank upgrade details, or nil if not personal bank
local function BuildBankUpgradeDetailsLines()
    local BANK_CAPACITY_ICON_TEXTURE = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"
    local BANK_CAPACITY_ICON_SIZE = "90%"

    local transferContext = BETTERUI.Banking.ReadTransferContextSnapshot()
    local isMainBankTransfer = transferContext.kind == BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
    if not isMainBankTransfer then
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

---@param tooltip table The gamepad tooltip control
---@param details {rows: {stat: string, value: string}[]}? The details from BuildBankUpgradeDetailsLines
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

---@param self BETTERUI.Banking.Class
---@return nil
function CurrencySelector.RefreshCurrencyTooltip(self)
    if not BETTERUI.Utils.IsBankingSceneShowing() then return end
    local GuildBank = BETTERUI.Banking.GuildBank
    local isGuildBank = GuildBank and GuildBank.IsGuildBankMode()
    local list = self:GetList()
    -- Guild identity, capacity, and banked gold are scene-level information and
    -- must remain visible even when the selected guild has no item permission or
    -- while its item rows are still loading. Personal-bank currency details stay
    -- tied to the currency row.
    if not isGuildBank
        and (not list or not list.selectedData or not list.selectedData.currencyType) then
        return
    end

    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_RIGHT_TOOLTIP)

    if isGuildBank then
        -- No LayoutBankCurrencies call here: U50 removed its currency-list
        -- argument, and the custom guild layout below rebuilds the tooltip
        -- from scratch (ClearLines) anyway.
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        if not tooltip then return end

        local guildId = GuildBank.GetSelectedGuildId()
        local guildName = GuildBank.GetSelectedGuildName()

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
        local bankedFormatId = rawget(_G, "SI_BETTERUI_BANK_BANKED_CURRENCY_FORMAT")
        local carriedFormatId = rawget(_G, "SI_BETTERUI_BANK_CARRIED_CURRENCY_FORMAT")
        local bankedLabel = bankedFormatId and zo_strformat(GetString(bankedFormatId), goldName)
            or ("Banked " .. goldName)
        local carriedLabel = carriedFormatId and zo_strformat(GetString(carriedFormatId), goldName)
            or ("Carried " .. goldName)
        AddToGold(bankedLabel, FmtGold(guildBankGold))
        AddToGold(carriedLabel, FmtGold(carriedGold))
        mainSection:AddSection(goldSection)

        tooltip:AddSection(mainSection)
        -- Tooltip controls can remain hidden after the native guild-bank scene is
        -- suppressed or after an empty/no-permission selection. The summary is
        -- scene-level information, so make its pane visible explicitly.
        if tooltip.SetHidden then
            tooltip:SetHidden(false)
        end
    else
        -- U50: LayoutBankCurrencies takes no currency-list argument.
        GAMEPAD_TOOLTIPS:LayoutBankCurrencies(GAMEPAD_LEFT_TOOLTIP)
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        LayoutBankUpgradeDetailsTooltip(tooltip, BuildBankUpgradeDetailsLines())
    end
end

function BETTERUI.Banking.Class:RefreshCurrencyTooltip()
    CurrencySelector.RefreshCurrencyTooltip(self)
end

---@param self BETTERUI.Banking.Class
---@return integer|nil
function CurrencySelector.GetActiveCurrencyType(self)
    return GetSelectorState(self).currencyType
end

--- Computes the current transferable maximum for the active mode and bank.
--- Used when opening the selector and re-checked at confirm time, since
--- balances can change while the selector is open.
---@param self BETTERUI.Banking.Class
---@param currencyType integer ESO currency type constant (e.g. CURT_MONEY)
---@return integer
function CurrencySelector.GetLiveTransferMax(self, currencyType)
    local GuildBank = BETTERUI.Banking.GuildBank
    local isGuildBank = GuildBank and GuildBank.IsGuildBankMode() == true

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
        return GetMaxCurrencyTransfer(currencyType, fromLocation, toLocation) or 0
    elseif self.currentMode == BETTERUI.Banking.LIST_DEPOSIT then
        return GetCarriedCurrencyAmount(currencyType) or 0
    end
    return GetBankedCurrencyAmount(currencyType) or 0
end

---@param self BETTERUI.Banking.Class
---@param currencyType integer ESO currency type constant (e.g. CURT_MONEY)
function CurrencySelector.DisplaySelector(self, currencyType)
    if currencyType == nil then
        local selectedData = self.GetList and self:GetList() and self:GetList():GetSelectedData() or nil
        currencyType = selectedData and selectedData.currencyType or nil
    end
    if currencyType == nil then
        return
    end

    local selectorState = GetSelectorState(self)
    selectorState.currencyType = currencyType
    selectorState.mode = self.currentMode

    local GuildBank = BETTERUI.Banking.GuildBank
    local isGuildBank = GuildBank and GuildBank.IsGuildBankMode()
    selectorState.isGuildBank = isGuildBank == true

    local currency_max = CurrencySelector.GetLiveTransferMax(self, currencyType)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "display selector", {
            currencyType = currencyType,
            max = currency_max,
        })
    end

    if currency_max > 0 then
        self.selector:SetMaxValue(currency_max)
        -- ZO_CurrencySelector_Gamepad:SetClampValues takes a single boolean
        -- (clampGreaterThanMax); the max itself comes from SetMaxValue above.
        self.selector:SetClampValues(true)
        self.selector.control:GetParent():SetHidden(false)

        self.selectorCurrency:SetTexture(BETTERUI.Banking.CONST.CURRENCY_TEXTURES[currencyType])

        self.selector:Activate()
        self.list:Deactivate()

        if BETTERUI.Log and BETTERUI.Log.TraceEvent then
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.KEYBIND, "bank.currency_selector", "before", {
                action = "show",
                currencyType = currencyType,
                max = currency_max,
                mode = self.currentMode,
                currency = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.currencyKeybinds, "currency") or nil,
                core = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
                selector = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.currencySelectorKeybinds, "selector") or nil,
            })
        end
        RemoveKeybindGroupIfPresent(self.currencyKeybinds)
        RemoveKeybindGroupIfPresent(self.coreKeybinds)
        EnsureKeybindGroupAdded(self.currencySelectorKeybinds)
        if BETTERUI.Log and BETTERUI.Log.TraceEvent then
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.KEYBIND, "bank.currency_selector", "after", {
                action = "show",
                currencyType = currencyType,
                max = currency_max,
                mode = self.currentMode,
                selector = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.currencySelectorKeybinds, "selector") or nil,
            })
        end
    else
        if BETTERUI.Log and BETTERUI.Log.TraceEvent then
            BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.KEYBIND, "bank.currency_selector", "skipped", {
                action = "show",
                reason = "maxZero",
                currencyType = currencyType,
                max = currency_max,
                mode = self.currentMode,
                guild = isGuildBank == true,
                currency = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.currencyKeybinds, "currency") or nil,
                core = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
            })
        end
        BETTERUI.CIM.UserAlertText("Banking.Currency", GetString(rawget(_G, "SI_BETTERUI_BANK_NO_FUNDS")))
    end
end

---@param self BETTERUI.Banking.Class
function CurrencySelector.HideSelector(self)
    local selectorState = GetSelectorState(self)
    local previousCurrencyType = selectorState.currencyType
    local previousMode = selectorState.mode
    local previousIsGuildBank = selectorState.isGuildBank
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "hide selector", {
            currencyType = previousCurrencyType,
            mode = previousMode,
            guild = previousIsGuildBank == true,
        })
    end

    self.selector.control:GetParent():SetHidden(true)
    self.selector:Deactivate()
    self.list:Activate()

    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.KEYBIND, "bank.currency_selector", "before", {
            action = "hide",
            currencyType = previousCurrencyType,
            mode = previousMode,
            guild = previousIsGuildBank == true,
            currency = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.currencyKeybinds, "currency") or nil,
            core = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
            selector = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.currencySelectorKeybinds, "selector") or nil,
        })
    end
    selectorState.currencyType = nil
    selectorState.mode = nil
    selectorState.isGuildBank = nil
    RemoveKeybindGroupIfPresent(self.currencySelectorKeybinds)
    RemoveKeybindGroupIfPresent(self.currencyKeybinds)
    RemoveKeybindGroupIfPresent(self.coreKeybinds)
    EnsureKeybindGroupAdded(self.currencyKeybinds)
    EnsureKeybindGroupAdded(self.coreKeybinds)
    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.KEYBIND, "bank.currency_selector", "after", {
            action = "hide",
            currencyType = previousCurrencyType,
            mode = previousMode,
            guild = previousIsGuildBank == true,
            currency = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.currencyKeybinds, "currency") or nil,
            core = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
        })
    end
end
