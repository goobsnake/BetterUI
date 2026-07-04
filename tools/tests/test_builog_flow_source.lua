--[[
File: tools/tests/test_builog_flow_source.lua
Purpose: Source contract for live builog observability. Flow APIs must stay wired
         into the user flows that are hardest to debug from Interface.log alone:
         inventory junk toggles, banking transfers, keybind refreshes, list refresh
         outcomes, and watch snapshot providers.
Usage:   lua tools/tests/test_builog_flow_source.lua
]]

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return "" end
    local content = handle:read("*a") or ""
    handle:close()
    return content
end

local function writeFile(path, content)
    local handle = io.open(path, "w")
    if not handle then return false end
    handle:write(content)
    handle:close()
    return true
end

local function shellQuote(path)
    return '"' .. tostring(path):gsub('"', '\\"') .. '"'
end

local function commandSucceeded(commandOk, statusCode)
    return commandOk == true or commandOk == 0 or statusCode == 0
end

local function runLintFixture(content)
    local sourcePath = os.tmpname() .. ".lua"
    local outputPath = os.tmpname()
    if not writeFile(sourcePath, content) then return "", false end
    local commandOk, _, statusCode = os.execute("lua tools/lint/lint_log_messages.lua "
        .. shellQuote(sourcePath) .. " > " .. shellQuote(outputPath) .. " 2>&1")
    local output = readFile(outputPath)
    os.remove(sourcePath)
    os.remove(outputPath)
    return output, commandSucceeded(commandOk, statusCode)
end

local function countPlain(haystack, needle)
    local count = 0
    local pos = 1
    while true do
        local found = haystack:find(needle, pos, true)
        if not found then return count end
        count = count + 1
        pos = found + #needle
    end
end

local function containsAfter(haystack, anchor, needle)
    local anchorIndex = haystack:find(anchor, 1, true)
    return anchorIndex ~= nil and haystack:find(needle, anchorIndex, true) ~= nil
end

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== builog flow instrumentation source contract ===\n")

local slotActions = readFile("Modules/Inventory/Actions/SlotActions.lua")
local itemActions = readFile("Modules/Inventory/Actions/ItemActionHandlers.lua")
local dialogRestore = readFile("Modules/CIM/Dialogs/DialogRestore.lua")
local destroyAction = readFile("Modules/Inventory/Actions/DestroyAction.lua")
local actionHooks = readFile("Modules/Inventory/Actions/ActionDialogHooks.lua")
local transferActions = readFile("Modules/Banking/Actions/TransferActions.lua")
local inventory = readFile("Modules/Inventory/Inventory.lua")
local banking = readFile("Modules/Banking/Banking.lua")
local bankingClass = readFile("Modules/Banking/Core/BankingClass.lua")
local keybinds = readFile("Modules/Inventory/Core/InventoryClass.lua")
local inventorySceneLifecycle = readFile("Modules/Inventory/Scene/InventorySceneLifecycle.lua")
local inventoryKeybinds = readFile("Modules/Inventory/Keybinds/InventoryKeybinds.lua")
local craftBagKeybinds = readFile("Modules/Inventory/Keybinds/CraftBagKeybinds.lua")
local inventoryCategories = readFile("Modules/Inventory/Lists/CategoryListManager.lua")
local headerNavigation = readFile("Modules/CIM/UI/HeaderNavigation.lua")
local bankQuantityDialog = readFile("Modules/Banking/Dialogs/QuantityDialog.lua")
local craftBagQuantityDialog = readFile("Modules/Inventory/Dialogs/CraftBagQuantityDialog.lua")
local itemList = readFile("Modules/Inventory/Lists/ItemListManager.lua")
local bankList = readFile("Modules/Banking/Lists/BankListManager.lua")
local inventoryState = readFile("Modules/Inventory/State/ListStateManager.lua")
local bankingState = readFile("Modules/Banking/State/StateManager.lua")
local bankingKeybinds = readFile("Modules/Banking/Keybinds/KeybindManager.lua")
local bankingActions = readFile("Modules/Banking/Actions/BankingActions.lua")
local currencySelector = readFile("Modules/Banking/Currency/CurrencySelector.lua")
local positionManager = readFile("Modules/CIM/Core/Data/PositionManager.lua")
local resourceOrbs = readFile("Modules/ResourceOrbFrames/ResourceOrbFrames.lua")
local genericSlotActions = readFile("Modules/CIM/Actions/GenericSlotActions.lua")
local listRefreshManager = readFile("Modules/CIM/Lists/ListRefreshManager.lua")
local watchMode = readFile("Modules/CIM/Core/Diagnostics/WatchMode.lua")
local headerSortController = readFile("Modules/CIM/UI/HeaderSortController.lua")
local headerSortIntegration = readFile("Modules/CIM/UI/HeaderSortIntegration.lua")
local headerSortKeybinds = readFile("Modules/CIM/UI/HeaderSortKeybinds.lua")
local domainLog = readFile("Modules/CIM/Core/Diagnostics/DomainLog.lua")
local logCore = readFile("Modules/CIM/Core/Diagnostics/Log.lua")
local interfaceLog = readFile("Modules/CIM/Core/Diagnostics/InterfaceLog.lua")
local builogCommands = readFile("Modules/CIM/Core/Diagnostics/BuilogCommands.lua")
local companionActions = readFile("Modules/Companions/Actions/CompanionActions.lua")
local companionDialogs = readFile("Modules/Companions/Dialogs/CompanionDialogs.lua")
local companionModule = readFile("Modules/Companions/Module.lua")
local companionsRuntime = readFile("Modules/Companions/Core/CompanionsRuntime.lua")
local companionListManager = readFile("Modules/Companions/Core/CompanionListManager.lua")
local companionItemList = readFile("Modules/Companions/Core/CompanionItemList.lua")
local fontLocalization = readFile("Modules/CIM/Core/Presentation/FontLocalization.lua")
local nameplates = readFile("Modules/Nameplates/Nameplates.lua")
local nameplateSettings = readFile("Modules/Nameplates/Settings.lua")
local vendor = readFile("Modules/Vendor/Vendor.lua")
local vendorKeybinds = readFile("Modules/Vendor/Core/VendorKeybinds.lua")
local vendorBootstrap = readFile("Modules/Vendor/Core/VendorBootstrapRuntime.lua")
local vendorBuy = readFile("Modules/Vendor/Components/BuyComponent.lua")
local vendorSell = readFile("Modules/Vendor/Components/SellComponent.lua")
local vendorRepair = readFile("Modules/Vendor/Components/RepairComponent.lua")
local vendorBridge = readFile("Modules/Vendor/Core/Bridge/VendorNativeStoreBridge.lua")
local vendorControllerRuntime = readFile("Modules/Vendor/Core/Lifecycle/VendorControllerRuntime.lua")
local vendorLifecycle = readFile("Modules/Vendor/Core/Lifecycle/VendorInteractionRuntime.lua")
local vendorBatch = readFile("Modules/Vendor/Core/VendorBatchRuntime.lua")
local writCore = readFile("Modules/Writs/Core/Writ.lua")
local writModule = readFile("Modules/Writs/Module.lua")
local tradingHouseClass = readFile("Modules/TradingHouse/Core/TradingHouseClass.lua")
local tradingHouseFlow = readFile("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
local tradingHouseBrowse = readFile("Modules/TradingHouse/Components/BrowseComponent.lua")
local tradingHouseListings = readFile("Modules/TradingHouse/Components/ListingsComponent.lua")
local tradingHouseFilters = readFile("Modules/TradingHouse/Core/BrowseFilters.lua")
local tradingHousePrice = readFile("Modules/TradingHouse/Core/PriceEntry.lua")
local orbBars = readFile("Modules/ResourceOrbFrames/Core/OrbBars.lua")
local orbBarUpdates = readFile("Modules/ResourceOrbFrames/Core/OrbBarUpdates.lua")
local logMessageLint = readFile("tools/lint/lint_log_messages.lua")
local orbCombat = readFile("Modules/ResourceOrbFrames/Core/OrbCombatIndicators.lua")
local orbVisuals = readFile("Modules/ResourceOrbFrames/Core/OrbVisuals.lua")
local orbEvents = readFile("Modules/ResourceOrbFrames/Core/OrbEvents.lua")
local frontBarManager = readFile("Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua")
local backBarManager = readFile("Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua")
local ultimateManager = readFile("Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua")
local frontBarCooldowns = readFile("Modules/ResourceOrbFrames/SkillBar/FrontBarCooldowns.lua")
local inventoryModule = readFile("Modules/Inventory/Module.lua")
local inventoryDialogs = readFile("Modules/Inventory/Dialogs/InventoryDialogs.lua")
local betterUiRoot = readFile("BetterUI.lua")
local generalModule = readFile("Modules/GeneralInterface/Module.lua")
local generalSetup = readFile("Modules/GeneralInterface/Setup.lua")
local tooltips = readFile("Modules/GeneralInterface/Tooltips/Tooltips.lua")
local tooltipSettings = readFile("Modules/GeneralInterface/Tooltips/Settings.lua")
local settingsAccessor = readFile("Modules/CIM/Core/Settings/SettingsAccessor.lua")
local craftingPriceTooltip = readFile("Modules/GeneralInterface/Tooltips/CraftingPriceTooltip.lua")
local bankingHeader = readFile("Modules/Banking/UI/HeaderManager.lua")
local bankingFooter = readFile("Modules/Banking/UI/FooterManager.lua")
local guildBankAdapter = readFile("Modules/Banking/Core/GuildBankAdapter.lua")
local manifest = readFile("BetterUI.txt")
local inputAnchor = readFile("Modules/CIM/Keybinds/InputAnchor.lua")
local watchdog = readFile("Modules/CIM/Core/Diagnostics/Watchdog.lua")
local genericKeybinds = readFile("Modules/CIM/Keybinds/GenericKeybinds.lua")
local tradingHouseRuntime = readFile("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
local hostParseDocs = readFile("docs/reference/logging-host-tail-parse.md")
local developerGuide = readFile("docs/reference/builog-developer-guide.md")

check(slotActions:find("inventoryJunk", 1, true) ~= nil and slotActions:find("FlowBegin", 1, true) ~= nil,
    "primary inventory junk actions begin builog flows")
check(itemActions:find("inventory dialog junk toggle requested", 1, true) ~= nil,
    "dialog inventory junk action emits flow context")
check(itemActions:find("inventory dialog junk toggle cache invalidated; waiting for inventory update", 1, true) ~= nil
    and itemActions:find("inventory dialog action confirmed", 1, true) ~= nil,
    "dialog inventory actions log confirmation and wait for inventory-update refresh")
check(destroyAction:find('"inventory.destroy"', 1, true) ~= nil
    and destroyAction:find("confirm_dialog_request", 1, true) ~= nil
    and destroyAction:find("showReturnedDialog", 1, true) ~= nil,
    "destroy action logs canonical request/show dialog outcomes")
check(destroyAction:find("refresh_start", 1, true) ~= nil
    and destroyAction:find("refresh_complete", 1, true) ~= nil
    and destroyAction:find("refresh_failed", 1, true) ~= nil,
    "destroy deferred UI refresh logs execution outcome")
check(itemActions:find("action_dialog_selected", 1, true) ~= nil
    and itemActions:find("quick_requested", 1, true) ~= nil
    and actionHooks:find('source = "fallback"', 1, true) ~= nil,
    "managed and fallback destroy dialog paths expose quick/confirm routing")
check(itemActions:find('"inventory.action_dialog.confirm_branch"', 1, true) ~= nil
    and itemActions:find('"use_or_special"', 1, true) ~= nil
    and itemActions:find('"place_furniture"', 1, true) ~= nil
    and itemActions:find('"show_quest"', 1, true) ~= nil
    and itemActions:find('"native_action"', 1, true) ~= nil,
    "inventory action dialog non-destroy branches trace before/after/blocked outcomes")
check(genericSlotActions:find('"cim.slot_action.use"', 1, true) ~= nil
    and genericSlotActions:find('"cim.slot_action.craft_bag_transfer"', 1, true) ~= nil
    and genericSlotActions:find('"cim.slot_action.secure_move"', 1, true) ~= nil
    and genericSlotActions:find("pickup_failed", 1, true) ~= nil
    and genericSlotActions:find("place_failed", 1, true) ~= nil,
    "shared CIM slot actions trace secure use and craft-bag transfer outcomes")
check(itemActions:find('reason = "missingTarget"', 1, true) ~= nil
    and itemActions:find('reason = "invalidSlot"', 1, true) ~= nil
    and actionHooks:find('reason = "missingTarget"', 1, true) ~= nil,
    "destroy dialog paths log missing and invalid target blockers")
check(slotActions:find("primary_selected", 1, true) ~= nil
    and slotActions:find("native_initiate", 1, true) ~= nil
    and slotActions:find("primary_action_fallback", 1, true) ~= nil,
    "primary destroy action traces native and fallback routes")
check(transferActions:find("bankTransfer", 1, true) ~= nil and transferActions:find("bank transfer refresh decision", 1, true) ~= nil,
    "bank transfers emit flow context through refresh scheduling")
check(transferActions:find("L.CATEGORY.TRANSFER", 1, true) ~= nil
    and transferActions:find("L.TraceEvent(L.CATEGORY.ACTION, event, phase", 1, true) == nil
    and transferActions:find("L.FlowBegin(\"bankTransfer\", L.CATEGORY.ACTION", 1, true) == nil,
    "bank item-transfer trace helpers use TRANSFER, not ACTION")
check(transferActions:find("move_requested", 1, true) ~= nil
    and transferActions:find("pending_marked", 1, true) ~= nil
    and transferActions:find('"confirmed"', 1, true) ~= nil
    and transferActions:find('"expired"', 1, true) ~= nil
    and transferActions:find('BeginBankTransferFlow("bank transfer direct requested"', 1, true) ~= nil
    and transferActions:find("MarkTransferPending(bag, index, flow)", 1, true) ~= nil
    and transferActions:find("PendingFlow", 1, true) ~= nil,
    "bank transfers distinguish move requests from cursor requests and trace confirmed/expired outcome state")
check(logMessageLint:find("PHASE_PATTERNS", 1, true) ~= nil
    and logMessageLint:find("TraceBankTransfer", 1, true) ~= nil
    and logMessageLint:find("TraceBankKeybind", 1, true) ~= nil
    and logMessageLint:find("TraceBankingActionDialog", 1, true) ~= nil
    and logMessageLint:find("TraceListTrigger", 1, true) ~= nil
    and logMessageLint:find("TraceKeybind", 1, true) ~= nil
    and logMessageLint:find("TraceBankCurrencyAction", 1, true) ~= nil
    and logMessageLint:find("TraceBankState", 1, true) ~= nil
    and logMessageLint:find("TraceVendorEvent", 1, true) ~= nil
    and logMessageLint:find("TraceVendor", 1, true) ~= nil
    and logMessageLint:find("TraceVendorBatch", 1, true) ~= nil
    and logMessageLint:find("TraceVendorBootstrap", 1, true) ~= nil
    and logMessageLint:find("TraceNativeStoreBridge", 1, true) ~= nil
    and logMessageLint:find("TraceBrowse", 1, true) ~= nil
    and logMessageLint:find("TraceSell", 1, true) ~= nil
    and logMessageLint:find("TraceListings", 1, true) ~= nil
    and logMessageLint:find("TraceTH", 1, true) ~= nil
    and logMessageLint:find("TraceTHFlow", 1, true) ~= nil
    and logMessageLint:find("TraceWrit", 1, true) ~= nil
    and logMessageLint:find("TraceWritEvent", 1, true) ~= nil
    and logMessageLint:find("TraceCompanionRuntime", 1, true) ~= nil
    and logMessageLint:find("TraceCompanionDialog", 1, true) ~= nil
    and logMessageLint:find("TraceUltimate", 1, true) ~= nil
    and logMessageLint:find("TraceCoordinator", 1, true) ~= nil
    and logMessageLint:find("TraceCastBar", 1, true) ~= nil
    and logMessageLint:find("TraceOrbEvents", 1, true) ~= nil
    and logMessageLint:find("TraceNameplates", 1, true) ~= nil
    and logMessageLint:find("TraceGeneralInterface", 1, true) ~= nil
    and logMessageLint:find("TraceGeneralSetting", 1, true) ~= nil
    and logMessageLint:find("TraceDrag", 1, true) ~= nil
    and logMessageLint:find("legacyPhaseTotal", 1, true) ~= nil
    and logMessageLint:find("WARN: %d approved legacy TraceEvent phase(s) remain.", 1, true) ~= nil
    and logMessageLint:find("pending_expired", 1, true) ~= nil,
    "log message lint scans project Trace* wrappers and warns on approved legacy phases")
local lintCanonicalOutput, lintCanonicalOk = runLintFixture([[
local ready = true
TraceVendorEvent("vendor.mode", "begin", {})
TraceTHFlow(nil, "tradinghouse.listing", ready and "blocked" or "completed", {})
TraceCompanionRuntime("companion.state", ready and "begin" or "completed", {})
TraceBankState("bank.currency_ui_refresh", ready and "completed" or "failed", {})
TraceNativeStoreBridge("vendor.native_store_cleanup", "begin", {})
TraceNativeStoreBridge("vendor.native_store_cleanup",
    ready and "blocked" or "completed", {})
TraceVendorBootstrap("vendor.bootstrap", ready and "begin" or "completed", {})
]])
check(lintCanonicalOk
    and lintCanonicalOutput:find("OK: no terse log messages found.", 1, true) ~= nil,
    "log message lint accepts canonical wrapper phases, including conditional wrapper forms")
local lintLegacyOutput, lintLegacyOk = runLintFixture([[
local ready = true
TraceVendorEvent("vendor.mode", "activate", {})
TraceTHFlow(nil, "tradinghouse.listing", ready and "refresh_begin" or "refresh_end", {})
TraceCompanionRuntime("companion.state", ready and "show_begin" or "showing_end", {})
]])
check(lintLegacyOk
    and lintLegacyOutput:find("WARN legacy TraceVendorEvent phase \"activate\"", 1, true) ~= nil
    and lintLegacyOutput:find("WARN legacy TraceTHFlow phase \"refresh_begin\"", 1, true) ~= nil
    and lintLegacyOutput:find("WARN legacy TraceTHFlow phase \"refresh_end\"", 1, true) ~= nil
    and lintLegacyOutput:find("WARN legacy TraceCompanionRuntime phase \"show_begin\"", 1, true) ~= nil
    and lintLegacyOutput:find("WARN legacy TraceCompanionRuntime phase \"showing_end\"", 1, true) ~= nil
    and lintLegacyOutput:find("WARN: 5 approved legacy TraceEvent phase(s) remain.", 1, true) ~= nil,
    "log message lint warns but passes approved legacy wrapper phases")
local lintExtendedLegacyOutput, lintExtendedLegacyOk = runLintFixture([[
local ready = true
TraceBankState("bank.open", "event", {})
TraceNativeStoreBridge("vendor.open_store_sync", "mode_applied", {})
TraceNativeStoreBridge("vendor.open_store_sync", ready and "retry" or "give_up", {})
TraceNativeStoreBridge("vendor.native_store_takeover",
    ready and "native_open_suppressed" or "native_open_fallback", {})
TraceVendorBootstrap("vendor.scene", ready and "showing_begin" or "showing_end", {})
]])
check(lintExtendedLegacyOk
    and lintExtendedLegacyOutput:find("WARN legacy TraceBankState phase \"event\"", 1, true) ~= nil
    and lintExtendedLegacyOutput:find("WARN legacy TraceNativeStoreBridge phase \"mode_applied\"", 1, true) ~= nil
    and lintExtendedLegacyOutput:find("WARN legacy TraceNativeStoreBridge phase \"retry\"", 1, true) ~= nil
    and lintExtendedLegacyOutput:find("WARN legacy TraceNativeStoreBridge phase \"give_up\"", 1, true) ~= nil
    and lintExtendedLegacyOutput:find("WARN legacy TraceNativeStoreBridge phase \"native_open_suppressed\"", 1, true) ~= nil
    and lintExtendedLegacyOutput:find("WARN legacy TraceNativeStoreBridge phase \"native_open_fallback\"", 1, true) ~= nil
    and lintExtendedLegacyOutput:find("WARN legacy TraceVendorBootstrap phase \"showing_begin\"", 1, true) ~= nil
    and lintExtendedLegacyOutput:find("WARN legacy TraceVendorBootstrap phase \"showing_end\"", 1, true) ~= nil
    and lintExtendedLegacyOutput:find("WARN: 8 approved legacy TraceEvent phase(s) remain.", 1, true) ~= nil,
    "log message lint covers newer wrapper families and multiline conditional phases")
local lintUnknownOutput, lintUnknownOk = runLintFixture([[
TraceVendorEvent("vendor.mode", "banana_phase", {})
]])
check(not lintUnknownOk
    and lintUnknownOutput:find("non-canonical TraceVendorEvent phase \"banana_phase\"", 1, true) ~= nil
    and lintUnknownOutput:find("1 non-canonical TraceEvent phase(s) found.", 1, true) ~= nil,
    "log message lint fails unknown wrapper phases")
check(transferActions:find("bank transfer blocked", 1, true) ~= nil
    and transferActions:find("guild_transfer_denied", 1, true) ~= nil
    and transferActions:find("request_move_failed", 1, true) ~= nil
    and transferActions:find("GetTransferItemSummary", 1, true) ~= nil
    and transferActions:find("L.DescribeItem({ bagId = bag, slotIndex = slot }, \"item\")", 1, true) ~= nil,
    "bank transfers log blocked capacity/permission paths and privacy-aware item metadata")
check(transferActions:find("guild bank transfer requested", 1, true) ~= nil
    and transferActions:find("guild bank transfer refresh decision", 1, true) ~= nil,
    "guild bank transfers emit flow context through refresh scheduling")
check(bankingKeybinds:find("bankCurrencyTransfer", 1, true) ~= nil
    and bankingKeybinds:find('TraceBankCurrencyAction("completed"', 1, true) ~= nil
    and bankingKeybinds:find("bank currency transfer failed", 1, true) ~= nil,
    "bank currency transfers emit completed and failed builog flow context")
check(bankingKeybinds:find('L.TraceEvent(L.CATEGORY.TRANSFER, "bank.currency_transfer"', 1, true) ~= nil
    and bankingKeybinds:find('L.FlowBegin("bankCurrencyTransfer", L.CATEGORY.TRANSFER', 1, true) ~= nil
    and bankingKeybinds:find("L.FlowEnd(flow, L.CATEGORY.TRANSFER", 1, true) ~= nil,
    "bank currency transfer trace helpers use TRANSFER, not ACTION")
check(bankingKeybinds:find('TraceBankCurrencyAction("blocked"', 1, true) ~= nil
    and bankingKeybinds:find('"invalidAmount"', 1, true) ~= nil
    and bankingKeybinds:find('"bank.currency_selector"', 1, true) ~= nil
    and bankingKeybinds:find('"cannotAfford"', 1, true) ~= nil,
    "bank currency and upgrade keybind denied/no-op paths emit trace outcomes")
check(bankingKeybinds:find("bank.mode_toggle", 1, true) ~= nil
    and bankingKeybinds:find("bank.upgrade", 1, true) ~= nil
    and bankingKeybinds:find("BETTERUI.Banking.IsTransferPending(bagId, slotIndex)", 1, true) ~= nil,
    "bank mode toggles, upgrade prompts, and all transfer modes expose keybind state transitions")
check(bankingKeybinds:find("local canTransfer, denialText = CanUsePrimaryTransfer(self)", 1, true) ~= nil
    and bankingKeybinds:find('"callbackRecheckFailed"', 1, true) ~= nil,
    "bank primary transfer callbacks re-check pending and permission state before moving")
check(inventoryKeybinds:find("handled = handled == true", 1, true) ~= nil
    and inventoryKeybinds:find("branch = branch", 1, true) ~= nil
    and inventoryKeybinds:find("return InventoryKeybinds.HandlePrimaryKeybind(self)", 1, true) ~= nil
    and inventoryKeybinds:find("return InventoryKeybinds.HandleSecondaryKeybind(self)", 1, true) ~= nil
    and inventoryKeybinds:find("return InventoryKeybinds.HandleTertiaryKeybind(self)", 1, true) ~= nil
    and inventoryKeybinds:find("return InventoryKeybinds.HandleMultiSelectEntry(self)", 1, true) ~= nil
    and craftBagKeybinds:find('return false, "noTarget"', 1, true) ~= nil
    and craftBagKeybinds:find('"showActions"', 1, true) ~= nil,
    "inventory keybind callbacks report handled/reason/branch outcomes")
local inputAnchorIndex = manifest:find("Modules\\CIM\\Keybinds\\InputAnchor.lua", 1, true)
local genericKeybindIndex = manifest:find("Modules\\CIM\\Keybinds\\GenericKeybinds.lua", 1, true)
local actionContextIndex = manifest:find("Modules\\CIM\\Keybinds\\ActionContext.lua", 1, true)
check(inputAnchorIndex ~= nil
    and genericKeybindIndex ~= nil
    and actionContextIndex ~= nil
    and inputAnchorIndex < genericKeybindIndex
    and inputAnchorIndex < actionContextIndex,
    "InputAnchor loads before shared and module keybind factories")
check(inputAnchor:find('BETTERUI.CIM.Keybinds.InputAnchor = InputAnchor', 1, true) ~= nil
    and inputAnchor:find('InputAnchor.Wrap(descriptorEntry', 1, true) ~= nil
    and inputAnchor:find('InputAnchor.WrapGroup(descriptor', 1, true) ~= nil
    and inputAnchor:find('"input.keybind", "fired"', 1, true) ~= nil
    and inputAnchor:find('return callback(...)', 1, true) ~= nil
    and inputAnchor:find('resolveEnabled(entry)', 1, true) ~= nil,
    "InputAnchor exposes wrap APIs, emits the standard fired anchor, and preserves callback dispatch")
local domainLogIndex = manifest:find("Modules\\CIM\\Core\\Diagnostics\\DomainLog.lua", 1, true)
local logIndex = manifest:find("Modules\\CIM\\Core\\Diagnostics\\Log.lua", 1, true)
local watchdogIndex = manifest:find("Modules\\CIM\\Core\\Diagnostics\\Watchdog.lua", 1, true)
local watchModeIndex = manifest:find("Modules\\CIM\\Core\\Diagnostics\\WatchMode.lua", 1, true)
local builogCommandsIndex = manifest:find("Modules\\CIM\\Core\\Diagnostics\\BuilogCommands.lua", 1, true)
check(domainLogIndex ~= nil
    and logIndex ~= nil
    and watchdogIndex ~= nil
    and watchModeIndex ~= nil
    and builogCommandsIndex ~= nil
    and domainLogIndex < logIndex
    and logIndex < watchdogIndex
    and watchdogIndex < watchModeIndex
    and watchModeIndex < builogCommandsIndex,
    "DomainLog/Log/Watchdog/WatchMode/BuilogCommands load in dependency order")
check(domainLog:find("function DomainLog.DescribeItem", 1, true) ~= nil
    and domainLog:find("function DomainLog.DescribeKeybindDescriptor", 1, true) ~= nil
    and logCore:find("Log.DescribeItem = DomainLog.DescribeItem", 1, true) ~= nil
    and logCore:find("Log.GetCurrencyAmountForLocation = DomainLog.GetCurrencyAmountForLocation", 1, true) ~= nil,
    "Domain-specific log describers live in DomainLog behind thin Log aliases")
check(builogCommands:find("local function HandleCommand(args)", 1, true) ~= nil
    and builogCommands:find("local function HandleHealthCommand()", 1, true) ~= nil
    and builogCommands:find("BuilogCommands.Register = Register", 1, true) ~= nil
    and interfaceLog:find("local function HandleCommand(args)", 1, true) == nil
    and interfaceLog:find("SLASH_COMMANDS", 1, true) == nil,
    "builog slash command surface lives outside InterfaceLog transport")
check(watchdog:find("BETTERUI.CIM.Watchdog = Watchdog", 1, true) ~= nil
    and watchdog:find("function Watchdog.Expect", 1, true) ~= nil
    and watchdog:find("function Watchdog.Resolve", 1, true) ~= nil
    and watchdog:find("function Watchdog.GetStats", 1, true) ~= nil
    and watchdog:find('traceAnomaly("detected"', 1, true) ~= nil
    and watchdog:find('traceAnomaly("overflow"', 1, true) ~= nil
    and watchdog:find("MAX_PENDING = 64", 1, true) ~= nil,
    "Watchdog core exposes expectation APIs, anomaly events, and the live pending cap")
check(logCore:find('pcall(watchdog.Expect, "flow"', 1, true) ~= nil
    and logCore:find('pcall(watchdog.Resolve, "flow"', 1, true) ~= nil
    and logCore:find("Log.EnabledFor(Log.LEVEL.DEBUG, flowCategory)", 1, true) ~= nil
    and logCore:find('pcall(watchdog.Deactivate)', 1, true) ~= nil
    and watchMode:find('pcall(watchdog.Deactivate)', 1, true) ~= nil,
    "flow envelopes use the exact DEBUG gate and preset/watch deactivation is wired to Watchdog")
check(hostParseDocs:find("event=anomaly phase=detected", 1, true) ~= nil
    and hostParseDocs:find("event=anomaly phase=overflow", 1, true) ~= nil
    and developerGuide:find("Watchdog.Expect(kind, key, timeoutMs, context)", 1, true) ~= nil
    and developerGuide:find("Log.FlowBegin", 1, true) ~= nil
    and developerGuide:find("anomaly", 1, true) ~= nil,
    "anomaly watchdog record family and API rules are documented with the parse contract")
local keybindAdoptionSource = table.concat({
    bankingKeybinds,
    inventoryKeybinds,
    vendorKeybinds,
    tradingHouseRuntime,
    companionsRuntime,
    companionListManager,
    companionDialogs,
    generalSetup,
}, "\n")
check(bankingKeybinds:find("WrapBankingKeybindGroup", 1, true) ~= nil
    and inventoryKeybinds:find("WrapInventoryKeybindGroup", 1, true) ~= nil
    and vendorKeybinds:find("WrapVendorKeybindGroup", 1, true) ~= nil
    and tradingHouseRuntime:find("WrapTradingHouseKeybindGroup", 1, true) ~= nil
    and companionsRuntime:find("WrapCompanionKeybindGroup", 1, true) ~= nil
    and companionListManager:find("WrapCompanionHeaderKeybindGroup", 1, true) ~= nil
    and companionDialogs:find("WrapCompanionDialogKeybind", 1, true) ~= nil
    and generalSetup:find("WrapGeneralInterfaceKeybind", 1, true) ~= nil,
    "module keybind descriptor surfaces route through InputAnchor wrappers")
check(bankingKeybinds:find("WrapBankingKeybindGroup(self.coreKeybinds)", 1, true) ~= nil
    and bankingKeybinds:find("WrapBankingKeybindGroup(self.withdrawDepositKeybinds)", 1, true) ~= nil
    and bankingKeybinds:find("WrapBankingKeybindGroup(self.currencySelectorKeybinds)", 1, true) ~= nil
    and bankingKeybinds:find("WrapBankingKeybindGroup(self.currencyKeybinds)", 1, true) ~= nil
    and inventoryKeybinds:find("WrapInventoryKeybindGroup(self.mainKeybindStripDescriptor)", 1, true) ~= nil
    and vendorKeybinds:find("return WrapVendorKeybindGroup({", 1, true) ~= nil
    and vendor:find("VendorKeybinds.BuildCoreKeybinds(vendorInstance", 1, true) ~= nil
    and containsAfter(tradingHouseRuntime, "function TH.BuildCoreKeybinds", "return WrapTradingHouseKeybindGroup({")
    and containsAfter(tradingHouseRuntime, "function TH.BuildTabKeybinds", "return WrapTradingHouseKeybindGroup({")
    and containsAfter(companionsRuntime, "function Companions.BuildCoreKeybinds", "return WrapCompanionKeybindGroup({")
    and companionListManager:find("WrapCompanionHeaderKeybindGroup(tabBar.keybindStripDescriptor)", 1, true) ~= nil
    and generalSetup:find("WrapGeneralInterfaceKeybind(descriptor, \"mail_delete\")", 1, true) ~= nil,
    "keybind construction sites wrap the live descriptor groups, not just helper definitions")
local vendorBackPreviewIndex = vendorKeybinds:find("if IsVendorPreviewActive(Vendor, vendorInstance) then", 1, true)
local vendorBackCloseIndex = vendorBackPreviewIndex and vendorKeybinds:find("close_scene", vendorBackPreviewIndex, true)
check(vendorBackPreviewIndex ~= nil
    and vendorBackCloseIndex ~= nil
    and vendorBackPreviewIndex < vendorBackCloseIndex
    and vendorKeybinds:find("EndVendorPreview(Vendor, vendorInstance, isStableInteraction())", 1, true) ~= nil
    and vendor:find("Vendor.EndActivePreview = EndActiveVendorPreview", 1, true) ~= nil
    and vendorBootstrap:find("Vendor.SyncPreviewState(screen)", 1, true) ~= nil
    and vendorBootstrap:find("Vendor.SyncPreviewState(screen, false)", 1, true) ~= nil,
    "vendor Back ends active item preview before the scene-close branch")
check(countPlain(companionDialogs, "WrapCompanionDialogKeybind({") >= 6
    and companionDialogs:find("}, \"batch_destroy_cancel\")", 1, true) ~= nil
    and companionDialogs:find("}, \"batch_destroy_confirm\")", 1, true) ~= nil
    and companionDialogs:find("}, \"action_dialog_cancel\")", 1, true) ~= nil
    and companionDialogs:find("}, \"action_dialog_confirm\")", 1, true) ~= nil
    and companionDialogs:find("}, \"batch_dialog_cancel\")", 1, true) ~= nil
    and companionDialogs:find("}, \"batch_dialog_confirm\")", 1, true) ~= nil,
    "companion dialog button descriptors are wrapped at each cancel/confirm site")
check(genericKeybinds:find("data.keybind = keybind", 1, true) == nil
    and inventoryKeybinds:find("data.keybind = keybind", 1, true) == nil
    and companionsRuntime:find("data.keybind = nil", 1, true) ~= nil
    and generalSetup:find("payload._inputAnchorDetail == true", 1, true) ~= nil
    and generalSetup:find("_inputAnchorDetail = true", 1, true) ~= nil
    and generalSetup:find('payload.fn == "mailDeleteDescriptor.callback"', 1, true) == nil
    and vendorKeybinds:find("data._inputAnchorDetail = true", 1, true) ~= nil,
    "keybind detail records avoid duplicating anchor-owned module/keybind/gamepad fields")
check(keybindAdoptionSource:find('"fired"', 1, true) == nil,
    "module keybind files do not add bespoke fired KEYBIND emits outside InputAnchor")
check(generalSetup:find('"general_interface.mail_delete", "requested"', 1, true) ~= nil
    and generalSetup:find('"general_interface.mail_delete", "confirmed"', 1, true) ~= nil
    and generalSetup:find('"general_interface.mail_delete", "skipped"', 1, true) ~= nil
    and generalSetup:find('"general_interface.chat_history", "requested"', 1, true) ~= nil
    and generalSetup:find('"general_interface.chat_history", "confirmed"', 1, true) ~= nil,
    "GeneralInterface mail delete and chat-history mutations expose canonical requested/confirmed/skipped lifecycles")
check((writCore .. "\n" .. writModule):find("keybind%s*=") == nil,
    "Writs scheduled files currently have no user-fired keybind descriptors to wrap")
check(inventorySceneLifecycle:find('"inventory.keybind_ownership"', 1, true) ~= nil
    and inventorySceneLifecycle:find("RemoveInventoryKeybindsForSceneExit(self, \"hiding\")", 1, true) ~= nil
    and inventorySceneLifecycle:find("stripHasMain", 1, true) ~= nil
    and inventorySceneLifecycle:find("inventory keybind ownership warning", 1, true) ~= nil
    and keybinds:find('reason = "sceneNotShowing"', 1, true) ~= nil
    and keybinds:find("inventory keybind refresh outside scene removed stale group", 1, true) ~= nil,
    "inventory scene exits and hidden refreshes expose keybind ownership cleanup")
check(inventoryCategories:find('"inventory.category"', 1, true) ~= nil
    and inventoryCategories:find('"restored"', 1, true) ~= nil
    and inventoryCategories:find('"committed"', 1, true) ~= nil
    and headerNavigation:find('"category.navigation"', 1, true) ~= nil
    and headerNavigation:find('"staleToken"', 1, true) ~= nil,
    "inventory category and header navigation changes emit canonical trace phases")
check(bankQuantityDialog:find("ShouldTraceSliderPreview", 1, true) ~= nil
    and bankQuantityDialog:find("coalesced = true", 1, true) ~= nil
    and bankQuantityDialog:find("CaptureBankSlotIdentity", 1, true) ~= nil
    and bankQuantityDialog:find("IsBankSlotIdentityCurrent", 1, true) ~= nil
    and bankQuantityDialog:find("CreateQuantityDialogListProxy", 1, true) ~= nil
    and bankQuantityDialog:find("ClearQuantityDialogSuppression", 1, true) ~= nil
    and bankQuantityDialog:find("noChoiceCallback", 1, true) ~= nil
    and bankQuantityDialog:find('"show_blocked"', 1, true) ~= nil
    and bankQuantityDialog:find('"confirm_blocked"', 1, true) ~= nil
    and bankQuantityDialog:find('"invalidQuantity"', 1, true) ~= nil
    and bankQuantityDialog:find('"staleSlot"', 1, true) ~= nil
    and bankQuantityDialog:find('"emptyLiveStack"', 1, true) ~= nil
    and bankQuantityDialog:find('"missingMoveItem"', 1, true) ~= nil
    and bankQuantityDialog:find('"no_choice"', 1, true) ~= nil
    and bankQuantityDialog:find("_betteruiLastSliderTraceKey = nil", 1, true) ~= nil
    and bankQuantityDialog:find("_betteruiLastSliderTraceBucket = nil", 1, true) ~= nil
    and bankQuantityDialog:find("moveRequested", 1, true) ~= nil
    and bankQuantityDialog:find("ReleaseQuantityDialog", 1, true) ~= nil
    and bankQuantityDialog:find('"suppression_cleared"', 1, true) ~= nil
    and craftBagQuantityDialog:find("ShouldTraceSliderPreview", 1, true) ~= nil
    and craftBagQuantityDialog:find("coalesced = true", 1, true) ~= nil
    and craftBagQuantityDialog:find("_betteruiLastSliderTraceKey = nil", 1, true) ~= nil
    and craftBagQuantityDialog:find("_betteruiLastSliderTraceBucket = nil", 1, true) ~= nil
    and craftBagQuantityDialog:find('"show_blocked"', 1, true) ~= nil
    and craftBagQuantityDialog:find('"confirm_blocked"', 1, true) ~= nil,
    "quantity dialogs throttle slider traces and expose blocked confirm/show outcomes")
check(inventory:find('RegisterSnapshotProvider("inventory"', 1, true) ~= nil,
    "inventory registers a watch snapshot provider")
check(banking:find('RegisterSnapshotProvider("banking"', 1, true) ~= nil,
    "banking registers a watch snapshot provider")
check(watchMode:find("function Watch.RegisterViewScene", 1, true) ~= nil
    and watchMode:find("viewSceneRegistry", 1, true) ~= nil
    and watchMode:find("registeredSceneMatches", 1, true) ~= nil
    and watchMode:find('view == "inventory"', 1, true) == nil
    and watchMode:find('view:sub(1, 8) == "banking."', 1, true) == nil,
    "watch mode uses registered view/scene pairs instead of hardcoded inventory/banking branches")
check(inventory:find('RegisterViewScene("inventory"', 1, true) ~= nil
    and bankingClass:find('RegisterViewScene("banking"', 1, true) ~= nil
    and bankingClass:find("BETTERUI_GUILD_BANKING_SCENE_NAME", 1, true) ~= nil
    and banking:find("BETTERUI.Banking.RegisterWatchScenes", 1, true) ~= nil
    and inventoryState:find('RegisterViewScene("inventory"', 1, true) ~= nil
    and bankingState:find("BETTERUI.Banking.RegisterWatchScenes", 1, true) ~= nil,
    "inventory and banking register their watch view scene pairs before setting views")
check(inventoryState:find("SetInventoryWatchView", 1, true) ~= nil
    and bankingState:find("SetBankingWatchView", 1, true) ~= nil,
    "inventory and banking feed production view context into watch mode")
check(inventory:find("visible=0", 1, true) ~= nil and inventory:find("visible=1", 1, true) ~= nil
    and banking:find("visible=0", 1, true) ~= nil and banking:find("visible=1", 1, true) ~= nil,
    "inventory and banking snapshots distinguish hidden and visible windows")
check(keybinds:find("inventory keybind refreshed", 1, true) ~= nil
    and keybinds:find("CATEGORY.STATE", 1, true) ~= nil,
    "successful inventory keybind refresh outcomes are visible at STATE level")
check(positionManager:find('"list.position"', 1, true) ~= nil
    and positionManager:find('"saved"', 1, true) ~= nil
    and positionManager:find('"restored"', 1, true) ~= nil
    and positionManager:find('"cleared"', 1, true) ~= nil,
    "saved list positions emit structured save/restore/clear diagnostics")
check(keybinds:find("inventory keybind refresh incomplete", 1, true) ~= nil,
    "incomplete inventory keybind refresh outcomes remain visible at STATE level")
check(keybinds:find("inventory dialog restore complete", 1, true) ~= nil
    and keybinds:find("inventory dialog restore skipped", 1, true) ~= nil
    and itemActions:find("inventory dialog finish restore complete", 1, true) ~= nil,
    "dialog restore attempts log their eventual state/keybind outcome")
check(itemActions:find("pendingHeaderSort", 1, true) ~= nil
    and bankingActions:find("pendingHeaderSort", 1, true) ~= nil
    and dialogRestore:find('"inventory.action_dialog.restore"', 1, true) ~= nil,
    "sort action-dialog handoff avoids transient keybind restore and logs restore state")
check(headerSortIntegration:find("header sort list preserved", 1, true) ~= nil
    and headerSortIntegration:find("suspendList", 1, true) ~= nil,
    "header sort mode logs list preservation and keeps list suspension explicitly opt-in")
check(itemActions:find("inventory dialog finish restore waiting", 1, true) ~= nil
    and keybinds:find("inventory dialog restore waiting", 1, true) ~= nil
    and keybinds:find("sequenceKey", 1, true) ~= nil,
    "dialog restore retry waits and unique task names are observable")
check(keybinds:find("hasStrip", 1, true) ~= nil and keybinds:find("updated =", 1, true) ~= nil,
    "inventory keybind logs distinguish missing strip from successful update")
check(slotActions:find("inventory primary action resolved", 1, true) ~= nil
    and slotActions:find("inventory primary action invoked", 1, true) ~= nil
    and slotActions:find("GetSlotItemLink", 1, true) ~= nil,
    "primary action resolution and invocation log selected action and item metadata")
check(itemList:find("inventory item list refreshed", 1, true) ~= nil,
    "inventory item-list refresh outcomes are visible at STATE level")
check(inventory:find("inventory category list refreshed", 1, true) ~= nil
    and inventory:find("inventory category list refresh scheduled", 1, true) ~= nil
    and inventory:find("updates =", 1, true) ~= nil,
    "inventory update/category refresh reactions are visible as coalesced STATE outcomes")
check(bankList:find("bank list refreshed", 1, true) ~= nil,
    "bank list refresh outcomes are visible at STATE level")
check(bankingKeybinds:find("bank primary transfer invoked", 1, true) ~= nil
    and bankingKeybinds:find('LogBankKeybindState("bank primary transfer invoked"', 1, true) ~= nil
    and bankingKeybinds:find('}, "TRANSFER")', 1, true) ~= nil
    and transferActions:find("bank action dialog shown", 1, true) ~= nil,
    "banking primary transfer and action dialog hand-offs are visible with transfer-category landmarks")
check(banking:find("bank currency UI refresh complete", 1, true) ~= nil,
    "bank currency event refreshes emit STATE outcomes")
check(banking:find("beforeCarriedGold", 1, true) ~= nil
    and banking:find("afterBankGold", 1, true) ~= nil
    and banking:find('"bank.open"', 1, true) ~= nil,
    "bank open and currency event refreshes include replayable gold/capacity snapshots")
check(banking:find('"bank.upgrade"', 1, true) ~= nil
    and banking:find("EVENT_INVENTORY_BUY_BANK_SPACE", 1, true) ~= nil
    and banking:find("EVENT_INVENTORY_BOUGHT_BANK_SPACE", 1, true) ~= nil
    and banking:find("EVENT_INVENTORY_BANK_CAPACITY_CHANGED", 1, true) ~= nil,
    "bank-space buy, bought, and capacity-change events emit replayable upgrade traces")
check(bankingActions:find("bank.action_dialog.confirm_branch", 1, true) ~= nil
    and bankingActions:find("stack_transfer", 1, true) ~= nil
    and bankingActions:find("bank.junk_toggle", 1, true) ~= nil
    and bankingActions:find("releaseRequested", 1, true) ~= nil
    and bankingActions:find("missingSelectedAction", 1, true) ~= nil
    and bankingActions:find("missingSelectedData", 1, true) ~= nil,
    "bank action-dialog branches log before/after outcomes, release requests, and blocked no-op reasons")
check(currencySelector:find('"skipped"', 1, true) ~= nil
    and currencySelector:find("previousCurrencyType", 1, true) ~= nil,
    "bank currency selector logs skipped show and preserves hide context")
check(transferActions:find("bank transfer list refresh scheduled", 1, true) ~= nil
    and transferActions:find("bank transfer list refresh skipped", 1, true) ~= nil
    and transferActions:find("flow = flow", 1, true) ~= nil,
    "bank transfer refresh scheduling, skipped paths, and deferred flow context are visible")
check(listRefreshManager:find("pendingRefreshFlow", 1, true) ~= nil
    and listRefreshManager:find("coalescedCount", 1, true) ~= nil
    and listRefreshManager:find("options.flow", 1, true) ~= nil
    and transferActions:find("coalesce = true", 1, true) ~= nil,
    "list refresh coalescing carries the latest flow and coalesced count")
check(transferActions:find('pcall(watchdog.Expect, "bank.transfer"', 1, true) ~= nil
    and transferActions:find('pcall(watchdog.Resolve, "bank.transfer"', 1, true) ~= nil
    and countPlain(transferActions, 'WatchdogResolveTransfer(key, "expired")') >= 2,
    "bank pending transfers register and all expiry paths resolve watchdog expectations")
check(tradingHouseFlow:find('pcall(watchdog.Expect, "th.op"', 1, true) ~= nil
    and tradingHouseFlow:find('pcall(watchdog.Resolve, "th.op"', 1, true) ~= nil
    and tradingHouseFlow:find("TH.ClearPendingOperation and TH.ClearPendingOperation(operation)", 1, true) ~= nil,
    "trading house pending operations register and resolve watchdog expectations")
check(listRefreshManager:find('pcall(watchdog.Expect, "list.refresh"', 1, true) ~= nil
    and listRefreshManager:find('refreshWatchdogPrefix = "manager"', 1, true) ~= nil
    and listRefreshManager:find('local watchdogKey = tostring(self.refreshWatchdogPrefix or "manager") .. ":" .. tostring(refreshToken)', 1, true) ~= nil
    and listRefreshManager:find('WatchdogResolveRefresh(options.watchdogKey, "executed")', 1, true) ~= nil
    and listRefreshManager:find('WatchdogResolveRefresh(self.pendingRefreshWatchdogKey, "cancelled")', 1, true) ~= nil,
    "list refresh queue/execute/cancel paths register namespaced watchdog expectations")
check(containsAfter(listRefreshManager, 'BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.LIST, "list.refresh", "executed"',
    'WatchdogResolveRefresh(options.watchdogKey, "executed")'),
    "list refresh resolves watchdog expectations after the executed outcome record")
check(listRefreshManager:find('WatchdogResolveRefresh(watchdogKey, "stale")', 1, true) ~= nil
    and containsAfter(listRefreshManager, 'WatchdogResolveRefresh(watchdogKey, "stale")',
        'self.pendingRefreshWatchdogKey = nil'),
    "list refresh stale-token path resolves and clears its active watchdog key")
check(builogCommands:find("Watchdog: pending=%s flows=%s detected=%s resolved=%s", 1, true) ~= nil
    and builogCommands:find("watchdog: pending=%s flows=%s detected=%s resolved=%s", 1, true) ~= nil,
    "builog status and buihealth include watchdog stats")
check(vendor:find('RegisterViewScene("vendor"', 1, true) ~= nil
    and vendorControllerRuntime:find('RegisterViewScene("vendor"', 1, true) ~= nil
    and vendorControllerRuntime:find('watch.SetView("vendor."', 1, true) ~= nil
    and countPlain(vendorControllerRuntime, "SetVendorWatchView(mode)") >= 2
    and tradingHouseClass:find('RegisterViewScene("th"', 1, true) ~= nil
    and tradingHouseClass:find('watch.SetView("th."', 1, true) ~= nil
    and countPlain(tradingHouseClass, "SetTradingHouseWatchView(mode)") >= 2
    and companionModule:find('RegisterViewScene("companions"', 1, true) ~= nil
    and companionsRuntime:find('RegisterViewScene("companions"', 1, true) ~= nil
    and companionsRuntime:find('SetCompanionWatchView("companions.list"', 1, true) ~= nil
    and companionsRuntime:find("onShowing = function", 1, true) ~= nil
    and companionsRuntime:find('reason = "sceneHidden"', 1, true) ~= nil
    and not companionsRuntime:find('SetCompanionWatchView(nil)%s*TraceCompanionRuntime%("companions.event", "skipped"', 1, false)
    and writCore:find('SetWritWatchView("writs.panel"', 1, true) ~= nil
    and writCore:find("SetWritWatchView(nil)", 1, true) ~= nil,
    "vendor, trading house, companions, and writs publish watch view context")
check(transferActions:find("guild_slot_update", 1, true) ~= nil
    and transferActions:find("EVENT_GUILD_BANK_ITEM_ADDED", 1, true) ~= nil
    and transferActions:find("EVENT_GUILD_BANK_ITEM_REMOVED", 1, true) ~= nil
    and transferActions:find("EVENT_GUILD_BANK_UPDATED_QUANTITY", 1, true) ~= nil
    and transferActions:find("cleared = cleared == true", 1, true) ~= nil,
    "guild-bank item updates clear pending transfer markers with slot-level traces")
check(resourceOrbs:find("DescribeControlForTrace", 1, true) ~= nil
    and resourceOrbs:find("rootControl", 1, true) ~= nil
    and resourceOrbs:find("orbOffset", 1, true) ~= nil,
    "resource orb layout/watch traces include linked control positions and settings offsets")
check(resourceOrbs:find("RunTraceWithoutLastAction", 1, true) ~= nil
    and resourceOrbs:find("updatesLastAction", 1, true) ~= nil
    and resourceOrbs:find('["resource_orbs.force_layout"] = true', 1, true) ~= nil
    and resourceOrbs:find('RunTraceWithoutLastAction(function()', 1, true) ~= nil,
    "resource orb force-layout maintenance traces do not overwrite lastAction context")
check(headerSortController:find("clear_sort_skipped", 1, true) ~= nil
    and headerSortController:find("callback_before", 1, true) ~= nil
    and headerSortController:find("callback_after", 1, true) ~= nil
    and headerSortKeybinds:find("header sort keybind refresh failed", 1, true) ~= nil
    and headerSortKeybinds:find("header sort keybind ownership lost", 1, true) ~= nil,
    "header sort traces clear/apply reasons plus keybind refresh and ownership failures")
check(interfaceLog:find("IsPriorityLine", 1, true) ~= nil
    and interfaceLog:find("PRIORITY_CATEGORIES", 1, true) ~= nil
    and interfaceLog:find("STATE = true", 1, true) ~= nil
    and interfaceLog:find("SCENE = true", 1, true) ~= nil
    and interfaceLog:find("DIALOG = true", 1, true) ~= nil
    and interfaceLog:find("local level, category = header:match", 1, true) ~= nil
    and interfaceLog:find("RawEmit(line, IsPriorityLine(line))", 1, true) ~= nil,
    "interface log priority lines keep trace state visible under throttle pressure")
check(listRefreshManager:find("restoreReason", 1, true) ~= nil
    and listRefreshManager:find("restoredById", 1, true) ~= nil
    and listRefreshManager:find("savedUniqueIdNotFound", 1, true) ~= nil
    and listRefreshManager:find("indexClamped", 1, true) ~= nil,
    "list refresh restore traces identify id/index/clamp fallback reasons")
check(companionsRuntime:find('"companions.event"', 1, true) ~= nil
    and companionsRuntime:find("refresh_complete", 1, true) ~= nil
    and companionsRuntime:find("scene_hide_requested", 1, true) ~= nil
    and companionModule:find('"companions.init"', 1, true) ~= nil
    and companionModule:find('"missingInteraction"', 1, true) ~= nil
    and companionItemList:find("GetCompanionTraitName", 1, true) ~= nil
    and companionItemList:find("traitName = GetCompanionTraitName", 1, true) ~= nil,
    "companion activation, deactivation, inventory refresh, init retry, and trait data are traceable")
check(companionActions:find("ResolveActionEligibility", 1, true) ~= nil
    and companionActions:find("eligibility", 1, true) ~= nil
    and companionActions:find("result = didShowDialog == true", 1, true) ~= nil
    and companionDialogs:find("batch_begin", 1, true) ~= nil
    and companionDialogs:find("batch_end", 1, true) ~= nil
    and companionDialogs:find("select_all", 1, true) ~= nil
    and companionDialogs:find("listCount", 1, true) ~= nil,
    "companion action menus, split dialog result, and batch selection/destroy lifecycle are traceable")
check(fontLocalization:find('"western"', 1, true) ~= nil
    and nameplates:find("IsFontLocalizedForLanguage", 1, true) ~= nil
    and nameplates:find("originalFontsNotCaptured", 1, true) ~= nil
    and nameplates:find("currentKeyboardFont", 1, true) ~= nil
    and nameplateSettings:find("FONT_STYLE_OUTLINE or 1", 1, true) ~= nil,
    "nameplate font localization, reset fallback, and settings defaults are guarded")
check(vendor:find('"vendor.store_event"', 1, true) ~= nil
    and vendor:find("open_requested", 1, true) ~= nil
    and vendor:find("close_requested", 1, true) ~= nil
    and vendorLifecycle:find("cleanup_bridge", 1, true) ~= nil
    and vendorBridge:find("ScheduleOpenStoreSync", 1, true) ~= nil
    and vendorBridge:find("give_up", 1, true) ~= nil,
    "vendor open/close handoff, bridge sync retries, and cleanup are traceable")
check(vendorRepair:find('"vendor.repair"', 1, true) ~= nil
    and vendorRepair:find('"vendor.repair_all_dialog"', 1, true) ~= nil
    and vendorRepair:find('"confirm"', 1, true) ~= nil
    and vendorRepair:find("declineCallback", 1, true) ~= nil
    and vendorRepair:find("pendingRepairAllTrace", 1, true) ~= nil
    and vendorBatch:find('"vendor.batch_ack"', 1, true) ~= nil
    and vendorBatch:find('"scheduled_next"', 1, true) ~= nil,
    "vendor repair, repair-all confirmation, and batch ack/step progression are traceable")
check(vendorBuy:find('"vendor.buy"', 1, true) ~= nil
    and vendorBuy:find('"blocked"', 1, true) ~= nil
    -- BUI-CONS-008: buy routes the requested/settled envelope (incl. goldBefore
    -- threading) through Vendor.DispatchTracedAction in VendorModePolicy.lua.
    and vendorBuy:find('Vendor.DispatchTracedAction("vendor.buy"', 1, true) ~= nil
    and vendorBuy:find("expectedPrice", 1, true) ~= nil
    and vendorBuy:find('"cannotAfford"', 1, true) ~= nil
    and vendorBuy:find('"cannotCarry"', 1, true) ~= nil
    and vendorBuy:find("IsPrimaryActionEnabled", 1, true) ~= nil
    and vendorSell:find('"vendor.sell"', 1, true) ~= nil
    and vendorSell:find('"blocked"', 1, true) ~= nil
    -- BUI-CONS-008: the direct sell envelope routes through DispatchTracedAction;
    -- the sell_all_junk path keeps the literal requested/settled pair.
    and vendorSell:find('Vendor.DispatchTracedAction("vendor.sell"', 1, true) ~= nil
    and vendorSell:find('Vendor.ScheduleActionSettled("vendor.sell_all_junk"', 1, true) ~= nil
    and vendorSell:find("goldBefore", 1, true) ~= nil
    and vendorSell:find("expectedPrice", 1, true) ~= nil
    and vendorSell:find('"goldCap"', 1, true) ~= nil
    and vendorSell:find("Sell:SellAllJunk", 1, true) ~= nil
    and vendorSell:find("IsPrimaryActionEnabled", 1, true) ~= nil,
    "vendor buy/sell primary gating, denial reasons, junk sale, and requested/settled outcome traces are traceable")
check(writCore:find('"writ.objectives"', 1, true) ~= nil
    and writCore:find("objectiveSummary", 1, true) ~= nil
    and writCore:find("GetJournalQuestNumSteps", 1, true) ~= nil
    and writCore:find("objectives = {}", 1, true) ~= nil
    and writCore:find("readErrorCount", 1, true) ~= nil
    and writModule:find("OnQuestJournalChanged", 1, true) ~= nil
    and writModule:find("cachedWritsBefore", 1, true) ~= nil
    and writModule:find("EVENT_QUEST_CONDITION_COUNTER_CHANGED", 1, true) ~= nil,
    "writ objective summaries and quest journal refresh invalidation are traceable")
check(writModule:find("currentCraftingType ~= id", 1, true) ~= nil
    and writModule:find('"stationClosedOrChanged"', 1, true) ~= nil
    and writModule:find("Writs.CacheControls()", 1, true) ~= nil,
    "writ deferred craft refreshes are station-bound and setup caches controls before events")
check(writCore:find('"show_error"', 1, true) ~= nil
    and writCore:find("Writs.HidePanel()", 1, true) ~= nil
    and writCore:find("panelHidden = true", 1, true) ~= nil,
    "writ panel hides and traces stale-panel cleanup on refresh failures")
check(betterUiRoot:find('{ name = "Writs", namespace = "Writs", dependsOnCIM = true }', 1, true) ~= nil
    and betterUiRoot:find('{ moduleName = "Writs", nameStringId = "SI_BETTERUI_ENABLE_WRITS", tooltipStringId = "SI_BETTERUI_ENABLE_WRITS_TOOLTIP", updatesCIM = true }', 1, true) ~= nil,
    "Writs root ownership keeps CIM trace infrastructure enabled")
check(tradingHouseFlow:find('"trading_house.scene_ownership"', 1, true) ~= nil
    and tradingHouseFlow:find('"trading_house.browse_state"', 1, true) ~= nil
    and tradingHouseFlow:find('"failed"', 1, true) ~= nil
    and tradingHouseFlow:find('"succeeded"', 1, true) ~= nil
    and tradingHouseFlow:find('"missingKeybindStrip"', 1, true) ~= nil
    and tradingHouseFlow:find("selected_changed_skipped", 1, true) ~= nil
    and tradingHouseFlow:find('local fn = data.fn or data["function"]', 1, true) ~= nil
    and tradingHouseClass:find('data["function"] = fn', 1, true) ~= nil
    and tradingHouseBrowse:find("deferredSearchToken", 1, true) ~= nil
    and tradingHouseBrowse:find("deferred_timeout_skipped", 1, true) ~= nil,
    "trading house scene ownership, deferred search, and response/keybind states are traceable")
check(tradingHouseBrowse:find('"trading_house.buy_dialog"', 1, true) ~= nil
    and tradingHouseBrowse:find("awaiting_choice", 1, true) ~= nil
    and tradingHouseBrowse:find("TracePendingBuyDialog", 1, true) ~= nil
    and tradingHouseListings:find('"trading_house.cancel_listing_dialog"', 1, true) ~= nil
    and tradingHouseListings:find("TracePendingCancelDialog", 1, true) ~= nil
    and tradingHouseListings:find("dialogReleased", 1, true) ~= nil
    and tradingHouseFilters:find("field_setup", 1, true) ~= nil
    and tradingHousePrice:find("selector_created", 1, true) ~= nil,
    "trading house buy/cancel dialogs, filter fields, and price selector setup are traceable")
check(tradingHouseFlow:find("RegisterCreateListingDialog", 1, true) ~= nil
    and tradingHouseFlow:find("SetPendingItemPost(BAG_BACKPACK, 0, 0)", 1, true) ~= nil
    and tradingHouseFlow:find('"trading_house.pending_post"', 1, true) ~= nil
    and tradingHouseFlow:find('"confirm_begin"', 1, true) ~= nil
    and tradingHouseFlow:find('"finished"', 1, true) ~= nil
    and tradingHouseBrowse:find("SetPendingItemPurchase(tradingHouseIndex)", 1, true) ~= nil
    and tradingHouseBrowse:find('"confirm"', 1, true) ~= nil
    and tradingHouseListings:find("CancelTradingHouseListing", 1, true) ~= nil
    and tradingHouseListings:find('"confirm"', 1, true) ~= nil,
    "trading house buy/post/cancel dialog callbacks expose pending-state and cleanup transitions")
check(orbBars:find('GetAbilityCastInfo(abilityId, nil, "player")', 1, true) ~= nil
    and orbBars:find('"resource_orbs.cast_bar"', 1, true) ~= nil
    and orbBars:find("outsideWindow", 1, true) ~= nil
    and orbBarUpdates:find("cast_start_skipped", 1, true) ~= nil
    and orbBarUpdates:find("cast_stop", 1, true) ~= nil,
    "resource orb cast-bar events and power probe decisions are traceable")
check(orbCombat:find('"resource_orbs.combat_icon"', 1, true) ~= nil
    and orbCombat:find("fallback_resolved", 1, true) ~= nil
    and orbEvents:find("hide_enforce_scheduled", 1, true) ~= nil
    and frontBarCooldowns:find('"resource_orbs.quickslot_count"', 1, true) ~= nil
    and resourceOrbs:find("setupDidNotInitialize", 1, true) ~= nil,
    "resource orb combat icon anchoring, hide enforcement, quickslot count, and apply settings are traceable")
check(ultimateManager:find('"resource_orbs.ultimate_meter"', 1, true) ~= nil
    and ultimateManager:find('"resource_orbs.ultimate_number"', 1, true) ~= nil
    and backBarManager:find('"resource_orbs.back_bar"', 1, true) ~= nil
    and backBarManager:find('"resource_orbs.back_bar_layout"', 1, true) ~= nil
    and frontBarManager:find('"resource_orbs.front_bar_usability"', 1, true) ~= nil
    and frontBarManager:find('"resource_orbs.front_bar_layout"', 1, true) ~= nil
    and orbVisuals:find('"resource_orbs.orb_layout"', 1, true) ~= nil
    and orbBarUpdates:find('"resource_orbs.mount_stamina"', 1, true) ~= nil
    and resourceOrbs:find("skipped_disabled", 1, true) ~= nil,
    "resource orb ultimate, front/back bar layout, orb layout, mount stamina, and disabled callbacks are traceable")
check(resourceOrbs:find("RestoreNativeBars", 1, true) ~= nil
    and resourceOrbs:find("SetHiddenForReason('ResourceOrbFrames', false)", 1, true) ~= nil
    and resourceOrbs:find("nativeBarsRestored", 1, true) ~= nil
    and frontBarManager:find("RestoreNativeActionBar", 1, true) ~= nil,
    "resource orb disable restores native action and attribute bar visibility")
check(inventoryModule:find('"inventory.split_stack_lock"', 1, true) ~= nil
    and inventoryModule:find("type(_G.ZO_StackSplit_SplitItem)", 1, true) ~= nil
    and inventoryDialogs:find('"inventory.split_stack_dialog"', 1, true) ~= nil
    and inventoryDialogs:find('"inventory.destroy_dialog"', 1, true) ~= nil
    and inventoryDialogs:find('"inventory.armory_destroy_dialog"', 1, true) ~= nil
    and inventoryDialogs:find("staleSlot", 1, true) ~= nil
    and inventoryDialogs:find("refreshScheduled", 1, true) ~= nil
    and inventoryDialogs:find("pickup_success", 1, true) ~= nil
    and itemActions:find('"inventory.split_stack"', 1, true) ~= nil,
    "inventory split-stack lock, dialog, pickup, and action-menu paths are traceable")
check(tooltips:find("sourceSummary", 1, true) ~= nil
    and tooltips:find("bag_link_failed", 1, true) ~= nil
    and tooltips:find("ScheduleTooltipEquippedRefresh", 1, true) ~= nil
    and generalSetup:find("direct_delete_dispatched", 1, true) ~= nil
    and generalSetup:find("retry_scheduled", 1, true) ~= nil
    and generalSetup:find("InstallCraftingPriceTooltipHooks", 1, true) ~= nil
    and craftingPriceTooltip:find("BETTERUI.Log.MakeTracer{", 1, true) ~= nil,
    "general interface tooltip sources, bag context, mail delete, crafting hook retry, and tooltip action records are traceable")
check(tooltips:find("source_failed", 1, true) ~= nil
    and tooltips:find("renderedSources", 1, true) ~= nil
    and tooltips:find("path_recovery_failed", 1, true) ~= nil
    and tooltips:find("controlInvalid", 1, true) ~= nil
    and tooltips:find("house_bank_lookup_failed", 1, true) ~= nil
    and generalModule:find('m_options["showCraftingMarketPrice"] = true', 1, true) ~= nil
    and generalSetup:find('rawget(_G, "KEYBOARD_CHAT_SYSTEM")', 1, true) ~= nil
    and generalSetup:find("direct_delete_failed", 1, true) ~= nil
    and generalSetup:find("native_callback_failed", 1, true) ~= nil
    and craftingPriceTooltip:find("link_failed", 1, true) ~= nil
    and craftingPriceTooltip:find("marketApiError", 1, true) ~= nil
    and craftingPriceTooltip:find("retry_exhausted", 1, true) ~= nil,
    "general interface tooltip price, default, path recovery, deferred callback, mail, and crafting API failures are traceable")
check(generalSetup:find('GetModuleSettings("CIM")', 1, true) ~= nil
    and generalSetup:find("cimSettings and cimSettings.enableTooltipEnhancements", 1, true) ~= nil
    and generalSetup:find("cimSettings and cimSettings.tooltipSize", 1, true) ~= nil
    and generalSetup:find("settings and settings.ttcIntegration", 1, true) ~= nil
    and generalSetup:find("settings and settings.mmIntegration", 1, true) ~= nil
    and generalSetup:find("settings and settings.attIntegration", 1, true) ~= nil,
    "general interface snapshots read canonical CIM and market-integration setting keys")
check(settingsAccessor:find('"general_interface.tooltip_feature"', 1, true) ~= nil
    and settingsAccessor:find("TraceTooltipFeatureSetting", 1, true) ~= nil
    and tooltipSettings:find('SetModuleSetting("CIM", "enableTooltipEnhancements"', 1, true) ~= nil,
    "tooltip enhancement setting changes emit shared setting writes and feature diagnostics")
check(nameplates:find("NormalizeStyleValue", 1, true) ~= nil
    and nameplates:find("CloneSettingsValue", 1, true) ~= nil
    and nameplates:find("getter_failed", 1, true) ~= nil
    and nameplates:find("setter_failed", 1, true) ~= nil
    and nameplates:find('"nameplates.reset", "end"', 1, true) ~= nil
    and nameplateSettings:find("Nameplates.NormalizeStyleValue", 1, true) ~= nil,
    "nameplate style normalization, default cloning, getter/setter failures, and reset close spans are traceable")
check(bankingHeader:find('"bank.header"', 1, true) ~= nil
    and bankingHeader:find("entries_built", 1, true) ~= nil
    and bankingFooter:find('"bank.footer"', 1, true) ~= nil
    and bankingFooter:find("refreshed", 1, true) ~= nil
    and guildBankAdapter:find('"bank.guild_bank"', 1, true) ~= nil
    and guildBankAdapter:find("money_updated", 1, true) ~= nil,
    "bank header, footer, and guild-bank event/currency flows are traceable")
check(bankingKeybinds:find('"bank.primary_transfer"', 1, true) ~= nil
    and bankingKeybinds:find("transferPendingCleared", 1, true) ~= nil
    and itemActions:find("enter_skipped", 1, true) ~= nil
    and bankingActions:find("enter_skipped", 1, true) ~= nil,
    "pending bank transfers and header-sort scheduler failure exits are traceable")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
