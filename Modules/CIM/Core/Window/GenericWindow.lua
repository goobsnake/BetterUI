--[[
File: Modules/CIM/Core/Window/GenericWindow.lua
Purpose: A specialized base class for Inventory-like windows (Banking, Backpack).
         Inherits from BETTERUI.Interface.Window and adds shared inventory behaviors.
         Supports configurable virtual templates for header unification.
]]


if not BETTERUI.CIM then BETTERUI.CIM = {} end

--- @class BETTERUI.CIM.GenericWindow : BETTERUI.Interface.Window
--- @field positionModuleKey string PositionManager namespace for this window's category positions
--- @field currentCategoryKey string|nil Currently active category key
--- @field headerGeneric table|nil Header control with tabBar reference
--- @field list table|nil The active parametric scroll list
BETTERUI.CIM.GenericWindow = BETTERUI.Interface.Window:Subclass()

function BETTERUI.CIM.GenericWindow:New(...)
    return BETTERUI.Interface.Window.New(self, ...)
end

function BETTERUI.CIM.GenericWindow:Initialize(tlw_name, scene_name, virtualTemplate)
    BETTERUI.Interface.Window.Initialize(self, tlw_name, scene_name, virtualTemplate)

    -- Category position persistence (PLT-003): delegated to the shared,
    -- uniqueId-aware BETTERUI.CIM.PositionManager under a per-window namespace,
    -- so a category the user returns to restores onto the same ITEM (by
    -- uniqueId), not just the same index — matching Inventory/Vendor/Companions.
    self.positionModuleKey = "GenericWindow:" .. tostring(scene_name or tlw_name or "default")
    self.currentCategoryKey = nil
end

-- CATEGORY MANAGEMENT

function BETTERUI.CIM.GenericWindow:GetCurrentCategoryKey()
    return self.currentCategoryKey
end

function BETTERUI.CIM.GenericWindow:SetCurrentCategoryKey(categoryKey)
    self.currentCategoryKey = categoryKey
end

--- Saves the current category's list position via the shared PositionManager
--- (records both the selected index and the item uniqueId for robust restore).
--- @param categoryKey string|nil Category key (defaults to currentCategoryKey)
--- @param position integer|nil Deprecated/ignored — the position is read from the live list
function BETTERUI.CIM.GenericWindow:SaveCategoryPosition(categoryKey, position)
    local key = categoryKey or self.currentCategoryKey
    if not key then return end

    local pm = BETTERUI.CIM and BETTERUI.CIM.PositionManager
    if pm and self.list then
        pm.SavePosition(self.positionModuleKey, key, self.list)
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.CATEGORY, "save category position", { key = key, module = self.positionModuleKey }) end
end

--- Restores the saved list index for a category, preferring the saved item's
--- uniqueId (via PositionManager) so the cursor lands on the same item even if
--- the list reordered. Returns a clamped index, or 1 when nothing is saved.
--- @param categoryKey string|nil Category key (defaults to currentCategoryKey)
--- @return integer position The restored index, or 1 if none
function BETTERUI.CIM.GenericWindow:RestoreCategoryPosition(categoryKey)
    local key = categoryKey or self.currentCategoryKey
    if not key then return 1 end

    local pm = BETTERUI.CIM and BETTERUI.CIM.PositionManager
    if pm and self.list then
        local pos = pm.RestorePosition(self.positionModuleKey, key, self.list, self.list.dataList)
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.CATEGORY, "restore category position", { key = key, pos = pos }) end
        return pos or 1
    end
    return 1
end

--- Clears all saved category positions for this window.
function BETTERUI.CIM.GenericWindow:ClearCategoryPositions()
    local pm = BETTERUI.CIM and BETTERUI.CIM.PositionManager
    if pm and self.positionModuleKey then
        pm.ClearModule(self.positionModuleKey)
    end
end

function BETTERUI.CIM.GenericWindow:SwitchToCategory(categoryKey)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.CATEGORY, "switch to category", {
            categoryKey = categoryKey,
            prevKey = self.currentCategoryKey,
        })
    end

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
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "ensure header keybinds", {
        fn = "GenericWindow:EnsureHeaderKeybindsActive",
        main = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or tostring(self.mainKeybindStripDescriptor),
        tab = BETTERUI.Log.DescribeKeybindDescriptor and self.headerGeneric and self.headerGeneric.tabBar and BETTERUI.Log.DescribeKeybindDescriptor(self.headerGeneric.tabBar.keybindStripDescriptor, "tab") or nil,
        search = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.textSearchKeybindStripDescriptor, "search") or tostring(self.textSearchKeybindStripDescriptor),
    }) end
    if self.headerGeneric and self.headerGeneric.tabBar then
        local tabBar = self.headerGeneric.tabBar
        if tabBar.keybindStripDescriptor then
            BETTERUI.Interface.EnsureKeybindGroupAdded(tabBar.keybindStripDescriptor)
        end
    end

    -- Also ensure text search keybinds are removed when not in search mode
    if not self._searchModeActive and self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.textSearchKeybindStripDescriptor)
    end

    -- And ensure main keybinds are present
    if self.mainKeybindStripDescriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(self.mainKeybindStripDescriptor)
        BETTERUI.Interface.UpdateKeybindGroup(self.mainKeybindStripDescriptor)
    end
end

--- Standard keybind refresh pattern.
function BETTERUI.CIM.GenericWindow:RefreshActiveKeybinds()
    if not KEYBIND_STRIP then return end

    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "refresh active keybinds", {
        fn = "GenericWindow:RefreshActiveKeybinds",
        main = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or tostring(self.mainKeybindStripDescriptor),
        core = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.coreKeybinds, "core") or tostring(self.coreKeybinds),
    }) end
    if self.mainKeybindStripDescriptor then
        BETTERUI.Interface.UpdateKeybindGroup(self.mainKeybindStripDescriptor)
    end

    if self.coreKeybinds then
        BETTERUI.Interface.UpdateKeybindGroup(self.coreKeybinds)
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
