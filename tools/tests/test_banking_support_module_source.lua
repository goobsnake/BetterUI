--[[
File: tools/tests/test_banking_support_module_source.lua
Purpose: Source regressions for smaller Banking support modules that mostly
         expose helper seams, constants, and adapter contracts.

Usage:
  lua tools/tests/test_banking_support_module_source.lua
]]

if false then
    dofile("Modules/Banking/Categories/CategoryManager.lua")
    dofile("Modules/Banking/Constants.lua")
    dofile("Modules/Banking/Core/GuildBankAdapter.lua")
    dofile("Modules/Banking/Core/RefreshIntegration.lua")
    dofile("Modules/Banking/Currency/CurrencySelector.lua")
    dofile("Modules/Banking/Dialogs/QuantityDialog.lua")
    dofile("Modules/Banking/Lists/BankListManager.lua")
    dofile("Modules/Banking/Lists/BankRowSetup.lua")
    dofile("Modules/Banking/Module.lua")
    dofile("Modules/Banking/Scene/BankingSceneLifecycle.lua")
    dofile("Modules/Banking/Search/SearchManager.lua")
    dofile("Modules/Banking/State/StateManager.lua")
    dofile("Modules/Banking/UI/FooterManager.lua")
    dofile("Modules/Banking/UI/HeaderManager.lua")
end

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local categoryManager = read_file("Modules/Banking/Categories/CategoryManager.lua")
assert_true(categoryManager:find("function CategoryManager.ComputeVisibleBankCategories") ~= nil,
    "CategoryManager exposes ComputeVisibleBankCategories")
assert_true(categoryManager:find("BETTERUI%.CIM%.SharedItemSupport%.DoesItemMatchCategory") ~= nil,
    "CategoryManager delegates category matching to SharedItemSupport")
assert_true(categoryManager:find('if visibility%["all"%] ~= nil then') ~= nil,
    "CategoryManager keeps the synthetic all-category visible when present")
assert_true(categoryManager:find("function BETTERUI%.Banking%.Class%.ComputeVisibleBankCategories") ~= nil,
    "CategoryManager exposes the Banking class wrapper")

local constants = read_file("Modules/Banking/Constants.lua")
assert_true(constants:find("BETTERUI%.Banking%.CONST%.CAROUSEL") ~= nil,
    "Banking constants define carousel overrides")
assert_true(constants:find("function BETTERUI%.Banking%.CONST%.GetSearchConstants%(%)") ~= nil,
    "Banking constants expose the shared search constant getter")
assert_true(constants:find("BETTERUI%.Banking%.CONST%.CURRENCY_TEXTURES") ~= nil,
    "Banking constants define currency selector textures")
assert_true(constants:find("BETTERUI_BANK_MOVE_COALESCE_DELAY_MS") ~= nil,
    "Banking constants re-export move coalescing timing")

local guildBankAdapter = read_file("Modules/Banking/Core/GuildBankAdapter.lua")
assert_true(guildBankAdapter:find("function GuildBank%.IsGuildBankMode%(%)") ~= nil,
    "GuildBankAdapter exposes guild-bank mode detection")
assert_true(guildBankAdapter:find("function GuildBank%.CanDeposit%(%)") ~= nil,
    "GuildBankAdapter exposes deposit permission checks")
assert_true(guildBankAdapter:find("function GuildBank%.CanWithdraw%(%)") ~= nil,
    "GuildBankAdapter exposes withdraw permission checks")
assert_true(guildBankAdapter:find("function GuildBank%.GetPermissionDenialReason%(mode%)") ~= nil,
    "GuildBankAdapter exposes denial-reason formatting")
assert_true(guildBankAdapter:find("function GuildBank%.GetSourceBags%(mode%)") ~= nil,
    "GuildBankAdapter exposes source bag resolution")
assert_true(guildBankAdapter:find("function GuildBank%.GetDepositTargetBag%(%)") ~= nil,
    "GuildBankAdapter exposes deposit target resolution")

local refreshIntegration = read_file("Modules/Banking/Core/RefreshIntegration.lua")
assert_true(refreshIntegration:find("function BETTERUI%.Banking%.InitializeRefreshManager%(%)") ~= nil,
    "RefreshIntegration exposes refresh-manager initialization")
assert_true(refreshIntegration:find("ListRefreshManager:New%(%{") ~= nil,
    "RefreshIntegration constructs a Banking ListRefreshManager")

local currencySelector = read_file("Modules/Banking/Currency/CurrencySelector.lua")
assert_true(currencySelector:find("local function BuildBankUpgradeDetailsLines%(%)") ~= nil,
    "CurrencySelector builds personal-bank upgrade detail rows")
assert_true(currencySelector:find("function CurrencySelector%.RefreshCurrencyTooltip%(self%)") ~= nil,
    "CurrencySelector exposes tooltip refresh behavior")
assert_true(currencySelector:find("function BETTERUI%.Banking%.Class:RefreshCurrencyTooltip%(%)") ~= nil,
    "CurrencySelector wires the Banking class refresh wrapper")

local quantityDialog = read_file("Modules/Banking/Dialogs/QuantityDialog.lua")
assert_true(quantityDialog:find('BETTERUI_BANK_QUANTITY_DIALOG = "BETTERUI_BANK_QUANTITY_DIALOG"') ~= nil,
    "QuantityDialog declares the banking quantity dialog name")
assert_true(quantityDialog:find("local function SetupSliderKeybindHints%(dialog%)") ~= nil,
    "QuantityDialog exposes slider keybind hint setup")
assert_true(quantityDialog:find("function BETTERUI%.Banking%.InitializeQuantityDialog%(%)") ~= nil,
    "QuantityDialog exposes the dialog registration hook")
assert_true(quantityDialog:find("BETTERUI%.CIM%.Dialogs%.Register%(BETTERUI_BANK_QUANTITY_DIALOG, %{%s*") ~= nil,
    "QuantityDialog registers through the shared CIM dialog seam")

local bankListManager = read_file("Modules/Banking/Lists/BankListManager.lua")
assert_true(bankListManager:find("local function BuildAllBankCategories%(isFurnitureVault%)") ~= nil,
    "BankListManager defines the shared bank-category builder")
assert_true(bankListManager:find("local function ResolveBagsAndSlotType%(self%)") ~= nil,
    "BankListManager defines banking bag resolution")
assert_true(bankListManager:find("BETTERUI%.Banking%.BuildAllBankCategories = BuildAllBankCategories") ~= nil,
    "BankListManager exports BuildAllBankCategories for later consumers")
assert_true(bankListManager:find("BETTERUI%.Banking%.ResolveBagsAndSlotType = ResolveBagsAndSlotType") ~= nil,
    "BankListManager exports ResolveBagsAndSlotType for later consumers")
assert_true(bankListManager:find("function BETTERUI%.Banking%.Class:RefreshList%(%)") ~= nil,
    "BankListManager exposes the Banking RefreshList implementation")

local bankRowSetup = read_file("Modules/Banking/Lists/BankRowSetup.lua")
assert_true(bankRowSetup:find('BETTERUI%.Banking%.CURRENCY_ROW_TEMPLATE = "BETTERUI_BankCurrencySelectorTemplate"') ~= nil,
    "BankRowSetup declares the banking currency row template")
assert_true(bankRowSetup:find("function BETTERUI%.Banking%.Class%.SetupLabelListing%(control, data%)") ~= nil,
    "BankRowSetup exposes the label-row setup helper")
assert_true(bankRowSetup:find("function BETTERUI%.Banking%.BuildCurrencyTransferEntryData%(self, currencyType, modeText, labelByCurrency%)") ~= nil,
    "BankRowSetup exposes currency transfer entry construction")
assert_true(bankRowSetup:find("function BETTERUI%.Banking%.Class%.SetupCurrencyTransferEntry%(control, data, selected, selectedDuringRebuild, enabled,") ~= nil,
    "BankRowSetup exposes the currency transfer row setup hook")

local bankingModule = read_file("Modules/Banking/Module.lua")
assert_true(bankingModule:find("Banking%.ROOT_CONTRACT = %{%s*") ~= nil,
    "Banking module declares a root contract")
assert_true(bankingModule:find('BETTERUI%.CIM%.RegisterModuleAccessors%("Banking"%)') ~= nil,
    "Banking module registers shared Banking accessors")
assert_true(bankingModule:find("function Banking%.InitModule%(m_options%)") ~= nil,
    "Banking module exposes InitModule")
assert_true(bankingModule:find("function Banking%.Setup%(%)") ~= nil,
    "Banking module exposes Setup")

local sceneLifecycle = read_file("Modules/Banking/Scene/BankingSceneLifecycle.lua")
assert_true(sceneLifecycle:find("local GUILD_BANK_EVENTS = %{%s*") ~= nil,
    "BankingSceneLifecycle batches guild-bank events")
assert_true(sceneLifecycle:find("function BETTERUI%.Banking%.Class:OnSceneShowing%(wasPushed%)") ~= nil,
    "BankingSceneLifecycle exposes the scene showing hook")
assert_true(sceneLifecycle:find('SHARED_INVENTORY:RegisterCallback%("FullInventoryUpdate", self%._inventoryFullUpdateCallback%)') ~= nil,
    "BankingSceneLifecycle registers the shared inventory full-update callback")
assert_true(sceneLifecycle:find('SHARED_INVENTORY:RegisterCallback%("SingleSlotInventoryUpdate", self%._inventorySingleSlotCallback%)') ~= nil,
    "BankingSceneLifecycle registers the shared inventory single-slot callback")

local searchManager = read_file("Modules/Banking/Search/SearchManager.lua")
assert_true(searchManager:find("BETTERUI%.Banking%.Class%.SEARCH_LIFECYCLE = %{%s*") ~= nil,
    "SearchManager exposes the canonical search lifecycle table")
assert_true(searchManager:find("function BETTERUI%.Banking%.Class:ClearSearchInput%(%)") ~= nil,
    "SearchManager exposes ClearSearchInput")
assert_true(searchManager:find("function BETTERUI%.Banking%.Class:EnterSearchMode%(%)") ~= nil,
    "SearchManager exposes EnterSearchMode")
assert_true(searchManager:find("function BETTERUI%.Banking%.Class:ExitSearchMode%(%)") ~= nil,
    "SearchManager exposes ExitSearchMode")
assert_true(searchManager:find("function BETTERUI%.Banking%.Class:PositionSearchControl%(%)") ~= nil,
    "SearchManager exposes PositionSearchControl")

local stateManager = read_file("Modules/Banking/State/StateManager.lua")
assert_true(stateManager:find("function BETTERUI%.Banking%.Class:CurrentUsedBank%(%)") ~= nil,
    "StateManager exposes CurrentUsedBank")
assert_true(stateManager:find("function BETTERUI%.Banking%.Class:SaveListPosition%(%)") ~= nil,
    "StateManager exposes SaveListPosition")
assert_true(stateManager:find("function BETTERUI%.Banking%.Class:GetRestoredPosition%(%)") ~= nil,
    "StateManager exposes GetRestoredPosition")
assert_true(stateManager:find("function BETTERUI%.Banking%.Class:HandleBankSwitch%(%)") ~= nil,
    "StateManager exposes HandleBankSwitch")
assert_true(stateManager:find("function BETTERUI%.Banking%.Class:ToggleList%(toWithdraw%)") ~= nil,
    "StateManager exposes ToggleList")

local footerManager = read_file("Modules/Banking/UI/FooterManager.lua")
assert_true(footerManager:find("function BETTERUI%.Banking%.Class:RefreshFooter%(%)") ~= nil,
    "FooterManager exposes RefreshFooter")
assert_true(footerManager:find('GetNamedChild%("DepositButtonSpaceLabel"%)') ~= nil,
    "FooterManager updates the deposit capacity label")
assert_true(footerManager:find('GetNamedChild%("WithdrawButtonSpaceLabel"%)') ~= nil,
    "FooterManager updates the withdraw capacity label")

local headerManager = read_file("Modules/Banking/UI/HeaderManager.lua")
assert_true(headerManager:find("function BETTERUI%.Banking%.Class:CycleCategory%(delta%)") ~= nil,
    "HeaderManager exposes CycleCategory")
assert_true(headerManager:find("function BETTERUI%.Banking%.Class:UpdateHeaderTitle%(%)") ~= nil,
    "HeaderManager exposes UpdateHeaderTitle")
assert_true(headerManager:find("function BETTERUI%.Banking%.Class:EnsureHeaderKeybindsActive%(%)") ~= nil,
    "HeaderManager exposes EnsureHeaderKeybindsActive")
assert_true(headerManager:find("function BETTERUI%.Banking%.Class:RebuildHeaderCategories%(%)") ~= nil,
    "HeaderManager exposes RebuildHeaderCategories")

local actionDialogUtils = read_file("Modules/CIM/Actions/ActionDialogUtils.lua")
assert_true(actionDialogUtils:find("function BETTERUI%.CIM%.GetQuickslotLabel%(slotIndex%)") ~= nil,
    "ActionDialogUtils exposes quickslot labels")
assert_true(actionDialogUtils:find("function BETTERUI%.CIM%.BuildQuickslotDialogEntries%(dialog, target%)") ~= nil,
    "ActionDialogUtils exposes quickslot dialog entry construction")
assert_true(actionDialogUtils:find("function BETTERUI%.CIM%.PopulateActionEntries%(parametricList, slotActions, options%)") ~= nil,
    "ActionDialogUtils exposes shared action entry population")
assert_true(actionDialogUtils:find("function BETTERUI%.CIM%.HandleLinkToChat%(targetData%)") ~= nil,
    "ActionDialogUtils exposes the shared link-to-chat handler")

if failed > 0 then
    error(string.format("test_banking_support_module_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_banking_support_module_source.lua: %d passed", passed))
