# Completed Improvements

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

