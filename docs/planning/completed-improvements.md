# Completed Improvements

## [Completed] MPR-2 Engineer-Review Remediation (2026-06-12)
**Summary**: Full-codebase engineer review (all ~383 Lua files) with adversarial finding validation, then routed remediation of all confirmed P0–P3 issues. Resolved the open P1/P2 backlog — PB-002 (Actions-dialog single-item "Mark as Junk" no longer kills LB/RB carousel paging: deferred keybind restoration to the post-dialog OnFinish path so the dialog's pushed keybind-state snapshot is not corrupted before Pop), PB-003 (disabling tooltip enhancements restores stock layout/fonts in-session by gating the per-layout PostHook and fully reversing fonts/anchors), PB-004 (enhanced tooltips re-add the set-collection Collected/Uncollected/Reconstructed tag), PB-005 (inventory pooled control names kept under the 63-char engine limit via `BETTERUI_GamepadInventoryTopLevel`→`BUI_GpInv` rename + category pool prefix), PB-006 (primary action re-resolves on in-place slot updates after container open). New confirmed fixes: PB-008 vendor batch "Buy All" excludes locked/ineligible entries; PB-010 batch sell/fence/launder/junk/lock re-validate slot identity at execution via the new shared `BETTERUI.CIM.Utils.CaptureSlotIdentity`/`IsSlotIdentityCurrent`; PB-009 Trading House Sell tab uses the engine authority `IsItemSellableOnTradingHouse` + `CanSellOnTradingHouse` guild gate; ORB-001 `GetSlotAbilityCost` ultimate-cost argument order. P3 hardening: TH off-scene guild-change `IsSceneShowing` guard, create-listing price-slider fine-step, SearchPresets version-stamp + SafeExecute, Companions destroy-eligibility `slotType`, ProtectionPolicy nil-slotType contract note, UnifiedScreen stale-reference fix, vendor skipped-step pacing + alt-currency icon. Cleanups: removed dead `VendorEventBridge.UnregisterCollectionUpdated`, the FoodBuffTracker stub + FoodBar control (HUD-002), and the Companions `CONFIRM_EQUIP_BOE` probe; HUD-003 Nameplates now consumes the canonical CIM Western-only font list. Adversarially refuted and dropped 11 false-positive findings (all 5 Banking flags, ORB-002, GEN-001, two CIM settings/contract claims, SafeExecute `ZO_Alert`). PLT-001 (file splits) and PLT-002 (locale backfill) reviewed and deferred with rationale (see feature-requests). All 165 test files green via `test_validate(lua_run, tools/tests/run_all_tests.lua)`.
**Source Issue/Phase**: MPR-2 deep engineer-review — PB-002, PB-003, PB-004, PB-005, PB-006, HUD-002, HUD-003 + new PB-008/PB-009/PB-010/ORB-001 findings
**Related Files/Tests**: CIM (`Core/Utilities.lua`, `Core/Batching/BatchActions.lua`, `MultiSelectManager.lua`, `Actions/ProtectionPolicy.lua`, `Core/Window/UnifiedScreen.lua`, `Core/Data/Types.lua`); Inventory (`Actions/ItemActionHandlers.lua`, `Core/HeaderManager.lua`, `Core/Utils.lua`, `Inventory.lua`, `Lists/CategoryListManager.lua`, `Module.lua`, `Templates/GamepadInventory.xml`, `UI/TooltipEquipped.lua`, `UI/TooltipUtils.lua`); GeneralInterface (`Tooltips/Tooltips.lua`, `Tooltips/Settings.lua`); Vendor (`Core/List/BatchActionCounts.lua`, `Core/VendorBatchRuntime.lua`, `Components/SellComponent.lua`, `Core/List/VendorRowSetup.lua`, `Core/Lifecycle/VendorEventBridge.lua`); TradingHouse (`Components/SellComponent.lua`, `Core/TradingHouseRuntimeFlow.lua`, `Core/SearchPresets.lua`); Companions (`Core/CompanionItemList.lua`, `Actions/CompanionActions.lua`); ResourceOrbFrames (`SkillBar/UltimateManager.lua`, `FrontBarManager.lua`, `FrontBarPressFeedback.lua`, `Core/OrbBars.lua`, `OrbBarUpdates.lua`, `ResourceOrbFrames.lua`, `Templates/ResourceOrbFrames.xml`, `LayoutTemplates.xml`); Nameplates (`Nameplates.lua`); `.luarc.json`; docs (`changelog.txt`, `tribal-knowledge.md`, `architecture.md`, `testing-guide.md`); new tests (`test_inventory_junk_carousel_keybinds`, `test_inventory_primary_action_inplace_update`, `test_inventory_control_name_length`, `test_trading_house_sell_filter`) + extended (`test_batch_safety`, `test_inventory_destroy_policy`, `test_tooltip_helpers`, `test_trading_house_callbacks`, `test_trading_house_search_presets`, `test_vendor_batch_action_counts`, `test_vendor_batching_parallel_contract`, `test_front_bar_manager`, `test_companion_actions_source`, `test_companions_runtime_source`, `test_nameplates_reset`, + load-order fixes).

## [Completed] ECO-002 Vendor Phase 1 Closeout (2026-04-16)
**Summary**: Closed the remaining vendor phase 1 backlog by finishing stable riding-training progress bars and adding SellVengeance support. Stable training rows now use a dedicated BetterUI template with inline progress bars, and the vendor scene now exposes a BetterUI Sell Vengeance tab backed by `BAG_VENGEANCE` when the Vengeance ruleset and sell flag are active.
**Source Issue/Phase**: ECO-002 Vendor phase 1 (`VND-002`, `VND-003`)
**Related Files/Tests**: `Modules/CIM/Constants.lua`, `Modules/CIM/Templates/SharedTemplates.xml`, `Modules/Vendor/Core/BatchActionCounts.lua`, `Modules/Vendor/Core/VendorClass.lua`, `Modules/Vendor/Core/VendorRowSetup.lua`, `Modules/Vendor/Components/SellVengeanceComponent.lua`, `Modules/Vendor/Vendor.lua`, `lang/en.lua`, `BetterUI.txt`, `tools/tests/test_vendor_sell_vengeance_source.lua`, `tools/tests/test_vendor_stable_progress_source.lua`, `tools/tests/test_vendor_stable_transition.lua`, `tools/tests/test_vendor_stable_icons.lua`, `tools/tests/test_vendor_tabs.lua`

## [Completed] March 14 Completion Audit + Feature Gap Fixes (2026-04-11)
**Summary**: Audited all March 14, 2026 completion claims against actual codebase. Identified 5 partially-implemented features and 2 missing planning docs. Fixed all gaps: integrated StatComparison into Banking and Companion surfaces (INV-001 parity), added narration registration for Vendor and TradingHouse scenes (ACC-001 parity), implemented Trading House search presets (TH-001), documented ORB_CONFIG table, and removed dead planning doc references (continuity-ledger.md, console-readiness.md). PLT-001 console readiness postponed.
**Source Issue/Phase**: Post-completion audit of March 14 items
**Related Files/Tests**: `Modules/Inventory/Core/StatComparison.lua` (equipBagId param), `Modules/Banking/Lists/BankRowSetup.lua` (stat comparison), `Modules/Companions/Core/CompanionItemList.lua` (stat comparison), `Modules/Vendor/Vendor.lua` (narration), `Modules/TradingHouse/TradingHouse.lua` (narration + preset keybinds), `Modules/TradingHouse/Components/SearchPresets.lua` (new), `Modules/TradingHouse/Module.lua` (searchPresets default), `Modules/ResourceOrbFrames/Core/OrbVisuals.lua` (ORB_CONFIG docs), `docs/README.md`, `docs/planning/completed-improvements.md`, `BetterUI.txt`

## [Completed] Second-Pass Audit Closeout + Language Maintenance Fix (2026-03-28)
**Summary**: Performed requested second-pass deep verification and fixed additional misses: scene lifecycle task-manager routing/cancellation for Banking and Inventory, stale CIM template icon path, and strict-mode PowerShell `$Matches` collision in localization maintenance tooling.
**Source Issue/Phase**: Post-refactor follow-up audit pass
**Related Files/Tests**: `Modules/Banking/Banking.lua`, `Modules/CIM/Core/Window/WindowClass.lua`, `Modules/Inventory/Scene/InventorySceneLifecycle.lua`, `Modules/CIM/Templates/SharedTemplates.xml`, `Modules/ResourceOrbFrames/Core/OrbEvents.lua`, `tools/LanguageMaintenance.ps1`, `luacheck BetterUI.lua Modules lang tools/tests`, `lua tools/tests/run_all_tests.lua`, `mcp_test-runner_test_validate(luac_syntax)`, `pwsh -File tools/LanguageMaintenance.ps1 -Mode Audit`

## [Completed] Refactor Audit + Manifest Integrity Pass (2026-03-28)
**Summary**: Completed deep post-refactor audit from `99ac62a41af2d1e176ced6a5a221f5ab190192fd` to `HEAD`; validated Lua syntax and XML structure, verified manifest coverage/order, and fixed manifest/quality issues discovered during audit.
**Source Issue/Phase**: Post-refactor verification sweep
**Related Files/Tests**: `BetterUI.txt`, `Modules/GeneralInterface/Tooltips/Tooltips.lua`, `Modules/Inventory/Module.lua`, `Modules/ResourceOrbFrames/ResourceOrbFrames.lua`, `docs/publishing/changelog.txt`, `luacheck BetterUI.lua Modules lang tools/tests`, `lua tools/tests/run_all_tests.lua`, `mcp_test-runner_test_validate(luac_syntax)`

## [Completed] Guild Bank Validation and Commit (2026-03-14)
**Summary**: Implemented comprehensive Guild Bank support via UI reuse. Fixed deposit restriction missing check for player-locked items and matched `TransferToGuildBank`/`TransferFromGuildBank` exact argument signatures.
**Source Issue/Phase**: Guild Bank Integration
**Related Files/Tests**: `TransferActions.lua`, `GuildBankAdapter.lua`, `MultiSelectActions.lua`, `BankListManager.lua`, `KeybindManager.lua`

## March 14, 2026

- `BUI-P1-001` / `project-improvements.md` - Complete multi-select anti-spam hardening rollout (Phases 0-5)
- `BUI-P1-002` / `ACC-001` - Finish gamepad narration parity for BetterUI custom surfaces
- `BUI-P1-003` / `INV-003` - Restore reliable "New Item" lifecycle and clear behavior in inventory flows
- `BUI-P1-004` / `BNK-001` - Define and begin guild-bank integration path for BetterUI Banking
- `INV-001` - Item stat comparison parity across Inventory, Banking, and Companion item surfaces
- `INV-004` - Companion equipment management workspace with comparison and slot views
- `ECO-002` - Vendor/store enhancements (sorting, price context, batch junk sell UX)
- `TH-001` - Guild store/trading house overhaul with stronger search, presets, and unit-price ergonomics
- XML Template Audit - `[Modules/CIM/ConstantsUI.lua]`
- v3.2 Compat Removal - `[Modules/CIM/ConstantsUI.lua]`
- EmmyLua Typing - `[Modules/CIM/Core/Utilities.lua]`
- Config Documentation - `[Modules/ResourceOrbFrames/Core/OrbVisuals.lua]`
- Tribal Knowledge Gotchas - `[docs/reference/tribal-knowledge.md]`
- `TODO-09` Bar Constants Refactoring - Migrated 30+ global bar constants to `BETTERUI.ResourceOrbFrames.CONST.BARS` namespace, cleaned stale `.luarc.json` entries
- `DeveloperDebug.lua` Split - Split from 627 lines to 114 lines by extracting BatchConfig, BatchOverlay, and BatchActions helpers
- Anti-Spam Implementation Plan - All 15 items verified complete (re-entry guard, pipeline token, weighted cost, adaptive delay, jitter, rate limiting, chunk cooldowns, post-batch cooldown, destination slot)
- Batch Safety Test Coverage - `test_batch_safety.lua` covering re-entry guard, pipeline token invalidation, and adaptive backoff


## [Completed] Comment Feedback Implementation Plan — All Phases (2026-06-10)
**Summary**: Implemented all four phases from `docs/planning/comment-feedback-implementation-plan.md`:

- **PB-007** — Vault deposit busy-state keybind: Added `_pendingTransfers` table with 5s timeout, `MarkTransferPending`/`ClearTransferPending`/`IsTransferPending`/`SweepStaleTransfers`, and `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` auto-clear. Deposit keybind now disables while a transfer is in-flight for the selected slot.
- **ECO-001** — Archival Fortunes currency display: Added 13th currency entry to `CURRENCY_DATA`, `CurrencyManager.DEFS`, all four `CURRENCY_PRESETS`, order clamp (12→13), `POS_13` choices, and guarded with `rawget(_G, "CURT_ARCHIVAL_FORTUNES")` for API safety.
- **TRC-001** — Market prices on crafting/improvement tooltips: Created `CraftingPriceTooltip.lua` with `ZO_PostHook` for `LayoutPendingSmithingItem` and `LayoutImproveResultSmithingItem`; reuses `MarketIntegration.GetMarketPriceInfo`; gated by `showCraftingMarketPrice` setting (default on).
- **HUD-001** — Independent orb positioning: Added `enableIndependentOrbOffset`, `orbOffsetX`, `orbOffsetY` to ResourceOrbFrames defaults; modified `UpdateOrbLayout` to apply offsets to left/right orb anchors in all branches; added LAM checkbox + X/Y sliders.

**Source Issue/Phase**: `docs/planning/comment-feedback-implementation-plan.md` (Phases 1–4)
**Related Files/Tests**:
- PB-007: `Modules/Banking/Actions/TransferActions.lua`, `Modules/Banking/Keybinds/KeybindManager.lua`, `tools/tests/test_banking_transfer_actions.lua`
- ECO-001: `Modules/Inventory/Settings/CurrencySettings.lua`, `Modules/CIM/UI/CurrencyManager.lua`, `Modules/CIM/Constants.lua`, `lang/*.lua`
- TRC-001: `Modules/GeneralInterface/Tooltips/CraftingPriceTooltip.lua`, `Modules/GeneralInterface/Tooltips/Settings.lua`, `Modules/CIM/Core/Settings/DefaultsRegistry.lua`, `Modules/CIM/Core/Settings/SettingsMetadata.lua`, `BetterUI.txt`, `lang/*.lua`, `tools/tests/test_crafting_price_tooltip.lua`
- HUD-001: `Modules/ResourceOrbFrames/Core/OrbVisuals.lua`, `Modules/ResourceOrbFrames/Module.lua`, `Modules/ResourceOrbFrames/Settings/Defaults.lua`, `lang/*.lua`, `tools/tests/test_orb_independent_positioning.lua`
