--[[
File: Modules/Banking/UI/FooterManager.lua
Purpose: Manages the banking footer UI (capacity info, currency display).
         Extracted from Banking.lua.
]]

-- SHARED CONSTANTS & STATE
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW

local function TraceBankFooter(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = data.module or "Banking"
    data.feature = data.feature or "footer"
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.FOOTER or categories.STATE, event, phase, data)
end

--[[
Function: BETTERUI.Banking.Class:RefreshFooter
Description: Updates the footer information (bag capacity, currency).
]]
function BETTERUI.Banking.Class:RefreshFooter()
    if not self.footer or not self.footer.footer then
        TraceBankFooter("bank.footer", "skipped", {
            fn = "RefreshFooter",
            reason = "missingFooterControl",
        })
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.FOOTER, "footer update skipped: control missing") end
        return
    end
    if not self.footerFragment or not self.footerFragment.control then
        TraceBankFooter("bank.footer", "skipped", {
            fn = "RefreshFooter",
            reason = "missingFooterFragment",
        })
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.FOOTER, "footer update skipped: control missing") end
        return
    end
    local transferState = BETTERUI.Banking.ReadTransferContextSnapshot()
    local isGuildBank = transferState.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
    local transferTargetBankBag = transferState.depositTargetBag
    local isTargetMainBank = transferTargetBankBag == BAG_BANK

    -- Deposit side (player inventory) — always the same
    self.footer.footer:GetNamedChild("DepositButtonSpaceLabel"):SetText(zo_strformat(
        "|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t <<1>>",
        zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))

    -- Withdraw side (bank) — varies by bank type
    if isGuildBank then
        self.footer.footer:GetNamedChild("WithdrawButtonSpaceLabel"):SetText(zo_strformat(
            "|t24:24:/esoui/art/icons/mapkey/mapkey_bank.dds|t <<1>>",
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_GUILDBANK),
                GetBagUseableSize(BAG_GUILDBANK))))
    elseif isTargetMainBank then
        self.footer.footer:GetNamedChild("WithdrawButtonSpaceLabel"):SetText(zo_strformat(
            "|t24:24:/esoui/art/icons/mapkey/mapkey_bank.dds|t <<1>>",
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK),
                GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))
    else
        -- House bank
        self.footer.footer:GetNamedChild("WithdrawButtonSpaceLabel"):SetText(zo_strformat(
            "|t24:24:/esoui/art/icons/mapkey/mapkey_bank.dds|t <<1>>",
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(transferTargetBankBag),
                GetBagUseableSize(transferTargetBankBag))))
    end

    local data1Value
    local data2Value

    -- Currency display — varies by bank type and mode
    if isGuildBank then
        -- Guild bank: show guild bank gold (only currency guild banks support)
        if self.currentMode == LIST_WITHDRAW then
            data1Value = BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_GUILD_BANK))
            data2Value = ""
        else
            data1Value = BETTERUI.DisplayNumber(GetCarriedCurrencyAmount(CURT_MONEY))
            data2Value = ""
        end
    elseif (self.currentMode == LIST_WITHDRAW) and isTargetMainBank then
        data1Value = BETTERUI.DisplayNumber(GetBankedCurrencyAmount(CURT_MONEY))
        data2Value = BETTERUI.DisplayNumber(GetBankedCurrencyAmount(CURT_TELVAR_STONES))
    else
        data1Value = BETTERUI.DisplayNumber(GetCarriedCurrencyAmount(CURT_MONEY))
        data2Value = BETTERUI.DisplayNumber(GetCarriedCurrencyAmount(CURT_TELVAR_STONES))
    end
    self.footerFragment.control:GetNamedChild("Data1Value"):SetText(data1Value)
    self.footerFragment.control:GetNamedChild("Data2Value"):SetText(data2Value)

    local backpackUsed, backpackSize = GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)
    local withdrawUsed
    local withdrawSize
    if isGuildBank then
        withdrawUsed = GetNumBagUsedSlots(BAG_GUILDBANK)
        withdrawSize = GetBagUseableSize(BAG_GUILDBANK)
    elseif isTargetMainBank then
        withdrawUsed = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
        withdrawSize = GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK)
    else
        withdrawUsed = GetNumBagUsedSlots(transferTargetBankBag)
        withdrawSize = GetBagUseableSize(transferTargetBankBag)
    end
    local traceState = table.concat({
        tostring(self.currentMode),
        tostring(transferState.kind),
        tostring(transferTargetBankBag),
        tostring(isGuildBank),
        tostring(isTargetMainBank),
        tostring(data1Value),
        tostring(data2Value),
        tostring(backpackUsed),
        tostring(backpackSize),
        tostring(withdrawUsed),
        tostring(withdrawSize),
    }, ":")
    if self._betteruiFooterTraceState ~= traceState then
        self._betteruiFooterTraceState = traceState
        TraceBankFooter("bank.footer", "refreshed", {
            fn = "RefreshFooter",
            mode = self.currentMode,
            transferKind = transferState.kind,
            transferTargetBankBag = transferTargetBankBag,
            guildBank = isGuildBank == true,
            mainBank = isTargetMainBank == true,
            data1Value = data1Value,
            data2Value = data2Value,
            backpackUsed = backpackUsed,
            backpackSize = backpackSize,
            withdrawUsed = withdrawUsed,
            withdrawSize = withdrawSize,
        })
    end
end
