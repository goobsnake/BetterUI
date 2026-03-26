# BetterUI Test Utilities

## Syntax validation

Run from the repository root:

```bash
bash tools/tests/run_syntax_check.sh
```

This checks that every Lua file under `Modules/` compiles with `luac -p` and reports syntax errors.

## Manifest validation

Run from the repository root:

```bash
bash tools/tests/validate_manifest.sh
```

This checks each entry in `BetterUI.txt` and prints `MISSING: <path>` for files that are referenced but not present on disk.

## Current coverage status

Current automated coverage is approximately **41%**.

## Planned next steps

- Add focused unit tests for banking action filtering and dialog callback behavior.
- Add CI wiring to run syntax and manifest checks on every change.
- Expand module-level Lua test suites under `tools/tests/` for higher behavioral coverage.
