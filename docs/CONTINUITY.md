# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-11
> **Provenance:** [CODE] ResourceOrbFrames placement correction restored XP/mount bars to default-height presentation and repositioned them below ornaments and closer to screen edges

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
- [2026-02-11] [CODE] Resource Orb Frames placement correction: restored XP and mount bar heights to default-scale presentation (`BETTERUI_XP_BAR_HEIGHT 150`, `BETTERUI_MOUNT_STAMINA_BAR_HEIGHT 150`), moved visible-mode bars below ornaments (`BETTERUI_XP_BAR_OFFSET_Y 12`, `BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y 12`), and pushed bars outward toward edges (`BETTERUI_XP_BAR_OFFSET_X -90`, `BETTERUI_MOUNT_STAMINA_BAR_OFFSET_X 90`)
- [2026-02-11] [CODE] Resource Orb Frames follow-up tuning: raised mount bar toward ornament (`BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y -55 -> -85`), expanded XP/mount fill regions + slightly raised label anchors inside each bar window (`BETTERUI_XP_BAR_FILL_REGION`, `BETTERUI_MOUNT_STAMINA_BAR_FILL_REGION`, label Y `-1`), and increased ornament-visible orb border scale (`visibleScale 0.75 -> 0.80`) to better fill ornament sockets
- [2026-02-11] [CODE] Resource Orb Frames bar-layout refresh: ornaments increased by ~10% (`left 293`, `right 309`), XP/Cast/Mount bar dimensions + anchor offsets updated for current art (`55/62/62` heights; visible-mode offsets `-52 / 89 / -55`), and `Modules/ResourceOrbFrames/Core/OrbBars.lua` now applies per-bar texture crop bounds + fill regions + fill-centered label anchors (`BETTERUI_*_BAR_TEXTURE_BOUNDS`, `BETTERUI_*_BAR_FILL_REGION`) so frame/fill/text align with the new DDS assets
- [2026-02-11] [CODE] Resource Orb Frames ornament fit follow-up: ornament sizes reduced by ~25% (`left 266`, `right 281`) and `Modules/ResourceOrbFrames/Core/OrbVisuals.lua` now scales ornament-visible orb border size/anchor offsets/fill offsets/splitter offsets (plus orb label offsets) via `visibleScale`, keeping `OrbBorder.dds` aligned within ornament sockets while preserving hidden-ornament sizing behavior
- [2026-02-11] [CODE] Resource Orb Frames graphics alignment pass: `Modules/ResourceOrbFrames/Core/OrbBars.lua` now uses per-bar backdrop textures (`Bar.dds` for XP, `CastBar.dds` for cast, `MountBar.dds` for mount), and `Modules/ResourceOrbFrames/Constants.lua` ornament defaults were tuned (smaller + raised) to reduce bottom clipping with the updated ornament art
- [2026-02-10] [CODE] `tools/ConvertPngToDds.ps1` `ResourceOrbFrames` profile now enforces required logical filenames + source dimensions that are power-of-two or multiples-of-4 (instead of exact canvas matches), warns on non-default sizes, deterministically resolves duplicate logical-name sources, and validates output dimensions while blocking unexpected size changes unless `-ResizePow2` is used
- [2026-02-09] [CODE] Resource Orb Frames custom-texture workflow hardened: `Modules/ResourceOrbFrames/Core/OrbVisuals.lua` now applies custom `Shield.dds` at runtime, `tools/ConvertPngToDds.ps1` gained `-Profile ResourceOrbFrames` (required filename + exact size enforcement + post-convert size checks), and `Modules/ResourceOrbFrames/CustomTextures/README.md` was expanded with AI-ready generation contract, layer diagrams, and OrbBorder glass-lens transparency requirements
- [2026-02-09] [CODE] Banking multi-select review/fix pass completed: fixed unreachable entry path in `Modules/Banking/Keybinds/KeybindManager.lua` (Y-hold now works even before manager init), hardened `Modules/CIM/Core/MultiSelectMixin.lua` target resolution (`GetSelectedData` fallback), and revalidated with `luac -p` + `lua tools/tests/run_all_tests.lua` (9/9 PASS)
- [2026-02-09] [CODE] Added centralized settings metadata registry in `Modules/CIM/Core/SettingsFactory.lua` (schema includes label/tooltip/default/dependency/sortGroup/resetGroup) and replaced duplicated top-level submenu sorting helpers with shared utilities to reduce drift
- [2026-02-09] [CODE] `IconSettingsFactory` now fully localized: removed remaining hardcoded English names/tooltips/submenu copy; wired icon labels/defaults through metadata registry and added localized keys across `lang/en/de/es/fr/jp/ru/zh.lua`
- [2026-02-09] [CODE] General Interface `Market Price Integration` now includes configurable source order dropdown (`marketPricePriority`), with `MarketIntegration.lua` honoring selected provider order for `BETTERUI.GetMarketPrice`; defaults/migration added in `DefaultsRegistry` + `RuntimeSetup`
- [2026-02-09] [CODE] Disabled integration controls now append explicit localized addon-missing reason text in tooltips (`SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP`) and TTC disabled rows now also render `OFF` when addon is unavailable
- [2026-02-09] [CODE] Added user-facing feedback when currency visibility cap blocks enable action (`SI_BETTERUI_CURRENCY_ENABLE_LIMIT_WARNING`) via chat warning + negative click sound in `CurrencySettings.lua`
- [2026-02-09] [CODE] Layout/label follow-up: Inventory+Banking font reset labels now use requested wording (`Reset Name Font Settings`, `Reset Other Font Settings`), Currency submenu now opts out of recursive alphabetical sorting to preserve paired visibility/order row layout, Currency reset text shortened to `Reset Currency Settings`, Resource Orb Frames offset label updated to `Offset (Up/Down)`, and settings sorter now supports `sortAlwaysLast` (applied to `Use Custom Textures` so it remains bottom in General)

**Now:**
- Resource Orb Frames runtime now places XP/mount bars below ornaments with outward edge bias and default-height presentation; pending screenshot validation for final pixel-level offsets

**Next:**
- In-game validation for Resource Orb Frames new art set: confirm XP/mount bars are no longer visually shrunk and sit under ornaments near screen edges; then tune only small offset deltas if needed

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
- `Modules/ResourceOrbFrames/Core/OrbBars.lua`
- `Modules/ResourceOrbFrames/Core/OrbVisuals.lua`
- `Modules/ResourceOrbFrames/CustomTextures/README.md`
- `Modules/ResourceOrbFrames/Templates/ResourceOrbFrames.xml`
- `Modules/ResourceOrbFrames/Constants.lua`
- `tools/ConvertPngToDds.ps1`
- `tools/README.md`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-11 | [TOOL] | Placement-correction validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after XP/mount height + visible-mode anchor corrections |
| 2026-02-11 | [TOOL] | Follow-up tuning validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after mount offset direction fix + XP/mount fill-region/label updates + orb visibleScale increase |
| 2026-02-11 | [TOOL] | Bar-geometry refresh validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after per-bar texture bounds/fill-region wiring |
| 2026-02-11 | [TOOL] | Ornament-fit follow-up validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after adding ornament-visible orb scaling |
| 2026-02-11 | [TOOL] | Graphics alignment validation: `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after wiring cast/mount-specific bar backdrops + ornament position/size tuning |
| 2026-02-10 | [TOOL] | Updated converter profile checks to power-of-two-or-multiple-of-4 + deterministic duplicate selection; PowerShell parser check PASS for `tools/ConvertPngToDds.ps1`; README contract updated to match behavior |
| 2026-02-09 | [TOOL] | ROF custom-texture profile smoke test PASS via `tools/ConvertPngToDds.ps1 -Profile ResourceOrbFrames` against shipped textures (10/10 converted); `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` and PowerShell parse check for converter both PASS |
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

