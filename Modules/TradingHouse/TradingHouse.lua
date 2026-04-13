--[[
File: Modules/TradingHouse/TradingHouse.lua
Purpose: Main orchestrator for the Trading House module.

This file handles:
1. Creating the TradingHouse class instance and scene
2. Registering all components (Browse, Sell, Listings)
3. Wiring EVENT_TRADING_HOUSE_* events
4. Tab navigation (carousel or tab-bar)
5. Scene alias so BetterUI replaces the native gamepad_trading_house scene
6. Guild switching via D-Pad

KEY MECHANICS:
  - EVENT_OPEN_TRADING_HOUSE: Opens in BROWSE mode with Browse/Sell/Listings tabs
  - EVENT_CLOSE_TRADING_HOUSE: Hides the scene and restores native alias
  - Tab switching calls TradingHouseClass:SetMode() which routes to component Activate/Deactivate
  - Scene is created as ZO_InteractScene and aliased to gamepad_trading_house
  - D-Pad Left/Right cycles guilds via SelectTradingHouseGuildId
]]

-- LOCAL STATE
local TH         = BETTERUI.TradingHouse
local MODE       = TH.MODE
local EVENT_NS   = "BetterUI_TradingHouse"

-- TAB DEFINITIONS

---@alias THTabDef {mode: number, name: fun(): string}

---@type THTabDef[]
local TH_TABS = {
    { mode = MODE.BROWSE,   name = function() return GetString(rawget(_G, "SI_BETTERUI_TH_TAB_BROWSE"))   end },
    { mode = MODE.SELL,     name = function() return GetString(rawget(_G, "SI_BETTERUI_TH_TAB_SELL"))     end },
    { mode = MODE.LISTINGS, name = function() return GetString(rawget(_G, "SI_BETTERUI_TH_TAB_LISTINGS")) end },
}

-- SCENE ALIAS MANAGEMENT

local TH_SYSTEM_NAME = rawget(_G, "ZO_TRADING_HOUSE_SYSTEM_NAME") or "tradingHouse"

local function SetTHSceneAlias(sceneObject)
    if not SCENE_MANAGER or not SCENE_MANAGER.scenes then return end
    SCENE_MANAGER.scenes["gamepad_trading_house"] = sceneObject
end

local function SetTHSystemGamepadRootScene(sceneObject)
    if not SYSTEMS or type(SYSTEMS.GetSystem) ~= "function" then return end
    local system = SYSTEMS:GetSystem(TH_SYSTEM_NAME)
    if not system then return end
    if TH.nativeTHSystemGamepadRootScene == nil then
        TH.nativeTHSystemGamepadRootScene = system.gamepadRootScene
    end
    system.gamepadRootScene = sceneObject
end

local function RestoreNativeTHSceneAlias()
    if TH.nativeTHScene then
        SetTHSceneAlias(TH.nativeTHScene)
    end
    if TH.nativeTHSystemGamepadRootScene then
        SetTHSystemGamepadRootScene(TH.nativeTHSystemGamepadRootScene)
    end
end

local function AliasTHSceneToBetterUI()
    if TH.instance and TH.instance.scene then
        SetTHSceneAlias(TH.instance.scene)
        SetTHSystemGamepadRootScene(TH.instance.scene)
    end
end

-- KEYBINDS

---@param thInstance BETTERUI.TradingHouse.Class
---@return table keybindGroup Core keybind descriptor group
local function BuildCoreKeybinds(thInstance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Primary action (A / GAMEPAD_BUTTON_1): Buy / List / Cancel
        {
            name = function()
                local component = thInstance:GetActiveComponent()
                if component and component.GetPrimaryActionName then
                    return component:GetPrimaryActionName(thInstance)
                end
                return GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION"))
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local component = thInstance:GetActiveComponent()
                if component and component.OnPrimaryAction then
                    component:OnPrimaryAction(thInstance)
                end
            end,
            enabled = function()
                local component = thInstance:GetActiveComponent()
                if component and component.IsPrimaryActionEnabled then
                    return component:IsPrimaryActionEnabled(thInstance)
                end
                local selectedData = thInstance.list and thInstance.list:GetSelectedData()
                return selectedData ~= nil
            end,
        },
        -- Secondary action (X / GAMEPAD_BUTTON_3): Search (Browse mode)
        {
            name = function()
                local mode = thInstance:GetCurrentMode()
                if mode == MODE.BROWSE then
                    return GetString(rawget(_G, "SI_BETTERUI_TH_SEARCH"))
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                return thInstance:GetCurrentMode() == MODE.BROWSE
            end,
            enabled = function()
                if TH.BrowseComponent and TH.BrowseComponent.searchPending then
                    return false
                end
                return true
            end,
            callback = function()
                if TH.BrowseComponent then
                    TH.BrowseComponent:ExecuteSearch()
                end
            end,
        },
        -- Tertiary action (Y / GAMEPAD_BUTTON_4): Load Preset (Browse mode)
        {
            name = function()
                if thInstance:GetCurrentMode() == MODE.BROWSE then
                    return GetString(rawget(_G, "SI_BETTERUI_TH_PRESETS") or "SI_BETTERUI_TH_PRESETS")
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                return thInstance:GetCurrentMode() == MODE.BROWSE
                    and TH.SearchPresets ~= nil
            end,
            callback = function()
                if TH.SearchPresets then
                    TH.SearchPresets.ShowLoadDialog()
                end
            end,
        },
        -- Right Stick: Save Preset (Browse mode)
        {
            name = function()
                if thInstance:GetCurrentMode() == MODE.BROWSE then
                    return GetString(rawget(_G, "SI_BETTERUI_TH_SAVE_PRESET") or "SI_BETTERUI_TH_SAVE_PRESET")
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = function()
                return thInstance:GetCurrentMode() == MODE.BROWSE
                    and TH.SearchPresets ~= nil
            end,
            callback = function()
                if TH.SearchPresets then
                    TH.SearchPresets.ShowSaveDialog()
                end
            end,
        },
        -- Back / Exit (B / GAMEPAD_BUTTON_2)
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                SCENE_MANAGER:HideCurrentScene()
            end,
        },
        -- Guild cycle: Left Trigger (previous guild)
        {
            name = function()
                local id = rawget(_G, "SI_BETTERUI_TH_GUILD_PREV")
                return id and GetString(id) or "Previous Guild"
            end,
            keybind = "UI_SHORTCUT_LEFT_TRIGGER",
            ethereal = true,
            visible = function()
                return GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() > 1
            end,
            callback = function()
                thInstance:CycleGuild(-1)
            end,
        },
        -- Guild cycle: Right Trigger (next guild)
        {
            name = function()
                local id = rawget(_G, "SI_BETTERUI_TH_GUILD_NEXT")
                return id and GetString(id) or "Next Guild"
            end,
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            ethereal = true,
            visible = function()
                return GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() > 1
            end,
            callback = function()
                thInstance:CycleGuild(1)
            end,
        },
        -- Pagination: Next Page (Browse only)
        {
            name = function()
                local id = rawget(_G, "SI_BETTERUI_TH_NEXT_PAGE")
                return id and GetString(id) or "Next Page"
            end,
            keybind = "UI_SHORTCUT_QUATERNARY",
            visible = function()
                return thInstance:GetCurrentMode() == MODE.BROWSE
                    and TH.BrowseComponent
                    and TH.BrowseComponent.hasMorePages == true
            end,
            enabled = function()
                return TH.BrowseComponent and TH.BrowseComponent.hasMorePages == true
            end,
            callback = function()
                if TH.BrowseComponent then
                    TH.BrowseComponent:NextPage(thInstance)
                end
            end,
        },
        -- Pagination: Previous Page (Browse only)
        {
            name = function()
                local id = rawget(_G, "SI_BETTERUI_TH_PREV_PAGE")
                return id and GetString(id) or "Previous Page"
            end,
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                return thInstance:GetCurrentMode() == MODE.BROWSE
                    and TH.BrowseComponent
                    and (TH.BrowseComponent.currentPage or 0) > 0
            end,
            enabled = function()
                return TH.BrowseComponent and (TH.BrowseComponent.currentPage or 0) > 0
            end,
            callback = function()
                if TH.BrowseComponent then
                    TH.BrowseComponent:PrevPage(thInstance)
                end
            end,
        },
    }
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return table keybindGroup Tab navigation keybind descriptor group
local function BuildTabKeybinds(thInstance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Switch tabs left (LB / GAMEPAD_BUTTON_5)
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_PAGED_LIST_PAGE_LEFT_NARRATION")),
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            callback = function()
                thInstance:CycleTabs(-1)
            end,
            enabled = function()
                return #TH_TABS > 1
            end,
        },
        -- Switch tabs right (RB / GAMEPAD_BUTTON_6)
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_PAGED_LIST_PAGE_RIGHT_NARRATION")),
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            callback = function()
                thInstance:CycleTabs(1)
            end,
            enabled = function()
                return #TH_TABS > 1
            end,
        },
    }
end

-- TAB CYCLING

---@param direction number -1 for left, 1 for right
function BETTERUI.TradingHouse.Class:CycleTabs(direction)
    if #TH_TABS <= 1 then return end

    -- Find current tab index
    local currentMode = self:GetCurrentMode()
    local currentIndex = 1
    for i, tab in ipairs(TH_TABS) do
        if tab.mode == currentMode then
            currentIndex = i
            break
        end
    end

    local newIndex
    if TH.GetSetting("enableCarousel") == false then
        newIndex = currentIndex + direction
        if newIndex < 1 or newIndex > #TH_TABS then
            return
        end
    else
        -- Carousel wraps around
        newIndex = ((currentIndex - 1 + direction) % #TH_TABS) + 1
    end
    self:SetMode(TH_TABS[newIndex].mode)

    -- Update header to reflect new tab
    self:UpdateTabHeader()
end

--- Updates the header title to show the current tab name plus guild.
function BETTERUI.TradingHouse.Class:UpdateTabHeader()
    local currentMode = self:GetCurrentMode()

    for _, tab in ipairs(TH_TABS) do
        if tab.mode == currentMode then
            local tabName   = tab.name()
            local guildName = self:GetCurrentGuildName()
            local title     = "|c0066FF" .. guildName .. "|r - " .. tabName
            if self.header and self.header.SetTitle then
                self.header:SetTitle(title)
            end
            break
        end
    end
end

-- GUILD SWITCHING

--- Cycles through available trading house guilds.
---@param direction number -1 for previous, 1 for next
function BETTERUI.TradingHouse.Class:CycleGuild(direction)
    local numGuilds = GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() or 0
    if numGuilds <= 1 then return end

    -- Find current guild index
    local currentGuildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
    local currentIndex = 1
    for i = 1, numGuilds do
        local guildId = GetTradingHouseGuildDetails and select(1, GetTradingHouseGuildDetails(i)) or nil
        if guildId == currentGuildId then
            currentIndex = i
            break
        end
    end

    local newIndex = ((currentIndex - 1 + direction) % numGuilds) + 1
    local newGuildId = GetTradingHouseGuildDetails and select(1, GetTradingHouseGuildDetails(newIndex)) or nil
    if newGuildId and SelectTradingHouseGuildId then
        SelectTradingHouseGuildId(newGuildId)
    end
end

-- CREATE-LISTING DIALOG

local function RegisterCreateListingDialog()
    if ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered("BETTERUI_TRADING_HOUSE_CREATE_LISTING") then
        return
    end

    -- Use ESO's parametric dialog to let the user choose stack count and price
    ZO_Dialogs_RegisterCustomDialog("BETTERUI_TRADING_HOUSE_CREATE_LISTING", {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title = {
            text = rawget(_G, "SI_BETTERUI_TH_LIST_ITEM") or SI_TRADING_HOUSE_POST_ITEM,
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        parametricList = {
            -- Stack count slider
            {
                template = "ZO_GamepadSliderDialogTemplate",
                text = GetString(rawget(_G, "SI_TRADING_HOUSE_POSTING_QUANTITY")),
                templateData = {
                    setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                        local dialog = data.dialog or ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        local dialogData = dialog and dialog.data
                        local maxStack = dialogData and dialogData.stackCount or 1
                        control.slider:SetMinMax(1, maxStack)
                        control.slider:SetValue(dialogData and dialogData.selectedStackCount or maxStack)
                        control.slider:SetValueChangedCallback(function(_, value)
                            if dialogData then
                                dialogData.selectedStackCount = value
                            end
                        end)
                    end,
                },
            },
            -- Price input slider
            {
                template = "ZO_GamepadSliderDialogTemplate",
                text = GetString(rawget(_G, "SI_BETTERUI_TH_PRICE_LABEL")),
                templateData = {
                    setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                        local dialog = data.dialog or ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        local dialogData = dialog and dialog.data
                        -- Default price hint: use the item's vendor sell price * stack as starting point
                        local defaultPrice = dialogData and dialogData.defaultPrice or 100
                        local maxPrice = 999999999
                        control.slider:SetMinMax(1, maxPrice)
                        control.slider:SetValue(defaultPrice)
                        control.slider:SetValueChangedCallback(function(_, value)
                            if dialogData then
                                dialogData.selectedPrice = value
                            end
                        end)
                    end,
                },
            },
        },
        buttons = {
            {
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    local data = dialog.data
                    if not data then return end

                    -- Guard against double-submission
                    if data._submitted then return end
                    data._submitted = true

                    local bagId     = data.bagId
                    local slotIndex = data.slotIndex
                    local stackCount = data.selectedStackCount or data.stackCount or 1
                    local price = data.selectedPrice or 0

                    if price <= 0 then
                        data._submitted = false
                        BETTERUI.CIM.UserAlertText("TH:NoPrice",
                            GetString(rawget(_G, "SI_BETTERUI_TH_ENTER_PRICE")))
                        return
                    end

                    -- Post the listing
                    if PostItemOnTradingHouse then
                        PostItemOnTradingHouse(bagId, slotIndex, stackCount, price)
                    end
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
            },
        },
    })
end

-- EVENT HANDLERS

local function OnOpenTradingHouse()
    if not TH.instance then return end

    -- Guard: only take ownership for genuine trading house interactions
    local interactionType = GetInteractionType and GetInteractionType() or nil
    if interactionType and interactionType ~= INTERACTION_TRADINGHOUSE then
        RestoreNativeTHSceneAlias()
        return
    end

    AliasTHSceneToBetterUI()

    -- Default to Browse tab
    TH.instance:SetMode(MODE.BROWSE)
    TH.instance:UpdateTabHeader()

    -- Reset browse state
    if TH.BrowseComponent then
        TH.BrowseComponent.currentPage = 0
        TH.BrowseComponent.searchPending = false
    end

    -- Show the scene
    if SCENE_MANAGER then
        SCENE_MANAGER:Show(BETTERUI_TRADING_HOUSE_SCENE_NAME)
    end

    -- Native trading-house handlers may also request a scene show in this event.
    -- Re-assert ownership shortly after dispatch so BetterUI remains the active scene.
    local function ReassertTradingHouseOwnership()
        local currentInteraction = GetInteractionType and GetInteractionType() or nil
        if currentInteraction and currentInteraction ~= INTERACTION_TRADINGHOUSE then
            return
        end
        AliasTHSceneToBetterUI()
        if SCENE_MANAGER then
            SCENE_MANAGER:Show(BETTERUI_TRADING_HOUSE_SCENE_NAME)
        end
    end

    if TH.Tasks then
        TH.Tasks:Cancel("sceneOwnershipOpen")
        TH.Tasks:Schedule("sceneOwnershipOpen", 30, ReassertTradingHouseOwnership)
    elseif type(zo_callLater) == "function" then
        zo_callLater(ReassertTradingHouseOwnership, 30)
    end
end

local function OnCloseTradingHouse()
    if TH.Tasks then
        TH.Tasks:Cancel("sceneOwnershipOpen")
    end

    local sceneName = BETTERUI_TRADING_HOUSE_SCENE_NAME
    if SCENE_MANAGER then
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene and scene.IsShowing and scene:IsShowing() then
            SCENE_MANAGER:Hide(sceneName)
        end
    end

    -- Keep BetterUI ownership for the next open so native open handlers route here.
    AliasTHSceneToBetterUI()
end

local function OnSearchResultsReceived()
    if TH.BrowseComponent then
        TH.BrowseComponent:OnSearchResultsReceived(TH.instance)
    end
end

local function OnSearchCooldownUpdate()
    -- Update keybinds to reflect search button enabled/disabled state
    if TH.instance and TH.instance:IsSceneShowing() then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end
end

local function OnTradingHouseResponse(_, responseType, result)
    if not TH.instance then return end
    if not TH.instance:IsSceneShowing() then return end

    -- Refresh after successful operations
    if result == TRADING_HOUSE_RESULT_SUCCESS then
        -- Coalesce rapid updates
        TH.Tasks:Cancel("listRefresh")
        TH.Tasks:Schedule("listRefresh", 100, function()
            if TH.instance and TH.instance:IsSceneShowing() then
                TH.instance:RefreshList()
                TH.instance:RefreshTHFooter()
            end
        end)
    end
end

local function OnGuildSelfJoinedGuild()
    -- Could change available guilds; update header
    if TH.instance and TH.instance:IsSceneShowing() then
        TH.instance:UpdateTabHeader()
    end
end

local function OnListingOperation()
    -- Refresh listings after posting or cancelling
    if not TH.instance then return end
    if not TH.instance:IsSceneShowing() then return end

    TH.Tasks:Cancel("listRefresh")
    TH.Tasks:Schedule("listRefresh", 100, function()
        if TH.instance and TH.instance:IsSceneShowing() then
            TH.instance:RefreshList()
            TH.instance:RefreshTHFooter()
        end
    end)
end

-- INITIALIZATION

--- Initializes the Trading House module.
function BETTERUI.TradingHouse.Init()
    if TH.initialized then return end

    -- Register the create-listing dialog
    RegisterCreateListingDialog()

    -- Create the TradingHouse class instance
    TH.instance = TH.Class:New("BETTERUI_TradingHouseWindow", BETTERUI_TRADING_HOUSE_SCENE_NAME)
    TH.instance:SetTitle("|c0066FF" ..
        GetString(rawget(_G, "SI_BETTERUI_TH_TITLE")) .. "|r")

    -- Register components
    if TH.BrowseComponent then
        TH.instance:RegisterComponent(MODE.BROWSE, TH.BrowseComponent)
    end
    if TH.SellComponent then
        TH.instance:RegisterComponent(MODE.SELL, TH.SellComponent)
    end
    if TH.ListingsComponent then
        TH.instance:RegisterComponent(MODE.LISTINGS, TH.ListingsComponent)
    end

    -- Register the item list template with our TH-specific row setup
    TH.instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI.TradingHouse.THEntrySetup
    )

    -- Add column headers (matching Inventory/Banking/Vendor layout)
    local COL = BETTERUI.CIM.CONST.LAYOUT.COLUMNS
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_NAME")),  COL[1])
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_TYPE")),  COL[2])
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_TRAIT")), COL[3])
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_STAT")),  COL[4])
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_VALUE")), COL[5])

    -- Build keybinds
    TH.instance.coreKeybinds = BuildCoreKeybinds(TH.instance)
    TH.instance.tabKeybinds  = BuildTabKeybinds(TH.instance)

    -- Initialize scene fragments
    TH.instance.fragment = ZO_SimpleSceneFragment:New(TH.instance.control)
    TH.instance.fragment:SetHideOnSceneHidden(true)

    local thFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_THFooterDummy", GuiRoot, CT_CONTROL)
    thFooterDummy:SetHidden(true)
    TH.instance.footerFragment = ZO_SimpleSceneFragment:New(thFooterDummy)
    TH.instance.footerFragment:SetHideOnSceneHidden(true)

    -- Create the scene
    local sceneName = BETTERUI_TRADING_HOUSE_SCENE_NAME
    local scene = ZO_InteractScene:New(sceneName, SCENE_MANAGER, TH.TH_INTERACTION)
    TH.instance.scene = scene

    -- Capture native TH scene so we can restore it if needed
    TH.nativeTHScene = TH.nativeTHScene or (SCENE_MANAGER and SCENE_MANAGER:GetScene("gamepad_trading_house"))

    -- Suppress native trading house manager interference.
    -- The native OnOpenTradingHouse handler shows the native scene which conflicts
    -- with BetterUI's scene. Unregister native handlers and redirect sceneName
    -- so the native system cannot show its UI.
    local nativeTH = rawget(_G, "TRADING_HOUSE_GAMEPAD")
    if nativeTH then
        if nativeTH.control then
            nativeTH.control:UnregisterForEvent(EVENT_OPEN_TRADING_HOUSE)
            nativeTH.control:UnregisterForEvent(EVENT_CLOSE_TRADING_HOUSE)
        end
        -- Also unregister the primary native handlers registered on EVENT_MANAGER
        if ZO_TRADING_HOUSE_SYSTEM_NAME then
            EVENT_MANAGER:UnregisterForEvent(ZO_TRADING_HOUSE_SYSTEM_NAME, EVENT_OPEN_TRADING_HOUSE)
            EVENT_MANAGER:UnregisterForEvent(ZO_TRADING_HOUSE_SYSTEM_NAME, EVENT_CLOSE_TRADING_HOUSE)
        end
        -- Redirect native sceneName so any native ShowComponent checks fail
        if nativeTH.sceneName then
            nativeTH.sceneName = "betterui_native_th_blocked"
        end
        -- Override the native system object methods so any engine path that calls
        -- OpenTradingHouse/CloseTradingHouse routes to BetterUI instead.
        nativeTH.OpenTradingHouse = function(_)
            OnOpenTradingHouse()
        end
        nativeTH.CloseTradingHouse = function(_)
            OnCloseTradingHouse()
        end
    end

    -- Add standard fragment groups (matching Vendor/Banking pattern)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(TH.instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(TH.instance.footerFragment)

    -- Register unified scene lifecycle with both keybind groups
    BETTERUI.CIM.SceneLifecycle.Register(TH.instance, {
        keybinds = { TH.instance.coreKeybinds, TH.instance.tabKeybinds },
        taskManager = TH.Tasks,
        onShowing = function(screen, wasPushed)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            screen:RefreshTHFooter()
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

    -- Keep BetterUI alias by default so EVENT_OPEN_TRADING_HOUSE resolves here.
    AliasTHSceneToBetterUI()

    -- Set up footer (gold + bag capacity)
    TH.instance:InitTHFooter()

    -- Register events
    local em = EVENT_MANAGER
    if em then
        em:RegisterForEvent(EVENT_NS .. "_Open",
            EVENT_OPEN_TRADING_HOUSE, OnOpenTradingHouse)
        em:RegisterForEvent(EVENT_NS .. "_Close",
            EVENT_CLOSE_TRADING_HOUSE, OnCloseTradingHouse)
        em:RegisterForEvent(EVENT_NS .. "_SearchResults",
            EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED, OnSearchResultsReceived)
        em:RegisterForEvent(EVENT_NS .. "_Cooldown",
            EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE, OnSearchCooldownUpdate)
        em:RegisterForEvent(EVENT_NS .. "_Response",
            EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, OnTradingHouseResponse)
        em:RegisterForEvent(EVENT_NS .. "_ListingOp",
            EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE, OnListingOperation)
        em:RegisterForEvent(EVENT_NS .. "_GuildJoin",
            EVENT_GUILD_SELF_JOINED_GUILD, OnGuildSelfJoinedGuild)
        em:RegisterForEvent(EVENT_NS .. "_GuildLeave",
            EVENT_GUILD_SELF_LEFT_GUILD, OnGuildSelfJoinedGuild)
        -- Inventory changes while posting
        em:RegisterForEvent(EVENT_NS .. "_InvUpdate",
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
                if TH.instance and TH.instance:IsSceneShowing() and
                   TH.instance:GetCurrentMode() == MODE.SELL then
                    OnListingOperation()
                end
            end)
    end

    -- Expose helpers
    TH.GetTabs = function() return TH_TABS end

    -- Register narration for Trading House scene (ACC-001)
    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_TRADING_HOUSE_SCENE_NAME,
            function() return TH.instance and TH.instance.list and TH.instance.list:GetTargetData() end,
            function() return TH.instance and TH.instance:GetTitle() end
        )
    end

    TH.initialized = true
end

-- PUBLIC API

--- Check if the Trading House module has been initialized.
---@return boolean initialized True if Init() has completed
function BETTERUI.TradingHouse.IsInitialized()
    return TH.initialized == true
end

--- Check if the trading house is currently open.
---@return boolean isOpen True if the TH scene is showing
function BETTERUI.TradingHouse.IsTradingHouseOpen()
    if TH.instance and TH.instance:IsSceneShowing() then
        return true
    end
    return false
end
