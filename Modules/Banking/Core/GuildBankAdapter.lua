--[[
File: Modules/Banking/Core/GuildBankAdapter.lua
Purpose: Guild bank detection, permission checks, and mode switching.
         Provides a permission-aware adapter between ESO's guild bank
         system and BetterUI's Banking module.
Author: BetterUI Team
Last Modified: 2026-03-14

KEY MECHANICS:
1.  **Detection**: Detects when the player interacts with a guild banker
    by checking `GetBankingBag() == BAG_GUILDBANK`.
2.  **Permission Checks**: Wraps `DoesPlayerHaveGuildPermission()` to
    verify deposit/withdraw rights before allowing item transfers.
3.  **Guild Selection**: Tracks the active guild bank ID via ZO_GuildSelector.
4.  **Mode Adapter**: Provides helper functions that allow the Banking module
    to transparently handle guild bank bags alongside personal/house banks.
]]

BETTERUI.Banking = BETTERUI.Banking or {}
BETTERUI.Banking.GuildBank = {}

local GuildBank = BETTERUI.Banking.GuildBank

-------------------------------------------------------------------------------------------------
-- DETECTION
-------------------------------------------------------------------------------------------------

--- Returns true when the current banking interaction is a guild bank.
--- @return boolean isGuildBank
function GuildBank.IsGuildBankMode()
    return GetBankingBag() == BAG_GUILDBANK
end

--- Returns the currently selected guild's ID for guild bank operations.
--- Falls back to 0 if no guild is selected or the API is unavailable.
--- @return number guildId
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

--- Returns the display name of the currently selected guild bank.
--- @return string guildName
function GuildBank.GetSelectedGuildName()
    local guildId = GuildBank.GetSelectedGuildId()
    if guildId > 0 and GetGuildName then
        local name = GetGuildName(guildId)
        if name and name ~= "" then
            return name
        end
    end
    return GetString(SI_GAMEPAD_GUILD_BANK_CATEGORY_HEADER)
end

-------------------------------------------------------------------------------------------------
-- PERMISSION CHECKS
-------------------------------------------------------------------------------------------------

--- Checks whether the player has deposit permission in the selected guild bank.
--- @return boolean canDeposit
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

--- Checks whether the player has withdrawal permission in the selected guild bank.
--- @return boolean canWithdraw
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

--- Returns a user-facing permission denial reason, or nil if no denial.
--- @param mode number LIST_WITHDRAW or LIST_DEPOSIT from Banking constants
--- @return string|nil denialReason
function GuildBank.GetPermissionDenialReason(mode)
    if not GuildBank.IsGuildBankMode() then return nil end

    local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
    local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

    if mode == LIST_WITHDRAW and not GuildBank.CanWithdraw() then
        return GetString(SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS)
    elseif mode == LIST_DEPOSIT and not GuildBank.CanDeposit() then
        local guildId = GuildBank.GetSelectedGuildId()
        local minMembers = GetGuildBankMinDepositMembers and GetGuildBankMinDepositMembers() or 10
        return zo_strformat(GetString(SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS), minMembers)
    end

    return nil
end

-------------------------------------------------------------------------------------------------
-- BAG RESOLUTION
-------------------------------------------------------------------------------------------------

--- Returns the source bag(s) for the current mode and bank type.
--- For guild bank withdraw: { BAG_GUILDBANK }
--- For guild bank deposit: { BAG_BACKPACK }
--- For personal bank: delegates to existing logic (BAG_BANK, BAG_SUBSCRIBER_BANK)
--- @param mode number LIST_WITHDRAW or LIST_DEPOSIT
--- @return table bags Array of bag IDs
function GuildBank.GetSourceBags(mode)
    local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW

    if not GuildBank.IsGuildBankMode() then
        -- Personal/house bank: reuse existing logic
        if mode == LIST_WITHDRAW then
            local currentUsedBank = BETTERUI.Banking.currentUsedBank
            if currentUsedBank == BAG_BANK then
                return { BAG_BANK, BAG_SUBSCRIBER_BANK }
            else
                return { currentUsedBank }
            end
        else
            return { BAG_BACKPACK }
        end
    end

    -- Guild bank mode
    if mode == LIST_WITHDRAW then
        return { BAG_GUILDBANK }
    else
        return { BAG_BACKPACK }
    end
end

--- Returns the deposit target bag for the current bank type.
--- Guild banks deposit to BAG_GUILDBANK; personal banks use existing resolution.
--- @return number bagId
function GuildBank.GetDepositTargetBag()
    if GuildBank.IsGuildBankMode() then
        return BAG_GUILDBANK
    end
    -- Personal bank: reuse existing logic
    return BAG_BANK
end

-------------------------------------------------------------------------------------------------
-- TITLE HELPER
-------------------------------------------------------------------------------------------------

--- Returns the header title appropriate for the current bank type.
--- Guild bank: "<GuildName> Bank"
--- Personal bank: existing bank title
--- @return string title
function GuildBank.GetHeaderTitle()
    if GuildBank.IsGuildBankMode() then
        local guildName = GuildBank.GetSelectedGuildName()
        return "|c0066FF" .. guildName .. " Bank|r"
    end
    return "|c0066FF" .. GetString(SI_BETTERUI_BANK_TITLE) .. "|r"
end

-------------------------------------------------------------------------------------------------
-- LOADING STATE
-------------------------------------------------------------------------------------------------

local loadingGuildBank = false

--- Returns true while guild bank items are still loading.
--- @return boolean isLoading
function GuildBank.IsLoading()
    return loadingGuildBank
end

--- Sets the guild bank loading state.
--- @param loading boolean
function GuildBank.SetLoading(loading)
    loadingGuildBank = loading == true
end

-------------------------------------------------------------------------------------------------
-- GUILD SELECTION
-------------------------------------------------------------------------------------------------

--- Switches the active guild bank. Triggers EVENT_GUILD_BANK_SELECTED flow.
--- @param guildBankId number The guild ID to switch to.
function GuildBank.ChangeGuildBank(guildBankId)
    if guildBankId ~= GetSelectedGuildBankId() then
        loadingGuildBank = true
        if ZO_GUILD_SELECTOR_MANAGER and ZO_GUILD_SELECTOR_MANAGER.SetSelectedGuildBankId then
            ZO_GUILD_SELECTOR_MANAGER:SetSelectedGuildBankId(guildBankId)
        end
    end
end

-------------------------------------------------------------------------------------------------
-- EVENT HANDLERS
-------------------------------------------------------------------------------------------------

--- Called when a guild bank is selected. Clears items and shows loading state.
function GuildBank.OnGuildBankSelected()
    loadingGuildBank = true
    local window = BETTERUI.Banking.Window
    if window then
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
        window._suppressListUpdates = true
    end
end

--- Called when a guild bank is deselected. Clears items.
function GuildBank.OnGuildBankDeselected()
    local window = BETTERUI.Banking.Window
    if window and window.list then
        window.list:Clear()
        window.list:Commit()
    end
end

--- Called when guild bank items are ready. Hides loading and refreshes lists.
function GuildBank.OnGuildBankReady()
    loadingGuildBank = false
    local window = BETTERUI.Banking.Window
    if window then
        window._suppressListUpdates = false
        window.bankCategories = window:ComputeVisibleBankCategories()
        window:RebuildHeaderCategories()
        window:RefreshList()
        if window.coreKeybinds then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(window.coreKeybinds)
        end
    end
end

--- Called when guild bank items are added/removed/updated. Refreshes withdraw list.
function GuildBank.OnGuildBankUpdated()
    local window = BETTERUI.Banking.Window
    if window and not loadingGuildBank then
        window.bankCategories = window:ComputeVisibleBankCategories()
        window:RebuildHeaderCategories()
        window:RefreshList()
    end
end

--- Called when guild bank open fails. Clears loading state.
function GuildBank.OnGuildBankOpenError()
    loadingGuildBank = false
    local window = BETTERUI.Banking.Window
    if window then
        window._suppressListUpdates = false
        if window.list then
            window.list:Clear()
            window.list:Commit()
        end
    end
end

--- Called when guild banked money is updated. Refreshes footer and lists.
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
function GuildBank.OnGuildSelfLeft()
    ZO_Dialogs_ReleaseAllDialogsOfName("BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD")
end

-------------------------------------------------------------------------------------------------
-- GUILD SELECTOR DIALOG
-------------------------------------------------------------------------------------------------

--- Registers the guild bank selection dialog for switching between guilds.
function GuildBank.RegisterGuildSelectorDialog()
    local dialogName = "BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD"
    if ESO_Dialogs[dialogName] then return end

    ESO_Dialogs[dialogName] = {
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title = {
            text = GetString(SI_TRADING_HOUSE_GUILD_LABEL),
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        parametricList = {},
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
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
                text = GetString(SI_GAMEPAD_BACK_OPTION),
            },
        },
    }

    -- Pre-populate on each show
    ZO_Dialogs_RegisterCustomDialog(dialogName, ESO_Dialogs[dialogName])
    -- Override setup to build guild list dynamically
    local orig = ESO_Dialogs[dialogName]
    orig.setup = function(dialog)
        local parametricList = {}
        local numGuilds = GetNumGuilds()
        for i = 1, numGuilds do
            local guildId = GetGuildId(i)
            local guildName = GetGuildName(guildId)
            local isSelected = (guildId == GetSelectedGuildBankId())
            local entryData = ZO_GamepadEntryData:New(guildName)
            entryData.guildId = guildId
            if isSelected then
                entryData:SetNameColors(ZO_SELECTED_TEXT, ZO_SELECTED_TEXT)
            end
            table.insert(parametricList, {
                template = "ZO_GamepadMenuEntryTemplate",
                entryData = entryData,
            })
        end
        dialog.info.parametricList = parametricList
        dialog:setupFunc()
    end
end
