--[[
File: Modules/CIM/Keybinds/GenericKeybinds.lua
Purpose: Shared keybind descriptor factories for Inventory and Banking modules.
         Provides reusable keybind definitions to reduce duplication.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Keybinds then BETTERUI.CIM.Keybinds = {} end

-- KEYBIND FACTORY FUNCTIONS

function BETTERUI.CIM.Keybinds.CreateBackKeybind(callback)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
        keybind = "UI_SHORTCUT_NEGATIVE",
        order = 2000,
        callback = callback or function()
            SCENE_MANAGER:HideCurrentScene()
        end,
    }
end

function BETTERUI.CIM.Keybinds.CreateStackAllKeybind(bagId, visibleFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(rawget(_G, "SI_ITEM_ACTION_STACK_ALL")),
        keybind = "UI_SHORTCUT_LEFT_STICK",
        disabledDuringSceneHiding = true,
        visible = visibleFn or function() return true end,
        callback = function()
            StackBag(bagId)
        end,
    }
end

function BETTERUI.CIM.Keybinds.CreateActionsKeybind(showActionsFn, visibleFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND")),
        keybind = "UI_SHORTCUT_TERTIARY",
        order = 1000,
        visible = visibleFn or function() return true end,
        callback = showActionsFn,
    }
end

function BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(clearSearchFn, visibleFn, hasTextFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(rawget(_G, "SI_BETTERUI_CLEAR_SEARCH")),
        keybind = "UI_SHORTCUT_QUATERNARY",
        disabledDuringSceneHiding = true,
        visible = function()
            -- Base visibility check
            local baseVisible = true
            if visibleFn then
                baseVisible = visibleFn()
            end
            -- Additional check: only show if search has text
            if hasTextFn then
                return baseVisible and hasTextFn()
            end
            return baseVisible
        end,
        callback = clearSearchFn,
    }
end

-- KEYBIND GROUP HELPERS

function BETTERUI.CIM.Keybinds.AddBackNavigation(keybindGroup, navigationType)
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(
        keybindGroup,
        navigationType or GAME_NAVIGATION_TYPE_BUTTON
    )
end

--[[
Function: BETTERUI.CIM.Keybinds.AddTriggerKeybinds
Adds trigger keybinds for a parametric list (LT/RT for page navigation).
param: keybindGroup (table) - The keybind group to add to.
param: list (table) - The parametric scroll list.
]]
function BETTERUI.CIM.Keybinds.AddTriggerKeybinds(keybindGroup, list)
    ZO_Gamepad_AddListTriggerKeybindDescriptors(keybindGroup, list)
end

function BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(listOrGetter, useCategoryJumpGetter, speedGetter, enabledGetter)

    local function GetActualList(listWrapper)
        if not listWrapper then return nil end
        if listWrapper.JumpToPreviousHeader then return listWrapper end
        if listWrapper.list and listWrapper.list.JumpToPreviousHeader then return listWrapper.list end
        if listWrapper.GetParametricList then
            local pList = listWrapper:GetParametricList()
            if pList and pList.JumpToPreviousHeader then return pList end
        end
        return listWrapper
    end

    local function GetSpeed()
        if type(speedGetter) == "function" then
            return tonumber(speedGetter()) or BETTERUI.CIM.CONST.DEFAULTS.DEFAULT_TRIGGER_SPEED
        end
        return BETTERUI.CIM.CONST.DEFAULTS.DEFAULT_TRIGGER_SPEED
    end

    local function IsEnabled()
        if type(enabledGetter) == "function" then
            return enabledGetter() == true
        end
        return true -- Default: always enabled if no getter
    end

    local function GetSelectedIndex(list)
        if type(list.targetSelectedIndex) == "number" and list.targetSelectedIndex >= 1 then
            return list.targetSelectedIndex
        end
        if type(list.selectedIndex) == "number" and list.selectedIndex >= 1 then
            return list.selectedIndex
        end
        if list.GetSelectedIndex then
            local selectedIndex = list:GetSelectedIndex()
            if type(selectedIndex) == "number" and selectedIndex >= 1 then
                return selectedIndex
            end
        end
        return 1
    end

    local leftTrigger = {
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        ethereal = true,
        callback = function()
            if not IsEnabled() then return end
            local rawList = type(listOrGetter) == "function" and listOrGetter() or listOrGetter
            local list = GetActualList(rawList)
            if list and (not list.IsActive or list:IsActive()) then
                local jumpByCategory = false
                if type(useCategoryJumpGetter) == "function" then
                    jumpByCategory = useCategoryJumpGetter()
                elseif type(useCategoryJumpGetter) == "boolean" then
                    jumpByCategory = useCategoryJumpGetter
                end

                if jumpByCategory and list.JumpToPreviousHeader then
                    list:JumpToPreviousHeader()
                elseif not list:IsEmpty() then
                    local speed = GetSpeed()
                    list:SetSelectedIndex(GetSelectedIndex(list) - speed)
                end
            end
        end
    }
    local rightTrigger = {
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        ethereal = true,
        callback = function()
            if not IsEnabled() then return end
            local rawList = type(listOrGetter) == "function" and listOrGetter() or listOrGetter
            local list = GetActualList(rawList)
            if list and (not list.IsActive or list:IsActive()) then
                local jumpByCategory = false
                if type(useCategoryJumpGetter) == "function" then
                    jumpByCategory = useCategoryJumpGetter()
                elseif type(useCategoryJumpGetter) == "boolean" then
                    jumpByCategory = useCategoryJumpGetter
                end

                if jumpByCategory and list.JumpToNextHeader then
                    list:JumpToNextHeader()
                elseif not list:IsEmpty() then
                    local speed = GetSpeed()
                    list:SetSelectedIndex(GetSelectedIndex(list) + speed)
                end
            end
        end,
    }
    return leftTrigger, rightTrigger
end
