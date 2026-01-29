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
Rationale: Quick way to reset search filter.
Used By: Inventory/Keybinds/InventoryKeybinds.lua, Banking/Keybinds/KeybindManager.lua
param: clearSearchFn (function) - Function to call to clear the search.
param: visibleFn (function|nil) - Optional visibility function.
return: table - Keybind descriptor for clear search action.
]]
--- @param clearSearchFn function Function to call to clear the search
--- @param visibleFn function|nil Optional visibility function
--- @return table keybind Keybind descriptor for clear search action
function BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(clearSearchFn, visibleFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(SI_BETTERUI_CLEAR_SEARCH),
        keybind = "UI_SHORTCUT_QUATERNARY",
        disabledDuringSceneHiding = true,
        visible = visibleFn or function() return true end,
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
Mechanism: Uses BETTERUI.Settings.Modules["CIM"].triggerSpeed for scroll amount.
param: list (table) - The parametric scroll list to control.
return: table, table - Left trigger and right trigger keybind descriptors.
]]
--- @param list table The parametric scroll list to control
--- @return table leftTrigger Left trigger keybind descriptor
--- @return table rightTrigger Right trigger keybind descriptor
function BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(list)
    local leftTrigger = {
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        ethereal = true,
        callback = function()
            if list and not list:IsEmpty() then
                local speed = tonumber(BETTERUI.Settings.Modules["CIM"].triggerSpeed) or 5
                list:SetSelectedIndex(list.selectedIndex - speed)
            end
        end
    }
    local rightTrigger = {
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        ethereal = true,
        callback = function()
            if list and not list:IsEmpty() then
                local speed = tonumber(BETTERUI.Settings.Modules["CIM"].triggerSpeed) or 5
                list:SetSelectedIndex(list.selectedIndex + speed)
            end
        end,
    }
    return leftTrigger, rightTrigger
end
