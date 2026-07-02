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

local function TraceKeybind(scope, keybind, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.scope = scope
    data.keybind = keybind
    L.TraceEvent(L.CATEGORY.KEYBIND, "keybind.callback", phase, data)
end

local function InvokeKeybind(scope, keybind, action, callback, data)
    if type(callback) ~= "function" then
        TraceKeybind(scope, keybind, "end", { action = action, handled = false, reason = "missingCallback" })
        return nil
    end
    data = data or {}
    data.action = action
    TraceKeybind(scope, keybind, "begin", data)
    local r1, r2, r3 = callback()
    data.handled = r1 ~= false
    data.reason = r2
    data.branch = r3
    TraceKeybind(scope, keybind, "end", data)
    return r1, r2, r3
end

-- KEYBIND FACTORY FUNCTIONS

---@param callback function|nil
---@return BetterUIKeybindDescriptor
function BETTERUI.CIM.Keybinds.CreateBackKeybind(callback)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: back created")
    end
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
        keybind = "UI_SHORTCUT_NEGATIVE",
        order = 2000,
        callback = function()
            return InvokeKeybind("generic", "UI_SHORTCUT_NEGATIVE", "back", callback or function()
                SCENE_MANAGER:HideCurrentScene()
            end)
        end,
    }
end

---@param bagId number
---@param visibleFn function|nil
---@return BetterUIKeybindDescriptor
function BETTERUI.CIM.Keybinds.CreateStackAllKeybind(bagId, visibleFn)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: stack all created", {bagId = bagId})
    end
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(rawget(_G, "SI_ITEM_ACTION_STACK_ALL")),
        keybind = "UI_SHORTCUT_LEFT_STICK",
        disabledDuringSceneHiding = true,
        visible = visibleFn or function() return true end,
        callback = function()
            return InvokeKeybind("generic", "UI_SHORTCUT_LEFT_STICK", "stack_all", function()
                StackBag(bagId)
            end, { bagId = bagId })
        end,
    }
end

---@param showActionsFn function|nil
---@param visibleFn function|nil
---@return BetterUIKeybindDescriptor
function BETTERUI.CIM.Keybinds.CreateActionsKeybind(showActionsFn, visibleFn)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: actions created")
    end
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND")),
        keybind = "UI_SHORTCUT_TERTIARY",
        order = 1000,
        visible = visibleFn or function() return true end,
        callback = type(showActionsFn) == "function" and function()
            return InvokeKeybind("generic", "UI_SHORTCUT_TERTIARY", "actions", showActionsFn)
        end or nil,
    }
end

---@param clearSearchFn function
---@param visibleFn function|nil
---@param hasTextFn function|nil
---@return BetterUIKeybindDescriptor
function BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(clearSearchFn, visibleFn, hasTextFn)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: clear search created")
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
        callback = function()
            return InvokeKeybind("generic", "UI_SHORTCUT_QUATERNARY", "clear_search", clearSearchFn)
        end,
    }
end

-- MULTI-SELECT LABEL BUILDERS
-- Shared label text for multi-select / batch-select keybinds and dialog
-- entries, used by the Inventory, Banking, and Vendor modules.

--- "Multi-Select" mode-entry keybind label.
---@return string
function BETTERUI.CIM.Keybinds.GetMultiSelectLabel()
    return GetString(rawget(_G, "SI_BETTERUI_MULTI_SELECT") or "SI_BETTERUI_MULTI_SELECT")
end

--- "Select All" batch-dialog entry label.
---@return string
function BETTERUI.CIM.Keybinds.GetSelectAllLabel()
    return GetString(rawget(_G, "SI_BETTERUI_SELECT_ALL") or "SI_BETTERUI_SELECT_ALL")
end

--- "Deselect All (<count>)" batch-dialog entry label.
---@param selectedCount number Current number of selected rows
---@return string
function BETTERUI.CIM.Keybinds.GetDeselectAllLabel(selectedCount)
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
    return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_SELECT_WITH_COUNT") or "SI_BETTERUI_SELECT_WITH_COUNT"), count)
end

-- KEYBIND GROUP HELPERS

---@param keybindGroup table The keybind group to mutate
---@param navigationType number|nil Optional navigation event type
function BETTERUI.CIM.Keybinds.AddBackNavigation(keybindGroup, navigationType)
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: back navigation added")
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

    local function TraceListTrigger(direction, phase, list, data)
        local L = BETTERUI.Log
        if not (L and L.TraceEvent) then return end
        data = data or {}
        data.direction = direction
        data.keybind = direction == "previous" and "UI_SHORTCUT_LEFT_TRIGGER" or "UI_SHORTCUT_RIGHT_TRIGGER"
        if list and L.DescribeListSelection then
            data.selected = L.DescribeListSelection(list, "selection")
        end
        L.TraceEvent(L.CATEGORY.KEYBIND, "keybind.list_trigger", phase, data)
    end

    local leftTrigger = {
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        ethereal = true,
        callback = function()
            if not IsEnabled() then
                TraceListTrigger("previous", "skipped", nil, { reason = "disabled" })
                return
            end
            local list = ResolveList(listOrGetter)
            if not list then
                TraceListTrigger("previous", "skipped", nil, { reason = "missingList" })
                return
            end
            if list.IsActive and not list:IsActive() then
                TraceListTrigger("previous", "skipped", list, { reason = "inactiveList" })
                return
            end
            local jumpByCategory = false
            if type(categoryJumpGetter) == "function" then
                jumpByCategory = categoryJumpGetter() == true
            end
            local speed = GetSpeed()
            local selectedBefore = GetSelectedIndex(list)
            TraceListTrigger("previous", "begin", list, {
                jumpByCategory = jumpByCategory,
                speed = speed,
                selectedBefore = selectedBefore,
            })
            local action = "none"
            if jumpByCategory and list.JumpToPreviousHeader then
                action = "previousHeader"
                list:JumpToPreviousHeader()
            elseif not list.IsEmpty or not list:IsEmpty() then
                action = "offset"
                list:SetSelectedIndex(selectedBefore - speed)
            else
                action = "empty"
            end
            TraceListTrigger("previous", "end", list, {
                action = action,
                jumpByCategory = jumpByCategory,
                speed = speed,
                selectedBefore = selectedBefore,
                selectedAfter = GetSelectedIndex(list),
            })
        end
    }

    local rightTrigger = {
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        ethereal = true,
        callback = function()
            if not IsEnabled() then
                TraceListTrigger("next", "skipped", nil, { reason = "disabled" })
                return
            end
            local list = ResolveList(listOrGetter)
            if not list then
                TraceListTrigger("next", "skipped", nil, { reason = "missingList" })
                return
            end
            if list.IsActive and not list:IsActive() then
                TraceListTrigger("next", "skipped", list, { reason = "inactiveList" })
                return
            end
            local jumpByCategory = false
            if type(categoryJumpGetter) == "function" then
                jumpByCategory = categoryJumpGetter() == true
            end
            local speed = GetSpeed()
            local selectedBefore = GetSelectedIndex(list)
            TraceListTrigger("next", "begin", list, {
                jumpByCategory = jumpByCategory,
                speed = speed,
                selectedBefore = selectedBefore,
            })
            local action = "none"
            if jumpByCategory and list.JumpToNextHeader then
                action = "nextHeader"
                list:JumpToNextHeader()
            elseif not list.IsEmpty or not list:IsEmpty() then
                action = "offset"
                list:SetSelectedIndex(selectedBefore + speed)
            else
                action = "empty"
            end
            TraceListTrigger("next", "end", list, {
                action = action,
                jumpByCategory = jumpByCategory,
                speed = speed,
                selectedBefore = selectedBefore,
                selectedAfter = GetSelectedIndex(list),
            })
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
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "keybind: list triggers created", {speed = speed})
    end
    return leftTrigger, rightTrigger
end
