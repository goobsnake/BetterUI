-- Modules/Vendor/Core/VendorClass.lua
-- Core class definition, constants, and mode-routing for the Vendor module.
--
-- Component-tab model: each tab is a separate "mode" with its own list builder
-- and keybinds. Active mode tracked in self.currentMode, changed via SetMode().

-- NAMESPACE & GUARD
if not BETTERUI.Vendor then BETTERUI.Vendor = {} end
local Vendor = BETTERUI.Vendor

-- SCENE CONSTANTS

BETTERUI_VENDOR_SCENE_NAME = "BETTERUI_VENDOR"

BETTERUI.Vendor.VENDOR_INTERACTION = STORE_INTERACTION

-- Fence shares the vendor scene but opens via EVENT_OPEN_FENCE.
BETTERUI.Vendor.FENCE_INTERACTION = {
    type = "Fence",
    interactTypes = { INTERACTION_VENDOR },
}

-- MODE CONSTANTS

BETTERUI.Vendor.MODE = {
    BUY           = 1,
    SELL          = 2,
    REPAIR        = 3,
    BUYBACK       = 4,
    FENCE_SELL    = 5,
    FENCE_LAUNDER = 6,
    STABLE        = 7,
}

local DEFAULT_VENDOR_CATEGORY_ICON = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"

local function ResolveNativeStoreMode(mode)
    if mode == BETTERUI.Vendor.MODE.BUY then
        return rawget(_G, "ZO_MODE_STORE_BUY")
    elseif mode == BETTERUI.Vendor.MODE.SELL then
        return rawget(_G, "ZO_MODE_STORE_SELL")
    elseif mode == BETTERUI.Vendor.MODE.REPAIR then
        return rawget(_G, "ZO_MODE_STORE_REPAIR")
    elseif mode == BETTERUI.Vendor.MODE.BUYBACK then
        return rawget(_G, "ZO_MODE_STORE_BUY_BACK")
    elseif mode == BETTERUI.Vendor.MODE.FENCE_SELL then
        return rawget(_G, "ZO_MODE_STORE_SELL_STOLEN")
    elseif mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER then
        return rawget(_G, "ZO_MODE_STORE_LAUNDER")
    elseif mode == BETTERUI.Vendor.MODE.STABLE then
        return rawget(_G, "ZO_MODE_STORE_STABLE")
    end
    return nil
end

local function ResolveModeName(mode)
    if mode == BETTERUI.Vendor.MODE.BUY then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY") or "SI_BETTERUI_VENDOR_TAB_BUY")
    elseif mode == BETTERUI.Vendor.MODE.SELL then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL") or "SI_BETTERUI_VENDOR_TAB_SELL")
    elseif mode == BETTERUI.Vendor.MODE.REPAIR then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_REPAIR") or "SI_BETTERUI_VENDOR_TAB_REPAIR")
    elseif mode == BETTERUI.Vendor.MODE.BUYBACK then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUYBACK") or "SI_BETTERUI_VENDOR_TAB_BUYBACK")
    elseif mode == BETTERUI.Vendor.MODE.FENCE_SELL then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_SELL") or "SI_BETTERUI_VENDOR_TAB_FENCE_SELL")
    elseif mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER then
        return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER") or "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER")
    elseif mode == BETTERUI.Vendor.MODE.STABLE then
        return GetString(rawget(_G, "SI_STABLE_STABLES_TAB") or "SI_STABLE_STABLES_TAB")
    end
    return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TITLE") or "SI_BETTERUI_VENDOR_TITLE")
end

local function ResolveStableInteractionIcon()
    if BETTERUI.Vendor and BETTERUI.Vendor.GetStableInteractionIcon then
        return BETTERUI.Vendor.GetStableInteractionIcon()
    end
    return "EsoUI/Art/Collections/Default/collections_default_mount.dds"
end

local function ResolveModeIcon(mode)
    if mode == BETTERUI.Vendor.MODE.BUY then
        return "EsoUI/Art/Vendor/vendor_tabIcon_buy_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.SELL then
        return "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.REPAIR then
        return "EsoUI/Art/Vendor/vendor_tabIcon_repair_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.BUYBACK then
        return "EsoUI/Art/Vendor/vendor_tabIcon_buyBack_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.FENCE_SELL then
        return "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER then
        return "EsoUI/Art/Vendor/vendor_tabIcon_fence_up.dds"
    elseif mode == BETTERUI.Vendor.MODE.STABLE then
        return ResolveStableInteractionIcon()
    end
    return DEFAULT_VENDOR_CATEGORY_ICON
end

---@param activeTabs table[]|nil
---@return boolean
local function IsSellBuybackOnlyTabs(activeTabs)
    local modeSet
    if BETTERUI.Vendor.BuildActiveModeSet then
        modeSet = BETTERUI.Vendor.BuildActiveModeSet(activeTabs)
    else
        modeSet = {}
        for _, tab in ipairs(activeTabs or {}) do
            if tab and tab.mode then
                modeSet[tab.mode] = true
            end
        end
    end

    if BETTERUI.Vendor.IsSellBuybackOnlyModeSet then
        local isFenceInteraction = BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction()
        return BETTERUI.Vendor.IsSellBuybackOnlyModeSet(modeSet, isFenceInteraction)
    end

    modeSet = modeSet or {}
    local hasSell = modeSet[BETTERUI.Vendor.MODE.SELL] == true
    local hasBuyback = modeSet[BETTERUI.Vendor.MODE.BUYBACK] == true
    local hasBuy = modeSet[BETTERUI.Vendor.MODE.BUY] == true
    local hasRepair = modeSet[BETTERUI.Vendor.MODE.REPAIR] == true
    return hasSell and hasBuyback and not hasBuy and not hasRepair
end

-- Forward declare; BuildHeaderModeTabs is defined before the function body.
local IsStableInteractionActive

local function BuildHeaderModeTabs(activeTabs, currentMode)
    local modeTabs = {}
    local isFenceInteraction = BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction()
    local isStableInteraction = IsStableInteractionActive()
    local isSellBuybackOnly = IsSellBuybackOnlyTabs(activeTabs)
    currentMode = currentMode or BETTERUI.Vendor.MODE.BUY
    local onUnifiedBuyScene = currentMode == BETTERUI.Vendor.MODE.BUY
        or currentMode == BETTERUI.Vendor.MODE.REPAIR
        or currentMode == BETTERUI.Vendor.MODE.BUYBACK

    for _, tab in ipairs(activeTabs or {}) do
        if isFenceInteraction then
            -- Fence uses footer buttons + keybind toggle; no mode tabs in header
        elseif isSellBuybackOnly then
            if tab.mode == BETTERUI.Vendor.MODE.SELL or tab.mode == BETTERUI.Vendor.MODE.BUYBACK then
                modeTabs[#modeTabs + 1] = tab
            end
        elseif onUnifiedBuyScene then
            if isStableInteraction then
                if tab.mode == BETTERUI.Vendor.MODE.REPAIR then
                    modeTabs[#modeTabs + 1] = tab
                end
            elseif tab.mode == BETTERUI.Vendor.MODE.REPAIR
                or tab.mode == BETTERUI.Vendor.MODE.BUYBACK then
                modeTabs[#modeTabs + 1] = tab
            end
        end
    end

    return modeTabs
end

local function BuildFallbackCategory()
    return {
        key = "all",
        name = GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_ALL") or "SI_BETTERUI_INV_ITEM_ALL"),
        iconFile = DEFAULT_VENDOR_CATEGORY_ICON,
        itemCount = 0,
    }
end

---@param left table[]|nil
---@param right table[]|nil
---@return boolean
local function AreVendorCategoriesEquivalent(left, right)
    if left == right then
        return true
    end
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    if #left ~= #right then
        return false
    end

    for index = 1, #left do
        local leftCategory = left[index] or {}
        local rightCategory = right[index] or {}
        if (leftCategory.key or leftCategory.name or index) ~= (rightCategory.key or rightCategory.name or index)
            or leftCategory.name ~= rightCategory.name
            or leftCategory.iconFile ~= rightCategory.iconFile
            or leftCategory.filterType ~= rightCategory.filterType
            or leftCategory.itemCount ~= rightCategory.itemCount
            or leftCategory.special ~= rightCategory.special then
            return false
        end
    end

    return true
end

local function ShouldShowVendorHeaderTabBar(headerEntryCount)
    return (headerEntryCount or 0) > 0
end

local function SafeCall(context, fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end

    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute then
        return BETTERUI.CIM.SafeExecute(context, fn, ...)
    end

    local ok, result = pcall(fn, ...)
    return ok, result
end

local function LogVendorDebug(flagName, category, message)
    if BETTERUI.Vendor and BETTERUI.Vendor.DebugLog then
        BETTERUI.Vendor.DebugLog(message, flagName, category)
    end
end

---@return boolean
function IsStableInteractionActive()
    return BETTERUI.Vendor
        and BETTERUI.Vendor.IsStableInteraction
        and BETTERUI.Vendor.IsStableInteraction()
        or false
end

local function IsDirectionalInputListening(obj)
    if BETTERUI.Vendor and BETTERUI.Vendor.IsDirectionalInputListening then
        return BETTERUI.Vendor.IsDirectionalInputListening(obj)
    end
    return false
end

---@param obj table|nil
---@return number registrationCount
local function CountDirectionalInputRegistrations(obj)
    if not obj or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.inputObjects) then
        return 0
    end

    local registrationCount = 0
    for _, registeredObject in ipairs(DIRECTIONAL_INPUT.inputObjects) do
        if registeredObject == obj then
            registrationCount = registrationCount + 1
        end
    end

    return registrationCount
end

---@param tabBar table|nil
---@param active boolean
---@return nil
local function SetTabBarVisualActive(tabBar, active)
    if not tabBar or tabBar.active == active then
        return
    end

    tabBar.active = active
    tabBar.dirty = false

    local onActivatedChanged = (tabBar.GetOnActivatedChangedFunction and tabBar:GetOnActivatedChangedFunction())
        or tabBar.onActivatedChangedFunction
    if onActivatedChanged then
        onActivatedChanged(tabBar, active)
    end

    if tabBar.RefreshVisible then
        tabBar:RefreshVisible()
    end
    if tabBar.Commit then
        tabBar:Commit()
    end
end

local function ReleaseDirectionalInputRegistrations(obj, includeMovementController)
    if BETTERUI.Vendor and BETTERUI.Vendor.ReleaseDirectionalInputRegistrations then
        return BETTERUI.Vendor.ReleaseDirectionalInputRegistrations(obj, includeMovementController)
    end
    return 0
end

local function ReleaseSpinnerDirectionalInput(spinner)
    if not spinner then
        return
    end

    if spinner.DetachFromListEntry then
        SafeCall("Vendor.ReleaseSpinnerDirectionalInput:DetachFromListEntry", spinner.DetachFromListEntry, spinner)
    end
    if spinner.Deactivate then
        SafeCall("Vendor.ReleaseSpinnerDirectionalInput:Deactivate", spinner.Deactivate, spinner)
    end
    if spinner.SetHidden then
        spinner:SetHidden(true)
    end

    ReleaseDirectionalInputRegistrations(spinner, true)

    if spinner.spinner then
        if spinner.spinner.Deactivate then
            SafeCall("Vendor.ReleaseSpinnerDirectionalInput:DeactivateNestedSpinner", spinner.spinner.Deactivate, spinner.spinner)
        end
        ReleaseDirectionalInputRegistrations(spinner.spinner, true)
    end
end

local function ForEachHeaderDirectionalInputCandidate(header, callback)
    if not header or type(callback) ~= "function" then
        return
    end

    local seen = {}
    local function Visit(candidate)
        if not candidate or seen[candidate] then
            return
        end
        seen[candidate] = true
        callback(candidate)
    end

    Visit(header.headerFocus)
    Visit(header.headerFocusControl)
    Visit(header.headerFocusControl and header.headerFocusControl.owner)
    Visit(header.tabBar)
    Visit(header.tabBar and header.tabBar.control)
end

local function ReleaseHeaderDirectionalInput(header, context)
    local releasedCount = 0

    ForEachHeaderDirectionalInputCandidate(header, function(candidate)
        if candidate.Deactivate then
            SafeCall(context or "Vendor.ReleaseHeaderDirectionalInput:Deactivate", candidate.Deactivate, candidate)
        end
        releasedCount = releasedCount + ReleaseDirectionalInputRegistrations(candidate, true)
    end)

    return releasedCount
end

local function HasVisibleGamepadDialog()
    if not GetControl then
        return false
    end

    local gamepadDialog = GetControl("ZO_DialogGamepad1")
    return gamepadDialog and gamepadDialog.IsHidden and not gamepadDialog:IsHidden() or false
end

local function ShouldAllowVendorDeferredNormalization(screen)
    return screen
        and screen.IsSceneShowing and screen:IsSceneShowing()
        and not screen.confirmationMode
        and not screen._searchModeActive
        and not screen._searchHeaderActive
        and not HasVisibleGamepadDialog()
end

local function SupportsVendorHeaderSearch(screen)
    return screen
        and screen.textSearchKeybindStripDescriptor ~= nil
        and screen.textSearchHeaderControl ~= nil
        and screen.textSearchHeaderFocus ~= nil
end

local HEADER_COLUMN_KEYS = { "NAME", "TYPE", "TRAIT", "STAT", "VALUE" }
local LAYOUT_COLUMN_KEYS = { "SUBMENU", "TYPE", "TRAIT", "STAT", "VALUE" }

local function ResolveHeaderColumnOffset(columnIndex)
    if not columnIndex then
        return nil
    end

    local headerColumns = BETTERUI.CIM.CONST.HEADER_LAYOUT and BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    if headerColumns then
        local headerKey = HEADER_COLUMN_KEYS[columnIndex]
        if headerKey and headerColumns[headerKey] then
            return headerColumns[headerKey]
        end
    end

    local layoutColumns = BETTERUI.CIM.CONST.LAYOUT and BETTERUI.CIM.CONST.LAYOUT.COLUMNS
    if layoutColumns then
        local layoutKey = LAYOUT_COLUMN_KEYS[columnIndex]
        local columnDef = layoutKey and layoutColumns[layoutKey]
        if type(columnDef) == "table" and columnDef.OFFSET_X then
            return columnDef.OFFSET_X
        end

        local legacyOffset = layoutColumns[columnIndex]
        if type(legacyOffset) == "number" then
            return legacyOffset
        end
    end

    return nil
end

-- MODULE-SCOPE TASK MANAGER (for coalescing list refreshes)
assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask, "BetterUI: CIM.DeferredTask must load before Vendor/Core/VendorClass")
BETTERUI.Vendor.Tasks = BETTERUI.CIM.DeferredTask.Manager:New()

-- CLASS DEFINITION

---@class BETTERUI.Vendor.Class : BETTERUI.CIM.GenericWindow
---@field currentMode number Current active vendor mode (see BETTERUI.Vendor.MODE)
---@field components table<number, VendorComponent> Registered mode components
---@field list table|nil Parametric list control
---@field coreKeybinds table Core keybind button group
---@field header table|nil Header control with SetTitle method
---@field _keybindsAdded boolean Whether keybinds are currently registered
---@field _suppressListUpdates boolean Whether list refreshes are suppressed
---@field _isDirty boolean Whether list needs refresh after suppression ends
---@field unifiedFooterController table|nil Footer controller reference
BETTERUI.Vendor.Class = BETTERUI.CIM.GenericWindow:Subclass()

---@param ... any Arguments forwarded to GenericWindow:New
---@return BETTERUI.Vendor.Class
function BETTERUI.Vendor.Class:New(...)
    local obj = BETTERUI.CIM.GenericWindow.New(self, ...)
    return obj --[[@as BETTERUI.Vendor.Class]]
end

---@return boolean showing True if the vendor scene is currently showing
function BETTERUI.Vendor.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

---@return boolean active True when the vendor scene is not hidden (showing/shown/transitioning)
function BETTERUI.Vendor.Class:IsSceneActiveOrShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then
        return false
    end
    if scene.GetState and rawget(_G, "SCENE_HIDDEN") then
        return scene:GetState() ~= SCENE_HIDDEN
    end
    return scene:IsShowing()
end

---@return boolean
function BETTERUI.Vendor.Class:IsSellBuybackOnlyStore()
    if BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction() then
        return false
    end

    if BETTERUI.Vendor.IsSellBuybackOnlyStore then
        return BETTERUI.Vendor.IsSellBuybackOnlyStore()
    end

    local activeTabs = (BETTERUI.Vendor.GetActiveTabs and BETTERUI.Vendor.GetActiveTabs()) or {}
    return IsSellBuybackOnlyTabs(activeTabs)
end

---@return nil
function BETTERUI.Vendor.Class:ReleaseNativeStoreInputOwnership()
    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if not storeManager then
        return
    end

    ReleaseSpinnerDirectionalInput(storeManager.spinner)

    LogVendorDebug(
        "DIRECTIONAL_INPUT",
        "VendorDI",
        string.format(
            "ReleaseNativeStoreInputOwnership store=%s headerFocus=%s currentList=%s",
            tostring(IsDirectionalInputListening(storeManager)),
            tostring(IsDirectionalInputListening(storeManager.headerFocus)),
            tostring(IsDirectionalInputListening(storeManager._currentList))
        )
    )

    if type(storeManager.DeactivateActiveComponent) == "function" then
        SafeCall(
            "Vendor.ReleaseNativeStoreInputOwnership:DeactivateActiveComponent",
            storeManager.DeactivateActiveComponent,
            storeManager,
            false
        )
    end

    if type(storeManager.DeactivateTextSearch) == "function" then
        SafeCall("Vendor.ReleaseNativeStoreInputOwnership:DeactivateTextSearch", storeManager.DeactivateTextSearch, storeManager)
    end

    local headerFocus = storeManager.headerFocus
    if headerFocus then
        -- Deactivate unconditionally — headerFocus may be registered on DIRECTIONAL_INPUT
        -- even when IsActive() returns false (inconsistent state from external deactivation).
        -- ZO_GamepadFocus:SetActive(false) checks `self.active ~= active` and is a no-op
        -- when active is already false, so also call DIRECTIONAL_INPUT:Deactivate directly.
        if headerFocus.Deactivate then
            SafeCall("Vendor.ReleaseNativeStoreInputOwnership:HeaderFocusDeactivate", headerFocus.Deactivate, headerFocus)
        end
        ReleaseDirectionalInputRegistrations(headerFocus)
    end

    if type(storeManager.RemoveListKeybinds) == "function" then
        SafeCall("Vendor.ReleaseNativeStoreInputOwnership:RemoveListKeybinds", storeManager.RemoveListKeybinds, storeManager)
    end

    if storeManager.keybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(storeManager.keybindStripDescriptor)
    end

    if type(storeManager.Deactivate) == "function" then
        SafeCall("Vendor.ReleaseNativeStoreInputOwnership:Deactivate", storeManager.Deactivate, storeManager)
    end

    -- Direct DIRECTIONAL_INPUT:Deactivate on storeManager — bypasses the
    -- DisableCurrentList → SetDirectionalInputEnabled chain which may have
    -- already run, leaving the storeManager's active flag false while it
    -- is still registered on the DI stack.
    ReleaseDirectionalInputRegistrations(storeManager)

    -- Deactivate the native store's header tabBar — the native scene's SCENE_HIDDEN
    -- handler (which calls ZO_GamepadGenericHeader_Deactivate) never fires because
    -- BetterUI replaces the scene alias, leaving the native tabBar orphaned on the
    -- DIRECTIONAL_INPUT stack.
    local nativeHeader = storeManager.header
    if nativeHeader then
        ReleaseHeaderDirectionalInput(nativeHeader, "Vendor.ReleaseNativeStoreInputOwnership:NativeHeader")

        local nativeTabBar = nativeHeader.tabBar
        if nativeTabBar then
            if nativeTabBar.Deactivate then
                nativeTabBar:Deactivate()
            end
            ReleaseDirectionalInputRegistrations(nativeTabBar)
        end
    end

    -- Deactivate the native store's current list — use direct DI calls in case
    -- the list's .active flag is already false (ZO_ParametricScrollList:Deactivate
    -- is a no-op when self.active ~= false is false).
    if storeManager._currentList then
        if storeManager._currentList.Deactivate then
            storeManager._currentList:Deactivate()
        end
        if storeManager._currentList.SetDirectionalInputEnabled then
            storeManager._currentList:SetDirectionalInputEnabled(false)
        end
        ReleaseDirectionalInputRegistrations(storeManager._currentList, true)
    end

    -- Sweep all native component lists off DI — component:Refresh() during
    -- SetActiveComponents may have triggered OnEffectivelyShown handlers that
    -- call list:Activate(), registering them on the DI stack.
    local activeComps = storeManager.activeComponents
    if type(activeComps) == "table" then
        for _, comp in ipairs(activeComps) do
            if comp and comp.list then
                if comp.list.SetDirectionalInputEnabled then
                    comp.list:SetDirectionalInputEnabled(false)
                end
                ReleaseDirectionalInputRegistrations(comp.list, true)
            end
        end
    end
end

---@return nil
function BETTERUI.Vendor.Class:ForceReleaseDirectionalInput()
    if not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT.Deactivate) then
        return
    end

    LogVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "ForceReleaseDirectionalInput invoked")

    -- Use proper Deactivate methods where possible so object state (e.g.
    -- tabBar.active, list:IsActive()) stays consistent with DIRECTIONAL_INPUT.
    local function SafeDeactivate(obj, includeMovementController, disableDirectionalInput)
        if not obj then return end
        if disableDirectionalInput and obj.SetDirectionalInputEnabled then
            obj:SetDirectionalInputEnabled(false)
        end
        if obj.Deactivate then
            if not obj.IsActive or obj:IsActive() or IsDirectionalInputListening(obj)
                or (includeMovementController and IsDirectionalInputListening(obj.movementController)) then
                obj:Deactivate()
            end
        end
        ReleaseDirectionalInputRegistrations(obj, includeMovementController)
    end

    SafeDeactivate(self, true)
    SafeDeactivate(self.list, true, true)
    ReleaseSpinnerDirectionalInput(self.spinner)
    ReleaseHeaderDirectionalInput(self.headerGeneric, "Vendor.ForceReleaseDirectionalInput:HeaderGeneric")
    ReleaseHeaderDirectionalInput(self.header, "Vendor.ForceReleaseDirectionalInput:Header")
    SafeDeactivate(self.textSearchHeaderFocus, true)
    SafeDeactivate(self.headerFocus, true)
    SafeDeactivate(self.textSearchHeaderControl, true)
end

---@param reason string|nil
---@return boolean detached
function BETTERUI.Vendor.Class:DetachUnexpectedSearchHeaderFocus(reason)
    if SupportsVendorHeaderSearch(self) then
        return false
    end

    local focusControl = self.textSearchHeaderControl
    local focusObject = self.textSearchHeaderFocus
    local hadSearchFocus = focusControl ~= nil or focusObject ~= nil or self.headerFocus ~= nil
    if not hadSearchFocus then
        return false
    end

    local function ClearHeader(header)
        if not header then
            return
        end

        if header.headerFocusControl == focusControl then
            header.headerFocusControl = nil
        end
        if header.headerFocus == focusObject or header.headerFocus == focusControl then
            header.headerFocus = nil
        end

        local tabBarControl = header.tabBar and header.tabBar.control
        if tabBarControl then
            if tabBarControl.headerFocusControl == focusControl then
                tabBarControl.headerFocusControl = nil
            end
            if tabBarControl.headerFocus == focusObject or tabBarControl.headerFocus == focusControl then
                tabBarControl.headerFocus = nil
            end
        end
    end

    if focusObject then
        if focusObject.SetFocused then
            SafeCall("Vendor.DetachUnexpectedSearchHeaderFocus:SetFocused", focusObject.SetFocused, focusObject, false)
        end
        if focusObject.Deactivate then
            SafeCall("Vendor.DetachUnexpectedSearchHeaderFocus:DeactivateFocus", focusObject.Deactivate, focusObject)
        end
        ReleaseDirectionalInputRegistrations(focusObject, true)
    end

    if focusControl then
        if focusControl.SetHidden then
            focusControl:SetHidden(true)
        end
        ReleaseDirectionalInputRegistrations(focusControl, true)
    end

    ClearHeader(self.headerGeneric)
    ClearHeader(self.header)

    if self.headerFocus == focusObject or self.headerFocus == focusControl then
        self.headerFocus = nil
    end

    self._searchModeActive = false
    self._searchHeaderActive = false

    if hadSearchFocus then
        LogVendorDebug(
            "DIRECTIONAL_INPUT",
            "VendorDI",
            string.format("DetachUnexpectedSearchHeaderFocus reason=%s", tostring(reason or "unknown"))
        )
    end

    return hadSearchFocus
end

---@param reason string|nil
---@return nil
function BETTERUI.Vendor.Class:NormalizeDirectionalInputOwnership(reason)
    if not (self.IsSceneShowing and self:IsSceneShowing()) then
        return
    end

    if self.DetachUnexpectedSearchHeaderFocus then
        self:DetachUnexpectedSearchHeaderFocus(reason)
    end

    if HasVisibleGamepadDialog() then
        return
    end

    if not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.inputObjects) then
        return
    end

    local allowed = {}
    local function Allow(obj, includeMovementController)
        if not obj then
            return
        end

        allowed[obj] = true
        if obj.spinner then
            allowed[obj.spinner] = true
        end

        if includeMovementController then
            if obj.movementController then
                allowed[obj.movementController] = true
            end
            if obj.horizontalMovementController then
                allowed[obj.horizontalMovementController] = true
            end
            if obj.verticalMovementController then
                allowed[obj.verticalMovementController] = true
            end
            if obj.spinner and obj.spinner.spinner then
                allowed[obj.spinner.spinner] = true
            end
        end
    end

    local function AllowHeader(header)
        ForEachHeaderDirectionalInputCandidate(header, function(candidate)
            Allow(candidate, true)
        end)
    end

    if self.confirmationMode then
        Allow(self.spinner, true)
    elseif (self._searchModeActive or self._searchHeaderActive) and SupportsVendorHeaderSearch(self) then
        Allow(self.textSearchHeaderFocus, true)
        Allow(self.headerFocus, true)
        Allow(self.textSearchHeaderControl, true)
        Allow(self.list, true)
        AllowHeader(self.headerGeneric)
        AllowHeader(self.header)
    elseif self.isInHeaderSortMode then
        Allow(self.headerGeneric and self.headerGeneric.tabBar, true)
        AllowHeader(self.headerGeneric)
        AllowHeader(self.header)
    else
        Allow(self.list, true)
    end

    local snapshot = {}
    for i, obj in ipairs(DIRECTIONAL_INPUT.inputObjects) do
        snapshot[i] = obj
    end

    local releasedCount = 0
    for _, obj in ipairs(snapshot) do
        if obj and not allowed[obj] then
            releasedCount = releasedCount + ReleaseDirectionalInputRegistrations(obj, true)
        end
    end

    if releasedCount > 0 then
        LogVendorDebug(
            "DIRECTIONAL_INPUT",
            "VendorDI",
            string.format("NormalizeDirectionalInputOwnership released=%d reason=%s", releasedCount, tostring(reason or "unknown"))
        )
    end
end

---@param reason string|nil
---@param delayMs number|nil
---@return nil
function BETTERUI.Vendor.Class:ScheduleDirectionalInputNormalization(reason, delayMs)
    if not (BETTERUI.Vendor and BETTERUI.Vendor.Tasks) then
        return
    end

    if not ShouldAllowVendorDeferredNormalization(self) then
        BETTERUI.Vendor.Tasks:Cancel("directionalInputNormalize")
        return
    end

    BETTERUI.Vendor.Tasks:Cancel("directionalInputNormalize")
    BETTERUI.Vendor.Tasks:Schedule("directionalInputNormalize", delayMs or 40, function()
        if ShouldAllowVendorDeferredNormalization(self) and self.NormalizeDirectionalInputOwnership then
            self:NormalizeDirectionalInputOwnership(string.format("%s:deferred", tostring(reason or "unknown")))
        end
    end)
end

-- MODE ROUTING

---@return number mode Current vendor mode constant
function BETTERUI.Vendor.Class:GetCurrentMode()
    return self.currentMode or BETTERUI.Vendor.MODE.BUY
end

---@param mode number|nil
---@return nil
function BETTERUI.Vendor.Class:ApplyNativeStoreMode(mode)
    local function ReleaseNativeInputIfNeeded()
        if self.IsSceneActiveOrShowing and self:IsSceneActiveOrShowing() and self.ReleaseNativeStoreInputOwnership then
            self:ReleaseNativeStoreInputOwnership()
        end
    end

    local targetMode = ResolveNativeStoreMode(mode or self:GetCurrentMode())
    if targetMode == nil then
        return
    end

    LogVendorDebug(
        "SCENE_TRANSITIONS",
        "VendorScene",
        string.format("ApplyNativeStoreMode requested=%s native=%s", tostring(mode or self:GetCurrentMode()), tostring(targetMode))
    )

    if type(SetStoreMode) == "function" then
        local currentMode = nil
        if type(GetStoreMode) == "function" then
            local okGetMode, modeResult = SafeCall("Vendor.ApplyNativeStoreMode:GetStoreMode", GetStoreMode)
            if okGetMode then
                currentMode = modeResult
            end
        end
        if currentMode ~= targetMode then
            SafeCall("Vendor.ApplyNativeStoreMode:SetStoreMode", SetStoreMode, targetMode)
        end
    end

    local storeManager = rawget(_G, "STORE_WINDOW_GAMEPAD")
    if not storeManager then
        ReleaseNativeInputIfNeeded()
        return
    end

    if type(storeManager.SetMode) ~= "function" then
        ReleaseNativeInputIfNeeded()
        return
    end

    local targetVendorMode = mode or self:GetCurrentMode()
    local shouldEnsureNativeComponents = targetVendorMode == BETTERUI.Vendor.MODE.BUY
        or targetVendorMode == BETTERUI.Vendor.MODE.STABLE
    if shouldEnsureNativeComponents and BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
        BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
    end

    local activeComponents = storeManager.activeComponents
    if type(activeComponents) ~= "table" or #activeComponents == 0 then
        ReleaseNativeInputIfNeeded()
        return
    end

    local hasTargetMode = false
    for _, component in ipairs(activeComponents) do
        if component and type(component.GetStoreMode) == "function" then
            local okMode, componentMode = SafeCall("Vendor.ApplyNativeStoreMode:ComponentMode", component.GetStoreMode, component)
            if okMode and componentMode == targetMode then
                hasTargetMode = true
                break
            end
        end
    end

    if not hasTargetMode then
        if shouldEnsureNativeComponents and BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
            BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
            activeComponents = storeManager.activeComponents
            if type(activeComponents) == "table" and #activeComponents > 0 then
                for _, component in ipairs(activeComponents) do
                    if component and type(component.GetStoreMode) == "function" then
                        local okMode, componentMode = SafeCall("Vendor.ApplyNativeStoreMode:ComponentModeRetry", component.GetStoreMode, component)
                        if okMode and componentMode == targetMode then
                            hasTargetMode = true
                            break
                        end
                    end
                end
            end
        end

        if not hasTargetMode then
            ReleaseNativeInputIfNeeded()
            return
        end
    end

    local currentMode = nil
    if type(storeManager.GetCurrentMode) == "function" then
        local okCurrent, currentResult = SafeCall("Vendor.ApplyNativeStoreMode:GetCurrentMode", storeManager.GetCurrentMode, storeManager)
        if okCurrent then
            currentMode = currentResult
        end
    end

    if currentMode ~= targetMode then
        SafeCall("Vendor.ApplyNativeStoreMode:StoreManagerSetMode", storeManager.SetMode, storeManager, targetMode)
    end

    ReleaseNativeInputIfNeeded()
    LogVendorDebug(
        "DIRECTIONAL_INPUT",
        "VendorDI",
        string.format("ApplyNativeStoreMode complete store=%s currentList=%s", tostring(IsDirectionalInputListening(storeManager)), tostring(IsDirectionalInputListening(storeManager._currentList)))
    )
end

---@return nil
function BETTERUI.Vendor.Class:InitializeCategoryHeader()
    self.modeCategories = self.modeCategories or {}
    self.categoryIndexByMode = self.categoryIndexByMode or {}

    self.headerGeneric = (self.header and self.header:GetNamedChild("Header")) or self.header
    if not self.headerGeneric then
        return
    end

    BETTERUI.GenericHeader.Initialize(self.headerGeneric, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
end

---@param mode number
---@return table[] categories
function BETTERUI.Vendor.Class:GetModeCategories(mode)
    self.modeCategories = self.modeCategories or {}
    local categories = self.modeCategories[mode]
    if not categories or #categories == 0 then
        categories = { BuildFallbackCategory() }
        self.modeCategories[mode] = categories
    end
    return categories
end

---@param mode number
---@param categories table[]|nil
---@return nil
function BETTERUI.Vendor.Class:SetModeCategories(mode, categories)
    self.modeCategories = self.modeCategories or {}
    self.categoryIndexByMode = self.categoryIndexByMode or {}
    local previousCategories = self.modeCategories[mode]

    if not categories or #categories == 0 then
        categories = { BuildFallbackCategory() }
    end

    self.modeCategories[mode] = categories
    if mode == BETTERUI.Vendor.MODE.BUY and #categories > 0 then
        self._cachedBuyCategories = categories
    end

    local selectedIndex = self.categoryIndexByMode[mode] or 1
    if selectedIndex < 1 or selectedIndex > #categories then
        selectedIndex = 1
    end
    self.categoryIndexByMode[mode] = selectedIndex

    if mode == self:GetCurrentMode() then
        self.currentCategoryIndex = selectedIndex
        local shouldRebuildHeader = self.vendorHeaderData == nil or not AreVendorCategoriesEquivalent(previousCategories, categories)
        if shouldRebuildHeader then
            self:RebuildCategoryHeader()
        elseif self.UpdateVendorHeaderTitle then
            self:UpdateVendorHeaderTitle()
        end
    end
end

---@return table category
function BETTERUI.Vendor.Class:GetCurrentCategory()
    local mode = self:GetCurrentMode()
    local categories = self:GetModeCategories(mode)
    local selectedIndex = (self.categoryIndexByMode and self.categoryIndexByMode[mode]) or 1
    if selectedIndex < 1 or selectedIndex > #categories then
        selectedIndex = 1
        self.categoryIndexByMode[mode] = selectedIndex
    end
    self.currentCategoryIndex = selectedIndex
    return categories[selectedIndex]
end

---@param mode number Vendor mode constant
---@return string moduleKey PositionManager module key for this mode
local function GetVendorModeModuleKey(mode)
    local MODULES = BETTERUI.CIM.CONST.MODULES
    if mode == BETTERUI.Vendor.MODE.BUY then return MODULES.VENDOR_BUY
    elseif mode == BETTERUI.Vendor.MODE.SELL then return MODULES.VENDOR_SELL
    elseif mode == BETTERUI.Vendor.MODE.REPAIR then return MODULES.VENDOR_REPAIR
    elseif mode == BETTERUI.Vendor.MODE.BUYBACK then return MODULES.VENDOR_BUYBACK
    elseif mode == BETTERUI.Vendor.MODE.FENCE_SELL then return MODULES.VENDOR_FENCE_SELL
    elseif mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER then return MODULES.VENDOR_FENCE_LAUNDER
    elseif mode == BETTERUI.Vendor.MODE.STABLE then return MODULES.VENDOR_STABLE
    end
    return "Vendor"
end

---@param self BETTERUI.Vendor.Class
---@return string categoryKey PositionManager category key for the active category
local function GetVendorCategoryKey(self)
    local category = self:GetCurrentCategory()
    if not category then return "k:all" end
    return BETTERUI.CIM.PositionManager.GetCategoryKey(category) or "k:all"
end

---@return nil
function BETTERUI.Vendor.Class:SaveListPosition()
    local currentMode = self:GetCurrentMode()
    if not currentMode or not self.list then
        return
    end

    local moduleKey = GetVendorModeModuleKey(currentMode)
    local categoryKey = GetVendorCategoryKey(self)
    BETTERUI.CIM.PositionManager.SavePosition(moduleKey, categoryKey, self.list)
end

---@return nil
function BETTERUI.Vendor.Class:UpdateVendorHeaderTitle()
    local headerGeneric = self.headerGeneric
    local titleContainer = headerGeneric and headerGeneric.GetNamedChild and headerGeneric:GetNamedChild("TitleContainer")
    local titleControl = titleContainer and titleContainer.GetNamedChild and titleContainer:GetNamedChild("Title")
    if not (titleControl and self.vendorHeaderData and self.vendorHeaderData.titleText) then
        return
    end

    titleControl:SetText(self.vendorHeaderData.titleText(self.vendorHeaderData.name))

    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
end

--- Clears the text search input and normalized query state.
---@return nil
function BETTERUI.Vendor.Class:ClearSearchInput()
    self.searchQuery = ""
    if not BETTERUI.CIM.TryCall("Interface.Window.ClearSearchText", self) then
        if self.ClearSearchText then
            self:ClearSearchText()
        end
    end
end

--- Backwards-compatible alias.
---@return nil
function BETTERUI.Vendor.Class:ClearTextSearch()
    self:ClearSearchInput()
end

--- Checks whether search/header focus is active.
---@return boolean focused
function BETTERUI.Vendor.Class:IsHeaderFocused()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        return self.textSearchHeaderFocus:IsActive()
    end
    return self._searchModeActive == true
end

--- Backwards-compatible alias.
---@return boolean active
function BETTERUI.Vendor.Class:IsHeaderActive()
    return self:IsHeaderFocused()
end

--- Requests focus for the search header.
---@return nil
function BETTERUI.Vendor.Class:RequestHeaderFocus()
    if self.OnHeaderEntered then
        self:OnHeaderEntered()
    else
        self:EnterSearchMode()
    end
end

--- Backwards-compatible alias for template hooks.
---@return nil
function BETTERUI.Vendor.Class:RequestEnterHeader()
    self:RequestHeaderFocus()
end

--- Repositions the search control under the header title.
---@return nil
function BETTERUI.Vendor.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then
        return
    end

    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.headerGeneric or self.header
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        titleContainer = anchorTarget:GetNamedChild("TitleContainer") or anchorTarget:GetNamedChild("Header")
    end

    local parentForAnchor = titleContainer or anchorTarget
    local searchConst = BETTERUI.CIM.GetSearchBarConstants and BETTERUI.CIM.GetSearchBarConstants("BANKING")
    local xOffset = (searchConst and searchConst.X_OFFSET) or 55
    local yOffset = (searchConst and searchConst.Y_OFFSET) or 15
    local rightInset = (searchConst and searchConst.RIGHT_INSET) or -8

    if parentForAnchor then
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, rightInset, yOffset)
    end

    self.textSearchHeaderControl:SetHidden(false)
    if ZO_GamepadGenericHeader_SetHeaderFocusControl then
        local headerTarget
        if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.control then
            headerTarget = self.headerGeneric.tabBar.control
        else
            headerTarget = self.headerGeneric or self.header
        end
        if headerTarget then
            ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
        end
    end
end

--- Enters text-search mode and swaps active keybind groups.
---@return nil
function BETTERUI.Vendor.Class:EnterSearchMode()
    if self._searchModeActive then
        return
    end
    self._searchModeActive = true
    self._searchHeaderActive = true

    if self.coreKeybinds and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
    end

    if self.textSearchKeybindStripDescriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Activate and not self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Activate()
    end
    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(true)
    end

    if self.NormalizeDirectionalInputOwnership then
        self:NormalizeDirectionalInputOwnership("EnterSearchMode")
    end
end

--- Exits text-search mode and restores list/core keybind ownership.
---@return nil
function BETTERUI.Vendor.Class:ExitSearchMode()
    if not self._searchModeActive and not self._searchHeaderActive then
        return
    end
    self._searchModeActive = false
    self._searchHeaderActive = false

    if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate and self.textSearchHeaderFocus:IsActive() then
        self.textSearchHeaderFocus:Deactivate()
    end
    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(false)
    end

    if self.list and self.list.Activate and (not self.list.IsActive or not self.list:IsActive()) then
        self.list:Activate()
    end
    if self.coreKeybinds then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.coreKeybinds)
    end

    if self.EnsureHeaderKeybindsActive then
        self:EnsureHeaderKeybindsActive()
    end
    if self.EnsureListInputActive then
        self:EnsureListInputActive()
    end
    if self.NormalizeDirectionalInputOwnership then
        self:NormalizeDirectionalInputOwnership("ExitSearchMode")
    end
end

--- Backwards-compatible alias.
---@return nil
function BETTERUI.Vendor.Class:LeaveSearchMode()
    self:ExitSearchMode()
end

--- Handles search focus loss.
---@return nil
function BETTERUI.Vendor.Class:OnSearchFocusLost()
    self:ExitSearchMode()
end

--- Backwards-compatible alias.
---@return nil
function BETTERUI.Vendor.Class:ExitSearchFocus()
    self:OnSearchFocusLost()
end

--- Callback when navigating from list into header/search.
---@return nil
function BETTERUI.Vendor.Class:OnHeaderEntered()
    if self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden()) then
        self:EnterSearchMode()

        if BETTERUI.CIM.TryResolve("Interface.Window.OnEnterHeader") then
            BETTERUI.Interface.Window.OnEnterHeader(self)
        end

        BETTERUI.Vendor.Tasks:Schedule("searchKeybindCleanup", 20, function()
            if not self._searchModeActive or not KEYBIND_STRIP then
                return
            end

            local keybindGroups = KEYBIND_STRIP.keybindButtonGroups
            if keybindGroups then
                for i = #keybindGroups, 1, -1 do
                    local group = keybindGroups[i]
                    if group and group ~= self.textSearchKeybindStripDescriptor then
                        KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                    end
                end
            end

            if self._searchModeActive and self.textSearchKeybindStripDescriptor then
                BETTERUI.Interface.EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
            end
        end)
    else
        BETTERUI.CIM.TryCall("Interface.Window.OnEnterHeader", self)
    end
end

--- Backwards-compatible alias.
---@return nil
function BETTERUI.Vendor.Class:OnEnterHeader()
    self:OnHeaderEntered()
end

--- Handles text updates from search edit box callbacks.
---@param editBox table|string|nil
---@return nil
function BETTERUI.Vendor.Class:OnSearchTextChanged(editBox)
    local query
    if type(editBox) == "string" then
        query = editBox
    elseif editBox and editBox.GetText then
        query = editBox:GetText()
    else
        query = tostring(editBox or "")
    end

    self.searchQuery = query or ""
    self:RefreshList()
end

---@return nil
function BETTERUI.Vendor.Class:EnsureHeaderKeybindsActive()
    -- Guard against premature DIRECTIONAL_INPUT registration during scene
    -- transitions — matches Banking pattern (prevents joystick lock-up).
    if self.isInHeaderSortMode then
        return
    end
    if self.scene and not self.scene:IsShowing() then
        return
    end

    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end
    if not ShouldShowVendorHeaderTabBar(self._vendorHeaderEntryCount) then
        ReleaseHeaderDirectionalInput(self.headerGeneric, "Vendor.EnsureHeaderKeybindsActive:HeaderGenericHidden")
        ReleaseHeaderDirectionalInput(self.header, "Vendor.EnsureHeaderKeybindsActive:HeaderHidden")
        SetTabBarVisualActive(tabBar, false)
        return
    end

    if self.DetachUnexpectedSearchHeaderFocus then
        self:DetachUnexpectedSearchHeaderFocus("EnsureHeaderKeybindsActive")
    end

    -- Vendor uses core shoulder keybinds for tab cycling; do not register the
    -- header tab bar on DIRECTIONAL_INPUT or it can steal focus from the item list.
    ReleaseHeaderDirectionalInput(self.headerGeneric, "Vendor.EnsureHeaderKeybindsActive:HeaderGeneric")
    ReleaseHeaderDirectionalInput(self.header, "Vendor.EnsureHeaderKeybindsActive:Header")
    if tabBar.keybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(tabBar.keybindStripDescriptor)
    end
    SetTabBarVisualActive(tabBar, true)
end

---@return nil
function BETTERUI.Vendor.Class:EnsureListInputActive()
    -- Only activate list input when the scene is actually showing.
    if self.scene and not self.scene:IsShowing() then
        return
    end

    local list = self.list
    if not list then
        return
    end

    if self.DetachUnexpectedSearchHeaderFocus then
        self:DetachUnexpectedSearchHeaderFocus("EnsureListInputActive")
    end

    local listRegistrationCount = CountDirectionalInputRegistrations(list)
    local controllerRegistrationCount = CountDirectionalInputRegistrations(list.movementController)
    local listListening = listRegistrationCount > 0
    local controllerListening = controllerRegistrationCount > 0
    local shouldResetListInput = listRegistrationCount > 1 or controllerRegistrationCount > 1
        or (controllerListening and not listListening)
    local isListActive = not list.IsActive or list:IsActive()

    if shouldResetListInput then
        local releasedCount = ReleaseDirectionalInputRegistrations(list, true)
        if releasedCount > 0 then
            LogVendorDebug(
                "DIRECTIONAL_INPUT",
                "VendorDI",
                string.format(
                    "EnsureListInputActive cleared stale vendor list registrations=%d list=%d controller=%d",
                    releasedCount,
                    listRegistrationCount,
                    controllerRegistrationCount
                )
            )
        end

        if list.SetActive then
            list:SetActive(false)
        elseif list.Deactivate and (not list.IsActive or list:IsActive()) then
            list:Deactivate()
        end

        listListening = false
        controllerListening = false
        isListActive = false
    end

    local shouldActivateList = list.Activate and (shouldResetListInput or not isListActive)
    if shouldActivateList then
        -- ZO_ParametricScrollList:Activate() already registers the list when
        -- directionalInputEnabled is true. Setting it via the public mutator here
        -- would register the same list twice and accelerate scrolling.
        list.directionalInputEnabled = true
    elseif list.SetDirectionalInputEnabled and not listListening then
        list:SetDirectionalInputEnabled(true)
        listListening = CountDirectionalInputRegistrations(list) > 0
    end

    controllerListening = CountDirectionalInputRegistrations(list.movementController) > 0
    if shouldActivateList then
        LogVendorDebug("DIRECTIONAL_INPUT", "VendorDI", "EnsureListInputActive activating vendor list")
        list:Activate()
    end

    if self.NormalizeDirectionalInputOwnership and not self.confirmationMode
        and not self._searchModeActive and not self._searchHeaderActive then
        self:NormalizeDirectionalInputOwnership("EnsureListInputActive")
        if self.ScheduleDirectionalInputNormalization then
            self:ScheduleDirectionalInputNormalization("EnsureListInputActive")
        end
    end
end

---@return nil
function BETTERUI.Vendor.Class:InitializeScrollIndicator()
    if not (self.list and self.list.control and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator) then
        return
    end

    BETTERUI.CIM.ScrollIndicator.Initialize(self.list.control, 25, -5, -10, self.list)
end

---@return nil
function BETTERUI.Vendor.Class:ApplyListLayoutTuning()
    local list = self.list
    if not list then
        return
    end

    list.maxOffset = rawget(_G, "BETTERUI_BANK_LIST_MAX_OFFSET") or 30

    local headerPaddingScale = rawget(_G, "BETTERUI_BANK_HEADER_PADDING_SCALE") or 0.75
    if list.SetHeaderPadding and GAMEPAD_HEADER_DEFAULT_PADDING and GAMEPAD_HEADER_SELECTED_PADDING then
        list:SetHeaderPadding(
            GAMEPAD_HEADER_DEFAULT_PADDING * headerPaddingScale,
            GAMEPAD_HEADER_SELECTED_PADDING * headerPaddingScale
        )
    end
    if list.SetUniversalPostPadding and GAMEPAD_DEFAULT_POST_PADDING then
        list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * headerPaddingScale)
    end

    if list.SetFixedCenterOffset then
        -- Align selected row with the tooltip arrow like Inventory/Banking.
        list:SetFixedCenterOffset(-50)
    end
end

---@param list table|nil
---@return nil
function BETTERUI.Vendor.Class:UpdateScrollIndicator(list)
    local targetList = list or self.list
    local listControl = targetList and targetList.control
    if not (listControl and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator) then
        return
    end

    local currentIndex = targetList.targetSelectedIndex
        or (targetList.GetSelectedIndex and targetList:GetSelectedIndex())
        or 1
    local totalItems = (targetList.GetNumItems and targetList:GetNumItems())
        or (targetList.dataList and #targetList.dataList)
        or 0
    local visibleItems = BETTERUI.CIM.CONST.UI.BANKING_VISIBLE_ITEMS or 10

    BETTERUI.CIM.ScrollIndicator.Update(listControl, currentIndex, totalItems, visibleItems)
end

---@return nil
function BETTERUI.Vendor.Class:DeactivateListInput()
    local list = self.list
    if not list then
        return
    end
    if list.SetDirectionalInputEnabled then
        list:SetDirectionalInputEnabled(false)
    end
    if list.Deactivate and (not list.IsActive or list:IsActive()) then
        list:Deactivate()
    end
    ReleaseDirectionalInputRegistrations(list, true)
end

---@return nil
function BETTERUI.Vendor.Class:EnsureColumnHeadersVisible()
    if not (self.header and self.header.columns) then
        return
    end

    local anchorTarget = (self.header and self.header:GetNamedChild("HeaderTabBar"))
        or (self.headerGeneric and self.headerGeneric:GetNamedChild("TabBar"))
        or (self.header and self.header:GetNamedChild("HeaderColumnBar"))

    for _, label in ipairs(self.header.columns) do
        if label then
            if anchorTarget then
                local idx = label.columnIndex
                local xOffset = ResolveHeaderColumnOffset(idx)
                if xOffset then
                    label:ClearAnchors()
                    label:SetAnchor(LEFT, anchorTarget, BOTTOMLEFT, xOffset, BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET)
                end
            end
            label:SetHidden(false)
            label:SetAlpha(1)
            if label.SetDrawLayer then
                label:SetDrawLayer(DL_OVERLAY)
            end
            if label.SetDrawTier then
                label:SetDrawTier(DT_HIGH)
            end
            if label.SetDrawLevel then
                label:SetDrawLevel(10)
            end
        end
    end
end

---@return nil
function BETTERUI.Vendor.Class:DeactivateHeaderKeybinds()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end
    SetTabBarVisualActive(tabBar, false)
    if tabBar.Deactivate then
        tabBar:Deactivate()
    end
    ReleaseDirectionalInputRegistrations(tabBar, true)
    if tabBar.keybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(tabBar.keybindStripDescriptor)
    end
end

---@return nil
function BETTERUI.Vendor.Class:RefreshVendorActionKeybinds()
    if not (KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups) then
        return
    end
    if self.IsSceneShowing and not self:IsSceneShowing() then
        return
    end
    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
end

---@return nil
function BETTERUI.Vendor.Class:RefreshVendorHeaderCarouselLayout()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end

    tabBar.carouselMode = (not BETTERUI.Vendor.GetSetting) or (BETTERUI.Vendor.GetSetting("enableCarousel") ~= false)

    if tabBar.UpdateAnchors then
        local selectedIndex = tabBar.targetSelectedIndex or tabBar.selectedIndex or 1
        tabBar:UpdateAnchors(selectedIndex, true, false, false)
    end
end

---@return nil
function BETTERUI.Vendor.Class:RebuildCategoryHeader()
    local headerGeneric = self.headerGeneric
    if not headerGeneric then
        return
    end

    local headerNavigation = BETTERUI.CIM and BETTERUI.CIM.HeaderNavigation or nil
    local navigationState = BETTERUI.CIM and BETTERUI.CIM.NavigationState or nil

    local mode = self:GetCurrentMode()
    local activeTabs = (BETTERUI.Vendor.GetActiveTabs and BETTERUI.Vendor.GetActiveTabs()) or {}
    local modeTabs = BuildHeaderModeTabs(activeTabs, mode)
    local isSellBuybackOnly = IsSellBuybackOnlyTabs(activeTabs)
    local useUnifiedBuyHeader = (not isSellBuybackOnly)
        and mode ~= BETTERUI.Vendor.MODE.SELL
        and mode ~= BETTERUI.Vendor.MODE.STABLE
        and mode ~= BETTERUI.Vendor.MODE.FENCE_SELL
        and mode ~= BETTERUI.Vendor.MODE.FENCE_LAUNDER
    local categoryMode = useUnifiedBuyHeader and BETTERUI.Vendor.MODE.BUY or mode
    local categories = self:GetModeCategories(categoryMode)
    if useUnifiedBuyHeader
        and categoryMode == BETTERUI.Vendor.MODE.BUY
        and #categories <= 1
        and self._cachedBuyCategories
        and #self._cachedBuyCategories > 1 then
        categories = self._cachedBuyCategories
        self.modeCategories[BETTERUI.Vendor.MODE.BUY] = categories
    end
    local showCategoryEntries = not isSellBuybackOnly
    if not showCategoryEntries and #modeTabs == 0 then
        showCategoryEntries = true
    end
    local selectedIndex = (self.categoryIndexByMode and self.categoryIndexByMode[categoryMode]) or 1
    selectedIndex = zo_clamp(selectedIndex, 1, #categories)
    self.categoryIndexByMode[categoryMode] = selectedIndex
    self.currentCategoryIndex = selectedIndex

    local selectedCategory = categories[selectedIndex]
    local modeEntryCount = #modeTabs
    local selectedHeaderIndex
    if showCategoryEntries then
        selectedHeaderIndex = modeEntryCount + selectedIndex
        if useUnifiedBuyHeader and mode ~= BETTERUI.Vendor.MODE.BUY then
            for modeEntryIndex, tab in ipairs(modeTabs) do
                if tab.mode == mode then
                    selectedHeaderIndex = modeEntryIndex
                    break
                end
            end
        end
    else
        selectedHeaderIndex = 1
        for modeEntryIndex, tab in ipairs(modeTabs) do
            if tab.mode == mode then
                selectedHeaderIndex = modeEntryIndex
                break
            end
        end
    end
    local preferredModeSelection = self._preferredModeHeaderSelectionMode
    if preferredModeSelection and modeEntryCount > 0 then
        for modeEntryIndex, tab in ipairs(modeTabs) do
            if tab.mode == preferredModeSelection then
                selectedHeaderIndex = modeEntryIndex
                break
            end
        end
    end
    self._preferredModeHeaderSelectionMode = nil
    local headerEntries = {}
    for _, tab in ipairs(modeTabs) do
        headerEntries[#headerEntries + 1] = {
            modeSwitchMode = tab.mode,
            name = ResolveModeName(tab.mode),
            iconFile = ResolveModeIcon(tab.mode),
        }
    end
    if showCategoryEntries then
        for categoryIndex, category in ipairs(categories) do
            headerEntries[#headerEntries + 1] = {
                categoryIndex = categoryIndex,
                categoryMode = categoryMode,
                name = category.name,
                iconFile = category.iconFile or DEFAULT_VENDOR_CATEGORY_ICON,
                filterType = category.filterType,
                itemCount = category.itemCount,
            }
        end
    end
    self._vendorHeaderModeEntryCount = modeEntryCount
    self._vendorHeaderCategoryCount = showCategoryEntries and #categories or 0
    self._vendorHeaderCategoryMode = categoryMode
    self._vendorHeaderEntryCount = #headerEntries
    local shouldShowHeaderTabBar = ShouldShowVendorHeaderTabBar(self._vendorHeaderEntryCount)

    self.vendorHeaderData = self.vendorHeaderData or {}
    self.vendorHeaderData.titleText = function()
        if mode == BETTERUI.Vendor.MODE.STABLE then
            return ResolveModeName(mode)
        end
        if mode == BETTERUI.Vendor.MODE.BUYBACK or mode == BETTERUI.Vendor.MODE.REPAIR then
            return zo_strformat("<<1>> - <<2>>", ResolveModeName(mode), "Items")
        end
        if showCategoryEntries and selectedCategory and selectedCategory.name and selectedCategory.name ~= "" then
            return zo_strformat("<<1>> - <<2>>", ResolveModeName(mode), selectedCategory.name)
        end
        return ResolveModeName(mode)
    end
    self.vendorHeaderData.tabBarData = { parent = self }
    local carouselStartOffset = (BETTERUI.Banking and BETTERUI.Banking.CONST and BETTERUI.Banking.CONST.CAROUSEL and BETTERUI.Banking.CONST.CAROUSEL.startOffset)
        or BETTERUI.CIM.CONST.CAROUSEL.startOffset
    local carouselVerticalOffset = (BETTERUI.Banking and BETTERUI.Banking.CONST and BETTERUI.Banking.CONST.CAROUSEL and BETTERUI.Banking.CONST.CAROUSEL.verticalOffset)
        or BETTERUI.CIM.CONST.CAROUSEL.verticalOffset
    self.vendorHeaderData.carouselConfig = {
        enabled = (not BETTERUI.Vendor.GetSetting) or (BETTERUI.Vendor.GetSetting("enableCarousel") ~= false),
        startOffset = carouselStartOffset,
        verticalOffset = carouselVerticalOffset,
        itemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing,
    }
    local coalescedCategoryHandler = nil
    if headerNavigation and headerNavigation.CreateCoalescedHandler then
        coalescedCategoryHandler = headerNavigation.CreateCoalescedHandler({
            delay = BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS,
            onSave = function(instance)
                instance:SaveListPosition()
            end,
            onApply = function(instance, headerIndex)
                local appliedHeaderIndex = zo_clamp(headerIndex or 1, 1, #headerEntries)
                local appliedEntry = headerEntries[appliedHeaderIndex]
                if not appliedEntry then
                    return
                end

                local categoryIndex = appliedEntry.categoryIndex or 1
                local selectedCategoryMode = appliedEntry.categoryMode or instance:GetCurrentMode()
                local shouldSwitchToBuy = useUnifiedBuyHeader
                    and instance:GetCurrentMode() ~= BETTERUI.Vendor.MODE.BUY
                    and selectedCategoryMode == BETTERUI.Vendor.MODE.BUY
                if instance.categoryIndexByMode[selectedCategoryMode] == categoryIndex and not shouldSwitchToBuy then
                    if instance.UpdateVendorHeaderTitle then
                        instance:UpdateVendorHeaderTitle()
                    end
                    return
                end

                instance.categoryIndexByMode[selectedCategoryMode] = categoryIndex
                instance.currentCategoryIndex = categoryIndex
                if instance.UpdateVendorHeaderTitle then
                    instance:UpdateVendorHeaderTitle()
                end

                if shouldSwitchToBuy then
                    instance:SetMode(BETTERUI.Vendor.MODE.BUY)
                    return
                end

                instance:RefreshList()
            end,
            sceneCheck = function()
                if self.IsSceneShowing then
                    return self:IsSceneShowing()
                end
                if self.IsSceneActiveOrShowing then
                    return self:IsSceneActiveOrShowing()
                end
                return true
            end,
        })
    end
    self.vendorHeaderData.onSelectedChanged = function(list)
        if self._suppressVendorHeaderSelection then
            return
        end

        local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(self) or nil
        if navigationState and state and navigationState.ShouldSuppressCallback and navigationState.ShouldSuppressCallback(state) then
            return
        end

        local index = list and list.selectedIndex or selectedHeaderIndex
        index = zo_clamp(index, 1, #headerEntries)
        local selectedEntry = headerEntries[index]
        if not selectedEntry then
            return
        end

        if selectedEntry.modeSwitchMode then
            local targetMode = selectedEntry.modeSwitchMode
            if targetMode ~= mode then
                self._preferredModeHeaderSelectionMode = targetMode
                self:SetMode(targetMode)
                return
            end
            return
        end

        if coalescedCategoryHandler then
            coalescedCategoryHandler(self, list, selectedEntry)
            return
        end

        local categoryIndex = selectedEntry.categoryIndex or 1
        local selectedCategoryMode = selectedEntry.categoryMode or mode
        local shouldSwitchToBuy = useUnifiedBuyHeader
            and mode ~= BETTERUI.Vendor.MODE.BUY
            and selectedCategoryMode == BETTERUI.Vendor.MODE.BUY
        if self.categoryIndexByMode[selectedCategoryMode] == categoryIndex and not shouldSwitchToBuy then
            return
        end

        self.categoryIndexByMode[selectedCategoryMode] = categoryIndex
        self.currentCategoryIndex = categoryIndex
        if shouldSwitchToBuy then
            self:SetMode(BETTERUI.Vendor.MODE.BUY)
            return
        end
        self:RefreshList()
    end

    self._suppressVendorHeaderSelection = true
    if not headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(headerGeneric, self.vendorHeaderData, false)
    end
    if headerGeneric.tabBar then
        headerGeneric.tabBar:Clear()
    end

    for _, entryInfo in ipairs(headerEntries) do
        local entryData = ZO_GamepadEntryData:New(entryInfo.name, entryInfo.iconFile or DEFAULT_VENDOR_CATEGORY_ICON)
        entryData.filterType = entryInfo.filterType
        entryData.itemCount = entryInfo.itemCount
        entryData.countBadgeOffsetY = 3
        entryData.modeSwitchMode = entryInfo.modeSwitchMode
        entryData.categoryIndex = entryInfo.categoryIndex
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(headerGeneric, entryData)
    end

    BETTERUI.GenericHeader.Refresh(headerGeneric, self.vendorHeaderData, false)

    local tabBarControl = headerGeneric:GetNamedChild("TabBar")
    if tabBarControl then
        tabBarControl:SetHidden(not shouldShowHeaderTabBar)
    end

    if headerGeneric.tabBar and shouldShowHeaderTabBar then
        local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(self) or nil
        if state and state.justToggledMode then
            headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(selectedHeaderIndex, true, true)
        else
            if state then
                state.suppressHeaderCallback = true
            end
            headerGeneric.tabBar:SetSelectedIndex(selectedHeaderIndex, true, true)
            if state then
                state.suppressHeaderCallback = false
            end
        end
        self:RefreshVendorHeaderCarouselLayout()
    elseif headerGeneric.tabBar then
        SetTabBarVisualActive(headerGeneric.tabBar, false)
        ReleaseDirectionalInputRegistrations(headerGeneric.tabBar, true)
    end
    local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(self) or nil
    if state then
        state.justToggledMode = false
    end
    self._suppressVendorHeaderSelection = false
    if self.PositionSearchControl then
        self:PositionSearchControl()
    end

    if self:IsSceneShowing() then
        self:EnsureHeaderKeybindsActive()
        if not self._searchModeActive and not self._searchHeaderActive then
            self:EnsureListInputActive()
        end
    end

    self:EnsureColumnHeadersVisible()
end

---@return nil
function BETTERUI.Vendor.Class:ToggleBuySellMode()
    local firstMode, secondMode = nil, nil
    if BETTERUI.Vendor.GetToggleModePair then
        firstMode, secondMode = BETTERUI.Vendor.GetToggleModePair()
    end
    if not firstMode or not secondMode then
        return
    end

    local mode = self:GetCurrentMode()
    if IsStableInteractionActive()
        and firstMode == BETTERUI.Vendor.MODE.BUY
        and secondMode == BETTERUI.Vendor.MODE.STABLE then
        if mode == secondMode then
            self:SetMode(firstMode)
        else
            self:SetMode(secondMode)
        end
        return
    end

    if mode == firstMode then
        self:SetMode(secondMode)
    elseif mode == secondMode then
        self:SetMode(firstMode)
    else
        self:SetMode(firstMode)
    end
end

---@param mode number Vendor mode constant from BETTERUI.Vendor.MODE
function BETTERUI.Vendor.Class:SetMode(mode)
    if not mode then return end
    if self.currentMode == mode then return end

    local headerNavigation = BETTERUI.CIM and BETTERUI.CIM.HeaderNavigation or nil
    local state = headerNavigation and headerNavigation.GetOrCreateState and headerNavigation.GetOrCreateState(self) or nil
    if state then
        state.justToggledMode = true
    end

    -- Save position for outgoing mode
    self:SaveListPosition()

    -- Deactivate the current component if any
    local oldComponent = self:GetActiveComponent()
    if oldComponent and oldComponent.Deactivate then
        oldComponent:Deactivate(self)
    end

    self.currentMode = mode

    if Vendor.multiSelectManager then
        Vendor.multiSelectManager:ExitSelectionMode()
    end

    if mode ~= BETTERUI.Vendor.MODE.BUY and self.DisableStablePreviewMode then
        self:DisableStablePreviewMode()
    end
    if mode ~= BETTERUI.Vendor.MODE.BUY and self.DisableVendorStorePreviewMode then
        self:DisableVendorStorePreviewMode()
    end

    self:ApplyNativeStoreMode(mode)

    -- Activate the new component
    local newComponent = self:GetActiveComponent()
    if newComponent and newComponent.Activate then
        newComponent:Activate(self)
    end

    -- Update keybinds for new mode
    if self:IsSceneShowing() then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end

    self:RebuildCategoryHeader()
    self:RefreshVendorFooter()
end

---@return VendorComponent|nil component The currently active component, or nil
function BETTERUI.Vendor.Class:GetActiveComponent()
    if not self.components then return nil end
    return self.components[self:GetCurrentMode()]
end

---@param mode number Vendor mode constant from BETTERUI.Vendor.MODE
---@param component VendorComponent Component implementing Activate/Deactivate/BuildList
function BETTERUI.Vendor.Class:RegisterComponent(mode, component)
    if not mode or not component then return end
    self.components = self.components or {}
    self.components[mode] = component
end

-- LIST MANAGEMENT

local VENDOR_SORT_COMPARATORS = {
    name = function(a, b)
        local nameA = tostring((a.dataSource and a.dataSource.name) or a.name or "")
        local nameB = tostring((b.dataSource and b.dataSource.name) or b.name or "")
        return nameA < nameB
    end,
    type = function(a, b)
        local typeA = tostring((a.dataSource and a.dataSource.bestItemTypeName) or "")
        local typeB = tostring((b.dataSource and b.dataSource.bestItemTypeName) or "")
        if typeA == typeB then
            return VENDOR_SORT_COMPARATORS.name(a, b)
        end
        return typeA < typeB
    end,
    trait = function(a, b)
        local traitA = tostring((a.dataSource and a.dataSource.traitName) or "")
        local traitB = tostring((b.dataSource and b.dataSource.traitName) or "")
        local blankA = traitA == "" and 1 or 0
        local blankB = traitB == "" and 1 or 0
        if blankA ~= blankB then
            return blankA < blankB
        end
        if traitA == traitB then
            return VENDOR_SORT_COMPARATORS.name(a, b)
        end
        return traitA < traitB
    end,
    stat = function(a, b)
        local statA = (a.dataSource and a.dataSource.statValue) or ""
        local statB = (b.dataSource and b.dataSource.statValue) or ""
        local numA = tonumber(statA)
        local numB = tonumber(statB)
        if numA and numB then
            if numA ~= numB then
                return numA > numB
            end
        elseif statA ~= statB then
            return tostring(statA) < tostring(statB)
        end
        return VENDOR_SORT_COMPARATORS.name(a, b)
    end,
    value = function(a, b)
        local valA = (a.dataSource and (a.dataSource.price or a.dataSource.repairCost or a.dataSource.launderCost or a.dataSource.stackSellPrice or a.dataSource.sellPrice or 0)) or 0
        local valB = (b.dataSource and (b.dataSource.price or b.dataSource.repairCost or b.dataSource.launderCost or b.dataSource.stackSellPrice or b.dataSource.sellPrice or 0)) or 0
        if valA ~= valB then
            return valA > valB
        end
        return VENDOR_SORT_COMPARATORS.name(a, b)
    end,
}

function BETTERUI.Vendor.Class:ApplySortToList()
    if not self.list or not self.list.dataList then return end
    local sortKey = "name"
    local sortOrder = ZO_SORT_ORDER_UP
    if self.sortController and self.sortController.GetActiveSortColumn then
        local column, direction = self.sortController:GetActiveSortColumn()
        if column and direction and direction ~= BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.NONE then
            sortKey = column.key or sortKey
            if direction == BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.DESCENDING then
                sortOrder = ZO_SORT_ORDER_DOWN
            end
        end
    end
    local comparator = VENDOR_SORT_COMPARATORS[sortKey] or VENDOR_SORT_COMPARATORS.name
    if sortOrder == ZO_SORT_ORDER_DOWN then
        local base = comparator
        comparator = function(a, b) return base(b, a) end
    end
    table.sort(self.list.dataList, comparator)
end

--- Clears and rebuilds the list from the active component's BuildList.
---@return nil
function BETTERUI.Vendor.Class:RefreshList()
    if self._suppressListUpdates then
        self._isDirty = true
        return
    end

    if not self.list then return end

    self:ApplyListLayoutTuning()

    local component = self:GetActiveComponent()
    if component and component.GetCategories then
        self:SetModeCategories(self:GetCurrentMode(), component:GetCategories(self))
    else
        self:SetModeCategories(self:GetCurrentMode(), nil)
    end

    -- Clear existing data
    self.list:Clear()

    -- Delegate to the active component's BuildList
    if component and component.BuildList then
        component:BuildList(self)
    end

    local currentMode = self:GetCurrentMode()

    local hasSearchQuery = BETTERUI.Vendor.NormalizeSearchQuery and BETTERUI.Vendor.NormalizeSearchQuery(self.searchQuery) ~= nil
    if self.list.SetNoItemText then
        if hasSearchQuery then
            self.list:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_SEARCH_NO_RESULTS")))
        elseif currentMode == BETTERUI.Vendor.MODE.REPAIR then
            self.list:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_NO_REPAIR_ITEMS")))
        elseif currentMode == BETTERUI.Vendor.MODE.BUYBACK then
            self.list:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_NO_BUYBACK_ITEMS")))
        else
            self.list:SetNoItemText(GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_EMPTY")))
        end
    end

    self:ApplySortToList()
    self.list:Commit()
    self._isDirty = false

    -- Restore list position for current mode and category
    if currentMode and self.list and self.list.dataList and #self.list.dataList > 0 then
        local moduleKey = GetVendorModeModuleKey(currentMode)
        local categoryKey = GetVendorCategoryKey(self)
        local targetIndex = BETTERUI.CIM.PositionManager.RestorePosition(moduleKey, categoryKey, self.list, self.list.dataList)
        if self.list.SetSelectedIndexWithoutAnimation then
            self.list:SetSelectedIndexWithoutAnimation(targetIndex, true, false)
        elseif self.list.SetSelectedIndex then
            self.list:SetSelectedIndex(targetIndex)
        end
    end

    if Vendor.multiSelectManager then
        Vendor.multiSelectManager:RefreshSelections()
    end

    self:EnsureColumnHeadersVisible()
    if self:IsSceneShowing() then
        if not self._searchModeActive and not self._searchHeaderActive then
            self:EnsureListInputActive()
        end
        self:OnItemSelectedChange(self.list, self.list:GetTargetData())
        if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
            KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
        end
    end
    self:UpdateScrollIndicator(self.list)

    if self:GetCurrentMode() == BETTERUI.Vendor.MODE.BUY then
        local entryCount = (self.list.dataList and #self.list.dataList) or 0
        if entryCount == 0 and self:IsSceneActiveOrShowing() then
            local retryCount = (self._buyListRetryCount or 0) + 1
            self._buyListRetryCount = retryCount
            if retryCount <= 20 then
                BETTERUI.Vendor.Tasks:Cancel("buyListRetry")
                BETTERUI.Vendor.Tasks:Schedule("buyListRetry", 180, function()
                    if BETTERUI.Vendor and BETTERUI.Vendor.ShouldAbortDeferredVendorRefresh
                        and BETTERUI.Vendor.ShouldAbortDeferredVendorRefresh(self, BETTERUI.Vendor.MODE.BUY) then
                        return
                    end
                    if BETTERUI.Vendor and BETTERUI.Vendor.EnsureNativeStoreComponents then
                        BETTERUI.Vendor.EnsureNativeStoreComponents("storeTextSearch")
                    end
                    self:ApplyNativeStoreMode(BETTERUI.Vendor.MODE.BUY)
                    self:RefreshList()
                end)
            end
        else
            self._buyListRetryCount = 0
        end
    else
        self._buyListRetryCount = 0
    end
end

---@param selectedData table|nil
---@return boolean
function BETTERUI.Vendor.Class:CanPreviewStableStoreEntry(selectedData)
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
function BETTERUI.Vendor.Class:SetVendorPreviewBlurActive(shouldActivateVendorBlur)
    if not FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT then
        return
    end

    if shouldActivateVendorBlur then
        SCENE_MANAGER:AddFragment(FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT)
    else
        SCENE_MANAGER:RemoveFragmentImmediately(FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT)
    end
end

---@param hidden boolean
---@return nil
function BETTERUI.Vendor.Class:SetVendorStorePreviewUiHidden(hidden)
    if self.SetStablePreviewUiHidden then
        self:SetStablePreviewUiHidden(hidden)
    end
end

---@param selectedData table|nil
---@return boolean
function BETTERUI.Vendor.Class:CanPreviewVendorStoreEntry(selectedData)
    if IsStableInteractionActive() or self:GetCurrentMode() ~= BETTERUI.Vendor.MODE.BUY then
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

---@return nil
function BETTERUI.Vendor.Class:DisableVendorStorePreviewMode()
    self:SetVendorPreviewBlurActive(false)
    self:SetVendorStorePreviewUiHidden(false)

    if not ITEM_PREVIEW_GAMEPAD or not ITEM_PREVIEW_GAMEPAD.IsInteractionCameraPreviewEnabled then
        return
    end
    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        return
    end

    ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(
        false,
        FRAME_TARGET_STORE_GAMEPAD_FRAGMENT,
        FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
        GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT
    )
end

---@param selectedData table|nil
---@return nil
function BETTERUI.Vendor.Class:UpdateVendorStorePreview(selectedData)
    if IsStableInteractionActive() then
        return
    end
    if not (ITEM_PREVIEW_GAMEPAD and ZO_StoreManager_DoPreviewAction) then
        return
    end
    if self:GetCurrentMode() ~= BETTERUI.Vendor.MODE.BUY then
        self:DisableVendorStorePreviewMode()
        return
    end
    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        self:SetVendorPreviewBlurActive(false)
        self:SetVendorStorePreviewUiHidden(false)
        return
    end

    if self:CanPreviewVendorStoreEntry(selectedData) then
        local ds = selectedData and (selectedData.dataSource or selectedData) or nil
        local storeEntryIndex = ds and (ds.slotIndex or ds.entryIndex) or nil
        local executeAction = rawget(_G, "ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE")
        if storeEntryIndex and executeAction ~= nil then
            ZO_StoreManager_DoPreviewAction(executeAction, storeEntryIndex)
        end
        self:SetVendorPreviewBlurActive(true)
        self:SetVendorStorePreviewUiHidden(true)
    else
        self:DisableVendorStorePreviewMode()
    end
end

---@return nil
function BETTERUI.Vendor.Class:ToggleVendorStorePreviewMode()
    if IsStableInteractionActive() or self:GetCurrentMode() ~= BETTERUI.Vendor.MODE.BUY then
        return
    end
    if not ITEM_PREVIEW_GAMEPAD then
        return
    end

    local willPreviewBeDisabled = ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
    self:SetVendorPreviewBlurActive(willPreviewBeDisabled)
    ITEM_PREVIEW_GAMEPAD:ToggleInteractionCameraPreview(
        FRAME_TARGET_STORE_GAMEPAD_FRAGMENT,
        FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
        GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT
    )

    local targetData = self.list and self.list.GetTargetData and self.list:GetTargetData() or nil
    self:UpdateVendorStorePreview(targetData)
end

---@param hidden boolean
---@return nil
function BETTERUI.Vendor.Class:SetStablePreviewUiHidden(hidden)
    if self._stablePreviewUiHidden == hidden then
        return
    end
    self._stablePreviewUiHidden = hidden

    if self.control and self.control.SetHidden then
        self.control:SetHidden(hidden)
    end

    local scene = self.scene
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

---@return nil
function BETTERUI.Vendor.Class:DisableStablePreviewMode()
    self:SetStablePreviewUiHidden(false)

    if not ITEM_PREVIEW_GAMEPAD then
        return
    end
    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        return
    end

    ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(
        false,
        FRAME_TARGET_STORE_GAMEPAD_FRAGMENT,
        FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
        GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT
    )
end

---@return nil
function BETTERUI.Vendor.Class:ToggleStablePreviewMode()
    if not ITEM_PREVIEW_GAMEPAD then
        return
    end
    if not IsStableInteractionActive() or self:GetCurrentMode() ~= BETTERUI.Vendor.MODE.BUY then
        return
    end

    ITEM_PREVIEW_GAMEPAD:ToggleInteractionCameraPreview(
        FRAME_TARGET_STORE_GAMEPAD_FRAGMENT,
        FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
        GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT
    )

    local isPreviewActive = ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
    self:SetStablePreviewUiHidden(isPreviewActive)
    self:UpdateStablePreview()
end

---@return nil
function BETTERUI.Vendor.Class:UpdateStablePreview()
    if not (ITEM_PREVIEW_GAMEPAD and ZO_StoreManager_DoPreviewAction) then
        return
    end
    if not IsStableInteractionActive() or self:GetCurrentMode() ~= BETTERUI.Vendor.MODE.BUY then
        self:DisableStablePreviewMode()
        return
    end

    if not ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        self:SetStablePreviewUiHidden(false)
        return
    end

    local selectedData = self.list and self.list:GetTargetData() or nil
    if self:CanPreviewStableStoreEntry(selectedData) then
        local ds = selectedData and (selectedData.dataSource or selectedData) or nil
        local storeEntryIndex = ds and (ds.slotIndex or ds.entryIndex) or nil
        local executeAction = rawget(_G, "ZO_STORE_MANAGER_PREVIEW_ACTION_EXECUTE")
        if storeEntryIndex and executeAction ~= nil then
            ZO_StoreManager_DoPreviewAction(executeAction, storeEntryIndex)
        end
        self:SetStablePreviewUiHidden(true)
    else
        self:DisableStablePreviewMode()
    end
end

---@param _list table
---@param selectedData table|nil
---@return nil
function BETTERUI.Vendor.Class:OnItemSelectedChange(_list, selectedData)
    if not GAMEPAD_TOOLTIPS then
        return
    end

    if BETTERUI.Inventory and BETTERUI.Inventory.CleanupEnhancedTooltip then
        BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
        BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
    end

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    if not ds then
        if IsStableInteractionActive() then
            self:UpdateStablePreview()
        else
            self:UpdateVendorStorePreview(nil)
        end
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        self:RefreshVendorActionKeybinds()
        return
    end

    local mode = self:GetCurrentMode()
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
    if IsStableInteractionActive()
        and mode == BETTERUI.Vendor.MODE.BUY
        and ITEM_PREVIEW_GAMEPAD
        and ITEM_PREVIEW_GAMEPAD.IsInteractionCameraPreviewEnabled
        and ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
        self:UpdateStablePreview()
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        self:RefreshVendorActionKeybinds()
        return
    end

    if mode == BETTERUI.Vendor.MODE.STABLE and ds.trainingType and GAMEPAD_TOOLTIPS.LayoutRidingSkill then
        GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:LayoutRidingSkill(
            GAMEPAD_LEFT_TOOLTIP,
            ds.trainingType,
            ds.bonus or 0,
            ds.maxBonus or 0
        )
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        if tooltip then
            tooltip._betterui_itemLink = nil
            tooltip._betterui_bagId = nil
            tooltip._betterui_slotIndex = nil
            tooltip._betterui_storeStackCount = nil
            tooltip._betterui_priceRendered = true
        end
    elseif (mode == BETTERUI.Vendor.MODE.BUY or mode == BETTERUI.Vendor.MODE.BUYBACK) and GAMEPAD_TOOLTIPS.LayoutStoreWindowItem then
        if mode == BETTERUI.Vendor.MODE.BUY
            and not IsStableInteractionActive()
            and ITEM_PREVIEW_GAMEPAD
            and ITEM_PREVIEW_GAMEPAD.IsInteractionCameraPreviewEnabled
            and ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled() then
            local targetData = self.list and self.list.GetTargetData and self.list:GetTargetData() or selectedData
            self:UpdateVendorStorePreview(targetData)
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
            self:RefreshVendorActionKeybinds()
            return
        end

        if ds.dataSource == nil then
            ds.dataSource = ds
        end
        GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:LayoutStoreWindowItem(GAMEPAD_LEFT_TOOLTIP, ds)
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        if tooltip then
            tooltip._betterui_itemLink = ds.itemLink or ((GetStoreItemLink and ds.entryIndex) and GetStoreItemLink(ds.entryIndex)) or nil
            tooltip._betterui_bagId = nil
            tooltip._betterui_slotIndex = nil
            tooltip._betterui_storeStackCount = ds.stackCount or ds.stack or 1
            tooltip._betterui_priceRendered = false
        end
    elseif ds.bagId and ds.slotIndex and GAMEPAD_TOOLTIPS.LayoutBagItem then
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
        if tooltip then
            tooltip._betterui_bagId = ds.bagId
            tooltip._betterui_slotIndex = ds.slotIndex
            tooltip._betterui_itemLink = GetItemLink(ds.bagId, ds.slotIndex)
            tooltip._betterui_storeStackCount = nil
            tooltip._betterui_priceRendered = false
        end
    else
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    end

    if BETTERUI.Inventory and BETTERUI.Inventory.UpdateTooltipEquippedText then
        BETTERUI.Inventory.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)
    end

    -- Vendor uses a single visible tooltip panel. Force the right tooltip
    -- inactive so equipped-comparison content cannot overlap the primary panel.
    local rightTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
    if rightTooltip then
        rightTooltip._betterui_itemLink = nil
        rightTooltip._betterui_bagId = nil
        rightTooltip._betterui_slotIndex = nil
        rightTooltip._betterui_storeStackCount = nil
        rightTooltip._betterui_priceRendered = true
    end
    if GAMEPAD_TOOLTIPS.ClearStatusLabel then
        GAMEPAD_TOOLTIPS:ClearStatusLabel(GAMEPAD_RIGHT_TOOLTIP)
    end
    if IsStableInteractionActive() then
        self:UpdateStablePreview()
    else
        self:UpdateVendorStorePreview(selectedData)
    end
    self:RefreshVendorActionKeybinds()
end

--- Suppresses list refreshes until FlushListUpdates is called.
---@return nil
function BETTERUI.Vendor.Class:SuppressListUpdates()
    self._suppressListUpdates = true
    self._isDirty = false
end

--- Releases suppressed list updates and refreshes if dirty.
---@return nil
function BETTERUI.Vendor.Class:FlushListUpdates()
    self._suppressListUpdates = false
    if self._isDirty then
        self:RefreshList()
    end
end

-- STORE/FENCE STATE QUERIES

---@return boolean isFence True if current mode is a fence mode
function BETTERUI.Vendor.Class:IsFenceMode()
    local mode = self:GetCurrentMode()
    return mode == BETTERUI.Vendor.MODE.FENCE_SELL
        or mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER
end

---@return number currencyType1 Primary currency type
---@return number|nil currencyType2 Secondary currency type, or nil
function BETTERUI.Vendor.Class:GetStoreCurrencyTypes()
    if GetStoreUsedCurrencyTypes then
        return GetStoreUsedCurrencyTypes()
    end
    return CURT_MONEY, nil
end

---@param cost number|nil Item cost to check
---@param currencyType number|nil Currency type (defaults to CURT_MONEY)
---@return boolean canAfford True if player can afford the cost
function BETTERUI.Vendor.Class:CanAfford(cost, currencyType)
    if not cost or cost <= 0 then return true end
    currencyType = currencyType or CURT_MONEY
    local current = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER) or 0
    return current >= cost
end

---@return boolean hasSpace True if backpack has at least one free slot
function BETTERUI.Vendor.Class:HasInventorySpace()
    local numFree = GetNumBagFreeSlots(BAG_BACKPACK)
    return numFree and numFree > 0
end


--- Initializes the vendor footer by relabelling the embedded Withdraw/Deposit
--- controls to show buy/sell list toggles.
--- Called once during Init after the window is created.
---@return nil
function BETTERUI.Vendor.Class:InitVendorFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- Keep centre divider visible for buy/sell list switching.
    local dividerCentre = footerRoot:GetNamedChild("DividerCentre")
    if dividerCentre then dividerCentre:SetHidden(false) end

    -- LEFT SIDE: Relabel "WITHDRAW" -> Buy list
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", function()
                if BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction() then
                    self:SetMode(BETTERUI.Vendor.MODE.FENCE_SELL)
                    return
                end
                self:SetMode(BETTERUI.Vendor.MODE.BUY)
            end)

            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY") or "SI_BETTERUI_VENDOR_TAB_BUY"))
            end
        end
        -- Keep current icon style.
        local icon = withdraw:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/currency/currency_gold_64.dds")
        end
    end

    -- RIGHT SIDE: Relabel "DEPOSIT" -> Sell list
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", function()
                if BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction() then
                    self:SetMode(BETTERUI.Vendor.MODE.FENCE_LAUNDER)
                    return
                end
                if IsStableInteractionActive() then
                    self:SetMode(BETTERUI.Vendor.MODE.STABLE)
                else
                    self:SetMode(BETTERUI.Vendor.MODE.SELL)
                end
            end)

            local label = btn:GetNamedChild("Label")
            if label then
                if IsStableInteractionActive() then
                    label:SetText(GetString(rawget(_G, "SI_STABLE_STABLES_TAB") or "SI_STABLE_STABLES_TAB"))
                else
                    label:SetText(GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL") or "SI_BETTERUI_VENDOR_TAB_SELL"))
                end
            end
        end
        -- Keep current icon style.
        local icon = deposit:GetNamedChild("Icon")
        if icon then
            if IsStableInteractionActive() then
                icon:SetTexture(ResolveStableInteractionIcon())
            else
                icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
            end
        end
    end

    self:RefreshVendorFooter()
end

--- Refreshes the vendor footer values (gold amount, bag capacity, or fence transaction counts).
--- Called on scene showing and after inventory changes.
---@return nil
function BETTERUI.Vendor.Class:RefreshVendorFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    local currentMode = self:GetCurrentMode()
    local isStableInteraction = IsStableInteractionActive()
    local isFenceInteraction = BETTERUI.Vendor.IsFenceInteraction and BETTERUI.Vendor.IsFenceInteraction()

    local isSecondMode, isFirstListMode
    if isFenceInteraction then
        isSecondMode    = currentMode == BETTERUI.Vendor.MODE.FENCE_LAUNDER
        isFirstListMode = currentMode == BETTERUI.Vendor.MODE.FENCE_SELL
    else
        local secondListMode = isStableInteraction and BETTERUI.Vendor.MODE.STABLE or BETTERUI.Vendor.MODE.SELL
        isSecondMode    = currentMode == secondListMode
        isFirstListMode = currentMode == BETTERUI.Vendor.MODE.BUY
            or (isStableInteraction and currentMode == BETTERUI.Vendor.MODE.REPAIR)
    end
    local isTwoPaneMode = isFirstListMode or isSecondMode
    local activeColor   = { 1, 1, 1, 1 }
    local inactiveColor = BETTERUI_BANK_INACTIVE_LABEL_COLOR or { 0.35, 0.35, 0.35, 1 }

    local selectBg = footerRoot:GetNamedChild("SelectBg")
    if selectBg then
        local rotation = 0
        if isSecondMode then
            rotation = BETTERUI_BANK_DEPOSIT_ARROW_ROTATION or 0
        end
        selectBg:SetTextureRotation(rotation)
    end

    -- LEFT SIDE: Gold amount (regular/stable) or fence sell transaction count
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
                    local fenceSellComp = self.components and self.components[BETTERUI.Vendor.MODE.FENCE_SELL]
                    if fenceSellComp and fenceSellComp.GetFooterText then
                        spaceLabel:SetText(fenceSellComp:GetFooterText())
                    else
                        spaceLabel:SetText("")
                    end
                else
                    local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
                    spaceLabel:SetText("|t24:24:esoui/art/currency/currency_gold_32.dds|t " ..
                        BETTERUI.DisplayNumber(gold))
                end
            end
        end
    end

    -- RIGHT SIDE: Bag capacity (regular/stable) or fence launder transaction count
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
                    local fenceLaunderComp = self.components and self.components[BETTERUI.Vendor.MODE.FENCE_LAUNDER]
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
                icon:SetTexture(ResolveStableInteractionIcon())
            else
                icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
            end
        end
    end
end
