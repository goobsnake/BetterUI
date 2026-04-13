--[[
File: Modules/Companions/Core/CompanionsClass.lua
Purpose: Base class and shared constants for the Companions module.
         Companion list/category behaviors are implemented in
         Core/CompanionListManager.lua.

ESO Reference: ZO_CompanionEquipment_Gamepad in
  esoui/ingame/companion/gamepad/companionequipment_gamepad.lua
]]

if not BETTERUI.Companions then BETTERUI.Companions = {} end

-- SCENE CONSTANTS
BETTERUI_COMPANION_EQUIP_SCENE_NAME = "BETTERUI_CompanionEquipment"

BETTERUI.Companions.COMPANION_INTERACTION = {
    type = "Companion",
    interactTypes = { INTERACTION_COMPANION_MENU },
}

-- MODULE-SCOPE TASK MANAGER
assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask,
    "BetterUI: CIM.DeferredTask must load before Companions/Core/CompanionsClass")
BETTERUI.Companions.Tasks = BETTERUI.CIM.DeferredTask.Manager:New()

---@class BETTERUI.Companions.Class : BETTERUI.CIM.GenericWindow
BETTERUI.Companions.Class = BETTERUI.CIM.GenericWindow:Subclass()

function BETTERUI.Companions.Class:New(...)
    local obj = BETTERUI.CIM.GenericWindow.New(self, ...)
    return obj
end

---@return boolean showing True if the companion scene is currently showing
function BETTERUI.Companions.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_COMPANION_EQUIP_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

-- FOOTER

--- Initializes the companion footer — hides banking controls, shows companion info.
function BETTERUI.Companions.Class:InitCompanionFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- Hide the centre vertical divider
    local dividerCentre = footerRoot:GetNamedChild("DividerCentre")
    if dividerCentre then dividerCentre:SetHidden(true) end

    -- LEFT SIDE: Companion name
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", nil)
            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_TITLE") or "SI_BETTERUI_COMPANIONS_TITLE"))
            end
        end
        local icon = withdraw:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/companion/gamepad/gp_companion_menu_icon.dds")
        end
    end

    -- RIGHT SIDE: Bag capacity
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            btn:SetHandler("OnClicked", nil)
            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_FOOTER_BAG_CAPACITY") or "SI_BETTERUI_FOOTER_BAG_CAPACITY"))
                label:SetColor(1, 1, 1, 1)
            end
        end
        local icon = deposit:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
        end
    end

    self:RefreshCompanionFooter()
end

-- SEARCH FOCUS HELPERS

function BETTERUI.Companions.Class:EnterSearchFocus()
    if not self.textSearchHeaderControl or self.textSearchHeaderControl:IsHidden() then return end
    if self.textSearchHeaderFocus then
        self.textSearchHeaderFocus:Activate()
        if self.SetTextSearchFocused then
            self:SetTextSearchFocused(true)
        end
    end
    if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP and self.coreKeybinds then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
    end
    self._searchModeActive = true
end

function BETTERUI.Companions.Class:ExitSearchFocus()
    if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
    end
    if self.coreKeybinds and KEYBIND_STRIP then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
    end
    if self.textSearchHeaderFocus then
        self.textSearchHeaderFocus:Deactivate()
    end
    if self.SetTextSearchFocused then
        self:SetTextSearchFocused(false)
    end
    self._searchModeActive = false
    self:EnsureListInputActive()
end

function BETTERUI.Companions.Class:ClearTextSearch()
    if self.ClearSearchText then
        self:ClearSearchText()
    end
end

--- Refreshes companion footer values (companion name, bag capacity).
function BETTERUI.Companions.Class:RefreshCompanionFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- LEFT SIDE: Active companion name
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                local companionName = ""
                if HasActiveCompanion and HasActiveCompanion() then
                    local defId = GetActiveCompanionDefId and GetActiveCompanionDefId()
                    if defId and GetCompanionName then
                        companionName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetCompanionName(defId))
                    end
                end
                spaceLabel:SetText(companionName ~= "" and companionName or "-")
            end
        end
    end

    -- RIGHT SIDE: Bag capacity
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                spaceLabel:SetText(
                    "|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t " ..
                    zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                        GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)))
            end
        end
    end
end
