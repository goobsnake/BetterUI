# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-09
> **Provenance:** [TOOL] Continuity optimization pass applied (concise receipts retained at 12 entries, `Done` retention cap aligned to 12) while preserving Banking multi-select remediation context (`9948ca645643407d30acb1e3fe689ef83a2d4961`, `c38d0e6e6f41d8766068df783da112b85d685c19`)

**Reference:** For ESO API quirks, patterns, and lessons learned see [TRIBAL_KNOWLEDGE.md](TRIBAL_KNOWLEDGE.md).

---

## Snapshot (≤25 lines)

**Goal:** Maintain high-quality ESO addon with gamepad-first UI modernization

**Success Criteria:**
- All modules follow CIM patterns
- Consistent gamepad navigation across scenes
- Clean code with comprehensive documentation
- No regressions in existing functionality

**Invariants:**
- Never modify `esoui/` reference folder
- All code must load without errors in-game
- Follow `betterui-development-guidelines` for all changes
- Shared code goes in `Modules/CIM/`, never new "Shared" folders

---

## State

**Done (recent ≤12):**
- [2026-02-09] [CODE] Banking multi-select review/fix pass completed: fixed unreachable entry path in `Modules/Banking/Keybinds/KeybindManager.lua` (Y-hold now works even before manager init), hardened `Modules/CIM/Core/MultiSelectMixin.lua` target resolution (`GetSelectedData` fallback), and revalidated with `luac -p` + `lua tools/tests/run_all_tests.lua` (9/9 PASS)
- [2026-02-09] [CODE] Added centralized settings metadata registry in `Modules/CIM/Core/SettingsFactory.lua` (schema includes label/tooltip/default/dependency/sortGroup/resetGroup) and replaced duplicated top-level submenu sorting helpers with shared utilities to reduce drift
- [2026-02-09] [CODE] `IconSettingsFactory` now fully localized: removed remaining hardcoded English names/tooltips/submenu copy; wired icon labels/defaults through metadata registry and added localized keys across `lang/en/de/es/fr/jp/ru/zh.lua`
- [2026-02-09] [CODE] General Interface `Market Price Integration` now includes configurable source order dropdown (`marketPricePriority`), with `MarketIntegration.lua` honoring selected provider order for `BETTERUI.GetMarketPrice`; defaults/migration added in `DefaultsRegistry` + `RuntimeSetup`
- [2026-02-09] [CODE] Disabled integration controls now append explicit localized addon-missing reason text in tooltips (`SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP`) and TTC disabled rows now also render `OFF` when addon is unavailable
- [2026-02-09] [CODE] Added user-facing feedback when currency visibility cap blocks enable action (`SI_BETTERUI_CURRENCY_ENABLE_LIMIT_WARNING`) via chat warning + negative click sound in `CurrencySettings.lua`
- [2026-02-09] [CODE] Layout/label follow-up: Inventory+Banking font reset labels now use requested wording (`Reset Name Font Settings`, `Reset Other Font Settings`), Currency submenu now opts out of recursive alphabetical sorting to preserve paired visibility/order row layout, Currency reset text shortened to `Reset Currency Settings`, Resource Orb Frames offset label updated to `Offset (Up/Down)`, and settings sorter now supports `sortAlwaysLast` (applied to `Use Custom Textures` so it remains bottom in General)

**Now:**
- Commit-scope Banking multi-select review is complete for `9948ca6` and `c38d0e6`; critical entry-path regression fixed, CIM extraction verified, and locale-key coverage validated across `lang/en,de,es,fr,jp,ru,zh.lua`

**Next:**
- In-game validation pass for Banking multi-select UX: Y-hold entry, A-toggle select/deselect, Y batch menu actions, back-to-exit behavior, and Withdraw/Deposit mode switch teardown while selections are active

---

## Decisions

| ID | Status | Date | Decision |
|----|--------|------|----------|
| D001 | ACTIVE | 2026-02-06 | Two-file approach: CONTINUITY.md for session state, TRIBAL_KNOWLEDGE.md for permanent learnings |

---

## Open Questions

(None currently)

---

## Working Set (≤12 paths)

- `docs/CONTINUITY.md`
- `Modules/Banking/Keybinds/KeybindManager.lua`
- `Modules/CIM/Core/MultiSelectMixin.lua`
- `Modules/Banking/Core/BankingClass.lua`
- `Modules/Banking/Core/MultiSelectActions.lua`
- `Modules/Inventory/Core/InventoryClass.lua`
- `BetterUI.txt`
- `lang/*.lua`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-09 | [TOOL] | Banking multi-select repair review completed for `9948ca6` + `c38d0e6` (entry-path fix, multi-select target fallback, `luac -p`, tests 9/9 PASS, locale key parity verified) |
| 2026-02-09 | [TOOL] | Wrap-up gate PASS: clean status, sr-review-gate PASS, tests 9/9 PASS, debug scan clean, Lua syntax clean, locale parity clean (`lang/en,de,es,fr,jp,ru,zh.lua`) |
| 2026-02-09 | [CODE] | Settings consistency hardening: aligned defaults/resets, strict integer editbox parsing, and nil-safe settings callbacks across affected modules (`luac -p` validated) |
| 2026-02-09 | [CODE] | Resource Orb General reset scope corrected in `Modules/ResourceOrbFrames/Module.lua` to only `scale`, `offsetY`, and `useCustomTextures` (`luac -p`) |
| 2026-02-09 | [CODE] | Naming/layout pass: `disableAutoSort` for Inventory Currency, `sortAlwaysLast` for `Use Custom Textures`, and requested EN label updates (`luac -p`) |
| 2026-02-09 | [CODE] | Reset UX/stability pass: icon submenu reset wiring, scene-gated refresh helpers, and reset label localization updates across all locales (`luac -p`) |
| 2026-02-09 | [CODE] | Regression fixes: Inventory reset crash, `sortAlwaysFirst` dependency ordering, Nameplates button width, and Market/Tooltips reset defaults + locale keys (`luac -p`) |
| 2026-02-09 | [CODE] | UI/text follow-up: explicit submenu reset labels, orb reset locale keys, grouped orb headers, and master toggle ordering improvements (`luac -p`) |
| 2026-02-09 | [CODE] | Settings platform updates: metadata registry, market source priority, addon-missing tooltip reasons, currency-cap warning feedback, and top-level General resets (`luac -p`) |
| 2026-02-09 | [CODE] | Sorting/label cleanup: Nameplates size label order fix, ATT/MM OFF rendering behavior fix, shared sorter adoption, module-toggle sorting, and mail-label truncation fix |
| 2026-02-08 | [CODE] | Milestone (compressed): Inventory/Banking icon customization rollout and runtime icon behavior corrections completed; see 2026-02-08 commits for details |
| 2026-02-08 | [CODE] | Milestone (compressed): LAM parity + dev-flag cleanup complete; feature request audits updated (#13 restored/reprioritized, #20 expanded with esoui references) |

