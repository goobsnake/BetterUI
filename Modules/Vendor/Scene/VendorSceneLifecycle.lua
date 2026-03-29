--[[
File: Modules/Vendor/Scene/VendorSceneLifecycle.lua
Purpose: DEPRECATED — Scene lifecycle is now handled by CIM.SceneLifecycle.Register
         in Vendor.lua Init(). This file is retained for reference only.

Previously managed what happens when the vendor scene shows and hides:
- On show: adds keybind groups, sets up footer, refreshes list
- On hide: removes keybind groups, cleans up state
]]

local Vendor = BETTERUI.Vendor

-- SCENE LIFECYCLE
Vendor.SceneLifecycle = {}

--- Registers scene state callbacks for showing/hiding the vendor.
---@param sceneName string Scene name to register callbacks for
---@param vendorInstance BETTERUI.Vendor.Class Vendor class instance
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

--- Called when the vendor scene begins showing.
---@param vendorInstance BETTERUI.Vendor.Class
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

--- Called when the vendor scene begins hiding.
---@param vendorInstance BETTERUI.Vendor.Class
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

--- Called when the vendor scene is fully hidden.
---@param vendorInstance BETTERUI.Vendor.Class
function Vendor.SceneLifecycle.OnHidden(vendorInstance)
    if not vendorInstance then return end

    -- Deactivate current component
    local component = vendorInstance:GetActiveComponent()
    if component and component.Deactivate then
        component:Deactivate(vendorInstance)
    end
end

