--[[
File: tools/tests/test_banking_guild_bank.lua
Purpose: Covers guild bank adapter behavior and Banking.Init integration.

Usage:
  lua tools/tests/test_banking_guild_bank.lua
]]

if false then
    dofile("Modules/Banking/Core/GuildBankAdapter.lua")
    dofile("Modules/Banking/Banking.lua")
end

BAG_BACKPACK = 1
BAG_BANK = 2
BAG_GUILDBANK = 3
BAG_SUBSCRIBER_BANK = 6

GUILD_PERMISSION_BANK_DEPOSIT = 11
GUILD_PERMISSION_BANK_WITHDRAW = 12

SI_GAMEPAD_GUILD_BANK_CATEGORY_HEADER = "SI_GAMEPAD_GUILD_BANK_CATEGORY_HEADER"
SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS = "SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS"
SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS = "SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS"
SI_GAMEPAD_GUILD_BANK_NO_PERMISSION = "SI_GAMEPAD_GUILD_BANK_NO_PERMISSION"
SI_BETTERUI_BANK_TITLE = "SI_BETTERUI_BANK_TITLE"
SI_TRADING_HOUSE_GUILD_LABEL = "SI_TRADING_HOUSE_GUILD_LABEL"
SI_GAMEPAD_SELECT_OPTION = "SI_GAMEPAD_SELECT_OPTION"
SI_GAMEPAD_BACK_OPTION = "SI_GAMEPAD_BACK_OPTION"
SI_BETTERUI_BANKING_COLUMN_NAME = "SI_BETTERUI_BANKING_COLUMN_NAME"
SI_BETTERUI_BANKING_COLUMN_TYPE = "SI_BETTERUI_BANKING_COLUMN_TYPE"
SI_BETTERUI_BANKING_COLUMN_TRAIT = "SI_BETTERUI_BANKING_COLUMN_TRAIT"
SI_BETTERUI_BANKING_COLUMN_STAT = "SI_BETTERUI_BANKING_COLUMN_STAT"
SI_BETTERUI_BANKING_COLUMN_VALUE = "SI_BETTERUI_BANKING_COLUMN_VALUE"

GAMEPAD_LEFT_TOOLTIP = {}
GAMEPAD_DIALOGS = { PARAMETRIC = "PARAMETRIC" }
TEXT_ALIGN_CENTER = "center"
EVENT_OPEN_GUILD_BANK = 1001
EVENT_CLOSE_GUILD_BANK = 1002

BETTERUI_BANKING_SCENE_NAME = "betterui_banking"
BETTERUI_GUILD_BANKING_SCENE_NAME = "betterui_guild_banking"

local testsPassed = 0
local testsFailed = 0

local bankingBag = BAG_BANK
local selectedGuildId = 0
local selectorGuildId = 0
local guildNames = {}
local permissionMatrix = {}
local stringValues = {
    [SI_GAMEPAD_GUILD_BANK_CATEGORY_HEADER] = "Guild Bank",
    [SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS] = "No withdraw",
    [SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS] = "No deposit %s",
    [SI_GAMEPAD_GUILD_BANK_NO_PERMISSION] = "No guild permission",
    [SI_BETTERUI_BANK_TITLE] = "Bank",
    [SI_TRADING_HOUSE_GUILD_LABEL] = "Select Guild",
    [SI_GAMEPAD_SELECT_OPTION] = "Select",
    [SI_GAMEPAD_BACK_OPTION] = "Back",
    [SI_BETTERUI_BANKING_COLUMN_NAME] = "Name",
    [SI_BETTERUI_BANKING_COLUMN_TYPE] = "Type",
    [SI_BETTERUI_BANKING_COLUMN_TRAIT] = "Trait",
    [SI_BETTERUI_BANKING_COLUMN_STAT] = "Stat",
    [SI_BETTERUI_BANKING_COLUMN_VALUE] = "Value",
}

local tooltipClears = 0
local updateKeybindCalls = 0
local releasedDialogName = nil
local shownGuildDialog = nil
local tooltipWidths = {}
local narrationCalls = {}
local lifecycleRegistrations = {}
local sceneLifecycleCalls = {}
local refreshManagerCalls = 0
local quantityDialogCalls = 0
local sceneInterceptionCalls = 0
local eventRegistrations = {}
local unregisteredEvents = {}
local shownSceneName = nil
local hiddenSceneName = nil

local function assertTrue(condition, message)
    if condition then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        print("  [FAILED] " .. message)
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
end

local function assertTableEquals(expected, actual, message)
    local ok = #expected == #actual
    if ok then
        for i = 1, #expected do
            if expected[i] ~= actual[i] then
                ok = false
                break
            end
        end
    end
    assertTrue(ok, message)
end

function GetBankingBag()
    return bankingBag
end

function GetGuildName(guildId)
    return guildNames[guildId]
end

function DoesPlayerHaveGuildPermission(guildId, permission)
    local guildPermissions = permissionMatrix[guildId] or {}
    return guildPermissions[permission] == true
end

function GetGuildBankMinDepositMembers()
    return 10
end

function GetSelectedGuildBankId()
    return selectedGuildId
end

function GetDisplayName()
    return "@player"
end

function GetNumGuilds()
    return 2
end

function GetGuildId(index)
    return index == 1 and 55 or 88
end

function GetGuildAlliance()
    return 1
end

function ZO_GetLargeAllianceSymbolIcon()
    return "alliance_icon"
end

ZO_GamepadEntryData = {
    New = function(text, icon)
        return {
            text = text,
            icon = icon,
            SetFontScaleOnSelection = function() end,
            SetIconTintOnSelection = function() end,
        }
    end,
}

function GetString(id)
    return stringValues[id] or tostring(id)
end

function zo_strformat(template, ...)
    return string.format(template, ...)
end

function ZO_ClearTable(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

function ZO_GamepadGenericHeader_Refresh(_, headerData)
    shownGuildDialog = headerData.titleText
end

function ZO_Dialogs_ReleaseAllDialogsOfName(name)
    releasedDialogName = name
end

function ZO_Dialogs_RegisterCustomDialog(name, dialogData)
    ESO_Dialogs[name] = dialogData
end

BETTERUI_GUILD_BANKING_SCENE = {
    isShowing = false,
    IsShowing = function(self)
        return self.isShowing
    end,
}

GUILD_BANK_SELECT = {
    GetSelectedGuildBankId = function()
        return selectedGuildId
    end,
}

ZO_GUILD_SELECTOR_MANAGER = {
    GetSelectedGuildBankId = function()
        return selectorGuildId
    end,
    SetSelectedGuildBankId = function(_, guildId)
        selectedGuildId = guildId
    end,
}

KEYBIND_STRIP = {
    UpdateKeybindButtonGroup = function(_, _)
        updateKeybindCalls = updateKeybindCalls + 1
    end,
}

GAMEPAD_TOOLTIPS = {
    ClearTooltip = function(_, tooltip)
        if tooltip == GAMEPAD_LEFT_TOOLTIP then
            tooltipClears = tooltipClears + 1
        end
    end,
}

ESO_Dialogs = {}

FRAGMENT_GROUP = {
    GAMEPAD_DRIVEN_UI_WINDOW = "driven",
    FRAME_TARGET_GAMEPAD = "frame",
}

FRAME_EMOTE_FRAGMENT_INVENTORY = "emote"
GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT = "background"
MINIMIZE_CHAT_FRAGMENT = "minimize"
GAMEPAD_MENU_SOUND_FRAGMENT = "menu_sound"

local function createWindow()
    local window = {
        listClearCount = 0,
        listCommitCount = 0,
        refreshListCount = 0,
        refreshFooterCount = 0,
        rebuildHeaderCategoriesCount = 0,
        computeVisibleCategoriesCount = 0,
        title = nil,
        columns = {},
        fragment = "bank_fragment",
        footerFragment = "footer_fragment",
        scene = { name = BETTERUI_BANKING_SCENE_NAME },
        coreKeybinds = { "core" },
        list = {},
    }

    function window.list:Clear()
        window.listClearCount = window.listClearCount + 1
    end

    function window.list:Commit()
        window.listCommitCount = window.listCommitCount + 1
    end

    function window:ComputeVisibleBankCategories()
        self.computeVisibleCategoriesCount = self.computeVisibleCategoriesCount + 1
        return { { key = "all" }, { key = "junk" } }
    end

    function window:GetCurrentCategoryKey()
        return "all"
    end

    function window:SetListUpdatesSuppressed(suppressed)
        self._suppressListUpdates = suppressed == true
    end

    function window:RebuildHeaderCategories()
        self.rebuildHeaderCategoriesCount = self.rebuildHeaderCategoriesCount + 1
    end

    function window:RefreshList()
        self.refreshListCount = self.refreshListCount + 1
    end

    function window:RefreshCategoryView(_)
        self:ComputeVisibleBankCategories()
        self:RebuildHeaderCategories()
        self:RefreshList()
    end

    function window:RefreshFooter()
        self.refreshFooterCount = self.refreshFooterCount + 1
    end

    function window:SetTitle(title)
        self.title = title
    end

    function window:GetTitle()
        return self.title
    end

    function window:GetParametricList()
        return {
            GetTargetData = function()
                return { guildId = selectedGuildId }
            end,
        }
    end

    function window:AddColumn(name, width)
        table.insert(self.columns, { name = name, width = width })
    end

    function window:LinkColumnLabels()
        self.linkColumnLabelsCalled = true
    end

    function window:RefreshList()
        self.refreshListCount = self.refreshListCount + 1
    end

    function window:RebuildHeaderCategories()
        self.rebuildHeaderCategoriesCount = self.rebuildHeaderCategoriesCount + 1
    end

    function window:SetupUnifiedFooter()
        self.setupUnifiedFooterCalled = true
    end

    return window
end

local activeWindow = createWindow()

BETTERUI = {
    Banking = {
        LIST_WITHDRAW = 1,
        LIST_DEPOSIT = 2,
        TRANSFER_MODE_MAIN_BANK = "main-bank",
        TRANSFER_MODE_HOUSE_BANK = "house-bank",
        TRANSFER_MODE_GUILD_BANK = "guild-bank",
        RuntimeState = {
            currentUsedBank = BAG_BANK,
            lastUsedBank = BAG_BANK,
        },
        GUILD_BANK_INTERACTION = "guild",
        BANKING_INTERACTION = "bank",
        CONST = {},
        _ResolveBankBag = function(bankBagId)
            if bankBagId == nil or bankBagId == 0 then
                return BAG_BANK
            end
            return bankBagId
        end,
        GetTransferContext = function()
            local sourceBag = BETTERUI.Banking._ResolveBankBag(bankingBag)
            local isGuildBank = sourceBag == BAG_GUILDBANK
                or (BETTERUI_GUILD_BANKING_SCENE and BETTERUI_GUILD_BANKING_SCENE.isShowing == true)
            local targetBag = sourceBag == BAG_GUILDBANK and BAG_GUILDBANK
                or BETTERUI.Banking._ResolveBankBag(BETTERUI.Banking.RuntimeState.currentUsedBank)
            return {
                kind = isGuildBank and BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
                    or (sourceBag == BAG_BANK and BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
                        or BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK),
                interactionBag = sourceBag,
                depositTargetBag = targetBag,
                withdrawSourceBags = isGuildBank and { BAG_GUILDBANK }
                    or (targetBag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { targetBag }),
                sourceIsFurnitureVault = false,
                targetIsFurnitureVault = false,
            }
        end,
        GetTransferState = function()
            return BETTERUI.Banking.GetTransferContext()
        end,
        ReadTransferContextSnapshot = function()
            return BETTERUI.Banking.GetTransferContext()
        end,
        RefreshWindowView = function(window, options)
            if window.RefreshTransferView then
                window:RefreshTransferView(options or {})
                return
            end
            if window.ComputeVisibleBankCategories and window.RebuildHeaderCategories then
                window.bankCategories = window:ComputeVisibleBankCategories()
                if window.bankCategories and #window.bankCategories > 0 then
                    window.currentCategoryIndex = 1
                    window:RebuildHeaderCategories()
                end
            end
            if window.RefreshList then
                window:RefreshList()
            end
        end,
        IsGuildBankTransfer = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
        end,
        Class = {
            New = function()
                activeWindow = createWindow()
                return activeWindow
            end,
        },
        GetSetting = function(key)
            if key == "enableGuildBank" then
                return true
            end
            return nil
        end,
        InitializeRefreshManager = function()
            refreshManagerCalls = refreshManagerCalls + 1
        end,
        InitializeQuantityDialog = function()
            quantityDialogCalls = quantityDialogCalls + 1
        end,
        SetupSceneInterception = function()
            sceneInterceptionCalls = sceneInterceptionCalls + 1
        end,
        CreateSearchKeybindDescriptor = function()
            return {}
        end,
    },
    Interface = {
        UpdateKeybindGroup = function(descriptor)
            if descriptor then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
            end
        end,
    },
    CIM = {
        ProtectionPolicy = {
            DENY = {
                GUILD_PERMISSION = "guild_permission",
            },
        },
        SceneLifecycle = {
            Register = function(screen, callbacks)
                table.insert(lifecycleRegistrations, {
                    screen = screen,
                    scene = screen.scene,
                    callbacks = callbacks,
                })
            end,
        },
        SetTooltipWidth = function(width)
            table.insert(tooltipWidths, width)
        end,
        CONST = {
            HEADER_LAYOUT = {
                COLUMNS = { NAME = 1, TYPE = 2, TRAIT = 3, STAT = 4, VALUE = 5 },
            },
            LAYOUT = {
                PANEL = { WIDTH = 320, ZO_WIDTH = 200 },
            },
        },
        Narration = {
            RegisterListNarration = function(sceneName)
                table.insert(narrationCalls, sceneName)
            end,
        },
        Dialogs = {
            GetCurrentInfo = function(name)
                return ESO_Dialogs[name]
            end,
            Register = function(name, info)
                ESO_Dialogs[name] = info
                return true
            end,
        },
        Utils = {
            InstallNativeSceneRedirect = function(options)
                eventRegistrations[options.namespace .. ":" .. tostring(options.openEventId)] = function()
                    if options.isEnabled and not options.isEnabled() then
                        return
                    end
                    if type(options.showFn) == "function" then
                        options.showFn()
                    elseif SCENE_MANAGER and SCENE_MANAGER.Show then
                        SCENE_MANAGER:Show(options.sceneName)
                    end
                end
                if options.closeEventId then
                    eventRegistrations[options.namespace .. ":" .. tostring(options.closeEventId)] = function()
                        if SCENE_MANAGER and SCENE_MANAGER.Hide then
                            SCENE_MANAGER:Hide(options.sceneName)
                        end
                    end
                end
            end,
        },
    },
}

local personalBankScene = { name = BETTERUI_BANKING_SCENE_NAME }
local vanillaGuildScene = { name = "gamepad_guild_bank_vanilla" }

SCENE_MANAGER = {
    scenes = {
        [BETTERUI_BANKING_SCENE_NAME] = personalBankScene,
        ["gamepad_guild_bank"] = vanillaGuildScene,
    },
    Show = function(_, sceneName)
        shownSceneName = sceneName
    end,
    Hide = function(_, sceneName)
        hiddenSceneName = sceneName
    end,
    IsShowing = function(_, sceneName)
        return shownSceneName == sceneName
    end,
}

EVENT_MANAGER = {
    RegisterForEvent = function(_, namespace, eventId, handler)
        eventRegistrations[namespace .. ":" .. tostring(eventId)] = handler
    end,
    UnregisterForEvent = function(_, namespace, eventId)
        table.insert(unregisteredEvents, namespace .. ":" .. tostring(eventId))
        eventRegistrations[namespace .. ":" .. tostring(eventId)] = nil
    end,
}

function zo_callLater(callback)
    callback()
end

ZO_InteractScene = {
    New = function(name, _, interaction)
        local scene = {
            name = name,
            interaction = interaction,
            fragmentGroups = {},
            fragments = {},
            AddFragmentGroup = function(self, group)
                table.insert(self.fragmentGroups, group)
            end,
            AddFragment = function(self, fragment)
                table.insert(self.fragments, fragment)
            end,
        }
        SCENE_MANAGER.scenes[name] = scene
        return scene
    end,
}

dofile("Modules/Banking/Core/GuildBankAdapter.lua")
dofile("Modules/Banking/Banking.lua")

local function resetGuildBankState()
    bankingBag = BAG_BANK
    selectedGuildId = 0
    selectorGuildId = 0
    guildNames = {}
    permissionMatrix = {}
    tooltipClears = 0
    updateKeybindCalls = 0
    releasedDialogName = nil
    BETTERUI_GUILD_BANKING_SCENE.isShowing = false
    activeWindow = createWindow()
    BETTERUI.Banking.Window = activeWindow
    BETTERUI.Banking.RuntimeState.currentUsedBank = BAG_BANK
    BETTERUI.Banking.GuildBank.SetLoading(false)
end

print("\n=== GuildBankAdapter ===\n")

resetGuildBankState()
assertFalse = function(value, message)
    assertEqual(false, value, message)
end

assertFalse(BETTERUI.Banking.GuildBank.IsGuildBankMode(), "Personal bank is not guild bank mode")
bankingBag = BAG_GUILDBANK
assertTrue(BETTERUI.Banking.GuildBank.IsGuildBankMode(), "Guild banking bag enables guild bank mode")
bankingBag = BAG_BANK
BETTERUI_GUILD_BANKING_SCENE.isShowing = true
assertTrue(BETTERUI.Banking.GuildBank.IsGuildBankMode(), "Guild banking scene showing forces guild bank mode")

resetGuildBankState()
selectedGuildId = 12
assertEqual(12, BETTERUI.Banking.GuildBank.GetSelectedGuildId(), "Canonical GetSelectedGuildBankId API wins when available")
-- U50: GetSelectedGuildBankId() is the canonical API; remove it to exercise fallbacks.
local savedGetSelectedGuildBankId = GetSelectedGuildBankId
GetSelectedGuildBankId = nil
selectorGuildId = 34
assertEqual(34, BETTERUI.Banking.GuildBank.GetSelectedGuildId(), "Selector manager is fallback")
ZO_GUILD_SELECTOR_MANAGER = nil
assertEqual(0, BETTERUI.Banking.GuildBank.GetSelectedGuildId(), "No selector yields zero guild ID")
GetSelectedGuildBankId = savedGetSelectedGuildBankId

GUILD_BANK_SELECT = {
    GetSelectedGuildBankId = function()
        return selectedGuildId
    end,
}
ZO_GUILD_SELECTOR_MANAGER = {
    GetSelectedGuildBankId = function()
        return selectorGuildId
    end,
    SetSelectedGuildBankId = function(_, guildId)
        selectedGuildId = guildId
    end,
}

resetGuildBankState()
selectedGuildId = 55
guildNames[55] = "Guild One"
assertEqual("Guild One", BETTERUI.Banking.GuildBank.GetSelectedGuildName(), "Selected guild name is returned when present")
guildNames[55] = ""
assertEqual("Guild Bank", BETTERUI.Banking.GuildBank.GetSelectedGuildName(), "Fallback guild title used when name missing")

resetGuildBankState()
assertTrue(BETTERUI.Banking.GuildBank.CanDeposit(), "Personal bank always allows deposits")
assertTrue(BETTERUI.Banking.GuildBank.CanWithdraw(), "Personal bank always allows withdrawals")
bankingBag = BAG_GUILDBANK
selectedGuildId = 90
permissionMatrix[90] = {
    [GUILD_PERMISSION_BANK_DEPOSIT] = true,
    [GUILD_PERMISSION_BANK_WITHDRAW] = false,
}
assertTrue(BETTERUI.Banking.GuildBank.CanDeposit(), "Guild deposit permission is respected")
assertFalse(BETTERUI.Banking.GuildBank.CanWithdraw(), "Guild withdraw permission is respected")

local withdrawDenial = BETTERUI.Banking.GuildBank.GetPermissionDenial(BETTERUI.Banking.LIST_WITHDRAW)
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.GUILD_PERMISSION, withdrawDenial.reason,
    "Structured withdraw denial uses shared guild-permission reason")
assertEqual(SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS, withdrawDenial.stringId,
    "Structured withdraw denial keeps withdraw-specific string id")
assertEqual("No withdraw", withdrawDenial.text,
    "Structured withdraw denial includes localized text")
permissionMatrix[90][GUILD_PERMISSION_BANK_DEPOSIT] = false
local depositDenial = BETTERUI.Banking.GuildBank.GetPermissionDenial(BETTERUI.Banking.LIST_DEPOSIT)
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.GUILD_PERMISSION, depositDenial.reason,
    "Structured deposit denial uses shared guild-permission reason")
assertEqual(SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS, depositDenial.stringId,
    "Structured deposit denial keeps deposit-specific string id")
assertEqual("No deposit 10", depositDenial.text,
    "Structured deposit denial includes localized text with member requirement")
bankingBag = BAG_BANK
assertEqual(nil, BETTERUI.Banking.GuildBank.GetPermissionDenial(BETTERUI.Banking.LIST_DEPOSIT),
    "Personal bank has no structured permission denial")

resetGuildBankState()
assertTableEquals({ BAG_BANK, BAG_SUBSCRIBER_BANK }, BETTERUI.Banking.GetTransferContext().withdrawSourceBags,
    "Personal main bank withdraw sources both bank bags")
BETTERUI.Banking.RuntimeState.currentUsedBank = nil
assertTableEquals({ BAG_BANK, BAG_SUBSCRIBER_BANK }, BETTERUI.Banking.GetTransferContext().withdrawSourceBags,
    "Personal withdraw falls back to both bank bags when runtime state is missing")
BETTERUI.Banking.RuntimeState.currentUsedBank = 0
assertTableEquals({ BAG_BANK, BAG_SUBSCRIBER_BANK }, BETTERUI.Banking.GetTransferContext().withdrawSourceBags,
    "Personal withdraw normalizes the zero bank sentinel before building source bags")
BETTERUI.Banking.RuntimeState.currentUsedBank = 88
bankingBag = 88
assertTableEquals({ 88 }, BETTERUI.Banking.GetTransferContext().withdrawSourceBags,
    "House bank withdraw sources current bank only")
BETTERUI.Banking.RuntimeState.currentUsedBank = BAG_BANK
bankingBag = BAG_BANK
assertEqual(BAG_BANK, BETTERUI.Banking.GetTransferContext().depositTargetBag, "Personal deposit target is main bank")
bankingBag = BAG_GUILDBANK
assertTableEquals({ BAG_GUILDBANK }, BETTERUI.Banking.GetTransferContext().withdrawSourceBags,
    "Guild withdraw sources guild bank")
BETTERUI.Banking.RuntimeState.currentUsedBank = BAG_GUILDBANK
assertEqual(BAG_GUILDBANK, BETTERUI.Banking.GetTransferContext().depositTargetBag, "Guild deposit target is guild bank bag")

resetGuildBankState()
assertEqual("|c0066FFBank|r", BETTERUI.Banking.GuildBank.GetHeaderTitle(), "Personal header title uses bank title")
bankingBag = BAG_GUILDBANK
selectedGuildId = 55
guildNames[55] = "Guild One"
assertEqual("|c0066FFGuild One Bank|r", BETTERUI.Banking.GuildBank.GetHeaderTitle(), "Guild header includes guild name")

resetGuildBankState()
assertFalse(BETTERUI.Banking.GuildBank.IsLoading(), "Guild bank loading starts false")
BETTERUI.Banking.GuildBank.SetLoading(true)
assertTrue(BETTERUI.Banking.GuildBank.IsLoading(), "Guild bank loading can be enabled")
selectedGuildId = 10
BETTERUI.Banking.GuildBank.ChangeGuildBank(11)
assertEqual(11, selectedGuildId, "Changing guild bank updates selected guild ID")
assertTrue(BETTERUI.Banking.GuildBank.IsLoading(), "Changing guild bank enables loading")

resetGuildBankState()
BETTERUI.Banking.GuildBank.OnGuildBankSelected()
assertTrue(BETTERUI.Banking.GuildBank.IsLoading(), "Selecting guild bank enables loading")
assertEqual(1, tooltipClears, "Selecting guild bank clears tooltip")
assertTrue(BETTERUI.Banking.Window._suppressListUpdates, "Selecting guild bank suppresses list updates")

resetGuildBankState()
BETTERUI.Banking.GuildBank.OnGuildBankDeselected()
assertEqual(1, BETTERUI.Banking.Window.listClearCount, "Deselection clears list")
assertEqual(1, BETTERUI.Banking.Window.listCommitCount, "Deselection commits list clear")

resetGuildBankState()
BETTERUI.Banking.GuildBank.SetLoading(true)
BETTERUI.Banking.GuildBank.OnGuildBankReady()
assertFalse(BETTERUI.Banking.GuildBank.IsLoading(), "Guild bank ready clears loading")
assertFalse(BETTERUI.Banking.Window._suppressListUpdates, "Guild bank ready enables list updates")
assertEqual(1, BETTERUI.Banking.Window.computeVisibleCategoriesCount, "Guild bank ready recomputes categories")
assertEqual(1, BETTERUI.Banking.Window.rebuildHeaderCategoriesCount, "Guild bank ready rebuilds header categories")
assertEqual(1, BETTERUI.Banking.Window.refreshListCount, "Guild bank ready refreshes the list")
assertEqual(1, updateKeybindCalls, "Guild bank ready updates keybinds")

resetGuildBankState()
BETTERUI.Banking.GuildBank.OnGuildBankUpdated()
assertEqual(1, BETTERUI.Banking.Window.refreshListCount, "Guild updates refresh when not loading")
BETTERUI.Banking.GuildBank.SetLoading(true)
BETTERUI.Banking.Window.refreshListCount = 0
BETTERUI.Banking.GuildBank.OnGuildBankUpdated()
assertEqual(0, BETTERUI.Banking.Window.refreshListCount, "Guild updates are ignored while loading")

resetGuildBankState()
BETTERUI.Banking.GuildBank.SetLoading(true)
BETTERUI.Banking.GuildBank.OnGuildBankOpenError()
assertFalse(BETTERUI.Banking.GuildBank.IsLoading(), "Open error clears loading")
assertFalse(BETTERUI.Banking.Window._suppressListUpdates, "Open error unsuppresses list updates")
assertEqual(1, BETTERUI.Banking.Window.listClearCount, "Open error clears the list")

resetGuildBankState()
BETTERUI.Banking.GuildBank.OnGuildBankedMoneyUpdate()
assertEqual(1, BETTERUI.Banking.Window.refreshListCount, "Money updates refresh the list")
assertEqual(1, BETTERUI.Banking.Window.refreshFooterCount, "Money updates refresh the footer")

resetGuildBankState()
selectedGuildId = 77
BETTERUI.Banking.GuildBank.OnGuildRanksChanged(nil, 77)
assertEqual(1, updateKeybindCalls, "Rank changes for selected guild update keybinds")
assertEqual(1, BETTERUI.Banking.Window.refreshListCount, "Rank changes for selected guild refresh the list")
updateKeybindCalls = 0
BETTERUI.Banking.Window.refreshListCount = 0
BETTERUI.Banking.GuildBank.OnGuildRanksChanged(nil, 12)
assertEqual(0, updateKeybindCalls, "Unrelated rank changes do not update keybinds")
assertEqual(0, BETTERUI.Banking.Window.refreshListCount, "Unrelated rank changes do not refresh")

resetGuildBankState()
selectedGuildId = 77
BETTERUI.Banking.GuildBank.OnGuildMemberRankChanged(nil, 77, "@player")
assertEqual(1, updateKeybindCalls, "Player rank changes update keybinds")
assertEqual(1, BETTERUI.Banking.Window.refreshListCount, "Player rank changes refresh the list")
updateKeybindCalls = 0
BETTERUI.Banking.Window.refreshListCount = 0
BETTERUI.Banking.GuildBank.OnGuildMemberRankChanged(nil, 77, "@someoneElse")
assertEqual(0, updateKeybindCalls, "Other players' rank changes do not update keybinds")
assertEqual(0, BETTERUI.Banking.Window.refreshListCount, "Other players' rank changes do not refresh")

resetGuildBankState()
BETTERUI.Banking.GuildBank.OnGuildSelfLeft()
assertEqual("BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD", releasedDialogName, "Leaving guild releases guild selector dialog")

resetGuildBankState()
BETTERUI.Banking.GuildBank.RegisterGuildSelectorDialog()
assertTrue(ESO_Dialogs.BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD ~= nil, "Guild selector dialog is registered")
local dialog = ESO_Dialogs.BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD
local setupInvoked = 0
local fakeDialog
fakeDialog = {
    info = {},
    headerData = {},
    header = {},
    setupFunc = function()
        setupInvoked = setupInvoked + 1
    end,
    entryList = {
        GetTargetData = function()
            return { guildId = 88 }
        end,
        SetSelectedDataByEval = function(_, predicate)
            fakeDialog.selectedByEval = predicate({ isCurrentGuild = true })
        end,
    },
}
dialog.setup(fakeDialog)
assertEqual(1, setupInvoked, "Dialog setup delegates to dialog setup function")
assertTrue(fakeDialog.selectedByEval == true, "Dialog setup selects the active guild entry")
selectedGuildId = 77
guildNames[88] = "Guild Two"
bankingBag = BAG_GUILDBANK
dialog.buttons[1].callback(fakeDialog)
assertEqual(88, selectedGuildId, "Dialog primary callback changes guild bank")
assertEqual("|c0066FFGuild Two Bank|r", activeWindow.title, "Dialog callback refreshes title with current guild header")

print("\n=== Banking.Init ===\n")

local function resetInitState(enableGuildBank)
    refreshManagerCalls = 0
    quantityDialogCalls = 0
    sceneInterceptionCalls = 0
    narrationCalls = {}
    lifecycleRegistrations = {}
    tooltipWidths = {}
    sceneLifecycleCalls = {}
    eventRegistrations = {}
    unregisteredEvents = {}
    shownSceneName = nil
    hiddenSceneName = nil
    activeWindow = createWindow()
    activeWindow.scene = { name = "window_personal_scene" }
    BETTERUI.Banking.Class.New = function()
        return activeWindow
    end
    BETTERUI.Banking.GetSetting = function(key)
        if key == "enableGuildBank" then
            return enableGuildBank
        end
        return nil
    end
    personalBankScene = { name = BETTERUI_BANKING_SCENE_NAME }
    vanillaGuildScene = { name = "gamepad_guild_bank_vanilla" }
    SCENE_MANAGER.scenes = {
        [BETTERUI_BANKING_SCENE_NAME] = personalBankScene,
        ["gamepad_guild_bank"] = vanillaGuildScene,
    }
    BETTERUI.Banking.Window = nil
    BETTERUI_GUILD_BANKING_SCENE = nil
    GAMEPAD_BANKING_SCENE = nil
end

resetInitState(true)
BETTERUI.Banking.Init()
assertTrue(BETTERUI.Banking.Window ~= nil, "Init creates the banking window")
assertEqual("|c0066FFBank|r", BETTERUI.Banking.Window.title, "Init sets the banking title")
assertEqual(5, #BETTERUI.Banking.Window.columns, "Init adds all banking columns")
assertTrue(BETTERUI.Banking.Window.linkColumnLabelsCalled == true, "Init links column labels")
assertEqual(1, BETTERUI.Banking.Window.rebuildHeaderCategoriesCount, "Init rebuilds header categories")
assertEqual(1, BETTERUI.Banking.Window.refreshListCount, "Init refreshes the list")
assertTrue(GAMEPAD_BANKING_SCENE == personalBankScene, "Init syncs GAMEPAD_BANKING_SCENE to BetterUI scene")
assertTrue(BETTERUI_GUILD_BANKING_SCENE ~= nil, "Init registers the guild bank scene when enabled")
assertTableEquals({ FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW, FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD },
    BETTERUI_GUILD_BANKING_SCENE.fragmentGroups, "Guild bank scene gets the expected fragment groups")
assertEqual(6, #BETTERUI_GUILD_BANKING_SCENE.fragments, "Guild bank scene adds all required fragments")
assertEqual(1, #lifecycleRegistrations, "Init registers guild bank lifecycle callbacks")
assertTrue(lifecycleRegistrations[1].scene == BETTERUI_GUILD_BANKING_SCENE, "Lifecycle registration targets guild scene")
assertEqual("window_personal_scene", BETTERUI.Banking.Window.scene.name, "Init restores personal scene after lifecycle registration")
assertTrue(SCENE_MANAGER.scenes["gamepad_guild_bank"] == vanillaGuildScene, "Init leaves the vanilla guild bank scene entry untouched")
assertTrue(eventRegistrations["BETTERUI_GUILD_BANK_SCENE_REDIRECT:" .. tostring(EVENT_OPEN_GUILD_BANK)] ~= nil,
    "Init registers a guild bank open redirect event")
assertTrue(eventRegistrations["BETTERUI_GUILD_BANK_SCENE_REDIRECT:" .. tostring(EVENT_CLOSE_GUILD_BANK)] ~= nil,
    "Init registers a guild bank close redirect event")
eventRegistrations["BETTERUI_GUILD_BANK_SCENE_REDIRECT:" .. tostring(EVENT_OPEN_GUILD_BANK)]()
assertEqual(BETTERUI_GUILD_BANKING_SCENE_NAME, shownSceneName, "Guild bank open event shows the BetterUI guild scene")
eventRegistrations["BETTERUI_GUILD_BANK_SCENE_REDIRECT:" .. tostring(EVENT_CLOSE_GUILD_BANK)]()
assertEqual(BETTERUI_GUILD_BANKING_SCENE_NAME, hiddenSceneName, "Guild bank close event hides the BetterUI guild scene")
assertEqual(1, refreshManagerCalls, "Init configures the refresh manager")
assertEqual(1, quantityDialogCalls, "Init configures the quantity dialog")
assertEqual(1, sceneInterceptionCalls, "Init installs scene interception")
assertTrue(BETTERUI.Banking.Window.setupUnifiedFooterCalled == true, "Init configures unified footer")
assertEqual(2, #narrationCalls, "Init registers narration for personal and guild scenes")

local callbacks = lifecycleRegistrations[1].callbacks
local callbackWindow = {
    OnSceneShowing = function()
        table.insert(sceneLifecycleCalls, "showing")
    end,
    OnSceneHiding = function()
        table.insert(sceneLifecycleCalls, "hiding")
    end,
    OnSceneHidden = function()
        table.insert(sceneLifecycleCalls, "hidden")
    end,
}
callbacks.onShowing(callbackWindow, true)
callbacks.onHiding(callbackWindow)
callbacks.onHidden(callbackWindow)
assertTableEquals({ 320, 200 }, tooltipWidths, "Lifecycle callbacks set tooltip widths for showing and hiding")
assertTableEquals({ "showing", "hiding", "hidden" }, sceneLifecycleCalls, "Lifecycle callbacks forward to scene methods")

resetInitState(false)
BETTERUI.Banking.Init()
assertTrue(BETTERUI_GUILD_BANKING_SCENE == nil, "Init skips guild bank scene when disabled")
assertTrue(SCENE_MANAGER.scenes["gamepad_guild_bank"] == vanillaGuildScene, "Init leaves vanilla guild scene untouched when disabled")
assertTrue(eventRegistrations["BETTERUI_GUILD_BANK_SCENE_REDIRECT:" .. tostring(EVENT_OPEN_GUILD_BANK)] == nil,
    "Init skips guild bank open redirect when disabled")
assertTrue(eventRegistrations["BETTERUI_GUILD_BANK_SCENE_REDIRECT:" .. tostring(EVENT_CLOSE_GUILD_BANK)] == nil,
    "Init skips guild bank close redirect when disabled")
assertEqual(1, refreshManagerCalls, "Shared init steps still run when guild bank disabled")

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED — see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
