---
description: End-of-session closeout workflow that enforces AGENTS compliance, zero-deferral review/integrity loops, and final commit hygiene
---

# Wrap-Up Workflow

Use this workflow at the end of an implementation session to ensure all work is reviewed, verified, fixed, and committed without deferrals.

## Prerequisites

See `AGENTS.md` for project rules and `docs/CONTINUITY.md` for current session state.

---

## Non-Negotiable Rules

1. **No deferrals**: Findings from review or verification must be fixed in this session.
2. **No skip path**: Do not bypass `sr-review-gate` or `verify-integrity`.
3. **No commit until clean**: Commit only after all checks pass.

---

## Step 0: Reconfirm Session Baseline

Before closing work, re-read:
1. `AGENTS.md`
2. `docs/CONTINUITY.md`
3. `docs/TRIBAL_KNOWLEDGE.md`

Confirm active changes with:

```powershell
git status --short
```

---

## Step 1: AGENTS.md Compliance Check

Validate the current change set against AGENTS requirements:

1. No new code file exceeds 500 LOC (modular-first rule), existing files ignore this limit.
2. No empty try/catch-equivalent blocks or fallback masking patterns.
3. No temporary review/plan artifacts intended for cleanup.
4. Docs updates are addon-focused only.

If any issue is found, fix it immediately before continuing.

---

## Step 2: Sr. Review Gate (Default Adhoc/Bugfix Mode)

Run:

```text
Follow /sr-review-gate
```

This is a code-review gate for the current work (bugfix/adhoc/default mode).

### Resolution Loop (Mandatory)

If review findings exist:
1. Fix every finding immediately.
2. Re-run `/sr-review-gate`.
3. Repeat until full PASS.

No TODO deferrals, no "follow-up later" for review findings.

---

## Step 3: Verify Integrity (Full)

After `sr-review-gate` passes, run:

```text
Follow /verify-integrity --full
```

### Resolution Loop (Mandatory)

If integrity checks fail:
1. Fix every failing check immediately (tests, debug scan, XML/Lua validation, etc.).
2. Re-run `/verify-integrity --full`.
3. Repeat until all checks PASS.

No deferrals are allowed.

---

## Step 4: Final Cleanup and Required Updates

Before commit:

1. Remove temporary artifacts (`critical_code_review.md`, `sr_engineering_team_review.md`, `implementation_plan.md`) if present.
2. Apply AGENTS-directed file updates when applicable:
   - Update `docs/CONTINUITY.md` only for meaningful addon development deltas.
   - Do not update continuity/docs for agent-infrastructure-only changes unless they materially affect addon development outcomes.
   - Update `docs/TRIBAL_KNOWLEDGE.md` only when durable implementation learnings were discovered.

---

## Step 5: Commit

Once review + integrity + cleanup are all clean:

1. Stage all intended changes.
2. Create one commit that reflects the completed work.
3. Use a commit message that summarizes what was fixed/changed.

Example:

```powershell
git add -A
git commit -m "chore(workflows): add wrap-up flow and default adhoc sr-review-gate mode"
```

---

## Step 6: Final Wrap-Up Report

Provide a concise session closeout summary:

| Item | Result |
|------|--------|
| AGENTS Compliance | PASS/FAIL |
| Sr. Review Gate | PASS/FAIL |
| Verify Integrity | PASS/FAIL |
| Deferrals | None |
| Commit | `<hash>` + message |

If any row is FAIL, do not claim wrap-up complete.

---

## Quick Invocation

```text
/wrap-up
```
