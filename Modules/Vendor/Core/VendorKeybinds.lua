--[[
File: Modules/Vendor/Core/VendorKeybinds.lua
Purpose: Build and trace Vendor keybind descriptor groups.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}

local VendorKeybinds = {}
BETTERUI.Vendor.Keybinds = VendorKeybinds

local function requireFunction(deps, name)
    local fn = deps and deps[name]
    assert(type(fn) == "function", "VendorKeybinds requires dependency function: " .. tostring(name))
    return fn
end

local function TraceVendorKeybind(ctx, key, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then
        return
    end
    data = data or {}
    data.key = data.key or key
    data.action = data.action or key
    data.feature = data.feature or "vendor-keybind"
    data.fn = data.fn or "Vendor.BuildCoreKeybinds"
    data._inputAnchorDetail = true
    ctx.traceVendorEvent("vendor.keybind", phase, data, L.CATEGORY.KEYBIND)
end

local function ExecuteVendorKeybindAction(ctx, key, action, fn, endData)
    TraceVendorKeybind(ctx, key, "begin", { action = action })
    local Vendor = ctx.Vendor
    local ok, result
    if type(Vendor.ExecuteSafely) == "function" then
        ok, result = Vendor.ExecuteSafely("Vendor.Keybind:" .. tostring(action), fn)
    else
        ok, result = pcall(fn)
    end
    if not ok then
        TraceVendorKeybind(ctx, key, "failed", {
            action = action,
            reason = "error",
            error = result,
        })
        return false, result
    end
    local payload = {}
    for payloadKey, value in pairs(endData or {}) do
        payload[payloadKey] = value
    end
    payload.action = action
    payload.result = payload.result or "dispatched"
    TraceVendorKeybind(ctx, key, "end", payload)
    return true, result
end

local function WrapVendorKeybindGroup(group)
    local keybinds = BETTERUI.CIM and BETTERUI.CIM.Keybinds
    local anchor = keybinds and keybinds.InputAnchor
    if anchor and type(anchor.WrapGroup) == "function" then
        return anchor.WrapGroup(group, "Vendor")
    end
    return group
end

local function UpdateCurrentKeybindGroups()
    local interface = BETTERUI and BETTERUI.Interface
    local update = interface and interface.UpdateCurrentKeybindGroups
    if type(update) == "function" then
        pcall(update)
    end
end

function VendorKeybinds.Describe(instance)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.DescribeKeybindDescriptors and instance) then
        return nil
    end

    return {
        core = instance.coreKeybinds and L.DescribeKeybindDescriptors(instance.coreKeybinds, "core") or nil,
        search = instance.textSearchKeybindStripDescriptor and L.DescribeKeybindDescriptors(instance.textSearchKeybindStripDescriptor, "search") or nil,
    }
end

---@param vendorInstance BETTERUI.Vendor.Class
---@param deps table
---@return BetterUIKeybindDescriptorGroup keybindGroup Core keybind descriptor group
function VendorKeybinds.BuildCoreKeybinds(vendorInstance, deps)
    deps = deps or {}
    local Vendor = deps.Vendor or BETTERUI.Vendor
    local MODE = deps.MODE or Vendor.MODE
    local ctx = {
        Vendor = Vendor,
        traceVendorEvent = requireFunction(deps, "traceVendorEvent"),
    }
    local getActiveTabs = requireFunction(deps, "getActiveTabs")
    local getToggleModePair = requireFunction(deps, "getToggleModePair")
    local getCurrentVendorTargetData = requireFunction(deps, "getCurrentVendorTargetData")
    local isPrimaryActionAllowed = requireFunction(deps, "isPrimaryActionAllowed")
    local canMultiSelectInCurrentMode = requireFunction(deps, "canMultiSelectInCurrentMode")
    local isMultiSelectAvailable = requireFunction(deps, "isMultiSelectAvailable")
    local registerVendorBatchDialog = requireFunction(deps, "registerVendorBatchDialog")
    local isFenceInteraction = requireFunction(deps, "isFenceInteraction")
    local isStableInteraction = requireFunction(deps, "isStableInteraction")

    return WrapVendorKeybindGroup({
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            ethereal = true,
            visible = function()
                if vendorInstance.headerGeneric and vendorInstance.headerGeneric.tabBar then
                    return false
                end
                if vendorInstance._vendorHeaderEntryCount and vendorInstance._vendorHeaderEntryCount > 1 then
                    return true
                end
                return #getActiveTabs() > 1
            end,
            callback = function()
                ExecuteVendorKeybindAction(ctx, "UI_SHORTCUT_LEFT_SHOULDER", "cycle_tabs_previous", function()
                    vendorInstance:CycleTabs(-1)
                end, { result = "cycled", direction = "previous" })
            end,
        },
        {
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            ethereal = true,
            visible = function()
                if vendorInstance.headerGeneric and vendorInstance.headerGeneric.tabBar then
                    return false
                end
                if vendorInstance._vendorHeaderEntryCount and vendorInstance._vendorHeaderEntryCount > 1 then
                    return true
                end
                return #getActiveTabs() > 1
            end,
            callback = function()
                ExecuteVendorKeybindAction(ctx, "UI_SHORTCUT_RIGHT_SHOULDER", "cycle_tabs_next", function()
                    vendorInstance:CycleTabs(1)
                end, { result = "cycled", direction = "next" })
            end,
        },
        {
            name = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return BETTERUI.CIM.Keybinds.GetMultiSelectToggleLabel(ms, getCurrentVendorTargetData(vendorInstance))
                end
                local component = vendorInstance:GetActiveComponent()
                if component and component.GetPrimaryActionName then
                    return component:GetPrimaryActionName(vendorInstance)
                end
                return GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION"))
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return isPrimaryActionAllowed()
            end,
            callback = function()
                local key = "UI_SHORTCUT_PRIMARY"
                if not isPrimaryActionAllowed() then
                    TraceVendorKeybind(ctx, key, "skipped", {
                        action = "primary",
                        reason = "primaryActionNotAllowed",
                    })
                    return
                end
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    local selectedData = getCurrentVendorTargetData(vendorInstance)
                    if not selectedData then
                        TraceVendorKeybind(ctx, key, "skipped", {
                            action = "multi_select_toggle",
                            reason = "missingSelection",
                        })
                        return
                    end
                    ExecuteVendorKeybindAction(ctx, key, "multi_select_toggle", function()
                        vendorInstance:SaveListPosition()
                        ms:ToggleSelection(selectedData)
                        vendorInstance:RefreshList()
                        vendorInstance:EnsureListInputActive()
                    end, { result = "toggled" })
                    return
                end
                local component = vendorInstance:GetActiveComponent()
                if component and component.OnPrimaryAction then
                    ExecuteVendorKeybindAction(ctx, key, "primary", function()
                        component:OnPrimaryAction(vendorInstance)
                    end, { result = "dispatched" })
                else
                    TraceVendorKeybind(ctx, key, "skipped", {
                        action = "primary",
                        reason = "missingComponentAction",
                    })
                end
            end,
            enabled = function()
                if not isPrimaryActionAllowed() then
                    return false
                end

                local ms = Vendor.multiSelectManager
                local selectedData = getCurrentVendorTargetData(vendorInstance)
                if ms and ms:IsActive() then
                    return selectedData ~= nil
                end

                local component = vendorInstance:GetActiveComponent()
                if component and component.IsPrimaryActionEnabled then
                    return component:IsPrimaryActionEnabled(vendorInstance)
                end
                return selectedData ~= nil
            end,
        },
        {
            name = function()
                return GetString(rawget(_G, "SI_BETTERUI_BANKING_TOGGLE_LIST") or "SI_BETTERUI_BANKING_TOGGLE_LIST")
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then return false end
                local firstMode, secondMode = getToggleModePair()
                if not firstMode or not secondMode then
                    return false
                end
                return true
            end,
            enabled = function()
                local firstMode, secondMode = getToggleModePair()
                if not firstMode or not secondMode then
                    return false
                end
                return true
            end,
            callback = function()
                local key = "UI_SHORTCUT_SECONDARY"
                local firstMode, secondMode = getToggleModePair()
                if not firstMode or not secondMode then
                    TraceVendorKeybind(ctx, key, "skipped", {
                        action = "toggle_mode",
                        reason = "missingTogglePair",
                    })
                    return
                end
                local oldMode = vendorInstance:GetCurrentMode()
                local targetMode = oldMode == firstMode and secondMode or firstMode
                ExecuteVendorKeybindAction(ctx, key, "toggle_mode", function()
                    vendorInstance:ToggleBuySellMode()
                end, {
                    result = "toggled",
                    old = oldMode,
                    ["new"] = targetMode,
                    mode = targetMode,
                })
            end,
        },
        BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(
            function()
                local key = "UI_SHORTCUT_QUATERNARY"
                if not (vendorInstance.textSearchHeaderControl and not vendorInstance.textSearchHeaderControl:IsHidden()) then
                    TraceVendorKeybind(ctx, key, "skipped", {
                        action = "clear_search",
                        reason = "searchHidden",
                    })
                    return false, "searchHidden", "clear_search"
                end
                local ok, err = ExecuteVendorKeybindAction(ctx, key, "clear_search", function()
                    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
                    if searchMixin and searchMixin.CallSearchLifecycle then
                        searchMixin.CallSearchLifecycle(vendorInstance, "clear")
                    elseif vendorInstance.ClearSearchInput then
                        vendorInstance:ClearSearchInput()
                    end
                    UpdateCurrentKeybindGroups()
                end, { result = "cleared" })
                if not ok then
                    return false, err, "clear_search"
                end
                return true, nil, "clear_search"
            end,
            function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then return false end
                return vendorInstance.textSearchHeaderControl ~= nil and not vendorInstance.textSearchHeaderControl:IsHidden()
            end,
            function()
                return vendorInstance.searchQuery and vendorInstance.searchQuery ~= ""
            end
        ),
        {
            name = function()
                local defaultActionLabel = GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND") or "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND")
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return defaultActionLabel
                end

                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.REPAIR then
                    local repairAllStringId = rawget(_G, "SI_BETTERUI_VENDOR_REPAIR_ALL")
                    if repairAllStringId then
                        return GetString(repairAllStringId)
                    end
                    return "Repair All"
                end
                if mode == MODE.SELL then
                    return GetString(rawget(_G, "SI_SELL_ALL_JUNK_KEYBIND_TEXT") or "SI_SELL_ALL_JUNK_KEYBIND_TEXT")
                end

                return defaultActionLabel
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return canMultiSelectInCurrentMode() and ms:HasSelections()
                end
                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.SELL then
                    return Vendor.GetSetting("enableBatchJunkSell") ~= false
                end
                if mode == MODE.REPAIR then
                    local repairAllCost = GetRepairAllCost and GetRepairAllCost() or 0
                    return repairAllCost > 0
                end
                return false
            end,
            enabled = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return ms:HasSelections()
                end
                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.SELL then
                    local _, itemCount = Vendor.GetJunkSellSummary()
                    return itemCount > 0
                end
                if mode == MODE.REPAIR then
                    local repairAllCost = GetRepairAllCost and GetRepairAllCost() or 0
                    if repairAllCost <= 0 then
                        return false
                    end
                    if vendorInstance:CanAfford(repairAllCost) then
                        return true
                    end
                    return false, GetString(rawget(_G, "SI_REPAIR_ALL_CANNOT_AFFORD") or "SI_REPAIR_ALL_CANNOT_AFFORD")
                end
                return false
            end,
            callback = function()
                local key = "UI_SHORTCUT_TERTIARY"
                if Vendor._batchProcessing then
                    ExecuteVendorKeybindAction(ctx, key, "batch_abort", function()
                        Vendor.RequestBatchAbort()
                    end, { result = "abort_requested" })
                    return
                end
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    TraceVendorKeybind(ctx, key, "begin", { action = "batch_dialog" })
                    local function showBatchDialog()
                        local registered = registerVendorBatchDialog()
                        if registered == false or not ZO_Dialogs_ShowGamepadDialog then
                            return "dialogUnavailable"
                        end
                        ZO_Dialogs_ShowGamepadDialog("BETTERUI_VENDOR_BATCH_DIALOG")
                        return "dialog_shown"
                    end
                    local ok, result
                    if type(Vendor.ExecuteSafely) == "function" then
                        ok, result = Vendor.ExecuteSafely("Vendor.Keybind:batch_dialog", showBatchDialog)
                    else
                        ok, result = pcall(showBatchDialog)
                    end
                    if not ok then
                        TraceVendorKeybind(ctx, key, "failed", {
                            action = "batch_dialog",
                            reason = "error",
                            error = result,
                        })
                    elseif result == "dialog_shown" then
                        TraceVendorKeybind(ctx, key, "end", {
                            action = "batch_dialog",
                            result = "dialog_shown",
                        })
                    else
                        TraceVendorKeybind(ctx, key, "skipped", {
                            action = "batch_dialog",
                            reason = "dialogUnavailable",
                        })
                    end
                    return
                end
                local component = vendorInstance:GetActiveComponent()
                if not component then
                    TraceVendorKeybind(ctx, key, "skipped", {
                        action = "item_actions",
                        reason = "missingComponent",
                    })
                    return
                end
                local mode = vendorInstance:GetCurrentMode()
                if mode == MODE.SELL and component.SellAllJunk then
                    ExecuteVendorKeybindAction(ctx, key, "sell_all_junk", function()
                        Vendor.ShowSellAllJunkDialog(vendorInstance, component)
                    end, { result = "dialog_shown" })
                    return
                end
                if mode == MODE.REPAIR and component.RepairAll then
                    ExecuteVendorKeybindAction(ctx, key, "repair_all", function()
                        component:RepairAll(vendorInstance)
                    end, { result = "dispatched" })
                    return
                end
                TraceVendorKeybind(ctx, key, "skipped", {
                    action = "item_actions",
                    reason = "unsupportedMode",
                    mode = mode,
                })
            end,
        },
        {
            name = function() return BETTERUI.CIM.Keybinds.GetMultiSelectLabel() end,
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                local ms = Vendor.multiSelectManager
                if ms and ms:IsActive() then
                    return false
                end
                return canMultiSelectInCurrentMode() and isMultiSelectAvailable()
            end,
            callback = function()
                local key = "UI_SHORTCUT_QUINARY"
                local ms = Vendor.multiSelectManager
                if not ms then
                    TraceVendorKeybind(ctx, key, "skipped", {
                        action = "multi_select_enter",
                        reason = "missingMultiSelectManager",
                    })
                    return
                end
                if ms:IsActive() then
                    TraceVendorKeybind(ctx, key, "skipped", {
                        action = "multi_select_enter",
                        reason = "alreadyActive",
                    })
                    return
                end
                ExecuteVendorKeybindAction(ctx, key, "multi_select_enter", function()
                    vendorInstance:SaveListPosition()
                    ms:EnterSelectionMode()
                    local target = getCurrentVendorTargetData(vendorInstance)
                    if target and ms.Select then
                        ms:Select(target)
                    elseif target then
                        ms:ToggleSelection(target)
                    end
                    vendorInstance:RefreshList()
                    vendorInstance:EnsureListInputActive()
                    UpdateCurrentKeybindGroups()
                end, { result = "entered" })
            end,
        },
        {
            name = function()
                if ITEM_PREVIEW_GAMEPAD and ITEM_PREVIEW_GAMEPAD.IsInteractionCameraPreviewEnabled
                    and ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
                    return GetString(rawget(_G, "SI_CRAFTING_EXIT_PREVIEW_MODE") or "SI_CRAFTING_EXIT_PREVIEW_MODE")
                end
                return GetString(rawget(_G, "SI_CRAFTING_ENTER_PREVIEW_MODE") or "SI_CRAFTING_ENTER_PREVIEW_MODE")
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = function()
                local selectedData = getCurrentVendorTargetData(vendorInstance)
                if Vendor.SelectionRuntime and Vendor.SelectionRuntime.CanSelectionPreview then
                    return Vendor.SelectionRuntime.CanSelectionPreview(vendorInstance, selectedData, isStableInteraction())
                end
                return false
            end,
            enabled = function()
                return true
            end,
            callback = function()
                local key = "UI_SHORTCUT_RIGHT_STICK"
                if not (Vendor.SelectionRuntime and Vendor.SelectionRuntime.ToggleSelectionPreview) then
                    TraceVendorKeybind(ctx, key, "skipped", {
                        action = "toggle_preview",
                        reason = "missingSelectionRuntime",
                    })
                    return
                end
                ExecuteVendorKeybindAction(ctx, key, "toggle_preview", function()
                    Vendor.SelectionRuntime.ToggleSelectionPreview(vendorInstance, isStableInteraction())
                end, { result = "toggled" })
            end,
        },
        {
            name = GetString(rawget(_G, "SI_ITEM_ACTION_STACK_ALL") or "SI_ITEM_ACTION_STACK_ALL"),
            keybind = "UI_SHORTCUT_LEFT_STICK",
            visible = function()
                return isFenceInteraction()
            end,
            enabled = function()
                return isFenceInteraction()
            end,
            callback = function()
                ExecuteVendorKeybindAction(ctx, "UI_SHORTCUT_LEFT_STICK", "stack_all", function()
                    StackBag(BAG_BACKPACK)
                end, { result = "stacked" })
            end,
        },
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                local ms = Vendor.multiSelectManager
                local action = ms and ms:IsActive() and "multi_select_exit" or "close_scene"
                ExecuteVendorKeybindAction(ctx, "UI_SHORTCUT_NEGATIVE", action, function()
                    if ms and ms:IsActive() then
                        vendorInstance:SaveListPosition()
                        ms:ExitSelectionMode()
                        vendorInstance:RefreshList()
                        vendorInstance:EnsureListInputActive()
                        UpdateCurrentKeybindGroups()
                        return
                    end
                    SCENE_MANAGER:HideCurrentScene()
                end, {
                    result = action == "multi_select_exit" and "exited" or "closed",
                })
            end,
        },
    })
end

VendorKeybinds._internals = {
    TraceVendorKeybind = TraceVendorKeybind,
    ExecuteVendorKeybindAction = ExecuteVendorKeybindAction,
    WrapVendorKeybindGroup = WrapVendorKeybindGroup,
}
