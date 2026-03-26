--[[
File: Modules/ResourceOrbFrames/Settings/SettingsSubmenus.lua
Purpose: Settings submenu builders for the Resource Orb Frames module.
Extracted from Module.lua to keep files under 600 lines.
Each function returns a LAM submenu table definition.
]]

local ROF = BETTERUI.ResourceOrbFrames
if not ROF then return end

--- @class ROFSettingsSubmenus
BETTERUI.ResourceOrbFrames.SettingsSubmenus = {}
local Submenus = BETTERUI.ResourceOrbFrames.SettingsSubmenus

--[[
Function: Submenus.BuildSkillBarsSubmenu
Description: Builds the "Skill Bars" submenu with cooldown timers, quickslot,
back bar, ultimate, and combat indicator settings.
]]
--- @param accessors any Description
--- @return any Description
function Submenus.BuildSkillBarsSubmenu(accessors)
    local a = accessors
    return {
        type = "submenu",
        name = GetString(SI_BETTERUI_SKILL_BARS_SUBMENU),
        controls = {
            {
                type = "header",
                name = GetString(SI_BETTERUI_SKILL_COOLDOWN_TIMER_HEADER),
            },
            {
                type = "slider",
                name = GetString(SI_BETTERUI_TEXT_SIZE),
                tooltip = GetString(SI_BETTERUI_SKILL_COOLDOWN_SCALE_TOOLTIP),
                min = 12, max = 30, step = 1,
                getFunc = a.getCooldownSize, setFunc = a.setCooldownSize,
                width = "full",
            },
            {
                type = "colorpicker",
                name = GetString(SI_BETTERUI_FONT_COLOR),
                tooltip = GetString(SI_BETTERUI_SKILL_COOLDOWN_COLOR_TOOLTIP),
                getFunc = a.getCooldownColor, setFunc = a.setCooldownColor,
                width = "full",
            },
            {
                type = "header",
                name = GetString(SI_BETTERUI_QUICKSLOTS_HEADER),
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN),
                tooltip = GetString(SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN_TOOLTIP),
                getFunc = a.getShowQuickCool, setFunc = a.setShowQuickCool,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_SHOW_QUICKSLOT_QUANTITY),
                tooltip = GetString(SI_BETTERUI_SHOW_QUICKSLOT_QUANTITY_TOOLTIP),
                getFunc = a.getShowQuickCount, setFunc = a.setShowQuickCount,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(SI_BETTERUI_TEXT_SIZE),
                tooltip = GetString(SI_BETTERUI_QUICKSLOT_SCALE_TOOLTIP),
                min = 12, max = 30, step = 1,
                getFunc = a.getQuickslotSize, setFunc = a.setQuickslotSize,
                width = "full",
            },
            {
                type = "colorpicker",
                name = GetString(SI_BETTERUI_FONT_COLOR),
                tooltip = GetString(SI_BETTERUI_QUICKSLOT_COLOR_TOOLTIP),
                getFunc = a.getQuickslotColor, setFunc = a.setQuickslotColor,
                width = "full",
            },
            {
                type = "header",
                name = GetString(SI_BETTERUI_BACK_BAR_HEADER),
            },
            {
                type = "slider",
                name = GetString(SI_BETTERUI_BACK_BAR_OPACITY),
                tooltip = GetString(SI_BETTERUI_BACK_BAR_OPACITY_TOOLTIP),
                min = 0.3, max = 1.0, step = 0.05, decimals = 2,
                getFunc = a.getBackBarOpacity, setFunc = a.setBackBarOpacity,
                disabled = function()
                    local s = a.GetSettings()
                    return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                        or (s and s.hideBackBar)
                end,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_HIDE_BACK_BAR),
                tooltip = GetString(SI_BETTERUI_HIDE_BACK_BAR_TOOLTIP),
                getFunc = a.getHideBackBar, setFunc = a.setHideBackBar,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_ROF_WEAPON_SWAP_ANIMATION),
                tooltip = GetString(SI_BETTERUI_ROF_WEAPON_SWAP_ANIMATION_TOOLTIP),
                getFunc = a.getWeaponAnim, setFunc = a.setWeaponAnim,
                disabled = function()
                    local s = a.GetSettings()
                    return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                        or (s and s.hideBackBar)
                end,
                width = "full",
            },
            {
                type = "header",
                name = GetString(SI_BETTERUI_ULTIMATE_DISPLAY_HEADER),
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_SHOW_ULTIMATE_NUMBER),
                tooltip = GetString(SI_BETTERUI_SHOW_ULTIMATE_NUMBER_TOOLTIP),
                getFunc = a.getShowUlt, setFunc = a.setShowUlt,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(SI_BETTERUI_ULTIMATE_TEXT_SIZE),
                tooltip = GetString(SI_BETTERUI_ULTIMATE_TEXT_SIZE_TOOLTIP),
                min = 12, max = 30, step = 1,
                getFunc = a.getUltSize, setFunc = a.setUltSize,
                disabled = function()
                    local s = a.GetSettings()
                    return not s or not s.showUltimateNumber
                end,
                width = "full",
            },
            {
                type = "colorpicker",
                name = GetString(SI_BETTERUI_ULTIMATE_TEXT_COLOR),
                tooltip = GetString(SI_BETTERUI_ULTIMATE_TEXT_COLOR_TOOLTIP),
                getFunc = a.getUltColor, setFunc = a.setUltColor,
                disabled = function()
                    local s = a.GetSettings()
                    return not s or not s.showUltimateNumber
                end,
                width = "full",
            },
            {
                type = "header",
                name = GetString(SI_BETTERUI_COMBAT_INDICATORS_HEADER),
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_COMBAT_GLOW_ENABLED),
                tooltip = GetString(SI_BETTERUI_COMBAT_GLOW_ENABLED_TOOLTIP),
                getFunc = a.getShowGlow, setFunc = a.setShowGlow,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_COMBAT_ICON_ENABLED),
                tooltip = GetString(SI_BETTERUI_COMBAT_ICON_ENABLED_TOOLTIP),
                getFunc = a.getShowCombatIcon, setFunc = a.setShowCombatIcon,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_COMBAT_AUDIO_ENABLED),
                tooltip = GetString(SI_BETTERUI_COMBAT_AUDIO_ENABLED_TOOLTIP),
                getFunc = a.getPlayAudio, setFunc = a.setPlayAudio,
                width = "full",
            },
            {
                type = "button",
                name = GetString(SI_BETTERUI_RESET_SKILL_BAR),
                func = function()
                    a.ResetSettingsGroup({
                        { key = "cooldownTextSize", value = 27 },
                        { key = "cooldownTextColor", isColor = true, colorFallback = { 0.86, 0.84, 0.13, 1 } },
                        { key = "quickslotTextSize", value = 27 },
                        { key = "quickslotTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } },
                        { key = "backBarOpacity", value = 1 },
                        { key = "hideBackBar", value = false },
                        { key = "weaponSwapAnimation", value = true },
                        { key = "showUltimateNumber", value = true },
                        { key = "ultimateTextSize", value = 27 },
                        { key = "ultimateTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } },
                        { key = "showQuickslotCooldown", value = true },
                        { key = "showQuickslotCount", value = true },
                        { key = "showCombatGlow", value = true },
                        { key = "showCombatIcon", value = true },
                        { key = "playCombatAudio", value = true },
                    })
                end,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "half",
            },
        },
    }
end

--[[
Function: Submenus.BuildOrbTextSubmenu
Description: Builds the "Orb Text & Visuals" submenu with ornament, text size/color settings.
]]
--- @param accessors any Description
--- @return any Description
function Submenus.BuildOrbTextSubmenu(accessors)
    local a = accessors
    return {
        type = "submenu",
        name = GetString(SI_BETTERUI_ORB_TEXT_SUBMENU),
        controls = {
            {
                type = "header",
                name = GetString(SI_BETTERUI_ORB_VISUALS_HEADER),
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_ROF_ORB_ANIMATIONS),
                tooltip = GetString(SI_BETTERUI_ROF_ORB_ANIMATIONS_TOOLTIP),
                getFunc = a.getOrbAnim, setFunc = a.setOrbAnim,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_HIDE_LEFT_ORNAMENT),
                tooltip = GetString(SI_BETTERUI_HIDE_LEFT_ORNAMENT_TOOLTIP),
                getFunc = a.getHideLeft, setFunc = a.setHideLeft,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(SI_BETTERUI_LEFT_ORB_SIZE),
                tooltip = GetString(SI_BETTERUI_LEFT_ORB_SIZE_TOOLTIP),
                min = 1.0, max = 1.2, step = 0.1, decimals = 1,
                getFunc = a.getLeftSize, setFunc = a.setLeftSize,
                disabled = function()
                    local s = a.GetSettings()
                    return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                        or not (s and s.hideLeftOrnament)
                end,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(SI_BETTERUI_HIDE_RIGHT_ORNAMENT),
                tooltip = GetString(SI_BETTERUI_HIDE_RIGHT_ORNAMENT_TOOLTIP),
                getFunc = a.getHideRight, setFunc = a.setHideRight,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(SI_BETTERUI_RIGHT_ORB_SIZE),
                tooltip = GetString(SI_BETTERUI_RIGHT_ORB_SIZE_TOOLTIP),
                min = 1.0, max = 1.2, step = 0.1, decimals = 1,
                getFunc = a.getRightSize, setFunc = a.setRightSize,
                disabled = function()
                    local s = a.GetSettings()
                    return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                        or not (s and s.hideRightOrnament)
                end,
                width = "full",
            },
            {
                type = "header",
                name = GetString(SI_BETTERUI_ORB_TEXT_SETTINGS_HEADER),
            },
            { type = "slider", name = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_SIZE), tooltip = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_SIZE_TOOLTIP), min = 12, max = 26, step = 1, getFunc = a.getHealthSize, setFunc = function(v) a.setHealthSize(v); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate") end, width = "full" },
            { type = "colorpicker", name = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_COLOR), tooltip = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_COLOR_TOOLTIP), getFunc = a.getHealthColor, setFunc = function(r,g,b,aa) a.setHealthColor(r,g,b,aa); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate") end, width = "full" },
            { type = "slider", name = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE), tooltip = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE_TOOLTIP), min = 12, max = 26, step = 1, getFunc = a.getMagSize, setFunc = function(v) a.setMagSize(v); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate") end, width = "full" },
            { type = "colorpicker", name = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR), tooltip = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR_TOOLTIP), getFunc = a.getMagColor, setFunc = function(r,g,b,aa) a.setMagColor(r,g,b,aa); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate") end, width = "full" },
            { type = "slider", name = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_SIZE), tooltip = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_SIZE_TOOLTIP), min = 12, max = 26, step = 1, getFunc = a.getStamSize, setFunc = function(v) a.setStamSize(v); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate") end, width = "full" },
            { type = "colorpicker", name = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_COLOR), tooltip = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_COLOR_TOOLTIP), getFunc = a.getStamColor, setFunc = function(r,g,b,aa) a.setStamColor(r,g,b,aa); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate") end, width = "full" },
            { type = "slider", name = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_SIZE), tooltip = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_SIZE_TOOLTIP), min = 12, max = 26, step = 1, getFunc = a.getShieldSize, setFunc = function(v) a.setShieldSize(v); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate") end, width = "full" },
            { type = "colorpicker", name = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_COLOR), tooltip = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_COLOR_TOOLTIP), getFunc = a.getShieldColor, setFunc = a.setShieldColor, width = "full" },
            {
                type = "button",
                name = GetString(SI_BETTERUI_ORB_TEXT_RESET),
                tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                func = function()
                    a.ResetSettingsGroup({
                        { key = "hideLeftOrnament", value = false },
                        { key = "hideRightOrnament", value = false },
                        { key = "leftOrbSizeScale", value = 1.0 },
                        { key = "rightOrbSizeScale", value = 1.0 },
                        { key = "healthTextSize", value = 20 },
                        { key = "healthTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } },
                        { key = "magickaTextSize", value = 20 },
                        { key = "magickaTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } },
                        { key = "staminaTextSize", value = 20 },
                        { key = "staminaTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } },
                        { key = "shieldTextSize", value = 20 },
                        { key = "shieldTextColor", isColor = true, colorFallback = { 0.4, 0.9, 1, 1 } },
                    })
                end,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "half",
            },
        },
    }
end

--[[
Function: Submenus.BuildBarSubmenus
Description: Returns submenu tables for XP Bar, Cast Bar, and Mount Stamina Bar settings.
]]
--- @param accessors any Description
--- @return any Description
function Submenus.BuildBarSubmenus(accessors)
    local a = accessors
    local xpSubmenu = {
        type = "submenu",
        name = GetString(SI_BETTERUI_XP_BAR_SUBMENU),
        controls = {
            { type = "checkbox", name = GetString(SI_BETTERUI_XP_BAR_ENABLED), tooltip = GetString(SI_BETTERUI_XP_BAR_ENABLED_TOOLTIP), sortAlwaysFirst = true, getFunc = a.getXpEnabled, setFunc = a.setXpEnabled, width = "full" },
            { type = "slider", name = GetString(SI_BETTERUI_XP_BAR_TEXT_SIZE), tooltip = GetString(SI_BETTERUI_XP_BAR_TEXT_SIZE_TOOLTIP), min = 5, max = 20, step = 1, getFunc = a.getXpSize, setFunc = a.setXpSize, disabled = function() local s = a.GetSettings(); return not (s and s.xpBarEnabled == true) end, width = "full" },
            { type = "colorpicker", name = GetString(SI_BETTERUI_XP_BAR_TEXT_COLOR), tooltip = GetString(SI_BETTERUI_XP_BAR_TEXT_COLOR_TOOLTIP), getFunc = a.getXpColor, setFunc = a.setXpColor, disabled = function() local s = a.GetSettings(); return not (s and s.xpBarEnabled == true) end, width = "full" },
            { type = "button", name = GetString(SI_BETTERUI_XP_BAR_RESET), tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                func = function() a.ResetSettingsGroup({ { key = "xpBarTextSize", value = 16 }, { key = "xpBarTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } } }) end,
                disabled = function() local s = a.GetSettings(); return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and s and s.xpBarEnabled == true) end, width = "half" },
        },
    }
    local castSubmenu = {
        type = "submenu",
        name = GetString(SI_BETTERUI_CAST_BAR_SUBMENU),
        controls = {
            { type = "checkbox", name = GetString(SI_BETTERUI_CAST_BAR_ENABLED), tooltip = GetString(SI_BETTERUI_CAST_BAR_ENABLED_TOOLTIP), sortAlwaysFirst = true, getFunc = a.getCastEnabled, setFunc = a.setCastEnabled, width = "full" },
            { type = "checkbox", name = GetString(SI_BETTERUI_CAST_BAR_ALWAYS_SHOW), tooltip = GetString(SI_BETTERUI_CAST_BAR_ALWAYS_SHOW_TOOLTIP), getFunc = a.getCastAlways, setFunc = a.setCastAlways, disabled = function() local s = a.GetSettings(); return not (s and s.castBarEnabled == true) end, width = "full" },
            { type = "slider", name = GetString(SI_BETTERUI_CAST_BAR_TEXT_SIZE), tooltip = GetString(SI_BETTERUI_CAST_BAR_TEXT_SIZE_TOOLTIP), min = 5, max = 20, step = 1, getFunc = a.getCastSize, setFunc = a.setCastSize, disabled = function() local s = a.GetSettings(); return not (s and s.castBarEnabled == true) end, width = "full" },
            { type = "colorpicker", name = GetString(SI_BETTERUI_CAST_BAR_TEXT_COLOR), tooltip = GetString(SI_BETTERUI_CAST_BAR_TEXT_COLOR_TOOLTIP), getFunc = a.getCastColor, setFunc = a.setCastColor, disabled = function() local s = a.GetSettings(); return not (s and s.castBarEnabled == true) end, width = "full" },
            { type = "button", name = GetString(SI_BETTERUI_CAST_BAR_RESET), tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                func = function() a.ResetSettingsGroup({ { key = "castBarTextSize", value = 16 }, { key = "castBarTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } } }) end,
                disabled = function() local s = a.GetSettings(); return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and s and s.castBarEnabled == true) end, width = "half" },
        },
    }
    local mountSubmenu = {
        type = "submenu",
        name = GetString(SI_BETTERUI_MOUNT_STAMINA_BAR_SUBMENU),
        controls = {
            { type = "checkbox", name = GetString(SI_BETTERUI_MOUNT_BAR_ENABLED), tooltip = GetString(SI_BETTERUI_MOUNT_BAR_ENABLED_TOOLTIP), sortAlwaysFirst = true, getFunc = a.getMountEnabled, setFunc = a.setMountEnabled, width = "full" },
            { type = "slider", name = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_SIZE), tooltip = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_SIZE_TOOLTIP), min = 5, max = 20, step = 1, getFunc = a.getMountSize, setFunc = a.setMountSize, disabled = function() local s = a.GetSettings(); return not (s and s.mountStaminaBarEnabled == true) end, width = "full" },
            { type = "colorpicker", name = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_COLOR), tooltip = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_COLOR_TOOLTIP), getFunc = a.getMountColor, setFunc = a.setMountColor, disabled = function() local s = a.GetSettings(); return not (s and s.mountStaminaBarEnabled == true) end, width = "full" },
            { type = "button", name = GetString(SI_BETTERUI_MOUNT_STAMINA_BAR_RESET), tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                func = function() a.ResetSettingsGroup({ { key = "mountStaminaBarTextSize", value = 16 }, { key = "mountStaminaBarTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } } }) end,
                disabled = function() local s = a.GetSettings(); return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and s and s.mountStaminaBarEnabled == true) end, width = "half" },
        },
    }
    return xpSubmenu, castSubmenu, mountSubmenu
end
