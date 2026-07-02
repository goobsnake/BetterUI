--[[
File: Modules/CIM/Dialogs/DialogRegistry.lua
Purpose: Centralized dialog registration and management.

Used By: Inventory, Banking dialog initialization
Dependencies: ZO_Dialogs_RegisterCustomDialog

Dialogs registered via this registry:
  - CONFIRM_EQUIP_BOE (Inventory/Module.lua)
  - ZO_GAMEPAD_SPLIT_STACK_DIALOG (Inventory/Inventory.lua)
  - BETTERUI_CONFIRM_DESTROY_DIALOG (Inventory/Inventory.lua)
  - ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG (Inventory/Inventory.lua)
  - BETTERUI.Inventory.Dialogs.EQUIP_SLOT (Inventory/Actions/EquipAction.lua)

  - ZO_GAMEPAD_INVENTORY_ACTION_DIALOG (Inventory/Actions/ActionDialogHooks.lua)
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Dialogs then BETTERUI.CIM.Dialogs = {} end

-- DIALOG REGISTRY

--[[
Table: BETTERUI.CIM.Dialogs.Registry
Description: Tracks all registered dialogs for cleanup and management.
Rationale: Provides a single point of truth for dialog registration,
           preventing duplicate registration and enabling cleanup.
]]
BETTERUI.CIM.Dialogs.Registry = {
    _dialogs = {},
    _previousDialogs = {},
}

local function TraceDialog(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    L.TraceEvent(L.CATEGORY.ACTION, event, phase, data)
end

local function GetCurrentDialogInfo(dialogName)
    if type(ESO_Dialogs) == "table" then
        return ESO_Dialogs[dialogName]
    end
    return nil
end

---@param dialog table|nil
---@param value number|nil
---@return boolean
function BETTERUI.CIM.Dialogs.ShouldTraceSliderPreview(dialog, value)
    if not (dialog and dialog.data and value) then
        return false
    end

    local sliderMin = dialog.data.sliderMin or 1
    local sliderMax = dialog.data.sliderMax or sliderMin
    local span = math.max(sliderMax - sliderMin, 1)
    local bucketSize = math.max(1, math.floor(span / 10))
    local bucket = math.floor((value - sliderMin) / bucketSize)
    local key = table.concat({
        tostring(bucket),
        tostring(value == sliderMin),
        tostring(value == sliderMax),
    }, ":")

    if dialog._betteruiLastSliderTraceKey == key then
        return false
    end

    dialog._betteruiLastSliderTraceKey = key
    dialog._betteruiLastSliderTraceBucket = bucket
    return true
end

local function WarnDialogOwnershipLost(dialogName, expectedInfo, observedInfo)
    if not (BETTERUI.Log and BETTERUI.Log.Warn) then
        return
    end
    BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.GENERAL, "dialog ownership changed after BetterUI registration", {
        fn = "BETTERUI.CIM.Dialogs.Register",
        dialog = dialogName,
        hadExpectedOwner = expectedInfo ~= nil and expectedInfo == observedInfo,
        expectedOwnerType = type(expectedInfo),
        observedOwnerType = type(observedInfo),
    })
end

---@param dialogName string
---@param dialogInfo table
---@return boolean
function BETTERUI.CIM.Dialogs.IsCurrentOwner(dialogName, dialogInfo)
    local currentInfo = GetCurrentDialogInfo(dialogName)
    if currentInfo == nil then
        return false
    end
    return currentInfo == dialogInfo
end

---@param dialogName string
---@return table|nil
function BETTERUI.CIM.Dialogs.GetPreviousInfo(dialogName)
    return BETTERUI.CIM.Dialogs.Registry._previousDialogs[dialogName]
end

---@param dialogName string
---@return table|nil
function BETTERUI.CIM.Dialogs.GetCurrentInfo(dialogName)
    return GetCurrentDialogInfo(dialogName)
end

---@param dialogName string
---@return boolean
function BETTERUI.CIM.Dialogs.Restore(dialogName)
    local record = BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName]
    if not record then
        return false
    end
    if not BETTERUI.CIM.Dialogs.IsCurrentOwner(dialogName, record.info) then
        WarnDialogOwnershipLost(dialogName, record.info, GetCurrentDialogInfo(dialogName))
        return false
    end
    if not record.previousInfo then
        if type(ESO_Dialogs) == "table" then
            ESO_Dialogs[dialogName] = nil
        end
        BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] = nil
        BETTERUI.CIM.Dialogs.Registry._previousDialogs[dialogName] = nil
        TraceDialog("dialog.restore", "removed", { dialog = dialogName })
        return true
    end

    if ZO_Dialogs_RegisterCustomDialog then
        ZO_Dialogs_RegisterCustomDialog(dialogName, record.previousInfo)
    elseif type(ESO_Dialogs) == "table" then
        ESO_Dialogs[dialogName] = record.previousInfo
    else
        return false
    end

    BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] = nil
    BETTERUI.CIM.Dialogs.Registry._previousDialogs[dialogName] = nil
    TraceDialog("dialog.restore", "restored", { dialog = dialogName })
    return true
end

---@param dialogName string
---@param dialogInfo table
---@param options {overwrite: boolean?}?
---@return boolean
function BETTERUI.CIM.Dialogs.Register(dialogName, dialogInfo, options)
    options = options or {}

    -- Check for duplicate registration
    local priorOwnedInfo = BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName]
    local observedBefore = GetCurrentDialogInfo(dialogName)
    if priorOwnedInfo and observedBefore ~= priorOwnedInfo.info then
        WarnDialogOwnershipLost(dialogName, priorOwnedInfo.info, observedBefore)
    end
    if BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] and not options.overwrite then
        if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.GENERAL, string.format("[Dialog] '%s' already registered, skipping", dialogName)) end
        return false
    end

    local previousInfo = observedBefore
    local replacingExisting = previousInfo ~= nil and previousInfo ~= dialogInfo
    if replacingExisting then
        BETTERUI.CIM.Dialogs.Registry._previousDialogs[dialogName] = previousInfo
        TraceDialog("dialog.register", "replacing_existing", {
            dialog = dialogName,
            overwrite = options.overwrite == true,
            previousTracked = BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] ~= nil,
        })
    end

    local registered = BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName]
    if registered and registered.info and previousInfo ~= registered.info and previousInfo ~= nil then
        local L = BETTERUI.Log
        if L and L.Warn then
            L.Warn(L.CATEGORY.DIALOG or L.CATEGORY.GENERAL, "dialog ownership changed before re-register", {
                dialog = dialogName,
                ownerLost = true,
            })
        end
    end

    -- Register with ZO_Dialogs
    if ZO_Dialogs_RegisterCustomDialog then
        ZO_Dialogs_RegisterCustomDialog(dialogName, dialogInfo)
    elseif type(ESO_Dialogs) == "table" then
        ESO_Dialogs[dialogName] = dialogInfo
    end

    -- Track in registry
    BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] = {
        name = dialogName,
        info = dialogInfo,
        previousInfo = previousInfo,
        replacedExisting = replacingExisting,
        registeredAt = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0,
    }

    return true
end

---@param dialogName string
---@return boolean
function BETTERUI.CIM.Dialogs.IsRegistered(dialogName)
    return BETTERUI.CIM.Dialogs.Registry._dialogs[dialogName] ~= nil
end

---@param dialogName string
---@param data table?
---@return nil
function BETTERUI.CIM.Dialogs.Show(dialogName, data)
    if not BETTERUI.CIM.Dialogs.IsRegistered(dialogName) then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.GENERAL, string.format("[Dialog] '%s' not registered", dialogName)) end
        TraceDialog("dialog.show", "rejected", { dialog = dialogName, reason = "notRegistered", hasData = data ~= nil })
        return
    end

    local method = ZO_Dialogs_ShowGamepadDialog and "gamepad" or (ZO_Dialogs_ShowDialog and "standard" or "missing")
    TraceDialog("dialog.show", "before", { dialog = dialogName, method = method, hasData = data ~= nil })
    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(dialogName, data)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(dialogName, data)
    end
    TraceDialog("dialog.show", "after", { dialog = dialogName, method = method, shown = method ~= "missing" })
end

---@param label string
---@param actionId string
---@return table
function BETTERUI.CIM.Dialogs.CreateParametricActionEntry(label, actionId)
    local entryData = ZO_GamepadEntryData:New(label)
    entryData:SetIconTintOnSelection(true)
    entryData.actionId = actionId
    entryData.setup = ZO_SharedGamepadEntry_OnSetup
    return {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = entryData,
    }
end

---@return string[]
function BETTERUI.CIM.Dialogs.GetAll()
    local names = {}
    for name, _ in pairs(BETTERUI.CIM.Dialogs.Registry._dialogs) do
        table.insert(names, name)
    end
    return names
end
