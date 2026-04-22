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

function GuildBank.IsGuildBankMode()
    local isGuildBankTransfer = BETTERUI.Banking and BETTERUI.Banking.IsGuildBankTransfer or nil
    if type(isGuildBankTransfer) == "function" then
        return isGuildBankTransfer()
    end
    return false
end

function GuildBank.GetSelectedGuildId()
    if GUILD_BANK_SELECT and GUILD_BANK_SELECT.GetSelectedGuildBankId then
        return GUILD_BANK_SELECT:GetSelectedGuildBankId() or 0
    end
    -- Gamepad guild selector manager fallback
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
        local minMembers = GetGuildBankMinDepositMembers and GetGuildBankMinDepositMembers() or 10
        local stringId = rawget(_G, "SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS")
        return {
            reason = reasonCode,
            stringId = stringId,
            text = zo_strformat(GetString(stringId), minMembers),
        }
    end

    return nil
end

function GuildBank.GetHeaderTitle()
    if GuildBank.IsGuildBankMode() then
        local guildName = GuildBank.GetSelectedGuildName()
        return "|c0066FF" .. guildName .. " Bank|r"
    end
    return "|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE")) .. "|r"
end

local loadingGuildBank = false

function GuildBank.IsLoading()
    return loadingGuildBank
end

function GuildBank.SetLoading(loading)
    loadingGuildBank = loading == true
end

function GuildBank.ChangeGuildBank(guildBankId)
    if guildBankId ~= GetSelectedGuildBankId() then
        loadingGuildBank = true
        if ZO_GUILD_SELECTOR_MANAGER and ZO_GUILD_SELECTOR_MANAGER.SetSelectedGuildBankId then
            ZO_GUILD_SELECTOR_MANAGER:SetSelectedGuildBankId(guildBankId)
        end
    end
end

function GuildBank.OnGuildBankSelected()
    loadingGuildBank = true
    local window = BETTERUI.Banking.Window
    if window then
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
        window:SetListUpdatesSuppressed(true)
    end
end

function GuildBank.OnGuildBankDeselected()
    local window = BETTERUI.Banking.Window
    if window and window.list then
        window.list:Clear()
        window.list:Commit()
    end
end

function GuildBank.OnGuildBankReady()
    loadingGuildBank = false
    local window = BETTERUI.Banking.Window
    if window then
        local preferredCategoryKey = window.GetCurrentCategoryKey and window:GetCurrentCategoryKey() or nil
        window:SetListUpdatesSuppressed(false)
        if window.RefreshCategoryView then
            window:RefreshCategoryView({
                preferredCategoryKey = preferredCategoryKey,
            })
        else
            window:RefreshList()
        end
        if window.coreKeybinds then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(window.coreKeybinds)
        end
    end
end

function GuildBank.OnGuildBankUpdated()
    local window = BETTERUI.Banking.Window
    if window and not loadingGuildBank then
        if window.RefreshCategoryView then
            window:RefreshCategoryView({
                preferredCategoryKey = window.GetCurrentCategoryKey and window:GetCurrentCategoryKey() or nil,
            })
        else
            window:RefreshList()
        end
    end
end

--- Called when guild bank open fails. Clears loading state.
---@return nil
function GuildBank.OnGuildBankOpenError()
    loadingGuildBank = false
    local window = BETTERUI.Banking.Window
    if window then
        window:SetListUpdatesSuppressed(false)
        if window.list then
            window.list:Clear()
            window.list:Commit()
        end
    end
end

--- Called when guild banked money is updated. Refreshes footer and lists.
---@return nil
function GuildBank.OnGuildBankedMoneyUpdate()
    local window = BETTERUI.Banking.Window
    if window then
        window:RefreshList()
        if window.RefreshFooter then
            window:RefreshFooter()
        end
    end
end

--- Called when guild ranks change. Refreshes keybinds if it affects the selected guild.
---@param _ any Unused event parameter
---@param guildId integer The guild whose ranks changed
function GuildBank.OnGuildRanksChanged(_, guildId)
    if guildId == GetSelectedGuildBankId() then
        local window = BETTERUI.Banking.Window
        if window then
            if window.coreKeybinds then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(window.coreKeybinds)
            end
            window:RefreshList()
        end
    end
end

--- Called when a guild member's rank changes. Refreshes if it's the player in the selected guild.
---@param _ any Unused event parameter
---@param guildId integer The guild where the rank changed
---@param displayName string The member's display name
function GuildBank.OnGuildMemberRankChanged(_, guildId, displayName)
    if guildId == GetSelectedGuildBankId() and displayName == GetDisplayName() then
        local window = BETTERUI.Banking.Window
        if window then
            if window.coreKeybinds then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(window.coreKeybinds)
            end
            window:RefreshList()
        end
    end
end

--- Called when player leaves a guild. Releases any open guild selection dialog.
---@return nil
function GuildBank.OnGuildSelfLeft()
    ZO_Dialogs_ReleaseAllDialogsOfName("BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD")
end

-- GUILD SELECTOR DIALOG

--- Registers the guild bank selection dialog for switching between guilds.
---@return nil
function GuildBank.RegisterGuildSelectorDialog()
    local dialogName = "BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD"
    if ESO_Dialogs[dialogName] then return end

    ESO_Dialogs[dialogName] = {
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
            dialog:setupFunc()
        end,
        parametricList = {},
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
                callback = function(dialog)
                    local selected = dialog.entryList and dialog.entryList:GetTargetData()
                    if selected and selected.guildId then
                        GuildBank.ChangeGuildBank(selected.guildId)
                        -- Update title immediately
                        local window = BETTERUI.Banking.Window
                        if window then
                            window:SetTitle(GuildBank.GetHeaderTitle())
                        end
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
            },
        },
    }

    -- Pre-populate on each show
    ZO_Dialogs_RegisterCustomDialog(dialogName, ESO_Dialogs[dialogName])
    -- Override setup to build guild list dynamically
    local orig = ESO_Dialogs[dialogName]
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

    orig.setup = function(dialog)
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
        dialog.info.parametricList = parametricList
        dialog:setupFunc()
        dialog.entryList:SetSelectedDataByEval(IsActiveGuild)
    end
end
