--[[
File: Modules/CIM/Core/Diagnostics/LayoutSnapshot.lua
Purpose: Emits AI-readable UI geometry snapshots to the BetterUI log.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local LayoutSnapshot = {}
BETTERUI.CIM.LayoutSnapshot = LayoutSnapshot

local DEFAULT_MAX_DEPTH = 3
local DEFAULT_MAX_CONTROLS = 60

local SNAPSHOT_ORDER = { "inventory", "vendor", "companions", "tradinghouse", "orbs" }
local SNAPSHOT_REGISTRY = {
    inventory = { globals = { "BUI_GpInv" } },
    vendor = { globals = { "BETTERUI_VendorWindow", "BETTERUI_VENDOR" } },
    companions = { globals = { "BUI_GpCmp" } },
    tradinghouse = { globals = { "BETTERUI_TradingHouseWindow", "BETTERUI_TradingHouse" } },
    orbs = { globals = { "ResourceOrbFrames" } },
}

local SNAPSHOT_ALIASES = {
    inv = "inventory",
    th = "tradinghouse",
    trading_house = "tradinghouse",
    orb = "orbs",
}

local function G(name) return rawget(_G, name) end

local function Trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function NormalizeSnapshotName(name)
    name = Trim(name):lower():gsub("%-", "_")
    if name == "" then return nil end
    return SNAPSHOT_ALIASES[name] or name
end

local function SafeControlCall(control, methodName, ...)
    if control == nil then return false, nil end
    local okMethod, method = pcall(function() return control[methodName] end)
    if not okMethod or type(method) ~= "function" then return false, nil end
    return pcall(method, control, ...)
end

local function GetControlName(control)
    local ok, name = SafeControlCall(control, "GetName")
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

local function IsControlLike(control)
    return GetControlName(control) ~= nil
end

local function GetHidden(control)
    local ok, hidden = SafeControlCall(control, "IsHidden")
    if ok and type(hidden) == "boolean" then return hidden end
    return true
end

local function GetChildCount(control)
    local ok, count = SafeControlCall(control, "GetNumChildren")
    if ok and type(count) == "number" and count > 0 then return count end
    return 0
end

local function ResolveRegistryRoot(key)
    local descriptor = SNAPSHOT_REGISTRY[key]
    if not descriptor then return nil, nil end

    for _, globalName in ipairs(descriptor.globals) do
        local control = G(globalName)
        if IsControlLike(control) then
            return control, globalName
        end
    end
    return nil, nil
end

local function ResolveVisibleRoot()
    for _, key in ipairs(SNAPSHOT_ORDER) do
        local control, globalName = ResolveRegistryRoot(key)
        if control and GetHidden(control) == false then
            return key, control, globalName
        end
    end
    return nil, nil, nil
end

local function DescribeControl(control)
    local L = BETTERUI.Log
    if L and type(L.DescribeControl) == "function" then
        local ok, description = pcall(L.DescribeControl, control)
        if ok then return description end
    end
    return nil
end

local function ShortName(rootName, controlName)
    if not controlName or controlName == "" then return nil end
    if controlName == rootName then return "." end
    if rootName and controlName:sub(1, #rootName) == rootName then
        local suffix = controlName:sub(#rootName + 1)
        if suffix ~= "" then return suffix end
    end
    return controlName
end

local function AddScreenRect(payload, control)
    local ok, left, top, right, bottom = SafeControlCall(control, "GetScreenRect")
    if not ok then return end

    payload.left = left
    payload.top = top
    if type(left) == "number" and type(right) == "number" then
        payload.width = right - left
    end
    if type(top) == "number" and type(bottom) == "number" then
        payload.height = bottom - top
    end
end

local function AddAnchor(payload, control)
    local ok, isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = SafeControlCall(control, "GetAnchor", 0)
    if not ok then return end

    payload.anchorValid = isValidAnchor == true
    if isValidAnchor then
        payload.anchorPoint = point
        payload.anchorRelativeTo = DescribeControl(relativeTo)
        payload.anchorRelativePoint = relativePoint
        payload.anchorOffsetX = offsetX
        payload.anchorOffsetY = offsetY
    end
end

local function BuildRecord(snapshotKey, rootName, rootGlobal, entry, index)
    local control = entry.control
    local hidden = GetHidden(control)
    local controlName = GetControlName(control)
    local payload = {
        snapshot = snapshotKey,
        root = rootName,
        rootGlobal = rootGlobal,
        index = index,
        depth = entry.depth,
        name = ShortName(rootName, controlName),
        hidden = hidden == true,
    }
    AddScreenRect(payload, control)
    AddAnchor(payload, control)
    return payload
end

local function CollectRecords(snapshotKey, root, rootGlobal, maxDepth, maxControls)
    local rootName = GetControlName(root) or rootGlobal or snapshotKey
    local records = {}
    local queue = { { control = root, depth = 0 } }
    local head = 1
    local enqueued = 1
    local visited = 0
    local skipped = 0

    while head <= #queue do
        local entry = queue[head]
        head = head + 1
        visited = visited + 1

        local name = GetControlName(entry.control)
        local hidden = GetHidden(entry.control)
        if name and hidden == false then
            records[#records + 1] = BuildRecord(snapshotKey, rootName, rootGlobal, entry, #records + 1)
        end

        local childCount = GetChildCount(entry.control)
        if childCount > 0 then
            if entry.depth >= maxDepth then
                skipped = skipped + childCount
            else
                for i = 1, childCount do
                    local ok, child = SafeControlCall(entry.control, "GetChild", i)
                    if ok and child ~= nil then
                        if enqueued < maxControls then
                            enqueued = enqueued + 1
                            queue[#queue + 1] = { control = child, depth = entry.depth + 1 }
                        else
                            skipped = skipped + 1
                        end
                    else
                        skipped = skipped + 1
                    end
                end
            end
        end
    end

    return records, visited, skipped, rootName
end

local function TraceLayout(phase, data, level)
    local L = BETTERUI.Log
    if not (L and type(L.TraceEvent) == "function") then return false end
    local categories = L.CATEGORY or {}
    return pcall(L.TraceEvent, categories.STATE or "STATE", "layout.snapshot", phase, data, level)
end

function LayoutSnapshot.GetAvailableNames()
    return table.concat(SNAPSHOT_ORDER, "|")
end

function LayoutSnapshot.Snapshot(name, options)
    options = type(options) == "table" and options or {}
    if not (BETTERUI.Log and type(BETTERUI.Log.TraceEvent) == "function") then
        return false, {
            reason = "loggerUnavailable",
            requested = NormalizeSnapshotName(name) or "visible",
            available = LayoutSnapshot.GetAvailableNames(),
        }
    end

    local requestedName = NormalizeSnapshotName(name)
    local snapshotKey, root, rootGlobal

    if requestedName then
        if not SNAPSHOT_REGISTRY[requestedName] then
            return false, {
                reason = "unknownSnapshot",
                requested = requestedName,
                available = LayoutSnapshot.GetAvailableNames(),
            }
        end
        snapshotKey = requestedName
        root, rootGlobal = ResolveRegistryRoot(snapshotKey)
    else
        snapshotKey, root, rootGlobal = ResolveVisibleRoot()
    end

    if not root then
        return false, {
            reason = requestedName and "rootUnavailable" or "noRegisteredRootVisible",
            requested = requestedName or "visible",
            available = LayoutSnapshot.GetAvailableNames(),
        }
    end

    local maxDepth = tonumber(options.maxDepth) or DEFAULT_MAX_DEPTH
    local maxControls = tonumber(options.maxControls) or DEFAULT_MAX_CONTROLS
    maxDepth = math.max(0, math.min(10, maxDepth))
    maxControls = math.max(1, math.min(200, maxControls))

    local records, visited, skipped, rootName = CollectRecords(snapshotKey, root, rootGlobal, maxDepth, maxControls)
    local beginPayload = {
        snapshot = snapshotKey,
        requested = requestedName or "visible",
        root = rootName,
        rootGlobal = rootGlobal,
        controlCount = #records,
        visited = visited,
        skipped = skipped,
        maxDepth = maxDepth,
        maxControls = maxControls,
    }

    TraceLayout("begin", beginPayload)
    for i = 1, #records do
        TraceLayout("detected", records[i])
    end
    TraceLayout("end", {
        snapshot = snapshotKey,
        root = rootName,
        rootGlobal = rootGlobal,
        emitted = #records,
        skipped = skipped,
        visited = visited,
        maxDepth = maxDepth,
        maxControls = maxControls,
        truncated = skipped > 0,
    })

    return true, {
        snapshot = snapshotKey,
        root = rootName,
        rootGlobal = rootGlobal,
        emitted = #records,
        skipped = skipped,
        visited = visited,
    }
end
