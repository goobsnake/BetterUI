--[[
File: Modules/Vendor/Scene/VendorSceneLifecycle.lua
Purpose: Scene lifecycle management for the Vendor module.
Authors: BUI Team
Last Modified: 2026-03-14

Manages what happens when the vendor scene shows and hides:
- On show: adds keybind groups, sets up footer, refreshes list
- On hide: removes keybind groups, cleans up state
- Uses unique event namespaces to avoid collisions with vanilla UI
]]

local Vendor = BETTERUI.Vendor

-- ============================================================================
-- SCENE LIFECYCLE
-- ============================================================================
Vendor.SceneLifecycle = {}

--[[
Function: Vendor.SceneLifecycle.Register
Description: Registers scene state callbacks for showing/hiding the vendor.
param: sceneName (string) - The scene name.
param: vendorInstance (table) - The VendorClass instance.
]]
--- @param sceneName any Description
--- @param vendorInstance any Description
--- @return any Description
function Vendor.SceneLifecycle.Register(sceneName, vendorInstance)
    if not sceneName or not vendorInstance then return end

    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(sceneName)
    if not scene then return end

    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            Vendor.SceneLifecycle.OnShowing(vendorInstance)
        elseif newState == SCENE_HIDING then
            Vendor.SceneLifecycle.OnHiding(vendorInstance)
        elseif newState == SCENE_HIDDEN then
            Vendor.SceneLifecycle.OnHidden(vendorInstance)
        end
    end)
end

--[[
Function: Vendor.SceneLifecycle.OnShowing
Description: Called when the vendor scene begins showing.
             Adds keybinds, sets up footer, refreshes the list.
]]
--- @param vendorInstance any Description
--- @return any Description
function Vendor.SceneLifecycle.OnShowing(vendorInstance)
    if not vendorInstance then return end

    -- Setup the footer
    vendorInstance:SetupUnifiedFooter()

    -- Refresh list for current mode
    vendorInstance:RefreshList()

    -- Guard against double-add if scene transitions rapidly (SCENE_SHOWING fired twice)
    if not vendorInstance._keybindsAdded then
        if vendorInstance.coreKeybinds then
            KEYBIND_STRIP:AddKeybindButtonGroup(vendorInstance.coreKeybinds)
        end
        if vendorInstance.tabKeybinds then
            KEYBIND_STRIP:AddKeybindButtonGroup(vendorInstance.tabKeybinds)
        end
        vendorInstance._keybindsAdded = true
    end

    -- Update header
    vendorInstance:UpdateTabHeader()
end

--[[
Function: Vendor.SceneLifecycle.OnHiding
Description: Called when the vendor scene begins hiding.
             Removes keybinds and cancels deferred tasks.
]]
--- @param vendorInstance any Description
--- @return any Description
function Vendor.SceneLifecycle.OnHiding(vendorInstance)
    if not vendorInstance then return end

    -- Remove keybind groups (only if they were added)
    if vendorInstance._keybindsAdded then
        if vendorInstance.coreKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(vendorInstance.coreKeybinds)
        end
        if vendorInstance.tabKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(vendorInstance.tabKeybinds)
        end
        vendorInstance._keybindsAdded = false
    end

    -- Cancel any pending deferred tasks
    Vendor.Tasks:CancelAll()

    -- Flush any suppressed updates
    vendorInstance._suppressListUpdates = false
    vendorInstance._isDirty = false
end

--[[
Function: Vendor.SceneLifecycle.OnHidden
Description: Called when the vendor scene is fully hidden.
             Deactivates the current component.
]]
--- @param vendorInstance any Description
--- @return any Description
function Vendor.SceneLifecycle.OnHidden(vendorInstance)
    if not vendorInstance then return end

    -- Deactivate current component
    local component = vendorInstance:GetActiveComponent()
    if component and component.Deactivate then
        component:Deactivate(vendorInstance)
    end
end

