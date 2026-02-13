# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-12
> **Provenance:** [CODE] Multi-select audit hardening now normalizes/filters stale slot targets before batch execution, re-validates item support immediately before each secure action call, suppresses unsupported transfer targets (stolen/furniture-vault-gemmable) from banking/inventory batch transfer flows, and routes batch destroy through the shared throttled runner to reduce redundant server-bound attempts

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
- [2026-02-12] [CODE] Multi-select throttle + action-validity hardening pass: `Modules/CIM/Constants.lua` keeps simplified base tiers (`0-9 => 75ms/silent`, `10-49 => 100ms/progress`, `50+ => 125ms/progress`) with server-bound cooldown (`20 items / 500ms`), while `Modules/CIM/Core/MultiSelectMixin.lua` now normalizes/deduplicates batch slot targets, drops stale/empty slots before scheduling, and re-validates lock/junk eligibility at execution time to avoid redundant `SetItemIsPlayerLocked`/`SetItemIsJunk` calls; `Modules/Banking/Core/MultiSelectActions.lua` now filters unsupported deposit items (stolen, furniture-vault gemmable), computes transfer menu counts from truly transferable items, and only issues `RequestMoveItem` when destination capacity/compatibility exists; `Modules/Inventory/Core/InventoryClass.lua` now hardens retrieve/stow/deposit/destroy batch paths with prefilter + runtime slot checks and routes batch destroy through `ProcessBatchThrottled` so destroy runs share cooldown pacing and abort/keybind safeguards
- [2026-02-12] [CODE] Resource Orb Frames combat-icon anchor/pulse hardening pass: `Modules/ResourceOrbFrames/Core/OrbEvents.lua` now resolves quickslot/icon controls via ROF-owned parent/global-name paths only (no generic global-name fallback), preventing accidental binding to unrelated UI controls after quickslot reparenting; icon anchoring still falls back to deterministic quickslot geometry anchored to `BgMiddle` when needed and continues to apply red pulse/tint (`BETTERUI_COMBAT_ICON_TINT_*`, `BETTERUI_COMBAT_ICON_PULSE_*`) only while icon rendering is active; `Modules/ResourceOrbFrames/Constants.lua` defaults `BETTERUI_COMBAT_ICON_TEXTURE` to an `esoui`-referenced crossed-swords icon (`EsoUI/Art/LFG/LFG_icon_dps.dds`)
- [2026-02-12] [CODE] Resource Orb Frames combat-indicator layering/alignment pass: `Modules/ResourceOrbFrames/Core/OrbEvents.lua` now applies combat glow through each visible front-bar button `Glow` control (`Button1-5`, `UltimateButton`, `QuickslotButton`, `CompanionButton`) with per-control timelines, explicitly hides legacy stretched `FrontBarContainer.CombatGlow`, keeps glow beneath keybind glyph/text strata (`DL_CONTROLS`/`DT_MEDIUM`/level `5`), and forces combat icon draw order (`DL_OVERLAY`/`DT_HIGH`/level `40`) after applying `BETTERUI_COMBAT_ICON_*` placement constants so indicators render in the expected z-order while tracking skill-bar layout updates
- [2026-02-12] [CODE] Resource Orb Frames combat indicators runtime pass: `Modules/ResourceOrbFrames/Core/OrbEvents.lua` now wires `EVENT_PLAYER_COMBAT_STATE`/dead/alive/activated to live `CombatGlow` + `CombatIcon` visibility updates (including glow timeline and optional audio cue), exposes `SetupCombatIndicators` + `RefreshCombatIndicators` for explicit lifecycle hooks, and applies combat-icon anchor/dimensions from new constants (`BETTERUI_COMBAT_ICON_*`) in `Modules/ResourceOrbFrames/Constants.lua`; `Modules/ResourceOrbFrames/ResourceOrbFrames.lua` now invokes those hooks during setup, forced layout updates, player activation refresh, initialization completion, and `ApplySettings` so enabled indicators appear immediately and stay aligned with scaled UI/layout changes
- [2026-02-12] [CODE] Numeric settings clamping audit/hardening pass: added shared font slider bounds + normalizers in `Modules/CIM/Core/FontDefinitions.lua`, wired those bounds into `Modules/CIM/Core/SettingsFactory.lua` and `Modules/Inventory/Settings/FontSettings.lua`, and now normalize persisted font sizes in `Modules/Banking/Module.lua` + `Modules/Inventory/Settings/SettingsPanel.lua`; `Modules/ResourceOrbFrames/Settings/Defaults.lua` now clamps persisted `scale`, `offsetY`, back-bar opacity, left/right orb size, orb text sizes, and bar/skill text sizes to current slider caps on `InitModule`; `Modules/CIM/Module.lua` now clamps persisted `triggerSpeed`, `rhScrollSpeed`, and `tooltipSize` to editbox/slider bounds; `Modules/CIM/Nameplates/Settings.lua` now clamps persisted nameplate `size` to slider bounds
- [2026-02-12] [CODE] Resource Orb Frames text-size + text-anchor constants pass: `Modules/ResourceOrbFrames/Constants.lua` now declares quickslot count and ultimate number text positioning constants (`BETTERUI_QUICKSLOT_COUNT_TEXT_*`, `BETTERUI_ULTIMATE_NUMBER_TEXT_*`), `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now anchors quickslot count labels using those constants, `Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua` now applies ultimate-number anchor/dimensions from constants, and `Modules/ResourceOrbFrames/Settings/Defaults.lua` now normalizes persisted text sizes to active slider bounds during `InitModule` (XP/Cast/Mount `5-20`, cooldown/quickslot/ultimate `12-30`)
- [2026-02-12] [CODE] Resource Orb Frames quickslot/cooldown continuity pass: `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now anchors quickslot `CountText` below `ButtonText` (LB glyph line) to avoid overlap clipping, elevates cooldown/stack text draw tier above cooldown overlays, normalizes cooldown state keys to `slot/category`, and uses shared cooldown caches (`SkillBar.SharedCooldownCaches`) so front/back bar transitions reuse existing remain/duration state; `Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua` now uses the same shared caches/state-key format and explicit cooldown-text draw priority; `Modules/ResourceOrbFrames/Templates/SkillBarTemplates.xml` now lowers cooldown overlay/edge tiers so countdown text renders fully opaque above the darkening layer and positions `UltimateText` as a bottom-aligned label box (`Dimensions y=32`, `BOTTOM` to parent `BOTTOM`, `offsetY -20`) so the number sits just above `LB+RB`
- [2026-02-12] [CODE] Resource Orb Frames cooldown smoothing coverage pass: `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now interpolates cooldown remain time per slot for smoother edge motion (`m_cooldownVisualState`), keeps icon desaturation clamped to empty-state when quickslot count reaches `0`, and updates quickslot count text through a shared helper that now shows `0` for item slots with no remaining quantity; `Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua` now applies the same per-slot remain interpolation + linear reveal-edge overlay behavior for back-bar slots including back-bar ultimate; `Modules/ResourceOrbFrames/Core/OrbEvents.lua` now runs cooldown updates for both bars on a shared `16ms` loop while leaving core status updates on `100ms`; `Modules/ResourceOrbFrames/Templates/SkillBarTemplates.xml` now defines `CooldownEdge` for back-bar buttons to render the reveal line
- [2026-02-11] [CODE] Resource Orb Frames cast-bar resource tint pass: `Modules/ResourceOrbFrames/Core/OrbBars.lua` now resolves cast-fill color using ESOUI-style cost mechanics (`GetAbilityBaseCostInfo` + `mechanicFlags` on bound/chained ability ID) and a short post-cast `EVENT_POWER_UPDATE` probe window (`450ms`) to sample actual health/magicka/stamina spend when metadata is ambiguous; cast fill now applies orb-matched two-tone styling (Fog + Fog2 equivalents from `Templates/ResourceOrbFrames.xml`: `health ff0000/4d0000`, `magicka 0066ff/000033`, `stamina 00ff00/004d00`) with default fallback for ultimate/non-resource casts
- [2026-02-11] [CODE] Resource Orb Frames cooldown reveal correction pass: `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now resolves front-bar button controls directly (root child first for quickslot/companion) before fallback search, applies gamepad reveal using a native-style top-left `CooldownEdge` anchor with width tied to logical button dimensions (`cooldownRevealWidth/Height`) set during layout, drives `CooldownOverlay` height from unrevealed percent to enforce visible greyed-out state at cooldown start, and progressively restores icon saturation as cooldown completes; `Modules/ResourceOrbFrames/ResourceOrbFrames.lua` now invalidates `ControlUtils` lookup cache immediately after quickslot/companion reparent to prevent stale control bindings
- [2026-02-11] [CODE] Resource Orb Frames bar-fill tuning clarity pass: `Modules/ResourceOrbFrames/Constants.lua` now defines explicit per-bar fill controls (`BETTERUI_*_BAR_FILL_WIDTH_SCALE`, `*_FILL_HEIGHT_SCALE`, `*_FILL_OFFSET_X`, `*_FILL_OFFSET_Y`) with direction docs and derives `*_FILL_REGION` from those values for XP/Cast/Mount; `Modules/ResourceOrbFrames/Core/OrbBars.lua` now wires explicit texture constants per bar (`*_BAR_BACKDROP_TEXTURE`, `*_BAR_FILL_TEXTURE`) so all fill/backdrop graphics are centrally identified and customizable
- [2026-02-11] [CODE] Resource Orb Frames cooldown/visual polish pass: `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now computes gamepad cooldown edge/overlay geometry from each button frame (`FlipCard` fallback chain) so quickslot and ultimate cooldown graphics track button dimensions across scale changes; quickslot count label now anchors centered below quickslot button (`AnchorQuickslotCountText` + template anchor update in `Modules/ResourceOrbFrames/Templates/SkillBarTemplates.xml`), XP fill strip height increased slightly in `Modules/ResourceOrbFrames/Constants.lua` (`BETTERUI_XP_BAR_FILL_REGION` top/bottom `0.42/0.585`), and shield text/overlay defaults shifted to electric blue in `Settings/Defaults.lua`, `Module.lua`, `Core/OrbVisuals.lua`, and `Templates/ResourceOrbFrames.xml`

**Now:**
- Multi-select server-call minimization audit is code-complete; pending in-game validation that large batch runs no longer attempt unsupported targets and that flood-kick risk stays reduced under the current timing/cooldown profile

**Next:**
- In-game validation pass: execute mixed valid/invalid 150-400 item batches (stolen, full bank/backpack, lock/junk state changes) and confirm (1) unsupported items are skipped without transfer attempts, (2) no flood kick, and (3) ETA + abort/completion messaging remain accurate

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
- `Modules/CIM/Core/MultiSelectMixin.lua`
- `Modules/CIM/Constants.lua`
- `Modules/Banking/Core/MultiSelectActions.lua`
- `Modules/Banking/Core/BankingClass.lua`
- `Modules/Inventory/Core/InventoryClass.lua`
- `Modules/Banking/Keybinds/KeybindManager.lua`
- `Modules/Inventory/Keybinds/InventoryKeybinds.lua`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-12 | [TOOL] | Multi-select audit hardening validation: `luac -p Modules/CIM/Core/MultiSelectMixin.lua` PASS, `luac -p Modules/CIM/Constants.lua` PASS, `luac -p Modules/Banking/Core/MultiSelectActions.lua` PASS, `luac -p Modules/Inventory/Core/InventoryClass.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after slot normalization/dedupe guards, unsupported transfer-target filtering, runtime eligibility rechecks, and routing batch destroy through `ProcessBatchThrottled` |
| 2026-02-12 | [TOOL] | Combat-icon anchor/pulse hardening validation: `luac -p Modules/ResourceOrbFrames/Core/OrbEvents.lua` PASS, `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after hardening quickslot/icon lookup to ROF-owned controls only (eliminating generic global fallback collisions), keeping BgMiddle geometry fallback anchoring, maintaining icon red pulse/tint lifecycle, and defaulting icon texture to `EsoUI/Art/LFG/LFG_icon_dps.dds` |
| 2026-02-12 | [TOOL] | Combat-icon control/texture fallback validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbEvents.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after switching to a known-valid default icon texture, adding persistent icon control resolution with dynamic fallback creation, and reapplying icon visual state/draw strata each refresh |
| 2026-02-12 | [TOOL] | Combat-icon quickslot-anchor visibility validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbEvents.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after enlarging/defaulting icon constants, reparenting icon to root to prevent clipping, anchoring above quickslot, and explicitly enforcing texture/alpha/color/draw strata each refresh |
| 2026-02-12 | [TOOL] | Combat-indicator layering/alignment follow-up validation: `luac -p Modules/ResourceOrbFrames/Core/OrbEvents.lua` PASS and `lua tools/tests/run_all_tests.lua` PASS (9/9) after tuning per-button glow draw strata below keybind hints (`DL_CONTROLS`/`DT_MEDIUM`) while keeping combat icon overlay draw order forced high |
| 2026-02-12 | [TOOL] | Combat-indicator runtime validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbEvents.lua` PASS, `luac -p Modules/ResourceOrbFrames/ResourceOrbFrames.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after wiring combat-state events/settings to live combat glow/icon updates and adding icon placement constants |
| 2026-02-12 | [TOOL] | Numeric-settings clamp hardening validation: `luac -p Modules/CIM/Core/FontDefinitions.lua` PASS, `luac -p Modules/CIM/Core/SettingsFactory.lua` PASS, `luac -p Modules/CIM/Module.lua` PASS, `luac -p Modules/CIM/Nameplates/Settings.lua` PASS, `luac -p Modules/CIM/Tooltips/Settings.lua` PASS, `luac -p Modules/Banking/Module.lua` PASS, `luac -p Modules/Inventory/Settings/FontSettings.lua` PASS, `luac -p Modules/Inventory/Settings/SettingsPanel.lua` PASS, `luac -p Modules/ResourceOrbFrames/Settings/Defaults.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after wiring load-time clamps for slider/editbox numeric settings across affected modules |
| 2026-02-12 | [TOOL] | Text-size migration/anchor-constant validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Settings/Defaults.lua` PASS, `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after adding quickslot/ultimate text-position constants and normalizing persisted text-size saved vars to current slider caps during `InitModule` |
| 2026-02-12 | [TOOL] | Quickslot/cooldown continuity validation: `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after re-anchoring quickslot count below keybind glyphs, lowering cooldown overlay tier under text, sharing cooldown smoothing/effect-duration caches across front/back bars, and finalizing `UltimateText` to a bottom-aligned anchor model (`y=32`, `BOTTOM` to `BOTTOM`, `offsetY -20`) |
| 2026-02-12 | [TOOL] | Cooldown smoothing coverage validation: `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbEvents.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after extending remain-time interpolation + linear reveal-edge cooldown visuals to both bars and moving both cooldown loops to shared 16ms updates |
| 2026-02-11 | [TOOL] | Cast-bar resource-tint validation: `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS and `lua tools/tests/run_all_tests.lua` PASS (9/9) after aligning cast-fill classification to ESOUI cost-mechanic flags (`GetAbilityBaseCostInfo`) plus power-drop probe fallback and orb-matched two-tone fill shading, while preserving ultimate/non-resource default fallback |
| 2026-02-11 | [TOOL] | Cooldown reveal correction validation: `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/ResourceOrbFrames.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after direct button-resolution + native-style gamepad edge reveal update with layout-driven logical button dimensions and overlay-driven unrevealed-state darkening |
| 2026-02-11 | [TOOL] | Bar-fill tunability validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after introducing explicit per-bar fill width/height/offset constants + texture constant wiring |
| 2026-02-11 | [TOOL] | Cooldown/quickslot/shield polish validation: `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Module.lua` PASS, `luac -p Modules/ResourceOrbFrames/Settings/Defaults.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) |
| 2026-02-11 | [TOOL] | Cast-bar instant-preview validation: `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after enabling non-cast/channel skill previews via `BETTERUI_CAST_BAR_INSTANT_DISPLAY_MS` |
| 2026-02-11 | [TOOL] | Placement-correction validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after XP/mount height + visible-mode anchor corrections |
| 2026-02-11 | [TOOL] | Follow-up tuning validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after mount offset direction fix + XP/mount fill-region/label updates + orb visibleScale increase |
| 2026-02-11 | [TOOL] | Bar-geometry refresh validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after per-bar texture bounds/fill-region wiring |
| 2026-02-11 | [TOOL] | Ornament-fit follow-up validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after adding ornament-visible orb scaling |
| 2026-02-11 | [TOOL] | Graphics alignment validation: `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after wiring cast/mount-specific bar backdrops + ornament position/size tuning |

