--[[
File: tools/tests/test_vendor_buy_preview.lua
Purpose: Regression coverage for vendor buy preview support.
]]

local validateCalls = {}
local executeCalls = {}
local blurStates = {}
local vendorUiHiddenStates = {}
local leftTooltipHiddenStates = {}
local rightTooltipHiddenStates = {}

ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE = 1
ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE = 2

local previewEnabled = false
ITEM_PREVIEW_GAMEPAD = {
    IsInteractionCameraPreviewEnabled = function()
        return previewEnabled
    end,
    ToggleInteractionCameraPreview = function()
        previewEnabled = not previewEnabled
    end,
    SetInteractionCameraPreviewEnabled = function(_, enabled)
        previewEnabled = enabled
    end,
}

function IsCharacterPreviewingAvailable()
    return true
end

GAMEPAD_LEFT_TOOLTIP = 1
GAMEPAD_RIGHT_TOOLTIP = 2
GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT = { name = "quadrant1" }

GAMEPAD_TOOLTIPS = {
    Reset = function() end,
    ClearTooltip = function() end,
    GetTooltip = function(_, tooltipType)
        if tooltipType == GAMEPAD_LEFT_TOOLTIP then
            return {
                SetHidden = function(_, hidden)
                    leftTooltipHiddenStates[#leftTooltipHiddenStates + 1] = hidden
                end,
            }
        end
        return {
            SetHidden = function(_, hidden)
                rightTooltipHiddenStates[#rightTooltipHiddenStates + 1] = hidden
            end,
        }
    end,
}

function ZO_StoreManager_DoPreviewAction(action, storeEntryIndex)
    if action == ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE then
        validateCalls[#validateCalls + 1] = storeEntryIndex
        return storeEntryIndex == 7
    end

    executeCalls[#executeCalls + 1] = storeEntryIndex
    return true
end

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function getFocusedVendorData(vendorInstance)
    local list = vendorInstance and vendorInstance.list
    if not list then
        return nil
    end

    if list.GetTargetData then
        return list:GetTargetData()
    end

    return list.selectedData
end

local function isPreviewVisible(vendorInstance)
    if vendorInstance:GetCurrentMode() ~= 1 then
        return false
    end
    if ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        return true
    end
    return vendorInstance:CanPreviewVendorStoreEntry(getFocusedVendorData(vendorInstance))
end

local VendorClass = {}
VendorClass.__index = VendorClass

function VendorClass:New()
    return setmetatable({
        currentMode = 1,
        _vendorStorePreviewUiHidden = false,
        scene = {
            RemoveFragment = function() end,
            AddFragment = function() end,
        },
        control = {
            SetHidden = function(_, hidden)
                vendorUiHiddenStates[#vendorUiHiddenStates + 1] = hidden
            end,
        },
        list = {
            selectedData = { dataSource = { entryIndex = 7 } },
            targetData = { dataSource = { entryIndex = 7 } },
            GetTargetData = function(self)
                return self.targetData
            end,
            GetSelectedData = function(self)
                return self.selectedData
            end,
        },
    }, self)
end

function VendorClass:GetCurrentMode()
    return self.currentMode
end

function VendorClass:SetVendorPreviewBlurActive(shouldActivateVendorBlur)
    blurStates[#blurStates + 1] = shouldActivateVendorBlur
end

function VendorClass:SetVendorStorePreviewUiHidden(hidden)
    if self._vendorStorePreviewUiHidden == hidden then
        return
    end

    self._vendorStorePreviewUiHidden = hidden

    if self.control and self.control.SetHidden then
        self.control:SetHidden(hidden)
    end

    if self.scene and GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT then
        if hidden then
            self.scene:RemoveFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
        else
            self.scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
        end
    end

    if GAMEPAD_TOOLTIPS then
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)

        local leftTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        local rightTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
        if leftTooltip and leftTooltip.SetHidden then
            leftTooltip:SetHidden(hidden)
        end
        if rightTooltip and rightTooltip.SetHidden then
            rightTooltip:SetHidden(hidden)
        end
    end
end

function VendorClass:CanPreviewVendorStoreEntry(selectedData)
    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    local storeEntryIndex = ds and (ds.slotIndex or ds.entryIndex) or nil
    if not storeEntryIndex then
        return false
    end

    return ZO_StoreManager_DoPreviewAction(ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE, storeEntryIndex) == true
end

function VendorClass:DisableVendorStorePreviewMode()
    self:SetVendorPreviewBlurActive(false)
    self:SetVendorStorePreviewUiHidden(false)
    if ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(false)
    end
end

function VendorClass:UpdateVendorStorePreview(selectedData)
    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        self:SetVendorPreviewBlurActive(false)
        self:SetVendorStorePreviewUiHidden(false)
        return
    end

    if self:CanPreviewVendorStoreEntry(selectedData) then
        local ds = selectedData and (selectedData.dataSource or selectedData) or nil
        local storeEntryIndex = ds and (ds.slotIndex or ds.entryIndex) or nil
        ZO_StoreManager_DoPreviewAction(ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE, storeEntryIndex)
        self:SetVendorPreviewBlurActive(true)
        self:SetVendorStorePreviewUiHidden(true)
    else
        self:DisableVendorStorePreviewMode()
    end
end

function VendorClass:ToggleVendorStorePreviewMode()
    local willPreviewBeDisabled = ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
    self:SetVendorPreviewBlurActive(willPreviewBeDisabled)
    ITEM_PREVIEW_GAMEPAD:ToggleInteractionCameraPreview()
    self:UpdateVendorStorePreview(self.list:GetTargetData())
end

local vendor = VendorClass:New()

do
    assertEq(vendor:CanPreviewVendorStoreEntry(vendor.list:GetTargetData()), true, "preview validate succeeds for previewable buy entries")
    assertEq(validateCalls[#validateCalls], 7, "preview validation uses the focused store entry index")
    assertEq(isPreviewVisible(vendor), true, "preview keybind is visible for previewable focused rows")
end

do
    vendor:ToggleVendorStorePreviewMode()
    assertEq(previewEnabled, true, "preview mode toggles on for vendor buy entries")
    assertEq(executeCalls[#executeCalls], 7, "preview execute runs for the focused store entry")
    assertEq(blurStates[#blurStates], true, "preview execution enables vendor blur")
    assertEq(vendorUiHiddenStates[#vendorUiHiddenStates], true, "preview execution hides the vendor UI like stable preview")
    assertEq(leftTooltipHiddenStates[#leftTooltipHiddenStates], true, "preview execution hides the left tooltip")
    assertEq(rightTooltipHiddenStates[#rightTooltipHiddenStates], true, "preview execution hides the right tooltip")
end

do
    vendor.list.targetData = { dataSource = { entryIndex = 9 } }
    vendor:UpdateVendorStorePreview(vendor.list:GetTargetData())
    assertEq(previewEnabled, false, "preview mode is disabled when the focused row cannot be previewed")
    assertEq(blurStates[#blurStates], false, "non-previewable rows clear the vendor blur")
    assertEq(vendorUiHiddenStates[#vendorUiHiddenStates], false, "disabling preview restores the vendor UI")
end

do
    previewEnabled = false
    vendor.list.selectedData = { dataSource = { entryIndex = 7 } }
    vendor.list.targetData = { dataSource = { entryIndex = 9 } }
    assertEq(isPreviewVisible(vendor), false, "preview keybind hides when only a stale selected row is previewable")
    assertEq(validateCalls[#validateCalls], 9, "preview validation follows the currently focused target row")
end

do
    previewEnabled = false
    vendor.list.selectedData = { dataSource = { entryIndex = 7 } }
    vendor.list.targetData = nil
    assertEq(isPreviewVisible(vendor), false, "preview keybind hides when no live target exists even if the stale selected row is previewable")
end

print("test_vendor_buy_preview.lua: PASS")