--[[
File: Modules/CIM/Core/GenericWindow.lua
Purpose: A specialized base class for Inventory-like windows (Banking, Backpack).
         Inherits from BETTERUI.Interface.Window and adds shared inventory behaviors.
         Supports configurable virtual templates for header unification.
Author: BetterUI Team
Last Modified: 2026-02-03
]]


if not BETTERUI.CIM then BETTERUI.CIM = {} end

--[[
Class: BETTERUI.CIM.GenericWindow
Description: Intermediate base class for Inventory and Banking windows.
Rationale: Shared logic for category management, list focus, and common inventory patterns.
]]
BETTERUI.CIM.GenericWindow = BETTERUI.Interface.Window:Subclass()

--[[
Function: BETTERUI.CIM.GenericWindow:New
Description: Constructor.
]]
function BETTERUI.CIM.GenericWindow:New(...)
    return BETTERUI.Interface.Window.New(self, ...)
end

--[[
Function: BETTERUI.CIM.GenericWindow:Initialize
Description: Initialize the generic inventory window.
Mechanism: Calls parent Initialize and sets up category position tracking.
param: tlw_name (string) - Top-level window name.
param: scene_name (string) - Scene name to register.
param: virtualTemplate (string|nil) - Optional template override for modern modules.
]]
function BETTERUI.CIM.GenericWindow:Initialize(tlw_name, scene_name, virtualTemplate)
    BETTERUI.Interface.Window.Initialize(self, tlw_name, scene_name, virtualTemplate)

    -- Category position persistence
    self.categoryPositions = {}
    self.currentCategoryKey = nil
end

-------------------------------------------------------------------------------------------------
-- CATEGORY MANAGEMENT
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericWindow:GetCurrentCategoryKey
Description: Returns the current category identifier.
return: string|nil - The current category key, or nil if none is set.
]]
--- @return string|nil categoryKey The current category key
function BETTERUI.CIM.GenericWindow:GetCurrentCategoryKey()
    return self.currentCategoryKey
end

--[[
Function: BETTERUI.CIM.GenericWindow:SetCurrentCategoryKey
Description: Sets the current category identifier.
param: categoryKey (string) - The category key to set.
]]
--- @param categoryKey string The category key to set
function BETTERUI.CIM.GenericWindow:SetCurrentCategoryKey(categoryKey)
    self.currentCategoryKey = categoryKey
end

--[[
Function: BETTERUI.CIM.GenericWindow:SaveCategoryPosition
Description: Saves the current list position for a category.
Rationale: Allows returning to the same position when switching back to a category.
param: categoryKey (string) - The category to save position for. Uses current if nil.
param: position (number|nil) - The position to save. Uses current list selection if nil.
]]
--- @param categoryKey string|nil The category to save position for
--- @param position number|nil The position to save
function BETTERUI.CIM.GenericWindow:SaveCategoryPosition(categoryKey, position)
    local key = categoryKey or self.currentCategoryKey
    if not key then return end

    local pos = position
    if not pos and self.list then
        pos = self.list:GetSelectedIndex() or 1
    end

    self.categoryPositions[key] = pos or 1
end

--[[
Function: BETTERUI.CIM.GenericWindow:RestoreCategoryPosition
Description: Restores a previously saved list position for a category.
param: categoryKey (string) - The category to restore position for. Uses current if nil.
return: number - The saved position, or 1 if not found.
]]
--- @param categoryKey string|nil The category to restore position for
--- @return number position The saved position, or 1 if not found
function BETTERUI.CIM.GenericWindow:RestoreCategoryPosition(categoryKey)
    local key = categoryKey or self.currentCategoryKey
    if not key then return 1 end

    return self.categoryPositions[key] or 1
end

--[[
Function: BETTERUI.CIM.GenericWindow:ClearCategoryPositions
Description: Clears all saved category positions.
Rationale: Called when exiting the window to reset state for next visit.
]]
function BETTERUI.CIM.GenericWindow:ClearCategoryPositions()
    self.categoryPositions = {}
end

--[[
Function: BETTERUI.CIM.GenericWindow:SwitchToCategory
Description: Switches to a specific category with position restoration.
Rationale: Common pattern for category tab navigation in Inventory/Banking.
Mechanism:
  1. Saves current category position.
  2. Updates current category key.
  3. Refreshes the list.
  4. Restores position for the new category.
param: categoryKey (string) - The category to switch to.
]]
--- @param categoryKey string The category to switch to
function BETTERUI.CIM.GenericWindow:SwitchToCategory(categoryKey)
    if not categoryKey then return end

    -- Save current position before switching
    if self.currentCategoryKey then
        self:SaveCategoryPosition(self.currentCategoryKey)
    end

    -- Update current category
    self.currentCategoryKey = categoryKey

    -- Refresh list for new category (subclasses should override RefreshList)
    if self.RefreshList then
        self:RefreshList()
    end

    -- Restore position for new category
    local savedPosition = self:RestoreCategoryPosition(categoryKey)
    if self.list and self.list.SetSelectedIndex then
        self.list:SetSelectedIndex(savedPosition)
    end
end

-------------------------------------------------------------------------------------------------
-- KEYBIND MANAGEMENT
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericWindow:EnsureHeaderKeybindsActive
Description: Ensures header tab bar keybinds are active.
Rationale: Common pattern to restore header navigation after dialogs or spinners.
Mechanism: Adds the tab bar keybinds if headerGeneric and tabBar exist.
]]
function BETTERUI.CIM.GenericWindow:EnsureHeaderKeybindsActive()
    if self.headerGeneric and self.headerGeneric.tabBar then
        local tabBar = self.headerGeneric.tabBar
        if tabBar.keybindStripDescriptor then
            BETTERUI.Interface.EnsureKeybindGroupAdded(tabBar.keybindStripDescriptor)
        end
    end

    -- Also ensure text search keybinds are removed when not in search mode
    if not self._searchModeActive and self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
    end

    -- And ensure main keybinds are present
    if self.mainKeybindStripDescriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.mainKeybindStripDescriptor)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
    end
end

--[[
Function: BETTERUI.CIM.GenericWindow:RefreshActiveKeybinds
Description: Standard keybind refresh pattern.
Rationale: Updates keybind button visibility/state based on current selection.
]]
function BETTERUI.CIM.GenericWindow:RefreshActiveKeybinds()
    if not KEYBIND_STRIP then return end

    if self.mainKeybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
    end

    if self.coreKeybinds then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
    end
end

-------------------------------------------------------------------------------------------------
-- PLACEHOLDER METHODS (Override in subclasses)
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.GenericWindow:UpdateHeaderTitle
Description: Placeholder for updating header title based on category.
]]
function BETTERUI.CIM.GenericWindow:UpdateHeaderTitle()
    -- Subclasses should override
end

--[[
Function: BETTERUI.CIM.GenericWindow:RefreshFooter
Description: Placeholder for updating footer info.
]]
function BETTERUI.CIM.GenericWindow:RefreshFooter()
    -- Subclasses should override
end
