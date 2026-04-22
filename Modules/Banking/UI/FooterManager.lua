--[[
File: Modules/Banking/UI/FooterManager.lua
Purpose: Manages the banking footer UI (capacity info, currency display).
         Extracted from Banking.lua.
]]

-- SHARED CONSTANTS & STATE
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW

--[[
Function: BETTERUI.Banking.Class:RefreshFooter
Description: Updates the footer information (bag capacity, currency).
]]
function BETTERUI.Banking.Class:RefreshFooter()
    if not self.footer or not self.footer.footer then return end
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

    -- Currency display — varies by bank type and mode
    if isGuildBank then
        -- Guild bank: show guild bank gold (only currency guild banks support)
        if self.currentMode == LIST_WITHDRAW then
            self.footerFragment.control:GetNamedChild("Data1Value"):SetText(BETTERUI.DisplayNumber(
                GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_GUILD_BANK)))
            self.footerFragment.control:GetNamedChild("Data2Value"):SetText("")
        else
            self.footerFragment.control:GetNamedChild("Data1Value"):SetText(BETTERUI.DisplayNumber(
                GetCarriedCurrencyAmount(CURT_MONEY)))
            self.footerFragment.control:GetNamedChild("Data2Value"):SetText("")
        end
    elseif (self.currentMode == LIST_WITHDRAW) and isTargetMainBank then
        self.footerFragment.control:GetNamedChild("Data1Value"):SetText(BETTERUI.DisplayNumber(GetBankedCurrencyAmount(
            CURT_MONEY)))
        self.footerFragment.control:GetNamedChild("Data2Value"):SetText(BETTERUI.DisplayNumber(GetBankedCurrencyAmount(
            CURT_TELVAR_STONES)))
    else
        self.footerFragment.control:GetNamedChild("Data1Value"):SetText(BETTERUI.DisplayNumber(GetCarriedCurrencyAmount(
            CURT_MONEY)))
        self.footerFragment.control:GetNamedChild("Data2Value"):SetText(BETTERUI.DisplayNumber(GetCarriedCurrencyAmount(
            CURT_TELVAR_STONES)))
    end
end
