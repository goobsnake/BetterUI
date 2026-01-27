--[[
File: Modules/CIM/Keybinds/GenericKeybinds.lua
Purpose: Shared keybind descriptor factories for Inventory and Banking modules.
         Provides reusable keybind definitions to reduce duplication.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

local _

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Keybinds then BETTERUI.CIM.Keybinds = {} end

-------------------------------------------------------------------------------------------------
-- KEYBIND FACTORY FUNCTIONS
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.Keybinds.CreateBackKeybind
Description: Creates a standard back navigation keybind.
Rationale: Common pattern for exiting a scene.
param: callback (function|nil) - Custom callback. If nil, uses standard back navigation.
return: table - Keybind descriptor for back navigation.
]]
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
param: bagId (number) - The bag to stack items in.
param: visibleFn (function|nil) - Optional visibility function.
return: table - Keybind descriptor for stack all action.
]]
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
Function: BETTERUI.CIM.Keybinds.CreateLinkToChatKeybind
Description: Creates a "Link to Chat" keybind.
Rationale: Common action to insert item link into chat.
param: getItemLinkFn (function) - Function that returns the item link to insert.
param: visibleFn (function|nil) - Optional visibility function.
return: table - Keybind descriptor for link to chat action.
]]
function BETTERUI.CIM.Keybinds.CreateLinkToChatKeybind(getItemLinkFn, visibleFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(SI_ITEM_ACTION_LINK_TO_CHAT),
        keybind = "UI_SHORTCUT_SECONDARY",
        visible = visibleFn or function()
            local itemLink = getItemLinkFn and getItemLinkFn()
            return itemLink and itemLink ~= ""
        end,
        callback = function()
            local itemLink = getItemLinkFn and getItemLinkFn()
            if itemLink and itemLink ~= "" then
                ZO_LinkHandler_InsertLink(zo_strformat("<<2>>", SI_TOOLTIP_ITEM_NAME, itemLink))
            end
        end,
    }
end

--[[
Function: BETTERUI.CIM.Keybinds.CreateActionsKeybind
Description: Creates an "Actions" keybind (Y-button menu).
Rationale: Opens the context menu for the selected item.
param: showActionsFn (function) - Function to call to show the actions menu.
param: visibleFn (function|nil) - Optional visibility function.
return: table - Keybind descriptor for actions menu.
]]
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
param: clearSearchFn (function) - Function to call to clear the search.
param: visibleFn (function|nil) - Optional visibility function.
return: table - Keybind descriptor for clear search action.
]]
function BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(clearSearchFn, visibleFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = function()
            return GetString(SI_BETTERUI_CLEAR_SEARCH) or GetString(SI_GAMEPAD_SELECT_OPTION) or "Clear"
        end,
        keybind = "UI_SHORTCUT_QUATERNARY",
        disabledDuringSceneHiding = true,
        visible = visibleFn or function() return true end,
        callback = clearSearchFn,
    }
end

--[[
Function: BETTERUI.CIM.Keybinds.CreateSwitchModeKeybind
Description: Creates a mode switch keybind (e.g., Inventory <-> Craft Bag).
Rationale: R-Stick action to toggle between different view modes.
param: getNameFn (function) - Function returning the keybind display name.
param: switchFn (function) - Function to call to perform the switch.
param: visibleFn (function|nil) - Optional visibility function.
return: table - Keybind descriptor for switch mode action.
]]
function BETTERUI.CIM.Keybinds.CreateSwitchModeKeybind(getNameFn, switchFn, visibleFn)
    return {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        name = getNameFn,
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        disabledDuringSceneHiding = true,
        visible = visibleFn or function() return true end,
        callback = switchFn,
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
