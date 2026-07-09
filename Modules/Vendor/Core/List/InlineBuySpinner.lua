--[[
File: Modules/Vendor/Core/List/InlineBuySpinner.lua
Purpose: Native-style INLINE quantity spinner for the vendor BUY list. Instead of
         a modal dialog, the focused stackable store row's STAT cell hosts a
         < n > dial and its VALUE cell shows the running total -- so the item's
         Name / Type / Trait stay fully readable (and this is portable to other
         list scenes, e.g. Banking withdraw/deposit).

Design (workflow wnwtparlo; pivoted 2026-07-06 from a whole-row takeover to
borrowing two existing columns):
  - ONE shared overlay control, created once via CreateControlFromVirtual from
    ZOS's ZO_GamepadLabeledQuantitySpinnerContainerTemplate. We use only its
    < n > Spinner child (anchored into the row's Stat cell) and its Price child
    (the running total, re-anchored onto the row's Value cell); the template's
    own "QUANTITY" caption + outline Highlight are hidden.
  - Parented under a genuinely SHOWN vendor control (the list control) so it draws
    -- a control parented under the hidden native store window would not render.
  - The row's own Stat + Value cells are HIDDEN while attached and restored on
    detach (pooling-safe via Mask/RestoreRowContent + an authoritative rule in
    VendorEntrySetup). Hidden controls keep their layout, so anchoring the dial /
    total to them lands them exactly in those columns at any list font size.
  - CRITICAL: we NEVER call the container's Activate(). That is the only thing
    that registers a competing DIRECTIONAL_INPUT owner; the value is driven
    externally (SetValue/Adjust) from the vendor's horizontal movement controller
    (D-pad / left-stick +/-1) and the L2/R2 min/max keybinds.
  - The inherited ZO_GamepadQuantitySpinner mixin computes the running total
    (qty * unitPrice) and renders it red when unaffordable inside its own
    OnValueChanged (SetupCurrency + ZO_CurrencyControl_SetSimpleCurrency), so the
    Price child is reused verbatim rather than re-implementing currency math.

  The Stat cell is a deliberate host: for buyable vendor stock (materials,
  consumables, furnishings, recipes) the Stat column is almost always empty, and
  the shared header for this column reads "STAT/QTY". Kept generic (Stat/Value
  named children) so other BetterUI list scenes can reuse this module unchanged.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}

---@class BETTERUI.Vendor.InlineBuySpinner
local InlineBuySpinner = {
    _control = nil,        -- the shared overlay control (ZO_GamepadQuantitySpinner mixin)
    _attached = false,     -- currently attached to a row?
    _attachedEntryIndex = nil, -- store entryIndex of the attached row (preserve qty across same-entry re-attach)
    _dialArmed = false,    -- true once the stick returned to neutral post-attach (blocks phantom held-stick dials)
    _movementController = nil, -- lazy horizontal ZO_MovementController; dropped on Detach for zeroed accumulation
    _min = 1,
    _max = 1,
    _unitPrice = 0,
    _currencyType = nil,
    _onValueChanged = nil, -- optional external hook (future scenes)
    _priceControl = nil,   -- template Price (running total), re-anchored onto the row's Value cell
    _maskedRow = nil,      -- the focused row whose Stat/Value cells are currently hidden
    _maskedControls = nil, -- cached {statCell, valueCell} to restore
}
BETTERUI.Vendor.InlineBuySpinner = InlineBuySpinner

local SPINNER_CONTROL_NAME = "BetteruiVendorInlineBuyQuantitySpinner"
local CELL_ANCHOR_BLEED_Y = 4 -- small vertical bleed so the 42px dial isn't clipped by the row
-- Shift the whole < n > dial left by this many UI units. The ZOS spinner centers its
-- number inside a ~97px control (left/right arrows flank it), which leaves the number
-- sitting mid-cell; nudging left lines it up with the column's own left-aligned values.
local SPINNER_LEFT_NUDGE = -40
-- Nudge the running-total (Price/currency) left a few units so it lines up with the row's
-- plain left-aligned Value text: the ZO_CurrencyTemplate carries a small internal left inset
-- that otherwise sits the total a few px right of the other rows' values.
local PRICE_LEFT_NUDGE = -8
-- The dial "arms" only after the analog stick returns within this magnitude of neutral
-- since the last attach, so a stick still held from a list scroll / selection change can't
-- fire a phantom +/-1 on the first attached frame (GAMEPAD_INCLUDE_DEADZONE reports 0 at rest).
local DIAL_NEUTRAL_EPSILON = 0.1
-- Existing row cells the spinner borrows: the Stat cell hosts the < n > dial and
-- the Value cell hosts the running total. Both are hidden while attached and
-- restored on detach. Named children only -> reusable by any BetterUI list scene.
local BORROWED_CELL_NAMES = { "Stat", "Value" }

local function TraceInlineSpinner(phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Vendor"
    data.feature = "vendor-inline-spinner"
    L.TraceEvent(L.CATEGORY.ACTION, "vendor.inline_spinner", phase, data)
end

---@param v number
---@param lo number
---@param hi number
---@return number
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- Left-stick X magnitude for the horizontal dial controller. Uses ONLY the public
--- GetGamepadLeftStickX. CRITICAL: DIRECTIONAL_INPUT:GetX(..., ZO_DI_DPAD) reads the
--- D-pad via the PROTECTED IsKeyDown, which is illegal from insecure (addon) code --
--- calling it threw "Attempt to access a private function 'IsKeyDown'... callstack
--- became untrusted" EVERY FRAME, aborting ZO_DirectionalInput:OnUpdate and freezing
--- the keybind strip / LB-RB / list navigation (and wedging it after scene exit). The
--- D-pad cannot be polled safely from an addon, so dialing is analog-stick only
--- (mirrors the vendor search controller's GetVendorSearchStickY precedent).
---@return number
local function GetBuyQuantityStickX()
    local getX = rawget(_G, "GetGamepadLeftStickX")
    if type(getX) == "function" then
        return getX(rawget(_G, "GAMEPAD_INCLUDE_DEADZONE")) or 0
    end
    return 0
end

--- Left-stick Y magnitude, read the same safe public way as GetBuyQuantityStickX. Used
--- only to compare against |X| so a mostly-vertical scroll can't trip the horizontal
--- dial (see HandleDirectionalInput's dominance guard).
---@return number
local function GetBuyQuantityStickY()
    local getY = rawget(_G, "GetGamepadLeftStickY")
    if type(getY) == "function" then
        return getY(rawget(_G, "GAMEPAD_INCLUDE_DEADZONE")) or 0
    end
    return 0
end

--- The Stat + Value cells of a vendor row that the spinner borrows. Returned as a
--- list so Mask/RestoreRowContent stay generic.
---@param rowControl table|nil
---@return table controls
local function CollectBorrowedCells(rowControl)
    local controls = {}
    if rowControl and rowControl.GetNamedChild then
        for i = 1, #BORROWED_CELL_NAMES do
            local child = rowControl:GetNamedChild(BORROWED_CELL_NAMES[i])
            if child then controls[#controls + 1] = child end
        end
    end
    return controls
end

--- The Stat (dial host) and Value (total host) cells of a row, by name.
---@param rowControl table|nil
---@return table|nil statCell
---@return table|nil valueCell
local function GetRowCells(rowControl)
    if not (rowControl and rowControl.GetNamedChild) then
        return nil, nil
    end
    return rowControl:GetNamedChild("Stat"), rowControl:GetNamedChild("Value")
end

--- Lazily creates the shared overlay control under `parent` (a shown vendor
--- control). Returns the control or nil if the engine template / API is missing.
---@param parent table
---@return table|nil control
function InlineBuySpinner:EnsureControl(parent)
    if self._control then
        return self._control
    end
    if not parent then
        return nil
    end

    local createFromVirtual = rawget(_G, "CreateControlFromVirtual")
    if type(createFromVirtual) ~= "function" then
        TraceInlineSpinner("create_blocked", { reason = "noCreateControlFromVirtual" })
        return nil
    end

    -- ZO_GamepadLabeledQuantitySpinnerContainerTemplate zo_mixins
    -- ZO_GamepadQuantitySpinner onto the control in its OnInitialized.
    local control = createFromVirtual(SPINNER_CONTROL_NAME, parent, "ZO_GamepadLabeledQuantitySpinnerContainerTemplate")
    if not (control and type(control.InitializeSpinner) == "function") then
        TraceInlineSpinner("create_blocked", { reason = "mixinMissing", hasControl = control ~= nil })
        return nil
    end

    local horizontal = rawget(_G, "GAMEPAD_SPINNER_DIRECTION_HORIZONTAL")
    control:InitializeSpinner(function(newValue)
        if self._onValueChanged then
            self._onValueChanged(newValue)
        end
    end, horizontal)
    control:SetHidden(true)

    -- We borrow the row's Stat + Value cells rather than taking over the row, so
    -- the template's own caption + outline are unused: hide the "QUANTITY" Label
    -- and the outline Highlight. The Price (running total) child is kept and gets
    -- re-anchored onto the row's Value cell on each attach.
    local caption = control:GetNamedChild("Label")
    if caption then caption:SetHidden(true) end
    local highlight = control:GetNamedChild("Highlight")
    if highlight then highlight:SetHidden(true) end
    self._priceControl = control:GetNamedChild("Price")

    -- Left-align the < n > dial inside the Stat cell so it lines up with the column's
    -- own left-aligned text (the row cells are horizontalAlignment=LEFT). The template
    -- anchors the spinner CENTER, which pushed it to the right of the column.
    local spinner = control:GetNamedChild("Spinner")
    if spinner then
        spinner:ClearAnchors()
        spinner:SetAnchor(LEFT, control, LEFT, SPINNER_LEFT_NUDGE, 0)
    end

    self._control = control
    TraceInlineSpinner("created", nil)
    return control
end

--- (Re)anchors the < n > dial into the row's Stat cell and the running-total label
--- onto the row's Value cell. Hidden cells keep their layout, so this positions
--- the dial/total exactly in those columns regardless of the list font size.
---@param rowControl table
---@param statCell table|nil
---@param valueCell table|nil
---@return nil
function InlineBuySpinner:AnchorToRow(rowControl, statCell, valueCell)
    local control = self._control
    if not control then
        return
    end
    if not (statCell and valueCell) then
        local s, v = GetRowCells(rowControl)
        statCell = statCell or s
        valueCell = valueCell or v
    end
    if statCell then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, statCell, TOPLEFT, 0, -CELL_ANCHOR_BLEED_Y)
        control:SetAnchor(BOTTOMRIGHT, statCell, BOTTOMRIGHT, 0, CELL_ANCHOR_BLEED_Y)
    end
    if self._priceControl and valueCell then
        -- Left-align the running total at the Value column start, matching the row's
        -- own left-aligned Value text (right-anchoring pushed it to the cell's edge).
        self._priceControl:ClearAnchors()
        self._priceControl:SetAnchor(LEFT, valueCell, LEFT, PRICE_LEFT_NUDGE, 0)
    end
end

--- Attaches the spinner to `rowControl`: the < n > dial in its Stat cell and the
--- running total in its Value cell (both borrowed from the row).
---@param parent table Stable, shown vendor control that owns the overlay (e.g. list.control)
---@param rowControl table The currently focused row control
---@param params { min:integer?, max:integer, unitPrice:integer?, currencyType:integer?, onValueChanged:fun(v:integer)? }
---@return boolean attached
function InlineBuySpinner:Attach(parent, rowControl, params)
    if not (rowControl and params and params.max and params.max > 1) then
        TraceInlineSpinner("attach_blocked", { reason = "invalidArgs", max = params and params.max or nil })
        return false
    end

    local control = self:EnsureControl(parent)
    if not control then
        return false
    end

    local statCell, valueCell = GetRowCells(rowControl)
    if not (statCell and valueCell) then
        TraceInlineSpinner("attach_blocked", { reason = "missingCells" })
        return false
    end

    -- Preserve the dialed quantity when RE-attaching to the SAME entry (a same-row
    -- reselect or a background list refresh must not snap the user's choice back to 1).
    -- Capture before SetMinMax, which may clamp the live value.
    local sameEntry = self._attached and self._attachedEntryIndex ~= nil
        and params.entryIndex ~= nil and self._attachedEntryIndex == params.entryIndex
    local preservedValue = nil
    if sameEntry then
        local current = control:GetValue()
        if type(current) == "number" then
            preservedValue = current
        end
    end

    self._min = params.min or 1
    self._max = params.max
    self._unitPrice = params.unitPrice or 0
    self._currencyType = params.currencyType
    self._onValueChanged = params.onValueChanged

    -- Configure range + currency, then set the value: the preserved dial for the same
    -- entry (clamped to the possibly-changed max), else the minimum for a fresh row.
    -- SetupCurrency + SetValue drive the mixin's OnValueChanged, which renders the
    -- running total (red if unaffordable) into the Price child.
    control:SetMinMax(self._min, self._max)
    control:SetupCurrency(self._unitPrice, self._currencyType)
    control:SetValue(preservedValue and Clamp(preservedValue, self._min, self._max) or self._min)

    self._attached = true
    self._attachedEntryIndex = params.entryIndex
    self._dialArmed = false
    self:AnchorToRow(rowControl, statCell, valueCell)
    control:SetHidden(false)
    -- Borrow the Stat cell (dial) + Value cell (total): hide the row's own text in
    -- them so the spinner + running total show in their place.
    self:MaskRowContent(rowControl)

    TraceInlineSpinner("attached", { min = self._min, max = self._max, unitPrice = self._unitPrice })
    return true
end

--- Hides + unanchors the overlay and restores the borrowed cells. Safe when not attached.
---@return nil
function InlineBuySpinner:Detach()
    self._attached = false
    self._attachedEntryIndex = nil
    self._dialArmed = false
    -- Drop the movement controller so the next attach starts from zeroed accumulation
    -- (it is rebuilt lazily); with arm-on-neutral this stops a stick held across a
    -- selection change from carrying stale dial state onto the next row.
    self._movementController = nil
    self._onValueChanged = nil
    self:RestoreRowContent()
    local control = self._control
    if not control then
        return
    end
    control:SetHidden(true)
    control:ClearAnchors()
    TraceInlineSpinner("detached", nil)
end

--- Hides the row's borrowed Stat/Value cells so the dial + total show in their
--- place. Restores any previously borrowed row first (idempotent for same control).
---@param rowControl table
---@return nil
function InlineBuySpinner:MaskRowContent(rowControl)
    if not rowControl or self._maskedRow == rowControl then
        return
    end
    self:RestoreRowContent()
    local controls = CollectBorrowedCells(rowControl)
    for i = 1, #controls do
        local c = controls[i]
        if c.SetHidden then c:SetHidden(true) end
    end
    self._maskedRow = rowControl
    self._maskedControls = controls
end

--- Re-shows the borrowed cells of the currently masked row (if any). Safe anytime;
--- makes restore pooling-safe so a recycled row control never keeps them hidden.
---@return nil
function InlineBuySpinner:RestoreRowContent()
    local controls = self._maskedControls
    if controls then
        for i = 1, #controls do
            local c = controls[i]
            if c and c.SetHidden then c:SetHidden(false) end
        end
    end
    self._maskedRow = nil
    self._maskedControls = nil
end

--- @param control table
--- @return boolean true if the inline spinner is currently borrowing `control`'s cells
function InlineBuySpinner:IsRowMasked(control)
    return self._maskedRow ~= nil and self._maskedRow == control
end

--- @return boolean
function InlineBuySpinner:IsAttached()
    return self._attached == true and self._control ~= nil
end

--- Nudges the quantity by delta (D-pad / left-stick +/-1), clamped to [min,max].
---@param delta integer
---@return integer|nil value
function InlineBuySpinner:Adjust(delta)
    if not self:IsAttached() then
        return nil
    end
    local current = self._control:GetValue() or self._min
    local next = Clamp(current + (delta or 0), self._min, self._max)
    if next ~= current then
        self._control:SetValue(next)
    end
    return next
end

--- Jumps to the minimum (L2 quick-select).
---@return integer|nil value
function InlineBuySpinner:SetToMin()
    if not self:IsAttached() then return nil end
    self._control:SetValue(self._min)
    return self._min
end

--- Jumps to the maximum (R2 quick-select).
---@return integer|nil value
function InlineBuySpinner:SetToMax()
    if not self:IsAttached() then return nil end
    self._control:SetValue(self._max)
    return self._max
end

--- @return integer|nil quantity Current dialed quantity, or nil if not attached
function InlineBuySpinner:GetQuantity()
    if not self:IsAttached() then
        return nil
    end
    return self._control:GetValue()
end

--- @return integer max The current attached max (1 if not attached)
function InlineBuySpinner:GetMax()
    return self._max or 1
end

--- Lazily builds the horizontal movement controller that turns left/right stick +
--- D-pad into discrete +/-1 dial steps (with the engine's hold-repeat
--- acceleration). It is POLLED inside HandleDirectionalInput -- it never registers
--- a DIRECTIONAL_INPUT owner, so it never contends with the list's own input.
---@return table|nil controller
function InlineBuySpinner:EnsureMovementController()
    if self._movementController then
        return self._movementController
    end
    local ctor = rawget(_G, "ZO_MovementController")
    local horizontal = rawget(_G, "MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL")
    if not (ctor and horizontal) then
        return nil
    end
    self._movementController = ctor:New(horizontal, nil, GetBuyQuantityStickX)
    return self._movementController
end

--- Called from the vendor list's custom directional-input handler every frame.
--- While attached, consumes LEFT/RIGHT to dial the quantity (returns true); returns
--- false otherwise so the list's own UP/DOWN row navigation is left untouched.
---@param verticalResult number The list's own vertical movement result this frame (0/NO_CHANGE = none)
---@return boolean consumed
function InlineBuySpinner:HandleDirectionalInput(verticalResult)
    if not self:IsAttached() then
        return false
    end
    local controller = self:EnsureMovementController()
    if not controller then
        return false
    end
    -- Advance the controller EVERY attached frame -- even when we won't dial -- so it
    -- observes neutral (zero-magnitude) frames and resets its own accumulation/debt.
    -- ZO_MovementController:CheckMovement only clears its repeat state on a zero reading,
    -- so short-circuiting before this call left stale debt that dropped/delayed the next dial.
    local result = controller:CheckMovement()

    local absX = GetBuyQuantityStickX()
    if absX < 0 then absX = -absX end
    local absY = GetBuyQuantityStickY()
    if absY < 0 then absY = -absY end

    -- Arm-on-neutral: after each attach, ignore dialing until the stick has returned to
    -- (near) neutral once, so a stick still held from the selection change / list scroll
    -- can't make a fresh controller fire a phantom step on the first attached frame.
    if not self._dialArmed then
        if absX < DIAL_NEUTRAL_EPSILON and absY < DIAL_NEUTRAL_EPSILON then
            self._dialArmed = true
        end
        return false
    end

    -- Returning true here SKIPS the list's up/down move, so dial ONLY on a clearly-sideways
    -- push. Otherwise scrolling the item list "hiccups" whenever the stick drifts sideways
    -- during a vertical push. Two guards, either one defers to the list:
    --   1. The list already resolved a vertical move this frame -> it wins.
    --   2. Else |stickX| must dominate |stickY| (a more-than-45-degrees-sideways push).
    local noChange = rawget(_G, "MOVEMENT_CONTROLLER_NO_CHANGE") or 0
    if verticalResult ~= nil and verticalResult ~= noChange then
        return false
    end
    if absX <= absY then
        return false
    end
    -- ESO's horizontal movement controller maps positive magnitude (stick RIGHT) to
    -- MOVE_PREVIOUS and negative (LEFT) to MOVE_NEXT: RIGHT increments, LEFT decrements.
    if result == rawget(_G, "MOVEMENT_CONTROLLER_MOVE_PREVIOUS") then
        self:Adjust(1)
        return true
    elseif result == rawget(_G, "MOVEMENT_CONTROLLER_MOVE_NEXT") then
        self:Adjust(-1)
        return true
    end
    return false
end

--- Decides whether the inline spinner should be shown for the current selection,
--- (re)attaching or detaching accordingly. Only BUY-mode store entries with a live
--- GetStoreEntryMaxBuyable > 1 get the spinner (store entryIndex and sell slotIndex
--- can collide, so the buy-mode gate is required).
--- True when the spinner is dialing a specific store entry (the entry the user
--- pressed Buy on). Distinguishes the FIRST Buy press (reveal spinner) from the
--- SECOND (execute the purchase).
---@param entryIndex integer|nil
---@return boolean
function InlineBuySpinner:IsDialingEntry(entryIndex)
    return self:IsAttached() and entryIndex ~= nil and self._attachedEntryIndex == entryIndex
end

--- Enters dialing mode: attaches the inline spinner to the currently focused BUY
--- row when it is a stackable buyable (GetStoreEntryMaxBuyable > 1). Called from
--- the Buy keybind (NOT on plain selection) so the spinner stays hidden until the
--- user presses Buy, matching the default store. Returns true when dialing began.
---@param instance BETTERUI.Vendor.Class
---@param selectedData table|nil
---@return boolean started
function InlineBuySpinner:BeginDialing(instance, selectedData)
    if not instance then
        return false
    end

    local buyMode = rawget(_G, "ZO_MODE_STORE_BUY")
    local currentMode = instance.GetCurrentMode and instance:GetCurrentMode() or nil
    if not (buyMode and currentMode == buyMode) then
        return false
    end

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    local entryIndex = ds and (ds.entryIndex or ds.slotIndex) or nil
    if not entryIndex then
        return false
    end

    local getMax = rawget(_G, "GetStoreEntryMaxBuyable")
    local maxBuyable = getMax and getMax(entryIndex) or 0
    if type(maxBuyable) ~= "number" or maxBuyable <= 1 then
        return false
    end

    local list = instance.list
    local rowControl = list and list.GetSelectedControl and list:GetSelectedControl() or nil
    local parent = list and list.control or nil
    if not (rowControl and parent) then
        return false
    end

    -- 999 display cap (MAX_STORE_WINDOW_STACK_QUANTITY), matching the native store.
    local cap = rawget(_G, "MAX_STORE_WINDOW_STACK_QUANTITY") or 999
    local max = maxBuyable
    if max > cap then
        max = cap
    end

    return self:Attach(parent, rowControl, {
        min = 1,
        max = max,
        unitPrice = ds.price,
        currencyType = ds.currencyType1,
        entryIndex = entryIndex,
    })
end

--- Maintains an ACTIVE dialing session across selection changes. The spinner is
--- revealed only by the Buy press (BeginDialing), never by plain selection, so
--- this ONLY cancels dialing -- when focus leaves the dialed entry, BUY mode ends,
--- or the entry stops being a stackable buyable. While the same dialed entry stays
--- focused the row-control glue is handled authoritatively by VendorEntrySetup.
---@param instance BETTERUI.Vendor.Class
---@param selectedData table|nil
---@return nil
function InlineBuySpinner:UpdateForSelection(instance, selectedData)
    if not self:IsAttached() then
        return
    end
    if not instance then
        self:Detach()
        return
    end

    local buyMode = rawget(_G, "ZO_MODE_STORE_BUY")
    local currentMode = instance.GetCurrentMode and instance:GetCurrentMode() or nil
    if not (buyMode and currentMode == buyMode) then
        self:Detach()
        return
    end

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    local entryIndex = ds and (ds.entryIndex or ds.slotIndex) or nil
    if not entryIndex or entryIndex ~= self._attachedEntryIndex then
        -- Focus moved off the dialed row (or onto a non-entry row): cancel dialing.
        self:Detach()
        return
    end

    local getMax = rawget(_G, "GetStoreEntryMaxBuyable")
    local maxBuyable = getMax and getMax(entryIndex) or 0
    if type(maxBuyable) ~= "number" or maxBuyable <= 1 then
        self:Detach()
    end
end

--- Re-anchors the (already attached) overlay to a freshly set-up row control.
--- Called from VendorEntrySetup for the selected row so the dial/total stay glued
--- across list scroll / row-control recycling.
---@param rowControl table
---@return nil
function InlineBuySpinner:Reanchor(rowControl)
    if not (self:IsAttached() and rowControl and self._control) then
        return
    end
    -- Row control recycled to a new selected row: re-borrow the new row's cells
    -- (restoring the previous) then re-anchor the dial/total into them.
    self:MaskRowContent(rowControl)
    self:AnchorToRow(rowControl)
end
