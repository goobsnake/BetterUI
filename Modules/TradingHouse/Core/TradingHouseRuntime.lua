--[[
File: Modules/TradingHouse/Core/TradingHouseRuntime.lua
Purpose: Runtime scene, dialog, ownership, and event orchestration for the
         Trading House module so TradingHouse.lua can stay focused on module
         lifecycle wiring and public API.
]]

local TH = BETTERUI.TradingHouse
local MODE = TH.MODE

---@alias THTabDef {mode: number, name: fun(): string}
---@alias TradingHouseSelectionPayload {dataSource: table|nil, bagId: integer|nil, slotIndex: integer|nil}
---@alias TradingHouseSceneLifecyclePayload {keybinds: table[], taskManager: table|nil, onShowing: fun(screen: BETTERUI.TradingHouse.Class), onHiding: fun(screen: BETTERUI.TradingHouse.Class), onHidden: fun(screen: BETTERUI.TradingHouse.Class)}
---@alias TradingHouseKeybindGroup table

---@type THTabDef[]
local TH_TABS = {
    { mode = MODE.BROWSE,   name = function() return GetString(rawget(_G, "SI_BETTERUI_TH_TAB_BROWSE"))   end },
    { mode = MODE.SELL,     name = function() return GetString(rawget(_G, "SI_BETTERUI_TH_TAB_SELL"))     end },
    { mode = MODE.LISTINGS, name = function() return GetString(rawget(_G, "SI_BETTERUI_TH_TAB_LISTINGS")) end },
}

function TH.GetTabs()
    local tabs = {}
    for index, tab in ipairs(TH_TABS) do
        tabs[index] = {
            mode = tab.mode,
            name = tab.name,
        }
    end
    return tabs
end

function TH.RegisterComponents(instance)
    if TH.BrowseComponent then
        instance:RegisterComponent(MODE.BROWSE, TH.BrowseComponent)
    end
    if TH.SellComponent then
        instance:RegisterComponent(MODE.SELL, TH.SellComponent)
    end
    if TH.ListingsComponent then
        instance:RegisterComponent(MODE.LISTINGS, TH.ListingsComponent)
    end
end

function TH.SetupSelectionTooltip(instance)
    if instance.list and instance.list.SetOnSelectedDataChangedCallback then
        ---@param _ unknown
        ---@param selectedData TradingHouseSelectionPayload|nil
        instance.list:SetOnSelectedDataChangedCallback(function(_, selectedData)
            if not GAMEPAD_TOOLTIPS then
                return
            end
            local ds = selectedData and (selectedData.dataSource or selectedData) or nil
            if ds and ds.bagId and ds.slotIndex then
                GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
            else
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            end
            GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
        end)
    end
end

---@param instance BETTERUI.TradingHouse.Class
---@return table scene
function TH.CreateScene(instance)
    instance.fragment = ZO_SimpleSceneFragment:New(instance.control)
    instance.fragment:SetHideOnSceneHidden(true)

    local thFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_THFooterDummy", GuiRoot, CT_CONTROL)
    thFooterDummy:SetHidden(true)
    instance.footerFragment = ZO_SimpleSceneFragment:New(thFooterDummy)
    instance.footerFragment:SetHideOnSceneHidden(true)

    local scene = ZO_InteractScene:New(BETTERUI_TRADING_HOUSE_SCENE_NAME, SCENE_MANAGER, TH.TH_INTERACTION)
    instance.scene = scene

    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(instance.footerFragment)
    return scene
end

---@param instance BETTERUI.TradingHouse.Class
function TH.RegisterSceneLifecycle(instance)
    ---@type TradingHouseSceneLifecyclePayload
    local lifecyclePayload = {
        keybinds = { instance.coreKeybinds, instance.tabKeybinds },
        taskManager = TH.Tasks,
        onShowing = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            screen:RefreshTHFooter()
            screen:RefreshList()
            screen:UpdateTabHeader()
            if screen.list and GAMEPAD_TOOLTIPS then
                local selectedData = screen.list:GetTargetData()
                local ds = selectedData and (selectedData.dataSource or selectedData) or nil
                if ds and ds.bagId and ds.slotIndex then
                    GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
                else
                    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
                end
                GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
            end
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
    }
    BETTERUI.CIM.SceneLifecycle.Register(instance, lifecyclePayload)
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return TradingHouseKeybindGroup keybindGroup
function TH.BuildCoreKeybinds(thInstance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
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
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                SCENE_MANAGER:HideCurrentScene()
            end,
        },
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
---@return TradingHouseKeybindGroup keybindGroup
function TH.BuildTabKeybinds(thInstance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
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

function BETTERUI.TradingHouse.Class:CycleTabs(direction)
    if #TH_TABS <= 1 then
        return
    end

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
        newIndex = ((currentIndex - 1 + direction) % #TH_TABS) + 1
    end
    self:SetMode(TH_TABS[newIndex].mode)
    self:UpdateTabHeader()
end

function BETTERUI.TradingHouse.Class:UpdateTabHeader()
    local currentMode = self:GetCurrentMode()

    for _, tab in ipairs(TH_TABS) do
        if tab.mode == currentMode then
            local tabName = tab.name()
            local guildName = self:GetCurrentGuildName()
            local title = "|c0066FF" .. guildName .. "|r - " .. tabName
            if self.header and self.header.SetTitle then
                self.header:SetTitle(title)
            end
            break
        end
    end
end

function BETTERUI.TradingHouse.Class:CycleGuild(direction)
    local numGuilds = GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() or 0
    if numGuilds <= 1 then
        return
    end

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
