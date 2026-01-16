-- BetterUI Globals
---
--- Purpose: Defines the core addon namespace (BETTERUI) and global utility functions.
---          Serves as the foundation for module registration and shared helper methods.
--- Mechanics: Initializes the global BETTERUI table and sub-tables for modules.
---            Provides text formatting, hook management, and external addon integration helpers.
---

-- Compatibility patch by Friday_The13_rus for AutoCategory integration

BETTERUI = {
	ResearchTraits = {}  -- Cached research trait data per craft type, indexed by craftType -> researchLine -> traitIndex
}

BETTERUI.name = "BetterUI"
BETTERUI.version = "2.92"

-- ESO API references
--- Cache global API managers for performance and ease of access.
BETTERUI.WindowManager = GetWindowManager()
BETTERUI.EventManager = GetEventManager()

-- Module namespaces
BETTERUI.CONST = {}   -- Constants and configuration values
BETTERUI.CIM = {}     -- Common Interface Module

-- UI component modules
BETTERUI.GenericHeader = {}        -- Custom header for inventory/banking
BETTERUI.GenericFooter = {}        -- Custom footer with currency display
BETTERUI.Interface = {}            -- Base interface utilities
BETTERUI.Interface.Window = {}     -- Window management class

-- Feature modules
BETTERUI.Inventory = {
	List = {},   -- Inventory list implementation
	Class = {},  -- Main inventory class
}

BETTERUI.Writs = {
	List = {}    -- Active writ quest tracking
}

BETTERUI.Banking = {
	Class = {}   -- Banking interface class
}

BETTERUI.Tooltips = {}   -- Tooltip enhancements (pricing, traits)
BETTERUI.Nameplates = {} -- Enhanced nameplate customization

-- Settings storage
BETTERUI.Settings = {}

-- Default settings template (AceDB-style wildcard defaults)
BETTERUI.DefaultSettings = {
	firstInstall = true,
	useAccountWide = false,
	Modules = {
		["*"] = { m_enabled = true }  -- All modules enabled by default
	}
}

--- Prints a debug message to chat with BetterUI prefix.
---
--- Purpose: Standardized debug logging for development.
--- Mechanics: Prefixes the message with cyan [BETTERUI] tag and prints to chat.
---
--- @param str string The message string to display.
function ddebug(str)
	return d("|c0066ff[BETTERUI]|r "..str)
end

--- Rounds a number to a specified number of decimal places.
---
--- Purpose: Utility for numeric formatting in UI elements.
--- Mechanics: Multiplies by power of 10, floors, and divides back to truncate/round.
---
--- @param number number The value to round.
--- @param decimals number The number of decimal places to keep.
--- @return number|string The rounded number, formatted as a string (via string.format), or 0 if inputs invalid.
function BETTERUI.roundNumber(number, decimals)
	if number ~= nil and decimals ~= nil then
		local power = 10^decimals
		return string.format("%.2f", math.floor(number * power) / power)
	else
		return 0
	end
end

--- Formats a number with comma separators (e.g., 1234567 -> 1,234,567).
--- Credits: Bart Kiers
---
--- Purpose: Improves readability of large currency values in the UI.
--- Mechanics: Uses string pattern matching to insert commas every 3 digits.
---
--- @param number number The number to format.
--- @return string The formatted string with commas.
function BETTERUI.DisplayNumber(number)
	local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
	-- reverse the int-string and append a comma to all blocks of 3 digits
	int = int:reverse():gsub("(%d%d%d)", "%1,")
	-- reverse the int-string back remove an optional comma and put the
	-- optional minus and fractional part back
	return minus .. int:reverse():gsub("^,", "") .. fraction
end

--- Abbreviates large numbers using k/m/b suffixes.
---
--- Purpose: Compact display of large values (Health, XP, Gold) where space is limited.
--- Mechanics: Checks magnitude (Billions -> Millions -> Thousands) and formats accordingly.
---            Rules:
---             - >= 1B: 'b' suffix, 2 decimals
---             - >= 1M: 'm' suffix, 2 decimals
---             - >= 1k: 'k' suffix, 0 decimals if integer, 2 if float
---             - < 1k: Comma separated (DisplayNumber)
---
--- @param n number The number to abbreviate.
--- @param defaultDecimals number|nil Optional default decimal places (defaults to 2).
--- @return string The abbreviated number string.
function BETTERUI.AbbreviateNumber(n, defaultDecimals)
	local abs = math.abs(n or 0)
	local suffix = ""
	local value = n or 0
	local decimals = defaultDecimals or 2

	if abs >= 1000000000 then
		suffix = "b"
		value = value / 1000000000
		-- always 2 decimals for billions
		decimals = 2
	elseif abs >= 1000000 then
		suffix = "m"
		value = value / 1000000
		-- always 2 decimals for millions
		decimals = 2
	elseif abs >= 1000 then
		suffix = "k"
		value = value / 1000
		-- for thousands, show 0 decimals if integer, else 2
		if value == math.floor(value) then
			decimals = 0
		else
			decimals = 2
		end
	else
		return BETTERUI.DisplayNumber(n or 0)
	end

	local fmt = "%0." .. tostring(decimals) .. "f"
	return string.format(fmt, value) .. suffix
end

--- Safely returns an icon path string.
---
--- Purpose: Prevents crashes or errors when passing nil icon paths to ESO API functions.
--- Mechanics: Checks if iconPath is nil; returns empty string if so, otherwise returns original path.
---
--- @param iconPath string|nil The path to the icon texture.
--- @return string The icon path or an empty string.
function BETTERUI.SafeIcon(iconPath)
	if iconPath == nil then return "" end
	return iconPath
end

--- Populates the ResearchTraits cache.
---
--- Purpose: Caches player's research knowledge to avoid expensive API calls during list rendering.
--- Mechanics: Iterates through all crafting types, research lines, and traits.
---            Stores boolean status (known/unknown) in BETTERUI.ResearchTraits.
--- References: Called on initialization and when research completes.
---
--- @param forceRefresh boolean If true, ignores existing cache and rebuilds data.
function BETTERUI.GetResearch(forceRefresh)
	if not forceRefresh and BETTERUI.ResearchTraits and next(BETTERUI.ResearchTraits) then
		return -- Use cached data
	end

	BETTERUI.ResearchTraits = {}
	for i, craftType in pairs(BETTERUI.CONST.CraftingSkillTypes) do
		BETTERUI.ResearchTraits[craftType] = {}
		for researchIndex = 1, GetNumSmithingResearchLines(craftType) do
			local name, icon, numTraits, timeRequiredForNextResearchSecs = GetSmithingResearchLineInfo(craftType, researchIndex)
			BETTERUI.ResearchTraits[craftType][researchIndex] = {}
			for traitIndex = 1, numTraits do
				local traitType, _, known = GetSmithingResearchLineTraitInfo(craftType, researchIndex, traitIndex)
				BETTERUI.ResearchTraits[craftType][researchIndex][traitIndex] = known
			end
		end
	end
end

--- Custom comparison function for sorting gamepad inventory items.
---
--- Purpose: Defines a specific sort order: Type -> Name -> Level -> CP -> Icon -> ID.
--- Mechanics: Uses ZO_TableOrderingFunction with a custom schema.
---
--- @param left table The first item data.
--- @param right table The second item data.
--- @return boolean True if 'left' should appear before 'right'.
function BETTERUI_GamepadInventory_DefaultItemSortComparator(left, right)
	local CUSTOM_GAMEPAD_ITEM_SORT = {
		sortPriorityName  = { tiebreaker = "bestItemTypeName" },
		bestItemTypeName = { tiebreaker = "name" },
		name = { tiebreaker = "requiredLevel" },
		requiredLevel = { tiebreaker = "requiredChampionPoints", isNumeric = true },
		requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
		iconFile = { tiebreaker = "uniqueId" },
		uniqueId = { isId64 = true },
	}
	return ZO_TableOrderingFunction(left, right, "sortPriorityName", CUSTOM_GAMEPAD_ITEM_SORT, ZO_SORT_ORDER_UP)
end

--- Retrieves the market price of an item from third-party trade addons.
---
--- Purpose: Integration with MM, ATT, and TTC to display price info in tooltips.
--- Mechanics: Checks which addon integration is enabled in settings.
---            Calls the specific addon's API to fetch price data.
---            Returns the average price multiplied by stack size.
---
--- @param itemLink string The item link.
--- @param stackCount number The stack size (defaults to 1).
--- @return number The calculated total price, or 0 if unavailable.
function BETTERUI.GetMarketPrice(itemLink, stackCount)
    if not itemLink then return 0 end
    if not BETTERUI.Settings or not BETTERUI.Settings.Modules or not BETTERUI.Settings.Modules["Tooltips"] then
        return 0
    end

    stackCount = stackCount or 1
    local tooltipSettings = BETTERUI.Settings.Modules["Tooltips"]

    -- Check MasterMerchant integration first (most commonly used)
    if MasterMerchant ~= nil and tooltipSettings.mmIntegration then
        local mmData = MasterMerchant:itemStats(itemLink, false)
        if mmData and mmData.avgPrice and mmData.avgPrice > 0 then
            return mmData.avgPrice * stackCount
        end
    end

    -- Check Arkadius Trade Tools
    if ArkadiusTradeTools ~= nil and tooltipSettings.attIntegration then
        local avgPrice = ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(itemLink, nil, nil)
        if avgPrice and avgPrice > 0 then
            return avgPrice * stackCount
        end
    end

    -- Check Tamriel Trade Centre
    if TamrielTradeCentre ~= nil and tooltipSettings.ttcIntegration then
        local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
        if priceInfo then
            if priceInfo.Avg then
                return priceInfo.Avg * stackCount
            elseif priceInfo.SuggestedPrice then
                return priceInfo.SuggestedPrice * stackCount
            end
        end
    end

    return 0
end

--- Retrieves custom category information from AutoCategory addon.
---
--- Purpose: Integration with AutoCategory for advanced inventory sorting.
--- Mechanics: Checks if AutoCategory is loaded and initialized.
---            Calls MatchCategoryRules to get rule-based categorization.
---
--- @param itemData table The item data (must contain bagId and slotIndex).
--- @return boolean useCustomCategory (True if AutoCategory is active).
--- @return boolean matched (True if a rule matched).
--- @return string categoryName (The name of the matched category).
--- @return number categoryPriority (The priority for sorting).
function BETTERUI.GetCustomCategory(itemData)
	local useCustomCategory = false
	--shadowcep[[
	if AutoCategory and AutoCategory.Inited then
	--shadowcep]]
		useCustomCategory = true
		local bagId = itemData.bagId
		local slotIndex = itemData.slotIndex
		local matched, categoryName, categoryPriority = AutoCategory:MatchCategoryRules(bagId, slotIndex)
		return useCustomCategory, matched, categoryName, categoryPriority
	end

	return useCustomCategory, false, "", 0
end

--- Hooks a method to run AFTER the original method.
---
--- Purpose: Safe method extension.
--- Mechanics: Replaces the method on the control with a wrapper that calls Original -> New.
---
--- @param control table The UI control or object.
--- @param method string The name of the method to hook.
--- @param fn function The function to execute after the original.
function BETTERUI.PostHook(control, method, fn)
	if control == nil then return end

	local originalMethod = control[method]
	control[method] = function(self, ...)
		originalMethod(self, ...)
		fn(self, ...)
	end
end

--- Generalized hook function with optional original method suppression.
---
--- Purpose: flexible hooking for replacing or extending functionality.
--- Mechanics: Replaces key 'method' on 'control'.
---            If overwriteOriginal is false (default), runs Original -> New.
---            If overwriteOriginal is true, runs ONLY New.
---
--- @param control table The UI control.
--- @param method string The method name.
--- @param postHookFunction function The new function.
--- @param overwriteOriginal boolean If true, the original method is NOT called.
function BETTERUI.Hook(control, method, postHookFunction, overwriteOriginal)
	if control == nil then return end

	local originalMethod = control[method]
	control[method] = function(self, ...)
		if overwriteOriginal == false then originalMethod(self, ...) end
		postHookFunction(self, ...)
	end
end

--- Creates a standardized module configuration panel for LibAddonMenu.
---
--- Purpose: Ensures consistent settings menu appearance across modules.
--- Mechanics: Returns a table matching LAM's panel specification.
---
--- @param moduleName string The display name of the module.
--- @param moduleDesc string The description text.
--- @return table The LAM panel configuration table.
function Init_ModulePanel(moduleName, moduleDesc)
	return {
		type = "panel",
		name = "|t24:24:/esoui/art/buttons/gamepad/xbox/nav_xbone_b.dds|t " .. BETTERUI.name .. " (" .. moduleName .. ")",
		displayName = "|c0066ffBETTERUI|r :: " .. moduleDesc,
		author = "prasoc, RockingDice, Goobsnake",
		version = BETTERUI.version,
		slashCommand = "/betterui",
		registerForRefresh = true,
		registerForDefaults = true
	}
end

ZO_Store_OnInitialize_Gamepad = function(...) end

-- Imagery, you dont need to localise these strings
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_TEXT_HIGHLIGHT","|cFF6600<<1>>|r")
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_TEXT_NORMAL","|cCCCCCC<<1>>|r")
