# BetterUI Feature Requests: Gamepad QoL Enhancements

> **Created:** 2026-02-08
> **Source:** Comprehensive audit of `esoui/` gamepad reference folder (130+ gamepad directories, 713+ files) cross-referenced against BetterUI's current 5 modules (CIM, Banking, Inventory, ResourceOrbFrames, WritUnit).

---

## Overview

This document catalogs gamepad-specific quality-of-life features present in the ESO base UI (`esoui/`) that BetterUI does not currently implement. Each recommendation includes source file references, a description of the base game feature, a gap analysis explaining what BetterUI lacks, and implementation notes.

A priority matrix is provided at the end.

---

## Table of Contents

1. [Item Stat Comparison Tooltip System](#1-item-stat-comparison-tooltip-system)
2. [Radial Utility Wheel / Quick Slot Management](#2-radial-utility-wheel--quick-slot-management)
3. [Guild Bank Module with Permission-Aware UI](#3-guild-bank-module-with-permission-aware-ui)
4. [Enhanced Loot Pickup Window](#4-enhanced-loot-pickup-window)
5. [Store / Vendor Window Enhancements](#5-store--vendor-window-enhancements)
6. [Trading House / Guild Store Enhancement](#6-trading-house--guild-store-enhancement)
7. [Crafting Station UI Enhancements](#7-crafting-station-ui-enhancements)
8. [Mail System Enhancement](#8-mail-system-enhancement)
9. [Collections & Outfit Management Browser](#9-collections--outfit-management-browser)
10. [Map Filter Enhancement & Quest Integration](#10-map-filter-enhancement--quest-integration)
11. [Group Finder & Role Selection Enhancement](#11-group-finder--role-selection-enhancement)
12. [Accessibility & Screen Narration Support](#12-accessibility--screen-narration-support)
13. ["New Item" Visual Tracking System](#13-new-item-visual-tracking-system)
14. [Stack Consolidation ("Stack All") Feature](#14-stack-consolidation-stack-all-feature)
15. [Companion Equipment Management](#15-companion-equipment-management)

---

## 1. Item Stat Comparison Tooltip System

**esoui source:** `esoui/ingame/inventory/gamepad/gamepadinventory.lua` (lines ~2050-2061)

### What the base game has

A full side-by-side stat comparison system for gamepad inventory. When browsing items, pressing a secondary action key toggles a comparison tooltip that shows the stat delta between the selected item and the currently equipped item in that slot. It uses `GAMEPAD_TOOLTIPS:LayoutItemStatComparison()` and supports:

- **Equipped item comparison** with green/red stat deltas (DPS, armor, enchantment, trait)
- **Mundus Stone stat comparison** via `LayoutMundusStatComparison()` showing derived stat effects
- **Companion item comparison** with `ZO_LayoutBagItemEquippedComparison()`
- An account-wide saved variable `useStatComparisonTooltip` for persistence
- A toggle keybind on `UI_SHORTCUT_SECONDARY` to enable/disable

### What BetterUI lacks

BetterUI's Inventory and Banking modules show item tooltips but don't implement the stat comparison overlay. Players must mentally calculate whether an item is an upgrade. Adding a comparison mode with clear +/- stat deltas (especially for traits and enchantments, which BetterUI already extracts) would be a significant usability win.

### Implementation notes

- Hook into the existing `GAMEPAD_TOOLTIPS:LayoutItemStatComparison()` API
- Add a toggle keybind to Inventory and Banking keybind descriptors
- Persist the toggle via `useStatComparisonTooltip` saved variable
- Extend CIM's `TooltipLayout.lua` to format comparison deltas with color coding

---

## 2. Radial Utility Wheel / Quick Slot Management

**esoui source:** `esoui/ingame/quickslot/gamepad/quickslot_gamepad.lua`, `esoui/ingame/utilitywheel/gamepad/accessibleassignableutilitywheel_gamepad.lua`

### What the base game has

A radial wheel UI (`ZO_AssignableUtilityWheel_Gamepad`) for quickslot assignment with:

- 8-slot radial selection with analog stick input (`ZO_RadialMenu` from `esoui/libraries/zo_radialmenu/`)
- Three assignment types: items, collectibles (mounts/pets), and quest items
- Visual pending-assignment indicators with sparkle/completion effects
- An accessible alternative mode via `ACCESSIBILITY_SETTING_ACCESSIBLE_QUICKWHEELS` for players who struggle with radial input
- Category labels and icon previews during selection

### What BetterUI lacks

BetterUI has a `QuickslotAction` in Inventory for *assigning* an item to a quickslot, but no dedicated quickslot *management* module. An enhanced quickslot manager with BetterUI's list-style UX (searchable, categorized, with item stat tooltips) alongside or replacing the radial wheel would let players manage their quickslot loadout far more efficiently than the stock radial-only interface.

### Implementation notes

- New module: `Modules/QuickSlots/`
- Use CIM's parametric list for a browsable quickslot inventory
- Integrate `ZO_RadialMenu` for the visual wheel (or offer list-based alternative)
- Support all three assignment types: items, collectibles, quest items
- Add search/filter using CIM's `SearchManager`

---

## 3. Guild Bank Module with Permission-Aware UI

**esoui source:** `esoui/ingame/inventory/gamepad/guildbank_gamepad.lua` (35KB)

### What the base game has

A substantial guild bank subsystem with:

- **Permission-gated actions**: `GUILD_PERMISSION_BANK_DEPOSIT`, `GUILD_PERMISSION_BANK_WITHDRAW`, `GUILD_PERMISSION_BANK_VIEW_GOLD`, `GUILD_PERMISSION_BANK_WITHDRAW_GOLD`
- **Contextual empty-state messaging**: different "no items" text depending on whether you lack permissions vs. the bank is empty
- **Gold transfer entry**: dedicated currency deposit/withdraw with dynamic icon tinting
- **Multi-guild switching**: quick-switch active guild without closing the UI
- **Category-based header grouping** with tiebreaker sorting

### What BetterUI lacks

BetterUI's Banking module handles personal bank, subscriber bank, and house banks with its enhanced list, categories, and currency system. However, it doesn't extend to guild banks. Guild bank interactions fall back to the stock UI. Given that BetterUI already has all the infrastructure (CIM lists, search, sort, categories, currency selectors), extending Banking to cover guild bank with proper permission indicators and multi-guild tab switching would be a natural and high-value addition.

### Implementation notes

- Extend `Modules/Banking/` with a guild bank mode or create `Modules/GuildBank/`
- Reuse `BankListManager`, `HeaderManager`, `FooterManager` patterns
- Add permission checks via `DoesPlayerHaveGuildPermission()` and `DoesGuildHavePrivilege()`
- Add guild selector tab (LB/RB to cycle guilds)
- Show contextual empty-state text based on permission state

---

## 4. Enhanced Loot Pickup Window

**esoui source:** `esoui/ingame/zo_loot/gamepad/lootpickup_gamepad.lua`, `esoui/ingame/zo_loot/gamepad/lootcommon_gamepad.lua`

### What the base game has

- Organized display by type (currency, items, quest items, collectibles)
- Quality/rarity color-coded icons
- Stack count display for stackable items
- Stolen item visual markers
- Separate entries for each currency type (gold, Tel Var, writ vouchers)
- Item tooltip on selection (right tooltip)
- "Take All" and "Take Selected" keybinds
- Ethereal (minimal chrome) keybinds for immersion
- Loot history tracking (`loothistory_gamepad.lua`) with session totals

### What BetterUI lacks

BetterUI doesn't touch the loot window at all. An enhanced loot module could add:

- BetterUI-styled fonts and layout
- Market price annotations (via the existing TTC/AGS integration in CIM's `MarketIntegration.lua`)
- Trait and set indicators on loot items
- Junk auto-flagging for items below a quality threshold
- A persistent loot history panel accessible from inventory

### Implementation notes

- New module: `Modules/Loot/`
- Hook or replace `ZO_LootPickup_Gamepad`
- Integrate CIM's `MarketIntegration` for price display
- Reuse existing trait/set icon patterns from Inventory's `ItemListManager`
- Add configurable auto-junk threshold in settings

---

## 5. Store / Vendor Window Enhancements

**esoui source:** `esoui/ingame/storewindow/gamepad/` (multiple files)

### What the base game has

- **Buy/Sell/Repair/Buyback tabs** with mode switching
- **Quantity spinner** for bulk purchases
- **Header focus switching** between header controls and item list
- **Real-time currency and inventory capacity** display
- **Repair All** batch operation with confirmation
- **Fence mode** (stolen goods laundering) with cost preview

### What BetterUI lacks

BetterUI doesn't modify vendor interactions. An enhanced store module could add:

- BetterUI's column sorting (sort vendor items by price, type, trait)
- Market price comparison (show TTC value next to vendor price so players know if an item is worth more on the guild store)
- Trait and set indicators on items being sold
- Batch "sell all junk" functionality
- Enhanced fence UI with laundering cost totals

### Implementation notes

- New module: `Modules/Store/`
- Hook `ZO_GamepadStoreManager` for buy/sell/repair modes
- Reuse CIM's `HeaderSortController` for column sorting
- Integrate `MarketIntegration` for TTC/AGS price comparison column
- Add "Sell All Junk" keybind with confirmation dialog

---

## 6. Trading House / Guild Store Enhancement

**esoui source:** `esoui/ingame/tradinghouse/gamepad/` (multiple files including browse, sell, name search autocomplete)

### What the base game has

- **Mode tabs**: Browse, Create Listing, Manage Listings, Manage Auctions
- **Text search with autocomplete** (`tradinghousenamesearchautocomplete_gamepad.lua`)
- **Search history** for quick re-running previous searches
- **Category quick-filters** (armor, weapons, enchantments, etc.)
- **Min/max price filtering**
- **Result locking** while search is executing
- **Listing duration selection** (1h, 12h, 24h, 48h)
- **Price suggestions** for sell listings

### What BetterUI lacks

The gamepad guild store experience is widely considered one of the weakest parts of ESO's gamepad UI. BetterUI could build a dramatically improved trading house with:

- Better search UX using CIM's search infrastructure
- Saved search presets (e.g., "CP160 gold jewelry", "alchemy reagents")
- Price-per-unit calculations for stacked items
- Integration with TTC price data for "good deal" indicators
- Enhanced result sorting (by unit price, not just total)
- A more readable listing management view with expiration warnings

### Implementation notes

- New module: `Modules/TradingHouse/`
- Hook or replace `ZO_GamepadTradingHouse`
- Leverage CIM's `SearchManager` for improved search UX
- Add saved search presets via saved variables
- Integrate `MarketIntegration` for TTC/AGS fair-price indicators
- Compute and display price-per-unit on all stacked listings
- This is the highest-effort but also highest-demand enhancement

---

## 7. Crafting Station UI Enhancements

**esoui source:** `esoui/ingame/crafting/gamepad/` (40+ files covering all crafting types)

### What the base game has

Extensive crafting UIs for:

- **Smithing**: Creation, Deconstruction, Improvement, Research modes with XP bar, material display, trait selection
- **Alchemy**: Reagent selection with effect combinations preview
- **Enchanting**: Glyph assembly (aspect/potency/essence), extraction, application
- **Provisioning**: Recipe browser with ingredient confirmation, batch creation
- **Scribing**: Ability combination with cost/effect preview
- **Craft Advisor**: `craftadvisor_gamepad.lua` with build suggestions
- **Consolidated Set Stations**: `consolidatedsmithingsets_gamepad.lua` for set crafting

The crafting inventory list (`gamepadcraftinginventory.lua`) auto-sorts items by tier and category with header grouping.

### What BetterUI lacks

BetterUI only touches crafting via WritUnit (writ progress display). BetterUI could enhance crafting station inventories with:

- Column sorting and market prices in deconstruction lists
- Trait and research status indicators (known/unknown/researching)
- A "deconstruction advisor" that highlights items with no research value and low market price
- Enhanced provisioning recipe browser with ingredient availability counts
- Improved material selection with BetterUI's search

### Implementation notes

- New module: `Modules/Crafting/` or enhance `Modules/WritUnit/`
- Hook crafting inventory lists to inject BetterUI's `ItemDataProcessor` formatting
- Add research status via CIM's existing `ResearchCache`
- Integrate `MarketIntegration` for decon value assessment
- Consider a "smart decon" mode that pre-selects low-value, no-research items

---

## 8. Mail System Enhancement

**esoui source:** `esoui/ingame/mail/gamepad/` (multiple files)

### What the base game has

- **Inbox/Send tabs** with unread count badges
- **"FULL" indicator** when inbox at capacity
- **Up to 10 attachment slots** with visual grid
- **COD handling** with color-coded cash-on-delivery and insufficient funds warning
- **Mail expiration display**
- **Return letter** (reply to sender)
- **Attachment management**: collect all or individual items

### What BetterUI lacks

BetterUI doesn't touch the mail system. An enhanced mail module could add:

- BetterUI-styled attachment list with market price annotations
- A "collect all attachments from all mail" bulk action
- COD value validation against TTC prices (is this COD fair?)
- Improved compose UI with recent-recipients autocomplete
- Mail expiration warnings with visual urgency indicators

### Implementation notes

- New module: `Modules/Mail/`
- Hook or replace `ZO_MailManager_Gamepad`
- Reuse CIM list patterns for inbox browsing
- Integrate `MarketIntegration` for attachment price display
- Add bulk collect via iteration over `GetNextMailId()` + `RequestReadMail()` + `TakeMailAttachedItems()`

---

## 9. Collections & Outfit Management Browser

**esoui source:** `esoui/ingame/collections/gamepad/collectionsbook_gamepad.lua`, `esoui/ingame/restyle/gamepad/`, `esoui/ingame/dyeing/gamepad/`

### What the base game has

- **Hierarchical collectible browsing** (Category > Subcategory > Items) with grid layout option
- **"New" indicator** with pulse animation for newly acquired collectibles
- **3D preview panel** for costumes, mounts, pets
- **Outfit selector** with rename, duplicate, and preview capabilities
- **Dye system** with channel selection, color picker, history, randomize, and undo
- **Restyle station** with outfit slot modification, dye channels, cost preview
- **Item set collection browser** showing craftable sets, bonuses, and piece tracking

### What BetterUI lacks

None of these are touched by BetterUI. An enhanced collections browser could provide:

- Better search and filtering for collectibles (especially useful given the massive number of collectibles in ESO)
- A favorites system for frequently used collectibles
- Categorized "recently acquired" view
- An improved outfit management workflow that's less cumbersome than the stock nested navigation
- Item set browser with "pieces owned" progress bars

### Implementation notes

- New module: `Modules/Collections/`
- Leverage CIM's `SearchManager` and `HeaderSortController`
- Use `ZO_COLLECTIBLE_DATA_MANAGER` for collectible data
- Add favorites via saved variables
- Surface set completion progress from `ITEM_SET_COLLECTIONS_DATA_MANAGER`

---

## 10. Map Filter Enhancement & Quest Integration

**esoui source:** `esoui/ingame/map/gamepad/` (multiple files: worldmapfilters, worldmapquests, worldmaplocations, worldmapzonestory)

### What the base game has

- **Checkbox filter list** with real-time map pin refresh and persistent settings
- **Dependent combo-box options** (dropdown filters only show when parent checkbox enabled)
- **Tab-based organization**: Quests, Locations, Filters, Houses, Antiquities
- **Interactive pin display** with click-to-view details and tooltips
- **Quest tracking** with set-as-active and objective viewing
- **Zone story progress tracking** with completion percentage and suggested activities
- **PvP keep information** with upgrade options, battle state, and resource counters
- **Antiquity lead tracking** on map with filter support

### What BetterUI lacks

BetterUI doesn't touch the map system. An enhanced map module could:

- Improve the filter UI with BetterUI's list presentation
- Add persistent custom filter presets (e.g., "Crafting Nodes Only", "Undiscovered Locations", "Active Quests Only")
- Improve the quest list with BetterUI's search and sorting
- Provide a better zone completion dashboard with clear progress indicators

### Implementation notes

- New module: `Modules/Map/`
- Hook `ZO_WorldMapFilters_Gamepad` for enhanced filter UI
- Add filter presets via saved variables
- Integrate CIM's search for quest list filtering
- Hook zone story panel for enhanced progress display

---

## 11. Group Finder & Role Selection Enhancement

**esoui source:** `esoui/ingame/groupfinder/gamepad/` (multiple files), `esoui/ingame/lfg/gamepad/`

### What the base game has

- **Visual role selection bar** (Tank/Healer/Damage) with toggle states and availability display
- **Activity categories**: Dungeons, Trials, Arenas with difficulty indicators
- **New content markers** with special coloring for recently added activities
- **Level/CP gating** showing requirements when disabled
- **Search results list** with member count, leader info, voice requirements
- **Application dialog** with optional message
- **Promotional event integration** showing special rewards
- **Group listing creation/editing** with activity, roles, voice options, description

### What BetterUI lacks

The group finder is one of the most-used systems for endgame players and its gamepad UX is notoriously clunky. BetterUI could enhance it with:

- Better search and filtering of group listings
- Saved activity presets ("my daily random dungeons")
- Clearer visual distinction between different difficulty tiers
- Improved group listing creation with templates
- Role queue status prominently displayed with estimated wait time

### Implementation notes

- New module: `Modules/GroupFinder/`
- Hook `ZO_GroupFinder_Gamepad` and related subsystems
- Reuse CIM's `SearchManager` for listing search
- Add activity presets via saved variables
- Enhance role bar with CIM visual patterns

---

## 12. Accessibility & Screen Narration Support

**esoui source:** Found in **300+ files** across the entire gamepad UI

### What the base game has

A comprehensive accessibility system:

- **`SCREEN_NARRATION_MANAGER`**: Central narration service
- **`GetNarrationText()`**: Required function on all interactive elements
- **Multi-part narration** with pause times between segments
- **Heading/entry separation**: Headers narrated separately from list entries
- **Ethereal keybind narration**: Informational keybinds announced to screen readers
- **`ACCESSIBILITY_SETTING_ACCESSIBLE_QUICKWHEELS`**: Alternative input for radial menus
- **`entryData:SetPriceNarrationInfo()`**: Price narration per entry
- **Registration**: `SCREEN_NARRATION_MANAGER:RegisterParametricListScreen(list, self)` and `RegisterGamepadGrid(self)`

### What BetterUI lacks

BetterUI's custom UI screens (Banking, Inventory) don't implement narration hooks. Since BetterUI replaces the stock screens entirely, players using screen readers lose all accessibility support when BetterUI is enabled. This is the single most impactful gap relative to effort.

### Implementation notes

- Add `GetNarrationText()`, `GetHeaderNarration()`, and `GetFooterNarration()` overrides to CIM's base `WindowClass.lua` and `GenericWindow.lua`
- Register CIM lists with `SCREEN_NARRATION_MANAGER:RegisterParametricListScreen()`
- Since CIM's class hierarchy is shared by all modules, this only needs to be done once in the base classes
- Add `entryData:SetPriceNarrationInfo()` calls in `ItemDataProcessor`
- **Low effort, high impact**: all BetterUI modules inherit the fix automatically

---

## 13. "New Item" Visual Tracking System

**esoui source:** `esoui/ingame/inventory/gamepad/gamepadinventory.lua` (lines ~62-75), `esoui/common/gamepad/zo_gamepadentrydata.lua`

### What the base game has

- **Pulsing "NEW" badge animation** on list entries
- **`PrepareNextClearNewStatus()`**: Queues clearing the new flag on selection change
- **`TryClearNewStatusOnHidden()`**: Clears when list is hidden
- **Persist-while-selected**: Shows for 200ms even after selection for smooth UX
- **Fade-out timeline**: Animated removal after clearing
- **`entryData:SetNew(isNew)` / `entryData:IsNew()`**: Per-entry state

### What BetterUI lacks

BetterUI tracks `isNew` in its item data structure but doesn't implement the visual "NEW" badge or the smart clear-on-view behavior. Adding a pulsing new-item indicator to inventory and banking lists would help players quickly identify freshly looted items, especially after returning from dungeons with full bags.

### Implementation notes

- Add a "NEW" badge texture to CIM's shared list templates (similar to the existing banking currency pulse animation work)
- Use `ZO_GamepadEntryData:SetNew()` / `:IsNew()` for state management
- Implement `PrepareNextClearNewStatus()` in list selection-changed callbacks
- Add fade-out animation timeline via `ANIMATION_MANAGER:CreateTimelineFromVirtual()`
- **Low effort**: reuses existing animation patterns from banking currency row pulse

---

## 14. Stack Consolidation ("Stack All") Feature

**esoui source:** `esoui/ingame/inventory/gamepad/gamepadinventory.lua` (lines ~804-811)

### What the base game has

- **Left Stick click** (`UI_SHORTCUT_LEFT_STICK`) triggers `StackBag()`
- Consolidates all partial stacks of the same item in the current bag
- Works across backpack and craft bag

### What BetterUI lacks

BetterUI's inventory doesn't expose this as a prominent keybind action. While the ESO API function `StackBag()` exists, BetterUI could enhance this with:

- A visual progress indicator during stacking
- A confirmation toast showing how many stacks were consolidated
- Extending it to work in banking (consolidate bank stacks, or merge inventory+bank stacks of the same item during deposit)

### Implementation notes

- Add `UI_SHORTCUT_LEFT_STICK` keybind to Inventory and Banking keybind descriptors
- Call `StackBag(bagId)` on activation
- Show a brief alert via `ZO_AlertTextForContext()` with consolidation count
- Optionally add a "Stack All in Bank" variant during banking sessions
- **Very low effort**: single keybind addition + one API call

---

## 15. Companion Equipment Management

**esoui source:** `esoui/ingame/companion/gamepad/companionequipment_gamepad.lua`, `esoui/ingame/companion/gamepad/companionskills_gamepad.lua`

### What the base game has

- **Separate companion inventory** with `ITEMFILTERTYPE_COMPANION` filter
- **Companion stat comparison** via `ZO_LayoutBagItemEquippedComparison()`
- **Companion skill management** with ability assignment to companion action bar
- **Quality filters** and equipment slot organization
- **Dedicated `BAG_COMPANION_WORN`** bag for companion equipment

### What BetterUI lacks

BetterUI's Inventory module filters companion items via `ITEMFILTERTYPE_COMPANION` but doesn't provide an enhanced companion equipment management screen. An enhanced companion gear view with BetterUI's column sorting, trait/stat display, and stat comparison (see recommendation #1) applied to companion slots would be valuable, especially since companions are now a core part of ESO gameplay.

### Implementation notes

- Extend `Modules/Inventory/` with a companion equipment tab or create `Modules/Companion/`
- Reuse `ItemListManager` patterns with `ITEMFILTERTYPE_COMPANION` filter
- Add companion equip slot display using `BAG_COMPANION_WORN`
- Integrate stat comparison from recommendation #1 using `ZO_LayoutBagItemEquippedComparison()`
- Add companion skill overview panel as secondary tab

---

## Priority Matrix

| # | Feature | User Impact | Dev Effort | CIM Synergy | Priority |
|---|---------|-------------|------------|-------------|----------|
| 12 | Accessibility / Narration | **High** | **Low** | Done once in base classes | **P0** |
| 13 | "New Item" Visual Tracking | Medium | **Low** | Reuses pulse animation | **P1** |
| 14 | Stack Consolidation | Low | **Very Low** | Single keybind | **P1** |
| 1 | Item Stat Comparison | **High** | Medium | Extends tooltip system | **P1** |
| 3 | Guild Bank Module | **High** | Medium | Extends Banking directly | **P1** |
| 4 | Enhanced Loot Window | **High** | Medium | New module, uses CIM + Market | **P2** |
| 5 | Store / Vendor Enhancements | **High** | Medium | New module, reuses CIM | **P2** |
| 15 | Companion Equipment | Medium | Medium | Extends Inventory | **P2** |
| 6 | Trading House Enhancement | **Very High** | **High** | Highest user demand | **P2** |
| 7 | Crafting Station Enhancements | Medium | High | Extends CIM into crafting | **P3** |
| 8 | Mail System Enhancement | Medium | Medium | New module | **P3** |
| 2 | Radial Quick Slot Manager | Medium | High | New module | **P3** |
| 9 | Collections & Outfit Browser | Medium | High | New module | **P3** |
| 10 | Map Filter Enhancement | Medium | High | New module | **P4** |
| 11 | Group Finder Enhancement | Medium | High | New module | **P4** |

### Priority key

- **P0**: Should be done ASAP — low effort, fixes a regression (accessibility loss)
- **P1**: High value, achievable quickly — quick wins or natural extensions of existing modules
- **P2**: High value, moderate effort — new modules that leverage CIM heavily
- **P3**: Medium value, higher effort — worthwhile but can wait
- **P4**: Medium value, high effort — long-term roadmap items

### Recommended implementation order

1. **Accessibility** (#12) — one-time CIM base class change, all modules benefit
2. **New Item Tracking** (#13) + **Stack All** (#14) — quick wins, immediate visual improvement
3. **Stat Comparison** (#1) — high visibility feature, extends existing tooltip work
4. **Guild Bank** (#3) — natural extension of the Banking module already built
5. **Loot Window** (#4) + **Vendor** (#5) — two new modules sharing patterns
6. **Trading House** (#6) — the crown jewel, highest community demand
