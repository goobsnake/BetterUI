--[[
File: Modules/CIM/Core/GenericWindow.lua
Purpose: A specialized base class for Inventory-like windows (Banking, Backpack).
         Inherits from BETTERUI.Interface.Window and adds shared inventory behaviors.
         Supports configurable virtual templates for header unification.
Author: BetterUI Team
Last Modified: 2026-03-26
]]


if not BETTERUI.CIM then BETTERUI.CIM = {} end

--[[
Class: BETTERUI.CIM.GenericWindow
Intermediate base class for Inventory and Banking windows.
Inherits from BETTERUI.Interface.Window.
]]
--- @class BETTERUI.CIM.GenericWindow : BETTERUI.Interface.Window
--- @field categoryPositions table<string, number> Map of category keys to saved positions
--- @field currentCategoryKey string|nil The current category identifier
--- @field list table|nil The list control reference
--- @field headerGeneric table|nil The header control reference
--- @field textSearchKeybindStripDescriptor table|nil Keybind descriptor for text search
--- @field mainKeybindStripDescriptor table|nil Main keybind strip descriptor
--- @field coreKeybinds table|nil Core keybinds table
--- @field _searchModeActive boolean|nil Whether search mode is active
BETTERUI.CIM.GenericWindow = BETTERUI.Interface.Window:Subclass()

--[[
Function: BETTERUI.CIM.GenericWindow:New
Constructor.
]]
--- @param ... any Arguments passed to parent Initialize
--- @return BETTERUI.CIM.GenericWindow
function BETTERUI.CIM.GenericWindow:New(...)
    return BETTERUI.Interface.Window.New(self, ...)
end

--[[
Function: BETTERUI.CIM.GenericWindow:Initialize
Initialize the generic inventory window.
]]
--- @param tlw_name string Top-level window name
--- @param scene_name string Scene name to register
--- @param virtualTemplate string|nil Optional template override for modern modules
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
Returns the current category identifier.
]]
--- @return string|nil categoryKey The current category key, or nil if none is set
function BETTERUI.CIM.GenericWindow:GetCurrentCategoryKey()
    return self.currentCategoryKey
end

--[[
Function: BETTERUI.CIM.GenericWindow:SetCurrentCategoryKey
Sets the current category identifier.
]]
--- @param categoryKey string The category key to set
function BETTERUI.CIM.GenericWindow:SetCurrentCategoryKey(categoryKey)
    self.currentCategoryKey = categoryKey
end

--[[
Function: BETTERUI.CIM.GenericWindow:SaveCategoryPosition
Saves the current list position for a category.
]]
--- @param categoryKey string|nil The category to save position for. Uses current if nil
--- @param position number|nil The position to save. Uses current list selection if nil
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
Restores a previously saved list position for a category.
]]
--- @param categoryKey string|nil The category to restore position for. Uses current if nil
--- @return number position The saved position, or 1 if not found
function BETTERUI.CIM.GenericWindow:RestoreCategoryPosition(categoryKey)
    local key = categoryKey or self.currentCategoryKey
    if not key then return 1 end

    return self.categoryPositions[key] or 1
end

--[[
Function: BETTERUI.CIM.GenericWindow:ClearCategoryPositions
Clears all saved category positions.
]]
function BETTERUI.CIM.GenericWindow:ClearCategoryPositions()
    self.categoryPositions = {}
end

--[[
Function: BETTERUI.CIM.GenericWindow:SwitchToCategory
Switches to a specific category with position restoration.
  1. Saves current category position.
  2. Updates current category key.
  3. Refreshes the list.
  4. Restores position for the new category.
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
Ensures header tab bar keybinds are active.
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
Standard keybind refresh pattern.
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
Placeholder for updating header title based on category.
]]
function BETTERUI.CIM.GenericWindow:UpdateHeaderTitle()
    -- Subclasses should override
end

--[[
Function: BETTERUI.CIM.GenericWindow:RefreshFooter
Placeholder for updating footer info.
]]
function BETTERUI.CIM.GenericWindow:RefreshFooter()
    -- Subclasses should override
end
