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
- Update `docs/CONTINUITY.md` only when there is a meaningful delta in: Goal/success criteria, Invariants/constraints, Decisions, State (Done/Now/Next), Open questions, Working set, or important tool outcomes.
- Do **not** update `docs/CONTINUITY.md` or other `docs/` files for agent-infrastructure-only changes (for example: `.agent/*`, `.claude/*`, `AGENTS.md`, `CLAUDE.md`) unless those changes materially affect BetterUI addon behavior or development outcomes.

### Keep It Bounded (Anti-Bloat)
- Keep `docs/CONTINUITY.md` short and high-signal:
  - `Snapshot`: ≤ 25 lines.
  - `Done (recent)`: ≤ 7 bullets.
  - `Working set`: ≤ 12 paths.
  - `Receipts`: keep last 10–20 entries.
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
  - **Tier 1 (always first):** `git status --short` + re-read active workflow doc
  - **Tier 2 (if state is still unclear):** `git diff --name-only HEAD` + `rg --files -g "implementation_plan.md" -g "critical_code_review.md" -g "sr_engineering_team_review.md"`
  - **Tier 3 (fallback only):** `rg --files -g "*task*.md" -g "*todo*.md"`
- After recovery, restate a concise checkpoint before continuing:
  - `Done:` [last completed gate/phase]
  - `Now:` [current step being executed]
  - `Next:` [immediate next gate/phase]
- If the restored state remains ambiguous, ask the user to confirm before proceeding.

### Quota Efficiency Defaults
- Use the smallest sufficient workflow scope by default; expand only when needed.
- Prefer targeted reads/search (`rg -n` on specific paths) before whole-file scans.
- Reuse existing artifacts (`implementation_plan.md`, review reports) instead of regenerating from scratch.
- Avoid duplicate review gates for the same checkpoint; run the minimum gate needed for that phase.
- After each major step, emit a concise checkpoint: `Done / Now / Next`.

### Canonical Workflow Artifacts
- `implementation_plan.md`
- `critical_code_review.md`
- `sr_engineering_team_review.md`

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
| `/code-review` | Full codebase audit with TODOs or fixes |
| `/garbage-cleanup` | Dead code and orphaned file detection |
| `/lang-audit` | Localization file synchronization |
| `/review-todos` | Prioritize outstanding TODOs |
| `/scaffold-module` | Create new module structure |

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
- `git add` - Staging files
- `git commit` - Creating commits
- `git checkout` - Switching branches or restoring files
- `git diff` - Viewing changes

**Feature branches:** For substantial refactors, create feature branch off `develop`:
```bash
git checkout develop && git checkout -b feature/<descriptive-name>
```
