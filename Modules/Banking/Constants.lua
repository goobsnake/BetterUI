if not BETTERUI.Banking then BETTERUI.Banking = {} end
if not BETTERUI.Banking.CONST then BETTERUI.Banking.CONST = {} end

BETTERUI.Banking.LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW or 1
BETTERUI.Banking.LIST_DEPOSIT = BETTERUI.Banking.LIST_DEPOSIT or 2
BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK = BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK or "main-bank"
BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK = BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK or "house-bank"
BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK = BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK or "guild-bank"

local cim = BETTERUI.CIM or {}
local timing = cim.CONST and cim.CONST.TIMING or {}

BETTERUI.Banking.CONST.CAROUSEL = {
    startOffset = 705,
    verticalOffset = -1,
}

BETTERUI.Banking.CONST.CURRENCY_TEXTURES = {
    [CURT_MONEY] = "EsoUI/Art/currency/gamepad/gp_gold.dds",
    [CURT_TELVAR_STONES] = "EsoUI/Art/currency/gamepad/gp_telvar.dds",
    [CURT_ALLIANCE_POINTS] = "esoui/art/currency/gamepad/gp_alliancepoints.dds",
    [CURT_WRIT_VOUCHERS] = "EsoUI/Art/currency/gamepad/gp_writvoucher.dds",
}

BETTERUI_BANK_LIST_MAX_OFFSET = 30
BETTERUI_BANK_HEADER_PADDING_SCALE = 0.75
BETTERUI_BANK_INACTIVE_LABEL_COLOR = { 0.26, 0.26, 0.26, 1 }
BETTERUI_BANK_DEPOSIT_ARROW_ROTATION = math.pi

BETTERUI_BANK_MOVE_COALESCE_DELAY_MS = timing.MOVE_COALESCE_DELAY_MS or 100
BETTERUI_BANK_CATEGORY_CHANGE_DELAY_MS = timing.CATEGORY_CHANGE_DELAY_MS or 120

BETTERUI_BANKING_SCENE_NAME = "gamepad_banking"

BETTERUI.Banking.BANKING_INTERACTION = {
    type = "Banking",
    interactTypes = { INTERACTION_BANK },
}

BETTERUI_GUILD_BANKING_SCENE_NAME = "BETTERUI_GUILD_BANKING"

local guildBankingInteraction = rawget(_G, "GUILD_BANKING_INTERACTION")
if type(guildBankingInteraction) ~= "table" then
    guildBankingInteraction = nil
end

BETTERUI.Banking.GUILD_BANK_INTERACTION = {
    type = guildBankingInteraction and guildBankingInteraction.type or "GuildBanking",
    interactTypes = guildBankingInteraction and guildBankingInteraction.interactTypes or { INTERACTION_GUILDBANK },
}
