local _

function BETTERUI.GenericFooter:Initialize()
	if(self.footer == nil) then self.footer = self.control.container:GetNamedChild("FooterContainer").footer end

	if(self.footer.GoldLabel ~= nil) then BETTERUI.GenericFooter.Refresh(self) end
end

function BETTERUI.GenericFooter:Refresh()
	-- a hack until I completely generalize these functions... 
	local invSettings = BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Inventory"] or {}

	local function setLabel(labelControl, enabled, text)
		labelControl:SetHidden(not enabled)
		if enabled then labelControl:SetText(text) end
	end

	if(self.footer.GoldLabel ~= nil) then
		-- Bag/Bank capacities (not currencies) remain always visible
		self.footer.CWLabel:SetText(zo_strformat("BAG: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
		self.footer.BankLabel:SetText(zo_strformat("BANK: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK), GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))

		setLabel(self.footer.GoldLabel, invSettings.showCurrencyGold ~= false, zo_strformat("GOLD: |cFFBF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_MONEY)), GetCurrencyGamepadIcon(CURT_MONEY)))
		setLabel(self.footer.APLabel, invSettings.showCurrencyAlliancePoints ~= false, zo_strformat("AP: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_ALLIANCE_POINTS)), GetCurrencyGamepadIcon(CURT_ALLIANCE_POINTS)))
		setLabel(self.footer.TVLabel, invSettings.showCurrencyTelVar ~= false, zo_strformat("TEL VAR: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_TELVAR_STONES)), GetCurrencyGamepadIcon(CURT_TELVAR_STONES)))
		setLabel(self.footer.GemsLabel, invSettings.showCurrencyCrownGems ~= false, zo_strformat("GEMS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_CROWN_GEMS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_CROWN_GEMS)))
		setLabel(self.footer.TCLabel, invSettings.showCurrencyTransmute ~= false, zo_strformat("TRANSMUTE: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_STYLE_STONES)))
		setLabel(self.footer.CrownsLabel, invSettings.showCurrencyCrowns ~= false, zo_strformat("CROWNS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_CROWNS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_CROWNS)))
		setLabel(self.footer.WritsLabel, invSettings.showCurrencyWritVouchers ~= false, zo_strformat("WRITS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_WRIT_VOUCHERS)), GetCurrencyGamepadIcon(CURT_WRIT_VOUCHERS)))
		setLabel(self.footer.TicketsLabel, invSettings.showCurrencyEventTickets ~= false, zo_strformat("TICKETS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_EVENT_TICKETS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_EVENT_TICKETS)))
		setLabel(self.footer.KeysLabel, invSettings.showCurrencyUndauntedKeys ~= false, zo_strformat("KEYS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_UNDAUNTED_KEYS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_UNDAUNTED_KEYS)))
		setLabel(self.footer.OutfitLabel, invSettings.showCurrencyOutfitTokens ~= false, zo_strformat("OUTFIT: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_STYLE_STONES, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_STYLE_STONES)))
	else
		-- Fallback path using GetNamedChild
		local footer = self.footer
		footer:GetNamedChild("CWLabel"):SetText(zo_strformat("BAG: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
		footer:GetNamedChild("BankLabel"):SetText(zo_strformat("BANK: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK), GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))

		local function setChild(name, enabled, text)
			local c = footer:GetNamedChild(name)
			c:SetHidden(not enabled)
			if enabled then c:SetText(text) end
		end

		setChild("GoldLabel", invSettings.showCurrencyGold ~= false, zo_strformat("GOLD: |cFFBF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_MONEY)), GetCurrencyGamepadIcon(CURT_MONEY)))
		setChild("APLabel", invSettings.showCurrencyAlliancePoints ~= false, zo_strformat("AP: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_ALLIANCE_POINTS)), GetCurrencyGamepadIcon(CURT_ALLIANCE_POINTS)))
		setChild("TVLabel", invSettings.showCurrencyTelVar ~= false, zo_strformat("TEL VAR: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_TELVAR_STONES)), GetCurrencyGamepadIcon(CURT_TELVAR_STONES)))
		setChild("GemsLabel", invSettings.showCurrencyCrownGems ~= false, zo_strformat("GEMS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_CROWN_GEMS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_CROWN_GEMS)))
		setChild("TCLabel", invSettings.showCurrencyTransmute ~= false, zo_strformat("TRANSMUTE: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_STYLE_STONES)))
		setChild("CrownsLabel", invSettings.showCurrencyCrowns ~= false, zo_strformat("CROWNS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_CROWNS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_CROWNS)))
		setChild("WritsLabel", invSettings.showCurrencyWritVouchers ~= false, zo_strformat("WRITS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_WRIT_VOUCHERS)), GetCurrencyGamepadIcon(CURT_WRIT_VOUCHERS)))
		setChild("TicketsLabel", invSettings.showCurrencyEventTickets ~= false, zo_strformat("TICKETS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_EVENT_TICKETS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_EVENT_TICKETS)))
		setChild("KeysLabel", invSettings.showCurrencyUndauntedKeys ~= false, zo_strformat("KEYS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_UNDAUNTED_KEYS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_UNDAUNTED_KEYS)))
		setChild("OutfitLabel", invSettings.showCurrencyOutfitTokens ~= false, zo_strformat("OUTFIT: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.DisplayNumber(GetCurrencyAmount(CURT_STYLE_STONES, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_STYLE_STONES)))
	end
end
