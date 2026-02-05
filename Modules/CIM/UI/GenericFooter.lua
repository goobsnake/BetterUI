--[[
File: Modules/CIM/UI/GenericFooter.lua
Purpose: Manages the Gamepad Bottom Bar (Footer) logic.
         Displays bag/bank capacity and various currencies (Gold, AP, Tel Var, etc.).
Author: BetterUI Team
Last Modified: 2026-01-28
]]


-- ============================================================================
-- LOCAL ALIASES
-- Reference CurrencyManager functions for cleaner code
-- ============================================================================

local Currency = nil -- Will be set after load order verification

local function EnsureCurrencyManager()
    if not Currency then
        Currency = BETTERUI.CIM.Currency
    end
    return Currency
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--[[
Function: GetLabelControl
Description: Retrieves a label control from the footer by name.
             Delegates to CurrencyManager's implementation for consistency.
]]
local function GetLabelControl(footer, labelName)
    return EnsureCurrencyManager().GetLabelControl(footer, labelName)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--[[
Function: BETTERUI.GenericFooter:Initialize
Description: Initializes the footer control reference.
Rationale: Links the Lua object to the XML control structure defined in GenericFooter.xml.
Mechanism: Finds the 'FooterContainer' child within the main control and caches the reference.
           Triggers an initial refresh if the control is ready.
param: control (table) - The parent control containing the footer.
return: nil
]]
function BETTERUI.GenericFooter:Initialize()
    if (self.footer == nil) then self.footer = self.control.container:GetNamedChild("FooterContainer").footer end

    if (self.footer.GoldLabel ~= nil) then BETTERUI.GenericFooter.Refresh(self) end
end

--[[
Function: BETTERUI.GenericFooter:Refresh
Description: Refreshes the footer content and layout.
Rationale: Updates displayed values (Capacity, Currencies) to reflect current player state.
Mechanism:
  1. Updates Capacity Labels (Backpack and Bank).
  2. Delegates currency updates to CurrencyManager.
  3. Dynamically positions currency labels based on user-defined order.
References: Called on inventory updates (EVENT_INVENTORY_SINGLE_SLOT_UPDATE) and initialization.
]]
function BETTERUI.GenericFooter:Refresh()
    if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return end
    local invSettings = BETTERUI.Settings.Modules["Inventory"]
    local footer = self.footer
    if not footer._stringCache then footer._stringCache = {} end

    local stringsChanged = false
    local CurrencyMgr = EnsureCurrencyManager()

    -- Update capacity labels (works for both direct property and named child access)
    local cwLabel = GetLabelControl(footer, "CWLabel")
    local bankLabel = GetLabelControl(footer, "BankLabel")

    if cwLabel then
        local bagText = zo_strformat("<<1>> (<<2>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t",
            GetString(SI_BETTERUI_FOOTER_BAG_CAPACITY),
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)))

        if footer._stringCache.bag ~= bagText then
            cwLabel:SetText(bagText)
            footer._stringCache.bag = bagText
            stringsChanged = true
        end
    end

    if bankLabel then
        local bankText = zo_strformat("<<1>> (<<2>>)|t32:32:/esoui/art/inventory/inventory_all_tabicon_inactive.dds|t",
            GetString(SI_BETTERUI_FOOTER_BANK_CAPACITY),
            zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK),
                GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK)))

        if footer._stringCache.bank ~= bankText then
            bankLabel:SetText(bankText)
            footer._stringCache.bank = bankText
            stringsChanged = true
        end
    end

    -- Delegate currency updates to CurrencyManager
    local currenciesChanged = CurrencyMgr.UpdateLabels(footer, invSettings)

    -- Position labels only if something changed
    -- Note: Initial sizing/positioning might need to run at least once,
    -- but Initialize calls Refresh which will trigger updates as internal caches start empty.
    if stringsChanged or currenciesChanged then
        CurrencyMgr.PositionLabels(footer, invSettings)
    end
end
