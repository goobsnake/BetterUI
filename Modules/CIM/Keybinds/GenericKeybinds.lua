--[[
File: Modules/CIM/Keybinds/GenericKeybinds.lua
Purpose: Shared keybind descriptor factories for Inventory and Banking modules.
         Provides reusable keybind definitions to reduce duplication.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Keybinds then BETTERUI.CIM.Keybinds = {} end

local BuildTriggerKeybinds

local function AsFunctionOrBoolean(value)
    if type(value) == "function" then
        return value
    end
    if type(value) == "boolean" then
        return function()
            return value
        end
    end
    return nil
end

-- KEYBIND FACTORY FUNCTIONS

---@param callback function|nil
---@return BetterUIKeybindDescriptor
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

---@param bagId number
---@param visibleFn function|nil
---@return BetterUIKeybindDescriptor
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

---@param showActionsFn function|nil
---@param visibleFn function|nil
---@return BetterUIKeybindDescriptor
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

---@param clearSearchFn function
---@param visibleFn function|nil
---@param hasTextFn function|nil
---@return BetterUIKeybindDescriptor
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

---@param keybindGroup table The keybind group to mutate
---@param navigationType number|nil Optional navigation event type
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

---@param keybindGroup table The keybind group to mutate
---@param list BetterUIListTriggerListLike List or list provider
function BETTERUI.CIM.Keybinds.AddTriggerKeybinds(keybindGroup, list)
    ZO_Gamepad_AddListTriggerKeybindDescriptors(keybindGroup, list)
end

local function ResolveList(listOrGetter)
    local listWrapper = listOrGetter
    if type(listWrapper) == "function" then
        listWrapper = listWrapper()
    end
    if not listWrapper then return nil end
    if listWrapper.JumpToPreviousHeader then return listWrapper end
    if listWrapper.list and listWrapper.list.JumpToPreviousHeader then return listWrapper.list end
    if listWrapper.GetParametricList then
        local parametricList = listWrapper:GetParametricList()
        if parametricList and parametricList.JumpToPreviousHeader then
            return parametricList
        end
    end
    return listWrapper
end

local function CoerceListTriggerContract(listOrGetter, useCategoryJumpGetter, speedGetter, enabledGetter)
    if type(listOrGetter) == "table" and rawget(listOrGetter, "list") ~= nil then
        return {
            list = listOrGetter.list,
            resolveCategoryJump = AsFunctionOrBoolean(listOrGetter.resolveCategoryJump),
            getSpeed = type(listOrGetter.getSpeed) == "function" and listOrGetter.getSpeed or nil,
            isEnabled = type(listOrGetter.isEnabled) == "function" and listOrGetter.isEnabled or nil,
        }
    end

    return {
        list = listOrGetter,
        resolveCategoryJump = AsFunctionOrBoolean(useCategoryJumpGetter),
        getSpeed = type(speedGetter) == "function" and speedGetter or nil,
        isEnabled = type(enabledGetter) == "function" and enabledGetter or nil,
    }
end

BuildTriggerKeybinds = function(contract)
    local listOrGetter = contract.list
    local categoryJumpGetter = contract.resolveCategoryJump
    local speedGetter = contract.getSpeed
    local enabledGetter = contract.isEnabled

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
            local list = ResolveList(listOrGetter)
            if list and (not list.IsActive or list:IsActive()) then
                local jumpByCategory = false
                if type(categoryJumpGetter) == "function" then
                    jumpByCategory = categoryJumpGetter() == true
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
            local list = ResolveList(listOrGetter)
            if list and (not list.IsActive or list:IsActive()) then
                local jumpByCategory = false
                if type(categoryJumpGetter) == "function" then
                    jumpByCategory = categoryJumpGetter() == true
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

--- Public contract uses a single explicit key trigger option contract.
---@param contract BetterUIListTriggerKeybindContract
---@return BetterUITriggerKeybindDescriptor
---@return BetterUITriggerKeybindDescriptor
function BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(contract)
    assert(type(contract) == "table" and rawget(contract, "list") ~= nil,
        "CreateListTriggerKeybinds expects BetterUIListTriggerKeybindContract with a list field")
    return BuildTriggerKeybinds(CoerceListTriggerContract(contract))
end
