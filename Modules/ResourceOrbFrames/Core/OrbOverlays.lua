--[[
File: Modules/ResourceOrbFrames/Core/OrbOverlays.lua
Purpose: Overlay-specific sizing helpers for resource orbs.
         Layout, pool setup, and shield setup are defined canonically in OrbVisuals.lua,
         which is loaded immediately before this file (BetterUI.txt lines 124-125).
]]

-- OrbOverlays previously re-defined Visuals.UpdateOrbLayout, Visuals.SetupPowerPools,
-- and Visuals.SetupShieldBar on the shared BETTERUI.ResourceOrbFrames.Visuals namespace.
-- Because this file loads after OrbVisuals.lua, those definitions silently overwrote the
-- more-complete canonical implementations in OrbVisuals.lua (which include the ornament-nil
-- fallback anchors and BETTERUI_SHIELD_DEBUG flag).
-- Those definitions have been removed. All callers now use the OrbVisuals.lua versions.

-- The hide-ornament CustomOverlay path (Health.dds/MagStam.dds) and its sizing helper were
-- also removed: those texture assets never shipped, so the overlay could only render
-- missing-texture placeholders. Only OrbOverlay_Shield.dds remains in use (OrbVisuals.lua).
