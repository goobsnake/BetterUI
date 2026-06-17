--[[
File: Modules/CIM/Core/Window/UnifiedScreen.lua
Purpose: Unified base class for Inventory and Banking screens.
         Provides common functionality including:
         - Footer mode switching (CURRENCY vs BANKING)
         - Shared initialization patterns
         - Common refresh hooks
]]

-- CLASS: BETTERUI.CIM.UnifiedScreen
-- Common parent for Inventory and Banking implementing shared patterns.

---@class BetterUIUnifiedScreen : BETTERUI_Gamepad_ParametricList_Screen
---@field control table
---@field footerMode integer
---@field unifiedFooterController table|nil
---@field activeKeybindDescriptor BetterUIKeybindDescriptorGroup|nil
---@field searchKeybindDescriptor BetterUIKeybindDescriptorGroup|nil
---@field _searchModeActive boolean|nil
---@field isInHeaderSortMode boolean|nil
BETTERUI.CIM.UnifiedScreen = BETTERUI_Gamepad_ParametricList_Screen:Subclass()

-- Capture the parent table only (never the dynamic MODE member) to avoid the
-- "Stale Reference Trap": access UnifiedFooter.MODE.X at each use site so a later
-- reassignment of UnifiedFooter.MODE is always observed. See tribal-knowledge.md.
local UnifiedFooter = BETTERUI.CIM.UnifiedFooter

--- Creates a new UnifiedScreen instance.
---@param ... any
---@return BetterUIUnifiedScreen
function BETTERUI.CIM.UnifiedScreen:New(...)
    return BETTERUI_Gamepad_ParametricList_Screen.New(self, ...)
end

--- Initializes the screen with unified footer support.
---@param control table
---@param createTabBar boolean?
---@param activateOnShow boolean?
---@param scene table?
---@param footerMode integer?
function BETTERUI.CIM.UnifiedScreen:Initialize(control, createTabBar, activateOnShow, scene, footerMode)
    BETTERUI_Gamepad_ParametricList_Screen.Initialize(self, control, createTabBar, activateOnShow, scene)

    -- Default to CURRENCY mode if not specified
    self.footerMode = footerMode or UnifiedFooter.MODE.CURRENCY

    -- Cache footer controller reference
    self.unifiedFooterController = nil
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "unifiedScreenInit", { footerMode = self.footerMode }) end

    -- Setup footer after initialization (only if this is a true UnifiedScreen subclass)
    -- When used as mixin on ZO_GamepadInventory subclasses, this method may not exist on self
    if self.SetupUnifiedFooter then
        self:SetupUnifiedFooter()
    end
end

--- Initializes a window-backed screen through the shared UnifiedScreen seam.
--- This stages legacy BETTERUI.Interface.Window users onto the same footer/bootstrap
--- contract as Inventory without forcing an inheritance rewrite in one step.
---@param screen BetterUIWindow
---@param tlwName string
---@param sceneName string
---@param footerMode integer?
---@param virtualTemplate string?
function BETTERUI.CIM.UnifiedScreen.InitializeWindowShell(screen, tlwName, sceneName, footerMode, virtualTemplate)
    BETTERUI.Interface.Window.Initialize(screen, tlwName, sceneName, virtualTemplate)

    screen.footerMode = footerMode or UnifiedFooter.MODE.CURRENCY
    screen.unifiedFooterController = nil

    if screen.SetupUnifiedFooter then
        screen:SetupUnifiedFooter()
    end
end

--- Links to the UnifiedFooter controller and sets initial mode.
function BETTERUI.CIM.UnifiedScreen:SetupUnifiedFooter()
    local footerContainer = self.control.container and self.control.container:GetNamedChild("FooterContainer")
    if footerContainer and footerContainer.unifiedFooter then
        self.unifiedFooterController = footerContainer.unifiedFooter
        self.unifiedFooterController:SetMode(self.footerMode)
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "setupUnifiedFooter", { hasController = self.unifiedFooterController ~= nil }) end
end

--- Changes the footer display mode.
---@param mode integer
function BETTERUI.CIM.UnifiedScreen:SetFooterMode(mode)
    self.footerMode = mode
    if self.unifiedFooterController then
        self.unifiedFooterController:SetMode(mode)
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "setFooterMode", { mode = mode }) end
end

--- Returns the current footer mode.
---@return integer
function BETTERUI.CIM.UnifiedScreen:GetFooterMode()
    return self.footerMode
end

--- Triggers a footer content refresh.
function BETTERUI.CIM.UnifiedScreen:RefreshFooter()
    if self.unifiedFooterController then
        self.unifiedFooterController:Refresh()
    end
end

--- Called when screen is about to show. Sets footer mode.
function BETTERUI.CIM.UnifiedScreen:OnShowing()
    -- Ensure footer controller is set up
    if not self.unifiedFooterController then
        self:SetupUnifiedFooter()
    end

    -- Apply footer mode when showing
    if self.unifiedFooterController then
        self.unifiedFooterController:SetMode(self.footerMode)
    end
    if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "unifiedScreenShowing", { footerMode = self.footerMode }) end
end

--- Called when screen is about to hide.
--- Override in subclasses for cleanup.
function BETTERUI.CIM.UnifiedScreen:OnHiding()
    -- Subclasses can override for cleanup
end

-- SCENE HANDLER MIXIN METHODS
-- These provide common scene state handling for Inventory/Banking

--- Common SCENE_SHOWING handler logic.
--- Subclasses can call this then add module-specific logic.
function BETTERUI.CIM.UnifiedScreen:HandleSceneShowing()
    -- Ensure footer controller is set up
    if not self.unifiedFooterController then
        self:SetupUnifiedFooter()
    end

    -- Apply footer mode
    if self.unifiedFooterController then
        self.unifiedFooterController:SetMode(self.footerMode)
    end

    -- Hide external toolbars
    BETTERUI.CIM.Utils.SetExternalToolbarHidden(true)

    -- Call subclass OnShowing if implemented
    if self.OnShowing then
        self:OnShowing()
    end
    if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "unifiedScreenShowing", { footerMode = self.footerMode }) end
end

--- Common SCENE_HIDING handler logic.
function BETTERUI.CIM.UnifiedScreen:HandleSceneHiding()
    -- Restore external toolbars
    BETTERUI.CIM.Utils.SetExternalToolbarHidden(false)

    -- Call subclass OnHiding if implemented
    if self.OnHiding then
        self:OnHiding()
    end
    if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "unifiedScreenHidden", {}) end
end

--- Common SCENE_HIDDEN handler logic.
function BETTERUI.CIM.UnifiedScreen:HandleSceneHidden()
    -- Clear keybinds
    if self.ClearActiveKeybinds then
        self:ClearActiveKeybinds()
    end

    -- Restore external toolbars (redundant safety)
    BETTERUI.CIM.Utils.SetExternalToolbarHidden(false)

    -- Clear search state if applicable
    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    if searchMixin and searchMixin.CallSearchLifecycle then
        searchMixin.CallSearchLifecycle(self, "clear")
    elseif self.ClearSearchInput then
        self:ClearSearchInput()
    end
    if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "unifiedScreenHidden", {}) end
end

-- KEYBIND MANAGEMENT METHODS

--- Sets the active keybind group, removing any previous one.
---@param keybindDescriptor BetterUIKeybindDescriptorGroup?
function BETTERUI.CIM.UnifiedScreen:SetActiveKeybinds(keybindDescriptor)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "SetActiveKeybinds", { hasDescriptor = keybindDescriptor ~= nil, headerSortMode = self.isInHeaderSortMode == true }) end
    -- Skip keybind changes if in header sort mode to preserve header mode keybinds
    if self.isInHeaderSortMode then
        return
    end
    if self.activeKeybindDescriptor == keybindDescriptor then
        if keybindDescriptor and KEYBIND_STRIP then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(keybindDescriptor)
        end
        return
    end
    if self.activeKeybindDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.activeKeybindDescriptor)
    end
    self.activeKeybindDescriptor = keybindDescriptor
    if keybindDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:AddKeybindButtonGroup(keybindDescriptor)
    end
end

--- Refreshes the currently active keybind group.
function BETTERUI.CIM.UnifiedScreen:RefreshActiveKeybinds()
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "RefreshActiveKeybinds", { hasDescriptor = self.activeKeybindDescriptor ~= nil, headerSortMode = self.isInHeaderSortMode == true }) end
    -- Skip refreshing active keybinds if in header sort mode
    if self.isInHeaderSortMode then
        return
    end
    if self.activeKeybindDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.activeKeybindDescriptor)
    end
end

--- Removes only this screen's own keybind button groups from the strip.
--- Never wipes groups owned by the native UI or other addons.
function BETTERUI.CIM.UnifiedScreen:ClearActiveKeybinds()
    if KEYBIND_STRIP then
        if self.activeKeybindDescriptor and KEYBIND_STRIP:HasKeybindButtonGroup(self.activeKeybindDescriptor) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.activeKeybindDescriptor)
        end
        if self.searchKeybindDescriptor and KEYBIND_STRIP:HasKeybindButtonGroup(self.searchKeybindDescriptor) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.searchKeybindDescriptor)
        end
    end
    self.activeKeybindDescriptor = nil
    -- Reset search mode so the next EnterSearchMode is not a no-op for
    -- subclasses whose teardown does not route through SceneCleanup.
    self._searchModeActive = false
end

--- Overrides base class RefreshKeybinds with header mode guard.
--- Prevents keybind updates during header sort mode.
function BETTERUI.CIM.UnifiedScreen:RefreshKeybinds()
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "RefreshKeybinds", { hasDescriptor = self.activeKeybindDescriptor ~= nil, headerSortMode = self.isInHeaderSortMode == true }) end
    -- Block keybind refresh during header sort mode to preserve header mode keybinds
    if self.isInHeaderSortMode then
        return
    end
    -- Call parent class implementation if it exists
    if BETTERUI_Gamepad_ParametricList_Screen.RefreshKeybinds then
        BETTERUI_Gamepad_ParametricList_Screen.RefreshKeybinds(self)
    end
end

-- SEARCH FOCUS LOGIC

--- Initializes search focus behavior for the screen.
---@param searchKeybindDescriptor BetterUIKeybindDescriptorGroup
function BETTERUI.CIM.UnifiedScreen:SetupSearchFocus(searchKeybindDescriptor)
    self.searchKeybindDescriptor = searchKeybindDescriptor
    self._searchModeActive = false
end

--- Activates search mode keybinds and state.
function BETTERUI.CIM.UnifiedScreen:EnterSearchMode()
    if self._searchModeActive then return end
    self._searchModeActive = true

    if self.searchKeybindDescriptor and KEYBIND_STRIP then
        -- Swap to search keybinds
        if self.activeKeybindDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.activeKeybindDescriptor)
        end
        KEYBIND_STRIP:AddKeybindButtonGroup(self.searchKeybindDescriptor)
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "searchMode", { active = self._searchModeActive }) end
end

--- Deactivates search mode and restores main keybinds.
function BETTERUI.CIM.UnifiedScreen:ExitSearchMode()
    if not self._searchModeActive then return end
    self._searchModeActive = false

    if KEYBIND_STRIP then
        if self.searchKeybindDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.searchKeybindDescriptor)
        end
        if self.activeKeybindDescriptor then
            KEYBIND_STRIP:AddKeybindButtonGroup(self.activeKeybindDescriptor)
        end
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "searchMode", { active = self._searchModeActive }) end
end

-- EXPORTED MODE CONSTANTS (Convenience)

BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_CURRENCY = UnifiedFooter.MODE.CURRENCY
BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_BANKING = UnifiedFooter.MODE.BANKING
