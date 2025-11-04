local _

--- Initializes the generic footer by setting up the footer control reference
function BETTERUI.GenericFooter:Initialize()
	if(self.footer == nil) then self.footer = self.control.container:GetNamedChild("FooterContainer").footer end

	if(self.footer.GoldLabel ~= nil) then BETTERUI.GenericFooter.Refresh(self) end
end

--- Refreshes the footer display with current bag capacities and currency amounts, arranging currencies dynamically based on user settings
function BETTERUI.GenericFooter:Refresh()
	-- a hack until I completely generalize these functions... 
	local invSettings = BETTERUI.Settings.Modules["Inventory"]

	local function setLabel(labelControl, enabled, text)
		labelControl:SetHidden(not enabled)
		if enabled then labelControl:SetText(text) end
	end

	if(self.footer.GoldLabel ~= nil) then
		-- Bag/Bank capacities (not currencies) remain always visible
		self.footer.CWLabel:SetText(zo_strformat("BAG: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
		self.footer.BankLabel:SetText(zo_strformat("BANK: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK), GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))

		setLabel(self.footer.GoldLabel, invSettings.showCurrencyGold ~= false, zo_strformat("GOLD: |cFFBF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_MONEY)), GetCurrencyGamepadIcon(CURT_MONEY)))
		setLabel(self.footer.APLabel, invSettings.showCurrencyAlliancePoints ~= false, zo_strformat("AP: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_ALLIANCE_POINTS)), GetCurrencyGamepadIcon(CURT_ALLIANCE_POINTS)))
		setLabel(self.footer.TVLabel, invSettings.showCurrencyTelVar ~= false, zo_strformat("TEL VAR: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_TELVAR_STONES)), GetCurrencyGamepadIcon(CURT_TELVAR_STONES)))
		setLabel(self.footer.GemsLabel, invSettings.showCurrencyCrownGems ~= false, zo_strformat("GEMS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CROWN_GEMS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_CROWN_GEMS)))
		setLabel(self.footer.TCLabel, invSettings.showCurrencyTransmute ~= false, zo_strformat("TRANSMUTE: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_STYLE_STONES)))
		setLabel(self.footer.CrownsLabel, invSettings.showCurrencyCrowns ~= false, zo_strformat("CROWNS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CROWNS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_CROWNS)))
		setLabel(self.footer.WritsLabel, invSettings.showCurrencyWritVouchers ~= false, zo_strformat("WRITS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_WRIT_VOUCHERS)), GetCurrencyGamepadIcon(CURT_WRIT_VOUCHERS)))
		setLabel(self.footer.TicketsLabel, invSettings.showCurrencyEventTickets ~= false, zo_strformat("TICKETS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_EVENT_TICKETS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_EVENT_TICKETS)))
		setLabel(self.footer.KeysLabel, invSettings.showCurrencyUndauntedKeys ~= false, zo_strformat("KEYS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_UNDAUNTED_KEYS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_UNDAUNTED_KEYS)))
		setLabel(self.footer.OutfitLabel, invSettings.showCurrencyOutfitTokens ~= false, zo_strformat("OUTFIT: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_STYLE_STONES, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_STYLE_STONES)))

    		-- Dynamic layout: order left-to-right, top row then bottom row based on user order
	local orderStr = BETTERUI.Settings.Modules["Inventory"].currencyOrder or "gold,ap,telvar,keys,transmute,crowns,gems,writs,tickets,outfit"
		local map = {
			gold = { name = "GoldLabel", enabledKey = "showCurrencyGold" },
			ap = { name = "APLabel", enabledKey = "showCurrencyAlliancePoints" },
			telvar = { name = "TVLabel", enabledKey = "showCurrencyTelVar" },
			gems = { name = "GemsLabel", enabledKey = "showCurrencyCrownGems" },
			transmute = { name = "TCLabel", enabledKey = "showCurrencyTransmute" },
			crowns = { name = "CrownsLabel", enabledKey = "showCurrencyCrowns" },
			writs = { name = "WritsLabel", enabledKey = "showCurrencyWritVouchers" },
			tickets = { name = "TicketsLabel", enabledKey = "showCurrencyEventTickets" },
			keys = { name = "KeysLabel", enabledKey = "showCurrencyUndauntedKeys" },
			outfit = { name = "OutfitLabel", enabledKey = "showCurrencyOutfitTokens" },
		}

		-- Reserve leftmost column (X=0) for BAG/BANK labels; currencies start at 200
		local ltrX = {200, 450, 700, 950, 1150}
		local yTop, yBottom = 32, 58

		-- Build visible list following user order; append any remaining enabled ones not in orderStr
		local seen = {}
		local visible = {}
		for token in string.gmatch(string.lower(orderStr), "[^,%s]+") do
			local entry = map[token]
			if entry then
				seen[token] = true
				local enabled = invSettings[entry.enabledKey] ~= false
				if enabled then table.insert(visible, token) end
			end
		end
		for token, entry in pairs(map) do
			if not seen[token] then
				local enabled = invSettings[entry.enabledKey] ~= false
				if enabled then table.insert(visible, token) end
			end
		end

		local parent = self.footer
		for idx, token in ipairs(visible) do
			local entry = map[token]
			local ctrl = parent[entry.name] or parent:GetNamedChild(entry.name)
			if ctrl then
				ctrl:ClearAnchors()
				local perRow = #ltrX
				local col = ((idx - 1) % perRow) + 1
				local rowY = (idx <= perRow) and yTop or yBottom
				ctrl:SetAnchor(LEFT, parent, BOTTOMLEFT, ltrX[col], rowY)
			end
		end
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

		setChild("GoldLabel", invSettings.showCurrencyGold ~= false, zo_strformat("GOLD: |cFFBF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_MONEY)), GetCurrencyGamepadIcon(CURT_MONEY)))
		setChild("APLabel", invSettings.showCurrencyAlliancePoints ~= false, zo_strformat("AP: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_ALLIANCE_POINTS)), GetCurrencyGamepadIcon(CURT_ALLIANCE_POINTS)))
		setChild("TVLabel", invSettings.showCurrencyTelVar ~= false, zo_strformat("TEL VAR: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_TELVAR_STONES)), GetCurrencyGamepadIcon(CURT_TELVAR_STONES)))
		setChild("GemsLabel", invSettings.showCurrencyCrownGems ~= false, zo_strformat("GEMS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CROWN_GEMS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_CROWN_GEMS)))
		setChild("TCLabel", invSettings.showCurrencyTransmute ~= false, zo_strformat("TRANSMUTE: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_STYLE_STONES)))
		setChild("CrownsLabel", invSettings.showCurrencyCrowns ~= false, zo_strformat("CROWNS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CROWNS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_CROWNS)))
		setChild("WritsLabel", invSettings.showCurrencyWritVouchers ~= false, zo_strformat("WRITS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_WRIT_VOUCHERS)), GetCurrencyGamepadIcon(CURT_WRIT_VOUCHERS)))
		setChild("TicketsLabel", invSettings.showCurrencyEventTickets ~= false, zo_strformat("TICKETS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_EVENT_TICKETS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_EVENT_TICKETS)))
		setChild("KeysLabel", invSettings.showCurrencyUndauntedKeys ~= false, zo_strformat("KEYS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_UNDAUNTED_KEYS, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_UNDAUNTED_KEYS)))
		setChild("OutfitLabel", invSettings.showCurrencyOutfitTokens ~= false, zo_strformat("OUTFIT: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_STYLE_STONES, CURRENCY_LOCATION_ACCOUNT)), GetCurrencyGamepadIcon(CURT_STYLE_STONES)))

		-- Dynamic layout in fallback path
	local orderStr = BETTERUI.Settings.Modules["Inventory"].currencyOrder or "gold,ap,telvar,keys,transmute,crowns,gems,writs,tickets,outfit"
		local map = {
			gold = "GoldLabel", ap = "APLabel", telvar = "TVLabel", gems = "GemsLabel", transmute = "TCLabel",
			crowns = "CrownsLabel", writs = "WritsLabel", tickets = "TicketsLabel", keys = "KeysLabel", outfit = "OutfitLabel",
		}
		local enabledKey = {
			GoldLabel = "showCurrencyGold", APLabel = "showCurrencyAlliancePoints", TVLabel = "showCurrencyTelVar",
			GemsLabel = "showCurrencyCrownGems", TCLabel = "showCurrencyTransmute", CrownsLabel = "showCurrencyCrowns",
			WritsLabel = "showCurrencyWritVouchers", TicketsLabel = "showCurrencyEventTickets", KeysLabel = "showCurrencyUndauntedKeys", OutfitLabel = "showCurrencyOutfitTokens",
		}
		-- Reserve leftmost column (X=0) for BAG/BANK labels; currencies start at 200
		local ltrX = {200, 450, 700, 950, 1150}
		local yTop, yBottom = 32, 58
		local seen = {}
		local visible = {}
		for token in string.gmatch(string.lower(orderStr), "[^,%s]+") do
			local name = map[token]
			if name then
				seen[token] = true
				if invSettings[enabledKey[name]] ~= false then table.insert(visible, name) end
			end
		end
		for token, name in pairs(map) do
			if not seen[token] and invSettings[enabledKey[name]] ~= false then table.insert(visible, name) end
		end
		for idx, name in ipairs(visible) do
			local ctrl = footer:GetNamedChild(name)
			if ctrl then
				ctrl:ClearAnchors()
				local perRow = #ltrX
				local col = ((idx - 1) % perRow) + 1
				local rowY = (idx <= perRow) and yTop or yBottom
				ctrl:SetAnchor(LEFT, footer, BOTTOMLEFT, ltrX[col], rowY)
			end
		end
	end
end
