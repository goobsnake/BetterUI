# Multi-Select Anti-Spam Hardening Plan (Phased)

Date: March 5, 2026  
Owner: BetterUI addon team

Related planning artifacts:
- `docs/planning/priority-backlog.md` for active `P0/P1` execution ranking
- `docs/planning/feature-requests.md` for long-horizon capability intake

## Scope
- Hardening all multi-select batch operations to reduce server-facing burst patterns that can trigger temporary logout/kick behavior.
- Cover all previously recommended items (major + minor):
  - explicit destination-slot resolution for move requests,
  - re-entry/concurrency guards for batch pipelines,
  - adaptive + weighted throttling,
  - destroy-path robustness,
  - optional user-facing safety profile.
- Keep existing feature behavior and UX intent unless safety requires a stricter default.

## Non-Goals
- Rewriting inventory/banking architecture outside multi-select and batch-action paths.
- Large visual redesign of dialogs/keybind strips.
- Full migration of unrelated legacy code in `InventoryClass.lua`.

## Success Criteria
- No multi-select path issues unbounded request bursts.
- No multi-select path sends `RequestMoveItem` with unresolved destination slot.
- Batch operations are single-owner (no overlapping pipelines).
- Server-bound actions back off under stress and recover when stable.
- Smoke testing shows no regressions in normal inventory/banking actions.

---

## Phase 0 - Baseline & Guardrails

- [ ] **P0.1 Capture current behavior baseline and add safety feature flag scaffold**
  - Files:
    - `Modules/CIM/Constants.lua`
    - `Modules/CIM/Core/DefaultsRegistry.lua`
  - Behavior change:
    - Add explicit batch safety profile/version constants and defaults (`legacy`, `safe_v2`), defaulting to existing behavior for first merge.
  - Test to write first:
    - `tools/tests/test_batch_safety_defaults.lua` (default profile, tier ordering, cooldown constants present).
  - Validation command:
    - `lua tools/tests/test_batch_safety_defaults.lua`
    - `luac -p Modules/CIM/Constants.lua Modules/CIM/Core/DefaultsRegistry.lua`

- [ ] **P0.2 Add lightweight batch diagnostics (debug-only)**
  - Files:
    - `Modules/CIM/Core/MultiSelectMixin.lua`
    - `Modules/CIM/Core/DeveloperDebug.lua`
  - Behavior change:
    - Track last batch summary: action name, item count, elapsed, average delay, abort reason.
    - Expose debug readout command for manual validation.
  - Test to write first:
    - `tools/tests/test_batch_diagnostics.lua` (summary fields populated/reset correctly).
  - Validation command:
    - `lua tools/tests/test_batch_diagnostics.lua`
    - `luac -p Modules/CIM/Core/MultiSelectMixin.lua Modules/CIM/Core/DeveloperDebug.lua`

Dependency: None (foundation phase).

---

## Phase 1 - Correctness Blockers (Must-Fix First)

- [ ] **P1.1 Resolve destination slot explicitly for every `RequestMoveItem` batch call**
  - Files:
    - `Modules/Banking/Core/MultiSelectActions.lua`
    - `Modules/Inventory/Core/InventoryClass.lua`
    - `Modules/CIM/Core/Utilities.lua` (shared resolver helper)
  - Behavior change:
    - Replace `destinationSlot=nil` paths with explicit slot resolution:
      - first empty slot in destination bag,
      - fallback to stackable target slot where applicable,
      - hard stop with controlled abort reason when no valid slot.
  - Test to write first:
    - `tools/tests/test_batch_destination_resolution.lua`:
      - empty-slot case,
      - stack-merge fallback case,
      - full-bag stop case.
  - Validation command:
    - `lua tools/tests/test_batch_destination_resolution.lua`
    - `luac -p Modules/Banking/Core/MultiSelectActions.lua Modules/Inventory/Core/InventoryClass.lua Modules/CIM/Core/Utilities.lua`

- [ ] **P1.2 Harden destroy action reliability in batch contexts**
  - Files:
    - `Modules/Inventory/Actions/DestroyAction.lua`
    - `Modules/Inventory/Core/InventoryClass.lua`
  - Behavior change:
    - Guarantee cursor sound state restoration on all exit paths.
    - Ensure destroy calls are executed through a safe, deterministic path in throttled batch loops.
  - Test to write first:
    - `tools/tests/test_destroy_action_batch_safety.lua`.
  - Validation command:
    - `lua tools/tests/test_destroy_action_batch_safety.lua`
    - `luac -p Modules/Inventory/Actions/DestroyAction.lua Modules/Inventory/Core/InventoryClass.lua`

Risk notes (high-impact):
- Slot resolver mistakes can misroute items; add strict bag/slot validation before issuing move call.
- Destroy safety changes can impact existing quick-destroy behavior; keep parity tests for single-item flow.

Dependencies:
- P1.1 independent.
- P1.2 independent.

Parallelization:
- P1.1 and P1.2 can run in parallel.

---

## Phase 2 - Batch Pipeline Safety & Concurrency Control

- [ ] **P2.1 Enforce single active batch pipeline per screen instance**
  - Files:
    - `Modules/CIM/Core/MultiSelectMixin.lua`
    - `Modules/Banking/Core/BankingClass.lua`
    - `Modules/Inventory/Core/InventoryClass.lua`
  - Behavior change:
    - Add re-entry guard: reject or queue batch start if `isBatchProcessing` is already true.
    - Add pipeline token/owner ID so stale timers cannot continue after replacement/abort.
  - Test to write first:
    - `tools/tests/test_batch_reentry_guard.lua` (double-start, stale timer, post-abort start).
  - Validation command:
    - `lua tools/tests/test_batch_reentry_guard.lua`
    - `luac -p Modules/CIM/Core/MultiSelectMixin.lua Modules/Banking/Core/BankingClass.lua Modules/Inventory/Core/InventoryClass.lua`

- [ ] **P2.2 Normalize action cost accounting for multi-call operations**
  - Files:
    - `Modules/CIM/Core/MultiSelectMixin.lua`
  - Behavior change:
    - Support operation cost per item (`cost=2` for `Pickup+Place`, `cost=1` for single request).
    - Cooldown cadence uses accumulated cost, not just item count.
  - Test to write first:
    - `tools/tests/test_batch_weighted_cost.lua`.
  - Validation command:
    - `lua tools/tests/test_batch_weighted_cost.lua`
    - `luac -p Modules/CIM/Core/MultiSelectMixin.lua`

Risk notes (high-impact):
- Incorrect token lifecycle can orphan active batches; include explicit teardown in all finish/abort branches.

Dependencies:
- P2.2 depends on P2.1.

---

## Phase 3 - Adaptive Anti-Spam Pacing

- [ ] **P3.1 Add adaptive backoff policy**
  - Files:
    - `Modules/CIM/Core/MultiSelectMixin.lua`
    - `Modules/CIM/Constants.lua`
  - Behavior change:
    - Increase delay when slot-update acknowledgements lag or failures occur.
    - Decay delay gradually after stable successful operations.
  - Test to write first:
    - `tools/tests/test_batch_adaptive_backoff.lua`.
  - Validation command:
    - `lua tools/tests/test_batch_adaptive_backoff.lua`
    - `luac -p Modules/CIM/Core/MultiSelectMixin.lua Modules/CIM/Constants.lua`

- [ ] **P3.2 Add bounded jitter to avoid request rhythm spikes**
  - Files:
    - `Modules/CIM/Core/MultiSelectMixin.lua`
  - Behavior change:
    - Add small randomized jitter within a safe range per dispatch interval.
  - Test to write first:
    - `tools/tests/test_batch_jitter_bounds.lua`.
  - Validation command:
    - `lua tools/tests/test_batch_jitter_bounds.lua`
    - `luac -p Modules/CIM/Core/MultiSelectMixin.lua`

- [ ] **P3.3 Add explicit max dispatch budget**
  - Files:
    - `Modules/CIM/Core/MultiSelectMixin.lua`
    - `Modules/CIM/Constants.lua`
  - Behavior change:
    - Enforce hard maximum dispatch budget per second (weighted by operation cost).
  - Test to write first:
    - `tools/tests/test_batch_dispatch_budget.lua`.
  - Validation command:
    - `lua tools/tests/test_batch_dispatch_budget.lua`
    - `luac -p Modules/CIM/Core/MultiSelectMixin.lua Modules/CIM/Constants.lua`

Risk notes (high-impact):
- Overly conservative adaptive settings can feel sluggish; tune with staged rollout and telemetry from Phase 0.

Dependencies:
- P3.1 depends on P2.2.
- P3.2/P3.3 depend on P3.1.

---

## Phase 4 - User Controls, UX, and Safe Defaults

- [ ] **P4.1 Add batch safety profile setting**
  - Files:
    - `Modules/CIM/Core/DefaultsRegistry.lua`
    - `Modules/Inventory/Settings/SettingsPanel.lua`
    - `Modules/Banking/Settings/SettingsPanel.lua`
    - `Modules/CIM/Core/MultiSelectMixin.lua`
  - Behavior change:
    - Add user-selectable profiles:
      - `Safe` (strongest anti-spam),
      - `Balanced` (default after rollout),
      - `Fast` (explicit opt-in).
  - Test to write first:
    - `tools/tests/test_batch_profile_mapping.lua`.
  - Validation command:
    - `lua tools/tests/test_batch_profile_mapping.lua`
    - `luac -p Modules/CIM/Core/DefaultsRegistry.lua Modules/Inventory/Settings/SettingsPanel.lua Modules/Banking/Settings/SettingsPanel.lua Modules/CIM/Core/MultiSelectMixin.lua`

- [ ] **P4.2 Improve in-batch user feedback**
  - Files:
    - `Modules/CIM/Core/MultiSelectMixin.lua`
    - `lang/en.lua` (and localized strings files in `lang/`)
  - Behavior change:
    - Make “still processing” messages include safety-mode context and abort hint.
    - Clarify stop reasons (full bag, scene change, manual abort, safety throttle).
  - Test to write first:
    - `tools/tests/test_batch_status_messages.lua`.
  - Validation command:
    - `lua tools/tests/test_batch_status_messages.lua`
    - `luac -p Modules/CIM/Core/MultiSelectMixin.lua`

Dependencies:
- P4.1 depends on P3.x completion.
- P4.2 can start during late P3.

---

## Phase 5 - Verification, Rollout, and Rollback

- [ ] **P5.1 Automated regression pass**
  - Files:
    - `tools/tests/*` (new + existing)
  - Behavior change:
    - None (verification only).
  - Test to write first:
    - N/A (execution phase).
  - Validation command:
    - `lua tools/tests/run_all_tests.lua`
    - `luac -p Modules/CIM/Core/MultiSelectMixin.lua Modules/Banking/Core/MultiSelectActions.lua Modules/Inventory/Core/InventoryClass.lua Modules/Inventory/Actions/DestroyAction.lua`

- [ ] **P5.2 Manual in-game stress suite (must pass before profile default change)**
  - Files:
    - `docs/guides/testing-guide.md` (append multi-select stress checklist)
  - Behavior change:
    - Documented stress runs:
      - 200-item bank withdraw/deposit mixed stacks,
      - 200-item craftbag stow/retrieve,
      - rapid open/close scene while batch active,
      - repeated abort/restart cycles.
  - Test to write first:
    - Add checklist section first, then execute it.
  - Validation command:
    - Manual: `/reloadui`, perform checklist in `docs/guides/testing-guide.md`.

- [ ] **P5.3 Staged rollout + rollback switch**
  - Files:
    - `Modules/CIM/Core/DefaultsRegistry.lua`
    - `Modules/CIM/Constants.lua`
  - Behavior change:
    - Keep runtime switch to revert from `safe_v2` to legacy pacing without code rollback.
  - Test to write first:
    - `tools/tests/test_batch_profile_rollback.lua`.
  - Validation command:
    - `lua tools/tests/test_batch_profile_rollback.lua`
    - `luac -p Modules/CIM/Core/DefaultsRegistry.lua Modules/CIM/Constants.lua`

Risk notes (high-impact):
- Rollout without staged profile gate can reintroduce logout risk if tuning is off.
- Do not flip default profile until P5.2 stress pass is clean.

---

## Dependency Graph (Summary)
- Phase 0 -> Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5.
- Parallel candidates:
  - P1.1 and P1.2.
  - Late P3 tuning and P4.2 messaging.

## Completion Definition
- All phase checkboxes complete.
- New tests added and passing.
- Manual stress suite executed with zero forced-logoff/kick incidents in validation session.
- Safety profile rollback path verified.
