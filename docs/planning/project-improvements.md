# Project Improvements

Last Updated: 2026-07-03
Status: Active

## Purpose

This file tracks execution-ready improvement phases and tech debt items for BetterUI.
Items are phased by dependency and risk. Completed items are migrated to `completed-improvements.md`.

## Active Phases

### BUI-TRACE-002A: Closeout — monitor core flows

All implementation phases (1–10) and the host validation/docs/review gate are complete and archived in `completed-improvements.md`. Release-only monitor checks remain and are user-assisted.

- [ ] Task: Run `/builog preset inspect` for one bank deposit+withdraw, one vendor buy+sell, one Trading House search, one settings toggle, and one `/builog privacy on` sample. (est: 5 min)
  - Expected traces include bank `requested→confirmed→list.refresh flow=bankTransfer#N`, vendor `requested→settled` with `goldDelta`, Trading House `requested→completed` with a shared `opId`, `settings.value write_before/write_after`, and redacted privacy output.

### BUI-TRACE-002B: Closeout — monitor input, combat, and digest

- [ ] Task: Run keybind, anomaly, combat/HUD, and digest checks over the same monitor session. (est: 5 min)
  - Expected traces include `event=input.keybind phase=fired` in each touched module, one forced `WARN STATE | event=anomaly phase=detected`, `resource_orbs.ultimate`, `resource_orbs.bar_swap`, `resource_orbs.cast`, and one `tools/builog-monitor/monitor.sh digest --last <n>` reviewed before release/tag.
  - Gates **release/tag only** — the branch is commit-ready on host validation alone. On success, migrate this item; on failure, record findings as a remediation phase.

### BUI-REGR-L4-VERIFY-001A: Live regression verification — bank and guild store

The host-fixable source work for guild bank, guild store, stablemaster, vendor/banking search keybinds, vendor category icon refresh, default/enhanced tooltips, quickslot placement, resource-orb global unlock, nameplate positioning, and builog flow/noise handling has been implemented and archived in `completed-improvements.md`. Remaining work is live ESO verification only.

- [ ] Task: L4 verify guild bank opens BetterUI and emits `bank.guild_scene_redirect` with either `show_fallback` or a concrete rejected-interaction reason; if no redirect trace appears, capture install-time redirect state. (est: 5 min)
- [ ] Task: L4 verify guild trader opens either BetterUI or native guild store after BetterUI bail paths; capture `trading_house.native_handoff` and `trading_house.scene` phases. (est: 5 min)

### BUI-REGR-L4-VERIFY-001B: Live regression verification — vendor flows

- [ ] Task: L4 verify stablemaster opens the BetterUI vendor scene; capture `vendor.stable_event` and final shown scene. (est: 5 min)
- [ ] Task: L4 verify vendor search retains focus while typing, scroll-exit restores full merchant category icon brightness, and Banking/Vendor sort/search exits restore the full keybind strip without needing item navigation. (est: 5 min)

### BUI-REGR-L4-VERIFY-001C: Live regression verification — tooltip and quickslot

- [ ] Task: L4 verify default-tooltip mode no longer strips the native top/equipped area after initial paint; confirm `general_interface.tooltip_stock_relayout nativeTopAreaPreserved=true`. (est: 5 min)
- [ ] Task: L4 verify enhanced-tooltip mode by hovering an equipped item, then a non-equipped item; no stale "Equipped" header may remain. (est: 5 min)
- [ ] Task: L4 verify quickslot default placement with both skill bars visible. (est: 5 min)

### BUI-REGR-L4-VERIFY-001D: Live regression verification — builog and nameplates

- [ ] Task: Re-scan a fresh builog session to confirm stale `nameplates.init` flow attribution is gone and `settings.control` no longer dominates default verbosity. (est: 5 min)
- [ ] Task: L4 verify compass/reticle positioning survives keyboard/gamepad switches and interact/non-interact prompt swaps without stale offsets or duplicate drag handles. (est: 5 min)


### BUI-CONS-001: Adopt CIM SafeGetTargetData across Vendor/TradingHouse components

Ten byte-identical local `GetTargetRowData` helpers re-implement (as a strict subset) the existing `BETTERUI.CIM.Utils.SafeGetTargetData` (`Modules/CIM/Core/Utilities.lua:277`), which also handles `.targetData`/`.selectedData`. `Vendor/Components/BuyComponent.lua` already uses the CIM path, proving the seam is load-order safe. Sites: `Vendor/Components/{Buyback:16, SellVengeance:17, FenceLaunder:16, FenceSell:16, Repair:16, Sell:16, StableTraining:12}Component.lua`, `TradingHouse/Components/{Sell:34, Listings:105, Browse:105}Component.lua`, plus an inline copy in `TradingHouse/Core/TradingHouseRuntime.lua:~200`.

- [ ] Task: Replace the 7 Vendor component locals with `BETTERUI.CIM.Utils.SafeGetTargetData(instance.list)` and delete the copies. (est: 15 min)
- [ ] Task: Replace the 3 TradingHouse component locals + the TradingHouseRuntime inline copy; run the vendor/trading-house test suites. (est: 15 min)

### BUI-CONS-002: Migrate hand-rolled Trace* wrappers to Log.MakeTracer

`BETTERUI.Log.MakeTracer{module=, feature=, category=, ...}` (`Modules/CIM/Core/Diagnostics/Log.lua:242`) already produces the standard trace closure and is adopted by newer modules (`Banking/Banking.lua:7`, `Companions/Core/CompanionsRuntime.lua:48`, Vendor). ~70 legacy local `TraceX(event, phase, data)` wrappers with the `if not (L and L.TraceEvent) then return end` guard idiom remain: ~47 across CIM+ResourceOrbFrames (e.g. `CIM/Dialogs/DialogRegistry.lua:34`, `CIM/UI/HeaderSortController.lua:48`, `ROF/SkillBar/FrontBarManager.lua:79`), 9 in TradingHouse (`TraceSell`, `TraceBrowse`, `TracePriceEntry`, ...), ~24 across Banking/Companions/Writs/Nameplates/GeneralInterface. Pure copy-paste subsets: `TraceDrag` is byte-identical in 4 ROF files (`Core/ElementDrag.lua:34`, `Settings/SettingsSubmenus.lua:14`, `ResourceOrbFrames.lua:134`, `Module.lua:82`); `TraceGeneralSetting` is duplicated in `GeneralInterface/Tooltips/SettingsHelpers.lua:16` and `Settings.lua:44`; `TraceWritState` in both Writs files.

- [ ] Task: Replace the 4 identical ROF `TraceDrag` copies with one shared tracer exposed from `ROF/Core/Utils.lua`. (est: 15 min)
- [ ] Task: Migrate GeneralInterface/Writs/Nameplates duplicated wrappers (`TraceGeneralSetting`, `TraceWritState`, `TraceWritEvent`) to `MakeTracer` or a single shared local per module. (est: 15 min)
- [ ] Task: Migrate the Banking/Companions legacy wrappers (~14 sites listed in review) to `MakeTracer`, preserving per-event category routing and `SetLastAction` behavior. (est: 25 min)
- [ ] Task: Migrate the TradingHouse and CIM/ROF bulk wrappers in mechanical batches; verify trace parity for `categories.ACTION or categories.STATE`-style selection and parse-time load order. (est: 60 min, split into per-module slices)

### BUI-CONS-003: Deduplicate GetCurrentSceneName reimplementations

13+ local copies of the `SCENE_MANAGER:GetCurrentSceneName()` pcall guard duplicate the canonical `BETTERUI.CIM.Utils.GetCurrentSceneName()` (`Modules/CIM/Core/Utilities.lua:104`). Sites include `Nameplates/Settings.lua:10`, `Nameplates/Nameplates.lua:13`, `GeneralInterface/Setup.lua:6`, `GeneralInterface/Tooltips/{CraftingPriceTooltip.lua:22, Settings.lua:36, Tooltips.lua:13}`, `Companions/Core/CompanionItemList.lua:9`, `ROF/SkillBar/FrontBarCooldowns.lua:22`, `ROF/Core/OrbEvents.lua:42`, `ROF/ResourceOrbFrames.lua:73`.

- [ ] Task: Delete the local copies and call the shared helper (optionally re-export via `ROF/Core/Utils.lua` to keep ROF's CIM surface narrow). (est: 20 min)

### BUI-CONS-004: Retire dead load-order fallback shims

Multiple modules carry `type(fn) == "function"` guards with full fallback re-implementations for helpers that are defined unconditionally by earlier manifest entries — the fallback bodies can never run. Sites: `Vendor/Core/VendorSafeExecute.lua:24-42` (fallback body of `ExecuteSafely` re-implements `CIM.SafeExecute`, which `VendorClass.lua:530` asserts present), `Vendor/Core/Lifecycle/VendorInteractionRuntime.lua:230,258-289` (`DefaultSafeCall` else-branch + local `PackResults`), `Vendor/Core/VendorKeybinds.lua:33-38,373-379` (`pcall` fallbacks), `Banking/Actions/TransferActions.lua:74-87,229-252` and `Banking/Keybinds/KeybindManager.lua:12-71` (wrappers re-implementing `BETTERUI.Banking.ReadTransferContextSnapshot` / `IsActionableTransferEntry` / `BETTERUI.Interface.*` keybind helpers), `Nameplates/Settings.lua:20-50,162-196` (Clamp/reset fallbacks), `Banking/Search/SearchManager.lua:31-33` + `Banking/Banking.lua:342-346` (search-focus else-branches).

- [ ] Task: Vendor shims — collapse `ExecuteSafely` to a thin delegator to `CIM.SafeExecute`; remove `DefaultSafeCall` else-branch and keybind pcall fallbacks. (est: 25 min)
- [ ] Task: Banking shims — delete local wrappers and call the canonical `BETTERUI.Banking.*` / `BETTERUI.Interface.*` helpers directly; also fold the "prefer GetCurrentCategoryKey() else walk bankCategories" fallback copied 4× (`BankingActions.lua:21,125`, `TransferActions.lua:120`, `BankingClass.lua:534`). (est: 25 min)
- [ ] Task: Nameplates — route both Settings reset paths through `Positioning.ResetOffsets` (removes the dead else at `Settings.lua:188-195` and the triplicated field reset); delete Clamp fallbacks. (est: 15 min)

### BUI-CONS-005: Shared secure-action-failed notifier

`NotifySecureActionFailed` is defined identically 3× and inlined 4× in Inventory: `Actions/EquipAction.lua:1`, `Keybinds/CraftBagKeybinds.lua:11`, `Module.lua:56`, inline at `Actions/ItemActionHandlers.lua:1193`, `Dialogs/InventoryDialogs.lua:51,241,267`.

- [ ] Task: Add `BETTERUI.CIM.UserNotifySecureActionFailed(context)` beside `CIM.UserNotify` in `Modules/CIM/Core/Diagnostics/SafeExecute.lua` and replace all 7 sites. (est: 20 min)

### BUI-CONS-006: CIM numeric-entry dialog builder

Banking, Inventory, and TradingHouse each hand-build near-identical gamepad numeric/slider dialogs: `Inventory/Dialogs/CraftBagQuantityDialog.lua` (ITEM_SLIDER), `Inventory/Dialogs/InventoryDialogs.lua:118-320` (split-stack slider reusing CraftBag labels), `Banking/Dialogs/QuantityDialog.lua`, `Banking/Currency/CurrencySelector.lua`, `TradingHouse/Core/PriceEntry.lua` (CurrencySelector_Gamepad), `TradingHouse/Core/TradingHouseRuntimeFlow.lua:700-850` (dual browse slider rows). Shared machinery: min/max keybinds, slider value labels, `SetupSliderKeybindHints`, confirm-callback plumbing.

- [ ] Task: Design + extract `Modules/CIM/Dialogs/NumericEntryDialog.lua` parameterized by min/max/step/labels/confirm; register via `DialogRegistry`. (est: 45 min)
- [ ] Task: Migrate one consumer (Banking QuantityDialog) as the pilot, then the remaining dialogs in follow-up slices with per-module test runs. (est: 45 min, sliced)

### BUI-CONS-007: CIM dialog register-with-prior-chaining helper

TradingHouse repeats `GetCurrentDialogInfo` + `ChainPriorDialogSetup` + `RegisterXxxDialog` scaffolding (thin copies of `BETTERUI.CIM.Dialogs.GetCurrentInfo`/`.Register` plus prior-setup chaining) in 4 files × 3 helpers: `Core/PriceEntry.lua:61,69,83`, `Core/SearchPresets.lua:192,200`, `Core/BrowseFilters.lua:317,326,335`, `Core/TradingHouseRuntimeFlow.lua:40,48,305`.

- [ ] Task: Add `CIM.Dialogs.RegisterWithPriorChain(name, def)` to `Modules/CIM/Dialogs/DialogRegistry.lua` and delete the 12 copies. (est: 35 min)

### BUI-CONS-008: Vendor component store-interaction skeleton

The 8 Vendor components duplicate three scaffolds: (a) list-entry build tail (`ZO_GamepadEntryData:New` + `SetDataSource` + narration + quality `SetNameColors` + `AddEntry("BETTERUI_GamepadItemSubEntryTemplate")`) at `Buyback:132, SellVengeance:240, FenceLaunder:265, FenceSell:264, Repair:315, Sell:398, Buy:820`; (b) `OnPrimaryAction` trace envelope (`TraceActionRequested` → engine call → `ScheduleActionSettled`) at `Buyback:83, SellVengeance:174, FenceLaunder:180, FenceSell:175, Repair:167, Sell:247, Buy:790`; (c) `AuthorizeVendorAction` assert-wrapper at `Sell:27, SellVengeance:25, FenceLaunder:24, FenceSell:24, VendorBatchRuntime:60`. Related duplications: `IsAtGoldCap` (`VendorBatchRuntime.lua:77-84` ≡ `SellComponent.lua:37-44`), BUY affordability check mirrored 3× (`BuyComponent.lua:601-628`, `Core/List/BatchActionCounts.lua:33-65`, `VendorBatchRuntime.lua:~200-235`), per-refresh frame-ms memoize scaffold shared by 4 components, `IsSellVengeanceModeAvailable` predicate duplicated (`Vendor.lua:37-42` ≡ `SellVengeanceComponent.lua:33-38`).

- [ ] Task: Extract `Vendor.AddItemRow(list, entryData)`, `Vendor.DispatchTracedAction(event, traceData, fn)`, `Vendor.AuthorizeAction(mode, ds)` as Vendor-local shared helpers (not CIM) and migrate components. (est: 60 min, sliced per component)
- [ ] Task: Unify `Vendor.CanAffordStoreEntry(instance, ds)` in `Core/Policy/VendorModePolicy.lua` and `Vendor.PerRefreshCache(computeFn)`; dedupe `IsAtGoldCap` and the SellVengeance predicate. (est: 30 min)

### BUI-CONS-009: Inventory duplication cluster

File-by-file review found: two byte-identical BetterUI-destroy confirm blocks in `Actions/ItemActionHandlers.lua:884-965` vs `:1015-1105` (differ only by trace `source` string); `MenuEntryTemplateEquality` re-declared in `Lists/ItemListManager.lua:19` and `Lists/InventoryList.lua:106` despite the CIM export; quest-item predicate copied 3× (`Actions/ItemActionHandlers.lua:87-133`, `Lists/ItemListFiltering.lua:53-76`, `Lists/InventoryEntryFormatting.lua:349-370`); `LogInventoryDialogRestore` ≡ `LogActionDialogRestore` trace helpers plus the same 120-retry/50ms dialog-restore loop in `Core/InventoryClass.lua:~505` and `Actions/ItemActionHandlers.lua:~398`; duplicated default sort schema (`Lists/InventoryList.lua:22-39` ≡ `Lists/CraftList.lua:37-54`); `Core/PositionManager.lua:143-190` craft-bag/else branches copy-pasted; `Core/InventoryMultiSelect.lua:363-405` hand-builds dialog entries bypassing `MultiSelectMixin.CreateDialogEntry`; filter comparator built 3 ways (`Lists/ItemListManager.lua:51`, `Lists/ItemListFiltering.lua:134`, `Lists/CraftList.lua:12`); `UI/TooltipEquipped.lua:476-483` re-inlines `TooltipUtils.RestoreStockLabelFonts` + duplicated `STOCK_TOOLTIP_BODY_FONT` constant; `Lists/CraftBagListManager.lua:143-157` singular count getter superseded by the plural one at `:120`.

- [ ] Task: Merge the two destroy confirm blocks behind one helper with a `source` parameter. (est: 20 min)
- [ ] Task: Point both local `MenuEntryTemplateEquality` copies at `BETTERUI.CIM.MenuEntryTemplateEquality`; extract the quest-item predicate to one Inventory (or CIM Data) helper. (est: 20 min)
- [ ] Task: Extract `CIM.DialogRestore.Schedule(self, tryFn, opts)` for the duplicated retry loop + trace helper; migrate both callers. (est: 30 min)
- [ ] Task: Dedupe sort schema, PositionManager branches, batch-menu builder, filter comparator factory, tooltip font-restore, and remove the superseded singular craft-bag count getter (verify zero callers first). (est: 45 min, sliced)

### BUI-CONS-010: Banking/Companions/Writs small-helper dedup

Confirmed identical-helper copies: `GetBankingWindow` 3× (`Banking/Dialogs/QuantityDialog.lua:20`, `Banking/Core/GuildBankAdapter.lua:30`, `Banking/Core/MultiSelectActions.lua:56`); `RegisterBankingWatchScenes` 2× (`Banking/Banking.lua:784`, `Banking/State/StateManager.lua:9`); snapshot keybind-present helper (`return BETTERUI.Interface.HasKeybindGroup(d) and 1 or 0`) in every module's snapshot provider (`Banking/Banking.lua:780`, `Companions/Module.lua:105`, + Inventory/TradingHouse/Vendor); Writs count/visibility/trace helpers duplicated across `Writs/Module.lua:62,70,81,89` and `Writs/Core/Writ.lua:46,60,71,78`; Companions category-title computation copy-pasted (`Core/CompanionListManager.lua:257-269` vs `:393-399`) and keybind wrap helper duplicated (`CompanionListManager.lua:5` ≡ `CompanionsRuntime.lua:607`).

- [ ] Task: Add `BETTERUI.Banking.GetWindow()` and `Banking.RegisterWatchScenes`; replace copies. (est: 10 min)
- [ ] Task: Add `WatchMode.KeybindPresent(descriptor)` in `Modules/CIM/Core/Diagnostics/WatchMode.lua`; use it in all snapshot providers. (est: 15 min)
- [ ] Task: Move Writs helpers onto `BETTERUI.Writs` (owned by `Core/Writ.lua`) and reuse from `Module.lua`; dedupe the Companions title/wrap helpers. (est: 20 min)

### BUI-CONS-011: ResourceOrbFrames skill-bar shared helpers

`ApplyCooldownTextStyle` is duplicated between `SkillBar/BackBarManager.lua:313-328` and `SkillBar/FrontBarCooldowns.lua:163-181` (only an `applyFont` guard differs). Front/back bars also share button-caching, per-button layout iteration, and cooldown-overlay loops (`FrontBarManager.lua:167/590`, `BackBarManager.lua:70/192/332`, `FrontBarCooldowns.lua:304`) that differ mainly by hotbar category and container. The bars have deliberately diverged elsewhere (usability/quickslot/companion handling), so consolidate only the cache + cooldown loops.

- [ ] Task: Move `ApplyCooldownTextStyle` into `SkillBar/CooldownUtils.lua` keeping the `applyFont` param. (est: 15 min)
- [ ] Task: Evaluate a parameterized `SharedBarButtons` helper (`{container, hotbarCategory, buttonCount}`) for cache + cooldown-refresh loops only; implement if parity is provable via the skill-bar tests. (est: 60 min)

### BUI-CONS-012: Extract the settings layout engine from BetterUI.lua

`BetterUI.lua:563-1660` (~1100 of ~2400 lines) is a self-contained custom LAM widget-geometry + tabbed-submenu rendering engine (`ReadMeasuredWidth` → `ApplySettings*Geometry` → `CreateSettingsTwinContainer` → `CreateSettingsSimulatedSubmenuHeader` → `AddSettingsLayoutEntry`/`CreateSettingsPageWidgets` → `Create/Refresh/LayoutSettingsTabsControl` → `RegisterSettingsTabsLamCallbacks`) with no dependency on the surrounding module-toggle/saved-vars logic. Related: three near-identical `Normalize*SortName` markup-strip helpers (`BetterUI.lua:205-231`, `CIM/Core/Settings/SettingsFactory.lua:20-38,105-125`) share a common color/texture/whitespace/lowercase core.

- [ ] Task: Extract the block to `Modules/CIM/Core/Settings/SettingsPanelLayout.lua` with an explicit exported table; add the manifest entry before `BetterUI.lua`'s consumers; watch file-local upvalue coupling. (est: 60 min)
- [ ] Task: Extract `StripUIMarkupForSort(name)` into `CIM/Core/Utilities.lua`; keep per-caller prefix/emoji stripping local. (est: 20 min)

### BUI-CLEAN-001: Decide fate of the dormant performance-instrumentation pair

Two performance systems ship with zero production producers: `Modules/CIM/Core/Diagnostics/PerformanceProfiler.lua` (no `StartTiming`/`EndTiming`/`Wrap`/`IncrementCounter` calls anywhere, so the `/buidebug`-wired `Report`/`GetTimings` surfaces in `DebugCommands.lua:445-446,640-655` can only return empty; its "not integrated" header comment is also stale) and `Modules/CIM/Core/Diagnostics/Perf.lua` (`Perf.Begin/End/Measure` — its last consumer, GenericListManager:ApplyTextFilter, was removed in the 9f8ce2aa dead-code pass; only the README references it now). Either wire one system into the hot paths it was built for, or retire both files plus their DebugCommands wiring, manifest entries, and tests.

- [ ] Task: Decide keep-and-wire vs retire; if retiring, remove both files, the DebugCommands perf command branches, manifest lines, and their test coverage in one slice. (est: 30 min)
- [ ] Task: If keeping, add `Perf.Begin/End` spans to at least the list-filter and list-refresh hot paths so the `/buidebug` report surface is functional. (est: 30 min)

### BUI-CLEAN-002: Retire or re-wire test-pinned production-dead API surface

Both cleanup passes (9f8ce2aa + pass 2) deliberately kept exports that have zero production callers but are exercised or source-pinned by tools/tests. They are documented here so the surface shrinks intentionally instead of silently: `Vendor.ClampPurchaseQuantity` (BuyComponent.lua:639, reserved for a future quantity spinner), `BETTERUI.Inventory.SlotActionsVisibilityHelpers` (SlotActions.lua:510), `Class:BatchDeposit` (InventoryBatchOps.lua:284), `TH.GetTabs`, `Filters.BuildNameHashFilter`, `PriceEntry.ShouldOfferDigitEntry` (digit row is offered unconditionally in TradingHouseRuntimeFlow.lua:882-907 without consulting it), `VendorClass:SuppressListUpdates` + `TradingHouseClass:SuppressListUpdates/FlushListUpdates` (every real suppression write is a direct `_suppressListUpdates` field assignment; Vendor `FlushListUpdates` IS live via bootstrap), `ListRefreshManager:IsDirty`, `ControlCache.Create/CacheChildren`, `Defaults.IsDestructive/GetDefault`, `GetCategoryTypeFromWeaponType`, `Drag.SetElementLocked/GetOffset`, `CooldownUtils.GetCooldownVisualArmingGeneration`, lang keys `SI_BETTERUI_BUILOG_POPUPS(_TOOLTIP)` and `SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_X/Y(_TOOLTIP)` (tests construct the tooltip variants by concatenation). Deliberate test seams (`Screenshot._ResetForTests`, `_SetLimitsForTests`) are exempt.

- [ ] Task: For each item choose remove (updating its pinning tests) or wire into production; batch the removals in one commit per module. (est: 45 min, sliced per module)
- [ ] Task: Retire Vendor's dead `confirmationMode`/`.spinner` read paths (`VendorClass.lua:714,977,1658` always-false branches; `.spinner` guards at `VendorClass.lua:660-666,951-978`, `VendorControllerRuntime.lua:194,306`, `Vendor/Module.lua:217`, `DebugCommands.lua:148-149,171-172`) — all always-nil/always-false since the Window spinner subsystem was removed; update `test_vendor_tabs.lua` pins. (est: 20 min)
