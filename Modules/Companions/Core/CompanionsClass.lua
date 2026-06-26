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

---@return boolean showing True if the companion scene is currently showing
function BETTERUI.Companions.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_COMPANION_EQUIP_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

-- FOOTER

--- Initializes the companion footer — hides banking controls, shows companion info.
function BETTERUI.Companions.Class:InitCompanionFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- Hide the centre vertical divider
    local dividerCentre = footerRoot:GetNamedChild("DividerCentre")
    if dividerCentre then dividerCentre:SetHidden(true) end

    -- LEFT SIDE: Companion name
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", nil)
            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_TITLE") or "SI_BETTERUI_COMPANIONS_TITLE"))
            end
        end
        local icon = withdraw:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/companion/gamepad/gp_companion_menu_icon.dds")
        end
    end

    -- RIGHT SIDE: Bag capacity
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", nil)
            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_FOOTER_BAG_CAPACITY") or "SI_BETTERUI_FOOTER_BAG_CAPACITY"))
                label:SetColor(1, 1, 1, 1)
            end
        end
        local icon = deposit:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
        end
    end

    self:RefreshCompanionFooter()
end

-- SEARCH FOCUS HELPERS

local function TraceCompanionClass(event, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Companions"
    data.feature = data.feature or "companion-search"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.KEYBIND or categories.ACTION, event, phase, data)
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
    TraceCompanionClass("companions.search_mode", "enter_begin", {
        fn = "Companions.Class:EnterSearchMode",
        hadSearchMode = self._searchModeActive == true,
        hadHeaderActive = self._searchHeaderActive == true,
        hasSearchKeybinds = self.textSearchKeybindStripDescriptor ~= nil,
        hasCoreKeybinds = self.coreKeybinds ~= nil,
    })
    if self.textSearchHeaderFocus then
        self.textSearchHeaderFocus:Activate()
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
    self._searchModeActive = true
    self._searchHeaderActive = true
    TraceCompanionClass("companions.search_mode", "entered", {
        fn = "Companions.Class:EnterSearchMode",
        searchModeActive = self._searchModeActive == true,
        searchHeaderActive = self._searchHeaderActive == true,
    })
end

function BETTERUI.Companions.Class:ExitSearchMode()
    if not self._searchModeActive and not self._searchHeaderActive then
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
    if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.textSearchKeybindStripDescriptor)
    end
    -- Restore exactly the groups the search-mode cleanup removed.
    if self._searchRemovedKeybindGroups then
        BETTERUI.Interface.RestoreKeybindGroups(self._searchRemovedKeybindGroups)
        self._searchRemovedKeybindGroups = nil
    end
    if self.coreKeybinds and KEYBIND_STRIP then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.coreKeybinds)
    end
    if self.textSearchHeaderFocus then
        self.textSearchHeaderFocus:Deactivate()
    end
    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(false)
    end
    self._searchModeActive = false
    self._searchHeaderActive = false
    self:EnsureListInputActive()
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

function BETTERUI.Companions.Class:EnterSearchFocus()
    self:EnterSearchMode()
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
    if self.ClearSearchText then
        self:ClearSearchText()
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
    if self.clearNewStatusCallId == callId and self:IsClearNewItemActuallyNew() then
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
    self.clearNewStatusCallId = nil
    self.clearNewStatusBagId = nil
    self.clearNewStatusSlotIndex = nil
    self.clearNewStatusUniqueId = nil
    self.clearNewStatusOnSelectionChanged = nil
end

--- Refreshes companion footer values (companion name, bag capacity).
function BETTERUI.Companions.Class:RefreshCompanionFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- LEFT SIDE: Active companion name
    local companionName = ""
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                if HasActiveCompanion and HasActiveCompanion() then
                    local defId = GetActiveCompanionDefId and GetActiveCompanionDefId()
                    if defId and GetCompanionName then
                        companionName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetCompanionName(defId))
                    end
                end
                spaceLabel:SetText(companionName ~= "" and companionName or "-")
            end
        end
    end

    -- RIGHT SIDE: Bag capacity
    local bagUsed = GetNumBagUsedSlots(BAG_BACKPACK)
    local bagSize = GetBagSize(BAG_BACKPACK)
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                spaceLabel:SetText(
                    "|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t " ..
                    zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                        bagUsed, bagSize))
            end
        end
    end
    if BETTERUI.Log and BETTERUI.Log.TraceEvent then
        BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.STATE, "companions.footer", "refreshed", {
            module = "Companions",
            feature = "footer",
            fn = "RefreshCompanionFooter",
            companionName = companionName ~= "" and companionName or nil,
            bagUsed = bagUsed,
            bagSize = bagSize,
        })
    end
end
