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
