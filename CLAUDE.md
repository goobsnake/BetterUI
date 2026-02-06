# BetterUI - Claude Code Configuration

> Dual-IDE project: Antigravity IDE uses `AGENTS.md` + `.agent/`.
> This file bridges that configuration to Claude Code.

## On Session Start

1. Read `AGENTS.md` for project rules, context, and workflow references
2. Read `docs/CONTINUITY.md` for current session state

## Available Project Skills

These skills exist in `.agent/skills/` and are available:

| Skill | When to Use |
|-------|-------------|
| `betterui-development-guidelines` | **Always** - Lua/XML standards, verification |
| `betterui-sr-engineering-team` | Reviews, quality gates, phase approvals |

## Tool Name Mapping

When following `.agent/` workflows, translate Antigravity tool names:

| Antigravity Tool | Claude Code Equivalent |
|---|---|
| `find_by_name` | `Glob` |
| `grep_search` | `Grep` |
| `view_file` / `view_file_outline` | `Read` |
| `replace_file_content` / `multi_replace_file_content` | `Edit` |

> [!NOTE]
> This mapping applies globally. Individual commands don't repeat it.

## Unavailable in Claude Code

Global skills from `%USERPROFILE%\.gemini\antigravity\skills\` are not available:
- `brainstorming`, `writing-plans`, `verification-before-completion`, `systematic-debugging`

Apply equivalent reasoning directly when workflows reference these skills.

## Available Commands

| Command | Maps to |
|---|---|
| `/verify-integrity` | `.agent/workflows/verify-integrity.md` |
| `/sr-review-gate` | `.agent/workflows/sr-review-gate.md` |
| `/update-tribal-knowledge` | `.agent/workflows/update-tribal-knowledge.md` |
| `/code-review` | `.agent/workflows/comprehensive-code-review.md` |
| `/garbage-cleanup` | `.agent/workflows/garbage-cleanup.md` |
| `/lang-audit` | `.agent/workflows/lang-audit.md` |
| `/review-todos` | `.agent/workflows/review-todos.md` |
| `/scaffold-module` | `.agent/workflows/scaffold-module.md` |
