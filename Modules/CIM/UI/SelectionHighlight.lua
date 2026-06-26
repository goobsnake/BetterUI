--[[
File: Modules/CIM/UI/SelectionHighlight.lua
Purpose: Provides a gradient highlight bar for selected inventory/banking rows.
         Gradient is defined in XML via FadeGradient element for reliability.
         This Lua just shows/hides the SelectionBar.
]]

-- Ensure namespace exists
if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.SelectionHighlight then BETTERUI.CIM.SelectionHighlight = {} end

local SelectionHighlight = BETTERUI.CIM.SelectionHighlight

--- Shows or hides the row selection bar.
---@param control table
---@param selected boolean
---@param data table|nil Row data used only for diagnostics
function SelectionHighlight.Setup(control, selected, data)
    if not control then return end

    local function ControlName(target)
        if target and target.GetName then
            local ok, name = pcall(target.GetName, target)
            if ok then return name end
        end
        return "nil"
    end

    local function IsHidden(target)
        if target and target.IsHidden then
            local ok, hidden = pcall(target.IsHidden, target)
            if ok then return hidden == true end
        end
        return nil
    end

    local function IsQuestRow(rowData)
        if type(rowData) ~= "table" then return false end
        local source = rowData and rowData.dataSource or rowData
        return rowData and (rowData.isQuestItem == true
            or (type(source) == "table" and source.isQuestItem == true)
            or (type(source) == "table" and source.questIndex ~= nil)
            or (type(rowData.uniqueId) == "string" and rowData.uniqueId:find("^quest:") ~= nil)
            or (type(source) == "table" and type(source.uniqueId) == "string" and source.uniqueId:find("^quest:") ~= nil)) or false
    end

    local function DescribeRow(rowData)
        local L = BETTERUI.Log
        if L and L.DescribeItem then
            return L.DescribeItem(rowData, "row")
        end
        if type(rowData) ~= "table" then return nil end
        local source = rowData.dataSource or rowData
        return {
            name = rowData.name or source.name,
            uniqueId = rowData.uniqueId or source.uniqueId,
            bagId = source.bagId,
            slotIndex = source.slotIndex,
            questIndex = source.questIndex,
        }
    end

    local function TraceHighlight(phase, payload)
        local L = BETTERUI.Log
        if L and L.TraceEvent then
            local categories = L.CATEGORY or {}
            local levels = L.LEVEL or {}
            L.TraceEvent(categories.LIST or "LIST", "inventory.row.selection_highlight", phase, payload or {}, levels.TRACE)
        elseif L and L.IsActive and L.IsActive() and L.Trace then
            L.Trace((L.CATEGORY and L.CATEGORY.LIST) or "LIST", "selection highlight", payload or {})
        end
    end

    local selectionBar = control:GetNamedChild("SelectionBar")
    if not selectionBar then
        TraceHighlight("missing_bar", {
            controlName = ControlName(control),
            selected = selected == true,
            item = DescribeRow(data),
            quest = IsQuestRow(data),
        })
        return
    end

    selectionBar:SetHidden(not selected)
    TraceHighlight("applied", {
        controlName = ControlName(control),
        selected = selected == true,
        requestedHidden = selected ~= true,
        barHidden = IsHidden(selectionBar),
        item = DescribeRow(data),
        quest = IsQuestRow(data),
    })
end
