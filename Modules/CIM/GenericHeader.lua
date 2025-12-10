-- BetterUI Generic Header
-- Modified header class for inventory with tab bar navigation
-- Supports category switching via BETTERUI_TabBarScrollList

local _

-- Control alias constants for readability
local TABBAR            = ZO_GAMEPAD_HEADER_CONTROLS.TABBAR
local TITLE             = ZO_GAMEPAD_HEADER_CONTROLS.TITLE
local TITLE_BASELINE    = ZO_GAMEPAD_HEADER_CONTROLS.TITLE_BASELINE
local DIVIDER_SIMPLE    = ZO_GAMEPAD_HEADER_CONTROLS.DIVIDER_SIMPLE
local DIVIDER_PIPPED    = ZO_GAMEPAD_HEADER_CONTROLS.DIVIDER_PIPPED

local GENERIC_HEADER_INFO_LABEL_HEIGHT = 33


--- Setup function for tab bar entries: hides label, shows icon, tints when needed
local function TabBar_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    local label = control:GetNamedChild("Label")
    label:SetHidden(true)
    local icon = control:GetNamedChild("Icon")
    local text = data.text
    if type(text) == "function" then
        text = text()
    end
    local iconPath = data.iconsNormal[1]
    icon:SetTexture(iconPath)

	if not data.filterType then
		icon:SetColor(1, 0.95, 0.5, icon:GetControlAlpha())
	else
		icon:SetColor(1, 1, 1, icon:GetControlAlpha())
	end

    if data.canSelect == nil then
        data.canSelect = true
    end
    ZO_GamepadMenuHeaderTemplate_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)

end

--- Initialize the header control and (optionally) create the tab bar
function BETTERUI.GenericHeader.Initialize(control, createTabBar, layout)
    control.controls =
        {
            [TABBAR]            = control:GetNamedChild("TabBar"),
            [TITLE]             = control:GetNamedChild("TitleContainer"):GetNamedChild("Title"),
            [TITLE_BASELINE]    = control:GetNamedChild("TitleContainer"),
            [DIVIDER_SIMPLE]    = control:GetNamedChild("DividerSimple"),
            [DIVIDER_PIPPED]    = control:GetNamedChild("DividerPipped"),
        }

        if createTabBar == ZO_GAMEPAD_HEADER_TABBAR_CREATE then
            local tabBarControl = control.controls[TABBAR]

            tabBarControl:SetHidden(false)

        end

end

local TEXT_ALIGN_RIGHT = 2

local function TabBar_OnDataChanged(list, selectedData, oldSelectedData, reselectingDuringRebuild)
    if selectedData then
        local categoryList = GAMEPAD_INVENTORY.categoryList
        for i = 1, categoryList:GetNumEntries() do
            if categoryList:GetEntryData(i) == selectedData then
                categoryList:SetSelectedIndex(i)
                break
            end
        end
    end
end

--- Add an entry to the tab bar list using the BetterUI tab template
function BETTERUI.GenericHeader.AddToList(control, data)
    control.tabBar:AddEntry("BETTERUI_GamepadTabBarTemplate", data)
end

--- Set the primary equip text in the header (main vs backup)
function BETTERUI.GenericHeader.SetEquipText(control, isEquipMain)
    local equipControl = control:GetNamedChild("TitleContainer"):GetNamedChild("EquipText")
    if isEquipMain then
        equipControl:SetText(zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_TEXT_HIGHLIGHT), GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN)))
    else
        equipControl:SetText(zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_TEXT_NORMAL), GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN)))
    end
    equipControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
end

--- Set the backup equip text in the header (main vs backup)
function BETTERUI.GenericHeader.SetBackupEquipText(control, isEquipMain)
    local equipControl = control:GetNamedChild("TitleContainer"):GetNamedChild("BackupEquipText")
    if isEquipMain then
        equipControl:SetText(zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_TEXT_NORMAL), GetString(SI_BETTERUI_INV_EQUIPSLOT_BACKUP)))
    else
        equipControl:SetText(zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_TEXT_HIGHLIGHT), GetString(SI_BETTERUI_INV_EQUIPSLOT_BACKUP)))
    end

    equipControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
end

--- Update the header title text
function BETTERUI.GenericHeader.SetTitleText(control, titleText)
    local titleTextControl = control:GetNamedChild("TitleContainer"):GetNamedChild("Title")
    titleTextControl:SetText(titleText)
end


--- Populate current equipped icons for the main bar (with defaults when empty)
function BETTERUI.GenericHeader.SetEquippedIcons(control, equipMain, equipOff, equipPoison)
	local equipMainControl = control:GetNamedChild("TitleContainer"):GetNamedChild("MainHandIcon")
	local equipOffControl = control:GetNamedChild("TitleContainer"):GetNamedChild("OffHandIcon")
	local equipPoisonControl = control:GetNamedChild("TitleContainer"):GetNamedChild("PoisonIcon")
	
	local DEFAULT_INVSLOT_ICON = "/esoui/art/inventory/inventory_slot.dds"

	if(equipMain ~= "") then equipMainControl:SetTexture(equipMain) else equipMainControl:SetTexture(DEFAULT_INVSLOT_ICON) end
	if(equipOff ~= "") then equipOffControl:SetTexture(equipOff) else equipOffControl:SetTexture(DEFAULT_INVSLOT_ICON)  end
	if(equipPoison ~= "") then equipPoisonControl:SetTexture(equipPoison) else equipPoisonControl:SetTexture(DEFAULT_INVSLOT_ICON)  end
end

--- Populate current equipped icons for the backup bar (with defaults when empty)
function BETTERUI.GenericHeader.SetBackupEquippedIcons(control, equipMain, equipOff, equipPoison)
    local equipMainControl = control:GetNamedChild("TitleContainer"):GetNamedChild("BackupMainHandIcon")
    local equipOffControl = control:GetNamedChild("TitleContainer"):GetNamedChild("BackupOffHandIcon")
    local equipPoisonControl = control:GetNamedChild("TitleContainer"):GetNamedChild("BackupPoisonIcon")
    
    local DEFAULT_INVSLOT_ICON = "/esoui/art/inventory/inventory_slot.dds"

    if(equipMain ~= "") then equipMainControl:SetTexture(equipMain) else equipMainControl:SetTexture(DEFAULT_INVSLOT_ICON) end
    if(equipOff ~= "") then equipOffControl:SetTexture(equipOff) else equipOffControl:SetTexture(DEFAULT_INVSLOT_ICON)  end
    if(equipPoison ~= "") then equipPoisonControl:SetTexture(equipPoison) else equipPoisonControl:SetTexture(DEFAULT_INVSLOT_ICON)  end
end

--- Refresh the header with provided data; optionally block tab bar callbacks during rebuild
function BETTERUI.GenericHeader.Refresh(control, data, blockTabBarCallbacks)
	control:GetNamedChild("TitleContainer"):GetNamedChild("Title"):SetText(data.titleText(data.name))

    local tabBarControl = control.controls[TABBAR]
    tabBarControl:SetHidden(false)

    if not control.tabBar then
        local tabBarData = { attachedTo=control, parent=data.tabBarData.parent, onNext=data.tabBarData.onNext, onPrev = data.tabBarData.onPrev }
        control.tabBar = BETTERUI_TabBarScrollList:New(tabBarControl, tabBarControl:GetNamedChild("LeftIcon"), tabBarControl:GetNamedChild("RightIcon"), tabBarData)
        control.tabBar:Activate()
        control.tabBar.hideUnselectedControls = false

        control.tabBar:AddDataTemplate("BETTERUI_GamepadTabBarTemplate", TabBar_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality)
    end
    
    -- Always ensure scrollList alias is set on the UI control so XML OnClicked handlers work
    -- This must be outside the creation block in case the control was recreated or refreshed
    tabBarControl.scrollList = control.tabBar

    -- Apply carousel configuration if provided in data
    if control.tabBar and data.carouselConfig then
        if data.carouselConfig.startOffset then
            control.tabBar.carouselStartOffset = data.carouselConfig.startOffset
        end
        if data.carouselConfig.verticalOffset then
            control.tabBar.carouselVerticalOffset = data.carouselConfig.verticalOffset
        end
        if data.carouselConfig.itemSpacing then
            control.tabBar.carouselItemSpacing = data.carouselConfig.itemSpacing
        end
        if data.carouselConfig.enabled ~= nil then
            control.tabBar.carouselMode = data.carouselConfig.enabled
        end
    end

    if control.tabBar then
        -- Only use onSelectedDataChangedCallback when NOT using onNext/onPrev pattern
        -- The onNext/onPrev callbacks are invoked directly from MoveNext/MovePrevious
        -- and should not be combined with onSelectedDataChangedCallback to avoid double-firing
        local hasDirectCallbacks = data.tabBarData and (data.tabBarData.onNext or data.tabBarData.onPrev)
        local onChange = nil
        if not hasDirectCallbacks then
            onChange = data and data.onSelectedChanged or TabBar_OnDataChanged
        end
        if onChange then
            if(blockTabBarCallbacks) then
                control.tabBar:RemoveOnSelectedDataChangedCallback(onChange)
            else
                control.tabBar:SetOnSelectedDataChangedCallback(onChange)
            end
        else
            -- Clear any previously set callback when using onNext/onPrev pattern
            control.tabBar:RemoveOnSelectedDataChangedCallback(nil)
        end
        if data.activatedCallback then
            control.tabBar:SetOnActivatedChangedFunction(data.activatedCallback)
        end

        control.tabBar:Commit()
        if(blockTabBarCallbacks) then
            control.tabBar:SetOnSelectedDataChangedCallback(onChange)
        end
    end
end
