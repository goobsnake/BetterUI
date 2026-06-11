--[[
File: Modules/CIM/Core/Window/GenericWindow.lua
Purpose: A specialized base class for Inventory-like windows (Banking, Backpack).
         Inherits from BETTERUI.Interface.Window and adds shared inventory behaviors.
         Supports configurable virtual templates for header unification.
]]


if not BETTERUI.CIM then BETTERUI.CIM = {} end

--- @class BETTERUI.CIM.GenericWindow : BETTERUI.Interface.Window
--- @field categoryPositions table<string, integer> Saved scroll positions by category key
--- @field currentCategoryKey string|nil Currently active category key
--- @field headerGeneric table|nil Header control with tabBar reference
--- @field list table|nil The active parametric scroll list
BETTERUI.CIM.GenericWindow = BETTERUI.Interface.Window:Subclass()

function BETTERUI.CIM.GenericWindow:New(...)
    return BETTERUI.Interface.Window.New(self, ...)
end

function BETTERUI.CIM.GenericWindow:Initialize(tlw_name, scene_name, virtualTemplate)
    BETTERUI.Interface.Window.Initialize(self, tlw_name, scene_name, virtualTemplate)

    -- Category position persistence
    self.categoryPositions = {}
    self.currentCategoryKey = nil
end

-- CATEGORY MANAGEMENT

function BETTERUI.CIM.GenericWindow:GetCurrentCategoryKey()
    return self.currentCategoryKey
end

function BETTERUI.CIM.GenericWindow:SetCurrentCategoryKey(categoryKey)
    self.currentCategoryKey = categoryKey
end

--- @param categoryKey string|nil Category key (defaults to currentCategoryKey)
--- @param position integer|nil Position to save (defaults to current list selection)
function BETTERUI.CIM.GenericWindow:SaveCategoryPosition(categoryKey, position)
    local key = categoryKey or self.currentCategoryKey
    if not key then return end

    local pos = position
    if not pos and self.list then
        pos = self.list:GetSelectedIndex() or 1
    end

    self.categoryPositions[key] = pos or 1
end

--- @param categoryKey string|nil Category key (defaults to currentCategoryKey)
--- @return integer position The saved position or 1 if none
function BETTERUI.CIM.GenericWindow:RestoreCategoryPosition(categoryKey)
    local key = categoryKey or self.currentCategoryKey
    if not key then return 1 end

    return self.categoryPositions[key] or 1
end

--- Clears all saved category positions.
function BETTERUI.CIM.GenericWindow:ClearCategoryPositions()
    self.categoryPositions = {}
end

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

-- KEYBIND MANAGEMENT

--- Ensures header tab bar keybinds are active.
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

--- Standard keybind refresh pattern.
function BETTERUI.CIM.GenericWindow:RefreshActiveKeybinds()
    if not KEYBIND_STRIP then return end

    if self.mainKeybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
    end

    if self.coreKeybinds then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
    end
end

-- PLACEHOLDER METHODS (Override in subclasses)

--- Placeholder for updating header title based on category.
function BETTERUI.CIM.GenericWindow:UpdateHeaderTitle()
    -- Subclasses should override
end

--- Placeholder for updating footer info.
function BETTERUI.CIM.GenericWindow:RefreshFooter()
    -- Subclasses should override
end
