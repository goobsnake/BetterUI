--[[
    BetterUI Generic Footer
    Description: Logic for the Gamepad Bottom Bar (Footer).
    Displays:
    - Bag/Bank Capacity
    - Various Currencies (Gold, AP, Tel Var, etc.)
    features:
    - Dynamic ordering of currencies based on user settings.
    - Automatic abbreviation of large numbers (k/m/b).
]]

local _

--- Initialize the footer control reference.
--- Purpose: Links the Lua object to the XML control.
--- @param control table The parent control containing the footer.
function BETTERUI.GenericFooter:Initialize()
	if(self.footer == nil) then self.footer = self.control.container:GetNamedChild("FooterContainer").footer end

	if(self.footer.GoldLabel ~= nil) then BETTERUI.GenericFooter.Refresh(self) end
end

--- Refreshes the footer content and layout.
---
--- Purpose: Updates bag capacity and currency displays based on user settings.
--- Mechanics:
--- 1. Updates Capacity Labels (Backpack and Bank).
--- 2. Updates Currency Labels (Gold, AP, Tel Var, etc.) with formatted values.
--- 3. Dynamically positions currency labels based on user-defined order.
--- 4. Handles fallback layout if specific XML structure is missing.
function BETTERUI.GenericFooter:Refresh()
	-- Reference inventory settings for currency visibility/order
	local invSettings = BETTERUI.Settings.Modules["Inventory"]

    -- Helper to show/hide and set text for a label
	local function setLabel(labelControl, enabled, text)
		labelControl:SetHidden(not enabled)
		if enabled then labelControl:SetText(text) end
	end

	-- Use global helper to ensure icon values passed into formatting are safe (escaped properly for texture strings)
	local SafeIcon = BETTERUI.SafeIcon

	if(self.footer.GoldLabel ~= nil) then
		-- Update Capacity Labels (Always visible)
        -- Format: BAG: (Used/Total) [Icon]
		self.footer.CWLabel:SetText(zo_strformat("BAG: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
		self.footer.BankLabel:SetText(zo_strformat("BANK: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK), GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))


        -- Update Currency Labels with formatted values and icons
        -- Checks specific settings keys for visibility
		setLabel(self.footer.GoldLabel, invSettings.showCurrencyGold ~= false, zo_strformat("GOLD: |cFFBF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_MONEY)), SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))))
		setLabel(self.footer.APLabel, invSettings.showCurrencyAlliancePoints ~= false, zo_strformat("AP: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_ALLIANCE_POINTS)), SafeIcon(GetCurrencyGamepadIcon(CURT_ALLIANCE_POINTS))))
		setLabel(self.footer.TVLabel, invSettings.showCurrencyTelVar ~= false, zo_strformat("TEL VAR: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_TELVAR_STONES)), SafeIcon(GetCurrencyGamepadIcon(CURT_TELVAR_STONES))))
		setLabel(self.footer.GemsLabel, invSettings.showCurrencyCrownGems ~= false, zo_strformat("GEMS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CROWN_GEMS, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_CROWN_GEMS))))
		setLabel(self.footer.TCLabel, invSettings.showCurrencyTransmute ~= false, zo_strformat("TRANSMUTE: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_STYLE_STONES))))
		setLabel(self.footer.CrownsLabel, invSettings.showCurrencyCrowns ~= false, zo_strformat("CROWNS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CROWNS, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_CROWNS))))
		setLabel(self.footer.WritsLabel, invSettings.showCurrencyWritVouchers ~= false, zo_strformat("WRITS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_WRIT_VOUCHERS)), SafeIcon(GetCurrencyGamepadIcon(CURT_WRIT_VOUCHERS))))
		setLabel(self.footer.TicketsLabel, invSettings.showCurrencyEventTickets ~= false, zo_strformat("TICKETS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_EVENT_TICKETS, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_EVENT_TICKETS))))
		setLabel(self.footer.KeysLabel, invSettings.showCurrencyUndauntedKeys ~= false, zo_strformat("KEYS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_UNDAUNTED_KEYS, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_UNDAUNTED_KEYS))))
		setLabel(self.footer.OutfitLabel, invSettings.showCurrencyOutfitTokens ~= false, zo_strformat("OUTFIT: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_STYLE_STONES, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_STYLE_STONES))))

    	-- Dynamic layout: Order left-to-right, top row then bottom row based on user order string (e.g. "gold,ap,telvar...")
        -- Default order if setting is missing
    	local orderStr = BETTERUI.Settings.Modules["Inventory"].currencyOrder or "gold,ap,telvar,keys,transmute,crowns,gems,writs,tickets,outfit"
		
        -- Map token names to Control names and Settings keys
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

		-- X Positions for each column.
        -- Reserve leftmost column (X=0) for BAG/BANK labels; currencies start at 200.
		local ltrX = {200, 450, 700, 950, 1150}
		local yTop, yBottom = 32, 58

		-- Build list of visible tokens in the desired order
		local seen = {}
		local visible = {}
        
        -- First pass: Add enabled tokens found in the order string
		for token in string.gmatch(string.lower(orderStr), "[^,%s]+") do
			local entry = map[token]
			if entry then
				seen[token] = true
				local enabled = invSettings[entry.enabledKey] ~= false
				if enabled then table.insert(visible, token) end
			end
		end
        
        -- Second pass: Add any remaining enabled tokens that weren't in the order string (fallback)
		for token, entry in pairs(map) do
			if not seen[token] then
				local enabled = invSettings[entry.enabledKey] ~= false
				if enabled then table.insert(visible, token) end
			end
		end

        -- Position the visible labels
		local parent = self.footer
		for idx, token in ipairs(visible) do
			local entry = map[token]
			local ctrl = parent[entry.name] or parent:GetNamedChild(entry.name)
			if ctrl then
				ctrl:ClearAnchors()
				local perRow = #ltrX
				local col = ((idx - 1) % perRow) + 1 -- Wrap around columns
				local rowY = (idx <= perRow) and yTop or yBottom -- Move to second row if needed
				ctrl:SetAnchor(LEFT, parent, BOTTOMLEFT, ltrX[col], rowY)
			end
		end
	else
		-- Fallback path: If self.footer.GoldLabel is nil (likely due to different XML structure or initialization timing),
        -- try to find children by name and perform a similar update.
        -- TODO: Unify this logic with the block above to avoid code duplication.
		local footer = self.footer
		footer:GetNamedChild("CWLabel"):SetText(zo_strformat("BAG: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK))))
		footer:GetNamedChild("BankLabel"):SetText(zo_strformat("BANK: (<<1>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t", zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK), GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK))))

		local function setChild(name, enabled, text)
			local c = footer:GetNamedChild(name)
			c:SetHidden(not enabled)
			if enabled then c:SetText(text) end
		end

		setChild("GoldLabel", invSettings.showCurrencyGold ~= false, zo_strformat("GOLD: |cFFBF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_MONEY)), SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))))
		setChild("APLabel", invSettings.showCurrencyAlliancePoints ~= false, zo_strformat("AP: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_ALLIANCE_POINTS)), SafeIcon(GetCurrencyGamepadIcon(CURT_ALLIANCE_POINTS))))
		setChild("TVLabel", invSettings.showCurrencyTelVar ~= false, zo_strformat("TEL VAR: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_TELVAR_STONES)), SafeIcon(GetCurrencyGamepadIcon(CURT_TELVAR_STONES))))
		setChild("GemsLabel", invSettings.showCurrencyCrownGems ~= false, zo_strformat("GEMS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CROWN_GEMS, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_CROWN_GEMS))))
		setChild("TCLabel", invSettings.showCurrencyTransmute ~= false, zo_strformat("TRANSMUTE: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_STYLE_STONES))))
		setChild("CrownsLabel", invSettings.showCurrencyCrowns ~= false, zo_strformat("CROWNS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_CROWNS, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_CROWNS))))
		setChild("WritsLabel", invSettings.showCurrencyWritVouchers ~= false, zo_strformat("WRITS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_WRIT_VOUCHERS)), SafeIcon(GetCurrencyGamepadIcon(CURT_WRIT_VOUCHERS))))
		setChild("TicketsLabel", invSettings.showCurrencyEventTickets ~= false, zo_strformat("TICKETS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_EVENT_TICKETS, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_EVENT_TICKETS))))
		setChild("KeysLabel", invSettings.showCurrencyUndauntedKeys ~= false, zo_strformat("KEYS: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_UNDAUNTED_KEYS, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_UNDAUNTED_KEYS))))
		setChild("OutfitLabel", invSettings.showCurrencyOutfitTokens ~= false, zo_strformat("OUTFIT: |c00FF00<<1>>|r |t24:24:<<2>>|t", BETTERUI.AbbreviateNumber(GetCurrencyAmount(CURT_STYLE_STONES, CURRENCY_LOCATION_ACCOUNT)), SafeIcon(GetCurrencyGamepadIcon(CURT_STYLE_STONES))))

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
