#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA_GLOB = "**/*.lua"
EXCLUDE_PARTS = {".desloppify", ".git", "node_modules", ".venv-desloppify", "lang", "docs", "tools/tests", "Source/Legacy"}

pattern = re.compile(r"GetString\(\s*(SI_[A-Z0-9_]+)\s*\)")

changed_files = 0
replacements = 0

for path in ROOT.glob(LUA_GLOB):
    if any(part in EXCLUDE_PARTS for part in path.parts):
        continue

    try:
        original = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    updated, count = pattern.subn(r'GetString(rawget(_G, "\1"))', original)
    if count > 0:
        path.write_text(updated, encoding="utf-8")
        changed_files += 1
        replacements += count

print(f"changed_files={changed_files}")
print(f"replacements={replacements}")
