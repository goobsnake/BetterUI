---
description: Scaffold a new BetterUI module with minimal structure and manifest wiring. Default is lean skeleton-only scaffolding.
---

# Scaffold Module Workflow

Create new modules with the smallest maintainable footprint, then expand only when feature scope demands it.

## Defaults

- Default mode is `--minimal`.
- Reuse existing BetterUI module patterns; do not generate decorative boilerplate.
- Keep new files modular-first and avoid unnecessary folders.

## Inputs

- `ModuleName` (required, PascalCase): `/scaffold-module QuestTracker`
- `--minimal` (default): create only required files/folders.
- `--extended`: add optional folders for known near-term needs.

## Stop Conditions

- `Modules/{ModuleName}` already exists and overwrite was not requested.
- `ModuleName` is not PascalCase.
- Requested structure conflicts with AGENTS modularity or load-order rules.

## Step 0: Context Guard

If session context may be stale (resume/compaction/long gap), run AGENTS Session Compaction Recovery Tier 1 first.

## Step 1: Create Base Structure

Required:

- `Modules/{ModuleName}/Constants.lua`
- `Modules/{ModuleName}/Module.lua`
- `Modules/{ModuleName}/Core/`

Optional (`--extended` only, or explicit need):

- `UI/`, `Lists/`, `Actions/`, `Keybinds/`, `State/`, `Settings/`, `Templates/`, `Images/`

## Step 2: Add Lean File Skeletons

Use canonical namespace:

- `BETTERUI.{ModuleName}`
- `BETTERUI.{ModuleName}.CONST`

`Constants.lua` should define only:

- module identity constants
- a minimal timing/config table when needed

`Module.lua` should define only:

- `Setup()`
- `Init()`

Do not add placeholder logic that is not immediately required.

## Step 3: Wire Manifest (`BetterUI.txt`)

Add in correct order (after CIM, before dependent feature modules):

- `Modules/{ModuleName}/Constants.lua`
- `Modules/{ModuleName}/Module.lua`

Manifest ordering is required: constants before module entrypoint.

## Step 4: Register Setup (`BetterUI.lua`)

Add guarded setup call in addon initialization path:

- `if BETTERUI.{ModuleName} then BETTERUI.{ModuleName}.Setup() end`

Place it with module setup block ordering conventions already used by BetterUI.

## Step 5: Verify

- `luac -p` for any newly created Lua files.
- `git diff --name-only HEAD` to confirm only expected scaffold paths changed.
- Run `/verify-integrity` if runtime paths were modified beyond basic scaffolding.

## Output Contract

Return:

- `Created`: exact paths created
- `Updated`: exact files modified (`BetterUI.txt`, `BetterUI.lua`, etc.)
- `Validation`: commands run and pass/fail
- `Follow-up`: first implementation step to start feature work

## Invocation

```text
/scaffold-module ModuleName
/scaffold-module ModuleName --minimal
/scaffold-module ModuleName --extended
```

