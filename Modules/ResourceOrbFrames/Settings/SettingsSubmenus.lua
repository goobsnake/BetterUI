--[[
File: Modules/ResourceOrbFrames/Settings/SettingsSubmenus.lua
Purpose: Settings submenu builders for the Resource Orb Frames module.
Extracted from Module.lua to keep files under 600 lines.
Each function returns a LAM submenu table definition.
]]

local ROF = BETTERUI.ResourceOrbFrames
if not ROF then return end

BETTERUI.ResourceOrbFrames.SettingsSubmenus = {}
local Submenus = BETTERUI.ResourceOrbFrames.SettingsSubmenus

local function GetSharedSettings(shared)
    return shared and shared.getSettings and shared.getSettings() or nil
end

local function ResetSharedSettingsGroup(shared, entries)
    if shared and shared.resetSettingsGroup then
        shared.resetSettingsGroup(entries)
    end
end

local function WrapLayoutRefresh(setFunc)
    return function(...)
        setFunc(...)
        if CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks then
            CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
        end
    end
end

---@param skillBars table Section-scoped skill bar contracts
---@param shared table Shared settings helpers
---@return table submenu Skill bars submenu definition
function Submenus.BuildSkillBarsSubmenu(skillBars, shared)
    local cooldownText = skillBars.cooldownText
    local quickslot = skillBars.quickslot
    local backBar = skillBars.backBar
    local ultimate = skillBars.ultimate
    local combatIndicators = skillBars.combatIndicators
    return {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_SKILL_BARS_SUBMENU")),
        controls = {
            {
                type = "header",
                name = GetString(rawget(_G, "SI_BETTERUI_SKILL_COOLDOWN_TIMER_HEADER")),
            },
            {
                type = "slider",
                name = GetString(rawget(_G, "SI_BETTERUI_TEXT_SIZE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_SKILL_COOLDOWN_SCALE_TOOLTIP")),
                min = 12, max = 30, step = 1,
                getFunc = cooldownText.size.get, setFunc = cooldownText.size.set,
                width = "full",
            },
            {
                type = "colorpicker",
                name = GetString(rawget(_G, "SI_BETTERUI_FONT_COLOR")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_SKILL_COOLDOWN_COLOR_TOOLTIP")),
                getFunc = cooldownText.color.get, setFunc = cooldownText.color.set,
                width = "full",
            },
            {
                type = "header",
                name = GetString(rawget(_G, "SI_BETTERUI_QUICKSLOTS_HEADER")),
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN_TOOLTIP")),
                getFunc = quickslot.showCooldown.get, setFunc = quickslot.showCooldown.set,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_SHOW_QUICKSLOT_QUANTITY")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_SHOW_QUICKSLOT_QUANTITY_TOOLTIP")),
                getFunc = quickslot.showCount.get, setFunc = quickslot.showCount.set,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(rawget(_G, "SI_BETTERUI_TEXT_SIZE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_QUICKSLOT_SCALE_TOOLTIP")),
                min = 12, max = 30, step = 1,
                getFunc = quickslot.text.size.get, setFunc = quickslot.text.size.set,
                width = "full",
            },
            {
                type = "colorpicker",
                name = GetString(rawget(_G, "SI_BETTERUI_FONT_COLOR")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_QUICKSLOT_COLOR_TOOLTIP")),
                getFunc = quickslot.text.color.get, setFunc = quickslot.text.color.set,
                width = "full",
            },
            {
                type = "header",
                name = GetString(rawget(_G, "SI_BETTERUI_BACK_BAR_HEADER")),
            },
            {
                type = "slider",
                name = GetString(rawget(_G, "SI_BETTERUI_BACK_BAR_OPACITY")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_BACK_BAR_OPACITY_TOOLTIP")),
                min = 0.3, max = 1.0, step = 0.05, decimals = 2,
                getFunc = backBar.opacity.get, setFunc = backBar.opacity.set,
                disabled = function()
                    local s = GetSharedSettings(shared)
                    return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                        or (s and s.hideBackBar)
                end,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_HIDE_BACK_BAR")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_HIDE_BACK_BAR_TOOLTIP")),
                getFunc = backBar.hidden.get, setFunc = backBar.hidden.set,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_ROF_WEAPON_SWAP_ANIMATION")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_ROF_WEAPON_SWAP_ANIMATION_TOOLTIP")),
                getFunc = backBar.weaponSwapAnimation.get, setFunc = backBar.weaponSwapAnimation.set,
                disabled = function()
                    local s = GetSharedSettings(shared)
                    return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                        or (s and s.hideBackBar)
                end,
                width = "full",
            },
            {
                type = "header",
                name = GetString(rawget(_G, "SI_BETTERUI_ULTIMATE_DISPLAY_HEADER")),
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_SHOW_ULTIMATE_NUMBER")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_SHOW_ULTIMATE_NUMBER_TOOLTIP")),
                getFunc = ultimate.showNumber.get, setFunc = ultimate.showNumber.set,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(rawget(_G, "SI_BETTERUI_ULTIMATE_TEXT_SIZE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_ULTIMATE_TEXT_SIZE_TOOLTIP")),
                min = 12, max = 30, step = 1,
                getFunc = ultimate.text.size.get, setFunc = ultimate.text.size.set,
                disabled = function()
                    local s = GetSharedSettings(shared)
                    return not s or not s.showUltimateNumber
                end,
                width = "full",
            },
            {
                type = "colorpicker",
                name = GetString(rawget(_G, "SI_BETTERUI_ULTIMATE_TEXT_COLOR")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_ULTIMATE_TEXT_COLOR_TOOLTIP")),
                getFunc = ultimate.text.color.get, setFunc = ultimate.text.color.set,
                disabled = function()
                    local s = GetSharedSettings(shared)
                    return not s or not s.showUltimateNumber
                end,
                width = "full",
            },
            {
                type = "header",
                name = GetString(rawget(_G, "SI_BETTERUI_COMBAT_INDICATORS_HEADER")),
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_COMBAT_GLOW_ENABLED")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_COMBAT_GLOW_ENABLED_TOOLTIP")),
                getFunc = combatIndicators.glow.get, setFunc = combatIndicators.glow.set,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_COMBAT_ICON_ENABLED")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_COMBAT_ICON_ENABLED_TOOLTIP")),
                getFunc = combatIndicators.icon.get, setFunc = combatIndicators.icon.set,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_COMBAT_AUDIO_ENABLED")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_COMBAT_AUDIO_ENABLED_TOOLTIP")),
                getFunc = combatIndicators.audio.get, setFunc = combatIndicators.audio.set,
                width = "full",
            },
            {
                type = "button",
                name = GetString(rawget(_G, "SI_BETTERUI_RESET_SKILL_BAR")),
                func = function()
                    ResetSharedSettingsGroup(shared, {
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

---@param orbText table Section-scoped orb text contracts
---@param shared table Shared settings helpers
---@return table submenu Orb text submenu definition
function Submenus.BuildOrbTextSubmenu(orbText, shared)
    local visuals = orbText.visuals
    local resourceText = orbText.resourceText
    local refreshLayout = WrapLayoutRefresh
    return {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_SUBMENU")),
        controls = {
            {
                type = "header",
                name = GetString(rawget(_G, "SI_BETTERUI_ORB_VISUALS_HEADER")),
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_ROF_ORB_ANIMATIONS")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_ROF_ORB_ANIMATIONS_TOOLTIP")),
                getFunc = visuals.animations.get, setFunc = visuals.animations.set,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_HIDE_LEFT_ORNAMENT")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_HIDE_LEFT_ORNAMENT_TOOLTIP")),
                getFunc = visuals.leftOrnamentHidden.get, setFunc = visuals.leftOrnamentHidden.set,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(rawget(_G, "SI_BETTERUI_LEFT_ORB_SIZE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_LEFT_ORB_SIZE_TOOLTIP")),
                min = 1.0, max = 1.2, step = 0.1, decimals = 1,
                getFunc = visuals.leftSizeScale.get, setFunc = visuals.leftSizeScale.set,
                disabled = function()
                    local s = GetSharedSettings(shared)
                    return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                        or not (s and s.hideLeftOrnament)
                end,
                width = "full",
            },
            {
                type = "checkbox",
                name = GetString(rawget(_G, "SI_BETTERUI_HIDE_RIGHT_ORNAMENT")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_HIDE_RIGHT_ORNAMENT_TOOLTIP")),
                getFunc = visuals.rightOrnamentHidden.get, setFunc = visuals.rightOrnamentHidden.set,
                disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                width = "full",
            },
            {
                type = "slider",
                name = GetString(rawget(_G, "SI_BETTERUI_RIGHT_ORB_SIZE")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_RIGHT_ORB_SIZE_TOOLTIP")),
                min = 1.0, max = 1.2, step = 0.1, decimals = 1,
                getFunc = visuals.rightSizeScale.get, setFunc = visuals.rightSizeScale.set,
                disabled = function()
                    local s = GetSharedSettings(shared)
                    return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                        or not (s and s.hideRightOrnament)
                end,
                width = "full",
            },
            {
                type = "header",
                name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_SETTINGS_HEADER")),
            },
            { type = "slider", name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_HEALTH_SIZE")), tooltip = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_HEALTH_SIZE_TOOLTIP")), min = 12, max = 26, step = 1, getFunc = resourceText.health.size.get, setFunc = refreshLayout(resourceText.health.size.set), width = "full" },
            { type = "colorpicker", name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_HEALTH_COLOR")), tooltip = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_HEALTH_COLOR_TOOLTIP")), getFunc = resourceText.health.color.get, setFunc = refreshLayout(resourceText.health.color.set), width = "full" },
            { type = "slider", name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE")), tooltip = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE_TOOLTIP")), min = 12, max = 26, step = 1, getFunc = resourceText.magicka.size.get, setFunc = refreshLayout(resourceText.magicka.size.set), width = "full" },
            { type = "colorpicker", name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR")), tooltip = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR_TOOLTIP")), getFunc = resourceText.magicka.color.get, setFunc = refreshLayout(resourceText.magicka.color.set), width = "full" },
            { type = "slider", name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_STAMINA_SIZE")), tooltip = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_STAMINA_SIZE_TOOLTIP")), min = 12, max = 26, step = 1, getFunc = resourceText.stamina.size.get, setFunc = refreshLayout(resourceText.stamina.size.set), width = "full" },
            { type = "colorpicker", name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_STAMINA_COLOR")), tooltip = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_STAMINA_COLOR_TOOLTIP")), getFunc = resourceText.stamina.color.get, setFunc = refreshLayout(resourceText.stamina.color.set), width = "full" },
            { type = "slider", name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_SHIELD_SIZE")), tooltip = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_SHIELD_SIZE_TOOLTIP")), min = 12, max = 26, step = 1, getFunc = resourceText.shield.size.get, setFunc = refreshLayout(resourceText.shield.size.set), width = "full" },
            { type = "colorpicker", name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_SHIELD_COLOR")), tooltip = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_SHIELD_COLOR_TOOLTIP")), getFunc = resourceText.shield.color.get, setFunc = resourceText.shield.color.set, width = "full" },
            {
                type = "button",
                name = GetString(rawget(_G, "SI_BETTERUI_ORB_TEXT_RESET")),
                tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP")),
                func = function()
                    ResetSharedSettingsGroup(shared, {
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

---@param bars table Section-scoped bar contracts
---@param shared table Shared settings helpers
---@return table xpSubmenu XP bar submenu
---@return table castSubmenu Cast bar submenu
---@return table mountSubmenu Mount stamina bar submenu
function Submenus.BuildBarSubmenus(bars, shared)
    local xp = bars.xp
    local cast = bars.cast
    local mount = bars.mount
    local xpSubmenu = {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_XP_BAR_SUBMENU")),
        controls = {
            { type = "checkbox", name = GetString(rawget(_G, "SI_BETTERUI_XP_BAR_ENABLED")), tooltip = GetString(rawget(_G, "SI_BETTERUI_XP_BAR_ENABLED_TOOLTIP")), sortAlwaysFirst = true, getFunc = xp.enabled.get, setFunc = xp.enabled.set, width = "full" },
            { type = "slider", name = GetString(rawget(_G, "SI_BETTERUI_XP_BAR_TEXT_SIZE")), tooltip = GetString(rawget(_G, "SI_BETTERUI_XP_BAR_TEXT_SIZE_TOOLTIP")), min = 5, max = 20, step = 1, getFunc = xp.text.size.get, setFunc = xp.text.size.set, disabled = function() local s = GetSharedSettings(shared); return not (s and s.xpBarEnabled == true) end, width = "full" },
            { type = "colorpicker", name = GetString(rawget(_G, "SI_BETTERUI_XP_BAR_TEXT_COLOR")), tooltip = GetString(rawget(_G, "SI_BETTERUI_XP_BAR_TEXT_COLOR_TOOLTIP")), getFunc = xp.text.color.get, setFunc = xp.text.color.set, disabled = function() local s = GetSharedSettings(shared); return not (s and s.xpBarEnabled == true) end, width = "full" },
            { type = "button", name = GetString(rawget(_G, "SI_BETTERUI_XP_BAR_RESET")), tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP")),
                func = function() ResetSharedSettingsGroup(shared, { { key = "xpBarTextSize", value = 16 }, { key = "xpBarTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } } }) end,
                disabled = function() local s = GetSharedSettings(shared); return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and s and s.xpBarEnabled == true) end, width = "half" },
        },
    }
    local castSubmenu = {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_SUBMENU")),
        controls = {
            { type = "checkbox", name = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_ENABLED")), tooltip = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_ENABLED_TOOLTIP")), sortAlwaysFirst = true, getFunc = cast.enabled.get, setFunc = cast.enabled.set, width = "full" },
            { type = "checkbox", name = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_ALWAYS_SHOW")), tooltip = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_ALWAYS_SHOW_TOOLTIP")), getFunc = cast.alwaysShow.get, setFunc = cast.alwaysShow.set, disabled = function() local s = GetSharedSettings(shared); return not (s and s.castBarEnabled == true) end, width = "full" },
            { type = "slider", name = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_TEXT_SIZE")), tooltip = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_TEXT_SIZE_TOOLTIP")), min = 5, max = 20, step = 1, getFunc = cast.text.size.get, setFunc = cast.text.size.set, disabled = function() local s = GetSharedSettings(shared); return not (s and s.castBarEnabled == true) end, width = "full" },
            { type = "colorpicker", name = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_TEXT_COLOR")), tooltip = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_TEXT_COLOR_TOOLTIP")), getFunc = cast.text.color.get, setFunc = cast.text.color.set, disabled = function() local s = GetSharedSettings(shared); return not (s and s.castBarEnabled == true) end, width = "full" },
            { type = "button", name = GetString(rawget(_G, "SI_BETTERUI_CAST_BAR_RESET")), tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP")),
                func = function() ResetSharedSettingsGroup(shared, { { key = "castBarTextSize", value = 16 }, { key = "castBarTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } } }) end,
                disabled = function() local s = GetSharedSettings(shared); return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and s and s.castBarEnabled == true) end, width = "half" },
        },
    }
    local mountSubmenu = {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_MOUNT_STAMINA_BAR_SUBMENU")),
        controls = {
            { type = "checkbox", name = GetString(rawget(_G, "SI_BETTERUI_MOUNT_BAR_ENABLED")), tooltip = GetString(rawget(_G, "SI_BETTERUI_MOUNT_BAR_ENABLED_TOOLTIP")), sortAlwaysFirst = true, getFunc = mount.enabled.get, setFunc = mount.enabled.set, width = "full" },
            { type = "slider", name = GetString(rawget(_G, "SI_BETTERUI_MOUNT_BAR_TEXT_SIZE")), tooltip = GetString(rawget(_G, "SI_BETTERUI_MOUNT_BAR_TEXT_SIZE_TOOLTIP")), min = 5, max = 20, step = 1, getFunc = mount.text.size.get, setFunc = mount.text.size.set, disabled = function() local s = GetSharedSettings(shared); return not (s and s.mountStaminaBarEnabled == true) end, width = "full" },
            { type = "colorpicker", name = GetString(rawget(_G, "SI_BETTERUI_MOUNT_BAR_TEXT_COLOR")), tooltip = GetString(rawget(_G, "SI_BETTERUI_MOUNT_BAR_TEXT_COLOR_TOOLTIP")), getFunc = mount.text.color.get, setFunc = mount.text.color.set, disabled = function() local s = GetSharedSettings(shared); return not (s and s.mountStaminaBarEnabled == true) end, width = "full" },
            { type = "button", name = GetString(rawget(_G, "SI_BETTERUI_MOUNT_STAMINA_BAR_RESET")), tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP")),
                func = function() ResetSharedSettingsGroup(shared, { { key = "mountStaminaBarTextSize", value = 16 }, { key = "mountStaminaBarTextColor", isColor = true, colorFallback = { 1, 1, 1, 1 } } }) end,
                disabled = function() local s = GetSharedSettings(shared); return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and s and s.mountStaminaBarEnabled == true) end, width = "half" },
        },
    }
    return xpSubmenu, castSubmenu, mountSubmenu
end

-- SUBMENU SECTION ORDERING

--- Strips color codes, texture tags, and whitespace for sort-safe comparison.
local function NormalizeSectionSortName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalized = name
    normalized = normalized:gsub("|c%x%x%x%x%x%x", "") -- strip ESO color codes (|cRRGGBB)
    normalized = normalized:gsub("|r", "")               -- strip color reset tags
    normalized = normalized:gsub("|t[^|]+|t", "")        -- strip texture tags (|t...|t)
    normalized = normalized:gsub("%s+", " ")             -- collapse whitespace
    normalized = normalized:gsub("^%s+", "")             -- trim leading
    normalized = normalized:gsub("%s+$", "")             -- trim trailing

    if zo_strlower then
        return zo_strlower(normalized)
    end
    return string.lower(normalized)
end

--- Sorts header-delimited sections within a LAM controls array alphabetically.
local function SortSubmenuHeaderSectionsAlphabetically(controls)
    if type(controls) ~= "table" then
        return
    end

    local trailingButtons = {}
    while #controls > 0 do
        local lastControl = controls[#controls]
        if type(lastControl) == "table" and lastControl.type == "button" then
            table.insert(trailingButtons, 1, lastControl)
            table.remove(controls, #controls)
        else
            break
        end
    end

    local sections = {}
    local currentSection = nil
    local preHeaderControls = {}

    for _, control in ipairs(controls) do
        local isHeader = type(control) == "table" and control.type == "header" and type(control.name) == "string"
        if isHeader then
            currentSection = { control }
            table.insert(sections, currentSection)
        elseif currentSection then
            table.insert(currentSection, control)
        else
            -- Controls before the first header have no section; keep them at
            -- the top instead of dropping them during the rebuild.
            table.insert(preHeaderControls, control)
        end
    end

    table.sort(sections, function(leftSection, rightSection)
        local leftHeader = leftSection[1]
        local rightHeader = rightSection[1]
        local leftKey = NormalizeSectionSortName(leftHeader and leftHeader.name)
        local rightKey = NormalizeSectionSortName(rightHeader and rightHeader.name)
        if leftKey == rightKey then
            return tostring(leftHeader and leftHeader.name) < tostring(rightHeader and rightHeader.name)
        end
        return leftKey < rightKey
    end)

    local rebuilt = {}
    for _, control in ipairs(preHeaderControls) do
        table.insert(rebuilt, control)
    end
    for _, section in ipairs(sections) do
        for _, control in ipairs(section) do
            table.insert(rebuilt, control)
        end
    end
    for _, control in ipairs(trailingButtons) do
        table.insert(rebuilt, control)
    end

    for i = 1, #controls do
        controls[i] = nil
    end
    for i = 1, #rebuilt do
        controls[i] = rebuilt[i]
    end
end

--- Finds the Skill Bars submenu in optionsTable and sorts its sections alphabetically.
---@param optionsTable table|nil LAM options data array
---@return nil
function Submenus.ApplySubmenuSectionOrdering(optionsTable)
    if type(optionsTable) ~= "table" then
        return
    end

    local skillBarsSubmenuName = GetString(rawget(_G, "SI_BETTERUI_SKILL_BARS_SUBMENU"))
    for _, option in ipairs(optionsTable) do
        if type(option) == "table"
            and option.type == "submenu"
            and option.name == skillBarsSubmenuName
            and type(option.controls) == "table" then
            SortSubmenuHeaderSectionsAlphabetically(option.controls)
        end
    end
end
