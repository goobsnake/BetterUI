--[[
File: Modules/CIM/Core/DeferredTask.lua
Purpose: Managed deferred task execution with automatic cancellation.
         Replaces raw zo_callLater with trackable, cancellable tasks.
Author: BetterUI Team
Last Modified: 2026-01-29

Usage:
    -- Schedule a task (auto-cancels previous task with same ID)
    BETTERUI.CIM.Tasks:Schedule("refreshList", 100, function()
        self:RefreshList()
    end)

    -- Cancel a specific task
    BETTERUI.CIM.Tasks:Cancel("refreshList")

    -- Cancel all tasks (call on scene exit)
    BETTERUI.CIM.Tasks:CancelAll()
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.DeferredTask = {}

-- ============================================================================
-- DEFERRED TASK MANAGER CLASS
-- ============================================================================

-- Class: DeferredTaskManager (extends ZO_Object)
-- Field: _tasks - table<string, number> Task ID -> zo_callLater ID mapping
local DeferredTaskManager = ZO_Object:Subclass()

--- Creates a new DeferredTaskManager instance.
---@return table DeferredTaskManager instance
function DeferredTaskManager:New()
    local obj = ZO_Object.New(self)
    obj._tasks = {}
    return obj
end

--- Schedule a deferred task with automatic previous-task cancellation.
--- If a task with the same ID is already pending, it will be cancelled
--- before scheduling the new one.
---@param taskId string Unique identifier for this task type
---@param delayMs number Delay in milliseconds before execution
---@param callback fun() Function to execute after delay
function DeferredTaskManager:Schedule(taskId, delayMs, callback)
    -- Cancel any existing task with this ID to prevent duplicates
    self:Cancel(taskId)

    -- Schedule new task and store its ID
    self._tasks[taskId] = zo_callLater(function()
        -- Clear from tracking before execution
        self._tasks[taskId] = nil
        -- Execute the callback
        callback()
    end, delayMs)
end

--- Cancel a pending task if it exists.
---@param taskId string Task identifier to cancel
function DeferredTaskManager:Cancel(taskId)
    local existingId = self._tasks[taskId]
    if existingId then
        -- zo_removeCallLater is the correct API for cancelling zo_callLater tasks
        zo_removeCallLater(existingId)
        self._tasks[taskId] = nil
    end
end

--- Cancel all pending tasks.
--- Call this on scene exit to prevent orphaned callbacks.
function DeferredTaskManager:CancelAll()
    for taskId, _ in pairs(self._tasks) do
        self:Cancel(taskId)
    end
end

--- Check if a task is currently pending.
---@param taskId string Task identifier
---@return boolean pending True if task is scheduled and not yet executed
function DeferredTaskManager:IsPending(taskId)
    return self._tasks[taskId] ~= nil
end

--- Get the count of currently pending tasks.
---@return number count Number of pending tasks
function DeferredTaskManager:GetPendingCount()
    local count = 0
    for _, _ in pairs(self._tasks) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- GLOBAL INSTANCE
-- ============================================================================

-- Create the global shared instance for use across all modules
BETTERUI.CIM.Tasks = DeferredTaskManager:New()

-- Export the class for modules that need their own instances
BETTERUI.CIM.DeferredTask.Manager = DeferredTaskManager
