---
description: Find and remove dead code, orphaned files, deprecated usage, and unused references from the codebase
---

# Garbage Cleanup Workflow

Dead code and orphan detection with conservative defaults.

## Defaults

- Scope default: `--core` (CIM first).
- Mode default: report only.
- Never delete anything without explicit validation.

## Modes

| Mode | Behavior |
|------|----------|
| (none) | Findings report only |
| `--plan` | Create implementation plan after review gate |

## Step 0: Scope

If session state may be stale (resume/compaction/long gap), run AGENTS Session Compaction Recovery Tier 1 first.

```powershell
/garbage-cleanup --core
/garbage-cleanup --all
```

Use `--all` only for dedicated cleanup sessions.

## Step 1: Candidate Discovery

```powershell
rg -n -i "deprecated|legacy|obsolete|remove in" Modules
```

Treat output as candidates, not facts.

## Step 2: Dead/Orphan Scans

Key checks:

- Lua files not in `BetterUI.txt`
- XML templates with no references
- Assets with no Lua/XML references
- Local/global functions with no reachable calls
- Localization/constant keys with no usage

Use `rg` first, then targeted validation.

## Step 3: Findings Report

Classify each finding with:

- Evidence (file references)
- Confidence (High/Medium/Low)
- Risk if removed
- Recommended action

## Step 4: Gate and Plan (`--plan`)

1. Run `/sr-review-gate` on findings.
2. If approved, create `implementation_plan.md`.
3. Run `/sr-review-gate --plan-review` before execution.
4. Execute in phases with `/sr-review-gate --phase-review`.

## Step 5: Verify and Commit

Run `/verify-integrity` before commit.

## Invocation

```text
/garbage-cleanup
/garbage-cleanup --all
/garbage-cleanup --plan
/garbage-cleanup --all --plan
```

