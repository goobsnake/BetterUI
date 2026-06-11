# Feature Requests Backlog

Last Updated: 2026-06-11
Status: Active

This document tracks durable BetterUI feature gaps and parity opportunities discovered from ESO gamepad workflow audits.

## Intake Rules

- Log one durable request per row with a stable ID.
- Keep entries scoped to product capability gaps, not transient bugs or outages.
- Include clear impact, effort, and priority so sequencing is objective.
- Move items to `Closed` only after code, docs, and in-game validation are complete.

## Entry Template

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Inventory and Companion

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-001` | 2026-06-11 | Inventory dialogs | Consolidate InventoryMultiSelect batch dialogs into `BETTERUI.CIM.Dialogs.Register` with a shared builder | Low | Low | P3 | Open | Engineer review (MPR-1). `Modules/Inventory/Core/InventoryMultiSelect.lua` writes two dialogs directly into `ESO_Dialogs`, bypassing central registration and duplicating ~45 lines of scaffolding. |
| `INV-002` | 2026-06-11 | Companions | Slot-centric companion category model (native parity): categories from `ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN)`, selected-slot equip targeting, right-tooltip slot mirroring | Medium | High | P3 | Open | Companions deep review (2026-06-11). BetterUI deliberately uses inventory-style filter categories; the native slot-centric model would add locked-slot visibility, two-handed off-hand display, empty-slot rows, and category headers. Interim fixes landed: locked-slot/two-handed equip-resolver rules, equipped-indicator tooltips, cooldowns, new-status clearing. |
| `INV-003` | 2026-06-11 | Companions | Gamepad item-preview integration for companion equipment (`PreviewInventoryItem`/`EndPreview`, gated by `CanInventoryItemBePreviewed`) | Low | Medium | P3 | Open | Companions deep review (2026-06-11). The screen does not participate in the gamepad item-preview system; native previews the selected item and ends preview on back navigation. |

## Banking and Economy

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `ECO-001` | 2026-05-29 | Currency display | Add Archival Fortunes to the currency display options | Medium | Low | P2 | **Completed** | ESOUI comment (oddavi, 05/29/26). Infinite Archive currency (`CURT_ARCHIVAL_FORTUNES`); add to the currency rows/toggles wherever existing optional currencies (Tel Var, Transmute, etc.) are offered. |

## Trading and Crafting

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `TRC-001` | 2026-04-11 | Market integration | Show market price data on crafting and improvement pages (TTC 4.27 parity) | Medium | Medium | P2 | **Completed** | ESOUI comment (Edricson, 04/11/26). TTC 4.27 added price data to crafting/improvement screens; extend BUI market integration (ATT/MM/TTC via `MarketIntegration.lua`) to gamepad crafting/improvement panels. |
| `TRC-002` | 2026-06-11 | Vendor buy flow | Quantity spinner for purchasing stacked store items (parity with native STORE_WINDOW_GAMEPAD spinner) | Medium | Medium | P3 | Open | Engineer review (MPR-1). `Modules/Vendor/Components/BuyComponent.lua` hard-codes quantity 1 for stacked items (e.g. lockpicks). Deep review (2026-06-11) extended scope: sell-side parity too — sell/fence-sell/launder/sell-vengeance actions always act on the full stack (native offers a stack spinner; see storewindowsell_gamepad.lua ConfirmSell/SetupSpinner). |
| `TRC-003` | 2026-06-11 | Guild store browse | Browse filter-editing UI: item-name search (`MatchTradingHouseItemNames` autocomplete), category, price-range, quality, and level filters | High | High | P2 | Open | TradingHouse deep review (2026-06-11). No filter UI exists, so every search dispatches the default everything-query and saved presets can only capture sort state. Native gamepad reference: tradinghouse_browse_gamepad.lua features (nameSearch, searchCategory, priceRange, quality). Search-feature association is already wired (`AssociateSearchFeatures` in TradingHouseRuntimeFlow.lua), so feature state plumbing is in place. |
| `TRC-004` | 2026-06-11 | Guild store sell | Digit-entry price selector for create-listing (ZO_CurrencySelector-style) | Low | Medium | P3 | Open | TradingHouse deep review (2026-06-11). The price slider now uses the native suggested price and step 1 for ranges ≤ 10000, but large ranges keep a coarse step (defaultPrice/20), so exact high prices remain unreachable without digit entry. |
| `TRC-005` | 2026-06-11 | Vendor stables | Stable parity polish: active-mount icon, no-mount-skin warning, train-button animation/narration | Low | Medium | P3 | Open | Vendor deep review (2026-06-11). `StableTrainingComponent.lua` uses a generic mount icon and calls `TrainRiding` directly; native resolves the active mount via STABLE_MANAGER and routes training through the animated/narrated button flow. |

## Social and Guild

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## World and Group Systems

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Accessibility and Platform

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `PLT-001` | 2026-06-11 | Code structure | Split files exceeding the 600-line standard by concern | Medium | High | P3 | Open | Engineer review (MPR-1). `Vendor/Core/VendorClass.lua` (~1840: header model, input ownership, search lifecycle), `Vendor/Vendor.lua` (~1390: keybinds, dialogs), `Banking/Core/BankingClass.lua` (~1067: sort comparators, transfer DI), `Inventory/Keybinds/CraftBagKeybinds.lua` (807; misnamed — holds generic inventory keybind logic), `GeneralInterface/Tooltips/Tooltips.lua` (~750), `CIM/Core/Batching/MultiSelectMixin.lua` (735; ~500-line `ProcessBatchThrottled`), `ResourceOrbFrames/Core/OrbVisuals.lua` (731), `CIM/Core/Diagnostics/DebugCommands.lua` (704), `CIM/Core/Batching/BatchConfig.lua` (613), plus the ~490-line `UpdateTooltipEquippedText` in `Inventory/UI/TooltipEquipped.lua`. |
| `PLT-002` | 2026-06-11 | Localization | Backfill non-EN locale files with missing string ids | Medium | Medium | P3 | Open | Engineer review (MPR-1). ~40 pre-existing SI_BETTERUI ids plus the 37 ids added 2026-06-11 exist only in `lang/en.lua`; de/es/fr/jp/ru/zh fall back to English. Also reconcile the one-id es.lua delta. |
| `PLT-003` | 2026-06-11 | CIM persistence | Converge `GenericWindow` category-position persistence onto `BETTERUI.CIM.PositionManager` | Low | Medium | P3 | Open | Engineer review (MPR-1). Two parallel persistence systems with divergent restore fidelity (`CIM/Core/Window/GenericWindow.lua` index-only vs `CIM/Core/Data/PositionManager.lua` uniqueId-aware). |
| `PLT-004` | 2026-06-11 | CIM consolidation | Migrate the remaining medium/high-risk cross-module duplication clusters into shared CIM seams | Medium | High | P3 | Open | CIM consolidation discovery (2026-06-11); low-risk clusters (header-sort comparators, ResolveStackCount/HasItemAtSlot, PositionSearchControl, multi-select keybind labels, settings-panel scaffolding) were consolidated directly. Remaining clusters need behavioral care: (1) search lifecycle wiring (Banking/Inventory/Vendor/TH each re-implement query plumbing around `CIM/Core/Data/SearchManager`); (2) list row setup (`Banking/Lists/BankRowSetup.lua` vs `TradingHouse` row setup vs `Inventory/Lists/InventoryList.lua` template registration); (3) shared entry functions currently living in module files but consumed cross-module; (4) Banking deposit predicates vs Inventory equivalents; (5) tooltip layout helpers duplicated between `GeneralInterface/Tooltips` and module tooltips; (6) batch move-op factory (Banking transfer vs Inventory move vs Vendor sell batch step builders in `CIM/Core/Batching`); (7) scene lifecycle latches (show/hide/activate ordering repeated per module). |

## HUD and Frames

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `HUD-001` | 2026-04-10 | Resource orbs / action bar | Allow moving resource orbs independently from the action bar (at minimum, independent orb offsets) | High | High | P2 | **Completed** | ESOUI comments (Loliam 04/10/26, Vo1se 05/10/26). Orbs and bars are currently anchored as one frame group (`Modules/ResourceOrbFrames`, `PositionManager.lua`); author previously replied "whole UI frames move together". Requested repeatedly. |
| `HUD-002` | 2026-06-11 | Resource orbs | Decide FoodBuffTracker: implement food-buff tracking or remove the stub | Low | Medium | P3 | Open | Engineer review (MPR-1). `Core/OrbBarUpdates.lua` FoodBuffTracker always reports 0 and the FoodBar XML control ships placeholder values (`Templates/ResourceOrbFrames.xml`). |
| `HUD-003` | 2026-06-11 | Nameplates fonts | Consume `FontLocalization.WESTERN_ONLY_FONTS` in Nameplates instead of its local duplicate list | Low | Low | P3 | Open | Engineer review (MPR-1). CIM copies were deduplicated 2026-06-11; `Modules/Nameplates/Nameplates.lua` still owns a private copy. |

_Open feature-request inventory cleared on 2026-04-16 per product decision. Historical closed items remain below._

## Closed

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-000` | 2026-02-08 | Inventory/Banking | Expose stack consolidation (`Stack All`) in keybind flows | High | Low | `Closed` | Closed | Implemented in Inventory and Banking keybind managers. |

## Recommended Implementation Order

1. `ECO-001` Archival Fortunes currency display (low effort, isolated).
2. `TRC-001` TTC/market prices on crafting and improvement pages.
3. `HUD-001` Independent orb/action-bar positioning (high effort; needs anchoring redesign).
