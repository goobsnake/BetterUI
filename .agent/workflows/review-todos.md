---
description: Review outstanding TODOs in the codebase and prioritize the top N most beneficial to implement
---

# Review Outstanding TODOs

Analyze all TODO comments in the BetterUI codebase and prioritize the most impactful ones for implementation.

## Parameters

- **Count**: Number of top TODOs to surface (default: 10)
  - Usage: `/review-todos 5` or `/review-todos 20`
  - If no number specified, defaults to 10

- **--plan**: Create an implementation plan for the top TODOs
  - Usage: `/review-todos --plan` or `/review-todos 5 --plan`
  - When specified, proceed to Step 4 after generating the prioritized list
  - Without this flag, stop after Step 3

---

## Step 1: Gather All TODOs

Search the codebase for TODO, FIXME, HACK, and XXX comments in **BetterUI source code only**.

> [!NOTE]
> - `rg` (ripgrep) is NOT installed on this system. Use `grep` instead.
> - The search excludes: `esoui/` (base game), `.agent/`, `tools/`, and other `.gitignore` patterns.

// turbo
```powershell
cd x:\Git\BetterUI && grep -rn --include="*.lua" --include="*.xml" -E "TODO|FIXME|HACK|XXX" . | grep -v "^./esoui/" | grep -v "^./.agent/" | grep -v "^./tools/" | grep -v "^./.idea/" | grep -v "^./.vscode/" | grep -v "^./source/"
```

---

## Step 2: Categorize and Analyze

For each TODO found, evaluate:

1. **Impact**: How significantly would this improve the codebase?
   - User-facing bugs/improvements (HIGH)
   - Code quality/maintainability (MEDIUM)
   - Minor cleanup/cosmetic (LOW)

2. **Effort**: Estimated implementation complexity
   - Quick fix (< 30 min)
   - Moderate (1-2 hours)
   - Substantial (> 2 hours)

3. **Risk**: Potential for regressions
   - Isolated change (LOW)
   - Touches shared code (MEDIUM)
   - Core system change (HIGH)

---

## Step 3: Generate Prioritized List

Output the top **{COUNT}** TODOs ranked by benefit-to-effort ratio:

| Rank | File:Line | TODO Description | Impact | Effort | Recommendation |
|------|-----------|------------------|--------|--------|----------------|
| 1 | ... | ... | HIGH | Quick | Implement immediately |
| 2 | ... | ... | ... | ... | ... |

---

## Step 4: Create Implementation Plan (requires `--plan` flag)

**Skip this step unless the `--plan` parameter was provided.**

For the top TODOs from Step 3:

1. Use the `writing-plans` skill to create an implementation plan for the prioritized TODO(s)
2. Group related TODOs together where it makes sense
3. **Before executing**, invoke the review gate:

```
Follow /sr-review-gate --plan-review
```

All 5 team members must PASS before proceeding.

4. Execute via standard development workflow
5. **After each phase completes:**

```
Follow /sr-review-gate --phase-review
```

> [!IMPORTANT]
> **Remove TODOs after implementation**: When a TODO from an implementation plan is completed, the corresponding TODO comment in the source code MUST be removed. Do not leave resolved TODOs in the codebase - they create confusion and clutter future audits.

---

## Output Format

Provide a markdown table with:
- File and line number (linked)
- Full TODO text
- Impact/effort assessment
- Brief recommendation

Flag any TODOs that appear outdated or already resolved.
