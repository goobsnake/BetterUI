# Desloppify Rerun Queue — Execution Ordering Recommendation

**Date**: 2026-04-17  
**Current Scores**: overall 76.4 / objective 79.2 / strict 76.3 / verified 67.0  
**Target**: strict 90 (config says 95, but task says 90)  
**Gap to 90**: 13.7 points  
**Scan count**: 26

---

## Live Queue Breakdown (34 items)

| Segment | Count | Items |
|---------|-------|-------|
| Subjective re-reviews | 19 | All 19 subjective dimensions (17 in top block + cross_module_architecture, test_strategy at tail) |
| Review issues (new) | 8 | abstraction_fitness×2, cross_module_architecture×3, test_strategy×3 |
| Triage pipeline | 7 | strategize→observe→reflect→organize→enrich→sense-check→commit |

All 15 execution clusters are `done` or `review` status. No active cluster. Vendor-tail clusters (`vendor-surface-contracts`) are **done** — no leftover Vendor work remains in the live queue.

---

## Dimension Score Landscape (below 90, sorted by gap)

| Dimension | Strict | Gap to 90 | Subjective? | In queue? |
|-----------|--------|-----------|-------------|-----------|
| Test health | 16.7 | 73.3 | No (objective) | No — 164 test_coverage issues, separate lane |
| Design coherence | 64.0 | 26.0 | Yes | Yes |
| High elegance | 68.0 | 22.0 | Yes | Yes |
| Low elegance | 68.0 | 22.0 | Yes | Yes |
| API coherence | 72.0 | 18.0 | Yes | Yes |
| Type safety | 72.0 | 18.0 | Yes | Yes |
| AI generated debt | 73.0 | 17.0 | Yes | Yes |
| Error consistency | 74.0 | 16.0 | Yes | Yes |
| Stale migration | 76.0 | 14.0 | Yes | Yes |
| Test strategy | 76.0 | 14.0 | Yes | Yes (+ 3 review issues) |
| Init coupling | 77.0 | 13.0 | Yes | Yes |
| Logic clarity | 80.0 | 10.0 | Yes | Yes |
| Mid elegance | 81.0 | 9.0 | Yes | Yes |
| Cross-module arch | 81.6 | 8.4 | Yes | Yes (+ 3 review issues) |
| Abstraction fit | 82.0 | 8.0 | Yes | Yes (+ 2 review issues) |
| Contracts | 84.0 | 6.0 | Yes | Yes |
| Naming quality | 84.0 | 6.0 | Yes | Yes |
| Structure nav | 84.0 | 6.0 | Yes | No |
| File health | 84.1 | 5.9 | No (objective) | No — 44 structural issues |
| Convention drift | 88.0 | 2.0 | Yes | Yes |
| Dep health | 91.0 | — | Yes | Yes (already ≥90) |

---

## Recommended Ordering: Triage First, Then Batched Re-Reviews

### Rationale

1. **Triage the 8 review issues first** — they are concrete findings with file-level acceptance criteria. Resolving them directly moves 3 dimensions (abstraction_fitness, cross_module_architecture, test_strategy) and unblocks their subjective re-reviews with better signal. Triage is low-risk, fast, and produces committed fixes.

2. **Do NOT re-review subjective dimensions before fixing review issues** — re-reviewing dimensions that have open review issues just re-discovers the same problems and wastes the review budget without score movement. The re-review will score higher after fixes land.

3. **Vendor-tail work is done** — both `vendor-surface-contracts` clusters are `execution_status: done`. The SQL board should mark these complete. No Vendor execution remains.

4. **Test health (16.7) is the single largest drag** but is a separate lane (164 files, no cross-dependency with subjective work). It should run in parallel but not block the subjective path to 90.

### Execution Batches

**Batch 0 — Review Issue Triage** (est: 1 session, ~30 min)
```
Queue items: triage::strategize through triage::commit (7 steps)
Prereq: none
Effect: resolves 8 review issues, fixes land in code
```
The triage pipeline is already seeded with strategy guidance. Execute the 7-step triage pipeline (`strategize→observe→reflect→organize→enrich→sense-check→commit`) which processes and resolves the 8 review issues.

**Batch 1 — High-Impact Subjective Re-Reviews** (est: 2-3 sessions)
```
Queue items (6 dimensions, biggest gap-to-90):
  subjective::design_coherence        (64 → target ≥80)
  subjective::high_level_elegance     (68 → target ≥80)
  subjective::low_level_elegance      (68 → target ≥80)
  subjective::api_surface_coherence   (72 → target ≥80)
  subjective::type_safety             (72 → target ≥80)
  subjective::ai_generated_debt       (73 → target ≥80)
Prereq: Batch 0 complete (review fixes landed)
Effect: these 6 dims account for most of the strict score drag
```
These are the dimensions farthest from 90 and will move the strict average the most. Re-review after triage fixes land.

**Batch 2 — Mid-Gap Subjective Re-Reviews** (est: 1-2 sessions)
```
Queue items (5 dimensions):
  subjective::error_consistency       (74)
  subjective::incomplete_migration    (76)
  subjective::test_strategy           (76)
  subjective::initialization_coupling (77)
  subjective::logic_clarity           (80)
Prereq: none (can parallel with Batch 1)
Effect: mid-tier dimensions closer to target
```

**Batch 3 — Near-Target Subjective Re-Reviews** (est: 1 session)
```
Queue items (6 dimensions):
  subjective::mid_level_elegance      (81)
  subjective::cross_module_architecture (81.6)
  subjective::abstraction_fitness     (82)
  subjective::contract_coherence      (84)
  subjective::naming_quality          (84)
  subjective::convention_outlier      (88)
Prereq: Batch 0 complete (cross_module_arch and abstraction_fitness have review issues)
Effect: polish pass, each needs only small uplift
```

**Batch 4 — Already-Passing Dimensions** (est: skip or minimal)
```
Queue items (2 dimensions):
  subjective::dependency_health       (91, already ≥90)
  subjective::package_organization    (84, moderate gap)
Prereq: none
Effect: minimal — dep_health can be skipped, package_organization is standalone
```

**Parallel Lane — Test Coverage** (ongoing, independent)
```
164 test_coverage issues in auto/test_coverage clusters
No dependency on subjective work
Effect: moves Test health from 16.7 toward target
```

### Dependency Graph

```
Batch 0 (triage) ──→ Batch 1 (high-gap re-reviews)
                 ──→ Batch 3 (near-target, needs review fixes for 2 dims)

Batch 2 (mid-gap) ── no dependency, can parallel with Batch 1

Batch 4 ── independent, low priority

Test Coverage ── fully independent parallel lane
```

---

## SQL/Board Alignment Recommendations

1. **Mark Vendor clusters done**: `vendor-surface-contracts`, `bootstrap-scene-orchestration`, `inventory-local-refactors`, `skillbar-cooldown-utils`, `resource-orbframes-structure`, `banking-contract-cleanups`, `cim-generalinterface-boundaries`, `cim-lifecycle-cleanups`, `settings-registration-contracts`, `module-root-contracts`, `writunit-doc-cleanups`, `architecture-doc-sync` — all have `execution_status: done`. If the board still shows these as active, close them.

2. **Remove Vendor-tail from board priority**: The task context mentioned "two Vendor-tail batches remain in SQL" — these are no longer in the live queue. Demote or archive them.

3. **Add triage pipeline as next-up**: The 7 triage steps should be the board's current active work item.

4. **Group the 19 subjective re-reviews into 4 batches** per the ordering above, so the board reflects true dependencies rather than a flat list of 19.

5. **Separate test_coverage into its own board lane**: 164 items with no cross-dependency deserve their own tracking, not mixed into the subjective path.

---

## Path to Strict 90

The strict score is the average of all 25 dimension strict scores. Current average: 76.3.

To reach 90, you need the sum of all dimension scores to increase by ~342 points (25 × 13.7). The biggest levers:
- **Test health**: 16.7 → 70 would add 53.3 points (2.1 pts to strict)
- **Design coherence**: 64 → 85 would add 21 pts (0.84 pts to strict)
- **Elegance trio**: 68→85 each × 2 dims = 34 pts (1.36 pts to strict)
- **API + Type safety**: 72→85 each × 2 = 26 pts (1.04 pts to strict)

Realistically, getting all subjective dimensions to 85+ and test health to ~50 would put strict around 83-84. Reaching 90 requires test health above 70 AND most subjective dimensions above 88.

**Bottom line**: Triage first (Batch 0), then Batch 1 high-gap re-reviews, with test coverage running in parallel. This is the fastest path to strict 90.
