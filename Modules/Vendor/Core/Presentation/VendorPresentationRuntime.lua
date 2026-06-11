--[[
File: Modules/Vendor/Core/Presentation/VendorPresentationRuntime.lua
Purpose: Own vendor preview/footer presentation flows so VendorClass stays coordinator-focused.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.PresentationRuntime = Vendor.PresentationRuntime or {}
local PresentationRuntime = Vendor.PresentationRuntime

local MODE = assert(Vendor.MODE, "Vendor mode constants must load before presentation runtime")

--- Buy-pane footer balance text. When the store trades in a non-gold currency
--- (e.g. Tel Var, writ vouchers), show that currency's balance at its correct
--- player-stored location (icon + amount); otherwise fall back to carried gold.
--- Drives the previously-dead Class:GetStoreCurrencyTypes helper.
---@param instance BETTERUI.Vendor.Class
---@return string text
local function ResolveBuyPaneCurrencyText(instance)
    local storeCurrencyType
    if instance and instance.GetStoreCurrencyTypes then
        -- GetStoreUsedCurrencyTypes() can return several types; pick the first
        -- non-gold one as the headline store currency.
        local types = { instance:GetStoreCurrencyTypes() }
        for _, currencyType in ipairs(types) do
            if currencyType and currencyType ~= CURT_MONEY and currencyType ~= CURT_NONE then
                storeCurrencyType = currencyType
                break
            end
        end
    end

    if storeCurrencyType and type(ZO_Currency_FormatGamepad) == "function" then
        local location = (GetCurrencyPlayerStoredLocation and GetCurrencyPlayerStoredLocation(storeCurrencyType))
            or CURRENCY_LOCATION_CHARACTER
        local amount = GetCurrencyAmount(storeCurrencyType, location) or 0
        return ZO_Currency_FormatGamepad(storeCurrencyType, amount, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
    end

    local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    return "|t24:24:esoui/art/currency/currency_gold_32.dds|t " .. BETTERUI.DisplayNumber(gold)
end

local function GetPreviewSceneFragments()
    return FRAME_TARGET_STORE_GAMEPAD_FRAGMENT,
        FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
        GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT
end

---@param instance BETTERUI.Vendor.Class
---@param selectedData table|nil
---@return boolean
function PresentationRuntime.CanPreviewStableStoreEntry(instance, selectedData)
    if not (ITEM_PREVIEW_GAMEPAD and ZO_StoreManager_DoPreviewAction and IsCharacterPreviewingAvailable) then
        return false
    end
    if not IsCharacterPreviewingAvailable() then
        return false
    end

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    local storeEntryIndex = ds and (ds.slotIndex or ds.entryIndex) or nil
    if not storeEntryIndex then
        return false
    end

    local validateAction = rawget(_G, "ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE")
    if validateAction == nil then
        return false
    end
    return ZO_StoreManager_DoPreviewAction(validateAction, storeEntryIndex) == true
end

---@param shouldActivateVendorBlur boolean
---@return nil
function PresentationRuntime.SetVendorPreviewBlurActive(_, shouldActivateVendorBlur)
    if not FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT then
        return
    end

    if shouldActivateVendorBlur then
        SCENE_MANAGER:AddFragment(FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT)
    else
        SCENE_MANAGER:RemoveFragmentImmediately(FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT)
    end
end

---@param instance BETTERUI.Vendor.Class
---@param hidden boolean
---@return nil
function PresentationRuntime.SetVendorStorePreviewUiHidden(instance, hidden)
    if instance.SetStablePreviewUiHidden then
        instance:SetStablePreviewUiHidden(hidden)
    end
end

---@param instance BETTERUI.Vendor.Class
---@param selectedData table|nil
---@param isStableInteractionActive fun(): boolean
---@return boolean
function PresentationRuntime.CanPreviewVendorStoreEntry(instance, selectedData, isStableInteractionActive)
    if isStableInteractionActive() or instance:GetCurrentMode() ~= MODE.BUY then
        return false
    end
    if not (ITEM_PREVIEW_GAMEPAD and ZO_StoreManager_DoPreviewAction and IsCharacterPreviewingAvailable) then
        return false
    end
    if not IsCharacterPreviewingAvailable() then
        return false
    end

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    local storeEntryIndex = ds and (ds.slotIndex or ds.entryIndex) or nil
    local validateAction = rawget(_G, "ZO_STORE_MANAGER_PREVIEW_ACTION_VALIDATE")
    if not storeEntryIndex or validateAction == nil then
        return false
    end

    return ZO_StoreManager_DoPreviewAction(validateAction, storeEntryIndex) == true
end

---@param instance BETTERUI.Vendor.Class
---@return nil
function PresentationRuntime.DisableVendorStorePreviewMode(instance)
    instance:SetVendorPreviewBlurActive(false)
    instance:SetVendorStorePreviewUiHidden(false)

    if not ITEM_PREVIEW_GAMEPAD or not ITEM_PREVIEW_GAMEPAD.IsInteractionCameraPreviewEnabled then
        return
    end
    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        return
    end

    local a, b, c = GetPreviewSceneFragments()
    ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(false, a, b, c)
end

---@param instance BETTERUI.Vendor.Class
---@param selectedData table|nil
---@param isStableInteractionActive fun(): boolean
---@return nil
function PresentationRuntime.UpdateVendorStorePreview(instance, selectedData, isStableInteractionActive)
    if isStableInteractionActive() then
        return
    end
    if not (ITEM_PREVIEW_GAMEPAD and ZO_StoreManager_DoPreviewAction) then
        return
    end
    if instance:GetCurrentMode() ~= MODE.BUY then
        instance:DisableVendorStorePreviewMode()
        return
    end
    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        instance:SetVendorPreviewBlurActive(false)
        instance:SetVendorStorePreviewUiHidden(false)
        return
    end

    if instance:CanPreviewVendorStoreEntry(selectedData) then
        local ds = selectedData and (selectedData.dataSource or selectedData) or nil
        local storeEntryIndex = ds and (ds.slotIndex or ds.entryIndex) or nil
        local executeAction = rawget(_G, "ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE")
        if storeEntryIndex and executeAction ~= nil then
            ZO_StoreManager_DoPreviewAction(executeAction, storeEntryIndex)
        end
        instance:SetVendorPreviewBlurActive(true)
        instance:SetVendorStorePreviewUiHidden(true)
    else
        instance:DisableVendorStorePreviewMode()
    end
end

---@param instance BETTERUI.Vendor.Class
---@param isStableInteractionActive fun(): boolean
---@return nil
function PresentationRuntime.ToggleVendorStorePreviewMode(instance, isStableInteractionActive)
    if isStableInteractionActive() or instance:GetCurrentMode() ~= MODE.BUY then
        return
    end
    if not ITEM_PREVIEW_GAMEPAD then
        return
    end

    local willPreviewBeDisabled = ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
    instance:SetVendorPreviewBlurActive(willPreviewBeDisabled)

    local a, b, c = GetPreviewSceneFragments()
    ITEM_PREVIEW_GAMEPAD:ToggleInteractionCameraPreview(a, b, c)

    local targetData = instance.list and instance.list.GetTargetData and instance.list:GetTargetData() or nil
    instance:UpdateVendorStorePreview(targetData)
end

---@param instance BETTERUI.Vendor.Class
---@param hidden boolean
---@return nil
function PresentationRuntime.SetStablePreviewUiHidden(instance, hidden)
    if instance._stablePreviewUiHidden == hidden then
        return
    end
    instance._stablePreviewUiHidden = hidden

    if instance.control and instance.control.SetHidden then
        instance.control:SetHidden(hidden)
    end

    local scene = instance.scene
        or (SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME))
    if scene and GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT then
        if hidden then
            scene:RemoveFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
        else
            scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
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

---@param instance BETTERUI.Vendor.Class
---@return nil
function PresentationRuntime.DisableStablePreviewMode(instance)
    instance:SetStablePreviewUiHidden(false)

    if not ITEM_PREVIEW_GAMEPAD then
        return
    end
    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        return
    end

    local a, b, c = GetPreviewSceneFragments()
    ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(false, a, b, c)
end

---@param instance BETTERUI.Vendor.Class
---@param isStableInteractionActive fun(): boolean
---@return nil
function PresentationRuntime.ToggleStablePreviewMode(instance, isStableInteractionActive)
    if not ITEM_PREVIEW_GAMEPAD then
        return
    end
    if not isStableInteractionActive() or instance:GetCurrentMode() ~= MODE.BUY then
        return
    end

    local a, b, c = GetPreviewSceneFragments()
    ITEM_PREVIEW_GAMEPAD:ToggleInteractionCameraPreview(a, b, c)

    local isPreviewActive = ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
    instance:SetStablePreviewUiHidden(isPreviewActive)
    instance:UpdateStablePreview()
end

---@param instance BETTERUI.Vendor.Class
---@param isStableInteractionActive fun(): boolean
---@return nil
function PresentationRuntime.UpdateStablePreview(instance, isStableInteractionActive)
    if not (ITEM_PREVIEW_GAMEPAD and ZO_StoreManager_DoPreviewAction) then
        return
    end
    if not isStableInteractionActive() or instance:GetCurrentMode() ~= MODE.BUY then
        instance:DisableStablePreviewMode()
        return
    end

    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        instance:SetStablePreviewUiHidden(false)
        return
    end

    local selectedData = instance.list and instance.list:GetTargetData() or nil
    if instance:CanPreviewStableStoreEntry(selectedData) then
        local ds = selectedData and (selectedData.dataSource or selectedData) or nil
        local storeEntryIndex = ds and (ds.slotIndex or ds.entryIndex) or nil
        local executeAction = rawget(_G, "ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE")
        if storeEntryIndex and executeAction ~= nil then
            ZO_StoreManager_DoPreviewAction(executeAction, storeEntryIndex)
        end
        instance:SetStablePreviewUiHidden(true)
    else
        instance:DisableStablePreviewMode()
    end
end

---@param instance BETTERUI.Vendor.Class
---@param isStableInteractionActive fun(): boolean
---@return nil
function PresentationRuntime.InitVendorFooter(instance, isStableInteractionActive)
    local footerRoot = instance.footer and instance.footer:GetNamedChild("Footer")
    if not footerRoot then
        return
    end

    local dividerCentre = footerRoot:GetNamedChild("DividerCentre")
    if dividerCentre then
        dividerCentre:SetHidden(false)
    end

    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", function()
                if Vendor.IsFenceInteraction and Vendor.IsFenceInteraction() then
                    instance:SetMode(MODE.FENCE_SELL)
                    return
                end
                instance:SetMode(MODE.BUY)
            end)

            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY") or "SI_BETTERUI_VENDOR_TAB_BUY"))
            end
        end
        local icon = withdraw:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/currency/currency_gold_64.dds")
        end
    end

    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", function()
                if Vendor.IsFenceInteraction and Vendor.IsFenceInteraction() then
                    instance:SetMode(MODE.FENCE_LAUNDER)
                    return
                end
                if isStableInteractionActive() then
                    instance:SetMode(MODE.STABLE)
                else
                    instance:SetMode(MODE.SELL)
                end
            end)

            local label = btn:GetNamedChild("Label")
            if label then
                if isStableInteractionActive() then
                    label:SetText(GetString(rawget(_G, "SI_STABLE_STABLES_TAB") or "SI_STABLE_STABLES_TAB"))
                else
                    label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL") or "SI_BETTERUI_VENDOR_TAB_SELL"))
                end
            end
        end

        local icon = deposit:GetNamedChild("Icon")
        if icon then
            if isStableInteractionActive() and Vendor.GetStableInteractionIcon then
                icon:SetTexture(Vendor.GetStableInteractionIcon())
            else
                icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
            end
        end
    end

    instance:RefreshVendorFooter()
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function PresentationRuntime.RefreshVendorFooter(instance, deps)
    local footerRoot = instance.footer and instance.footer:GetNamedChild("Footer")
    if not footerRoot then
        return
    end

    local isStableInteraction = deps.isStableInteractionActive()
    local isFenceInteraction = deps.isFenceInteraction()
    local currentMode = instance:GetCurrentMode()
    local paneRole = deps.resolveModePaneRole(currentMode, isStableInteraction, isFenceInteraction)
    local isSecondMode = paneRole == "second"
    local isFirstListMode = paneRole == "first"
    local isTwoPaneMode = isFirstListMode or isSecondMode
    local activeColor = { 1, 1, 1, 1 }
    local inactiveColor = BETTERUI_BANK_INACTIVE_LABEL_COLOR or { 0.35, 0.35, 0.35, 1 }

    local selectBg = footerRoot:GetNamedChild("SelectBg")
    if selectBg then
        local rotation = 0
        if isSecondMode then
            rotation = BETTERUI_BANK_DEPOSIT_ARROW_ROTATION or 0
        end
        selectBg:SetTextureRotation(rotation)
    end

    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            local label = btn:GetNamedChild("Label")
            if label then
                if isFenceInteraction then
                    label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_SELL")
                        or "SI_BETTERUI_VENDOR_TAB_FENCE_SELL"))
                else
                    label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY") or "SI_BETTERUI_VENDOR_TAB_BUY"))
                end
                if isTwoPaneMode then
                    label:SetColor(unpack(isSecondMode and inactiveColor or activeColor))
                else
                    label:SetColor(unpack(activeColor))
                end
            end

            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                if isFenceInteraction then
                    local fenceSellComp = instance.components and instance.components[MODE.FENCE_SELL]
                    if fenceSellComp and fenceSellComp.GetFooterText then
                        spaceLabel:SetText(fenceSellComp:GetFooterText())
                    else
                        spaceLabel:SetText("")
                    end
                else
                    spaceLabel:SetText(ResolveBuyPaneCurrencyText(instance))
                end
            end
        end
    end

    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            local label = btn:GetNamedChild("Label")
            if label then
                if isFenceInteraction then
                    label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER")
                        or "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER"))
                else
                    label:SetText(isStableInteraction
                        and GetString(rawget(_G, "SI_STABLE_STABLES_TAB") or "SI_STABLE_STABLES_TAB")
                        or GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL") or "SI_BETTERUI_VENDOR_TAB_SELL"))
                end
                if isTwoPaneMode then
                    label:SetColor(unpack(isSecondMode and activeColor or inactiveColor))
                else
                    label:SetColor(unpack(activeColor))
                end
            end

            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                if isFenceInteraction then
                    spaceLabel:SetHidden(false)
                    local fenceLaunderComp = instance.components and instance.components[MODE.FENCE_LAUNDER]
                    if fenceLaunderComp and fenceLaunderComp.GetFooterText then
                        spaceLabel:SetText(fenceLaunderComp:GetFooterText())
                    else
                        spaceLabel:SetText("")
                    end
                elseif isStableInteraction then
                    spaceLabel:SetHidden(true)
                    spaceLabel:SetText("")
                else
                    spaceLabel:SetHidden(false)
                    spaceLabel:SetText(
                        "|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t " ..
                        zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                            GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)))
                end
            end
        end

        local icon = deposit:GetNamedChild("Icon")
        if icon then
            if isStableInteraction then
                icon:SetTexture(deps.resolveStableInteractionIcon())
            else
                icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
            end
        end
    end
end
