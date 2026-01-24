--[[
File: Globals.lua
Purpose: Defines the core addon namespace (BETTERUI) and global utility functions.
         Serves as the foundation for module registration and shared helper methods.
Mechanics: Initializes the global BETTERUI table and sub-tables for modules.
           Provides text formatting, hook management, and external addon integration helpers.
Author: BetterUI Team
Last Modified: 2026-01-23
]]

-- Compatibility patch by Friday_The13_rus for AutoCategory integration
-- and shared utilities for BetterUI


BETTERUI = {
	ResearchTraits = {}  -- Cached research trait data per craft type, indexed by craftType -> researchLine -> traitIndex
}

BETTERUI.name = "BetterUI"
BETTERUI.version = "2.93"

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

BETTERUI.GeneralInterface = {} -- Renamed from Tooltips
BETTERUI.Tooltips = BETTERUI.GeneralInterface -- Backwards compatibility alias
BETTERUI.Nameplates = {} -- Enhanced nameplate customization
BETTERUI.ResourceOrbFrames = {} -- Custom ARPG-style resource orbs

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

--- Checks if a specific BetterUI module is enabled.
--- Handles potential inconsistency between 'm_enabled' and 'enabled' setting keys.
--- @param moduleName string The key of the module in BETTERUI.Settings.Modules
--- @return boolean True if the module is enabled
function BETTERUI.GetModuleEnabled(moduleName)
	if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return false end
	local settings = BETTERUI.Settings.Modules[moduleName]
	if not settings then return false end

	-- Check standard key first
	if settings.m_enabled ~= nil then
		return settings.m_enabled
	end
	-- Fallback to legacy key
	if settings.enabled ~= nil then
		return settings.enabled
	end

	return false
end

-- TODO(NAMESPACE): Move ddebug to BETTERUI.Debug(str) to avoid global namespace pollution.
-- Global function names risk collision with other addons.
-- Pattern to follow: BETTERUI.SomeModule.SomeFunction()
-- Current usage: ~50 call sites across codebase.
--- Prints a debug message to chat with BetterUI prefix.
---
--- Purpose: Standardized debug logging for development.
--- Mechanics: Prefixes the message with cyan [BETTERUI] tag and prints to chat.
--- References: Used globally throughout the addon for debug logging.
---
--- @param str string The message string to display.
function ddebug(str)
	return d("|c0066ff[BETTERUI]|r "..str)
end

--- Rounds a number to a specified number of decimal places.
---
--- Purpose: Utility for numeric formatting in UI elements.
--- Mechanics: Multiplies by power of 10, floors, and divides back to truncate/round.
--- References: Used internally by AbbreviateNumber and other UI formatting logic.
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
--- References: Used by AbbreviateNumber and general UI display elements.
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
--- References: Used by ResourceOrbs, Currency displays, and other compact UI elements.
---
--- @param n number The number to abbreviate.
--- @param defaultDecimals number|nil Optional default decimal places (defaults to 2).
--- @return string The abbreviated number string.
-- TODO(DUPLICATION): AbbreviateNumber and FormatAbbreviatedNumber (line 191) have overlapping functionality.
-- Consider consolidating into single function with options parameter:
--   BETTERUI.FormatNumber(n, {style="abbreviated", case="upper", decimals=2})
-- This would reduce code and ensure consistent formatting across the addon.
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

--- Formats a number into abbreviated form (K, M, B) with caps, for Inventory.
---
--- Purpose: compact display for inventory values.
--- Mechanics: similar to AbbreviateNumber but uses capitalized suffixes and slightly different flooring logic.
--- References: moved from InventoryList.lua
---
--- @param value number The number to format
--- @return string Formatted string like "1.12K", "12.3K", "123K", "1.23M".
function BETTERUI.FormatAbbreviatedNumber(value)
    if not value or value == 0 then
        return "0"
    end
    
    local absValue = math.abs(value)
    local sign = value < 0 and "-" or ""
    
    if absValue >= 1000000000 then
        -- Billions
        local num = absValue / 1000000000
        if num >= 100 then
            return sign .. string.format("%.0fB", num)
        elseif num >= 10 then
            return sign .. string.format("%.1fB", num)
        else
            return sign .. string.format("%.2fB", num)
        end
    elseif absValue >= 1000000 then
        -- Millions
        local num = absValue / 1000000
        if num >= 100 then
            return sign .. string.format("%.0fM", num)
        elseif num >= 10 then
            return sign .. string.format("%.1fM", num)
        else
            return sign .. string.format("%.2fM", num)
        end
    elseif absValue >= 1000 then
        -- Thousands
        local num = absValue / 1000
        if num >= 100 then
            return sign .. string.format("%.0fK", num)
        elseif num >= 10 then
            return sign .. string.format("%.1fK", num)
        else
            return sign .. string.format("%.2fK", num)
        end
    else
        -- Less than 1000, show as-is (no commas, integer only)
        return sign .. tostring(math.floor(absValue))
    end
end

--- Applies a currency preset configuration to a settings table.
---
--- Purpose: Centralized logic for applying currency presets (Default, PvP, etc).
--- Mechanics: Lookups up preset in BETTERUI.CONST.CURRENCY_PRESETS and applies values.
--- References: Used by Inventory settings.
---
--- @param presetName string The key of the preset (e.g., "pvp").
--- @param targetSettings table|nil The settings table to update. Defaults to BETTERUI.Settings.Modules["Inventory"].
function BETTERUI.ApplyCurrencyPreset(presetName, targetSettings)
    if not BETTERUI.CONST.CURRENCY_PRESETS then return end
    local preset = BETTERUI.CONST.CURRENCY_PRESETS[presetName]
    if not preset then return end
    
    local inv = targetSettings or (BETTERUI.Settings.Modules and BETTERUI.Settings.Modules["Inventory"])
    if not inv then return end
    
    for key, value in pairs(preset) do
        inv[key] = value
    end
end

--- Safely returns an icon path string.
---
--- Purpose: Prevents crashes or errors when passing nil icon paths to ESO API functions.
--- Mechanics: Checks if iconPath is nil; returns empty string if so, otherwise returns original path.
--- References: Used by Inventory, Banking, and Writ lists to ensure icon validity.
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

-- TODO(NAMESPACE): Move CUSTOM_GAMEPAD_ITEM_SORT to BETTERUI.CONST.INVENTORY.SORT_SCHEMA
-- This constant is only used by the sort comparator below.
local CUSTOM_GAMEPAD_ITEM_SORT = {
	sortPriorityName  = { tiebreaker = "bestItemTypeName" },
	bestItemTypeName = { tiebreaker = "name" },
	name = { tiebreaker = "requiredLevel" },
	requiredLevel = { tiebreaker = "requiredChampionPoints", isNumeric = true },
	requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
	iconFile = { tiebreaker = "uniqueId" },
	uniqueId = { isId64 = true },
}

-- TODO(NAMESPACE): Rename to BETTERUI.Inventory.DefaultSortComparator
-- Global function BETTERUI_GamepadInventory_DefaultItemSortComparator pollutes namespace.
-- This is referenced in: Banking.lua:509, Inventory.lua (multiple), InventoryList.lua
-- After renaming, update all call sites and remove this global.
--- Custom comparison function for sorting gamepad inventory items.
---
--- Purpose: Defines a specific sort order: Type -> Name -> Level -> CP -> Icon -> ID.
--- Mechanics: Uses ZO_TableOrderingFunction with a custom schema.
--- References: Used by the gamepad inventory list (Sort Comparator).
---
--- @param left table The first item data.
--- @param right table The second item data.
--- @return boolean True if 'left' should appear before 'right'.
function BETTERUI_GamepadInventory_DefaultItemSortComparator(left, right)
	return ZO_TableOrderingFunction(left, right, "sortPriorityName", CUSTOM_GAMEPAD_ITEM_SORT, ZO_SORT_ORDER_UP)
end

--- Retrieves the market price of an item from third-party trade addons.
---
--- Purpose: Integration with MM, ATT, and TTC to display price info in tooltips.
--- Mechanics: Checks which addon integration is enabled in settings.
---            Calls the specific addon's API to fetch price data.
---            Returns the average price multiplied by stack size.
--- References: Used by BetterUI.Tooltips and Inventory rows to show value.
---
--- @param itemLink string The item link.
--- @param stackCount number The stack size (defaults to 1).
--- @return number The calculated total price, or 0 if unavailable.
function BETTERUI.GetMarketPrice(itemLink, stackCount)
    if not itemLink then return 0 end
    if not BETTERUI.Settings or not BETTERUI.Settings.Modules then
        return 0
    end
    -- Support both GeneralInterface (new) and Tooltips (legacy) settings keys
    local tooltipSettings = BETTERUI.Settings.Modules["GeneralInterface"] or BETTERUI.Settings.Modules["Tooltips"]
    if not tooltipSettings then
        return 0
    end
    stackCount = stackCount or 1

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
--- References: Used by Inventory list setup to assign items to dynamic categories.
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

-- TODO(DUPLICATION): PostHook and Hook (below) share 80% of their implementation.
-- Consider refactoring to a single internal function:
--   local function createHook(control, method, fn, position) -- position = "before"|"after"|"replace"
-- Then expose as:
--   BETTERUI.PreHook(control, method, fn)   -- runs before original
--   BETTERUI.PostHook(control, method, fn)  -- runs after original  
--   BETTERUI.ReplaceHook(control, method, fn) -- replaces original
--- Hooks a method to run AFTER the original method.
---
--- Purpose: Safe method extension.
--- Mechanics: Replaces the method on the control with a wrapper that calls Original -> New.
--- References: General utility used internally generally.
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
--- References: General utility used for aggressive overrides (e.g. replacing Action Dialogs).
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
--- References: Used by all Modules (Inventory, Banking, etc.) in their Initialization.
---
--- @param moduleName string The display name of the module.
--- @param moduleDesc string The description text.
--- @return table The LAM panel configuration table.
function BETTERUI.Init_ModulePanel(moduleName, moduleDesc)
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

-- TODO(RISKY-OVERRIDE): Investigate if this ZO_Store_OnInitialize_Gamepad override is still necessary.
-- This completely suppresses the native gamepad store initialization.
-- Risk: If this breaks store functionality, users have no recourse.
-- Recommendation: Test removal in isolated environment. If needed, consider:
--   1. Hook AFTER native init instead of replacing entirely
--   2. Document specific conflict this prevents
--   3. Add runtime check to skip if not needed
--[[
Override: ZO_Store_OnInitialize_Gamepad
Rationale: Suppresses the native gamepad store initialization to prevent potential
           conflicts with BetterUI's custom gamepad UI systems. While BetterUI does
           not implement a custom store, this empty override ensures the native
           initialization doesn't interfere with BetterUI's global UI modifications.
           
           Removing this override has not been tested and may cause UI conflicts.
           If store functionality issues arise, this override should be investigated.
           
Added: Legacy (pre-2.0)
Status: Preserved for stability - removal requires in-game testing
]]
-- Empty override for store initialization (testing status: confirmed needed for some UI refresh cycles)
ZO_Store_OnInitialize_Gamepad = function(...) end


