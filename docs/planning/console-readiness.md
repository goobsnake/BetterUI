# Console Readiness Track (PLT-001)

This document tracks the requirements and considerations for making BetterUI
ready for potential console distribution or mod-browser packaging.

## Current Status: **Planning Phase**

BetterUI is currently a PC addon loaded via the Elder Scrolls Online addon system.
Console readiness requires addressing multiple packaging and compatibility concerns.

## Requirements Checklist

### Packaging & Footprint
- [ ] Audit total addon file size and texture asset weight
- [ ] Identify and remove development-only files from distribution
- [ ] Minimize manifest includes (lazy-load modules where possible)
- [ ] Create a release build pipeline that strips debug commands

### API Compatibility
- [ ] Audit all ESO API calls for console-specific restrictions
- [ ] Verify no PC-only APIs are used without fallbacks (`GetMousePosition`, etc.)
- [ ] Test with gamepad-only input (no mouse/keyboard assumptions)
- [ ] Ensure all text input paths have gamepad-compatible alternatives

### Input Model
- [ ] Verify all keybinds use gamepad-compatible mappings
- [ ] Ensure no features depend on mouse hover events
- [ ] Test d-pad navigation flow through all BetterUI screens
- [ ] Validate scroll indicator behavior on all parametric lists

### Performance
- [ ] Profile memory usage across all modules
- [ ] Verify batch processing doesn't cause frame drops on console hardware
- [ ] Test with large inventories (200+ items) on constrained environments

### Localization
- [ ] Ensure all strings use SI_ constants (no hardcoded English)
- [ ] Verify text fits within console-resolution UI elements
- [ ] Test with non-Latin character sets (Japanese, Korean)

## Architecture Notes

BetterUI's modular structure (`Modules/*/Module.lua`) makes selective
deployment feasible. A minimal console build could include:

- **Core CIM** (required)
- **Inventory** (highest user value)
- **Banking** (second highest)

With optional modules (ResourceOrbFrames, WritUnit, TradingHouse, etc.)
as add-on packs.
