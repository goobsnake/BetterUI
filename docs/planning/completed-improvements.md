# Completed Improvements

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
- `INV-002` - Quickslot management hub (radial/list hybrid) with loadout maintenance
- `INV-004` - Companion equipment management workspace with comparison and slot views
- `ECO-001` - Enhanced gamepad loot window with BetterUI styling and market metadata
- `ECO-002` - Vendor/store enhancements (sorting, price context, batch junk sell UX)
- `MNT-001` - Unified repair + soul-gem maintenance hub with urgency surfacing
- `TH-001` - Guild store/trading house overhaul with stronger search, presets, and unit-price ergonomics
- `CFT-001` - Crafting station UI enhancements with research-aware and value-aware guidance
- `MAIL-001` - Better mail inbox/attachments UX with bulk flows and clearer COD handling
- `COL-001` - Collections/outfit browser improvements with filtering, favorites, and progress clarity
- `PLT-001` - Console add-on support and mod-browser readiness track (planning doc only)
- XML Template Audit - `[Modules/CIM/ConstantsUI.lua]`
- v3.2 Compat Removal - `[Modules/CIM/ConstantsUI.lua]`
- EmmyLua Typing - `[Modules/CIM/Core/Utilities.lua]`
- Config Documentation - `[Modules/ResourceOrbFrames/Core/OrbVisuals.lua]`
- Tribal Knowledge Gotchas - `[docs/reference/tribal-knowledge.md]`
- `TODO-09` Bar Constants Refactoring - Migrated 30+ global bar constants to `BETTERUI.ResourceOrbFrames.CONST.BARS` namespace, cleaned stale `.luarc.json` entries
- `DeveloperDebug.lua` Split - Split from 627 lines to 114 lines by extracting BatchConfig, BatchOverlay, and BatchActions helpers
- Anti-Spam Implementation Plan - All 15 items verified complete (re-entry guard, pipeline token, weighted cost, adaptive delay, jitter, rate limiting, chunk cooldowns, post-batch cooldown, destination slot)
- Batch Safety Test Coverage - `test_batch_safety.lua` covering re-entry guard, pipeline token invalidation, and adaptive backoff
- Session Continuity Ledger - `continuity-ledger.md` operating procedures codified into project workflow
- Console Readiness Planning - `console-readiness.md` requirements checklist documented for future PLT-001 execution
