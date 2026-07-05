--[[
File: tools/tests/test_category_getter_contracts_source.lua
Purpose: Guards pure getter contracts for Vendor and Companions category accessors.

Usage:
  lua tools/tests/test_category_getter_contracts_source.lua
]]

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function assert_contains(haystack, needle, message)
    if not haystack:find(needle, 1, true) then
        error(message .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, message)
    if haystack:find(needle, 1, true) then
        error(message .. "\nUnexpected: " .. needle)
    end
end

local function extract_function_body(source, signature)
    local startPos = source:find(signature, 1, true)
    if not startPos then
        error("Missing function signature: " .. signature)
    end

    local remainder = source:sub(startPos)
    local endPos = remainder:find("\nend", 1, true)
    if not endPos then
        error("Missing function terminator for: " .. signature)
    end

    return remainder:sub(1, endPos + 3)
end

print("test_category_getter_contracts_source")

local companionSource = read_file("Modules/Companions/Core/CompanionListManager.lua")
local vendorSource = read_file("Modules/Vendor/Core/VendorClass.lua")
local companionGetter = extract_function_body(companionSource, "function BETTERUI.Companions.Class:GetCurrentCategory()")
local vendorGetter = extract_function_body(vendorSource, "function BETTERUI.Vendor.Class:GetCurrentCategory()")

assert_contains(
    companionSource,
    "function BETTERUI.Companions.Class:GetCurrentCategory()",
    "Companions still exposes GetCurrentCategory"
)
assert_not_contains(
    companionGetter,
    "self.currentCategoryIndex = index",
    "Companions GetCurrentCategory no longer mutates currentCategoryIndex"
)
assert_contains(
    companionSource,
    "local isCarousel = (not Companions.GetSetting) or (Companions.GetSetting(\"enableCarousel\") ~= false)",
    "Companions category header reads the carousel setting"
)
assert_contains(
    companionSource,
    "enabled = isCarousel",
    "Companions category header passes the carousel setting into GenericHeader"
)
assert_contains(
    companionSource,
    "if Companions.GetSetting and Companions.GetSetting(\"enableCarousel\") == false then",
    "Companions category cycling branches for non-carousel mode"
)
assert_contains(
    companionSource,
    "if nextIndex < 1 or nextIndex > #categories then\n            return",
    "Companions non-carousel category cycling stops at the edges"
)

assert_contains(
    vendorSource,
    "function BETTERUI.Vendor.Class:GetCurrentCategory()",
    "Vendor still exposes GetCurrentCategory"
)
assert_contains(
    vendorSource,
    "---@return table|nil category",
    "Vendor GetCurrentCategory contract truthfully documents nullable category output"
)
assert_not_contains(
    vendorGetter,
    "self.categoryIndexByMode[mode] = selectedIndex",
    "Vendor GetCurrentCategory no longer mutates categoryIndexByMode"
)
assert_not_contains(
    vendorGetter,
    "self.currentCategoryIndex = selectedIndex",
    "Vendor GetCurrentCategory no longer mutates currentCategoryIndex"
)

print("  OK")
