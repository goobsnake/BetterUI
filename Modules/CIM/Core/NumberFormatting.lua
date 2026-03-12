--[[
File: Modules/CIM/Core/NumberFormatting.lua
Purpose: Number formatting utilities for the BetterUI addon.
         Provides comma formatting, abbreviation (K/M/B), and rounding functions.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-- ============================================================================
-- ROUNDING
-- ============================================================================

--[[
Function: BETTERUI.roundNumber
Description: Rounds a number to a specified number of decimal places.
Rationale: Utility for numeric formatting in UI elements.
Mechanism: Multiplies by power of 10, floors, and divides back to truncate/round.
References: Used internally by AbbreviateNumber and other UI formatting logic.
param: number (number) - The value to round.
param: decimals (number) - The number of decimal places to keep.
return: number|string - The rounded number, formatted as a string (via string.format), or 0 if inputs invalid.
]]
--- @param number number The value to round
--- @param decimals number The number of decimal places to keep
--- @return string|number rounded The rounded number string, or 0 if invalid
function BETTERUI.roundNumber(number, decimals)
    if number ~= nil and decimals ~= nil then
        local power = 10 ^ decimals
        return string.format("%.2f", math.floor(number * power) / power)
    else
        return 0
    end
end

-- ============================================================================
-- COMMA FORMATTING
-- ============================================================================

--[[
Function: BETTERUI.DisplayNumber
Description: Formats a number with comma separators (e.g., 1234567 -> 1,234,567).
Rationale: Improves readability of large currency values in the UI.
Mechanism: Uses string pattern matching to insert commas every 3 digits.
References: Used by AbbreviateNumber and general UI display elements.
Credits: Bart Kiers
param: number (number) - The number to format.
return: string - The formatted string with commas.
]]
--- @param number number|string The number to format
--- @return string formatted The number string with comma separators
function BETTERUI.DisplayNumber(number)
    local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    -- reverse the int-string and append a comma to all blocks of 3 digits
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    -- reverse the int-string back remove an optional comma and put the
    -- optional minus and fractional part back
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

-- ============================================================================
-- ABBREVIATION (K/M/B)
-- ============================================================================

--[[
Function: BETTERUI.FormatNumber
Description: Abbreviates large numbers using k/m/b suffixes.
Rationale: Compact display of large values (Health, XP, Gold) where space is limited.
Mechanism: Checks magnitude (Billions -> Millions -> Thousands) and formats accordingly.
           Supports options for case (upper/lower suffixes) and decimal handling.
References: Used by ResourceOrbs, Currency displays, Inventory values.
param: value (number) - The number to format.
param: options (table|nil) - Optional settings: {case="upper"|"lower", style="smart"|"fixed", decimals=number}
  - case: "upper" for K/M/B, "lower" for k/m/b (default: "lower")
  - style: "smart" adjusts decimals by magnitude, "fixed" uses specified decimals (default: "smart")
  - decimals: fixed decimal places when style="fixed" (default: 2)
return: string - The formatted abbreviated number string.
]]
--- @param value number The number to format
--- @param options? {case?: "upper"|"lower", style?: "smart"|"fixed", decimals?: number} Optional formatting settings
--- @return string formatted The abbreviated number string
function BETTERUI.FormatNumber(value, options)
    if not value or value == 0 then
        return "0"
    end

    options = options or {}
    local useUpperCase = options.case == "upper"
    local useSmartDecimals = options.style ~= "fixed"
    local fixedDecimals = options.decimals or 2

    local absValue = math.abs(value)
    local sign = value < 0 and "-" or ""

    local num, suffix
    local decimals = fixedDecimals

    if absValue >= 1000000000 then
        num = absValue / 1000000000
        suffix = useUpperCase and "B" or "b"
        if useSmartDecimals then
            decimals = num >= 100 and 0 or (num >= 10 and 1 or 2)
        end
    elseif absValue >= 1000000 then
        num = absValue / 1000000
        suffix = useUpperCase and "M" or "m"
        if useSmartDecimals then
            decimals = num >= 100 and 0 or (num >= 10 and 1 or 2)
        end
    elseif absValue >= 1000 then
        num = absValue / 1000
        suffix = useUpperCase and "K" or "k"
        if useSmartDecimals then
            decimals = num >= 100 and 0 or (num >= 10 and 1 or 2)
        elseif not useSmartDecimals and num == math.floor(num) then
            -- For fixed style, still show 0 decimals if value is exact
            decimals = 0
        end
    else
        -- Less than 1000
        if useUpperCase then
            return sign .. tostring(math.floor(absValue))
        else
            return BETTERUI.DisplayNumber(value)
        end
    end

    local fmt = "%." .. tostring(decimals) .. "f"
    return sign .. string.format(fmt, num) .. suffix
end

--[[
Function: BETTERUI.AbbreviateNumber
Description: Abbreviates large numbers using k/m/b suffixes (lowercase).
Rationale: Backward-compatible wrapper for ResourceOrbs and legacy code.
param: n (number) - The number to abbreviate.
param: defaultDecimals (number|nil) - Optional decimal places (ignored - uses smart decimals).
return: string - The abbreviated number string.
]]
--- @param n number The number to abbreviate
--- @param defaultDecimals? number Optional decimal places (ignored)
--- @return string abbreviated The abbreviated number string
function BETTERUI.AbbreviateNumber(n, defaultDecimals)
    -- Legacy behavior: lowercase, smart decimals
    return BETTERUI.FormatNumber(n, { case = "lower", style = "smart" })
end

--[[
Function: BETTERUI.FormatAbbreviatedNumber
Description: Formats a number into abbreviated form (K, M, B) with uppercase.
Rationale: Backward-compatible wrapper for Inventory display values.
param: value (number) - The number to format.
return: string - Formatted string like "1.12K", "12.3K", "123K", "1.23M".
]]
--- @param value number The number to format
--- @return string formatted The abbreviated uppercase number string
function BETTERUI.FormatAbbreviatedNumber(value)
    -- Legacy behavior: uppercase, smart decimals
    return BETTERUI.FormatNumber(value, { case = "upper", style = "smart" })
end
