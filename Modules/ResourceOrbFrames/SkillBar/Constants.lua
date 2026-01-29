--[[
File: Modules/ResourceOrbFrames/SkillBar/Constants.lua
Purpose: Shared constants for SkillBar managers (FrontBar, BackBar, Ultimate, Tooltips).
         Consolidates duplicate slot mapping arrays that were repeated 5+ times.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end

BETTERUI.ResourceOrbFrames.SkillBar.CONST = {
    --[[
    Table: FRONT_BAR_SLOTS
    Description: Standard front bar slot mapping for 5 ability slots + ultimate.
    Used By: FrontBarManager (UpdateFrontBar, UpdateFrontBarUsability, SetupFrontBarTooltips, UpdateCooldowns)
    ]]
    FRONT_BAR_SLOTS = {
        { buttonName = "Button1",        slot = 3 },
        { buttonName = "Button2",        slot = 4 },
        { buttonName = "Button3",        slot = 5 },
        { buttonName = "Button4",        slot = 6 },
        { buttonName = "Button5",        slot = 7 },
        { buttonName = "UltimateButton", slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 },
    },

    --[[
    Table: BACK_BAR_SLOTS
    Description: Back bar slot indices (slots 3-8 map to abilities + ultimate).
    Used By: BackBarManager (UpdateBackBar, SetupBackBarTooltips, UpdateCooldowns)
    ]]
    BACK_BAR_SLOTS = { 3, 4, 5, 6, 7, 8 },

    --[[
    Table: SLOT_KEYBINDS
    Description: Keyboard/gamepad keybind action names for slots 1-5.
    Direction: Index 1-5 corresponds to Button1-Button5.
    Used By: FrontBarManager.SetupFrontBarKeybinds
    ]]
    SLOT_KEYBINDS = {
        [1] = { keyboard = "ACTION_BUTTON_3", gamepad = "GAMEPAD_ACTION_BUTTON_3" },
        [2] = { keyboard = "ACTION_BUTTON_4", gamepad = "GAMEPAD_ACTION_BUTTON_4" },
        [3] = { keyboard = "ACTION_BUTTON_5", gamepad = "GAMEPAD_ACTION_BUTTON_5" },
        [4] = { keyboard = "ACTION_BUTTON_6", gamepad = "GAMEPAD_ACTION_BUTTON_6" },
        [5] = { keyboard = "ACTION_BUTTON_7", gamepad = "GAMEPAD_ACTION_BUTTON_7" },
    },

    --[[
    Constant: HIDE_UNBOUND
    Description: Flag for ZO_Keybindings_RegisterLabelForBindingUpdate.
    Direction: false = show unbound keybinds, true = hide them.
    Used By: FrontBarManager.SetupFrontBarKeybinds
    ]]
    HIDE_UNBOUND = false,

    --[[
    Constant: COOLDOWN_DURATION_THRESHOLD
    Description: Minimum duration (ms) for cooldown to be displayed.
    Direction: Cooldowns shorter than 1500ms are filtered out (global cooldown).
    Used By: FrontBarManager.UpdateFrontBarCooldowns, BackBarManager.UpdateBackBarCooldowns
    ]]
    COOLDOWN_DURATION_THRESHOLD = 1500,
}
