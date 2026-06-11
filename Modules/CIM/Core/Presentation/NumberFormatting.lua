--[[
File: Modules/CIM/Core/Presentation/NumberFormatting.lua
Purpose: Number formatting utilities for the BetterUI addon.
         Provides comma formatting, abbreviation (K/M/B), and rounding functions.
]]

-- ROUNDING

--- Floors a number to the requested precision and formats it with exactly
--- that many decimals. Always returns a string for a consistent return type.
---@param number number?
---@param decimals integer?
---@return string
function BETTERUI.roundNumber(number, decimals)
    if number == nil then
        return "0"
    end
    local digits = math.max(math.floor(tonumber(decimals) or 0), 0)
    local power = 10 ^ digits
    return string.format("%." .. digits .. "f", math.floor(number * power) / power)
end

-- COMMA FORMATTING

---@param number number
---@return string
function BETTERUI.DisplayNumber(number)
    local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    -- reverse the int-string and append a comma to all blocks of 3 digits
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    -- reverse the int-string back remove an optional comma and put the
    -- optional minus and fractional part back
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

-- ABBREVIATION (K/M/B)

---@param value number?
---@param options {case: string?, style: string?, decimals: integer?}?
---@return string
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
        elseif num == math.floor(num) then
            -- For fixed style, still show 0 decimals if value is exact
            decimals = 0
        end
    elseif absValue >= 1000000 then
        num = absValue / 1000000
        suffix = useUpperCase and "M" or "m"
        if useSmartDecimals then
            decimals = num >= 100 and 0 or (num >= 10 and 1 or 2)
        elseif num == math.floor(num) then
            -- For fixed style, still show 0 decimals if value is exact
            decimals = 0
        end
    elseif absValue >= 1000 then
        num = absValue / 1000
        suffix = useUpperCase and "K" or "k"
        if useSmartDecimals then
            decimals = num >= 100 and 0 or (num >= 10 and 1 or 2)
        elseif num == math.floor(num) then
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

---@param n number?
---@param defaultDecimals integer?
---@return string
function BETTERUI.AbbreviateNumber(n, defaultDecimals)
    -- Legacy behavior: lowercase, smart decimals
    return BETTERUI.FormatNumber(n, { case = "lower", style = "smart" })
end

---@param value number?
---@return string
function BETTERUI.FormatAbbreviatedNumber(value)
    -- Legacy behavior: uppercase, smart decimals
    return BETTERUI.FormatNumber(value, { case = "upper", style = "smart" })
end
