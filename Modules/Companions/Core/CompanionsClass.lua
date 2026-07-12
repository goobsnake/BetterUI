--[[
File: Modules/Companions/Core/CompanionsClass.lua
Purpose: Base class and shared constants for the Companions module.
         Companion list/category behaviors are implemented in
         Core/CompanionListManager.lua.

ESO Reference: ZO_CompanionEquipment_Gamepad in
  esoui/ingame/companion/gamepad/companionequipment_gamepad.lua
]]

if not BETTERUI.Companions then BETTERUI.Companions = {} end

-- SCENE CONSTANTS
BETTERUI_COMPANION_EQUIP_SCENE_NAME = "BETTERUI_CompanionEquipment"

BETTERUI.Companions.COMPANION_INTERACTION = {
    type = "Companion",
    interactTypes = { INTERACTION_COMPANION_MENU },
}

-- MODULE-SCOPE TASK MANAGER
local CompanionsDeferredTask = assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask,
    "BetterUI: CIM.DeferredTask must load before Companions/Core/CompanionsClass")
local function EnsureCompanionsTaskManager()
    if not BETTERUI.Companions._taskManager then
        BETTERUI.Companions._taskManager = CompanionsDeferredTask.CreateManager()
    end
    return BETTERUI.Companions._taskManager
end
BETTERUI.Companions.EnsureTaskManager = EnsureCompanionsTaskManager
BETTERUI.Companions.Tasks = BETTERUI.Companions.Tasks or CompanionsDeferredTask.CreateLazyManagerProxy(EnsureCompanionsTaskManager)

---@class BETTERUI.Companions.Class : BETTERUI.CIM.GenericWindow
BETTERUI.Companions.Class = BETTERUI.CIM.GenericWindow:Subclass()
BETTERUI.Companions.Class.SEARCH_LIFECYCLE = {
    accept = "AcceptSearchAndReturnToList",
    clear = "ClearSearchInput",
    exit = "ExitSearchMode",
    headerActive = "IsHeaderFocused",
    requestEnter = "RequestHeaderFocus",
    onEnter = "OnHeaderEntered",
}

function BETTERUI.Companions.Class:New(...)
    local obj = BETTERUI.CIM.GenericWindow.New(self, ...)
    return obj
end

--- Builds the Companion scene from the same XML-materialized shell used by Inventory.
function BETTERUI.Companions.Class:Initialize(control, sceneName)
    assert(control, "BetterUI: BUI_GpCmp XML control must load before Companion initialization")
    self.windowName = control.GetName and control:GetName() or "BUI_GpCmp"
    self.sceneName = sceneName
    self.positionModuleKey = "GenericWindow:" .. tostring(sceneName or self.windowName or "default")
    self.currentCategoryKey = nil

    self.control = control
    local mask = self.control:GetNamedChild("Mask")
    local container = mask and mask:GetNamedChild("Container")
    assert(container, "BetterUI: Companion Inventory shell is missing its Container")
    self.control.container = container

    self.header = container:GetNamedChild("HeaderContainer")
    local templateListContainer = container:GetNamedChild("ListContainer")
    self.footer = container:GetNamedChild("FooterContainer")
    self.headerGeneric = self.header and (self.header.header or self.header:GetNamedChild("Header"))
    assert(self.header and self.headerGeneric and self.footer and templateListContainer,
        "BetterUI: Companion Inventory shell hierarchy is incomplete")

    -- Inventory materializes its active Main list after the static screen shell
    -- loads. Do the same here; the template-owned ListContainer is only a shell
    -- placeholder and does not participate in Inventory's live list lifecycle.
    templateListContainer:SetHidden(true)
    local listContainer = CreateControlFromVirtual(
        "$(parent)Main",
        self.control.container,
        "BETTERUI_Gamepad_ParametricList_Screen_ListContainer"
    )
    listContainer:SetHidden(false)
    self.listContainer = listContainer
    local listControl = listContainer.list or listContainer:GetNamedChild("List")
    assert(listControl, "BetterUI: Companion Main list control was not materialized")

    self.header.columns = {}
    self.list = BETTERUI_VerticalItemParametricScrollList:New(listControl)
    self.list.owner = self
    self.list.alignToScreenCenterExpectedEntryHalfHeight = 15
    if self.list.SetAlignToScreenCenter then
        self.list:SetAlignToScreenCenter(true, 30)
    end

    self.footerMode = BETTERUI.CIM.UnifiedFooter.MODE.CURRENCY
    self:SetupUnifiedFooter()
end

local COMPANION_COLUMN_CONTROL_NAMES = {
    "Column1Label", "Column2Label", "Column4Label", "Column6Label", "Column5Label",
}

--- Reuses Inventory's XML-owned column labels without re-anchoring them.
function BETTERUI.Companions.Class:AddColumn(columnName, xOffset)
    local columnIndex = #self.header.columns + 1
    local columnBar = self.headerGeneric and self.headerGeneric:GetNamedChild("ColumnBar")
    local controlName = COMPANION_COLUMN_CONTROL_NAMES[columnIndex]
    local label = columnBar and controlName and columnBar:GetNamedChild(controlName)
    if not label then return end

    self.header.columns[columnIndex] = label
    label:SetText(columnName)
    label:SetMouseEnabled(true)
    label.columnIndex = columnIndex
    label.owner = self

    local widths = BETTERUI.CIM.CONST.LAYOUT.COLUMN_WIDTHS
    label:SetDimensions(widths[columnIndex] or 100, 30)
    if not label._betteruiColumnMouseUpHooked then
        label._betteruiColumnMouseUpHooked = true
        ZO_PostHookHandler(label, "OnMouseUp", function(control, button, upInside)
            if not (upInside and button == MOUSE_BUTTON_INDEX_LEFT) then return end
            local owner = control.owner
            local integration = BETTERUI.CIM and BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortIntegration
            local controller = (integration and integration.EnsureControllerForOwner
                    and integration.EnsureControllerForOwner(owner))
                or (owner and (owner.headerSortController or owner.sortController))
            if controller then
                controller:ToggleSortForColumn(control.columnIndex)
                PlaySound(SOUNDS.DEFAULT_CLICK)
            end
        end)
    end
end

---@return boolean showing True if the companion scene is currently showing
function BETTERUI.Companions.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_COMPANION_EQUIP_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

-- FOOTER / EQUIPMENT HEADER

function BETTERUI.Companions.Class:SetupUnifiedFooter()
    local footerContainer = self.control.container:GetNamedChild("FooterContainer")
    if not (footerContainer and footerContainer.unifiedFooter) then return end

    self.unifiedFooterController = footerContainer.unifiedFooter
    if not self.unifiedFooterController._initialized and footerContainer.footer
        and self.unifiedFooterController.SetupFooter then
        self.unifiedFooterController:SetupFooter(footerContainer.footer)
    end
    self.unifiedFooterController:SetCapacityBagId(BAG_COMPANION_WORN)
    self.unifiedFooterController:SetMode(BETTERUI.CIM.UnifiedFooter.MODE.CURRENCY)
    self.unifiedFooterController:Refresh()
end

function BETTERUI.Companions.Class:RefreshCompanionFooter()
    if self.unifiedFooterController then
        self.unifiedFooterController:Refresh()
    end
end

local function GetCompanionHeaderControl(instance, name)
    local titleContainer = instance.headerGeneric and instance.headerGeneric:GetNamedChild("TitleContainer")
    return titleContainer and titleContainer:GetNamedChild(name)
end

function BETTERUI.Companions.Class:SetCompanionHeaderControlHidden(name, hidden)
    local control = GetCompanionHeaderControl(self, name)
    if control then control:SetHidden(hidden) end
end

local EMPTY_WEAPON_SLOT_TEXTURES = {
    [EQUIP_SLOT_MAIN_HAND] = "EsoUI/Art/CharacterWindow/gearSlot_mainHand.dds",
    [EQUIP_SLOT_OFF_HAND] = "EsoUI/Art/CharacterWindow/gearSlot_offHand.dds",
}

local function GetCompanionWeaponHeaderIcon(hasItem, icon, equipSlot)
    if hasItem and icon and icon ~= "" then
        return icon
    end
    if ZO_Character_GetEmptyEquipSlotTexture then
        local emptyIcon = ZO_Character_GetEmptyEquipSlotTexture(equipSlot)
        if emptyIcon and emptyIcon ~= "" then
            return emptyIcon
        end
    end
    return EMPTY_WEAPON_SLOT_TEXTURES[equipSlot]
end

function BETTERUI.Companions.Class:RefreshCompanionWeaponHeader()
    if not (self.headerGeneric and BETTERUI.GenericHeader and GetWornItemInfo) then return end

    local mainHasItem, mainIcon = GetWornItemInfo(BAG_COMPANION_WORN, EQUIP_SLOT_MAIN_HAND)
    local offHasItem, offIcon = GetWornItemInfo(BAG_COMPANION_WORN, EQUIP_SLOT_OFF_HAND)
    mainIcon = GetCompanionWeaponHeaderIcon(mainHasItem, mainIcon, EQUIP_SLOT_MAIN_HAND)
    offIcon = GetCompanionWeaponHeaderIcon(offHasItem, offIcon, EQUIP_SLOT_OFF_HAND)
    BETTERUI.GenericHeader.SetEquipText(self.headerGeneric, true)
    BETTERUI.GenericHeader.SetEquippedIcons(self.headerGeneric, mainIcon, offIcon, nil)

    self:SetCompanionHeaderControlHidden("EquipText", false)
    self:SetCompanionHeaderControlHidden("MainHandIcon", false)
    self:SetCompanionHeaderControlHidden("OffHandIcon", false)
    self:SetCompanionHeaderControlHidden("PoisonIcon", true)
    self:SetCompanionHeaderControlHidden("BackupEquipText", true)
    self:SetCompanionHeaderControlHidden("BackupMainHandIcon", true)
    self:SetCompanionHeaderControlHidden("BackupOffHandIcon", true)
    self:SetCompanionHeaderControlHidden("BackupPoisonIcon", true)
end

-- SEARCH FOCUS HELPERS

-- Search-focus tracer via the shared MakeTracer (BUI-CONS-002): module/feature/
-- scene/gamepad/table-form last-action match the former copy; category is KEYBIND
-- (ACTION fallback). Scene now resolves through CIM.Utils.
local TraceCompanionClass = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{
        module = "Companions",
        feature = "companion-search",
        category = (BETTERUI.Log.CATEGORY or {}).KEYBIND or (BETTERUI.Log.CATEGORY or {}).ACTION or "KEYBIND",
    }
    or function() end

local function GetCompanionSearchStickY()
    -- Use ESOUI's directional-input arbitration first so consumed input and
    -- mostly-horizontal stick movement cannot leak into the vertical search
    -- transition. The raw stick query remains a compatibility fallback.
    if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.GetY then
        local ok, value = pcall(
            DIRECTIONAL_INPUT.GetY,
            DIRECTIONAL_INPUT,
            ZO_DI_LEFT_STICK_NO_KEYBOARD
        )
        if ok then
            return value or 0
        end
    end
    if type(GetGamepadLeftStickY) == "function" then
        return GetGamepadLeftStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
    end
    return 0
end

function BETTERUI.Companions.Class:EnsureSearchMovementController()
    if self._companionSearchMovementController then
        return true
    end
    if not ZO_MovementController then
        return false
    end
    self._companionSearchMovementController = ZO_MovementController:New(
        MOVEMENT_CONTROLLER_DIRECTION_VERTICAL,
        nil,
        GetCompanionSearchStickY
    )
    return true
end

function BETTERUI.Companions.Class:UpdateSearchDirectionalInput()
    if not (self._searchModeActive or self._searchHeaderActive) or not self:IsSceneShowing() then
        return false
    end
    if not self:EnsureSearchMovementController() then
        return false
    end

    local result = self._companionSearchMovementController:CheckMovement()
    if result == MOVEMENT_CONTROLLER_MOVE_NEXT then
        if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Consume then
            DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK, ZO_DI_LEFT_STICK_NO_KEYBOARD)
        end
        return self:AcceptSearchAndReturnToList()
    elseif result == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then
        if DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Consume then
            DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK, ZO_DI_LEFT_STICK_NO_KEYBOARD)
        end
        return true
    end
    return false
end

function BETTERUI.Companions.Class:SetSearchDirectionalInputUpdate(enabled)
    local inputObject = self._companionSearchDirectionalInputObject
    if inputObject and DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening
        and DIRECTIONAL_INPUT.Deactivate then
        local safety = 0
        while DIRECTIONAL_INPUT:IsListening(inputObject) and safety < 4 do
            DIRECTIONAL_INPUT:Deactivate(inputObject)
            safety = safety + 1
        end
    end
    if enabled ~= true then
        return false
    end
    if not self:EnsureSearchMovementController()
        or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.Activate) then
        return false
    end

    local control = self.textSearchHeaderControl or self.control
    if not control then
        return false
    end
    if not inputObject then
        inputObject = { owner = self }
        function inputObject:UpdateDirectionalInput()
            local owner = self.owner
            if owner then
                owner:UpdateSearchDirectionalInput()
            end
        end
        self._companionSearchDirectionalInputObject = inputObject
    end
    inputObject.owner = self
    DIRECTIONAL_INPUT:Activate(inputObject, control)
    return true
end

function BETTERUI.Companions.Class:EnterSearchMode()
    if not self.textSearchHeaderControl or self.textSearchHeaderControl:IsHidden() then
        TraceCompanionClass("companions.search_mode", "enter_skipped", {
            fn = "Companions.Class:EnterSearchMode",
            reason = "missingOrHiddenHeader",
            hasHeader = self.textSearchHeaderControl ~= nil,
        })
        return
    end
    if self._searchModeActive or self._searchHeaderActive then
        TraceCompanionClass("companions.search_mode", "enter_skipped", {
            fn = "Companions.Class:EnterSearchMode",
            reason = "alreadyActive",
        })
        return
    end
    TraceCompanionClass("companions.search_mode", "enter_begin", {
        fn = "Companions.Class:EnterSearchMode",
        hadSearchMode = false,
        hadHeaderActive = false,
        hasSearchKeybinds = self.textSearchKeybindStripDescriptor ~= nil,
        hasCoreKeybinds = self.coreKeybinds ~= nil,
    })

    -- Claim lifecycle ownership before Activate/TakeFocus. Taking edit-box focus
    -- synchronously fires OnFocusGained, which routes back through OnHeaderEntered.
    self._searchModeActive = true
    self._searchHeaderActive = true

    -- Match Inventory's RequestEnterHeader path: the list must be inactive while
    -- the search header owns focus. Deactivation also applies the standard dimmed
    -- parametric-list presentation and prevents refresh selection callbacks from
    -- returning focus to the rows.
    self:DeactivateListInput()
    self:SetSearchDirectionalInputUpdate(true)

    if self.textSearchHeaderFocus then
        if not self.textSearchHeaderFocus.IsActive or not self.textSearchHeaderFocus:IsActive() then
            self.textSearchHeaderFocus:Activate()
        end
        if self.SetTextSearchFocused then
            self:SetTextSearchFocused(true)
        end
    end
    if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP and self.coreKeybinds then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.coreKeybinds)
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
        TraceCompanionClass("companions.search_keybinds", "swapped_to_search", {
            fn = "Companions.Class:EnterSearchMode",
            removedCore = true,
            addedSearch = true,
        })
    end
    -- Search and the category carousel coexist in Inventory. Keep the tab bar's
    -- LB/RB group registered while only the item-action group is displaced.
    self:EnsureHeaderKeybindsActive()
    TraceCompanionClass("companions.search_mode", "entered", {
        fn = "Companions.Class:EnterSearchMode",
        searchModeActive = self._searchModeActive == true,
        searchHeaderActive = self._searchHeaderActive == true,
    })
end

function BETTERUI.Companions.Class:ExitSearchMode()
    if not self._searchModeActive and not self._searchHeaderActive then
        -- Focus callbacks can clear the lifecycle flags before the scoped stick
        -- listener is released. Teardown must follow actual DI ownership rather
        -- than treating the flags as proof that cleanup already happened.
        self:SetSearchDirectionalInputUpdate(false)
        TraceCompanionClass("companions.search_mode", "exit_skipped", {
            fn = "Companions.Class:ExitSearchMode",
            reason = "notActive",
        })
        return
    end
    TraceCompanionClass("companions.search_mode", "exit_begin", {
        fn = "Companions.Class:ExitSearchMode",
        hadSearchMode = self._searchModeActive == true,
        hadHeaderActive = self._searchHeaderActive == true,
        hasRemovedGroups = self._searchRemovedKeybindGroups ~= nil,
    })

    -- Clear lifecycle ownership before Deactivate/LoseFocus. Those calls
    -- synchronously fire OnFocusLost, which otherwise re-enters this method.
    self._searchModeActive = false
    self._searchHeaderActive = false
    self:SetSearchDirectionalInputUpdate(false)

    if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.textSearchKeybindStripDescriptor)
    end
    -- Restore exactly the groups the search-mode cleanup removed -- but ONLY while
    -- the scene is still showing. ExitSearchMode also runs during scene teardown
    -- (onHiding -> CallCompanionSearchLifecycle "exit"); by then SceneLifecycleManager
    -- has already removed our groups, so re-adding here would leak the Companions
    -- keybinds onto the next scene (Inventory/Banking). Still clear the saved-group
    -- state either way so a later entry can never restore a stale set.
    local sceneShowing = (not self.IsSceneShowing) or self:IsSceneShowing()
    if self._searchRemovedKeybindGroups then
        if sceneShowing then
            BETTERUI.Interface.RestoreKeybindGroups(self._searchRemovedKeybindGroups)
        end
        self._searchRemovedKeybindGroups = nil
    end
    if sceneShowing and self.coreKeybinds and KEYBIND_STRIP then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.coreKeybinds)
    end
    if self.textSearchHeaderFocus then
        self.textSearchHeaderFocus:Deactivate()
    end
    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(false)
    end
    self:EnsureListInputActive()
    self:EnsureHeaderKeybindsActive()
    if self.coreKeybinds and KEYBIND_STRIP then
        BETTERUI.Interface.UpdateKeybindGroup(self.coreKeybinds)
    end
    TraceCompanionClass("companions.search_mode", "exited", {
        fn = "Companions.Class:ExitSearchMode",
        searchModeActive = self._searchModeActive == true,
        searchHeaderActive = self._searchHeaderActive == true,
        hasCoreKeybinds = self.coreKeybinds ~= nil,
    })
end

function BETTERUI.Companions.Class:AcceptSearchAndReturnToList()
    if not self._searchModeActive and not self._searchHeaderActive then
        return false
    end
    self:ExitSearchMode()
    return true
end

function BETTERUI.Companions.Class:ExitSearchFocus()
    self:ExitSearchMode()
end

function BETTERUI.Companions.Class:IsHeaderFocused()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        return self.textSearchHeaderFocus:IsActive()
    end
    return self._searchModeActive == true
end

function BETTERUI.Companions.Class:IsHeaderActive()
    return self:IsHeaderFocused()
end

function BETTERUI.Companions.Class:RequestHeaderFocus()
    if self.OnHeaderEntered then
        self:OnHeaderEntered()
    elseif self.EnterSearchMode then
        self:EnterSearchMode()
    end
end

function BETTERUI.Companions.Class:RequestEnterHeader()
    self:RequestHeaderFocus()
end

--- Called when navigating up from the list into the header/search box.
--- Enters search mode and schedules a keybind strip cleanup (matching Banking/Vendor).
function BETTERUI.Companions.Class:OnHeaderEntered()
    if not (self.textSearchHeaderControl and not self.textSearchHeaderControl:IsHidden()) then
        return
    end
    if self._searchModeActive or self._searchHeaderActive then
        return
    end
    self:EnterSearchMode()

    BETTERUI.Companions.Tasks:Schedule("searchKeybindCleanup", 20, function()
        if not self._searchModeActive or not KEYBIND_STRIP then return end
        -- Remove only this module's own keybind groups, snapshotting what was
        -- removed so ExitSearchMode restores exactly that.
        local owned = {}
        owned[#owned + 1] = self.coreKeybinds
        local removed = BETTERUI.Interface.RemoveOwnedKeybindGroups(
            owned, self.textSearchKeybindStripDescriptor)
        if self._searchRemovedKeybindGroups then
            -- Re-entry while search is still active: append instead of
            -- overwriting so the first snapshot is restored on exit.
            for _, group in ipairs(removed) do
                self._searchRemovedKeybindGroups[#self._searchRemovedKeybindGroups + 1] = group
            end
        else
            self._searchRemovedKeybindGroups = removed
        end
        if self._searchModeActive and self.textSearchKeybindStripDescriptor then
            BETTERUI.Interface.EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
        end
    end)
end

--- Backwards-compatible alias.
function BETTERUI.Companions.Class:OnEnterHeader()
    self:OnHeaderEntered()
end

function BETTERUI.Companions.Class:ClearSearchInput()
    self.searchQuery = ""
    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    if searchMixin and searchMixin.ClearSearchText then
        searchMixin.ClearSearchText(self)
    elseif self.ClearSearchText then
        self:ClearSearchText()
    end
    local sceneShowing = (not self.IsSceneShowing) or self:IsSceneShowing()
    if sceneShowing and self.EnsureHeaderKeybindsActive then
        -- ClearText can synchronously transfer focus back to the item list while
        -- ESO still considers the carousel keybind group registered. Recycle the
        -- tab bar so its LB/RB callbacks are freshly registered for list focus.
        self:EnsureHeaderKeybindsActive(true)
        if BETTERUI.Interface.UpdateCurrentKeybindGroups then
            BETTERUI.Interface.UpdateCurrentKeybindGroups()
        end
    end
end

function BETTERUI.Companions.Class:ClearTextSearch()
    self:ClearSearchInput()
end

local TIME_NEW_PERSISTS_WHILE_SELECTED_MS = 200

function BETTERUI.Companions.Class:PrepareNextClearNewStatus(selectedData)
    self:TryClearNewStatus()
    if selectedData then
        self.clearNewStatusBagId = selectedData.bagId
        self.clearNewStatusSlotIndex = selectedData.slotIndex
        self.clearNewStatusUniqueId = selectedData.uniqueId
        if not self.trySetClearNewFlagCallback then
            self.trySetClearNewFlagCallback = function(callId)
                self:TrySetClearNewFlag(callId)
            end
        end
        self.clearNewStatusCallId = zo_callLater(self.trySetClearNewFlagCallback, TIME_NEW_PERSISTS_WHILE_SELECTED_MS)
    end
end

function BETTERUI.Companions.Class:IsClearNewItemActuallyNew()
    return self.clearNewStatusBagId and
        SHARED_INVENTORY:IsItemNew(self.clearNewStatusBagId, self.clearNewStatusSlotIndex) and
        SHARED_INVENTORY:GetItemUniqueId(self.clearNewStatusBagId, self.clearNewStatusSlotIndex) == self.clearNewStatusUniqueId
end

function BETTERUI.Companions.Class:TrySetClearNewFlag(callId)
    -- Reject a nil callId: a cancelled timer clears clearNewStatusCallId to nil, and
    -- zo_callLater passes nil for callId, so `nil == nil` would otherwise fire a stale
    -- timer against a hidden scene.
    if callId and self.clearNewStatusCallId == callId and self:IsClearNewItemActuallyNew() then
        self.clearNewStatusOnSelectionChanged = true
    end
end

function BETTERUI.Companions.Class:TryClearNewStatus()
    if self.clearNewStatusOnSelectionChanged and self:IsClearNewItemActuallyNew() then
        SHARED_INVENTORY:ClearNewStatus(self.clearNewStatusBagId, self.clearNewStatusSlotIndex)
    end
    self.clearNewStatusOnSelectionChanged = nil
end

function BETTERUI.Companions.Class:TryClearNewStatusOnHidden()
    self:TryClearNewStatus()
    -- Cancel the pending 200ms selection timer so it can't fire against a hidden
    -- scene. Remove BEFORE clearing the id, or the handle is lost.
    if self.clearNewStatusCallId then
        zo_removeCallLater(self.clearNewStatusCallId)
    end
    self.clearNewStatusCallId = nil
    self.clearNewStatusBagId = nil
    self.clearNewStatusSlotIndex = nil
    self.clearNewStatusUniqueId = nil
    self.clearNewStatusOnSelectionChanged = nil
end
