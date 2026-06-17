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
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "createBack")
    end
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
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "createStackAll", {bagId = bagId})
    end
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
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "createActions")
    end
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
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "createClearSearch")
    end
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

-- MULTI-SELECT LABEL BUILDERS
-- Shared label text for multi-select / batch-select keybinds and dialog
-- entries, used by the Inventory, Banking, and Vendor modules.

--- "Multi-Select" mode-entry keybind label.
---@return string
function BETTERUI.CIM.Keybinds.GetMultiSelectLabel()
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "multiSelectLabel", {count = 0})
    end
    return GetString(rawget(_G, "SI_BETTERUI_MULTI_SELECT") or "SI_BETTERUI_MULTI_SELECT")
end

--- "Select All" batch-dialog entry label.
---@return string
function BETTERUI.CIM.Keybinds.GetSelectAllLabel()
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "multiSelectLabel", {count = 0})
    end
    return GetString(rawget(_G, "SI_BETTERUI_SELECT_ALL") or "SI_BETTERUI_SELECT_ALL")
end

--- "Deselect All (<count>)" batch-dialog entry label.
---@param selectedCount number Current number of selected rows
---@return string
function BETTERUI.CIM.Keybinds.GetDeselectAllLabel(selectedCount)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "multiSelectLabel", {count = selectedCount})
    end
    return zo_strformat("<<1>> (<<2>>)",
        GetString(rawget(_G, "SI_BETTERUI_DESELECT_ALL") or "SI_BETTERUI_DESELECT_ALL"), selectedCount)
end

--- Selection-mode toggle label: "Deselect" when the target row is selected,
--- otherwise "Select (<count>)". With afterToggle the label reflects the
--- state the row will have once the pending toggle is applied.
---@param manager table Multi-select manager owning the selection state
---@param target table|nil Currently highlighted list entry
---@param afterToggle boolean|nil When true, report the post-toggle label
---@return string
function BETTERUI.CIM.Keybinds.GetMultiSelectToggleLabel(manager, target, afterToggle)
    local isSelected = target and manager:IsSelected(target) or false
    if afterToggle then
        isSelected = not isSelected
    end
    if isSelected then
        return GetString(rawget(_G, "SI_BETTERUI_DESELECT_ITEM") or "SI_BETTERUI_DESELECT_ITEM")
    end

    local count = manager.GetSelectedCount and manager:GetSelectedCount() or 0
    if afterToggle and target then
        if manager:IsSelected(target) then
            count = math.max(0, count - 1)
        else
            count = count + 1
        end
    end
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "multiSelectLabel", {count = count})
    end
    return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_SELECT_WITH_COUNT") or "SI_BETTERUI_SELECT_WITH_COUNT"), count)
end

-- KEYBIND GROUP HELPERS

---@param keybindGroup table The keybind group to mutate
---@param navigationType number|nil Optional navigation event type
function BETTERUI.CIM.Keybinds.AddBackNavigation(keybindGroup, navigationType)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "addBackNav")
    end
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(
        keybindGroup,
        navigationType or GAME_NAVIGATION_TYPE_BUTTON
    )
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
                elseif not list.IsEmpty or not list:IsEmpty() then
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
                elseif not list.IsEmpty or not list:IsEmpty() then
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
    local leftTrigger, rightTrigger = BuildTriggerKeybinds(CoerceListTriggerContract(contract))
    if BETTERUI.Log then
        local speed = leftTrigger and leftTrigger.callback and "variable" or "default"
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "triggerKeybinds", {speed = speed})
    end
    return leftTrigger, rightTrigger
end
