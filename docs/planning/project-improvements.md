# Project Improvements

Last Updated: 2026-06-30
Status: Active

## Purpose

This file tracks execution-ready improvement phases and tech debt items for BetterUI.
Items are phased by dependency and risk. Completed items are migrated to `completed-improvements.md`.

## Active Phases

### BUI-TRACE-001: AI-replay-grade builog coverage

Goal: make `Interface.log` dense enough for an AI reviewer to reconstruct in-game BetterUI behavior without video: scene, function, module feature, selected row, row order, displayed/fired keybinds, dialog lifecycle, item/currency deltas, settings changes, and failure reason.

- [ ] Phase 1: Trace contract foundation (est: 25 min)
- [ ] Task: define canonical trace envelope fields for `scene`, `module`, `feature`, `event`, `phase`, `flowId`, `function`, `target`, `selection`, `keybinds`, `result`, and `reason` (est: 10 min; validation: host Lua/static check plus inspect-log sample review)
- [ ] Task: standardize helper serializers for items, lists, keybind descriptors, currency, settings values, and bounded table snapshots (est: 10 min; validation: host Lua/static check)
- [ ] Task: add watch/drop visibility for muted/dropped/high-volume trace categories without hiding replay-critical failures (est: 5 min; validation: 5-minute monitor)

- [ ] Phase 2: Settings and LAM trace coverage (est: 25 min)
- [ ] Task: trace every shared module settings panel registration, sort, control registration, get, set, button, disabled, and warning evaluation through `CIM.Settings` (est: 10 min; validation: module settings panel smoke pass)
- [ ] Task: trace master BetterUI module toggles and developer feature-flag controls in the root LAM panel (est: 5 min; validation: settings panel smoke pass)
- [ ] Task: trace setting writes at `GetSetting`/`SetSetting`/callbacks with old/new/default source values across all modules (est: 10 min; validation: targeted setting toggle monitor)

- [ ] Phase 3: Inventory and banking replay paths (est: 25 min)
- [ ] Task: complete inventory equip, BOE, equip-slot dialog, primary action discovery/mutation, custom action injection, and Y-menu lifecycle traces (est: 10 min; validation: inventory equip/sort/action dialog monitor)
- [ ] Task: complete banking transfer destination, pending mark/clear/timeout, currency delta, quantity slider/min/max/confirm/cancel, and action dialog close traces (est: 10 min; validation: bank deposit/withdraw/currency monitor)
- [ ] Task: capture list rebuild order, selected row identity, equip icon state, and before/after keybind strip snapshots for inventory/banking lists (est: 5 min; validation: tab-through/sort monitor)

- [ ] Phase 4: Vendor, TradingHouse, and Writs replay paths (est: 25 min)
- [ ] Task: trace vendor scene open/close, mode switches, list order/selection, keybind display/fire, buy/sell/repair/fence/launder/stable actions, and item/currency deltas (est: 10 min; validation: vendor interaction monitor)
- [ ] Task: trace TradingHouse browse/listings/sell scene, filters/search, price entry, row identity/order, keybinds, dialogs, listing creation/cancel/buy results, and currency/item deltas (est: 10 min; validation: guild trader monitor)
- [ ] Task: trace Writ state changes, craft/turn-in decisions, scene/dialog transitions, and failure reasons (est: 5 min; validation: writ flow monitor)

- [ ] Phase 5: Visual and interface modules (est: 25 min)
- [ ] Task: trace ResourceOrbFrames resource values, threshold bands, combat indicators, weapon-swap/skillbar/ultimate cooldown state, cast start/stop, and rate-limited high-frequency deltas (est: 10 min; validation: combat/skillbar monitor)
- [ ] Task: trace Nameplates live setting application, size/style visibility decisions, and refresh outcomes (est: 5 min; validation: nameplate setting monitor)
- [ ] Task: trace Companions list/dialog/equip/junk flows and companion summon/equipment scene state (est: 5 min; validation: companion scene monitor)
- [ ] Task: trace GeneralInterface tooltip/market-price/delete-dialog/mail/chat-history behavior with item metadata and setting source (est: 5 min; validation: tooltip/general UI monitor)

- [ ] Phase 6: Review and monitor hardening (est: 25 min)
- [ ] Task: run delegated critical review across Kimi, Antigravity, Codex, and Claude for trace semantics, overlogging, privacy, and parser usability (est: 5 min; validation: host review of artifacts)
- [ ] Task: run host Lua/static validation and fix valid findings from delegated review (est: 10 min; validation: host validation command)
- [ ] Task: run a 5-minute in-game builog monitor and compare observed gameplay against expected trace reconstruction questions (est: 10 min; validation: monitor summary)
