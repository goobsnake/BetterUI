--[[
File: Modules/Vendor/Components/RepairComponent.lua
Purpose: Repair tab component for the Vendor module.
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
Vendor.RepairComponent = Vendor.RepairComponent or {}
local Repair = Vendor.RepairComponent

--- Resolve the focused row the same way the Vendor keybind strip does
--- (GetTargetData when available, falling back to GetSelectedData).
---@param vendorInstance BETTERUI.Vendor.Class|nil
---@return table|nil rowData
local function GetTargetRowData(vendorInstance)
    local list = vendorInstance and vendorInstance.list
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    return list:GetSelectedData()
end

local function TraceRepair(event, phase, data)
    local L = BETTERUI and BETTERUI.Log or nil
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Vendor"
    data.scene = rawget(_G, "BETTERUI_VENDOR_SCENE_NAME") or "BETTERUI_VENDOR"
    data.feature = data.feature or "vendor-repair"
    data.fn = data.fn or "Vendor.RepairComponent"
    L.TraceEvent(L.CATEGORY.ACTION, event, phase, data)
end

Repair.pendingRepairAllTrace = nil
local repairAllDialogHooksInstalled = false
local repairAllPreHookPending = nil

local function TakePendingRepairAllTrace(phase, reason)
    local pending = Repair.pendingRepairAllTrace
    if not pending then return nil end
    if reason ~= nil then
        pending.reason = reason
    end
    TraceRepair("vendor.repair_all_dialog", phase, pending)
    Repair.pendingRepairAllTrace = nil
    return pending
end

local function EnsureRepairAllDialogHooks()
    if repairAllDialogHooksInstalled then return end
    repairAllDialogHooksInstalled = true

    if type(RepairAll) == "function" and type(ZO_PreHook) == "function" then
        ZO_PreHook(_G, "RepairAll", function(...)
            local pending = TakePendingRepairAllTrace("confirm", nil)
            if pending then
                repairAllPreHookPending = pending
            end
        end)
    end
    if type(RepairAll) == "function" and type(ZO_PostHook) == "function" then
        ZO_PostHook(_G, "RepairAll", function(...)
            local pending = repairAllPreHookPending
            repairAllPreHookPending = nil
            if pending then
                TraceRepair("vendor.repair_all", "dispatched", {
                    fn = "Vendor.RepairComponent.RepairAll",
                    cost = pending.cost,
                    dialogName = pending.dialogName,
                })
            end
        end)
    end

    if type(ZO_Dialogs_ReleaseDialog) == "function" and type(ZO_PostHook) == "function" then
        ZO_PostHook(_G, "ZO_Dialogs_ReleaseDialog", function(dialogName, ...)
            if dialogName == "REPAIR_ALL" then
                TakePendingRepairAllTrace("cancel", "dialogReleased")
            end
        end)
    end
    if type(ZO_Dialogs_ReleaseDialogOnButtonPress) == "function" and type(ZO_PostHook) == "function" then
        ZO_PostHook(_G, "ZO_Dialogs_ReleaseDialogOnButtonPress", function(dialogName, ...)
            if dialogName == "REPAIR_ALL" then
                TakePendingRepairAllTrace("cancel", "buttonPressRelease")
            end
        end)
    end
end

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function Repair:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Repair:Deactivate(vendorInstance)
    TakePendingRepairAllTrace("cancel", "componentDeactivated")
end

-- PRIMARY ACTION

---@return string name Localized repair action label
function Repair:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_REPAIR"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if repair is affordable and needed
function Repair:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = GetTargetRowData(vendorInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    local repairCost = ds.repairCost or 0
    return repairCost > 0 and vendorInstance:CanAfford(repairCost)
end

---@param vendorInstance BETTERUI.Vendor.Class
function Repair:OnPrimaryAction(vendorInstance)
    local selectedData = GetTargetRowData(vendorInstance)
    if not selectedData then
        TraceRepair("vendor.repair", "blocked", {
            fn = "Vendor.RepairComponent.OnPrimaryAction",
            reason = "missingSelection",
        })
        return
    end
    local ds = selectedData.dataSource or selectedData

    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    if bagId == nil or slotIndex == nil then
        TraceRepair("vendor.repair", "blocked", {
            fn = "Vendor.RepairComponent.OnPrimaryAction",
            reason = "missingSlot",
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        })
        return
    end

    local repairCost = ds.repairCost or 0
    if repairCost <= 0 then
        TraceRepair("vendor.repair", "blocked", {
            fn = "Vendor.RepairComponent.OnPrimaryAction",
            reason = "zeroCost",
            bagId = bagId,
            slotIndex = slotIndex,
            cost = repairCost,
        })
        return
    end

    if not vendorInstance:CanAfford(repairCost) then
        TraceRepair("vendor.repair", "blocked", {
            fn = "Vendor.RepairComponent.OnPrimaryAction",
            reason = "cannotAfford",
            bagId = bagId,
            slotIndex = slotIndex,
            cost = repairCost,
        })
        BETTERUI.CIM.UserAlertText("Repair:CannotAfford",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    local L = BETTERUI.Log
    if L and L.TraceEvent then
        L.TraceEvent(L.CATEGORY.ACTION, "vendor.repair", "request", {
            module = "Vendor",
            scene = BETTERUI_VENDOR_SCENE_NAME,
            feature = "vendor-repair",
            fn = "Vendor.RepairComponent.OnPrimaryAction",
            ["function"] = "Vendor.RepairComponent.OnPrimaryAction",
            mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
            bagId = bagId,
            slotIndex = slotIndex,
            cost = repairCost,
            item = L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name,
        })
    end

    RepairItem(bagId, slotIndex)

    if L and L.TraceEvent then
        L.TraceEvent(L.CATEGORY.ACTION, "vendor.repair", "requested", {
            module = "Vendor",
            scene = BETTERUI_VENDOR_SCENE_NAME,
            feature = "vendor-repair",
            fn = "Vendor.RepairComponent.OnPrimaryAction",
            ["function"] = "Vendor.RepairComponent.OnPrimaryAction",
            mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
            bagId = bagId,
            slotIndex = slotIndex,
            cost = repairCost,
            item = L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name,
        })
    end
end

-- REPAIR ALL

---@param vendorInstance BETTERUI.Vendor.Class
function Repair:RepairAll(vendorInstance)
    local repairAllCost = GetRepairAllCost and GetRepairAllCost() or 0
    if repairAllCost <= 0 then
        TraceRepair("vendor.repair_all", "skipped", {
            fn = "Vendor.RepairComponent.RepairAll",
            reason = "zeroCost",
            cost = repairAllCost,
        })
        return
    end

    if not vendorInstance:CanAfford(repairAllCost) then
        TraceRepair("vendor.repair_all", "blocked", {
            fn = "Vendor.RepairComponent.RepairAll",
            reason = "cannotAfford",
            cost = repairAllCost,
        })
        BETTERUI.CIM.UserAlertText("Repair:CannotAffordAll",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
        return
    end

    TraceRepair("vendor.repair_all", "request", {
        fn = "Vendor.RepairComponent.RepairAll",
        cost = repairAllCost,
        dialogName = "REPAIR_ALL",
        hasDialogApi = type(ZO_Dialogs_ShowGamepadDialog) == "function",
    })

    -- ESO's own store uses "REPAIR_ALL" dialog (storewindow_gamepad.lua:309)
    TraceRepair("vendor.repair_all_dialog", "show", {
        fn = "Vendor.RepairComponent.RepairAll",
        cost = repairAllCost,
        dialogName = "REPAIR_ALL",
    })
    EnsureRepairAllDialogHooks()
    Repair.pendingRepairAllTrace = {
        fn = "Vendor.RepairComponent.RepairAll",
        cost = repairAllCost,
        dialogName = "REPAIR_ALL",
    }
    ZO_Dialogs_ShowGamepadDialog("REPAIR_ALL", {
        cost = repairAllCost,
        callback = function()
            RepairAll()
        end,
        declineCallback = function()
            TakePendingRepairAllTrace("cancel", "declineCallback")
        end,
    })
    TraceRepair("vendor.repair_all_dialog", "awaiting_choice", {
        fn = "Vendor.RepairComponent.RepairAll",
        cost = repairAllCost,
        dialogName = "REPAIR_ALL",
    })
end

-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function Repair:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil

    -- Scan equipped and backpack items for damage
    local bags = { BAG_WORN, BAG_BACKPACK }

    for _, bagId in ipairs(bags) do
        local bagSize = GetBagSize(bagId) or 0
        for slotIndex = 0, bagSize - 1 do
            local condition = GetItemCondition(bagId, slotIndex) or 100
            if condition < 100 then
                -- 9th GetItemInfo return is displayQuality (8th is functionalQuality)
                local icon, stackCount, _, _, _, _, _, _, displayQuality = GetItemInfo(bagId, slotIndex)
                local name = GetItemName(bagId, slotIndex)

                if name and name ~= ""
                    and (not Vendor.MatchesSearchQuery or Vendor.MatchesSearchQuery(searchQuery, name))
                then
                    name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                    local repairCost = GetItemRepairCost(bagId, slotIndex) or 0

                    local entryData = {
                        name             = name,
                        icon             = icon,
                        stackCount       = stackCount or 1,
                        condition        = condition,
                        repairCost       = repairCost,
                        quality          = displayQuality or ITEM_DISPLAY_QUALITY_NORMAL,
                        bagId            = bagId,
                        slotIndex        = slotIndex,
                        itemLink         = GetItemLink(bagId, slotIndex),
                        bestGamepadItemCategoryName = "",
                        statValue        = zo_strformat(
                            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CONDITION") or "SI_BETTERUI_VENDOR_CONDITION"),
                            condition
                        ),
                    }

                    local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
                    entry:SetDataSource(entryData)
                    entry.narrationText = function() return entryData.name end

                    if entryData.quality then
                        local r, g, b = GetItemQualityColor(entryData.quality):UnpackRGBA()
                        entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                    end

                    list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
                end
            end
        end
    end
end
