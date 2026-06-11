# Feature Requests Backlog

Last Updated: 2026-06-10
Status: Active

This document tracks durable BetterUI feature gaps and parity opportunities discovered from ESO gamepad workflow audits.

## Intake Rules

- Log one durable request per row with a stable ID.
- Keep entries scoped to product capability gaps, not transient bugs or outages.
- Include clear impact, effort, and priority so sequencing is objective.
- Move items to `Closed` only after code, docs, and in-game validation are complete.

## Entry Template

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Inventory and Companion

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Banking and Economy

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `ECO-001` | 2026-05-29 | Currency display | Add Archival Fortunes to the currency display options | Medium | Low | P2 | **Completed** | ESOUI comment (oddavi, 05/29/26). Infinite Archive currency (`CURT_ARCHIVAL_FORTUNES`); add to the currency rows/toggles wherever existing optional currencies (Tel Var, Transmute, etc.) are offered. |

## Trading and Crafting

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `TRC-001` | 2026-04-11 | Market integration | Show market price data on crafting and improvement pages (TTC 4.27 parity) | Medium | Medium | P2 | **Completed** | ESOUI comment (Edricson, 04/11/26). TTC 4.27 added price data to crafting/improvement screens; extend BUI market integration (ATT/MM/TTC via `MarketIntegration.lua`) to gamepad crafting/improvement panels. |

## Social and Guild

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## World and Group Systems

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Accessibility and Platform

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## HUD and Frames

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `HUD-001` | 2026-04-10 | Resource orbs / action bar | Allow moving resource orbs independently from the action bar (at minimum, independent orb offsets) | High | High | P2 | **Completed** | ESOUI comments (Loliam 04/10/26, Vo1se 05/10/26). Orbs and bars are currently anchored as one frame group (`Modules/ResourceOrbFrames`, `PositionManager.lua`); author previously replied "whole UI frames move together". Requested repeatedly. |

_Open feature-request inventory cleared on 2026-04-16 per product decision. Historical closed items remain below._

## Closed

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-000` | 2026-02-08 | Inventory/Banking | Expose stack consolidation (`Stack All`) in keybind flows | High | Low | `Closed` | Closed | Implemented in Inventory and Banking keybind managers. |

## Recommended Implementation Order

1. `ECO-001` Archival Fortunes currency display (low effort, isolated).
2. `TRC-001` TTC/market prices on crafting and improvement pages.
3. `HUD-001` Independent orb/action-bar positioning (high effort; needs anchoring redesign).
