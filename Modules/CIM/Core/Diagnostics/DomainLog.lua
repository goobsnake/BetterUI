--[[
File: Modules/CIM/Core/Diagnostics/DomainLog.lua
Purpose: Compact domain-specific log describers used by the BetterUI logger.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local DomainLog = {}
BETTERUI.CIM.DomainLog = DomainLog

local function G(name) return rawget(_G, name) end

-- Keep text normalization aligned with Log.lua. These helpers stay local because
-- DomainLog loads before Log.lua.
local function safeTostring(v, fallback)
    local ok, s = pcall(tostring, v)
    if ok and type(s) == "string" then return s end
    return fallback or ""
end

local function normalizeLogText(v, fallback)
    return (safeTostring(v, fallback or ""):gsub("[\r\n\t]+", " "):gsub("|", "/"))
end

local function normalizeLogToken(v, fallback)
    local s = normalizeLogText(v, fallback or "?"):gsub("%s+", "_")
    if s == "" then return fallback or "?" end
    return s
end

local keybindDescriptorIds = setmetatable({}, { __mode = "k" })
local nextKeybindDescriptorId = 0

local function getKeybindDescriptorId(descriptor)
    if type(descriptor) ~= "table" then
        return safeTostring(descriptor, type(descriptor))
    end
    local id = keybindDescriptorIds[descriptor]
    if not id then
        nextKeybindDescriptorId = nextKeybindDescriptorId + 1
        id = "kb" .. tostring(nextKeybindDescriptorId)
        keybindDescriptorIds[descriptor] = id
    end
    return id
end

local function summarizeKeybindName(name)
    if type(name) == "function" then
        local ok, value = pcall(name)
        if not ok then return "name_error" end
        return normalizeLogToken(value, "empty"):sub(1, 24)
    end
    return normalizeLogToken(name, "unnamed"):sub(1, 24)
end

local function summarizeKeybindVisible(visible)
    if type(visible) ~= "function" then return "v-" end
    local ok, value = pcall(visible)
    if not ok then return "vE" end
    return value and "v1" or "v0"
end

local function rawEntryData(value)
    if type(value) ~= "table" then return nil end
    return value.dataSource or value
end

local function callGlobal(fnName, ...)
    local fn = G(fnName)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

local function getPrivacyMode()
    local L = BETTERUI and BETTERUI.Log
    return (L and type(L.GetPrivacyMode) == "function" and L.GetPrivacyMode() == true) or false
end

--- Compact, stable identity for a ZOS keybind button group descriptor.
--- The id is local to the UI session and lets the live log correlate add/remove/update calls.
---@param descriptor table|nil
---@param label string|nil
---@return string
function DomainLog.DescribeKeybindDescriptor(descriptor, label)
    local prefix = label and (normalizeLogToken(label, "descriptor") .. ":") or ""
    if descriptor == nil then return prefix .. "nil" end
    if type(descriptor) ~= "table" then return prefix .. "<" .. type(descriptor) .. ">" end

    local count = 0
    local parts = {}
    for i, entry in ipairs(descriptor) do
        count = count + 1
        if #parts < 4 then
            if type(entry) == "table" then
                local keybind = normalizeLogToken(entry.keybind or entry.key or i, "?")
                    :gsub("^UI_SHORTCUT_", "")
                    :sub(1, 12)
                local callback = type(entry.callback) == "function" and "cb1" or "cb0"
                parts[#parts + 1] = keybind .. ":" .. summarizeKeybindName(entry.name):sub(1, 14)
                    .. ":" .. summarizeKeybindVisible(entry.visible) .. ":" .. callback
            else
                parts[#parts + 1] = normalizeLogToken(type(entry), "?")
            end
        end
    end

    return string.format("%s%s[n=%d %s]", prefix, getKeybindDescriptorId(descriptor), count, table.concat(parts, ","))
end

---@param descriptors table|nil
---@param label string|nil
---@return string
function DomainLog.DescribeKeybindDescriptors(descriptors, label)
    local prefix = label and (normalizeLogToken(label, "descriptors") .. ":") or ""
    if descriptors == nil then return prefix .. "nil" end
    if type(descriptors) ~= "table" then return prefix .. "<" .. type(descriptors) .. ">" end

    local first = descriptors[1]
    local looksLikeSingleDescriptor = descriptors.alignment ~= nil
        or (type(first) == "table" and (first.keybind ~= nil or first.name ~= nil or first.callback ~= nil))
    if looksLikeSingleDescriptor then
        return DomainLog.DescribeKeybindDescriptor(descriptors, label)
    end

    local count = 0
    local parts = {}
    for _, descriptor in ipairs(descriptors) do
        count = count + 1
        if #parts < 3 then
            parts[#parts + 1] = DomainLog.DescribeKeybindDescriptor(descriptor)
        end
    end

    return string.format("%sgroups=%d[%s]", prefix, count, table.concat(parts, ";"))
end

---@param descriptors table|nil
---@return number
function DomainLog.CountKeybindDescriptors(descriptors)
    if type(descriptors) ~= "table" then return 0 end
    local count = 0
    for _ in ipairs(descriptors) do count = count + 1 end
    return count
end

--- Compact item identity for replay logs. Stable enough to correlate list rows,
--- keybind targets, action requests, and row-icon state without dumping whole rows.
---@param value table|nil
---@param label string|nil
---@return string
function DomainLog.DescribeItem(value, label)
    local raw = rawEntryData(value)
    local prefix = label and (normalizeLogToken(label, "item") .. ":") or ""
    if type(raw) ~= "table" then return prefix .. "nil" end
    local redactNames = getPrivacyMode()

    local bagId = raw.bagId or raw.bag
    local slotIndex = raw.slotIndex or raw.slot
    local parts = {}
    parts[#parts + 1] = "bag=" .. normalizeLogToken(bagId, "nil")
    parts[#parts + 1] = "slot=" .. normalizeLogToken(slotIndex, "nil")
    if raw.uniqueId ~= nil then parts[#parts + 1] = "uid=" .. normalizeLogToken(raw.uniqueId, "?") end
    if raw.itemType ~= nil then parts[#parts + 1] = "type=" .. normalizeLogToken(raw.itemType, "?") end
    if raw.equipType ~= nil then parts[#parts + 1] = "equip=" .. normalizeLogToken(raw.equipType, "?") end
    if raw.slotType ~= nil then parts[#parts + 1] = "slotType=" .. normalizeLogToken(raw.slotType, "?") end
    if raw.stackCount ~= nil then parts[#parts + 1] = "stack=" .. normalizeLogToken(raw.stackCount, "?") end
    if raw.itemId ~= nil then parts[#parts + 1] = "itemId=" .. normalizeLogToken(raw.itemId, "?") end
    if raw.tradingHouseIndex ~= nil then parts[#parts + 1] = "thIndex=" .. normalizeLogToken(raw.tradingHouseIndex, "?") end
    if raw.listingIndex ~= nil then parts[#parts + 1] = "listing=" .. normalizeLogToken(raw.listingIndex, "?") end
    if raw.entryIndex ~= nil then parts[#parts + 1] = "entry=" .. normalizeLogToken(raw.entryIndex, "?") end
    if raw.slotId ~= nil then parts[#parts + 1] = "slotId=" .. normalizeLogToken(raw.slotId, "?") end

    if bagId ~= nil and slotIndex ~= nil then
        local uid = raw.uniqueId or callGlobal("GetItemUniqueId", bagId, slotIndex)
        if uid ~= nil and raw.uniqueId == nil then parts[#parts + 1] = "uid=" .. normalizeLogToken(uid, "?") end
        if not redactNames then
            local name = callGlobal("GetItemName", bagId, slotIndex)
            if name and name ~= "" then parts[#parts + 1] = "name=" .. normalizeLogToken(name, "?"):sub(1, 36) end
        end
        local stack = raw.stackCount or callGlobal("GetSlotStackSize", bagId, slotIndex)
        if stack ~= nil and raw.stackCount == nil then parts[#parts + 1] = "stack=" .. normalizeLogToken(stack, "?") end
        local link = raw.itemLink or callGlobal("GetItemLink", bagId, slotIndex)
        if link and link ~= "" then parts[#parts + 1] = "hasLink=1" end
    elseif raw.currencyType ~= nil then
        parts[#parts + 1] = "currency=" .. normalizeLogToken(raw.currencyType, "?")
    else
        local rawName = raw.name or raw.itemName or raw.displayName
        if not redactNames and rawName and rawName ~= "" then parts[#parts + 1] = "name=" .. normalizeLogToken(rawName, "?"):sub(1, 36) end
        local rawLink = raw.itemLink or raw.link
        if rawLink and rawLink ~= "" then parts[#parts + 1] = "hasLink=1" end
    end

    return prefix .. "{" .. table.concat(parts, ",") .. "}"
end

---@param list table|nil
---@param label string|nil
---@return string
function DomainLog.DescribeListSelection(list, label)
    local prefix = label and (normalizeLogToken(label, "selection") .. ":") or ""
    if type(list) ~= "table" and type(list) ~= "userdata" then return prefix .. "nil" end
    local okIndex, selectedIndex = pcall(function()
        if list.GetSelectedIndex then return list:GetSelectedIndex() end
        return list.selectedIndex or list.targetSelectedIndex
    end)
    local okCount, count = pcall(function()
        if list.GetNumItems then return list:GetNumItems() end
        return list.dataList and #list.dataList or nil
    end)
    local okData, selectedData = pcall(function()
        if list.GetSelectedData then return list:GetSelectedData() end
        return list.selectedData
    end)
    return string.format("%sidx=%s count=%s %s", prefix,
        normalizeLogToken(okIndex and selectedIndex or nil, "nil"),
        normalizeLogToken(okCount and count or nil, "nil"),
        DomainLog.DescribeItem(okData and selectedData or nil, "selected"))
end

---@param control table|userdata|nil
---@param label string|nil
---@return string
function DomainLog.DescribeControl(control, label)
    local prefix = label and (normalizeLogToken(label, "control") .. ":") or ""
    if control == nil then return prefix .. "nil" end

    local valueType = type(control)
    if valueType ~= "table" and valueType ~= "userdata" then
        return prefix .. "<" .. valueType .. ">"
    end

    local okName, name = pcall(function()
        if control.GetName then return control:GetName() end
        return nil
    end)
    if okName and name and name ~= "" then
        return prefix .. normalizeLogToken(name, "control")
    end

    return prefix .. "<" .. valueType .. ">"
end

function DomainLog.GetCurrencyAmountForLocation(currencyType, location)
    local getCurrencyAmount = G("GetCurrencyAmount")
    if type(getCurrencyAmount) == "function" then
        local ok, amount = pcall(getCurrencyAmount, currencyType, location)
        if ok then return amount end
    end
    if location == rawget(_G, "CURRENCY_LOCATION_CHARACTER") then
        return callGlobal("GetCarriedCurrencyAmount", currencyType)
    end
    if location == rawget(_G, "CURRENCY_LOCATION_BANK") then
        return callGlobal("GetBankedCurrencyAmount", currencyType)
    end
    return nil
end
