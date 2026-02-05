--[[
File: Modules/CIM/Core/UnifiedScreen.lua
Purpose: Unified base class for Inventory and Banking screens.
         Provides common functionality including:
         - Footer mode switching (CURRENCY vs BANKING)
         - Shared initialization patterns
         - Common refresh hooks
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-- ============================================================================
-- CLASS: BETTERUI.CIM.UnifiedScreen
-- Common parent for Inventory and Banking implementing shared patterns.
-- ============================================================================

-- Class: BETTERUI.CIM.UnifiedScreen (extends BETTERUI_Gamepad_ParametricList_Screen)
BETTERUI.CIM.UnifiedScreen = BETTERUI_Gamepad_ParametricList_Screen:Subclass()

local MODE = BETTERUI.CIM.UnifiedFooter.MODE

--[[
Function: BETTERUI.CIM.UnifiedScreen:New
Description: Creates a new UnifiedScreen instance.
return: UnifiedScreen
Note: We pass ... to the parent's New, which handles Initialize automatically.
]]
function BETTERUI.CIM.UnifiedScreen:New(...)
    return BETTERUI_Gamepad_ParametricList_Screen.New(self, ...)
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:Initialize
Description: Initializes the screen with unified footer support.
param: control (Control) - The screen control.
param: createTabBar (boolean) - Whether to create tab bar.
param: activateOnShow (boolean) - Whether to activate on show.
param: scene (Scene) - The scene to associate.
param: footerMode (number) - Initial footer mode (MODE.CURRENCY or MODE.BANKING).
]]
function BETTERUI.CIM.UnifiedScreen:Initialize(control, createTabBar, activateOnShow, scene, footerMode)
    BETTERUI_Gamepad_ParametricList_Screen.Initialize(self, control, createTabBar, activateOnShow, scene)

    -- Default to CURRENCY mode if not specified
    self.footerMode = footerMode or MODE.CURRENCY

    -- Cache footer controller reference
    self.unifiedFooterController = nil

    -- Setup footer after initialization (only if this is a true UnifiedScreen subclass)
    -- When used as mixin on ZO_GamepadInventory subclasses, this method may not exist on self
    if self.SetupUnifiedFooter then
        self:SetupUnifiedFooter()
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:SetupUnifiedFooter
Description: Links to the UnifiedFooter controller and sets initial mode.
]]
function BETTERUI.CIM.UnifiedScreen:SetupUnifiedFooter()
    local footerContainer = self.control.container and self.control.container:GetNamedChild("FooterContainer")
    if footerContainer and footerContainer.unifiedFooter then
        self.unifiedFooterController = footerContainer.unifiedFooter
        self.unifiedFooterController:SetMode(self.footerMode)
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:SetFooterMode
Description: Changes the footer display mode.
param: mode (number) - MODE.CURRENCY or MODE.BANKING
]]
function BETTERUI.CIM.UnifiedScreen:SetFooterMode(mode)
    self.footerMode = mode
    if self.unifiedFooterController then
        self.unifiedFooterController:SetMode(mode)
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:GetFooterMode
Description: Returns the current footer mode.
return: number
]]
function BETTERUI.CIM.UnifiedScreen:GetFooterMode()
    return self.footerMode
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:RefreshFooter
Description: Triggers a footer content refresh.
]]
function BETTERUI.CIM.UnifiedScreen:RefreshFooter()
    if self.unifiedFooterController then
        self.unifiedFooterController:Refresh()
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:OnShowing
Description: Called when screen is about to show. Sets footer mode.
]]
function BETTERUI.CIM.UnifiedScreen:OnShowing()
    -- Ensure footer controller is set up
    if not self.unifiedFooterController then
        self:SetupUnifiedFooter()
    end

    -- Apply footer mode when showing
    if self.unifiedFooterController then
        self.unifiedFooterController:SetMode(self.footerMode)
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:OnHiding
Description: Called when screen is about to hide.
             Override in subclasses for cleanup.
]]
function BETTERUI.CIM.UnifiedScreen:OnHiding()
    -- Subclasses can override for cleanup
end

-- ============================================================================
-- SCENE HANDLER MIXIN METHODS
-- These provide common scene state handling for Inventory/Banking
-- ============================================================================

--[[
Function: BETTERUI.CIM.UnifiedScreen:HandleSceneShowing
Description: Common SCENE_SHOWING handler logic.
             Subclasses can call this then add module-specific logic.
]]
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
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:HandleSceneHiding
Description: Common SCENE_HIDING handler logic.
]]
function BETTERUI.CIM.UnifiedScreen:HandleSceneHiding()
    -- Restore external toolbars
    BETTERUI.CIM.Utils.SetExternalToolbarHidden(false)

    -- Call subclass OnHiding if implemented
    if self.OnHiding then
        self:OnHiding()
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:HandleSceneHidden
Description: Common SCENE_HIDDEN handler logic.
]]
function BETTERUI.CIM.UnifiedScreen:HandleSceneHidden()
    -- Clear keybinds
    if self.ClearActiveKeybinds then
        self:ClearActiveKeybinds()
    end

    -- Restore external toolbars (redundant safety)
    BETTERUI.CIM.Utils.SetExternalToolbarHidden(false)

    -- Clear search state if applicable
    if self.ClearTextSearch then
        self:ClearTextSearch()
    end
end

-- ============================================================================
-- KEYBIND MANAGEMENT METHODS
-- ============================================================================

--[[
Function: BETTERUI.CIM.UnifiedScreen:SetActiveKeybinds
Description: Sets the active keybind group, removing any previous one.
param: keybindDescriptor (table) - The keybind group to activate.
]]
function BETTERUI.CIM.UnifiedScreen:SetActiveKeybinds(keybindDescriptor)
    -- Skip keybind changes if in header sort mode to preserve header mode keybinds
    if self.isInHeaderSortMode then
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

--[[
Function: BETTERUI.CIM.UnifiedScreen:RefreshActiveKeybinds
Description: Refreshes the currently active keybind group.
]]
function BETTERUI.CIM.UnifiedScreen:RefreshActiveKeybinds()
    -- Skip refreshing active keybinds if in header sort mode
    if self.isInHeaderSortMode then
        return
    end
    if self.activeKeybindDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.activeKeybindDescriptor)
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:ClearActiveKeybinds
Description: Removes all keybind button groups from the strip.
]]
function BETTERUI.CIM.UnifiedScreen:ClearActiveKeybinds()
    if KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveAllKeyButtonGroups()
    end
    self.activeKeybindDescriptor = nil
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:RefreshKeybinds
Description: Overrides base class RefreshKeybinds with header mode guard.
             Prevents keybind updates during header sort mode.
]]
function BETTERUI.CIM.UnifiedScreen:RefreshKeybinds()
    -- Block keybind refresh during header sort mode to preserve header mode keybinds
    if self.isInHeaderSortMode then
        return
    end
    -- Call parent class implementation if it exists
    if BETTERUI_Gamepad_ParametricList_Screen.RefreshKeybinds then
        BETTERUI_Gamepad_ParametricList_Screen.RefreshKeybinds(self)
    end
end

-- ============================================================================
-- SEARCH FOCUS LOGIC
-- ============================================================================

--[[
Function: BETTERUI.CIM.UnifiedScreen:SetupSearchFocus
Description: Initializes search focus behavior for the screen.
param: searchKeybindDescriptor (table) - Keybind group for search mode.
]]
function BETTERUI.CIM.UnifiedScreen:SetupSearchFocus(searchKeybindDescriptor)
    self.searchKeybindDescriptor = searchKeybindDescriptor
    self._searchModeActive = false
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:EnterSearchMode
Description: Activates search mode keybinds and state.
]]
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
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:ExitSearchMode
Description: Deactivates search mode and restores main keybinds.
]]
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
end

-- ============================================================================
-- EXPORTED MODE CONSTANTS (Convenience)
-- ============================================================================

BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_CURRENCY = MODE.CURRENCY
BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_BANKING = MODE.BANKING
