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

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== builog flow instrumentation source contract ===\n")

local slotActions = readFile("Modules/Inventory/Actions/SlotActions.lua")
local itemActions = readFile("Modules/Inventory/Actions/ItemActionHandlers.lua")
local destroyAction = readFile("Modules/Inventory/Actions/DestroyAction.lua")
local actionHooks = readFile("Modules/Inventory/Actions/ActionDialogHooks.lua")
local transferActions = readFile("Modules/Banking/Actions/TransferActions.lua")
local inventory = readFile("Modules/Inventory/Inventory.lua")
local banking = readFile("Modules/Banking/Banking.lua")
local keybinds = readFile("Modules/Inventory/Core/InventoryClass.lua")
local itemList = readFile("Modules/Inventory/Lists/ItemListManager.lua")
local bankList = readFile("Modules/Banking/Lists/BankListManager.lua")
local inventoryState = readFile("Modules/Inventory/State/ListStateManager.lua")
local bankingState = readFile("Modules/Banking/State/StateManager.lua")
local bankingKeybinds = readFile("Modules/Banking/Keybinds/KeybindManager.lua")
local bankingActions = readFile("Modules/Banking/Actions/BankingActions.lua")
local currencySelector = readFile("Modules/Banking/Currency/CurrencySelector.lua")
local resourceOrbs = readFile("Modules/ResourceOrbFrames/ResourceOrbFrames.lua")
local headerSortController = readFile("Modules/CIM/UI/HeaderSortController.lua")
local headerSortKeybinds = readFile("Modules/CIM/UI/HeaderSortKeybinds.lua")
local interfaceLog = readFile("Modules/CIM/Core/Diagnostics/InterfaceLog.lua")
local companionsRuntime = readFile("Modules/Companions/Core/CompanionsRuntime.lua")
local companionItemList = readFile("Modules/Companions/Core/CompanionItemList.lua")
local fontLocalization = readFile("Modules/CIM/Core/Presentation/FontLocalization.lua")
local nameplates = readFile("Modules/Nameplates/Nameplates.lua")
local nameplateSettings = readFile("Modules/Nameplates/Settings.lua")
local vendor = readFile("Modules/Vendor/Vendor.lua")
local vendorRepair = readFile("Modules/Vendor/Components/RepairComponent.lua")
local vendorBridge = readFile("Modules/Vendor/Core/Bridge/VendorNativeStoreBridge.lua")
local vendorLifecycle = readFile("Modules/Vendor/Core/Lifecycle/VendorInteractionRuntime.lua")
local vendorBatch = readFile("Modules/Vendor/Core/VendorBatchRuntime.lua")
local writCore = readFile("Modules/Writs/Core/Writ.lua")
local writModule = readFile("Modules/Writs/Module.lua")
local tradingHouseFlow = readFile("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
local tradingHouseBrowse = readFile("Modules/TradingHouse/Components/BrowseComponent.lua")
local tradingHouseListings = readFile("Modules/TradingHouse/Components/ListingsComponent.lua")
local tradingHouseFilters = readFile("Modules/TradingHouse/Core/BrowseFilters.lua")
local tradingHousePrice = readFile("Modules/TradingHouse/Core/PriceEntry.lua")
local orbBars = readFile("Modules/ResourceOrbFrames/Core/OrbBars.lua")
local orbBarUpdates = readFile("Modules/ResourceOrbFrames/Core/OrbBarUpdates.lua")
local orbCombat = readFile("Modules/ResourceOrbFrames/Core/OrbCombatIndicators.lua")
local orbEvents = readFile("Modules/ResourceOrbFrames/Core/OrbEvents.lua")
local frontBarCooldowns = readFile("Modules/ResourceOrbFrames/SkillBar/FrontBarCooldowns.lua")
local inventoryModule = readFile("Modules/Inventory/Module.lua")
local inventoryDialogs = readFile("Modules/Inventory/Dialogs/InventoryDialogs.lua")
local generalSetup = readFile("Modules/GeneralInterface/Setup.lua")
local tooltips = readFile("Modules/GeneralInterface/Tooltips/Tooltips.lua")
local craftingPriceTooltip = readFile("Modules/GeneralInterface/Tooltips/CraftingPriceTooltip.lua")
local bankingHeader = readFile("Modules/Banking/UI/HeaderManager.lua")
local bankingFooter = readFile("Modules/Banking/UI/FooterManager.lua")
local guildBankAdapter = readFile("Modules/Banking/Core/GuildBankAdapter.lua")

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
check(transferActions:find("move_requested", 1, true) ~= nil
    and transferActions:find("pending_marked", 1, true) ~= nil
    and transferActions:find("pending_expired", 1, true) ~= nil,
    "bank transfers distinguish move requests from cursor requests and trace pending timeout state")
check(transferActions:find("bank transfer blocked", 1, true) ~= nil
    and transferActions:find("guild_transfer_denied", 1, true) ~= nil
    and transferActions:find("request_move_failed", 1, true) ~= nil
    and transferActions:find("GetTransferItemName", 1, true) ~= nil,
    "bank transfers log blocked capacity/permission paths and item metadata")
check(transferActions:find("guild bank transfer requested", 1, true) ~= nil
    and transferActions:find("guild bank transfer refresh decision", 1, true) ~= nil,
    "guild bank transfers emit flow context through refresh scheduling")
check(bankingKeybinds:find("bankCurrencyTransfer", 1, true) ~= nil
    and bankingKeybinds:find('TraceBankCurrencyAction("completed"', 1, true) ~= nil
    and bankingKeybinds:find("bank currency transfer failed", 1, true) ~= nil,
    "bank currency transfers emit completed and failed builog flow context")
check(bankingKeybinds:find("bank.mode_toggle", 1, true) ~= nil
    and bankingKeybinds:find("bank.upgrade", 1, true) ~= nil
    and bankingKeybinds:find("BETTERUI.Banking.IsTransferPending(bagId, slotIndex)", 1, true) ~= nil,
    "bank mode toggles, upgrade prompts, and all transfer modes expose keybind state transitions")
check(inventory:find('RegisterSnapshotProvider("inventory"', 1, true) ~= nil,
    "inventory registers a watch snapshot provider")
check(banking:find('RegisterSnapshotProvider("banking"', 1, true) ~= nil,
    "banking registers a watch snapshot provider")
check(inventoryState:find("SetInventoryWatchView", 1, true) ~= nil
    and bankingState:find("SetBankingWatchView", 1, true) ~= nil,
    "inventory and banking feed production view context into watch mode")
check(inventory:find("visible=0", 1, true) ~= nil and inventory:find("visible=1", 1, true) ~= nil
    and banking:find("visible=0", 1, true) ~= nil and banking:find("visible=1", 1, true) ~= nil,
    "inventory and banking snapshots distinguish hidden and visible windows")
check(keybinds:find("inventory keybind refreshed", 1, true) ~= nil
    and keybinds:find("CATEGORY.STATE", 1, true) ~= nil,
    "successful inventory keybind refresh outcomes are visible at STATE level")
check(keybinds:find("inventory keybind refresh incomplete", 1, true) ~= nil,
    "incomplete inventory keybind refresh outcomes remain visible at STATE level")
check(keybinds:find("inventory dialog restore complete", 1, true) ~= nil
    and keybinds:find("inventory dialog restore skipped", 1, true) ~= nil
    and itemActions:find("inventory dialog finish restore complete", 1, true) ~= nil,
    "dialog restore attempts log their eventual state/keybind outcome")
check(itemActions:find("pendingHeaderSort", 1, true) ~= nil
    and bankingActions:find("pendingHeaderSort", 1, true) ~= nil
    and itemActions:find('"inventory.action_dialog.restore"', 1, true) ~= nil,
    "sort action-dialog handoff avoids transient keybind restore and logs restore state")
check(itemActions:find("inventory dialog finish restore waiting", 1, true) ~= nil
    and keybinds:find("inventory dialog restore waiting", 1, true) ~= nil
    and keybinds:find("inventoryDialogRestoreSequence", 1, true) ~= nil,
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
    and transferActions:find("bank action dialog shown", 1, true) ~= nil,
    "banking primary transfer and action dialog hand-offs are visible")
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
check(headerSortController:find("clear_sort_skipped", 1, true) ~= nil
    and headerSortController:find("callback_before", 1, true) ~= nil
    and headerSortController:find("callback_after", 1, true) ~= nil
    and headerSortKeybinds:find("header sort keybind refresh failed", 1, true) ~= nil,
    "header sort traces clear/apply reasons and keybind refresh failures")
check(interfaceLog:find("IsPriorityLine", 1, true) ~= nil
    and interfaceLog:find("STATE |", 1, true) ~= nil
    and interfaceLog:find("SCENE |", 1, true) ~= nil
    and interfaceLog:find("DIALOG |", 1, true) ~= nil
    and interfaceLog:find("RawEmit(line, priority)", 1, true) ~= nil,
    "interface log priority lines keep trace state visible under throttle pressure")
check(companionsRuntime:find('"companions.event"', 1, true) ~= nil
    and companionsRuntime:find("refresh_complete", 1, true) ~= nil
    and companionsRuntime:find("scene_hide_requested", 1, true) ~= nil
    and companionItemList:find("GetCompanionTraitName", 1, true) ~= nil
    and companionItemList:find("traitName = GetCompanionTraitName", 1, true) ~= nil,
    "companion activation, deactivation, inventory refresh, and trait data are traceable")
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
check(writCore:find('"writ.objectives"', 1, true) ~= nil
    and writCore:find("objectiveSummary", 1, true) ~= nil
    and writCore:find("GetJournalQuestNumSteps", 1, true) ~= nil
    and writCore:find("objectives = {}", 1, true) ~= nil
    and writCore:find("readErrorCount", 1, true) ~= nil
    and writModule:find("OnQuestJournalChanged", 1, true) ~= nil
    and writModule:find("cachedWritsBefore", 1, true) ~= nil
    and writModule:find("EVENT_QUEST_CONDITION_COUNTER_CHANGED", 1, true) ~= nil,
    "writ objective summaries and quest journal refresh invalidation are traceable")
check(tradingHouseFlow:find('"trading_house.scene_ownership"', 1, true) ~= nil
    and tradingHouseFlow:find('"trading_house.browse_state"', 1, true) ~= nil
    and tradingHouseFlow:find('"failed"', 1, true) ~= nil
    and tradingHouseFlow:find("selected_changed_skipped", 1, true) ~= nil
    and tradingHouseBrowse:find("deferredSearchToken", 1, true) ~= nil
    and tradingHouseBrowse:find("deferred_timeout_skipped", 1, true) ~= nil,
    "trading house scene ownership, deferred search, and failed response state are traceable")
check(tradingHouseBrowse:find('"trading_house.buy_dialog"', 1, true) ~= nil
    and tradingHouseBrowse:find("awaiting_choice", 1, true) ~= nil
    and tradingHouseBrowse:find("TracePendingBuyDialog", 1, true) ~= nil
    and tradingHouseListings:find('"trading_house.cancel_listing_dialog"', 1, true) ~= nil
    and tradingHouseListings:find("TracePendingCancelDialog", 1, true) ~= nil
    and tradingHouseListings:find("dialogReleased", 1, true) ~= nil
    and tradingHouseFilters:find("field_setup", 1, true) ~= nil
    and tradingHousePrice:find("selector_created", 1, true) ~= nil,
    "trading house buy/cancel dialogs, filter fields, and price selector setup are traceable")
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
    and craftingPriceTooltip:find("flow = event", 1, true) ~= nil,
    "general interface tooltip sources, bag context, mail delete, and tooltip action records are traceable")
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
