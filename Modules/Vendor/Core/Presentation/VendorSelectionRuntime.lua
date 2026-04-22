--[[
File: Modules/Vendor/Core/Presentation/VendorSelectionRuntime.lua
Purpose: Shared Vendor selection/preview runtime so selection branches and
         preview toggles stay testable without re-bootstraping the full scene.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.SelectionRuntime = Vendor.SelectionRuntime or {}
local SelectionRuntime = Vendor.SelectionRuntime

local function CleanupEnhancedTooltips()
    if BETTERUI.CIM.SharedItemSupport and BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip then
        BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
        BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
    end
end

local function ResetTooltipPanel(panel)
    GAMEPAD_TOOLTIPS:Reset(panel)
    GAMEPAD_TOOLTIPS:ClearTooltip(panel)
end

local function ResetTooltipMetadata(tooltip, itemLink, bagId, slotIndex, storeStackCount, priceRendered)
    if not tooltip then
        return
    end

    tooltip._betterui_itemLink = itemLink
    tooltip._betterui_bagId = bagId
    tooltip._betterui_slotIndex = slotIndex
    tooltip._betterui_storeStackCount = storeStackCount
    tooltip._betterui_priceRendered = priceRendered
end

local function FinalizeSelectionUpdate(instance, selectedData, isStableInteraction, skipPreviewRefresh)
    if BETTERUI.CIM.SharedItemSupport and BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText then
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)
    end

    local rightTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
    ResetTooltipMetadata(rightTooltip, nil, nil, nil, nil, true)
    if GAMEPAD_TOOLTIPS.ClearStatusLabel then
        GAMEPAD_TOOLTIPS:ClearStatusLabel(GAMEPAD_RIGHT_TOOLTIP)
    end

    if not skipPreviewRefresh then
        if isStableInteraction then
            instance:UpdateStablePreview()
        else
            instance:UpdateVendorStorePreview(selectedData)
        end
    end
    instance:RefreshVendorActionKeybinds()
end

local function HandleEmptySelection(instance, isStableInteraction)
    if isStableInteraction then
        instance:UpdateStablePreview()
    else
        instance:UpdateVendorStorePreview(nil)
    end
    ResetTooltipPanel(GAMEPAD_LEFT_TOOLTIP)
    ResetTooltipPanel(GAMEPAD_RIGHT_TOOLTIP)
    FinalizeSelectionUpdate(instance, nil, isStableInteraction, true)
end

local function HandleStablePreviewSelection(instance, mode, selectedData, isStableInteraction)
    if not isStableInteraction or mode ~= Vendor.MODE.BUY then
        return false
    end
    if not (ITEM_PREVIEW_GAMEPAD and ITEM_PREVIEW_GAMEPAD.IsInteractionCameraPreviewEnabled) then
        return false
    end
    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        return false
    end

    instance:UpdateStablePreview()
    ResetTooltipPanel(GAMEPAD_LEFT_TOOLTIP)
    ResetTooltipPanel(GAMEPAD_RIGHT_TOOLTIP)
    FinalizeSelectionUpdate(instance, selectedData, isStableInteraction, true)
    return true
end

local function LayoutStableTrainingSelection(mode, ds)
    if mode ~= Vendor.MODE.STABLE or not ds.trainingType or not GAMEPAD_TOOLTIPS.LayoutRidingSkill then
        return false
    end

    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:LayoutRidingSkill(
        GAMEPAD_LEFT_TOOLTIP,
        ds.trainingType,
        ds.bonus or 0,
        ds.maxBonus or 0
    )

    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    ResetTooltipMetadata(tooltip, nil, nil, nil, nil, true)
    return true
end

local function LayoutStoreSelection(instance, mode, selectedData, ds, isStableInteraction)
    if (mode ~= Vendor.MODE.BUY and mode ~= Vendor.MODE.BUYBACK) or not GAMEPAD_TOOLTIPS.LayoutStoreWindowItem then
        return false
    end

    if mode == Vendor.MODE.BUY
        and not isStableInteraction
        and ITEM_PREVIEW_GAMEPAD
        and ITEM_PREVIEW_GAMEPAD.IsInteractionCameraPreviewEnabled
        and ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        local targetData = instance.list and instance.list.GetTargetData and instance.list:GetTargetData() or selectedData
        instance:UpdateVendorStorePreview(targetData)
        ResetTooltipPanel(GAMEPAD_LEFT_TOOLTIP)
        ResetTooltipPanel(GAMEPAD_RIGHT_TOOLTIP)
        FinalizeSelectionUpdate(instance, selectedData, isStableInteraction, true)
        return true
    end

    if ds.dataSource == nil then
        ds.dataSource = ds
    end
    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:LayoutStoreWindowItem(GAMEPAD_LEFT_TOOLTIP, ds)
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    ResetTooltipMetadata(
        tooltip,
        ds.itemLink or ((GetStoreItemLink and ds.entryIndex) and GetStoreItemLink(ds.entryIndex)) or nil,
        nil,
        nil,
        ds.stackCount or ds.stack or 1,
        false
    )
    return true
end

local function LayoutBagSelection(ds)
    if not (ds.bagId and ds.slotIndex and GAMEPAD_TOOLTIPS.LayoutBagItem) then
        return false
    end

    GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    ResetTooltipMetadata(tooltip, GetItemLink(ds.bagId, ds.slotIndex), ds.bagId, ds.slotIndex, nil, false)
    return true
end

function SelectionRuntime.CanSelectionPreview(instance, selectedData, isStableInteraction)
    if not (instance and instance.GetCurrentMode and instance:GetCurrentMode() == Vendor.MODE.BUY) then
        return false
    end

    if isStableInteraction then
        return instance.CanPreviewStableStoreEntry and instance:CanPreviewStableStoreEntry(selectedData) or false
    end

    return instance.CanPreviewVendorStoreEntry and instance:CanPreviewVendorStoreEntry(selectedData) or false
end

function SelectionRuntime.ToggleSelectionPreview(instance, isStableInteraction)
    if isStableInteraction then
        if instance.ToggleStablePreviewMode then
            instance:ToggleStablePreviewMode()
        end
    else
        if instance.ToggleVendorStorePreviewMode then
            instance:ToggleVendorStorePreviewMode()
        end
    end

    if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end
end

function SelectionRuntime.HandleSelection(instance, selectedData, isStableInteraction)
    if not GAMEPAD_TOOLTIPS then
        return
    end

    CleanupEnhancedTooltips()

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    if not ds then
        HandleEmptySelection(instance, isStableInteraction)
        return
    end

    local mode = instance:GetCurrentMode()
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)

    if HandleStablePreviewSelection(instance, mode, selectedData, isStableInteraction) then
        return
    end

    if not LayoutStableTrainingSelection(mode, ds)
        and not LayoutStoreSelection(instance, mode, selectedData, ds, isStableInteraction)
        and not LayoutBagSelection(ds) then
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    end

    FinalizeSelectionUpdate(instance, selectedData, isStableInteraction, false)
end
