--[[
File: Modules/Companions/Module.lua
Purpose: Entry point for the Companions equipment management module.
         Provides companion equipment viewing/management through BetterUI's
         enhanced interface (column headers, icon badges, font controls).

ESO Reference: ZO_CompanionEquipment_Gamepad in
  esoui/ingame/companion/gamepad/companionequipment_gamepad.lua
  Uses BAG_COMPANION_WORN for equipped companion gear and BAG_BACKPACK for
  equippable companion items. Scene: "companionEquipmentGamepad".
]]

BETTERUI.Companions = BETTERUI.Companions or {}

-- Constants are defined in Core/CompanionsClass.lua (loaded first)

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
if BETTERUI.CIM and BETTERUI.CIM.RegisterModuleAccessors then
    BETTERUI.CIM.RegisterModuleAccessors("Companions")
end

-- LOCAL STATE
local Companions   = BETTERUI.Companions
local EVENT_NS     = "BetterUI_Companions"

--- Initializes defaults and applies fallback values for saved variables.
---@param m_options table|nil Module options from saved variables
---@return table m_options Initialized options with defaults applied
function BETTERUI.Companions.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.Companions.DEFAULTS
    local fallbackDefaults = {
        enableCompanionEquipment = true,
    }

    m_options = BETTERUI.CIM.InitModuleDefaults("Companions", m_options, defaults, fallbackDefaults)
    return m_options
end

--- Lifecycle hook: registers settings panel and initializes the module.
--- Called by BETTERUI.LoadModules() via MODULE_REGISTRY.
function BETTERUI.Companions.Setup()
    BETTERUI.Companions.Init()
end

-- KEYBINDS

---@param bagId number
---@param slotIndex number
---@return number|nil equipSlot
local function ResolveCompanionEquipSlot(bagId, slotIndex)
    local equipType = GetItemEquipType and GetItemEquipType(bagId, slotIndex) or nil
    if equipType == nil or equipType == 0 or equipType == EQUIP_TYPE_INVALID then
        return nil
    end

    if not ZO_Character_EnumerateOrderedEquipSlots or not ZO_Character_DoesEquipSlotUseEquipType then
        return nil
    end

    local firstCompatibleSlot = nil
    for _, equipSlot in ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN) do
        if ZO_Character_DoesEquipSlotUseEquipType(equipSlot, equipType) then
            if not firstCompatibleSlot then
                firstCompatibleSlot = equipSlot
            end
            if not HasItemInSlot or not HasItemInSlot(BAG_COMPANION_WORN, equipSlot) then
                return equipSlot
            end
        end
    end

    return firstCompatibleSlot
end

---@param instance BETTERUI.Companions.Class
---@return table keybindGroup
local function BuildCoreKeybinds(instance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Primary action: Equip / Unequip
        {
            name = function()
                local selectedData = instance.list and instance.list:GetSelectedData()
                if selectedData then
                    local ds = selectedData.dataSource or selectedData
                    if ds.isEquipped then
                        return GetString(rawget(_G, "SI_ITEM_ACTION_UNEQUIP") or "SI_ITEM_ACTION_UNEQUIP")
                    end
                end
                return GetString(rawget(_G, "SI_ITEM_ACTION_EQUIP") or "SI_ITEM_ACTION_EQUIP")
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local selectedData = instance.list and instance.list:GetSelectedData()
                if not selectedData then return end
                local ds = selectedData.dataSource or selectedData
                local bagId = ds.bagId
                local slotIndex = ds.slotIndex
                if bagId == nil or slotIndex == nil then return end

                if ds.isEquipped then
                    -- Unequip: move companion item to backpack
                    if not GetNumBagFreeSlots(BAG_BACKPACK) or GetNumBagFreeSlots(BAG_BACKPACK) == 0 then
                        BETTERUI.CIM.UserAlertText("Companions:BagFull",
                            GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_CARRY") or "SI_BETTERUI_VENDOR_CANNOT_CARRY"))
                        return
                    end
                    if CallSecureProtected then
                        CallSecureProtected("RequestMoveItem",
                            BAG_COMPANION_WORN, slotIndex, BAG_BACKPACK, 0, 1)
                    end
                else
                    -- Equip to the first compatible companion equipment slot.
                    local equipSlot = ResolveCompanionEquipSlot(bagId, slotIndex)
                    if not equipSlot then return end

                    if CallSecureProtected then
                        CallSecureProtected("RequestMoveItem",
                            bagId, slotIndex, BAG_COMPANION_WORN, equipSlot, 1)
                    end
                end
            end,
            enabled = function()
                local selectedData = instance.list and instance.list:GetSelectedData()
                return selectedData ~= nil
            end,
        },
        -- Back / Exit
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION") or "SI_GAMEPAD_BACK_OPTION"),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                SCENE_MANAGER:HideCurrentScene()
            end,
        },
    }
end

-- EVENT HANDLERS

local function OnCompanionActivated()
    if not Companions.instance then return end
    if Companions.instance:IsSceneShowing() then
        Companions.instance:RefreshList()
        Companions.instance:RefreshCompanionFooter()
    end
end

local function OnCompanionDeactivated()
    if not Companions.instance then return end
    if Companions.instance:IsSceneShowing() then
        SCENE_MANAGER:HideCurrentScene()
    end
end

local function OnInventoryUpdated()
    if not Companions.instance then return end
    if not Companions.instance:IsSceneShowing() then return end

    Companions.Tasks:Cancel("listRefresh")
    Companions.Tasks:Schedule("listRefresh", 100, function()
        if Companions.instance and Companions.instance:IsSceneShowing() then
            Companions.instance:RefreshList()
            Companions.instance:RefreshCompanionFooter()
        end
    end)
end

-- INITIALIZATION

--- Core initialization: creates the companion equipment window and scene.
function BETTERUI.Companions.Init()
    if Companions.initialized then return end

    -- Guard: companion system may not be available on older API versions
    if not INTERACTION_COMPANION_MENU then
        BETTERUI.Debug("[Companions] INTERACTION_COMPANION_MENU not available — skipping init")
        Companions.initialized = true
        return
    end

    -- Create the class instance
    Companions.instance = Companions.Class:New(
        "BETTERUI_CompanionWindow", BETTERUI_COMPANION_EQUIP_SCENE_NAME)
    Companions.instance:SetTitle(
        "|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_TITLE") or "SI_BETTERUI_COMPANIONS_TITLE") .. "|r")

    -- Register the item list template
    Companions.instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup
    )

    -- Add column headers
    local COL = BETTERUI.CIM.CONST.LAYOUT.COLUMNS
    Companions.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_NAME")), COL[1])
    Companions.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_TYPE")), COL[2])
    Companions.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_TRAIT")), COL[3])
    Companions.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_STAT")), COL[4])
    Companions.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_VALUE")), COL[5])

    -- Build keybinds
    Companions.instance.coreKeybinds = BuildCoreKeybinds(Companions.instance)

    -- Initialize scene fragments (no banking footer overlay)
    Companions.instance.fragment = ZO_SimpleSceneFragment:New(Companions.instance.control)
    Companions.instance.fragment:SetHideOnSceneHidden(true)
    local companionFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_CompanionFooterDummy", GuiRoot, CT_CONTROL)
    companionFooterDummy:SetHidden(true)
    Companions.instance.footerFragment = ZO_SimpleSceneFragment:New(companionFooterDummy)
    Companions.instance.footerFragment:SetHideOnSceneHidden(true)

    -- Create the scene
    local sceneName = BETTERUI_COMPANION_EQUIP_SCENE_NAME
    local scene = ZO_InteractScene:New(sceneName, SCENE_MANAGER, Companions.COMPANION_INTERACTION)
    Companions.instance.scene = scene

    -- Add fragment groups
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(Companions.instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(Companions.instance.footerFragment)

    -- Register unified scene lifecycle
    BETTERUI.CIM.SceneLifecycle.Register(Companions.instance, {
        keybinds = { Companions.instance.coreKeybinds },
        taskManager = Companions.Tasks,
        onShowing = function(screen, wasPushed)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            screen:RefreshCompanionFooter()
            screen:RefreshList()
        end,
        onHiding = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
        end,
        onHidden = function(screen)
            -- No cleanup needed
        end,
    })

    -- Alias to replace native companion equipment scene
    SCENE_MANAGER.scenes["companionEquipmentGamepad"] = scene

    -- Set up companion-specific footer labels
    Companions.instance:InitCompanionFooter()

    -- Register events
    local em = EVENT_MANAGER
    if em then
        if EVENT_COMPANION_ACTIVATED then
            em:RegisterForEvent(EVENT_NS .. "_CompActivated",
                EVENT_COMPANION_ACTIVATED, OnCompanionActivated)
        end
        if EVENT_COMPANION_DEACTIVATED then
            em:RegisterForEvent(EVENT_NS .. "_CompDeactivated",
                EVENT_COMPANION_DEACTIVATED, OnCompanionDeactivated)
        end
        em:RegisterForEvent(EVENT_NS .. "_InvUpdate",
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_InvFull",
            EVENT_INVENTORY_FULL_UPDATE, OnInventoryUpdated)
    end

    Companions.initialized = true
end
