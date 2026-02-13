---
name: betterui-development-guidelines
description: BetterUI Lua/XML implementation standards and verification checklist. Use for BetterUI runtime coding tasks (implement/fix/refactor/settings/UI); do not use for agent-infrastructure-only or changelog-only work.
---

# BetterUI Development Guidelines

Use this skill for BetterUI runtime code changes (`Modules/`, `lang/`, `BetterUI.lua`, `BetterUI.txt`) and related technical docs.

## Trigger Phrases

- "implement/fix/refactor ... in BetterUI"
- "add/update setting/keybind/template/module"
- "clean up TODO/debug statements"
- "investigate a BetterUI behavior regression"

## Do Not Trigger

- Agent-infrastructure-only edits (`.agent/`, `.claude/`, `AGENTS.md`) unless the user explicitly requests this layer.
- Pure release-note curation (`/update-changelog`) or tribal-log capture (`/update-tribal-knowledge`) without code work.
- Non-BetterUI repositories.

## Required Context (Progressive Load)

1. `AGENTS.md` for rules and command permissions.
2. `docs/CONTINUITY.md` minimum: `Done/Now/Next`, `Open Questions`, `Working Set`.
3. Target files from active diff and user request.
4. `docs/TRIBAL_KNOWLEDGE.md` only when touching related ESO API behavior.

## Standards Checklist

- New code files stay <= 500 LOC; split logic early.
- Shared logic belongs in `Modules/CIM/`.
- No fallback masking during development.
- No empty try/catch-equivalent blocks.
- Never modify `esoui/`.
- Non-English locale updates must include real translations (no English placeholders).
- Prefer targeted `rg -n` queries and changed-file scope.

## Implementation Flow

1. Anchor and scope diff-first (`git diff --name-only HEAD`).
2. Implement with stable entrypoints and isolated logic.
3. Verify with the smallest sufficient checks first:
   - `/verify-integrity`
   - `luac -p` for changed Lua files
   - `lua tools/tests/run_all_tests.lua` when runtime behavior changed (or report why skipped)
4. Report concise outcomes and residual risks.

## Output Contract

When this skill is active, final responses must include:

- `Summary`: what changed and why
- `Validation`: exact commands run plus pass/fail
- `Risks`: unverified assumptions or required in-game checks

## Troubleshooting

- If context may be stale (resume/compaction/long gap), run AGENTS Session Compaction Recovery Tier 1 before edits.
- If scope is ambiguous or conflicts with the working tree, ask the user before implementation.
