--[[
File: Modules/Vendor/Vendor.lua
Purpose: Main orchestrator for the Vendor module.

This file handles:
1. Creating the Vendor class instance and scene
2. Registering all components (Buy, Sell, Repair, Buyback, FenceSell, FenceLaunder)
3. Wiring EVENT_OPEN_STORE / EVENT_OPEN_FENCE / EVENT_CLOSE_STORE
4. Tab navigation (carousel or tab-bar)
5. Scene alias so BetterUI replaces the native gamepad_store scene

KEY MECHANICS:
  - EVENT_OPEN_STORE: Opens in BUY mode with Buy/Sell/Repair/Buyback tabs
  - EVENT_OPEN_FENCE: Opens with FenceSell/FenceLaunder tabs (no Buy/Repair/Buyback)
  - Tab switching calls VendorClass:SetMode() which routes to component Activate/Deactivate
  - Scene is created as ZO_InteractScene and aliased to gamepad_store
]]

-- LOCAL STATE
local Vendor      = BETTERUI.Vendor
local MODE        = Vendor.MODE
local EVENT_NS    = "BetterUI_Vendor"

-- Tracks whether current interaction is fence (true) or regular store (false)
local isFenceInteraction = false

-- Tracks which fence modes are enabled for the current fence interaction
local fenceEnableSell    = false
local fenceEnableLaunder = false

-- TAB DEFINITIONS

---@alias VendorTabDef {mode: number, name: fun(): string}

-- Regular vendor tabs (Buy, Sell, Repair, Buyback)
---@type VendorTabDef[]
local VENDOR_TABS = {
    { mode = MODE.BUY,     name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUY")) end },
    { mode = MODE.SELL,    name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_SELL")) end },
    { mode = MODE.REPAIR,  name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_REPAIR")) end },
    { mode = MODE.BUYBACK, name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_BUYBACK")) end },
}

-- Fence tabs (Sell Stolen, Launder)
---@type VendorTabDef[]
local FENCE_TABS = {
    { mode = MODE.FENCE_SELL,    name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_SELL")) end },
    { mode = MODE.FENCE_LAUNDER, name = function() return GetString(rawget(_G, "SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER")) end },
}

-- GET ACTIVE TABS

--- Returns the tab list for the current interaction type.
---@return VendorTabDef[] tabs Active tab definitions
local function GetActiveTabs()
    if isFenceInteraction then
        local tabs = {}
        if fenceEnableSell then
            tabs[#tabs + 1] = FENCE_TABS[1]
        end
        if fenceEnableLaunder then
            tabs[#tabs + 1] = FENCE_TABS[2]
        end
        -- Safety: if no tabs enabled, fall back to sell
        if #tabs == 0 then
            tabs[1] = FENCE_TABS[1]
        end
        return tabs
    end
    return VENDOR_TABS
end

-- KEYBINDS

---@param vendorInstance BETTERUI.Vendor.Class
---@return table keybindGroup Core keybind descriptor group
local function BuildCoreKeybinds(vendorInstance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Primary action (keybind A / GAMEPAD_BUTTON_1)
        {
            name = function()
                local component = vendorInstance:GetActiveComponent()
                if component and component.GetPrimaryActionName then
                    return component:GetPrimaryActionName(vendorInstance)
                end
                return GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION"))
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local component = vendorInstance:GetActiveComponent()
                if component and component.OnPrimaryAction then
                    component:OnPrimaryAction(vendorInstance)
                end
            end,
            enabled = function()
                local component = vendorInstance:GetActiveComponent()
                if component and component.IsPrimaryActionEnabled then
                    return component:IsPrimaryActionEnabled(vendorInstance)
                end
                -- Disabled if no list data
                local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
                return selectedData ~= nil
            end,
        },
        -- Back / Exit (keybind B / GAMEPAD_BUTTON_2)
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                -- Close the interaction
                SCENE_MANAGER:HideCurrentScene()
            end,
        },
    }
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return table keybindGroup Tab navigation keybind descriptor group
local function BuildTabKeybinds(vendorInstance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Switch tabs left (LB / GAMEPAD_BUTTON_5)
        {
            --Narration
            name = GetString(rawget(_G, "SI_GAMEPAD_PAGED_LIST_PAGE_LEFT_NARRATION")),
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            callback = function()
                vendorInstance:CycleTabs(-1)
            end,
            enabled = function()
                local tabs = GetActiveTabs()
                return #tabs > 1
            end,
        },
        -- Switch tabs right (RB / GAMEPAD_BUTTON_6)
        {
            --Narration
            name = GetString(rawget(_G, "SI_GAMEPAD_PAGED_LIST_PAGE_RIGHT_NARRATION")),
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            callback = function()
                vendorInstance:CycleTabs(1)
            end,
            enabled = function()
                local tabs = GetActiveTabs()
                return #tabs > 1
            end,
        },
    }
end

-- TAB CYCLING

---@param direction number -1 for left, 1 for right
function BETTERUI.Vendor.Class:CycleTabs(direction)
    local tabs = GetActiveTabs()
    if #tabs <= 1 then return end

    -- Find current tab index
    local currentMode = self:GetCurrentMode()
    local currentIndex = 1
    for i, tab in ipairs(tabs) do
        if tab.mode == currentMode then
            currentIndex = i
            break
        end
    end

    -- Calculate new index with wrap
    local newIndex = ((currentIndex - 1 + direction) % #tabs) + 1
    self:SetMode(tabs[newIndex].mode)

    -- Update header to reflect new tab
    self:UpdateTabHeader()
end

--- Updates the header title to show the current tab name.
---@return nil
function BETTERUI.Vendor.Class:UpdateTabHeader()
    local tabs = GetActiveTabs()
    local currentMode = self:GetCurrentMode()

    for _, tab in ipairs(tabs) do
        if tab.mode == currentMode then
            local tabName = tab.name()
            if self.header and self.header.SetTitle then
                self.header:SetTitle(tabName)
            end
            break
        end
    end
end

-- EVENT HANDLERS

local function OnOpenStore()
    isFenceInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false

    if not Vendor.instance then return end

    -- Set mode to BUY (default for vendor)
    Vendor.instance:SetMode(MODE.BUY)
    Vendor.instance:UpdateTabHeader()

    -- Show the scene
    local sceneName = BETTERUI_VENDOR_SCENE_NAME
    if SCENE_MANAGER then
        SCENE_MANAGER:Show(sceneName)
    end
end

---@param _ any Unused event code
---@param enableSell boolean|nil Whether fence sell is enabled (default true)
---@param enableLaunder boolean|nil Whether fence launder is enabled (default true)
local function OnOpenFence(_, enableSell, enableLaunder)
    isFenceInteraction = true
    fenceEnableSell = (enableSell ~= false)     -- default true
    fenceEnableLaunder = (enableLaunder ~= false) -- default true

    if not Vendor.instance then return end

    -- Set mode to first available fence tab
    if fenceEnableSell then
        Vendor.instance:SetMode(MODE.FENCE_SELL)
    elseif fenceEnableLaunder then
        Vendor.instance:SetMode(MODE.FENCE_LAUNDER)
    end
    Vendor.instance:UpdateTabHeader()

    -- Show the scene
    local sceneName = BETTERUI_VENDOR_SCENE_NAME
    if SCENE_MANAGER then
        SCENE_MANAGER:Show(sceneName)
    end
end

local function OnCloseStore()
    isFenceInteraction = false
    fenceEnableSell = false
    fenceEnableLaunder = false

    -- Scene hiding is handled by VendorSceneLifecycle
end

local function OnInventoryUpdated()
    if not Vendor.instance then return end
    if not Vendor.instance:IsSceneShowing() then return end

    -- Coalesce rapid updates
    Vendor.Tasks:Cancel("listRefresh")
    Vendor.Tasks:Schedule("listRefresh", 100, function()
        if Vendor.instance and Vendor.instance:IsSceneShowing() then
            Vendor.instance:RefreshList()
        end
    end)
end

local function OnSellReceipt()
    -- Refresh after selling an item
    OnInventoryUpdated()
end

-- INITIALIZATION

--- Initializes the Vendor module.
---@return nil
function BETTERUI.Vendor.Init()
    if Vendor.initialized then return end

    -- Create the Vendor class instance with proper window/scene names
    Vendor.instance = Vendor.Class:New("BETTERUI_VendorWindow", BETTERUI_VENDOR_SCENE_NAME)
    Vendor.instance:SetTitle("|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_VENDOR_TITLE")) .. "|r")

    -- Register components (each is initialized in its own file)
    if Vendor.BuyComponent then
        Vendor.instance:RegisterComponent(MODE.BUY, Vendor.BuyComponent)
    end
    if Vendor.SellComponent then
        Vendor.instance:RegisterComponent(MODE.SELL, Vendor.SellComponent)
    end
    if Vendor.RepairComponent then
        Vendor.instance:RegisterComponent(MODE.REPAIR, Vendor.RepairComponent)
    end
    if Vendor.BuybackComponent then
        Vendor.instance:RegisterComponent(MODE.BUYBACK, Vendor.BuybackComponent)
    end
    if Vendor.FenceSellComponent then
        Vendor.instance:RegisterComponent(MODE.FENCE_SELL, Vendor.FenceSellComponent)
    end
    if Vendor.FenceLaunderComponent then
        Vendor.instance:RegisterComponent(MODE.FENCE_LAUNDER, Vendor.FenceLaunderComponent)
    end

    -- Register the item list template with our vendor-specific row setup
    Vendor.instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI.Vendor.VendorEntrySetup
    )

    -- Add column headers (matching Inventory/Banking layout)
    local COL = BETTERUI.CIM.CONST.LAYOUT.COLUMNS
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_NAME")), COL[1])
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_TYPE")), COL[2])
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_TRAIT")), COL[3])
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_STAT")), COL[4])
    Vendor.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_VALUE")), COL[5])

    -- Build keybinds
    Vendor.instance.coreKeybinds = BuildCoreKeybinds(Vendor.instance)
    Vendor.instance.tabKeybinds = BuildTabKeybinds(Vendor.instance)

    -- Initialize scene fragments manually — vendor does not use BETTERUI_BankingFooterBar
    Vendor.instance.fragment = ZO_SimpleSceneFragment:New(Vendor.instance.control)
    Vendor.instance.fragment:SetHideOnSceneHidden(true)
    -- Dummy footer fragment (vendor footer is embedded in the window template, not a separate overlay)
    local vendorFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_VendorFooterDummy", GuiRoot, CT_CONTROL)
    vendorFooterDummy:SetHidden(true)
    Vendor.instance.footerFragment = ZO_SimpleSceneFragment:New(vendorFooterDummy)
    Vendor.instance.footerFragment:SetHideOnSceneHidden(true)

    -- Create the scene
    local sceneName = BETTERUI_VENDOR_SCENE_NAME
    local scene = ZO_InteractScene:New(sceneName, SCENE_MANAGER, Vendor.VENDOR_INTERACTION)
    Vendor.instance.scene = scene

    -- Add required fragment groups (matching WindowClass.InitializeScene pattern)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(Vendor.instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(Vendor.instance.footerFragment)

    -- Register unified scene lifecycle with both keybind groups
    BETTERUI.CIM.SceneLifecycle.Register(Vendor.instance, {
        keybinds = { Vendor.instance.coreKeybinds, Vendor.instance.tabKeybinds },
        taskManager = Vendor.Tasks,
        onShowing = function(screen, wasPushed)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            screen:RefreshVendorFooter()
            screen:RefreshList()
            screen:UpdateTabHeader()
        end,
        onHiding = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
            screen._suppressListUpdates = false
            screen._isDirty = false
        end,
        onHidden = function(screen)
            local component = screen:GetActiveComponent()
            if component and component.Deactivate then
                component:Deactivate(screen)
            end
        end,
    })

    -- Alias to replace gamepad_store scene
    SCENE_MANAGER.scenes["gamepad_store"] = scene

    -- Set up vendor-specific footer labels (replace banking WITHDRAW/DEPOSIT with gold/capacity)
    Vendor.instance:InitVendorFooter()

    -- Register events
    local em = EVENT_MANAGER
    if em then
        em:RegisterForEvent(EVENT_NS .. "_Open", EVENT_OPEN_STORE, OnOpenStore)
        em:RegisterForEvent(EVENT_NS .. "_OpenFence", EVENT_OPEN_FENCE, OnOpenFence)
        em:RegisterForEvent(EVENT_NS .. "_Close", EVENT_CLOSE_STORE, OnCloseStore)
        em:RegisterForEvent(EVENT_NS .. "_InvUpdate",
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_InvFull",
            EVENT_INVENTORY_FULL_UPDATE, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_SellReceipt",
            EVENT_SELL_RECEIPT, OnSellReceipt)
        em:RegisterForEvent(EVENT_NS .. "_BuyReceipt",
            EVENT_BUY_RECEIPT, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_BuybackReceipt",
            EVENT_BUYBACK_RECEIPT, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_RepairItem",
            EVENT_ITEM_REPAIR_ALREADY_APPLIED_CONFIRMATION, OnInventoryUpdated)
        -- Fence-specific events
        em:RegisterForEvent(EVENT_NS .. "_ItemLaunder",
            EVENT_ITEM_LAUNDER_RESULT, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_FenceUpdate",
            EVENT_JUSTICE_FENCE_UPDATE, OnInventoryUpdated)
    end

    -- Expose helpers for use in Vendor module
    Vendor.GetActiveTabs = GetActiveTabs
    Vendor.IsFenceInteraction = function() return isFenceInteraction end

    Vendor.initialized = true
end

-- PUBLIC API

--- Check if the Vendor module has been initialized.
---@return boolean initialized True if Init() has completed
function BETTERUI.Vendor.IsInitialized()
    return Vendor.initialized == true
end

--- Check if a store is currently open.
---@return boolean isOpen True if the vendor scene is showing
function BETTERUI.Vendor.IsStoreOpen()
    if Vendor.instance and Vendor.instance:IsSceneShowing() then
        return true
    end
    return false
end
