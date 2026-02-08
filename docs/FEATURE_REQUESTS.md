# BetterUI Feature Requests: Gamepad QoL Enhancements

> **Created:** 2026-02-08
> **Last audited:** 2026-02-08
> **Source:** Standard-scope audit of `esoui/` gamepad systems (Categories A-C and F) cross-referenced against BetterUI modules (`CIM`, `Banking`, `Inventory`, `ResourceOrbFrames`, `WritUnit`).

---

## Overview

This document catalogs gamepad QoL opportunities from `esoui/` and tracks their current BetterUI status (`MISSING`, `PARTIAL`, `IMPLEMENTED`).

### Audit Delta (2026-02-08)

- **Added:** 4 new requests (`Guild Roster`, `Social Hub`, `Chat Menu`, `Maintenance Hub`)
- **Updated:** 11 existing requests (status and priority corrections)
- **Closed as implemented:** 2 items (inventory stat comparison baseline, stack-all keybind exposure)
- **Reopened for review:** 1 item (`New Item` visual lifecycle appears non-functional in current BetterUI behavior)

---

## Table of Contents

1. [Item Stat Comparison Tooltip System (Parity)](#1-item-stat-comparison-tooltip-system-parity)
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
13. ["New Item" Visual Tracking System (Needs Review)](#13-new-item-visual-tracking-system-needs-review)
14. [Stack Consolidation ("Stack All") Feature (Implemented)](#14-stack-consolidation-stack-all-feature-implemented)
15. [Companion Equipment Management](#15-companion-equipment-management)
16. [Guild Roster & Rank Management Workspace](#16-guild-roster--rank-management-workspace)
17. [Social Contacts & Notification Hub](#17-social-contacts--notification-hub)
18. [Chat Menu & Channel Tooling](#18-chat-menu--channel-tooling)
19. [Equipment Maintenance Hub (Repair + Soul Gems)](#19-equipment-maintenance-hub-repair--soul-gems)

---

## 1. Item Stat Comparison Tooltip System (Parity)

**Status:** `PARTIAL`  
**esoui source:** `esoui/ingame/inventory/gamepad/gamepadinventory.lua:2051`  
**BetterUI baseline:** `Modules/Inventory/Lists/ItemListManager.lua:721`, `Modules/Inventory/Keybinds/InventoryKeybinds.lua:295`

### What the base game has

A full side-by-side stat comparison system for gamepad inventory. When browsing items, pressing a secondary action key toggles a comparison tooltip that shows the stat delta between the selected item and the currently equipped item in that slot. It uses `GAMEPAD_TOOLTIPS:LayoutItemStatComparison()` and supports:

- **Equipped item comparison** with green/red stat deltas (DPS, armor, enchantment, trait)
- **Mundus Stone stat comparison** via `LayoutMundusStatComparison()` showing derived stat effects
- **Companion item comparison** with `ZO_LayoutBagItemEquippedComparison()`
- An account-wide saved variable `useStatComparisonTooltip` for persistence
- A toggle keybind on `UI_SHORTCUT_SECONDARY` to enable/disable

### What BetterUI lacks

BetterUI already supports inventory stat comparison with toggle behavior, but parity is incomplete across adjacent systems (Banking and dedicated Companion surfaces). The remaining gap is coverage consistency, not baseline capability.

### Implementation notes

- Keep Inventory implementation as canonical reference.
- Extend comparison to Banking item rows where equip-slot derivation is valid.
- Apply same comparison policy to future Companion-focused list surfaces.

---

## 2. Radial Utility Wheel / Quick Slot Management

**esoui source:** `esoui/ingame/quickslot/gamepad/quickslot_gamepad.lua`, `esoui/ingame/utilitywheel/gamepad/accessibleassignableutilitywheel_gamepad.lua`
**Status:** `PARTIAL`

### What the base game has

A radial wheel UI (`ZO_AssignableUtilityWheel_Gamepad`) for quickslot assignment with:

- 8-slot radial selection with analog stick input (`ZO_RadialMenu` from `esoui/libraries/zo_radialmenu/`)
- Three assignment types: items, collectibles (mounts/pets), and quest items
- Visual pending-assignment indicators with sparkle/completion effects
- An accessible alternative mode via `ACCESSIBILITY_SETTING_ACCESSIBLE_QUICKWHEELS` for players who struggle with radial input
- Category labels and icon previews during selection

### What BetterUI lacks

BetterUI has a working quickslot assignment flow (`Modules/Inventory/Actions/QuickslotAction.lua`) but still lacks a dedicated quickslot management scene for full loadout browsing, reordering, and cross-category maintenance.

### Implementation notes

- New module: `Modules/QuickSlots/`
- Keep current assignment dialog as fallback path.
- Use CIM's parametric list for a browsable quickslot inventory.
- Integrate `ZO_RadialMenu` for the visual wheel (or offer list-based alternative).
- Support all three assignment types: items, collectibles, quest items
- Add search/filter using CIM's `SearchManager`

---

## 3. Guild Bank Module with Permission-Aware UI

**esoui source:** `esoui/ingame/inventory/gamepad/guildbank_gamepad.lua` (35KB)
**Status:** `MISSING`  
**BetterUI baseline:** `Modules/Banking/State/StateManager.lua` currently resolves non-house banking to `BAG_BANK`, so guild-bank mode is not surfaced.

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
**Status:** `MISSING`

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
**Status:** `MISSING`

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
**Status:** `MISSING`

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
**Status:** `MISSING`

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
**Status:** `MISSING`

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
**Status:** `MISSING`

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
**Status:** `MISSING`

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
**Status:** `MISSING`

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
**Status:** `PARTIAL`  
**BetterUI baseline:** Search narration exists via `SCREEN_NARRATION_MANAGER:RegisterTextSearchHeader(...)` in `Modules/CIM/Core/SearchManager.lua`.

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

BetterUI has partial narration support but does not yet match native coverage for full parametric-list screen registration, generalized entry narration, and price narration consistency. Accessibility parity is not complete across all custom BetterUI screens.

### Implementation notes

- Add `GetNarrationText()`, `GetHeaderNarration()`, and `GetFooterNarration()` overrides to CIM's base `WindowClass.lua` and `GenericWindow.lua`
- Register CIM lists with `SCREEN_NARRATION_MANAGER:RegisterParametricListScreen()`
- Since CIM's class hierarchy is shared by all modules, this only needs to be done once in the base classes
- Add `entryData:SetPriceNarrationInfo()` calls in `ItemDataProcessor`
- **Low effort, high impact**: all BetterUI modules inherit the fix automatically

---

## 13. "New Item" Visual Tracking System (Needs Review)

**Status:** `NOT WORKING - NEEDS REVIEW`  
**esoui source:** `esoui/ingame/inventory/gamepad/gamepadinventory.lua` (lines ~62-75), `esoui/common/gamepad/zo_gamepadentrydata.lua`  
**Current BetterUI references to audit:** `Modules/Inventory/Lists/InventoryList.lua:211`, `Modules/Inventory/Lists/InventoryList.lua:617`, `Modules/Inventory/Lists/ItemListManager.lua:93`

### What the base game has

- **Pulsing "NEW" badge animation** on list entries
- **`PrepareNextClearNewStatus()`**: Queues clearing the new flag on selection change
- **`TryClearNewStatusOnHidden()`**: Clears when list is hidden
- **Persist-while-selected**: Shows for 200ms even after selection for smooth UX
- **Fade-out timeline**: Animated removal after clearing
- **`entryData:SetNew(isNew)` / `entryData:IsNew()`**: Per-entry state

### What BetterUI lacks

BetterUI appears to have hook points for new-item behavior, but the feature is currently reported as not working in practice and requires review. Until verified in-game, this should be treated as an active backlog item rather than implemented.

### Implementation notes

- Verify whether `data.brandNew` is populated correctly for BetterUI list entries.
- Confirm `PrepareNextClearNewStatus()` / `TryClearNewStatusOnHidden()` timing against list activation/deactivation flow.
- Add/restore explicit visual animation timeline if state is present but icon never renders.
- Re-validate in-game after fixes before reclassifying as implemented.

---

## 14. Stack Consolidation ("Stack All") Feature (Implemented)

**Status:** `IMPLEMENTED`  
**esoui source:** `esoui/ingame/inventory/gamepad/gamepadinventory.lua:804`  
**BetterUI implementation:** `Modules/CIM/Keybinds/GenericKeybinds.lua:50`, `Modules/Inventory/Keybinds/InventoryKeybinds.lua:419`, `Modules/Banking/Keybinds/KeybindManager.lua:186`

BetterUI already exposes stack-all keybinds in Inventory and Banking flows, including Banking-specific dual-bank handling.

### Optional follow-up (not backlog-critical)

- Add optional completion toast/count feedback after stack operations.

---

## 15. Companion Equipment Management

**esoui source:** `esoui/ingame/companion/gamepad/companionequipment_gamepad.lua`, `esoui/ingame/companion/gamepad/companionskills_gamepad.lua`
**Status:** `PARTIAL`  
**BetterUI baseline:** Companion compatibility and equip patching exist (`Modules/Inventory/Actions/EquipAction.lua`), but no dedicated companion-management scene exists.

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

## 16. Guild Roster & Rank Management Workspace

**esoui source:** `esoui/ingame/guild/gamepad/guildroster_gamepad.lua:209`, `esoui/ingame/guild/gamepad/guildroster_gamepad.lua:231`, `esoui/ingame/guild/gamepad/guildroster_gamepad.lua:307`, `esoui/ingame/guild/gamepad/zo_guildranks_gamepad.lua:150`, `esoui/ingame/guild/gamepad/zo_guildranks_gamepad.lua:888`  
**Status:** `MISSING`

### What the base game has

- Permission-aware member moderation actions (promote/demote/set rank/remove/uninvite/edit note)
- Rank editing and permission grid workflows
- Integrated social actions (mail, whisper, invite, travel)

### What BetterUI lacks

BetterUI currently does not enhance guild roster or rank-management gamepad flows despite heavy daily usage in trading and social guilds.

### Implementation notes

- New module: `Modules/Guild/` (or `Modules/Social/Guild/`)
- Reuse CIM list/search/sort infrastructure for roster readability upgrades
- Keep native permission checks and dialogs, improve discoverability and row clarity

---

## 17. Social Contacts & Notification Hub

**esoui source:** `esoui/ingame/contacts/gamepad/sociallist_gamepad.lua:28`, `esoui/ingame/contacts/gamepad/sociallist_gamepad.lua:105`, `esoui/ingame/contacts/gamepad/sociallist_gamepad.lua:220`, `esoui/ingame/contacts/gamepad/notifications_gamepad.lua:578`, `esoui/ingame/contacts/gamepad/notifications_gamepad.lua:719`  
**Status:** `MISSING`

### What the base game has

- Searchable social list with hide-offline toggles and status filters
- Guild invite option templating from social lists
- Multi-action gamepad notification handling (accept/decline/more info/gamercard)

### What BetterUI lacks

BetterUI does not currently provide enhanced UX for friends/ignore/notifications despite having reusable list and tooltip foundations.

### Implementation notes

- New module: `Modules/Social/`
- Improve row density, status emphasis, and notification decision clarity
- Reuse CIM search and keybind patterns for consistent interaction

---

## 18. Chat Menu & Channel Tooling

**esoui source:** `esoui/ingame/chatsystem/gamepad/chatmenu_gamepad.lua:162`, `esoui/ingame/chatsystem/gamepad/chatmenu_gamepad.lua:250`, `esoui/ingame/chatsystem/gamepad/chatmenu_gamepad.lua:349`, `esoui/ingame/chatsystem/gamepad/chatmenu_gamepad.lua:405`, `esoui/ingame/chatsystem/gamepad/chatmenu_gamepad.lua:511`  
**Status:** `MISSING`

### What the base game has

- Dedicated channel dropdown lifecycle and active-channel syncing
- Link extraction and link-target navigation in chat log rows
- Gamepad keybind actions for send/roll/social options

### What BetterUI lacks

BetterUI does not currently improve gamepad chat channel ergonomics or link-focused message navigation.

### Implementation notes

- New module: `Modules/Chat/`
- Add channel presets and better channel-switching affordances
- Add stronger visual cues for link-containing rows and active context

---

## 19. Equipment Maintenance Hub (Repair + Soul Gems)

**esoui source:** `esoui/ingame/repair/gamepad/repairkits_gamepad.lua:7`, `esoui/ingame/soulgemitemcharger/gamepad/soulgemitemcharger_gamepad.lua:7`, `esoui/ingame/storewindow/gamepad/storewindow_gamepad.lua:277`  
**Status:** `MISSING`

### What the base game has

- Dedicated repair-kit flow with tier sorting and pending repair tooltip
- Dedicated soul-gem charging flow with pending charge tooltip
- Repair-all vendor integration and cost messaging

### What BetterUI lacks

BetterUI does not provide a unified maintenance UX that connects durability and charge workflows with inventory triage.

### Implementation notes

- New module: `Modules/Maintenance/`
- Add quick-jump actions from Inventory and Banking
- Surface maintenance urgency in BetterUI item rows and/or tooltips

---

## Priority Matrix

| # | Feature | Status | User Impact | Dev Effort | Priority |
|---|---------|--------|-------------|------------|----------|
| 12 | Accessibility / Narration | PARTIAL | **High** | **Low** | **P1** |
| 13 | New Item Visual Tracking | NOT WORKING - NEEDS REVIEW | Medium | **Low** | **P1** |
| 3 | Guild Bank Module | MISSING | **High** | Medium | **P1** |
| 4 | Enhanced Loot Window | MISSING | **High** | Medium | **P2** |
| 5 | Store / Vendor Enhancements | MISSING | **High** | Medium | **P2** |
| 6 | Trading House Enhancement | MISSING | **Very High** | **High** | **P2** |
| 1 | Item Stat Comparison Parity | PARTIAL | Medium | Medium | **P2** |
| 2 | Radial Quick Slot Manager | PARTIAL | Medium | High | **P3** |
| 7 | Crafting Station Enhancements | MISSING | Medium | High | **P3** |
| 8 | Mail System Enhancement | MISSING | Medium | Medium | **P3** |
| 9 | Collections & Outfit Browser | MISSING | Medium | High | **P3** |
| 15 | Companion Equipment Management | PARTIAL | Medium | Medium | **P3** |
| 16 | Guild Roster & Rank Workspace | MISSING | Medium | High | **P3** |
| 17 | Social Contacts & Notification Hub | MISSING | Medium | Medium | **P3** |
| 18 | Chat Menu & Channel Tooling | MISSING | Medium | Medium | **P3** |
| 19 | Equipment Maintenance Hub | MISSING | Medium | Medium | **P3** |
| 10 | Map Filter Enhancement | MISSING | Medium | High | **P4** |
| 11 | Group Finder Enhancement | MISSING | Medium | High | **P4** |

### Closed items (implemented)

- **#14 Stack Consolidation** — implemented in BetterUI Inventory and Banking keybind flows.

### Priority key

- **P1**: High value and high adjacency to current BetterUI module coverage.
- **P2**: High value with moderate-to-high effort but clear payoff.
- **P3**: Valuable expansions that can follow core adjacency work.
- **P4**: Long-horizon roadmap items.

### Recommended implementation order

1. **Accessibility completion** (#12) — finish narration parity on existing BetterUI surfaces.
2. **New Item tracking review/fix** (#13) — validate behavior and close regression risk.
3. **Guild Bank** (#3) — strongest module adjacency to current Banking architecture.
4. **Loot + Store/Vendor** (#4, #5) — shared item-list patterns and tooltip reuse.
5. **Trading House** (#6) — highest impact major module once core adjacent wins land.
6. **Quickslot + Companion parity** (#2, #15) — convert partial support into full workflows.
7. **Social/Guild/Chat tranche** (#16, #17, #18) — coordinated social UX pass.
