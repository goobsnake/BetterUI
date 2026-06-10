# Comment-Feedback Implementation Plan (Outstanding Items)

Created: 2026-06-10
Status: Active
Source: ESOUI addon page comment triage (2026-06-10). Closed in that pass: PB-002..PB-006.
Outstanding: PB-007 (UX), ECO-001, TRC-001, HUD-001.

## Scope and Sequencing

| Order | Item | Area | Effort | Risk |
|---|---|---|---|---|
| 1 | PB-007 vault deposit busy-state keybind | Banking | Low | Low |
| 2 | ECO-001 Archival Fortunes currency display | Inventory currency rows | Low | Low |
| 3 | TRC-001 market prices on crafting/improvement pages | CIM market integration | Medium | Medium |
| 4 | HUD-001 independent orb / action-bar positioning | ResourceOrbFrames | High | High |

Each phase lands as its own commit with tests; run `/review-commit` per phase.

---

## Phase 1 — PB-007: Furniture vault deposit busy-state keybind

**Problem.** Deposits issue `CallSecureProtected("RequestMoveItem", ...)`
(`Modules/Banking/Actions/TransferActions.lua:212`) and the server round-trip takes
noticeable time in the furniture vault; the keybind gives no feedback, so users
re-press and perceive lag (bortsmithson, 04/10/26).

**Design.** Track in-flight transfers per `bagId..":"..slotIndex` in a module-local
table inside `TransferActions.lua`:

1. `MarkTransferPending(bag, index)` before `RequestMoveItem`; store `GetFrameTimeMilliseconds()`.
2. Clear the marker on `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` for that bag/slot
   (register via `Modules/CIM/Core/Lifecycle/EventRegistry.lua`), plus a 5 s
   stale-entry sweep so a missed event can never wedge the keybind.
3. `IsTransferPending(target)` consumed by the deposit keybind's `enabled` callback in
   `Modules/Banking/Actions/BankingActions.lua` — show the stock "busy" disabled state;
   ignore presses while pending. `est: 5m`

**Tests.** Extend `tools/tests/test_banking_transfer_actions.lua`: pending marker set on
deposit, cleared on simulated slot-update event, stale sweep clears after timeout,
keybind enabled-callback returns false while pending. `est: 5m`

**Acceptance.** Single press deposits; keybind shows disabled/busy until the move
confirms; no double `RequestMoveItem` for the same slot while pending.

---

## Phase 2 — ECO-001: Archival Fortunes in currency display options

**Problem.** Archival Fortunes (Infinite Archive, `CURT_ARCHIVAL_FORTUNES`) cannot be
shown in the currency rows (oddavi, 05/29/26).

**Design.** The currency system is data-driven via `CURRENCY_DATA` in
`Modules/Inventory/Settings/CurrencySettings.lua` (id, settingKey, orderKey, labelStr,
orderStr, defaultOrder):

1. Append entry `id = "archival"`, `settingKey = "showCurrencyArchival"`,
   `orderKey = "orderCurrencyArchival"`, `defaultOrder` = next slot; confirm the
   id→`CURT_*` mapping point used by the row renderer and add
   `CURT_ARCHIVAL_FORTUNES` there (guard with `rawget(_G, "CURT_ARCHIVAL_FORTUNES")`
   for API safety). `est: 5m`
2. Register defaults in `Modules/CIM/Core/Settings/DefaultsRegistry.lua` and metadata in
   `SettingsMetadata.lua` (group: currency display; default hidden=false to match other
   optional currencies). `est: 5m`
3. Strings: add `SI_BETTERUI_CURRENCY_SHOW_ARCHIVAL` / `SI_BETTERUI_CURRENCY_ORDER_ARCHIVAL`
   to `lang/en.lua`, then the l10n preview→apply flow for de/es/fr/jp/ru/zh
   (`l10n_write_preview` → `l10n_apply`). `est: 5m`

**Tests.** Extend the currency settings test (`tools/tests/test_settings_group_resets.lua`
or the currency-specific suite): new keys present, default order stable, reset group
includes the new keys; lang completeness check via `tools/LanguageMaintenance.ps1`
parity tests. `est: 5m`

**Acceptance.** Toggle + order setting appear with the other currencies; row renders the
Archival Fortunes amount with its icon; non-EN locales fall back cleanly until
translated.

---

## Phase 3 — TRC-001: Market prices on crafting and improvement pages

**Problem.** TTC 4.27 ships price data on crafting/improvement screens; users want the
same while BUI is active (Edricson, 04/11/26). BUI already aggregates ATT/MM/TTC via
`Modules/CIM/Core/Integration/MarketIntegration.lua`
(`GetMarketPriceInfo(itemLink, stackCount)`, priority order, per-source toggles).

**Design.** Reuse the existing aggregation — no new data sources:

1. Identify the gamepad crafting tooltip surfaces: smithing creation/improvement use
   `ZO_SmithingCreation_Gamepad` / `ZO_SmithingImprovement_Gamepad` result tooltips
   rendered through `GAMEPAD_TOOLTIPS` (`GAMEPAD_LEFT_TOOLTIP`). Verify exact layout
   functions with esoui-api (`ZO_Tooltip:LayoutPendingSmithingItem`,
   `ZO_Tooltip:LayoutPendingItemChargeOrQuality`). `est: 5m`
2. New `Modules/GeneralInterface/Tooltips/CraftingPriceTooltip.lua`: post-hook the two
   layout functions; build the would-be item link (`GetSmithingPatternResultLink`,
   `GetSmithingImprovedItemLink`), call `MarketIntegration.GetMarketPriceInfo`, append a
   price line to the tooltip via the existing native-price label pattern from
   `Modules/Inventory/UI/TooltipUtils.lua` (`_betterUiNativePriceLabel`). Respect
   `showMarketPrice` + per-source toggles; no-op when no source addon is loaded. `est: 5m`
3. Add file to `BetterUI.txt` load order after MarketIntegration; gate behind a new
   `showCraftingMarketPrice` setting (default on) in the Market Integration submenu in
   `Modules/GeneralInterface/Tooltips/Settings.lua`. `est: 5m`

**Tests.** New `tools/tests/test_crafting_price_tooltip.lua` with stubbed
`GetSmithingPatternResultLink`/TTC price provider: hook installs once, price line text
formatting, disabled-setting path, missing-provider path. Extend
`test_market_integration.lua` for the new entry point. `est: 5m`

**Risks.** ZO layout function names can shift per API bump — guard every hook with
`type(...) == "function"` checks and fail soft. Improvement preview links may be
nil for un-improvable selections; skip the line.

**Acceptance.** With TTC (or MM/ATT) enabled, creation and improvement panels show the
aggregated unit price for the result item; toggling the setting removes it instantly.

---

## Phase 4 — HUD-001: Independent orb / action-bar positioning

**Problem.** Orbs and the action bar move as one anchored frame group; users want the
orbs placed independently (Loliam 04/10/26, Vo1se 05/10/26 — "at least the orbs").

**Design (incremental, orbs-first as requested).**

1. **Audit anchor graph** in `Modules/ResourceOrbFrames/ResourceOrbFrames.lua` (frame
   layout), `Core/OrbVisuals.lua` (`baseAnchorX/...` fields), and
   `Modules/CIM/Core/Data/PositionManager.lua` (saved offsets): document which controls
   anchor to the action-bar container vs. screen. `est: 10m`
2. **Introduce per-group offsets**: extend PositionManager saved-vars schema with
   `orbOffsetX/orbOffsetY` (left + right orb pair) layered on top of the existing global
   frame offset — orbs keep following the global offset by default so existing setups
   are unchanged (migration: new keys default 0). `est: 5m`
3. **Apply offsets** in the orb layout pass (`ResourceOrbFrames.lua` anchor update +
   `OrbAnimations.lua` `rootFrame:ClearAnchors()` paths must re-apply the extra offset
   to avoid animation snap-back). `est: 5m`
4. **Settings UI**: add "Move orbs independently" toggle + X/Y sliders (or reuse the
   existing frame-move keybind flow with an orb-only mode) in the ResourceOrbFrames
   settings panel. `est: 5m`
5. **Tests**: extend `tools/tests/test_position_manager.lua` (schema migration,
   defaults, offset math) and `test_orb_bars_pure.lua` (layout math with non-zero orb
   offsets). `est: 5m`

**Risks.** Highest-risk item: animation paths clear anchors at runtime; missing one
re-anchor site causes drift mid-combat. Ship behind the toggle (default off) so stock
behavior is preserved; in-game verification across weapon-swap, mount, and werewolf
states required before release.

**Acceptance.** With the toggle off, layout is pixel-identical to today. With it on,
orb pair offset persists across reload/zone, animations keep the offset, and the
action bar is unaffected.

---

## Verification Gates (all phases)

- `test_validate(luac_syntax)` on changed files; `test_validate(lua_run)` on the
  matching `tools/tests/test_*.lua` suites.
- Update `docs/reference/architecture.md` if new files/settings groups are added.
- In-game gamepad smoke pass per phase before ESOUI release; fold completed phases into
  `docs/planning/completed-improvements.md` and close the backlog/feature rows.
