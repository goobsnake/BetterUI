--[[
File: Modules/CIM/GenericHeader.lua
Purpose: Manages the custom Gamepad Header logic for BetterUI.
         Provides a standardized header with a parametric tab bar (carousel),
         dynamic title, and equipment slot tracking.
         Replaces stock ZO_GamepadGenericHeader functionality.
Author: BetterUI Team
Last Modified: 2026-01-16
]]

local _

-- Control alias constants for readability and performance
local TABBAR            = ZO_GAMEPAD_HEADER_CONTROLS.TABBAR
local TITLE             = ZO_GAMEPAD_HEADER_CONTROLS.TITLE
local TITLE_BASELINE    = ZO_GAMEPAD_HEADER_CONTROLS.TITLE_BASELINE
local DIVIDER_SIMPLE    = ZO_GAMEPAD_HEADER_CONTROLS.DIVIDER_SIMPLE
local DIVIDER_PIPPED    = ZO_GAMEPAD_HEADER_CONTROLS.DIVIDER_PIPPED

-- Height of the info label area (legacy constant?)
-- TODO: [Sanitation] Verify if this legacy constant is actually used or dead code.
local GENERIC_HEADER_INFO_LABEL_HEIGHT = 33

--[[
Function: TabBar_Setup
Description: Configures the visual state of a tab icon (hidden label, tinted icon).
Rationale: Ensures the tab bar matches the BetterUI aesthetic (icons only, gold tint).
Mechanism: Hides text labels, sets icon texture, and applies color tinting based on filter type.
param: control (table) - The list entry control.
param: data (table) - The data associated with this entry.
param: selected (boolean) - Is this entry currently selected?
param: selectedDuringRebuild (boolean) - (unused)
param: enabled (boolean) - (unused)
param: activated (boolean) - (unused)
References: Used as the setup callback for BETTERUI_TabBarScrollList.
]]
local function TabBar_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    local label = control:GetNamedChild("Label")
    -- Why: In this specific header design, we only want to show the large icon.
    -- The text label is redundant or doesn't fit the visual style of the carousel.
    label:SetHidden(true) -- Icons only for this tab bar style
    local icon = control:GetNamedChild("Icon")
    
    -- Resolve text if function (though ignored by SetHidden(true) above, might be used for accessiblity later)
    local text = data.text
    if type(text) == "function" then
        text = text()
    end
    
    local iconPath = data.iconsNormal[1]
    icon:SetTexture(iconPath)

    -- Tint icons: Gold/Yellow for normal categories, White for filter types (sub-filters)
    -- TODO: [Magic Values] Extract these color literals (1, 0.95, 0.5) to BETTERUI.CONST.COLORS.
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

--[[
Function: BETTERUI.GenericHeader.Initialize
Description: Initializes the header control and caches child references.
Rationale: Caching references prevents repeated GetNamedChild calls during high-frequency updates.
Mechanism: Populates control.controls table mapping constants (TABBAR, TITLE) to UI objects.
param: control (table) - The header control.
param: createTabBar (number) - Flag to indicate if tab bar should be shown/created.
param: layout (any) - Layout info (unused explicitly here).
References: Called by Inventory and Banking initialization.
]]
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

--[[
Function: TabBar_OnDataChanged
Description: Callback handler for when a tab is selected.
Rationale: Syncs the main inventory category list when the header tab selection changes.
Mechanism: Iterates through GAMEPAD_INVENTORY.categoryList to find and select the matching entry.
param: list (table) - The scroll list control.
param: selectedData (table) - The new selected data item.
param: oldSelectedData (table) - The previous selected data item.
param: reselectingDuringRebuild (boolean) - True during list rebuilds.
TODO: [Coupling] Decouple from 'GAMEPAD_INVENTORY' global to allow reuse in other screens.
]]
local function TabBar_OnDataChanged(list, selectedData, oldSelectedData, reselectingDuringRebuild)
    if selectedData then
        -- Sync with the global Gamepad Inventory category list
        -- logic should be injected or passed via data to allow reuse in Banking/Vendor screens.
        local categoryList = GAMEPAD_INVENTORY.categoryList
        for i = 1, categoryList:GetNumEntries() do
            if categoryList:GetEntryData(i) == selectedData then
                categoryList:SetSelectedIndex(i)
                break
            end
        end
    end
end

--[[
Function: BETTERUI.GenericHeader.AddToList
Description: Add an entry to the tab bar list.
Rationale: Helper to add entries using the standardized BETTERUI tab template.
param: control (table) - The header control.
param: data (table) - The entry data.
]]
function BETTERUI.GenericHeader.AddToList(control, data)
    control.tabBar:AddEntry("BETTERUI_GamepadTabBarTemplate", data)
end

--[[
Function: BETTERUI.GenericHeader.SetEquipText
Description: Set the primary equip text in the header (Main Hand).
Rationale: Updates the visual indicator for the active weapon bar (text color/highlight).
Mechanism: Sets text and alignment for the EquipText label.
param: control (table) - Header control.
param: isEquipMain (boolean) - True if Main Hand is the active weapon bar.
TODO: [DRY] Refactor with SetBackupEquipText into `UpdateEquipText(control, type, isActive)`.
]]
function BETTERUI.GenericHeader.SetEquipText(control, isEquipMain)
    local equipControl = control:GetNamedChild("TitleContainer"):GetNamedChild("EquipText")
    if isEquipMain then
        equipControl:SetText(zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_TEXT_HIGHLIGHT), GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN)))
    else
        equipControl:SetText(zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_TEXT_NORMAL), GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN)))
    end
    equipControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
end

--[[
Function: BETTERUI.GenericHeader.SetBackupEquipText
Description: Set the backup equip text in the header (Back Up).
Rationale: Updates visual indicator for backup bar. Hides entirely if weapon swap is locked.
Mechanism: Checks player level for weapon swap unlock. Sets text/color based on active bar.
param: control (table) - Header control.
param: isEquipMain (boolean) - True if Main Hand is active (Backup is inactive).
]]
function BETTERUI.GenericHeader.SetBackupEquipText(control, isEquipMain)
    local equipControl = control:GetNamedChild("TitleContainer"):GetNamedChild("BackupEquipText")
    if not equipControl then return end
    
    -- Hide backup bar UI if player hasn't unlocked weapon swap
    -- Why: Weapon swap is a core mechanic unlocked at level 15. Showing these slots earlier clutters the UI.
    if GetUnitLevel("player") < GetWeaponSwapUnlockedLevel() then
        equipControl:SetHidden(true)
        return
    end
    
    equipControl:SetHidden(false)
    if isEquipMain then
        -- If Main is active, Backup is inactive (Normal/Grey)
        equipControl:SetText(zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_TEXT_NORMAL), GetString(SI_BETTERUI_INV_EQUIPSLOT_BACKUP)))
    else
        -- If Main is NOT active, Backup is active (Highlight/Orange)
        equipControl:SetText(zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_TEXT_HIGHLIGHT), GetString(SI_BETTERUI_INV_EQUIPSLOT_BACKUP)))
    end

    equipControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
end

--- Update the header title text.
--- @param control table The header control.
--- @param titleText string The new title text.
function BETTERUI.GenericHeader.SetTitleText(control, titleText)
    local titleTextControl = control:GetNamedChild("TitleContainer"):GetNamedChild("Title")
    titleTextControl:SetText(titleText)
end


--- Populate current equipped icons for the main bar.
--- Uses default empty slot icon if texture path is empty.
--- TODO: [DRY] Near-identical to SetBackupEquippedIcons. Refactor to `UpdateEquippedIcons(control, iconsData)`.
--- @param control table The header control.
--- @param equipMain string Texture path for main hand icon.
--- @param equipOff string Texture path for off hand icon.
--- @param equipPoison string Texture path for poison icon.
function BETTERUI.GenericHeader.SetEquippedIcons(control, equipMain, equipOff, equipPoison)
	local equipMainControl = control:GetNamedChild("TitleContainer"):GetNamedChild("MainHandIcon")
	local equipOffControl = control:GetNamedChild("TitleContainer"):GetNamedChild("OffHandIcon")
	local equipPoisonControl = control:GetNamedChild("TitleContainer"):GetNamedChild("PoisonIcon")
	
    -- TODO: [Magic Values] Extract string literal to constant.
	local DEFAULT_INVSLOT_ICON = "/esoui/art/inventory/inventory_slot.dds"

	if(equipMain ~= "") then equipMainControl:SetTexture(equipMain) else equipMainControl:SetTexture(DEFAULT_INVSLOT_ICON) end
	if(equipOff ~= "") then equipOffControl:SetTexture(equipOff) else equipOffControl:SetTexture(DEFAULT_INVSLOT_ICON)  end
	if(equipPoison ~= "") then equipPoisonControl:SetTexture(equipPoison) else equipPoisonControl:SetTexture(DEFAULT_INVSLOT_ICON)  end
end

--- Populate current equipped icons for the backup bar.
--- Handles visibility based on Weapon Swap unlock status.
--- TODO: [DRY] Duplicate logic.
--- @param control table The header control.
--- @param equipMain string Texture path for main hand icon.
--- @param equipOff string Texture path for off hand icon.
--- @param equipPoison string Texture path for poison icon.
function BETTERUI.GenericHeader.SetBackupEquippedIcons(control, equipMain, equipOff, equipPoison)
    local titleContainer = control:GetNamedChild("TitleContainer")
    local equipMainControl = titleContainer:GetNamedChild("BackupMainHandIcon")
    local equipOffControl = titleContainer:GetNamedChild("BackupOffHandIcon")
    local equipPoisonControl = titleContainer:GetNamedChild("BackupPoisonIcon")
    
    -- Hide backup bar icons if player hasn't unlocked weapon swap
    if GetUnitLevel("player") < GetWeaponSwapUnlockedLevel() then
        if equipMainControl then equipMainControl:SetHidden(true) end
        if equipOffControl then equipOffControl:SetHidden(true) end
        if equipPoisonControl then equipPoisonControl:SetHidden(true) end
        return
    end
    
    -- TODO: [Magic Values] Extract string literal.
    local DEFAULT_INVSLOT_ICON = "/esoui/art/inventory/inventory_slot.dds"

    -- Ensure controls are shown and textured
    if equipMainControl then
        equipMainControl:SetHidden(false)
        if(equipMain ~= "") then equipMainControl:SetTexture(equipMain) else equipMainControl:SetTexture(DEFAULT_INVSLOT_ICON) end
    end
    if equipOffControl then
        equipOffControl:SetHidden(false)
        if(equipOff ~= "") then equipOffControl:SetTexture(equipOff) else equipOffControl:SetTexture(DEFAULT_INVSLOT_ICON) end
    end
    if equipPoisonControl then
        equipPoisonControl:SetHidden(false)
        if(equipPoison ~= "") then equipPoisonControl:SetTexture(equipPoison) else equipPoisonControl:SetTexture(DEFAULT_INVSLOT_ICON) end
    end
end

--- Refresh the header with provided data.
---
--- Purpose: Rebuilds the TabBar if necessary and applies carousel settings.
--- Mechanics: Updates title, initializes BETTERUI_TabBarScrollList if needed, and applies dynamic callbacks.
--- References: Called whenever header data changes (e.g. switching between Inventory and CraftBag).
---
--- @param control table Header control.
--- @param data table Header data (title, carousel config, callbacks).
--- @param blockTabBarCallbacks boolean If true, supresses OnSelectedChanged during initialization.
function BETTERUI.GenericHeader.Refresh(control, data, blockTabBarCallbacks)
	control:GetNamedChild("TitleContainer"):GetNamedChild("Title"):SetText(data.titleText(data.name))

    local tabBarControl = control.controls[TABBAR]
    tabBarControl:SetHidden(false)

    -- Initialize Tab Bar Scroll List if missing
    if not control.tabBar then
        local tabBarData = { attachedTo=control, parent=data.tabBarData.parent, onNext=data.tabBarData.onNext, onPrev = data.tabBarData.onPrev }
        -- Create the Parametric Scroll List for the Tab Bar
        control.tabBar = BETTERUI_TabBarScrollList:New(tabBarControl, tabBarControl:GetNamedChild("LeftIcon"), tabBarControl:GetNamedChild("RightIcon"), tabBarData)
        control.tabBar:Activate()
        control.tabBar.hideUnselectedControls = false

        control.tabBar:AddDataTemplate("BETTERUI_GamepadTabBarTemplate", TabBar_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality)
    end
    
    -- Always ensure scrollList alias is set on the UI control so XML OnClicked handlers work
    -- This must be outside the creation block in case the control was recreated or refreshed
    tabBarControl.scrollList = control.tabBar

    -- Apply carousel configuration (offsets, spacing) from BetterUI.CONST.lua (via data)
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
            if(blockTabBarCallbacks) then
                control.tabBar:RemoveOnSelectedDataChangedCallback(onChange)
            else
                control.tabBar:SetOnSelectedDataChangedCallback(onChange)
            end
        else
            -- Clear any previously set callback
            control.tabBar:RemoveOnSelectedDataChangedCallback(nil)
        end
        if data.activatedCallback then
            control.tabBar:SetOnActivatedChangedFunction(data.activatedCallback)
        end

        control.tabBar:Commit()
        
        -- Restore callback after commit if it was blocked
        if(blockTabBarCallbacks) then
            control.tabBar:SetOnSelectedDataChangedCallback(onChange)
        end
    end
end
