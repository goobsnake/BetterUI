-- BetterUI luacheck configuration
std = 'lua51+busted'

-- ESO Lua environment globals
globals = {
    'BETTERUI',
    'd', 'df',
    'zo_callLater', 'zo_strformat',
    'GetString', 'SI_BETTERUI_GENERAL_AUTHOR',
    'EVENT_MANAGER',
    'SCENE_MANAGER',
    'SLASH_COMMANDS',
    'LibAddonMenu2',
    'ZO_SavedVars',
    'ZO_CreateStringId',
    'WINDOW_MANAGER',
    'BAG_BACKPACK', 'BAG_BANK', 'BAG_SUBSCRIBER_BANK', 'BAG_HOUSE_BANK_ONE',
    'BAG_VIRTUAL', 'BAG_WORN',
}

-- Read ESO globals from existing code patterns
read_globals = {
    'GetBagSize', 'GetSlotStackSize', 'GetItemLink',
    'GetItemType', 'GetItemQuality', 'IsItemStolen',
    'GetItemTrait', 'GetItemTraitType',
    'GetMaxBags', 'GetBagInfo',
    'ZO_Dialogs_ShowDialog', 'ZO_Dialogs_RegisterCustomDialog',
    'ZO_ClearTable', 'ZO_DeepTableCopy',
    'ZO_GetPlatformAccountLabel', 'ZO_ColorDef',
    'zo_min', 'zo_max', 'zo_clamp', 'zo_round',
    'zo_plainTableConcat',
    'CT_LABEL', 'CT_TEXTURE', 'CT_BUTTON', 'CT_LINE',
    'CENTER', 'TOPLEFT', 'TOP', 'TOPRIGHT', 'LEFT', 'RIGHT',
    'BOTTOMLEFT', 'BOTTOM', 'BOTTOMRIGHT',
    'TEXT_ALIGN_LEFT', 'TEXT_ALIGN_CENTER', 'TEXT_ALIGN_RIGHT',
    'KEY_GAMEPAD_LEFT_SHOULDER', 'KEY_GAMEPAD_RIGHT_SHOULDER',
}

-- Allow self parameter
self = true

-- Relaxed settings for addon code
max_line_length = false
max_code_line_length = false

-- Ignore common patterns
ignore = {
    '212/self',    -- unused self arg
    '213',         -- unused loop variables
    '542',         -- empty if branch
}

-- Exclude directories
exclude_files = {
    'Source/Legacy/**',
    'tools/tests/**',
    '.desloppify/**',
    'docs/**',
}
