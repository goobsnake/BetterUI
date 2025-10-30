-- shadowcep: Patched for compatibility with latest version of AutoCategory (fix by Friday_The13_rus)
BETTERUI = {
	ResearchTraits = {}
}

BETTERUI.name = "BetterUI"
BETTERUI.version = "2.77"

-- Program Global (scope of BETTERUI, though) variable initialization
BETTERUI.WindowManager = GetWindowManager()
BETTERUI.EventManager = GetEventManager()

-- pseudo-Class definitions
BETTERUI.CONST = {}
--BETTERUI.Lib = {}
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

function BETTERUI.roundNumber(number, decimals)
	if (number ~= nil or number ~= 0) and decimals ~= nil then
    	local power = 10^decimals
    	return string.format("%.2f", math.floor(number * power) / power)
    else
    	return 0
    end
end

function BETTERUI.OnScreenMessage(message)
	local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
	messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_COUNTDOWN)
	messageParams:SetText(message)
	CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

-- Thanks to Bart Kiers for this function :)
function BETTERUI.DisplayNumber(number)
	  local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
	  -- reverse the int-string and append a comma to all blocks of 3 digits
	  int = int:reverse():gsub("(%d%d%d)", "%1,")
	  -- reverse the int-string back remove an optional comma and put the
	  -- optional minus and fractional part back
	  return minus .. int:reverse():gsub("^,", "") .. fraction
end

function BETTERUI.GetResearch()
	BETTERUI.ResearchTraits = {}
	for i,craftType in pairs(BETTERUI.CONST.CraftingSkillTypes) do
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

function BETTERUI_GamepadInventory_DefaultItemSortComparator(left, right)
	local CUSTOM_GAMEPAD_ITEM_SORT =
	{
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

function BETTERUI.GetMarketPrice(itemLink, stackCount)
    if itemLink then
        if(stackCount == nil) then stackCount = 1 end

        if MasterMerchant ~= nil and BETTERUI.Settings.Modules["Tooltips"].mmIntegration then 
            local mmData = MasterMerchant:itemStats(itemLink, false)
            if(mmData.avgPrice ~= nil and mmData.avgPrice > 0) then
                return mmData.avgPrice * stackCount
            end
        end
        if ArkadiusTradeTools ~= nil and BETTERUI.Settings.Modules["Tooltips"].attIntegration then 
            local avgPrice = ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(itemLink, nil, nil)
            if(avgPrice ~= nil and avgPrice > 0) then
                return avgPrice * stackCount
            end
        end
        if TamrielTradeCentre ~= nil and BETTERUI.Settings.Modules["Tooltips"].ttcIntegration then
            local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
    		if(priceInfo ~= nil) then
    			if priceInfo.Avg then
    				return priceInfo.Avg * stackCount
    			else
    				return priceInfo.SuggestedPrice * stackCount
    			end
    		end
    	end
    	return 0
    else
        return 0
    end
end

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

function BETTERUI.PostHook(control, method, fn)
	if control == nil then return end

	local originalMethod = control[method]
	control[method] = function(self, ...)
		originalMethod(self, ...)
		fn(self, ...)
	end
end

function BETTERUI.Hook(control, method, postHookFunction, overwriteOriginal)
	if control == nil then return end

	local originalMethod = control[method]
	control[method] = function(self, ...)
		if(overwriteOriginal == false) then originalMethod(self, ...) end
		postHookFunction(self, ...)
	end
end

function BETTERUI.RGBToHex(rgba)
	r,g,b,a = unpack(rgba)
	return string.format("%02x%02x%02x", r*255, g*255, b*255)
end

function Init_ModulePanel(moduleName, moduleDesc)
	return {
		type = "panel",
		name = "|t24:24:/esoui/art/buttons/gamepad/xbox/nav_xbone_b.dds|t "..BETTERUI.name.." ("..moduleName..")",
		displayName = "|c0066ffBETTERUI|r :: "..moduleDesc,
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
