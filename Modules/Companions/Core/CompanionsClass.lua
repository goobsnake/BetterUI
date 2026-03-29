--[[
File: Modules/Companions/Core/CompanionsClass.lua
Purpose: Core class for the Companions equipment management module.
         Extends CIM.GenericWindow with companion equipment list building,
         equip/unequip actions, and companion-specific footer.

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

-- LIST BUILDING

--- Refreshes the equipment list showing companion-worn items and equippable backpack items.
function BETTERUI.Companions.Class:RefreshList()
    if not self.list then return end
    self.list:Clear()

    -- Section 1: Currently equipped companion items
    self:BuildEquippedItems()

    -- Section 2: Equippable companion items from backpack
    self:BuildBackpackItems()

    self.list:Commit()
end

--- Adds currently equipped companion items (BAG_COMPANION_WORN) to the list.
function BETTERUI.Companions.Class:BuildEquippedItems()
    local list = self.list
    if not list then return end

    -- Safely check if companion is active
    if not HasActiveCompanion or not HasActiveCompanion() then return end

    -- Use BAG_COMPANION_WORN size to enumerate slots
    local bagSize = GetBagSize(BAG_COMPANION_WORN)
    if not bagSize or bagSize == 0 then return end

    for slotIndex = 0, bagSize - 1 do
        local slotHasItem, icon, stackCount, sellPrice, isLocked, equipType,
            _, functionalQuality, displayQuality = GetItemInfo(BAG_COMPANION_WORN, slotIndex)

        if slotHasItem then
            local name = GetItemName(BAG_COMPANION_WORN, slotIndex) or ""
            if name ~= "" then
                name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                local quality = displayQuality or functionalQuality or ITEM_DISPLAY_QUALITY_NORMAL
                local itemLink = GetItemLink(BAG_COMPANION_WORN, slotIndex)
                local itemType = itemLink and GetItemLinkItemType(itemLink) or 0

                local entryData = {
                    name = name,
                    icon = icon,
                    stackCount = stackCount or 1,
                    sellPrice = sellPrice or 0,
                    stackSellPrice = (sellPrice or 0) * (stackCount or 1),
                    quality = quality,
                    bagId = BAG_COMPANION_WORN,
                    slotIndex = slotIndex,
                    isEquipped = true,
                    isCompanionItem = true,
                    bestGamepadItemCategoryName = GetBestItemCategoryDescription
                        and GetBestItemCategoryDescription({bagId = BAG_COMPANION_WORN, slotIndex = slotIndex})
                        or "",
                    bestItemTypeName = GetString("SI_ITEMTYPE", itemType),
                    cached_itemLink = itemLink,
                    cached_itemType = itemType,
                    statValue = "",
                }

                -- Get stat value for equipment (armor rating or weapon damage)
                if GetItemStatValue then
                    local sv = GetItemStatValue(BAG_COMPANION_WORN, slotIndex)
                    if sv and sv > 0 then
                        entryData.statValue = sv
                    end
                end

                local entry = ZO_GamepadEntryData:New("|cFFD700[E]|r " .. entryData.name, entryData.icon)
                entry:SetDataSource(entryData)
                entry.narrationText = function() return entryData.name end

                if quality then
                    local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                    entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                end

                list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
            end
        end
    end
end

--- Adds equippable companion items from BAG_BACKPACK to the list.
function BETTERUI.Companions.Class:BuildBackpackItems()
    local list = self.list
    if not list then return end

    local bagSize = GetBagSize(BAG_BACKPACK) or 0

    for slotIndex = 0, bagSize - 1 do
        local slotHasItem, icon, stackCount, sellPrice = GetItemInfo(BAG_BACKPACK, slotIndex)

        if slotHasItem then
            -- Check if this item is companion-usable
            local actorCategory = GetItemActorCategory
                and GetItemActorCategory(BAG_BACKPACK, slotIndex)
            if actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
                local name = GetItemName(BAG_BACKPACK, slotIndex) or ""
                if name ~= "" then
                    name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                    local quality = GetItemDisplayQuality(BAG_BACKPACK, slotIndex)
                        or ITEM_DISPLAY_QUALITY_NORMAL
                    local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
                    local itemType = itemLink and GetItemLinkItemType(itemLink) or 0

                    local entryData = {
                        name = name,
                        icon = icon,
                        stackCount = stackCount or 1,
                        sellPrice = sellPrice or 0,
                        stackSellPrice = (sellPrice or 0) * (stackCount or 1),
                        quality = quality,
                        bagId = BAG_BACKPACK,
                        slotIndex = slotIndex,
                        isEquipped = false,
                        isCompanionItem = true,
                        bestGamepadItemCategoryName = GetBestItemCategoryDescription
                            and GetBestItemCategoryDescription({bagId = BAG_BACKPACK, slotIndex = slotIndex})
                            or "",
                        bestItemTypeName = GetString("SI_ITEMTYPE", itemType),
                        cached_itemLink = itemLink,
                        cached_itemType = itemType,
                        statValue = "",
                    }

                    -- Get stat value for equipment (armor rating or weapon damage)
                    if GetItemStatValue then
                        local sv = GetItemStatValue(BAG_BACKPACK, slotIndex)
                        if sv and sv > 0 then
                            entryData.statValue = sv
                        end
                    end

                    local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
                    entry:SetDataSource(entryData)
                    entry.narrationText = function() return entryData.name end

                    if quality then
                        local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                        entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                    end

                    list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
                end
            end
        end
    end
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
                        companionName = zo_strformat(SI_TOOLTIP_ITEM_NAME,
                            GetCompanionName(defId))
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
