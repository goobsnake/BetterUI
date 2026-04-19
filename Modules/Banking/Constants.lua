if not BETTERUI.Banking then BETTERUI.Banking = {} end
if not BETTERUI.Banking.CONST then BETTERUI.Banking.CONST = {} end

assert(BETTERUI.CIM and BETTERUI.CIM.SearchBar and BETTERUI.CIM.SearchBar.GetConstants, "BetterUI: CIM must load before Banking/Constants")

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

BETTERUI_BANK_MOVE_COALESCE_DELAY_MS = BETTERUI.CIM.CONST.TIMING.MOVE_COALESCE_DELAY_MS
BETTERUI_BANK_CATEGORY_CHANGE_DELAY_MS = BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS

BETTERUI_BANKING_SCENE_NAME = "gamepad_banking"

BETTERUI.Banking.BANKING_INTERACTION = {
    type = "Banking",
    interactTypes = { INTERACTION_BANK },
}

BETTERUI_GUILD_BANKING_SCENE_NAME = "BETTERUI_GUILD_BANKING"

BETTERUI.Banking.GUILD_BANK_INTERACTION = {
    type = "GuildBanking",
    interactTypes = { INTERACTION_GUILDBANK },
}
