-- shadowcep: Patched for compatibility with latest version of AutoCategory (fix by Friday_The13_rus)
BETTERUI = {
	ResearchTraits = {}
}

BETTERUI.name = "BetterUI"
BETTERUI.version = "2.84"

-- Program Global (scope of BETTERUI, though) variable initialization
BETTERUI.WindowManager = GetWindowManager()
BETTERUI.EventManager = GetEventManager()

-- pseudo-Class definitions
BETTERUI.CONST = {}
BETTERUI.CIM = {}

BETTERUI.GenericHeader = {}
BETTERUI.GenericFooter = {}
BETTERUI.Interface = {}
BETTERUI.Interface.Window = {}

BETTERUI.Inventory = {
	List = {},
	Class = {},
}

BETTERUI.Writs = {
	List = {}
}

BETTERUI.Banking = {
	Class = {}
}

BETTERUI.Tooltips = {

}

BETTERUI.Settings = {}

BETTERUI.DefaultSettings = {
	firstInstall = true,
	Modules = {
		["*"] = { -- Module setting template
			m_enabled = true
		}
	}
}

function ddebug(str)
	return d("|c0066ff[BETTERUI]|r "..str)
end

--- Rounds a number to specified decimal places
--- @param number number: The number to round
--- @param decimals number: Number of decimal places
--- @return number: The rounded number or 0 if invalid input
function BETTERUI.roundNumber(number, decimals)
	if number ~= nil and decimals ~= nil then
		local power = 10^decimals
		return string.format("%.2f", math.floor(number * power) / power)
	else
		return 0
	end
end

--- Displays a message on screen using the center screen announce system
--- @param message string: The message to display
function BETTERUI.OnScreenMessage(message)
	local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
	messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_COUNTDOWN)
	messageParams:SetText(message)
	CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

--- Formats a number with comma separators (e.g., 1234567 -> 1,234,567)
--- Thanks to Bart Kiers for this function
--- @param number number: The number to format
--- @return string: The formatted number string
function BETTERUI.DisplayNumber(number)
	local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
	-- reverse the int-string and append a comma to all blocks of 3 digits
	int = int:reverse():gsub("(%d%d%d)", "%1,")
	-- reverse the int-string back remove an optional comma and put the
	-- optional minus and fractional part back
	return minus .. int:reverse():gsub("^,", "") .. fraction
end

--- Abbreviates large numbers using k/m/b with configurable decimals.
--- Rules:
---  - >= 1,000 => k; show 0 decimals if exact integer (e.g., 1k), else 2 decimals (e.g., 1.24k)
---  - >= 1,000,000 => m; always 2 decimals (e.g., 1.20m)
---  - >= 1,000,000,000 => b; always 2 decimals (e.g., 1.20b)
---  - < 1,000 uses DisplayNumber with separators
--- @param n number
--- @param defaultDecimals number|nil defaults to 2
--- @return string
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

--- Safely returns an icon path string or empty string if nil to avoid passing nil into ESO icon-format helpers.
--- @param iconPath string|nil: Path to the icon texture
--- @return string: iconPath or empty string
function BETTERUI.SafeIcon(iconPath)
	if iconPath == nil then return "" end
	return iconPath
end

--- Populates research traits data with caching to avoid redundant API calls. Research traits track which item traits (like 'sharp' or 'divine') the player has researched for each crafting skill, used for displaying research status in tooltips.
--- Only rebuilds data if forceRefresh is true or data hasn't been initialized
--- @param forceRefresh boolean: Force a refresh of the research data
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

--- Custom item sort comparator for gamepad inventory
--- @param left table: Left item data for comparison
--- @param right table: Right item data for comparison
--- @return boolean: True if left should come before right
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

--- Gets market price for an item from various trading addons (MasterMerchant, Arkadius Trade Tools, Tamriel Trade Centre). Checks each addon in order and returns the average price multiplied by stack count, or 0 if no pricing data is available.
--- @param itemLink string: The item link to get price for
--- @param stackCount number: Number of items (defaults to 1)
--- @return number: The calculated price, or 0 if no price found
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

--- Gets custom category information from the AutoCategory addon if available. AutoCategory is a third-party addon that allows custom inventory categorization rules based on item properties.
--- @param itemData table: Item data containing bagId and slotIndex
--- @return boolean, boolean, string, number: useCustomCategory, matched, categoryName, categoryPriority
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

--- Post-hooks a method on a UI control, ensuring the original method runs first, then the hook function. Useful for extending existing ESO UI behavior without breaking it.
--- @param control table: The UI control to hook
--- @param method string: The method name to hook
--- @param fn function: The hook function to call after the original
function BETTERUI.PostHook(control, method, fn)
	if control == nil then return end

	local originalMethod = control[method]
	control[method] = function(self, ...)
		originalMethod(self, ...)
		fn(self, ...)
	end
end

--- Hooks a method on a UI control with flexible options. If overwriteOriginal is false, calls the original method first; otherwise, replaces it entirely. Used for modifying ESO's UI systems safely.
--- @param control table: The UI control to hook
--- @param method string: The method name to hook
--- @param postHookFunction function: The hook function to call
--- @param overwriteOriginal boolean: If true, skips calling the original method
function BETTERUI.Hook(control, method, postHookFunction, overwriteOriginal)
	if control == nil then return end

	local originalMethod = control[method]
	control[method] = function(self, ...)
		if overwriteOriginal == false then originalMethod(self, ...) end
		postHookFunction(self, ...)
	end
end

--- Converts RGB color values (0-1 range) to a hexadecimal string for use in ESO's color formatting system.
--- @param rgb table: Table containing r, g, b values (0-1 range)
--- @return string: Hexadecimal color string (e.g., "ff0000")
function BETTERUI.RGBToHex(rgb)
	local r, g, b = table.unpack(rgb)
	return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

--- Creates a standardized module panel configuration for settings menus using LibAddonMenu2, including author, version, and slash command details.
--- @param moduleName string: The name of the module
--- @param moduleDesc string: The description of the module
--- @return table: Panel configuration table for LibAddonMenu
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
