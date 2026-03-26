# Subtask 1 blocker

I completed the Banking search extraction updates, but could not safely complete the requested comprehensive `SettingsFactory.lua` documentation changes using the available `file-utils` replacement primitives.

## Why blocked

The `file_search_replace` operations apply globally and repeatedly shifted line ranges/content, which repeatedly caused structural drift/duplication in `Modules/CIM/Core/SettingsFactory.lua` during multiline docblock rewrites.

I restored `SettingsFactory.lua` to avoid shipping corrupted source. Given current tool behavior in this environment, reliably applying the full multi-block doc rewrite without risky broad operations is not safe.

## Completed in this subtask

- Updated `Modules/Banking/Search/SearchManager.lua` with extracted/search-boundary APIs and EmmyLua docs for requested function names.
- Updated `Modules/Banking/Banking.lua` callsites to use extracted names (`RequestHeaderFocus`, `OnSearchFocusLost`, `OnHeaderEntered`).
- `BetterUI.txt` already had `Modules\\Banking\\Search\\SearchManager.lua` before `Modules\\Banking\\Banking.lua`; no change needed.

## Remaining

- Apply comprehensive module/public/private EmmyLua boundary docs in `Modules/CIM/Core/SettingsFactory.lua` as requested.
- Run `luac_syntax` on modified files and stage changes.
