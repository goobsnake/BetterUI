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
local resourceOrbs = readFile("Modules/ResourceOrbFrames/ResourceOrbFrames.lua")
local genericSlotActions = readFile("Modules/CIM/Actions/GenericSlotActions.lua")
local listRefreshManager = readFile("Modules/CIM/Lists/ListRefreshManager.lua")
local headerSortController = readFile("Modules/CIM/UI/HeaderSortController.lua")
local headerSortKeybinds = readFile("Modules/CIM/UI/HeaderSortKeybinds.lua")
local interfaceLog = readFile("Modules/CIM/Core/Diagnostics/InterfaceLog.lua")
local companionActions = readFile("Modules/Companions/Actions/CompanionActions.lua")
local companionDialogs = readFile("Modules/Companions/Dialogs/CompanionDialogs.lua")
local companionModule = readFile("Modules/Companions/Module.lua")
local companionsRuntime = readFile("Modules/Companions/Core/CompanionsRuntime.lua")
local companionItemList = readFile("Modules/Companions/Core/CompanionItemList.lua")
local fontLocalization = readFile("Modules/CIM/Core/Presentation/FontLocalization.lua")
local nameplates = readFile("Modules/Nameplates/Nameplates.lua")
local nameplateSettings = readFile("Modules/Nameplates/Settings.lua")
local vendor = readFile("Modules/Vendor/Vendor.lua")
local vendorBuy = readFile("Modules/Vendor/Components/BuyComponent.lua")
local vendorSell = readFile("Modules/Vendor/Components/SellComponent.lua")
local vendorRepair = readFile("Modules/Vendor/Components/RepairComponent.lua")
local vendorBridge = readFile("Modules/Vendor/Core/Bridge/VendorNativeStoreBridge.lua")
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
    and vendorBuy:find('"request"', 1, true) ~= nil
    and vendorBuy:find('"requested"', 1, true) ~= nil
    and vendorBuy:find('"cannotAfford"', 1, true) ~= nil
    and vendorBuy:find('"cannotCarry"', 1, true) ~= nil
    and vendorBuy:find("IsPrimaryActionEnabled", 1, true) ~= nil
    and vendorSell:find('"vendor.sell"', 1, true) ~= nil
    and vendorSell:find('"blocked"', 1, true) ~= nil
    and vendorSell:find('"request"', 1, true) ~= nil
    and vendorSell:find('"requested"', 1, true) ~= nil
    and vendorSell:find('"goldCap"', 1, true) ~= nil
    and vendorSell:find("Sell:SellAllJunk", 1, true) ~= nil
    and vendorSell:find("IsPrimaryActionEnabled", 1, true) ~= nil,
    "vendor buy/sell primary gating, denial reasons, junk sale, and request/result traces are traceable")
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
    and craftingPriceTooltip:find("flow = event", 1, true) ~= nil,
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
