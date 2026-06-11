--[[
File: tools/tests/test_vendor_can_carry.lua
Purpose: Contract coverage for BETTERUI.Vendor.Class:CanCarry (native CanCarry
         parity): craft-bag-virtual items and partial-stack merges need no free
         backpack slot, and a missing itemLink falls back to the free-slot test.
Usage:
  lua tools/tests/test_vendor_can_carry.lua
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

print("test_vendor_can_carry")

-- ESO globals + currency constants referenced by VendorClass at load/runtime.
CURT_NONE = 0
CURT_MONEY = 1
CURRENCY_LOCATION_CHARACTER = 1
BAG_BACKPACK = 1
STORE_INTERACTION = "store"
INTERACTION_VENDOR = 100

-- Tunable ESO API stubs the helper consults.
local freeSlots = 0
local virtualLinks = {}
local craftBagAccess = true
local bagSpaceLinks = {}

function GetNumBagFreeSlots(_)
    return freeSlots
end

function CanItemLinkBeVirtual(itemLink)
    return virtualLinks[itemLink] == true
end

function HasCraftBagAccess()
    return craftBagAccess
end

function DoesBagHaveSpaceForItemLink(_, itemLink)
    return bagSpaceLinks[itemLink] == true
end

function GetString(value)
    return tostring(value)
end

-- Minimal collaborator stubs so VendorClass's load-time asserts pass. CanCarry
-- itself depends on none of these, so empty tables / no-op functions suffice.
local function MakeStubClass()
    local cls = {}
    cls.__index = cls
    cls.Subclass = function(self)
        local sub = setmetatable({}, { __index = self })
        sub.__index = sub
        sub.Subclass = self.Subclass
        return sub
    end
    cls.New = function(self, ...)
        return setmetatable({}, { __index = self })
    end
    return cls
end

BETTERUI = {
    CIM = {
        GenericWindow = MakeStubClass(),
        DeferredTask = {
            CreateManager = function() return { Cancel = function() end, Schedule = function() end } end,
            CreateLazyManagerProxy = function() return { Cancel = function() end, Schedule = function() end } end,
        },
    },
}
BETTERUI.Vendor = {
    MODE = { BUY = 1, SELL = 2, REPAIR = 3, BUYBACK = 4, FENCE_SELL = 5, FENCE_LAUNDER = 6, STABLE = 7, SELL_VENGEANCE = 8 },
    ResolveModeName = function() return "" end,
    ResolveModeIcon = function() return "" end,
    ResolveNativeStoreMode = function() return nil end,
    ModePolicy = {},
    ControllerRuntime = {},
    PresentationRuntime = {},
    SelectionRuntime = {},
    ExecuteSafely = function(_, fn, ...)
        if type(fn) ~= "function" then return false end
        return pcall(fn, ...)
    end,
}

dofile("Modules/Vendor/Core/VendorClass.lua")

local Class = BETTERUI.Vendor.Class
assert(type(Class) == "table" and type(Class.CanCarry) == "function", "VendorClass exposes CanCarry")

local instance = setmetatable({}, { __index = Class })

-- 1) Backpack full, no itemLink: falls back to HasInventorySpace (false).
freeSlots = 0
assert_eq(instance:CanCarry(nil), false, "no itemLink + full backpack cannot carry (free-slot fallback)")

-- 2) Backpack has a free slot, no itemLink: free-slot fallback returns true.
freeSlots = 1
assert_eq(instance:CanCarry(nil), true, "no itemLink + free slot can carry (free-slot fallback)")

-- 3) Backpack full, item is craft-bag-virtual with craft-bag access: can carry.
freeSlots = 0
virtualLinks["link:virtual"] = true
craftBagAccess = true
assert_eq(instance:CanCarry("link:virtual"), true,
    "craft-bag-virtual item with craft-bag access carries despite a full backpack")

-- 4) Virtual item but no craft-bag access: falls through to bag-space check.
craftBagAccess = false
bagSpaceLinks["link:virtual"] = false
assert_eq(instance:CanCarry("link:virtual"), false,
    "virtual item without craft-bag access needs bag space")

-- 5) Non-virtual item with a free/partial-stack slot per DoesBagHaveSpaceForItemLink.
virtualLinks["link:normal"] = false
bagSpaceLinks["link:normal"] = true
assert_eq(instance:CanCarry("link:normal"), true,
    "non-virtual item carries when DoesBagHaveSpaceForItemLink reports room (stacking aware)")

-- 6) Non-virtual item with no room: cannot carry.
bagSpaceLinks["link:normal"] = false
freeSlots = 0
assert_eq(instance:CanCarry("link:normal"), false,
    "non-virtual item cannot carry when no bag space and not virtualizable")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
