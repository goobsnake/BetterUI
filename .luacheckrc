-- BetterUI luacheck configuration
-- ESO addon: suppress undefined globals (entire ESO API is injected at runtime)
std = "lua51"

-- ESO addons define and access hundreds of game-engine globals
-- Suppress all global-related warnings as false positives
allow_defined = true
allow_defined_top = true

ignore = {
    "1",    -- all global-variable warnings (1xx series)
    "212",  -- unused argument (ESO event handlers always pass eventCode)
    "213",  -- unused loop variable
    "542",  -- empty if branch
}

max_line_length = false
max_code_line_length = false

exclude_files = {
    "Source/Legacy/**",
    "tools/tests/**",
    ".desloppify/**",
    "docs/**",
}
