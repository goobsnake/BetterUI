--[[
File: tools/tests/test_inventory_id64_normalizer_source.lua
Purpose: Source contract / regression lock. Every uniqueId stringification in the
         Inventory module MUST route through the safe Id64 normalizer
         (BETTERUI.*.Utils.NormalizeIdentityValue = type-check + pcall(Id64ToString)),
         NEVER a raw Id64ToString(...) -- which RAISES on a quest item's synthetic STRING
         uniqueId (e.g. "quest:1:2:1:"). That raw call at InventoryClass.lua:263 aborted
         SetSelectedInventoryData before the item-action/keybind refresh, leaving the
         PREVIOUS item's keybinds on quest rows and spamming ~3-4 native errors/sec
         (surfaced by the live-log playtest). StatComparison.lua:239 was the latent twin.
         This test fails the instant a raw Id64ToString( is reintroduced.
Usage:   lua tools/tests/test_inventory_id64_normalizer_source.lua
]]

local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1
    else failed = failed + 1; io.stderr:write("FAIL: " .. label .. "\n") end
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

print("\n=== Inventory Id64 normalizer source contract ===\n")

-- PRIMARY (dependable, no external tools): the two sites this bug was found at must now
-- use the normalizer and contain NO raw Id64ToString( call.
for _, path in ipairs({
    "Modules/Inventory/Core/InventoryClass.lua",
    "Modules/Inventory/Core/StatComparison.lua",
}) do
    local src = readFile(path)
    check(src ~= nil, path .. " is readable")
    if src then
        -- A raw call is `Id64ToString(` (the comment/pcall forms `Id64ToString RAISES` and
        -- `pcall(Id64ToString, ...)` do NOT have a '(' immediately after the name).
        check(src:find("Id64ToString%s*%(") == nil,
            path .. " has NO raw Id64ToString( call (must route through NormalizeIdentityValue)")
        check(src:find("NormalizeIdentityValue") ~= nil,
            path .. " references the safe NormalizeIdentityValue helper")
    end
end

-- BONUS (best-effort, repo-wide): no .lua under Modules/ should make a raw Id64ToString(
-- direct call. The canonical guards (CIM/Core/Utilities.lua, Batching/MultiSelectManager)
-- use pcall(Id64ToString, ...), which does not match this pattern. Skipped silently if
-- grep is unavailable in the harness.
local h = io.popen("grep -rn --include=*.lua 'Id64ToString(' Modules 2>/dev/null")
if h then
    local out = h:read("*a") or ""
    h:close()
    if out ~= "" then
        failed = failed + 1
        io.stderr:write("FAIL: raw Id64ToString( direct call(s) remain under Modules/ -- route through NormalizeIdentityValue:\n" .. out .. "\n")
    else
        passed = passed + 1
        print("  [OK] repo-wide: no raw Id64ToString( direct calls under Modules/")
    end
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
print("All tests passed!")
