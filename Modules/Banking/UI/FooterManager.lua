--[[
File: Modules/Banking/UI/FooterManager.lua
Purpose: Manages the banking footer UI (capacity info, currency display).
         Extracted from Banking.lua.
Author: BetterUI Team
Last Modified: 2026-01-24
]]

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS & STATE
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW

--[[
Function: BETTERUI.Banking.Class:RefreshFooter
Description: Updates the footer information (bag capacity, currency).
]]
function BETTERUI.Banking.Class:RefreshFooter()
    if not self.footer or not self.footer.footer then return end
    local currentUsedBank = BETTERUI.Banking.currentUsedBank
    if (currentUsedBank == BAG_BANK) then
        --IsBankOpen()
        self.footer.footer:GetNamedChild("DepositButtonSpaceLabel"):SetText(zo_strformat(
            "|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t <<1>>",
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
        self.footer.footer:GetNamedChild("WithdrawButtonSpaceLabel"):SetText(zo_strformat(
            "|t24:24:/esoui/art/icons/mapkey/mapkey_bank.dds|t <<1>>",
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK),
                GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))
    else
        self.footer.footer:GetNamedChild("DepositButtonSpaceLabel"):SetText(zo_strformat(
            "|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t <<1>>",
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
        self.footer.footer:GetNamedChild("WithdrawButtonSpaceLabel"):SetText(zo_strformat(
            "|t24:24:/esoui/art/icons/mapkey/mapkey_bank.dds|t <<1>>",
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(currentUsedBank),
                GetBagUseableSize(currentUsedBank))))
    end

    if ((self.currentMode == LIST_WITHDRAW) and (currentUsedBank == BAG_BANK)) then
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
