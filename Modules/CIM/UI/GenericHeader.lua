local TABBAR         = ZO_GAMEPAD_HEADER_CONTROLS.TABBAR
local TITLE          = ZO_GAMEPAD_HEADER_CONTROLS.TITLE
local TITLE_BASELINE = ZO_GAMEPAD_HEADER_CONTROLS.TITLE_BASELINE
local DIVIDER_SIMPLE = ZO_GAMEPAD_HEADER_CONTROLS.DIVIDER_SIMPLE
local DIVIDER_PIPPED = ZO_GAMEPAD_HEADER_CONTROLS.DIVIDER_PIPPED

local function TabBar_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    local countBadge = control:GetNamedChild("CountBadge")
    local icon = control:GetNamedChild("Icon")

    local iconPath = data.iconsNormal[1]
    icon:SetTexture(iconPath)

    local colors = BETTERUI.CIM.CONST.COLORS
    local color = data.filterType and colors.TAB_ICON_FILTER or colors.TAB_ICON_GOLD
    icon:SetColor(color[1], color[2], color[3], icon:GetControlAlpha())

    if data.canSelect == nil then
        data.canSelect = true
    end

    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseUp", function(self)
        BETTERUI_TabBar_OnCategoryIconClicked(self)
    end)

    ZO_GamepadMenuHeaderTemplate_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)

    if not countBadge then return end
    if not (selected and data.itemCount and data.itemCount > 0) then
        countBadge:SetHidden(true)
        return
    end

    countBadge:SetText("[" .. tostring(data.itemCount) .. "]")
    countBadge:SetHidden(false)
    countBadge:SetColor(1, 1, 1, 0.9)

    if data.countBadgeOffsetY then
        countBadge:ClearAnchors()
        countBadge:SetAnchor(BOTTOM, icon, TOP, 0, data.countBadgeOffsetY)
    end
end

---@param control table
---@param createTabBar integer?
---@param layout table?
---@return nil
function BETTERUI.GenericHeader.Initialize(control, createTabBar, layout)
    local titleContainer = control:GetNamedChild("TitleContainer")
    control.controls =
    {
        [TABBAR]         = control:GetNamedChild("TabBar"),
        [TITLE]          = titleContainer and titleContainer:GetNamedChild("Title"),
        [TITLE_BASELINE] = titleContainer,
        [DIVIDER_SIMPLE] = control:GetNamedChild("DividerSimple"),
        [DIVIDER_PIPPED] = control:GetNamedChild("DividerPipped"),
    }

    if createTabBar == ZO_GAMEPAD_HEADER_TABBAR_CREATE then
        local tabBarControl = control.controls[TABBAR]
        if tabBarControl then
            tabBarControl:SetHidden(false)
        end
    end
end

local TEXT_ALIGN_RIGHT = 2

local function TabBar_OnDataChanged(list, selectedData, oldSelectedData, reselectingDuringRebuild)
    if selectedData then
        local categoryList = (selectedData and selectedData.categoryList) or GAMEPAD_INVENTORY.categoryList
        for i = 1, categoryList:GetNumEntries() do
            if categoryList:GetEntryData(i) == selectedData then
                categoryList:SetSelectedIndex(i)
                break
            end
        end
    end
end

---@param control table
---@param data table
---@return nil
function BETTERUI.GenericHeader.AddToList(control, data)
    control.tabBar:AddEntry("BETTERUI_GamepadTabBarTemplate", data)
end

local function UpdateEquipText(control, controlName, slotStringKey, isActive, hideIfLocked)
    local equipControl = control:GetNamedChild("TitleContainer"):GetNamedChild(controlName)
    if not equipControl then return end

    if hideIfLocked and GetUnitLevel("player") < GetWeaponSwapUnlockedLevel() then
        equipControl:SetHidden(true)
        return
    end

    equipControl:SetHidden(false)
    local formatKey = isActive and SI_BETTERUI_INV_EQUIP_TEXT_HIGHLIGHT or SI_BETTERUI_INV_EQUIP_TEXT_NORMAL
    equipControl:SetText(zo_strformat(GetString(formatKey), GetString(slotStringKey)))
    equipControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
end

---@param control table
---@param isEquipMain boolean
---@return nil
function BETTERUI.GenericHeader.SetEquipText(control, isEquipMain)
    UpdateEquipText(control, "EquipText", SI_BETTERUI_INV_EQUIPSLOT_MAIN, isEquipMain, false)
end

---@param control table
---@param isEquipMain boolean
---@return nil
function BETTERUI.GenericHeader.SetBackupEquipText(control, isEquipMain)
    UpdateEquipText(control, "BackupEquipText", SI_BETTERUI_INV_EQUIPSLOT_BACKUP, not isEquipMain, true)
end

---@param control table
---@param titleText string
---@return nil
function BETTERUI.GenericHeader.SetTitleText(control, titleText)
    local titleTextControl = control:GetNamedChild("TitleContainer"):GetNamedChild("Title")
    titleTextControl:SetText(titleText)
end

local function UpdateEquippedIcons(control, iconNames, iconsData, hideIfLocked)
    local titleContainer = control:GetNamedChild("TitleContainer")
    if not titleContainer then return end

    if hideIfLocked and GetUnitLevel("player") < GetWeaponSwapUnlockedLevel() then
        if iconNames.main then titleContainer:GetNamedChild(iconNames.main):SetHidden(true) end
        if iconNames.off then titleContainer:GetNamedChild(iconNames.off):SetHidden(true) end
        if iconNames.poison then titleContainer:GetNamedChild(iconNames.poison):SetHidden(true) end
        return
    end

    local defaultIcon = BETTERUI.CIM.CONST.ICONS.DEFAULT_SLOT
    local mapping = {
        { name = iconNames.main,   texture = iconsData.main },
        { name = iconNames.off,    texture = iconsData.off },
        { name = iconNames.poison, texture = iconsData.poison },
    }

    for _, entry in ipairs(mapping) do
        local ctrl = titleContainer:GetNamedChild(entry.name)
        if ctrl then
            ctrl:SetHidden(false)
            local texture = entry.texture
            ctrl:SetTexture((texture and texture ~= "") and texture or defaultIcon)
        end
    end
end

---@param control table
---@param equipMain string?
---@param equipOff string?
---@param equipPoison string?
---@return nil
function BETTERUI.GenericHeader.SetEquippedIcons(control, equipMain, equipOff, equipPoison)
    UpdateEquippedIcons(control,
        { main = "MainHandIcon", off = "OffHandIcon", poison = "PoisonIcon" },
        { main = equipMain, off = equipOff, poison = equipPoison },
        false)
end

---@param control table
---@param equipMain string?
---@param equipOff string?
---@param equipPoison string?
---@return nil
function BETTERUI.GenericHeader.SetBackupEquippedIcons(control, equipMain, equipOff, equipPoison)
    UpdateEquippedIcons(control,
        { main = "BackupMainHandIcon", off = "BackupOffHandIcon", poison = "BackupPoisonIcon" },
        { main = equipMain, off = equipOff, poison = equipPoison },
        true)
end

---@param control table
---@param data table
---@param blockTabBarCallbacks boolean?
---@return nil
function BETTERUI.GenericHeader.Refresh(control, data, blockTabBarCallbacks)
    control:GetNamedChild("TitleContainer"):GetNamedChild("Title"):SetText(data.titleText(data.name))

    local tabBarControl = control.controls[TABBAR]
    tabBarControl:SetHidden(false)

    if not control.tabBar then
        local tabBarData = {
            attachedTo = control,
            parent = data.tabBarData.parent,
            onNext = data.tabBarData.onNext,
            onPrev =
                data.tabBarData.onPrev
        }
        control.tabBar = BETTERUI_TabBarScrollList:New(tabBarControl, tabBarControl:GetNamedChild("LeftIcon"),
            tabBarControl:GetNamedChild("RightIcon"), tabBarData)
        control.tabBar.hideUnselectedControls = false

        control.tabBar:AddDataTemplate("BETTERUI_GamepadTabBarTemplate", TabBar_Setup,
            ZO_GamepadMenuEntryTemplateParametricListFunction, BETTERUI.CIM.MenuEntryTemplateEquality)
    end

    tabBarControl.scrollList = control.tabBar

    local tabBar = control.tabBar
    if not tabBar then return end

    local carouselConfig = data.carouselConfig
    if carouselConfig then
        if carouselConfig.startOffset then
            tabBar.carouselStartOffset = carouselConfig.startOffset
        end
        if carouselConfig.verticalOffset then
            tabBar.carouselVerticalOffset = carouselConfig.verticalOffset
        end
        if carouselConfig.itemSpacing then
            tabBar.carouselItemSpacing = carouselConfig.itemSpacing
        end
        if carouselConfig.enabled ~= nil then
            tabBar.carouselMode = carouselConfig.enabled
        end
    end

    if data.callback then
        tabBar:SetOnSelectedDataChangedCallback(data.callback)
    end

    tabBar:Commit(blockTabBarCallbacks)

    local hasDirectCallbacks = data.tabBarData and (data.tabBarData.onNext or data.tabBarData.onPrev)
    local onChange = nil
    if not hasDirectCallbacks then
        onChange = data and data.onSelectedChanged or TabBar_OnDataChanged
    end

    if onChange then
        if blockTabBarCallbacks then
            tabBar:RemoveOnSelectedDataChangedCallback(onChange)
        else
            tabBar:SetOnSelectedDataChangedCallback(onChange)
        end
    else
        tabBar:RemoveOnSelectedDataChangedCallback(nil)
    end

    if data.activatedCallback then
        tabBar:SetOnActivatedChangedFunction(data.activatedCallback)
    end

    tabBar:Commit()

    if blockTabBarCallbacks and onChange then
        tabBar:SetOnSelectedDataChangedCallback(onChange)
    end
end
