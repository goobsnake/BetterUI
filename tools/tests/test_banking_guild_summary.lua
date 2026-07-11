-- Guild identity and bank summary must render without a selected list row.

local passed, failed = 0, 0
local function assertTrue(value, message)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print("  [FAILED] " .. message)
    end
end

BAG_GUILDBANK = 3
CURT_MONEY = 1
CURRENCY_LOCATION_GUILD_BANK = 2
GAMEPAD_LEFT_TOOLTIP = "left"
GAMEPAD_RIGHT_TOOLTIP = "right"
ZO_CURRENCY_FORMAT_AMOUNT_ICON = 1
SI_TRADING_HOUSE_GUILD_LABEL = "guild"
SI_GAMEPAD_BANK_BANK_CAPACITY_LABEL = "capacity"
SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT = "<<1>>/<<2>>"
SI_BETTERUI_BANK_BANKED_CURRENCY_FORMAT = "Banked <<1>>"
SI_BETTERUI_BANK_CARRIED_CURRENCY_FORMAT = "Carried <<1>>"
SI_BETTERUI_BANK_TITLE = "bank"

local strings = {
    guild = "Guild",
    capacity = "Capacity",
    bank = "Bank",
    [SI_BETTERUI_BANK_BANKED_CURRENCY_FORMAT] = "Banked <<1>>",
    [SI_BETTERUI_BANK_CARRIED_CURRENCY_FORMAT] = "Carried <<1>>",
}
function GetString(id) return strings[id] or tostring(id) end
function zo_strformat(format, ...)
    local values = { ... }
    return (tostring(format):gsub("<<(%d+)>>", function(index)
        return tostring(values[tonumber(index)] or "")
    end))
end
function GetCurrencyAmount() return 4242 end
function GetCarriedCurrencyAmount() return 313 end
function GetCurrencyName() return "Gold" end
function ZO_Currency_FormatGamepad(_, amount) return tostring(amount) .. " gold" end
function GetNumBagUsedSlots() return 12 end
function GetBagUseableSize() return 500 end

local renderedStats, addedSections, clearCalls, tooltipHidden = {}, 0, 0, true
local function CreatePair()
    return {
        SetStat = function(_, value) renderedStats[#renderedStats + 1] = value end,
        SetValue = function(_, value) renderedStats[#renderedStats + 1] = value end,
    }
end
local function CreateSection()
    return {
        AcquireStatValuePair = function() return CreatePair() end,
        AddStatValuePair = function() end,
        AddSection = function() end,
        SetNextSpacing = function() end,
    }
end
local tooltip = {
    GetStyle = function(_, name) return name end,
    AcquireSection = function() return CreateSection() end,
    AddSection = function() addedSections = addedSections + 1 end,
    SetHidden = function(_, hidden) tooltipHidden = hidden end,
}
GAMEPAD_TOOLTIPS = {
    ClearLines = function() clearCalls = clearCalls + 1 end,
    GetTooltip = function() return tooltip end,
}

BETTERUI = {
    Banking = {
        Class = {},
        GuildBank = {
            IsGuildBankMode = function() return true end,
            GetSelectedGuildId = function() return 55 end,
            GetSelectedGuildName = function() return "Accessible Guild" end,
            GetHeaderTitle = function() return "Accessible Guild Bank" end,
        },
    },
    Utils = { IsBankingSceneShowing = function() return true end },
}

dofile("Modules/Banking/Currency/CurrencySelector.lua")
dofile("Modules/Banking/UI/HeaderManager.lua")

local window = { GetList = function() return { selectedData = nil } end }
BETTERUI.Banking.CurrencySelector.RefreshCurrencyTooltip(window)
local summary = table.concat(renderedStats, "|")
assertTrue(clearCalls == 2, "Guild summary rebuilds both tooltip panes without a selected row")
assertTrue(addedSections == 1, "Guild summary renders without a selected row")
assertTrue(tooltipHidden == false, "Guild summary explicitly reveals the tooltip pane")
assertTrue(summary:find("Accessible Guild", 1, true) ~= nil, "Guild summary includes selected guild")
assertTrue(summary:find("4242 gold", 1, true) ~= nil, "Guild summary includes banked guild gold")

local headerWindow = {
    bankCategories = { { name = "All Items" } },
    currentCategoryIndex = 1,
    SetTitle = function(self, title) self.title = title end,
}
BETTERUI.Banking.Class.UpdateHeaderTitle(headerWindow)
assertTrue(headerWindow.title:find("Accessible Guild Bank", 1, true) ~= nil,
    "Guild header keeps selected guild visible")
assertTrue(headerWindow.title:find("All Items", 1, true) ~= nil,
    "Guild header keeps active category visible")

print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) end
