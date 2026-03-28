--[[
File: Modules/CIM/GenericHeader.lua
Purpose: Manages the custom Gamepad Header logic for BetterUI.
         Provides a standardized header with a parametric tab bar (carousel),
         dynamic title, and equipment slot tracking.
         Replaces stock ZO_GamepadGenericHeader functionality.
]]


-- Control alias constants for readability and performance
local TABBAR         = ZO_GAMEPAD_HEADER_CONTROLS.TABBAR
local TITLE          = ZO_GAMEPAD_HEADER_CONTROLS.TITLE
local TITLE_BASELINE = ZO_GAMEPAD_HEADER_CONTROLS.TITLE_BASELINE
local DIVIDER_SIMPLE = ZO_GAMEPAD_HEADER_CONTROLS.DIVIDER_SIMPLE
local DIVIDER_PIPPED = ZO_GAMEPAD_HEADER_CONTROLS.DIVIDER_PIPPED

-- Height of the info label area (historical reference, unused)

--[[
Function: TabBar_Setup
Configures the visual state of a tab icon (hidden label, tinted icon).
param: control (table) - The list entry control.
param: data (table) - The data associated with this entry.
param: selected (boolean) - Is this entry currently selected?
param: selectedDuringRebuild (boolean) - (unused)
param: enabled (boolean) - (unused)
param: activated (boolean) - (unused)
References: Used as the setup callback for BETTERUI_TabBarScrollList.
]]
local function TabBar_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    local countBadge = control:GetNamedChild("CountBadge")
    local icon = control:GetNamedChild("Icon")

    -- Resolve text if function (used for accessibility)
    local iconPath = data.iconsNormal[1]
    icon:SetTexture(iconPath)

    -- Tint icons: Gold/Yellow for normal categories, White for filter types (sub-filters)
    local colors = BETTERUI.CIM.CONST.COLORS
    local color = data.filterType and colors.TAB_ICON_FILTER or colors.TAB_ICON_GOLD
    icon:SetColor(color[1], color[2], color[3], icon:GetControlAlpha())

    if data.canSelect == nil then
        data.canSelect = true
    end

    -- BetterUI Fix: Explicitly enable mouse and attach click handler
    -- XML template handlers may not be inherited by pooled controls
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseUp", function(self)
        BETTERUI_TabBar_OnCategoryIconClicked(self)
    end)

    -- Call base setup function (this may set label text to category name)
    ZO_GamepadMenuHeaderTemplate_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)

    -- Display item count badge for selected tab only
    -- Count is populated by module's RefreshList via data.itemCount
    -- NOTE: Must be AFTER base setup since that overwrites the label control
    if not countBadge then return end
    if not (selected and data.itemCount and data.itemCount > 0) then
        countBadge:SetHidden(true)
        return
    end

    countBadge:SetText("[" .. tostring(data.itemCount) .. "]")
    countBadge:SetHidden(false)
    countBadge:SetColor(1, 1, 1, 0.9) -- White text for count with slight transparency

    if data.countBadgeOffsetY then
        countBadge:ClearAnchors()
        countBadge:SetAnchor(BOTTOM, icon, TOP, 0, data.countBadgeOffsetY)
    end
end

--[[
Function: BETTERUI.GenericHeader.Initialize
Initializes the header control and caches child references.
param: control (table) - The header control.
param: createTabBar (number) - Flag to indicate if tab bar should be shown/created.
param: layout (any) - Layout info (unused explicitly here).
References: Called by Inventory and Banking initialization.
]]
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

--[[
Function: TabBar_OnDataChanged
Callback handler for when a tab is selected.
param: list (table) - The scroll list control.
param: selectedData (table) - The new selected data item.
param: oldSelectedData (table) - The previous selected data item.
param: reselectingDuringRebuild (boolean) - True during list rebuilds.
-- NOTE: categoryList can now be injected via selectedData.categoryList for Banking/Vendor reuse.
--       Fallback to GAMEPAD_INVENTORY for backwards compatibility.
]]
local function TabBar_OnDataChanged(list, selectedData, oldSelectedData, reselectingDuringRebuild)
    if selectedData then
        -- Injected categoryList allows reuse in Banking/Vendor screens
        local categoryList = (selectedData and selectedData.categoryList) or GAMEPAD_INVENTORY.categoryList
        for i = 1, categoryList:GetNumEntries() do
            if categoryList:GetEntryData(i) == selectedData then
                categoryList:SetSelectedIndex(i)
                break
            end
        end
    end
end

--- @param control table The header control
--- @param data table The entry data
function BETTERUI.GenericHeader.AddToList(control, data)
    control.tabBar:AddEntry("BETTERUI_GamepadTabBarTemplate", data)
end

--[[
Function: UpdateEquipText
Updates equipment slot text styling for main or backup bar.
param: control (table) - Header control
param: controlName (string) - Name of the child label control
param: slotStringKey (number) - String identifier for the slot name
param: isActive (boolean) - Whether this slot's bar is active
param: hideIfLocked (boolean) - Whether to hide if weapon swap is locked
]]
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

--[[
Function: BETTERUI.GenericHeader.SetEquipText
Set the primary equip text in the header (Main Hand).
param: control (table) - Header control.
param: isEquipMain (boolean) - True if Main Hand is the active weapon bar.
]]
function BETTERUI.GenericHeader.SetEquipText(control, isEquipMain)
    UpdateEquipText(control, "EquipText", SI_BETTERUI_INV_EQUIPSLOT_MAIN, isEquipMain, false)
end

--[[
Function: BETTERUI.GenericHeader.SetBackupEquipText
Set the backup equip text in the header (Back Up).
param: control (table) - Header control.
param: isEquipMain (boolean) - True if Main Hand is active (Backup is inactive).
]]
function BETTERUI.GenericHeader.SetBackupEquipText(control, isEquipMain)
    UpdateEquipText(control, "BackupEquipText", SI_BETTERUI_INV_EQUIPSLOT_BACKUP, not isEquipMain, true)
end

--- Update the header title text.
--- @param control table The header control.
--- @param titleText string The new title text.
function BETTERUI.GenericHeader.SetTitleText(control, titleText)
    local titleTextControl = control:GetNamedChild("TitleContainer"):GetNamedChild("Title")
    titleTextControl:SetText(titleText)
end

--[[
Function: UpdateEquippedIcons
Updates equipment icons for main or backup bar.
param: control (table) - Header control
param: iconNames (table) - Table mapping 'main', 'off', 'poison' to child control names
param: iconsData (table) - Table with 'main', 'off', 'poison' texture paths
param: hideIfLocked (boolean) - Whether to hide if weapon swap is locked
]]
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

--[[
Function: BETTERUI.GenericHeader.SetEquippedIcons
Populate current equipped icons for the main bar.
param: control (table) - The header control.
param: equipMain (string) - Texture path for main hand icon.
param: equipOff (string) - Texture path for off hand icon.
param: equipPoison (string) - Texture path for poison icon.
]]
function BETTERUI.GenericHeader.SetEquippedIcons(control, equipMain, equipOff, equipPoison)
    UpdateEquippedIcons(control,
        { main = "MainHandIcon", off = "OffHandIcon", poison = "PoisonIcon" },
        { main = equipMain, off = equipOff, poison = equipPoison },
        false)
end

--[[
Function: BETTERUI.GenericHeader.SetBackupEquippedIcons
Populate current equipped icons for the backup bar.
param: control (table) - The header control.
param: equipMain (string) - Texture path for main hand icon.
param: equipOff (string) - Texture path for off hand icon.
param: equipPoison (string) - Texture path for poison icon.
]]
function BETTERUI.GenericHeader.SetBackupEquippedIcons(control, equipMain, equipOff, equipPoison)
    UpdateEquippedIcons(control,
        { main = "BackupMainHandIcon", off = "BackupOffHandIcon", poison = "BackupPoisonIcon" },
        { main = equipMain, off = equipOff, poison = equipPoison },
        true)
end

--- Refresh the header with provided data.
---
--- Purpose: Rebuilds the TabBar if necessary and applies carousel settings.
--- Mechanics: Updates title, initializes BETTERUI_TabBarScrollList if needed, and applies dynamic callbacks.
--- References: Called whenever header data changes (e.g. switching between Inventory and CraftBag).
---
--- @param control table Header control.
--- @param data table Header data (title, carousel config, callbacks).
--- @param blockTabBarCallbacks? boolean If true, supresses OnSelectedChanged during initialization.
function BETTERUI.GenericHeader.Refresh(control, data, blockTabBarCallbacks)
    control:GetNamedChild("TitleContainer"):GetNamedChild("Title"):SetText(data.titleText(data.name))

    local tabBarControl = control.controls[TABBAR]
    tabBarControl:SetHidden(false)

    -- Initialize Tab Bar Scroll List if missing
    if not control.tabBar then
        local tabBarData = {
            attachedTo = control,
            parent = data.tabBarData.parent,
            onNext = data.tabBarData.onNext,
            onPrev =
                data.tabBarData.onPrev
        }
        -- Create the Parametric Scroll List for the Tab Bar
        control.tabBar = BETTERUI_TabBarScrollList:New(tabBarControl, tabBarControl:GetNamedChild("LeftIcon"),
            tabBarControl:GetNamedChild("RightIcon"), tabBarData)
        -- NOTE: Do NOT activate here - tabBar should only be activated when scene shows.
        -- Activation during module setup causes DIRECTIONAL_INPUT registration before
        -- scene is visible, leading to joystick lock-up on startup.
        -- The tabBar will be activated by scene handlers (OnSceneShowing/ActivateHeader).
        control.tabBar.hideUnselectedControls = false

        -- Use the namespaced equality function from GenericListManager
        control.tabBar:AddDataTemplate("BETTERUI_GamepadTabBarTemplate", TabBar_Setup,
            ZO_GamepadMenuEntryTemplateParametricListFunction, BETTERUI.CIM.MenuEntryTemplateEquality)
    end

    -- Always ensure scrollList alias is set on the UI control so XML OnClicked handlers work
    -- This must be outside the creation block in case the control was recreated or refreshed
    tabBarControl.scrollList = control.tabBar

    local tabBar = control.tabBar
    if not tabBar then return end

    -- Apply carousel configuration (offsets, spacing) from BetterUI.CONST.lua (via data)
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

    -- BetterUI Fix: Ensure callback from data is applied to the tab bar
    -- This allows context switching (Inventory <-> Craft Bag) to update the listener
    if data.callback then
        tabBar:SetOnSelectedDataChangedCallback(data.callback)
    end

    -- If tab bar exists, commit the list to show items
    tabBar:Commit(blockTabBarCallbacks)

    -- Only use onSelectedDataChangedCallback when NOT using onNext/onPrev pattern.
    -- The onNext/onPrev callbacks are invoked directly from MoveNext/MovePrevious
    -- and should not be combined with onSelectedDataChangedCallback to avoid double-firing.
    -- Why: Some menus drive navigation via direct list changes (onSelectedChanged), others via explicit Next/Prev buttons.
    -- We must correctly detect which mode we are in.
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
        -- Clear any previously set callback
        tabBar:RemoveOnSelectedDataChangedCallback(nil)
    end

    if data.activatedCallback then
        tabBar:SetOnActivatedChangedFunction(data.activatedCallback)
    end

    tabBar:Commit()

    -- Restore callback after commit if it was blocked
    if blockTabBarCallbacks and onChange then
        tabBar:SetOnSelectedDataChangedCallback(onChange)
    end
end
