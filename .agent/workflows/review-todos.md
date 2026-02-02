---
description: Review outstanding TODOs in the codebase and prioritize the top N most beneficial to implement
---

# Review Outstanding TODOs

Analyze all TODO comments in the BetterUI codebase and prioritize the most impactful ones for implementation.

## Parameters

- **Count**: Number of top TODOs to surface (default: 10)
  - Usage: `/review-todos 5` or `/review-todos 20`
  - If no number specified, defaults to 10

---

## Step 1: Gather All TODOs

Search the codebase for TODO, FIXME, HACK, and XXX comments:

// turbo
```powershell
cd x:\Git\BetterUI && rg -n "TODO|FIXME|HACK|XXX" --type lua --type xml -g "!.agent/*" -g "!tools/*"
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

## Step 4: Optional - Create Implementation Plan

For any TODO the user wants to address:
1. Use `/writing-plans` skill to create implementation plan
2. Execute via standard development workflow

---

## Output Format

Provide a markdown table with:
- File and line number (linked)
- Full TODO text
- Impact/effort assessment
- Brief recommendation

Flag any TODOs that appear outdated or already resolved.
