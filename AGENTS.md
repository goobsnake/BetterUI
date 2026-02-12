# BetterUI Agent Configuration

> This is the root configuration for AI agents working on BetterUI.
> **At session start:** Read this file, then `docs/CONTINUITY.md`, then `docs/TRIBAL_KNOWLEDGE.md`.

---

## Important Rules

* **Build modular first.** No new code file exceeds 500 LOC (modular-first rule), existing files ignore this limit. Documentation and plans can be any length, but code must be modular.
* **Think ahead!** Do not write code that you know will need to be changed later without planning for that change now. Keep entrypoints stable and isolate logic into smaller modules from the start.
* **Do not limit yourself due to the LOC limit!** If a task requires more code, split it into multiple files/modules/functions.
* **No default fallbacks during development.** If something fails, let it fail so we can fix it.
* **Localization exception:** Do not use English placeholder text in non-English locale files. Add translated locale strings in the same change set.
* **No empty try-catch blocks anywhere!**
* **Do not reinvent the wheel!** Reference existing ESO API patterns from the `esoui/` folder or online ESO documentation. Leverage in-game libraries and utilities where available.
* **Design UI for the end-user, not for the schema!**
* **Keep docs addon-focused.** Files under `docs/` must stay strictly about BetterUI addon architecture, behavior, testing, and ESO implementation details.
* **Cleanup before commit.** Remove temporary files (code review artifacts, implementation plans, scratch notes) before `git commit`.

---

## Continuity Ledger

Maintain a single continuity file for this workspace: `docs/CONTINUITY.md`.

`docs/CONTINUITY.md` is the canonical briefing designed to survive compaction; do not rely on earlier chat/tool output unless it's reflected there.

### Operating Rule
- At the start of each assistant turn: read `docs/CONTINUITY.md` before acting.
- Per-turn minimum read (quota-efficient): `State (Done/Now/Next)`, `Open Questions`, and `Working Set`.
- Full-file continuity re-read is required on session start, stale-risk states, workflow switches, or before major phase transitions.
- Continuity is milestone-oriented, not message-oriented.
- Update `docs/CONTINUITY.md` only when there is a meaningful delta in: Goal/success criteria, Invariants/constraints, Decisions, State (Done/Now/Next), Open questions, Working set, or important tool outcomes.
- Batch continuity writes: make at most one continuity edit per major phase/decision boundary unless the user explicitly requests denser logging.
- Do **not** update `docs/CONTINUITY.md` or other `docs/` files for agent-infrastructure-only changes (for example: `.agent/*`, `.claude/*`, `AGENTS.md`, `CLAUDE.md`) unless those changes materially affect BetterUI addon behavior or development outcomes.

### Write Cadence (Troubleshooting + Trial/Error)
- Keep continuity read-only during active debugging/trial-and-error loops.
- Do not update continuity for each attempt, failed command, temporary hypothesis, or intermediate rollback.
- Use chat checkpoints (`Done / Now / Next`) for interim progress.
- Write continuity only on durable milestones: validated fix/decision, phase completion, workflow handoff, or session closeout.
- When multiple milestones occur close together, batch them into one concise continuity update.

### Keep It Bounded (Anti-Bloat)
- Keep `docs/CONTINUITY.md` short and high-signal:
  - `Snapshot`: ≤ 25 lines.
  - `Done (recent)`: ≤ 12 bullets.
  - `Working set`: ≤ 12 paths.
  - `Receipts`: keep last 10–20 entries.
- Receipt style target: concise one-line entries; prefer milestone compression + commit pointers over narrative detail.
- If sections exceed caps, compress older items into milestone bullets with pointers (commit/PR/log path/doc path). Do not paste raw logs.

### Anti-Drift Rules
- Facts only, no transcripts.
- Every entry must include:
  - a date or ISO timestamp (e.g., `2026-01-13` or `2026-01-13T09:42Z`)
  - a provenance tag: `[USER]`, `[CODE]`, `[TOOL]`, `[ASSUMPTION]`
- If unknown, write `UNCONFIRMED` (never guess). If something changes, supersede it explicitly (don't silently rewrite history).

### Decisions and Incidents
- Record durable choices in `Decisions` as ADR-lite entries (e.g., `D001 ACTIVE: …`).
- For recurring weirdness, create a small, stable incident capsule (Symptoms / Evidence pointers / Mitigation / Status).

### Session Compaction Recovery (Required)
- If context was compacted, resumed, or partially lost, do **not** continue from memory.
- Use this tiered recovery sequence to minimize quota/tool cost:
  - **Tier 1 (always first):** run a freshness fingerprint:
    - `git rev-parse --abbrev-ref HEAD`
    - `git rev-parse --short HEAD`
    - `git status --short`
    - re-read active workflow doc
    - optional fast path: `pwsh -File tools/context_health_check.ps1`
  - **Tier 2 (if state is still unclear):** `git diff --name-only HEAD` + `rg --files -g "implementation_plan.md" -g "critical_code_review.md" -g "sr_engineering_team_review.md"` + `rg -n "^\*\*Done|^\*\*Now:|^\*\*Next:|^## Working Set|^## Open Questions" docs/CONTINUITY.md`
  - **Tier 3 (fallback only):** `rg --files -g "*task*.md" -g "*todo*.md"`
- After recovery, restate a concise checkpoint before continuing:
  - `Done:` [last completed gate/phase]
  - `Now:` [current step being executed]
  - `Next:` [immediate next gate/phase]
- If any ambiguity remains (workflow mismatch, changed-file mismatch, unresolved findings), ask the user to confirm before proceeding.

### Context Freshness Protocol (Long Sessions)
- Treat context as **stale-risk** when any is true:
  - session resumed/compacted
  - workflow switched mid-session
  - long idle gap (`UNCONFIRMED`: ~30+ min) before next major action
  - large scope change (diff/file-count jumps unexpectedly)
- Before major actions in stale-risk state, run Tier 1 fingerprint and re-anchor to:
  - active workflow step
  - `docs/CONTINUITY.md` (`Done/Now/Next`, `Working set`, `Open questions`)
  - active diff file list
- Re-anchor before editing files last read long ago: re-open the target file or run targeted `rg -n` to confirm current symbols/lines.
- Emit compact checkpoints during long runs: `Done / Now / Next` after each major step.

### Continuity Health Check (Drift Control)
- On long sessions, ensure `docs/CONTINUITY.md` still respects cap rules (`Done ≤12`, `Working set ≤12`, `Receipts ≤20`).
- If caps are exceeded, compress oldest history into milestone bullets with date/provenance preserved.
- Prefer one compact consolidation over many micro-edits to keep continuity stable and low-noise.

### Quota Efficiency Defaults
- Default to diff-first execution: inspect `git diff --name-only HEAD` and touched files before broad scans.
- Default workflow scope is incremental/changed-files; use full-repo modes only when explicitly requested or clearly high-risk.
- Prefer targeted reads/search (`rg -n` on specific paths) before whole-file scans.
- Reuse existing artifacts only when they reduce rework; do not regenerate large artifacts without unresolved findings.
- Avoid duplicate review gates for the same checkpoint; run the minimum gate needed for that phase.
- Keep outputs compact (findings first, concise summaries).
- After each major step, emit a concise checkpoint: `Done / Now / Next`.

### Agent Operating Loop (Default)
- Use this loop for every task to balance recall quality with low quota:
  1. **Anchor**: read `docs/CONTINUITY.md` and classify task type (edit/review/docs/investigation).
  2. **Scope**: determine minimal file set from active diff + user request.
  3. **Load**: read only required workflow/skill docs for the current step (lazy-load, do not preload all workflows).
  4. **Execute**: make scoped changes or analysis.
  5. **Verify**: run smallest sufficient checks first; escalate only when risk demands.
  6. **Checkpoint**: emit `Done / Now / Next` each major step; update continuity only on durable milestones with meaningful addon-state deltas.
- For long sessions, repeat **Anchor + Scope** before each major phase or after idle gaps.
- If stale-risk is high, run `tools/context_health_check.ps1` once per major phase (not every turn).

### Artifact Lifecycle (Quota + Hygiene)
- Canonical names (use only when needed):
  - `implementation_plan.md`
  - `critical_code_review.md`
  - `sr_engineering_team_review.md`
- Create artifacts only for multi-phase work, broad audits, or when the user explicitly asks for persisted reports.
- For small/medium tasks, keep plans and reviews inline instead of creating files.
- Do not commit temporary artifacts unless explicitly requested.

---

## Project Context

**Project:** BetterUI - Elder Scrolls Online addon for enhanced gamepad UI

**Tech Stack:**
- Lua 5.1 (use `luac -p` for syntax validation)
- XML for UI templates
- ESO API (see `esoui/` reference folder - read-only, never modify)

**Key Directories:**
| Path | Purpose |
|------|---------|
| `Modules/CIM/` | Common Interface Module - all shared code goes here |
| `Modules/Banking/` | Banking scene and features |
| `Modules/Inventory/` | Inventory scene and features |
| `Modules/ResourceOrbFrames/` | Resource orbs and skill bar UI |
| `Modules/WritUnit/` | Writ crafting assistance |
| `esoui/` | ESO base game UI reference (read-only, never modify) |
| `docs/` | Architecture, tribal knowledge, changelog |
| `.agent/skills/` | Project-specific agent skills |
| `.agent/workflows/` | Project automation workflows |

---

## Skills Reference

| Skill | When to Use |
|-------|-------------|
| `betterui-development-guidelines` | **Always** - Lua/XML standards, documentation, verification |
| `betterui-sr-engineering-team` | Before executing plans, after each phase, quality gates |

**Global skills** (from user's skill library):
| Skill | When to Use |
|-------|-------------|
| `brainstorming` | Before creating new features |
| `writing-plans` | Before touching code on multi-step tasks |
| `verification-before-completion` | Before claiming any task is complete |
| `systematic-debugging` | When encountering bugs or test failures |

---

## Workflows Reference

| Workflow | Description |
|----------|-------------|
| `/sr-review-gate` | **REQUIRED** review gate. Default = bugfix/adhoc review; use `--plan-review` for plans and `--phase-review` for phase gates |
| `/verify-integrity` | Pre-commit checks (tests, debug scan, syntax) |
| `/wrap-up` | End-of-session closeout: AGENTS compliance, sr-review-gate, verify-integrity, fix loops, and commit |
| `/update-changelog` | Build upcoming release notes from full commit history since the last changelog update, excluding internal dev-cycle fix churn |
| `/update-tribal-knowledge` | Capture session learnings |
| `/code-review` | Diff-first review by default; full codebase audit only for explicit deep-review requests |
| `/garbage-cleanup` | Dead code and orphaned file detection |
| `/lang-audit` | Localization audit with changed-file fast path; full sync/audit optional |
| `/review-todos` | Prioritize outstanding TODOs |
| `/scaffold-module` | Create new module structure |
| `/feature-requests` | Targeted esoui gap scan by default; expanded scan only when requested |

---

## Cross-IDE Bridge Notes

For Claude/Codex compatibility when following `.agent/` workflows:

### Tool Name Mapping

| Antigravity Tool | Claude/Codex Equivalent |
|---|---|
| `find_by_name` | file glob / recursive file listing |
| `grep_search` | `rg` content search (preferred) |
| `view_file` / `view_file_outline` | file read / outline scan |
| `replace_file_content` / `multi_replace_file_content` | file edit / patch |

### Global Skills Availability

Some global skills may not be mounted in all IDEs (`brainstorming`, `writing-plans`, `verification-before-completion`, `systematic-debugging`).

When unavailable, apply equivalent reasoning directly and continue with the workflow.

---

## Documentation Reference

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Module structure, patterns, design |
| [TRIBAL_KNOWLEDGE.md](docs/TRIBAL_KNOWLEDGE.md) | ESO API quirks, gotchas, lessons learned |
| [TESTING.md](docs/TESTING.md) | Test infrastructure and patterns |
| [EVENTS.md](docs/EVENTS.md) | Custom event system documentation |

---

## Command Permissions

These commands **do not require user approval** and can be auto-run:
- `rg` - Searching file contents (preferred)
- `grep` - Legacy content search
- `luac` - Lua syntax validation
- `git rev-parse` - Branch/commit fingerprinting
- `pwsh -File tools/context_health_check.ps1` - Optional stale-context health snapshot
- `git status` - Working tree snapshot
- `git add` - Staging files
- `git commit` - Creating commits
- `git checkout` - Switching branches or restoring files
- `git diff` - Viewing changes

**Feature branches:** For substantial refactors, create feature branch off `develop`:
```bash
git checkout develop && git checkout -b feature/<descriptive-name>
```
