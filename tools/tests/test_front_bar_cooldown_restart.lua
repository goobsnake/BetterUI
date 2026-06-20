--[[
File: tools/tests/test_front_bar_cooldown_restart.lua
Purpose: Unit tests for the HUD-005 front-bar radial cooldown restart logic in
         Modules/ResourceOrbFrames/SkillBar/FrontBarCooldowns.lua. The radial
         must (re)start when a new cooldown window begins — a duration change OR
         a same-duration refresh where the remaining time jumps back up — while
         a normal per-frame countdown must NOT restart it (no per-tick churn).

Usage:
  lua tools/tests/test_front_bar_cooldown_restart.lua
]]

-- Minimal stub: the module only needs BETTERUI.ResourceOrbFrames.Utils to be a
-- table at load time; the functions under test are pure / control-driven.
BETTERUI = { ResourceOrbFrames = { Utils = {} } }

dofile("Modules/ResourceOrbFrames/SkillBar/FrontBarCooldowns.lua")

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
local ShouldRestart = SkillBar.ShouldRestartRadialCooldown
local StartCooldownIfChanged = SkillBar.StartCooldownIfChanged

local passed, failed = 0, 0
local function check(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s",
            label, tostring(expected), tostring(actual)))
    end
end

assert(type(ShouldRestart) == "function", "ShouldRestartRadialCooldown must be exported")
assert(type(StartCooldownIfChanged) == "function", "StartCooldownIfChanged must be exported")

print("[ShouldRestartRadialCooldown]")
-- New window: no prior duration applied -> restart.
check(ShouldRestart(nil, nil, 4000, 4000), true, "first window starts the radial")
-- Duration change -> restart.
check(ShouldRestart(4000, 1000, 6000, 6000), true, "duration change restarts the radial")
-- Normal countdown (remaining decreasing) -> no restart.
check(ShouldRestart(4000, 4000, 4000, 3984), false, "per-frame countdown does not restart")
check(ShouldRestart(4000, 2000, 4000, 1980), false, "mid-countdown does not restart")
-- Same-duration refresh (remaining jumps back up) -> restart (HUD-005).
check(ShouldRestart(4000, 500, 4000, 4000), true, "same-duration refresh restarts the radial")
-- Upward jitter within the +100ms margin -> no restart (no per-tick churn).
check(ShouldRestart(4000, 2000, 4000, 2050), false, "sub-threshold upward jitter does not restart")
check(ShouldRestart(4000, 2000, 4000, 2100), false, "exactly +100ms does not restart")
check(ShouldRestart(4000, 2000, 4000, 2101), true, "just over +100ms restarts")
-- applied == duration but no last-seen yet -> conservative no restart.
check(ShouldRestart(4000, nil, 4000, 4000), false, "matching duration with no last-seen does not restart")

print("[StartCooldownIfChanged]")
local function NewCooldown()
    return {
        starts = {},
        StartCooldown = function(self, remain, duration)
            self.starts[#self.starts + 1] = { remain = remain, duration = duration }
        end,
    }
end

do
    local cd = NewCooldown()
    StartCooldownIfChanged(cd, 4000, 4000)
    check(#cd.starts, 1, "first call starts the radial")
    check(cd.appliedCooldownDurationMs, 4000, "applied duration latched on start")
    check(cd.lastSeenCooldownRemainMs, 4000, "last-seen remaining latched on start")

    StartCooldownIfChanged(cd, 3984, 4000)
    StartCooldownIfChanged(cd, 2000, 4000)
    check(#cd.starts, 1, "countdown frames do not restart")
    check(cd.lastSeenCooldownRemainMs, 2000, "last-seen tracks the latest tick during countdown")

    StartCooldownIfChanged(cd, 4000, 4000)
    check(#cd.starts, 2, "same-duration refresh restarts the radial (HUD-005)")
    check(cd.starts[2].remain, 4000, "restart uses the refreshed remaining time")

    StartCooldownIfChanged(cd, 6000, 6000)
    check(#cd.starts, 3, "duration change restarts the radial")
end

do
    -- After a reset (ended/gamepad branch clears the latch), the next window restarts.
    local cd = NewCooldown()
    StartCooldownIfChanged(cd, 4000, 4000)
    cd.appliedCooldownDurationMs = nil
    cd.lastSeenCooldownRemainMs = nil
    StartCooldownIfChanged(cd, 4000, 4000)
    check(#cd.starts, 2, "recast after a reset restarts the radial")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
