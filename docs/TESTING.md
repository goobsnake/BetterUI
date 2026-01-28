# BetterUI Manual Testing Procedures

## Overview

ESO addons cannot use automated test frameworks. This document provides manual verification procedures for each BetterUI module.

---

## Pre-Testing Checklist

1. **Backup SavedVariables** - Copy `Documents/Elder Scrolls Online/live/SavedVariables/BetterUI.lua`
2. **Enable debug output** - `/script BETTERUI.Debug("test")` should print `[BETTERUI] test`
3. **Clear UI errors** - `/reloadui` before starting session

---

## Module: Inventory

### Basic Functionality
- [ ] Open inventory (gamepad mode)
- [ ] Categories load and display correctly
- [ ] Item sorting works (by type, name, level)
- [ ] Item icons and names display correctly

### Keybind Actions
- [ ] **A button** - Primary action (equip/use)
- [ ] **X button** - Secondary action (quickslot/compare/link)
- [ ] **Y button** - Actions menu opens with valid options
- [ ] **L-Stick** - Stack all items
- [ ] **R-Stick** - Switch between bags
- [ ] **LB/RB** - Category navigation

### Search
- [ ] Search box appears and accepts input
- [ ] Filter updates list in real-time
- [ ] Clear search restores full list
- [ ] D-pad down exits search to list

### Tooltips
- [ ] Hover shows item tooltip
- [ ] Compare tooltip shows (if enabled)
- [ ] Trade prices show (if MM/ATT/TTC enabled)

---

## Module: Banking

### Basic Functionality
- [ ] Visit bank NPC
- [ ] Banking UI opens
- [ ] Category tabs navigate correctly
- [ ] Items display with correct icons/names

### Keybind Actions
- [ ] **A button** - Deposit/withdraw
- [ ] **Y button** - Actions menu
- [ ] **LB/RB** - Category navigation
- [ ] **L-Stick** - Stack all

### Search
- [ ] Search filters bank items
- [ ] Clear search works

---

## Module: Store (After Override Removal)

### Vendor Interaction
- [ ] Visit any vendor NPC
- [ ] Store UI opens without errors
- [ ] Buy items works
- [ ] Sell items works
- [ ] Buyback works
- [ ] Repair works (at armorer)

---

## Module: Resource Orbs

### Display
- [ ] Health/Magicka/Stamina orbs display
- [ ] Values update correctly
- [ ] Ultimate bar displays

---

## Regression Tests

### After Code Changes
1. `/reloadui` - No Lua errors
2. Open inventory - Verify fully functional
3. Visit bank - Verify fully functional
4. Visit store - Verify fully functional

### Backward Compatibility
- [ ] `ddebug("test")` works (deprecated alias)
- [ ] `BETTERUI_GamepadInventory_DefaultItemSortComparator` works (deprecated alias)

---

## Error Reporting

If errors occur:
1. Note exact steps to reproduce
2. Copy error message from chat
3. Check `Documents/Elder Scrolls Online/live/Logs/UIErrors.log`
