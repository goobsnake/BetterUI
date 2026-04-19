local Currency = nil -- Will be set after load order verification

local function EnsureCurrencyManager()
    if not Currency then
        Currency = BETTERUI.CIM.Currency
    end
    return Currency
end

local function GetLabelControl(footer, labelName)
    return EnsureCurrencyManager().GetLabelControl(footer, labelName)
end

function BETTERUI.GenericFooter:Initialize()
    if (self.footer == nil) then self.footer = self.control.container:GetNamedChild("FooterContainer").footer end

    if (self.footer.GoldLabel ~= nil) then BETTERUI.GenericFooter.Refresh(self) end
end

function BETTERUI.GenericFooter:Refresh()
    local invSettings = BETTERUI.GetModuleSettings("Inventory")
    local footer = self.footer
    if not footer._stringCache then footer._stringCache = {} end

    local stringsChanged = false
    local CurrencyMgr = EnsureCurrencyManager()

    local cwLabel = GetLabelControl(footer, "CWLabel")
    local bankLabel = GetLabelControl(footer, "BankLabel")

    if cwLabel then
        local bagText = zo_strformat("<<1>> (<<2>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t",
            GetString(rawget(_G, "SI_BETTERUI_FOOTER_BAG_CAPACITY")),
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)))

        if footer._stringCache.bag ~= bagText then
            cwLabel:SetText(bagText)
            footer._stringCache.bag = bagText
            stringsChanged = true
        end
    end

    if bankLabel then
        local bankText = zo_strformat("<<1>> (<<2>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t",
            GetString(rawget(_G, "SI_BETTERUI_FOOTER_BANK_CAPACITY")),
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK),
                GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK)))

        if footer._stringCache.bank ~= bankText then
            bankLabel:SetText(bankText)
            footer._stringCache.bank = bankText
            stringsChanged = true
        end
    end

    local currenciesChanged = CurrencyMgr.UpdateLabels(footer, invSettings)

    if stringsChanged or currenciesChanged then
        CurrencyMgr.PositionLabels(footer, invSettings)
    end
end
