--[[
File: Modules/CIM/Keybinds/GenericKeybinds.lua
Purpose: Shared keybind descriptor factories for Inventory and Banking modules.
         Provides reusable keybind definitions to reduce duplication.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Keybinds then BETTERUI.CIM.Keybinds = {} end

-------------------------------------------------------------------------------------------------
-- KEYBIND FACTORY FUNCTIONS
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.Keybinds.CreateBackKeybind
Description: Creates a standard back navigation keybind.
Rationale: Common pattern for exiting a scene.
Used By: Common utility, not currently in production use.
param: callback (function|nil) - Custom callback. If nil, uses standard back navigation.
return: table - Keybind descriptor for back navigation.
]]
--- @param callback function|nil Custom callback for the back action
--- @return table keybind Keybind descriptor for back navigation
function BETTERUI.CIM.Keybinds.CreateBackKeybind(callback)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(SI_GAMEPAD_BACK_OPTION),
        keybind = "UI_SHORTCUT_NEGATIVE",
        order = 2000,
        callback = callback or function()
            SCENE_MANAGER:HideCurrentScene()
        end,
    }
end

--[[
Function: BETTERUI.CIM.Keybinds.CreateStackAllKeybind
Description: Creates a "Stack All" keybind for a specific bag.
Rationale: L-Stick action to consolidate item stacks.
Used By: Inventory/Keybinds/InventoryKeybinds.lua
param: bagId (number) - The bag to stack items in.
param: visibleFn (function|nil) - Optional visibility function.
return: table - Keybind descriptor for stack all action.
]]
--- @param bagId number The bag to stack items in
--- @param visibleFn function|nil Optional visibility function
--- @return table keybind Keybind descriptor for stack all action
function BETTERUI.CIM.Keybinds.CreateStackAllKeybind(bagId, visibleFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(SI_ITEM_ACTION_STACK_ALL),
        keybind = "UI_SHORTCUT_LEFT_STICK",
        disabledDuringSceneHiding = true,
        visible = visibleFn or function() return true end,
        callback = function()
            StackBag(bagId)
        end,
    }
end

--[[
Function: BETTERUI.CIM.Keybinds.CreateActionsKeybind
Description: Creates an "Actions" keybind (Y-button menu).
Rationale: Opens the context menu for the selected item.
Used By: Inventory/Keybinds/InventoryKeybinds.lua, Banking/Keybinds/KeybindManager.lua
param: showActionsFn (function) - Function to call to show the actions menu.
param: visibleFn (function|nil) - Optional visibility function.
return: table - Keybind descriptor for actions menu.
]]
--- @param showActionsFn function Function to call to show the actions menu
--- @param visibleFn function|nil Optional visibility function
--- @return table keybind Keybind descriptor for actions menu
function BETTERUI.CIM.Keybinds.CreateActionsKeybind(showActionsFn, visibleFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND),
        keybind = "UI_SHORTCUT_TERTIARY",
        order = 1000,
        visible = visibleFn or function() return true end,
        callback = showActionsFn,
    }
end

--[[
Function: BETTERUI.CIM.Keybinds.CreateClearSearchKeybind
Description: Creates a "Clear Search" keybind.
             Only visible when search box contains text (via hasTextFn).
Rationale: Quick way to reset search filter. Hidden when empty to reduce keybind clutter.
Used By: Inventory/Keybinds/InventoryKeybinds.lua, Banking/Keybinds/KeybindManager.lua
param: clearSearchFn (function) - Function to call to clear the search.
param: visibleFn (function|nil) - Optional base visibility function.
param: hasTextFn (function|nil) - Optional function returning true if search has text. If nil, always shows.
return: table - Keybind descriptor for clear search action.
]]
--- @param clearSearchFn function Function to call to clear the search
--- @param visibleFn function|nil Optional base visibility function
--- @param hasTextFn function|nil Optional function returning true if search has text
--- @return table keybind Keybind descriptor for clear search action
function BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(clearSearchFn, visibleFn, hasTextFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(SI_BETTERUI_CLEAR_SEARCH),
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

-------------------------------------------------------------------------------------------------
-- KEYBIND GROUP HELPERS
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.Keybinds.AddBackNavigation
Description: Adds back navigation keybind(s) to a keybind group.
Rationale: Wrapper around ZO_Gamepad_AddBackNavigationKeybindDescriptors for consistency.
param: keybindGroup (table) - The keybind group to add to.
param: navigationType (number|nil) - Navigation type. Defaults to GAME_NAVIGATION_TYPE_BUTTON.
]]
--- @param keybindGroup table The keybind group to add to
--- @param navigationType number|nil Navigation type constant
function BETTERUI.CIM.Keybinds.AddBackNavigation(keybindGroup, navigationType)
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(
        keybindGroup,
        navigationType or GAME_NAVIGATION_TYPE_BUTTON
    )
end

--[[
Function: BETTERUI.CIM.Keybinds.AddTriggerKeybinds
Description: Adds trigger keybinds for a parametric list (LT/RT for page navigation).
Rationale: Wrapper around ZO_Gamepad_AddListTriggerKeybindDescriptors.
param: keybindGroup (table) - The keybind group to add to.
param: list (table) - The parametric scroll list.
]]
function BETTERUI.CIM.Keybinds.AddTriggerKeybinds(keybindGroup, list)
    ZO_Gamepad_AddListTriggerKeybindDescriptors(keybindGroup, list)
end

--[[
Function: BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds
Description: Creates LT/RT keybinds for fast scrolling with configurable speed.
Rationale: Used by Banking/Inventory for trigger-based list navigation.
Mechanism: Uses per-module speedGetter for scroll amount, or falls back to DEFAULT_TRIGGER_SPEED.
param: listOrGetter (table|function) - The parametric scroll list, or a function returning it.
param: useCategoryJumpGetter (function|boolean|nil) - Optional. Getter for category jump mode.
param: speedGetter (function|nil) - Optional. Returns the trigger speed for this module.
param: enabledGetter (function|nil) - Optional. Returns whether triggers are enabled. Nil = always enabled.
return: table, table - Left trigger and right trigger keybind descriptors.
]]
--- @param listOrGetter table|function The parametric scroll list, or a function returning it
--- @param useCategoryJumpGetter function|boolean|nil Optional. Getter function returning boolean if category jump should be used instead of speed skip.
--- @param speedGetter function|nil Optional. Returns the number of lines to skip per trigger press.
--- @param enabledGetter function|nil Optional. Returns whether triggers are enabled for this module.
--- @return table leftTrigger Left trigger keybind descriptor
--- @return table rightTrigger Right trigger keybind descriptor
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
            return tonumber(speedGetter()) or BETTERUI.CONST.DEFAULT_TRIGGER_SPEED
        end
        return BETTERUI.CONST.DEFAULT_TRIGGER_SPEED
    end

    local function IsEnabled()
        if type(enabledGetter) == "function" then
            return enabledGetter() == true
        end
        return true -- Default: always enabled if no getter
    end

    local leftTrigger = {
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        ethereal = true,
        callback = function()
            if not IsEnabled() then return end
            local rawList = type(listOrGetter) == "function" and listOrGetter() or listOrGetter
            local list = GetActualList(rawList)
            if list then
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
                    list:SetSelectedIndex(list.selectedIndex - speed)
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
            if list then
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
                    list:SetSelectedIndex(list.selectedIndex + speed)
                end
            end
        end,
    }
    return leftTrigger, rightTrigger
end
