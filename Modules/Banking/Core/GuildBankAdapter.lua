-- Guild-bank adapter for Banking permissions, labels, and scene state.

BETTERUI.Banking = BETTERUI.Banking or {}
BETTERUI.Banking.GuildBank = {}

local GuildBank = BETTERUI.Banking.GuildBank
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT = BETTERUI.Banking.LIST_DEPOSIT
local ProtectionPolicy = assert(
    BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy,
    "BetterUI: CIM.ProtectionPolicy must load before Banking/Core/GuildBankAdapter"
)
local DENY = assert(
    ProtectionPolicy and ProtectionPolicy.DENY,
    "BetterUI: CIM.ProtectionPolicy.DENY must load before Banking/Core/GuildBankAdapter"
)
assert(type(DENY.GUILD_PERMISSION) == "string",
    "BetterUI: CIM.ProtectionPolicy.DENY.GUILD_PERMISSION must be defined")

local function TraceGuildBank(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = data.module or "Banking"
    data.feature = data.feature or "guildBank"
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.STATE or categories.ACTION, event, phase, data)
end

local function GetGuildBankRuntimeState()
    local getMutableGuildBankRuntimeState = BETTERUI.Banking and BETTERUI.Banking.GetMutableGuildBankRuntimeState or nil
    if type(getMutableGuildBankRuntimeState) == "function" then
        return getMutableGuildBankRuntimeState()
    end

    BETTERUI.Banking.RuntimeState = BETTERUI.Banking.RuntimeState or {}
    BETTERUI.Banking.RuntimeState.guildBank = BETTERUI.Banking.RuntimeState.guildBank or { isLoading = false }
    if BETTERUI.Banking.RuntimeState.guildBank.isLoading == nil then
        BETTERUI.Banking.RuntimeState.guildBank.isLoading = false
    end
    return BETTERUI.Banking.RuntimeState.guildBank
end

local function ReadTransferContextSnapshot()
    local readTransferContextSnapshot = BETTERUI.Banking and BETTERUI.Banking.ReadTransferContextSnapshot or nil
    if type(readTransferContextSnapshot) == "function" then
        return readTransferContextSnapshot()
    end
    return {
        kind = BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK,
        interactionBag = BAG_BANK,
        depositTargetBag = BAG_BANK,
        withdrawSourceBags = { BAG_BANK, BAG_SUBSCRIBER_BANK },
        sourceIsFurnitureVault = false,
        targetIsFurnitureVault = false,
    }
end

function GuildBank.IsGuildBankMode()
    local transferContext = ReadTransferContextSnapshot()
    if transferContext.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
        or transferContext.interactionBag == BAG_GUILDBANK then
        return true
    end

    local guildBankScene = BETTERUI_GUILD_BANKING_SCENE
    if guildBankScene then
        if guildBankScene.IsShowing and guildBankScene:IsShowing() then
            return true
        end
        if guildBankScene.isShowing == true then
            return true
        end
    end

    return false
end

function GuildBank.GetSelectedGuildId()
    -- U50 API: GetSelectedGuildBankId() is the canonical accessor.
    if GetSelectedGuildBankId then
        return GetSelectedGuildBankId() or 0
    end
    if ZO_GUILD_SELECTOR_MANAGER and ZO_GUILD_SELECTOR_MANAGER.GetSelectedGuildBankId then
        return ZO_GUILD_SELECTOR_MANAGER:GetSelectedGuildBankId() or 0
    end
    return 0
end

function GuildBank.GetSelectedGuildName()
    local guildId = GuildBank.GetSelectedGuildId()
    if guildId > 0 and GetGuildName then
        local name = GetGuildName(guildId)
        if name and name ~= "" then
            return name
        end
    end
    return GetString(rawget(_G, "SI_GAMEPAD_GUILD_BANK_CATEGORY_HEADER"))
end

function GuildBank.CanDeposit()
    if not GuildBank.IsGuildBankMode() then
        return true -- personal bank always allows deposits
    end
    local guildId = GuildBank.GetSelectedGuildId()
    if guildId <= 0 then return false end
    if DoesPlayerHaveGuildPermission then
        return DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT) == true
    end
    return false
end

function GuildBank.CanWithdraw()
    if not GuildBank.IsGuildBankMode() then
        return true -- personal bank always allows withdrawals
    end
    local guildId = GuildBank.GetSelectedGuildId()
    if guildId <= 0 then return false end
    if DoesPlayerHaveGuildPermission then
        return DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW) == true
    end
    return false
end

--- Gold withdrawals need a dedicated rank permission (see ZOS guildbank_gamepad.lua).
---@return boolean
function GuildBank.CanWithdrawGold()
    if not GuildBank.IsGuildBankMode() then
        return true -- personal bank always allows gold withdrawals
    end
    local guildId = GuildBank.GetSelectedGuildId()
    if guildId <= 0 then return false end
    if DoesPlayerHaveGuildPermission then
        return DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW_GOLD) == true
    end
    return false
end

--- Resolves the minimum guild member count required for bank deposits.
--- U50 exposes this via GetNumGuildMembersRequiredForPrivilege(GUILD_PRIVILEGE_BANK_DEPOSIT);
--- fall back to the long-standing threshold of 10 when the API is unavailable.
---@return integer
local function GetBankDepositMemberRequirement()
    if GetNumGuildMembersRequiredForPrivilege and GUILD_PRIVILEGE_BANK_DEPOSIT then
        return GetNumGuildMembersRequiredForPrivilege(GUILD_PRIVILEGE_BANK_DEPOSIT)
    end
    return 10
end

--- Gold deposits are gated by the guild-level bank-deposit privilege; there is
--- no GUILD_PERMISSION_BANK_DEPOSIT_GOLD (ZOS gamepad guild bank checks
--- DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT) for gold).
---@return boolean
function GuildBank.CanDepositGold()
    if not GuildBank.IsGuildBankMode() then
        return true -- personal bank always allows gold deposits
    end
    local guildId = GuildBank.GetSelectedGuildId()
    if guildId <= 0 then return false end
    if DoesGuildHavePrivilege then
        return DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_BANK_DEPOSIT) == true
    end
    return false
end

--- Returns a denial descriptor when the player cannot move gold in the given
--- mode, mirroring GetPermissionDenial for item transfers.
---@param mode integer LIST_WITHDRAW or LIST_DEPOSIT
---@return {reason: string, stringId: integer|nil, text: string}|nil
function GuildBank.GetGoldPermissionDenial(mode)
    if not GuildBank.IsGuildBankMode() then
        return nil
    end

    local reasonCode = DENY.GUILD_PERMISSION

    if mode == LIST_WITHDRAW and not GuildBank.CanWithdrawGold() then
        local stringId = rawget(_G, "SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS")
        return {
            reason = reasonCode,
            stringId = stringId,
            text = GetString(stringId),
        }
    end

    if mode == LIST_DEPOSIT and not GuildBank.CanDepositGold() then
        -- CanDepositGold fails on the guild-level deposit privilege (guild too
        -- small), so use the privilege-specific denial string.
        local stringId = rawget(_G, "SI_INVENTORY_ERROR_GUILD_BANK_NO_DEPOSIT_PRIVILEGES")
        return {
            reason = reasonCode,
            stringId = stringId,
            text = zo_strformat(GetString(stringId), GetBankDepositMemberRequirement()),
        }
    end

    return nil
end

function GuildBank.GetPermissionDenial(mode)
    if not GuildBank.IsGuildBankMode() then
        return nil
    end

    local reasonCode = DENY.GUILD_PERMISSION

    if mode == LIST_WITHDRAW and not GuildBank.CanWithdraw() then
        local stringId = rawget(_G, "SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS")
        return {
            reason = reasonCode,
            stringId = stringId,
            text = GetString(stringId),
        }
    end

    if mode == LIST_DEPOSIT and not GuildBank.CanDeposit() then
        -- ZOS gamepad guild bank formats this string with the member threshold
        -- from GetNumGuildMembersRequiredForPrivilege (guildbank_gamepad.lua).
        local stringId = rawget(_G, "SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS")
        return {
            reason = reasonCode,
            stringId = stringId,
            text = zo_strformat(GetString(stringId), GetBankDepositMemberRequirement()),
        }
    end

    return nil
end

function GuildBank.GetHeaderTitle()
    if GuildBank.IsGuildBankMode() then
        local guildName = GuildBank.GetSelectedGuildName()
        local formatId = rawget(_G, "SI_BETTERUI_GUILD_BANK_TITLE_FORMAT")
        local title = formatId and zo_strformat(GetString(formatId), guildName)
            or (guildName .. " Bank")
        return "|c0066FF" .. title .. "|r"
    end
    return "|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE")) .. "|r"
end

function GuildBank.IsLoading()
    return GetGuildBankRuntimeState().isLoading == true
end

function GuildBank.SetLoading(loading)
    GetGuildBankRuntimeState().isLoading = loading == true
    TraceGuildBank("bank.guild_bank", "loading_set", {
        fn = "GuildBank.SetLoading",
        loading = loading == true,
        guildId = GuildBank.GetSelectedGuildId(),
    })
end

function GuildBank.ChangeGuildBank(guildBankId)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.ACTION, "change guild bank", { guildId = guildBankId })
    end
    local currentGuildId = GetSelectedGuildBankId()
    TraceGuildBank("bank.guild_selector", "change_requested", {
        fn = "GuildBank.ChangeGuildBank",
        requestedGuildId = guildBankId,
        currentGuildId = currentGuildId,
        changed = guildBankId ~= currentGuildId,
    })
    if guildBankId ~= currentGuildId then
        GuildBank.SetLoading(true)
        if ZO_GUILD_SELECTOR_MANAGER and ZO_GUILD_SELECTOR_MANAGER.SetSelectedGuildBankId then
            ZO_GUILD_SELECTOR_MANAGER:SetSelectedGuildBankId(guildBankId)
            TraceGuildBank("bank.guild_selector", "native_selection_set", {
                fn = "GuildBank.ChangeGuildBank",
                requestedGuildId = guildBankId,
            })
        else
            TraceGuildBank("bank.guild_selector", "native_selection_skipped", {
                fn = "GuildBank.ChangeGuildBank",
                reason = "missingGuildSelectorManager",
                requestedGuildId = guildBankId,
            })
        end
    else
        TraceGuildBank("bank.guild_selector", "change_skipped", {
            fn = "GuildBank.ChangeGuildBank",
            reason = "alreadySelected",
            guildId = guildBankId,
        })
    end
end

function GuildBank.OnGuildBankSelected()
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "guild bank selected")
    end
    GuildBank.SetLoading(true)
    local window = BETTERUI.Banking.GetWindow()
    if window then
        if GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.ClearTooltip then
            GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
        end
        window:SetListUpdatesSuppressed(true)
    end
    TraceGuildBank("bank.guild_bank", "selected", {
        fn = "GuildBank.OnGuildBankSelected",
        guildId = GuildBank.GetSelectedGuildId(),
        hasWindow = window ~= nil,
        clearedTooltip = GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.ClearTooltip ~= nil or false,
        listUpdatesSuppressed = window ~= nil,
    })
end

function GuildBank.OnGuildBankDeselected()
    local window = BETTERUI.Banking.GetWindow()
    if window and window.list then
        window.list:Clear()
        window.list:Commit()
    end
    TraceGuildBank("bank.guild_bank", "deselected", {
        fn = "GuildBank.OnGuildBankDeselected",
        guildId = GuildBank.GetSelectedGuildId(),
        clearedList = window and window.list ~= nil or false,
    })
end

function GuildBank.OnGuildBankReady()
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "guild bank ready")
    end
    GuildBank.SetLoading(false)
    local window = BETTERUI.Banking.GetWindow()
    if window then
        window:SetListUpdatesSuppressed(false)
        BETTERUI.Banking.RefreshWindowView(window)
        if window.coreKeybinds and BETTERUI.Interface and BETTERUI.Interface.UpdateKeybindGroup then
            BETTERUI.Interface.UpdateKeybindGroup(window.coreKeybinds)
        end
    end
    TraceGuildBank("bank.guild_bank", "ready", {
        fn = "GuildBank.OnGuildBankReady",
        guildId = GuildBank.GetSelectedGuildId(),
        hasWindow = window ~= nil,
        refreshedWindow = window ~= nil,
        refreshedKeybinds = window and window.coreKeybinds ~= nil or false,
    })
end

function GuildBank.OnGuildBankUpdated()
    local window = BETTERUI.Banking.GetWindow()
    if window and not GuildBank.IsLoading() then
        BETTERUI.Banking.RefreshWindowView(window)
        TraceGuildBank("bank.guild_bank", "updated", {
            fn = "GuildBank.OnGuildBankUpdated",
            guildId = GuildBank.GetSelectedGuildId(),
            refreshedWindow = true,
        })
    else
        TraceGuildBank("bank.guild_bank", "update_skipped", {
            fn = "GuildBank.OnGuildBankUpdated",
            guildId = GuildBank.GetSelectedGuildId(),
            reason = not window and "missingWindow" or "loading",
        })
    end
end

--- Called when guild bank open fails. Clears loading state.
---@return nil
function GuildBank.OnGuildBankOpenError()
    GuildBank.SetLoading(false)
    local window = BETTERUI.Banking.GetWindow()
    if window then
        window:SetListUpdatesSuppressed(false)
        if window.list then
            window.list:Clear()
            window.list:Commit()
        end
    end
    TraceGuildBank("bank.guild_bank", "open_error", {
        fn = "GuildBank.OnGuildBankOpenError",
        guildId = GuildBank.GetSelectedGuildId(),
        hasWindow = window ~= nil,
        clearedList = window and window.list ~= nil or false,
    })
end

--- Called when guild banked money is updated. Refreshes footer and lists.
---@return nil
function GuildBank.OnGuildBankedMoneyUpdate()
    local window = BETTERUI.Banking.GetWindow()
    if window then
        BETTERUI.Banking.RefreshWindowView(window)
        if window.RefreshFooter then
            window:RefreshFooter()
        end
    end
    TraceGuildBank("bank.guild_bank", "money_updated", {
        fn = "GuildBank.OnGuildBankedMoneyUpdate",
        guildId = GuildBank.GetSelectedGuildId(),
        hasWindow = window ~= nil,
        refreshedFooter = window and window.RefreshFooter ~= nil or false,
    })
end

--- Called when guild ranks change. Refreshes keybinds if it affects the selected guild.
---@param _ any Unused event parameter
---@param guildId integer The guild whose ranks changed
function GuildBank.OnGuildRanksChanged(_, guildId)
    if guildId == GetSelectedGuildBankId() then
        local window = BETTERUI.Banking.GetWindow()
        if window then
            if window.coreKeybinds and BETTERUI.Interface and BETTERUI.Interface.UpdateKeybindGroup then
                BETTERUI.Interface.UpdateKeybindGroup(window.coreKeybinds)
            end
            window:RefreshList()
        end
        TraceGuildBank("bank.guild_permissions", "ranks_changed", {
            fn = "GuildBank.OnGuildRanksChanged",
            guildId = guildId,
            selected = true,
            refreshedWindow = window ~= nil,
            refreshedKeybinds = window and window.coreKeybinds ~= nil or false,
        })
    else
        TraceGuildBank("bank.guild_permissions", "ranks_changed_skipped", {
            fn = "GuildBank.OnGuildRanksChanged",
            guildId = guildId,
            selectedGuildId = GetSelectedGuildBankId(),
            reason = "notSelectedGuild",
        })
    end
end

--- Called when a guild member's rank changes. Refreshes if it's the player in the selected guild.
---@param _ any Unused event parameter
---@param guildId integer The guild where the rank changed
---@param displayName string The member's display name
function GuildBank.OnGuildMemberRankChanged(_, guildId, displayName)
    if guildId == GetSelectedGuildBankId() and displayName == GetDisplayName() then
        local window = BETTERUI.Banking.GetWindow()
        if window then
            if window.coreKeybinds and BETTERUI.Interface and BETTERUI.Interface.UpdateKeybindGroup then
                BETTERUI.Interface.UpdateKeybindGroup(window.coreKeybinds)
            end
            window:RefreshList()
        end
        TraceGuildBank("bank.guild_permissions", "member_rank_changed", {
            fn = "GuildBank.OnGuildMemberRankChanged",
            guildId = guildId,
            player = true,
            refreshedWindow = window ~= nil,
            refreshedKeybinds = window and window.coreKeybinds ~= nil or false,
        })
    else
        TraceGuildBank("bank.guild_permissions", "member_rank_changed_skipped", {
            fn = "GuildBank.OnGuildMemberRankChanged",
            guildId = guildId,
            selectedGuildId = GetSelectedGuildBankId(),
            player = displayName == GetDisplayName(),
        })
    end
end

--- Called when player leaves a guild. Releases any open guild selection dialog.
---@return nil
function GuildBank.OnGuildSelfLeft()
    ZO_Dialogs_ReleaseAllDialogsOfName("BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD")
    TraceGuildBank("bank.guild_selector", "released_on_self_left", {
        fn = "GuildBank.OnGuildSelfLeft",
    })
end

-- GUILD SELECTOR DIALOG

--- Registers the guild bank selection dialog for switching between guilds.
---@return nil
function GuildBank.RegisterGuildSelectorDialog()
    local dialogName = "BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD"
    local dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs or nil
    if not (dialogs and type(dialogs.Register) == "function" and type(dialogs.GetCurrentInfo) == "function") then
        TraceGuildBank("bank.guild_selector", "register_skipped", {
            fn = "GuildBank.RegisterGuildSelectorDialog",
            reason = "missingDialogRegistry",
            dialogName = dialogName,
        })
        return
    end
    if dialogs.GetCurrentInfo(dialogName) then
        TraceGuildBank("bank.guild_selector", "register_skipped", {
            fn = "GuildBank.RegisterGuildSelectorDialog",
            reason = "alreadyRegistered",
            dialogName = dialogName,
        })
        return
    end

    local CHECKED_ICON = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds"
    local GUILD_ENTRY_TEMPLATE = "ZO_GamepadSubMenuEntryWithStatusTemplate"

    local function IsActiveGuild(data)
        return data.isCurrentGuild
    end

    local function SetupGuildBankItem(control, data, ...)
        ZO_SharedGamepadEntry_OnSetup(control, data, ...)
        if IsActiveGuild(data) then
            control.statusIndicator:AddIcon(CHECKED_ICON)
            control.statusIndicator:Show()
        end
    end

    local dialogInfo = {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            -- Center the title text — PARAMETRIC dialogs default to left-align
            RefreshTextOverride = function(dialog, title)
                local headerData = dialog.headerData
                if headerData then
                    ZO_ClearTable(headerData)
                    headerData.titleText = title
                    headerData.titleTextAlignment = TEXT_ALIGN_CENTER
                    ZO_GamepadGenericHeader_Refresh(dialog.header, headerData)
                end
            end,
        },
        title = {
            text = GetString(rawget(_G, "SI_TRADING_HOUSE_GUILD_LABEL")),
        },
        setup = function(dialog)
            local currentGuildId = GetSelectedGuildBankId()
            local parametricList = {}
            local numGuilds = GetNumGuilds()
            for i = 1, numGuilds do
                local guildId = GetGuildId(i)
                local guildName = GetGuildName(guildId)
                local allianceId = GetGuildAlliance(guildId)
                local icon = ZO_GetLargeAllianceSymbolIcon(allianceId)
                local entryData = ZO_GamepadEntryData:New(guildName, icon)
                entryData:SetFontScaleOnSelection(false)
                entryData:SetIconTintOnSelection(true)
                entryData.guildId = guildId
                entryData.guildName = guildName
                entryData.isCurrentGuild = (guildId == currentGuildId)
                entryData.setup = SetupGuildBankItem
                table.insert(parametricList, {
                    template = GUILD_ENTRY_TEMPLATE,
                    entryData = entryData,
                })
            end
            local info = dialog.info or dialogInfo
            info.parametricList = parametricList
            dialog.info = info
            dialog:setupFunc()
            dialog.entryList:SetSelectedDataByEval(IsActiveGuild)
            TraceGuildBank("bank.guild_selector", "setup", {
                fn = "GuildSelectorDialog.setup",
                dialogName = dialogName,
                currentGuildId = currentGuildId,
                guildCount = numGuilds,
                selectedApplied = true,
            })
        end,
        parametricList = {},
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
                callback = function(dialog)
                    local selected = dialog.entryList and dialog.entryList:GetTargetData()
                    TraceGuildBank("bank.guild_selector", "confirm", {
                        fn = "GuildSelectorDialog.primary",
                        dialogName = dialogName,
                        selectedGuildId = selected and selected.guildId or nil,
                        selectedGuildName = selected and selected.guildName or nil,
                    })
                    if selected and selected.guildId then
                        GuildBank.ChangeGuildBank(selected.guildId)
                        -- Update title immediately
                        local window = BETTERUI.Banking.GetWindow()
                        if window then
                            window:SetTitle(GuildBank.GetHeaderTitle())
                        end
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
                callback = function()
                    TraceGuildBank("bank.guild_selector", "cancel", {
                        fn = "GuildSelectorDialog.negative",
                        dialogName = dialogName,
                    })
                end,
            },
        },
    }

    if not dialogs.Register(dialogName, dialogInfo) then
        TraceGuildBank("bank.guild_selector", "register_skipped", {
            fn = "GuildBank.RegisterGuildSelectorDialog",
            reason = "registryRejected",
            dialogName = dialogName,
        })
        return
    end
    TraceGuildBank("bank.guild_selector", "registered", {
        fn = "GuildBank.RegisterGuildSelectorDialog",
        dialogName = dialogName,
    })
end
